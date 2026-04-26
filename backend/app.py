"""
Bismart Backend - PostgreSQL only (no SQLite fallback).
CRITICAL FIX: All lastrowid issues replaced with atomic RETURNING clauses.
Fixes data loss bug where báo cáo & chấm công disappeared after creation.
"""
from __future__ import annotations

import json
import math
import mimetypes
import os
import uuid
from datetime import datetime, timedelta, timezone
from functools import wraps
from pathlib import Path
from typing import Any

import jwt
import psycopg
from psycopg.rows import dict_row
from flask import Flask, Response, g, jsonify, request, stream_with_context
from werkzeug.security import check_password_hash, generate_password_hash
from werkzeug.utils import secure_filename

# PostgreSQL ONLY - no SQLite fallback
BASE_DIR = Path(__file__).resolve().parent
DATABASE_URL = os.getenv("DATABASE_URL", "").strip()
if not DATABASE_URL:
    raise ValueError("DATABASE_URL required - PostgreSQL only backend")

DB_READY = False
VN_TZ = timezone(timedelta(hours=7))
JWT_SECRET = os.getenv("SECRET_KEY", "bismart-dev-secret-key")
JWT_EXP_HOURS = 72
LESSON_VIDEO_DIR = Path(os.getenv("LESSON_VIDEO_DIR", "/data/lesson_videos"))
try:
    LESSON_VIDEO_DIR.mkdir(parents=True, exist_ok=True)
except Exception:
    LESSON_VIDEO_DIR = Path(os.getenv("BASE_DIR", ".")) / "lesson_videos"
    LESSON_VIDEO_DIR.mkdir(parents=True, exist_ok=True)
POST_VIDEO_DIR = Path(os.getenv("POST_VIDEO_DIR", "/data/post_videos"))
try:
    POST_VIDEO_DIR.mkdir(parents=True, exist_ok=True)
except Exception:
    POST_VIDEO_DIR = Path(os.getenv("BASE_DIR", ".")) / "post_videos"
    POST_VIDEO_DIR.mkdir(parents=True, exist_ok=True)
MAX_VIDEO_BYTES = int(os.getenv("MAX_VIDEO_BYTES", str(1024 * 1024 * 1024)))  # 1GB
ALLOWED_VIDEO_EXT = {".mp4", ".webm", ".mov", ".m4v"}
CORS_ALLOW_HEADERS = "Content-Type, Authorization"
CORS_ALLOW_METHODS = "GET, POST, PUT, DELETE, OPTIONS"
app = Flask(__name__)
app.config["SECRET_KEY"] = JWT_SECRET
app.config["MAX_CONTENT_LENGTH"] = MAX_VIDEO_BYTES + (5 * 1024 * 1024)
DBIntegrityError = psycopg.IntegrityError

def get_db():
    if "db" not in g:
        g.db = psycopg.connect(DATABASE_URL, row_factory=dict_row, autocommit=False)
    return g.db

@app.teardown_appcontext
def close_db(_exc=None):
    db = g.pop("db", None)
    if db:
        db.close()

def ensure_database_ready():
    global DB_READY
    if DB_READY:
        return
    db = get_db()
    schema_sql = (BASE_DIR / "schema_postgres.sql").read_text(encoding="utf-8")
    with db.cursor() as cur:
        cur.execute(schema_sql)
    db.commit()
    DB_READY = True

@app.before_request
def _before_request():
    if request.method == "OPTIONS":
        return ("", 204)
    ensure_database_ready()


@app.after_request
def _add_cors_headers(response):
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Headers"] = CORS_ALLOW_HEADERS
    response.headers["Access-Control-Allow-Methods"] = CORS_ALLOW_METHODS
    return response

def create_token(user_id, employee_id):
    return jwt.encode({
        "user_id": user_id,
        "employee_id": employee_id,
        "exp": datetime.now(tz=VN_TZ) + timedelta(hours=JWT_EXP_HOURS)
    }, JWT_SECRET, algorithm="HS256")

def get_current_user():
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return None
    try:
        return jwt.decode(auth[7:], JWT_SECRET, algorithms=["HS256"])
    except Exception:
        return None

def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        g.current_user = get_current_user()
        if not g.current_user:
            return jsonify({"error": "Unauthorized"}), 401
        return f(*args, **kwargs)
    return decorated


def _user_to_api_json(user_row: dict[str, Any]) -> dict[str, Any]:
    employee_id = user_row.get("employee_id") or user_row.get("auth_employee_id") or user_row.get("id") or user_row.get("user_id")
    username = user_row.get("username") or "admin"
    return {
        "id": str(employee_id or user_row.get("user_id") or "0"),
        "fullName": user_row.get("full_name") or username.upper(),
        "employeeCode": user_row.get("employee_code") or username,
        "position": user_row.get("position") or "ADM",
        "workLocation": user_row.get("work_location") or "",
        "score": int(user_row.get("score") or 0),
        "rank": int(user_row.get("rank") or 0),
        "email": user_row.get("email"),
        "phone": user_row.get("phone"),
        "dateOfBirth": user_row.get("date_of_birth"),
        "cccd": user_row.get("cccd"),
        "address": user_row.get("address"),
        "status": user_row.get("status"),
        "department": user_row.get("department"),
        "province": user_row.get("province"),
        "area": user_row.get("area"),
        "createdDate": user_row.get("created_date"),
        "probationDate": user_row.get("probation_date"),
        "officialDate": user_row.get("official_date"),
        "resignDate": user_row.get("resign_date"),
        "resignReason": user_row.get("resign_reason"),
        "avatarUrl": user_row.get("avatar_url"),
        "storeCode": user_row.get("store_code"),
        "rankLevel": user_row.get("rank_level"),
    }


def _report_to_api_json(report_row: dict[str, Any], products: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "id": str(report_row["id"]),
        "date": report_row.get("report_date") or datetime.now(tz=VN_TZ).strftime("%Y-%m-%d"),
        "pgName": report_row.get("pg_name") or "",
        "nu": int(report_row.get("nu") or 0),
        "saleOut": float(report_row.get("sale_out") or 0),
        "products": [
            {
                "productId": str(item.get("product_id") or ""),
                "productName": item.get("product_name") or "",
                "quantity": int(item.get("quantity") or 0),
                "unitPrice": float(item.get("unit_price") or 0),
                "unit": item.get("unit"),
                "productGroup": item.get("product_group"),
            }
            for item in products
        ],
        "revenue": float(report_row.get("revenue") or 0),
        "storeName": report_row.get("store_name"),
        "storeCode": report_row.get("store_code"),
        "reportMonth": str(report_row.get("report_month")) if report_row.get("report_month") is not None else None,
        "points": int(report_row.get("points") or 0),
        "employeeCode": report_row.get("employee_code"),
    }


def _product_to_api_json(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": str(row.get("id") or ""),
        "name": row.get("name") or "",
        "unit": row.get("unit") or "",
        "priceWithVAT": float(row.get("price_with_vat") or 0),
        "productGroup": row.get("product_group") or "DELI",
        "productCondition": row.get("product_condition"),
    }


def _store_to_api_json(row: dict[str, Any], managers: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "id": str(row.get("id") or ""),
        "name": row.get("name") or "",
        "group": row.get("store_group") or "I",
        "storeCode": row.get("store_code") or "",
        "managers": managers,
        "latitude": row.get("latitude"),
        "longitude": row.get("longitude"),
        "province": row.get("province"),
        "sup": row.get("sup"),
        "status": row.get("status"),
        "openDate": row.get("open_date"),
        "closeDate": row.get("close_date"),
        "storeType": row.get("store_type"),
        "address": row.get("address"),
        "phone": row.get("phone"),
        "owner": row.get("owner"),
        "taxCode": row.get("tax_code"),
    }


def _employee_to_api_json(row: dict[str, Any], rank: int = 0) -> dict[str, Any]:
    return {
        "id": str(row.get("id") or ""),
        "fullName": row.get("full_name") or "",
        "employeeCode": row.get("employee_code") or "",
        "position": row.get("position") or "PG",
        "workLocation": row.get("work_location") or "",
        "score": int(row.get("score") or 0),
        "rank": rank,
        "email": row.get("email"),
        "phone": row.get("phone"),
        "dateOfBirth": row.get("date_of_birth"),
        "cccd": row.get("cccd"),
        "address": row.get("address"),
        "status": row.get("status"),
        "department": row.get("department"),
        "province": row.get("province"),
        "area": row.get("area"),
        "createdDate": row.get("created_date"),
        "probationDate": row.get("probation_date"),
        "officialDate": row.get("official_date"),
        "resignDate": row.get("resign_date"),
        "resignReason": row.get("resign_reason"),
        "avatarUrl": row.get("avatar_url"),
        "storeCode": row.get("store_code"),
        "rankLevel": row.get("rank_level"),
    }


def _normalize_store_code(value: Any) -> str | None:
    if value is None:
        return None
    code = str(value).strip().upper()
    return code or None


def _get_store_info_by_code(db, store_code: str | None) -> tuple[str | None, str | None]:
    code = _normalize_store_code(store_code)
    if not code:
        return None, None
    with db.cursor() as cur:
        cur.execute(
            "SELECT store_code, name FROM stores WHERE UPPER(store_code) = UPPER(%s) LIMIT 1",
            (code,),
        )
        row = cur.fetchone()
    if not row:
        return code, None
    return (row.get("store_code") or code), (row.get("name") or None)


def _derive_work_location(store_name: str | None, fallback: Any) -> str:
    if store_name and str(store_name).strip():
        return str(store_name).strip()
    return str(fallback or "").strip()


def _permission_to_api_json(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": int(row.get("id") or 0),
        "position": row.get("position") or "PG",
        "description": row.get("description"),
        "canAttendance": bool(row.get("can_attendance")),
        "canReport": bool(row.get("can_report")),
        "canManageAttendance": bool(row.get("can_manage_attendance")),
        "canEmployees": bool(row.get("can_employees")),
        "canMore": bool(row.get("can_more")),
        "canCrud": bool(row.get("can_crud")),
        "canSwitchStore": bool(row.get("can_switch_store")),
        "canStoreList": bool(row.get("can_store_list")),
        "canProductList": bool(row.get("can_product_list")),
    }


def _default_permission_for_position(position: str) -> dict[str, Any]:
    pos = (position or "").upper()
    is_manager = pos in {"ADM", "MNG", "CS"}
    return {
        "id": 0,
        "position": pos or "PG",
        "description": "Default permission",
        "canAttendance": True,
        "canReport": True,
        "canManageAttendance": is_manager,
        "canEmployees": True,
        "canMore": True,
        "canCrud": is_manager,
        "canSwitchStore": True,
        "canStoreList": True,
        "canProductList": True,
    }


def _dashboard_bounds(filter_type: str, now: datetime) -> tuple[str | None, str | None, list[str]]:
    today = now.strftime("%Y-%m-%d")
    if filter_type == "today":
        return today, today, [today]

    if filter_type == "week":
        days = [(now - timedelta(days=i)).strftime("%Y-%m-%d") for i in range(6, -1, -1)]
        return days[0], days[-1], days

    if filter_type == "month":
        month_start_dt = now.replace(day=1)
        day_count = (now - month_start_dt).days + 1
        days = [(month_start_dt + timedelta(days=i)).strftime("%Y-%m-%d") for i in range(day_count)]
        return days[0], days[-1], days

    # all
    days = [(now - timedelta(days=i)).strftime("%Y-%m-%d") for i in range(29, -1, -1)]
    return days[0], days[-1], days


def _normalize_report_date(value: Any) -> str:
    if isinstance(value, datetime):
        return value.strftime("%Y-%m-%d")
    text = str(value or "").strip()
    if not text:
        return datetime.now(tz=VN_TZ).strftime("%Y-%m-%d")
    if "T" in text:
        text = text.split("T", 1)[0]
    if " " in text:
        text = text.split(" ", 1)[0]
    return text[:10]

