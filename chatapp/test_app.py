import json

import pytest
import requests

import app as app_module
import db


class FakeOllamaResponse:
    def __init__(self, lines):
        self._lines = lines

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def raise_for_status(self):
        pass

    def iter_lines(self):
        yield from self._lines


@pytest.fixture
def client(monkeypatch):
    monkeypatch.delenv("DB_NAME", raising=False)
    db._memory.clear()
    app_module.app.config["TESTING"] = True
    return app_module.app.test_client()


def parse_ndjson(body: str) -> list[dict]:
    return [json.loads(line) for line in body.splitlines() if line.strip()]


def test_index_shows_chat_ui(client):
    resp = client.get("/")
    assert resp.status_code == 200
    assert b'id="chat-form"' in resp.data


def test_index_uses_forwarded_prefix(client):
    # Nginx lähettää alipolun X-Forwarded-Prefix-otsakkeessa (/week5)
    resp = client.get("/", headers={"X-Forwarded-Prefix": "/week5"})
    assert b'href="/week5/static/style.css' in resp.data
    assert b'src="/week5/static/week5.js' in resp.data
    assert b'data-base="/week5"' in resp.data


def test_index_without_prefix_works_locally(client):
    resp = client.get("/")
    assert b'href="/static/style.css' in resp.data
    assert b'data-base=""' in resp.data


def test_health(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.data.strip()


def test_chat_rejects_missing_message(client):
    resp = client.post("/api/chat", json={"session_id": "abcdef1234"})
    assert resp.status_code == 400


def test_chat_rejects_bad_session(client):
    resp = client.post("/api/chat", json={"session_id": "../etc", "message": "moi"})
    assert resp.status_code == 400


def test_chat_rejects_too_long_message(client):
    resp = client.post(
        "/api/chat",
        json={"session_id": "abcdef1234", "message": "x" * (app_module.MAX_MESSAGE_LEN + 1)},
    )
    assert resp.status_code == 400


def test_chat_streams_reply_and_saves_history(client, monkeypatch):
    lines = [
        json.dumps({"message": {"content": "Hei"}, "done": False}).encode(),
        json.dumps({"message": {"content": "!"}, "done": True}).encode(),
    ]
    captured = {}

    def fake_post(url, **kwargs):
        captured["url"] = url
        captured.update(kwargs)
        return FakeOllamaResponse(lines)

    monkeypatch.setattr(app_module.requests, "post", fake_post)

    resp = client.post("/api/chat", json={"session_id": "test-session-1", "message": "Moi"})
    events = parse_ndjson(resp.get_data(as_text=True))

    assert resp.status_code == 200
    assert "".join(e.get("token", "") for e in events) == "Hei!"
    assert events[-1] == {"done": True}
    assert captured["url"].endswith("/api/chat")
    assert captured["json"]["messages"][0]["role"] == "system"
    assert captured["json"]["messages"][-1] == {"role": "user", "content": "Moi"}
    assert db.get_history("test-session-1") == [
        {"role": "user", "content": "Moi"},
        {"role": "assistant", "content": "Hei!"},
    ]


def test_chat_sends_previous_messages_as_context(client, monkeypatch):
    db.save_message("test-session-2", "user", "Nimeni on Ville")
    db.save_message("test-session-2", "assistant", "Hei Ville!")
    captured = {}

    def fake_post(url, **kwargs):
        captured.update(kwargs)
        return FakeOllamaResponse([json.dumps({"message": {"content": "Ville"}, "done": True})])

    monkeypatch.setattr(app_module.requests, "post", fake_post)
    client.post("/api/chat", json={"session_id": "test-session-2", "message": "Mikä nimeni on?"})

    roles = [m["role"] for m in captured["json"]["messages"]]
    assert roles == ["system", "user", "assistant", "user"]


def test_chat_handles_ollama_down(client, monkeypatch):
    def fake_post(url, **kwargs):
        raise requests.ConnectionError("connection refused")

    monkeypatch.setattr(app_module.requests, "post", fake_post)

    resp = client.post("/api/chat", json={"session_id": "test-session-3", "message": "Moi"})
    events = parse_ndjson(resp.get_data(as_text=True))

    assert "error" in events[-1]
    assert db.get_history("test-session-3") == [{"role": "user", "content": "Moi"}]


def test_chat_database_error_returns_json(client, monkeypatch):
    def broken_save(*args, **kwargs):
        raise db.DatabaseError(1290, "The MariaDB server is running with the --read-only option")

    monkeypatch.setattr(db, "save_message", broken_save)

    resp = client.post("/api/chat", json={"session_id": "test-session-5", "message": "Moi"})

    assert resp.status_code == 503
    assert "Tietokantavirhe" in resp.get_json()["error"]


def test_history_endpoint(client):
    db.save_message("test-session-4", "user", "Moi")
    resp = client.get("/api/history/test-session-4")
    assert resp.status_code == 200
    assert resp.get_json() == [{"role": "user", "content": "Moi"}]