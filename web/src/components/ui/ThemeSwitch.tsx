import { Moon, Sun } from 'lucide-react';
import { useLanguage } from '../../i18n';
import { useTheme, type Theme } from '../../theme/ThemeContext';

/** فاتح / داكن segmented switch (same look as the language switch). */
export function ThemeSwitch() {
  const { t } = useLanguage();
  const { theme, setTheme } = useTheme();
  const options: { value: Theme; label: string; icon: JSX.Element }[] = [
    { value: 'light', label: t.theme.light, icon: <Sun size={14} aria-hidden /> },
    { value: 'dark', label: t.theme.dark, icon: <Moon size={14} aria-hidden /> },
  ];
  return (
    <div className="segmented segmented--small" role="radiogroup" aria-label={t.theme.label}>
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          role="radio"
          aria-checked={theme === o.value}
          className={`segmented__option segmented__option--icon ${theme === o.value ? 'is-active' : ''}`}
          onClick={() => setTheme(o.value)}
        >
          {o.icon}
          {o.label}
        </button>
      ))}
    </div>
  );
}
