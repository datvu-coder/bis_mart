from __future__ import annotations

import json
import os
import sqlite3
from datetime import datetime, timedelta, timezone
from functools import wraps
from pathlib import Path
from typing import Any

import jwt
from flask import Flask, g, jsonify, request
from werkzeug.security import check_password_hash, generate_password_hash

try:
    import psycopg
    from psycopg.rows import dict_row
except ImportError:
    psycopg = None
    dict_row = None

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
BASE_DIR = Path(__file__).resolve().parent
DATABASE = Path(os.getenv("DATABASE_PATH", str(BASE_DIR / "bismart.db"))).expanduser()
DATABASE_URL = os.getenv("DATABASE_URL", "").strip()
DB_BACKEND = "postgres" if DATABASE_URL else "sqlite"
DB_READY = False
VN_TZ = timezone(timedelta(hours=7))
JWT_SECRET = os.getenv("SECRET_KEY", "bismart-dev-secret-change-me")
JWT_EXP_HOURS = 72

app = Flask(__name__)
app.config["SECRET_KEY"] = JWT_SECRET


# ---------------------------------------------------------------------------
# DB abstraction (same pattern as Giao-viec)
# ---------------------------------------------------------------------------
class DBCompatConnection:
    def __init__(self, raw: Any, backend: str) -> None:
        self.raw = raw
        self.backend = backend

    def _adapt(self, sql: str) -> str:
        if self.backend == "postgres":
            sql = sql.replace("%", "%%")
            return sql.replace("?", "%s")
        return sql

    def execute(self, sql: str, params: tuple | list | None = None) -> Any:
        return self.raw.execute(self._adapt(sql), params or ())

    def executescript(self, sql_script: str) -> Any:
        if self.backend == "postgres":
            return self.raw.execute(sql_script)
        return self.raw.executescript(sql_script)

    def commit(self) -> None:
        self.raw.commit()

    def close(self) -> None:
        self.raw.close()

    def __getattr__(self, item: str) -> Any:
        return getattr(self.raw, item)


if DB_BACKEND == "postgres" and psycopg is not None:
    DBIntegrityError = psycopg.IntegrityError
else:
    DBIntegrityError = sqlite3.IntegrityError


def create_db_connection() -> DBCompatConnection:
    if DB_BACKEND == "postgres" and psycopg is not None:
        conn = psycopg.connect(DATABASE_URL, row_factory=dict_row, autocommit=False)
        return DBCompatConnection(conn, "postgres")
    conn = sqlite3.connect(str(DATABASE))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return DBCompatConnection(conn, "sqlite")


def get_db() -> DBCompatConnection:
    if "db" not in g:
        g.db = create_db_connection()
    return g.db


@app.teardown_appcontext
def close_db(_exc: BaseException | None = None) -> None:
    db = g.pop("db", None)
    if db is not None:
        db.close()


def ensure_database_ready() -> None:
    global DB_READY
    if DB_READY:
        return
    db = get_db()
    schema_file = "schema_postgres.sql" if DB_BACKEND == "postgres" else "schema.sql"
    schema_sql = (BASE_DIR / schema_file).read_text(encoding="utf-8")
    db.executescript(schema_sql)
    db.commit()
    _seed_data(db)
    DB_READY = True


@app.before_request
def _before_request() -> None:
    ensure_database_ready()


# ---------------------------------------------------------------------------
# JWT auth helpers
# ---------------------------------------------------------------------------
def create_token(user_id: int, employee_id: int | None) -> str:
    payload = {
        "user_id": user_id,
        "employee_id": employee_id,
        "exp": datetime.now(tz=VN_TZ) + timedelta(hours=JWT_EXP_HOURS),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")


def get_current_user() -> dict | None:
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return None
    token = auth[7:]
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None


def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        user = get_current_user()
        if user is None:
            return jsonify({"error": "Unauthorized"}), 401
        g.current_user = user
        return f(*args, **kwargs)
    return decorated


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------
@app.get("/healthz")
def healthz():
    try:
        ensure_database_ready()
    except Exception as exc:
        return jsonify({"status": "error", "message": str(exc)}), 503
    return jsonify({"status": "ok", "backend": DB_BACKEND}), 200


# ---------------------------------------------------------------------------
# AUTH endpoints
# ---------------------------------------------------------------------------
@app.post("/api/auth/login")
def api_login():
    data = request.get_json(silent=True) or {}
    username = (data.get("username") or "").strip()
    password = data.get("password") or ""
    if not username or not password:
        return jsonify({"error": "Thiếu tên đăng nhập hoặc mật khẩu"}), 400

    db = get_db()
    row = dict(db.execute(
        "SELECT u.id, u.password_hash, u.employee_id, u.is_active, "
        "e.full_name, e.employee_code, e.position, e.work_location, e.score, e.email "
        "FROM users u LEFT JOIN employees e ON u.employee_id = e.id "
        "WHERE u.username = ?", (username,)
    ).fetchone() or {})
    if not row or not row.get("id"):
        return jsonify({"error": "Sai tên đăng nhập hoặc mật khẩu"}), 401
    if not row.get("is_active"):
        return jsonify({"error": "Tài khoản đã bị khóa"}), 403
    if not check_password_hash(row["password_hash"], password):
        return jsonify({"error": "Sai tên đăng nhập hoặc mật khẩu"}), 401

    token = create_token(row["id"], row.get("employee_id"))
    return jsonify({
        "token": token,
        "user": _employee_dict(row),
    })


@app.get("/api/auth/me")
@login_required
def api_me():
    db = get_db()
    emp_id = g.current_user.get("employee_id")
    if not emp_id:
        return jsonify({"user": None})
    row = db.execute("SELECT * FROM employees WHERE id = ?", (emp_id,)).fetchone()
    if not row:
        return jsonify({"user": None})
    return jsonify({"user": _employee_dict(dict(row))})


@app.put("/api/auth/profile")
@login_required
def api_update_profile():
    data = request.get_json(silent=True) or {}
    emp_id = g.current_user.get("employee_id")
    if not emp_id:
        return jsonify({"error": "No employee linked"}), 400
    db = get_db()
    fields, params = [], []
    for col, key in [("full_name", "fullName"), ("email", "email"), ("work_location", "workLocation")]:
        if key in data:
            fields.append(f"{col} = ?")
            params.append(data[key])
    if not fields:
        return jsonify({"error": "Không có gì để cập nhật"}), 400
    params.append(emp_id)
    db.execute(f"UPDATE employees SET {', '.join(fields)} WHERE id = ?", tuple(params))
    db.commit()
    row = db.execute("SELECT * FROM employees WHERE id = ?", (emp_id,)).fetchone()
    return jsonify({"user": _employee_dict(dict(row))})


# ---------------------------------------------------------------------------
# EMPLOYEES
# ---------------------------------------------------------------------------
@app.get("/api/employees")
@login_required
def api_list_employees():
    db = get_db()
    rows = db.execute(
        "SELECT * FROM employees WHERE is_active = 1 ORDER BY score DESC"
    ).fetchall()
    employees = [_employee_dict(dict(r)) for r in rows]
    # assign ranks
    for i, e in enumerate(employees):
        e["rank"] = i + 1
    return jsonify(employees)


@app.post("/api/employees")
@login_required
def api_create_employee():
    data = request.get_json(silent=True) or {}
    required = ["fullName", "employeeCode", "position"]
    for f in required:
        if not data.get(f):
            return jsonify({"error": f"Thiếu {f}"}), 400
    db = get_db()
    try:
        cur = db.execute(
            "INSERT INTO employees (full_name, employee_code, position, work_location, "
            "score, email, phone, department, province, area, store_code, status) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (data["fullName"], data["employeeCode"], data["position"],
             data.get("workLocation", ""), data.get("score", 0), data.get("email"),
             data.get("phone"), data.get("department", "Kinh doanh"),
             data.get("province"), data.get("area"),
             data.get("storeCode"), data.get("status", "Chính thức")),
        )
        db.commit()
        new_id = cur.lastrowid if DB_BACKEND == "sqlite" else None
        if DB_BACKEND == "postgres":
            row = db.execute("SELECT * FROM employees WHERE employee_code = ?",
                             (data["employeeCode"],)).fetchone()
            new_id = dict(row)["id"]
        row = db.execute("SELECT * FROM employees WHERE id = ?", (new_id,)).fetchone()
        return jsonify(_employee_dict(dict(row))), 201
    except DBIntegrityError:
        return jsonify({"error": "Mã nhân viên đã tồn tại"}), 409


