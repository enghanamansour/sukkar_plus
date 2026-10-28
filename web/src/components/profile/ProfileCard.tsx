import { useState } from 'react';
import { format, useLanguage } from '../../i18n';
import { useAppState } from '../../state/AppState';
import { Button, Dialog, ForwardChevron } from '../ui';

/** Patient information card: avatar initial, name, Health ID and "تفاصيل". */
export function ProfileCard() {
  const { t, l, formatDate } = useLanguage();
  const { activeProfile: p } = useAppState();
  const [open, setOpen] = useState(false);

  return (
    <section className="profile-card" aria-label={t.profile.detailsTitle}>
      <span className="profile-card__avatar" aria-hidden>{l(p.initial)}</span>
      <div className="profile-card__info">
        <p className="profile-card__name">{l(p.name)}</p>
        <p className="profile-card__id">{format(t.profile.healthId, { id: p.healthId })}</p>
      </div>
      <button type="button" className="profile-card__details" onClick={() => setOpen(true)}>
        {t.common.details}
        <ForwardChevron size={14} />
      </button>

      <Dialog open={open} onClose={() => setOpen(false)} title={t.profile.detailsTitle} actions={<Button block onClick={() => setOpen(false)}>{t.common.ok}</Button>}>
        <dl className="detail-list">
          <div><dt>{t.profile.name}</dt><dd>{l(p.name)}</dd></div>
          <div><dt>{t.profile.healthIdLabel}</dt><dd><bdi>{p.healthId}</bdi></dd></div>
          <div><dt>{t.profile.dob}</dt><dd>{formatDate(p.dateOfBirth)}</dd></div>
          <div><dt>{t.profile.gender}</dt><dd>{l(p.gender)}</dd></div>
          <div><dt>{t.profile.bloodType}</dt><dd><bdi>{p.bloodType}</bdi></dd></div>
          <div><dt>{t.profile.nationality}</dt><dd>{l(p.nationality)}</dd></div>
        </dl>
        <p className="form__note">{t.app.mockupNotice}</p>
      </Dialog>
    </section>
  );
}
