"""
Bismart Backend - PostgreSQL only (no SQLite fallback).
CRITICAL FIX: All lastrowid issues replaced with atomic RETURNING clauses.
Fixes data loss bug where báo cáo & chấm công disappeared after creation.
"""
from __future__ import annotations

import csv
import io
import json
import math
import mimetypes
import os
import re
import unicodedata
import shutil
import urllib.error
import urllib.parse
import urllib.request
import threading
import time
import uuid
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape as _xml_escape
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
QUIZ_PASS_THRESHOLD = 50  # percent; below this a submission is recorded as not-passed
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
        "paymentMethod": report_row.get("payment_method"),
        "discountAmount": float(report_row.get("discount_amount") or 0),
        "customerName": report_row.get("customer_name"),
        "customerPhone": report_row.get("customer_phone"),
        "returnedAmount": float(report_row.get("returned_amount") or 0),
    }


def _product_conversions_from_row(row: dict[str, Any]) -> list[dict[str, Any]]:
    raw = row.get("conversions_json") if row else None
    if not raw:
        return []
    try:
        parsed = json.loads(raw)
    except (TypeError, ValueError):
        return []
    return parsed if isinstance(parsed, list) else []


def _product_to_api_json(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": str(row.get("id") or ""),
        "name": row.get("name") or "",
        "unit": row.get("unit") or "",
        "priceWithVAT": float(row.get("price_with_vat") or 0),
        "productGroup": row.get("product_group") or "DELI",
        "productCondition": row.get("product_condition"),
        "barcode": row.get("barcode"),
        "imageUrl": row.get("image_url"),
        "conversions": _product_conversions_from_row(row),
        "stockQuantity": float(row.get("stock_quantity") or 0),
        "lowStockThreshold": float(row.get("low_stock_threshold") or 0),
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

    # First-time login: either no users-table record exists yet, or one exists
    # but has no password set (e.g. bulk-imported employees never got a hash).
    # Auto-provision using the employee's configured default password
    # (employees.password, defaults to '1111'), falling back to the employee
    # code itself for backward compatibility. Subsequent logins go through the
    # regular hash check below. This lets every imported employee log in
    # without an admin manually creating a user row each time.
    if not user_row or not user_row.get("password_hash"):
        with db.cursor() as cur:
            cur.execute(
                "SELECT * FROM employees WHERE employee_code = %s LIMIT 1",
                (username,),
            )
            emp = cur.fetchone()
        default_password = (emp.get("password") if emp else None) or username
        if emp and password == default_password:
            new_hash = generate_password_hash(password, method="pbkdf2:sha256")
            with db.cursor() as cur:
                if user_row:
                    cur.execute(
                        "UPDATE users SET password_hash = %s WHERE id = %s",
                        (new_hash, user_row["user_id"]),
                    )
                else:
                    cur.execute(
                        "INSERT INTO users (username, password_hash, employee_id) "
                        "VALUES (%s, %s, %s) "
                        "ON CONFLICT (username) DO NOTHING",
                        (username, new_hash, emp["id"]),
                    )
            db.commit()
            with db.cursor() as cur:
                cur.execute(
                    "SELECT u.id as user_id, u.username, "
                    "u.employee_id as auth_employee_id, u.password_hash, e.* "
                    "FROM users u LEFT JOIN employees e ON u.employee_id = e.id "
                    "WHERE u.username = %s",
                    (username,),
                )
                user_row = cur.fetchone()

    if not user_row or not user_row.get("password_hash") or not check_password_hash(user_row["password_hash"], password):
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


@app.put("/api/auth/profile")
@login_required
def api_update_profile():
    """Update the current user's own employee profile (self-service)."""
    data = request.get_json(silent=True) or {}
    current_user = g.current_user or {}
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT e.id, e.full_name, e.email, e.work_location, e.phone, e.date_of_birth, "
            "e.cccd, e.address, e.avatar_url FROM users u "
            "LEFT JOIN employees e ON u.employee_id = e.id WHERE u.id = %s",
            (current_user.get("user_id"),),
        )
        existing = cur.fetchone()

    if not existing or not existing.get("id"):
        return jsonify({"error": "Unauthorized"}), 401

    with db.cursor() as cur:
        cur.execute(
            "UPDATE employees SET full_name = %s, email = %s, work_location = %s, phone = %s, "
            "date_of_birth = %s, cccd = %s, address = %s, avatar_url = %s WHERE id = %s",
            (
                data.get("fullName", existing.get("full_name")),
                data.get("email", existing.get("email")),
                data.get("workLocation", existing.get("work_location")),
                data.get("phone", existing.get("phone")),
                data.get("dateOfBirth", existing.get("date_of_birth")),
                data.get("cccd", existing.get("cccd")),
                data.get("address", existing.get("address")),
                data.get("avatarUrl", existing.get("avatar_url")),
                existing["id"],
            ),
        )
    db.commit()

    with db.cursor() as cur:
        cur.execute(
            "SELECT u.id as user_id, u.username, u.employee_id as auth_employee_id, e.* FROM users u "
            "LEFT JOIN employees e ON u.employee_id = e.id "
            "WHERE u.id = %s",
            (current_user.get("user_id"),),
        )
        user_row = cur.fetchone()

    return jsonify({"user": _user_to_api_json(user_row)})


@app.post("/api/auth/change-password")
@login_required
def api_change_password():
    """Self-service password change — requires the current password."""
    data = request.get_json(silent=True) or {}
    current_password = (data.get("currentPassword") or "").strip()
    new_password = (data.get("newPassword") or "").strip()
    if not current_password or not new_password:
        return jsonify({"error": "Vui lòng nhập đầy đủ mật khẩu"}), 400
    if len(new_password) < 4:
        return jsonify({"error": "Mật khẩu mới phải có ít nhất 4 ký tự"}), 400

    user_id = (g.current_user or {}).get("user_id")
    db = get_db()
    with db.cursor() as cur:
        cur.execute("SELECT password_hash FROM users WHERE id = %s", (user_id,))
        row = cur.fetchone()

    if not row or not row.get("password_hash") or not check_password_hash(row["password_hash"], current_password):
        return jsonify({"error": "Mật khẩu hiện tại không đúng"}), 401

    new_hash = generate_password_hash(new_password, method="pbkdf2:sha256")
    with db.cursor() as cur:
        cur.execute("UPDATE users SET password_hash = %s WHERE id = %s", (new_hash, user_id))
    db.commit()

    return jsonify({"ok": True})


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
            "SELECT COALESCE(SUM(sr.revenue), 0) AS group_revenue "
            "FROM sales_reports sr JOIN stores s ON UPPER(s.store_code) = UPPER(sr.store_code) "
            "WHERE s.store_group = 'I' AND LEFT(sr.report_date, 10) >= %s AND LEFT(sr.report_date, 10) <= %s",
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
    if not _is_admin_user():
        return _forbidden()
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
    if not _is_admin_user():
        return _forbidden()
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
    if not _is_admin_user():
        return _forbidden()
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
    if not _has_crud_permission():
        return _forbidden()
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
    if not _has_crud_permission():
        return _forbidden()
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
    if not _has_crud_permission():
        return _forbidden()
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
                "WHERE sm.employee_id = %s AND UPPER(s.store_code) = UPPER(%s) LIMIT 1",
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
    if not _has_crud_permission():
        return _forbidden()
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
    if not _has_crud_permission():
        return _forbidden()
    data = request.get_json(silent=True) or {}
    db = get_db()

    with db.cursor() as cur:
        cur.execute(
            "SELECT id, full_name, employee_code, position, work_location, score, email, phone, date_of_birth, cccd, address, status, department, province, area, store_code, rank_level "
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
            "UPDATE employees SET full_name = %s, employee_code = %s, position = %s, work_location = %s, score = %s, email = %s, phone = %s, date_of_birth = %s, cccd = %s, address = %s, status = %s, department = %s, province = %s, area = %s, store_code = %s, rank_level = %s "
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
                data.get("dateOfBirth", existing.get("date_of_birth")),
                data.get("cccd", existing.get("cccd")),
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
    if not _has_crud_permission():
        return _forbidden()
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
    if not (_can_manage_attendance_user() or _has_crud_permission()):
        return _forbidden()
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
    if not (_can_manage_attendance_user() or _has_crud_permission()):
        return _forbidden()
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
    store_code = (request.args.get("storeCode") or "").strip()
    db = get_db()
    base_select = (
        "SELECT es.id, es.employee_id, es.shift_id, es.work_date::text, es.note, "
        "e.full_name as employee_name, ws.name as shift_name, "
        "ws.start_hour, ws.start_minute, ws.end_hour, ws.end_minute "
        "FROM employee_schedules es "
        "JOIN employees e ON e.id = es.employee_id "
        "JOIN work_shifts ws ON ws.id = es.shift_id "
    )
    where_parts: list[str] = []
    params: list[Any] = []
    if week:
        where_parts.append("es.work_date >= %s::date AND es.work_date < (%s::date + INTERVAL '7 days')")
        params.extend([week, week])
    if store_code:
        where_parts.append("UPPER(e.store_code) = UPPER(%s)")
        params.append(store_code)
    where_sql = (" WHERE " + " AND ".join(where_parts)) if where_parts else ""
    order_sql = " ORDER BY es.work_date, es.employee_id" if week else " ORDER BY es.work_date DESC LIMIT 100"
    with db.cursor() as cur:
        cur.execute(base_select + where_sql + order_sql, tuple(params))
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
    if not (_can_manage_attendance_user() or _has_crud_permission()):
        return _forbidden()
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
    if not (_can_manage_attendance_user() or _has_crud_permission()):
        return _forbidden()
    db = get_db()
    with db.cursor() as cur:
        cur.execute("DELETE FROM employee_schedules WHERE id = %s", (schedule_id,))
    db.commit()
    return jsonify({"ok": True})


def _leave_request_to_api_json(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": str(row["id"]),
        "employeeId": str(row["employee_id"]),
        "employeeName": row.get("employee_name"),
        "storeCode": row.get("store_code"),
        "startDate": str(row["start_date"]),
        "endDate": str(row["end_date"]),
        "leaveType": row.get("leave_type"),
        "reason": row.get("reason"),
        "status": row.get("status"),
        "requestedAt": row.get("requested_at"),
        "approvedByName": row.get("approved_by_name"),
        "approvedAt": row.get("approved_at"),
    }


def _my_employee_id() -> int | None:
    user_id = (g.current_user or {}).get("user_id")
    if not user_id:
        return None
    db = get_db()
    with db.cursor() as cur:
        cur.execute("SELECT employee_id FROM users WHERE id = %s", (user_id,))
        row = cur.fetchone()
    return int(row["employee_id"]) if row and row.get("employee_id") else None


@app.get("/api/leave-requests")
@login_required
def api_get_leave_requests():
    """Managers (can_manage_attendance) see every request for their store;
    everyone else sees only their own requests."""
    can_manage = _can_manage_attendance_user()
    store_code = (request.args.get("storeCode") or "").strip()
    status = (request.args.get("status") or "").strip()
    db = get_db()

    base_select = (
        "SELECT lr.id, lr.employee_id, lr.store_code, lr.start_date::text, lr.end_date::text, "
        "       lr.leave_type, lr.reason, lr.status, lr.requested_at, lr.approved_at, "
        "       e.full_name AS employee_name, ab.full_name AS approved_by_name "
        "FROM leave_requests lr "
        "JOIN employees e ON e.id = lr.employee_id "
        "LEFT JOIN employees ab ON ab.id = lr.approved_by "
    )
    where_parts: list[str] = []
    params: list[Any] = []
    if can_manage:
        if store_code:
            where_parts.append("UPPER(lr.store_code) = UPPER(%s)")
            params.append(store_code)
    else:
        my_emp_id = _my_employee_id()
        if my_emp_id is None:
            return jsonify([])
        where_parts.append("lr.employee_id = %s")
        params.append(my_emp_id)
    if status:
        where_parts.append("lr.status = %s")
        params.append(status)
    where_sql = (" WHERE " + " AND ".join(where_parts)) if where_parts else ""
    with db.cursor() as cur:
        cur.execute(base_select + where_sql + " ORDER BY lr.requested_at DESC", tuple(params))
        rows = cur.fetchall()
    return jsonify([_leave_request_to_api_json(row) for row in rows])


@app.post("/api/leave-requests")
@login_required
def api_create_leave_request():
    """Self-service: the request is always filed for the caller's own
    employee record, never a client-supplied employeeId, so one employee
    can't file leave on another's behalf."""
    my_emp_id = _my_employee_id()
    if my_emp_id is None:
        return jsonify({"error": "Tài khoản chưa gắn với hồ sơ nhân viên"}), 400
    data = request.get_json(silent=True) or {}
    start_date = data.get("startDate")
    end_date = data.get("endDate")
    if not start_date or not end_date:
        return jsonify({"error": "Thiếu ngày bắt đầu/kết thúc"}), 400

    db = get_db()
    with db.cursor() as cur:
        cur.execute("SELECT store_code FROM employees WHERE id = %s", (my_emp_id,))
        emp_row = cur.fetchone() or {}
        cur.execute(
            "INSERT INTO leave_requests (employee_id, store_code, start_date, end_date, leave_type, reason) "
            "VALUES (%s, %s, %s::date, %s::date, %s, %s) "
            "RETURNING id",
            (
                my_emp_id,
                emp_row.get("store_code"),
                start_date,
                end_date,
                data.get("leaveType") or "Nghỉ phép năm",
                data.get("reason"),
            ),
        )
        new_id = cur.fetchone()["id"]
        cur.execute(
            "SELECT lr.id, lr.employee_id, lr.store_code, lr.start_date::text, lr.end_date::text, "
            "       lr.leave_type, lr.reason, lr.status, lr.requested_at, lr.approved_at, "
            "       e.full_name AS employee_name, ab.full_name AS approved_by_name "
            "FROM leave_requests lr "
            "JOIN employees e ON e.id = lr.employee_id "
            "LEFT JOIN employees ab ON ab.id = lr.approved_by "
            "WHERE lr.id = %s",
            (new_id,),
        )
        row = cur.fetchone()
    db.commit()
    return jsonify(_leave_request_to_api_json(row)), 201


@app.put("/api/leave-requests/<int:request_id>")
@login_required
def api_update_leave_request(request_id: int):
    """Approve/reject — manager only."""
    if not _can_manage_attendance_user():
        return _forbidden()
    data = request.get_json(silent=True) or {}
    status = data.get("status")
    if status not in ("approved", "rejected"):
        return jsonify({"error": "status phải là approved hoặc rejected"}), 400
    my_emp_id = _my_employee_id()

    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "UPDATE leave_requests SET status = %s, approved_by = %s, approved_at = CURRENT_TIMESTAMP "
            "WHERE id = %s AND status = 'pending' "
            "RETURNING id",
            (status, my_emp_id, request_id),
        )
        updated = cur.fetchone()
        if not updated:
            db.rollback()
            return jsonify({"error": "Không tìm thấy đơn đang chờ duyệt"}), 404
        cur.execute(
            "SELECT lr.id, lr.employee_id, lr.store_code, lr.start_date::text, lr.end_date::text, "
            "       lr.leave_type, lr.reason, lr.status, lr.requested_at, lr.approved_at, "
            "       e.full_name AS employee_name, ab.full_name AS approved_by_name "
            "FROM leave_requests lr "
            "JOIN employees e ON e.id = lr.employee_id "
            "LEFT JOIN employees ab ON ab.id = lr.approved_by "
            "WHERE lr.id = %s",
            (request_id,),
        )
        row = cur.fetchone()
    db.commit()
    return jsonify(_leave_request_to_api_json(row))


@app.delete("/api/leave-requests/<int:request_id>")
@login_required
def api_delete_leave_request(request_id: int):
    """The requester can cancel their own still-pending request; managers
    can remove any request."""
    can_manage = _can_manage_attendance_user()
    my_emp_id = _my_employee_id()
    db = get_db()
    with db.cursor() as cur:
        cur.execute("SELECT employee_id, status FROM leave_requests WHERE id = %s", (request_id,))
        existing = cur.fetchone()
        if not existing:
            return jsonify({"error": "Not found"}), 404
        is_owner = my_emp_id is not None and int(existing["employee_id"]) == my_emp_id
        if not can_manage and not (is_owner and existing["status"] == "pending"):
            return _forbidden()
        cur.execute("DELETE FROM leave_requests WHERE id = %s", (request_id,))
    db.commit()
    return jsonify({"ok": True})


@app.get("/api/products")
@login_required
def api_get_products():
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT id, name, unit, price_with_vat, product_group, product_condition, barcode, "
            "image_url, conversions_json, stock_quantity, low_stock_threshold "
            "FROM products ORDER BY id ASC"
        )
        rows = cur.fetchall()
    return jsonify([_product_to_api_json(row) for row in rows])


def _parse_nonneg_float(value: Any, default: float = 0) -> float:
    """Coerce to a non-negative float; falls back to default on bad/missing input."""
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        return default
    return max(parsed, 0)


@app.post("/api/products")
@login_required
def api_create_product():
    if not _has_crud_permission():
        return _forbidden()
    data = request.get_json(silent=True) or {}
    conversions = data.get("conversions")
    conversions_json = json.dumps(conversions) if isinstance(conversions, list) and conversions else None
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO products (name, unit, price_with_vat, product_group, product_condition, barcode, "
            "image_url, conversions_json, stock_quantity, low_stock_threshold) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s) "
            "RETURNING id, name, unit, price_with_vat, product_group, product_condition, barcode, "
            "image_url, conversions_json, stock_quantity, low_stock_threshold",
            (
                data.get("name", ""),
                data.get("unit", "Lon"),
                _parse_nonneg_float(data.get("priceWithVAT"), 0),
                data.get("productGroup", "DELI"),
                data.get("productCondition"),
                (data.get("barcode") or "").strip() or None,
                data.get("imageUrl") or None,
                conversions_json,
                _parse_nonneg_float(data.get("stockQuantity"), 0),
                _parse_nonneg_float(data.get("lowStockThreshold"), 5),
            ),
        )
        row = cur.fetchone()
    db.commit()
    return jsonify(_product_to_api_json(row)), 201


@app.put("/api/products/<int:product_id>")
@login_required
def api_update_product(product_id: int):
    if not _has_crud_permission():
        return _forbidden()
    data = request.get_json(silent=True) or {}
    conversions = data.get("conversions")
    conversions_json = json.dumps(conversions) if isinstance(conversions, list) and conversions else None
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "UPDATE products SET name = %s, unit = %s, price_with_vat = %s, product_group = %s, "
            "product_condition = %s, barcode = %s, image_url = %s, conversions_json = %s, "
            "stock_quantity = %s, low_stock_threshold = %s "
            "WHERE id = %s RETURNING id, name, unit, price_with_vat, product_group, product_condition, barcode, "
            "image_url, conversions_json, stock_quantity, low_stock_threshold",
            (
                data.get("name", ""),
                data.get("unit", "Lon"),
                _parse_nonneg_float(data.get("priceWithVAT"), 0),
                data.get("productGroup", "DELI"),
                data.get("productCondition"),
                (data.get("barcode") or "").strip() or None,
                data.get("imageUrl") or None,
                conversions_json,
                _parse_nonneg_float(data.get("stockQuantity"), 0),
                _parse_nonneg_float(data.get("lowStockThreshold"), 5),
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
    if not _has_crud_permission():
        return _forbidden()
    db = get_db()
    with db.cursor() as cur:
        cur.execute("DELETE FROM products WHERE id = %s", (product_id,))
    db.commit()
    return jsonify({"ok": True})


@app.post("/api/products/<int:product_id>/adjust-stock")
@login_required
def api_adjust_product_stock(product_id: int):
    """Manual stock correction (stocktake, damaged goods, restock not tied
    to a sale) — adds [delta] (positive or negative) to stock_quantity."""
    if not _has_crud_permission():
        return _forbidden()
    data = request.get_json(silent=True) or {}
    try:
        delta = float(data.get("delta", 0))
    except (TypeError, ValueError):
        return jsonify({"error": "delta không hợp lệ"}), 400
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "UPDATE products SET stock_quantity = GREATEST(stock_quantity + %s, 0) "
            "WHERE id = %s "
            "RETURNING id, name, unit, price_with_vat, product_group, product_condition, barcode, "
            "image_url, conversions_json, stock_quantity, low_stock_threshold",
            (delta, product_id),
        )
        row = cur.fetchone()
    db.commit()
    if not row:
        return jsonify({"error": "Product not found"}), 404
    return jsonify(_product_to_api_json(row))


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
    if not _has_crud_permission():
        return _forbidden()
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
    if not _has_crud_permission():
        return _forbidden()
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
    if not _has_crud_permission():
        return _forbidden()
    db = get_db()
    with db.cursor() as cur:
        cur.execute("DELETE FROM stores WHERE id = %s", (store_id,))
    db.commit()
    return jsonify({"ok": True})


# ---- E-INVOICE PROVIDER SETTINGS ----
# The app never talks to the tax authority directly. Submitting real
# e-invoices requires the business to register with a licensed provider
# (MISA meInvoice, VNPT, Viettel, BKAV...) that already has a certified API
# relationship with Tổng cục Thuế, plus a digital-signature contract. These
# routes only store that provider's connection details and do a basic
# reachability check — they are not a tax-authority integration themselves.

def _mask_secret(value: str | None) -> str | None:
    if not value:
        return value
    if len(value) <= 4:
        return "*" * len(value)
    return "*" * (len(value) - 4) + value[-4:]


@app.get("/api/einvoice/settings")
@login_required
def api_get_einvoice_settings():
    if not _is_admin_user():
        return _forbidden()
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT id, provider, tax_code, api_base_url, api_key, username, is_active, updated_at, "
            "seller_legal_name, seller_address, seller_phone, seller_email, seller_bank_name, "
            "seller_bank_account, invoice_template_code, invoice_series, vat_percent, "
            "misa_app_id, misa_pin_code, vnpt_account, vnpt_account_pass "
            "FROM einvoice_settings ORDER BY id DESC LIMIT 1"
        )
        row = cur.fetchone()
    if not row:
        return jsonify({
            "provider": "misa",
            "taxCode": None,
            "apiBaseUrl": None,
            "apiKeyMasked": None,
            "username": None,
            "isActive": False,
            "configured": False,
            "sellerLegalName": None,
            "sellerAddress": None,
            "sellerPhone": None,
            "sellerEmail": None,
            "sellerBankName": None,
            "sellerBankAccount": None,
            "invoiceTemplateCode": None,
            "invoiceSeries": None,
            "vatPercent": 8,
            "misaAppId": None,
            "misaPinCodeMasked": None,
            "vnptAccount": None,
            "vnptAccountPassMasked": None,
        })
    return jsonify({
        "provider": row.get("provider"),
        "taxCode": row.get("tax_code"),
        "apiBaseUrl": row.get("api_base_url"),
        "apiKeyMasked": _mask_secret(row.get("api_key")),
        "username": row.get("username"),
        "isActive": bool(row.get("is_active")),
        "configured": True,
        "updatedAt": row.get("updated_at"),
        "sellerLegalName": row.get("seller_legal_name"),
        "sellerAddress": row.get("seller_address"),
        "sellerPhone": row.get("seller_phone"),
        "sellerEmail": row.get("seller_email"),
        "sellerBankName": row.get("seller_bank_name"),
        "sellerBankAccount": row.get("seller_bank_account"),
        "invoiceTemplateCode": row.get("invoice_template_code"),
        "invoiceSeries": row.get("invoice_series"),
        "vatPercent": float(row.get("vat_percent") or 8),
        "misaAppId": row.get("misa_app_id"),
        "misaPinCodeMasked": _mask_secret(row.get("misa_pin_code")),
        "vnptAccount": row.get("vnpt_account"),
        "vnptAccountPassMasked": _mask_secret(row.get("vnpt_account_pass")),
    })


@app.put("/api/einvoice/settings")
@login_required
def api_update_einvoice_settings():
    if not _is_admin_user():
        return _forbidden()
    data = request.get_json(silent=True) or {}
    user_id = g.current_user.get("user_id")
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT id, api_key, misa_pin_code, vnpt_account_pass "
            "FROM einvoice_settings ORDER BY id DESC LIMIT 1"
        )
        existing = cur.fetchone()

    # Keep existing secrets if the client sends a blank value (i.e. the admin
    # only changed other fields and didn't retype them).
    new_api_key = (data.get("apiKey") or "").strip()
    if not new_api_key and existing:
        new_api_key = existing.get("api_key")
    new_misa_pin_code = (data.get("misaPinCode") or "").strip()
    if not new_misa_pin_code and existing:
        new_misa_pin_code = existing.get("misa_pin_code")
    new_vnpt_account_pass = (data.get("vnptAccountPass") or "").strip()
    if not new_vnpt_account_pass and existing:
        new_vnpt_account_pass = existing.get("vnpt_account_pass")

    common_params = (
        (data.get("provider") or "misa").strip().lower(),
        (data.get("taxCode") or "").strip() or None,
        (data.get("apiBaseUrl") or "").strip() or None,
        new_api_key,
        (data.get("username") or "").strip() or None,
        int(bool(data.get("isActive", False))),
        (data.get("sellerLegalName") or "").strip() or None,
        (data.get("sellerAddress") or "").strip() or None,
        (data.get("sellerPhone") or "").strip() or None,
        (data.get("sellerEmail") or "").strip() or None,
        (data.get("sellerBankName") or "").strip() or None,
        (data.get("sellerBankAccount") or "").strip() or None,
        (data.get("invoiceTemplateCode") or "").strip() or None,
        (data.get("invoiceSeries") or "").strip() or None,
        float(data.get("vatPercent", 8) or 8),
        (data.get("misaAppId") or "").strip() or None,
        new_misa_pin_code,
        (data.get("vnptAccount") or "").strip() or None,
        new_vnpt_account_pass,
    )

    with db.cursor() as cur:
        if existing:
            cur.execute(
                "UPDATE einvoice_settings SET provider=%s, tax_code=%s, api_base_url=%s, "
                "api_key=%s, username=%s, is_active=%s, seller_legal_name=%s, seller_address=%s, "
                "seller_phone=%s, seller_email=%s, seller_bank_name=%s, seller_bank_account=%s, "
                "invoice_template_code=%s, invoice_series=%s, vat_percent=%s, "
                "misa_app_id=%s, misa_pin_code=%s, vnpt_account=%s, vnpt_account_pass=%s, "
                "updated_by=%s, updated_at=CURRENT_TIMESTAMP "
                "WHERE id=%s",
                common_params + (user_id, existing["id"]),
            )
        else:
            cur.execute(
                "INSERT INTO einvoice_settings "
                "(provider, tax_code, api_base_url, api_key, username, is_active, "
                "seller_legal_name, seller_address, seller_phone, seller_email, seller_bank_name, "
                "seller_bank_account, invoice_template_code, invoice_series, vat_percent, "
                "misa_app_id, misa_pin_code, vnpt_account, vnpt_account_pass, updated_by) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                common_params + (user_id,),
            )
    db.commit()
    return jsonify({"ok": True})


@app.post("/api/einvoice/test-connection")
@login_required
def api_test_einvoice_connection():
    """Basic HTTP reachability check for the configured e-invoice provider
    endpoint. This only confirms the URL responds and that the API key is
    being sent — it does NOT validate against any specific provider's real
    auth/invoice schema, since that differs per provider and requires their
    official API documentation to implement correctly."""
    if not _is_admin_user():
        return _forbidden()
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT api_base_url, api_key FROM einvoice_settings ORDER BY id DESC LIMIT 1"
        )
        row = cur.fetchone()
    if not row or not row.get("api_base_url"):
        return jsonify({"ok": False, "error": "Chưa cấu hình địa chỉ API (apiBaseUrl)"}), 400

    req = urllib.request.Request(
        row["api_base_url"],
        method="GET",
        headers={"Authorization": f"Bearer {row.get('api_key') or ''}"},
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return jsonify({"ok": True, "statusCode": resp.status})
    except urllib.error.HTTPError as e:
        # Any HTTP response (even 401/404) at least proves the endpoint is reachable.
        return jsonify({
            "ok": True,
            "statusCode": e.code,
            "note": "Endpoint phản hồi nhưng có thể cần điều chỉnh xác thực",
        })
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 502


def _can_access_report(report_row: dict) -> bool:
    """Same visibility rule as GET /api/reports (own report, crud permission,
    or the caller's/managed store) — reused by the e-invoice endpoints so
    issuing/viewing an invoice requires the same access as the report itself."""
    if report_row.get("created_by") == g.current_user.get("user_id") or _has_crud_permission():
        return True
    allowed_codes = _allowed_store_codes_for_current_user()
    if allowed_codes is None:
        return True
    return (report_row.get("store_code") or "").upper() in allowed_codes


def _einvoice_record_to_json(row: dict) -> dict:
    return {
        "status": row.get("status"),
        "invoiceNumber": row.get("invoice_number"),
        "provider": row.get("provider"),
        "error": row.get("error_message"),
        "issuedAt": row.get("issued_at"),
        "createdAt": row.get("created_at"),
    }


@app.get("/api/reports/<int:report_id>/einvoice")
@login_required
def api_get_report_einvoice(report_id: int):
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT created_by, store_code FROM sales_reports WHERE id = %s",
            (report_id,),
        )
        report = cur.fetchone()
    if not report:
        return jsonify({"error": "Report not found"}), 404
    if not _can_access_report(report):
        return _forbidden()

    with db.cursor() as cur:
        cur.execute(
            "SELECT status, invoice_number, provider, error_message, issued_at, created_at "
            "FROM einvoice_records WHERE report_id = %s ORDER BY id DESC LIMIT 1",
            (report_id,),
        )
        row = cur.fetchone()
    return jsonify(_einvoice_record_to_json(row) if row else None)


def _viettel_map_payment(payment_method: str | None) -> tuple[str, str]:
    pm = (payment_method or "").strip().lower()
    if pm in ("transfer", "bank_transfer", "chuyen_khoan", "ck"):
        return "CK", "Chuyển khoản"
    return "TM", "Tiền mặt"