@app.get("/api/employees/<int:eid>")
@login_required
def api_get_employee(eid: int):
    db = get_db()
    row = db.execute("SELECT * FROM employees WHERE id = ? AND is_active = 1", (eid,)).fetchone()
    if not row:
        return jsonify({"error": "Không tìm thấy"}), 404
    return jsonify(_employee_dict(dict(row)))


@app.put("/api/employees/<int:eid>")
@login_required
def api_update_employee(eid: int):
    data = request.get_json(silent=True) or {}
    db = get_db()
    fields, params = [], []
    for col, key in [("full_name", "fullName"), ("employee_code", "employeeCode"),
                     ("position", "position"), ("work_location", "workLocation"),
                     ("score", "score"), ("email", "email"), ("phone", "phone"),
                     ("department", "department"), ("province", "province"),
                     ("area", "area"), ("store_code", "storeCode"),
                     ("status", "status"), ("address", "address")]:
        if key in data:
            fields.append(f"{col} = ?")
            params.append(data[key])
    if not fields:
        return jsonify({"error": "Không có gì để cập nhật"}), 400
    params.append(eid)
    db.execute(f"UPDATE employees SET {', '.join(fields)} WHERE id = ?", tuple(params))
    db.commit()
    row = db.execute("SELECT * FROM employees WHERE id = ?", (eid,)).fetchone()
    if not row:
        return jsonify({"error": "Không tìm thấy"}), 404
    return jsonify(_employee_dict(dict(row)))


@app.delete("/api/employees/<int:eid>")
@login_required
def api_delete_employee(eid: int):
    db = get_db()
    db.execute("UPDATE employees SET is_active = 0 WHERE id = ?", (eid,))
    db.commit()
    return jsonify({"ok": True})


# ---------------------------------------------------------------------------
# ATTENDANCE
# ---------------------------------------------------------------------------
@app.get("/api/attendances")
@login_required
def api_list_attendances():
    date_str = request.args.get("date", datetime.now(tz=VN_TZ).strftime("%Y-%m-%d"))
    db = get_db()
    rows = db.execute(
        "SELECT a.*, e.full_name FROM attendances a "
        "JOIN employees e ON a.employee_id = e.id "
        "WHERE a.attend_date = ? ORDER BY a.check_in_time",
        (date_str,)
    ).fetchall()
    return jsonify([_attendance_dict(dict(r)) for r in rows])


@app.post("/api/attendances/checkin")
@login_required
def api_checkin():
    data = request.get_json(silent=True) or {}
    emp_id = data.get("employeeId")
    if not emp_id:
        return jsonify({"error": "Thiếu employeeId"}), 400
    db = get_db()
    now = datetime.now(tz=VN_TZ)
    date_str = now.strftime("%Y-%m-%d")
    time_str = now.strftime("%Y-%m-%dT%H:%M:%S")
    try:
        db.execute(
            "INSERT INTO attendances (employee_id, attend_date, check_in_time) VALUES (?, ?, ?)",
            (emp_id, date_str, time_str),
        )
        db.commit()
    except DBIntegrityError:
        db.execute(
            "UPDATE attendances SET check_in_time = ? WHERE employee_id = ? AND attend_date = ?",
            (time_str, emp_id, date_str),
        )
        db.commit()
    return jsonify({"ok": True, "checkInTime": time_str})


@app.post("/api/attendances/checkout")
@login_required
def api_checkout():
    data = request.get_json(silent=True) or {}
    emp_id = data.get("employeeId")
    if not emp_id:
        return jsonify({"error": "Thiếu employeeId"}), 400
    db = get_db()
    now = datetime.now(tz=VN_TZ)
    date_str = now.strftime("%Y-%m-%d")
    time_str = now.strftime("%Y-%m-%dT%H:%M:%S")
    db.execute(
        "UPDATE attendances SET check_out_time = ? WHERE employee_id = ? AND attend_date = ?",
        (time_str, emp_id, date_str),
    )
    db.commit()
    return jsonify({"ok": True, "checkOutTime": time_str})


# ---------------------------------------------------------------------------
# WORK SHIFTS
# ---------------------------------------------------------------------------
@app.get("/api/shifts")
@login_required
def api_list_shifts():
    db = get_db()
    rows = db.execute("SELECT * FROM work_shifts ORDER BY start_hour, start_minute").fetchall()
    return jsonify([_shift_dict(dict(r)) for r in rows])


@app.post("/api/shifts")
@login_required
def api_create_shift():
    data = request.get_json(silent=True) or {}
    db = get_db()
    cur = db.execute(
        "INSERT INTO work_shifts (name, start_hour, start_minute, end_hour, end_minute) "
        "VALUES (?, ?, ?, ?, ?)",
        (data.get("name", ""), data.get("startHour", 0), data.get("startMinute", 0),
         data.get("endHour", 0), data.get("endMinute", 0)),
    )
    db.commit()
    new_id = cur.lastrowid if DB_BACKEND == "sqlite" else None
    if DB_BACKEND == "postgres":
        row = db.execute("SELECT * FROM work_shifts ORDER BY id DESC LIMIT 1").fetchone()
        new_id = dict(row)["id"]
    row = db.execute("SELECT * FROM work_shifts WHERE id = ?", (new_id,)).fetchone()
    return jsonify(_shift_dict(dict(row))), 201


@app.delete("/api/shifts/<int:sid>")
@login_required
def api_delete_shift(sid: int):
    db = get_db()
    db.execute("DELETE FROM work_shifts WHERE id = ?", (sid,))
    db.commit()
    return jsonify({"ok": True})


