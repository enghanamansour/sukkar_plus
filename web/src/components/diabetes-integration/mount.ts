/**
 * ─────────────────────────────────────────────────────────────────────────────
 *  DIABETES JOURNEY — MOUNT CONFIGURATION  (the one file to edit when integrating)
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Nothing is connected yet. While both values below are null/empty, the route
 * /my-profile/diabetes-journey shows <DiabetesJourneyPlaceholder />.
 *
 * Option A — same React codebase:
 *   import { DiabetesApp } from '<path-to-their-feature>';
 *   export const diabetesJourneyComponent: DiabetesJourneyComponent | null = DiabetesApp;
 *
 * Option B — separately deployed frontend (any framework):
 *   set VITE_DIABETES_JOURNEY_URL in `.env.local`, e.g.
 *   VITE_DIABETES_JOURNEY_URL=https://diabetes.example.com/
 *   It is embedded in an iframe with `?lang=ar|en&dir=rtl|ltr` appended.
 *
 * If both are set, Option A wins. See FRONTEND_HANDOFF.md.
 */
import type { DiabetesJourneyComponent } from './types';

export const diabetesJourneyComponent: DiabetesJourneyComponent | null = null;

export const diabetesJourneyEmbedUrl: string | null = (import.meta.env.VITE_DIABETES_JOURNEY_URL as string | undefined)?.trim() || null;
