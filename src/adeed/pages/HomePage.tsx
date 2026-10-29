import { useMemo, useState } from 'react';
import { CalendarClock, ChevronLeft, ChevronRight, ListChecks, MessageCircle } from 'lucide-react';
import { findPreviousComparable, compareMetric } from '@core/compare';
import { METRIC_BY_KEY } from '@core/catalog';
import { useAdeed } from '../context';
import { DemoTag, ErrorBox, Notice, RangeChart, Spinner, StatusChip, formatMetric, metricOf, reportTitle } from '../components';
import { UploadBox } from './UploadBox';
import { loadDemoData } from '../lib/demo';

export function HomePage() {
  const { t, lang, profile, reports, questions, loading, loadError, refresh, go, fmtDate, fmtNum, session, toast } = useAdeed();
  const [demoBusy, setDemoBusy] = useState<string | null>(null);
  const Chevron = lang === 'ar' ? ChevronLeft : ChevronRight;

  const processed = reports.filter((r) => r.status === 'processed' && r.report_kind === 'cgm_agp');
  const realFirst = processed.filter((r) => !r.is_demo);
  const latest = (realFirst.length ? realFirst : processed)[0];
  const pending = reports.filter((r) => r.status === 'processing' || r.status === 'uploaded');
  const failed = reports.filter((r) => r.status === 'failed');
  const prev = useMemo(() => (latest ? findPreviousComparable(latest, processed) : null), [latest, processed]);
  const reportQs = latest ? questions.filter((q) => q.report_id === latest.id) : [];
  const saved = questions.filter((q) => q.is_saved).length;

  if (loading) return <Spinner label={t.common.loading} />;

  const startDemo = async () => {
    if (!session) return;
    try {
      await loadDemoData(session.user.id, (i, n) => setDemoBusy(t.settings.demoLoading(i, n)));
      await refresh();
      toast(t.settings.demoDone);
    } catch (e) { toast(`${t.common.unknownError} ${(e as Error).message}`); }
    finally { setDemoBusy(null); }
  };

  return (
    <div className="ad-stack">
      <section className="ad-hello">
        <h1 className="ad-hello__title">{t.home.greeting(profile?.full_name?.split(' ')[0] ?? '')}</h1>
        <p className="ad-muted">{t.home.lead}</p>
      </section>

      {loadError && <ErrorBox message={loadError} onRetry={() => refresh()} />}
      {pending.length > 0 && <Notice tone="info"><Spinner label={t.home.processing} /></Notice>}
      {failed.length > 0 && (
        <Notice tone="warn" title={t.home.failed}>
          <button type="button" className="ad-link" onClick={() => go('reports')}>{failed[0].file_name}</button>
        </Notice>
      )}

      {!latest ? (
        <section className="ad-card ad-empty">
          <h2 className="ad-h2">{t.home.emptyTitle}</h2>
          <p className="ad-muted">{t.home.emptyBody}</p>
          <UploadBox />
          <div className="ad-divider" />
          <p className="ad-muted ad-small">{t.settings.demoLead}</p>
          <button type="button" className="ad-btn ad-btn--secondary" onClick={startDemo} disabled={Boolean(demoBusy)}>
            {demoBusy ?? t.home.tryDemo}
          </button>
        </section>
      ) : (
        <section className="ad-card">
          <header className="ad-cardhead">
            <div>
              <p className="ad-eyebrow">{t.home.latest}</p>
              <h2 className="ad-h2">{reportTitle(latest, fmtDate, t)}</h2>
              <p className="ad-muted ad-small">{latest.period_days ? `${latest.period_days} ${t.common.days}` : ''}{latest.device ? ` · ${latest.device}` : ''}</p>
            </div>
            {latest.is_demo && <DemoTag />}
          </header>
          {latest.is_demo && <Notice tone="demo">{t.home.demoNotice}</Notice>}
          <RangeChart report={latest} />
          <div className="ad-kpis">
            {(['mean_glucose', 'gmi', 'cv'] as const).map((k) => {
              const m = metricOf(latest, k);
              return (
                <div key={k} className="ad-kpi">
                  <span className="ad-kpi__label">{METRIC_BY_KEY[k].short[lang]}</span>
                  <span className="ad-kpi__value ad-num">{formatMetric(m, fmtNum)}</span>
                  {m && m.status !== 'extracted' && <StatusChip status={m.status} />}
                </div>
              );
            })}
          </div>
          <div className="ad-compare-mini">
            <p className="ad-eyebrow">{t.home.comparedWith}</p>
            {prev ? (
              <p>
                {(['tir', 'tbr_total'] as const).map((k) => {
                  const c = compareMetric(k, latest, prev.report, prev.compat);
                  if (!c.comparable) return null;
                  return <span key={k} className={`ad-delta ad-delta--${c.direction}`}>{METRIC_BY_KEY[k].short[lang]}: {fmtNum(c.previous)}% → {fmtNum(c.current)}% ({t.detail.dir[c.direction!]})</span>;
                })}
                {prev.compat.level === 'limited' && <span className="ad-tag ad-tag--warn">{t.detail.limited}</span>}
              </p>
            ) : <p className="ad-muted ad-small">{t.home.noComparison}</p>}
          </div>
          <button type="button" className="ad-btn ad-btn--primary ad-btn--block" onClick={() => go(`reports/${latest.id}`)}>{t.home.viewReport}</button>
        </section>
      )}

      <nav className="ad-tiles" aria-label={t.nav.home}>
        <button type="button" className="ad-tile" onClick={() => go('questions')}>
          <ListChecks size={22} aria-hidden />
          <span className="ad-tile__title">{t.nav.questions}</span>
          <span className="ad-tile__sub">{t.home.questionsReady(reportQs.length || questions.length)} · {t.home.savedQuestions(saved)}</span>
          <Chevron size={18} aria-hidden className="ad-tile__chev" />
        </button>
        <button type="button" className="ad-tile" onClick={() => go('appointment')}>
          <CalendarClock size={22} aria-hidden />
          <span className="ad-tile__title">{t.home.nextAppt}</span>
          <span className="ad-tile__sub">{profile?.next_appointment_at ? `${fmtDate(profile.next_appointment_at)}${profile.clinic_name ? ` · ${profile.clinic_name}` : ''}` : t.home.setAppt}</span>
          <Chevron size={18} aria-hidden className="ad-tile__chev" />
        </button>
        <button type="button" className="ad-tile" onClick={() => go('chat')}>
          <MessageCircle size={22} aria-hidden />
          <span className="ad-tile__title">{t.home.askAdeed}</span>
          <span className="ad-tile__sub">{t.home.askLead}</span>
          <Chevron size={18} aria-hidden className="ad-tile__chev" />
        </button>
      </nav>

      {latest && (
        <section className="ad-card">
          <h2 className="ad-h3">{t.home.upload}</h2>
          <UploadBox compact />
        </section>
      )}
    </div>
  );
}
