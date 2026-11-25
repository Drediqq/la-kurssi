"""Tietokantakerros.

Jos ympäristömuuttuja DB_NAME on asetettu, viestit tallennetaan MariaDB:hen.
Muuten (paikallinen kehitys ja testit) käytetään muistissa olevaa säilöä.
"""

import os
import threading

import pymysql

# Sovellus käsittelee tämän virheluokan (yhteys-, oikeus- ja read-only-virheet).
DatabaseError = pymysql.MySQLError

_memory: dict[str, list[dict]] = {}
_lock = threading.Lock()


def _use_mysql() -> bool:
    return bool(os.environ.get("DB_NAME"))


def _connect():
    return pymysql.connect(
        host=os.environ.get("DB_HOST", "127.0.0.1"),
        port=int(os.environ.get("DB_PORT", "3306")),
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        database=os.environ["DB_NAME"],
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True,
    )


def save_message(session_id: str, role: str, content: str) -> None:
    if not _use_mysql():
        with _lock:
            _memory.setdefault(session_id, []).append({"role": role, "content": content})
        return
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            "INSERT INTO messages (session_id, role, content) VALUES (%s, %s, %s)",
            (session_id, role, content),
        )


def get_history(session_id: str, limit: int = 10) -> list[dict]:
    """Palauttaa sessionin viimeiset `limit` viestiä aikajärjestyksessä."""
    if not _use_mysql():
        with _lock:
            return list(_memory.get(session_id, []))[-limit:]
    with _connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            SELECT role, content FROM (
                SELECT id, role, content FROM messages
                WHERE session_id = %s ORDER BY id DESC LIMIT %s
            ) AS t ORDER BY id ASC
            """,
            (session_id, limit),
        )
        return list(cur.fetchall())