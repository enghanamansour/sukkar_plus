// Gemini client (server-side only). Uses the generateContent REST endpoint,
// which Google documents as legacy but fully supported; see
// docs/INTEGRATIONS.md for the Interactions API migration note.
// The API key is read from the GEMINI_API_KEY secret and never reaches the app.

import type { FetchLike } from './make.ts';
import { METRIC_KEYS } from './validation.ts';

export const DEFAULT_GEMINI_MODEL = 'gemini-3.8-flash';
const ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/models';

export class AiNotConfiguredError extends Error {
  constructor() {
    super('ai_not_configured');
  }
}

export interface GeminiConfig {
  apiKey?: string;
  model?: string;
  timeoutMs?: number;
}

export const EXTRACTION_INSTRUCTION = `You read printed continuous glucose monitoring (CGM) summary reports.
Return ONLY values that are printed in the document. Never calculate, estimate or infer a value.
If a value is not printed, return null for it. Do not return names, dates of birth, serial numbers,
insulin, bolus, carbohydrate or pump-setting values.
Range bands: time_very_low (<54 mg/dL), time_low (54-69), time_in_range (70-180), time_high (181-250),
time_very_high (>250), time_below_range_total (<70), time_above_range_total (>180).
sensor_active is the printed percentage of time the CGM was active/connected.
Percent values use unit "%"; mean_glucose and sd use the report's glucose unit.`;

export const EXTRACTION_SCHEMA = {
  type: 'OBJECT',
  properties: {
    glucose_unit: { type: 'STRING', enum: ['mg/dL', 'mmol/L'] },
    fields: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          key: { type: 'STRING', enum: [...METRIC_KEYS] },
          value: { type: 'NUMBER', nullable: true },
          unit: { type: 'STRING' },
          page: { type: 'INTEGER', nullable: true },
          label: { type: 'STRING', nullable: true },
        },
        required: ['key', 'value', 'unit'],
      },
    },
  },
  required: ['glucose_unit', 'fields'],
};

export const EXPLANATION_INSTRUCTION = `أنت مساعد تعليمي في نموذج أولي اسمه "سكر بلس". اكتب شرحًا عربيًا موجزًا وهادئًا
يعتمد فقط على القيم الموثّقة المرسلة في السياق. لا تضف أي رقم غير موجود في السياق. لا تقدم تشخيصًا،
ولا توصيات علاجية، ولا أي حديث عن الجرعات أو الأدوية، ولا تصف أي قيمة بأنها خطيرة أو غير طبيعية.
إذا كانت قيمة ناقصة فاذكر أنها غير متاحة. اختم بأن الفريق الصحي هو المرجع. لا تتجاوز 120 كلمة.`;

export function buildExtractionRequest(pdfBase64: string) {
  return {
    systemInstruction: { parts: [{ text: EXTRACTION_INSTRUCTION }] },
    contents: [
      {
        role: 'user',
        parts: [
          { inline_data: { mime_type: 'application/pdf', data: pdfBase64 } },
          { text: 'Extract the printed CGM summary metrics as JSON.' },
        ],
      },
    ],
    generationConfig: { temperature: 0, responseMimeType: 'application/json', responseSchema: EXTRACTION_SCHEMA },
  };
}

export function buildExplanationRequest(context: unknown) {
  return {
    systemInstruction: { parts: [{ text: EXPLANATION_INSTRUCTION }] },
    contents: [{ role: 'user', parts: [{ text: `السياق (JSON):\n${JSON.stringify(context)}` }] }],
    generationConfig: { temperature: 0.2, maxOutputTokens: 600 },
  };
}

/** Extracts the concatenated text of the first candidate. */
export function responseText(json: unknown): string | null {
  const c = (json as { candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }> })?.candidates?.[0];
  const parts = c?.content?.parts;
  if (!Array.isArray(parts)) return null;
  const text = parts.map((p) => (typeof p.text === 'string' ? p.text : '')).join('');
  return text.length ? text : null;
}

export async function callGemini(cfg: GeminiConfig, body: unknown, fetchImpl: FetchLike = fetch): Promise<unknown> {
  if (!cfg.apiKey) throw new AiNotConfiguredError();
  const model = cfg.model || DEFAULT_GEMINI_MODEL;
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), cfg.timeoutMs ?? 45000);
  try {
    const res = await fetchImpl(`${ENDPOINT}/${encodeURIComponent(model)}:generateContent`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-goog-api-key': cfg.apiKey },
      body: JSON.stringify(body),
      signal: ctrl.signal,
    });
    if (!res.ok) throw new Error(`gemini_http_${res.status}`);
    return await res.json();
  } finally {
    clearTimeout(timer);
  }
}

/** Parses the model's JSON text; returns null on any parse failure. */
export function parseJsonText(text: string | null): unknown {
  if (!text) return null;
  const cleaned = text.trim().replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/, '');
  try {
    return JSON.parse(cleaned);
  } catch {
    return null;
  }
}
