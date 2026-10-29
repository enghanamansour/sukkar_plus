import { useEffect, useMemo, useState } from 'react';
import { Copy, Printer } from 'lucide-react';
import { METRIC_BY_KEY, meetsTarget, targetText } from '@core/catalog';
import { COMPARE_KEYS, compareMetric, findPreviousComparable } from '@core/compare';
import { checkMessage } from '@core/parser';
import { useAdeed } from '../context';
import * as api from '../lib/api';
import { DemoTag, Notice, PageHead, TargetText, copyText, formatMetric, metricOf, reportTitle } from '../components';

const toLocalInput = (iso: string | null) => {
  if (!iso) return '';
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
};

export function AppointmentPage() {
  const { t, lang, profile, reports, labs, questions, refresh, toast, fmtDate, fmtNum } = useAdeed();
  const [when, setWhen] = useState('');
  const [clinic, setClinic] = useState('');
  const [notes, setNotes] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    setWhen(toLocalInput(profile?.next_appointment_at ?? null));
    setClinic(profile?.clinic_name ?? '');
    setNotes(profile?.appointment_notes ?? '');
  }, [profile]);

  const processed = reports.filter((r) => r.status === 'processed' && r.report_kind === 'cgm_agp');
  const real = processed.filter((r) => !r.is_demo);
  const latest = (real.length ? real : processed)[0];
  const prev = useMemo(() => (latest ? findPreviousComparable(latest, processed) : null), [latest, processed]);
  const relevantLabs = labs.filter((l) => !latest || l.is_demo === latest.is_demo).slice(0, 3);
  const savedQs = questions.filter((q) => q.is_saved);
  const qs = savedQs.length ? savedQs : questions.filter((q) => !latest || q.report_id === latest.id || q.report_id === null);

  const findings = latest ? ['tir', 'tbr_total', 'tbr_level2', 'tar_total', 'mean_glucose', 'gmi', 'cv'].map((k) => {
    const m = metricOf(latest, k);
    const ok = meetsTarget(k, m?.value ?? null);
    return { k, m, ok };
  }).filter((f) => f.m && f.m.status !== 'unavailable') : [];
  const gaps = latest ? [
    ...latest.metrics.filter((m) => m.status === 'unavailable' || m.status === 'uncertain').map((m) => `${METRIC_BY_KEY[m.metric_key]?.label[lang] ?? m.metric_key}: ${t.status[m.status]}`),
    ...(latest.quality?.checks ?? []).filter((c) => c.level !== 'pass' && !['cv_consistency', 'cgm_active_missing'].includes(c.key)).map((c) => checkMessage(c, lang)),
  ] : [];

  const save = async () => {
    if (!profile) return;
    setBusy(true);
    try {
      await api.updateProfile(profile.id, { next_appointment_at: when ? new Date(when).toISOString() : null, clinic_name: clinic.trim() || null, appointment_notes: notes.trim() || null });
      await refresh(['profile']); toast(t.common.saved);
    } catch { toast(t.common.unknownError); } finally { setBusy(false); }
  };

  const summaryText = () => {
    const L: string[] = [];
    L.push(`${t.appt.summary} — ${lang === 'ar' ? 'عضيد' : 'Adeed'}`);
    if (profile?.next_appointment_at) L.push(`${t.appt.date}: ${new Date(profile.next_appointment_at).toLocaleString(lang === 'ar' ? 'ar-SA-u-ca-gregory-nu-latn' : 'en-GB')}${profile.clinic_name ? ` · ${profile.clinic_name}` : ''}`);
    if (latest) {
      L.push('', `${t.appt.latest}: ${reportTitle(latest, fmtDate, t)} (${latest.period_days ?? '?'} ${t.common.days})${latest.is_demo ? ` [${t.common.demo}]` : ''}`);
      L.push(`${t.appt.findings}:`);
      for (const f of findings) L.push(`- ${METRIC_BY_KEY[f.k].label[lang]}: ${formatMetric(f.m, fmtNum)}${f.m!.status !== 'extracted' ? ` (${t.status[f.m!.status]})` : ''}${targetText(f.k, lang) ? ` — ${t.detail.target}: ${targetText(f.k, lang)}` : ''}`);
      if (prev) {
        L.push(`${t.appt.comparison} (${fmtDate(prev.report.period_start)} – ${fmtDate(prev.report.period_end)})${prev.compat.level === 'limited' ? ` — ${t.detail.limited}` : ''}:`);
        for (const k of ['tir', 'tbr_total', 'gmi']) {
          const c = compareMetric(k, latest, prev.report, prev.compat);
          if (c.comparable) L.push(`- ${METRIC_BY_KEY[k].short[lang]}: ${fmtNum(c.previous)} → ${fmtNum(c.current)} (${t.detail.dir[c.direction!]})`);
        }
      }
      if (gaps.length) { L.push(`${t.appt.gaps}:`); gaps.forEach((g) => L.push(`- ${g}`)); }
    }
    L.push('', `${t.appt.labs}:`);
    if (relevantLabs.length) relevantLabs.forEach((l) => L.push(`- HbA1c ${fmtNum(l.value)}% (${fmtDate(l.measured_on)})${l.is_demo ? ` [${t.common.demo}]` : ''}`));
    else L.push(`- ${t.history.noLabs}`);
    L.push('', `${t.appt.questions}:`);
    qs.forEach((q, i) => L.push(`${i + 1}. ${q.question}`));
    if (notes.trim()) L.push('', `${t.appt.notes}:`, notes.trim());
    L.push('', t.disclaimer.short);
    return L.join('\n');
  };

  return (
    <div className="ad-stack ad-print">
      <PageHead title={t.appt.title} lead={t.appt.lead} actions={latest && (
        <>
          <button type="button" className="ad-iconbtn" onClick={async () => { if (await copyText(summaryText())) toast(t.common.copied); }}><Copy size={16} aria-hidden />{t.appt.copySummary}</button>
          <button type="button" className="ad-iconbtn" onClick={() => window.print()}><Printer size={16} aria-hidden />{t.common.print}</button>
        </>
      )} />

      <section className="ad-card ad-form ad-noprint">
        <label className="ad-field"><span>{t.appt.date}</span>
          <input className="ad-input" type="datetime-local" value={when} onChange={(e) => setWhen(e.target.value)} /></label>
        <label className="ad-field"><span>{t.appt.clinic}</span>
          <input className="ad-input" value={clinic} maxLength={160} onChange={(e) => setClinic(e.target.value)} /></label>
        <label className="ad-field"><span>{t.appt.notes}</span>
          <textarea className="ad-input" rows={3} maxLength={4000} value={notes} onChange={(e) => setNotes(e.target.value)} /></label>
        <button type="button" className="ad-btn ad-btn--primary ad-btn--sm" onClick={save} disabled={busy}>{t.appt.saveDetails}</button>
      </section>

      {!latest ? <Notice tone="info">{t.appt.noReport}</Notice> : (
        <section className="ad-card ad-summary">
          <h2 className="ad-h2">{t.appt.summary}</h2>
          {profile?.next_appointment_at && <p><b>{t.appt.date}:</b> {fmtDate(profile.next_appointment_at)}{profile.clinic_name ? ` · ${profile.clinic_name}` : ''}</p>}
          <h3 className="ad-h3">{t.appt.latest}: {reportTitle(latest, fmtDate, t)} {latest.is_demo && <DemoTag />}</h3>
          <ul className="ad-findings">
            {findings.map((f) => (
              <li key={f.k} className={f.ok === false ? 'is-off' : f.ok ? 'is-ok' : ''}>
                <span>{METRIC_BY_KEY[f.k].label[lang]}</span>
                <b className="ad-num">{formatMetric(f.m, fmtNum)}</b>
                {f.m!.status !== 'extracted' && <small>({t.status[f.m!.status]})</small>}
                {targetText(f.k, lang) && <small className="ad-muted">{t.detail.target}: <TargetText k={f.k} /></small>}
              </li>
            ))}
          </ul>
          {prev && (
            <>
              <h3 className="ad-h3">{t.appt.comparison} {prev.compat.level === 'limited' && <span className="ad-tag ad-tag--warn">{t.detail.limited}</span>}</h3>
              <ul className="ad-bullets">
                {COMPARE_KEYS.slice(0, 3).map((k) => {
                  const c = compareMetric(k, latest, prev.report, prev.compat);
                  return c.comparable ? <li key={k}>{METRIC_BY_KEY[k].short[lang]}: {fmtNum(c.previous)} → {fmtNum(c.current)} ({t.detail.dir[c.direction!]})</li> : null;
                })}
              </ul>
            </>
          )}
          {gaps.length > 0 && (<><h3 className="ad-h3">{t.appt.gaps}</h3><ul className="ad-bullets">{gaps.map((g, i) => <li key={i}>{g}</li>)}</ul></>)}
          <h3 className="ad-h3">{t.appt.labs}</h3>
          <ul className="ad-bullets">
            {relevantLabs.length ? relevantLabs.map((l) => <li key={l.id}>HbA1c <b className="ad-num">{fmtNum(l.value)}%</b> · {fmtDate(l.measured_on)} {l.is_demo && <DemoTag />}</li>) : <li>{t.history.noLabs}</li>}
          </ul>
          <h3 className="ad-h3">{t.appt.questions}</h3>
          {!savedQs.length && <p className="ad-muted ad-small">{t.appt.noQuestions}</p>}
          <ol className="ad-bullets">{qs.map((q) => <li key={q.id}>{q.question}</li>)}</ol>
          {notes.trim() && (<><h3 className="ad-h3">{t.appt.notes}</h3><p className="ad-pre">{notes}</p></>)}
          <p className="ad-muted ad-small">{t.appt.bring}</p>
          <p className="ad-fineprint">{t.disclaimer.short}</p>
        </section>
      )}
    </div>
  );
}
