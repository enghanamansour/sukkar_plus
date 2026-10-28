import { Link } from 'react-router-dom';
import { useLanguage } from '../i18n';
import { ROUTES } from '../routes';
import { EmptyState } from '../components/ui';

export function NotFoundPage() {
  const { t } = useLanguage();
  return (
    <div className="page">
      <div className="page__body">
        <EmptyState
          title={t.notFound.title}
          body={t.notFound.body}
          action={<Link className="btn btn--primary btn--md" to={ROUTES.home}>{t.notFound.goHome}</Link>}
        />
      </div>
    </div>
  );
}
