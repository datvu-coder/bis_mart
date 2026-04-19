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
            "INSERT INTO employees (full_name, employee_code, position, work_location, score, email) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            (data["fullName"], data["employeeCode"], data["position"],
             data.get("workLocation", ""), data.get("score", 0), data.get("email")),
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
                     ("score", "score"), ("email", "email")]:
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
            "INSERT INTO stores (name, store_code, store_group, latitude, longitude) "
            "VALUES (?, ?, ?, ?, ?)",
            (data["name"], data["storeCode"], data.get("group", "I"),
             data.get("latitude"), data.get("longitude")),
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
                     ("longitude", "longitude")]:
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
        "INSERT INTO sales_reports (report_date, pg_name, nu, revenue_n1, revenue, created_by) "
        "VALUES (?, ?, ?, ?, ?, ?)",
        (data.get("date", datetime.now(tz=VN_TZ).strftime("%Y-%m-%d")),
         data.get("pgName", ""), data.get("nu", 0),
         data.get("revenueN1", 0), data.get("revenue", 0), user_id),
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
    # Check if already seeded
    row = db.execute("SELECT COUNT(*) AS cnt FROM users").fetchone()
    if dict(row)["cnt"] > 0:
        return

    # Seed employees
    employees = [
        ("Nguyễn Văn A", "0002601020", "MNG", "Head Office", 1000, "admin@bismart.vn"),
        ("Nguyễn Thị Lan", "0002601001", "PG", "Bi'S MART Sa Đéc", 960, "lan@bismart.vn"),
        ("Trần Văn Minh", "0002601002", "PG", "Bi'S MART Đồng Thánh", 920, "minh@bismart.vn"),
        ("Lê Thị Hương", "0002601003", "ADM", "Bi'S MART Long Hựu", 880, "huong@bismart.vn"),
        ("Phạm Đức Anh", "0002601004", "TLD", "Bi'S MART Phước Vân", 840, "anh@bismart.vn"),
        ("Võ Thị Mai", "0002601005", "PG", "Bi'S MART Cầu Tràm", 800, "mai@bismart.vn"),
        ("Hoàng Văn Tùng", "0002601006", "PG", "Bi'S MART Cần Đước", 760, "tung@bismart.vn"),
        ("Đặng Thị Ngọc", "0002601007", "ADM", "Bi'S MART Phước Lại", 720, "ngoc@bismart.vn"),
        ("Bùi Quang Hải", "0002601008", "PG", "Bi'S MART Cần Giuộc", 680, "hai@bismart.vn"),
        ("Ngô Thị Thanh", "0002601009", "PG", "Bi'S MART Hiệp Phước", 640, "thanh@bismart.vn"),
        ("Trịnh Văn Long", "0002601010", "TLD", "Bi'S MART Tân Tập", 600, "long@bismart.vn"),
        ("Phan Thị Yến", "0002601011", "PG", "Bi'S MART Hưng Long", 560, "yen@bismart.vn"),
        ("Lý Văn Đức", "0002601012", "CS", "Bi'S MART Phước Kiến", 520, "duc@bismart.vn"),
        ("Hồ Thị Kim", "0002601013", "PG", "Bi'S MART Sa Đéc", 480, "kim@bismart.vn"),
        ("Dương Văn Nam", "0002601014", "PG", "Bi'S MART Đồng Thánh", 440, "nam@bismart.vn"),
        ("Cao Thị Linh", "0002601015", "ADM", "Head Office", 400, "linh@bismart.vn"),
        ("Đinh Văn Phúc", "0002601016", "PG", "Bi'S MART Long Hựu", 360, "phuc@bismart.vn"),
        ("Tô Thị Hà", "0002601017", "PG", "Bi'S MART Phước Vân", 320, "ha@bismart.vn"),
        ("Vũ Văn Sơn", "0002601018", "TLD", "Head Office", 280, "son@bismart.vn"),
        ("Mai Thị Dung", "0002601019", "PG", "Bi'S MART Cầu Tràm", 240, "dung@bismart.vn"),
    ]
    for emp in employees:
        db.execute(
            "INSERT INTO employees (full_name, employee_code, position, work_location, score, email) "
            "VALUES (?, ?, ?, ?, ?, ?)", emp
        )

    # Seed admin user (password: admin123)
    admin_username = os.getenv("SEED_ADMIN_USERNAME", "admin")
    admin_password = os.getenv("SEED_ADMIN_PASSWORD", "admin123")
    db.execute(
        "INSERT INTO users (username, password_hash, employee_id) VALUES (?, ?, 1)",
        (admin_username, generate_password_hash(admin_password, method="pbkdf2:sha256")),
    )

    # Seed stores
    stores = [
        ("Bi'S MART Sa Đéc", "101", "I", 10.2898, 105.7558),
        ("Bi'S MART Đồng Thánh", "102", "I", 10.3500, 106.4500),
        ("Bi'S MART Long Hựu", "103", "I", None, None),
        ("Bi'S MART Phước Vân", "104", "I", None, None),
        ("Bi'S MART Cầu Tràm", "105", "I", None, None),
        ("Bi'S MART Cần Đước", "106", "I", None, None),
        ("Bi'S MART Phước Lại", "107", "I", None, None),
        ("Bi'S MART Cần Giuộc", "108", "I", None, None),
        ("Bi'S MART Hiệp Phước", "109", "I", None, None),
        ("Bi'S MART Tân Tập", "110", "I", None, None),
        ("Bi'S MART Hưng Long", "111", "I", None, None),
        ("Bi'S MART Phước Kiến", "112", "I", None, None),
        ("Head Office", "000", "HO", None, None),
        ("Chủ Shop", "CS", "CS", None, None),
    ]
    for s in stores:
        db.execute(
            "INSERT INTO stores (name, store_code, store_group, latitude, longitude) "
            "VALUES (?, ?, ?, ?, ?)", s
        )

    # Seed products
    products = [
        ("SPDD CÔNG THỨC DELIMIL PRO+", "Lon", 450000, "DELI"),
        ("SPDD DELIVIE SMART", "Lon", 420000, "DELI"),
        ("SPDD DELIVIE PEDIA GAIN", "Lon", 398000, "DELI"),
        ("TPBS DELIVIE GLUSURE", "Lon", 520000, "DELIMIL"),
        ("TPBS DELIVIE CANXI NANO", "Hộp", 380000, "DELIMIL"),
        ("SPDD CÔNG THỨC DELIMIL PRO+ 400G", "Lon", 285000, "DELIMIL"),
        ("TPBS AUMIL AVI SURE 750G", "Lon", 668000, "AUMIL"),
        ("TPBS AUMIL AVI MOM 750G", "Lon", 678000, "AUMIL"),
        ("GOODLIFE CANXI PL", "Hộp", 350000, "GOODLIFE"),
        ("TP DÙNG CHO CHẾ ĐỘ", "Gói", 150000, "TP"),
    ]
    for p in products:
        db.execute(
            "INSERT INTO products (name, unit, price_with_vat, product_group) "
            "VALUES (?, ?, ?, ?)", p
        )

    # Seed work shifts
    shifts = [
        ("Ca gãy sáng", 7, 30, 11, 30),
        ("Ca gãy chiều", 17, 0, 21, 0),
        ("Ca ngày", 11, 0, 19, 0),
        ("Ca sáng", 8, 30, 12, 30),
        ("Ca chiều", 15, 0, 19, 0),
    ]
    for s in shifts:
        db.execute(
            "INSERT INTO work_shifts (name, start_hour, start_minute, end_hour, end_minute) "
            "VALUES (?, ?, ?, ?, ?)", s
        )

    # Seed community posts
    posts = [
        ("Nguyễn Thị Lan", "Hôm nay đạt target doanh số! 🎉 Cảm ơn cả team đã hỗ trợ.", 12, 5),
        ("Trần Văn Minh", "Chia sẻ tips bán hàng sữa DELIMIL PRO+ hiệu quả...", 8, 3),
        ("Lê Thị Hương", "Chương trình khuyến mãi mới cho GOODLIFE CANXI bắt đầu từ tuần sau!", 15, 7),
    ]
    for p in posts:
        db.execute(
            "INSERT INTO community_posts (author_name, content, like_count, comment_count) "
            "VALUES (?, ?, ?, ?)", p
        )

    # Seed lessons
    lessons_data = [
        ("Kiến thức sản phẩm DELIMIL PRO+", "", "PG", 0),
        ("Kỹ năng bán hàng nâng cao", "", "ALL", 0),
        ("Quản lý cửa hàng hiệu quả", "", "ADM", 1),
        ("Chăm sóc khách hàng chuyên nghiệp", "", "ALL", 0),
    ]
    for l in lessons_data:
        db.execute(
            "INSERT INTO lessons (title, thumbnail_url, target_role, is_restricted) "
            "VALUES (?, ?, ?, ?)", l
        )

    # Seed sample sales reports
    for i in range(5):
        d = (now - timedelta(days=i)).strftime("%Y-%m-%d")
        db.execute(
            "INSERT INTO sales_reports (report_date, pg_name, nu, revenue_n1, revenue, created_by) "
            "VALUES (?, ?, ?, ?, ?, 1)",
            (d, f"PG {i+1}", 3 + i, 2000000 + i * 500000, 3500000 + i * 700000),
        )

    for rid in range(1, 6):
        db.execute(
            "INSERT INTO sale_items (report_id, product_name, quantity, unit_price) "
            "VALUES (?, 'DELIMIL PRO+', ?, 450000)",
            (rid, 2 + rid - 1),
        )
        db.execute(
            "INSERT INTO sale_items (report_id, product_name, quantity, unit_price) "
            "VALUES (?, 'GOODLIFE CANXI', ?, 380000)",
            (rid, 1 + rid - 1),
        )

    # Seed training events
    for day_offset, titles in [(1, ["Đào tạo PG mới"]),
                               (3, ["Họp nhóm bán hàng", "Kiểm tra sản phẩm"]),
                               (5, ["Workshop kỹ năng bán hàng"]),
                               (7, ["Đánh giá tháng"])]:
        d = (now + timedelta(days=day_offset)).strftime("%Y-%m-%d")
        for t in titles:
            db.execute(
                "INSERT INTO training_events (event_date, title) VALUES (?, ?)", (d, t)
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
        "position": row.get("position", ""),
        "workLocation": row.get("work_location", ""),
        "score": row.get("score", 0),
        "rank": row.get("rank", 0),
        "email": row.get("email"),
    }


