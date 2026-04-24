"""
Bismart Backend - PostgreSQL only (no SQLite fallback).
CRITICAL FIX: All lastrowid issues replaced with atomic RETURNING clauses.
Fixes data loss bug where báo cáo & chấm công disappeared after creation.
"""
from __future__ import annotations

import json
import math
import os
from datetime import datetime, timedelta, timezone
from functools import wraps
from pathlib import Path
from typing import Any

import jwt
import psycopg
from psycopg.rows import dict_row
from flask import Flask, g, jsonify, request
from werkzeug.security import check_password_hash, generate_password_hash

# PostgreSQL ONLY - no SQLite fallback
BASE_DIR = Path(__file__).resolve().parent
DATABASE_URL = os.getenv("DATABASE_URL", "").strip()
if not DATABASE_URL:
    raise ValueError("DATABASE_URL required - PostgreSQL only backend")

DB_READY = False
VN_TZ = timezone(timedelta(hours=7))
JWT_SECRET = os.getenv("SECRET_KEY", "bismart-dev-secret-key")
JWT_EXP_HOURS = 72
CORS_ALLOW_HEADERS = "Content-Type, Authorization"
CORS_ALLOW_METHODS = "GET, POST, PUT, DELETE, OPTIONS"
app = Flask(__name__)
app.config["SECRET_KEY"] = JWT_SECRET
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
    except:
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
            cur.execute(
                "INSERT INTO store_managers (store_id, employee_id, store_role) "
                "VALUES (%s, %s, %s) "
                "ON CONFLICT (store_id, employee_id) DO UPDATE SET store_role = EXCLUDED.store_role "
                "RETURNING id, store_id, employee_id, store_role",
                (
                    int(data.get("storeId", 0)),
                    int(data.get("employeeId", 0)),
                    (data.get("storeRole") or "PG").upper(),
                ),
            )
            row = cur.fetchone()
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

    return jsonify({
        "systemRole": system_role,
        "storeRole": store_role,
        "systemPerm": sys_perm,
        "storePerm": store_perm,
        "effective": effective,
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
    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO employees (full_name, employee_code, position, work_location, email, score) "
            "VALUES (%s, %s, %s, %s, %s, %s) "
            "RETURNING id, full_name, employee_code, position, work_location, score, email, phone, date_of_birth, cccd, address, status, department, province, area, created_date, probation_date, official_date, resign_date, resign_reason, avatar_url, store_code, rank_level",
            (
                data.get("fullName", ""),
                data.get("employeeCode", ""),
                data.get("position", "PG"),
                data.get("workLocation", ""),
                data.get("email"),
                data.get("score", 0),
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
            "UPDATE employees SET full_name = %s, employee_code = %s, position = %s, work_location = %s, score = %s, email = %s, phone = %s, address = %s, status = %s, department = %s, province = %s, area = %s, store_code = %s, rank_level = %s "
            "WHERE id = %s "
            "RETURNING id, full_name, employee_code, position, work_location, score, email, phone, date_of_birth, cccd, address, status, department, province, area, created_date, probation_date, official_date, resign_date, resign_reason, avatar_url, store_code, rank_level",
            (
                data.get("fullName", ""),
                data.get("employeeCode", ""),
                data.get("position", "PG"),
                data.get("workLocation", ""),
                data.get("score", 0),
                data.get("email"),
                data.get("phone"),
                data.get("address"),
                data.get("status"),
                data.get("department"),
                data.get("province"),
                data.get("area"),
                data.get("storeCode"),
                data.get("rankLevel"),
                employee_id,
            ),
        )
        row = cur.fetchone()
    db.commit()
    if not row:
        return jsonify({"error": "Employee not found"}), 404
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
    
    # ATOMIC INSERT - gets report_id immediately, no race condition
    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO sales_reports "
            "(report_date, pg_name, store_name, nu, sale_out, store_code, "
            "report_month, revenue, points, employee_code, created_by) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING *",
            (
                report_date,
                data.get("pgName", ""),
                data.get("storeName", ""),
                data.get("nu", 0),
                data.get("saleOut", 0),
                data.get("storeCode", ""),
                data.get("reportMonth"),
                data.get("revenue", 0),
                data.get("points", 0),
                data.get("employeeCode", ""),
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
    Each employee can only check in once per day - uses unique constraint.
    """
    data = request.get_json(silent=True) or {}
    emp_id = data.get("employeeId")
    if not emp_id:
        return jsonify({"error": "Missing employeeId"}), 400
    
    db = get_db()
    now = datetime.now(tz=VN_TZ)
    date_str = now.strftime("%Y-%m-%d")
    time_str = now.strftime("%Y-%m-%dT%H:%M:%S")
    
    try:
        with db.cursor() as cur:
            cur.execute(
                "INSERT INTO attendances (employee_id, attend_date, check_in_time) "
                "VALUES (%s, %s, %s)",
                (emp_id, date_str, time_str),
            )
        db.commit()
    except DBIntegrityError:
        # Already checked in today - update time
        with db.cursor() as cur:
            cur.execute(
                "UPDATE attendances SET check_in_time = %s "
                "WHERE employee_id = %s AND attend_date = %s",
                (time_str, emp_id, date_str),
            )
        db.commit()
    
    return jsonify({"ok": True, "time": time_str})

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
