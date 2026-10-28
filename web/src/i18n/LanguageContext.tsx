import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import type { Direction, Language, LocalizedText } from '../types';
import { ar, type Dictionary } from './ar';
import { en } from './en';

export const dictionaries: Record<Language, Dictionary> = { ar, en };

/** localStorage key used to persist the selected language across refreshes. */
export const LANGUAGE_STORAGE_KEY = 'sehhaty-mockup.language';
const DEFAULT_LANGUAGE: Language = 'ar';

export const directionFor = (lang: Language): Direction => (lang === 'ar' ? 'rtl' : 'ltr');

/** Locale used for numbers and dates. Arabic keeps Latin digits and the Gregorian calendar, as in the reference app. */
export const localeFor = (lang: Language): string => (lang === 'ar' ? 'ar-SA-u-ca-gregory-nu-latn' : 'en-GB');

function readStoredLanguage(): Language {
  try {
    const stored = window.localStorage.getItem(LANGUAGE_STORAGE_KEY);
    if (stored === 'ar' || stored === 'en') return stored;
  } catch {
    /* storage unavailable (private mode etc.) — fall back to default */
  }
  return DEFAULT_LANGUAGE;
}

interface LanguageContextValue {
  lang: Language;
  dir: Direction;
  /** Dictionary for the active language. */
  t: Dictionary;
  setLang: (lang: Language) => void;
  toggleLang: () => void;
  /** Pick the active-language value from a `LocalizedText` in mock data. */
  l: (text: LocalizedText) => string;
  formatNumber: (n: number, options?: Intl.NumberFormatOptions) => string;
  formatDateTime: (iso: string) => string;
  formatDate: (iso: string) => string;
}

const LanguageContext = createContext<LanguageContextValue | null>(null);

export function LanguageProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<Language>(readStoredLanguage);
  const dir = directionFor(lang);
  const t = dictionaries[lang];

  // Keep <html lang/dir> and the tab title in sync — this is what drives RTL/LTR globally.
  useEffect(() => {
    const root = document.documentElement;
    root.lang = lang;
    root.dir = dir;
    document.title = t.app.documentTitle;
    try {
      window.localStorage.setItem(LANGUAGE_STORAGE_KEY, lang);
    } catch {
      /* ignore */
    }
  }, [lang, dir, t]);

  const setLang = useCallback((next: Language) => setLangState(next), []);
  const toggleLang = useCallback(() => setLangState((cur) => (cur === 'ar' ? 'en' : 'ar')), []);

  const value = useMemo<LanguageContextValue>(() => {
    const locale = localeFor(lang);
    return {
      lang,
      dir,
      t,
      setLang,
      toggleLang,
      l: (text) => text[lang],
      formatNumber: (n, options) => new Intl.NumberFormat(locale, options).format(n),
      formatDateTime: (iso) => {
        const d = new Date(iso);
        const date = new Intl.DateTimeFormat(locale, { day: 'numeric', month: 'long', year: 'numeric' }).format(d);
        const time = new Intl.DateTimeFormat(locale, { hour: '2-digit', minute: '2-digit', hour12: true }).format(d);
        return `${date} | ${time}`;
      },
      formatDate: (iso) =>
        new Intl.DateTimeFormat(locale, { day: 'numeric', month: 'long', year: 'numeric' }).format(new Date(iso)),
    };
  }, [lang, dir, t, setLang, toggleLang]);

  return <LanguageContext.Provider value={value}>{children}</LanguageContext.Provider>;
}

export function useLanguage(): LanguageContextValue {
  const ctx = useContext(LanguageContext);
  if (!ctx) throw new Error('useLanguage must be used inside <LanguageProvider>');
  return ctx;
}