@app.post("/api/auth/login")
def api_login():
    data = request.get_json(silent=True) or {}
    username = data.get("username", "").strip()
    password = data.get("password", "").strip()
    if not username or not password:
        return jsonify({"error": "Missing credentials"}), 400

    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT u.id as user_id, u.username, u.employee_id as auth_employee_id, u.password_hash, e.* FROM users u "
            "LEFT JOIN employees e ON u.employee_id = e.id "
            "WHERE u.username = %s", (username,)
        )
        user_row = cur.fetchone()

    # If no users-table record exists yet, auto-provision one for any matching
    # employees.employee_code where the provided password equals the employee
    # code itself (default first-time password). Subsequent logins go through
    # the regular hash check above. This lets every imported employee log in
    # without an admin manually creating a user row each time.
    if not user_row:
        with db.cursor() as cur:
            cur.execute(
                "SELECT * FROM employees WHERE employee_code = %s LIMIT 1",
                (username,),
            )
            emp = cur.fetchone()
        if emp and password == username:
            new_hash = generate_password_hash(password, method="pbkdf2:sha256")
            with db.cursor() as cur:
                cur.execute(
                    "INSERT INTO users (username, password_hash, employee_id) "
                    "VALUES (%s, %s, %s) "
                    "ON CONFLICT (username) DO NOTHING "
                    "RETURNING id",
                    (username, new_hash, emp["id"]),
                )
                inserted = cur.fetchone()
            db.commit()
            if inserted:
                with db.cursor() as cur:
                    cur.execute(
                        "SELECT u.id as user_id, u.username, "
                        "u.employee_id as auth_employee_id, u.password_hash, e.* "
                        "FROM users u LEFT JOIN employees e ON u.employee_id = e.id "
                        "WHERE u.id = %s",
                        (inserted["id"],),
                    )
                    user_row = cur.fetchone()

    if not user_row or not check_password_hash(user_row["password_hash"], password):
        return jsonify({"error": "Invalid credentials"}), 401

    token = create_token(user_row["user_id"], user_row.get("auth_employee_id"))
    return jsonify({"token": token, "user": _user_to_api_json(user_row)})


@app.get("/api/auth/me")
@login_required
def api_auth_me():
    current_user = g.current_user or {}
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT u.id as user_id, u.username, u.employee_id as auth_employee_id, e.* FROM users u "
            "LEFT JOIN employees e ON u.employee_id = e.id "
            "WHERE u.id = %s",
            (current_user.get("user_id"),),
        )
        user_row = cur.fetchone()

    if not user_row:
        return jsonify({"error": "Unauthorized"}), 401

    return jsonify({"user": _user_to_api_json(user_row)})


@app.get("/api/dashboard")
@login_required
def api_dashboard():
    filter_type = (request.args.get("filter") or "today").strip().lower()
    now = datetime.now(tz=VN_TZ)
    start_date, end_date, date_keys = _dashboard_bounds(filter_type, now)

    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT COALESCE(SUM(revenue), 0) AS total_revenue "
            "FROM sales_reports WHERE LEFT(report_date, 10) >= %s AND LEFT(report_date, 10) <= %s",
            (start_date, end_date),
        )
        total_revenue = float((cur.fetchone() or {}).get("total_revenue") or 0)

        cur.execute(
            "SELECT COALESCE(SUM(revenue), 0) AS group_revenue "
            "FROM sales_reports WHERE LEFT(report_date, 10) >= %s AND LEFT(report_date, 10) <= %s",
            (start_date, end_date),
        )
        group_revenue = float((cur.fetchone() or {}).get("group_revenue") or 0)

        cur.execute(
            "SELECT LEFT(report_date, 10) AS report_date, COALESCE(SUM(revenue), 0) AS revenue "
            "FROM sales_reports WHERE LEFT(report_date, 10) >= %s AND LEFT(report_date, 10) <= %s "
            "GROUP BY LEFT(report_date, 10) ORDER BY LEFT(report_date, 10) ASC",
            (start_date, end_date),
        )
        revenue_rows = cur.fetchall()

        cur.execute(
            "SELECT COALESCE(si.product_name, 'Khác') AS product_name, COALESCE(SUM(si.quantity), 0) AS qty "
            "FROM sale_items si "
            "JOIN sales_reports sr ON sr.id = si.report_id "
            "WHERE LEFT(sr.report_date, 10) >= %s AND LEFT(sr.report_date, 10) <= %s "
            "GROUP BY COALESCE(si.product_name, 'Khác') "
            "ORDER BY qty DESC, product_name ASC LIMIT 10",
            (start_date, end_date),
        )
        product_rows = cur.fetchall()

        cur.execute(
            "SELECT COALESCE(full_name, employee_code, 'Nhân viên') AS name "
            "FROM employees ORDER BY score DESC, id ASC LIMIT 10"
        )
        top_rows = cur.fetchall()

    revenue_map = {str(row.get("report_date")): float(row.get("revenue") or 0) for row in revenue_rows}
    revenue_chart = [
        {
            "date": date_str,
            "revenue": revenue_map.get(date_str, 0),
            "target": 0,
        }
        for date_str in date_keys
    ]

    top10 = [
        {"rank": idx + 1, "name": row.get("name") or f"Nhân viên {idx + 1}"}
        for idx, row in enumerate(top_rows)
    ]

    product_chart = [
        {
            "productName": row.get("product_name") or "Khác",
            "quantity": int(row.get("qty") or 0),
        }
        for row in product_rows
    ]

    return jsonify(
        {
            "date": now.strftime("%Y-%m-%d"),
            "announcement": "Dữ liệu tổng quan đã được đồng bộ.",
            "featuredPrograms": [
                "Bám mục tiêu doanh số theo ngày",
                "Đẩy mạnh sản phẩm chủ lực tuần này",
                "Theo dõi hiệu suất nhân sự tại cửa hàng",
            ],
            "top10": top10,
            "groupRevenue": group_revenue,
            "totalRevenue": total_revenue,
            "revenueChart": revenue_chart,
            "productChart": product_chart,
        }
    )


@app.get("/api/permissions")
@login_required
def api_get_permissions():
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT id, position, description, can_attendance, can_report, can_manage_attendance, can_employees, can_more, can_crud, can_switch_store, can_store_list, can_product_list "
            "FROM permissions ORDER BY id ASC"
        )
        rows = cur.fetchall()
    return jsonify([_permission_to_api_json(row) for row in rows])


@app.get("/api/permissions/<position>")
@login_required
def api_get_permission_by_position(position: str):
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT id, position, description, can_attendance, can_report, can_manage_attendance, can_employees, can_more, can_crud, can_switch_store, can_store_list, can_product_list "
            "FROM permissions WHERE UPPER(position) = UPPER(%s) LIMIT 1",
            (position,),
        )
        row = cur.fetchone()
    if not row:
        return jsonify(_default_permission_for_position(position))
    return jsonify(_permission_to_api_json(row))


@app.post("/api/permissions")
@login_required
def api_create_permission():
    data = request.get_json(silent=True) or {}
    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute(
                "INSERT INTO permissions (position, description, can_attendance, can_report, "
                "can_manage_attendance, can_employees, can_more, can_crud, can_switch_store, "
                "can_store_list, can_product_list) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s) "
                "RETURNING id, position, description, can_attendance, can_report, "
                "can_manage_attendance, can_employees, can_more, can_crud, can_switch_store, "
                "can_store_list, can_product_list",
                (
                    (data.get("position") or "").upper(),
                    data.get("description"),
                    int(bool(data.get("canAttendance", False))),
                    int(bool(data.get("canReport", False))),
                    int(bool(data.get("canManageAttendance", False))),
                    int(bool(data.get("canEmployees", False))),
                    int(bool(data.get("canMore", False))),
                    int(bool(data.get("canCrud", False))),
                    int(bool(data.get("canSwitchStore", False))),
                    int(bool(data.get("canStoreList", False))),
                    int(bool(data.get("canProductList", False))),
                ),
            )
            row = cur.fetchone()
        db.commit()
        return jsonify(_permission_to_api_json(row)), 201
    except Exception as e:
        db.rollback()
        return jsonify({"error": str(e)}), 400


@app.put("/api/permissions/<position>")
@login_required
def api_update_permission(position: str):
    data = request.get_json(silent=True) or {}
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "UPDATE permissions SET description = %s, can_attendance = %s, can_report = %s, "
            "can_manage_attendance = %s, can_employees = %s, can_more = %s, can_crud = %s, "
            "can_switch_store = %s, can_store_list = %s, can_product_list = %s "
            "WHERE UPPER(position) = UPPER(%s) "
            "RETURNING id, position, description, can_attendance, can_report, "
            "can_manage_attendance, can_employees, can_more, can_crud, can_switch_store, "
            "can_store_list, can_product_list",
            (
                data.get("description"),
                int(bool(data.get("canAttendance", False))),
                int(bool(data.get("canReport", False))),
                int(bool(data.get("canManageAttendance", False))),
                int(bool(data.get("canEmployees", False))),
                int(bool(data.get("canMore", False))),
                int(bool(data.get("canCrud", False))),
                int(bool(data.get("canSwitchStore", False))),
                int(bool(data.get("canStoreList", False))),
                int(bool(data.get("canProductList", False))),
                position,
            ),
        )
        row = cur.fetchone()
    db.commit()
    if not row:
        return jsonify({"error": "Position not found"}), 404
    return jsonify(_permission_to_api_json(row))


@app.delete("/api/permissions/<position>")
@login_required
def api_delete_permission(position: str):
    db = get_db()
    with db.cursor() as cur:
        cur.execute("DELETE FROM permissions WHERE UPPER(position) = UPPER(%s)", (position,))
    db.commit()
    return jsonify({"ok": True})


# ---- STORE MANAGERS (with store role) ----

@app.get("/api/store-managers")
@login_required
def api_get_store_managers():
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT sm.id, sm.store_id, sm.employee_id, sm.store_role, "
            "s.name AS store_name, s.store_code, "
            "e.full_name AS employee_name, e.employee_code "
            "FROM store_managers sm "
            "JOIN stores s ON s.id = sm.store_id "
            "JOIN employees e ON e.id = sm.employee_id "
            "ORDER BY s.name, e.full_name"
        )
        rows = cur.fetchall()
    return jsonify([
        {
            "id": int(row["id"]),
            "storeId": str(row["store_id"]),
            "employeeId": str(row["employee_id"]),
            "storeRole": row.get("store_role") or "PG",
            "storeName": row.get("store_name") or "",
            "storeCode": row.get("store_code") or "",
            "employeeName": row.get("employee_name") or "",
            "employeeCode": row.get("employee_code") or "",
        }
        for row in rows
    ])


@app.post("/api/store-managers")
@login_required
def api_create_store_manager():
    data = request.get_json(silent=True) or {}
    db = get_db()
    try:
        with db.cursor() as cur:
            store_id = int(data.get("storeId", 0))
            employee_id = int(data.get("employeeId", 0))
            cur.execute(
                "INSERT INTO store_managers (store_id, employee_id, store_role) "
                "VALUES (%s, %s, %s) "
                "ON CONFLICT (store_id, employee_id) DO UPDATE SET store_role = EXCLUDED.store_role "
                "RETURNING id, store_id, employee_id, store_role",
                (
                    store_id,
                    employee_id,
                    (data.get("storeRole") or "PG").upper(),
                ),
            )
            row = cur.fetchone()

            # Đồng bộ hồ sơ nhân viên: store_code là định danh chính, work_location là tên cửa hàng
            cur.execute("SELECT store_code, name FROM stores WHERE id = %s LIMIT 1", (store_id,))
            store_row = cur.fetchone()
            if store_row:
                cur.execute(
                    "UPDATE employees SET store_code = %s, work_location = %s WHERE id = %s",
                    (store_row.get("store_code"), store_row.get("name") or "", employee_id),
                )
        db.commit()
        return jsonify({
            "id": int(row["id"]),
            "storeId": str(row["store_id"]),
            "employeeId": str(row["employee_id"]),
            "storeRole": row.get("store_role") or "PG",
        }), 201
    except Exception as e:
        db.rollback()
        return jsonify({"error": str(e)}), 400


@app.put("/api/store-managers/<int:sm_id>")
@login_required
def api_update_store_manager(sm_id: int):
    data = request.get_json(silent=True) or {}
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "UPDATE store_managers SET store_role = %s WHERE id = %s "
            "RETURNING id, store_id, employee_id, store_role",
            ((data.get("storeRole") or "PG").upper(), sm_id),
        )
        row = cur.fetchone()
    db.commit()
    if not row:
        return jsonify({"error": "Not found"}), 404
    return jsonify({
        "id": int(row["id"]),
        "storeId": str(row["store_id"]),
        "employeeId": str(row["employee_id"]),
        "storeRole": row.get("store_role") or "PG",
    })


@app.delete("/api/store-managers/<int:sm_id>")
@login_required
def api_delete_store_manager(sm_id: int):
    db = get_db()
    with db.cursor() as cur:
        cur.execute("DELETE FROM store_managers WHERE id = %s", (sm_id,))
    db.commit()
    return jsonify({"ok": True})


