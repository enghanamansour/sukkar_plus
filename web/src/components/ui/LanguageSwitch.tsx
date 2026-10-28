import { Globe } from 'lucide-react';
import { useLanguage } from '../../i18n';
import type { Language } from '../../types';

/**
 * Language switch.
 *  - `compact`: a small pill for the home header (shows the *other* language).
 *  - `segmented`: an explicit العربية / English choice for settings rows.
 */
export function LanguageSwitch({ variant = 'compact' }: { variant?: 'compact' | 'segmented' }) {
  const { lang, t, setLang, toggleLang } = useLanguage();

  if (variant === 'compact') {
    return (
      <button
        type="button"
        className="lang-pill"
        onClick={toggleLang}
        aria-label={t.language.switchTo}
        title={t.language.switchTo}
        lang={lang === 'ar' ? 'en' : 'ar'}
      >
        <Globe size={15} aria-hidden />
        <span>{t.language.short}</span>
      </button>
    );
  }

  const options: { value: Language; label: string }[] = [
    { value: 'ar', label: t.language.arabic },
    { value: 'en', label: t.language.english },
  ];
  return (
    <div className="segmented segmented--small" role="radiogroup" aria-label={t.language.label}>
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          role="radio"
          aria-checked={lang === o.value}
          className={`segmented__option ${lang === o.value ? 'is-active' : ''}`}
          onClick={() => setLang(o.value)}
          lang={o.value}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}
