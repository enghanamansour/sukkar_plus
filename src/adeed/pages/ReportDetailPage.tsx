import { useMemo, useState } from 'react';
import { useParams } from 'react-router-dom';
import { ExternalLink, MessageCircle, RefreshCw, Trash2 } from 'lucide-react';
import { COMPARE_KEYS, compareMetric, compatReasonText, findPreviousComparable } from '@core/compare';
import { METRIC_BY_KEY } from '@core/catalog';
import { checkMessage, namesLikelyMatch } from '@core/parser';
import { useAdeed } from '../context';
import * as api from '../lib/api';
import { DemoTag, MetricCard, Notice, PageHead, QuestionCard, RangeChart, formatMetric, metricOf, reportTitle } from '../components';

export function ReportDetailPage() {
  const { id } = useParams();
  const { t, lang, reports, labs, questions, profile, go, fmtDate, fmtNum, refresh, toast } = useAdeed();
  const report = reports.find((r) => r.id === id);
  const [busy, setBusy] = useState(false);

  const processed = reports.filter((r) => r.status === 'processed');
  const prev = useMemo(() => (report?.status === 'processed' ? findPreviousComparable(report, processed) : null), [report, processed]);

  if (!report) return <Notice tone="warn">{t.common.unknownError}</Notice>;

  const reportQs = questions.filter((q) => q.report_id === report.id);
  const sameKindLabs = labs.filter((l) => l.is_demo === report.is_demo);
  const nearestLab = report.period_end
    ? sameKindLabs.map((l) => ({ l, gap: Math.abs(Date.parse(l.measured_on) - Date.parse(report.period_end!)) / 86400000 }))
        .filter((x) => x.gap <= 120).sort((a, b) => a.gap - b.gap)[0]
    : undefined;

  const checks = [...(report.quality?.checks ?? [])];
  // Checked again on the client in case the profile name changed after processing.
  if (!report.is_demo && !checks.some((c) => c.key === 'name_mismatch') && namesLikelyMatch(profile?.full_name, report.name_on_report) === false) {
    checks.push({ key: 'name_mismatch', level: 'warn', params: { name: report.name_on_report } });
  }
  const settings = report.metrics.filter((m) => m.category === 'device_setting');

  const openPdf = async () => {
    try { window.open(await api.signedPdfUrl(report.file_path), '_blank', 'noopener'); } catch { toast(t.common.unknownError); }
  };
  const remove = async () => {
    if (!window.confirm(t.common.confirmDelete)) return;
    setBusy(true);
    try { await api.deleteReport(report); await refresh(); toast(t.reports.deleted); go('reports'); }
    catch { toast(t.common.unknownError); setBusy(false); }
  };
  const regen = async () => {
    setBusy(true);
    try { await api.regenerateQuestions(report.id); await refresh(['questions']); toast(t.common.saved); }
    catch (e) { toast((e as Error).message); }
    finally { setBusy(false); }
  };
  const reprocess = async () => {
    setBusy(true);
    try { await api.processReport(report.id); } catch (e) { toast((e as Error).message); }
    await refresh(['reports', 'questions']); setBusy(false);
  };

  const actions = (
    <>
      <button type="button" className="ad-iconbtn" onClick={openPdf}><ExternalLink size={16} aria-hidden />{t.reports.viewPdf}</button>
      <button type="button" className="ad-iconbtn ad-iconbtn--danger" onClick={remove} disabled={busy}><Trash2 size={16} aria-hidden />{t.reports.deleteReport}</button>
    </>
  );

  if (report.status !== 'processed') {
    return (
      <div className="ad-stack">
        <PageHead title={report.file_name} actions={actions} />
        <Notice tone={report.status === 'failed' ? 'danger' : 'info'} title={report.status === 'failed' ? t.detail.failedTitle : t.reports.status[report.status]}>
          {report.error_message && <p>{report.error_message}</p>}
          {report.status === 'failed' && <button type="button" className="ad-btn ad-btn--ghost ad-btn--sm" onClick={reprocess} disabled={busy}><RefreshCw size={14} aria-hidden /> {t.reports.retry}</button>}
        </Notice>
      </div>
    );
  }

  return (
    <div className="ad-stack">
      <PageHead title={reportTitle(report, fmtDate, t)} lead={t.reports.kind[report.report_kind]} actions={actions} />
      {report.is_demo && <Notice tone="demo" title={t.common.demo}>{t.home.demoNotice}</Notice>}

      <section className="ad-card ad-facts">
        <dl>
          <div><dt>{t.reports.period}</dt><dd>{report.period_start ? `${fmtDate(report.period_start)} – ${fmtDate(report.period_end)} (${report.period_days} ${t.common.days})` : t.reports.noPeriod}</dd></div>
          <div><dt>{t.reports.generated}</dt><dd>{fmtDate(report.generated_on)}</dd></div>
          <div><dt>{t.reports.device}</dt><dd dir="auto">{report.device ?? t.common.none}</dd></div>
          <div><dt>{t.reports.source}</dt><dd dir="auto">{report.source_system ?? t.common.none}</dd></div>
          <div><dt>{t.detail.nameOnReport}</dt><dd dir="auto">{report.name_on_report ?? t.common.none}</dd></div>
          <div><dt>{t.reports.pages}</dt><dd>{report.page_count ?? t.common.none}</dd></div>
        </dl>
        {report.is_demo && <DemoTag />}
      </section>

      {report.report_kind === 'cgm_agp' && (
        <section className="ad-card">
          <h2 className="ad-h2">{t.detail.ranges}</h2>
          <p className="ad-muted ad-small">{t.detail.rangesLead}</p>
          <RangeChart report={report} />
        </section>
      )}

      <section className="ad-section">
        <h2 className="ad-h2">{t.detail.keyMetrics}</h2>
        <div className="ad-grid">
          {(report.report_kind === 'lab' ? ['hba1c'] : ['mean_glucose', 'gmi', 'cv', 'sd', 'cgm_active', 'automated_mode', 'tbr_total', 'tar_total']).map((k) => (
            <MetricCard key={k} metricKey={k} m={metricOf(report, k)}>
              {k === 'gmi' && <p className="ad-callout">{t.detail.gmiNotA1c}</p>}
            </MetricCard>
          ))}
        </div>
      </section>

      {report.report_kind === 'cgm_agp' && (
        <section className="ad-card">
          <h2 className="ad-h3">{t.detail.labTitle}</h2>
          {nearestLab ? (
            <p>
              <b className="ad-num ad-big">{fmtNum(nearestLab.l.value)}%</b> · {t.detail.labNear(fmtDate(nearestLab.l.measured_on))}
              {' · '}{t.history.source[nearestLab.l.source]}{nearestLab.l.is_demo && <> · <DemoTag /></>}
            </p>
          ) : <p className="ad-muted">{t.detail.labNone}</p>}
          <button type="button" className="ad-link" onClick={() => go('history')}>{t.detail.labAdd}</button>
        </section>
      )}

      {report.report_kind === 'cgm_agp' && (
        <section className="ad-card">
          <h2 className="ad-h3">{t.detail.compare}</h2>
          {!prev ? <p className="ad-muted">{t.detail.noPrev}</p> : (
            <>
              <p>
                <span className={`ad-tag ${prev.compat.level === 'compatible' ? 'ad-tag--ok' : 'ad-tag--warn'}`}>
                  {prev.compat.level === 'compatible' ? t.detail.compatible : t.detail.limited}
                </span>{' '}
                {fmtDate(prev.report.period_start)} – {fmtDate(prev.report.period_end)} ({prev.report.period_days} {t.common.days})
              </p>
              {prev.compat.reasons.length > 0 && <p className="ad-muted ad-small">{prev.compat.reasons.map((r) => compatReasonText(r, lang)).join(' · ')}</p>}
              <div className="ad-tablewrap">
                <table className="ad-table">
                  <thead><tr><th>{t.detail.range}</th><th>{t.detail.previous}</th><th>{t.detail.current}</th><th>{t.detail.change}</th></tr></thead>
                  <tbody>
                    {COMPARE_KEYS.map((k) => {
                      const c = compareMetric(k, report, prev.report, prev.compat);
                      const unit = c.unit === '%' ? '%' : c.unit ? ` ${c.unit}` : '';
                      return (
                        <tr key={k}>
                          <td>{METRIC_BY_KEY[k].short[lang]}</td>
                          <td className="ad-num">{c.previous == null ? '—' : `${fmtNum(c.previous)}${unit}`}</td>
                          <td className="ad-num">{c.current == null ? '—' : `${fmtNum(c.current)}${unit}`}</td>
                          <td>{c.comparable
                            ? <span className={`ad-delta ad-delta--${c.direction}`}>{c.delta! > 0 ? '+' : ''}{fmtNum(c.delta)} · {t.detail.dir[c.direction!]}{c.uncertain ? ` · ${t.status.uncertain}` : ''}</span>
                            : <span className="ad-muted">{t.detail.notComparable}</span>}</td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </>
          )}
        </section>
      )}

      <section className="ad-card">
        <h2 className="ad-h3">{t.detail.quality}: <span className={`ad-quality ad-quality--${report.quality?.score ?? 'fair'}`}>{t.detail.qualityScore[report.quality?.score ?? 'fair']}</span></h2>
        <ul className="ad-checks">
          {checks.map((c, i) => (
            <li key={i} className={`ad-check ad-check--${c.level}`}>{checkMessage(c, lang)}</li>
          ))}
        </ul>
      </section>

      <section className="ad-section">
        <div className="ad-sectionhead">
          <h2 className="ad-h2">{t.detail.questions}</h2>
          <button type="button" className="ad-iconbtn" onClick={regen} disabled={busy}><RefreshCw size={16} aria-hidden />{t.detail.regenerate}</button>
        </div>
        {reportQs.length === 0 ? <p className="ad-muted">{t.questions.empty}</p>
          : reportQs.map((q) => <QuestionCard key={q.id} q={q} onChanged={() => refresh(['questions'])} />)}
      </section>

      {settings.length > 0 && (
        <section className="ad-card">
          <h2 className="ad-h3">{t.detail.settings}</h2>
          <p className="ad-muted ad-small">{t.detail.settingsNote}</p>
          <dl className="ad-facts__inline">
            {settings.map((m) => (
              <div key={m.metric_key}><dt>{METRIC_BY_KEY[m.metric_key]?.label[lang]}</dt><dd className="ad-num">{formatMetric(m, fmtNum)}</dd></div>
            ))}
          </dl>
        </section>
      )}

      <button type="button" className="ad-btn ad-btn--primary ad-btn--block" onClick={() => go(`chat?ask=${encodeURIComponent(t.detail.askPrompt)}`)}>
        <MessageCircle size={18} aria-hidden /> {t.detail.ask}
      </button>
    </div>
  );
}