@app.get("/api/me/permissions")
@login_required
def api_me_permissions():
    """Resolve effective permissions for the current user (system role + store role)."""
    user = g.current_user
    employee_id = int(user.get("employee_id") or 0)
    db = get_db()
    with db.cursor() as cur:
        # Get employee record for system role + store_code
        cur.execute(
            "SELECT position, store_code FROM employees WHERE id = %s LIMIT 1",
            (employee_id,),
        )
        emp = cur.fetchone()
    system_role = (emp.get("position") if emp else None) or "PG"
    store_code = emp.get("store_code") if emp else None

    with db.cursor() as cur:
        # Get system role permissions
        cur.execute(
            "SELECT id, position, description, can_attendance, can_report, can_manage_attendance, "
            "can_employees, can_more, can_crud, can_switch_store, can_store_list, can_product_list "
            "FROM permissions WHERE UPPER(position) = UPPER(%s) LIMIT 1",
            (system_role,),
        )
        sys_row = cur.fetchone()

        # Get store role (from store_managers for this employee + their store)
        store_role = None
        store_row = None
        if store_code:
            cur.execute(
                "SELECT sm.store_role, sm.id AS sm_id "
                "FROM store_managers sm JOIN stores s ON s.id = sm.store_id "
                "WHERE sm.employee_id = %s AND s.store_code = %s LIMIT 1",
                (employee_id, store_code),
            )
            sm = cur.fetchone()
            if sm:
                store_role = sm.get("store_role") or "PG"

        if store_role:
            cur.execute(
                "SELECT id, position, description, can_attendance, can_report, "
                "can_manage_attendance, can_employees, can_more, can_crud, "
                "can_switch_store, can_store_list, can_product_list "
                "FROM permissions WHERE UPPER(position) = UPPER(%s) LIMIT 1",
                (store_role,),
            )
            store_row = cur.fetchone()

    sys_perm = _permission_to_api_json(sys_row) if sys_row else _default_permission_for_position(system_role)
    store_perm = (_permission_to_api_json(store_row) if store_row else
                  _default_permission_for_position(store_role) if store_role else None)

    # Merge: effective = OR of system + store perms
    bool_keys = ["canAttendance", "canReport", "canManageAttendance", "canEmployees",
                 "canMore", "canCrud", "canSwitchStore", "canStoreList", "canProductList"]
    effective = dict(sys_perm)
    effective["position"] = system_role
    if store_perm:
        for k in bool_keys:
            effective[k] = sys_perm.get(k, False) or store_perm.get(k, False)

    # All stores where this employee appears as a manager (Tier-2 access).
    with db.cursor() as cur:
        cur.execute(
            "SELECT sm.store_role, s.id, s.store_code, s.name "
            "FROM store_managers sm JOIN stores s ON s.id = sm.store_id "
            "WHERE sm.employee_id = %s ORDER BY s.id",
            (employee_id,),
        )
        managed_rows = cur.fetchall()
    managed_stores = [
        {
            "storeId": str(r["id"]),
            "storeCode": r.get("store_code"),
            "storeName": r.get("name"),
            "storeRole": r.get("store_role") or "PG",
        }
        for r in managed_rows
    ]

    return jsonify({
        "systemRole": system_role,
        "storeRole": store_role,
        "systemPerm": sys_perm,
        "storePerm": store_perm,
        "effective": effective,
        "managedStores": managed_stores,
    })


@app.get("/api/employees")
@login_required
def api_get_employees():
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT id, full_name, employee_code, position, work_location, score, email, phone, date_of_birth, cccd, address, status, department, province, area, created_date, probation_date, official_date, resign_date, resign_reason, avatar_url, store_code, rank_level "
            "FROM employees ORDER BY score DESC, id ASC"
        )
        rows = cur.fetchall()
    return jsonify([_employee_to_api_json(row, idx + 1) for idx, row in enumerate(rows)])


@app.post("/api/employees")
@login_required
def api_create_employee():
    data = request.get_json(silent=True) or {}
    db = get_db()
    store_code, store_name = _get_store_info_by_code(db, data.get("storeCode"))
    work_location = _derive_work_location(store_name, data.get("workLocation"))
    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO employees (full_name, employee_code, position, work_location, email, score, store_code) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s) "
            "RETURNING id, full_name, employee_code, position, work_location, score, email, phone, date_of_birth, cccd, address, status, department, province, area, created_date, probation_date, official_date, resign_date, resign_reason, avatar_url, store_code, rank_level",
            (
                data.get("fullName", ""),
                data.get("employeeCode", ""),
                data.get("position", "PG"),
                work_location,
                data.get("email"),
                data.get("score", 0),
                store_code,
            ),
        )
        row = cur.fetchone()
    db.commit()
    return jsonify(_employee_to_api_json(row, 0)), 201


@app.put("/api/employees/<int:employee_id>")
@login_required
def api_update_employee(employee_id: int):
    data = request.get_json(silent=True) or {}
    db = get_db()

    with db.cursor() as cur:
        cur.execute(
            "SELECT id, full_name, employee_code, position, work_location, score, email, phone, address, status, department, province, area, store_code, rank_level "
            "FROM employees WHERE id = %s LIMIT 1",
            (employee_id,),
        )
        existing = cur.fetchone()

    if not existing:
        return jsonify({"error": "Employee not found"}), 404

    store_code_input = data["storeCode"] if "storeCode" in data else existing.get("store_code")
    store_code, store_name = _get_store_info_by_code(db, store_code_input)
    work_location_input = data["workLocation"] if "workLocation" in data else existing.get("work_location")
    work_location = _derive_work_location(store_name, work_location_input)

    with db.cursor() as cur:
        cur.execute(
            "UPDATE employees SET full_name = %s, employee_code = %s, position = %s, work_location = %s, score = %s, email = %s, phone = %s, address = %s, status = %s, department = %s, province = %s, area = %s, store_code = %s, rank_level = %s "
            "WHERE id = %s "
            "RETURNING id, full_name, employee_code, position, work_location, score, email, phone, date_of_birth, cccd, address, status, department, province, area, created_date, probation_date, official_date, resign_date, resign_reason, avatar_url, store_code, rank_level",
            (
                data.get("fullName", existing.get("full_name") or ""),
                data.get("employeeCode", existing.get("employee_code") or ""),
                data.get("position", existing.get("position") or "PG"),
                work_location,
                data.get("score", existing.get("score") or 0),
                data.get("email", existing.get("email")),
                data.get("phone", existing.get("phone")),
                data.get("address", existing.get("address")),
                data.get("status", existing.get("status")),
                data.get("department", existing.get("department")),
                data.get("province", existing.get("province")),
                data.get("area", existing.get("area")),
                store_code,
                data.get("rankLevel", existing.get("rank_level")),
                employee_id,
            ),
        )
        row = cur.fetchone()

    db.commit()
    return jsonify(_employee_to_api_json(row, 0))


@app.delete("/api/employees/<int:employee_id>")
@login_required
def api_delete_employee(employee_id: int):
    db = get_db()
    with db.cursor() as cur:
        cur.execute("DELETE FROM employees WHERE id = %s", (employee_id,))
    db.commit()
    return jsonify({"ok": True})


@app.get("/api/shifts")
@login_required
def api_get_shifts():
    store_id = request.args.get("storeId")
    db = get_db()
    with db.cursor() as cur:
        if store_id:
            cur.execute(
                "SELECT ws.id, ws.name, ws.shift_code, ws.start_hour, ws.start_minute, "
                "ws.end_hour, ws.end_minute, ws.store_name, ws.store_id, s.name AS store_display_name "
                "FROM work_shifts ws LEFT JOIN stores s ON s.id = ws.store_id "
                "WHERE ws.store_id = %s ORDER BY ws.id ASC",
                (int(store_id),)
            )
        else:
            cur.execute(
                "SELECT ws.id, ws.name, ws.shift_code, ws.start_hour, ws.start_minute, "
                "ws.end_hour, ws.end_minute, ws.store_name, ws.store_id, s.name AS store_display_name "
                "FROM work_shifts ws LEFT JOIN stores s ON s.id = ws.store_id "
                "ORDER BY ws.id ASC"
            )
        rows = cur.fetchall()
    return jsonify([
        {
            "id": str(row.get("id") or ""),
            "name": row.get("name") or "",
            "shiftCode": row.get("shift_code"),
            "startHour": int(row.get("start_hour") or 0),
            "startMinute": int(row.get("start_minute") or 0),
            "endHour": int(row.get("end_hour") or 0),
            "endMinute": int(row.get("end_minute") or 0),
            "storeName": row.get("store_display_name") or row.get("store_name"),
            "storeId": str(row["store_id"]) if row.get("store_id") else None,
        }
        for row in rows
    ])


@app.post("/api/shifts")
@login_required
def api_create_shift():
    data = request.get_json(silent=True) or {}
    store_id = int(data["storeId"]) if data.get("storeId") else None
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO work_shifts (name, shift_code, start_hour, start_minute, end_hour, end_minute, store_name, store_id) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s, %s) "
            "RETURNING id, name, shift_code, start_hour, start_minute, end_hour, end_minute, store_name, store_id",
            (
                data.get("name", ""),
                data.get("shiftCode"),
                data.get("startHour", 0),
                data.get("startMinute", 0),
                data.get("endHour", 0),
                data.get("endMinute", 0),
                data.get("storeName"),
                store_id,
            ),
        )
        row = cur.fetchone()
    db.commit()
    return jsonify(
        {
            "id": str(row.get("id") or ""),
            "name": row.get("name") or "",
            "shiftCode": row.get("shift_code"),
            "startHour": int(row.get("start_hour") or 0),
            "startMinute": int(row.get("start_minute") or 0),
            "endHour": int(row.get("end_hour") or 0),
            "endMinute": int(row.get("end_minute") or 0),
            "storeName": row.get("store_name"),
            "storeId": str(row["store_id"]) if row.get("store_id") else None,
        }
    ), 201


@app.delete("/api/shifts/<int:shift_id>")
@login_required
def api_delete_shift(shift_id: int):
    db = get_db()
    with db.cursor() as cur:
        cur.execute("DELETE FROM work_shifts WHERE id = %s", (shift_id,))
    db.commit()
    return jsonify({"ok": True})


# ---- EMPLOYEE SCHEDULES ----

@app.get("/api/employee-schedules")
@login_required
def api_get_schedules():
    week = request.args.get("week")  # e.g. "2026-04-21" (Monday of the week)
    db = get_db()
    with db.cursor() as cur:
        if week:
            cur.execute(
                "SELECT es.id, es.employee_id, es.shift_id, es.work_date::text, es.note, "
                "e.full_name as employee_name, ws.name as shift_name, "
                "ws.start_hour, ws.start_minute, ws.end_hour, ws.end_minute "
                "FROM employee_schedules es "
                "JOIN employees e ON e.id = es.employee_id "
                "JOIN work_shifts ws ON ws.id = es.shift_id "
                "WHERE es.work_date >= %s::date AND es.work_date < (%s::date + INTERVAL '7 days') "
                "ORDER BY es.work_date, es.employee_id",
                (week, week),
            )
        else:
            cur.execute(
                "SELECT es.id, es.employee_id, es.shift_id, es.work_date::text, es.note, "
                "e.full_name as employee_name, ws.name as shift_name, "
                "ws.start_hour, ws.start_minute, ws.end_hour, ws.end_minute "
                "FROM employee_schedules es "
                "JOIN employees e ON e.id = es.employee_id "
                "JOIN work_shifts ws ON ws.id = es.shift_id "
                "ORDER BY es.work_date DESC LIMIT 100"
            )
        rows = cur.fetchall()
    return jsonify([
        {
            "id": str(row["id"]),
            "employeeId": str(row["employee_id"]),
            "shiftId": str(row["shift_id"]),
            "workDate": row["work_date"],
            "note": row.get("note"),
            "employeeName": row["employee_name"],
            "shiftName": row["shift_name"],
            "startHour": int(row["start_hour"] or 0),
            "startMinute": int(row["start_minute"] or 0),
            "endHour": int(row["end_hour"] or 0),
            "endMinute": int(row["end_minute"] or 0),
        }
        for row in rows
    ])


