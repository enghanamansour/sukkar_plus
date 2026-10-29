import { useState } from 'react';
import { BellOff, CalendarDays, FlaskConical, Megaphone, Pill } from 'lucide-react';
import type { ReactNode } from 'react';
import { useLanguage } from '../i18n';
import { useAppState } from '../state/AppState';
import { ROUTES } from '../routes';
import { BackHeader } from '../components/layout/PageHeader';
import { EmptyState, SegmentedControl } from '../components/ui';
import type { NotificationItem } from '../types';

const kindIcon: Record<NotificationItem['kind'], ReactNode> = {
  appointment: <CalendarDays size={20} aria-hidden />,
  prescription: <Pill size={20} aria-hidden />,
  result: <FlaskConical size={20} aria-hidden />,
  general: <Megaphone size={20} aria-hidden />,
};

export function NotificationsPage() {
  const { t, l, formatDate } = useLanguage();
  const { notifications, markAllRead, markRead, unreadCount } = useAppState();
  const [filter, setFilter] = useState<'all' | 'unread'>('all');
  const list = filter === 'all' ? notifications : notifications.filter((n) => !n.read);

  return (
    <div className="page">
      <BackHeader
        title={t.notifications.title}
        backTo={ROUTES.home}
        end={
          <button type="button" className="header-link" onClick={markAllRead} disabled={unreadCount === 0}>
            {t.notifications.markAllRead}
          </button>
        }
      />
      <div className="page__body">
        <SegmentedControl
          label={t.notifications.filterLabel}
          value={filter}
          onChange={setFilter}
          options={[
            { value: 'all', label: t.notifications.all },
            { value: 'unread', label: `${t.notifications.unread}${unreadCount ? ` (${unreadCount})` : ''}` },
          ]}
        />
        {list.length === 0 ? (
          <EmptyState
            icon={<BellOff size={26} aria-hidden />}
            title={filter === 'unread' ? t.notifications.emptyTitle : t.notifications.emptyAllTitle}
            body={t.notifications.emptyBody}
          />
        ) : (
          <ul className="notif-list" role="tabpanel">
            {list.map((n) => (
              <li key={n.id}>
                <button type="button" className={`notif ${n.read ? '' : 'is-unread'}`} onClick={() => markRead(n.id)}>
                  <span className="notif__icon">{kindIcon[n.kind]}</span>
                  <span className="notif__text">
                    <span className="notif__title">
                      {l(n.title)}
                      {!n.read && <span className="notif__dot"><span className="visually-hidden">{t.notifications.unreadDot}</span></span>}
                    </span>
                    <span className="notif__body">{l(n.body)}</span>
                    <time className="notif__time" dateTime={n.createdAt}>{formatDate(n.createdAt)}</time>
                  </span>
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
