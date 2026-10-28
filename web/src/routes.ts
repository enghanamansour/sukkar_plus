/**
 * Central route table. Placeholder screens for out-of-scope services are nested under the
 * tab they were opened from so the bottom navigation keeps the correct tab highlighted.
 */
export const ROUTES = {
  home: '/',
  appointments: '/appointments',
  wellness: '/wellness',
  profile: '/my-profile',
  notifications: '/notifications',
  settings: '/settings',
  /** Integration boundary for the separately-built diabetes-care product. */
  diabetesJourney: '/my-profile/diabetes-journey',
} as const;

export type TabId = 'home' | 'appointments' | 'wellness' | 'profile';

const tabBase: Record<TabId, string> = {
  home: '',
  appointments: ROUTES.appointments,
  wellness: ROUTES.wellness,
  profile: ROUTES.profile,
};

/** Path of a placeholder screen for a service opened from a given tab. */
export const serviceRoute = (tab: TabId, serviceId: string) => `${tabBase[tab]}/services/${serviceId}`;

export function tabForPath(pathname: string): TabId {
  if (pathname.startsWith(ROUTES.profile)) return 'profile';
  if (pathname.startsWith(ROUTES.appointments)) return 'appointments';
  if (pathname.startsWith(ROUTES.wellness)) return 'wellness';
  return 'home';
}

export const tabRoot = (tab: TabId): string => (tab === 'home' ? ROUTES.home : tabBase[tab]);
