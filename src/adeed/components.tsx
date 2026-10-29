import { Fragment, useState, type ReactNode } from 'react';
import { AlertTriangle, Bookmark, BookmarkCheck, Check, Copy, FileText, Info, Loader2, Pencil, Trash2 } from 'lucide-react';
import { METRIC_BY_KEY, meetsTarget, rangeOf, targetParts, targetText } from '@core/catalog';
import { useAdeed } from './context';
import type { DoctorQuestion, Evidence, MetricRow, Report } from './lib/api';
import * as api from './lib/api';

/** Target text with the number isolated so "<5%" never renders as "%5" in Arabic. */
export function TargetText({ k }: { k: string }) {
  const { lang } = useAdeed();
  const p = targetParts(k, lang);
  if (!p) return null;
  return <>{p.op} <bdi dir="ltr">{p.value}</bdi></>;
}

export const RANGE_ORDER = ['tar_level2', 'tar_level1', 'tir', 'tbr_level1', 'tbr_level2'] as const;

export function metricOf(r: Pick<Report, 'metrics'>, key: string): MetricRow | undefined {
  return r.metrics.find((m) => m.metric_key === key);
}

export function Spinner({ label }: { label?: string }) {
  return <span className="ad-spinner" role="status"><Loader2 size={18} className="ad-spin" aria-hidden />{label && <span>{label}</span>}</span>;
}

export function PageHead({ title, lead, actions }: { title: string; lead?: string; actions?: ReactNode }) {
  return (
    <header className="ad-pagehead">
      <div>
        <h1 className="ad-pagehead__title">{title}</h1>
        {lead && <p className="ad-pagehead__lead">{lead}</p>}
      </div>
      {actions && <div className="ad-pagehead__actions">{actions}</div>}
    </header>
  );
}

export function Notice({ tone = 'info', children, title }: { tone?: 'info' | 'warn' | 'danger' | 'demo'; children: ReactNode; title?: string }) {
  const Icon = tone === 'info' || tone === 'demo' ? Info : AlertTriangle;
  return (
    <div className={`ad-notice ad-notice--${tone}`} role={tone === 'danger' ? 'alert' : 'note'}>
      <Icon size={18} aria-hidden className="ad-notice__icon" />
      <div>{title && <strong className="ad-notice__title">{title}</strong>}{children}</div>
    </div>
  );
}

export function DemoTag() {
  const { t } = useAdeed();
  return <span className="ad-tag ad-tag--demo">{t.common.demo}</span>;
}

export function StatusChip({ status }: { status: MetricRow['status'] }) {
  const { t } = useAdeed();
  return <span className={`ad-status ad-status--${status}`} title={t.statusHelp[status]}>{t.status[status]}</span>;
}

export function ErrorBox({ message, onRetry }: { message: string; onRetry?: () => void }) {
  const { t } = useAdeed();
  return (
    <Notice tone="danger">
      <p>{message}</p>
      {onRetry && <button type="button" className="ad-btn ad-btn--ghost ad-btn--sm" onClick={onRetry}>{t.common.retry}</button>}
    </Notice>
  );
}

export function formatMetric(m: MetricRow | undefined, fmtNum: (n: number | null | undefined, d?: number) => string): string {
  if (!m || m.status === 'unavailable' || m.value === null) return '—';
  if (m.metric_key === 'setting_ic_ratio') return `1 : ${fmtNum(m.value)}`;
  const unit = m.unit === '%' ? '%' : m.unit ? ` ${m.unit}` : '';
  return `${fmtNum(m.value)}${unit}`;
}

