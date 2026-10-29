import type { ReactNode } from 'react';
import { ChevronDown } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { useLanguage } from '../../i18n';
import { BackArrow } from '../ui';

interface PageHeaderProps {
  title: string;
  /** If provided, the title gets the reference's "⌄" affordance and becomes a button. */
  onTitleClick?: () => void;
  titleExpanded?: boolean;
  titleButtonLabel?: string;
  /** Content aligned to the end side (e.g. "مشاركة"). */
  end?: ReactNode;
}

/** Large blue screen title used by مواعيدي / جودة الحياة / ملفي. */
export function PageHeader({ title, onTitleClick, titleExpanded, titleButtonLabel, end }: PageHeaderProps) {
  return (
    <header className="page-header">
      {onTitleClick ? (
        <h1 className="page-header__title">
          <button type="button" className="page-header__title-btn" onClick={onTitleClick} aria-haspopup="dialog" aria-expanded={titleExpanded} aria-label={titleButtonLabel ? `${title} — ${titleButtonLabel}` : undefined}>
            <span>{title}</span>
            <ChevronDown size={22} strokeWidth={2.4} aria-hidden />
          </button>
        </h1>
      ) : (
        <h1 className="page-header__title">{title}</h1>
      )}
      {end && <div className="page-header__end">{end}</div>}
    </header>
  );
}

interface BackHeaderProps {
  title: string;
  /** Where "back" goes. Defaults to browser history. */
  backTo?: string;
  backLabel?: string;
  end?: ReactNode;
}

/** Compact header for sub-screens: back button + title. */
export function BackHeader({ title, backTo, backLabel, end }: BackHeaderProps) {
  const navigate = useNavigate();
  const { t } = useLanguage();
  return (
    <header className="back-header">
      <button
        type="button"
        className="icon-btn"
        onClick={() => (backTo ? navigate(backTo) : navigate(-1))}
        aria-label={backLabel ?? t.common.back}
      >
        <BackArrow size={22} />
      </button>
      <h1 className="back-header__title">{title}</h1>
      <div className="back-header__end">{end}</div>
    </header>
  );
}
