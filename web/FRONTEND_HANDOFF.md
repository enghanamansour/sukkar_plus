# Frontend Handoff — "عضيد / Adheed"

This document is for the developer building the diabetes-care product. It describes **only** the integration boundary that the Sehhaty-inspired frontend mockup exposes. **The two projects are not connected yet.** No API, backend, data model or business logic for diabetes care exists in this repository.

---

> The service is named **عضيد** (Arabic) / **Adheed** (English). The route and code identifiers keep the neutral `diabetes-journey` / `DiabetesJourney*` names so they don't change if the display name changes again.

## 1. Where the entry point is

| Item | Value |
|---|---|
| Screen | ملفي / My File — route `/my-profile` (`src/pages/MyProfilePage.tsx`) |
| Section | الملف الصحي / Health File (`src/components/health-services/HealthFileGrid.tsx`) |
| Tile | 4th tile, after فريقي الطبي · السجل الصحي · الأدوية والوصفات. Visible without expanding "إظهار الكل". |
| Tile config | `healthFileTiles` in `src/components/health-services/services.ts` (`id: 'diabetes'`) |
| Test hook | `data-testid="diabetes-journey-tile"` |
| Highlight | Glowing gradient border (`featured` prop → `.service-tile--featured` in `components.css`); the glow animation stops for users who turn on reduced motion |
| Texts | `diabetes.*` keys in `src/i18n/ar.ts` and `src/i18n/en.ts` |

This tile is the **only** entry point. It is not in Home, Appointments, Well-being, the bottom navigation, the home search, or any banner.

## 2. Route

```
/my-profile/diabetes-journey/*
```

- Defined in `src/App.tsx`. Constant: `ROUTES.diabetesJourney` in `src/routes.ts`.
- The trailing `/*` means **every sub-path below it belongs to your feature** (e.g. `/my-profile/diabetes-journey/reports/42`). The shell does not interpret them.
- Because the path starts with `/my-profile`, the bottom navigation keeps **ملفي** highlighted on all of your screens.

## 3. The integration component

`src/components/diabetes-integration/`

| File | Purpose |
|---|---|
| `DiabetesJourneyIntegration.tsx` | The boundary. Sets `lang`/`dir` on its container, passes props down, chooses what to render. |
| `mount.ts` | **The one file to edit to connect your feature.** |
| `types.ts` | `DiabetesJourneyHostProps` — the props your root component receives. |
| `DiabetesJourneyPlaceholder.tsx` | The placeholder currently shown. **This is what gets replaced.** |

It is rendered by `src/pages/DiabetesJourneyPage.tsx`, which keeps the shell around it:

```
┌───────────────────────────────┐
│ ← عضيد  (BackHeader) │  ← owned by the shell
├───────────────────────────────┤
│                               │
│  <section class="dj-host"     │  ← your content area
│     lang=".." dir="..">       │
│                               │
├───────────────────────────────┤
│ الرئيسية المواعيد جودة الحياة ملفي │  ← owned by the shell (ملفي active)
└───────────────────────────────┘
```

Render priority: **component (Option A) → embed URL (Option B) → placeholder**.

### Props passed to your feature (`DiabetesJourneyHostProps`)

```ts
interface DiabetesJourneyHostProps {
  language: 'ar' | 'en';      // live — re-renders when the user switches language
  direction: 'rtl' | 'ltr';
  basePath: string;           // '/my-profile/diabetes-journey'
  onExit: () => void;         // navigates back to /my-profile
}
```

That is the entire contract on the shell side. Nothing about your data, components or endpoints is assumed.

## 4. Language and RTL/LTR

- Source of truth: `LanguageProvider` in `src/i18n/LanguageContext.tsx` (`useLanguage()` hook).
- Persisted in `localStorage` under `sehhaty-mockup.language` (`'ar'` default, or `'en'`).
- On change the provider sets `<html lang dir>` globally, so RTL/LTR applies to the whole document.
- The integration container **also** sets `lang` and `dir` on itself, so your content is correct even if it is rendered in an isolated subtree.
- Option A receives `language`/`direction` as props. Option B receives them as query params `?lang=ar&dir=rtl` (see below).
- The shell uses CSS logical properties (`margin-inline-start`, `inset-inline-end`, `text-align: start`) and mirrors directional icons with the `.flip-rtl` class. Doing the same in your feature will keep it consistent.