def _issue_viettel_invoice(settings: dict, report: dict, items: list[dict]):
    """Real (best-effort) integration against Viettel S-Invoice's documented
    REST webservice: POST {apiBaseUrl}/auth/login for a bearer access token,
    then POST {apiBaseUrl}/services/einvoiceapplication/api/InvoiceAPI/
    InvoiceWS/createInvoice/{username} with the invoice payload.

    Endpoint paths and the generalInvoiceInfo/sellerInfo/buyerInfo/payments/
    itemInfo/summarizeInfo/taxBreakdowns field names follow Viettel's
    published createInvoice schema. This has been grounded in Viettel's
    documented API shape (not guessed from a generic template), but every
    account's actual invoice template (templateCode/invoiceSeries) and
    required fields can vary by contract — verify against your own account's
    real template before relying on this for tax filings.

    Returns (status, invoice_number, error_message, response_snippet).
    """
    base_url = (settings.get("api_base_url") or "").rstrip("/")
    username = (settings.get("username") or "").strip()
    password = settings.get("api_key") or ""

    login_req = urllib.request.Request(
        f"{base_url}/auth/login",
        data=json.dumps({"username": username, "password": password}).encode("utf-8"),
        method="POST",
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(login_req, timeout=15) as resp:
            login_data = json.loads(resp.read().decode("utf-8", errors="replace") or "{}")
    except urllib.error.HTTPError as e:
        return "failed", None, f"Đăng nhập Viettel S-Invoice thất bại (HTTP {e.code})", None
    except Exception as e:
        return "failed", None, f"Không kết nối được Viettel S-Invoice: {e}", None

    access_token = login_data.get("access_token")
    if not access_token:
        return "failed", None, "Đăng nhập Viettel S-Invoice không trả về access_token", None

    vat_percent = float(settings.get("vat_percent") or 0)
    payment_code, payment_name = _viettel_map_payment(report.get("payment_method"))

    item_infos = []
    total_without_tax = 0.0
    total_tax = 0.0
    for it in items:
        qty = float(it.get("quantity") or 0)
        # Product prices in this app are VAT-inclusive (products.price_with_vat),
        # so back out the pre-tax amount using the configured VAT rate.
        unit_price_incl_vat = float(it.get("unit_price") or 0)
        line_incl_vat = qty * unit_price_incl_vat
        line_without_tax = (
            round(line_incl_vat / (1 + vat_percent / 100), 2) if vat_percent else line_incl_vat
        )
        line_tax = round(line_incl_vat - line_without_tax, 2)
        total_without_tax += line_without_tax
        total_tax += line_tax
        item_infos.append({
            "itemName": it.get("product_name"),
            "unitPrice": unit_price_incl_vat,
            "quantity": qty,
            "itemTotalAmountWithoutTax": line_without_tax,
            "taxPercentage": vat_percent,
            "taxAmount": line_tax,
        })

    discount = float(report.get("discount_amount") or 0)
    total_with_tax = max(total_without_tax + total_tax - discount, 0)

    payload = {
        "generalInvoiceInfo": {
            "invoiceType": "1",
            "templateCode": settings.get("invoice_template_code"),
            "invoiceSeries": settings.get("invoice_series"),
            "currencyCode": "VND",
            "exchangeRate": "1",
            "invoiceNote": f"Đơn hàng #{report.get('id')}",
            "paymentStatus": True,
        },
        "sellerInfo": {
            "sellerLegalName": settings.get("seller_legal_name"),
            "sellerTaxCode": settings.get("tax_code"),
            "sellerAddressLine": settings.get("seller_address"),
            "sellerPhoneNumber": settings.get("seller_phone"),
            "sellerEmail": settings.get("seller_email"),
            "sellerBankName": settings.get("seller_bank_name"),
            "sellerBankAccount": settings.get("seller_bank_account"),
        },
        "buyerInfo": {
            "buyerName": (report.get("customer_name") or "").strip() or "Khách lẻ",
            "buyerAddressLine": "",
            "buyerPhoneNumber": report.get("customer_phone"),
        },
        "payments": [{"paymentMethod": payment_code, "paymentMethodName": payment_name}],
        "itemInfo": item_infos,
        "summarizeInfo": {
            "sumOfTotalLineAmountWithoutTax": round(total_without_tax, 2),
            "totalAmountWithoutTax": round(total_without_tax, 2),
            "totalTaxAmount": round(total_tax, 2),
            "totalAmountWithTax": round(total_with_tax, 2),
        },
        "taxBreakdowns": [{
            "taxPercentage": vat_percent,
            "taxableAmount": round(total_without_tax, 2),
            "taxAmount": round(total_tax, 2),
        }],
    }

    invoice_req = urllib.request.Request(
        f"{base_url}/services/einvoiceapplication/api/InvoiceAPI/InvoiceWS/createInvoice/{username}",
        data=json.dumps(payload).encode("utf-8"),
        method="POST",
        headers={
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(invoice_req, timeout=20) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        err_body = ""
        try:
            err_body = e.read().decode("utf-8", errors="replace")
        except Exception:
            pass
        return "failed", None, f"Viettel S-Invoice phản hồi lỗi HTTP {e.code}", err_body[:2000]
    except Exception as e:
        return "failed", None, str(e), None

    try:
        resp_json = json.loads(raw) if raw else {}
    except ValueError:
        resp_json = {}

    error_code = resp_json.get("errorCode")
    if error_code:
        msg = resp_json.get("description") or f"Lỗi Viettel S-Invoice: {error_code}"
        return "failed", None, msg, raw[:2000]

    result = resp_json.get("result") or {}
    invoice_no = result.get("invoiceNo") or result.get("reservationCode")
    if not invoice_no:
        return "failed", None, "Viettel S-Invoice không trả về số hóa đơn", raw[:2000]
    return "issued", invoice_no, None, raw[:2000]


def _compute_invoice_lines(settings: dict, items: list[dict]):
    """Shared VAT back-out math for the MISA/VNPT integrations below
    (Viettel's does this inline). Product prices in this app are
    VAT-inclusive, so pre-tax line amounts are derived from the configured
    VAT rate. Returns (lines, total_without_tax, total_tax, vat_percent)."""
    vat_percent = float(settings.get("vat_percent") or 0)
    lines = []
    total_without_tax = 0.0
    total_tax = 0.0
    for it in items:
        qty = float(it.get("quantity") or 0)
        unit_price_incl_vat = float(it.get("unit_price") or 0)
        line_incl_vat = qty * unit_price_incl_vat
        without_tax = (
            round(line_incl_vat / (1 + vat_percent / 100), 2) if vat_percent else line_incl_vat
        )
        tax = round(line_incl_vat - without_tax, 2)
        total_without_tax += without_tax
        total_tax += tax
        lines.append({
            "name": it.get("product_name"),
            "unit": it.get("unit"),
            "quantity": qty,
            "unit_price_incl_vat": unit_price_incl_vat,
            "without_tax": without_tax,
            "tax": tax,
        })
    return lines, round(total_without_tax, 2), round(total_tax, 2), vat_percent


def _build_standard_invoice_xml(
    settings: dict, report: dict, lines: list[dict],
    total_without_tax: float, total_tax: float, vat_percent: float,
) -> str:
    """Best-effort reconstruction of the common Vietnamese e-invoice XML
    convention (HDon/DLHDon/TTChung/NDHDon) that MISA/VNPT/BKAV's
    underlying data format is built on. The outer element names are
    grounded in fragments confirmed from provider documentation, but the
    full leaf tag set was not confirmed against an official XSD — verify
    against your provider's real sample/sandbox before relying on this for
    tax filings.
    """
    discount = float(report.get("discount_amount") or 0)
    total_with_tax = max(total_without_tax + total_tax - discount, 0)
    buyer_name = (report.get("customer_name") or "").strip() or "Khách lẻ"
    buyer_phone = report.get("customer_phone") or ""

    item_xml = "".join(
        f"<HHDVu><STT>{i + 1}</STT><THHDVu>{_xml_escape(str(ln['name'] or ''))}</THHDVu>"
        f"<DVTinh>{_xml_escape(str(ln['unit'] or ''))}</DVTinh>"
        f"<SLuong>{ln['quantity']}</SLuong>"
        f"<DGia>{ln['unit_price_incl_vat']}</DGia>"
        f"<ThTien>{ln['without_tax']}</ThTien>"
        f"<TSuat>{vat_percent}%</TSuat></HHDVu>"
        for i, ln in enumerate(lines)
    )

    return (
        '<?xml version="1.0" encoding="utf-8"?>'
        "<HDon><DLHDon Id=\"data\">"
        "<TTChung>"
        "<PBan>2.0.0</PBan>"
        "<THDon>Hóa đơn giá trị gia tăng</THDon>"
        f"<KHMSHDon>{_xml_escape(str(settings.get('invoice_template_code') or ''))}</KHMSHDon>"
        f"<KHHDon>{_xml_escape(str(settings.get('invoice_series') or ''))}</KHHDon>"
        f"<NLap>{_xml_escape(str(report.get('report_date') or ''))}</NLap>"
        "<DVTTe>VND</DVTTe><TGia>1</TGia>"
        "</TTChung>"
        "<NDHDon>"
        "<NBan>"
        f"<Ten>{_xml_escape(str(settings.get('seller_legal_name') or ''))}</Ten>"
        f"<MST>{_xml_escape(str(settings.get('tax_code') or ''))}</MST>"
        f"<DChi>{_xml_escape(str(settings.get('seller_address') or ''))}</DChi>"
        f"<SDThoai>{_xml_escape(str(settings.get('seller_phone') or ''))}</SDThoai>"
        f"<DCTDTu>{_xml_escape(str(settings.get('seller_email') or ''))}</DCTDTu>"
        "</NBan>"
        "<NMua>"
        f"<Ten>{_xml_escape(buyer_name)}</Ten>"
        f"<SDThoai>{_xml_escape(str(buyer_phone))}</SDThoai>"
        "</NMua>"
        f"<DSHHDVu>{item_xml}</DSHHDVu>"
        "<TToan>"
        f"<TgTCThue>{total_without_tax}</TgTCThue>"
        f"<TgTThue>{total_tax}</TgTThue>"
        f"<TgTTTBSo>{total_with_tax}</TgTTTBSo>"
        "</TToan>"
        "</NDHDon>"
        "</DLHDon></HDon>"
    )


def _issue_misa_invoice(settings: dict, report: dict, items: list[dict]):
    """Best-effort integration against MISA meInvoice's documented REST API:
    POST {apiBaseUrl}/api/v3/auth/token for a JWT (appid/taxcode/username/
    password), then POST {apiBaseUrl}/api/v3/code/invoicepublishing with
    {"PinCode": ..., "XmlContent": <invoice xml>}. The endpoints, auth flow
    and headers (Authorization Bearer + CompanyTaxCode) are grounded in
    MISA's public docs; the exact leaf tags inside the invoice XML are a
    best-effort reconstruction (see _build_standard_invoice_xml) — verify
    against your account's real sample/sandbox before relying on this for
    tax filings.
    """
    base_url = (settings.get("api_base_url") or "").rstrip("/")
    tax_code = settings.get("tax_code") or ""
    username = settings.get("username") or ""
    password = settings.get("api_key") or ""

    login_req = urllib.request.Request(
        f"{base_url}/api/v3/auth/token",
        data=json.dumps({
            "appid": settings.get("misa_app_id") or "",
            "taxcode": tax_code,
            "username": username,
            "password": password,
        }).encode("utf-8"),
        method="POST",
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(login_req, timeout=15) as resp:
            login_data = json.loads(resp.read().decode("utf-8", errors="replace") or "{}")
    except urllib.error.HTTPError as e:
        return "failed", None, f"Đăng nhập MISA meInvoice thất bại (HTTP {e.code})", None
    except Exception as e:
        return "failed", None, f"Không kết nối được MISA meInvoice: {e}", None

    if login_data.get("Success") is False:
        err = login_data.get("Errors") or login_data.get("ErrorCode") or "đăng nhập thất bại"
        return "failed", None, f"Đăng nhập MISA meInvoice thất bại: {err}", None
    token = login_data.get("Data")
    if not token:
        return "failed", None, "Đăng nhập MISA meInvoice không trả về token", None

    lines, total_without_tax, total_tax, vat_percent = _compute_invoice_lines(settings, items)
    xml_content = _build_standard_invoice_xml(
        settings, report, lines, total_without_tax, total_tax, vat_percent
    )

    invoice_req = urllib.request.Request(
        f"{base_url}/api/v3/code/invoicepublishing",
        data=json.dumps({
            "PinCode": settings.get("misa_pin_code") or "",
            "XmlContent": xml_content,
        }).encode("utf-8"),
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "CompanyTaxCode": tax_code,
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(invoice_req, timeout=20) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        err_body = None
        try:
            err_body = e.read().decode("utf-8", errors="replace")[:2000]
        except Exception:
            pass
        return "failed", None, f"MISA meInvoice phản hồi lỗi HTTP {e.code}", err_body
    except Exception as e:
        return "failed", None, str(e), None

    try:
        resp_json = json.loads(raw) if raw else {}
    except ValueError:
        resp_json = {}

    if resp_json.get("Success") is False:
        err = resp_json.get("Errors") or resp_json.get("ErrorCode") or "phát hành thất bại"
        return "failed", None, f"Lỗi MISA meInvoice: {err}", raw[:2000]

    payload_data = resp_json.get("Data") or resp_json.get("Payload") or {}
    invoice_no = None
    if isinstance(payload_data, dict):
        invoice_no = (
            payload_data.get("invoiceNumber") or payload_data.get("SHDon")
            or payload_data.get("fkey")
        )
    if not invoice_no:
        invoice_no = f"DRAFT-{report['id']}-{int(datetime.now().timestamp())}"
    return "issued", invoice_no, None, raw[:2000]


def _issue_vnpt_invoice(settings: dict, report: dict, items: list[dict]):
    """Best-effort integration against VNPT Invoice's documented SOAP
    webservice: PublishService.asmx, operation
    ImportAndPublishInv(Account, ACpass, xmlInvData, username, pass,
    pattern, serial, convert). The operation name and parameter order are
    grounded in VNPT's published function signature; the SOAP namespace
    (assumed to be the ASP.NET .asmx default "http://tempuri.org/") and the
    inner xmlInvData/result XML schemas were not fully confirmed against an
    official sample — verify against your account's real sandbox before
    relying on this for tax filings.
    """
    base_url = (settings.get("api_base_url") or "").rstrip("/")
    account = settings.get("vnpt_account") or ""
    ac_pass = settings.get("vnpt_account_pass") or ""
    username = settings.get("username") or ""
    password = settings.get("api_key") or ""
    pattern = settings.get("invoice_template_code") or ""
    serial = settings.get("invoice_series") or ""

    lines, total_without_tax, total_tax, vat_percent = _compute_invoice_lines(settings, items)
    xml_inv_data = _build_standard_invoice_xml(
        settings, report, lines, total_without_tax, total_tax, vat_percent
    )

    envelope = (
        '<?xml version="1.0" encoding="utf-8"?>'
        '<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xmlns:xsd="http://www.w3.org/2001/XMLSchema" '
        'xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">'
        "<soap:Body>"
        '<ImportAndPublishInv xmlns="http://tempuri.org/">'
        f"<Account>{_xml_escape(account)}</Account>"
        f"<ACpass>{_xml_escape(ac_pass)}</ACpass>"
        f"<xmlInvData><![CDATA[{xml_inv_data}]]></xmlInvData>"
        f"<username>{_xml_escape(username)}</username>"
        f"<pass>{_xml_escape(password)}</pass>"
        f"<pattern>{_xml_escape(pattern)}</pattern>"
        f"<serial>{_xml_escape(serial)}</serial>"
        "<convert>0</convert>"
        "</ImportAndPublishInv>"
        "</soap:Body></soap:Envelope>"
    )

    req = urllib.request.Request(
        f"{base_url}/PublishService.asmx",
        data=envelope.encode("utf-8"),
        method="POST",
        headers={
            "Content-Type": "text/xml; charset=utf-8",
            "SOAPAction": "http://tempuri.org/ImportAndPublishInv",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        err_body = None
        try:
            err_body = e.read().decode("utf-8", errors="replace")[:2000]
        except Exception:
            pass
        return "failed", None, f"VNPT Invoice phản hồi lỗi HTTP {e.code}", err_body
    except Exception as e:
        return "failed", None, str(e), None

    try:
        root = ET.fromstring(raw)
    except ET.ParseError:
        return "failed", None, "Không đọc được phản hồi SOAP từ VNPT Invoice", raw[:2000]

    # Strip namespaces for simpler lookup regardless of the SOAP prefix used.
    result_text = None
    for el in root.iter():
        if el.tag.split("}")[-1] == "ImportAndPublishInvResult":
            result_text = el.text
            break
    if not result_text:
        return "failed", None, "VNPT Invoice không trả về kết quả", raw[:2000]

    invoice_no = None
    error_message = None
    try:
        result_root = ET.fromstring(result_text)
        for el in result_root.iter():
            tag = el.tag.split("}")[-1].lower()
            if tag in ("shdon", "invoiceno", "so_hd") and el.text:
                invoice_no = el.text
            if tag in ("description", "error", "message") and el.text and not invoice_no:
                error_message = el.text
    except ET.ParseError:
        # Result wasn't itself XML — fall back to treating any non-empty,
        # error-keyword-free string as a raw reference.
        lowered = result_text.lower()
        if "error" in lowered or "loi" in lowered or "lỗi" in lowered:
            error_message = result_text
        else:
            invoice_no = result_text.strip() or None

    if invoice_no:
        return "issued", invoice_no, None, raw[:2000]
    return "failed", None, error_message or "VNPT Invoice không trả về số hóa đơn", raw[:2000]


def _issue_generic_einvoice(settings: dict, report: dict, items: list[dict]):
    """Best-effort e-invoice issuance for any provider without a dedicated
    integration: posts a generic invoice payload to whichever endpoint is
    configured in einvoice_settings.

    This has NOT been validated against any specific licensed provider's
    certified schema — MISA/VNPT/BKAV each have their own documented API,
    auth flow and digital-signature requirements. Treat any "issued" result
    here as a draft record, not a tax-valid invoice, until this is adapted
    to that provider's official API documentation (see
    _issue_viettel_invoice for what a real per-provider integration looks
    like).

    Returns (status, invoice_number, error_message, response_snippet).
    """
    total_amount = max(
        float(report.get("sale_out") or 0) - float(report.get("discount_amount") or 0), 0
    )
    payload = {
        "sellerTaxCode": settings.get("tax_code"),
        "invoiceDate": report.get("report_date"),
        "customerName": (report.get("customer_name") or "").strip() or "Khách lẻ",
        "customerPhone": report.get("customer_phone"),
        "paymentMethod": report.get("payment_method"),
        "discountAmount": report.get("discount_amount"),
        "totalAmount": total_amount,
        "items": [
            {
                "name": it.get("product_name"),
                "unit": it.get("unit"),
                "quantity": float(it.get("quantity") or 0),
                "unitPrice": float(it.get("unit_price") or 0),
            }
            for it in items
        ],
    }

    req = urllib.request.Request(
        settings["api_base_url"],
        data=json.dumps(payload).encode("utf-8"),
        method="POST",
        headers={
            "Authorization": f"Bearer {settings.get('api_key') or ''}",
            "Content-Type": "application/json",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
            try:
                resp_json = json.loads(raw) if raw else {}
            except ValueError:
                resp_json = {}
            invoice_number = (
                resp_json.get("invoiceNumber") or resp_json.get("invoiceNo")
                or resp_json.get("so_hoa_don") or resp_json.get("id")
            )
            if not invoice_number:
                invoice_number = f"DRAFT-{report['id']}-{int(datetime.now().timestamp())}"
            return "issued", invoice_number, None, raw[:2000]
    except urllib.error.HTTPError as e:
        response_snippet = None
        try:
            response_snippet = e.read().decode("utf-8", errors="replace")[:2000]
        except Exception:
            pass
        return "failed", None, f"Nhà cung cấp phản hồi lỗi HTTP {e.code}", response_snippet
    except Exception as e:
        return "failed", None, str(e), None


@app.post("/api/reports/<int:report_id>/einvoice")
@login_required
def api_issue_report_einvoice(report_id: int):
    """Issue an e-invoice for a sales report, dispatching to a provider-
    specific integration when one exists (currently Viettel S-Invoice) and
    falling back to a generic best-effort POST otherwise."""
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT id, created_by, store_code, report_date, sale_out, discount_amount, "
            "customer_name, customer_phone, payment_method "
            "FROM sales_reports WHERE id = %s",
            (report_id,),
        )
        report = cur.fetchone()
    if not report:
        return jsonify({"error": "Report not found"}), 404
    if not _can_access_report(report):
        return _forbidden()

    with db.cursor() as cur:
        cur.execute(
            "SELECT 1 FROM einvoice_records WHERE report_id = %s AND status = 'issued' LIMIT 1",
            (report_id,),
        )
        if cur.fetchone():
            return jsonify({"error": "Đơn này đã được xuất hóa đơn điện tử"}), 409

    with db.cursor() as cur:
        cur.execute(
            "SELECT provider, tax_code, api_base_url, api_key, username, is_active, "
            "seller_legal_name, seller_address, seller_phone, seller_email, seller_bank_name, "
            "seller_bank_account, invoice_template_code, invoice_series, vat_percent "
            "FROM einvoice_settings ORDER BY id DESC LIMIT 1"
        )
        settings = cur.fetchone()
    if not settings or not settings.get("is_active") or not settings.get("api_base_url"):
        return jsonify({
            "error": "Chưa cấu hình hoặc chưa kích hoạt kết nối hóa đơn điện tử. "
                     "Vào Cá nhân → Cài đặt hóa đơn điện tử để cấu hình."
        }), 400

    with db.cursor() as cur:
        cur.execute(
            "SELECT product_name, quantity, unit_price, unit FROM sale_items "
            "WHERE report_id = %s ORDER BY id ASC",
            (report_id,),
        )
        items = cur.fetchall()

    provider = settings.get("provider")
    if provider == "viettel":
        status, invoice_number, error_message, response_snippet = _issue_viettel_invoice(
            settings, report, items
        )
    elif provider == "misa":
        status, invoice_number, error_message, response_snippet = _issue_misa_invoice(
            settings, report, items
        )
    elif provider == "vnpt":
        status, invoice_number, error_message, response_snippet = _issue_vnpt_invoice(
            settings, report, items
        )
    else:
        status, invoice_number, error_message, response_snippet = _issue_generic_einvoice(
            settings, report, items
        )

    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO einvoice_records "
            "(report_id, status, invoice_number, provider, error_message, response_snippet, "
            "issued_at, created_by) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s, %s) "
            "RETURNING status, invoice_number, provider, error_message, issued_at, created_at",
            (
                report_id,
                status,
                invoice_number,
                settings.get("provider"),
                error_message,
                response_snippet,
                datetime.now(tz=VN_TZ).isoformat() if status == "issued" else None,
                g.current_user.get("user_id"),
            ),
        )
        record = cur.fetchone()
    db.commit()

    result = _einvoice_record_to_json(record)
    return jsonify(result), (201 if status == "issued" else 502)


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

    # A client-supplied storeCode is only honored if the caller actually
    # belongs to / manages that store — otherwise fall back to their own
    # store so a report can't be misattributed to one they have no
    # relationship with.
    allowed_codes = _allowed_store_codes_for_current_user()
    if store_code and allowed_codes is not None and store_code.upper() not in allowed_codes:
        store_code = _normalize_store_code(me.get("store_code")) if me else None

    resolved_code, resolved_store_name = _get_store_info_by_code(db, store_code)
    store_code = resolved_code
    if not store_name:
        store_name = resolved_store_name or ""

    # Sale Out is always the sum of line items, computed server-side, never
    # trusted from the client — Revenue stays separately client-editable
    # (staff may adjust it for rounding/business reasons) but is clamped to
    # be non-negative.
    products_payload = data.get("products", [])
    sale_out = sum(
        float(item.get("quantity", 0) or 0) * float(item.get("unitPrice", 0) or 0)
        for item in products_payload
    )
    revenue = max(float(data.get("revenue", 0) or 0), 0)
    discount_amount = max(float(data.get("discountAmount", 0) or 0), 0)

    # ATOMIC INSERT - gets report_id immediately, no race condition
    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO sales_reports "
            "(report_date, pg_name, store_name, nu, sale_out, store_code, "
            "report_month, revenue, points, employee_code, created_by, payment_method, "
            "discount_amount, customer_name, customer_phone) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING *",
            (
                report_date,
                pg_name,
                store_name,
                data.get("nu", 0),
                sale_out,
                store_code,
                data.get("reportMonth"),
                revenue,
                data.get("points", 0),
                employee_code,
                user_id,
                (data.get("paymentMethod") or "").strip() or None,
                discount_amount,
                (data.get("customerName") or "").strip() or None,
                (data.get("customerPhone") or "").strip() or None,
            ),
        )
        report = cur.fetchone()
    report_id = report["id"]
    db.commit()

    # Insert all sale items in one batched statement, and decrement stock in
    # one bulk UPDATE for lines sold in the product's own base unit — a line
    # sold via a "Quy đổi" conversion unit has no stored multiplier back to
    # the base unit, so it's left out of the automatic decrement rather than
    # guessing a wrong number (use "Điều chỉnh tồn kho" to correct manually).
    # (Previously one INSERT+SELECT+UPDATE per line item — up to 3N round
    # trips for an N-item report.)
    if products_payload:
        insert_rows = []
        insert_params: list[Any] = []
        product_ids: set[int] = set()
        for item in products_payload:
            insert_rows.append("(%s, %s, %s, %s, %s, %s, %s)")
            insert_params.extend([
                report_id, item.get("productId"), item.get("productName", ""),
                item.get("quantity", 0), item.get("unitPrice", 0),
                item.get("unit"), item.get("productGroup"),
            ])
            try:
                if item.get("productId"):
                    product_ids.add(int(item["productId"]))
            except (TypeError, ValueError):
                pass

        with db.cursor() as cur:
            cur.execute(
                "INSERT INTO sale_items (report_id, product_id, product_name, quantity, unit_price, unit, product_group) "
                "VALUES " + ", ".join(insert_rows),
                insert_params,
            )

        product_units: dict[int, str] = {}
        if product_ids:
            with db.cursor() as cur:
                cur.execute(
                    "SELECT id, unit FROM products WHERE id = ANY(%s::int[])",
                    (list(product_ids),),
                )
                product_units = {r["id"]: (r.get("unit") or "") for r in cur.fetchall()}

        decrements: dict[int, float] = {}
        for item in products_payload:
            try:
                pid = int(item.get("productId"))
            except (TypeError, ValueError):
                continue
            if pid not in product_units:
                continue
            item_unit = (item.get("unit") or "").strip()
            if item_unit and item_unit != product_units[pid]:
                continue
            decrements[pid] = decrements.get(pid, 0) + float(item.get("quantity", 0) or 0)

        if decrements:
            with db.cursor() as cur:
                cur.execute(
                    "UPDATE products AS p SET stock_quantity = GREATEST(p.stock_quantity - v.qty, 0) "
                    "FROM (SELECT * FROM unnest(%s::int[], %s::float[]) AS t(id, qty)) AS v "
                    "WHERE p.id = v.id",
                    (list(decrements.keys()), list(decrements.values())),
                )
    db.commit()

    with db.cursor() as cur:
        cur.execute(
            "SELECT id, report_date, pg_name, nu, sale_out, revenue, store_name, store_code, report_month, "
            "points, employee_code, payment_method, discount_amount, customer_name, customer_phone "
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
    where_clauses: list[str] = []
    params: list[Any] = []

    if filter_type == "today":
        where_clauses.append("LEFT(sr.report_date, 10) = %s")
        params.append(now.strftime("%Y-%m-%d"))
    elif filter_type == "week":
        where_clauses.append("LEFT(sr.report_date, 10) >= %s")
        params.append((now - timedelta(days=7)).strftime("%Y-%m-%d"))
    elif filter_type == "month":
        where_clauses.append("LEFT(sr.report_date, 10) >= %s AND LEFT(sr.report_date, 10) < %s")
        month_start = now.replace(day=1).strftime("%Y-%m-%d")
        next_month = (now.replace(day=28) + timedelta(days=4)).replace(day=1).strftime("%Y-%m-%d")
        params.extend([month_start, next_month])

    # Scope to the caller's own store + any stores they manage — mirrors
    # PermissionProvider's client-side filtering, but enforced server-side
    # so a direct API call can't see other stores' revenue/customer data.
    allowed_codes = _allowed_store_codes_for_current_user()
    if allowed_codes is not None:
        if not allowed_codes:
            return jsonify([])
        where_clauses.append("UPPER(sr.store_code) = ANY(%s::text[])")
        params.append(list(allowed_codes))

    where_clause = f"WHERE {' AND '.join(where_clauses)}" if where_clauses else ""

    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            f"SELECT sr.id, sr.report_date, sr.pg_name, sr.nu, sr.sale_out, sr.revenue, sr.store_name, sr.store_code, "
            f"sr.report_month, sr.points, sr.employee_code, sr.payment_method, sr.discount_amount, "
            f"sr.customer_name, sr.customer_phone, COALESCE(rr.returned, 0) AS returned_amount "
            f"FROM sales_reports sr "
            f"LEFT JOIN (SELECT report_id, SUM(amount) AS returned FROM report_returns GROUP BY report_id) rr "
            f"ON rr.report_id = sr.id "
            f"{where_clause} ORDER BY sr.report_date DESC, sr.id DESC",
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


@app.put("/api/reports/<int:report_id>")
@login_required
def api_update_report(report_id: int):
    data = request.get_json(silent=True) or {}
    db = get_db()

    with db.cursor() as cur:
        cur.execute(
            "SELECT id, report_date, pg_name, store_name, nu, sale_out, store_code, "
            "report_month, revenue, points, employee_code, created_by, payment_method, "
            "discount_amount, customer_name, customer_phone FROM sales_reports WHERE id = %s",
            (report_id,),
        )
        existing = cur.fetchone()
    if not existing:
        return jsonify({"error": "Report not found"}), 404

    user_id = g.current_user.get("user_id")
    if existing.get("created_by") != user_id and not _has_crud_permission():
        return _forbidden()

    report_date = _normalize_report_date(data.get("date")) if "date" in data else existing.get("report_date")
    store_code = _normalize_store_code(data.get("storeCode")) if "storeCode" in data else existing.get("store_code")
    # Same store-misattribution guard as report creation — a non-crud user
    # can't move their own report to a store they don't belong to / manage.
    if "storeCode" in data and not _has_crud_permission():
        allowed_codes = _allowed_store_codes_for_current_user()
        if allowed_codes is not None and (not store_code or store_code.upper() not in allowed_codes):
            store_code = existing.get("store_code")
    resolved_code, resolved_store_name = _get_store_info_by_code(db, store_code)
    store_code = resolved_code
    store_name = (data.get("storeName") or "").strip() or resolved_store_name or existing.get("store_name") or ""
    # Sale Out is recomputed from the (possibly updated) line items rather
    # than trusted from the client, same rule as report creation.
    sale_out = (
        sum(
            float(item.get("quantity", 0) or 0) * float(item.get("unitPrice", 0) or 0)
            for item in data.get("products", [])
        )
        if "products" in data
        else existing.get("sale_out")
    )

    with db.cursor() as cur:
        cur.execute(
            "UPDATE sales_reports SET report_date = %s, pg_name = %s, store_name = %s, nu = %s, "
            "sale_out = %s, store_code = %s, report_month = %s, revenue = %s, points = %s, employee_code = %s, "
            "payment_method = %s, discount_amount = %s, customer_name = %s, customer_phone = %s "
            "WHERE id = %s",
            (
                report_date,
                data.get("pgName", existing.get("pg_name")),
                store_name,
                data.get("nu", existing.get("nu")),
                sale_out,
                store_code,
                data.get("reportMonth", existing.get("report_month")),
                max(float(data.get("revenue", existing.get("revenue")) or 0), 0),
                data.get("points", existing.get("points")),
                data.get("employeeCode", existing.get("employee_code")),
                data.get("paymentMethod", existing.get("payment_method")),
                max(float(data.get("discountAmount", existing.get("discount_amount")) or 0), 0),
                (data.get("customerName", existing.get("customer_name")) or "").strip() or None,
                (data.get("customerPhone", existing.get("customer_phone")) or "").strip() or None,
                report_id,
            ),
        )

        if "products" in data:
            cur.execute("DELETE FROM sale_items WHERE report_id = %s", (report_id,))
            for item in data.get("products", []):
                cur.execute(
                    "INSERT INTO sale_items (report_id, product_id, product_name, quantity, unit_price, unit, product_group) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s)",
                    (report_id, item.get("productId"), item.get("productName", ""),
                     item.get("quantity", 0), item.get("unitPrice", 0),
                     item.get("unit"), item.get("productGroup")),
                )
    db.commit()

    with db.cursor() as cur:
        cur.execute(
            "SELECT id, report_date, pg_name, nu, sale_out, revenue, store_name, store_code, report_month, "
            "points, employee_code, payment_method, discount_amount, customer_name, customer_phone "
            "FROM sales_reports WHERE id = %s",
            (report_id,),
        )
        updated_report = cur.fetchone()
        cur.execute(
            "SELECT product_id, product_name, quantity, unit_price, unit, product_group "
            "FROM sale_items WHERE report_id = %s ORDER BY id ASC",
            (report_id,),
        )
        updated_items = cur.fetchall()

    return jsonify(_report_to_api_json(updated_report, updated_items))


@app.delete("/api/reports/<int:report_id>")
@login_required
def api_delete_report(report_id: int):
    db = get_db()
    with db.cursor() as cur:
        cur.execute("SELECT created_by FROM sales_reports WHERE id = %s", (report_id,))
        existing = cur.fetchone()
    if not existing:
        return jsonify({"error": "Report not found"}), 404

    user_id = g.current_user.get("user_id")
    if existing.get("created_by") != user_id and not _has_crud_permission():
        return _forbidden()

    with db.cursor() as cur:
        cur.execute("DELETE FROM sales_reports WHERE id = %s", (report_id,))
    db.commit()
    return jsonify({"ok": True})


@app.post("/api/reports/<int:report_id>/returns")
@login_required
def api_create_report_return(report_id: int):
    """Record a partial return/refund against a report. The report row itself
    is never mutated — returnedAmount is the running sum of these records."""
    data = request.get_json(silent=True) or {}
    db = get_db()

    with db.cursor() as cur:
        cur.execute("SELECT created_by FROM sales_reports WHERE id = %s", (report_id,))
        existing = cur.fetchone()
    if not existing:
        return jsonify({"error": "Report not found"}), 404

    user_id = g.current_user.get("user_id")
    if existing.get("created_by") != user_id and not _has_crud_permission():
        return _forbidden()

    try:
        amount = max(float(data.get("amount", 0) or 0), 0)
    except (TypeError, ValueError):
        return jsonify({"error": "amount không hợp lệ"}), 400
    if amount <= 0:
        return jsonify({"error": "amount phải lớn hơn 0"}), 400
    reason = (data.get("reason") or "").strip() or None

    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO report_returns (report_id, amount, reason, created_by) "
            "VALUES (%s, %s, %s, %s)",
            (report_id, amount, reason, user_id),
        )
        cur.execute(
            "SELECT COALESCE(SUM(amount), 0) AS total FROM report_returns WHERE report_id = %s",
            (report_id,),
        )
        total_row = cur.fetchone()
    db.commit()

    return jsonify({"reportId": str(report_id), "returnedAmount": float(total_row.get("total") or 0)}), 201


def _scheduled_shift_for(db, emp_id: Any, attend_date: str) -> dict | None:
    """Return scheduled shift for (emp_id, attend_date) or None.

    Result keys: name, start_hour, start_minute, end_hour, end_minute, time_range.
    """
    try:
        with db.cursor() as cur:
            cur.execute(
                "SELECT ws.name, ws.start_hour, ws.start_minute, ws.end_hour, ws.end_minute "
                "FROM employee_schedules es "
                "JOIN work_shifts ws ON ws.id = es.shift_id "
                "WHERE es.employee_id = %s AND es.work_date = %s::date "
                "LIMIT 1",
                (int(emp_id), attend_date),
            )
            row = cur.fetchone()
    except Exception:
        return None
    if not row:
        return None
    sh = int(row.get("start_hour") or 0)
    sm = int(row.get("start_minute") or 0)
    eh = int(row.get("end_hour") or 0)
    em = int(row.get("end_minute") or 0)
    return {
        "name": row.get("name") or "",
        "start_hour": sh,
        "start_minute": sm,
        "end_hour": eh,
        "end_minute": em,
        "time_range": f"{sh:02d}:{sm:02d}-{eh:02d}:{em:02d}",
    }


def _evaluate_check_in(shift: dict | None, now: datetime) -> tuple[int | None, str | None]:
    """Return (diff_minutes, status). Positive diff = late. status: 'on_time'|'late'|'early'.

    `early` means employee checked in before scheduled start (>=5 min ahead).
    Threshold for late: any minute past scheduled start.
    """
    if not shift:
        return None, None
    sched = now.replace(hour=shift["start_hour"], minute=shift["start_minute"], second=0, microsecond=0)
    diff_min = int(round((now - sched).total_seconds() / 60))
    if diff_min > 0:
        return diff_min, "late"
    if diff_min < -5:
        return diff_min, "early"
    return diff_min, "on_time"


def _evaluate_check_out(shift: dict | None, now: datetime) -> tuple[int | None, str | None]:
    """Return (diff_minutes, status). Positive diff = stayed past scheduled end (overtime).

    status: 'on_time' | 'overtime' | 'early_leave'.
    """
    if not shift:
        return None, None
    sched = now.replace(hour=shift["end_hour"], minute=shift["end_minute"], second=0, microsecond=0)
    diff_min = int(round((now - sched).total_seconds() / 60))
    if diff_min < -5:
        return diff_min, "early_leave"
    if diff_min > 5:
        return diff_min, "overtime"
    return diff_min, "on_time"


MAX_ATTENDANCE_DISTANCE_M = 50.0


def _haversine_meters(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlambda / 2) ** 2
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _store_distance_for_employee(db, emp_id: Any, lat: float | None, lng: float | None) -> float | None:
    """Distance in meters from (lat, lng) to the employee's assigned store, or None
    if either the position or the store's coordinates are unknown."""
    if lat is None or lng is None:
        return None
    with db.cursor() as cur:
        cur.execute(
            "SELECT s.latitude, s.longitude FROM employees e "
            "LEFT JOIN stores s ON UPPER(s.store_code) = UPPER(e.store_code) "
            "WHERE e.id = %s LIMIT 1",
            (emp_id,),
        )
        row = cur.fetchone()
    if not row or row.get("latitude") is None or row.get("longitude") is None:
        return None
    return _haversine_meters(float(lat), float(lng), float(row["latitude"]), float(row["longitude"]))


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
    # GPS check-in proves the requester is physically at the store, so it can
    # only ever be self-service — never trust a client-supplied employeeId
    # for someone else, even for managers (that would defeat the GPS check).
    current_employee_id = (g.current_user or {}).get("employee_id")
    if str(emp_id) != str(current_employee_id):
        return _forbidden()

    lat = data.get("latitude")
    lng = data.get("longitude")
    coords = None
    if lat is not None and lng is not None:
        coords = f"{lat},{lng}"

    db = get_db()

    distance = _store_distance_for_employee(db, emp_id, lat, lng)
    if distance is not None and distance > MAX_ATTENDANCE_DISTANCE_M:
        return jsonify({
            "error": f"Quá xa cửa hàng ({distance:.0f}m, giới hạn {MAX_ATTENDANCE_DISTANCE_M:.0f}m)",
            "distance": distance,
        }), 400

    _ensure_attendance_indexes(db)
    now = datetime.now(tz=VN_TZ)
    date_str = now.strftime("%Y-%m-%d")
    time_str = now.strftime("%Y-%m-%dT%H:%M:%S")

    shift = _scheduled_shift_for(db, emp_id, date_str)
    diff_min, status = _evaluate_check_in(shift, now)
    shift_name = shift["name"] if shift else None
    shift_range = shift["time_range"] if shift else None

    try:
        with db.cursor() as cur:
            cur.execute(
                "INSERT INTO attendances (employee_id, attend_date, check_in_time, coordinates, distance_in, "
                "                         shift_name, shift_time_range, check_in_diff, check_in_status) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (emp_id, date_str, time_str, coords, distance, shift_name, shift_range, diff_min, status),
            )
        db.commit()
    except DBIntegrityError:
        # Already has a row for today — keep original check_in_time, update coords
        # only if there is no existing check-in time yet.
        # Must rollback the failed INSERT txn before issuing the UPDATE.
        db.rollback()
        with db.cursor() as cur:
            cur.execute(
                "UPDATE attendances "
                "SET check_in_time = COALESCE(check_in_time, %s), "
                "    coordinates = COALESCE(coordinates, %s), "
                "    distance_in = COALESCE(distance_in, %s), "
                "    shift_name = COALESCE(shift_name, %s), "
                "    shift_time_range = COALESCE(shift_time_range, %s), "
                "    check_in_diff = COALESCE(check_in_diff, %s), "
                "    check_in_status = COALESCE(check_in_status, %s) "
                "WHERE employee_id = %s AND attend_date = %s",
                (time_str, coords, distance, shift_name, shift_range, diff_min, status, emp_id, date_str),
            )
        db.commit()

    return jsonify({"ok": True, "time": time_str, "checkInDiff": diff_min, "checkInStatus": status, "distance": distance})


@app.post("/api/attendances/checkout")
@login_required
def api_checkout():
    data = request.get_json(silent=True) or {}
    emp_id = data.get("employeeId")
    if not emp_id:
        return jsonify({"error": "Missing employeeId"}), 400
    # Same self-service-only rule as check-in — see comment there.
    current_employee_id = (g.current_user or {}).get("employee_id")
    if str(emp_id) != str(current_employee_id):
        return _forbidden()

    lat = data.get("latitude")
    lng = data.get("longitude")
    coords_out = None
    if lat is not None and lng is not None:
        coords_out = f"{lat},{lng}"

    db = get_db()

    distance = _store_distance_for_employee(db, emp_id, lat, lng)
    if distance is not None and distance > MAX_ATTENDANCE_DISTANCE_M:
        return jsonify({
            "error": f"Quá xa cửa hàng ({distance:.0f}m, giới hạn {MAX_ATTENDANCE_DISTANCE_M:.0f}m)",
            "distance": distance,
        }), 400

    _ensure_attendance_indexes(db)
    now = datetime.now(tz=VN_TZ)
    date_str = now.strftime("%Y-%m-%d")
    time_str = now.strftime("%Y-%m-%dT%H:%M:%S")

    # Overnight shifts check in on one calendar day and check out after midnight
    # on the next. Resolve the still-open (checked-in, not checked-out) row's
    # actual attend_date instead of assuming "today", so the check-out pairs
    # with the right check-in instead of creating an orphan row.
    with db.cursor() as cur:
        cur.execute(
            "SELECT attend_date FROM attendances "
            "WHERE employee_id = %s AND check_in_time IS NOT NULL AND check_out_time IS NULL "
            "ORDER BY attend_date DESC LIMIT 1",
            (emp_id,),
        )
        open_row = cur.fetchone()
    attend_date = open_row["attend_date"] if open_row else date_str

    shift = _scheduled_shift_for(db, emp_id, attend_date)
    diff_min, status = _evaluate_check_out(shift, now)
    shift_name = shift["name"] if shift else None
    shift_range = shift["time_range"] if shift else None

    with db.cursor() as cur:
        cur.execute(
            "UPDATE attendances SET check_out_time = %s, coordinates = COALESCE(%s, coordinates), "
            "    distance_out = %s, "
            "    shift_name = COALESCE(shift_name, %s), "
            "    shift_time_range = COALESCE(shift_time_range, %s), "
            "    check_out_diff = %s, check_out_status = %s "
            "WHERE employee_id = %s AND attend_date = %s "
            "RETURNING id",
            (time_str, coords_out, distance, shift_name, shift_range, diff_min, status, emp_id, attend_date),
        )
        row = cur.fetchone()
        if not row:
            # No check-in yet today — create a row with only check-out time so
            # the employee shows up in today's list. Most realistic flow is the
            # client preventing this, but be tolerant.
            cur.execute(
                "INSERT INTO attendances (employee_id, attend_date, check_out_time, coordinates, distance_out, "
                "                         shift_name, shift_time_range, check_out_diff, check_out_status) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (emp_id, date_str, time_str, coords_out, distance, shift_name, shift_range, diff_min, status),
            )
    db.commit()
    return jsonify({"ok": True, "time": time_str, "checkOutDiff": diff_min, "checkOutStatus": status, "distance": distance})


def _ensure_attendance_indexes(db):
    """Make sure (employee_id, attend_date) is unique so check-in is idempotent.

    Old data may contain duplicate rows for the same (employee_id, attend_date).
    We keep the row with the smallest id (earliest) and merge any check-in /
    check-out times from the others into it before deleting them, then create
    the unique index. We swallow errors so the index step never breaks reads.
    """
    try:
        with db.cursor() as cur:
            # Find duplicates and merge them.
            cur.execute(
                "SELECT employee_id, attend_date, "
                "       array_agg(id ORDER BY id) AS ids "
                "FROM attendances "
                "GROUP BY employee_id, attend_date "
                "HAVING COUNT(*) > 1"
            )
            dupes = cur.fetchall()
            for row in dupes:
                ids = row["ids"]
                keeper = ids[0]
                drops = ids[1:]
                cur.execute(
                    "SELECT MIN(check_in_time) AS min_in, MAX(check_out_time) AS max_out "
                    "FROM attendances WHERE id = ANY(%s::int[])",
                    (ids,),
                )
                merged = cur.fetchone() or {}
                cur.execute(
                    "UPDATE attendances SET check_in_time = %s, check_out_time = %s "
                    "WHERE id = %s",
                    (merged.get("min_in"), merged.get("max_out"), keeper),
                )
                cur.execute(
                    "DELETE FROM attendances WHERE id = ANY(%s::int[])",
                    (drops,),
                )
            cur.execute(
                "CREATE UNIQUE INDEX IF NOT EXISTS uq_attendances_emp_date "
                "ON attendances(employee_id, attend_date)"
            )
        db.commit()
    except Exception:
        db.rollback()


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


@app.get("/api/attendances/hours-report")
@login_required
def api_attendance_hours_report():
    """Per-employee hours report for a given month.

    Permission rule:
      - Users with `can_manage_attendance` (admin / manager) see all employees of the store.
      - Otherwise they see only their own row.
    Query params: month=YYYY-MM (default current), storeCode (optional, default user's store).
    """
    db = get_db()
    _ensure_attendance_indexes(db)
    month = (request.args.get("month") or "").strip() or datetime.now(tz=VN_TZ).strftime("%Y-%m")
    store_code_param = (request.args.get("storeCode") or "").strip()

    can_manage = _can_manage_attendance_user()
    me = _current_employee_info()
    my_store = me.get("store_code") or ""
    store_code = store_code_param or my_store

    user_id = (g.current_user or {}).get("user_id")
    my_emp_id: int | None = None
    if user_id:
        with db.cursor() as cur:
            cur.execute("SELECT employee_id FROM users WHERE id = %s", (user_id,))
            r = cur.fetchone()
            if r and r.get("employee_id"):
                my_emp_id = int(r["employee_id"])

    where_parts = ["a.attend_date LIKE %s"]
    params: list[Any] = [f"{month}%"]
    if can_manage:
        if store_code:
            where_parts.append("UPPER(e.store_code) = UPPER(%s)")
            params.append(store_code)
    else:
        if my_emp_id is None:
            return jsonify([])
        where_parts.append("a.employee_id = %s")
        params.append(my_emp_id)

    sql = (
        "SELECT a.employee_id, e.full_name, e.position, e.store_code, "
        "       a.check_in_time, a.check_out_time, a.attend_date, "
        "       a.check_in_status, a.check_in_diff, a.check_out_status, a.check_out_diff "
        "FROM attendances a "
        "LEFT JOIN employees e ON e.id = a.employee_id "
        "WHERE " + " AND ".join(where_parts)
    )
    with db.cursor() as cur:
        cur.execute(sql, tuple(params))
        rows = cur.fetchall()

    # Aggregate
    summary: dict[int, dict[str, Any]] = {}
    for r in rows:
        emp_id = int(r["employee_id"])
        s = summary.setdefault(emp_id, {
            "employeeId": str(emp_id),
            "fullName": r.get("full_name") or "",
            "position": r.get("position") or "",
            "storeCode": r.get("store_code") or "",
            "daysWorked": 0,
            "totalHours": 0.0,
            "lateCount": 0,
            "lateMinutes": 0,
            "earlyLeaveCount": 0,
            "earlyLeaveMinutes": 0,
            "overtimeMinutes": 0,
            "_dates": set(),
        })
        if r.get("attend_date") and (r.get("check_in_time") or r.get("check_out_time")):
            s["_dates"].add(r["attend_date"])
        ci = r.get("check_in_time")
        co = r.get("check_out_time")
        if ci and co:
            try:
                t_in = datetime.fromisoformat(ci)
                t_out = datetime.fromisoformat(co)
                delta = (t_out - t_in).total_seconds()
                if delta > 0:
                    s["totalHours"] += delta / 3600.0
            except Exception:
                pass
        if (r.get("check_in_status") or "") == "late":
            s["lateCount"] += 1
            try:
                s["lateMinutes"] += int(r.get("check_in_diff") or 0)
            except Exception:
                pass
        if (r.get("check_out_status") or "") == "early_leave":
            s["earlyLeaveCount"] += 1
            try:
                s["earlyLeaveMinutes"] += abs(int(r.get("check_out_diff") or 0))
            except Exception:
                pass
        if (r.get("check_out_status") or "") == "overtime":
            try:
                s["overtimeMinutes"] += int(r.get("check_out_diff") or 0)
            except Exception:
                pass

    out = []
    for s in summary.values():
        s["daysWorked"] = len(s.pop("_dates"))
        s["totalHours"] = round(s["totalHours"], 1)
        out.append(s)
    out.sort(key=lambda x: x["fullName"].lower())
    return jsonify({
        "month": month,
        "storeCode": store_code,
        "canManage": can_manage,
        "rows": out,
    })


def _can_manage_attendance_user() -> bool:
    """Admin/Manager (and anyone whose position has can_manage_attendance) can edit/delete attendance rows."""
    user_id = (g.current_user or {}).get("user_id")
    if not user_id:
        return False
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT e.position, p.can_manage_attendance "
            "FROM users u "
            "LEFT JOIN employees e ON e.id = u.employee_id "
            "LEFT JOIN permissions p ON UPPER(p.position) = UPPER(e.position) "
            "WHERE u.id = %s",
            (user_id,),
        )
        row = cur.fetchone() or {}
    if row.get("can_manage_attendance"):
        return True
    pos = (row.get("position") or "").upper()
    return pos in {"ADM", "ADMIN", "MNG", "CS", "TMK"}


def _has_crud_permission() -> bool:
    """Admin, or anyone whose position/store-role has can_crud, may manage master data
    (employees, stores, products, shifts, schedules, store-managers)."""
    if _is_admin_user():
        return True
    user_id = (g.current_user or {}).get("user_id")
    if not user_id:
        return False
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT p.can_crud "
            "FROM users u "
            "LEFT JOIN employees e ON e.id = u.employee_id "
            "LEFT JOIN permissions p ON UPPER(p.position) = UPPER(e.position) "
            "WHERE u.id = %s",
            (user_id,),
        )
        row = cur.fetchone() or {}
    return bool(row.get("can_crud"))


def _forbidden():
    return jsonify({"error": "Forbidden"}), 403


def _allowed_store_codes_for_current_user() -> set[str] | None:
    """Store codes the caller may see: their own store plus any they manage
    via store_managers. Returns None for unrestricted access (admin/TMK).
    Mirrors PermissionProvider's client-side scoping (isAdmin -> all stores,
    else ownStoreCode + managedStoreIds) so the server enforces the same
    rule instead of trusting the client to filter."""
    if _is_admin_user():
        return None
    user_id = (g.current_user or {}).get("user_id")
    if not user_id:
        return set()
    db = get_db()
    codes: set[str] = set()
    with db.cursor() as cur:
        cur.execute(
            "SELECT e.store_code FROM users u LEFT JOIN employees e ON e.id = u.employee_id WHERE u.id = %s",
            (user_id,),
        )
        row = cur.fetchone() or {}
        own = (row.get("store_code") or "").strip().upper()
        if own:
            codes.add(own)
        cur.execute(
            "SELECT s.store_code FROM store_managers sm "
            "JOIN stores s ON s.id = sm.store_id "
            "JOIN users u ON u.employee_id = sm.employee_id "
            "WHERE u.id = %s",
            (user_id,),
        )
        for r in cur.fetchall():
            code = (r.get("store_code") or "").strip().upper()
            if code:
                codes.add(code)
    return codes


def _parse_attendance_time(value: Any, attend_date: str | None) -> str | None:
    """Accepts 'HH:MM', 'HH:MM:SS' or full ISO. Returns 'YYYY-MM-DDTHH:MM:SS' or None."""
    if value is None:
        return None
    s = str(value).strip()
    if not s:
        return None
    # Full ISO already
    if "T" in s and len(s) >= 16:
        return s[:19]
    if not attend_date:
        return None
    parts = s.split(":")
    try:
        hh = int(parts[0])
        mm = int(parts[1]) if len(parts) > 1 else 0
        ss = int(parts[2]) if len(parts) > 2 else 0
    except Exception:
        return None
    return f"{attend_date}T{hh:02d}:{mm:02d}:{ss:02d}"


@app.put("/api/attendances/<int:att_id>")
@login_required
def api_update_attendance(att_id: int):
    if not _can_manage_attendance_user():
        return jsonify({"error": "Forbidden"}), 403
    data = request.get_json(silent=True) or {}
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT id, attend_date FROM attendances WHERE id = %s",
            (att_id,),
        )
        existing = cur.fetchone()
        if not existing:
            return jsonify({"error": "Not found"}), 404
        attend_date = existing.get("attend_date")
        check_in_time = _parse_attendance_time(data.get("checkInTime"), attend_date) if "checkInTime" in data else None
        check_out_time = _parse_attendance_time(data.get("checkOutTime"), attend_date) if "checkOutTime" in data else None

        sets = []
        params: list[Any] = []
        if "checkInTime" in data:
            sets.append("check_in_time = %s")
            params.append(check_in_time)
        if "checkOutTime" in data:
            sets.append("check_out_time = %s")
            params.append(check_out_time)
        if not sets:
            return jsonify({"ok": True, "id": att_id})
        params.append(att_id)
        cur.execute(
            f"UPDATE attendances SET {', '.join(sets)} WHERE id = %s",
            tuple(params),
        )
    db.commit()
    return jsonify({"ok": True, "id": att_id})


@app.delete("/api/attendances/<int:att_id>")
@login_required
def api_delete_attendance(att_id: int):
    if not _can_manage_attendance_user():
        return jsonify({"error": "Forbidden"}), 403
    db = get_db()
    with db.cursor() as cur:
        cur.execute("DELETE FROM attendances WHERE id = %s", (att_id,))
    db.commit()
    return jsonify({"ok": True, "id": att_id})


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

def _post_visibility_where():
    """WHERE fragment + params restricting community_posts to ones the
    caller may see: not store-scoped, un-scoped, authored by them, or in a
    store they belong to/manage. Admins get no restriction (empty fragment).
    Mirrors the client-side filter in dao_tao_screen.dart's _buildCommunityPanel
    so a direct API call can't read another store's "store"-visibility posts."""
    user_id = (g.current_user or {}).get("user_id")
    allowed_codes = _allowed_store_codes_for_current_user()
    if allowed_codes is None:
        return "", []
    condition = "(p.visibility != 'store' OR p.store_code IS NULL OR p.store_code = '' OR p.author_id = %s"
    params = [user_id]
    if allowed_codes:
        condition += " OR UPPER(p.store_code) = ANY(%s::text[])"
        params.append(list(allowed_codes))
    condition += ")"
    return condition, params


@app.get("/api/posts")
@login_required
def api_get_posts():
    db = get_db()
    _ensure_posts_columns(db)
    user_id = (g.current_user or {}).get("user_id")
    where_sql, where_params = _post_visibility_where()
    query = (
        "SELECT p.id, p.author_id, p.author_name, p.content, p.image_url, p.images_json, p.video_url, "
        "p.visibility, p.store_code, p.like_count, p.comment_count, p.created_at, "
        "EXISTS(SELECT 1 FROM post_likes pl WHERE pl.post_id = p.id AND pl.user_id = %s) AS liked_by_me "
        "FROM community_posts p "
        f"{'WHERE ' + where_sql if where_sql else ''} "
        "ORDER BY p.id DESC LIMIT 100"
    )
    with db.cursor() as cur:
        cur.execute(query, [user_id, *where_params])
        rows = cur.fetchall()
    return jsonify([_post_to_api_json(r) for r in rows])

@app.post("/api/posts")
@login_required
def api_create_post():
    data = request.get_json(silent=True) or {}
    db = get_db()
    _ensure_posts_columns(db)
    author_id = g.current_user.get("user_id") if g.current_user else None
    author_name = _current_employee_info().get("full_name") or "Ẩn danh"
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
                    author_name,
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
    except Exception:
        db.rollback()
        app.logger.exception("Failed to create community post")
        return jsonify({"error": "Không thể đăng bài. Vui lòng thử lại."}), 400

@app.put("/api/posts/<int:post_id>")
@login_required
def api_update_post(post_id: int):
    data = request.get_json(silent=True) or {}
    db = get_db()
    _ensure_posts_columns(db)

    with db.cursor() as cur:
        cur.execute("SELECT author_id FROM community_posts WHERE id = %s", (post_id,))
        existing = cur.fetchone()
    if not existing:
        return jsonify({"error": "Not found"}), 404
    user_id = g.current_user.get("user_id")
    if existing.get("author_id") != user_id and not _is_admin_user():
        return _forbidden()

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
        cur.execute("SELECT author_id FROM community_posts WHERE id = %s", (post_id,))
        existing = cur.fetchone()
    if not existing:
        return jsonify({"error": "Not found"}), 404
    user_id = g.current_user.get("user_id")
    if existing.get("author_id") != user_id and not _is_admin_user():
        return _forbidden()

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
    g.current_user = user
    db = get_db()
    _ensure_posts_columns(db)
    with db.cursor() as cur:
        cur.execute(
            "SELECT video_url, visibility, store_code, author_id FROM community_posts WHERE id = %s", (post_id,)
        )
        row = cur.fetchone()
    if not row or not row.get("video_url"):
        return jsonify({"error": "no video"}), 404
    if not _can_view_post(row):
        return _forbidden()
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

def _can_view_post(post_row) -> bool:
    """True if the current caller (g.current_user) may view a post with
    this visibility/store_code/author_id — same rule _post_visibility_where()
    applies to the list endpoint, checked here per-post for the comment/video
    endpoints so a direct call can't bypass the "store" visibility scoping."""
    if (post_row.get("visibility") or "public") != "store":
        return True
    if post_row.get("author_id") == (g.current_user or {}).get("user_id"):
        return True
    store_code = (post_row.get("store_code") or "").strip()
    if not store_code:
        return True
    allowed_codes = _allowed_store_codes_for_current_user()
    if allowed_codes is None:
        return True
    return store_code.upper() in allowed_codes


@app.get("/api/posts/<int:post_id>/comments")
@login_required
def api_get_comments(post_id: int):
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT visibility, store_code, author_id FROM community_posts WHERE id = %s",
            (post_id,),
        )
        post = cur.fetchone()
    if not post:
        return jsonify({"error": "Not found"}), 404
    if not _can_view_post(post):
        return _forbidden()
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
    author_name = _current_employee_info().get("full_name") or "Ẩn danh"
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO comments (post_id, author_name, content) VALUES (%s, %s, %s) "
            "RETURNING id, author_name, content, created_at",
            (post_id, author_name, data.get("text", "")),
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
        cur.execute("ALTER TABLE quiz_results ADD COLUMN IF NOT EXISTS passed BOOLEAN")
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


@app.get("/api/ai-tools")
@login_required
def api_get_ai_tools():
    db = get_db()
    with db.cursor() as cur:
        cur.execute("SELECT id, name, link FROM ai_tools ORDER BY id ASC")
        rows = cur.fetchall()
    return jsonify([{"id": r["id"], "name": r["name"], "link": r.get("link")} for r in rows])


@app.post("/api/ai-tools")
@login_required
def api_create_ai_tool():
    if not _is_admin_user():
        return jsonify({"error": "Forbidden"}), 403
    data = request.get_json(silent=True) or {}
    name = (data.get("name") or "").strip()
    if not name:
        return jsonify({"error": "name required"}), 400
    link = (data.get("link") or "").strip() or None
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO ai_tools (name, link) VALUES (%s, %s) RETURNING id, name, link",
            (name, link),
        )
        row = cur.fetchone()
    db.commit()
    return jsonify({"id": row["id"], "name": row["name"], "link": row.get("link")}), 201


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


def _can_view_lesson(target_role: str | None) -> bool:
    """A lesson targeted at a specific position (PG/TLD/ADM) is only for
    employees in that position; 'ALL' (or unset) is open to everyone.
    Admins can always see every lesson so they can manage it regardless
    of who it's targeted at."""
    role = (target_role or "ALL").upper()
    if role == "ALL" or _is_admin_user():
        return True
    position = (_current_employee_info().get("position") or "").upper()
    return position == role


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
        lessons = [l for l in cur.fetchall() if _can_view_lesson(l.get("target_role"))]
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
        if not _can_view_lesson(row.get("target_role")):
            return _forbidden()
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
    g.current_user = user
    db = get_db()
    _ensure_training_tables(db)
    with db.cursor() as cur:
        cur.execute(
            "SELECT video_path FROM lesson_parts WHERE id = %s AND lesson_id = %s",
            (part_id, lesson_id),
        )
        row = cur.fetchone()
        cur.execute("SELECT target_role FROM lessons WHERE id = %s", (lesson_id,))
        lesson_row = cur.fetchone()
    if not row or not row.get("video_path"):
        return jsonify({"error": "no video"}), 404
    if not lesson_row or not _can_view_lesson(lesson_row.get("target_role")):
        return _forbidden()
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
        cur.execute("SELECT target_role FROM lessons WHERE id = %s", (resolved_lesson_id,))
        lesson_row = cur.fetchone()
        if not lesson_row:
            return jsonify({"error": "Lesson not found"}), 404
        if not _can_view_lesson(lesson_row.get("target_role")):
            return _forbidden()
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
    passed = score_percent >= QUIZ_PASS_THRESHOLD
    user = _current_employee_info()
    submitted_at = datetime.now(VN_TZ).strftime("%Y-%m-%d %H:%M:%S")
    employee_code = user["employee_code"]
    full_name = user["full_name"]
    _, resolved_store_name = _get_store_info_by_code(db, user.get("store_code"))
    store_name = resolved_store_name or user["store_code"]
    score_text = f"{earned}/{total}"
    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO quiz_results (submitted_at, employee_code, full_name, store_name, content_id, score, answers_json, passed) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s, %s) RETURNING id",
            (submitted_at, employee_code, full_name, store_name, content_id, score_text, json.dumps(answers), passed),
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
        "passed": passed,
        "submittedAt": submitted_at,
    }), 201


