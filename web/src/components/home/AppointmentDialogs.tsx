import { useState } from 'react';
import { useLanguage } from '../../i18n';
import { useAppState } from '../../state/AppState';
import { clinicOptions, facilityName, timeSlots } from '../../data/mockData';
import type { Appointment, VisitType } from '../../types';
import { Button, Dialog } from '../ui';

/** Read-only appointment details with a demo "cancel" flow (removes it from in-memory state only). */
export function AppointmentDetailsDialog({ appointment, onClose }: { appointment: Appointment | null; onClose: () => void }) {
  const { t, l, formatDateTime } = useLanguage();
  const { activeProfile, cancelAppointment, showToast } = useAppState();
  const [confirming, setConfirming] = useState(false);

  const close = () => {
    setConfirming(false);
    onClose();
  };

  if (!appointment) return null;
  const canCancel = appointment.status === 'upcoming';

  return (
    <>
      <Dialog
        open={!confirming}
        onClose={close}
        title={t.appointments.detailsTitle}
        actions={
          canCancel ? (
            <Button variant="danger" block onClick={() => setConfirming(true)}>{t.appointments.cancelAppointment}</Button>
          ) : (
            <Button block onClick={close}>{t.common.ok}</Button>
          )
        }
      >
        <dl className="detail-list">
          <div><dt>{t.appointments.clinic}</dt><dd>{l(appointment.clinic)}</dd></div>
          <div><dt>{t.appointments.visitType}</dt><dd>{appointment.visitType === 'inPerson' ? t.appointments.inPerson : t.appointments.virtual}</dd></div>
          <div><dt>{t.appointments.patient}</dt><dd>{l(activeProfile.name)}</dd></div>
          <div><dt>{t.appointments.location}</dt><dd>{l(appointment.facility)}</dd></div>
          <div><dt>{t.appointments.dateTime}</dt><dd><bdi>{formatDateTime(appointment.dateTime)}</bdi></dd></div>
        </dl>
      </Dialog>
      <Dialog
        open={confirming}
        onClose={() => setConfirming(false)}
        title={t.appointments.cancelConfirmTitle}
        actions={
          <>
            <Button variant="secondary" onClick={() => setConfirming(false)}>{t.common.cancel}</Button>
            <Button
              variant="danger"
              onClick={() => {
                cancelAppointment(appointment.id);
                showToast(t.appointments.cancelled);
                close();
              }}
            >
              {t.common.confirm}
            </Button>
          </>
        }
      >
        <p>{t.appointments.cancelConfirmBody}</p>
      </Dialog>
    </>
  );
}

interface FormErrors {
  clinic?: string;
  date?: string;
  time?: string;
}

const todayISO = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};

/** Demo booking form with translated validation. Adds to in-memory state only. */
export function BookAppointmentDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { t, l } = useLanguage();
  const { addAppointment, showToast } = useAppState();
  const [clinic, setClinic] = useState('');
  const [date, setDate] = useState('');
  const [time, setTime] = useState('');
  const [visitType, setVisitType] = useState<VisitType>('inPerson');
  const [errors, setErrors] = useState<FormErrors>({});

  const reset = () => {
    setClinic('');
    setDate('');
    setTime('');
    setVisitType('inPerson');
    setErrors({});
  };

  const close = () => {
    reset();
    onClose();
  };

  const submit = () => {
    const v = t.appointments.validation;
    const next: FormErrors = {};
    if (!clinic) next.clinic = v.clinicRequired;
    if (!date) next.date = v.dateRequired;
    else if (date < todayISO()) next.date = v.datePast;
    if (!time) next.time = v.timeRequired;
    setErrors(next);
    if (Object.keys(next).length) return;

    const option = clinicOptions.find((c) => c.id === clinic)!;
    addAppointment({ clinic: option.name, visitType, facility: facilityName, dateTime: `${date}T${time}:00` });
    showToast(t.appointments.booked);
    close();
  };

  return (
    <Dialog
      open={open}
      onClose={close}
      title={t.appointments.bookTitle}
      actions={<Button block size="lg" type="submit" form="book-form">{t.appointments.submit}</Button>}
    >
      <form
        id="book-form"
        className="form"
        noValidate
        onSubmit={(e) => {
          e.preventDefault();
          submit();
        }}
      >
        <label className="field">
          <span className="field__label">{t.appointments.clinic}</span>
          <select
            className={`field__control ${errors.clinic ? 'has-error' : ''}`}
            value={clinic}
            onChange={(e) => {
              setClinic(e.target.value);
              setErrors((x) => ({ ...x, clinic: undefined }));
            }}
            aria-invalid={!!errors.clinic}
            aria-describedby={errors.clinic ? 'err-clinic' : undefined}
          >
            <option value="">{t.appointments.clinicPlaceholder}</option>
            {clinicOptions.map((c) => (
              <option key={c.id} value={c.id}>{l(c.name)}</option>
            ))}
          </select>
          {errors.clinic && <span id="err-clinic" className="field__error" role="alert">{errors.clinic}</span>}
        </label>

        <fieldset className="field">
          <legend className="field__label">{t.appointments.visitType}</legend>
          <div className="segmented segmented--small" role="radiogroup">
            {(['inPerson', 'virtual'] as const).map((vt) => (
              <button
                key={vt}
                type="button"
                role="radio"
                aria-checked={visitType === vt}
                className={`segmented__option ${visitType === vt ? 'is-active' : ''}`}
                onClick={() => setVisitType(vt)}
              >
                {vt === 'inPerson' ? t.appointments.inPerson : t.appointments.virtual}
              </button>
            ))}
          </div>
        </fieldset>

        <div className="form__row">
          <label className="field">
            <span className="field__label">{t.appointments.date}</span>
            <input
              className={`field__control ${errors.date ? 'has-error' : ''}`}
              type="date"
              min={todayISO()}
              value={date}
              onChange={(e) => {
                setDate(e.target.value);
                setErrors((x) => ({ ...x, date: undefined }));
              }}
              aria-invalid={!!errors.date}
              aria-describedby={errors.date ? 'err-date' : undefined}
            />
            {errors.date && <span id="err-date" className="field__error" role="alert">{errors.date}</span>}
          </label>
          <label className="field">
            <span className="field__label">{t.appointments.time}</span>
            <select
              className={`field__control ${errors.time ? 'has-error' : ''}`}
              value={time}
              onChange={(e) => {
                setTime(e.target.value);
                setErrors((x) => ({ ...x, time: undefined }));
              }}
              aria-invalid={!!errors.time}
              aria-describedby={errors.time ? 'err-time' : undefined}
            >
              <option value="">{t.appointments.timePlaceholder}</option>
              {timeSlots.map((s) => (
                <option key={s} value={s}>{s}</option>
              ))}
            </select>
            {errors.time && <span id="err-time" className="field__error" role="alert">{errors.time}</span>}
          </label>
        </div>
        <p className="form__note">{t.appointments.bookingNote}</p>
      </form>
    </Dialog>
  );
}
