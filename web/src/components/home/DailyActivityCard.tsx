import { useState } from 'react';
import { Flame, Footprints, MapPin, Timer } from 'lucide-react';
import { format, useLanguage } from '../../i18n';
import { useAppState } from '../../state/AppState';
import { dailyActivity } from '../../data/mockData';
import { serviceRoute, type TabId } from '../../routes';
import { Button, Dialog, SectionHeading } from '../ui';

/** "نشاطك اليومي" card — steps, target and the three metric chips. Used on Home and Wellness. */
export function DailyActivityCard({ tab }: { tab: TabId }) {
  const { t, formatNumber } = useLanguage();
  const { stepTarget, setStepTarget, showToast } = useAppState();
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(String(stepTarget));
  const [error, setError] = useState<string | null>(null);

  const remaining = Math.max(0, stepTarget - dailyActivity.steps);

  const save = () => {
    const n = Number(draft);
    if (!Number.isInteger(n) || n < 1000 || n > 50000) {
      setError(t.home.targetInvalid);
      return;
    }
    setStepTarget(n);
    setEditing(false);
    showToast(t.home.targetSaved);
  };

  return (
    <section className="card card--outlined">
      <SectionHeading title={t.home.dailyActivity} action={{ label: t.common.viewMore, to: serviceRoute(tab, 'dailyActivity') }} />
      <div className="activity">
        <div className="activity__main">
          <span className="activity__icon"><Footprints size={22} aria-hidden /></span>
          <div className="activity__steps">
            <strong>{format(t.home.steps, { n: dailyActivity.steps })}</strong>
            <span>{format(t.home.stepsToGoal, { n: remaining })}</span>
          </div>
          <button
            type="button"
            className="text-link"
            onClick={() => {
              setDraft(String(stepTarget));
              setError(null);
              setEditing(true);
            }}
          >
            {t.home.updateTarget}
          </button>
        </div>
        <ul className="activity__metrics">
          <li className="metric metric--orange">
            <span className="metric__icon"><Timer size={16} aria-hidden /></span>
            <span className="metric__text"><span>{t.home.duration}</span><b>{format(t.home.minutesValue, { n: dailyActivity.durationMinutes })}</b></span>
          </li>
          <li className="metric metric--green">
            <span className="metric__icon"><MapPin size={16} aria-hidden /></span>
            <span className="metric__text"><span>{t.home.distance}</span><b>{format(t.home.kmValue, { n: formatNumber(dailyActivity.distanceKm) })}</b></span>
          </li>
          <li className="metric metric--red">
            <span className="metric__icon"><Flame size={16} aria-hidden /></span>
            <span className="metric__text"><span>{t.home.calories}</span><b>{format(t.home.kcalValue, { n: dailyActivity.calories })}</b></span>
          </li>
        </ul>
      </div>

      <Dialog
        open={editing}
        onClose={() => setEditing(false)}
        title={t.home.targetDialogTitle}
        actions={
          <>
            <Button variant="secondary" onClick={() => setEditing(false)}>{t.common.cancel}</Button>
            <Button onClick={save}>{t.home.save}</Button>
          </>
        }
      >
        <form
          noValidate
          onSubmit={(e) => {
            e.preventDefault();
            save();
          }}
        >
          <label className="field">
            <span className="field__label">{t.home.targetLabel}</span>
            <input
              className={`field__control ${error ? 'has-error' : ''}`}
              type="number"
              inputMode="numeric"
              min={1000}
              max={50000}
              step={500}
              value={draft}
              onChange={(e) => {
                setDraft(e.target.value);
                setError(null);
              }}
              aria-invalid={!!error}
              aria-describedby={error ? 'target-error' : undefined}
            />
            {error && <span className="field__error" id="target-error" role="alert">{error}</span>}
          </label>
        </form>
      </Dialog>
    </section>
  );
}
