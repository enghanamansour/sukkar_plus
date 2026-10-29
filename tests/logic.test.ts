import { describe, expect, it } from 'vitest';
import {
  compareMetric, findPreviousComparable, generateDoctorQuestions, reportCompatibility, detectSafetyLevel, isDoseRequest,
  type StoredReport,
} from '../supabase/functions/_shared/core/index.ts';

const m = (metric_key: string, value: number | null, status: StoredReport['metrics'][number]['status'] = 'extracted', unit = '%') =>
  ({ metric_key, value, unit, status });

function report(id: string, start: string, end: string, days: number, metrics: StoredReport['metrics'], extra: Partial<StoredReport> = {}): StoredReport {
  return { id, report_kind: 'cgm_agp', status: 'processed', period_start: start, period_end: end, period_days: days, is_demo: false, metrics, ...extra };
}

const aug = report('aug', '2026-08-01', '2026-08-30', 30, [
  m('tir', 45), m('tbr_level1', 11), m('tbr_level2', 10), m('tbr_total', 21, 'calculated'), m('tar_level1', 22), m('tar_level2', 12),
  m('tar_total', 34, 'calculated'), m('mean_glucose', 168, 'extracted', 'mg/dL'), m('gmi', 7.4), m('cv', 50, 'uncertain'), m('sd', 58, 'extracted', 'mg/dL'),
  m('cgm_active', null, 'unavailable'), m('automated_mode', 65), m('setting_target_glucose', 110, 'extracted', 'mg/dL'), m('setting_ic_ratio', 10, 'extracted', 'g/U'),
]);
const jul14 = report('jul', '2026-07-15', '2026-07-28', 14, [m('tir', 44), m('tbr_total', 20, 'calculated'), m('tbr_level2', 9)]);
const jun = report('jun', '2026-06-01', '2026-06-30', 30, [m('tir', 41), m('tbr_total', 20, 'calculated'), m('tbr_level2', 9)]);

describe('comparison rules', () => {
  it('refuses overlapping, demo-mixed and non-CGM comparisons', () => {
    expect(reportCompatibility(aug, report('x', '2026-08-15', '2026-09-10', 27, [])).level).toBe('incompatible');
    expect(reportCompatibility(aug, { ...jun, is_demo: true }).reasons).toContain('demo_mixed');
    expect(reportCompatibility(aug, { ...jun, report_kind: 'lab' }).level).toBe('incompatible');
    expect(reportCompatibility(aug, { ...jun, period_start: null }).reasons).toContain('missing_period');
  });
  it('labels clearly different period lengths as limited', () => {
    const c = reportCompatibility(aug, jul14);
    expect(c.level).toBe('limited');
    expect(c.reasons).toContain('different_period_length');
  });
  it('prefers the most recent fully compatible earlier report', () => {
    const p = findPreviousComparable(aug, [aug, jul14, jun]);
    expect(p?.report.id).toBe('jun');
    expect(p?.compat.level).toBe('compatible');
    expect(findPreviousComparable(aug, [aug, jul14])?.compat.level).toBe('limited');
    expect(findPreviousComparable(aug, [aug])).toBeNull();
  });
  it('computes direction using metric polarity and meaningful thresholds', () => {
    const c = reportCompatibility(aug, jun);
    expect(compareMetric('tir', aug, jun, c)).toMatchObject({ delta: 4, direction: 'stable', comparable: true });
    const better = report('b', '2026-05-01', '2026-05-30', 30, [m('tir', 30)]);
    expect(compareMetric('tir', aug, better, reportCompatibility(aug, better)).direction).toBe('improved');
    expect(compareMetric('gmi', aug, jun, c).comparable).toBe(false); // missing in June → not compared
  });
  it('does not compare metrics with different units', () => {
    const mm = report('mm', '2026-05-01', '2026-05-30', 30, [m('mean_glucose', 9.3, 'extracted', 'mmol/L')]);
    expect(compareMetric('mean_glucose', aug, mm, reportCompatibility(aug, mm))).toMatchObject({ comparable: false, reason: 'unit_mismatch' });
  });
});

