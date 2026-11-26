"""Chat-sovellus: Flask-backend, joka välittää viestit Ollamalle ja tallentaa ne MariaDB:hen."""

import json
import os
import re
from pathlib import Path

import requests
from flask import Flask, Response, jsonify, render_template, request
from werkzeug.middleware.proxy_fix import ProxyFix

import db

OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434")
OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "qwen2.5:0.5b")
SYSTEM_PROMPT = os.environ.get(
    "SYSTEM_PROMPT",
    "You are an obsessive cooking assistant. In EVERY single response—even if "
    "the user asks about unrelated topics, greets you, or asks a general question—"
    "you must provide a clear, unrelated, concise recipe (ingredients, step-by-step instructions, "
    "and approximate prep/cook time). If the user asked something else first, give a "
    "brief one-line nod and immediately provide a recipe anyway. Always reply in the "
    "same language as the user's message.",
)
HISTORY_LIMIT = int(os.environ.get("HISTORY_LIMIT", "10"))
MAX_MESSAGE_LEN = 2000
SESSION_RE = re.compile(r"^[A-Za-z0-9-]{8,64}$")

app = Flask(__name__)

# Sovellus on Nginxin takana alipolussa (/viikko5/). Nginx poistaa etuliitteen ja kertoo
# sen X-Forwarded-Prefix-otsakkeessa. ProxyFix asettaa sen Flaskin SCRIPT_NAME:ksi, jolloin
# url_for() ja request.script_root tuottavat oikeat polut (/viikko5/static/...).
# Otsakkeisiin voi luottaa, koska sovellukseen pääsee vain Nginxin kautta (Unix-soketti).
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_prefix=1)


def _ndjson(obj: dict) -> str:
    return json.dumps(obj, ensure_ascii=False) + "\n"


@app.get("/")
def index():
    return render_template("index.html", model=OLLAMA_MODEL)


@app.get("/health")
def health():
    revision_file = Path(__file__).with_name("REVISION")
    if revision_file.is_file():
        return revision_file.read_text(encoding="utf-8")
    return "local\n"


@app.get("/api/history/<session_id>")
def history(session_id: str):
    if not SESSION_RE.match(session_id):
        return jsonify(error="Virheellinen session_id"), 400
    try:
        return jsonify(db.get_history(session_id, limit=50))
    except db.DatabaseError as exc:
        app.logger.error("Tietokantavirhe: %s", exc)
        return jsonify(error="Tietokantavirhe"), 503


@app.post("/api/chat")
def chat():
    data = request.get_json(silent=True) or {}
    session_id = str(data.get("session_id", "")).strip()
    message = str(data.get("message", "")).strip()

    if not SESSION_RE.match(session_id):
        return jsonify(error="Virheellinen session_id"), 400
    if not message:
        return jsonify(error="Viesti puuttuu"), 400
    if len(message) > MAX_MESSAGE_LEN:
        return jsonify(error=f"Viesti on liian pitkä (max {MAX_MESSAGE_LEN} merkkiä)"), 400

    try:
        past = db.get_history(session_id, limit=HISTORY_LIMIT)
        db.save_message(session_id, "user", message)
    except db.DatabaseError as exc:
        app.logger.error("Tietokantavirhe: %s", exc)
        return jsonify(error="Tietokantavirhe – viestiä ei voitu tallentaa."), 503

    messages = (
        [{"role": "system", "content": SYSTEM_PROMPT}]
        + [{"role": m["role"], "content": m["content"]} for m in past]
        + [{"role": "user", "content": message}]
    )

    def generate():
        parts = []
        try:
            with requests.post(
                f"{OLLAMA_URL}/api/chat",
                json={"model": OLLAMA_MODEL, "messages": messages, "stream": True},
                stream=True,
                timeout=(5, 300),
            ) as resp:
                resp.raise_for_status()
                for line in resp.iter_lines():
                    if not line:
                        continue
                    chunk = json.loads(line)
                    token = chunk.get("message", {}).get("content", "")
                    if token:
                        parts.append(token)
                        yield _ndjson({"token": token})
                    if chunk.get("done"):
                        break
        except (requests.RequestException, ValueError) as exc:
            app.logger.error("Ollama-kutsu epäonnistui: %s", exc)
            yield _ndjson({"error": "Kielimalli ei vastannut. Yritä hetken päästä uudelleen."})
            return

        reply = "".join(parts)
        if reply:
            try:
                db.save_message(session_id, "assistant", reply)
            except db.DatabaseError as exc:
                # Vastaus on jo näytetty käyttäjälle; kirjataan virhe lokiin.
                app.logger.error("Vastauksen tallennus epäonnistui: %s", exc)
        yield _ndjson({"done": True})

    return Response(
        generate(),
        mimetype="application/x-ndjson",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )