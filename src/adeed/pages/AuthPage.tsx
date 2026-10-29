import { useState, type FormEvent } from 'react';
import { ShieldCheck } from 'lucide-react';
import { supabase, supabaseConfigured } from '../lib/supabase';
import { useAdeed } from '../context';
import { Notice } from '../components';

type Mode = 'signin' | 'signup' | 'reset';

export function AuthPage() {
  const { t } = useAdeed();
  const [mode, setMode] = useState<Mode>('signin');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setBusy(true); setError(null); setInfo(null);
    try {
      if (mode === 'signin') {
        const { error: err } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
        if (err) {
          setError(/confirm/i.test(err.message) ? t.auth.emailNotConfirmed : /invalid/i.test(err.message) ? t.auth.invalidCredentials : err.message);
        }
      } else if (mode === 'signup') {
        const { data, error: err } = await supabase.auth.signUp({
          email: email.trim(), password,
          options: { data: { full_name: name.trim() }, emailRedirectTo: window.location.href },
        });
        if (err) setError(err.message);
        else if (!data.session) { setInfo(t.auth.checkEmail); setMode('signin'); }
      } else {
        const { error: err } = await supabase.auth.resetPasswordForEmail(email.trim(), { redirectTo: window.location.href });
        if (err) setError(err.message); else setInfo(t.auth.resetSent);
      }
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="ad-auth">
      <div className="ad-auth__brand">
        <span className="ad-auth__mark" aria-hidden>ع</span>
        <h1>{t.auth.title}</h1>
        <p>{t.auth.lead}</p>
      </div>
      {!supabaseConfigured && <Notice tone="danger">{t.auth.notConfigured}</Notice>}
      <form className="ad-card ad-form" onSubmit={submit} noValidate>
        <h2 className="ad-h2">{mode === 'signup' ? t.auth.signUp : mode === 'reset' ? t.auth.forgot : t.auth.signIn}</h2>
        {mode === 'signup' && (
          <label className="ad-field">
            <span>{t.auth.fullName}</span>
            <input className="ad-input" value={name} onChange={(e) => setName(e.target.value)} autoComplete="name" maxLength={120} />
          </label>
        )}
        <label className="ad-field">
          <span>{t.auth.email}</span>
          <input className="ad-input" type="email" dir="ltr" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="email" required />
        </label>
        {mode !== 'reset' && (
          <label className="ad-field">
            <span>{t.auth.password}</span>
            <input className="ad-input" type="password" dir="ltr" value={password} onChange={(e) => setPassword(e.target.value)}
              autoComplete={mode === 'signup' ? 'new-password' : 'current-password'} minLength={8} required />
            {mode === 'signup' && <small className="ad-muted">{t.auth.passwordHint}</small>}
          </label>
        )}
        {error && <Notice tone="danger">{error}</Notice>}
        {info && <Notice tone="info">{info}</Notice>}
        <button type="submit" className="ad-btn ad-btn--primary ad-btn--block"
          disabled={busy || !email.includes('@') || (mode !== 'reset' && password.length < (mode === 'signup' ? 8 : 1))}>
          {busy ? t.common.loading : mode === 'signup' ? t.auth.signUp : mode === 'reset' ? t.common.save : t.auth.signIn}
        </button>
        <div className="ad-auth__links">
          {mode !== 'signin' && <button type="button" className="ad-link" onClick={() => setMode('signin')}>{t.auth.haveAccount}</button>}
          {mode === 'signin' && <button type="button" className="ad-link" onClick={() => setMode('signup')}>{t.auth.noAccount}</button>}
          {mode === 'signin' && <button type="button" className="ad-link" onClick={() => setMode('reset')}>{t.auth.forgot}</button>}
        </div>
      </form>
      <p className="ad-auth__privacy"><ShieldCheck size={16} aria-hidden /> {t.auth.privacy}</p>
      <p className="ad-fineprint">{t.disclaimer.notAffiliated}</p>
    </div>
  );
}