def _store_dict(row: dict) -> dict:
    return {
        "id": str(row["id"]),
        "name": row["name"],
        "storeCode": row["store_code"],
        "group": row["store_group"],
        "latitude": row.get("latitude"),
        "longitude": row.get("longitude"),
        "managers": [],
    }


def _product_dict(row: dict) -> dict:
    return {
        "id": str(row["id"]),
        "name": row["name"],
        "unit": row["unit"],
        "priceWithVAT": row["price_with_vat"],
        "productGroup": row["product_group"],
    }


def _report_dict(row: dict) -> dict:
    return {
        "id": str(row["id"]),
        "date": row["report_date"],
        "pgName": row["pg_name"],
        "nu": row["nu"],
        "revenueN1": row["revenue_n1"],
        "revenue": row["revenue"],
        "products": [],
    }


def _sale_item_dict(row: dict) -> dict:
    return {
        "productId": str(row.get("product_id") or ""),
        "productName": row["product_name"],
        "quantity": row["quantity"],
        "unitPrice": row["unit_price"],
    }


def _attendance_dict(row: dict) -> dict:
    return {
        "id": str(row["id"]),
        "date": row["attend_date"],
        "employeeId": str(row["employee_id"]),
        "isCheckedIn": row.get("check_in_time") is not None,
        "checkInTime": row.get("check_in_time"),
        "checkOutTime": row.get("check_out_time"),
    }


def _shift_dict(row: dict) -> dict:
    return {
        "id": str(row["id"]),
        "name": row["name"],
        "startHour": row["start_hour"],
        "startMinute": row["start_minute"],
        "endHour": row["end_hour"],
        "endMinute": row["end_minute"],
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
