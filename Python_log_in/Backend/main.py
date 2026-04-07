from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import mysql.connector
import hashlib
import datetime
import os
import sqlite3
from jose import jwt

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"https?://(127\.0\.0\.1|localhost)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

SECRET_KEY = "SECRET_KEY_CHANGE_ME"
ALGORITHM = "HS256"

DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_NAME = os.getenv("DB_NAME", "game_db")

USE_SQLITE_FALLBACK = os.getenv("USE_SQLITE_FALLBACK", "1").lower() not in {"0", "false", "no"}
SQLITE_DB_PATH = os.getenv(
    "SQLITE_DB_PATH",
    os.path.join(os.path.dirname(__file__), "game_db.sqlite3")
)

DEFAULT_ADMIN_EMAIL = os.getenv("DEFAULT_ADMIN_EMAIL", "admin@gmail.com")
DEFAULT_ADMIN_USERNAME = os.getenv("DEFAULT_ADMIN_USERNAME", "Admin")
DEFAULT_ADMIN_PASSWORD = os.getenv("DEFAULT_ADMIN_PASSWORD", "aze")


# 🔌 DATABASE
def get_db():
    return mysql.connector.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME
    )


def get_sqlite_db():
    conn = sqlite3.connect(SQLITE_DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_sqlite_fallback():
    if not USE_SQLITE_FALLBACK:
        return

    conn = get_sqlite_db()
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT UNIQUE,
            username TEXT,
            password TEXT
        )
        """
    )

    cur.execute("SELECT id FROM users WHERE email = ?", (DEFAULT_ADMIN_EMAIL,))
    existing = cur.fetchone()
    if existing is None:
        cur.execute(
            "INSERT INTO users (email, username, password) VALUES (?, ?, ?)",
            (DEFAULT_ADMIN_EMAIL, DEFAULT_ADMIN_USERNAME, hash_password(DEFAULT_ADMIN_PASSWORD)),
        )

    conn.commit()
    conn.close()


# 📦 MODELE
class User(BaseModel):
    email: str
    password: str
    username: str = None


# 🔐 HASH
def hash_password(password: str):
    return hashlib.sha256(password.encode()).hexdigest()


def verify_password(password: str, hashed: str):
    return hash_password(password) == hashed


def make_token_payload(user_row: dict):
    return {
        "user_id": user_row["id"],
        "email": user_row["email"],
        "username": user_row["username"],
        "exp": datetime.datetime.utcnow() + datetime.timedelta(hours=24),
    }


init_sqlite_fallback()


# 📝 REGISTER
@app.post("/register")
def register(user: User):
    print("📝 REGISTER:", user)

    hashed_password = hash_password(user.password)

    try:
        db = get_db()
        cursor = db.cursor()
        cursor.execute(
            "INSERT INTO users (email, username, password) VALUES (%s, %s, %s)",
            (user.email, user.username, hashed_password)
        )
        db.commit()
        cursor.close()
        db.close()

        print("✅ REGISTER OK (MySQL)")
        return {"message": "Utilisateur créé"}

    except Exception as mysql_error:
        print("⚠️ MySQL register failed, trying SQLite fallback:", mysql_error)

        if not USE_SQLITE_FALLBACK:
            raise HTTPException(status_code=400, detail=str(mysql_error))

        try:
            conn = get_sqlite_db()
            cur = conn.cursor()
            cur.execute(
                "INSERT INTO users (email, username, password) VALUES (?, ?, ?)",
                (user.email, user.username, hashed_password),
            )
            conn.commit()
            conn.close()
            print("✅ REGISTER OK (SQLite fallback)")
            return {"message": "Utilisateur créé"}
        except sqlite3.IntegrityError:
            raise HTTPException(status_code=400, detail="Email déjà utilisé")
        except Exception as sqlite_error:
            print("❌ REGISTER ERROR:", sqlite_error)
            raise HTTPException(status_code=400, detail=str(sqlite_error))


# 🔐 LOGIN
@app.post("/login")
def login(user: User):
    print("🔐 LOGIN:", user)

    result = None

    try:
        db = get_db()
        cursor = db.cursor(dictionary=True)
        cursor.execute(
            "SELECT * FROM users WHERE email=%s",
            (user.email,)
        )
        result = cursor.fetchone()
        cursor.close()
        db.close()
        print("🔎 RESULT (MySQL):", result)
    except Exception as mysql_error:
        print("⚠️ MySQL login failed, trying SQLite fallback:", mysql_error)

        if USE_SQLITE_FALLBACK:
            conn = get_sqlite_db()
            cur = conn.cursor()
            cur.execute("SELECT * FROM users WHERE email = ?", (user.email,))
            row = cur.fetchone()
            conn.close()
            if row is not None:
                result = {
                    "id": row["id"],
                    "email": row["email"],
                    "username": row["username"],
                    "password": row["password"],
                }
                print("🔎 RESULT (SQLite):", result)

    if result is None:
        raise HTTPException(status_code=400, detail="Utilisateur introuvable")

    if not verify_password(user.password, result["password"]):
        raise HTTPException(status_code=400, detail="Mot de passe incorrect")

    token = jwt.encode(make_token_payload(result), SECRET_KEY, algorithm=ALGORITHM)

    print("🎟 TOKEN OK")

    return {
        "token": token,
        "username": result["username"]
    }