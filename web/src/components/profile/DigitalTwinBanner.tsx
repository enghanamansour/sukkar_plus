import { Link } from 'react-router-dom';
import { useLanguage } from '../../i18n';
import { serviceRoute } from '../../routes';
import { ForwardArrow } from '../ui';

/** Mint "التوأم الرقمي" banner with an abstract body silhouette (original artwork). */
export function DigitalTwinBanner() {
  const { t } = useLanguage();
  return (
    <Link to={serviceRoute('profile', 'digitalTwin')} className="twin-banner">
      <span className="twin-banner__text">
        <span className="twin-banner__title">
          {t.profile.digitalTwin}
          <ForwardArrow size={18} />
        </span>
        <span className="twin-banner__body">{t.profile.digitalTwinBody}</span>
      </span>
      <svg className="twin-banner__art" viewBox="0 0 120 90" aria-hidden focusable="false">
        <defs>
          <linearGradient id="twinGrad" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stopColor="#9fd0f2" />
            <stop offset="1" stopColor="#1f5f99" />
          </linearGradient>
        </defs>
        <path d="M54 8c10 0 16 8 16 18 0 7-3 12-6 15 3 4 10 7 20 9 14 3 26 12 30 40H0c4-26 14-36 28-40 10-2 17-5 20-9-3-3-6-8-6-15 0-10 4-18 12-18Z" fill="url(#twinGrad)" opacity=".9" />
        <path d="M30 64c8 4 18 6 28 6s20-2 28-6" stroke="#d6ecfb" strokeWidth="1.2" fill="none" opacity=".7" />
        <path d="M58 44v40" stroke="#d6ecfb" strokeWidth="1" opacity=".5" />
      </svg>
    </Link>
  );
}
