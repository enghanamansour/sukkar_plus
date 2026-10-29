import { useRef, useState, type DragEvent } from 'react';
import { CheckCircle2, Lock, UploadCloud } from 'lucide-react';
import { useAdeed } from '../context';
import * as api from '../lib/api';
import { Notice, Spinner } from '../components';

type Phase = 'idle' | 'uploading' | 'processing' | 'done' | 'error';

export function UploadBox({ compact = false }: { compact?: boolean }) {
  const { t, session, refresh, go } = useAdeed();
  const input = useRef<HTMLInputElement>(null);
  const [phase, setPhase] = useState<Phase>('idle');
  const [error, setError] = useState<string | null>(null);
  const [reportId, setReportId] = useState<string | null>(null);
  const [drag, setDrag] = useState(false);

  const handle = async (file: File | undefined) => {
    if (!file || !session) return;
    setError(null);
    if (file.size > api.MAX_PDF_BYTES) { setPhase('error'); setError(t.upload.tooLarge); return; }
    if (!/\.pdf$/i.test(file.name) && file.type !== 'application/pdf') { setPhase('error'); setError(t.upload.notPdf); return; }
    try {
      setPhase('uploading');
      const id = await api.uploadReport(session.user.id, file, file.name);
      setReportId(id);
      setPhase('processing');
      await refresh(['reports']);
      try {
        await api.processReport(id);
      } catch (e) {
        // Processing errors are stored on the report itself and shown in the list.
        await refresh(['reports']);
        setPhase('error');
        setError((e as Error).message);
        return;
      }
      await refresh(['reports', 'questions']);
      setPhase('done');
    } catch (e) {
      const code = (e as api.ApiError).code;
      setPhase('error');
      setError(code === 'not_pdf' ? t.upload.notPdf : code === 'too_large' ? t.upload.tooLarge : `${t.upload.failed} ${(e as Error).message}`);
    } finally {
      if (input.current) input.current.value = '';
    }
  };

  const onDrop = (e: DragEvent) => { e.preventDefault(); setDrag(false); handle(e.dataTransfer.files?.[0]); };
  const busy = phase === 'uploading' || phase === 'processing';

  return (
    <div className={`ad-upload ${compact ? 'ad-upload--compact' : ''} ${drag ? 'is-drag' : ''}`}
      onDragOver={(e) => { e.preventDefault(); setDrag(true); }} onDragLeave={() => setDrag(false)} onDrop={onDrop}>
      <input ref={input} type="file" accept="application/pdf,.pdf" hidden onChange={(e) => handle(e.target.files?.[0])} />
      {busy ? (
        <Spinner label={phase === 'uploading' ? t.upload.uploading : t.upload.processing} />
      ) : phase === 'done' && reportId ? (
        <div className="ad-upload__done">
          <CheckCircle2 size={22} aria-hidden className="ad-ok" />
          <span>{t.upload.done}</span>
          <button type="button" className="ad-btn ad-btn--primary ad-btn--sm" onClick={() => go(`reports/${reportId}`)}>{t.upload.open}</button>
          <button type="button" className="ad-link" onClick={() => { setPhase('idle'); setReportId(null); }}>{t.home.upload}</button>
        </div>
      ) : (
        <>
          <UploadCloud size={compact ? 22 : 30} aria-hidden className="ad-upload__icon" />
          {!compact && <p className="ad-upload__title">{t.upload.drop}</p>}
          <p className="ad-upload__hint">{t.upload.hint}</p>
          <button type="button" className="ad-btn ad-btn--primary" onClick={() => input.current?.click()}>{t.upload.choose}</button>
          <p className="ad-upload__privacy"><Lock size={12} aria-hidden /> {t.upload.privacy}</p>
        </>
      )}
      {error && <Notice tone="danger">{error}</Notice>}
    </div>
  );
}
