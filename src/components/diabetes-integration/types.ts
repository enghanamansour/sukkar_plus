import type { ComponentType } from 'react';
import type { Direction, Language } from '../../types';

/**
 * Props the Sehhaty shell passes to the diabetes-care frontend when it is mounted
 * in-process (same React app). This is the whole contract on the shell side —
 * no data models or API endpoints are assumed.
 */
export interface DiabetesJourneyHostProps {
  /** Active UI language: 'ar' or 'en'. Changes live when the user switches language. */
  language: Language;
  /** 'rtl' for Arabic, 'ltr' for English. The host container already sets `dir` and `lang`. */
  direction: Direction;
  /** Route prefix the feature owns, e.g. '/my-profile/diabetes-journey'. Sub-routes below it are free to use. */
  basePath: string;
  /** Call to leave the feature and return to ملفي. */
  onExit: () => void;
}

export type DiabetesJourneyComponent = ComponentType<DiabetesJourneyHostProps>;
