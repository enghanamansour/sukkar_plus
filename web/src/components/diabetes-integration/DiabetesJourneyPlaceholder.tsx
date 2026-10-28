import { useLanguage } from '../../i18n';
import { BackArrow, Button, GlucoseIcon } from '../ui';

/**
 * Shown while no diabetes-care frontend is mounted.
 * REPLACE by configuring `mount.ts` — do not build feature logic here.
 */
export function DiabetesJourneyPlaceholder({ onExit }: { onExit: () => void }) {
  const { t } = useLanguage();
  return (
    <div className="dj-placeholder" data-testid="diabetes-journey-placeholder">
      <span className="dj-placeholder__badge">{t.diabetes.placeholderBadge}</span>
      <span className="dj-placeholder__icon"><GlucoseIcon size={40} strokeWidth={1.5} /></span>
      <h2 className="dj-placeholder__title">{t.diabetes.title}</h2>
      <p className="dj-placeholder__lead">{t.diabetes.description}</p>
      <p className="dj-placeholder__body">{t.diabetes.placeholderBody}</p>
      <Button variant="secondary" icon={<BackArrow size={18} />} onClick={onExit}>
        {t.diabetes.backToProfile}
      </Button>
    </div>
  );
}