@app.post("/api/employee-schedules")
@login_required
def api_create_schedule():
    data = request.get_json(silent=True) or {}
    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute(
                "INSERT INTO employee_schedules (employee_id, shift_id, work_date, note) "
                "VALUES (%s, %s, %s::date, %s) "
                "ON CONFLICT (employee_id, work_date) DO UPDATE "
                "SET shift_id = EXCLUDED.shift_id, note = EXCLUDED.note "
                "RETURNING id, employee_id, shift_id, work_date::text, note",
                (
                    int(data.get("employeeId", 0)),
                    int(data.get("shiftId", 0)),
                    data.get("workDate"),
                    data.get("note"),
                ),
            )
            row = cur.fetchone()
        db.commit()
        return jsonify({
            "id": str(row["id"]),
            "employeeId": str(row["employee_id"]),
            "shiftId": str(row["shift_id"]),
            "workDate": row["work_date"],
            "note": row.get("note"),
        }), 201
    except Exception as e:
        db.rollback()
        return jsonify({"error": str(e)}), 400


@app.delete("/api/employee-schedules/<int:schedule_id>")
@login_required
def api_delete_schedule(schedule_id: int):
    db = get_db()
    with db.cursor() as cur:
        cur.execute("DELETE FROM employee_schedules WHERE id = %s", (schedule_id,))
    db.commit()
    return jsonify({"ok": True})


@app.get("/api/products")
@login_required
def api_get_products():
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT id, name, unit, price_with_vat, product_group, product_condition "
            "FROM products ORDER BY id ASC"
        )
        rows = cur.fetchall()
    return jsonify([_product_to_api_json(row) for row in rows])


@app.post("/api/products")
@login_required
def api_create_product():
    data = request.get_json(silent=True) or {}
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO products (name, unit, price_with_vat, product_group, product_condition) "
            "VALUES (%s, %s, %s, %s, %s) RETURNING id, name, unit, price_with_vat, product_group, product_condition",
            (
                data.get("name", ""),
                data.get("unit", "Lon"),
                data.get("priceWithVAT", 0),
                data.get("productGroup", "DELI"),
                data.get("productCondition"),
            ),
        )
        row = cur.fetchone()
    db.commit()
    return jsonify(_product_to_api_json(row)), 201


@app.put("/api/products/<int:product_id>")
@login_required
def api_update_product(product_id: int):
    data = request.get_json(silent=True) or {}
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "UPDATE products SET name = %s, unit = %s, price_with_vat = %s, product_group = %s, product_condition = %s "
            "WHERE id = %s RETURNING id, name, unit, price_with_vat, product_group, product_condition",
            (
                data.get("name", ""),
                data.get("unit", "Lon"),
                data.get("priceWithVAT", 0),
                data.get("productGroup", "DELI"),
                data.get("productCondition"),
                product_id,
            ),
        )
        row = cur.fetchone()
    db.commit()
    if not row:
        return jsonify({"error": "Product not found"}), 404
    return jsonify(_product_to_api_json(row))


@app.delete("/api/products/<int:product_id>")
@login_required
def api_delete_product(product_id: int):
    db = get_db()
    with db.cursor() as cur:
        cur.execute("DELETE FROM products WHERE id = %s", (product_id,))
    db.commit()
    return jsonify({"ok": True})


@app.get("/api/stores")
@login_required
def api_get_stores():
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT id, name, store_code, store_group, latitude, longitude, province, sup, status, open_date, close_date, store_type, address, phone, owner, tax_code "
            "FROM stores ORDER BY id ASC"
        )
        rows = cur.fetchall()

        store_ids = [row["id"] for row in rows]
        managers_by_store: dict[int, list[dict[str, Any]]] = {sid: [] for sid in store_ids}
        if store_ids:
            cur.execute(
                "SELECT sm.store_id, sm.store_role, e.id AS employee_id, e.full_name, e.employee_code, e.email "
                "FROM store_managers sm JOIN employees e ON e.id = sm.employee_id "
                "WHERE sm.store_id = ANY(%s::int[]) ORDER BY sm.id ASC",
                (store_ids,),
            )
            for m in cur.fetchall():
                managers_by_store[m["store_id"]].append(
                    {
                        "employeeId": str(m.get("employee_id") or ""),
                        "name": m.get("full_name") or "",
                        "employeeCode": m.get("employee_code") or "",
                        "email": m.get("email"),
                        "storeRole": m.get("store_role") or "PG",
                    }
                )

    return jsonify([
        _store_to_api_json(row, managers_by_store.get(row["id"], []))
        for row in rows
    ])


@app.post("/api/stores")
@login_required
def api_create_store():
    data = request.get_json(silent=True) or {}
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO stores (name, store_code, store_group, latitude, longitude, province, sup, status, open_date, close_date, store_type, address, phone, owner, tax_code) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s) "
            "RETURNING id, name, store_code, store_group, latitude, longitude, province, sup, status, open_date, close_date, store_type, address, phone, owner, tax_code",
            (
                data.get("name", ""),
                data.get("storeCode", ""),
                data.get("group", "I"),
                data.get("latitude"),
                data.get("longitude"),
                data.get("province"),
                data.get("sup"),
                data.get("status", "Hoạt động"),
                data.get("openDate"),
                data.get("closeDate"),
                data.get("storeType"),
                data.get("address"),
                data.get("phone"),
                data.get("owner"),
                data.get("taxCode"),
            ),
        )
        row = cur.fetchone()
    db.commit()
    return jsonify(_store_to_api_json(row, [])), 201


@app.put("/api/stores/<int:store_id>")
@login_required
def api_update_store(store_id: int):
    data = request.get_json(silent=True) or {}
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "UPDATE stores SET name = %s, store_code = %s, store_group = %s, latitude = %s, longitude = %s, province = %s, sup = %s, status = %s, open_date = %s, close_date = %s, store_type = %s, address = %s, phone = %s, owner = %s, tax_code = %s "
            "WHERE id = %s RETURNING id, name, store_code, store_group, latitude, longitude, province, sup, status, open_date, close_date, store_type, address, phone, owner, tax_code",
            (
                data.get("name", ""),
                data.get("storeCode", ""),
                data.get("group", "I"),
                data.get("latitude"),
                data.get("longitude"),
                data.get("province"),
                data.get("sup"),
                data.get("status", "Hoạt động"),
                data.get("openDate"),
                data.get("closeDate"),
                data.get("storeType"),
                data.get("address"),
                data.get("phone"),
                data.get("owner"),
                data.get("taxCode"),
                store_id,
            ),
        )
        row = cur.fetchone()
    db.commit()
    if not row:
        return jsonify({"error": "Store not found"}), 404
    return jsonify(_store_to_api_json(row, []))


@app.delete("/api/stores/<int:store_id>")
@login_required
def api_delete_store(store_id: int):
    db = get_db()
    with db.cursor() as cur:
        cur.execute("DELETE FROM stores WHERE id = %s", (store_id,))
    db.commit()
    return jsonify({"ok": True})

@app.post("/api/reports")
@login_required
def api_create_report():
    """
    CRITICAL FIX: Atomic RETURNING id prevents race condition.
    Before: used lastrowid + SELECT * ORDER BY id DESC which could return wrong ID
    After: uses atomic RETURNING id from INSERT statement
    """
    data = request.get_json(silent=True) or {}
    db = get_db()
    user_id = g.current_user.get("user_id")
    report_date = _normalize_report_date(data.get("date"))

    # Ưu tiên store_code từ payload; nếu thiếu thì lấy theo nhân viên đăng nhập
    store_code = _normalize_store_code(data.get("storeCode"))
    store_name = (data.get("storeName") or "").strip()
    employee_code = (data.get("employeeCode") or "").strip()
    pg_name = (data.get("pgName") or "").strip()

    with db.cursor() as cur:
        cur.execute(
            "SELECT e.employee_code, e.full_name, e.store_code FROM users u "
            "LEFT JOIN employees e ON e.id = u.employee_id WHERE u.id = %s LIMIT 1",
            (user_id,),
        )
        me = cur.fetchone()

    if not store_code and me:
        store_code = _normalize_store_code(me.get("store_code"))
    if not employee_code and me:
        employee_code = (me.get("employee_code") or "").strip()
    if not pg_name and me:
        pg_name = (me.get("full_name") or "").strip()

    resolved_code, resolved_store_name = _get_store_info_by_code(db, store_code)
    store_code = resolved_code
    if not store_name:
        store_name = resolved_store_name or ""

    # ATOMIC INSERT - gets report_id immediately, no race condition
    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO sales_reports "
            "(report_date, pg_name, store_name, nu, sale_out, store_code, "
            "report_month, revenue, points, employee_code, created_by) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING *",
            (
                report_date,
                pg_name,
                store_name,
                data.get("nu", 0),
                data.get("saleOut", 0),
                store_code,
                data.get("reportMonth"),
                data.get("revenue", 0),
                data.get("points", 0),
                employee_code,
                user_id,
            ),
        )
        report = cur.fetchone()
    report_id = report["id"]
    db.commit()
    
    # Insert sale items for THIS exact report_id
    for item in data.get("products", []):
        with db.cursor() as cur:
            cur.execute(
                "INSERT INTO sale_items (report_id, product_id, product_name, quantity, unit_price) "
                "VALUES (%s, %s, %s, %s, %s)",
                (report_id, item.get("productId"), item.get("productName", ""),
                 item.get("quantity", 0), item.get("unitPrice", 0)),
            )
    db.commit()
    
    with db.cursor() as cur:
        cur.execute(
            "SELECT id, report_date, pg_name, nu, sale_out, revenue, store_name, store_code, report_month, points, employee_code "
            "FROM sales_reports WHERE id = %s",
            (report_id,),
        )
        created_report = cur.fetchone()
        cur.execute(
            "SELECT product_id, product_name, quantity, unit_price, unit, product_group "
            "FROM sale_items WHERE report_id = %s ORDER BY id ASC",
            (report_id,),
        )
        created_items = cur.fetchall()

    return jsonify(_report_to_api_json(created_report, created_items)), 201


@app.get("/api/reports")
@login_required
def api_get_reports():
    filter_type = (request.args.get("filter") or "all").strip().lower()
    now = datetime.now(tz=VN_TZ)
    where_clause = ""
    params: list[Any] = []

    if filter_type == "today":
        where_clause = "WHERE LEFT(report_date, 10) = %s"
        params = [now.strftime("%Y-%m-%d")]
    elif filter_type == "week":
        where_clause = "WHERE LEFT(report_date, 10) >= %s"
        params = [(now - timedelta(days=7)).strftime("%Y-%m-%d")]
    elif filter_type == "month":
        where_clause = "WHERE LEFT(report_date, 10) >= %s AND LEFT(report_date, 10) < %s"
        month_start = now.replace(day=1).strftime("%Y-%m-%d")
        next_month = (now.replace(day=28) + timedelta(days=4)).replace(day=1).strftime("%Y-%m-%d")
        params = [month_start, next_month]

    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            f"SELECT id, report_date, pg_name, nu, sale_out, revenue, store_name, store_code, report_month, points, employee_code "
            f"FROM sales_reports {where_clause} ORDER BY report_date DESC, id DESC",
            tuple(params),
        )
        report_rows = cur.fetchall()

        report_ids = [row["id"] for row in report_rows]
        items_by_report: dict[int, list[dict[str, Any]]] = {rid: [] for rid in report_ids}
        if report_ids:
            cur.execute(
                "SELECT report_id, product_id, product_name, quantity, unit_price, unit, product_group "
                "FROM sale_items WHERE report_id = ANY(%s::int[]) ORDER BY id ASC",
                (report_ids,),
            )
            for item in cur.fetchall():
                items_by_report[item["report_id"]].append(item)

    result = [_report_to_api_json(row, items_by_report.get(row["id"], [])) for row in report_rows]
    return jsonify(result)

@app.post("/api/attendances/checkin")
@login_required
def api_checkin():
    """
    CRITICAL FIX: Atomic INSERT prevents concurrent race condition.
    Each employee can only check in once per day - uses unique index.
    Re-calling check-in does NOT overwrite an existing check-in time;
    the original time is preserved.
    """
    data = request.get_json(silent=True) or {}
    emp_id = data.get("employeeId")
    if not emp_id:
        return jsonify({"error": "Missing employeeId"}), 400

    lat = data.get("latitude")
    lng = data.get("longitude")
    coords = None
    if lat is not None and lng is not None:
        coords = f"{lat},{lng}"

    db = get_db()
    _ensure_attendance_indexes(db)
    now = datetime.now(tz=VN_TZ)
    date_str = now.strftime("%Y-%m-%d")
    time_str = now.strftime("%Y-%m-%dT%H:%M:%S")

    try:
        with db.cursor() as cur:
            cur.execute(
                "INSERT INTO attendances (employee_id, attend_date, check_in_time, coordinates) "
                "VALUES (%s, %s, %s, %s)",
                (emp_id, date_str, time_str, coords),
            )
        db.commit()
    except DBIntegrityError:
        # Already has a row for today — keep original check_in_time, update coords
        # only if there is no existing check-in time yet.
        with db.cursor() as cur:
            cur.execute(
                "UPDATE attendances "
                "SET check_in_time = COALESCE(check_in_time, %s), "
                "    coordinates = COALESCE(coordinates, %s) "
                "WHERE employee_id = %s AND attend_date = %s",
                (time_str, coords, emp_id, date_str),
            )
        db.commit()

    return jsonify({"ok": True, "time": time_str})