# ---------------------------------------------------------------------------
# STORES
# ---------------------------------------------------------------------------
@app.get("/api/stores")
@login_required
def api_list_stores():
    db = get_db()
    rows = db.execute("SELECT * FROM stores ORDER BY id").fetchall()
    stores = []
    for r in rows:
        s = _store_dict(dict(r))
        mgr_rows = db.execute(
            "SELECT sm.employee_id, e.full_name, e.employee_code, e.email "
            "FROM store_managers sm JOIN employees e ON sm.employee_id = e.id "
            "WHERE sm.store_id = ?", (s["id"],)
        ).fetchall()
        s["managers"] = [
            {"employeeId": str(dict(m)["employee_id"]), "name": dict(m)["full_name"],
             "employeeCode": dict(m)["employee_code"], "email": dict(m).get("email")}
            for m in mgr_rows
        ]
        stores.append(s)
    return jsonify(stores)


@app.post("/api/stores")
@login_required
def api_create_store():
    data = request.get_json(silent=True) or {}
    if not data.get("name") or not data.get("storeCode"):
        return jsonify({"error": "Thiếu tên hoặc mã cửa hàng"}), 400
    db = get_db()
    try:
        cur = db.execute(
            "INSERT INTO stores (name, store_code, store_group, latitude, longitude, "
            "province, address, phone, owner, status, store_type) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (data["name"], data["storeCode"], data.get("group", "I"),
             data.get("latitude"), data.get("longitude"),
             data.get("province"), data.get("address"),
             data.get("phone"), data.get("owner"),
             data.get("status", "Hoạt động"), data.get("storeType")),
        )
        db.commit()
        new_id = cur.lastrowid if DB_BACKEND == "sqlite" else None
        if DB_BACKEND == "postgres":
            row = db.execute("SELECT * FROM stores WHERE store_code = ?",
                             (data["storeCode"],)).fetchone()
            new_id = dict(row)["id"]
        row = db.execute("SELECT * FROM stores WHERE id = ?", (new_id,)).fetchone()
        return jsonify(_store_dict(dict(row))), 201
    except DBIntegrityError:
        return jsonify({"error": "Mã cửa hàng đã tồn tại"}), 409


@app.put("/api/stores/<int:sid>")
@login_required
def api_update_store(sid: int):
    data = request.get_json(silent=True) or {}
    db = get_db()
    fields, params = [], []
    for col, key in [("name", "name"), ("store_code", "storeCode"),
                     ("store_group", "group"), ("latitude", "latitude"),
                     ("longitude", "longitude"), ("province", "province"),
                     ("address", "address"), ("phone", "phone"),
                     ("owner", "owner"), ("status", "status"),
                     ("store_type", "storeType")]:
        if key in data:
            fields.append(f"{col} = ?")
            params.append(data[key])
    if not fields:
        return jsonify({"error": "Không có gì để cập nhật"}), 400
    params.append(sid)
    db.execute(f"UPDATE stores SET {', '.join(fields)} WHERE id = ?", tuple(params))
    db.commit()
    row = db.execute("SELECT * FROM stores WHERE id = ?", (sid,)).fetchone()
    if not row:
        return jsonify({"error": "Không tìm thấy"}), 404
    return jsonify(_store_dict(dict(row)))


@app.delete("/api/stores/<int:sid>")
@login_required
def api_delete_store(sid: int):
    db = get_db()
    db.execute("DELETE FROM stores WHERE id = ?", (sid,))
    db.commit()
    return jsonify({"ok": True})


# ---------------------------------------------------------------------------
# PRODUCTS
# ---------------------------------------------------------------------------
@app.get("/api/products")
@login_required
def api_list_products():
    db = get_db()
    rows = db.execute("SELECT * FROM products ORDER BY product_group, name").fetchall()
    return jsonify([_product_dict(dict(r)) for r in rows])


@app.post("/api/products")
@login_required
def api_create_product():
    data = request.get_json(silent=True) or {}
    if not data.get("name"):
        return jsonify({"error": "Thiếu tên sản phẩm"}), 400
    db = get_db()
    cur = db.execute(
        "INSERT INTO products (name, unit, price_with_vat, product_group) VALUES (?, ?, ?, ?)",
        (data["name"], data.get("unit", "Lon"),
         data.get("priceWithVAT", 0), data.get("productGroup", "DELI")),
    )
    db.commit()
    new_id = cur.lastrowid if DB_BACKEND == "sqlite" else None
    if DB_BACKEND == "postgres":
        row = db.execute("SELECT * FROM products ORDER BY id DESC LIMIT 1").fetchone()
        new_id = dict(row)["id"]
    row = db.execute("SELECT * FROM products WHERE id = ?", (new_id,)).fetchone()
    return jsonify(_product_dict(dict(row))), 201


@app.put("/api/products/<int:pid>")
@login_required
def api_update_product(pid: int):
    data = request.get_json(silent=True) or {}
    db = get_db()
    fields, params = [], []
    for col, key in [("name", "name"), ("unit", "unit"),
                     ("price_with_vat", "priceWithVAT"), ("product_group", "productGroup")]:
        if key in data:
            fields.append(f"{col} = ?")
            params.append(data[key])
    if not fields:
        return jsonify({"error": "Không có gì để cập nhật"}), 400
    params.append(pid)
    db.execute(f"UPDATE products SET {', '.join(fields)} WHERE id = ?", tuple(params))
    db.commit()
    row = db.execute("SELECT * FROM products WHERE id = ?", (pid,)).fetchone()
    if not row:
        return jsonify({"error": "Không tìm thấy"}), 404
    return jsonify(_product_dict(dict(row)))


@app.delete("/api/products/<int:pid>")
@login_required
def api_delete_product(pid: int):
    db = get_db()
    db.execute("DELETE FROM products WHERE id = ?", (pid,))
    db.commit()
    return jsonify({"ok": True})


# ---------------------------------------------------------------------------
# SALES REPORTS
# ---------------------------------------------------------------------------
@app.get("/api/reports")
@login_required
def api_list_reports():
    filter_type = request.args.get("filter", "all")
    db = get_db()
    now = datetime.now(tz=VN_TZ)
    if filter_type == "today":
        where = "WHERE r.report_date = ?"
        params = (now.strftime("%Y-%m-%d"),)
    elif filter_type == "week":
        week_ago = (now - timedelta(days=7)).strftime("%Y-%m-%d")
        where = "WHERE r.report_date >= ?"
        params = (week_ago,)
    elif filter_type == "month":
        month_start = now.replace(day=1).strftime("%Y-%m-%d")
        where = "WHERE r.report_date >= ?"
        params = (month_start,)
    else:
        where = ""
        params = ()

    rows = db.execute(
        f"SELECT r.* FROM sales_reports r {where} ORDER BY r.report_date DESC", params
    ).fetchall()
    reports = []
    for r in rows:
        rd = _report_dict(dict(r))
        items = db.execute(
            "SELECT * FROM sale_items WHERE report_id = ?", (rd["id"],)
        ).fetchall()
        rd["products"] = [_sale_item_dict(dict(it)) for it in items]
        reports.append(rd)
    return jsonify(reports)