@app.post("/api/lessons/parts/<int:part_id>/watch")
@login_required
def api_mark_part_watched(part_id: int):
    """Record completion for a video-only part (no quiz) once its video has
    played to the end, so progress can reach 100% for lessons that include
    parts with nothing to quiz on. Parts that do have a quiz must still be
    completed by actually submitting it — this route 400s for those."""
    db = get_db()
    _ensure_training_tables(db)
    with db.cursor() as cur:
        cur.execute("SELECT lesson_id FROM lesson_parts WHERE id = %s", (part_id,))
        prow = cur.fetchone()
    if not prow:
        return jsonify({"error": "Part not found"}), 404
    lesson_id = prow["lesson_id"]
    content_id = f"part_{part_id}"
    with db.cursor() as cur:
        cur.execute("SELECT target_role FROM lessons WHERE id = %s", (lesson_id,))
        lesson_row = cur.fetchone()
        if not lesson_row or not _can_view_lesson(lesson_row.get("target_role")):
            return _forbidden()
        cur.execute("SELECT COUNT(*) AS c FROM quiz_questions WHERE content_id = %s", (content_id,))
        if (cur.fetchone() or {}).get("c"):
            return jsonify({"error": "Part has a quiz; submit the quiz instead"}), 400
    user = _current_employee_info()
    employee_code = user["employee_code"]
    with db.cursor() as cur:
        cur.execute(
            "SELECT 1 FROM quiz_results WHERE content_id = %s AND employee_code = %s LIMIT 1",
            (content_id, employee_code),
        )
        if cur.fetchone():
            return jsonify({"ok": True})
    submitted_at = datetime.now(VN_TZ).strftime("%Y-%m-%d %H:%M:%S")
    full_name = user["full_name"]
    _, resolved_store_name = _get_store_info_by_code(db, user.get("store_code"))
    store_name = resolved_store_name or user["store_code"]
    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO quiz_results (submitted_at, employee_code, full_name, store_name, content_id, score, answers_json, passed) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
            (submitted_at, employee_code, full_name, store_name, content_id, "Đã xem", "{}", True),
        )
    db.commit()
    return jsonify({"ok": True})


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
        "SELECT r.id, r.submitted_at, r.employee_code, r.full_name, r.store_name, r.content_id, r.score, r.passed "
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
            "passed": r.get("passed"),
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
            "SELECT r.id, r.submitted_at, r.employee_code, r.full_name, r.store_name, r.content_id, r.score, r.passed "
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
            "passed": r.get("passed"),
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
    if not _is_admin_user():
        return _forbidden()
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
    if not _is_admin_user():
        return _forbidden()
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


