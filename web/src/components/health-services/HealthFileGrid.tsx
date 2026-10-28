import { useId, useState } from 'react';
import { ChevronsDown, ChevronsUp } from 'lucide-react';
import { useLanguage } from '../../i18n';
import { SectionHeading } from '../ui';
import { HealthServiceTile } from './HealthServiceTile';
import { HEALTH_FILE_COLLAPSED_COUNT, healthFileTiles } from './services';

/**
 * "الملف الصحي" — grid of tall service tiles on ملفي.
 * This is the ONLY place in the app that links to the diabetes integration route.
 */
export function HealthFileGrid() {
  const { t } = useLanguage();
  const [expanded, setExpanded] = useState(false);
  const gridId = useId();
  const visible = expanded ? healthFileTiles : healthFileTiles.slice(0, HEALTH_FILE_COLLAPSED_COUNT);

  return (
    <section className="profile-section">
      <SectionHeading
        title={t.profile.healthFile}
        action={{
          label: expanded ? t.common.showLess : t.common.showAll,
          onClick: () => setExpanded((v) => !v),
          expanded,
          icon: expanded ? <ChevronsUp size={18} aria-hidden /> : <ChevronsDown size={18} aria-hidden />,
        }}
      />
      <ul className="tile-grid" id={gridId}>
        {visible.map((tile) =>
          tile.id === 'diabetes' ? (
            <li key={tile.id}>
              <HealthServiceTile
                title={t.diabetes.title}
                subtitle={t.diabetes.tileSubtitle}
                description={t.diabetes.description}
                art={tile.art}
                to={tile.route}
                testId="diabetes-journey-tile"
                featured
              />
            </li>
          ) : (
            <li key={tile.id}>
              <HealthServiceTile
                title={t.services[tile.id].title}
                subtitle={t.services[tile.id].subtitle || undefined}
                art={tile.art}
                to={tile.route}
              />
            </li>
          ),
        )}
      </ul>
    </section>
  );
}
