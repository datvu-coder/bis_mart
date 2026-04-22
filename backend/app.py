import os
import secrets
from datetime import datetime
from functools import wraps
from flask import Flask, request, jsonify
from flask_cors import CORS
import psycopg
from psycopg.rows import dict_row
from werkzeug.security import generate_password_hash, check_password_hash

app = Flask(__name__)
CORS(app)
DATABASE_URL = os.environ.get("DATABASE_URL")
if not DATABASE_URL:
    raise ValueError("DATABASE_URL is required")

def get_db_connection():
    return psycopg.connect(DATABASE_URL, row_factory=dict_row)

@app.route("/api/login", methods=["POST"])
def login():
    data = request.json
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM employees WHERE username = %s", (data["username"],))
            user = cur.fetchone()
            if user and check_password_hash(user["password_hash"], data["password"]):
                token = secrets.token_hex(32)
                cur.execute("INSERT INTO sessions (employee_id, token) VALUES (%s, %s) RETURNING id", (user["id"], token))
                conn.commit()
                return jsonify({"token": token})
    return jsonify({"message": "Invalid"}), 401

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