describe('doctor questions', () => {
  it('generates 3–8 grounded questions with evidence', () => {
    const qs = generateDoctorQuestions({ current: aug, previous: null, labs: [], lang: 'ar' });
    expect(qs.length).toBeGreaterThanOrEqual(3);
    expect(qs.length).toBeLessThanOrEqual(8);
    for (const q of qs) {
      expect(q.question.length).toBeGreaterThan(10);
      expect(q.rationale.length).toBeGreaterThan(10);
    }
    const keys = qs.map((q) => q.rule_key);
    expect(keys).toContain('hypo_time');
    expect(keys).toContain('tir_low');
    expect(keys).toContain('hba1c_missing');
    expect(keys).toContain('cgm_active_missing');
    const hypo = qs.find((q) => q.rule_key === 'hypo_time')!;
    expect(hypo.question).toContain('21');
    expect(hypo.evidence.map((e) => e.metric_key)).toContain('tbr_level2');
    // CV was uncertain → the variability question is flagged
    expect(qs.find((q) => q.rule_key === 'variability')?.is_uncertain).toBe(true);
    // Data gaps are always uncertain
    expect(qs.filter((q) => q.basis === 'data_gap').every((q) => q.is_uncertain)).toBe(true);
  });
  it('uses a nearby lab HbA1c, kept distinct from GMI, and only same-kind (demo/real) labs', () => {
    const qs = generateDoctorQuestions({ current: aug, previous: null, labs: [{ value: 8.2, measured_on: '2026-08-02', source: 'manual', is_demo: false }], lang: 'en' });
    const q = qs.find((x) => x.rule_key === 'gmi_vs_hba1c')!;
    expect(q.question).toContain('7.4');
    expect(q.question).toContain('8.2');
    expect(q.evidence.find((e) => e.role === 'lab')?.metric_key).toBe('hba1c');
    const demoOnly = generateDoctorQuestions({ current: aug, previous: null, labs: [{ value: 8.2, measured_on: '2026-08-02', source: 'demo', is_demo: true }], lang: 'en' });
    expect(demoOnly.find((x) => x.rule_key === 'hba1c_missing')).toBeTruthy();
  });
  it('adds a comparison question only for meaningful changes and flags limited comparisons', () => {
    const prev = report('may', '2026-05-01', '2026-05-30', 30, [m('tir', 30), m('tbr_total', 8, 'calculated')]);
    const qs = generateDoctorQuestions({ current: aug, previous: { report: prev, compat: reportCompatibility(aug, prev) }, labs: [], lang: 'ar' });
    const t = qs.find((q) => q.rule_key === 'trend_change')!;
    expect(t.basis).toBe('comparison');
    expect(t.evidence.some((e) => e.role === 'previous')).toBe(true);
    const lim = generateDoctorQuestions({ current: aug, previous: { report: { ...prev, period_days: 14, period_start: '2026-05-17' }, compat: { level: 'limited', reasons: ['different_period_length'] } }, labs: [], lang: 'ar' });
    expect(lim.find((q) => q.rule_key === 'trend_change')?.is_uncertain).toBe(true);
    const none = generateDoctorQuestions({ current: aug, previous: { report: jun, compat: reportCompatibility(aug, jun) }, labs: [], lang: 'ar' });
    expect(none.find((q) => q.rule_key === 'trend_change')).toBeUndefined(); // 41 → 45 is below the 5-point threshold
  });
  it('asks a maintenance question when results meet targets', () => {
    const good = report('g', '2026-08-01', '2026-08-14', 14, [m('tir', 84), m('tbr_level2', 0.5), m('tbr_total', 2, 'calculated'), m('tar_level2', 1), m('tar_total', 14, 'calculated'), m('cv', 30), m('gmi', 6.4), m('cgm_active', 95)]);
    const qs = generateDoctorQuestions({ current: good, previous: null, labs: [{ value: 6.5, measured_on: '2026-08-10', source: 'manual', is_demo: false }], lang: 'ar' });
    expect(qs.map((q) => q.rule_key)).toEqual(['on_target']);
  });
});

describe('safety layer', () => {
  it('detects emergencies in Arabic and English', () => {
    expect(detectSafetyLevel('أبوي فاقد الوعي والسكر منخفض')).toBe('emergency');
    expect(detectSafetyLevel('ولدي يتشنج وش أسوي')).toBe('emergency');
    expect(detectSafetyLevel('she is unconscious after a low')).toBe('emergency');
    expect(detectSafetyLevel('ما يقدر يبلع')).toBe('emergency');
    expect(detectSafetyLevel('عندي قيء مستمر والسكر عالي')).toBe('urgent');
    expect(detectSafetyLevel('وش معنى الوقت ضمن النطاق؟')).toBeNull();
  });
  it('detects dose-change requests', () => {
    expect(isDoseRequest('كم وحدة انسولين آخذ قبل العشاء؟')).toBe(true);
    expect(isDoseRequest('Should I increase my dose?')).toBe(true);
    expect(isDoseRequest('اشرح لي GMI')).toBe(false);
  });
});
