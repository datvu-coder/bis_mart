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
    ensure_database_ready()

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
            "SELECT u.id, u.password_hash, e.* FROM users u "
            "LEFT JOIN employees e ON u.employee_id = e.id "
            "WHERE u.username = %s", (username,)
        )
        user_row = cur.fetchone()
    
    if not user_row or not check_password_hash(user_row["password_hash"], password):
        return jsonify({"error": "Invalid credentials"}), 401
    
    token = create_token(user_row["id"], user_row.get("employee_id"))
    return jsonify({"token": token})

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
    
    return jsonify({"id": report_id, "status": "created"}), 201

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
