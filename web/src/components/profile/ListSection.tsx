import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { ForwardChevron } from '../ui';

export interface ListRowItem {
  key: string;
  label: string;
  icon: ReactNode;
  /** Navigate to a route… */
  to?: string;
  /** …or run an in-page action. */
  onClick?: () => void;
  /** Custom trailing content instead of the chevron (e.g. language switch). */
  trailing?: ReactNode;
}

/** Titled list card ("التقارير والمستندات", "أخرى") with icon squares and chevrons. */
export function ListSection({ title, items }: { title: string; items: ListRowItem[] }) {
  return (
    <section className="profile-section">
      <h2 className="section-heading__title section-heading__title--standalone">{title}</h2>
      <ul className="list-card">
        {items.map((item) => (
          <li key={item.key}>
            {item.trailing ? (
              <div className="list-row list-row--static">
                <span className="list-row__icon">{item.icon}</span>
                <span className="list-row__label">{item.label}</span>
                <span className="list-row__trailing">{item.trailing}</span>
              </div>
            ) : item.to ? (
              <Link to={item.to} className="list-row">
                <span className="list-row__icon">{item.icon}</span>
                <span className="list-row__label">{item.label}</span>
                <ForwardChevron size={20} className="list-row__chev" />
              </Link>
            ) : (
              <button type="button" className="list-row" onClick={item.onClick}>
                <span className="list-row__icon">{item.icon}</span>
                <span className="list-row__label">{item.label}</span>
                <ForwardChevron size={20} className="list-row__chev" />
              </button>
            )}
          </li>
        ))}
      </ul>
    </section>
  );
}
