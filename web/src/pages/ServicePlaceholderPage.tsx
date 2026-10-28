import { useLocation, useParams } from 'react-router-dom';
import { Construction } from 'lucide-react';
import { useLanguage } from '../i18n';
import { tabForPath, tabRoot } from '../routes';
import { BackHeader } from '../components/layout/PageHeader';
import { DemoBadge, EmptyState } from '../components/ui';
import type { ServiceId } from '../components/health-services/services';
import { NotFoundPage } from './NotFoundPage';

/** Services whose real screen would list records — shown with an empty state to make the placeholder obvious. */
const RECORD_SERVICES = new Set<ServiceId>([
  'healthRecord', 'medications', 'labResults', 'vaccinations', 'allergies', 'vitals', 'referrals',
  'prescriptions', 'testResults', 'insurance', 'sickLeaves', 'medicalReports', 'dependents', 'questionnaires', 'emergencyReports',
]);

/** Generic frontend placeholder for any service outside the mockup's scope. */
export function ServicePlaceholderPage() {
  const { serviceId } = useParams();
  const { pathname, state } = useLocation();
  const { t } = useLanguage();

  if (!serviceId || !(serviceId in t.services)) return <NotFoundPage />;
  const id = serviceId as ServiceId;
  const title = (state as { title?: string } | null)?.title ?? t.services[id].title;
  const tab = tabForPath(pathname);

  return (
    <div className="page">
      <BackHeader title={title} backTo={tabRoot(tab)} />
      <div className="page__body">
        <section className="placeholder-card">
          <DemoBadge>{t.placeholder.badge}</DemoBadge>
          <span className="placeholder-card__icon"><Construction size={28} aria-hidden /></span>
          <h2 className="placeholder-card__title">{title}</h2>
          <p className="placeholder-card__body">{t.placeholder.body}</p>
        </section>
        {RECORD_SERVICES.has(id) && <EmptyState title={t.placeholder.emptyTitle} body={t.placeholder.emptyBody} />}
      </div>
    </div>
  );
}
