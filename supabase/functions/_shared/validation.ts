// Server-side validation of AI extraction output. Mirrors
// packages/sukkar_core/lib/src/extraction/review.dart (AiExtractionValidator).
// Model output is never trusted: wrong types, units, ranges or duplicates are
// dropped with a reason. Nothing is coerced.

export const METRIC_KEYS = [
  'mean_glucose',
  'gmi',
  'cv',
  'sd',
  'time_very_low',
  'time_low',
  'time_in_range',
  'time_high',
  'time_very_high',
  'time_below_range_total',
  'time_above_range_total',
  'sensor_active',
] as const;
export type MetricKey = (typeof METRIC_KEYS)[number];

export type GlucoseUnit = 'mg/dL' | 'mmol/L';

export interface ValidatedField {
  key: MetricKey;
  value: number;
  unit: string;
  page: number | null;
  label: string | null;
}

export interface ValidatedExtraction {
  glucose_unit: GlucoseUnit;
  fields: ValidatedField[];
  rejected: string[];
}

export function parseGlucoseUnit(u: unknown): GlucoseUnit | null {
  if (typeof u !== 'string') return null;
  const s = u.toLowerCase().replace(/\s/g, '');
  if (s.includes('mg/dl')) return 'mg/dL';
  if (s.includes('mmol/l')) return 'mmol/L';
  return null;
}

export function plausibleRange(key: MetricKey, unit: GlucoseUnit): [number, number] {
  switch (key) {
    case 'mean_glucose':
      return unit === 'mg/dL' ? [40, 400] : [2.2, 22.2];
    case 'sd':
      return unit === 'mg/dL' ? [0, 200] : [0, 11.1];
    case 'gmi':
      return [4, 14];
    default:
      return [0, 100];
  }
}

export function validateAiExtraction(json: unknown): ValidatedExtraction {
  const rejected: string[] = [];
  if (json === null || typeof json !== 'object' || Array.isArray(json)) {
    return { glucose_unit: 'mg/dL', fields: [], rejected: ['response_not_object'] };
  }
  const obj = json as Record<string, unknown>;
  const unit = parseGlucoseUnit(obj.glucose_unit) ?? 'mg/dL';
  if (!Array.isArray(obj.fields)) {
    return { glucose_unit: unit, fields: [], rejected: ['fields_missing'] };
  }
  const out = new Map<MetricKey, ValidatedField>();
  const dupes = new Set<MetricKey>();
  for (const f of obj.fields) {
    if (f === null || typeof f !== 'object') {
      rejected.push('field_not_object');
      continue;
    }
    const r = f as Record<string, unknown>;
    const key = r.key as MetricKey;
    if (typeof r.key !== 'string' || !(METRIC_KEYS as readonly string[]).includes(r.key)) {
      rejected.push(`unknown_key:${String(r.key)}`);
      continue;
    }
    if (r.value === null || r.value === undefined) continue; // explicitly not found
    if (typeof r.value !== 'number' || !Number.isFinite(r.value)) {
      rejected.push(`${key}:not_a_number`);
      continue;
    }
    const wantsGlucoseUnit = key === 'mean_glucose' || key === 'sd';
    const unitOk = typeof r.unit === 'string' && (wantsGlucoseUnit ? parseGlucoseUnit(r.unit) === unit : r.unit.trim() === '%');
    if (!unitOk) {
      rejected.push(`${key}:unexpected_unit`);
      continue;
    }
    const [lo, hi] = plausibleRange(key, unit);
    if (r.value < lo || r.value > hi) {
      rejected.push(`${key}:out_of_range`);
      continue;
    }
    if (out.has(key)) {
      dupes.add(key);
      continue;
    }
    out.set(key, {
      key,
      value: r.value,
      unit: r.unit as string,
      page: typeof r.page === 'number' && Number.isInteger(r.page) ? r.page : null,
      label: typeof r.label === 'string' ? r.label.slice(0, 120) : null,
    });
  }
  for (const k of dupes) {
    out.delete(k);
    rejected.push(`${k}:duplicate`);
  }
  return { glucose_unit: unit, fields: [...out.values()], rejected };
}

/** Basic structural checks on an uploaded PDF (base64). */
export function checkPdfBase64(b64: unknown, maxBytes: number): { ok: true; bytes: number } | { ok: false; error: string } {
  if (typeof b64 !== 'string' || b64.length === 0) return { ok: false, error: 'empty' };
  if (!/^[A-Za-z0-9+/=\s]+$/.test(b64)) return { ok: false, error: 'not_base64' };
  const bytes = Math.floor((b64.replace(/\s/g, '').length * 3) / 4);
  if (bytes > maxBytes) return { ok: false, error: 'too_large' };
  const head = atob(b64.replace(/\s/g, '').slice(0, 24));
  if (!head.includes('%PDF-')) return { ok: false, error: 'not_pdf' };
  return { ok: true, bytes };
}
