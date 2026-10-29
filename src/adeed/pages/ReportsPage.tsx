import { useState } from 'react';
import { AlertTriangle, ChevronLeft, ChevronRight, RefreshCw } from 'lucide-react';
import { useAdeed } from '../context';
import * as api from '../lib/api';
import { DemoTag, PageHead, RangeStrip, Spinner, reportTitle } from '../components';
import { UploadBox } from './UploadBox';

export function ReportsPage() {
  const { t, lang, reports, go, fmtDate, refresh, toast } = useAdeed();
  const [retrying, setRetrying] = useState<string | null>(null);
  const Chevron = lang === 'ar' ? ChevronLeft : ChevronRight;

  const retry = async (id: string) => {
    setRetrying(id);
    try { await api.processReport(id); } catch (e) { toast((e as Error).message); }
    await refresh(['reports', 'questions']);
    setRetrying(null);
  };

  return (
    <div className="ad-stack">
      <PageHead title={t.reports.title} />
      <section className="ad-card"><UploadBox /></section>
      {reports.length === 0 ? (
        <p className="ad-muted ad-center">{t.reports.empty}</p>
      ) : (
        <ul className="ad-list">
          {reports.map((r) => (
            <li key={r.id} className={`ad-list__item ad-report ad-report--${r.status}`}>
              <button type="button" className="ad-report__main" onClick={() => go(`reports/${r.id}`)} disabled={r.status !== 'processed' && r.status !== 'failed'}>
                <span className="ad-report__title">
                  {reportTitle(r, fmtDate, t)}
                  {r.is_demo && <DemoTag />}
                </span>
                <span className="ad-report__meta">
                  {t.reports.kind[r.report_kind]}{r.period_days ? ` · ${r.period_days} ${t.common.days}` : ''} · <span dir="auto">{r.file_name}</span>
                </span>
                {r.status === 'processed' && <RangeStrip report={r} />}
                {(r.status === 'processing' || r.status === 'uploaded') && <Spinner label={t.reports.status[r.status]} />}
                {r.status === 'failed' && <span className="ad-report__err"><AlertTriangle size={14} aria-hidden /> {r.error_message ?? t.reports.status.failed}</span>}
                {r.status === 'processed' && <Chevron size={18} aria-hidden className="ad-report__chev" />}
              </button>
              {r.status === 'failed' && (
                <button type="button" className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => retry(r.id)} disabled={retrying === r.id}>
                  <RefreshCw size={14} aria-hidden /> {t.reports.retry}
                </button>
              )}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