@app.post("/api/reports")
@login_required
def api_create_report():
    data = request.get_json(silent=True) or {}
    db = get_db()
    user_id = g.current_user.get("user_id")
    cur = db.execute(
        "INSERT INTO sales_reports (report_date, pg_name, store_name, nu, sale_out, "
        "store_code, report_month, revenue, points, employee_code, created_by) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (data.get("date", datetime.now(tz=VN_TZ).strftime("%Y-%m-%d")),
         data.get("pgName", ""), data.get("storeName", ""),
         data.get("nu", 0), data.get("saleOut", 0),
         data.get("storeCode", ""), data.get("reportMonth"),
         data.get("revenue", 0), data.get("points", 0),
         data.get("employeeCode", ""), user_id),
    )
    db.commit()
    report_id = cur.lastrowid if DB_BACKEND == "sqlite" else None
    if DB_BACKEND == "postgres":
        row = db.execute("SELECT * FROM sales_reports ORDER BY id DESC LIMIT 1").fetchone()
        report_id = dict(row)["id"]

    for item in data.get("products", []):
        db.execute(
            "INSERT INTO sale_items (report_id, product_id, product_name, quantity, unit_price) "
            "VALUES (?, ?, ?, ?, ?)",
            (report_id, item.get("productId"), item.get("productName", ""),
             item.get("quantity", 0), item.get("unitPrice", 0)),
        )
    db.commit()
    row = db.execute("SELECT * FROM sales_reports WHERE id = ?", (report_id,)).fetchone()
    rd = _report_dict(dict(row))
    items = db.execute("SELECT * FROM sale_items WHERE report_id = ?", (report_id,)).fetchall()
    rd["products"] = [_sale_item_dict(dict(it)) for it in items]
    return jsonify(rd), 201


@app.delete("/api/reports/<int:rid>")
@login_required
def api_delete_report(rid: int):
    db = get_db()
    db.execute("DELETE FROM sales_reports WHERE id = ?", (rid,))
    db.commit()
    return jsonify({"ok": True})


@app.put("/api/reports/<int:rid>")
@login_required
def api_update_report(rid: int):
    data = request.get_json(silent=True) or {}
    db = get_db()
    db.execute(
        "UPDATE sales_reports SET report_date=?, pg_name=?, store_name=?, nu=?, "
        "sale_out=?, store_code=?, revenue=? WHERE id=?",
        (data.get("date"), data.get("pgName"), data.get("storeName", ""),
         data.get("nu", 0), data.get("saleOut", 0),
         data.get("storeCode", ""), data.get("revenue", 0), rid),
    )
    db.execute("DELETE FROM sale_items WHERE report_id = ?", (rid,))
    for item in data.get("products", []):
        db.execute(
            "INSERT INTO sale_items (report_id, product_id, product_name, quantity, unit_price) "
            "VALUES (?, ?, ?, ?, ?)",
            (rid, item.get("productId"), item.get("productName", ""),
             item.get("quantity", 0), item.get("unitPrice", 0)),
        )
    db.commit()
    row = db.execute("SELECT * FROM sales_reports WHERE id = ?", (rid,)).fetchone()
    rd = _report_dict(dict(row))
    items = db.execute("SELECT * FROM sale_items WHERE report_id = ?", (rid,)).fetchall()
    rd["products"] = [_sale_item_dict(dict(it)) for it in items]
    return jsonify(rd)


# ---------------------------------------------------------------------------
# COMMUNITY POSTS
# ---------------------------------------------------------------------------
@app.get("/api/posts")
@login_required
def api_list_posts():
    db = get_db()
    user_id = g.current_user.get("user_id")
    rows = db.execute(
        "SELECT p.*, (SELECT COUNT(*) FROM post_likes pl WHERE pl.post_id = p.id AND pl.user_id = ?) AS is_liked "
        "FROM community_posts p ORDER BY p.created_at DESC",
        (user_id,)
    ).fetchall()
    return jsonify([_post_dict(dict(r)) for r in rows])


@app.post("/api/posts")
@login_required
def api_create_post():
    data = request.get_json(silent=True) or {}
    db = get_db()
    user_id = g.current_user.get("user_id")
    author = data.get("authorName", "Bạn")
    cur = db.execute(
        "INSERT INTO community_posts (author_id, author_name, content) VALUES (?, ?, ?)",
        (user_id, author, data.get("content", "")),
    )
    db.commit()
    new_id = cur.lastrowid if DB_BACKEND == "sqlite" else None
    if DB_BACKEND == "postgres":
        row = db.execute("SELECT * FROM community_posts ORDER BY id DESC LIMIT 1").fetchone()
        new_id = dict(row)["id"]
    row = db.execute("SELECT * FROM community_posts WHERE id = ?", (new_id,)).fetchone()
    return jsonify(_post_dict(dict(row))), 201


@app.post("/api/posts/<int:pid>/like")
@login_required
def api_toggle_like(pid: int):
    db = get_db()
    user_id = g.current_user.get("user_id")
    existing = db.execute(
        "SELECT id FROM post_likes WHERE post_id = ? AND user_id = ?", (pid, user_id)
    ).fetchone()
    if existing:
        db.execute("DELETE FROM post_likes WHERE post_id = ? AND user_id = ?", (pid, user_id))
        db.execute("UPDATE community_posts SET like_count = like_count - 1 WHERE id = ?", (pid,))
        liked = False
    else:
        db.execute("INSERT INTO post_likes (post_id, user_id) VALUES (?, ?)", (pid, user_id))
        db.execute("UPDATE community_posts SET like_count = like_count + 1 WHERE id = ?", (pid,))
        liked = True
    db.commit()
    row = db.execute("SELECT like_count FROM community_posts WHERE id = ?", (pid,)).fetchone()
    return jsonify({"isLiked": liked, "likeCount": dict(row)["like_count"]})


@app.post("/api/posts/<int:pid>/comment")
@login_required
def api_add_comment(pid: int):
    db = get_db()
    db.execute("UPDATE community_posts SET comment_count = comment_count + 1 WHERE id = ?", (pid,))
    db.commit()
    row = db.execute("SELECT comment_count FROM community_posts WHERE id = ?", (pid,)).fetchone()
    return jsonify({"commentCount": dict(row)["comment_count"]})


@app.delete("/api/posts/<int:pid>")
@login_required
def api_delete_post(pid: int):
    db = get_db()
    db.execute("DELETE FROM community_posts WHERE id = ?", (pid,))
    db.commit()
    return jsonify({"ok": True})


# ---------------------------------------------------------------------------
# LESSONS
# ---------------------------------------------------------------------------
@app.get("/api/lessons")
@login_required
def api_list_lessons():
    db = get_db()
    rows = db.execute("SELECT * FROM lessons ORDER BY id").fetchall()
    return jsonify([_lesson_dict(dict(r)) for r in rows])


