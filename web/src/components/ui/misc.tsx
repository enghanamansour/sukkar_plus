import type { ReactNode } from 'react';
import logoUrl from '../../assets/sehhaty-logo.png';
import { useLanguage } from '../../i18n';
import { useAppState } from '../../state/AppState';

/** Intrinsic aspect ratio of `sehhaty-logo.png` (300 × 262) — keeps the mark from stretching. */
const LOGO_ASPECT = 262 / 300;

/** Sehhaty check-mark logo (clean transparent PNG matted from the supplied official artwork). */
export function SehhatyLogo({ size = 44, className }: { size?: number; className?: string }) {
  const { t } = useLanguage();
  return (
    <img
      src={logoUrl}
      alt={t.app.logoAlt}
      width={size}
      height={Math.round(size * LOGO_ASPECT)}
      className={`sehhaty-logo ${className ?? ''}`}
      decoding="async"
      draggable={false}
    />
  );;
}

/** White content card with the subtle border used throughout the reference. */
export function Card({ children, className, as: Tag = 'section' }: { children: ReactNode; className?: string; as?: 'section' | 'div' | 'article' }) {
  return <Tag className={`card ${className ?? ''}`}>{children}</Tag>;
}

/** Small label that marks placeholder / demo content so it is never mistaken for a real integration. */
export function DemoBadge({ children }: { children?: ReactNode }) {
  const { t } = useLanguage();
  return <span className="demo-badge">{children ?? t.common.demoBadge}</span>;
}

/** Global toast — announced politely to screen readers. */
export function Toast() {
  const { toast } = useAppState();
  return (
    <div className="toast-region" aria-live="polite">
      {toast && <div className="toast">{toast}</div>}
    </div>
  );
}