/** AGP-style vertical stacked bar with direct labels; a table view is always one tap away. */
export function RangeChart({ report }: { report: Report }) {
  const { t, lang, fmtNum } = useAdeed();
  const [table, setTable] = useState(false);
  const rows = RANGE_ORDER.map((k) => ({ key: k, m: metricOf(report, k), def: METRIC_BY_KEY[k] }));
  const available = rows.filter((r) => r.m && r.m.value != null && r.m.status !== 'unavailable');
  if (!available.length) return <p className="ad-muted">{t.status.unavailable}</p>;
  const total = available.reduce((s, r) => s + (r.m!.value as number), 0) || 100;

  return (
    <div className="ad-range">
      <div className="ad-range__toolbar">
        <button type="button" className="ad-link" onClick={() => setTable((v) => !v)}>{table ? t.detail.chart : t.detail.table}</button>
      </div>
      {table ? (
        <table className="ad-table">
          <thead><tr><th>{t.detail.range}</th><th>{t.detail.value}</th><th>{t.detail.target}</th><th>{t.detail.source}</th></tr></thead>
          <tbody>
            {rows.map(({ key, m, def }) => (
              <tr key={key}>
                <td>{def.label[lang]}</td>
                <td className="ad-num">{formatMetric(m, fmtNum)}</td>
                <td>{targetText(key, lang) ? <TargetText k={key} /> : t.common.none}</td>
                <td>{m ? <StatusChip status={m.status} /> : <StatusChip status="unavailable" />}</td>
              </tr>
            ))}
          </tbody>
        </table>
      ) : (
        <div className="ad-range__body">
          <div className="ad-range__bar" role="img" aria-label={rows.map((r) => `${r.def.label[lang]}: ${formatMetric(r.m, fmtNum)}`).join('، ')}>
            {rows.map(({ key, m, def }) => {
              const v = m?.value ?? 0;
              if (!m || m.status === 'unavailable' || v <= 0) return null;
              return <span key={key} className={`ad-range__seg ad-c-${key}`} style={{ flexGrow: v / total }} title={`${def.label[lang]}: ${formatMetric(m, fmtNum)}`} />;
            })}
          </div>
          <ul className="ad-range__legend">
            {rows.map(({ key, m, def }) => {
              const ok = meetsTarget(key, m?.value ?? null);
              return (
                <li key={key} className={key === 'tir' ? 'is-target' : ''}>
                  <span className={`ad-swatch ad-c-${key}`} aria-hidden />
                  <span className="ad-range__name">{def.short[lang]}<small>{rangeOf(key, lang)}</small></span>
                  <span className="ad-range__val ad-num">{formatMetric(m, fmtNum)}</span>
                  {m?.status === 'uncertain' && <StatusChip status="uncertain" />}
                  {ok !== null && (
                    <span className={`ad-target ${ok ? 'is-ok' : 'is-off'}`} title={`${t.detail.target}: ${targetText(key, lang)}`}>
                      {ok ? <Check size={12} aria-hidden /> : <AlertTriangle size={12} aria-hidden />}
                      <TargetText k={key} />
                    </span>
                  )}
                </li>
              );
            })}
          </ul>
        </div>
      )}
    </div>
  );
}

/** Compact horizontal 100% bar used in lists and history rows. */
export function RangeStrip({ report }: { report: Report }) {
  const { lang, fmtNum } = useAdeed();
  const rows = RANGE_ORDER.slice().reverse().map((k) => ({ key: k, m: metricOf(report, k) }))
    .filter((r) => r.m && r.m.value != null && r.m.status !== 'unavailable' && (r.m.value as number) > 0);
  if (!rows.length) return null;
  return (
    <div className="ad-strip" role="img" aria-label={rows.map((r) => `${METRIC_BY_KEY[r.key].short[lang]} ${formatMetric(r.m, fmtNum)}`).join('، ')}>
      {rows.map((r) => (
        <span key={r.key} className={`ad-strip__seg ad-c-${r.key}`} style={{ flexGrow: r.m!.value as number }} title={`${METRIC_BY_KEY[r.key].label[lang]}: ${formatMetric(r.m, fmtNum)}`} />
      ))}
    </div>
  );
}