# ---------------------------------------------------------------------------
# TRAINING EVENTS
# ---------------------------------------------------------------------------
@app.get("/api/events")
@login_required
def api_list_events():
    db = get_db()
    rows = db.execute("SELECT * FROM training_events ORDER BY event_date").fetchall()
    result: dict[str, list[str]] = {}
    for r in rows:
        d = dict(r)
        date_key = d["event_date"]
        result.setdefault(date_key, []).append(d["title"])
    return jsonify(result)


@app.post("/api/events")
@login_required
def api_create_event():
    data = request.get_json(silent=True) or {}
    db = get_db()
    user_id = g.current_user.get("user_id")
    db.execute(
        "INSERT INTO training_events (event_date, title, created_by) VALUES (?, ?, ?)",
        (data.get("date", ""), data.get("title", ""), user_id),
    )
    db.commit()
    return jsonify({"ok": True}), 201


@app.delete("/api/events")
@login_required
def api_delete_event():
    data = request.get_json(silent=True) or {}
    db = get_db()
    db.execute(
        "DELETE FROM training_events WHERE event_date = ? AND title = ?",
        (data.get("date", ""), data.get("title", "")),
    )
    db.commit()
    return jsonify({"ok": True})


# ---------------------------------------------------------------------------
# DASHBOARD
# ---------------------------------------------------------------------------
@app.get("/api/dashboard")
@login_required
def api_dashboard():
    filter_type = request.args.get("filter", "today")
    db = get_db()
    now = datetime.now(tz=VN_TZ)

    # Revenue
    if filter_type == "today":
        where = "WHERE r.report_date = ?"
        params = (now.strftime("%Y-%m-%d"),)
    elif filter_type == "week":
        week_ago = (now - timedelta(days=7)).strftime("%Y-%m-%d")
        where = "WHERE r.report_date >= ?"
        params = (week_ago,)
    else:
        month_start = now.replace(day=1).strftime("%Y-%m-%d")
        where = "WHERE r.report_date >= ?"
        params = (month_start,)

    rev_row = db.execute(
        f"SELECT COALESCE(SUM(r.revenue), 0) AS total FROM sales_reports r {where}", params
    ).fetchone()
    total_revenue = dict(rev_row)["total"]

    # Top employees
    top_rows = db.execute(
        "SELECT full_name, score FROM employees WHERE is_active = 1 ORDER BY score DESC LIMIT 10"
    ).fetchall()
    top10 = [{"rank": i + 1, "name": dict(r)["full_name"]} for i, r in enumerate(top_rows)]

    # Product sales
    prod_rows = db.execute(
        f"SELECT si.product_name, SUM(si.quantity) AS qty "
        f"FROM sale_items si JOIN sales_reports r ON si.report_id = r.id "
        f"{where} GROUP BY si.product_name ORDER BY qty DESC LIMIT 5", params
    ).fetchall()
    product_chart = [{"productName": dict(r)["product_name"], "quantity": dict(r)["qty"]}
                     for r in prod_rows]

    # Revenue chart
    chart_days = 7 if filter_type in ("today", "week") else 14
    revenue_chart = []
    for i in range(chart_days):
        d = now - timedelta(days=chart_days - 1 - i)
        d_str = d.strftime("%Y-%m-%d")
        day_rev = db.execute(
            "SELECT COALESCE(SUM(revenue), 0) AS rev FROM sales_reports WHERE report_date = ?",
            (d_str,)
        ).fetchone()
        revenue_chart.append({
            "date": d_str,
            "revenue": dict(day_rev)["rev"],
            "target": 5000000,
        })

    # Featured programs (static for now)
    featured = ["Cao Lớn Trước 7 Tuổi", "DELIMIL PRO+ Ưu đãi T4"]

    return jsonify({
        "date": now.strftime("%Y-%m-%dT%H:%M:%S"),
        "announcement": "Chào mừng đến với Bi'S MART! Chúc bạn một ngày làm việc hiệu quả.",
        "featuredPrograms": featured,
        "top10": top10,
        "groupRevenue": total_revenue,
        "totalRevenue": total_revenue,
        "revenueChart": revenue_chart,
        "productChart": product_chart,
    })


# ---------------------------------------------------------------------------
# Seed data
# ---------------------------------------------------------------------------
def _seed_data(db: DBCompatConnection) -> None:
    """Seed minimal admin user if database was imported from Excel and has employees but no users."""
    row = db.execute("SELECT COUNT(*) AS cnt FROM users").fetchone()
    if dict(row)["cnt"] > 0:
        return
    # Check if employees exist (from import)
    emp_row = db.execute("SELECT COUNT(*) AS cnt FROM employees").fetchone()
    if dict(emp_row)["cnt"] > 0:
        # Find a MNG employee for admin
        mgr = db.execute("SELECT id FROM employees WHERE position = 'MNG' AND is_active = 1 LIMIT 1").fetchone()
        emp_id = dict(mgr)["id"] if mgr else 1
        admin_username = os.getenv("SEED_ADMIN_USERNAME", "admin")
        admin_password = os.getenv("SEED_ADMIN_PASSWORD", "admin123")
        db.execute(
            "INSERT INTO users (username, password_hash, employee_id) VALUES (?, ?, ?)",
            (admin_username, generate_password_hash(admin_password, method="pbkdf2:sha256"), emp_id),
        )
        db.commit()
        return

    # Fallback: seed basic data if no Excel import was done
    admin_username = os.getenv("SEED_ADMIN_USERNAME", "admin")
    admin_password = os.getenv("SEED_ADMIN_PASSWORD", "admin123")
    db.execute(
        "INSERT INTO employees (full_name, employee_code, position, work_location, score, email) "
        "VALUES (?, ?, ?, ?, ?, ?)",
        ("Admin", "ADMIN001", "MNG", "Head Office", 1000, "admin@bismart.vn"),
    )
    db.execute(
        "INSERT INTO users (username, password_hash, employee_id) VALUES (?, ?, 1)",
        (admin_username, generate_password_hash(admin_password, method="pbkdf2:sha256")),
    )
    db.commit()


now = datetime.now(tz=VN_TZ)


# ---------------------------------------------------------------------------
# Dict converters
# ---------------------------------------------------------------------------
def _employee_dict(row: dict) -> dict:
    return {
        "id": str(row.get("id", row.get("employee_id", ""))),
        "fullName": row.get("full_name", ""),
        "employeeCode": row.get("employee_code", ""),
        "dateOfBirth": row.get("date_of_birth"),
        "cccd": row.get("cccd"),
        "address": row.get("address"),
        "status": row.get("status", "Chính thức"),
        "position": row.get("position", ""),
        "department": row.get("department", "Kinh doanh"),
        "workLocation": row.get("work_location", ""),
        "province": row.get("province"),
        "area": row.get("area"),
        "createdDate": row.get("created_date"),
        "probationDate": row.get("probation_date"),
        "officialDate": row.get("official_date"),
        "resignDate": row.get("resign_date"),
        "resignReason": row.get("resign_reason"),
        "phone": row.get("phone"),
        "email": row.get("email"),
        "avatarUrl": row.get("avatar_url"),
        "storeCode": row.get("store_code"),
        "score": row.get("score", 0),
        "rankLevel": row.get("rank_level"),
        "rank": row.get("rank", 0),
    }