# ---------------------------------------------------------------------------
# Zalo Mini App: Zalo account linking + task assignment / store work tracking
# ---------------------------------------------------------------------------

ZALO_GRAPH_ME_URL = "https://graph.zalo.me/v2.0/me?fields=id,name,picture"
ZALO_OA_SEND_URL = "https://openapi.zalo.me/v3.0/oa/message/cs"
ZALO_OA_ACCESS_TOKEN = os.getenv("ZALO_OA_ACCESS_TOKEN", "")
# Default under POST_VIDEO_DIR: that path is a mounted Docker volume (see
# scripts/bismart-vps-compose.example.yml), so photos survive container recreation.
TASK_PHOTO_DIR = Path(os.getenv("TASK_PHOTO_DIR", str(POST_VIDEO_DIR / "task_photos")))
try:
    TASK_PHOTO_DIR.mkdir(parents=True, exist_ok=True)
except Exception:
    TASK_PHOTO_DIR = Path(os.getenv("BASE_DIR", ".")) / "task_photos"
    TASK_PHOTO_DIR.mkdir(parents=True, exist_ok=True)
ALLOWED_PHOTO_EXT = {".jpg", ".jpeg", ".png", ".webp", ".heic"}
MAX_PHOTO_BYTES = 10 * 1024 * 1024
TASK_STATUSES = ("todo", "doing", "done", "cancelled")
TASK_PRIORITIES = ("low", "normal", "high", "urgent")
TASK_RECURRENCES = ("none", "daily", "weekly")


def _now_iso() -> str:
    return datetime.now(tz=VN_TZ).strftime("%Y-%m-%dT%H:%M:%S")


def _verify_zalo_access_token(access_token: str) -> dict | None:
    """Resolve a Mini App access token to the Zalo user via the Graph API, so
    the Zalo ID is never taken on the client's word."""
    if not access_token:
        return None
    req = urllib.request.Request(ZALO_GRAPH_ME_URL, headers={"access_token": access_token})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            body = json.loads(resp.read().decode("utf-8"))
    except Exception:
        return None
    if not isinstance(body, dict) or body.get("error") or not body.get("id"):
        return None
    return body


ZALO_OA_ID = os.getenv("ZALO_OA_ID", "")
ZALO_OA_APP_ID = os.getenv("ZALO_OA_APP_ID", "")
ZALO_OA_SECRET_KEY = os.getenv("ZALO_OA_SECRET_KEY", "")
ZALO_OA_REFRESH_TOKEN = os.getenv("ZALO_OA_REFRESH_TOKEN", "")
ZALO_OA_WEBHOOK_KEY = os.getenv("ZALO_OA_WEBHOOK_KEY", "")
ZALO_OA_TOKEN_URL = "https://oauth.zaloapp.com/v4/oa/access_token"
# Event-driven kinds worth a phone push. Reminders ('overdue', 'due_soon') are only generated while the app is
# open, so pushing those would be pointless.
OA_PUSH_KINDS = {"assigned", "fund_diff"}


_OA_REFRESH_FAILED_AT = [0.0]


def _oa_load_tokens() -> dict:
    db = get_db()
    with db.cursor() as cur:
        cur.execute("SELECT access_token, refresh_token, expires_at, oa_id FROM zalo_oa_tokens WHERE id = 1")
        row = cur.fetchone()
    if row:
        return dict(row)
    seed = {"access_token": ZALO_OA_ACCESS_TOKEN or None, "refresh_token": ZALO_OA_REFRESH_TOKEN or None, "expires_at": None}
    if seed["access_token"] or seed["refresh_token"]:
        with db.cursor() as cur:
            cur.execute("INSERT INTO zalo_oa_tokens (id, access_token, refresh_token, expires_at, updated_at) "
                        "VALUES (1,%s,%s,NULL,%s) ON CONFLICT (id) DO NOTHING", (seed["access_token"], seed["refresh_token"], _now_iso()))
        db.commit()
    return seed


def _oa_refresh(tokens: dict) -> dict | None:
    """Exchange the refresh token for a new pair (the refresh token rotates, so both are stored)."""
    if not (ZALO_OA_APP_ID and ZALO_OA_SECRET_KEY and tokens.get("refresh_token")):
        return None
    body = urllib.parse.urlencode({"app_id": ZALO_OA_APP_ID, "grant_type": "refresh_token",
                                   "refresh_token": tokens["refresh_token"]}).encode()
    req = urllib.request.Request(ZALO_OA_TOKEN_URL, data=body, headers={
        "secret_key": ZALO_OA_SECRET_KEY, "Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception:
        return None
    if not isinstance(data, dict) or not data.get("access_token"):
        return None
    try:
        ttl = int(data.get("expires_in") or 90000)
    except (TypeError, ValueError):
        ttl = 90000
    new = {"access_token": data["access_token"], "refresh_token": data.get("refresh_token") or tokens["refresh_token"],
           "expires_at": (datetime.now(tz=VN_TZ) + timedelta(seconds=ttl)).strftime("%Y-%m-%dT%H:%M:%S")}
    db = get_db()
    with db.cursor() as cur:
        cur.execute("INSERT INTO zalo_oa_tokens (id, access_token, refresh_token, expires_at, updated_at) VALUES (1,%s,%s,%s,%s) "
                    "ON CONFLICT (id) DO UPDATE SET access_token=EXCLUDED.access_token, refresh_token=EXCLUDED.refresh_token, "
                    "expires_at=EXCLUDED.expires_at, updated_at=EXCLUDED.updated_at",
                    (new["access_token"], new["refresh_token"], new["expires_at"], _now_iso()))
    db.commit()
    return new


def _oa_access_token(force_refresh: bool = False) -> str:
    """A usable OA access token, refreshed when it is close to expiry. Empty string when OA is not configured."""
    tokens = _oa_load_tokens()
    soon = (datetime.now(tz=VN_TZ) + timedelta(minutes=10)).strftime("%Y-%m-%dT%H:%M:%S")
    # An unknown expiry (token seeded from env) counts as stale so the real lifetime gets recorded.
    stale = force_refresh or not tokens.get("access_token") or not tokens.get("expires_at") or tokens["expires_at"] <= soon
    if stale and time.time() - _OA_REFRESH_FAILED_AT[0] > 300:
        fresh = _oa_refresh(tokens)
        if fresh:
            return fresh["access_token"]
        _OA_REFRESH_FAILED_AT[0] = time.time()  # back off for 5 minutes instead of retrying on every notification
    return tokens.get("access_token") or ""


def _oa_send_text(zalo_user_id: str, text: str) -> tuple[bool, str]:
    """POST one OA consultation message. Returns (ok, raw detail) so callers can log or show the Zalo answer."""
    token = _oa_access_token()
    if not token:
        return False, "OA not configured"
    payload = json.dumps({"recipient": {"user_id": zalo_user_id}, "message": {"text": text[:1900]}}).encode("utf-8")
    req = urllib.request.Request(ZALO_OA_SEND_URL, data=payload,
                                 headers={"Content-Type": "application/json", "access_token": token})
    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            raw = resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", "replace")
    except Exception as e:
        return False, f"{type(e).__name__}: {e}"
    try:
        err = json.loads(raw).get("error", 0)
    except ValueError:
        err = -1
    return err == 0, raw[:500]


def _notify_zalo(employee_id: int | None, text: str) -> None:
    """Best-effort OA push to an employee's phone. Never raises: a notification failure must not fail the
    write that triggered it. Uses the OA-scoped id when known, else the Mini App id."""
    if not employee_id or not (ZALO_OA_ACCESS_TOKEN or ZALO_OA_REFRESH_TOKEN or ZALO_OA_APP_ID):
        return
    try:
        db = get_db()
        with db.cursor() as cur:
            cur.execute("SELECT zalo_id, zalo_oa_id FROM employees WHERE id = %s", (employee_id,))
            row = cur.fetchone() or {}
        target = row.get("zalo_oa_id") or row.get("zalo_id")
        if not target:
            return
        ok, detail = _oa_send_text(str(target), text)
        with db.cursor() as cur:
            cur.execute("INSERT INTO zalo_oa_push_log (employee_id, ok, detail, created_at) VALUES (%s,%s,%s,%s)",
                        (employee_id, 1 if ok else 0, detail[:500], _now_iso()))
        db.commit()
    except Exception:
        try:
            get_db().rollback()
        except Exception:
            pass


def _fmt_due(iso: str | None) -> str:
    """'2026-10-02T17:00:00' -> '17:00 02/10' for human-readable messages."""
    try:
        d = datetime.strptime((iso or "")[:16], "%Y-%m-%dT%H:%M")
        return d.strftime("%H:%M %d/%m")
    except ValueError:
        return (iso or "").replace("T", " ")[:16]


def _notify(employee_id: int | None, kind: str, title: str, body: str = "", task_id: int | None = None,
            dedupe_key: str | None = None, push: bool = True, link: str | None = None) -> None:
    """Store an in-app notification (shown under the bell) and mirror it to Zalo OA when configured.
    A repeated dedupe_key for the same employee is ignored, which keeps reminders from piling up."""
    if not employee_id:
        return
    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute(
                "INSERT INTO notifications (employee_id, kind, title, body, task_id, dedupe_key, created_at, link) "
                "VALUES (%s,%s,%s,%s,%s,%s,%s,%s) ON CONFLICT (employee_id, dedupe_key) DO NOTHING RETURNING id",
                (employee_id, kind, title[:200], body[:500], task_id, dedupe_key, _now_iso(), link),
            )
            inserted = cur.fetchone()
        db.commit()
    except Exception:
        db.rollback()
        return
    if inserted and push and kind in OA_PUSH_KINDS:
        _notify_zalo(employee_id, f"{title}\n{body}".strip())


def _sync_task_reminders(employee_id: int) -> None:
    """Lazily create 'due soon' / 'overdue' notifications for the employee's open tasks."""
    now = datetime.now(tz=VN_TZ)
    now_iso = now.strftime("%Y-%m-%dT%H:%M:%S")
    soon_iso = (now + timedelta(hours=24)).strftime("%Y-%m-%dT%H:%M:%S")
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT id, title, due_at FROM tasks WHERE assignee_id = %s AND status IN ('todo','doing') "
            "AND due_at IS NOT NULL AND due_at <= %s",
            (employee_id, soon_iso),
        )
        rows = cur.fetchall()
    for r in rows:
        due_txt = _fmt_due(r["due_at"])
        if r["due_at"] < now_iso:
            _notify(employee_id, "overdue", "Việc đã quá hạn", f"{r['title']} · hạn {due_txt}", r["id"],
                    f"overdue:{r['id']}:{r['due_at']}")
        else:
            _notify(employee_id, "due_soon", "Việc sắp đến hạn", f"{r['title']} · hạn {due_txt}", r["id"],
                    f"due_soon:{r['id']}:{r['due_at']}")


def _sync_all_reminders(employee_id: int) -> None:
    """Everything that is generated lazily when the bell is polled."""
    _sync_task_reminders(employee_id)
    try:
        _sync_ops_reminders(employee_id)
    except Exception:
        get_db().rollback()


def _notification_to_api_json(row: dict) -> dict:
    return {
        "id": row["id"],
        "kind": row.get("kind") or "info",
        "title": row.get("title") or "",
        "body": row.get("body") or "",
        "taskId": row.get("task_id"),
        "link": row.get("link"),
        "isRead": bool(row.get("is_read")),
        "createdAt": row.get("created_at"),
    }


def _unread_count(employee_id: int) -> int:
    with get_db().cursor() as cur:
        cur.execute("SELECT COUNT(*) AS c FROM notifications WHERE employee_id = %s AND is_read = 0", (employee_id,))
        return int(cur.fetchone()["c"])


@app.get("/api/notifications/unread-count")
@login_required
def api_notifications_unread_count():
    emp = (g.current_user or {}).get("employee_id")
    if not emp:
        return jsonify({"unread": 0})
    _sync_all_reminders(emp)
    return jsonify({"unread": _unread_count(emp)})


@app.get("/api/notifications")
@login_required
def api_list_notifications():
    emp = (g.current_user or {}).get("employee_id")
    if not emp:
        return jsonify({"items": [], "unread": 0})
    _sync_all_reminders(emp)
    cutoff = (datetime.now(tz=VN_TZ) - timedelta(days=60)).strftime("%Y-%m-%dT%H:%M:%S")
    db = get_db()
    with db.cursor() as cur:
        cur.execute("DELETE FROM notifications WHERE employee_id = %s AND created_at < %s", (emp, cutoff))
        cur.execute(
            "SELECT id, kind, title, body, task_id, link, is_read, created_at FROM notifications "
            "WHERE employee_id = %s ORDER BY id DESC LIMIT 60",
            (emp,),
        )
        rows = cur.fetchall()
    db.commit()
    return jsonify({"items": [_notification_to_api_json(r) for r in rows], "unread": _unread_count(emp)})


@app.post("/api/notifications/read")
@login_required
def api_mark_notifications_read():
    """Mark the given ids (or all, when `ids` is omitted) as read for the caller."""
    emp = (g.current_user or {}).get("employee_id")
    if not emp:
        return jsonify({"unread": 0})
    ids = (request.get_json(silent=True) or {}).get("ids")
    db = get_db()
    with db.cursor() as cur:
        if isinstance(ids, list) and ids:
            clean = [int(i) for i in ids if str(i).isdigit()][:200]
            cur.execute(
                "UPDATE notifications SET is_read = 1 WHERE employee_id = %s AND is_read = 0 AND id = ANY(%s)",
                (emp, clean),
            )
        else:
            cur.execute("UPDATE notifications SET is_read = 1 WHERE employee_id = %s AND is_read = 0", (emp,))
    db.commit()
    return jsonify({"unread": _unread_count(emp)})


@app.post("/api/auth/zalo-link")
@login_required
def api_zalo_link():
    """Bind the Zalo account of a Mini App session to the logged-in employee."""
    data = request.get_json(silent=True) or {}
    zalo = _verify_zalo_access_token((data.get("accessToken") or "").strip())
    if not zalo:
        return jsonify({"error": "Invalid Zalo access token"}), 400
    employee_id = (g.current_user or {}).get("employee_id")
    if not employee_id:
        return jsonify({"error": "Account has no employee profile"}), 400
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT id FROM employees WHERE zalo_id = %s AND id <> %s",
            (str(zalo["id"]), employee_id),
        )
        if cur.fetchone():
            return jsonify({"error": "Zalo account already linked to another employee"}), 409
        cur.execute("UPDATE employees SET zalo_id = %s WHERE id = %s", (str(zalo["id"]), employee_id))
        # A follow event may have arrived before the employee was linked: apply the stored pair now.
        cur.execute("SELECT oa_user FROM zalo_oa_pending WHERE app_user = %s", (str(zalo["id"]),))
        pend = cur.fetchone()
        if pend:
            cur.execute("UPDATE employees SET zalo_oa_id = %s WHERE id = %s", (pend["oa_user"], employee_id))
    db.commit()
    return jsonify({"ok": True})


ZALO_OA_PERMISSION_URL = "https://oauth.zaloapp.com/v4/oa/permission"
ZALO_OA_REDIRECT_URI = os.getenv("ZALO_OA_REDIRECT_URI", "https://api.bismart.id.vn/api/zalo/oa-callback")


