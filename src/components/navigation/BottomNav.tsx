import { Link, useLocation } from 'react-router-dom';
import { CalendarDays, House, UserRound } from 'lucide-react';
import type { ReactNode } from 'react';
import { useLanguage } from '../../i18n';
import { WellnessIcon } from '../ui';
import { ROUTES, tabForPath, type TabId } from '../../routes';

/**
 * The four Sehhaty tabs. Order is logical (first = start side), so RTL renders
 * الرئيسية on the right and LTR renders Home on the left — matching the reference.
 * The diabetes service intentionally has NO entry here.
 */
export function BottomNav() {
  const { t } = useLanguage();
  const { pathname } = useLocation();
  const active = tabForPath(pathname);

  const items: { id: TabId; to: string; label: string; icon: ReactNode }[] = [
    { id: 'home', to: ROUTES.home, label: t.nav.home, icon: <House size={22} strokeWidth={1.6} aria-hidden /> },
    { id: 'appointments', to: ROUTES.appointments, label: t.nav.appointments, icon: <CalendarDays size={22} strokeWidth={1.6} aria-hidden /> },
    { id: 'wellness', to: ROUTES.wellness, label: t.nav.wellness, icon: <WellnessIcon size={23} /> },
    { id: 'profile', to: ROUTES.profile, label: t.nav.profile, icon: <UserRound size={22} strokeWidth={1.6} aria-hidden /> },
  ];

  return (
    <nav className="bottom-nav" aria-label={t.nav.ariaLabel}>
      <ul className="bottom-nav__list">
        {items.map((item) => {
          const isActive = item.id === active;
          return (
            <li key={item.id}>
              <Link to={item.to} className={`bottom-nav__item ${isActive ? 'is-active' : ''}`} aria-current={isActive ? 'page' : undefined}>
                <span className="bottom-nav__icon">{item.icon}</span>
                <span className="bottom-nav__label">{item.label}</span>
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