def _store_dict(row: dict) -> dict:
    return {
        "id": str(row["id"]),
        "name": row["name"],
        "storeCode": row["store_code"],
        "group": row["store_group"],
        "latitude": row.get("latitude"),
        "longitude": row.get("longitude"),
        "province": row.get("province"),
        "sup": row.get("sup"),
        "status": row.get("status", "Hoạt động"),
        "openDate": row.get("open_date"),
        "closeDate": row.get("close_date"),
        "storeType": row.get("store_type"),
        "address": row.get("address"),
        "phone": row.get("phone"),
        "owner": row.get("owner"),
        "taxCode": row.get("tax_code"),
        "managers": [],
    }


def _product_dict(row: dict) -> dict:
    return {
        "id": str(row["id"]),
        "name": row["name"],
        "unit": row["unit"],
        "priceWithVAT": row["price_with_vat"],
        "productCondition": row.get("product_condition"),
        "productGroup": row["product_group"],
    }


def _report_dict(row: dict) -> dict:
    return {
        "id": str(row["id"]),
        "date": row["report_date"],
        "pgName": row["pg_name"],
        "storeName": row.get("store_name", ""),
        "nu": row["nu"],
        "saleOut": row.get("sale_out", 0),
        "storeCode": row.get("store_code", ""),
        "reportMonth": row.get("report_month"),
        "revenue": row["revenue"],
        "points": row.get("points", 0),
        "employeeCode": row.get("employee_code", ""),
        "products": [],
    }


def _sale_item_dict(row: dict) -> dict:
    return {
        "productId": str(row.get("product_id") or ""),
        "productName": row["product_name"],
        "unit": row.get("unit", ""),
        "quantity": row["quantity"],
        "unitPrice": row["unit_price"],
        "productGroup": row.get("product_group", ""),
    }


def _attendance_dict(row: dict) -> dict:
    return {
        "id": str(row["id"]),
        "date": row["attend_date"],
        "employeeId": str(row["employee_id"]),
        "employeeName": row.get("full_name", ""),
        "shiftName": row.get("shift_name", ""),
        "shiftTimeRange": row.get("shift_time_range", ""),
        "coordinates": row.get("coordinates"),
        "distanceIn": row.get("distance_in"),
        "isCheckedIn": row.get("check_in_time") is not None,
        "checkInTime": row.get("check_in_time"),
        "checkInDiff": row.get("check_in_diff"),
        "checkInStatus": row.get("check_in_status", ""),
        "distanceOut": row.get("distance_out"),
        "checkOutTime": row.get("check_out_time"),
        "checkOutDiff": row.get("check_out_diff"),
        "checkOutStatus": row.get("check_out_status", ""),
    }


def _shift_dict(row: dict) -> dict:
    return {
        "id": str(row["id"]),
        "name": row["name"],
        "shiftCode": row.get("shift_code", ""),
        "startHour": row["start_hour"],
        "startMinute": row["start_minute"],
        "endHour": row["end_hour"],
        "endMinute": row["end_minute"],
        "storeName": row.get("store_name", ""),
    }


def _post_dict(row: dict) -> dict:
    return {
        "id": str(row["id"]),
        "authorName": row["author_name"],
        "createdAt": row["created_at"],
        "content": row.get("content"),
        "imageUrls": [],
        "likeCount": row.get("like_count", 0),
        "commentCount": row.get("comment_count", 0),
        "isLiked": bool(row.get("is_liked", 0)),
    }


def _lesson_dict(row: dict) -> dict:
    return {
        "id": str(row["id"]),
        "title": row["title"],
        "thumbnailUrl": row.get("thumbnail_url", ""),
        "targetRole": row.get("target_role", "ALL"),
        "isRestricted": bool(row.get("is_restricted", 0)),
        "videoUrl": row.get("video_url"),
    }


# ---------------------------------------------------------------------------
# PERMISSIONS
# ---------------------------------------------------------------------------
@app.get("/api/permissions")
@login_required
def api_list_permissions():
    db = get_db()
    rows = db.execute("SELECT * FROM permissions ORDER BY id").fetchall()
    return jsonify([{
        "id": dict(r)["id"], "position": dict(r)["position"],
        "description": dict(r).get("description", ""),
        "canAttendance": bool(dict(r).get("can_attendance")),
        "canReport": bool(dict(r).get("can_report")),
        "canManageAttendance": bool(dict(r).get("can_manage_attendance")),
        "canEmployees": bool(dict(r).get("can_employees")),
        "canMore": bool(dict(r).get("can_more")),
        "canCrud": bool(dict(r).get("can_crud")),
        "canSwitchStore": bool(dict(r).get("can_switch_store")),
        "canStoreList": bool(dict(r).get("can_store_list")),
        "canProductList": bool(dict(r).get("can_product_list")),
    } for r in rows])


@app.get("/api/permissions/<position>")
@login_required
def api_get_permission(position: str):
    db = get_db()
    row = db.execute("SELECT * FROM permissions WHERE position = ?", (position,)).fetchone()
    if not row:
        return jsonify({"error": "Không tìm thấy quyền"}), 404
    r = dict(row)
    return jsonify({
        "position": r["position"], "description": r.get("description", ""),
        "canAttendance": bool(r.get("can_attendance")),
        "canReport": bool(r.get("can_report")),
        "canManageAttendance": bool(r.get("can_manage_attendance")),
        "canEmployees": bool(r.get("can_employees")),
        "canMore": bool(r.get("can_more")),
        "canCrud": bool(r.get("can_crud")),
        "canSwitchStore": bool(r.get("can_switch_store")),
        "canStoreList": bool(r.get("can_store_list")),
        "canProductList": bool(r.get("can_product_list")),
    })


# ---------------------------------------------------------------------------
# COURSES (LMS)
# ---------------------------------------------------------------------------
@app.get("/api/courses")
@login_required
def api_list_courses():
    db = get_db()
    rows = db.execute("SELECT * FROM course_titles ORDER BY id").fetchall()
    courses = []
    for r in rows:
        d = dict(r)
        contents = db.execute(
            "SELECT * FROM course_contents WHERE title_id = ?", (d["excel_id"],)
        ).fetchall()
        courses.append({
            "id": str(d["id"]), "excelId": d["excel_id"],
            "title": d["title"], "accessLevel": d.get("access_level"),
            "imageUrl": d.get("image_url"), "description": d.get("description"),
            "rating": d.get("rating"), "targetGroup": d.get("target_group"),
            "contents": [{
                "id": str(dict(c)["id"]), "excelId": dict(c)["excel_id"],
                "title": dict(c)["title"], "detailHtml": dict(c).get("detail_html"),
                "points": dict(c).get("points", 0),
                "attachmentType": dict(c).get("attachment_type"),
                "imageUrl": dict(c).get("image_url"),
                "videoUrl": dict(c).get("video_url"),
                "status": dict(c).get("status"),
            } for c in contents],
        })
    return jsonify(courses)