@app.post("/api/attendances/checkout")
@login_required
def api_checkout():
    data = request.get_json(silent=True) or {}
    emp_id = data.get("employeeId")
    if not emp_id:
        return jsonify({"error": "Missing employeeId"}), 400

    lat = data.get("latitude")
    lng = data.get("longitude")
    coords_out = None
    if lat is not None and lng is not None:
        coords_out = f"{lat},{lng}"

    db = get_db()
    _ensure_attendance_indexes(db)
    now = datetime.now(tz=VN_TZ)
    date_str = now.strftime("%Y-%m-%d")
    time_str = now.strftime("%Y-%m-%dT%H:%M:%S")

    with db.cursor() as cur:
        cur.execute(
            "UPDATE attendances SET check_out_time = %s, coordinates = COALESCE(%s, coordinates) "
            "WHERE employee_id = %s AND attend_date = %s "
            "RETURNING id",
            (time_str, coords_out, emp_id, date_str),
        )
        row = cur.fetchone()
        if not row:
            # No check-in yet today — create a row with only check-out time so
            # the employee shows up in today's list. Most realistic flow is the
            # client preventing this, but be tolerant.
            cur.execute(
                "INSERT INTO attendances (employee_id, attend_date, check_out_time, coordinates) "
                "VALUES (%s, %s, %s, %s)",
                (emp_id, date_str, time_str, coords_out),
            )
    db.commit()
    return jsonify({"ok": True, "time": time_str})


def _ensure_attendance_indexes(db):
    """Make sure (employee_id, attend_date) is unique so check-in is idempotent."""
    with db.cursor() as cur:
        cur.execute(
            "CREATE UNIQUE INDEX IF NOT EXISTS uq_attendances_emp_date "
            "ON attendances(employee_id, attend_date)"
        )
    db.commit()


def _attendance_to_api_json(row: dict[str, Any]) -> dict[str, Any]:
    has_in = bool(row.get("check_in_time"))
    has_out = bool(row.get("check_out_time"))
    return {
        "id": str(row["id"]),
        "date": row.get("attend_date") or "",
        "employeeId": str(row["employee_id"]),
        "employeeName": row.get("employee_name"),
        "isCheckedIn": has_in and not has_out,
        "checkInTime": row.get("check_in_time"),
        "checkOutTime": row.get("check_out_time"),
        "shiftName": row.get("shift_name"),
        "shiftTimeRange": row.get("shift_time_range"),
        "coordinates": row.get("coordinates"),
        "distanceIn": row.get("distance_in"),
        "checkInDiff": (
            str(row["check_in_diff"]) if row.get("check_in_diff") is not None else None
        ),
        "checkInStatus": row.get("check_in_status"),
        "distanceOut": row.get("distance_out"),
        "checkOutDiff": (
            str(row["check_out_diff"]) if row.get("check_out_diff") is not None else None
        ),
        "checkOutStatus": row.get("check_out_status"),
    }


@app.get("/api/attendances")
@login_required
def api_get_attendances():
    db = get_db()
    _ensure_attendance_indexes(db)
    date_param = (request.args.get("date") or "").strip()
    if not date_param:
        date_param = datetime.now(tz=VN_TZ).strftime("%Y-%m-%d")
    with db.cursor() as cur:
        cur.execute(
            "SELECT a.id, a.employee_id, a.attend_date, a.check_in_time, a.check_out_time, "
            "       a.shift_name, a.shift_time_range, a.coordinates, "
            "       a.distance_in, a.check_in_diff, a.check_in_status, "
            "       a.distance_out, a.check_out_diff, a.check_out_status, "
            "       e.full_name AS employee_name "
            "FROM attendances a "
            "LEFT JOIN employees e ON e.id = a.employee_id "
            "WHERE a.attend_date = %s "
            "ORDER BY a.check_in_time DESC NULLS LAST, a.id DESC",
            (date_param,),
        )
        rows = cur.fetchall()
    return jsonify([_attendance_to_api_json(r) for r in rows])


@app.get("/api/attendances/monthly-summary")
@login_required
def api_attendance_monthly_summary():
    db = get_db()
    _ensure_attendance_indexes(db)
    month = (request.args.get("month") or "").strip()
    if not month:
        month = datetime.now(tz=VN_TZ).strftime("%Y-%m")
    employee_id = (request.args.get("employeeId") or "").strip()

    where = "WHERE attend_date LIKE %s"
    params: list[Any] = [f"{month}%"]
    if employee_id:
        where += " AND employee_id = %s"
        params.append(employee_id)

    with db.cursor() as cur:
        cur.execute(
            f"SELECT attend_date, check_in_time, check_out_time "
            f"FROM attendances {where}",
            tuple(params),
        )
        rows = cur.fetchall()

    days = set()
    total_seconds = 0
    for r in rows:
        d = r.get("attend_date")
        if d:
            days.add(d)
        ci = r.get("check_in_time")
        co = r.get("check_out_time")
        if ci and co:
            try:
                t_in = datetime.fromisoformat(ci)
                t_out = datetime.fromisoformat(co)
                delta = (t_out - t_in).total_seconds()
                if delta > 0:
                    total_seconds += delta
            except Exception:
                pass

    total_hours = round(total_seconds / 3600.0, 1)
    return jsonify({
        "month": month,
        "daysWorked": len(days),
        "totalHours": total_hours,
        "totalRecords": len(rows),
    })

# ---- COMMUNITY POSTS ----

def _ensure_posts_columns(db):
    """Add visibility, store_code, images_json, video_url columns if not exist."""
    with db.cursor() as cur:
        cur.execute("""
            ALTER TABLE community_posts
            ADD COLUMN IF NOT EXISTS visibility TEXT NOT NULL DEFAULT 'public',
            ADD COLUMN IF NOT EXISTS store_code TEXT,
            ADD COLUMN IF NOT EXISTS images_json TEXT,
            ADD COLUMN IF NOT EXISTS video_url TEXT
        """)
    db.commit()

def _post_image_urls(row):
    raw = row.get("images_json") if row else None
    if raw:
        try:
            data = json.loads(raw)
            if isinstance(data, list):
                return [str(x) for x in data if x]
        except Exception:
            pass
    legacy = row.get("image_url") if row else None
    return [legacy] if legacy else []

def _post_to_api_json(row, comments=None, is_liked=False):
    return {
        "id": str(row["id"]),
        "authorId": str(row["author_id"]) if row.get("author_id") else None,
        "authorName": row.get("author_name") or "Ẩn danh",
        "content": row.get("content"),
        "imageUrls": _post_image_urls(row),
        "videoUrl": row.get("video_url") or None,
        "visibility": row.get("visibility") or "public",
        "storeCode": row.get("store_code"),
        "likeCount": int(row.get("like_count") or 0),
        "commentCount": int(row.get("comment_count") or 0),
        "isLiked": bool(is_liked or row.get("liked_by_me")),
        "createdAt": row.get("created_at") or "",
        "comments": comments or [],
    }

@app.get("/api/posts")
@login_required
def api_get_posts():
    db = get_db()
    _ensure_posts_columns(db)
    user_id = (g.current_user or {}).get("user_id")
    with db.cursor() as cur:
        cur.execute(
            "SELECT p.id, p.author_id, p.author_name, p.content, p.image_url, p.images_json, p.video_url, "
            "p.visibility, p.store_code, p.like_count, p.comment_count, p.created_at, "
            "EXISTS(SELECT 1 FROM post_likes pl WHERE pl.post_id = p.id AND pl.user_id = %s) AS liked_by_me "
            "FROM community_posts p ORDER BY p.id DESC LIMIT 100",
            (user_id,),
        )
        rows = cur.fetchall()
    return jsonify([_post_to_api_json(r) for r in rows])

@app.post("/api/posts")
@login_required
def api_create_post():
    data = request.get_json(silent=True) or {}
    db = get_db()
    _ensure_posts_columns(db)
    author_id = g.current_user.get("user_id") if g.current_user else None
    image_urls = data.get("imageUrls") or []
    if not isinstance(image_urls, list):
        image_urls = []
    images_json = json.dumps([str(u) for u in image_urls if u])
    video_url = (data.get("videoUrl") or "").strip() or None
    try:
        with db.cursor() as cur:
            cur.execute(
                "INSERT INTO community_posts (author_id, author_name, content, visibility, store_code, images_json, video_url) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s) "
                "RETURNING id, author_id, author_name, content, image_url, images_json, video_url, visibility, store_code, "
                "like_count, comment_count, created_at",
                (
                    author_id,
                    data.get("authorName", "Ẩn danh"),
                    data.get("content", ""),
                    data.get("visibility", "public"),
                    data.get("storeCode"),
                    images_json,
                    video_url,
                ),
            )
            row = cur.fetchone()
        db.commit()
        return jsonify(_post_to_api_json(row)), 201
    except Exception as e:
        db.rollback()
        return jsonify({"error": str(e)}), 400

@app.put("/api/posts/<int:post_id>")
@login_required
def api_update_post(post_id: int):
    data = request.get_json(silent=True) or {}
    db = get_db()
    _ensure_posts_columns(db)
    image_urls = data.get("imageUrls")
    update_images = isinstance(image_urls, list)
    images_json = json.dumps([str(u) for u in (image_urls or []) if u]) if update_images else None
    with db.cursor() as cur:
        if update_images:
            cur.execute(
                "UPDATE community_posts SET content = %s, visibility = %s, images_json = %s "
                "WHERE id = %s "
                "RETURNING id, author_id, author_name, content, image_url, images_json, video_url, visibility, store_code, "
                "like_count, comment_count, created_at",
                (data.get("content"), data.get("visibility", "public"), images_json, post_id),
            )
        else:
            cur.execute(
                "UPDATE community_posts SET content = %s, visibility = %s "
                "WHERE id = %s "
                "RETURNING id, author_id, author_name, content, image_url, images_json, video_url, visibility, store_code, "
                "like_count, comment_count, created_at",
                (data.get("content"), data.get("visibility", "public"), post_id),
            )
        row = cur.fetchone()
    db.commit()
    if not row:
        return jsonify({"error": "Not found"}), 404
    return jsonify(_post_to_api_json(row))

@app.delete("/api/posts/<int:post_id>")
@login_required
def api_delete_post(post_id: int):
    db = get_db()
    with db.cursor() as cur:
        cur.execute("DELETE FROM community_posts WHERE id = %s", (post_id,))
    db.commit()
    return jsonify({"ok": True})


@app.post("/api/posts/upload-video")
@login_required
def api_upload_post_video():
    f = request.files.get("file") or request.files.get("video")
    if not f:
        return jsonify({"error": "no file"}), 400
    name = secure_filename(f.filename or "video")
    ext = os.path.splitext(name)[1].lower()
    if ext not in ALLOWED_VIDEO_EXT:
        return jsonify({"error": f"ext {ext} not allowed"}), 400
    fname = f"{uuid.uuid4().hex}{ext}"
    target = POST_VIDEO_DIR / fname
    f.save(target)
    try:
        size = target.stat().st_size
    except Exception:
        size = 0
    if size > MAX_VIDEO_BYTES:
        try:
            target.unlink()
        except Exception:
            pass
        return jsonify({"error": "file too large"}), 413
    return jsonify({"videoUrl": fname, "size": size})