@app.post("/api/zalo/oa-connect")
@login_required
def api_zalo_oa_connect():
    """Admin: start the OA authorisation (OAuth v4 with PKCE). Returns the Zalo consent URL; once the OA admin
    approves, Zalo redirects to /api/zalo/oa-callback and the tokens are stored server-side."""
    import base64, hashlib, secrets
    if not _is_admin_user():
        return _forbidden()
    if not (ZALO_OA_APP_ID and ZALO_OA_SECRET_KEY):
        return jsonify({"error": "OA app is not configured"}), 400
    verifier = secrets.token_urlsafe(48)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    state = secrets.token_urlsafe(16)
    db = get_db()
    with db.cursor() as cur:
        cur.execute("DELETE FROM zalo_oa_oauth WHERE created_at < %s", ((datetime.now(tz=VN_TZ) - timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%S"),))
        cur.execute("INSERT INTO zalo_oa_oauth (state, verifier, created_at) VALUES (%s,%s,%s)", (state, verifier, _now_iso()))
    db.commit()
    url = ZALO_OA_PERMISSION_URL + "?" + urllib.parse.urlencode({
        "app_id": ZALO_OA_APP_ID, "redirect_uri": ZALO_OA_REDIRECT_URI, "code_challenge": challenge, "state": state})
    return jsonify({"url": url})


def _oa_callback_page(ok: bool, message: str) -> Response:
    color = "#4c7a5d" if ok else "#b14a3d"
    html = (f'<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
            f'<body style="font-family:-apple-system,sans-serif;text-align:center;padding:60px 24px;background:#fbf7f1;color:#2b2118">'
            f'<h2 style="color:{color}">{"Đã kết nối OA" if ok else "Kết nối OA chưa thành công"}</h2><p>{_xml_escape(message)}</p>'
            f'<p>Bạn có thể đóng trang này và quay lại ứng dụng.</p></body>')
    return Response(html, mimetype="text/html; charset=utf-8", status=200 if ok else 400)


@app.get("/api/zalo/oa-callback")
def api_zalo_oa_callback():
    """Zalo redirects the OA admin here with ?code=...&oa_id=...&state=...; exchange the code for the token pair."""
    code, state, oa_id = request.args.get("code", ""), request.args.get("state", ""), request.args.get("oa_id", "")
    if not (code and state):
        return _oa_callback_page(False, "Thiếu mã uỷ quyền từ Zalo.")
    db = get_db()
    with db.cursor() as cur:
        cur.execute("SELECT verifier, created_at FROM zalo_oa_oauth WHERE state = %s", (state,))
        row = cur.fetchone()
        cur.execute("DELETE FROM zalo_oa_oauth WHERE state = %s", (state,))
    db.commit()
    if not row or row["created_at"] < (datetime.now(tz=VN_TZ) - timedelta(minutes=30)).strftime("%Y-%m-%dT%H:%M:%S"):
        return _oa_callback_page(False, "Phiên kết nối đã hết hạn hoặc không hợp lệ. Hãy bấm Kết nối OA lại.")
    body = urllib.parse.urlencode({"code": code, "app_id": ZALO_OA_APP_ID, "grant_type": "authorization_code",
                                   "code_verifier": row["verifier"]}).encode()
    req = urllib.request.Request(ZALO_OA_TOKEN_URL, data=body, headers={
        "secret_key": ZALO_OA_SECRET_KEY, "Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        return _oa_callback_page(False, f"Không đổi được mã với Zalo ({type(e).__name__}).")
    if not isinstance(data, dict) or not data.get("access_token"):
        return _oa_callback_page(False, f"Zalo từ chối: {json.dumps(data, ensure_ascii=False)[:200]}")
    try:
        ttl = int(data.get("expires_in") or 3600)
    except (TypeError, ValueError):
        ttl = 3600
    expires = (datetime.now(tz=VN_TZ) + timedelta(seconds=ttl)).strftime("%Y-%m-%dT%H:%M:%S")
    with db.cursor() as cur:
        cur.execute("INSERT INTO zalo_oa_tokens (id, access_token, refresh_token, expires_at, updated_at, oa_id) VALUES (1,%s,%s,%s,%s,%s) "
                    "ON CONFLICT (id) DO UPDATE SET access_token=EXCLUDED.access_token, refresh_token=EXCLUDED.refresh_token, "
                    "expires_at=EXCLUDED.expires_at, updated_at=EXCLUDED.updated_at, oa_id=COALESCE(NULLIF(EXCLUDED.oa_id,''), zalo_oa_tokens.oa_id)",
                    (data["access_token"], data.get("refresh_token"), expires, _now_iso(), oa_id))
    db.commit()
    _OA_REFRESH_FAILED_AT[0] = 0.0
    return _oa_callback_page(True, "Hệ thống đã nhận quyền gửi tin của OA và sẽ tự gia hạn.")


@app.get("/api/zalo/oa-info")
@login_required
def api_zalo_oa_info():
    """What the Mini App needs to offer 'follow our OA' (no secrets)."""
    return jsonify({"oaId": ZALO_OA_ID or (_oa_load_tokens().get("oa_id") or "")})


@app.post("/api/zalo/oa-webhook")
def api_zalo_oa_webhook():
    """Receives OA events. A follow/message event carries the user's OA-side id next to the Mini App id, which is
    how an employee is tied to the id the OA can message. Protected by a secret in the URL (?k=...)."""
    import hmac
    if not ZALO_OA_WEBHOOK_KEY:
        return jsonify({"error": "Webhook not configured"}), 503
    if not hmac.compare_digest(request.args.get("k", ""), ZALO_OA_WEBHOOK_KEY):
        return jsonify({"error": "Forbidden"}), 403
    data = request.get_json(silent=True) or {}
    db = get_db()
    follower = data.get("follower") or {}
    sender = data.get("sender") or {}
    oa_user = str(follower.get("id") or sender.get("id") or data.get("user_id") or "")
    app_user = str(data.get("user_id_by_app") or follower.get("user_id_by_app") or sender.get("user_id_by_app") or "")
    mapped = 0
    if oa_user and app_user:
        with db.cursor() as cur:
            cur.execute("UPDATE employees SET zalo_oa_id = %s WHERE zalo_id = %s AND COALESCE(zalo_oa_id,'') <> %s",
                        (oa_user, app_user, oa_user))
            mapped = cur.rowcount
            cur.execute("INSERT INTO zalo_oa_pending (app_user, oa_user, created_at) VALUES (%s,%s,%s) "
                        "ON CONFLICT (app_user) DO UPDATE SET oa_user = EXCLUDED.oa_user, created_at = EXCLUDED.created_at",
                        (app_user, oa_user, _now_iso()))
    # Remember who interacted with the OA: a follow, or a message from the user (the OA's own messages carry the
    # user as recipient and are not an interaction).
    event = str(data.get("event_name") or "")
    seen_user = ""
    if event in ("follow", "unfollow"):
        seen_user = str(follower.get("id") or "")
    elif event.startswith("user_send_") or event.startswith("user_click_") or event.startswith("user_submit_"):
        seen_user = str(sender.get("id") or "")
    if seen_user:
        with db.cursor() as cur:
            cur.execute("INSERT INTO oa_seen_users (user_id, first_seen, last_interaction, followed, app_user) VALUES (%s,%s,%s,%s,%s) "
                        "ON CONFLICT (user_id) DO UPDATE SET last_interaction = EXCLUDED.last_interaction, "
                        "app_user = COALESCE(NULLIF(EXCLUDED.app_user,''), oa_seen_users.app_user), "
                        "followed = CASE WHEN %s = 'unfollow' THEN 0 WHEN %s = 'follow' THEN 1 ELSE oa_seen_users.followed END",
                        (seen_user, _now_iso(), _now_iso(), 0 if event == "unfollow" else 1, app_user, event, event))
    with db.cursor() as cur:
        cur.execute("INSERT INTO zalo_oa_push_log (employee_id, ok, detail, created_at) VALUES (NULL, 2, %s, %s)",
                    (("webhook " + json.dumps(data, ensure_ascii=False))[:500], _now_iso()))
    db.commit()
    return jsonify({"ok": True, "mapped": mapped})


@app.get("/api/zalo/oa-status")
@login_required
def api_zalo_oa_status():
    if not _is_admin_user():
        return _forbidden()
    tokens = _oa_load_tokens()
    db = get_db()
    with db.cursor() as cur:
        cur.execute("SELECT COUNT(*) FILTER (WHERE zalo_id IS NOT NULL) AS linked, "
                    "COUNT(*) FILTER (WHERE zalo_oa_id IS NOT NULL) AS oa_mapped, COUNT(*) AS total "
                    "FROM employees WHERE is_active = 1")
        counts = cur.fetchone()
    return jsonify({
        "configured": bool(tokens.get("access_token") or tokens.get("refresh_token")),
        "canRefresh": bool(ZALO_OA_APP_ID and ZALO_OA_SECRET_KEY and tokens.get("refresh_token")),
        "oaId": ZALO_OA_ID or (tokens.get("oa_id") or ""), "webhookKey": bool(ZALO_OA_WEBHOOK_KEY),
        "appConfigured": bool(ZALO_OA_APP_ID and ZALO_OA_SECRET_KEY),
        "tokenExpiresAt": tokens.get("expires_at"),
        "employees": {"total": counts["total"], "zaloLinked": counts["linked"], "oaMapped": counts["oa_mapped"]},
    })


@app.post("/api/zalo/oa-test")
@login_required
def api_zalo_oa_test():
    """Admin: send a test message to the caller's own Zalo and show Zalo's raw answer."""
    if not _is_admin_user():
        return _forbidden()
    employee_id = (g.current_user or {}).get("employee_id")
    db = get_db()
    with db.cursor() as cur:
        cur.execute("SELECT zalo_id, zalo_oa_id FROM employees WHERE id = %s", (employee_id,))
        row = cur.fetchone() or {}
    target = row.get("zalo_oa_id") or row.get("zalo_id")
    if not target:
        return jsonify({"error": "Tài khoản này chưa liên kết Zalo. Hãy thoát app, mở lại từ Zalo rồi thử lại.", "ok": False, "detail": "not linked", "target": None}), 400
    ok, detail = _oa_send_text(str(target), "Tin thử từ Bi'S MART Công việc. Nếu bạn thấy tin này trên điện thoại thì thông báo đẩy đã hoạt động.")
    with db.cursor() as cur:
        cur.execute("INSERT INTO zalo_oa_push_log (employee_id, ok, detail, created_at) VALUES (%s,%s,%s,%s)",
                    (employee_id, 1 if ok else 0, ("test " + detail)[:500], _now_iso()))
    db.commit()
    return jsonify({"ok": ok, "detail": detail, "target": "oa" if row.get("zalo_oa_id") else "mini-app"})


ZALO_OA_USERLIST_URL = "https://openapi.zalo.me/v3.0/oa/user/getlist"
OA_CARE_PERIODS = {"TODAY", "YESTERDAY", "L7D", "L30D", "ALL"}
OA_CARE_MAX_RECIPIENTS = int(os.getenv("OA_CARE_MAX_RECIPIENTS", "1000"))
OA_CARE_DAILY_MAX = int(os.getenv("OA_CARE_DAILY_MAX", "3000"))


def _oa_call_json(url: str, payload: dict | None = None, query: dict | None = None) -> tuple[bool, dict, str]:
    """One OA API call. Zalo answers HTTP 200 with {"error": code, "message": ...}; ok means error == 0."""
    token = _oa_access_token()
    if not token:
        return False, {}, "OA not configured"
    if query:
        url += "?" + urllib.parse.urlencode(query)
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    headers = {"access_token": token}
    if data is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            raw = resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", "replace")
    except Exception as e:
        return False, {}, f"{type(e).__name__}: {e}"
    try:
        obj = json.loads(raw)
    except ValueError:
        return False, {}, raw[:300]
    return obj.get("error", 0) == 0, obj, raw[:500]


def _oa_follower_ids(period: str, limit: int = OA_CARE_MAX_RECIPIENTS) -> tuple[list[str], int | None, str]:
    """OA-scoped ids of followers, optionally limited to those who interacted recently. Returns (ids, total, error)."""
    ids: list[str] = []
    total = None
    offset = 0
    while len(ids) < limit:
        data = {"offset": offset, "count": 50, "is_follower": "true"}
        if period != "ALL":
            data["last_interaction_period"] = period
        ok, obj, raw = _oa_call_json(ZALO_OA_USERLIST_URL, query={"data": json.dumps(data)})
        if not ok:
            return ids, total, raw
        body = obj.get("data") or {}
        users = body.get("users") or []
        total = body.get("total", total)
        ids += [str(u.get("user_id")) for u in users if u.get("user_id")]
        if len(users) < 50:
            break
        offset += 50
    return ids[:limit], total, ""


def _oa_seen_ids(period: str, limit: int = OA_CARE_MAX_RECIPIENTS) -> list[str]:
    """Followers recorded from webhook events (follow / user messages), filtered by last interaction day."""
    now = datetime.now(tz=VN_TZ)
    today = now.replace(hour=0, minute=0, second=0, microsecond=0)
    fmt = "%Y-%m-%dT%H:%M:%S"
    where, args = "followed = 1", []
    if period == "TODAY":
        where += " AND last_interaction >= %s"; args.append(today.strftime(fmt))
    elif period == "YESTERDAY":
        where += " AND last_interaction >= %s AND last_interaction < %s"; args += [(today - timedelta(days=1)).strftime(fmt), today.strftime(fmt)]
    elif period == "L7D":
        where += " AND last_interaction >= %s"; args.append((now - timedelta(days=7)).strftime(fmt))
    elif period == "L30D":
        where += " AND last_interaction >= %s"; args.append((now - timedelta(days=30)).strftime(fmt))
    with get_db().cursor() as cur:
        cur.execute(f"SELECT user_id FROM oa_seen_users WHERE {where} ORDER BY last_interaction DESC LIMIT %s", (*args, limit))
        return [r["user_id"] for r in cur.fetchall()]


def _backfill_seen_from_log() -> int:
    """Webhook events logged before oa_seen_users existed still hold the sender/follower id in their first 500
    characters. Replay them once so earlier messages count as interactions."""
    db = get_db()
    with db.cursor() as cur:
        cur.execute("SELECT detail, created_at FROM zalo_oa_push_log WHERE ok = 2 ORDER BY id")
        rows = cur.fetchall()
    added = 0
    for r in rows:
        d = r["detail"] or ""
        ev = re.search(r'"event_name":\s*"([^"]+)"', d)
        if not ev:
            continue
        name = ev.group(1)
        if name in ("follow", "unfollow"):
            m = re.search(r'"follower":\s*\{\s*"id":\s*"(\d+)"', d)
        elif name.startswith(("user_send_", "user_click_", "user_submit_")):
            m = re.search(r'"sender":\s*\{\s*"id":\s*"(\d+)"', d)
        else:
            continue
        if not m:
            continue
        with db.cursor() as cur:
            ap = re.search(r'"user_id_by_app":\s*"(\d+)"', d)
            cur.execute("INSERT INTO oa_seen_users (user_id, first_seen, last_interaction, followed, app_user) VALUES (%s,%s,%s,%s,%s) "
                        "ON CONFLICT (user_id) DO UPDATE SET last_interaction = GREATEST(oa_seen_users.last_interaction, EXCLUDED.last_interaction), "
                        "followed = EXCLUDED.followed, app_user = COALESCE(NULLIF(EXCLUDED.app_user,''), oa_seen_users.app_user)",
                        (m.group(1), r["created_at"], r["created_at"], 0 if name == "unfollow" else 1, ap.group(1) if ap else ""))
        added += 1
    db.commit()
    return added


def _care_audience(period: str) -> dict:
    """Recipients for a period: Zalo's own list when the app may call it, else the webhook-recorded followers."""
    ids, total, err = _oa_follower_ids(period)
    if not err or ids:
        return {"ids": ids, "total": total if total is not None else len(ids), "source": "zalo", "apiError": ""}
    with get_db().cursor() as cur:
        cur.execute("SELECT COUNT(*) AS n, COUNT(*) FILTER (WHERE COALESCE(app_user,'') = '') AS missing FROM oa_seen_users")
        row = cur.fetchone()
        if not row["n"] or row["missing"]:
            _backfill_seen_from_log()
    seen = _oa_seen_ids(period)
    with get_db().cursor() as cur:
        cur.execute("SELECT COUNT(*) AS n FROM oa_seen_users WHERE followed = 1")
        known = cur.fetchone()["n"]
    return {"ids": seen, "total": known, "source": "webhook", "apiError": _care_list_error(err)}


def _care_list_error(raw: str) -> str:
    """Readable one-liner for a failed follower lookup, including Zalo's own code and message."""
    try:
        obj = json.loads(raw)
        why = f"Zalo báo lỗi {obj.get('error')}: {obj.get('message', '')}"
    except ValueError:
        why = raw[:160]
    return f"Không lấy được danh sách người quan tâm từ Zalo ({why})"


def _oa_alt_ids(uid: str) -> list[str]:
    """Other ids Zalo may know this person by: the Mini App/app-scoped id from the same webhook event."""
    with get_db().cursor() as cur:
        cur.execute("SELECT app_user FROM oa_seen_users WHERE user_id = %s", (uid,))
        row = cur.fetchone() or {}
    alt = row.get("app_user") or ""
    return [alt] if alt and alt != uid else []


def _oa_send_care(uid: str, text: str, image_url: str = "") -> tuple[bool, str]:
    """Text first, then the picture. The message counts as delivered when the text went through."""
    ok, detail = _oa_send_text(uid, text)
    if ok and image_url:
        payload = {"recipient": {"user_id": uid}, "message": {"attachment": {"type": "template", "payload": {
            "template_type": "media", "elements": [{"media_type": "image", "url": image_url}]}}}}
        _oa_call_json(ZALO_OA_SEND_URL, payload=payload)
    return ok, detail


def _care_image_url(name: str) -> str:
    name = secure_filename((name or "").strip())
    if not name or not (TASK_PHOTO_DIR / name).is_file():
        return ""
    return f"https://api.bismart.id.vn/api/tasks/photo/{urllib.parse.quote(name)}?w=1000"


def _care_error_key(detail: str) -> str:
    try:
        obj = json.loads(detail)
        return f"{obj.get('error')}: {str(obj.get('message', ''))[:80]}"
    except ValueError:
        return detail[:80]


def _care_worker(campaign_id: int, ids: list[str], text: str, image_url: str) -> None:
    """Send a campaign in the background, a few per second, recording progress after every batch."""
    with app.app_context():
        db = get_db()
        ok_n = fail_n = 0
        errors: dict[str, int] = {}
        with db.cursor() as cur:
            cur.execute("SELECT user_id, app_user FROM oa_seen_users WHERE user_id = ANY(%s)", (ids,))
            app_ids = {r["user_id"]: r["app_user"] for r in cur.fetchall() if r["app_user"]}
        try:
            for i, uid in enumerate(ids, 1):
                # The app-scoped id from the webhook event is accepted by the send API (it is what the Mini App
                # login yields); the raw sender id is not always. Try it first, then the sender id.
                ok, detail = False, ""
                for cand in ([app_ids[uid]] if app_ids.get(uid) not in (None, uid) else []) + [uid]:
                    ok, detail = _oa_send_care(cand, text, image_url)
                    if ok or _care_error_key(detail).split(":")[0] != "-201":
                        break
                if ok:
                    ok_n += 1
                else:
                    fail_n += 1
                    key = _care_error_key(detail)
                    errors[key] = errors.get(key, 0) + 1
                if i % 10 == 0 or i == len(ids):
                    with db.cursor() as cur:
                        cur.execute("UPDATE oa_care_campaigns SET ok_count=%s, fail_count=%s, errors=%s WHERE id=%s",
                                    (ok_n, fail_n, json.dumps(errors, ensure_ascii=False), campaign_id))
                    db.commit()
                time.sleep(0.15)
            status = "done"
        except Exception as e:
            status = "failed"
            errors[f"{type(e).__name__}"] = 1
        with db.cursor() as cur:
            cur.execute("UPDATE oa_care_campaigns SET status=%s, ok_count=%s, fail_count=%s, errors=%s, finished_at=%s WHERE id=%s",
                        (status, ok_n, fail_n, json.dumps(errors, ensure_ascii=False), _now_iso(), campaign_id))
        db.commit()


def _care_campaign_json(r: dict) -> dict:
    try:
        errors = json.loads(r.get("errors") or "{}")
    except ValueError:
        errors = {}
    return {"id": r["id"], "body": r["body"], "imageUrl": r["image_url"] or "", "period": r["period"], "status": r["status"],
            "total": r["total"], "okCount": r["ok_count"], "failCount": r["fail_count"], "errors": errors,
            "createdAt": r["created_at"], "finishedAt": r["finished_at"]}


@app.get("/api/oa/care/audience")
@login_required
def api_oa_care_audience():
    if not _is_admin_user():
        return _forbidden()
    period = (request.args.get("period") or "L7D").upper()
    if period not in OA_CARE_PERIODS:
        return jsonify({"error": "Invalid period"}), 400
    aud = _care_audience(period)
    return jsonify({"period": period, "count": len(aud["ids"]), "total": aud["total"], "source": aud["source"],
                    "apiError": aud["apiError"], "capped": len(aud["ids"]) >= OA_CARE_MAX_RECIPIENTS})


def _care_payload() -> tuple[str, str] | tuple[None, None]:
    data = request.get_json(silent=True) or {}
    text = (data.get("body") or "").strip()
    if not text or len(text) > 1500:
        return None, None
    return text, _care_image_url(data.get("imageName") or "")


@app.post("/api/oa/care/test")
@login_required
def api_oa_care_test():
    """Send the draft to the caller's own Zalo only."""
    if not _is_admin_user():
        return _forbidden()
    text, image_url = _care_payload()
    if text is None:
        return jsonify({"error": "Nội dung tin phải có từ 1 đến 1500 ký tự"}), 400
    employee_id = (g.current_user or {}).get("employee_id")
    with get_db().cursor() as cur:
        cur.execute("SELECT zalo_id, zalo_oa_id FROM employees WHERE id = %s", (employee_id,))
        row = cur.fetchone() or {}
    target = row.get("zalo_oa_id") or row.get("zalo_id")
    if not target:
        return jsonify({"error": "Tài khoản này chưa liên kết Zalo. Hãy thoát app, mở lại từ Zalo rồi thử lại."}), 400
    ok, detail = _oa_send_care(str(target), text, image_url)
    return jsonify({"ok": ok, "detail": detail})


@app.post("/api/oa/care/send")
@login_required
def api_oa_care_send():
    if not _is_admin_user():
        return _forbidden()
    text, image_url = _care_payload()
    if text is None:
        return jsonify({"error": "Nội dung tin phải có từ 1 đến 1500 ký tự"}), 400
    data = request.get_json(silent=True) or {}
    period = (data.get("period") or "L7D").upper()
    if period not in OA_CARE_PERIODS:
        return jsonify({"error": "Invalid period"}), 400
    db = get_db()
    now = datetime.now(tz=VN_TZ)
    with db.cursor() as cur:
        cur.execute("UPDATE oa_care_campaigns SET status='interrupted' WHERE status='sending' AND created_at < %s",
                    ((now - timedelta(minutes=30)).strftime("%Y-%m-%dT%H:%M:%S"),))
        cur.execute("SELECT COUNT(*) AS n FROM oa_care_campaigns WHERE status='sending'")
        if cur.fetchone()["n"]:
            db.commit()
            return jsonify({"error": "Đang có một đợt gửi chạy. Hãy đợi đợt đó xong rồi gửi tiếp."}), 409
        cur.execute("SELECT COALESCE(SUM(total),0) AS n FROM oa_care_campaigns WHERE created_at >= %s", (now.strftime("%Y-%m-%d"),))
        sent_today = cur.fetchone()["n"]
    ids = _care_audience(period)["ids"]
    if not ids:
        return jsonify({"error": "Chưa có người nhận phù hợp trong nhóm này"}), 400
    if sent_today + len(ids) > OA_CARE_DAILY_MAX:
        return jsonify({"error": f"Vượt giới hạn {OA_CARE_DAILY_MAX} tin mỗi ngày (hôm nay đã gửi {sent_today})"}), 429
    with db.cursor() as cur:
        cur.execute("INSERT INTO oa_care_campaigns (body, image_url, period, status, total, created_by, created_at) "
                    "VALUES (%s,%s,%s,'sending',%s,%s,%s) RETURNING id",
                    (text, image_url, period, len(ids), (g.current_user or {}).get("employee_id"), _now_iso()))
        cid = cur.fetchone()["id"]
    db.commit()
    threading.Thread(target=_care_worker, args=(cid, ids, text, image_url), daemon=True).start()
    return jsonify({"id": cid, "total": len(ids)}), 202


@app.get("/api/oa/care/campaigns")
@login_required
def api_oa_care_campaigns():
    if not _is_admin_user():
        return _forbidden()
    with get_db().cursor() as cur:
        cur.execute("SELECT * FROM oa_care_campaigns ORDER BY id DESC LIMIT 20")
        rows = cur.fetchall()
    return jsonify({"campaigns": [_care_campaign_json(r) for r in rows]})


@app.post("/api/auth/zalo-login")
def api_zalo_login():
    """One-tap login for an employee whose Zalo account was linked earlier."""
    data = request.get_json(silent=True) or {}
    zalo = _verify_zalo_access_token((data.get("accessToken") or "").strip())
    if not zalo:
        return jsonify({"error": "Invalid Zalo access token"}), 401
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT u.id as user_id, u.username, u.employee_id as auth_employee_id, e.* FROM employees e "
            "JOIN users u ON u.employee_id = e.id "
            "WHERE e.zalo_id = %s AND e.is_active = 1 LIMIT 1",
            (str(zalo["id"]),),
        )
        user_row = cur.fetchone()
    if not user_row:
        return jsonify({"error": "Zalo account not linked", "code": "NOT_LINKED"}), 404
    token = create_token(user_row["user_id"], user_row.get("auth_employee_id"))
    return jsonify({"token": token, "user": _user_to_api_json(user_row)})


def _task_viewer() -> dict:
    """Caller's employee id, store scope and whether they can assign/manage tasks."""
    user_id = (g.current_user or {}).get("user_id")
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT e.id, e.full_name, e.store_code, e.position, p.can_employees, p.can_crud "
            "FROM users u LEFT JOIN employees e ON e.id = u.employee_id "
            "LEFT JOIN permissions p ON UPPER(p.position) = UPPER(e.position) "
            "WHERE u.id = %s",
            (user_id,),
        )
        row = cur.fetchone() or {}
    is_admin = _is_admin_user()
    return {
        "employee_id": row.get("id"),
        "name": row.get("full_name") or "",
        "store_code": (row.get("store_code") or "").upper(),
        "position": (row.get("position") or "").upper(),
        "scope": _allowed_store_codes_for_current_user(),  # None = all stores
        "can_manage": bool(is_admin or row.get("can_crud") or row.get("can_employees")),
    }


def _task_to_api_json(row: dict[str, Any]) -> dict[str, Any]:
    try:
        photos = json.loads(row.get("photo_urls") or "[]")
    except Exception:
        photos = []
    due_at = row.get("due_at")
    status = row.get("status") or "todo"
    overdue = bool(due_at) and status in ("todo", "doing") and due_at < _now_iso()
    return {
        "id": row["id"],
        "title": row.get("title") or "",
        "description": row.get("description") or "",
        # A code that matches no store (stale/mistyped employee data) is shown as unassigned.
        "storeCode": (row.get("store_code") or "") if row.get("store_name") else "",
        "storeName": row.get("store_name") or "",
        "doerIds": [int(x) for x in _json_list(row.get("doer_ids")) if str(x).isdigit()],
        "assigneeId": row.get("assignee_id"),
        "assigneeName": row.get("assignee_name") or "",
        "assignedById": row.get("assigned_by"),
        "assignedByName": row.get("assigner_name") or "",
        "priority": row.get("priority") or "normal",
        "status": status,
        "dueAt": due_at,
        "overdue": overdue,
        "recurrence": row.get("recurrence") or "none",
        "requirePhoto": bool(row.get("require_photo")),
        "photoUrls": photos,
        "completedAt": row.get("completed_at"),
        "completionNote": row.get("completion_note") or "",
        "createdAt": row.get("created_at"),
        "updatedAt": row.get("updated_at"),
    }


_TASK_SELECT = (
    "SELECT t.*, a.full_name AS assignee_name, b.full_name AS assigner_name, s.name AS store_name "
    "FROM tasks t "
    "LEFT JOIN employees a ON a.id = t.assignee_id "
    "LEFT JOIN employees b ON b.id = t.assigned_by "
    "LEFT JOIN stores s ON UPPER(s.store_code) = UPPER(t.store_code) "
)


def _fetch_task(task_id: int) -> dict | None:
    with get_db().cursor() as cur:
        cur.execute(_TASK_SELECT + "WHERE t.id = %s", (task_id,))
        return cur.fetchone()


def _can_view_task(task: dict, viewer: dict) -> bool:
    if task.get("assignee_id") == viewer["employee_id"] or task.get("assigned_by") == viewer["employee_id"]:
        return True
    if viewer["scope"] is None:
        return True
    return viewer["can_manage"] and (task.get("store_code") or "").upper() in viewer["scope"]


def _can_manage_task(task: dict, viewer: dict) -> bool:
    if not viewer["can_manage"]:
        return False
    if task.get("assigned_by") == viewer["employee_id"] or viewer["scope"] is None:
        return True
    return (task.get("store_code") or "").upper() in viewer["scope"]


def _next_due(due_at: str | None, recurrence: str) -> str:
    base = datetime.now(tz=VN_TZ).replace(tzinfo=None)
    if due_at:
        try:
            base = datetime.strptime(due_at[:19], "%Y-%m-%dT%H:%M:%S")
        except ValueError:
            pass
    step = timedelta(days=7 if recurrence == "weekly" else 1)
    nxt = base + step
    now = datetime.now(tz=VN_TZ).replace(tzinfo=None)
    while nxt < now:  # skip occurrences already missed
        nxt += step
    return nxt.strftime("%Y-%m-%dT%H:%M:%S")


def _spawn_next_occurrence(task: dict) -> None:
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO tasks (title, description, store_code, assignee_id, assigned_by, priority, "
            "due_at, recurrence, require_photo, created_at, updated_at) "
            "VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id",
            (
                task["title"], task.get("description"), task.get("store_code") or "",
                task.get("assignee_id"), task.get("assigned_by"), task.get("priority") or "normal",
                _next_due(task.get("due_at"), task["recurrence"]), task["recurrence"],
                task.get("require_photo") or 0, _now_iso(), _now_iso(),
            ),
        )
        new_id = cur.fetchone()["id"]
    if task.get("assignee_id"):
        _notify(task["assignee_id"], "assigned", "Việc lặp lại mới", task["title"], new_id)


def _clean_photo_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [secure_filename(str(v)) for v in value[:10] if v]


@app.get("/api/tasks")
@login_required
def api_list_tasks():
    viewer = _task_viewer()
    where, params = [], []
    status = request.args.get("status")
    if status in TASK_STATUSES:
        where.append("t.status = %s")
        params.append(status)
    store = (request.args.get("storeCode") or "").strip().upper()
    if store:
        where.append("UPPER(t.store_code) = %s")
        params.append(store)
    assignee = request.args.get("assigneeId")
    if request.args.get("mine") == "1":
        assignee = str(viewer["employee_id"])
    if assignee and assignee.isdigit():
        where.append("t.assignee_id = %s")
        params.append(int(assignee))

    # Visibility: own tasks always; managers also see their store scope.
    if viewer["scope"] is not None:
        vis, vparams = ["t.assignee_id = %s", "t.assigned_by = %s"], [viewer["employee_id"]] * 2
        if viewer["can_manage"] and viewer["scope"]:
            vis.append("UPPER(t.store_code) = ANY(%s)")
            vparams.append(list(viewer["scope"]))
        where.append("(" + " OR ".join(vis) + ")")
        params.extend(vparams)

    sql = _TASK_SELECT + ("WHERE " + " AND ".join(where) + " " if where else "")
    sql += "ORDER BY (t.status IN ('done','cancelled')), t.due_at IS NULL, t.due_at ASC, t.id DESC LIMIT 300"
    with get_db().cursor() as cur:
        cur.execute(sql, params)
        rows = cur.fetchall()
    return jsonify({"tasks": [_task_to_api_json(r) for r in rows], "canManage": viewer["can_manage"], "isAdmin": _is_admin_user()})


@app.post("/api/tasks")
@login_required
def api_create_task():
    viewer = _task_viewer()
    if not viewer["can_manage"]:
        return _forbidden()
    data = request.get_json(silent=True) or {}
    title = (data.get("title") or "").strip()
    if not title:
        return jsonify({"error": "Title is required"}), 400
    priority = data.get("priority") or "normal"
    recurrence = data.get("recurrence") or "none"
    if priority not in TASK_PRIORITIES or recurrence not in TASK_RECURRENCES:
        return jsonify({"error": "Invalid priority or recurrence"}), 400

    assignee_id = data.get("assigneeId")
    store_code = (data.get("storeCode") or "").strip().upper()
    db = get_db()
    if assignee_id:
        with db.cursor() as cur:
            cur.execute("SELECT id, store_code FROM employees WHERE id = %s AND is_active = 1", (assignee_id,))
            assignee = cur.fetchone()
        if not assignee:
            return jsonify({"error": "Assignee not found"}), 404
        store_code = store_code or (assignee.get("store_code") or "").upper()
    if store_code:
        with db.cursor() as cur:
            cur.execute("SELECT 1 FROM stores WHERE UPPER(store_code) = %s LIMIT 1", (store_code,))
            if not cur.fetchone():
                store_code = ""  # unknown code (e.g. a stale value on the employee): leave the task unassigned
    if viewer["scope"] is not None and store_code not in viewer["scope"]:
        return _forbidden()

    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO tasks (title, description, store_code, assignee_id, assigned_by, priority, due_at, "
            "recurrence, require_photo, created_at, updated_at) "
            "VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id",
            (
                title, (data.get("description") or "").strip(), store_code, assignee_id or None,
                viewer["employee_id"], priority, data.get("dueAt") or None, recurrence,
                1 if data.get("requirePhoto") else 0, _now_iso(), _now_iso(),
            ),
        )
        task_id = cur.fetchone()["id"]
    db.commit()
    if assignee_id and int(assignee_id) != viewer["employee_id"]:
        due = f" · hạn {_fmt_due(data['dueAt'])}" if data.get("dueAt") else ""
        _notify(int(assignee_id), "assigned", "Bạn được giao việc mới", f"{title}{due} · giao bởi {viewer['name']}", task_id)
    return jsonify(_task_to_api_json(_fetch_task(task_id))), 201


@app.get("/api/tasks/summary")
@login_required
def api_tasks_summary():
    """Per-store counts for the manager dashboard (scoped like the list)."""
    viewer = _task_viewer()
    if not viewer["can_manage"]:
        return _forbidden()
    sql = (
        "SELECT CASE WHEN s.name IS NULL THEN '' ELSE t.store_code END AS store_code, s.name AS store_name, "
        "COUNT(*) FILTER (WHERE t.status = 'todo') AS todo, "
        "COUNT(*) FILTER (WHERE t.status = 'doing') AS doing, "
        "COUNT(*) FILTER (WHERE t.status = 'done') AS done, "
        "COUNT(*) FILTER (WHERE t.status IN ('todo','doing') AND t.due_at < %s) AS overdue "
        "FROM tasks t LEFT JOIN stores s ON UPPER(s.store_code) = UPPER(t.store_code) "
        "WHERE t.status <> 'cancelled' "
    )
    params: list[Any] = [_now_iso()]
    if viewer["scope"] is not None:
        sql += "AND UPPER(t.store_code) = ANY(%s) "
        params.append(list(viewer["scope"]))
    sql += "GROUP BY 1, 2 ORDER BY overdue DESC, 1"
    with get_db().cursor() as cur:
        cur.execute(sql, params)
        rows = cur.fetchall()
    return jsonify({"stores": [
        {"storeCode": r["store_code"], "storeName": r.get("store_name") or "", "todo": r["todo"],
         "doing": r["doing"], "done": r["done"], "overdue": r["overdue"]} for r in rows
    ]})


def _compute_task_analytics(rows: list[dict], days: int, now_iso: str, today: str) -> dict:
    """Completion analytics over task rows (cancelled already excluded). `days` = 0 means all time.
    The cohort is the tasks created in the period; the daily series covers the last 7/30 days."""
    from datetime import date as _date

    def _is_open(r):
        return r["status"] in ("todo", "doing")

    def _overdue(r):
        return _is_open(r) and bool(r.get("due_at")) and r["due_at"] < now_iso

    def _on_time(r):
        return r["status"] == "done" and (not r.get("due_at") or (bool(r.get("completed_at")) and r["completed_at"] <= r["due_at"]))

    today_d = _date.fromisoformat(today)
    from_date = (today_d - timedelta(days=days - 1)).isoformat() if days else ""
    cohort = [r for r in rows if not days or (r.get("created_at") or "")[:10] >= from_date]

    def _tally(items):
        total = len(items)
        done = sum(1 for r in items if r["status"] == "done")
        overdue = sum(1 for r in items if _overdue(r))
        on_time = sum(1 for r in items if _on_time(r))
        doing = sum(1 for r in items if r["status"] == "doing" and not _overdue(r))
        todo = sum(1 for r in items if r["status"] == "todo" and not _overdue(r))
        return {
            "total": total, "done": done, "overdue": overdue, "doing": doing, "todo": todo,
            "onTime": on_time, "late": done - on_time,
            "completionRate": round(done * 100 / total) if total else 0,
            "onTimeRate": round(on_time * 100 / done) if done else None,
        }

    by_store: dict[str, dict] = {}
    by_person: dict[int, dict] = {}
    by_doer: dict[int, int] = {}
    for r in cohort:
        if r["status"] == "done":
            for d in _json_list(r.get("doer_ids")):
                if str(d).isdigit():
                    by_doer[int(d)] = by_doer.get(int(d), 0) + 1
        sc = (r.get("store_code") or "").upper()
        by_store.setdefault(sc, {"name": r.get("store_name") or "", "items": []})["items"].append(r)
        if r.get("assignee_id"):
            by_person.setdefault(r["assignee_id"], {"name": r.get("assignee_name") or "", "store": sc, "items": []})["items"].append(r)

    span = days if days in (7, 30) else 30
    day_list = [(today_d - timedelta(days=i)).isoformat() for i in range(span - 1, -1, -1)]
    created_by_day: dict[str, int] = {}
    done_by_day: dict[str, int] = {}
    for r in rows:
        c = (r.get("created_at") or "")[:10]
        if c:
            created_by_day[c] = created_by_day.get(c, 0) + 1
        if r["status"] == "done" and r.get("completed_at"):
            d = r["completed_at"][:10]
            done_by_day[d] = done_by_day.get(d, 0) + 1

    return {
        "days": days,
        "totals": _tally(cohort),
        "byStore": sorted(
            ({"storeCode": k, "storeName": v["name"], **_tally(v["items"])} for k, v in by_store.items()),
            key=lambda x: (-x["total"], x["storeCode"]),
        ),
        "byAssignee": sorted(
            ({"id": k, "name": v["name"], "storeCode": v["store"], **_tally(v["items"])} for k, v in by_person.items()),
            key=lambda x: (-x["total"], x["name"]),
        )[:30],
        "daily": [{"date": d, "created": created_by_day.get(d, 0), "done": done_by_day.get(d, 0)} for d in day_list],
        "byDoer": [{"id": k, "done": v} for k, v in sorted(by_doer.items(), key=lambda kv: -kv[1])[:30]],
    }


def _employee_names(ids: list[int]) -> list[dict]:
    if not ids:
        return []
    with get_db().cursor() as cur:
        cur.execute("SELECT id, full_name FROM employees WHERE id = ANY(%s)", (ids,))
        found = {r["id"]: r["full_name"] for r in cur.fetchall()}
    return [{"id": i, "name": found[i]} for i in ids if i in found]


def _valid_doer_ids(raw: Any, store_code: str | None) -> list[int] | None:
    """Employee ids of active staff in the task's store, or None when the input is not acceptable."""
    if raw in (None, ""):
        return []
    if not isinstance(raw, list) or len(raw) > 30:
        return None
    try:
        ids = sorted({int(x) for x in raw})
    except (TypeError, ValueError):
        return None
    if not ids:
        return []
    with get_db().cursor() as cur:
        cur.execute("SELECT id FROM employees WHERE id = ANY(%s) AND is_active = 1 AND UPPER(COALESCE(store_code,'')) = %s",
                    (ids, (store_code or "").upper()))
        ok = {r["id"] for r in cur.fetchall()}
    return ids if set(ids) <= ok else None


@app.get("/api/tasks/stores")
@login_required
def api_task_stores():
    """Stores in the caller's scope with their store managers (employees whose position is SM in that store, or
    designated SM in store_managers), for 'assign by store'."""
    viewer = _task_viewer()
    if not viewer["can_manage"]:
        return _forbidden()
    sql = ("SELECT s.store_code, s.name, e.id AS emp_id, e.full_name FROM stores s "
           "LEFT JOIN employees e ON e.is_active = 1 AND ("
           "  (UPPER(COALESCE(e.position,'')) = 'SM' AND UPPER(COALESCE(e.store_code,'')) = UPPER(s.store_code)) "
           "  OR e.id IN (SELECT sm.employee_id FROM store_managers sm WHERE sm.store_id = s.id AND UPPER(sm.store_role) = 'SM')) "
           "WHERE NOT (COALESCE(s.status,'') ILIKE '%%đóng%%' OR COALESCE(s.status,'') ILIKE '%%ngừng%%') ")
    params: list[Any] = []
    if viewer["scope"] is not None:
        sql += "AND UPPER(s.store_code) = ANY(%s) "
        params.append(list(viewer["scope"]) or [""])
    sql += "ORDER BY s.name, e.full_name"
    stores: dict[str, dict] = {}
    with get_db().cursor() as cur:
        cur.execute(sql, params)
        for r in cur.fetchall():
            st = stores.setdefault(r["store_code"], {"storeCode": r["store_code"], "storeName": r["name"], "managers": []})
            if r["emp_id"]:
                st["managers"].append({"id": r["emp_id"], "name": r["full_name"]})
    return jsonify({"stores": list(stores.values())})


@app.get("/api/tasks/<int:task_id>/staff")
@login_required
def api_task_staff(task_id: int):
    """Staff of the task's store, so the person reporting the result can tick who carried it out."""
    viewer = _task_viewer()
    task = _fetch_task(task_id)
    if not task:
        return jsonify({"error": "Task not found"}), 404
    if not _can_view_task(task, viewer):
        return _forbidden()
    store = (task.get("store_code") or "").upper()
    if not store:
        return jsonify({"employees": []})
    with get_db().cursor() as cur:
        cur.execute("SELECT id, full_name, employee_code, position FROM employees WHERE is_active = 1 "
                    "AND UPPER(COALESCE(store_code,'')) = %s ORDER BY full_name", (store,))
        rows = cur.fetchall()
    return jsonify({"employees": [{"id": r["id"], "fullName": r["full_name"], "employeeCode": r["employee_code"],
                                   "position": r["position"] or ""} for r in rows]})


@app.get("/api/tasks/analytics")
@login_required
def api_tasks_analytics():
    """Completion-rate overview. Managers see their store scope (optionally one store); everyone else sees
    only their own tasks."""
    viewer = _task_viewer()
    try:
        days = int(request.args.get("days", 30))
    except ValueError:
        days = 30
    if days not in (0, 7, 30, 90):
        days = 30
    store = (request.args.get("storeCode") or "").strip().upper()

    where = ["t.status <> 'cancelled'"]
    params: list[Any] = []
    if viewer["can_manage"]:
        if viewer["scope"] is not None:
            if not viewer["scope"]:
                where.append("FALSE")
            else:
                where.append("UPPER(t.store_code) = ANY(%s)")
                params.append(list(viewer["scope"]))
    else:
        where.append("t.assignee_id = %s")
        params.append(viewer["employee_id"])

    select = (
        "SELECT t.id, t.store_code, s.name AS store_name, t.assignee_id, a.full_name AS assignee_name, "
        "t.status, t.due_at, t.completed_at, t.created_at, t.doer_ids FROM tasks t "
        "LEFT JOIN employees a ON a.id = t.assignee_id "
        "LEFT JOIN stores s ON UPPER(s.store_code) = UPPER(t.store_code) WHERE "
    )
    db = get_db()
    with db.cursor() as cur:
        cur.execute(select + " AND ".join(where), params)
        all_rows = cur.fetchall()

    stores = {}
    for r in all_rows:
        if not r.get("store_name"):
            r["store_code"] = ""  # no matching store: report under "unassigned"
        sc = (r.get("store_code") or "").upper()
        if sc and sc not in stores:
            stores[sc] = r.get("store_name") or ""
    rows = [r for r in all_rows if not store or (r.get("store_code") or "").upper() == store]

    out = _compute_task_analytics(rows, days, _now_iso(), _now_iso()[:10])
    if out["byDoer"]:
        with db.cursor() as cur:
            cur.execute("SELECT id, full_name, store_code FROM employees WHERE id = ANY(%s)", ([d["id"] for d in out["byDoer"]],))
            info = {r["id"]: r for r in cur.fetchall()}
        out["byDoer"] = [{"id": d["id"], "name": info[d["id"]]["full_name"], "storeCode": (info[d["id"]].get("store_code") or ""),
                          "done": d["done"]} for d in out["byDoer"] if d["id"] in info]
    out["scope"] = "team" if viewer["can_manage"] else "mine"
    out["storeCode"] = store
    out["stores"] = [{"storeCode": k, "storeName": v} for k, v in sorted(stores.items())]
    return jsonify(out)


@app.get("/api/tasks/assignees")
@login_required
def api_task_assignees():
    viewer = _task_viewer()
    if not viewer["can_manage"]:
        return _forbidden()
    sql = ("SELECT e.id, e.full_name, e.employee_code, e.position, e.store_code, s.name AS store_name FROM employees e "
           "LEFT JOIN stores s ON UPPER(s.store_code) = UPPER(e.store_code) WHERE e.is_active = 1 ")
    params: list[Any] = []
    if viewer["scope"] is not None:
        sql += "AND UPPER(e.store_code) = ANY(%s) "
        params.append(list(viewer["scope"]))
    sql += "ORDER BY e.store_code, e.full_name"
    with get_db().cursor() as cur:
        cur.execute(sql, params)
        rows = cur.fetchall()
    return jsonify({"employees": [
        {"id": r["id"], "fullName": r["full_name"], "employeeCode": r["employee_code"],
         "position": r["position"], "storeCode": r.get("store_code") or "", "storeName": r.get("store_name") or ""} for r in rows
    ]})


@app.post("/api/tasks/upload-photo")
@login_required
def api_upload_task_photo():
    f = request.files.get("file")
    if not f:
        return jsonify({"error": "no file"}), 400
    ext = os.path.splitext(secure_filename(f.filename or "photo.jpg"))[1].lower() or ".jpg"
    if ext not in ALLOWED_PHOTO_EXT:
        return jsonify({"error": f"ext {ext} not allowed"}), 400
    fname = f"{uuid.uuid4().hex}{ext}"
    target = TASK_PHOTO_DIR / fname
    f.save(target)
    if target.stat().st_size > MAX_PHOTO_BYTES:
        target.unlink(missing_ok=True)
        return jsonify({"error": "file too large"}), 413
    return jsonify({"photoUrl": fname})


@app.get("/api/tasks/photo/<path:fname>")
def api_task_photo(fname: str):
    # Names are unguessable UUIDs and <img> cannot send an Authorization header.
    full = TASK_PHOTO_DIR / secure_filename(fname)
    if not full.is_file():
        return jsonify({"error": "missing"}), 404
    width = request.args.get("w", type=int)
    if width:
        thumb = _thumb_for(full, width)
        if thumb:
            return Response(thumb.read_bytes(), mimetype="image/jpeg", headers={"Cache-Control": "private, max-age=604800"})
    mime = mimetypes.guess_type(str(full))[0] or "application/octet-stream"
    return Response(full.read_bytes(), mimetype=mime, headers={"Cache-Control": "private, max-age=86400"})


@app.get("/api/tasks/<int:task_id>")
@login_required
def api_get_task(task_id: int):
    viewer = _task_viewer()
    task = _fetch_task(task_id)
    if not task:
        return jsonify({"error": "Task not found"}), 404
    if not _can_view_task(task, viewer):
        return _forbidden()
    with get_db().cursor() as cur:
        cur.execute(
            "SELECT c.id, c.body, c.created_at, c.author_id, e.full_name FROM task_comments c "
            "LEFT JOIN employees e ON e.id = c.author_id WHERE c.task_id = %s ORDER BY c.id ASC",
            (task_id,),
        )
        comments = cur.fetchall()
    out = _task_to_api_json(task)
    out["canManage"] = _can_manage_task(task, viewer)
    out["doers"] = _employee_names(out["doerIds"])
    out["comments"] = [
        {"id": c["id"], "body": c["body"], "createdAt": c["created_at"],
         "authorId": c["author_id"], "authorName": c.get("full_name") or ""} for c in comments
    ]
    return jsonify(out)


@app.put("/api/tasks/<int:task_id>")
@login_required
def api_update_task(task_id: int):
    viewer = _task_viewer()
    task = _fetch_task(task_id)
    if not task:
        return jsonify({"error": "Task not found"}), 404
    if not _can_manage_task(task, viewer):
        return _forbidden()
    data = request.get_json(silent=True) or {}
    priority = data.get("priority", task["priority"])
    recurrence = data.get("recurrence", task["recurrence"])
    if priority not in TASK_PRIORITIES or recurrence not in TASK_RECURRENCES:
        return jsonify({"error": "Invalid priority or recurrence"}), 400
    title = (data.get("title", task["title"]) or "").strip()
    if not title:
        return jsonify({"error": "Title is required"}), 400
    new_assignee = data.get("assigneeId", task["assignee_id"]) or None
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "UPDATE tasks SET title=%s, description=%s, assignee_id=%s, priority=%s, due_at=%s, "
            "recurrence=%s, require_photo=%s, updated_at=%s WHERE id=%s",
            (
                title, data.get("description", task["description"]), new_assignee, priority,
                data.get("dueAt", task["due_at"]) or None, recurrence,
                1 if data.get("requirePhoto", bool(task["require_photo"])) else 0, _now_iso(), task_id,
            ),
        )
    db.commit()
    if new_assignee and new_assignee != task["assignee_id"] and int(new_assignee) != viewer["employee_id"]:
        _notify(int(new_assignee), "assigned", "Bạn được giao việc", f"{title} · giao bởi {viewer['name']}", task_id)
    return jsonify(_task_to_api_json(_fetch_task(task_id)))


@app.post("/api/tasks/<int:task_id>/status")
@login_required
def api_set_task_status(task_id: int):
    """Assignee or manager moves a task along; completing may require photo proof."""
    viewer = _task_viewer()
    task = _fetch_task(task_id)
    if not task:
        return jsonify({"error": "Task not found"}), 404
    is_assignee = task.get("assignee_id") == viewer["employee_id"]
    is_manager = _can_manage_task(task, viewer)
    if not (is_assignee or is_manager):
        return _forbidden()
    data = request.get_json(silent=True) or {}
    status = data.get("status")
    if status not in TASK_STATUSES:
        return jsonify({"error": "Invalid status"}), 400
    if status == "cancelled" and not is_manager:
        return _forbidden()

    photos = _clean_photo_list(data.get("photoUrls")) or json.loads(task.get("photo_urls") or "[]")
    if status == "done" and task.get("require_photo") and not photos:
        return jsonify({"error": "Photo proof is required to complete this task"}), 400

    doer_ids = _json_list(task.get("doer_ids"))
    if "doerIds" in data:
        doer_ids = _valid_doer_ids(data.get("doerIds"), task.get("store_code"))
        if doer_ids is None:
            return jsonify({"error": "Invalid doers"}), 400

    done_now = status == "done" and task["status"] != "done"
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "UPDATE tasks SET status=%s, photo_urls=%s, completion_note=%s, completed_at=%s, updated_at=%s, "
            "doer_ids=%s WHERE id=%s",
            (
                status, json.dumps(photos),
                (data.get("note") if "note" in data else task.get("completion_note")),
                _now_iso() if status == "done" else None, _now_iso(), json.dumps(doer_ids), task_id,
            ),
        )
    db.commit()
    if done_now:
        if task.get("recurrence") in ("daily", "weekly"):
            _spawn_next_occurrence(task)
            db.commit()
        if task.get("assigned_by") and task["assigned_by"] != viewer["employee_id"]:
            _notify(task["assigned_by"], "done", "Việc đã hoàn thành", f"{viewer['name']} đã hoàn thành: {task['title']}", task_id)
    elif status == "cancelled" and task["status"] != "cancelled":
        if task.get("assignee_id") and task["assignee_id"] != viewer["employee_id"]:
            _notify(task["assignee_id"], "cancelled", "Việc đã bị huỷ", f"{task['title']} · huỷ bởi {viewer['name']}", task_id)
    elif status == "todo" and task["status"] in ("done", "cancelled"):
        if task.get("assignee_id") and task["assignee_id"] != viewer["employee_id"]:
            _notify(task["assignee_id"], "reopened", "Việc được mở lại", f"{task['title']} · bởi {viewer['name']}", task_id)
    return jsonify(_task_to_api_json(_fetch_task(task_id)))


@app.post("/api/tasks/<int:task_id>/comments")
@login_required
def api_add_task_comment(task_id: int):
    viewer = _task_viewer()
    task = _fetch_task(task_id)
    if not task:
        return jsonify({"error": "Task not found"}), 404
    if not _can_view_task(task, viewer):
        return _forbidden()
    body = ((request.get_json(silent=True) or {}).get("body") or "").strip()
    if not body:
        return jsonify({"error": "Empty comment"}), 400
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO task_comments (task_id, author_id, body, created_at) VALUES (%s,%s,%s,%s) RETURNING id",
            (task_id, viewer["employee_id"], body, _now_iso()),
        )
        cid = cur.fetchone()["id"]
    db.commit()
    for target in {task.get("assignee_id"), task.get("assigned_by")} - {viewer["employee_id"], None}:
        _notify(target, "comment", f"{viewer['name']} đã trao đổi", f"{task['title']}: {body[:160]}", task_id)
    return jsonify({"id": cid, "body": body, "authorId": viewer["employee_id"],
                    "authorName": viewer["name"], "createdAt": _now_iso()}), 201