## 5. Returning to ملفي

Three ways, all ending at `/my-profile`:
1. The back arrow in the shell header (always present).
2. Your feature calls `onExit()` (Option A).
3. The bottom-nav **ملفي** tab.

The browser Back button also works normally.

## 6. How to connect

### Option A — same React app (simplest if you also use React 18 + TypeScript)

```ts
// src/components/diabetes-integration/mount.ts
import { DiabetesApp } from '<path-or-package-of-your-feature>';
export const diabetesJourneyComponent: DiabetesJourneyComponent | null = DiabetesApp;
```

- Your root component receives `DiabetesJourneyHostProps`.
- If you use React Router, render your own `<Routes>` inside it — relative routes resolve under `basePath` because the shell route is a splat (`/*`) and the `v7_relativeSplatPath` flag is on.
- Do **not** render a second `<BrowserRouter>`; the shell already provides one (react-router-dom 6.28).
- Your styles should be scoped (CSS modules, a prefix, etc.) so they do not override the shell's global CSS.

### Option B — separately deployed frontend (any framework, different repo)

```bash
# .env.local in this project
VITE_DIABETES_JOURNEY_URL=https://your-diabetes-app.example.com/
```

- The page then renders an `<iframe>` filling the content area, with `?lang=ar|en&dir=rtl|ltr` appended to your URL.
- Switching language changes the URL, which **reloads** the iframe. If you want live switching without reload, that needs a `postMessage` protocol — not implemented; agree on it first.
- The iframe is not sandboxed (assumes a trusted first-party app). Add a `sandbox` attribute in `DiabetesJourneyIntegration.tsx` if required.
- Your app must allow being framed by this origin (`Content-Security-Policy: frame-ancestors …` / no `X-Frame-Options: DENY`).

### Option C — link out instead of embedding

If neither fits, change the tile's `route` in `services.ts` to an external URL handler. Not implemented; tell the shell owner.

## 7. What to replace

- Replace: `DiabetesJourneyPlaceholder` — by configuring `mount.ts`. You don't need to delete the placeholder; it is only rendered when nothing is configured.
- Don't modify: `MyProfilePage`, `HealthFileGrid`, `BottomNav`, `AppShell`. The tile, route and shell are designed so you never need to.

## 8. Assumptions that need confirmation

1. **Framework** — Option A assumes React 18 + react-router-dom 6. If you use another framework or React 19 / Router 7, use Option B or we align versions.
2. **Language codes** — the shell uses exactly `ar` and `en`.
3. **Header ownership** — the shell shows its own back header with the title "عضيد". If your feature has its own header, decide which one stays (the shell's can be removed in `DiabetesJourneyPage.tsx`).
4. **Bottom navigation** — stays visible on your screens. Confirm this is acceptable for flows like report upload.
5. **Authentication / patient identity** — the mockup has no auth and only fictional patient data. How your feature gets the real patient context is undecided and **not** provided by this shell.
6. **Hosting / URL** — for Option B, the production URL and framing policy.
7. **Light/dark theme** — the shell supports فاتح/داكن via `<html data-theme="dark">` (see `src/theme/ThemeContext.tsx`). It is not passed as a prop; an in-process feature can read `document.documentElement.dataset.theme` or reuse the CSS tokens, which switch automatically. An embedded (iframe) feature does not receive the theme — agree on a `theme` query param if needed.
8. **Fonts and tokens** — shell tokens live in `src/styles/tokens.css` (IBM Plex Sans Arabic, healthcare blues). Reuse them if you want a visually seamless result.

## 9. Quick verification after integrating

```bash
npm install
npm run dev            # http://localhost:5173
```

1. Open ملفي → tap "عضيد" → URL is `/my-profile/diabetes-journey`.
2. Your feature renders inside the content area; bottom nav shows ملفي active.
3. Switch language (☰ المزيد → الإعدادات, or ملفي → الإعدادات → اللغة) → your feature switches and direction flips.
4. Back arrow / `onExit()` returns to `/my-profile`.
