# Sehhaty-Inspired Frontend Mockup

Light/dark, Arabic/English (RTL/LTR) mobile-style web mockup inspired by the Saudi Sehhaty (صحتي) app, built with React 18 + TypeScript + Vite. **Frontend only** — all data is synthetic and nothing is sent anywhere.

The diabetes-care service ("عضيد") appears **only** as a tile inside ملفي and opens an integration boundary for a separately built product. See **[FRONTEND_HANDOFF.md](./FRONTEND_HANDOFF.md)**.

## Run

```bash
npm install
npm run dev        # http://localhost:5173
npm run build      # type-check + production build into dist/
npm run preview    # serve the production build
```

Node 18+ recommended. When deploying `dist/` to a static host, configure an SPA fallback to `index.html` (the app uses browser-history routes such as `/my-profile/diabetes-journey`).

## Routes

| Route | Screen |
|---|---|
| `/` | الرئيسية / Home |
| `/appointments` | المواعيد / Appointments |
| `/wellness` | جودة الحياة / Well-being |
| `/my-profile` | ملفي / My File |
| `/my-profile/diabetes-journey/*` | Diabetes integration boundary (placeholder until connected) |
| `/notifications` | Notifications |
| `/settings` | الإعدادات / Settings (language), opened from the ☰ المزيد panel |
| `/services/:id`, `/<tab>/services/:id` | Labelled placeholder for out-of-scope services |

## Structure

```
src/
  App.tsx                     routes
  routes.ts                   route constants + tab helpers
  i18n/                       ar.ts, en.ts (dictionaries), LanguageContext, format
  styles/                     tokens.css (design tokens), global.css, components.css, screens.css
  types/                      shared types
  data/mockData.ts            fictional patient, appointments, notifications
  state/AppState.tsx          in-memory UI state (appointments, notifications, toast…)
  components/
    layout/                   AppShell, HomeHeader, PageHeader/BackHeader, MenuDrawer
    navigation/               BottomNav
    ui/                       Button, Dialog, EmptyState, SectionHeading, LanguageSwitch, SegmentedControl, icons, logo
    home/                     carousel, daily activity, appointment card + dialogs
    profile/                  ProfileCard, DigitalTwinBanner, ListSection
    health-services/          HealthServiceTile, HealthFileGrid, services registry, illustrations
    diabetes-integration/     DiabetesJourneyIntegration, mount.ts, placeholder, types
  pages/                      one file per screen
  assets/sehhaty-logo.png     logo (transparent, from the supplied artwork)
```

- **Translations:** `src/i18n/ar.ts` (source shape) and `src/i18n/en.ts`. The `Dictionary` type makes a missing English key a compile error.
- **Design tokens:** `src/styles/tokens.css`.
- **Language persistence:** `localStorage` key `sehhaty-mockup.language`.
- **Theme (فاتح / داكن):** `src/theme/ThemeContext.tsx`, switched from ☰ المزيد → المظهر or الإعدادات. Persisted as `sehhaty-mockup.theme` and applied as `<html data-theme="dark">`; the dark palette is the `:root[data-theme='dark']` block in `tokens.css`.

## Known limitations

- All interactions (booking, cancelling, notifications, profile switch, step target) are in-memory and reset on refresh; only the language persists.
- Illustrations are original simplified artwork, not the app's real images. Campaign banners are generic.
- Visual match is based on a single screen recording; exact font (IBM Plex Sans Arabic used as a close substitute), icon set (Lucide) and some spacing differ from the real app.
- Dark mode colours are sampled from reference screenshots; some illustrations keep their light-mode artwork.
