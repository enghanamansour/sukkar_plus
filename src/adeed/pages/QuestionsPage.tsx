import { useState } from 'react';
import { Copy, Plus } from 'lucide-react';
import { useAdeed } from '../context';
import * as api from '../lib/api';
import { DemoTag, PageHead, QuestionCard, copyText, reportTitle } from '../components';

export function QuestionsPage() {
  const { t, questions, reports, refresh, toast, fmtDate } = useAdeed();
  const [draft, setDraft] = useState('');
  const [onlySaved, setOnlySaved] = useState(false);
  const [busy, setBusy] = useState(false);

  const visible = questions.filter((q) => !onlySaved || q.is_saved);
  const groups = new Map<string, typeof visible>();
  for (const q of visible) {
    const k = q.report_id ?? 'general';
    groups.set(k, [...(groups.get(k) ?? []), q]);
  }
  const order = [...groups.keys()].sort((a, b) => {
    if (a === 'general') return 1;
    if (b === 'general') return -1;
    const ra = reports.find((r) => r.id === a), rb = reports.find((r) => r.id === b);
    return (rb?.period_end ?? '') > (ra?.period_end ?? '') ? 1 : -1;
  });

  const add = async () => {
    if (draft.trim().length < 3) return;
    setBusy(true);
    try { await api.addCustomQuestion(draft.trim(), null); setDraft(''); await refresh(['questions']); toast(t.common.saved); }
    catch { toast(t.common.unknownError); } finally { setBusy(false); }
  };

  const copyAll = async () => {
    const saved = questions.filter((q) => q.is_saved);
    const list = saved.length ? saved : questions;
    if (await copyText(list.map((q, i) => `${i + 1}. ${q.question}`).join('\n'))) toast(t.common.copied);
  };

  return (
    <div className="ad-stack">
      <PageHead title={t.questions.title} lead={t.questions.lead}
        actions={questions.length > 0 && (
          <button type="button" className="ad-btn ad-btn--secondary ad-btn--sm" onClick={copyAll}>
            <Copy size={16} aria-hidden /> {questions.some((q) => q.is_saved) ? t.questions.copyAll : t.questions.copyAllAny}
          </button>
        )} />

      <section className="ad-card ad-form">
        <label className="ad-field">
          <span>{t.questions.addOwn}</span>
          <textarea className="ad-input" rows={2} maxLength={1000} value={draft} placeholder={t.questions.addPlaceholder} onChange={(e) => setDraft(e.target.value)} />
        </label>
        <button type="button" className="ad-btn ad-btn--primary ad-btn--sm" onClick={add} disabled={busy || draft.trim().length < 3}><Plus size={16} aria-hidden /> {t.questions.add}</button>
      </section>

      {questions.length > 0 && (
        <label className="ad-check-inline">
          <input type="checkbox" checked={onlySaved} onChange={(e) => setOnlySaved(e.target.checked)} /> {t.questions.filterSaved}
        </label>
      )}

      {visible.length === 0 ? <p className="ad-muted ad-center">{t.questions.empty}</p> : order.map((k) => {
        const r = reports.find((x) => x.id === k);
        return (
          <section key={k} className="ad-section">
            <h2 className="ad-h3">{r ? reportTitle(r, fmtDate, t) : t.questions.general} {r?.is_demo && <DemoTag />}</h2>
            {groups.get(k)!.map((q) => <QuestionCard key={q.id} q={q} onChanged={() => refresh(['questions'])} />)}
          </section>
        );
      })}
    </div>
  );
}
