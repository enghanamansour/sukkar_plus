/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** Optional URL of a separately deployed diabetes-care frontend (see FRONTEND_HANDOFF.md). */
  readonly VITE_DIABETES_JOURNEY_URL?: string;
}
interface ImportMeta {
  readonly env: ImportMetaEnv;
}