export function MetricCard({ m, metricKey, children }: { m: MetricRow | undefined; metricKey: string; children?: ReactNode }) {
  const { t, lang, fmtNum } = useAdeed();
  const def = METRIC_BY_KEY[metricKey];
  const status = m?.status ?? 'unavailable';
  const ok = meetsTarget(metricKey, m?.value ?? null);
  return (
    <article className={`ad-metric ad-metric--${status}`}>
      <header className="ad-metric__head">
        <h3 className="ad-metric__label">{def?.label[lang] ?? metricKey}</h3>
        <StatusChip status={status} />
      </header>
      <p className="ad-metric__value ad-num">{formatMetric(m, fmtNum)}</p>
      {def?.target && m && status !== 'unavailable' && (
        <p className={`ad-target ${ok ? 'is-ok' : 'is-off'}`}>
          {ok ? <Check size={12} aria-hidden /> : <AlertTriangle size={12} aria-hidden />}
          {ok ? t.detail.meets : t.detail.notMeets} · <TargetText k={metricKey} />
        </p>
      )}
      <p className="ad-metric__explain">{def?.explain[lang]}</p>
      {children}
      {m?.note && status !== 'extracted' && <p className="ad-metric__note"><Info size={12} aria-hidden /> {m.note}</p>}
      {m?.source_page != null && (
        <p className="ad-metric__src"><FileText size={12} aria-hidden /> {t.detail.fromPage(m.source_page)}{m.source_label ? ` · “${m.source_label}”` : ''}</p>
      )}
    </article>
  );
}

