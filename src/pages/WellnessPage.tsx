import { Link } from 'react-router-dom';
import { Brain, Droplet, Footprints, ShieldAlert, Utensils, Wind } from 'lucide-react';
import type { ReactNode } from 'react';
import { useLanguage } from '../i18n';
import { serviceRoute } from '../routes';
import { PageHeader } from '../components/layout/PageHeader';
import { DailyActivityCard } from '../components/home/DailyActivityCard';
import { ForwardArrow, SectionHeading } from '../components/ui';

type ArticleKey = 'malnutrition' | 'panic' | 'bullying' | 'stress';

const articles: { key: ArticleKey; icon: ReactNode; tone: string }[] = [
  { key: 'malnutrition', icon: <Utensils size={34} strokeWidth={1.4} aria-hidden />, tone: 'rose' },
  { key: 'panic', icon: <Wind size={34} strokeWidth={1.4} aria-hidden />, tone: 'sky' },
  { key: 'bullying', icon: <ShieldAlert size={34} strokeWidth={1.4} aria-hidden />, tone: 'sand' },
  { key: 'stress', icon: <Brain size={34} strokeWidth={1.4} aria-hidden />, tone: 'mint' },
];

export function WellnessPage() {
  const { t } = useLanguage();
  return (
    <div className="page">
      <PageHeader title={t.wellness.title} />
      <div className="page__body">
        <section className="card card--outlined">
          <SectionHeading title={t.wellness.bloodDonation} action={{ label: t.wellness.viewServices, to: serviceRoute('wellness', 'bloodDonation') }} />
          <Link to={serviceRoute('wellness', 'bloodDonation')} className="donation-banner">
            <span className="donation-banner__text">
              <strong>{t.wellness.donationTitle}</strong>
              <span>{t.wellness.donationBody}</span>
            </span>
            <Droplet size={38} strokeWidth={1.4} aria-hidden className="donation-banner__icon" />
          </Link>
        </section>

        <section className="card card--outlined">
          <SectionHeading title={t.wellness.educational} action={{ label: t.common.viewAll, to: serviceRoute('wellness', 'educational') }} />
          <ul className="article-row">
            {articles.map((a) => (
              <li key={a.key}>
                <Link to={serviceRoute('wellness', 'article')} state={{ title: t.wellness.articles[a.key] }} className="article-card">
                  <span className={`article-card__art article-card__art--${a.tone}`}>{a.icon}</span>
                  <span className="article-card__title">{t.wellness.articles[a.key]}</span>
                </Link>
              </li>
            ))}
          </ul>
        </section>

        <DailyActivityCard tab="wellness" />

        <Link to={serviceRoute('wellness', 'walkCampaign')} className="walk-banner">
          <span className="walk-banner__text">
            <strong>
              {t.wellness.walkCampaign}
              <ForwardArrow size={16} />
            </strong>
            <span>{t.wellness.walkCampaignBody}</span>
          </span>
          <span className="walk-banner__badge" aria-hidden>
            <Footprints size={22} />
            <b>30</b>
          </span>
        </Link>
      </div>
    </div>
  );
}
