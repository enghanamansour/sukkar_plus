import { useState, type FormEvent } from 'react';
import { Trash2 } from 'lucide-react';
import { METRIC_BY_KEY } from '@core/catalog';
import { reportCompatibility } from '@core/compare';
import { useAdeed } from '../context';
import * as api from '../lib/api';
import { DemoTag, Notice, PageHead, RangeStrip, StatusChip, formatMetric, metricOf } from '../components';

export function HistoryPage() {
  const { t, lang, reports, labs, refresh, toast, fmtDate, fmtNum, go } = useAdeed();
  const [value, setValue] = useState('');
  const [date, setDate] = useState('');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const cgm = reports.filter((r) => r.status === 'processed' && r.report_kind === 'cgm_agp')
    .sort((a, b) => ((b.period_end ?? '') > (a.period_end ?? '') ? 1 : -1));
  const groups = [cgm.filter((r) => !r.is_demo), cgm.filter((r) => r.is_demo)].filter((g) => g.length);

  const addLab = async (e: FormEvent) => {
    e.preventDefault();
    const v = Number(value.replace(',', '.'));
    const today = new Date().toISOString().slice(0, 10);
    if (!(v >= 3 && v <= 20) || !date || date > today) { setErr(t.history.invalidLab); return; }
    setBusy(true); setErr(null);
    try { await api.addLab(Math.round(v * 10) / 10, date, note.trim() || null); setValue(''); setDate(''); setNote(''); await refresh(['labs']); toast(t.common.saved); }
    catch (e2) { setErr((e2 as Error).message); } finally { setBusy(false); }
  };
  const delLab = async (id: string) => {
    if (!window.confirm(t.common.confirmDelete)) return;
    try { await api.deleteLab(id); await refresh(['labs']); } catch { toast(t.common.unknownError); }
  };

  return (
    <div className="ad-stack">
      <PageHead title={t.history.title} lead={t.history.lead} />

      <section className="ad-card">
        <h2 className="ad-h2">{t.history.cgm}</h2>
        {cgm.length === 0 && <p className="ad-muted">{t.reports.empty}</p>}
        {groups.map((g, gi) => (
          <div key={gi} className="ad-history">
            {g[0].is_demo && <p><DemoTag /></p>}
            {g.length === 1 && <p className="ad-muted ad-small">{t.history.onlyOne}</p>}
            <div className="ad-tablewrap">
              <table className="ad-table ad-history__table">
                <thead>
                  <tr>
                    <th>{t.reports.period}</th>
                    <th className="ad-history__barcol">{t.detail.ranges}</th>
                    {(['tir', 'tbr_total', 'mean_glucose', 'gmi', 'cv'] as const).map((k) => <th key={k}>{METRIC_BY_KEY[k].short[lang]}</th>)}
                  </tr>
                </thead>
                <tbody>
                  {g.map((r) => {
                    const c = r === g[0] ? null : reportCompatibility(g[0], r);
                    return (
                      <tr key={r.id} onClick={() => go(`reports/${r.id}`)} className="ad-clickrow">
                        <td>
                          <span className="ad-nowrap">{fmtDate(r.period_start)} – {fmtDate(r.period_end)}</span>
                          <small className="ad-muted"> · {r.period_days} {t.common.days}</small>
                          {c && c.level !== 'compatible' && <span className="ad-tag ad-tag--warn">{c.level === 'limited' ? t.history.limitedNote : t.detail.notComparable}</span>}
                        </td>
                        <td className="ad-history__barcol"><RangeStrip report={r} /></td>
                        {(['tir', 'tbr_total', 'mean_glucose', 'gmi', 'cv'] as const).map((k) => {
                          const m = metricOf(r, k);
                          return <td key={k} className="ad-num">{formatMetric(m, fmtNum)}{m && m.status === 'uncertain' && <> <StatusChip status="uncertain" /></>}</td>;
                        })}
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
            <ul className="ad-legend" aria-hidden>
              {(['tbr_level2', 'tbr_level1', 'tir', 'tar_level1', 'tar_level2'] as const).map((k) => (
                <li key={k}><span className={`ad-swatch ad-c-${k}`} />{METRIC_BY_KEY[k].short[lang]}</li>
              ))}
            </ul>
          </div>
        ))}
      </section>

      <section className="ad-card">
        <h2 className="ad-h2">{t.history.labs}</h2>
        <Notice tone="info">{t.history.gmiVsA1c}</Notice>
        {labs.length === 0 ? <p className="ad-muted">{t.history.noLabs}</p> : (
          <ul className="ad-list">
            {labs.map((l) => (
              <li key={l.id} className="ad-list__item ad-lab">
                <b className="ad-num ad-big">{fmtNum(l.value)}%</b>
                <span>{fmtDate(l.measured_on)} · {t.history.source[l.source]}</span>
                {l.is_demo && <DemoTag />}
                {l.note && <small className="ad-muted" dir="auto">{l.note}</small>}
                {l.source !== 'report' && <button type="button" className="ad-iconbtn ad-iconbtn--danger" onClick={() => delLab(l.id)} aria-label={t.common.delete}><Trash2 size={16} aria-hidden /></button>}
              </li>
            ))}
          </ul>
        )}
        <form className="ad-form ad-form--row" onSubmit={addLab}>
          <label className="ad-field"><span>{t.history.value}</span>
            <input className="ad-input" inputMode="decimal" dir="ltr" value={value} onChange={(e) => setValue(e.target.value)} placeholder="7.2" /></label>
          <label className="ad-field"><span>{t.history.date}</span>
            <input className="ad-input" type="date" value={date} max={new Date().toISOString().slice(0, 10)} onChange={(e) => setDate(e.target.value)} /></label>
          <label className="ad-field ad-field--wide"><span>{t.history.note}</span>
            <input className="ad-input" value={note} maxLength={500} onChange={(e) => setNote(e.target.value)} /></label>
          <button type="submit" className="ad-btn ad-btn--primary ad-btn--sm" disabled={busy}>{t.history.addLab}</button>
        </form>
        {err && <Notice tone="danger">{err}</Notice>}
      </section>
    </div>
  );
}
