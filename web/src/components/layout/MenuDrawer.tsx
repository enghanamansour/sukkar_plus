import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { FileText, Info, LockOpen, MoonStar, PhoneCall, Settings, X } from 'lucide-react';
import type { ReactNode } from 'react';
import { useLanguage } from '../../i18n';
import { ROUTES, serviceRoute } from '../../routes';
import { ThemeSwitch } from '../ui';

/** Menu glyph with a shorter middle line, as used on the reference "المزيد" panel. */
function MoreIcon() {
  return (
    <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden className="flip-rtl">
      <path d="M3.5 6h17M3.5 12h11M3.5 18h17" />
    </svg>
  );
}

/**
 * "المزيد" panel opened from the home header menu icon.
 * Matches the reference: a light sheet that rises from below the header and covers the rest
 * of the screen (including the bottom nav), with no dimmed backdrop.
 */
export function MenuDrawer({ open, onClose }: { open: boolean; onClose: () => void }) {
  const ref = useRef<HTMLDialogElement>(null);
  const { t, dir } = useLanguage();
  const [top, setTop] = useState(0);

  // Start the sheet where the home content sheet begins (just under the search bar).
  useLayoutEffect(() => {
    if (!open) return;
    const sheet = document.querySelector('.home-sheet');
    const frame = document.querySelector('.app-frame');
    const y = sheet ? sheet.getBoundingClientRect().top : 0;
    const frameTop = frame ? frame.getBoundingClientRect().top : 0;
    setTop(Math.max(frameTop, y));
  }, [open]);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    if (open && !el.open) el.showModal();
    if (!open && el.open) el.close();
  }, [open]);

  const items: { label: string; to: string; icon: ReactNode }[] = [
    { label: t.menu.settings, to: ROUTES.settings, icon: <Settings size={21} strokeWidth={1.6} aria-hidden /> },
    { label: t.menu.about, to: serviceRoute('home', 'about'), icon: <Info size={20} strokeWidth={1.6} aria-hidden /> },
    { label: t.menu.terms, to: serviceRoute('home', 'terms'), icon: <FileText size={20} strokeWidth={1.6} aria-hidden /> },
    { label: t.menu.privacy, to: serviceRoute('home', 'privacy'), icon: <LockOpen size={20} strokeWidth={1.6} aria-hidden /> },
    { label: t.menu.contact, to: serviceRoute('home', 'contact'), icon: <PhoneCall size={20} strokeWidth={1.6} aria-hidden /> },
  ];

  return (
    <dialog
      ref={ref}
      className="more-sheet"
      dir={dir}
      aria-label={t.menu.title}
      style={{ top }}
      onCancel={(e) => {
        e.preventDefault();
        onClose();
      }}
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div className="more-sheet__head">
        <div className="more-sheet__title">
          <MoreIcon />
          <h2>{t.menu.title}</h2>
        </div>
        <button type="button" className="more-sheet__close" onClick={onClose} aria-label={t.common.close}>
          <X size={14} strokeWidth={2.6} aria-hidden />
        </button>
      </div>
      <div className="more-sheet__setting">
        <span className="more-sheet__setting-label">
          <MoonStar size={20} strokeWidth={1.6} aria-hidden />
          {t.theme.label}
        </span>
        <ThemeSwitch />
      </div>
      <ul className="more-sheet__list">
        {items.map((item) => (
          <li key={item.to}>
            <Link to={item.to} className="more-sheet__item" onClick={onClose}>
              {item.icon}
              <span>{item.label}</span>
            </Link>
          </li>
        ))}
      </ul>
    </dialog>
  );
}
