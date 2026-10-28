import { useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { useLanguage } from '../i18n';
import { ROUTES } from '../routes';
import { BackHeader } from '../components/layout/PageHeader';
import { DiabetesJourneyIntegration } from '../components/diabetes-integration';

/**
 * Route: /my-profile/diabetes-journey (and any sub-path below it).
 * Keeps the shell (back header + bottom nav with ملفي active) around the integration area.
 */
export function DiabetesJourneyPage() {
  const { t, lang, dir } = useLanguage();
  const navigate = useNavigate();
  const exitToProfile = useCallback(() => navigate(ROUTES.profile), [navigate]);

  return (
    <div className="page page--integration">
      <BackHeader title={t.diabetes.title} backTo={ROUTES.profile} backLabel={t.diabetes.backToProfile} />
      <DiabetesJourneyIntegration language={lang} direction={dir} basePath={ROUTES.diabetesJourney} onExit={exitToProfile} />
    </div>
  );
}