@app.delete("/api/tasks/<int:task_id>")
@login_required
def api_delete_task(task_id: int):
    viewer = _task_viewer()
    task = _fetch_task(task_id)
    if not task:
        return jsonify({"error": "Task not found"}), 404
    if not _can_manage_task(task, viewer):
        return _forbidden()
    db = get_db()
    with db.cursor() as cur:
        cur.execute("DELETE FROM tasks WHERE id = %s", (task_id,))
    db.commit()
    return jsonify({"ok": True})


# ---------------------------------------------------------------------------
# Store operations: cash-fund reports, purchase orders + receiving, announcements, photo gallery
# ---------------------------------------------------------------------------
from datetime import date as _date_cls

FUND_DENOMS = (500000, 200000, 100000, 50000, 20000, 10000, 5000, 2000, 1000)
ORDER_OPEN_STATUSES = ("submitted", "approved", "ordered", "partial")
ORDER_LABELS = {"approved": "đã được duyệt", "ordered": "đã đặt nhà cung cấp", "cancelled": "đã bị huỷ",
                "delivered": "đã nhận đủ hàng", "partial": "nhận thiếu hàng"}
CASH_EXCLUDED_METHODS = ("transfer", "bank_transfer", "chuyen_khoan", "ck")
ADMIN_POSITIONS = ("ADM", "ADMIN", "TMK")


def _valid_date(v: Any) -> str | None:
    try:
        return _date_cls.fromisoformat(str(v)[:10]).isoformat()
    except ValueError:
        return None


def _json_list(v: Any) -> list:
    try:
        x = json.loads(v or "[]")
    except (TypeError, ValueError):
        return []
    return x if isinstance(x, list) else []


def _to_amount(v: Any) -> float | None:
    """Non-negative finite number, or None when invalid."""
    try:
        n = float(v)
    except (TypeError, ValueError):
        return None
    return n if math.isfinite(n) and 0 <= n <= 1e12 else None


def _vnd(n: float) -> str:
    return f"{int(round(n)):,}".replace(",", ".") + "đ"


def _vn_date_text(iso: str) -> str:
    return f"{iso[8:10]}/{iso[5:7]}" if len(iso) >= 10 else iso


def _in_scope(viewer: dict, store_code: str | None) -> bool:
    return viewer["scope"] is None or (store_code or "").upper() in viewer["scope"]


def _manages(viewer: dict, store_code: str | None) -> bool:
    return bool(viewer["can_manage"]) and _in_scope(viewer, store_code)


def _store_name(code: str | None) -> str:
    cache = g.__dict__.setdefault("_store_names", {})
    key = (code or "").upper()
    if key not in cache:
        with get_db().cursor() as cur:
            cur.execute("SELECT name FROM stores WHERE UPPER(store_code) = %s LIMIT 1", (key,))
            row = cur.fetchone()
        cache[key] = (row or {}).get("name") or key
    return cache[key]


def _manager_ids(store_code: str) -> list[int]:
    """Admins, people with manage permissions in that store, and its designated managers."""
    code = (store_code or "").upper()
    with get_db().cursor() as cur:
        cur.execute(
            "SELECT DISTINCT e.id FROM employees e "
            "LEFT JOIN permissions p ON UPPER(p.position) = UPPER(e.position) "
            "WHERE e.is_active = 1 AND ("
            "  UPPER(e.position) = ANY(%s) "
            "  OR (UPPER(COALESCE(e.store_code,'')) = %s AND (p.can_crud = 1 OR p.can_employees = 1)) "
            "  OR e.id IN (SELECT sm.employee_id FROM store_managers sm JOIN stores s ON s.id = sm.store_id "
            "              WHERE UPPER(s.store_code) = %s))",
            (list(ADMIN_POSITIONS), code, code),
        )
        return [r["id"] for r in cur.fetchall()]


def _notify_managers(store_code: str, actor_id: int | None, kind: str, title: str, body: str, link: str,
                     dedupe_key: str | None = None, push: bool = True) -> None:
    for mid in _manager_ids(store_code):
        if mid != actor_id:
            _notify(mid, kind, title, body, None, dedupe_key, push, link)


def _bad(msg: str, code: int = 400):
    return jsonify({"error": msg}), code


# ----------------------------- cash fund ------------------------------------

_FUND_SELECT = (
    "SELECT f.*, s.name AS store_name, sb.full_name AS submitter_name, rb.full_name AS reviewer_name "
    "FROM fund_reports f "
    "LEFT JOIN stores s ON UPPER(s.store_code) = UPPER(f.store_code) "
    "LEFT JOIN employees sb ON sb.id = f.submitted_by "
    "LEFT JOIN employees rb ON rb.id = f.reviewed_by "
)


def _fund_report_to_json(r: dict) -> dict:
    try:
        counts = json.loads(r.get("counts_json") or "{}")
    except ValueError:
        counts = {}
    return {
        "id": r["id"], "storeCode": r["store_code"], "storeName": r.get("store_name") or r["store_code"],
        "reportDate": r["report_date"], "counts": counts, "otherAmount": r.get("other_amount") or 0,
        "cashTotal": r.get("cash_total") or 0, "systemBalance": r.get("system_balance") or 0,
        "difference": r.get("difference") or 0, "note": r.get("note") or "",
        "photoUrls": _json_list(r.get("photo_urls")), "status": r.get("status") or "submitted",
        "submittedById": r.get("submitted_by"), "submittedByName": r.get("submitter_name") or "",
        "reviewedByName": r.get("reviewer_name") or "", "reviewedAt": r.get("reviewed_at"),
        "reviewNote": r.get("review_note") or "", "createdAt": r.get("created_at"), "updatedAt": r.get("updated_at"),
    }


def _fund_suggestion(store: str, date: str) -> dict:
    """Expected cash in the till: yesterday's counted fund + cash sales + manual in - manual out."""
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "SELECT cash_total FROM fund_reports WHERE UPPER(store_code) = %s AND report_date < %s "
            "AND status <> 'rejected' ORDER BY report_date DESC LIMIT 1", (store, date))
        opening = float((cur.fetchone() or {}).get("cash_total") or 0)
        cur.execute(
            "SELECT COALESCE(SUM(revenue), 0) AS v FROM sales_reports WHERE UPPER(store_code) = %s "
            "AND LEFT(report_date, 10) = %s AND LOWER(COALESCE(payment_method, 'cash')) <> ALL(%s)",
            (store, date, list(CASH_EXCLUDED_METHODS)))
        cash_sales = float(cur.fetchone()["v"] or 0)
        cur.execute(
            "SELECT COALESCE(SUM(amount) FILTER (WHERE kind = 'in'), 0) AS i, "
            "COALESCE(SUM(amount) FILTER (WHERE kind = 'out'), 0) AS o FROM fund_entries "
            "WHERE UPPER(store_code) = %s AND entry_date = %s", (store, date))
        e = cur.fetchone()
    entries_in, entries_out = float(e["i"] or 0), float(e["o"] or 0)
    return {"storeCode": store, "date": date, "opening": opening, "cashSales": cash_sales,
            "entriesIn": entries_in, "entriesOut": entries_out,
            "suggested": opening + cash_sales + entries_in - entries_out}


@app.get("/api/fund/suggest")
@login_required
def api_fund_suggest():
    viewer = _task_viewer()
    store = (request.args.get("storeCode") or viewer["store_code"]).upper()
    date = _valid_date(request.args.get("date") or _now_iso()[:10])
    if not store or not date:
        return _bad("Store and date are required")
    if not _in_scope(viewer, store):
        return _forbidden()
    return jsonify(_fund_suggestion(store, date))


@app.post("/api/fund/reports")
@login_required
def api_save_fund_report():
    viewer = _task_viewer()
    data = request.get_json(silent=True) or {}
    store = (data.get("storeCode") or viewer["store_code"]).strip().upper()
    if not store:
        return _bad("Store is required")
    if not _in_scope(viewer, store):
        return _forbidden()
    today = _now_iso()[:10]
    date = _valid_date(data.get("reportDate") or today)
    if not date:
        return _bad("Invalid date")
    if date > today:
        return _bad("Report date cannot be in the future")

    raw_counts = data.get("counts") or {}
    counts: dict[str, int] = {}
    total = 0.0
    for d in FUND_DENOMS:
        try:
            n = int(raw_counts.get(str(d), 0) or 0)
        except (TypeError, ValueError):
            return _bad("Invalid denomination count")
        if n < 0 or n > 100000:
            return _bad("Invalid denomination count")
        if n:
            counts[str(d)] = n
        total += d * n
    other = _to_amount(data.get("otherAmount", 0))
    if other is None:
        return _bad("Invalid amount")
    total += other
    system = _to_amount(data["systemBalance"]) if data.get("systemBalance") not in (None, "") else None
    if data.get("systemBalance") not in (None, "") and system is None:
        return _bad("Invalid amount")
    if system is None:
        system = _fund_suggestion(store, date)["suggested"]
    diff = total - system
    photos = _clean_photo_list(data.get("photoUrls"))
    note = (data.get("note") or "").strip()[:1000]

    db = get_db()
    with db.cursor() as cur:
        cur.execute("SELECT id, status, submitted_by FROM fund_reports WHERE store_code = %s AND report_date = %s", (store, date))
        existing = cur.fetchone()
        if existing:
            is_admin = _is_admin_user()
            if existing["status"] == "approved" and not is_admin:
                return _bad("Report already approved", 409)
            if existing["submitted_by"] != viewer["employee_id"] and not _manages(viewer, store):
                return _forbidden()
            if existing["status"] == "approved":
                # An admin correcting an approved report keeps it approved.
                cur.execute(
                    "UPDATE fund_reports SET counts_json=%s, other_amount=%s, cash_total=%s, system_balance=%s, difference=%s, "
                    "note=%s, photo_urls=%s, updated_at=%s WHERE id=%s",
                    (json.dumps(counts), other, total, system, diff, note, json.dumps(photos), _now_iso(), existing["id"]))
            else:
                cur.execute(
                    "UPDATE fund_reports SET counts_json=%s, other_amount=%s, cash_total=%s, system_balance=%s, difference=%s, "
                    "note=%s, photo_urls=%s, status='submitted', reviewed_by=NULL, reviewed_at=NULL, review_note=NULL, "
                    "updated_at=%s WHERE id=%s",
                    (json.dumps(counts), other, total, system, diff, note, json.dumps(photos), _now_iso(), existing["id"]))
            report_id = existing["id"]
        else:
            cur.execute(
                "INSERT INTO fund_reports (store_code, report_date, counts_json, other_amount, cash_total, system_balance, "
                "difference, note, photo_urls, submitted_by, created_at, updated_at) "
                "VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id",
                (store, date, json.dumps(counts), other, total, system, diff, note, json.dumps(photos),
                 viewer["employee_id"], _now_iso(), _now_iso()))
            report_id = cur.fetchone()["id"]
    db.commit()

    link = f"/fund/{report_id}"
    where = f"{_store_name(store)} ngày {_vn_date_text(date)}"
    if round(diff) != 0:
        _notify_managers(store, viewer["employee_id"], "fund_diff", "Quỹ bị lệch",
                         f"{where}: {'thừa' if diff > 0 else 'thiếu'} {_vnd(abs(diff))}", link,
                         f"fund_diff:{store}:{date}:{int(round(diff))}")
    else:
        _notify_managers(store, viewer["employee_id"], "fund_new", "Báo cáo quỹ chờ duyệt",
                         f"{where}: {_vnd(total)}, khớp hệ thống", link, f"fund_new:{store}:{date}:{int(round(total))}")
    with db.cursor() as cur:
        cur.execute(_FUND_SELECT + "WHERE f.id = %s", (report_id,))
        row = cur.fetchone()
    return jsonify(_fund_report_to_json(row)), 200 if existing else 201


@app.get("/api/fund/reports")
@login_required
def api_list_fund_reports():
    viewer = _task_viewer()
    where, params = [], []
    if viewer["can_manage"]:
        if viewer["scope"] is not None:
            where.append("UPPER(f.store_code) = ANY(%s)")
            params.append(list(viewer["scope"]) or [""])
    else:
        where.append("f.submitted_by = %s")
        params.append(viewer["employee_id"])
    store = (request.args.get("storeCode") or "").strip().upper()
    if store:
        where.append("UPPER(f.store_code) = %s")
        params.append(store)
    status = request.args.get("status")
    if status in ("submitted", "approved", "rejected"):
        where.append("f.status = %s")
        params.append(status)
    for key, op in (("from", ">="), ("to", "<=")):
        d = _valid_date(request.args.get(key)) if request.args.get(key) else None
        if d:
            where.append(f"f.report_date {op} %s")
            params.append(d)
    try:
        limit = max(1, min(int(request.args.get("limit", 60)), 200))
    except ValueError:
        limit = 60
    sql = _FUND_SELECT + ("WHERE " + " AND ".join(where) + " " if where else "")
    sql += "ORDER BY f.report_date DESC, f.id DESC LIMIT %s"
    with get_db().cursor() as cur:
        cur.execute(sql, params + [limit])
        rows = cur.fetchall()
    admin = _is_admin_user()
    out = []
    for r in rows:
        item = _fund_report_to_json(r)
        item["canEdit"] = _can_edit_fund_report(viewer, r, admin)
        item["canDelete"] = _can_delete_fund_report(viewer, r)
        out.append(item)
    return jsonify({"reports": out, "canManage": viewer["can_manage"]})


def _load_fund_report(report_id: int) -> dict | None:
    with get_db().cursor() as cur:
        cur.execute(_FUND_SELECT + "WHERE f.id = %s", (report_id,))
        return cur.fetchone()


@app.get("/api/fund/reports/<int:report_id>")
@login_required
def api_get_fund_report(report_id: int):
    viewer = _task_viewer()
    row = _load_fund_report(report_id)
    if not row:
        return _bad("Report not found", 404)
    if row["submitted_by"] != viewer["employee_id"] and not _manages(viewer, row["store_code"]):
        return _forbidden()
    out = _fund_report_to_json(row)
    out["canReview"] = _manages(viewer, row["store_code"]) and row["status"] == "submitted"
    out["canEdit"] = _can_edit_fund_report(viewer, row)
    out["canDelete"] = _can_delete_fund_report(viewer, row)
    with get_db().cursor() as cur:
        cur.execute(
            "SELECT e.id, e.kind, e.amount, e.reason, e.photo_urls, ee.full_name AS by_name FROM fund_entries e "
            "LEFT JOIN employees ee ON ee.id = e.created_by "
            "WHERE UPPER(e.store_code) = UPPER(%s) AND e.entry_date = %s ORDER BY e.id",
            (row["store_code"], row["report_date"]))
        out["entries"] = [{"id": r["id"], "kind": r["kind"], "amount": r["amount"], "reason": r["reason"] or "",
                           "photoUrls": _json_list(r["photo_urls"]), "createdByName": r["by_name"] or ""}
                          for r in cur.fetchall()]
    return jsonify(out)


def _can_edit_fund_report(viewer: dict, row: dict, admin: bool | None = None) -> bool:
    if admin is None:
        admin = _is_admin_user()
    if admin:
        return True
    return row["status"] != "approved" and (row["submitted_by"] == viewer["employee_id"] or _manages(viewer, row["store_code"]))


def _can_delete_fund_report(viewer: dict, row: dict) -> bool:
    """Admins can delete any report; the author or a store manager only while it is not yet approved."""
    if _is_admin_user():
        return True
    if row["status"] == "approved":
        return False
    return row["submitted_by"] == viewer["employee_id"] or _manages(viewer, row["store_code"])


@app.delete("/api/fund/reports/<int:report_id>")
@login_required
def api_delete_fund_report(report_id: int):
    viewer = _task_viewer()
    row = _load_fund_report(report_id)
    if not row:
        return _bad("Report not found", 404)
    if row["submitted_by"] != viewer["employee_id"] and not _manages(viewer, row["store_code"]):
        return _forbidden()
    if not _can_delete_fund_report(viewer, row):
        return _bad("Only an admin can delete an approved report", 403)
    db = get_db()
    with db.cursor() as cur:
        cur.execute("DELETE FROM fund_reports WHERE id = %s", (report_id,))
    db.commit()
    return jsonify({"ok": True})


@app.post("/api/fund/reports/<int:report_id>/review")
@login_required
def api_review_fund_report(report_id: int):
    viewer = _task_viewer()
    row = _load_fund_report(report_id)
    if not row:
        return _bad("Report not found", 404)
    if not _manages(viewer, row["store_code"]):
        return _forbidden()
    data = request.get_json(silent=True) or {}
    decision = data.get("decision")
    note = (data.get("note") or "").strip()[:500]
    if decision not in ("approve", "reject"):
        return _bad("Invalid decision")
    if row["status"] != "submitted":
        return _bad("Report is not awaiting review", 409)
    if decision == "reject" and not note:
        return _bad("A note is required to reject a report")
    status = "approved" if decision == "approve" else "rejected"
    db = get_db()
    with db.cursor() as cur:
        cur.execute("UPDATE fund_reports SET status=%s, reviewed_by=%s, reviewed_at=%s, review_note=%s, updated_at=%s "
                    "WHERE id=%s", (status, viewer["employee_id"], _now_iso(), note, _now_iso(), report_id))
    db.commit()
    if row["submitted_by"] and row["submitted_by"] != viewer["employee_id"]:
        where = f"{_store_name(row['store_code'])} ngày {_vn_date_text(row['report_date'])}"
        _notify(row["submitted_by"], "fund_review",
                "Báo cáo quỹ đã được duyệt" if status == "approved" else "Báo cáo quỹ bị từ chối",
                f"{where}" + (f": {note}" if note else ""), None, None, True, f"/fund/{report_id}")
    return jsonify(_fund_report_to_json(_load_fund_report(report_id)))


