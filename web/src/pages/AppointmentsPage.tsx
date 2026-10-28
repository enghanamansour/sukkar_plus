import { useState } from 'react';
import { CalendarX2, Check } from 'lucide-react';
import { useLanguage } from '../i18n';
import { useAppState } from '../state/AppState';
import { PageHeader } from '../components/layout/PageHeader';
import { AppointmentCard } from '../components/home/AppointmentCard';
import { AppointmentDetailsDialog, BookAppointmentDialog } from '../components/home/AppointmentDialogs';
import { Button, Dialog, EmptyState, SegmentedControl } from '../components/ui';
import type { Appointment, AppointmentStatus } from '../types';

type Owner = 'mine' | 'dependents';

export function AppointmentsPage() {
  const { t } = useLanguage();
  const { appointments } = useAppState();
  const [tab, setTab] = useState<AppointmentStatus>('upcoming');
  const [owner, setOwner] = useState<Owner>('mine');
  const [ownerPicker, setOwnerPicker] = useState(false);
  const [booking, setBooking] = useState(false);
  const [selected, setSelected] = useState<Appointment | null>(null);

  // Dependents have no synthetic appointments — demonstrates the empty state.
  const list = owner === 'mine' ? appointments.filter((a) => a.status === tab) : [];

  const empty =
    owner === 'dependents'
      ? { title: t.appointments.emptyDependentsTitle, body: t.appointments.emptyDependentsBody }
      : tab === 'upcoming'
        ? { title: t.appointments.emptyUpcomingTitle, body: t.appointments.emptyUpcomingBody }
        : { title: t.appointments.emptyPreviousTitle, body: t.appointments.emptyPreviousBody };

  return (
    <div className="page">
      <PageHeader
        title={owner === 'mine' ? t.appointments.title : t.appointments.dependents}
        onTitleClick={() => setOwnerPicker(true)}
        titleExpanded={ownerPicker}
        titleButtonLabel={t.appointments.viewSwitcherLabel}
      />
      <div className="page__body page__body--with-footer">
        <SegmentedControl
          label={t.appointments.tabsLabel}
          value={tab}
          onChange={setTab}
          options={[
            { value: 'upcoming', label: t.appointments.upcoming },
            { value: 'previous', label: t.appointments.previous },
          ]}
        />
        <div role="tabpanel" className="stack">
          {list.length ? (
            list.map((a) => <AppointmentCard key={a.id} appointment={a} onOpen={() => setSelected(a)} />)
          ) : (
            <EmptyState icon={<CalendarX2 size={26} aria-hidden />} title={empty.title} body={empty.body} />
          )}
        </div>
      </div>
      <div className="page__footer">
        <Button block size="lg" onClick={() => setBooking(true)}>{t.home.bookNew}</Button>
      </div>

      <Dialog open={ownerPicker} onClose={() => setOwnerPicker(false)} title={t.appointments.viewSwitcherLabel}>
        <ul className="choice-list">
          {(['mine', 'dependents'] as const).map((o) => (
            <li key={o}>
              <button
                type="button"
                className={`choice ${owner === o ? 'is-active' : ''}`}
                aria-pressed={owner === o}
                onClick={() => {
                  setOwner(o);
                  setOwnerPicker(false);
                }}
              >
                <span>{o === 'mine' ? t.appointments.mine : t.appointments.dependents}</span>
                {owner === o && <Check size={18} aria-hidden />}
              </button>
            </li>
          ))}
        </ul>
      </Dialog>
      <BookAppointmentDialog open={booking} onClose={() => setBooking(false)} />
      <AppointmentDetailsDialog appointment={selected} onClose={() => setSelected(null)} />
    </div>
  );
}
