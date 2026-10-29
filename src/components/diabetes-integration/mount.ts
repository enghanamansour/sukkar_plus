/**
 * ─────────────────────────────────────────────────────────────────────────────
 *  DIABETES JOURNEY — MOUNT CONFIGURATION
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Connected: Option A (same React app). The Adeed feature lives in `src/adeed/` and is mounted at
 * /my-profile/diabetes-journey/*. See FRONTEND_HANDOFF.md for the contract and README.md for setup.
 *
 * Option B (iframe) is still available: set VITE_DIABETES_JOURNEY_URL and change the component below to null.
 */
import type { DiabetesJourneyComponent } from './types';
import { AdeedApp } from '../../adeed/AdeedApp';

export const diabetesJourneyComponent: DiabetesJourneyComponent | null = AdeedApp;

export const diabetesJourneyEmbedUrl: string | null = (import.meta.env.VITE_DIABETES_JOURNEY_URL as string | undefined)?.trim() || null;
