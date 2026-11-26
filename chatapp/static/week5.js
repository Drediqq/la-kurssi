"use strict";

const form = document.getElementById("chat-form");
const input = document.getElementById("message");
const sendBtn = document.getElementById("send");
const list = document.getElementById("messages");
const emptyHint = document.getElementById("empty-hint");
const newChatBtn = document.getElementById("new-chat");

const STORAGE_KEY = "viikko5_chat_session_id";

// Sovellus toimii alipolussa (esim. /viikko5). Polku tulee palvelimelta
// <body data-base="..."> -attribuutista, joten koodissa ei ole kovakoodattuja polkuja.
const BASE = document.body.dataset.base || "";

// crypto.randomUUID() toimii vain HTTPS:llä, joten tehdään id getRandomValuesilla
// (toimii myös pelkällä HTTP:llä cPoutan IP-osoitteessa).
function newSessionId() {
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

let memorySessionId = null;
function getSessionId(reset = false) {
  try {
    let id = localStorage.getItem(STORAGE_KEY);
    if (!id || reset) {
      id = newSessionId();
      localStorage.setItem(STORAGE_KEY, id);
    }
    return id;
  } catch {
    if (!memorySessionId || reset) memorySessionId = newSessionId();
    return memorySessionId;
  }
}

let sessionId = getSessionId();

function addMessage(role, text = "") {
  emptyHint.hidden = true;
  const el = document.createElement("div");
  el.className = `msg msg--${role}`;
  el.textContent = text;
  list.appendChild(el);
  list.scrollTop = list.scrollHeight;
  return el;
}

function clearMessages() {
  list.querySelectorAll(".msg").forEach((el) => el.remove());
  emptyHint.hidden = false;
}

async function loadHistory() {
  try {
    const resp = await fetch(`${BASE}/api/history/${sessionId}`);
    if (!resp.ok) return;
    const items = await resp.json();
    items.forEach((m) => addMessage(m.role, m.content));
  } catch (err) {
    console.error("Historian lataus epäonnistui", err);
  }
}

async function sendMessage(text) {
  addMessage("user", text);
  const bubble = addMessage("assistant");
  bubble.classList.add("msg--typing");
  sendBtn.disabled = true;

  try {
    const resp = await fetch(`${BASE}/api/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ session_id: sessionId, message: text }),
    });

    if (!resp.ok) {
      const data = await resp.json().catch(() => ({}));
      throw new Error(data.error || `HTTP ${resp.status}`);
    }

    // Vastaus tulee NDJSON-virtana: yksi JSON-olio per rivi.
    const reader = resp.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";

    for (;;) {
      const { value, done } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");
      buffer = lines.pop();
      for (const line of lines) {
        if (!line.trim()) continue;
        const evt = JSON.parse(line);
        if (evt.token) {
          bubble.textContent += evt.token;
          list.scrollTop = list.scrollHeight;
        }
        if (evt.error) throw new Error(evt.error);
      }
    }
  } catch (err) {
    if (!bubble.textContent) bubble.remove();
    addMessage("error", err.message);
  } finally {
    bubble.classList.remove("msg--typing");
    sendBtn.disabled = false;
    input.focus();
  }
}

form.addEventListener("submit", (e) => {
  e.preventDefault();
  const text = input.value.trim();
  if (!text || sendBtn.disabled) return;
  input.value = "";
  sendMessage(text);
});

input.addEventListener("keydown", (e) => {
  if (e.key === "Enter" && !e.shiftKey) {
    e.preventDefault();
    form.requestSubmit();
  }
});

newChatBtn.addEventListener("click", () => {
  sessionId = getSessionId(true);
  clearMessages();
  input.focus();
});

loadHistory();