@app.get("/api/courses/<course_id>/enrollments")
@login_required
def api_course_enrollments(course_id: str):
    db = get_db()
    rows = db.execute(
        "SELECT * FROM course_enrollments WHERE title_id = ? ORDER BY enrolled_at DESC",
        (course_id,)
    ).fetchall()
    return jsonify([{
        "id": str(dict(r)["id"]), "employeeCode": dict(r)["employee_code"],
        "fullName": dict(r)["full_name"], "enrolledAt": dict(r)["enrolled_at"],
    } for r in rows])


@app.get("/api/courses/<course_id>/completions")
@login_required
def api_course_completions(course_id: str):
    db = get_db()
    rows = db.execute(
        "SELECT * FROM course_completions WHERE title_id = ? ORDER BY completed_at DESC",
        (course_id,)
    ).fetchall()
    return jsonify([{
        "id": str(dict(r)["id"]), "contentId": dict(r)["content_id"],
        "employeeCode": dict(r)["employee_code"], "fullName": dict(r)["full_name"],
        "completedAt": dict(r)["completed_at"], "points": dict(r).get("points", 0),
        "contentName": dict(r).get("content_name"),
    } for r in rows])


# ---------------------------------------------------------------------------
# QUIZ
# ---------------------------------------------------------------------------
@app.get("/api/quiz/<content_id>")
@login_required
def api_quiz_questions(content_id: str):
    db = get_db()
    rows = db.execute(
        "SELECT * FROM quiz_questions WHERE content_id = ? ORDER BY question_number",
        (content_id,)
    ).fetchall()
    return jsonify([{
        "id": dict(r)["id"], "type": dict(r)["question_type"],
        "question": dict(r)["question"],
        "options": [dict(r).get("option_a"), dict(r).get("option_b"),
                    dict(r).get("option_c"), dict(r).get("option_d")],
        "correctAnswer": dict(r).get("correct_answer"),
        "points": dict(r).get("points", 0),
    } for r in rows])


@app.get("/api/quiz-results")
@login_required
def api_quiz_results():
    content_id = request.args.get("contentId")
    employee_code = request.args.get("employeeCode")
    db = get_db()
    where, params = [], []
    if content_id:
        where.append("content_id = ?")
        params.append(content_id)
    if employee_code:
        where.append("employee_code = ?")
        params.append(employee_code)
    clause = "WHERE " + " AND ".join(where) if where else ""
    rows = db.execute(
        f"SELECT * FROM quiz_results {clause} ORDER BY submitted_at DESC", tuple(params)
    ).fetchall()
    return jsonify([{
        "id": dict(r)["id"], "submittedAt": dict(r)["submitted_at"],
        "employeeCode": dict(r)["employee_code"], "fullName": dict(r)["full_name"],
        "storeName": dict(r).get("store_name"), "score": dict(r)["score"],
        "answersJson": dict(r).get("answers_json"),
    } for r in rows])


# ---------------------------------------------------------------------------
# CLASS SCHEDULES
# ---------------------------------------------------------------------------
@app.get("/api/class-schedules")
@login_required
def api_list_class_schedules():
    db = get_db()
    rows = db.execute("SELECT * FROM class_schedules ORDER BY start_date DESC").fetchall()
    schedules = []
    for r in rows:
        d = dict(r)
        attendances = db.execute(
            "SELECT * FROM class_attendances WHERE schedule_id = ? ORDER BY attend_date, attend_time",
            (d["excel_id"],)
        ).fetchall()
        schedules.append({
            "id": str(d["id"]), "excelId": d["excel_id"],
            "startDate": d["start_date"], "startTime": d["start_time"],
            "endDate": d["end_date"], "endTime": d["end_time"],
            "content": d["content"], "link": d.get("link"),
            "attendanceCount": len(attendances),
            "attendances": [{
                "id": str(dict(a)["id"]),
                "employeeCode": dict(a)["employee_code"],
                "fullName": dict(a)["full_name"],
                "storeName": dict(a).get("store_name"),
                "action": dict(a)["action"],
                "time": dict(a).get("attend_time"),
                "date": dict(a).get("attend_date"),
            } for a in attendances],
        })
    return jsonify(schedules)


# ---------------------------------------------------------------------------
# AI TOOLS
# ---------------------------------------------------------------------------
@app.get("/api/ai-tools")
@login_required
def api_list_ai_tools():
    db = get_db()
    rows = db.execute("SELECT * FROM ai_tools ORDER BY id").fetchall()
    return jsonify([{
        "id": dict(r)["id"], "name": dict(r)["name"], "link": dict(r).get("link"),
    } for r in rows])


@app.get("/api/ai-usage")
@login_required
def api_ai_usage():
    employee_code = request.args.get("employeeCode")
    db = get_db()
    if employee_code:
        rows = db.execute(
            "SELECT * FROM ai_usage_logs WHERE employee_code = ? ORDER BY used_at DESC",
            (employee_code,)
        ).fetchall()
    else:
        rows = db.execute("SELECT * FROM ai_usage_logs ORDER BY used_at DESC LIMIT 100").fetchall()
    return jsonify([{
        "id": dict(r)["id"], "employeeCode": dict(r)["employee_code"],
        "fullName": dict(r)["full_name"], "storeName": dict(r).get("store_name"),
        "aiName": dict(r)["ai_name"], "usedAt": dict(r)["used_at"],
        "points": dict(r).get("points", 0),
    } for r in rows])


# ---------------------------------------------------------------------------
# COMMENTS
# ---------------------------------------------------------------------------
@app.get("/api/posts/<int:pid>/comments")
@login_required
def api_list_comments(pid: int):
    db = get_db()
    rows = db.execute(
        "SELECT * FROM comments WHERE post_id = ? ORDER BY created_at", (pid,)
    ).fetchall()
    return jsonify([{
        "id": str(dict(r)["id"]), "content": dict(r).get("content"),
        "authorName": dict(r).get("author_name", ""),
        "employeeCode": dict(r).get("employee_code"),
        "imageUrl": dict(r).get("image_url"),
        "videoUrl": dict(r).get("video_url"),
        "points": dict(r).get("points", 0),
        "likeCount": dict(r).get("like_count", 0),
        "createdAt": dict(r).get("created_at"),
    } for r in rows])


# ---------------------------------------------------------------------------
# COURSES (LMS)
# ---------------------------------------------------------------------------
@app.get("/api/courses")
@login_required
def api_list_courses():
    db = get_db()
    rows = db.execute("SELECT * FROM course_titles ORDER BY id").fetchall()
    courses = []
    for r in rows:
        d = dict(r)
        contents = db.execute(
            "SELECT * FROM course_contents WHERE title_id = ?", (d["excel_id"],)
        ).fetchall()
        courses.append({
            "id": str(d["id"]), "excelId": d["excel_id"],
            "title": d["title"], "accessLevel": d.get("access_level"),
            "imageUrl": d.get("image_url"), "description": d.get("description"),
            "rating": d.get("rating"), "targetGroup": d.get("target_group"),
            "contents": [{
                "id": str(dict(c)["id"]), "excelId": dict(c)["excel_id"],
                "title": dict(c)["title"], "detailHtml": dict(c).get("detail_html"),
                "points": dict(c).get("points", 0),
                "attachmentType": dict(c).get("attachment_type"),
                "imageUrl": dict(c).get("image_url"),
                "videoUrl": dict(c).get("video_url"),
                "status": dict(c).get("status"),
            } for c in contents],
        })
    return jsonify(courses)