@app.get("/api/posts/<int:post_id>/video")
def api_stream_post_video(post_id: int):
    user = _resolve_video_token()
    if not user:
        return jsonify({"error": "Unauthorized"}), 401
    db = get_db()
    _ensure_posts_columns(db)
    with db.cursor() as cur:
        cur.execute(
            "SELECT video_url FROM community_posts WHERE id = %s", (post_id,)
        )
        row = cur.fetchone()
    if not row or not row.get("video_url"):
        return jsonify({"error": "no video"}), 404
    fname = secure_filename(row["video_url"])
    full = POST_VIDEO_DIR / fname
    if not full.is_file():
        return jsonify({"error": "missing"}), 404

    file_size = full.stat().st_size
    mime = mimetypes.guess_type(str(full))[0] or "video/mp4"
    range_header = request.headers.get("Range", "").strip()
    chunk_size = 1024 * 1024

    def _send(start: int, length: int):
        with open(full, "rb") as fh:
            fh.seek(start)
            remaining = length
            while remaining > 0:
                read_n = min(chunk_size, remaining)
                data = fh.read(read_n)
                if not data:
                    break
                remaining -= len(data)
                yield data

    headers = {
        "Accept-Ranges": "bytes",
        "Cache-Control": "private, no-store, max-age=0",
        "Content-Disposition": "inline",
        "X-Content-Type-Options": "nosniff",
    }
    if range_header.startswith("bytes="):
        try:
            rng = range_header[6:].split(",")[0]
            start_s, end_s = rng.split("-", 1)
            start = int(start_s) if start_s else 0
            end = int(end_s) if end_s else file_size - 1
            if start < 0 or start >= file_size:
                return Response(status=416)
            end = min(end, file_size - 1)
            length = end - start + 1
            headers.update({
                "Content-Range": f"bytes {start}-{end}/{file_size}",
                "Content-Length": str(length),
                "Content-Type": mime,
            })
            return Response(
                stream_with_context(_send(start, length)),
                status=206,
                headers=headers,
            )
        except Exception:
            return Response(status=416)
    headers.update({"Content-Length": str(file_size), "Content-Type": mime})
    return Response(
        stream_with_context(_send(0, file_size)),
        status=200,
        headers=headers,
    )


@app.post("/api/posts/<int:post_id>/like")
@login_required
def api_toggle_like(post_id: int):
    db = get_db()
    user_id = g.current_user.get("user_id") if g.current_user else None
    if not user_id:
        return jsonify({"error": "Unauthorized"}), 401
    with db.cursor() as cur:
        cur.execute(
            "SELECT id FROM post_likes WHERE post_id = %s AND user_id = %s",
            (post_id, user_id),
        )
        existing = cur.fetchone()
        if existing:
            cur.execute("DELETE FROM post_likes WHERE post_id = %s AND user_id = %s", (post_id, user_id))
            cur.execute("UPDATE community_posts SET like_count = GREATEST(like_count - 1, 0) WHERE id = %s", (post_id,))
            liked = False
        else:
            cur.execute("INSERT INTO post_likes (post_id, user_id) VALUES (%s, %s)", (post_id, user_id))
            cur.execute("UPDATE community_posts SET like_count = like_count + 1 WHERE id = %s", (post_id,))
            liked = True
        cur.execute("SELECT like_count FROM community_posts WHERE id = %s", (post_id,))
        count_row = cur.fetchone()
    db.commit()
    return jsonify({"liked": liked, "likeCount": int(count_row["like_count"]) if count_row else 0})

@app.get("/api/posts/<int:post_id>/comments")
@login_required
def api_get_comments(post_id: int):
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT id, author_name, content, created_at FROM comments WHERE post_id = %s ORDER BY id ASC",
            (post_id,),
        )
        rows = cur.fetchall()
    return jsonify([
        {"id": str(r["id"]), "authorName": r.get("author_name") or "Ẩn danh",
         "text": r.get("content") or "", "createdAt": r.get("created_at") or ""}
        for r in rows
    ])

@app.post("/api/posts/<int:post_id>/comment")
@login_required
def api_add_comment(post_id: int):
    data = request.get_json(silent=True) or {}
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO comments (post_id, author_name, content) VALUES (%s, %s, %s) "
            "RETURNING id, author_name, content, created_at",
            (post_id, data.get("authorName", "Ẩn danh"), data.get("text", "")),
        )
        row = cur.fetchone()
        cur.execute("UPDATE community_posts SET comment_count = comment_count + 1 WHERE id = %s", (post_id,))
    db.commit()
    return jsonify({
        "id": str(row["id"]), "authorName": row.get("author_name") or "Ẩn danh",
        "text": row.get("content") or "", "createdAt": row.get("created_at") or ""
    }), 201


# ---- LESSONS / QUIZ / EVENTS ----