@app.get("/api/fund/missing")
@login_required
def api_fund_missing():
    """Stores in the manager's scope that have not filed a fund report for the date."""
    viewer = _task_viewer()
    if not viewer["can_manage"]:
        return _forbidden()
    date = _valid_date(request.args.get("date") or _now_iso()[:10])
    if not date:
        return _bad("Invalid date")
    sql = ("SELECT s.store_code, s.name FROM stores s WHERE NOT (COALESCE(s.status,'') ILIKE '%%đóng%%' "
           "OR COALESCE(s.status,'') ILIKE '%%ngừng%%') AND NOT EXISTS (SELECT 1 FROM fund_reports f "
           "WHERE UPPER(f.store_code) = UPPER(s.store_code) AND f.report_date = %s) ")
    params: list[Any] = [date]
    if viewer["scope"] is not None:
        sql += "AND UPPER(s.store_code) = ANY(%s) "
        params.append(list(viewer["scope"]) or [""])
    sql += "ORDER BY s.store_code"
    with get_db().cursor() as cur:
        cur.execute(sql, params)
        rows = cur.fetchall()
    return jsonify({"date": date, "stores": [{"storeCode": r["store_code"], "storeName": r["name"]} for r in rows]})


@app.get("/api/fund/entries")
@login_required
def api_list_fund_entries():
    viewer = _task_viewer()
    store = (request.args.get("storeCode") or viewer["store_code"]).upper()
    date = _valid_date(request.args.get("date") or _now_iso()[:10])
    if not store or not date:
        return _bad("Store and date are required")
    if not _in_scope(viewer, store):
        return _forbidden()
    with get_db().cursor() as cur:
        cur.execute(
            "SELECT e.id, e.kind, e.amount, e.reason, e.photo_urls, e.created_by, ee.full_name AS by_name "
            "FROM fund_entries e LEFT JOIN employees ee ON ee.id = e.created_by "
            "WHERE UPPER(e.store_code) = %s AND e.entry_date = %s ORDER BY e.id DESC", (store, date))
        rows = cur.fetchall()
    return jsonify({"storeCode": store, "date": date, "entries": [
        {"id": r["id"], "kind": r["kind"], "amount": r["amount"], "reason": r["reason"] or "",
         "photoUrls": _json_list(r["photo_urls"]), "createdByName": r["by_name"] or "",
         "canDelete": r["created_by"] == viewer["employee_id"] or _manages(viewer, store),
         "canEdit": r["created_by"] == viewer["employee_id"] or _manages(viewer, store)} for r in rows]})


@app.post("/api/fund/entries")
@login_required
def api_create_fund_entry():
    viewer = _task_viewer()
    data = request.get_json(silent=True) or {}
    store = (data.get("storeCode") or viewer["store_code"]).strip().upper()
    if not store:
        return _bad("Store is required")
    if not _in_scope(viewer, store):
        return _forbidden()
    kind = data.get("kind")
    amount = _to_amount(data.get("amount"))
    date = _valid_date(data.get("entryDate") or _now_iso()[:10])
    if kind not in ("in", "out") or not amount or amount <= 0 or not date:
        return _bad("Invalid fund entry")
    if date > _now_iso()[:10]:
        return _bad("Report date cannot be in the future")
    reason = (data.get("reason") or "").strip()[:300]
    if not reason:
        return _bad("A reason is required")
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO fund_entries (store_code, entry_date, kind, amount, reason, photo_urls, created_by, created_at) "
            "VALUES (%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id",
            (store, date, kind, amount, reason, json.dumps(_clean_photo_list(data.get("photoUrls"))),
             viewer["employee_id"], _now_iso()))
        new_id = cur.fetchone()["id"]
    db.commit()
    return jsonify({"id": new_id}), 201


@app.put("/api/fund/entries/<int:entry_id>")
@login_required
def api_update_fund_entry(entry_id: int):
    viewer = _task_viewer()
    db = get_db()
    with db.cursor() as cur:
        cur.execute("SELECT store_code, created_by FROM fund_entries WHERE id = %s", (entry_id,))
        row = cur.fetchone()
    if not row:
        return _bad("Entry not found", 404)
    if row["created_by"] != viewer["employee_id"] and not _manages(viewer, row["store_code"]):
        return _forbidden()
    data = request.get_json(silent=True) or {}
    kind = data.get("kind")
    amount = _to_amount(data.get("amount"))
    reason = (data.get("reason") or "").strip()[:300]
    if kind not in ("in", "out") or not amount or amount <= 0:
        return _bad("Invalid fund entry")
    if not reason:
        return _bad("A reason is required")
    with db.cursor() as cur:
        cur.execute("UPDATE fund_entries SET kind=%s, amount=%s, reason=%s, photo_urls=%s WHERE id=%s",
                    (kind, amount, reason, json.dumps(_clean_photo_list(data.get("photoUrls"))), entry_id))
    db.commit()
    return jsonify({"ok": True})


@app.delete("/api/fund/entries/<int:entry_id>")
@login_required
def api_delete_fund_entry(entry_id: int):
    viewer = _task_viewer()
    db = get_db()
    with db.cursor() as cur:
        cur.execute("SELECT store_code, created_by FROM fund_entries WHERE id = %s", (entry_id,))
        row = cur.fetchone()
        if not row:
            return _bad("Entry not found", 404)
        if row["created_by"] != viewer["employee_id"] and not _manages(viewer, row["store_code"]):
            return _forbidden()
        cur.execute("DELETE FROM fund_entries WHERE id = %s", (entry_id,))
    db.commit()
    return jsonify({"ok": True})


# ----------------------------- purchase orders + receiving -------------------

_ORDER_SELECT = (
    "SELECT o.*, s.name AS store_name, cb.full_name AS creator_name, rb.full_name AS receiver_name, "
    "(SELECT COUNT(*) FROM purchase_order_items i WHERE i.order_id = o.id) AS item_count, "
    "(SELECT COALESCE(SUM(i.qty), 0) FROM purchase_order_items i WHERE i.order_id = o.id) AS total_qty "
    "FROM purchase_orders o "
    "LEFT JOIN stores s ON UPPER(s.store_code) = UPPER(o.store_code) "
    "LEFT JOIN employees cb ON cb.id = o.created_by "
    "LEFT JOIN employees rb ON rb.id = o.received_by "
)


def _order_to_json(r: dict, items: list | None = None) -> dict:
    out = {
        "id": r["id"], "storeCode": r["store_code"], "storeName": r.get("store_name") or r["store_code"],
        "orderDate": r["order_date"], "status": r["status"], "supplier": r.get("supplier") or "",
        "note": r.get("note") or "", "createdById": r.get("created_by"), "createdByName": r.get("creator_name") or "",
        "approvedAt": r.get("approved_at"), "orderedAt": r.get("ordered_at"), "receivedAt": r.get("received_at"),
        "receivedByName": r.get("receiver_name") or "", "receiptNote": r.get("receipt_note") or "",
        "receiptPhotos": _json_list(r.get("receipt_photos")), "itemCount": int(r.get("item_count") or 0),
        "totalQty": float(r.get("total_qty") or 0), "createdAt": r.get("created_at"), "updatedAt": r.get("updated_at"),
    }
    if items is not None:
        out["items"] = items
    return out


def _order_items(order_id: int) -> list[dict]:
    with get_db().cursor() as cur:
        cur.execute("SELECT id, product_id, product_name, unit, qty, qty_received, note FROM purchase_order_items "
                    "WHERE order_id = %s ORDER BY id", (order_id,))
        return [{"id": i["id"], "productId": i["product_id"], "productName": i["product_name"], "unit": i["unit"] or "",
                 "qty": i["qty"], "qtyReceived": i["qty_received"], "note": i["note"] or ""} for i in cur.fetchall()]


def _load_order(order_id: int) -> dict | None:
    with get_db().cursor() as cur:
        cur.execute(_ORDER_SELECT + "WHERE o.id = %s", (order_id,))
        return cur.fetchone()


def _parse_order_items(raw: Any):
    """Validated [(product_id, name, unit, qty, note)] or an error message."""
    if not isinstance(raw, list) or not raw:
        return "At least one item is required"
    if len(raw) > 200:
        return "Too many items"
    out = []
    with get_db().cursor() as cur:
        for it in raw:
            if not isinstance(it, dict):
                return "Invalid item"
            qty = _to_amount(it.get("qty"))
            if not qty or qty <= 0 or qty > 100000:
                return "Invalid quantity"
            name = (it.get("productName") or "").strip()
            unit = (it.get("unit") or "").strip()
            pid = it.get("productId")
            if pid:
                try:
                    cur.execute("SELECT name, unit FROM products WHERE id = %s", (int(pid),))
                except (TypeError, ValueError):
                    return "Invalid product"
                p = cur.fetchone()
                if not p:
                    return "Product not found"
                name, unit = name or p["name"], unit or (p["unit"] or "")
            if not name:
                return "Product name is required"
            out.append((int(pid) if pid else None, name[:200], unit[:40], qty, (it.get("note") or "").strip()[:200]))
    return out


@app.get("/api/orders/catalog")
@login_required
def api_order_catalog():
    q = (request.args.get("q") or "").strip()
    sql, params = "SELECT id, name, unit, product_group FROM products ", []
    if q:
        sql += "WHERE name ILIKE %s "
        params.append(f"%{q}%")
    sql += "ORDER BY name LIMIT 200"
    with get_db().cursor() as cur:
        cur.execute(sql, params)
        rows = cur.fetchall()
    return jsonify({"products": [{"id": r["id"], "name": r["name"], "unit": r["unit"] or "", "group": r["product_group"] or ""} for r in rows]})


@app.get("/api/orders/last")
@login_required
def api_order_last():
    """Items of the store's latest non-cancelled order, for the 'copy last order' shortcut."""
    viewer = _task_viewer()
    store = (request.args.get("storeCode") or viewer["store_code"]).upper()
    if not store or not _in_scope(viewer, store):
        return _forbidden()
    with get_db().cursor() as cur:
        cur.execute("SELECT id, order_date FROM purchase_orders WHERE UPPER(store_code) = %s AND status <> 'cancelled' "
                    "ORDER BY order_date DESC, id DESC LIMIT 1", (store,))
        o = cur.fetchone()
    if not o:
        return jsonify({"orderDate": None, "items": []})
    items = [{"productId": i["productId"], "productName": i["productName"], "unit": i["unit"], "qty": i["qty"], "note": i["note"]}
             for i in _order_items(o["id"])]
    return jsonify({"orderDate": o["order_date"], "items": items})


@app.post("/api/orders")
@login_required
def api_create_order():
    viewer = _task_viewer()
    data = request.get_json(silent=True) or {}
    store = (data.get("storeCode") or viewer["store_code"]).strip().upper()
    if not store:
        return _bad("Store is required")
    if not _in_scope(viewer, store):
        return _forbidden()
    date = _valid_date(data.get("orderDate") or _now_iso()[:10])
    if not date:
        return _bad("Invalid date")
    items = _parse_order_items(data.get("items"))
    if isinstance(items, str):
        return _bad(items)
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO purchase_orders (store_code, order_date, supplier, note, created_by, created_at, updated_at) "
            "VALUES (%s,%s,%s,%s,%s,%s,%s) RETURNING id",
            (store, date, (data.get("supplier") or "").strip()[:120], (data.get("note") or "").strip()[:500],
             viewer["employee_id"], _now_iso(), _now_iso()))
        order_id = cur.fetchone()["id"]
        for pid, name, unit, qty, note in items:
            cur.execute("INSERT INTO purchase_order_items (order_id, product_id, product_name, unit, qty, note) "
                        "VALUES (%s,%s,%s,%s,%s,%s)", (order_id, pid, name, unit, qty, note))
    db.commit()
    _notify_managers(store, viewer["employee_id"], "order_new", "Đơn đặt hàng mới",
                     f"{_store_name(store)}: {len(items)} mặt hàng, ngày {_vn_date_text(date)}", f"/orders/{order_id}")
    return jsonify(_order_to_json(_load_order(order_id), _order_items(order_id))), 201


@app.get("/api/orders")
@login_required
def api_list_orders():
    viewer = _task_viewer()
    where, params = [], []
    if viewer["scope"] is not None:
        where.append("UPPER(o.store_code) = ANY(%s)")
        params.append(list(viewer["scope"]) or [""])
    store = (request.args.get("storeCode") or "").strip().upper()
    if store:
        where.append("UPPER(o.store_code) = %s")
        params.append(store)
    status = request.args.get("status")
    if status == "open":
        where.append("o.status = ANY(%s)")
        params.append(list(ORDER_OPEN_STATUSES))
    elif status in ("submitted", "approved", "ordered", "partial", "delivered", "cancelled"):
        where.append("o.status = %s")
        params.append(status)
    date = _valid_date(request.args.get("date")) if request.args.get("date") else None
    if date:
        where.append("o.order_date = %s")
        params.append(date)
    sql = _ORDER_SELECT + ("WHERE " + " AND ".join(where) + " " if where else "") + "ORDER BY o.order_date DESC, o.id DESC LIMIT 100"
    with get_db().cursor() as cur:
        cur.execute(sql, params)
        rows = cur.fetchall()
    admin = _is_admin_user()
    out = []
    for r in rows:
        item = _order_to_json(r)
        mine, manages = r["created_by"] == viewer["employee_id"], _manages(viewer, r["store_code"])
        item["canEdit"] = admin or (r["status"] == "submitted" and (mine or manages)) or (r["status"] == "approved" and manages)
        item["canDelete"] = admin
        out.append(item)
    return jsonify({"orders": out, "canManage": viewer["can_manage"]})


@app.get("/api/orders/summary")
@login_required
def api_orders_summary():
    """Quantities per product summed across stores, for the person who places the supplier order."""
    viewer = _task_viewer()
    if not viewer["can_manage"]:
        return _forbidden()
    date = _valid_date(request.args.get("date") or _now_iso()[:10])
    if not date:
        return _bad("Invalid date")
    statuses = [x for x in (request.args.get("statuses") or "submitted,approved").split(",")
                if x in ("submitted", "approved", "ordered", "partial", "delivered")] or ["submitted", "approved"]
    sql = ("SELECT i.product_name, i.unit, o.store_code, SUM(i.qty) AS qty FROM purchase_order_items i "
           "JOIN purchase_orders o ON o.id = i.order_id WHERE o.order_date = %s AND o.status = ANY(%s) ")
    params: list[Any] = [date, statuses]
    if viewer["scope"] is not None:
        sql += "AND UPPER(o.store_code) = ANY(%s) "
        params.append(list(viewer["scope"]) or [""])
    sql += "GROUP BY i.product_name, i.unit, o.store_code ORDER BY i.product_name, o.store_code"
    with get_db().cursor() as cur:
        cur.execute(sql, params)
        rows = cur.fetchall()
        cur.execute("SELECT COUNT(*) AS c FROM purchase_orders o WHERE o.order_date = %s AND o.status = ANY(%s)" +
                    (" AND UPPER(o.store_code) = ANY(%s)" if viewer["scope"] is not None else ""),
                    [date, statuses] + ([list(viewer["scope"]) or [""]] if viewer["scope"] is not None else []))
        n_orders = cur.fetchone()["c"]
    products: dict[tuple, dict] = {}
    for r in rows:
        key = (r["product_name"], r["unit"] or "")
        p = products.setdefault(key, {"productName": r["product_name"], "unit": r["unit"] or "", "total": 0.0, "byStore": []})
        p["total"] += float(r["qty"])
        p["byStore"].append({"storeCode": r["store_code"], "storeName": _store_name(r["store_code"]), "qty": float(r["qty"])})
    items = sorted(products.values(), key=lambda p: (-p["total"], p["productName"]))
    return jsonify({"date": date, "statuses": statuses, "orders": n_orders, "items": items})


@app.get("/api/orders/<int:order_id>")
@login_required
def api_get_order(order_id: int):
    viewer = _task_viewer()
    row = _load_order(order_id)
    if not row:
        return _bad("Order not found", 404)
    if not _in_scope(viewer, row["store_code"]):
        return _forbidden()
    out = _order_to_json(row, _order_items(order_id))
    mine = row["created_by"] == viewer["employee_id"]
    manages = _manages(viewer, row["store_code"])
    out["canManage"] = manages
    admin = _is_admin_user()
    out["canEdit"] = admin or (row["status"] == "submitted" and (mine or manages)) or (row["status"] == "approved" and manages)
    out["canDelete"] = admin
    out["canCancel"] = row["status"] in ("submitted", "approved", "ordered") and (manages or (mine and row["status"] == "submitted"))
    out["canReceive"] = row["status"] in ("submitted", "approved", "ordered", "partial")
    return jsonify(out)


@app.put("/api/orders/<int:order_id>")
@login_required
def api_update_order(order_id: int):
    viewer = _task_viewer()
    row = _load_order(order_id)
    if not row:
        return _bad("Order not found", 404)
    mine = row["created_by"] == viewer["employee_id"]
    manages = _manages(viewer, row["store_code"])
    if not (_is_admin_user() or (row["status"] == "submitted" and (mine or manages)) or (row["status"] == "approved" and manages)):
        return _forbidden() if not (mine or manages) else _bad("Order can no longer be edited", 409)
    data = request.get_json(silent=True) or {}
    items = _parse_order_items(data.get("items"))
    if isinstance(items, str):
        return _bad(items)
    db = get_db()
    with db.cursor() as cur:
        cur.execute("UPDATE purchase_orders SET supplier=%s, note=%s, updated_at=%s WHERE id=%s",
                    ((data.get("supplier") or "").strip()[:120], (data.get("note") or "").strip()[:500], _now_iso(), order_id))
        cur.execute("DELETE FROM purchase_order_items WHERE order_id = %s", (order_id,))
        for pid, name, unit, qty, note in items:
            cur.execute("INSERT INTO purchase_order_items (order_id, product_id, product_name, unit, qty, note) "
                        "VALUES (%s,%s,%s,%s,%s,%s)", (order_id, pid, name, unit, qty, note))
    db.commit()
    return jsonify(_order_to_json(_load_order(order_id), _order_items(order_id)))


@app.delete("/api/orders/<int:order_id>")
@login_required
def api_delete_order(order_id: int):
    """Admins can remove any order outright (items go with it); everyone else cancels instead."""
    if not _is_admin_user():
        return _forbidden()
    if not _load_order(order_id):
        return _bad("Order not found", 404)
    db = get_db()
    with db.cursor() as cur:
        cur.execute("DELETE FROM purchase_orders WHERE id = %s", (order_id,))
    db.commit()
    return jsonify({"ok": True})


@app.post("/api/orders/<int:order_id>/status")
@login_required
def api_set_order_status(order_id: int):
    viewer = _task_viewer()
    row = _load_order(order_id)
    if not row:
        return _bad("Order not found", 404)
    if not _in_scope(viewer, row["store_code"]):
        return _forbidden()
    status = (request.get_json(silent=True) or {}).get("status")
    mine = row["created_by"] == viewer["employee_id"]
    manages = _manages(viewer, row["store_code"])
    now = _now_iso()
    sets, params = ["status = %s", "updated_at = %s"], [status, now]
    if status == "approved":
        if not manages:
            return _forbidden()
        if row["status"] != "submitted":
            return _bad("Order is not awaiting approval", 409)
        sets += ["approved_by = %s", "approved_at = %s"]
        params += [viewer["employee_id"], now]
    elif status == "ordered":
        if not manages:
            return _forbidden()
        if row["status"] not in ("submitted", "approved"):
            return _bad("Order cannot be marked as ordered", 409)
        sets += ["ordered_at = %s", "approved_by = COALESCE(approved_by, %s)", "approved_at = COALESCE(approved_at, %s)"]
        params += [now, viewer["employee_id"], now]
    elif status == "cancelled":
        if row["status"] not in ("submitted", "approved", "ordered"):
            return _bad("Order cannot be cancelled", 409)
        if not (manages or (mine and row["status"] == "submitted")):
            return _forbidden()
    else:
        return _bad("Invalid status")
    db = get_db()
    with db.cursor() as cur:
        cur.execute(f"UPDATE purchase_orders SET {', '.join(sets)} WHERE id = %s", params + [order_id])
    db.commit()
    if row["created_by"] and row["created_by"] != viewer["employee_id"]:
        _notify(row["created_by"], "order_status", f"Đơn đặt hàng {ORDER_LABELS[status]}",
                f"{_store_name(row['store_code'])} ngày {_vn_date_text(row['order_date'])}", None, None, True, f"/orders/{order_id}")
    return jsonify(_order_to_json(_load_order(order_id), _order_items(order_id)))


@app.post("/api/orders/<int:order_id>/receive")
@login_required
def api_receive_order(order_id: int):
    """Confirm what actually arrived; short lines flip the order to 'partial' and alert the managers."""
    viewer = _task_viewer()
    row = _load_order(order_id)
    if not row:
        return _bad("Order not found", 404)
    if not _in_scope(viewer, row["store_code"]):
        return _forbidden()
    if row["status"] not in ("submitted", "approved", "ordered", "partial"):
        return _bad("Order cannot be received", 409)
    data = request.get_json(silent=True) or {}
    received = data.get("items")
    items = _order_items(order_id)
    if not isinstance(received, list):
        return _bad("Items are required")
    qty_by_id: dict[int, float] = {}
    for r in received:
        try:
            iid, q = int(r.get("id")), _to_amount(r.get("qtyReceived"))
        except (TypeError, ValueError, AttributeError):
            return _bad("Invalid received quantity")
        if q is None or q > 100000:
            return _bad("Invalid received quantity")
        qty_by_id[iid] = q
    valid_ids = {i["id"] for i in items}
    if not qty_by_id or not set(qty_by_id) <= valid_ids:
        return _bad("Invalid received quantity")
    photos = _clean_photo_list(data.get("photoUrls"))
    note = (data.get("note") or "").strip()[:500]
    db = get_db()
    short = []
    with db.cursor() as cur:
        for it in items:
            q = qty_by_id.get(it["id"], it["qtyReceived"])
            if q is None:
                q = 0.0
            if it["id"] in qty_by_id:
                cur.execute("UPDATE purchase_order_items SET qty_received = %s WHERE id = %s", (q, it["id"]))
            if q < it["qty"]:
                short.append(f"{it['productName']} ({q:g}/{it['qty']:g})")
        status = "partial" if short else "delivered"
        cur.execute("UPDATE purchase_orders SET status=%s, received_at=%s, received_by=%s, receipt_note=%s, "
                    "receipt_photos=%s, updated_at=%s WHERE id=%s",
                    (status, _now_iso(), viewer["employee_id"], note,
                     json.dumps((_json_list(row.get("receipt_photos")) + photos)[:20]), _now_iso(), order_id))
    db.commit()
    where = f"{_store_name(row['store_code'])} ngày {_vn_date_text(row['order_date'])}"
    link = f"/orders/{order_id}"
    if short:
        _notify_managers(row["store_code"], viewer["employee_id"], "order_short", "Nhận hàng bị thiếu",
                         f"{where}: " + ", ".join(short[:4]) + ("..." if len(short) > 4 else ""), link)
    else:
        _notify_managers(row["store_code"], viewer["employee_id"], "order_received", "Đã nhận đủ hàng",
                         f"{where}: {viewer['name']} đã nhận hàng" + (f". {note}" if note else ""), link)
    if row["created_by"] and row["created_by"] != viewer["employee_id"] and row["created_by"] not in _manager_ids(row["store_code"]):
        _notify(row["created_by"], "order_status", f"Đơn đặt hàng {ORDER_LABELS[status]}", where, None, None, True, link)
    return jsonify(_order_to_json(_load_order(order_id), _order_items(order_id)))


# ----------------------------- announcements (bảng tin) ----------------------

def _audience_where(stores: list[str], positions: list[str], alias: str = "e") -> tuple[str, list]:
    sql, params = "", []
    if stores:
        sql += f" AND UPPER(COALESCE({alias}.store_code,'')) = ANY(%s)"
        params.append([s.upper() for s in stores])
    if positions:
        sql += f" AND UPPER(COALESCE({alias}.position,'')) = ANY(%s)"
        params.append([p.upper() for p in positions])
    return sql, params


def _audience_rows(stores: list[str], positions: list[str]) -> list[dict]:
    frag, params = _audience_where(stores, positions)
    with get_db().cursor() as cur:
        cur.execute("SELECT e.id, e.full_name, e.store_code, e.position FROM employees e WHERE e.is_active = 1" + frag +
                    " ORDER BY e.store_code, e.full_name", params)
        return cur.fetchall()


def _ann_matches(row: dict, store_code: str, position: str) -> bool:
    stores = [s.upper() for s in _json_list(row.get("audience_stores"))]
    positions = [p.upper() for p in _json_list(row.get("audience_positions"))]
    return (not stores or store_code.upper() in stores) and (not positions or position.upper() in positions)


def _ann_visible(row: dict, viewer: dict) -> bool:
    if row.get("created_by") == viewer["employee_id"] or _ann_matches(row, viewer["store_code"], viewer["position"]):
        return True
    if not viewer["can_manage"]:
        return False
    stores = [s.upper() for s in _json_list(row.get("audience_stores"))]
    return viewer["scope"] is None or any(s in viewer["scope"] for s in stores)


def _ann_stats(row: dict) -> tuple[int, int]:
    stores = _json_list(row.get("audience_stores"))
    positions = _json_list(row.get("audience_positions"))
    frag, params = _audience_where(stores, positions)
    with get_db().cursor() as cur:
        cur.execute("SELECT COUNT(*) AS c FROM employees e WHERE e.is_active = 1" + frag, params)
        total = cur.fetchone()["c"]
        cur.execute("SELECT COUNT(*) AS c FROM announcement_reads r JOIN employees e ON e.id = r.employee_id "
                    "WHERE r.announcement_id = %s AND e.is_active = 1" + frag, [row["id"]] + params)
        read = cur.fetchone()["c"]
    return int(total), int(read)


_ANN_SELECT = ("SELECT a.*, cb.full_name AS author_name, "
               "EXISTS (SELECT 1 FROM announcement_reads r WHERE r.announcement_id = a.id AND r.employee_id = %s) AS is_read "
               "FROM announcements a LEFT JOIN employees cb ON cb.id = a.created_by ")


def _ann_to_json(row: dict, viewer: dict, with_stats: bool = False) -> dict:
    out = {
        "id": row["id"], "title": row["title"], "body": row.get("body") or "",
        "imageUrls": _json_list(row.get("image_urls")), "pinned": bool(row.get("pinned")),
        "audienceStores": _json_list(row.get("audience_stores")), "audiencePositions": _json_list(row.get("audience_positions")),
        "remindAt": row.get("remind_at"), "authorName": row.get("author_name") or "", "authorId": row.get("created_by"),
        "createdAt": row.get("created_at"), "isRead": bool(row.get("is_read")),
        "canManage": row.get("created_by") == viewer["employee_id"] or (viewer["can_manage"] and _ann_visible(row, viewer)),
    }
    if with_stats and out["canManage"]:
        out["audienceCount"], out["readCount"] = _ann_stats(row)
    return out


def _visible_announcements(viewer: dict) -> list[dict]:
    with get_db().cursor() as cur:
        cur.execute(_ANN_SELECT + "ORDER BY a.pinned DESC, a.id DESC LIMIT 200", (viewer["employee_id"],))
        rows = cur.fetchall()
    return [r for r in rows if _ann_visible(r, viewer)]


@app.get("/api/announcements")
@login_required
def api_list_announcements():
    viewer = _task_viewer()
    rows = _visible_announcements(viewer)[:60]
    return jsonify({"announcements": [_ann_to_json(r, viewer, with_stats=True) for r in rows], "canManage": viewer["can_manage"]})


@app.post("/api/announcements")
@login_required
def api_create_announcement():
    viewer = _task_viewer()
    if not viewer["can_manage"]:
        return _forbidden()
    data = request.get_json(silent=True) or {}
    title = (data.get("title") or "").strip()[:200]
    if not title:
        return _bad("Title is required")
    stores = sorted({str(s).strip().upper() for s in (data.get("stores") or []) if str(s).strip()})
    positions = sorted({str(p).strip().upper() for p in (data.get("positions") or []) if str(p).strip()})
    if viewer["scope"] is not None:
        if not stores:
            stores = sorted(viewer["scope"])  # a scoped manager can only address their own stores
        if not set(stores) <= viewer["scope"]:
            return _forbidden()
    remind_at = data.get("remindAt") or None
    if remind_at and not re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}", str(remind_at)):
        return _bad("Invalid reminder time")
    db = get_db()
    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO announcements (title, body, image_urls, audience_stores, audience_positions, pinned, remind_at, "
            "created_by, created_at) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id",
            (title, (data.get("body") or "").strip()[:5000], json.dumps(_clean_photo_list(data.get("imageUrls"))),
             json.dumps(stores), json.dumps(positions), 1 if data.get("pinned") else 0,
             str(remind_at)[:19] if remind_at else None, viewer["employee_id"], _now_iso()))
        ann_id = cur.fetchone()["id"]
    db.commit()
    for emp in _audience_rows(stores, positions):
        if emp["id"] != viewer["employee_id"]:
            _notify(emp["id"], "announcement", "Thông báo mới", f"{title}", None, None, False, f"/board/{ann_id}")
    with db.cursor() as cur:
        cur.execute(_ANN_SELECT + "WHERE a.id = %s", (viewer["employee_id"], ann_id))
        row = cur.fetchone()
    return jsonify(_ann_to_json(row, viewer, with_stats=True)), 201


def _load_announcement(ann_id: int, viewer: dict) -> dict | None:
    with get_db().cursor() as cur:
        cur.execute(_ANN_SELECT + "WHERE a.id = %s", (viewer["employee_id"], ann_id))
        return cur.fetchone()


@app.get("/api/announcements/<int:ann_id>")
@login_required
def api_get_announcement(ann_id: int):
    viewer = _task_viewer()
    row = _load_announcement(ann_id, viewer)
    if not row:
        return _bad("Announcement not found", 404)
    if not _ann_visible(row, viewer):
        return _forbidden()
    out = _ann_to_json(row, viewer, with_stats=True)
    if out["canManage"]:
        audience = _audience_rows(_json_list(row["audience_stores"]), _json_list(row["audience_positions"]))
        with get_db().cursor() as cur:
            cur.execute("SELECT employee_id, read_at FROM announcement_reads WHERE announcement_id = %s", (ann_id,))
            read_at = {r["employee_id"]: r["read_at"] for r in cur.fetchall()}
        person = lambda e: {"id": e["id"], "name": e["full_name"], "storeCode": e.get("store_code") or "", "position": e.get("position") or ""}
        out["readers"] = [{**person(e), "readAt": read_at[e["id"]]} for e in audience if e["id"] in read_at][:300]
        out["unread"] = [person(e) for e in audience if e["id"] not in read_at][:300]
    return jsonify(out)


