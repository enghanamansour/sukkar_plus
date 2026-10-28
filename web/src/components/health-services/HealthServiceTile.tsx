import { Link } from 'react-router-dom';
import { TileIllustration } from './illustrations';
import type { TileArt } from './services';

interface HealthServiceTileProps {
  title: string;
  subtitle?: string;
  /** Longer description announced to assistive tech and shown as a tooltip. */
  description?: string;
  art: TileArt;
  to: string;
  /** Marks the integration tile for tests/handoff without changing its look. */
  testId?: string;
  /** Adds the glowing highlight used to spotlight a new feature (عضيد). */
  featured?: boolean;
}

/**
 * Tall Health File tile (الملف الصحي) — title + optional subtitle at the top,
 * illustration anchored to the bottom. Entire tile is a single link.
 */
export function HealthServiceTile({ title, subtitle, description, art, to, testId, featured }: HealthServiceTileProps) {
  return (
    <Link to={to} className={`service-tile ${featured ? 'service-tile--featured' : ''}`} title={description} data-testid={testId}>
      <span className="service-tile__title">{title}</span>
      {subtitle && <span className="service-tile__subtitle">{subtitle}</span>}
      {description && <span className="visually-hidden">{description}</span>}
      <TileIllustration art={art} />
    </Link>
  );
}
