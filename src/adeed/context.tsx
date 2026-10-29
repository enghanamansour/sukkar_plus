import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import type { Session } from '@supabase/supabase-js';
import { useNavigate } from 'react-router-dom';
import { supabase } from './lib/supabase';
import * as api from './lib/api';
import { ar, en, type Strings } from './strings';

type Lang = 'ar' | 'en';

interface AdeedContextValue {
  lang: Lang;
  t: Strings;
  basePath: string;
  go: (sub?: string) => void;
  session: Session | null;
  authReady: boolean;
  profile: api.Profile | null;
  reports: api.Report[];
  labs: api.LabResult[];
  questions: api.DoctorQuestion[];
  loading: boolean;
  loadError: string | null;
  refresh: (what?: Array<'profile' | 'reports' | 'labs' | 'questions'>) => Promise<void>;
  toast: (msg: string) => void;
  fmtDate: (iso: string | null | undefined) => string;
  fmtNum: (n: number | null | undefined, digits?: number) => string;
}

const Ctx = createContext<AdeedContextValue | null>(null);

export function useAdeed(): AdeedContextValue {
  const v = useContext(Ctx);
  if (!v) throw new Error('useAdeed outside provider');
  return v;
}

export function AdeedProvider({ lang, basePath, children }: { lang: Lang; basePath: string; children: ReactNode }) {
  const navigate = useNavigate();
  const t = lang === 'ar' ? ar : en;
  const [session, setSession] = useState<Session | null>(null);
  const [authReady, setAuthReady] = useState(false);
  const [profile, setProfile] = useState<api.Profile | null>(null);
  const [reports, setReports] = useState<api.Report[]>([]);
  const [labs, setLabs] = useState<api.LabResult[]>([]);
  const [questions, setQuestions] = useState<api.DoctorQuestion[]>([]);
  const [loading, setLoading] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [toastMsg, setToastMsg] = useState<string | null>(null);
  const toastTimer = useRef<number>();

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => { setSession(data.session); setAuthReady(true); });
    const { data } = supabase.auth.onAuthStateChange((_e, s) => setSession(s));
    return () => data.subscription.unsubscribe();
  }, []);

  const userId = session?.user.id ?? null;

  const refresh = useCallback(async (what: Array<'profile' | 'reports' | 'labs' | 'questions'> = ['profile', 'reports', 'labs', 'questions']) => {
    if (!userId) return;
    try {
      setLoadError(null);
      await Promise.all([
        what.includes('profile') ? api.getProfile().then(setProfile) : null,
        what.includes('reports') ? api.listReports().then(setReports) : null,
        what.includes('labs') ? api.listLabs().then(setLabs) : null,
        what.includes('questions') ? api.listQuestions().then(setQuestions) : null,
      ]);
    } catch (e) {
      setLoadError((e as Error).message);
    }
  }, [userId]);

  useEffect(() => {
    if (!userId) { setProfile(null); setReports([]); setLabs([]); setQuestions([]); return; }
    setLoading(true);
    refresh().finally(() => setLoading(false));
  }, [userId, refresh]);

  // Keep the server-side language (used for generated questions and assistant default) in sync with the app.
  useEffect(() => {
    if (profile && profile.preferred_language !== lang) {
      api.updateProfile(profile.id, { preferred_language: lang }).then(() => setProfile({ ...profile, preferred_language: lang })).catch(() => undefined);
    }
  }, [lang, profile]);

  // Poll while any report is still being processed.
  const busy = reports.some((r) => r.status === 'processing' || r.status === 'uploaded');
  useEffect(() => {
    if (!busy) return;
    const id = window.setInterval(() => refresh(['reports', 'questions']), 4000);
    return () => window.clearInterval(id);
  }, [busy, refresh]);

  const toast = useCallback((msg: string) => {
    setToastMsg(msg);
    window.clearTimeout(toastTimer.current);
    toastTimer.current = window.setTimeout(() => setToastMsg(null), 2600);
  }, []);

  const locale = lang === 'ar' ? 'ar-SA-u-ca-gregory-nu-latn' : 'en-GB';
  const fmtDate = useCallback((iso: string | null | undefined) => {
    if (!iso) return t.common.none;
    const d = new Date(iso.length === 10 ? `${iso}T00:00:00` : iso);
    return Number.isNaN(d.getTime()) ? iso : d.toLocaleDateString(locale, { year: 'numeric', month: 'short', day: 'numeric' });
  }, [locale, t]);
  const fmtNum = useCallback((n: number | null | undefined, digits = 1) => {
    if (n === null || n === undefined || Number.isNaN(n)) return t.common.none;
    return new Intl.NumberFormat(locale, { maximumFractionDigits: digits }).format(n);
  }, [locale, t]);

  const go = useCallback((sub = '') => navigate(sub ? `${basePath}/${sub}` : basePath), [navigate, basePath]);

  const value = useMemo<AdeedContextValue>(() => ({
    lang, t, basePath, go, session, authReady, profile, reports, labs, questions, loading, loadError, refresh, toast, fmtDate, fmtNum,
  }), [lang, t, basePath, go, session, authReady, profile, reports, labs, questions, loading, loadError, refresh, toast, fmtDate, fmtNum]);

  return (
    <Ctx.Provider value={value}>
      {children}
      <div className="ad-toast" role="status" aria-live="polite" data-visible={toastMsg ? 'true' : 'false'}>{toastMsg}</div>
    </Ctx.Provider>
  );
}
