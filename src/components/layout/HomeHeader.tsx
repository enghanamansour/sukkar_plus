import { useId, useMemo, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Search } from 'lucide-react';
import { format, useLanguage } from '../../i18n';
import { useAppState } from '../../state/AppState';
import { greetingName } from '../../data/mockData';
import { ROUTES, serviceRoute } from '../../routes';
import { searchableServices } from '../health-services/services';
import { Button, Dialog, SehhatyLogo, ForwardChevron } from '../ui';
import { MenuDrawer } from './MenuDrawer';
import clusterEmblemUrl from '../../assets/cluster-emblem.png';

/** Navy home header with greeting, quick actions, language switch and service search. */
export function HomeHeader() {
  const { t, l } = useLanguage();
  const { unreadCount } = useAppState();
  const [menuOpen, setMenuOpen] = useState(false);
  const [supportOpen, setSupportOpen] = useState(false);

  return (
    <header className="home-header">
      <Skyline />
      <div className="home-header__top">
        <div className="home-header__actions">
          <button type="button" className="icon-btn icon-btn--on-dark home-header__icon" aria-label={t.header.menu} onClick={() => setMenuOpen(true)}>
            <HeaderMenuIcon />
          </button>
          <Link
            to={ROUTES.notifications}
            className="icon-btn icon-btn--on-dark home-header__icon"
            aria-label={unreadCount ? `${t.header.notifications} — ${format(t.header.unreadNotifications, { count: unreadCount })}` : t.header.notifications}
          >
            <HeaderBellIcon />
            {unreadCount > 0 && <span className="notif-dot" aria-hidden />}
          </Link>
          <button type="button" className="icon-btn icon-btn--on-dark home-header__icon" aria-label={t.header.support} onClick={() => setSupportOpen(true)}>
            <HeaderHeadphonesIcon />
          </button>
        </div>
        <img src={clusterEmblemUrl} alt={t.app.clusterEmblemAlt} width={44} height={42} className="home-header__emblem" draggable={false} />
        <SehhatyLogo size={50} className="home-header__logo" />
      </div>

      <div className="home-header__greeting">
        <p className="home-header__hello">{format(t.header.greeting, { name: l(greetingName) })}</p>
        <p className="home-header__sub">{t.header.clusterCares}</p>
      </div>

      <ServiceSearch />

      <MenuDrawer open={menuOpen} onClose={() => setMenuOpen(false)} />
      <Dialog
        open={supportOpen}
        onClose={() => setSupportOpen(false)}
        title={t.header.support}
        actions={<Button block onClick={() => setSupportOpen(false)}>{t.common.ok}</Button>}
      >
        <p>{t.home.supportDialogBody}</p>
      </Dialog>
    </header>
  );
}

function ServiceSearch() {
  const { t } = useLanguage();
  const navigate = useNavigate();
  const [query, setQuery] = useState('');
  const listId = useId();

  const results = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return [];
    return searchableServices
      .map((s) => ({ ...s, title: t.services[s.id].title }))
      .filter((s) => s.title.toLowerCase().includes(q))
      .slice(0, 6);
  }, [query, t]);

  const showResults = query.trim().length > 0;

  return (
    <form
      className="search"
      role="search"
      onSubmit={(e) => {
        e.preventDefault();
        if (results[0]) navigate(serviceRoute(results[0].tab, results[0].id));
      }}
    >
      <label className="visually-hidden" htmlFor={`${listId}-input`}>{t.header.searchLabel}</label>
      <input
        id={`${listId}-input`}
        className="search__input"
        type="search"
        placeholder={t.header.searchPlaceholder}
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        aria-controls={showResults ? listId : undefined}
        autoComplete="off"
      />
      <button type="submit" className="search__btn" aria-label={t.header.searchLabel}>
        <Search size={18} strokeWidth={2} aria-hidden />
      </button>
      {showResults && (
        <ul className="search__results" id={listId}>
          {results.length === 0 ? (
            <li className="search__empty">{t.header.searchNoResults}</li>
          ) : (
            results.map((r) => (
              <li key={r.id}>
                <Link to={serviceRoute(r.tab, r.id)} className="search__result">
                  <span>{r.title}</span>
                  <ForwardChevron size={16} />
                </Link>
              </li>
            ))
          )}
        </ul>
      )}
    </form>
  );
}

/* Header glyphs drawn to match the reference app's icon style (thin, rounded, white). */
function HeaderMenuIcon() {
  // Three lines, the middle one shorter and aligned to the reading start (right in Arabic).
  return (
    <svg width="22" height="19" viewBox="0 0 22 19" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" aria-hidden className="flip-rtl">
      <path d="M1 1.5h20M1 9.5h13M1 17.5h20" />
    </svg>
  );
}

function HeaderBellIcon() {
  return (
    <svg width="19" height="21" viewBox="0 0 19 21" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" aria-hidden>
      <path d="M9.5 2.2c-3 0-5.2 2.4-5.2 5.4v3.2c0 1.6-.7 3-1.9 4-.5.4-.2 1.2.4 1.2h13.4c.6 0 .9-.8.4-1.2-1.2-1-1.9-2.4-1.9-4V7.6c0-3-2.2-5.4-5.2-5.4Z" />
      <path d="M7 16.2a2.5 2.5 0 0 0 5 0" />
    </svg>
  );
}

function HeaderHeadphonesIcon() {
  return (
    <svg width="19" height="16" viewBox="0 0 19 16" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" aria-hidden>
      <path d="M2.3 10.5V9a7.2 7.2 0 0 1 14.4 0v1.5" />
      <rect x="1.2" y="9.2" width="3.8" height="5.8" rx="1.9" />
      <rect x="14" y="9.2" width="3.8" height="5.8" rx="1.9" />
    </svg>
  );
}

/** Faint skyline line-art behind the greeting (decorative, original drawing). */
function Skyline() {
  return (
    <svg className="home-header__skyline" viewBox="0 0 400 140" preserveAspectRatio="xMidYMax slice" aria-hidden focusable="false">
      <g fill="none" stroke="currentColor" strokeWidth="1">
        <path d="M0 140V112h18V96h14v16h10V84h22v56" />
        <path d="M70 140V70l12-14 12 14v70M82 56V40" />
        <path d="M104 140V92h26v48M112 92V80h10v12" />
        <path d="M140 140V60h30v80M147 60V48h16v12M155 48V30" />
        <path d="M180 140V100c0-14 22-14 22 0v40" />
        <path d="M214 140V40l16-20 16 20v100M230 20V6M222 60h16M222 80h16M222 100h16" />
        <path d="M258 140V88h34v52M266 88V74h18v14" />
        <path d="M302 140V66h20v74M312 66V52" />
        <path d="M332 140v-30h28v30M340 110V96h12v14" />
        <path d="M368 140V82h32" />
      </g>
    </svg>
  );
}
