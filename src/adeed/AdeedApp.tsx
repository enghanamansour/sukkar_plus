import { NavLink, Route, Routes } from 'react-router-dom';
import { CalendarClock, FileText, History, Home, ListChecks, MessageCircle, Settings } from 'lucide-react';
import type { DiabetesJourneyHostProps } from '../components/diabetes-integration/types';
import { AdeedProvider, useAdeed } from './context';
import { Spinner } from './components';
import { AuthPage } from './pages/AuthPage';
import { HomePage } from './pages/HomePage';
import { ReportsPage } from './pages/ReportsPage';
import { ReportDetailPage } from './pages/ReportDetailPage';
import { QuestionsPage } from './pages/QuestionsPage';
import { ChatPage } from './pages/ChatPage';
import { AppointmentPage } from './pages/AppointmentPage';
import { HistoryPage } from './pages/HistoryPage';
import { SettingsPage } from './pages/SettingsPage';
import './adeed.css';

function SubNav() {
  const { t, basePath } = useAdeed();
  const items = [
    { to: '', label: t.nav.home, Icon: Home, end: true },
    { to: 'reports', label: t.nav.reports, Icon: FileText },
    { to: 'questions', label: t.nav.questions, Icon: ListChecks },
    { to: 'chat', label: t.nav.chat, Icon: MessageCircle },
    { to: 'appointment', label: t.nav.appointment, Icon: CalendarClock },
    { to: 'history', label: t.nav.history, Icon: History },
    { to: 'settings', label: t.nav.settings, Icon: Settings },
  ];
  return (
    <nav className="ad-subnav ad-noprint" aria-label="Adeed">
      {items.map(({ to, label, Icon, end }) => (
        <NavLink key={to} to={to ? `${basePath}/${to}` : basePath} end={end} className={({ isActive }) => `ad-subnav__item ${isActive ? 'is-active' : ''}`}>
          <Icon size={16} aria-hidden />
          <span>{label}</span>
        </NavLink>
      ))}
    </nav>
  );
}

function Gate() {
  const { session, authReady, t } = useAdeed();
  if (!authReady) return <div className="ad-page"><Spinner label={t.common.loading} /></div>;
  if (!session) return <div className="ad-page"><AuthPage /></div>;
  return (
    <>
      <SubNav />
      <main className="ad-page">
        <Routes>
          <Route index element={<HomePage />} />
          <Route path="reports" element={<ReportsPage />} />
          <Route path="reports/:id" element={<ReportDetailPage />} />
          <Route path="questions" element={<QuestionsPage />} />
          <Route path="chat" element={<ChatPage />} />
          <Route path="appointment" element={<AppointmentPage />} />
          <Route path="history" element={<HistoryPage />} />
          <Route path="settings" element={<SettingsPage />} />
          <Route path="*" element={<HomePage />} />
        </Routes>
        <p className="ad-fineprint ad-footer-note">{t.disclaimer.short}</p>
      </main>
    </>
  );
}

/** Root of the Adeed feature, mounted by the shell at /my-profile/diabetes-journey/* (see mount.ts). */
export function AdeedApp({ language, direction, basePath }: DiabetesJourneyHostProps) {
  return (
    <div className="adeed" lang={language} dir={direction}>
      <AdeedProvider lang={language} basePath={basePath}>
        <Gate />
      </AdeedProvider>
    </div>
  );
}
