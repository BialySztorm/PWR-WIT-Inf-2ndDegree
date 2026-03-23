import { useEffect, useRef, useState } from "react";
import "./chat.css";

type Message = {
  id: number;
  text: string;
  created_at: string;
};

type Media = {
  id: number;
  file: string;
  filename?: string;
  uploaded_at: string;
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
  const fileInputRef = useRef<HTMLInputElement>(null);
  const bottomRef = useRef<HTMLDivElement>(null);

  async function loadAll() {
    const [msgRes, medRes] = await Promise.all([
      fetch(`${API_BASE}/api/messages/`),
      fetch(`${API_BASE}/api/media/`),
    ]);
    if (msgRes.ok) setMessages((await msgRes.json()) as Message[]);
    if (medRes.ok) {
      const d = await medRes.json();
      setMedia(Array.isArray(d) ? d : []);
    }
  }

  useEffect(() => {
    loadAll();
  }, []);

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
        const res = await fetch(`${API_BASE}/api/media/`, { method: "POST", body: form });
        if (!res.ok) { alert("Nie udało się wysłać pliku"); return; }
        setPendingFile(null);
        if (fileInputRef.current) fileInputRef.current.value = "";
      }
      if (text.trim()) {
        const res = await fetch(`${API_BASE}/api/messages/`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ text }),
        });
        if (!res.ok) { alert("Nie udało się wysłać wiadomości"); return; }
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

  function guessIsImage(url: string) {
    return /\.(png|jpe?g|gif|webp|svg|bmp)(\?|$)/i.test(url);
  }

  return (
    <div className="chat-root">
      <header className="chat-header">
        <span className="chat-title">PWR Cloud Systems – Group Chat</span>
        <button className="chat-refresh" onClick={loadAll} title="Odśwież">↻</button>
      </header>

      <main className="chat-messages">
        {chatItems.length === 0 && (
          <div className="chat-empty">Brak wiadomości. Napisz coś!</div>
        )}
        {chatItems.map((item) =>
          item.kind === "message" ? (
            <div className="chat-bubble chat-bubble--text" key={`msg-${item.data.id}`}>
              <p className="chat-bubble__body">{item.data.text}</p>
              <span className="chat-bubble__time">
                {new Date(item.data.created_at).toLocaleString()}
              </span>
            </div>
          ) : (
            <div className="chat-bubble chat-bubble--media" key={`med-${item.data.id}`}>
              {guessIsImage(`${API_BASE}${item.data.file}`) ? (
                <img
                  src={`${API_BASE}${item.data.file}`}
                  alt="załącznik"
                  className="chat-bubble__image"
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