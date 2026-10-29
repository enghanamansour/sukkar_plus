import { ArrowLeft, ArrowRight, ChevronLeft, ChevronRight, type LucideProps } from 'lucide-react';

/**
 * Direction-aware icons. Each icon is drawn for LTR and mirrored in RTL
 * via the `.flip-rtl` class (see ui.css), so callers never branch on language.
 */
export const ForwardArrow = (p: LucideProps) => <ArrowRight {...p} className={`flip-rtl ${p.className ?? ''}`} aria-hidden />;
export const BackArrow = (p: LucideProps) => <ArrowLeft {...p} className={`flip-rtl ${p.className ?? ''}`} aria-hidden />;
export const ForwardChevron = (p: LucideProps) => <ChevronRight {...p} className={`flip-rtl ${p.className ?? ''}`} aria-hidden />;
export const BackChevron = (p: LucideProps) => <ChevronLeft {...p} className={`flip-rtl ${p.className ?? ''}`} aria-hidden />;

/** Lotus-style icon used for the Wellness (جودة الحياة) tab, matching the reference. */
export function WellnessIcon({ size = 24, strokeWidth = 1.6 }: { size?: number; strokeWidth?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M12 4c1.8 1.6 2.6 3.6 2.6 5.6S13.8 13.4 12 15c-1.8-1.6-2.6-3.4-2.6-5.4S10.2 5.6 12 4Z" />
      <path d="M9.6 8.2C7.6 7.6 5.6 7.9 4 8.9c.5 2.4 2 4.3 4.2 5.2 1.3.6 2.6.9 3.8.9" />
      <path d="M14.4 8.2c2-.6 4-.3 5.6.7-.5 2.4-2 4.3-4.2 5.2-1.3.6-2.6.9-3.8.9" />
      <path d="M4 17.5c2.5-.6 5-.4 8 1.5 3-1.9 5.5-2.1 8-1.5" />
      <path d="M6 20.5c2-.4 4 0 6 1 2-1 4-1.4 6-1" />
    </svg>
  );
}

/** Glucose-meter icon for the "Adheed" service. */
export function GlucoseIcon({ size = 22, strokeWidth = 1.7 }: { size?: number; strokeWidth?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <rect x="4" y="3" width="11" height="18" rx="2.5" />
      <rect x="6.5" y="6" width="6" height="4.5" rx="1" />
      <path d="M8 14h3M8 17h3" />
      <path d="M19 9.5c1.1 1.4 1.7 2.5 1.7 3.4a1.7 1.7 0 0 1-3.4 0c0-.9.6-2 1.7-3.4Z" />
    </svg>
  );
}
