import { Building2, Clock3, MapPin, UserRound } from 'lucide-react';
import { useLanguage } from '../../i18n';
import { useAppState } from '../../state/AppState';
import type { Appointment } from '../../types';
import { ForwardChevron } from '../ui';

/** Appointment card matching the reference: clinic header row, then patient / location / time rows. */
export function AppointmentCard({ appointment, onOpen }: { appointment: Appointment; onOpen: () => void }) {
  const { t, l, formatDateTime } = useLanguage();
  const { activeProfile } = useAppState();
  return (
    <button type="button" className="appt-card" onClick={onOpen}>
      <span className="appt-card__head">
        <span className="appt-card__clinic-icon"><Building2 size={22} strokeWidth={1.6} aria-hidden /></span>
        <span className="appt-card__clinic">
          <strong>{l(appointment.clinic)}</strong>
          <small>{appointment.visitType === 'inPerson' ? t.appointments.inPerson : t.appointments.virtual}</small>
        </span>
        <ForwardChevron size={20} className="appt-card__chev" />
      </span>
      <span className="appt-card__rows">
        <span className="appt-card__row appt-card__row--muted"><UserRound size={17} aria-hidden />{l(activeProfile.name)}</span>
        <span className="appt-card__row appt-card__row--link"><MapPin size={17} aria-hidden />{l(appointment.facility)}</span>
        <span className="appt-card__row appt-card__row--muted"><Clock3 size={17} aria-hidden /><bdi>{formatDateTime(appointment.dateTime)}</bdi></span>
      </span>
    </button>
  );
}
