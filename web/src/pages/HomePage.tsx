import { useState } from 'react';
import { Link } from 'react-router-dom';
import { FileCheck2, FlaskConical, Pill, Siren, Sparkles } from 'lucide-react';
import type { ReactNode } from 'react';
import { useLanguage } from '../i18n';
import { useAppState } from '../state/AppState';
import { ROUTES, serviceRoute } from '../routes';
import { HomeHeader } from '../components/layout/HomeHeader';
import { BannerCarousel } from '../components/home/BannerCarousel';
import { DailyActivityCard } from '../components/home/DailyActivityCard';
import { AppointmentCard } from '../components/home/AppointmentCard';
import { AppointmentDetailsDialog, BookAppointmentDialog } from '../components/home/AppointmentDialogs';
import { Button, Dialog, EmptyState, ForwardArrow, SectionHeading } from '../components/ui';
import type { Appointment } from '../types';
import type { ServiceId } from '../components/health-services/services';

export function HomePage() {
  const { t } = useLanguage();
  const { appointments } = useAppState();
  const [booking, setBooking] = useState(false);
  const [selected, setSelected] = useState<Appointment | null>(null);
  const [emergencyOpen, setEmergencyOpen] = useState(false);
  const next = appointments.find((a) => a.status === 'upcoming');

  const updates: { id: ServiceId; icon: ReactNode }[] = [
    { id: 'prescriptions', icon: <Pill size={20} aria-hidden /> },
    { id: 'testResults', icon: <FlaskConical size={20} aria-hidden /> },
    { id: 'insurance', icon: <FileCheck2 size={20} aria-hidden /> },
  ];

  return (
    <div className="home">
      <HomeHeader />
      <div className="home-sheet">
        <BannerCarousel />

        <section className="card card--outlined">
          <SectionHeading title={t.home.clusterCardTitle} action={{ label: t.home.viewTasks, to: serviceRoute('home', 'clusterTasks') }} />
          <div className="inner-card">
            <p className="inner-card__title">{t.home.digitalTwinTitle}</p>
            <p className="inner-card__body">{t.home.digitalTwinBody}</p>
            <Link className="text-cta" to={serviceRoute('profile', 'digitalTwin')}>
              {t.common.startNow}
              <ForwardArrow size={16} />
            </Link>
          </div>
        </section>

        <DailyActivityCard tab="home" />

        <Link to={serviceRoute('home', 'discover')} className="promo-banner">
          <span className="promo-banner__text">
            <strong>{t.home.promoTitle}</strong>
            <span>{t.home.promoBody}</span>
          </span>
          <Sparkles size={40} strokeWidth={1.3} aria-hidden className="promo-banner__icon" />
        </Link>

        <section className="card card--outlined">
          <SectionHeading title={t.home.latestUpdates} action={{ label: t.common.viewAll, to: serviceRoute('home', 'testResults') }} />
          <ul className="mini-tiles">
            {updates.map((u) => (
              <li key={u.id}>
                <Link to={serviceRoute('home', u.id)} className="mini-tile">
                  <span className="mini-tile__icon">{u.icon}</span>
                  <span className="mini-tile__label">{t.services[u.id].title}</span>
                </Link>
              </li>
            ))}
          </ul>
        </section>

        <section className="card card--outlined">
          <SectionHeading title={t.home.upcomingAppointments} action={{ label: t.common.viewMore, to: ROUTES.appointments }} />
          {next ? <AppointmentCard appointment={next} onOpen={() => setSelected(next)} /> : <EmptyState title={t.home.noUpcoming} />}
          <Button block size="lg" onClick={() => setBooking(true)}>{t.home.bookNew}</Button>
        </section>

        <section className="card card--outlined">
          <SectionHeading title={t.home.emergency} action={{ label: t.home.myReports, to: serviceRoute('home', 'emergencyReports') }} />
          <Button variant="danger" block size="lg" icon={<Siren size={20} aria-hidden />} onClick={() => setEmergencyOpen(true)}>
            {t.home.callAmbulance}
          </Button>
        </section>
      </div>

      <BookAppointmentDialog open={booking} onClose={() => setBooking(false)} />
      <AppointmentDetailsDialog appointment={selected} onClose={() => setSelected(null)} />
      <Dialog
        open={emergencyOpen}
        onClose={() => setEmergencyOpen(false)}
        title={t.home.emergencyDialogTitle}
        actions={<Button block onClick={() => setEmergencyOpen(false)}>{t.common.ok}</Button>}
      >
        <p>{t.home.emergencyDialogBody}</p>
      </Dialog>
    </div>
  );
}