@app.post("/api/announcements/<int:ann_id>/read")
@login_required
def api_read_announcement(ann_id: int):
    viewer = _task_viewer()
    row = _load_announcement(ann_id, viewer)
    if not row:
        return _bad("Announcement not found", 404)
    if not _ann_visible(row, viewer):
        return _forbidden()
    db = get_db()
    with db.cursor() as cur:
        cur.execute("INSERT INTO announcement_reads (announcement_id, employee_id, read_at) VALUES (%s,%s,%s) "
                    "ON CONFLICT DO NOTHING", (ann_id, viewer["employee_id"], _now_iso()))
        cur.execute("UPDATE notifications SET is_read = 1 WHERE employee_id = %s AND link = %s",
                    (viewer["employee_id"], f"/board/{ann_id}"))
    db.commit()
    return jsonify({"ok": True})


@app.put("/api/announcements/<int:ann_id>")
@login_required
def api_update_announcement(ann_id: int):
    """Edit the content of a post (audience and read receipts stay as they were)."""
    viewer = _task_viewer()
    row = _load_announcement(ann_id, viewer)
    if not row:
        return _bad("Announcement not found", 404)
    if not (row["created_by"] == viewer["employee_id"] or (viewer["can_manage"] and _ann_visible(row, viewer))):
        return _forbidden()
    data = request.get_json(silent=True) or {}
    title = (data.get("title") or "").strip()[:200]
    if not title:
        return _bad("Title is required")
    db = get_db()
    with db.cursor() as cur:
        cur.execute("UPDATE announcements SET title=%s, body=%s, image_urls=%s, pinned=%s WHERE id=%s",
                    (title, (data.get("body") or "").strip()[:5000], json.dumps(_clean_photo_list(data.get("imageUrls"))),
                     1 if data.get("pinned") else 0, ann_id))
    db.commit()
    return jsonify(_ann_to_json(_load_announcement(ann_id, viewer), viewer, with_stats=True))


@app.delete("/api/announcements/<int:ann_id>")
@login_required
def api_delete_announcement(ann_id: int):
    viewer = _task_viewer()
    row = _load_announcement(ann_id, viewer)
    if not row:
        return _bad("Announcement not found", 404)
    if not (row["created_by"] == viewer["employee_id"] or (viewer["can_manage"] and _ann_visible(row, viewer))):
        return _forbidden()
    db = get_db()
    with db.cursor() as cur:
        cur.execute("DELETE FROM announcements WHERE id = %s", (ann_id,))
    db.commit()
    return jsonify({"ok": True})


def _unread_audience(row: dict) -> list[dict]:
    audience = _audience_rows(_json_list(row["audience_stores"]), _json_list(row["audience_positions"]))
    with get_db().cursor() as cur:
        cur.execute("SELECT employee_id FROM announcement_reads WHERE announcement_id = %s", (row["id"],))
        seen = {r["employee_id"] for r in cur.fetchall()}
    return [e for e in audience if e["id"] not in seen]


@app.post("/api/announcements/<int:ann_id>/remind")
@login_required
def api_remind_announcement(ann_id: int):
    viewer = _task_viewer()
    row = _load_announcement(ann_id, viewer)
    if not row:
        return _bad("Announcement not found", 404)
    if not (row["created_by"] == viewer["employee_id"] or (viewer["can_manage"] and _ann_visible(row, viewer))):
        return _forbidden()
    today = _now_iso()[:10]
    sent = 0
    for e in _unread_audience(row):
        if e["id"] != viewer["employee_id"]:
            _notify(e["id"], "ann_remind", "Nhắc đọc thông báo", row["title"], None, f"ann_remind:{ann_id}:{today}", False, f"/board/{ann_id}")
            sent += 1
    return jsonify({"sent": sent})


@app.post("/api/announcements/<int:ann_id>/to-task")
@login_required
def api_announcement_to_task(ann_id: int):
    """Turn an announcement into a task for everyone in its audience (or a chosen subset)."""
    viewer = _task_viewer()
    row = _load_announcement(ann_id, viewer)
    if not row:
        return _bad("Announcement not found", 404)
    if not viewer["can_manage"] or not _ann_visible(row, viewer):
        return _forbidden()
    data = request.get_json(silent=True) or {}
    due = data.get("dueAt") or None
    if due and not re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}", str(due)):
        return _bad("Invalid deadline")
    audience = [e for e in _audience_rows(_json_list(row["audience_stores"]), _json_list(row["audience_positions"]))
                if _in_scope(viewer, e.get("store_code"))]
    chosen = data.get("assigneeIds")
    if isinstance(chosen, list) and chosen:
        wanted = {int(x) for x in chosen if str(x).isdigit()}
        audience = [e for e in audience if e["id"] in wanted]
    audience = audience[:100]
    if not audience:
        return _bad("No recipients")
    title = (data.get("title") or row["title"]).strip()[:200]
    db = get_db()
    ids = []
    with db.cursor() as cur:
        for e in audience:
            cur.execute(
                "INSERT INTO tasks (title, description, store_code, assignee_id, assigned_by, priority, due_at, "
                "created_at, updated_at) VALUES (%s,%s,%s,%s,%s,'normal',%s,%s,%s) RETURNING id",
                (title, row["body"] or "", (e.get("store_code") or "").upper(), e["id"], viewer["employee_id"],
                 str(due)[:19] if due else None, _now_iso(), _now_iso()))
            ids.append((e["id"], cur.fetchone()["id"]))
    db.commit()
    for emp_id, task_id in ids:
        if emp_id != viewer["employee_id"]:
            _notify(emp_id, "assigned", "Bạn được giao việc mới", f"{title} · giao bởi {viewer['name']}", task_id)
    return jsonify({"created": len(ids)}), 201


# ----------------------------- lazy reminders --------------------------------

def _sync_ops_reminders(employee_id: int) -> None:
    now = datetime.now(tz=VN_TZ)
    now_iso, today = now.strftime("%Y-%m-%dT%H:%M:%S"), now.strftime("%Y-%m-%d")
    db = get_db()
    with db.cursor() as cur:
        cur.execute("SELECT store_code, position FROM employees WHERE id = %s", (employee_id,))
        me = cur.fetchone() or {}
    store, position = (me.get("store_code") or "").upper(), (me.get("position") or "").upper()

    # 1) scheduled "unread announcement" reminders
    with db.cursor() as cur:
        cur.execute("SELECT a.* FROM announcements a WHERE a.remind_at IS NOT NULL AND a.remind_at <= %s AND NOT EXISTS "
                    "(SELECT 1 FROM announcement_reads r WHERE r.announcement_id = a.id AND r.employee_id = %s) "
                    "ORDER BY a.id DESC LIMIT 20", (now_iso, employee_id))
        due = cur.fetchall()
    for a in due:
        if _ann_matches(a, store, position):
            _notify(employee_id, "ann_remind", "Thông báo chưa đọc", a["title"], None, f"ann_due:{a['id']}", False, f"/board/{a['id']}")

    # 2) end-of-day cash report reminder for the people who normally file it
    if store and now.hour * 60 + now.minute >= 21 * 60 + 30:
        since = (now - timedelta(days=30)).strftime("%Y-%m-%d")
        with db.cursor() as cur:
            cur.execute("SELECT 1 FROM fund_reports WHERE UPPER(store_code) = %s AND report_date = %s", (store, today))
            if cur.fetchone():
                return
            cur.execute(
                "SELECT 1 WHERE EXISTS (SELECT 1 FROM fund_reports WHERE UPPER(store_code) = %s AND submitted_by = %s "
                "AND report_date >= %s) OR EXISTS (SELECT 1 FROM store_managers sm JOIN stores s ON s.id = sm.store_id "
                "WHERE UPPER(s.store_code) = %s AND sm.employee_id = %s)", (store, employee_id, since, store, employee_id))
            reporter = cur.fetchone()
        if reporter:
            _notify(employee_id, "fund_missing", "Chưa báo cáo quỹ hôm nay", f"{_store_name(store)} chưa có báo cáo quỹ ngày {_vn_date_text(today)}",
                    None, f"fund_missing:{store}:{today}", True, "/fund/new")


# ----------------------------- photo gallery, thumbnails, retention ----------

PHOTO_RETENTION_DAYS = int(os.getenv("PHOTO_RETENTION_DAYS", "0") or 0)  # 0 = keep forever
THUMB_WIDTHS = (160, 240, 400, 800)


def _thumb_for(full: Path, width: int) -> Path | None:
    """Resized JPEG copy (cached on disk). Returns None when Pillow is unavailable or the file is not an image."""
    try:
        from PIL import Image, ImageOps
    except ImportError:
        return None
    width = min(THUMB_WIDTHS, key=lambda w: abs(w - width))
    target = TASK_PHOTO_DIR / "thumbs" / str(width) / (full.stem + ".jpg")
    if target.is_file() and target.stat().st_mtime >= full.stat().st_mtime:
        return target
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        with Image.open(full) as im:
            im = ImageOps.exif_transpose(im)
            im.thumbnail((width, width * 4))
            im.convert("RGB").save(target, "JPEG", quality=78, optimize=True)
        return target
    except Exception:
        return None


def _cleanup_old_photos() -> int:
    """Delete photo files older than PHOTO_RETENTION_DAYS (off by default). Runs at most once a day."""
    if PHOTO_RETENTION_DAYS <= 0:
        return 0
    marker = TASK_PHOTO_DIR / ".last_cleanup"
    today = _now_iso()[:10]
    try:
        if marker.is_file() and marker.read_text().strip() == today:
            return 0
        marker.write_text(today)
    except OSError:
        return 0
    cutoff = datetime.now().timestamp() - PHOTO_RETENTION_DAYS * 86400
    removed = 0
    for f in TASK_PHOTO_DIR.iterdir():
        if f.is_file() and not f.name.startswith(".") and f.stat().st_mtime < cutoff:
            f.unlink(missing_ok=True)
            removed += 1
    shutil.rmtree(TASK_PHOTO_DIR / "thumbs", ignore_errors=True)
    return removed


@app.get("/api/media")
@login_required
def api_media_gallery():
    """Every photo attached to tasks, fund reports, receipts and announcements, newest first (managers)."""
    viewer = _task_viewer()
    if not viewer["can_manage"]:
        return _forbidden()
    _cleanup_old_photos()
    kind = request.args.get("kind", "all")
    store = (request.args.get("storeCode") or "").strip().upper()
    frm = _valid_date(request.args.get("from")) if request.args.get("from") else None
    to = _valid_date(request.args.get("to")) if request.args.get("to") else None
    items: list[dict] = []

    def add(names_json, kind_, title, store_code, date, link):
        for n in _json_list(names_json):
            items.append({"name": n, "kind": kind_, "title": title, "storeCode": (store_code or "").upper(),
                          "date": (date or "")[:10], "link": link})

    def scoped(col: str, params: list) -> str:
        frag = ""
        if viewer["scope"] is not None:
            frag += f" AND UPPER({col}) = ANY(%s)"
            params.append(list(viewer["scope"]) or [""])
        if store:
            frag += f" AND UPPER({col}) = %s"
            params.append(store)
        return frag

    def dated(col: str, params: list) -> str:
        frag = ""
        if frm:
            frag += f" AND LEFT({col}, 10) >= %s"
            params.append(frm)
        if to:
            frag += f" AND LEFT({col}, 10) <= %s"
            params.append(to)
        return frag

    with get_db().cursor() as cur:
        if kind in ("all", "task"):
            p: list = []
            cur.execute("SELECT id, title, store_code, photo_urls, COALESCE(completed_at, updated_at) AS d FROM tasks "
                        "WHERE photo_urls <> '[]'" + scoped("store_code", p) + dated("COALESCE(completed_at, updated_at)", p) +
                        " ORDER BY id DESC LIMIT 300", p)
            for r in cur.fetchall():
                add(r["photo_urls"], "task", r["title"], r["store_code"], r["d"], f"/task/{r['id']}")
        if kind in ("all", "fund"):
            p = []
            cur.execute("SELECT id, store_code, report_date, photo_urls FROM fund_reports WHERE photo_urls <> '[]'" +
                        scoped("store_code", p) + dated("report_date", p) + " ORDER BY id DESC LIMIT 300", p)
            for r in cur.fetchall():
                add(r["photo_urls"], "fund", "Báo cáo quỹ", r["store_code"], r["report_date"], f"/fund/{r['id']}")
            p = []
            cur.execute("SELECT id, store_code, entry_date, reason, photo_urls FROM fund_entries WHERE photo_urls <> '[]'" +
                        scoped("store_code", p) + dated("entry_date", p) + " ORDER BY id DESC LIMIT 300", p)
            for r in cur.fetchall():
                add(r["photo_urls"], "fund", f"Thu chi quỹ: {r['reason'] or ''}", r["store_code"], r["entry_date"], "/fund")
        if kind in ("all", "order"):
            p = []
            cur.execute("SELECT id, store_code, COALESCE(received_at, order_date) AS d, receipt_photos FROM purchase_orders "
                        "WHERE receipt_photos <> '[]'" + scoped("store_code", p) + dated("COALESCE(received_at, order_date)", p) +
                        " ORDER BY id DESC LIMIT 300", p)
            for r in cur.fetchall():
                add(r["receipt_photos"], "order", "Nhận hàng", r["store_code"], r["d"], f"/orders/{r['id']}")
        if kind in ("all", "announcement"):
            p = []
            cur.execute("SELECT id, title, audience_stores, created_at, image_urls FROM announcements WHERE image_urls <> '[]'" +
                        dated("created_at", p) + " ORDER BY id DESC LIMIT 300", p)
            for r in cur.fetchall():
                stores = [s.upper() for s in _json_list(r["audience_stores"])]
                if viewer["scope"] is not None and not any(s in viewer["scope"] for s in stores):
                    continue
                if store and store not in stores:
                    continue
                add(r["image_urls"], "announcement", r["title"], stores[0] if len(stores) == 1 else "", r["created_at"], f"/board/{r['id']}")
    items.sort(key=lambda x: x["date"], reverse=True)
    return jsonify({"items": items[:300], "total": len(items)})


# ----------------------------- CSV export (signed, short-lived links) --------

@app.post("/api/export-link")
@login_required
def api_export_link():
    viewer = _task_viewer()
    if not viewer["can_manage"]:
        return _forbidden()
    data = request.get_json(silent=True) or {}
    kind = data.get("kind")
    if kind not in ("fund", "orders"):
        return _bad("Invalid export")
    params = {k: str(data.get(k) or "")[:40] for k in ("storeCode", "from", "to")}
    token = jwt.encode({"purpose": "export", "kind": kind, "uid": (g.current_user or {}).get("user_id"),
                        "eid": viewer["employee_id"], "params": params,
                        "exp": datetime.now(tz=VN_TZ) + timedelta(minutes=5)}, JWT_SECRET, algorithm="HS256")
    return jsonify({"path": f"/api/export/{kind}.csv?t={token}"})


def _csv_response(name: str, header: list, rows: list[list]) -> Response:
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(header)
    w.writerows(rows)
    return Response("﻿" + buf.getvalue(), mimetype="text/csv; charset=utf-8",
                    headers={"Content-Disposition": f'attachment; filename="{name}"'})


@app.get("/api/export/<kind>.csv")
def api_export_csv(kind: str):
    try:
        claims = jwt.decode(request.args.get("t", ""), JWT_SECRET, algorithms=["HS256"])
    except Exception:
        return _bad("Link expired", 401)
    if claims.get("purpose") != "export" or claims.get("kind") != kind:
        return _bad("Invalid link", 401)
    g.current_user = {"user_id": claims.get("uid"), "employee_id": claims.get("eid")}
    viewer = _task_viewer()
    if not viewer["can_manage"]:
        return _forbidden()
    p = claims.get("params") or {}
    where, params = [], []
    scol = "f.store_code" if kind == "fund" else "o.store_code"
    dcol = "f.report_date" if kind == "fund" else "o.order_date"
    if viewer["scope"] is not None:
        where.append(f"UPPER({scol}) = ANY(%s)")
        params.append(list(viewer["scope"]) or [""])
    if p.get("storeCode"):
        where.append(f"UPPER({scol}) = %s")
        params.append(p["storeCode"].upper())
    for key, op in (("from", ">="), ("to", "<=")):
        d = _valid_date(p.get(key)) if p.get(key) else None
        if d:
            where.append(f"{dcol} {op} %s")
            params.append(d)
    clause = ("WHERE " + " AND ".join(where) + " ") if where else ""
    if kind == "fund":
        with get_db().cursor() as cur:
            cur.execute(_FUND_SELECT + clause + "ORDER BY f.report_date DESC, f.store_code", params)
            rows = cur.fetchall()
        head = ["Ngày", "Cửa hàng", "Tiền đếm được", "Quỹ hệ thống", "Chênh lệch", "Trạng thái", "Người báo cáo", "Ghi chú"] + [str(d) for d in FUND_DENOMS]
        out = []
        for r in rows:
            counts = json.loads(r.get("counts_json") or "{}")
            out.append([r["report_date"], r.get("store_name") or r["store_code"], r["cash_total"], r["system_balance"],
                        r["difference"], r["status"], r.get("submitter_name") or "", r.get("note") or ""] +
                       [counts.get(str(d), 0) for d in FUND_DENOMS])
        return _csv_response("bao-cao-quy.csv", head, out)
    with get_db().cursor() as cur:
        cur.execute("SELECT o.id, o.order_date, o.status, o.supplier, s.name AS store_name, o.store_code, i.product_name, i.unit, "
                    "i.qty, i.qty_received FROM purchase_orders o JOIN purchase_order_items i ON i.order_id = o.id "
                    "LEFT JOIN stores s ON UPPER(s.store_code) = UPPER(o.store_code) " + clause +
                    "ORDER BY o.order_date DESC, o.id, i.id", params)
        rows = cur.fetchall()
    return _csv_response("don-dat-hang.csv", ["Ngày", "Mã đơn", "Cửa hàng", "Trạng thái", "Nhà cung cấp", "Sản phẩm", "ĐVT", "Số lượng đặt", "Số lượng nhận"],
                         [[r["order_date"], r["id"], r.get("store_name") or r["store_code"], r["status"], r.get("supplier") or "",
                           r["product_name"], r.get("unit") or "", r["qty"], "" if r["qty_received"] is None else r["qty_received"]] for r in rows])


# ----------------------------- store KPI -------------------------------------

KPI_FIELDS = {
    "kpiTotal": "kpi_total", "kpiN1": "kpi_n1", "kpiSbpsN1": "kpi_sbps_n1",
    "dst": "dst", "dstSb": "dst_sb", "dstSbps": "dst_sbps", "dsN1": "ds_n1", "dsSbpsN1": "ds_sbps_n1",
    "stockTotal": "stock_total", "stockN1": "stock_n1",
}


def _kpi_month_arg(raw: str | None) -> str | None:
    m = (raw or "").strip()
    return m if re.fullmatch(r"20\d\d-(0[1-9]|1[0-2])", m) else None


def _kpi_prev_months(month: str, n: int) -> list[str]:
    y, m = int(month[:4]), int(month[5:])
    out = []
    for _ in range(n):
        m -= 1
        if m == 0:
            y, m = y - 1, 12
        out.append(f"{y}-{m:02d}")
    return out


def _kpi_norm(name: str | None) -> str:
    """Store name -> comparable key: no accents, no brand prefix, letters and digits only."""
    t = unicodedata.normalize("NFKD", (name or "").replace("Đ", "D").replace("đ", "d"))
    t = "".join(c for c in t if not unicodedata.combining(c)).upper()
    t = re.sub(r"BI'?S\s*MART", "", t)
    return re.sub(r"[^A-Z0-9]", "", t)


def _kpi_app_stores(cur) -> tuple[dict[str, dict], dict[str, dict]]:
    """The app's own stores, indexed by code and by normalised name."""
    cur.execute("SELECT store_code, name, province FROM stores")
    by_code, by_name = {}, {}
    for r in cur.fetchall():
        st = {"code": r["store_code"], "name": r["name"], "region": r.get("province") or ""}
        by_code[r["store_code"].upper()] = st
        by_name.setdefault(_kpi_norm(r["name"]), st)
    return by_code, by_name


def _kpi_resolve(by_code: dict, by_name: dict, kpi_code: str, kpi_name: str | None) -> dict | None:
    return by_code.get((kpi_code or "").upper()) or by_name.get(_kpi_norm(kpi_name))


def _kpi_row_json(row: dict[str, Any], store: dict) -> dict[str, Any]:
    out = {"storeCode": store["code"], "storeName": store["name"], "region": store["region"]}
    for k, col in KPI_FIELDS.items():
        out[k] = row.get(col)
    return out


@app.get("/api/kpi")
@login_required
def api_kpi():
    viewer = _task_viewer()
    can_edit = _is_admin_user()
    db = get_db()
    with db.cursor() as cur:
        cur.execute("SELECT DISTINCT month FROM store_kpi ORDER BY month DESC")
        months = [r["month"] for r in cur.fetchall()]
        month = _kpi_month_arg(request.args.get("month")) or (months[0] if months else _now_iso()[:7])
        by_code, by_name = _kpi_app_stores(cur)
        cur.execute("SELECT * FROM store_kpi WHERE month = %s ORDER BY store_code", (month,))
        rows = cur.fetchall()
        if not rows and can_edit:
            # Empty month: list the app's open stores with blank figures so admins can start entering them.
            cur.execute("SELECT store_code, name AS store_name FROM stores "
                        "WHERE NOT (COALESCE(status,'') ILIKE '%%đóng%%' OR COALESCE(status,'') ILIKE '%%ngừng%%') ORDER BY name")
            rows = cur.fetchall()
        history_months = _kpi_prev_months(month, 3)
        cur.execute("SELECT store_code, month, dst, ds_n1 FROM store_kpi WHERE month = ANY(%s)", (history_months,))
        history = cur.fetchall()
    scope = viewer["scope"]
    by_store: dict[str, dict[str, dict]] = {}
    for h in history:
        by_store.setdefault(h["store_code"], {})[h["month"]] = h
    stores = []
    for r in rows:
        store = _kpi_resolve(by_code, by_name, r["store_code"], r.get("store_name"))
        if not store:
            continue  # not a store of the app
        if scope is not None and store["code"].upper() not in scope:
            continue
        item = _kpi_row_json(r, store)
        hist = by_store.get(r["store_code"], {})
        prev = hist.get(history_months[0])
        past = [hist[m]["dst"] for m in history_months if m in hist and hist[m]["dst"]]
        item["prevDst"] = prev["dst"] if prev else None
        item["prevDsN1"] = prev["ds_n1"] if prev else None
        item["moa"] = round(sum(past) / len(past)) if past else None
        stores.append(item)
    return jsonify({"month": month, "months": months, "canEdit": can_edit, "stores": stores})


def _kpi_clean_values(data: dict) -> tuple[dict[str, Any] | None, str]:
    values: dict[str, Any] = {}
    for key, col in KPI_FIELDS.items():
        if key not in data:
            continue
        raw = data[key]
        if raw in (None, ""):
            values[col] = None
            continue
        try:
            values[col] = int(round(float(raw)))
        except (TypeError, ValueError):
            return None, "Giá trị phải là số"
        if values[col] < 0:
            return None, "Giá trị không được âm"
    return values, ""


def _kpi_save(cur, by_code: dict, by_name: dict, key_rows: list, store: dict, month: str, values: dict[str, Any], skip_blank: bool = False) -> dict | None:
    # The workbook import may key a store by its own code; reuse that key when it is the same store.
    key = store["code"]
    for r in key_rows:
        hit = _kpi_resolve(by_code, by_name, r["store_code"], r["store_name"])
        if hit and hit["code"] == store["code"]:
            key = r["store_code"]
            break
    if skip_blank and all(v is None for v in values.values()):
        # A blank card only matters when the store already has a row to clear.
        cur.execute("SELECT 1 FROM store_kpi WHERE store_code = %s AND month = %s", (key, month))
        if not cur.fetchone():
            return None
    cur.execute("INSERT INTO store_kpi (store_code, month, store_name, region) VALUES (%s, %s, %s, %s) ON CONFLICT DO NOTHING",
                (key, month, store["name"], store["region"]))
    if values:
        sets = ", ".join(f"{c} = %s" for c in values)
        cur.execute(f"UPDATE store_kpi SET {sets}, updated_by = %s, updated_at = %s WHERE store_code = %s AND month = %s",
                    [*values.values(), (g.current_user or {}).get("user_id"), _now_iso(), key, month])
    cur.execute("SELECT * FROM store_kpi WHERE store_code = %s AND month = %s", (key, month))
    return cur.fetchone()


@app.put("/api/kpi/<store_code>/<month>")
@login_required
def api_kpi_upsert(store_code: str, month: str):
    if not _is_admin_user():
        return jsonify({"error": "Chỉ quản trị viên được cập nhật KPI"}), 403
    month = _kpi_month_arg(month)
    if not month:
        return jsonify({"error": "Tháng không hợp lệ"}), 400
    values, err = _kpi_clean_values(request.get_json(silent=True) or {})
    if values is None:
        return jsonify({"error": err}), 400
    db = get_db()
    with db.cursor() as cur:
        by_code, by_name = _kpi_app_stores(cur)
        store = by_code.get(store_code.strip().upper())
        if not store:
            return jsonify({"error": "Không tìm thấy cửa hàng"}), 404
        cur.execute("SELECT DISTINCT store_code, store_name FROM store_kpi")
        row = _kpi_save(cur, by_code, by_name, cur.fetchall(), store, month, values)
    db.commit()
    return jsonify(_kpi_row_json(row, store))


@app.put("/api/kpi/<month>")
@login_required
def api_kpi_bulk(month: str):
    """Saves the whole month for many stores at once: {rows: [{storeCode, <fields>}]}."""
    if not _is_admin_user():
        return jsonify({"error": "Chỉ quản trị viên được cập nhật KPI"}), 403
    month = _kpi_month_arg(month)
    if not month:
        return jsonify({"error": "Tháng không hợp lệ"}), 400
    items = (request.get_json(silent=True) or {}).get("rows")
    if not isinstance(items, list) or not items:
        return jsonify({"error": "Không có dữ liệu để lưu"}), 400
    prepared = []
    for it in items:
        values, err = _kpi_clean_values(it if isinstance(it, dict) else {})
        if values is None:
            return jsonify({"error": err}), 400
        prepared.append((str((it or {}).get("storeCode") or "").strip().upper(), values))
    db = get_db()
    saved = 0
    with db.cursor() as cur:
        by_code, by_name = _kpi_app_stores(cur)
        cur.execute("SELECT DISTINCT store_code, store_name FROM store_kpi")
        key_rows = cur.fetchall()
        for code, values in prepared:
            store = by_code.get(code)
            if not store:
                return jsonify({"error": f"Không tìm thấy cửa hàng {code}"}), 404
            if _kpi_save(cur, by_code, by_name, key_rows, store, month, values, skip_blank=True):
                saved += 1
    db.commit()
    return jsonify({"saved": saved})


# ----------------------------- hub summary -----------------------------------

@app.get("/api/ops/summary")
@login_required
def api_ops_summary():
    viewer = _task_viewer()
    today = _now_iso()[:10]
    out: dict[str, Any] = {"canManage": viewer["can_manage"], "storeCode": viewer["store_code"], "isAdmin": _is_admin_user()}
    db = get_db()
    with db.cursor() as cur:
        if viewer["store_code"]:
            cur.execute("SELECT status FROM fund_reports WHERE UPPER(store_code) = %s AND report_date = %s", (viewer["store_code"], today))
            r = cur.fetchone()
            out["fund"] = {"reportedToday": bool(r), "status": r["status"] if r else None}
        else:
            out["fund"] = {"reportedToday": False, "status": None}
        scope_sql, scope_params = "", []
        if viewer["scope"] is not None:
            scope_sql, scope_params = " AND UPPER(store_code) = ANY(%s)", [list(viewer["scope"]) or [""]]
        cur.execute("SELECT status, COUNT(*) AS c FROM purchase_orders WHERE status = ANY(%s)" + scope_sql + " GROUP BY status",
                    [list(ORDER_OPEN_STATUSES)] + scope_params)
        counts = {r["status"]: r["c"] for r in cur.fetchall()}
        out["orders"] = {"pendingApproval": counts.get("submitted", 0) if viewer["can_manage"] else 0,
                         "awaitingReceipt": sum(counts.get(s, 0) for s in ORDER_OPEN_STATUSES)}
        if viewer["can_manage"]:
            sql = ("SELECT COUNT(*) AS c FROM stores s WHERE NOT (COALESCE(s.status,'') ILIKE '%%đóng%%' OR COALESCE(s.status,'') ILIKE '%%ngừng%%') "
                   "AND NOT EXISTS (SELECT 1 FROM fund_reports f WHERE UPPER(f.store_code) = UPPER(s.store_code) AND f.report_date = %s)")
            params: list[Any] = [today]
            if viewer["scope"] is not None:
                sql += " AND UPPER(s.store_code) = ANY(%s)"
                params.append(list(viewer["scope"]) or [""])
            cur.execute(sql, params)
            out["fund"]["missingCount"] = cur.fetchone()["c"]
            cur.execute("SELECT COUNT(*) AS c FROM fund_reports WHERE status = 'submitted'" + scope_sql, scope_params)
            out["fund"]["pendingReview"] = cur.fetchone()["c"]
    out["board"] = {"unread": sum(1 for r in _visible_announcements(viewer) if not r["is_read"])}
    return jsonify(out)


ZALO_VERIFY_DIR = Path(__file__).resolve().parent / "zalo_verify"


@app.get("/zalo_verifier<path:fname>")
def zalo_domain_verification(fname: str):
    """Serves the Zalo domain-verification file: /zalo_verifier<code>.html -> zalo_verify/<code>.html."""
    safe = secure_filename(fname)
    if not safe.endswith(".html"):
        return jsonify({"error": "Not found"}), 404
    # The file Zalo hands out may carry the "zalo_verifier" prefix itself, or only the code.
    for candidate in (f"zalo_verifier{safe}", safe):
        full = ZALO_VERIFY_DIR / candidate
        if full.is_file():
            return Response(full.read_bytes(), mimetype="text/html; charset=utf-8")
    return jsonify({"error": "Not found"}), 404


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