def _ensure_training_tables(db):
    with db.cursor() as cur:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS lessons (
                id SERIAL PRIMARY KEY,
                title TEXT NOT NULL,
                thumbnail_url TEXT NOT NULL DEFAULT '',
                description TEXT NOT NULL DEFAULT '',
                target_role TEXT NOT NULL DEFAULT 'ALL',
                is_restricted INTEGER NOT NULL DEFAULT 0,
                video_url TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)
        cur.execute("ALTER TABLE lessons ADD COLUMN IF NOT EXISTS description TEXT NOT NULL DEFAULT ''")
        cur.execute("ALTER TABLE lessons ADD COLUMN IF NOT EXISTS created_at TEXT DEFAULT CURRENT_TIMESTAMP")
        cur.execute("ALTER TABLE lessons ADD COLUMN IF NOT EXISTS video_path TEXT")
        cur.execute("""
            CREATE TABLE IF NOT EXISTS lesson_parts (
                id SERIAL PRIMARY KEY,
                lesson_id INTEGER NOT NULL,
                title TEXT NOT NULL DEFAULT '',
                description TEXT NOT NULL DEFAULT '',
                video_path TEXT NOT NULL DEFAULT '',
                order_index INTEGER NOT NULL DEFAULT 0,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)
        cur.execute("CREATE INDEX IF NOT EXISTS idx_lesson_parts_lesson ON lesson_parts(lesson_id, order_index)")
        cur.execute("""
            CREATE TABLE IF NOT EXISTS quiz_questions (
                id SERIAL PRIMARY KEY,
                question_type TEXT DEFAULT 'TN',
                question TEXT NOT NULL,
                option_a TEXT,
                option_b TEXT,
                option_c TEXT,
                option_d TEXT,
                correct_answer TEXT,
                points INTEGER NOT NULL DEFAULT 1,
                content_id TEXT,
                question_number INTEGER
            )
        """)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS quiz_results (
                id SERIAL PRIMARY KEY,
                submitted_at TEXT,
                employee_code TEXT,
                full_name TEXT,
                store_name TEXT,
                phone TEXT,
                content_id TEXT,
                score TEXT,
                answers_json TEXT
            )
        """)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS training_events (
                id SERIAL PRIMARY KEY,
                event_date TEXT NOT NULL,
                title TEXT NOT NULL,
                created_by INTEGER
            )
        """)
        cur.execute("CREATE INDEX IF NOT EXISTS idx_quiz_questions_content ON quiz_questions(content_id)")
        cur.execute("CREATE INDEX IF NOT EXISTS idx_quiz_results_content ON quiz_results(content_id)")
        cur.execute("CREATE INDEX IF NOT EXISTS idx_training_events_date ON training_events(event_date)")
        # Migration: turn each legacy lesson (video_path/video_url + questions on lesson_X)
        # into a single Part #1, then re-link questions/results to part_Y.
        cur.execute(
            "SELECT id, title, video_path, video_url FROM lessons l "
            "WHERE NOT EXISTS (SELECT 1 FROM lesson_parts p WHERE p.lesson_id = l.id) "
            "AND ("
            "  COALESCE(l.video_path,'') <> '' OR COALESCE(l.video_url,'') <> '' "
            "  OR EXISTS (SELECT 1 FROM quiz_questions q WHERE q.content_id = ('lesson_' || l.id::text)) "
            "  OR EXISTS (SELECT 1 FROM quiz_results r WHERE r.content_id = ('lesson_' || l.id::text))"
            ")"
        )
        legacy = cur.fetchall()
        for lr in legacy:
            cur.execute(
                "INSERT INTO lesson_parts (lesson_id, title, description, video_path, order_index) "
                "VALUES (%s, %s, %s, %s, %s) RETURNING id",
                (lr["id"], "Phần 1", "", lr.get("video_path") or "", 1),
            )
            new_part_id = cur.fetchone()["id"]
            old_cid = f"lesson_{lr['id']}"
            new_cid = f"part_{new_part_id}"
            cur.execute("UPDATE quiz_questions SET content_id = %s WHERE content_id = %s", (new_cid, old_cid))
            cur.execute("UPDATE quiz_results SET content_id = %s WHERE content_id = %s", (new_cid, old_cid))
    db.commit()


def _is_admin_user():
    user_id = (g.current_user or {}).get("user_id")
    if not user_id:
        return False
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT e.position FROM users u LEFT JOIN employees e ON e.id = u.employee_id WHERE u.id = %s",
            (user_id,),
        )
        row = cur.fetchone()
    role = ((row or {}).get("position") or "").upper()
    # Bài giảng được phép Thêm/Sửa/Xoá: TMK (chính) + ADM/ADMIN (super-admin)
    return role in ("ADM", "ADMIN", "TMK")


def _current_employee_info():
    user_id = (g.current_user or {}).get("user_id")
    if not user_id:
        return {"employee_code": "", "full_name": "", "store_code": ""}
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT u.username, e.employee_code, e.full_name, e.store_code, e.position "
            "FROM users u LEFT JOIN employees e ON e.id = u.employee_id WHERE u.id = %s",
            (user_id,),
        )
        row = cur.fetchone() or {}
    return {
        "employee_code": row.get("employee_code") or row.get("username") or "",
        "full_name": row.get("full_name") or row.get("username") or "",
        "store_code": row.get("store_code") or "",
        "position": row.get("position") or "",
    }


def _question_to_json(q):
    return {
        "id": q["id"],
        "type": q.get("question_type") or "TN",
        "question": q.get("question") or "",
        "options": [q.get("option_a"), q.get("option_b"), q.get("option_c"), q.get("option_d")],
        "points": int(q.get("points") or 1),
    }


def _fetch_part_questions(cur, part_id):
    cur.execute(
        "SELECT id, question_type, question, option_a, option_b, option_c, option_d, points, question_number "
        "FROM quiz_questions WHERE content_id = %s ORDER BY COALESCE(question_number, id) ASC",
        (f"part_{part_id}",),
    )
    return [_question_to_json(q) for q in cur.fetchall()]


def _part_to_json(p, questions=None):
    return {
        "id": str(p["id"]),
        "lessonId": str(p["lesson_id"]),
        "title": p.get("title") or "",
        "description": p.get("description") or "",
        "videoPath": p.get("video_path") or "",
        "orderIndex": int(p.get("order_index") or 0),
        "questionCount": len(questions) if questions is not None else int(p.get("question_count") or 0),
        "questions": questions if questions is not None else [],
    }


def _user_completed_parts(cur, lesson_id, employee_code):
    """Return set of part_ids the user has submitted a result for, on any part of this lesson."""
    if not employee_code:
        return set()
    cur.execute(
        "SELECT DISTINCT content_id FROM quiz_results r "
        "WHERE r.employee_code = %s AND r.content_id IN ("
        "  SELECT 'part_' || p.id::text FROM lesson_parts p WHERE p.lesson_id = %s"
        ")",
        (employee_code, lesson_id),
    )
    out = set()
    for r in cur.fetchall():
        cid = r.get("content_id") or ""
        if cid.startswith("part_"):
            try:
                out.add(int(cid[5:]))
            except Exception:
                pass
    return out


def _lesson_to_json(row, parts=None, user_completed_part_ids=None):
    parts_json = parts or []
    total = len(parts_json)
    completed = (
        sum(1 for p in parts_json if int(p["id"]) in (user_completed_part_ids or set()))
        if user_completed_part_ids is not None
        else 0
    )
    progress = (completed / total) if total else 0.0
    return {
        "id": str(row["id"]),
        "title": row.get("title") or "",
        "description": row.get("description") or "",
        "thumbnailUrl": row.get("thumbnail_url") or "",
        "targetRole": row.get("target_role") or "ALL",
        "isRestricted": bool(row.get("is_restricted")),
        "parts": parts_json,
        "partCount": total,
        "completedPartCount": completed,
        "progress": round(progress, 4),
    }


@app.get("/api/lessons")
@login_required
def api_get_lessons():
    db = get_db()
    _ensure_training_tables(db)
    user = _current_employee_info()
    emp = user.get("employee_code") or ""
    with db.cursor() as cur:
        cur.execute(
            "SELECT l.id, l.title, l.thumbnail_url, l.description, l.target_role, l.is_restricted "
            "FROM lessons l ORDER BY l.id DESC"
        )
        lessons = cur.fetchall()
        cur.execute(
            "SELECT p.id, p.lesson_id, p.title, p.description, p.video_path, p.order_index, "
            "(SELECT COUNT(*) FROM quiz_questions q WHERE q.content_id = ('part_' || p.id::text)) AS question_count "
            "FROM lesson_parts p ORDER BY p.lesson_id ASC, p.order_index ASC, p.id ASC"
        )
        all_parts = cur.fetchall()
        parts_by_lesson: dict = {}
        for p in all_parts:
            parts_by_lesson.setdefault(p["lesson_id"], []).append(_part_to_json(p))
        # Completed part_ids per lesson for current user
        completed_by_lesson: dict = {}
        if emp:
            cur.execute(
                "SELECT DISTINCT p.lesson_id, p.id AS part_id FROM lesson_parts p "
                "JOIN quiz_results r ON r.content_id = ('part_' || p.id::text) "
                "WHERE r.employee_code = %s",
                (emp,),
            )
            for r in cur.fetchall():
                completed_by_lesson.setdefault(r["lesson_id"], set()).add(r["part_id"])
    return jsonify([
        _lesson_to_json(
            l,
            parts=parts_by_lesson.get(l["id"], []),
            user_completed_part_ids=completed_by_lesson.get(l["id"], set()),
        )
        for l in lessons
    ])


@app.get("/api/lessons/<int:lesson_id>")
@login_required
def api_get_lesson_detail(lesson_id: int):
    db = get_db()
    _ensure_training_tables(db)
    user = _current_employee_info()
    emp = user.get("employee_code") or ""
    with db.cursor() as cur:
        cur.execute(
            "SELECT id, title, thumbnail_url, description, target_role, is_restricted "
            "FROM lessons WHERE id = %s",
            (lesson_id,),
        )
        row = cur.fetchone()
        if not row:
            return jsonify({"error": "Not found"}), 404
        cur.execute(
            "SELECT id, lesson_id, title, description, video_path, order_index "
            "FROM lesson_parts WHERE lesson_id = %s ORDER BY order_index ASC, id ASC",
            (lesson_id,),
        )
        part_rows = cur.fetchall()
        parts = []
        for p in part_rows:
            qs = _fetch_part_questions(cur, p["id"])
            parts.append(_part_to_json(p, questions=qs))
        completed = _user_completed_parts(cur, lesson_id, emp)
    return jsonify(_lesson_to_json(row, parts=parts, user_completed_part_ids=completed))


@app.post("/api/lessons")
@login_required
def api_create_lesson():
    if not _is_admin_user():
        return jsonify({"error": "Forbidden"}), 403
    data = request.get_json(silent=True) or {}
    title = (data.get("title") or "").strip()
    if not title:
        return jsonify({"error": "title required"}), 400
    db = get_db()
    _ensure_training_tables(db)
    parts_in = data.get("parts") or []
    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO lessons (title, thumbnail_url, description, target_role, is_restricted) "
            "VALUES (%s, %s, %s, %s, %s) "
            "RETURNING id, title, thumbnail_url, description, target_role, is_restricted",
            (
                title,
                data.get("thumbnailUrl") or "",
                data.get("description") or "",
                data.get("targetRole") or "ALL",
                1 if data.get("isRestricted") else 0,
            ),
        )
        row = cur.fetchone()
        lesson_id = row["id"]
        out_parts = []
        for idx, p in enumerate(parts_in, start=1):
            cur.execute(
                "INSERT INTO lesson_parts (lesson_id, title, description, video_path, order_index) "
                "VALUES (%s, %s, %s, %s, %s) "
                "RETURNING id, lesson_id, title, description, video_path, order_index",
                (
                    lesson_id,
                    (p.get("title") or f"Phần {idx}").strip(),
                    p.get("description") or "",
                    p.get("videoPath") or "",
                    idx,
                ),
            )
            prow = cur.fetchone()
            part_id = prow["id"]
            cid = f"part_{part_id}"
            qs_in = p.get("questions") or []
            for qidx, q in enumerate(qs_in, start=1):
                opts = (q.get("options") or []) + [None, None, None, None]
                cur.execute(
                    "INSERT INTO quiz_questions (question_type, question, option_a, option_b, option_c, option_d, "
                    "correct_answer, points, content_id, question_number) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                    (
                        q.get("type") or "TN",
                        q.get("question") or "",
                        opts[0], opts[1], opts[2], opts[3],
                        (q.get("correctAnswer") or "").upper(),
                        int(q.get("points") or 1),
                        cid,
                        qidx,
                    ),
                )
            out_parts.append(_part_to_json(prow, questions=_fetch_part_questions(cur, part_id)))
    db.commit()
    return jsonify(_lesson_to_json(row, parts=out_parts, user_completed_part_ids=set())), 201


@app.put("/api/lessons/<int:lesson_id>")
@login_required
def api_update_lesson(lesson_id: int):
    if not _is_admin_user():
        return jsonify({"error": "Forbidden"}), 403
    data = request.get_json(silent=True) or {}
    db = get_db()
    _ensure_training_tables(db)
    with db.cursor() as cur:
        cur.execute(
            "UPDATE lessons SET title = COALESCE(%s, title), thumbnail_url = COALESCE(%s, thumbnail_url), "
            "description = COALESCE(%s, description), target_role = COALESCE(%s, target_role), "
            "is_restricted = COALESCE(%s, is_restricted) "
            "WHERE id = %s "
            "RETURNING id, title, thumbnail_url, description, target_role, is_restricted",
            (
                data.get("title"),
                data.get("thumbnailUrl"),
                data.get("description"),
                data.get("targetRole"),
                (1 if data.get("isRestricted") else 0) if "isRestricted" in data else None,
                lesson_id,
            ),
        )
        row = cur.fetchone()
    db.commit()
    if not row:
        return jsonify({"error": "Not found"}), 404
    return jsonify(_lesson_to_json(row))


@app.delete("/api/lessons/<int:lesson_id>")
@login_required
def api_delete_lesson(lesson_id: int):
    if not _is_admin_user():
        return jsonify({"error": "Forbidden"}), 403
    db = get_db()
    _ensure_training_tables(db)
    with db.cursor() as cur:
        # find part_ids to clean up questions/results/files
        cur.execute("SELECT id, video_path FROM lesson_parts WHERE lesson_id = %s", (lesson_id,))
        parts = cur.fetchall()
        for p in parts:
            cid = f"part_{p['id']}"
            cur.execute("DELETE FROM quiz_questions WHERE content_id = %s", (cid,))
            cur.execute("DELETE FROM quiz_results WHERE content_id = %s", (cid,))
            vp = p.get("video_path") or ""
            if vp:
                try:
                    (LESSON_VIDEO_DIR / secure_filename(vp)).unlink(missing_ok=True)  # type: ignore[arg-type]
                except Exception:
                    pass
        cur.execute("DELETE FROM lesson_parts WHERE lesson_id = %s", (lesson_id,))
        # legacy cleanup
        cur.execute("DELETE FROM quiz_questions WHERE content_id = %s", (f"lesson_{lesson_id}",))
        cur.execute("DELETE FROM quiz_results WHERE content_id = %s", (f"lesson_{lesson_id}",))
        cur.execute("DELETE FROM lessons WHERE id = %s", (lesson_id,))
    db.commit()
    return jsonify({"ok": True})


@app.post("/api/lessons/<int:lesson_id>/parts")
@login_required
def api_create_part(lesson_id: int):
    if not _is_admin_user():
        return jsonify({"error": "Forbidden"}), 403
    data = request.get_json(silent=True) or {}
    db = get_db()
    _ensure_training_tables(db)
    with db.cursor() as cur:
        cur.execute("SELECT id FROM lessons WHERE id = %s", (lesson_id,))
        if not cur.fetchone():
            return jsonify({"error": "Lesson not found"}), 404
        cur.execute(
            "SELECT COALESCE(MAX(order_index), 0) AS m FROM lesson_parts WHERE lesson_id = %s",
            (lesson_id,),
        )
        next_idx = int((cur.fetchone() or {}).get("m") or 0) + 1
        cur.execute(
            "INSERT INTO lesson_parts (lesson_id, title, description, video_path, order_index) "
            "VALUES (%s, %s, %s, %s, %s) "
            "RETURNING id, lesson_id, title, description, video_path, order_index",
            (
                lesson_id,
                (data.get("title") or f"Phần {next_idx}").strip(),
                data.get("description") or "",
                data.get("videoPath") or "",
                int(data.get("orderIndex") or next_idx),
            ),
        )
        prow = cur.fetchone()
        part_id = prow["id"]
        cid = f"part_{part_id}"
        qs_in = data.get("questions") or []
        for qidx, q in enumerate(qs_in, start=1):
            opts = (q.get("options") or []) + [None, None, None, None]
            cur.execute(
                "INSERT INTO quiz_questions (question_type, question, option_a, option_b, option_c, option_d, "
                "correct_answer, points, content_id, question_number) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (
                    q.get("type") or "TN",
                    q.get("question") or "",
                    opts[0], opts[1], opts[2], opts[3],
                    (q.get("correctAnswer") or "").upper(),
                    int(q.get("points") or 1),
                    cid,
                    qidx,
                ),
            )
        out = _part_to_json(prow, questions=_fetch_part_questions(cur, part_id))
    db.commit()
    return jsonify(out), 201


@app.put("/api/lessons/<int:lesson_id>/parts/<int:part_id>")
@login_required
def api_update_part(lesson_id: int, part_id: int):
    if not _is_admin_user():
        return jsonify({"error": "Forbidden"}), 403
    data = request.get_json(silent=True) or {}
    db = get_db()
    _ensure_training_tables(db)
    with db.cursor() as cur:
        cur.execute(
            "UPDATE lesson_parts SET title = COALESCE(%s, title), description = COALESCE(%s, description), "
            "video_path = COALESCE(%s, video_path), order_index = COALESCE(%s, order_index) "
            "WHERE id = %s AND lesson_id = %s "
            "RETURNING id, lesson_id, title, description, video_path, order_index",
            (
                data.get("title"),
                data.get("description"),
                data.get("videoPath"),
                data.get("orderIndex"),
                part_id, lesson_id,
            ),
        )
        prow = cur.fetchone()
        if not prow:
            return jsonify({"error": "Not found"}), 404
        # Optionally replace questions if "questions" key present
        if "questions" in data:
            cid = f"part_{part_id}"
            cur.execute("DELETE FROM quiz_questions WHERE content_id = %s", (cid,))
            qs_in = data.get("questions") or []
            for qidx, q in enumerate(qs_in, start=1):
                opts = (q.get("options") or []) + [None, None, None, None]
                cur.execute(
                    "INSERT INTO quiz_questions (question_type, question, option_a, option_b, option_c, option_d, "
                    "correct_answer, points, content_id, question_number) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                    (
                        q.get("type") or "TN",
                        q.get("question") or "",
                        opts[0], opts[1], opts[2], opts[3],
                        (q.get("correctAnswer") or "").upper(),
                        int(q.get("points") or 1),
                        cid,
                        qidx,
                    ),
                )
        out = _part_to_json(prow, questions=_fetch_part_questions(cur, part_id))
    db.commit()
    return jsonify(out)


@app.delete("/api/lessons/<int:lesson_id>/parts/<int:part_id>")
@login_required
def api_delete_part(lesson_id: int, part_id: int):
    if not _is_admin_user():
        return jsonify({"error": "Forbidden"}), 403
    db = get_db()
    _ensure_training_tables(db)
    with db.cursor() as cur:
        cur.execute(
            "SELECT video_path FROM lesson_parts WHERE id = %s AND lesson_id = %s",
            (part_id, lesson_id),
        )
        prow = cur.fetchone()
        if not prow:
            return jsonify({"error": "Not found"}), 404
        cid = f"part_{part_id}"
        cur.execute("DELETE FROM quiz_questions WHERE content_id = %s", (cid,))
        cur.execute("DELETE FROM quiz_results WHERE content_id = %s", (cid,))
        cur.execute("DELETE FROM lesson_parts WHERE id = %s", (part_id,))
        vp = prow.get("video_path") or ""
        if vp:
            try:
                (LESSON_VIDEO_DIR / secure_filename(vp)).unlink(missing_ok=True)  # type: ignore[arg-type]
            except Exception:
                pass
    db.commit()
    return jsonify({"ok": True})


@app.post("/api/lessons/upload-video")
@login_required
def api_upload_lesson_video():
    if not _is_admin_user():
        return jsonify({"error": "Forbidden"}), 403
    f = request.files.get("file") or request.files.get("video")
    if not f:
        return jsonify({"error": "no file"}), 400
    name = secure_filename(f.filename or "video")
    ext = os.path.splitext(name)[1].lower()
    if ext not in ALLOWED_VIDEO_EXT:
        return jsonify({"error": f"ext {ext} not allowed"}), 400
    fname = f"{uuid.uuid4().hex}{ext}"
    target = LESSON_VIDEO_DIR / fname
    f.save(target)
    try:
        size = target.stat().st_size
    except Exception:
        size = 0
    if size > MAX_VIDEO_BYTES:
        try:
            target.unlink()
        except Exception:
            pass
        return jsonify({"error": "file too large"}), 413
    return jsonify({"videoPath": fname, "size": size})


def _resolve_video_token():
    """Auth for video streaming: accept Bearer header OR ?t= query param."""
    user = get_current_user()
    if user:
        return user
    tok = request.args.get("t")
    if not tok:
        return None
    try:
        return jwt.decode(tok, JWT_SECRET, algorithms=["HS256"])
    except Exception:
        return None


@app.get("/api/lessons/<int:lesson_id>/parts/<int:part_id>/video")
def api_stream_part_video(lesson_id: int, part_id: int):
    user = _resolve_video_token()
    if not user:
        return jsonify({"error": "Unauthorized"}), 401
    db = get_db()
    _ensure_training_tables(db)
    with db.cursor() as cur:
        cur.execute(
            "SELECT video_path FROM lesson_parts WHERE id = %s AND lesson_id = %s",
            (part_id, lesson_id),
        )
        row = cur.fetchone()
    if not row or not row.get("video_path"):
        return jsonify({"error": "no video"}), 404
    fname = secure_filename(row["video_path"])
    full = LESSON_VIDEO_DIR / fname
    if not full.is_file():
        return jsonify({"error": "missing"}), 404

    file_size = full.stat().st_size
    mime = mimetypes.guess_type(str(full))[0] or "video/mp4"
    range_header = request.headers.get("Range", "").strip()
    chunk_size = 1024 * 1024

    def _send(start: int, length: int):
        with open(full, "rb") as fh:
            fh.seek(start)
            remaining = length
            while remaining > 0:
                read_n = min(chunk_size, remaining)
                data = fh.read(read_n)
                if not data:
                    break
                remaining -= len(data)
                yield data

    headers = {
        "Accept-Ranges": "bytes",
        "Cache-Control": "private, no-store, max-age=0",
        "Content-Disposition": "inline",
        "X-Content-Type-Options": "nosniff",
    }

    if range_header.startswith("bytes="):
        try:
            rng = range_header[6:].split(",")[0]
            start_s, end_s = rng.split("-", 1)
            start = int(start_s) if start_s else 0
            end = int(end_s) if end_s else file_size - 1
            if start < 0 or start >= file_size:
                return Response(status=416)
            end = min(end, file_size - 1)
            length = end - start + 1
            headers.update({
                "Content-Range": f"bytes {start}-{end}/{file_size}",
                "Content-Length": str(length),
                "Content-Type": mime,
            })
            return Response(
                stream_with_context(_send(start, length)),
                status=206,
                headers=headers,
            )
        except Exception:
            return Response(status=416)

    headers.update({"Content-Length": str(file_size), "Content-Type": mime})
    return Response(
        stream_with_context(_send(0, file_size)),
        status=200,
        headers=headers,
    )


@app.post("/api/quiz/submit")
@login_required
def api_quiz_submit():
    data = request.get_json(silent=True) or {}
    part_id = data.get("partId")
    lesson_id = data.get("lessonId")
    answers = data.get("answers") or {}
    if not part_id and not lesson_id:
        return jsonify({"error": "partId required"}), 400
    db = get_db()
    _ensure_training_tables(db)
    if part_id:
        content_id = f"part_{part_id}"
        with db.cursor() as cur:
            cur.execute("SELECT lesson_id FROM lesson_parts WHERE id = %s", (part_id,))
            prow = cur.fetchone()
        if not prow:
            return jsonify({"error": "Part not found"}), 404
        resolved_lesson_id = prow["lesson_id"]
    else:
        content_id = f"lesson_{lesson_id}"
        resolved_lesson_id = lesson_id
    with db.cursor() as cur:
        cur.execute(
            "SELECT id, correct_answer, points FROM quiz_questions WHERE content_id = %s",
            (content_id,),
        )
        qs = cur.fetchall()
    if not qs:
        return jsonify({"error": "No questions"}), 400
    total = 0
    earned = 0
    correct_count = 0
    for q in qs:
        pts = int(q.get("points") or 1)
        total += pts
        ans = (answers.get(str(q["id"])) or "").strip().upper()
        correct = (q.get("correct_answer") or "").strip().upper()
        if ans and correct and ans == correct:
            earned += pts
            correct_count += 1
    score_percent = (earned / total * 100) if total else 0
    user = _current_employee_info()
    submitted_at = datetime.now(VN_TZ).strftime("%Y-%m-%d %H:%M:%S")
    employee_code = user["employee_code"]
    full_name = user["full_name"]
    store_name = user["store_code"]
    score_text = f"{earned}/{total}"
    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO quiz_results (submitted_at, employee_code, full_name, store_name, content_id, score, answers_json) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING id",
            (submitted_at, employee_code, full_name, store_name, content_id, score_text, json.dumps(answers)),
        )
        result_id = cur.fetchone()["id"]
    db.commit()
    return jsonify({
        "id": result_id,
        "partId": str(part_id) if part_id else None,
        "lessonId": str(resolved_lesson_id),
        "score": score_text,
        "earned": earned,
        "total": total,
        "correctCount": correct_count,
        "questionCount": len(qs),
        "scorePercent": round(score_percent, 2),
        "submittedAt": submitted_at,
    }), 201


@app.get("/api/quiz/results")
@login_required
def api_quiz_results():
    db = get_db()
    _ensure_training_tables(db)
    user = _current_employee_info()
    lesson_id = request.args.get("lessonId")
    part_id = request.args.get("partId")
    scope = (request.args.get("scope") or "self").lower()
    sql = (
        "SELECT r.id, r.submitted_at, r.employee_code, r.full_name, r.store_name, r.content_id, r.score "
        "FROM quiz_results r"
    )
    args: list = []
    where: list = []
    if scope != "all" or not _is_admin_user():
        where.append("r.employee_code = %s")
        args.append(user["employee_code"])
    if part_id:
        where.append("r.content_id = %s")
        args.append(f"part_{part_id}")
    elif lesson_id:
        where.append(
            "(r.content_id = %s OR r.content_id IN (SELECT 'part_' || p.id::text FROM lesson_parts p WHERE p.lesson_id = %s))"
        )
        args.extend([f"lesson_{lesson_id}", int(lesson_id)])
    if where:
        sql += " WHERE " + " AND ".join(where)
    sql += " ORDER BY r.id DESC LIMIT 500"
    with db.cursor() as cur:
        cur.execute(sql, tuple(args))
        rows = cur.fetchall()
    out = []
    for r in rows:
        cid = r.get("content_id") or ""
        rec_lesson_id = ""
        rec_part_id = ""
        if cid.startswith("part_"):
            rec_part_id = cid[5:]
        elif cid.startswith("lesson_"):
            rec_lesson_id = cid[7:]
        out.append({
            "id": r["id"],
            "submittedAt": r.get("submitted_at"),
            "employeeCode": r.get("employee_code"),
            "fullName": r.get("full_name"),
            "storeName": r.get("store_name"),
            "lessonId": rec_lesson_id,
            "partId": rec_part_id,
            "score": r.get("score"),
        })
    return jsonify(out)


@app.get("/api/lessons/<int:lesson_id>/history")
@login_required
def api_lesson_history(lesson_id: int):
    """List of users who have submitted at least one part of this lesson, with progress.
    Admins see everyone. Non-admins see only their own row."""
    db = get_db()
    _ensure_training_tables(db)
    is_admin = _is_admin_user()
    me = _current_employee_info()
    with db.cursor() as cur:
        cur.execute("SELECT id FROM lesson_parts WHERE lesson_id = %s", (lesson_id,))
        part_ids = [p["id"] for p in cur.fetchall()]
        total_parts = len(part_ids)
        sql = (
            "SELECT r.id, r.submitted_at, r.employee_code, r.full_name, r.store_name, r.content_id, r.score "
            "FROM quiz_results r WHERE r.content_id IN ("
            "  SELECT 'part_' || p.id::text FROM lesson_parts p WHERE p.lesson_id = %s"
            ") OR r.content_id = %s"
        )
        args: list = [lesson_id, f"lesson_{lesson_id}"]
        if not is_admin:
            sql += " AND r.employee_code = %s"
            args.append(me["employee_code"])
        sql += " ORDER BY r.submitted_at DESC, r.id DESC"
        cur.execute(sql, tuple(args))
        rows = cur.fetchall()
    # Aggregate by employee_code
    agg: dict = {}
    for r in rows:
        emp = r.get("employee_code") or ""
        info = agg.setdefault(emp, {
            "employeeCode": emp,
            "fullName": r.get("full_name") or "",
            "storeName": r.get("store_name") or "",
            "completedPartIds": set(),
            "submissions": [],
            "lastSubmittedAt": r.get("submitted_at"),
        })
        cid = r.get("content_id") or ""
        pid_str = cid[5:] if cid.startswith("part_") else ""
        if pid_str:
            try:
                info["completedPartIds"].add(int(pid_str))
            except Exception:
                pass
        info["submissions"].append({
            "id": r["id"],
            "submittedAt": r.get("submitted_at"),
            "partId": pid_str,
            "score": r.get("score"),
        })
    out = []
    for emp, info in agg.items():
        completed = len(info["completedPartIds"])
        progress = (completed / total_parts) if total_parts else 0.0
        out.append({
            "employeeCode": info["employeeCode"],
            "fullName": info["fullName"],
            "storeName": info["storeName"],
            "completedParts": completed,
            "totalParts": total_parts,
            "progress": round(progress, 4),
            "lastSubmittedAt": info["lastSubmittedAt"],
            "submissions": info["submissions"],
        })
    out.sort(key=lambda x: (x["lastSubmittedAt"] or ""), reverse=True)
    return jsonify({"totalParts": total_parts, "users": out})


@app.get("/api/events")
@login_required
def api_get_events():
    db = get_db()
    _ensure_training_tables(db)
    with db.cursor() as cur:
        cur.execute("SELECT event_date, title FROM training_events ORDER BY event_date ASC, id ASC")
        rows = cur.fetchall()
    out: dict[str, list[str]] = {}
    for r in rows:
        d = r.get("event_date") or ""
        if not d:
            continue
        out.setdefault(d, []).append(r.get("title") or "")
    return jsonify(out)


@app.post("/api/events")
@login_required
def api_create_event():
    data = request.get_json(silent=True) or {}
    title = (data.get("title") or "").strip()
    date_str = (data.get("date") or "").strip()
    if not title or not date_str:
        return jsonify({"error": "title and date required"}), 400
    # Normalize to YYYY-MM-DD
    try:
        d = datetime.fromisoformat(date_str.replace("Z", "+00:00"))
        date_str = d.strftime("%Y-%m-%d")
    except Exception:
        date_str = date_str[:10]
    db = get_db()
    _ensure_training_tables(db)
    user_id = g.current_user.get("user_id") if g.current_user else None
    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO training_events (event_date, title, created_by) VALUES (%s, %s, %s) RETURNING id",
            (date_str, title, user_id),
        )
    db.commit()
    return jsonify({"ok": True, "date": date_str, "title": title}), 201


@app.delete("/api/events")
@login_required
def api_delete_event():
    data = request.get_json(silent=True) or {}
    title = (data.get("title") or "").strip()
    date_str = (data.get("date") or "").strip()
    try:
        d = datetime.fromisoformat(date_str.replace("Z", "+00:00"))
        date_str = d.strftime("%Y-%m-%d")
    except Exception:
        date_str = date_str[:10]
    db = get_db()
    _ensure_training_tables(db)
    with db.cursor() as cur:
        cur.execute(
            "DELETE FROM training_events WHERE event_date = %s AND title = %s",
            (date_str, title),
        )
    db.commit()
    return jsonify({"ok": True})


@app.get("/healthz")
def healthz():
    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute("SELECT COUNT(*) as cnt FROM employees")
            count = cur.fetchone()["cnt"]
        return jsonify({"status": "ok", "backend": "postgres", "employees": count}), 200
    except Exception as e:
        return jsonify({"status": "error", "error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", 8000)), debug=False)
