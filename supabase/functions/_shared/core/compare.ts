/**
 * Historical comparison rules. Two reports are compared only when the comparison is meaningful:
 * both CGM/AGP reports, non-overlapping periods with known dates, same target range, both real (or both demo)
 * and similar period lengths. Anything else is labelled "limited" or refused — never silently compared.
 */
import { METRIC_BY_KEY } from './catalog.ts';

export interface StoredMetric {
  metric_key: string;
  value: number | null;
  unit: string | null;
  status: 'extracted' | 'calculated' | 'unavailable' | 'uncertain';
  source_page?: number | null;
  source_label?: string | null;
  note?: string | null;
}

export interface StoredReport {
  id: string;
  report_kind: 'cgm_agp' | 'lab' | 'unknown';
  status?: string;
  period_start: string | null;
  period_end: string | null;
  period_days: number | null;
  is_demo: boolean;
  file_name?: string;
  quality?: { target_range?: { low: number; high: number; unit: string } | null } & Record<string, unknown>;
  metrics: StoredMetric[];
}

export type CompatLevel = 'compatible' | 'limited' | 'incompatible';
export interface Compatibility { level: CompatLevel; reasons: string[] }

export function reportCompatibility(a: StoredReport, b: StoredReport): Compatibility {
  const reasons: string[] = [];
  if (a.id === b.id) return { level: 'incompatible', reasons: ['same_report'] };
  if (a.report_kind !== 'cgm_agp' || b.report_kind !== 'cgm_agp') return { level: 'incompatible', reasons: ['not_cgm'] };
  if (a.is_demo !== b.is_demo) return { level: 'incompatible', reasons: ['demo_mixed'] };
  if (!a.period_start || !a.period_end || !b.period_start || !b.period_end || !a.period_days || !b.period_days) {
    return { level: 'incompatible', reasons: ['missing_period'] };
  }
  if (a.period_start <= b.period_end && b.period_start <= a.period_end) return { level: 'incompatible', reasons: ['overlapping_periods'] };
  const ta = a.quality?.target_range, tb = b.quality?.target_range;
  if (ta && tb && (ta.low !== tb.low || ta.high !== tb.high || ta.unit !== tb.unit)) return { level: 'incompatible', reasons: ['different_target_range'] };
  if (Math.min(a.period_days, b.period_days) < 10) reasons.push('short_period');
  if (Math.min(a.period_days, b.period_days) / Math.max(a.period_days, b.period_days) < 0.75) reasons.push('different_period_length');
  return { level: reasons.length ? 'limited' : 'compatible', reasons };
}

export function compatReasonText(reason: string, lang: 'ar' | 'en'): string {
  const ar: Record<string, string> = {
    same_report: 'نفس التقرير', not_cgm: 'أحد التقريرين ليس تقرير حساس (AGP)', demo_mixed: 'لا نقارن بيانات العرض التجريبي ببيانات حقيقية',
    missing_period: 'فترة أحد التقريرين غير معروفة', overlapping_periods: 'الفترتان متداخلتان', different_target_range: 'النطاق المستهدف مختلف',
    short_period: 'أحد التقريرين يغطي أقل من 10 أيام', different_period_length: 'مدة التقريرين مختلفة بشكل واضح',
  };
  const en: Record<string, string> = {
    same_report: 'Same report', not_cgm: 'One report is not a CGM/AGP report', demo_mixed: 'Demo data is never compared with real data',
    missing_period: 'A reporting period is unknown', overlapping_periods: 'The periods overlap', different_target_range: 'Different target ranges',
    short_period: 'One report covers fewer than 10 days', different_period_length: 'The reports cover clearly different lengths of time',
  };
  return (lang === 'ar' ? ar : en)[reason] ?? reason;
}

/** The most recent earlier report that can be compared — preferring fully compatible over limited. */
export function findPreviousComparable(current: StoredReport, all: StoredReport[]): { report: StoredReport; compat: Compatibility } | null {
  if (!current.period_start) return null;
  const earlier = all
    .filter((r) => r.id !== current.id && r.period_end && r.period_end < current.period_start! && (r.status ?? 'processed') === 'processed')
    .sort((x, y) => (y.period_end! > x.period_end! ? 1 : -1))
    .map((r) => ({ report: r, compat: reportCompatibility(current, r) }))
    .filter((x) => x.compat.level !== 'incompatible');
  return earlier.find((x) => x.compat.level === 'compatible') ?? earlier[0] ?? null;
}

export interface MetricComparison {
  key: string;
  comparable: boolean;
  reason?: 'missing' | 'unit_mismatch';
  current: number | null;
  previous: number | null;
  unit: string | null;
  delta: number | null;
  direction: 'improved' | 'worsened' | 'stable' | 'up' | 'down' | null;
  uncertain: boolean;
}

export function getMetric(r: StoredReport, key: string): StoredMetric | undefined {
  return r.metrics.find((m) => m.metric_key === key);
}

export function compareMetric(key: string, current: StoredReport, previous: StoredReport, compat: Compatibility): MetricComparison {
  const a = getMetric(current, key), b = getMetric(previous, key);
  const base = { key, current: a?.value ?? null, previous: b?.value ?? null, unit: a?.unit ?? b?.unit ?? null, delta: null, direction: null };
  if (!a || !b || a.value == null || b.value == null || a.status === 'unavailable' || b.status === 'unavailable') {
    return { ...base, comparable: false, reason: 'missing', uncertain: true };
  }
  if ((a.unit ?? '') !== (b.unit ?? '')) return { ...base, comparable: false, reason: 'unit_mismatch', uncertain: true };
  const def = METRIC_BY_KEY[key];
  const delta = Math.round((a.value - b.value) * 10) / 10;
  const threshold = def?.meaningfulDelta ?? 0;
  let direction: MetricComparison['direction'];
  if (Math.abs(delta) < threshold) direction = 'stable';
  else if (!def || def.polarity === 'neutral') direction = delta > 0 ? 'up' : 'down';
  else direction = (delta > 0) === (def.polarity === 'higher_better') ? 'improved' : 'worsened';
  return {
    ...base, delta, direction, comparable: true,
    uncertain: a.status === 'uncertain' || b.status === 'uncertain' || compat.level !== 'compatible',
  };
}

export const COMPARE_KEYS = ['tir', 'tbr_level2', 'tbr_total', 'tar_level2', 'tar_total', 'mean_glucose', 'gmi', 'cv'];