/** Tiny Markdown subset (paragraphs, lists, **bold**, rules) rendered as React nodes — never as raw HTML. */
export function Markdown({ text }: { text: string }) {
  const blocks: ReactNode[] = [];
  const lines = text.replace(/\r/g, '').split('\n');
  let list: { ordered: boolean; items: string[] } | null = null;
  let para: string[] = [];
  const inline = (s: string, k: string) => s.split(/(\*\*[^*]+\*\*)/g).map((part, i) =>
    part.startsWith('**') && part.endsWith('**') ? <strong key={`${k}-${i}`}>{part.slice(2, -2)}</strong> : <Fragment key={`${k}-${i}`}>{part.replace(/^#{1,6}\s+/, '')}</Fragment>);
  const flushPara = () => { if (para.length) { blocks.push(<p key={`p${blocks.length}`}>{inline(para.join(' '), `p${blocks.length}`)}</p>); para = []; } };
  const flushList = () => {
    if (list) {
      const items = list.items.map((it, i) => <li key={i}>{inline(it, `l${blocks.length}-${i}`)}</li>);
      blocks.push(list.ordered ? <ol key={`o${blocks.length}`}>{items}</ol> : <ul key={`u${blocks.length}`}>{items}</ul>);
      list = null;
    }
  };
  for (const raw of lines) {
    const line = raw.trim();
    const ul = line.match(/^[-*•]\s+(.*)$/);
    const ol = line.match(/^\d+[.)]\s+(.*)$/);
    if (!line) { flushPara(); flushList(); continue; }
    if (/^(-{3,}|_{3,})$/.test(line)) { flushPara(); flushList(); blocks.push(<hr key={`h${blocks.length}`} />); continue; }
    if (ul || ol) {
      flushPara();
      const ordered = Boolean(ol);
      if (!list || list.ordered !== ordered) { flushList(); list = { ordered, items: [] }; }
      list.items.push((ul ?? ol)![1]);
      continue;
    }
    if (/^#{1,6}\s/.test(line)) { flushPara(); flushList(); blocks.push(<p key={`hd${blocks.length}`} className="ad-md-h">{inline(line, `hd${blocks.length}`)}</p>); continue; }
    flushList();
    para.push(line);
  }
  flushPara(); flushList();
  return <div className="ad-md">{blocks}</div>;
}

export async function copyText(text: string): Promise<boolean> {
  try { await navigator.clipboard.writeText(text); return true; }
  catch {
    const ta = document.createElement('textarea');
    ta.value = text; document.body.appendChild(ta); ta.select();
    const ok = document.execCommand('copy'); ta.remove(); return ok;
  }
}

function EvidenceChip({ e }: { e: Evidence }) {
  const { t, lang, fmtNum, fmtDate } = useAdeed();
  const def = METRIC_BY_KEY[e.metric_key];
  const unit = e.unit === '%' ? '%' : e.unit ? ` ${e.unit}` : '';
  const role = e.role === 'previous' ? ` · ${t.questions.previous}` : e.role === 'lab' ? ` · ${t.questions.lab}${e.date ? ` ${fmtDate(e.date)}` : ''}` : '';
  return (
    <span className={`ad-evidence ${e.status === 'uncertain' ? 'is-uncertain' : ''}`}>
      {def?.short[lang] ?? e.metric_key}: <b className="ad-num">{e.value == null ? '—' : `${fmtNum(e.value)}${unit}`}</b>
      {role}{e.source_page ? ` · ${t.detail.fromPage(e.source_page)}` : ''}{e.status === 'uncertain' ? ` · ${t.status.uncertain}` : e.status === 'calculated' ? ` · ${t.status.calculated}` : ''}
    </span>
  );
}

export function QuestionCard({ q, onChanged }: { q: DoctorQuestion; onChanged: () => void }) {
  const { t, toast } = useAdeed();
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(q.question);
  const [busy, setBusy] = useState(false);

  const run = async (fn: () => Promise<void>, msg?: string) => {
    setBusy(true);
    try { await fn(); if (msg) toast(msg); onChanged(); } catch { toast(t.common.unknownError); } finally { setBusy(false); }
  };

  return (
    <article className={`ad-q ${q.is_saved ? 'is-saved' : ''}`}>
      <div className="ad-q__meta">
        <span className={`ad-tag ad-tag--${q.basis}`}>{t.questions.basis[q.basis]}</span>
        {q.is_uncertain && <span className="ad-tag ad-tag--warn"><AlertTriangle size={12} aria-hidden /> {t.questions.uncertain}</span>}
        {q.is_edited && <span className="ad-tag">{t.questions.edited}</span>}
        <span className="ad-q__from">{t.questions.from[q.generated_by]}</span>
      </div>
      {editing ? (
        <div className="ad-q__edit">
          <textarea className="ad-input" rows={3} value={draft} maxLength={1000} onChange={(e) => setDraft(e.target.value)} aria-label={t.common.edit} />
          <div className="ad-row">
            <button type="button" className="ad-btn ad-btn--primary ad-btn--sm" disabled={busy || draft.trim().length < 3}
              onClick={() => run(async () => { await api.updateQuestion(q.id, { question: draft.trim(), is_edited: true }); setEditing(false); }, t.common.saved)}>{t.common.save}</button>
            <button type="button" className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => { setDraft(q.question); setEditing(false); }}>{t.common.cancel}</button>
          </div>
        </div>
      ) : (
        <p className="ad-q__text">{q.question}</p>
      )}
      {q.rationale && (
        <details className="ad-q__why">
          <summary>{t.questions.why}</summary>
          <p>{q.rationale}</p>
        </details>
      )}
      {q.evidence?.length > 0 && (
        <div className="ad-q__evidence" aria-label={t.questions.basedOn}>
          <span className="ad-muted">{t.questions.basedOn}:</span>
          {q.evidence.map((e, i) => <EvidenceChip key={i} e={e} />)}
        </div>
      )}
      <div className="ad-q__actions">
        <button type="button" className="ad-iconbtn" aria-pressed={q.is_saved} disabled={busy}
          onClick={() => run(() => api.updateQuestion(q.id, { is_saved: !q.is_saved }))}>
          {q.is_saved ? <BookmarkCheck size={16} aria-hidden /> : <Bookmark size={16} aria-hidden />}{q.is_saved ? t.questions.unsave : t.questions.save}
        </button>
        <button type="button" className="ad-iconbtn" onClick={() => setEditing(true)} disabled={busy}><Pencil size={16} aria-hidden />{t.common.edit}</button>
        <button type="button" className="ad-iconbtn" onClick={async () => { if (await copyText(q.question)) toast(t.common.copied); }}><Copy size={16} aria-hidden />{t.common.copy}</button>
        <button type="button" className="ad-iconbtn ad-iconbtn--danger" disabled={busy}
          onClick={() => { if (window.confirm(t.common.confirmDelete)) run(() => api.deleteQuestion(q.id)); }}><Trash2 size={16} aria-hidden />{t.common.delete}</button>
      </div>
    </article>
  );
}

export function reportTitle(r: Report, fmtDate: (s: string | null) => string, t: ReturnType<typeof useAdeed>['t']): string {
  if (r.period_start && r.period_end) return `${fmtDate(r.period_start)} – ${fmtDate(r.period_end)}`;
  return r.file_name || t.reports.noPeriod;
}
