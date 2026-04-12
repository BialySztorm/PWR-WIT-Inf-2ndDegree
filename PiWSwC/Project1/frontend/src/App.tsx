import { useEffect, useRef, useState } from "react";
import "./chat.css";
import {
  exchangeCodeForTokens,
  getAccessToken,
  getTokens,
  isCognitoConfigured,
  loginRedirect,
  logoutRedirect,
  setTokens,
} from "./auth/cognito";

type Message = {
  id: number;
  text: string;
  created_at: string;
  sender?: string | null;
};

type Media = {
  id: number;
  file: string;
  filename?: string;
  uploaded_at: string;
  sender?: string | null;
};

type ChatItem =
    | { kind: "message"; ts: number; data: Message }
    | { kind: "media"; ts: number; data: Media };

const API_BASE = import.meta.env.VITE_API_BASE ?? "http://127.0.0.1:8000";

export default function App() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [media, setMedia] = useState<Media[]>([]);
  const [text, setText] = useState("");
  const [pendingFile, setPendingFile] = useState<File | null>(null);
  const [sending, setSending] = useState(false);
  const [authBusy, setAuthBusy] = useState(false);
  const [authed, setAuthed] = useState(Boolean(getTokens()));
  const fileInputRef = useRef<HTMLInputElement>(null);
  const bottomRef = useRef<HTMLDivElement>(null);
  const [friendlyName, setFriendlyName] = useState("");
  const [savingName, setSavingName] = useState(false);

  function authFetch(input: RequestInfo | URL, init: RequestInit = {}) {
    const token = getAccessToken();
    const headers = new Headers(init.headers ?? {});
    if (token) headers.set("Authorization", `Bearer ${token}`);
    return fetch(input, { ...init, headers });
  }

  // Handle callback from Cognito: ?code=...
  useEffect(() => {
    const url = new URL(window.location.href);
    const code = url.searchParams.get("code");
    const error = url.searchParams.get("error");

    if (error) {
      console.error("Cognito error:", error, url.searchParams.get("error_description"));
      // clean URL
      url.searchParams.delete("error");
      url.searchParams.delete("error_description");
      window.history.replaceState({}, "", url.toString());
      return;
    }

    if (!code) return;

    (async () => {
      setAuthBusy(true);
      try {
        await exchangeCodeForTokens(code);
        setAuthed(true);
      } catch (e) {
        console.error(e);
        alert("Logowanie nie powiodło się (token exchange). Sprawdź konfigurację Cognito (callback URL / client_id / domain).");
        setTokens(null);
        setAuthed(false);
      } finally {
        // clean URL (remove code)
        url.searchParams.delete("code");
        url.searchParams.delete("state");
        window.history.replaceState({}, "", url.toString());
        setAuthBusy(false);
      }
    })();
  }, []);

  async function loadAll() {
    const [msgRes, medRes] = await Promise.all([
      authFetch(`${API_BASE}/api/messages/`),
      authFetch(`${API_BASE}/api/media/`),
    ]);

    if (msgRes.ok) setMessages((await msgRes.json()) as Message[]);
    if (medRes.ok) {
      const d = await medRes.json();
      setMedia(Array.isArray(d) ? d : []);
    } else {
      // jeśli backend nadal ma 405 na GET /api/media/, to nie crashuj UI
      setMedia([]);
    }
  }

  async function loadMe() {
    const res = await authFetch(`${API_BASE}/api/me/`);
    if (!res.ok) return;
    const d = (await res.json()) as { friendly_name?: string };
    setFriendlyName(d.friendly_name ?? "");
  }

  async function saveMe() {
    setSavingName(true);
    try {
      const res = await authFetch(`${API_BASE}/api/me/`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ friendly_name: friendlyName }),
      });
      if (!res.ok) {
        alert("Nie udało się zapisać nicku");
        return;
      }
      await loadMe();
      await loadAll(); // opcjonalnie: odśwież czat po zmianie nicku
    } finally {
      setSavingName(false);
    }
  }

  useEffect(() => {
    loadAll();
    if (authed) loadMe();
    if (!authed) setFriendlyName("");
  }, [authed]);

  // Scroll to bottom whenever chat items change
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages, media]);

  const chatItems: ChatItem[] = [
    ...messages.map((m) => ({
      kind: "message" as const,
      ts: new Date(m.created_at).getTime(),
      data: m,
    })),
    ...media.map((m) => ({
      kind: "media" as const,
      ts: new Date(m.uploaded_at).getTime(),
      data: m,
    })),
  ].sort((a, b) => a.ts - b.ts);

  async function handleSend(e: React.FormEvent) {
    e.preventDefault();
    if (!text.trim() && !pendingFile) return;
    setSending(true);
    try {
      if (pendingFile) {
        const form = new FormData();
        form.append("file", pendingFile);
        const res = await authFetch(`${API_BASE}/api/media/`, { method: "POST", body: form });
        if (!res.ok) {
          alert("Nie udało się wysłać pliku");
          return;
        }
        setPendingFile(null);
        if (fileInputRef.current) fileInputRef.current.value = "";
      }

      if (text.trim()) {
        const res = await authFetch(`${API_BASE}/api/messages/`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ text }),
        });
        if (!res.ok) {
          alert("Nie udało się wysłać wiadomości");
          return;
        }
        setText("");
      }

      await loadAll();
    } finally {
      setSending(false);
    }
  }

  function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    setPendingFile(e.target.files?.[0] ?? null);
  }

  function guessIsImage(pathOrName: string) {
    return /\.(png|jpe?g|gif|webp|svg|bmp)(\?|$)/i.test(pathOrName);
  }

  return (
      <div className="chat-root">
        <header className="chat-header">
          <span className="chat-title">PWR Cloud Systems – Group Chat</span>

          <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
            {isCognitoConfigured() ? (
                authed ? (
                    <>
                      <input
                          value={friendlyName}
                          onChange={(e) => setFriendlyName(e.target.value)}
                          placeholder="Nick…"
                          style={{
                            height: 28,
                            borderRadius: 8,
                            border: "1px solid rgba(255,255,255,0.25)",
                            padding: "0 8px",
                            background: "transparent",
                            color: "inherit",
                            width: 160,
                          }}
                          disabled={authBusy || savingName}
                      />
                      <button
                          className="chat-refresh"
                          onClick={() => saveMe()}
                          title="Zapisz nick"
                          disabled={authBusy || savingName}
                      >
                        Save
                      </button>
                      <button
                          className="chat-refresh"
                          onClick={() => logoutRedirect()}
                          title="Wyloguj"
                          disabled={authBusy}
                      >
                        Logout
                      </button>
                    </>
                ) : (
                    <button
                        className="chat-refresh"
                        onClick={() => loginRedirect()}
                        title="Zaloguj"
                        disabled={authBusy}
                    >
                      Login
                    </button>
                )
            ) : (
                <span style={{ fontSize: 12, opacity: 0.8 }}>
              (Cognito nie skonfigurowane – ustaw VITE_COGNITO_DOMAIN_FULL i VITE_COGNITO_CLIENT_ID)
            </span>
            )}

            <button className="chat-refresh" onClick={loadAll} title="Odśwież">
              ↻
            </button>
          </div>
        </header>

        <main className="chat-messages">
          {chatItems.length === 0 && (
              <div className="chat-empty">Brak wiadomości. Napisz coś!</div>
          )}

          {chatItems.map((item) =>
              item.kind === "message" ? (
                  <div className="chat-bubble chat-bubble--text" key={`msg-${item.data.id}`}>
                    {item.data.sender ? (
                        <div style={{ fontSize: 12, opacity: 0.75, marginBottom: 4 }}>
                          {item.data.sender}
                        </div>
                    ) : (
                        <div style={{ fontSize: 12, opacity: 0.5, marginBottom: 4 }}>Anonymous</div>
                    )}

                    <p className="chat-bubble__body">{item.data.text}</p>
                    <span className="chat-bubble__time">
                {new Date(item.data.created_at).toLocaleString()}
              </span>
                  </div>
              ) : (
                  <div className="chat-bubble chat-bubble--media" key={`med-${item.data.id}`}>
                    {item.data.sender ? (
                        <div style={{ fontSize: 12, opacity: 0.75, marginBottom: 4 }}>
                          {item.data.sender}
                        </div>
                    ) : (
                        <div style={{ fontSize: 12, opacity: 0.5, marginBottom: 4 }}>Anonymous</div>
                    )}
                    {guessIsImage(item.data.file) ? (
                        <img
                            src={`${API_BASE}/api/media/${item.data.id}`}
                            alt="załącznik"
                            className="chat-bubble__image"
                            loading="lazy"
                        />
                    ) : (
                        <a
                            href={`${API_BASE}/api/media/${item.data.id}`}
                            target="_blank"
                            rel="noreferrer"
                            className="chat-bubble__file-link"
                        >
                          📎 {item.data.filename ?? `File #${item.data.id}`}
                        </a>
                    )}
                    <span className="chat-bubble__time">
                {new Date(item.data.uploaded_at).toLocaleString()}
              </span>
                  </div>
              )
          )}
          <div ref={bottomRef} />
        </main>

        <footer className="chat-footer">
          <form className="chat-form" onSubmit={handleSend}>
            {pendingFile && (
                <div className="chat-pending-file">
                  📎 {pendingFile.name}
                  <button
                      type="button"
                      className="chat-pending-file__remove"
                      onClick={() => {
                        setPendingFile(null);
                        if (fileInputRef.current) fileInputRef.current.value = "";
                      }}
                  >
                    ✕
                  </button>
                </div>
            )}
            <div className="chat-form__row">
              <button
                  type="button"
                  className="chat-btn chat-btn--attach"
                  title="Dodaj załącznik"
                  onClick={() => fileInputRef.current?.click()}
              >
                📎
              </button>
              <input
                  ref={fileInputRef}
                  type="file"
                  style={{ display: "none" }}
                  onChange={handleFileChange}
              />
              <input
                  className="chat-form__input"
                  value={text}
                  onChange={(e) => setText(e.target.value)}
                  placeholder="Napisz wiadomość…"
                  onKeyDown={(e) => {
                    if (e.key === "Enter" && !e.shiftKey) {
                      e.preventDefault();
                      handleSend(e as unknown as React.FormEvent);
                    }
                  }}
              />
              <button
                  type="submit"
                  className="chat-btn chat-btn--send"
                  disabled={sending || (!text.trim() && !pendingFile)}
              >
                ➤
              </button>
            </div>
          </form>
        </footer>
      </div>
  );
}