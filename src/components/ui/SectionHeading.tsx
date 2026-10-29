import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { ForwardArrow } from './icons';

interface SectionHeadingProps {
  title: string;
  /** Optional trailing action, e.g. "عرض الكل". Provide `to` for navigation or `onClick` for in-page actions. */
  action?: { label: string; to?: string; onClick?: () => void; icon?: ReactNode; expanded?: boolean };
  level?: 2 | 3;
}

export function SectionHeading({ title, action, level = 2 }: SectionHeadingProps) {
  const Tag = level === 2 ? 'h2' : 'h3';
  const icon = action?.icon ?? <ForwardArrow size={16} />;
  return (
    <div className="section-heading">
      <Tag className="section-heading__title">{title}</Tag>
      {action &&
        (action.to ? (
          <Link className="section-heading__action" to={action.to}>
            <span>{action.label}</span>
            {icon}
          </Link>
        ) : (
          <button type="button" className="section-heading__action" onClick={action.onClick} aria-expanded={action.expanded}>
            <span>{action.label}</span>
            {icon}
          </button>
        ))}
    </div>
  );
}
