import type { Dictionary } from '../../i18n';
import { ROUTES, serviceRoute, type TabId } from '../../routes';

export type ServiceId = keyof Dictionary['services'];

/** Illustration keys available for tall Health File tiles (see illustrations.tsx). */
export type TileArt = 'careTeam' | 'record' | 'pills' | 'glucose' | 'lab' | 'vaccine' | 'allergy' | 'vitals' | 'referral';

export interface HealthFileTile {
  /** Translation key, or the special `diabetes` key for the integration tile. */
  id: ServiceId | 'diabetes';
  art: TileArt;
  route: string;
}

/**
 * Tiles of the "الملف الصحي" (Health File) section on ملفي.
 * `collapsedCount` tiles are visible by default; "إظهار الكل" reveals the rest.
 * عضيد sits directly after السجل الصحي and الأدوية والوصفات so it reads as a native service.
 */
export const healthFileTiles: HealthFileTile[] = [
  { id: 'careTeam', art: 'careTeam', route: serviceRoute('profile', 'careTeam') },
  { id: 'healthRecord', art: 'record', route: serviceRoute('profile', 'healthRecord') },
  { id: 'medications', art: 'pills', route: serviceRoute('profile', 'medications') },
  { id: 'diabetes', art: 'glucose', route: ROUTES.diabetesJourney },
  { id: 'labResults', art: 'lab', route: serviceRoute('profile', 'labResults') },
  { id: 'vaccinations', art: 'vaccine', route: serviceRoute('profile', 'vaccinations') },
  { id: 'allergies', art: 'allergy', route: serviceRoute('profile', 'allergies') },
  { id: 'vitals', art: 'vitals', route: serviceRoute('profile', 'vitals') },
  { id: 'referrals', art: 'referral', route: serviceRoute('profile', 'referrals') },
];
export const HEALTH_FILE_COLLAPSED_COUNT = 6;

/** Services reachable through the home search box. The diabetes service is deliberately excluded. */
export const searchableServices: { id: ServiceId; tab: TabId }[] = [
  { id: 'healthRecord', tab: 'profile' },
  { id: 'medications', tab: 'profile' },
  { id: 'careTeam', tab: 'profile' },
  { id: 'labResults', tab: 'profile' },
  { id: 'vaccinations', tab: 'profile' },
  { id: 'sickLeaves', tab: 'profile' },
  { id: 'medicalReports', tab: 'profile' },
  { id: 'insurance', tab: 'profile' },
  { id: 'prescriptions', tab: 'home' },
  { id: 'testResults', tab: 'home' },
  { id: 'checkup', tab: 'home' },
  { id: 'screening', tab: 'home' },
  { id: 'bloodDonation', tab: 'wellness' },
  { id: 'walkCampaign', tab: 'wellness' },
  { id: 'educational', tab: 'wellness' },
];
