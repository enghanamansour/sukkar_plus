import { useEffect, useState } from 'react';
import { LogOut } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAdeed } from '../context';
import * as api from '../lib/api';
import { loadDemoData } from '../lib/demo';
import { PageHead } from '../components';

export function SettingsPage() {
  const { t, profile, reports, session, refresh, toast } = useAdeed();
  const [name, setName] = useState('');
  const [type, setType] = useState<api.Profile['diabetes_type']>('unknown');
  const [busy, setBusy] = useState<string | null>(null);
  const [demoMsg, setDemoMsg] = useState<string | null>(null);

  useEffect(() => { setName(profile?.full_name ?? ''); setType(profile?.diabetes_type ?? 'unknown'); }, [profile]);
  const hasDemo = reports.some((r) => r.is_demo);

  const save = async () => {
    if (!profile) return;
    setBusy('save');
    try { await api.updateProfile(profile.id, { full_name: name.trim() || null, diabetes_type: type }); await refresh(['profile']); toast(t.common.saved); }
    catch { toast(t.common.unknownError); } finally { setBusy(null); }
  };
  const demo = async () => {
    if (!session) return;
    setBusy('demo');
    try { await loadDemoData(session.user.id, (i, n) => setDemoMsg(t.settings.demoLoading(i, n))); await refresh(); toast(t.settings.demoDone); }
    catch (e) { toast(`${t.common.unknownError} ${(e as Error).message}`); await refresh(); } finally { setBusy(null); setDemoMsg(null); }
  };
  const removeDemo = async () => {
    if (!session) return;
    setBusy('demo-remove');
    try { await api.deleteAllMyData(session.user.id, reports, true); await refresh(); toast(t.settings.demoRemoved); }
    catch { toast(t.common.unknownError); } finally { setBusy(null); }
  };
  const wipe = async () => {
    if (!session || !window.confirm(`${t.settings.dangerLead}\n${t.common.confirmDelete}`)) return;
    setBusy('wipe');
    try { await api.deleteAllMyData(session.user.id, reports); await refresh(); toast(t.settings.allDeleted); }
    catch { toast(t.common.unknownError); } finally { setBusy(null); }
  };

  return (
    <div className="ad-stack">
      <PageHead title={t.settings.title} />
      <section className="ad-card ad-form">
        <p className="ad-muted ad-small" dir="ltr">{session?.user.email}</p>
        <label className="ad-field"><span>{t.settings.name}</span>
          <input className="ad-input" value={name} maxLength={120} onChange={(e) => setName(e.target.value)} /></label>
        <label className="ad-field"><span>{t.settings.diabetesType}</span>
          <select className="ad-input" value={type} onChange={(e) => setType(e.target.value as api.Profile['diabetes_type'])}>
            {(Object.keys(t.settings.types) as Array<keyof typeof t.settings.types>).map((k) => <option key={k} value={k}>{t.settings.types[k]}</option>)}
          </select></label>
        <p className="ad-muted ad-small">{t.settings.langNote}</p>
        <button type="button" className="ad-btn ad-btn--primary ad-btn--sm" onClick={save} disabled={busy !== null}>{t.common.save}</button>
      </section>

      <section className="ad-card">
        <h2 className="ad-h3">{t.settings.demoTitle}</h2>
        <p className="ad-muted ad-small">{t.settings.demoLead}</p>
        <div className="ad-row">
          <button type="button" className="ad-btn ad-btn--secondary ad-btn--sm" onClick={demo} disabled={busy !== null || hasDemo}>{demoMsg ?? t.settings.loadDemo}</button>
          {hasDemo && <button type="button" className="ad-btn ad-btn--ghost ad-btn--sm" onClick={removeDemo} disabled={busy !== null}>{t.settings.removeDemo}</button>}
        </div>
      </section>

      <section className="ad-card">
        <h2 className="ad-h3">{t.settings.about}</h2>
        <p className="ad-small">{t.settings.aboutBody}</p>
        <p className="ad-fineprint">{t.disclaimer.notAffiliated}</p>
      </section>

      <section className="ad-card ad-card--danger">
        <h2 className="ad-h3">{t.settings.dangerTitle}</h2>
        <p className="ad-muted ad-small">{t.settings.dangerLead}</p>
        <button type="button" className="ad-btn ad-btn--danger ad-btn--sm" onClick={wipe} disabled={busy !== null}>{t.settings.deleteAll}</button>
      </section>

      <button type="button" className="ad-btn ad-btn--ghost ad-btn--block" onClick={() => supabase.auth.signOut()}>
        <LogOut size={16} aria-hidden className="flip-rtl" /> {t.auth.signOut}
      </button>
    </div>
  );
}
