import { useEffect, useRef, useState, type FormEvent } from 'react';
import { useSearchParams } from 'react-router-dom';
import { AlertOctagon, SendHorizontal, Trash2 } from 'lucide-react';
import { detectSafetyLevel, emergencyNotice } from '@core/safety';
import { useAdeed } from '../context';
import * as api from '../lib/api';
import { Markdown, Notice, PageHead, Spinner } from '../components';

interface LocalMsg extends api.ChatMessage { pending?: boolean }

export function ChatPage() {
  const { t, lang, session, toast, refresh } = useAdeed();
  const [params, setParams] = useSearchParams();
  const [messages, setMessages] = useState<LocalMsg[]>([]);
  const [loaded, setLoaded] = useState(false);
  const [draft, setDraft] = useState('');
  const [sending, setSending] = useState(false);
  const [notConfigured, setNotConfigured] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const endRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    api.listChat().then((m) => { setMessages(m); setLoaded(true); }).catch((e) => { setError((e as Error).message); setLoaded(true); });
  }, []);
  useEffect(() => {
    const ask = params.get('ask');
    if (ask) { setDraft(ask); setParams({}, { replace: true }); }
  }, [params, setParams]);
  useEffect(() => { endRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' }); }, [messages, sending]);

  const send = async (text: string) => {
    const message = text.trim();
    if (!message || sending) return;
    setError(null); setSending(true); setDraft('');
    const now = new Date().toISOString();
    // Emergency guidance appears instantly, from the deterministic layer, before any network call.
    const level = detectSafetyLevel(message);
    const optimistic: LocalMsg[] = [{ id: `u-${now}`, role: 'user', content: message, flags: level ? { safety: level } : {}, created_at: now, pending: true }];
    if (level) optimistic.push({ id: `s-${now}`, role: 'assistant', content: emergencyNotice(level, lang), flags: { safety: level, local: true }, created_at: now, pending: true });
    setMessages((m) => [...m, ...optimistic]);

    const res = await api.sendChat(message, lang);
    setSending(false);
    if (res.message) {
      setNotConfigured(false);
      setMessages((m) => [...m.filter((x) => !x.pending), { ...optimistic[0], id: `u2-${now}`, pending: false }, res.message!]);
      // The assistant may have saved a doctor question.
      refresh(['questions']);
      return;
    }
    if (res.error?.code === 'ai_not_configured') {
      setNotConfigured(true);
      // Keep the user's message and any local safety notice visible (they are not stored server-side).
      if (res.dose_notice) {
        setMessages((m) => [...m, { id: `d-${now}`, role: 'assistant', content: res.dose_notice!, flags: { dose_request: true }, created_at: now, pending: true }]);
      } else if (!level) {
        setMessages((m) => m.filter((x) => !x.pending));
        setDraft(message);
      }
      return;
    }
    setMessages((m) => m.filter((x) => !(x.pending && x.role === 'user')));
    setDraft(message);
    setError(res.error?.message ?? t.chat.failed);
  };

  const onSubmit = (e: FormEvent) => { e.preventDefault(); send(draft); };

  const clear = async () => {
    if (!session || !window.confirm(t.chat.confirmClear)) return;
    try { await api.clearChat(session.user.id); setMessages([]); toast(t.chat.cleared); } catch { toast(t.common.unknownError); }
  };

  return (
    <div className="ad-chat">
      <PageHead title={t.chat.title} lead={t.chat.lead}
        actions={messages.length > 0 && <button type="button" className="ad-iconbtn" onClick={clear}><Trash2 size={16} aria-hidden />{t.chat.clear}</button>} />
      <Notice tone="info">{t.disclaimer.short}</Notice>
      {notConfigured && <Notice tone="warn">{t.chat.notConfigured}</Notice>}

      <div className="ad-chat__log" aria-live="polite">
        {!loaded ? <Spinner label={t.common.loading} /> : messages.length === 0 && (
          <div className="ad-chat__empty">
            <p className="ad-h3">{t.chat.emptyTitle}</p>
            <p className="ad-muted ad-small">{t.chat.emptyBody}</p>
          </div>
        )}
        {messages.map((m) => (
          <div key={m.id} className={`ad-msg ad-msg--${m.role} ${m.flags?.local ? 'ad-msg--safety' : ''}`}>
            <span className="ad-msg__who">{m.role === 'user' ? t.chat.you : t.chat.adeed}</span>
            {m.flags?.local && <span className="ad-msg__alert"><AlertOctagon size={16} aria-hidden /> {t.chat.emergencyTitle}</span>}
            {m.role === 'assistant' ? <Markdown text={m.content} /> : <p className="ad-msg__text" dir="auto">{m.content}</p>}
          </div>
        ))}
        {sending && <div className="ad-msg ad-msg--assistant"><Spinner label={t.chat.thinking} /></div>}
        <div ref={endRef} />
      </div>

      {error && <Notice tone="danger">{error}</Notice>}

      {messages.length === 0 && (
        <div className="ad-chips">
          {t.chat.suggestions.map((s) => <button key={s} type="button" className="ad-chip" onClick={() => send(s)} disabled={sending}>{s}</button>)}
        </div>
      )}

      <form className="ad-chat__form" onSubmit={onSubmit}>
        <textarea className="ad-input" rows={2} maxLength={2000} value={draft} placeholder={t.chat.placeholder} dir="auto"
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(draft); } }} aria-label={t.chat.placeholder} />
        <button type="submit" className="ad-btn ad-btn--primary" disabled={sending || !draft.trim()} aria-label={t.chat.send}>
          <SendHorizontal size={18} aria-hidden className="flip-rtl" />
        </button>
      </form>
    </div>
  );
}