@app.get("/api/courses/<course_id>/enrollments")
@login_required
def api_course_enrollments(course_id: str):
    db = get_db()
    rows = db.execute(
        "SELECT * FROM course_enrollments WHERE title_id = ? ORDER BY enrolled_at DESC",
        (course_id,)
    ).fetchall()
    return jsonify([{
        "id": str(dict(r)["id"]), "employeeCode": dict(r)["employee_code"],
        "fullName": dict(r)["full_name"], "enrolledAt": dict(r)["enrolled_at"],
    } for r in rows])


@app.get("/api/courses/<course_id>/completions")
@login_required
def api_course_completions(course_id: str):
    db = get_db()
    rows = db.execute(
        "SELECT * FROM course_completions WHERE title_id = ? ORDER BY completed_at DESC",
        (course_id,)
    ).fetchall()
    return jsonify([{
        "id": str(dict(r)["id"]), "contentId": dict(r)["content_id"],
        "employeeCode": dict(r)["employee_code"], "fullName": dict(r)["full_name"],
        "completedAt": dict(r)["completed_at"], "points": dict(r).get("points", 0),
        "contentName": dict(r).get("content_name"),
    } for r in rows])


# ---------------------------------------------------------------------------
# QUIZ
# ---------------------------------------------------------------------------
@app.get("/api/quiz/<content_id>")
@login_required
def api_quiz_questions(content_id: str):
    db = get_db()
    rows = db.execute(
        "SELECT * FROM quiz_questions WHERE content_id = ? ORDER BY question_number",
        (content_id,)
    ).fetchall()
    return jsonify([{
        "id": dict(r)["id"], "type": dict(r)["question_type"],
        "question": dict(r)["question"],
        "options": [dict(r).get("option_a"), dict(r).get("option_b"),
                    dict(r).get("option_c"), dict(r).get("option_d")],
        "correctAnswer": dict(r).get("correct_answer"),
        "points": dict(r).get("points", 0),
    } for r in rows])


@app.get("/api/quiz-results")
@login_required
def api_quiz_results():
    content_id = request.args.get("contentId")
    employee_code = request.args.get("employeeCode")
    db = get_db()
    where, params = [], []
    if content_id:
        where.append("content_id = ?")
        params.append(content_id)
    if employee_code:
        where.append("employee_code = ?")
        params.append(employee_code)
    clause = "WHERE " + " AND ".join(where) if where else ""
    rows = db.execute(
        f"SELECT * FROM quiz_results {clause} ORDER BY submitted_at DESC", tuple(params)
    ).fetchall()
    return jsonify([{
        "id": dict(r)["id"], "submittedAt": dict(r)["submitted_at"],
        "employeeCode": dict(r)["employee_code"], "fullName": dict(r)["full_name"],
        "storeName": dict(r).get("store_name"), "score": dict(r)["score"],
        "answersJson": dict(r).get("answers_json"),
    } for r in rows])


# ---------------------------------------------------------------------------
# CLASS SCHEDULES
# ---------------------------------------------------------------------------
@app.get("/api/class-schedules")
@login_required
def api_list_class_schedules():
    db = get_db()
    rows = db.execute("SELECT * FROM class_schedules ORDER BY start_date DESC").fetchall()
    schedules = []
    for r in rows:
        d = dict(r)
        attendances = db.execute(
            "SELECT * FROM class_attendances WHERE schedule_id = ? ORDER BY attend_date, attend_time",
            (d["excel_id"],)
        ).fetchall()
        schedules.append({
            "id": str(d["id"]), "excelId": d["excel_id"],
            "startDate": d["start_date"], "startTime": d["start_time"],
            "endDate": d["end_date"], "endTime": d["end_time"],
            "content": d["content"], "link": d.get("link"),
            "attendanceCount": len(attendances),
            "attendances": [{
                "id": str(dict(a)["id"]),
                "employeeCode": dict(a)["employee_code"],
                "fullName": dict(a)["full_name"],
                "storeName": dict(a).get("store_name"),
                "action": dict(a)["action"],
                "time": dict(a).get("attend_time"),
                "date": dict(a).get("attend_date"),
            } for a in attendances],
        })
    return jsonify(schedules)


# ---------------------------------------------------------------------------
# AI TOOLS
# ---------------------------------------------------------------------------
@app.get("/api/ai-tools")
@login_required
def api_list_ai_tools():
    db = get_db()
    rows = db.execute("SELECT * FROM ai_tools ORDER BY id").fetchall()
    return jsonify([{
        "id": dict(r)["id"], "name": dict(r)["name"], "link": dict(r).get("link"),
    } for r in rows])


@app.get("/api/ai-usage")
@login_required
def api_ai_usage():
    employee_code = request.args.get("employeeCode")
    db = get_db()
    if employee_code:
        rows = db.execute(
            "SELECT * FROM ai_usage_logs WHERE employee_code = ? ORDER BY used_at DESC",
            (employee_code,)
        ).fetchall()
    else:
        rows = db.execute("SELECT * FROM ai_usage_logs ORDER BY used_at DESC LIMIT 100").fetchall()
    return jsonify([{
        "id": dict(r)["id"], "employeeCode": dict(r)["employee_code"],
        "fullName": dict(r)["full_name"], "storeName": dict(r).get("store_name"),
        "aiName": dict(r)["ai_name"], "usedAt": dict(r)["used_at"],
        "points": dict(r).get("points", 0),
    } for r in rows])


# ---------------------------------------------------------------------------
# COMMENTS
# ---------------------------------------------------------------------------
@app.get("/api/posts/<int:pid>/comments")
@login_required
def api_list_comments(pid: int):
    db = get_db()
    rows = db.execute(
        "SELECT * FROM comments WHERE post_id = ? ORDER BY created_at", (pid,)
    ).fetchall()
    return jsonify([{
        "id": str(dict(r)["id"]), "content": dict(r).get("content"),
        "authorName": dict(r).get("author_name", ""),
        "employeeCode": dict(r).get("employee_code"),
        "imageUrl": dict(r).get("image_url"),
        "videoUrl": dict(r).get("video_url"),
        "points": dict(r).get("points", 0),
        "likeCount": dict(r).get("like_count", 0),
        "createdAt": dict(r).get("created_at"),
    } for r in rows])


# ---------------------------------------------------------------------------
# CORS (allow Flutter web)
# ---------------------------------------------------------------------------
@app.after_request
def add_cors(response):
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
    return response


@app.route("/api/<path:path>", methods=["OPTIONS"])
def options_handler(path):
    return "", 204


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "5000")), debug=True)
