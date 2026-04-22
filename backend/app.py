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
    
    # ATOMIC INSERT - gets report_id immediately, no race condition
    with db.cursor() as cur:
        cur.execute(
            "INSERT INTO sales_reports "
            "(report_date, pg_name, store_name, nu, sale_out, store_code, "
            "report_month, revenue, points, employee_code, created_by) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING *",
            (
                data.get("date", datetime.now(tz=VN_TZ).strftime("%Y-%m-%d")),
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
        where_clause = "WHERE report_date = %s"
        params = [now.strftime("%Y-%m-%d")]
    elif filter_type == "week":
        where_clause = "WHERE report_date >= %s"
        params = [(now - timedelta(days=7)).strftime("%Y-%m-%d")]
    elif filter_type == "month":
        where_clause = "WHERE report_date >= %s AND report_date < %s"
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
