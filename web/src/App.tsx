import { BrowserRouter, Route, Routes } from 'react-router-dom';
import { LanguageProvider } from './i18n';
import { ThemeProvider } from './theme/ThemeContext';
import { AppStateProvider } from './state/AppState';
import { AppShell } from './components/layout/AppShell';
import { HomePage } from './pages/HomePage';
import { AppointmentsPage } from './pages/AppointmentsPage';
import { WellnessPage } from './pages/WellnessPage';
import { MyProfilePage } from './pages/MyProfilePage';
import { NotificationsPage } from './pages/NotificationsPage';
import { DiabetesJourneyPage } from './pages/DiabetesJourneyPage';
import { ServicePlaceholderPage } from './pages/ServicePlaceholderPage';
import { NotFoundPage } from './pages/NotFoundPage';
import { SettingsPage } from './pages/SettingsPage';

export default function App() {
  return (
    <ThemeProvider>
    <LanguageProvider>
      <AppStateProvider>
        <BrowserRouter future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
          <Routes>
            <Route element={<AppShell />}>
              <Route index element={<HomePage />} />
              <Route path="services/:serviceId" element={<ServicePlaceholderPage />} />
              <Route path="notifications" element={<NotificationsPage />} />
              <Route path="settings" element={<SettingsPage />} />

              <Route path="appointments" element={<AppointmentsPage />} />
              <Route path="appointments/services/:serviceId" element={<ServicePlaceholderPage />} />

              <Route path="wellness" element={<WellnessPage />} />
              <Route path="wellness/services/:serviceId" element={<ServicePlaceholderPage />} />

              <Route path="my-profile" element={<MyProfilePage />} />
              <Route path="my-profile/services/:serviceId" element={<ServicePlaceholderPage />} />
              {/* Integration boundary — the diabetes-care feature may own any sub-route below this path. */}
              <Route path="my-profile/diabetes-journey/*" element={<DiabetesJourneyPage />} />

              <Route path="*" element={<NotFoundPage />} />
            </Route>
          </Routes>
        </BrowserRouter>
      </AppStateProvider>
    </LanguageProvider>
    </ThemeProvider>
  );
}
