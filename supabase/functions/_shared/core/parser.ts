/**
 * Report text → structured metrics.
 *
 * Input is the text of each PDF page (index 0 = page 1). The parser:
 *  - only records values it actually finds, with the page and the matched text as source;
 *  - marks values it calculates (e.g. total time below range) as `calculated`;
 *  - marks expected-but-missing metrics as `unavailable` (never guessed);
 *  - runs consistency checks and downgrades a value to `uncertain` when the report contradicts itself.
 * Pure TypeScript with no runtime dependencies so it runs in Deno (Edge Functions), Node (tests) and browsers.
 */
import { EXPECTED_CGM_KEYS, METRIC_BY_KEY, gmiFromMean, type MetricCategory, type MetricStatus } from './catalog.ts';

export interface ExtractedMetric {
  key: string;
  category: MetricCategory;
  value: number | null;
  valueText: string | null;
  unit: string | null;
  status: MetricStatus;
  sourcePage: number | null;
  sourceLabel: string | null;
  note: string | null;
}

export type CheckLevel = 'pass' | 'warn' | 'fail';
export interface QualityCheck {
  key: string;
  level: CheckLevel;
  params?: Record<string, string | number | null>;
}

export interface ParsedReport {
  kind: 'cgm_agp' | 'lab' | 'unknown';
  sourceSystem: string | null;
  device: string | null;
  nameOnReport: string | null;
  generatedOn: string | null; // ISO yyyy-mm-dd
  periodStart: string | null;
  periodEnd: string | null;
  periodDays: number | null;
  statedDays: number | null;
  targetRange: { low: number; high: number; unit: string } | null;
  dateOrder: 'dmy' | 'mdy' | 'assumed_dmy' | 'iso' | null;
  pageCount: number;
  metrics: ExtractedMetric[];
  checks: QualityCheck[];
}

export class ReportParseError extends Error {
  constructor(public code: 'no_text' | 'no_metrics', message: string) {
    super(message);
  }
}

const NUM = '(\\d{1,3}(?:[.,]\\d+)?)';
const toNum = (s: string) => Number(s.replace(',', '.'));
const clean = (s: string) => s.replace(/\s+/g, ' ').trim().slice(0, 160);

// ───────────────────────── dates ─────────────────────────
const MONTHS: Record<string, number> = {
  jan: 1, feb: 2, mar: 3, apr: 4, may: 5, jun: 6, jul: 7, aug: 8, sep: 9, sept: 9, oct: 10, nov: 11, dec: 12,
};
const DATE_TOKEN =
  '(\\d{4}-\\d{2}-\\d{2}|\\d{1,2}[/.-]\\d{1,2}[/.-]\\d{4}|\\d{1,2}\\s+[A-Za-z]{3,9}\\.?\\s+\\d{4}|[A-Za-z]{3,9}\\.?\\s+\\d{1,2},?\\s+\\d{4})';

function iso(y: number, m: number, d: number): string | null {
  if (m < 1 || m > 12 || d < 1 || d > 31 || y < 1990 || y > 2100) return null;
  const dt = new Date(Date.UTC(y, m - 1, d));
  if (dt.getUTCMonth() !== m - 1) return null;
  return dt.toISOString().slice(0, 10);
}

/** Decide day/month order from every numeric date in the document. */
function detectDateOrder(all: string): ParsedReport['dateOrder'] {
  let dmy = false, mdy = false, any = false;
  for (const m of all.matchAll(/\b(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})\b/g)) {
    any = true;
    if (Number(m[1]) > 12) dmy = true;
    if (Number(m[2]) > 12) mdy = true;
  }
  if (dmy && !mdy) return 'dmy';
  if (mdy && !dmy) return 'mdy';
  if (any) return 'assumed_dmy';
  return /\d{4}-\d{2}-\d{2}/.test(all) ? 'iso' : null;
}

function parseDate(tok: string, order: ParsedReport['dateOrder']): string | null {
  tok = tok.trim();
  let m = tok.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (m) return iso(+m[1], +m[2], +m[3]);
  m = tok.match(/^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$/);
  if (m) return order === 'mdy' ? iso(+m[3], +m[1], +m[2]) : iso(+m[3], +m[2], +m[1]);
  m = tok.match(/^(\d{1,2})\s+([A-Za-z]{3,9})\.?\s+(\d{4})$/);
  if (m && MONTHS[m[2].slice(0, 3).toLowerCase()]) return iso(+m[3], MONTHS[m[2].slice(0, 3).toLowerCase()], +m[1]);
  m = tok.match(/^([A-Za-z]{3,9})\.?\s+(\d{1,2}),?\s+(\d{4})$/);
  if (m && MONTHS[m[1].slice(0, 3).toLowerCase()]) return iso(+m[3], MONTHS[m[1].slice(0, 3).toLowerCase()], +m[2]);
  return null;
}

export function daysBetweenInclusive(a: string, b: string): number {
  return Math.round((Date.parse(b) - Date.parse(a)) / 86400000) + 1;
}

// ───────────────────────── search helpers ─────────────────────────
interface Hit { value: string; unit?: string; page: number; label: string; extra?: string[] }

function findFirst(pages: string[], re: RegExp, valueGroup = 1, unitGroup?: number): Hit | null {
  for (let p = 0; p < pages.length; p++) {
    const m = pages[p].match(re);
    if (m && m[valueGroup] !== undefined) {
      return { value: m[valueGroup], unit: unitGroup ? m[unitGroup] : undefined, page: p + 1, label: clean(m[0]), extra: m.slice(1) };
    }
  }
  return null;
}

const SOURCE_SYSTEMS = ['Omnipod Discover', 'Dexcom Clarity', 'LibreView', 'CareLink', 'Glooko', 'Tidepool', 'Diasend', 'Eversense'];

const RANGE_SLOTS: Array<{ re: RegExp; key: string }> = [
  { re: /^very\s*high/i, key: 'tar_level2' },
  { re: /^very\s*low/i, key: 'tbr_level2' },
  { re: /^(target|in\s*range)/i, key: 'tir' },
  { re: /^high/i, key: 'tar_level1' },
  { re: /^low/i, key: 'tbr_level1' },
];

/** Table layout: one header line naming ≥3 ranges, followed by a line with the same number of percentages. */
function extractRangeTable(pages: string[]): Array<{ key: string; value: string; page: number; label: string }> {
  for (let p = 0; p < pages.length; p++) {
    const lines = pages[p].split('\n').map((l) => l.trim()).filter(Boolean);
    for (let i = 0; i < lines.length - 1; i++) {
      const labels = [...lines[i].matchAll(/(very\s+high|very\s+low|target|in\s+range|high|low)/gi)].map((m) => m[1]);
      if (labels.length < 3) continue;
      const keys = labels.map((l) => RANGE_SLOTS.find((s) => s.re.test(l))?.key).filter(Boolean) as string[];
      if (new Set(keys).size !== keys.length) continue;
      const values = [...lines[i + 1].matchAll(/(\d{1,3}(?:[.,]\d+)?)\s*%/g)].map((m) => m[1]);
      if (values.length !== keys.length) continue;
      return keys.map((key, j) => ({ key, value: values[j], page: p + 1, label: clean(`${labels[j]} … ${values[j]}%`) }));
    }
  }
  return [];
}

/** Inline layout, e.g. "Time in Range (70-180 mg/dL): 45%" or "Very Low (<54 mg/dL) 2%". */
const RANGE_INLINE: Record<string, RegExp> = {
  tar_level2: /very\s+high[^\n%\d]*(?:>|above|over)\s*250[^\n%\d]*?(?:mg\/dl)?[^\n%\d]*?(\d{1,3}(?:[.,]\d+)?)\s*%/i,
  tbr_level2: /very\s+low[^\n%\d]*(?:<|below|under)\s*54[^\n%\d]*?(?:mg\/dl)?[^\n%\d]*?(\d{1,3}(?:[.,]\d+)?)\s*%/i,
  tir: /(?:time\s+in\s+range|in\s+range|target)[^\n%\d]*70\s*[-–]\s*180[^\n%\d]*?(?:mg\/dl)?[^\n%\d]*?(\d{1,3}(?:[.,]\d+)?)\s*%/i,
  tar_level1: /(?<!very\s)high[^\n%\d]*181\s*[-–]\s*250[^\n%\d]*?(?:mg\/dl)?[^\n%\d]*?(\d{1,3}(?:[.,]\d+)?)\s*%/i,
  tbr_level1: /(?<!very\s)low[^\n%\d]*54\s*[-–]\s*69[^\n%\d]*?(?:mg\/dl)?[^\n%\d]*?(\d{1,3}(?:[.,]\d+)?)\s*%/i,
};

const BOUNDS: Record<string, [number, number]> = {
  pct: [0, 100], mean_glucose_mg: [40, 400], mean_glucose_mmol: [2.2, 22.2], gmi: [4, 14], sd_mg: [0, 200], sd_mmol: [0, 11], hba1c: [3, 20],
};

function metric(key: string, partial: Partial<ExtractedMetric>): ExtractedMetric {
  const def = METRIC_BY_KEY[key];
  return {
    key, category: def?.category ?? 'glycemic', value: null, valueText: null, unit: def?.unit ?? null,
    status: 'extracted', sourcePage: null, sourceLabel: null, note: null, ...partial,
  };
}

function normUnit(u: string | undefined): string | null {
  if (!u) return null;
  return /mmol/i.test(u) ? 'mmol/L' : 'mg/dL';
}

// ───────────────────────── main ─────────────────────────
export function parseReportPages(pages: string[]): ParsedReport {
  const textChars = pages.join('').replace(/\s/g, '').length;
  if (textChars < 40) {
    throw new ReportParseError('no_text', 'The PDF has no readable text layer (it may be a scanned image).');
  }
  const all = pages.join('\n');
  const dateOrder = detectDateOrder(all);
  const metrics = new Map<string, ExtractedMetric>();
  const checks: QualityCheck[] = [];
  const put = (m: ExtractedMetric) => { if (!metrics.has(m.key)) metrics.set(m.key, m); };

  // Header information
  const sourceSystem = SOURCE_SYSTEMS.find((s) => all.toLowerCase().includes(s.toLowerCase())) ?? null;
  const deviceHit = findFirst(pages, /Device(?:s)?\s+Used\s*:?\s*([^\n]+?)(?=\s{2,}|\s+Automated|\s+Sensor|\n|$)/i);
  const device = deviceHit ? clean(deviceHit.value) : null;

  let nameOnReport: string | null = null;
  const explicitName = findFirst(pages, /(?:Patient(?:\s+Name)?|Name|اسم المريض)\s*:\s*([^\n]{3,60}?)(?=\s{2,}|\n|$)/i);
  if (explicitName) nameOnReport = clean(explicitName.value);
  else if (sourceSystem) {
    const first = (pages[0] ?? '').split('\n')[0] ?? '';
    const idx = first.toLowerCase().indexOf(sourceSystem.toLowerCase());
    const cand = idx > 0 ? first.slice(0, idx).trim() : '';
    if (/^[A-Za-z؀-ۿ' .-]{3,60}$/.test(cand)) nameOnReport = cand;
  }

  const genHit = findFirst(pages, new RegExp(`(?:Report\\s+Generated|Generated(?:\\s+on)?|Printed(?:\\s+on)?|Report\\s+Date)\\s*:?\\s*${DATE_TOKEN}`, 'i'));
  const generatedOn = genHit ? parseDate(genHit.value, dateOrder) : null;

  const periodHit = findFirst(
    pages,
    new RegExp(`(?:Date\\s+Range|Reporting\\s+Period|Report\\s+Period|Period|Dates?)\\s*:?\\s*${DATE_TOKEN}\\s*(?:-|–|—|to|through|إلى)\\s*${DATE_TOKEN}`, 'i'),
  );
  let periodStart: string | null = null, periodEnd: string | null = null, periodDays: number | null = null;
  if (periodHit?.extra) {
    periodStart = parseDate(periodHit.extra[0], dateOrder);
    periodEnd = parseDate(periodHit.extra[1], dateOrder);
    if (periodStart && periodEnd && periodStart <= periodEnd) periodDays = daysBetweenInclusive(periodStart, periodEnd);
    else { periodStart = periodEnd = null; }
  }
  const statedHit = findFirst(pages, /\b(\d{1,3})\s*-?\s*Day\s+(?:AGP|Summary|Report|Overview)/i);
  const statedDays = statedHit ? Number(statedHit.value) : null;

  const trHit = findFirst(pages, /Target\s+Range\s*:?\s*(\d{2,3}(?:\.\d)?)\s*[-–]\s*(\d{2,3}(?:\.\d)?)\s*(mg\/dl|mmol\/l)/i);
  const targetRange = trHit?.extra ? { low: toNum(trHit.extra[0]), high: toNum(trHit.extra[1]), unit: normUnit(trHit.extra[2])! } : null;

  // Time in ranges
  const table = extractRangeTable(pages);
  for (const r of table) put(metric(r.key, { value: toNum(r.value), valueText: `${r.value}%`, unit: '%', sourcePage: r.page, sourceLabel: r.label }));
  for (const [key, re] of Object.entries(RANGE_INLINE)) {
    if (metrics.has(key)) continue;
    const h = findFirst(pages, re);
    if (h) put(metric(key, { value: toNum(h.value), valueText: `${h.value}%`, unit: '%', sourcePage: h.page, sourceLabel: h.label }));
  }

  // Glycemic & variability
  const meanHit = findFirst(pages, new RegExp(`(?:Average|Mean)\\s+(?:Sensor\\s+)?Glucose\\s*:?[^\\d\\n]{0,15}${NUM}\\s*(mg\\/dl|mmol\\/l)`, 'i'), 1, 2);
  if (meanHit) put(metric('mean_glucose', { value: toNum(meanHit.value), valueText: `${meanHit.value} ${normUnit(meanHit.unit)}`, unit: normUnit(meanHit.unit), sourcePage: meanHit.page, sourceLabel: meanHit.label }));

  const gmiHit = findFirst(pages, new RegExp(`(?:\\bGMI\\b|Glucose\\s+Management\\s+Indicator)[^\\d\\n]{0,30}?${NUM}\\s*%`, 'i'));
  if (gmiHit) put(metric('gmi', { value: toNum(gmiHit.value), valueText: `${gmiHit.value}%`, sourcePage: gmiHit.page, sourceLabel: gmiHit.label }));

  const cvHit = findFirst(pages, new RegExp(`(?:Coefficient\\s+of\\s+Variation|Variability\\s*\\(\\s*%?CV\\s*\\)|%CV|\\bCV\\b)[^\\d\\n]{0,20}?${NUM}\\s*%`, 'i'));
  if (cvHit) put(metric('cv', { value: toNum(cvHit.value), valueText: `${cvHit.value}%`, sourcePage: cvHit.page, sourceLabel: cvHit.label }));

  const sdHit = findFirst(pages, new RegExp(`(?:Standard\\s+Deviation|\\bSD\\b)[^\\d\\n]{0,20}?${NUM}\\s*(mg\\/dl|mmol\\/l)`, 'i'), 1, 2);
  if (sdHit) put(metric('sd', { value: toNum(sdHit.value), valueText: `${sdHit.value} ${normUnit(sdHit.unit)}`, unit: normUnit(sdHit.unit), sourcePage: sdHit.page, sourceLabel: sdHit.label }));

  const activeHit = findFirst(pages, new RegExp(`(?:%?\\s*Time\\s+CGM\\s+(?:is\\s+)?Active|CGM\\s+Active|Sensor\\s+(?:Wear|Usage|Active)(?:\\s+Time)?)[^\\d\\n]{0,20}?${NUM}\\s*%`, 'i'));
  if (activeHit) put(metric('cgm_active', { value: toNum(activeHit.value), valueText: `${activeHit.value}%`, sourcePage: activeHit.page, sourceLabel: activeHit.label }));

  const autoHit = findFirst(pages, new RegExp(`Automated\\s+Mode(?:\\s+(?:Wear\\s+)?Time)?[^\\d\\n]{0,20}?${NUM}\\s*(%+)`, 'i'));
  if (autoHit) {
    const malformed = (autoHit.extra?.[1] ?? '%').length > 1;
    put(metric('automated_mode', {
      value: toNum(autoHit.value), valueText: `${autoHit.value}%`, sourcePage: autoHit.page, sourceLabel: autoHit.label,
      note: malformed ? 'Printed with a duplicated percent sign in the source PDF; value read as a percentage.' : null,
    }));
  }

  // Lab HbA1c — never confused with GMI or "estimated A1C"
  for (let p = 0; p < pages.length && !metrics.has('hba1c'); p++) {
    for (const m of pages[p].matchAll(new RegExp(`(estimated\\s+|e)?(?:HbA1c|HbA1C|A1C|Glycated\\s+Ha?emoglobin|السكر التراكمي)(?:\\s+Level)?[^\\d\\n]{0,25}?${NUM}\\s*%`, 'gi'))) {
      if (m[1]) continue; // "estimated A1C"/"eA1C" is a sensor estimate, not a lab HbA1c
      put(metric('hba1c', { value: toNum(m[2]), valueText: `${m[2]}%`, sourcePage: p + 1, sourceLabel: clean(m[0]) }));
      break;
    }
  }

  // Device settings (informational only)
  const tg = findFirst(pages, /Target\s+Glucose\s*:?\s*(\d{2,3})\s*mg\/dl/i);
  if (tg) put(metric('setting_target_glucose', { value: toNum(tg.value), valueText: `${tg.value} mg/dL`, sourcePage: tg.page, sourceLabel: tg.label }));
  const ic = findFirst(pages, /(?:IC|I:C|Insulin[- ]to[- ]Carb(?:ohydrate)?)\s+Ratio\s*:?\s*1\s*U\s*:\s*(\d{1,3}(?:\.\d+)?)\s*g/i);
  if (ic) put(metric('setting_ic_ratio', { value: toNum(ic.value), valueText: `1 U : ${ic.value} g`, sourcePage: ic.page, sourceLabel: ic.label }));
  const mb = findFirst(pages, /Max(?:imum)?\s+Basal(?:\s+Rate)?\s*:?\s*(\d{1,2}(?:\.\d+)?)\s*U\/h/i);
  if (mb) put(metric('setting_max_basal', { value: toNum(mb.value), valueText: `${mb.value} U/hr`, sourcePage: mb.page, sourceLabel: mb.label }));

  // ── Kind
  const hasCgm = ['tir', 'mean_glucose', 'gmi', 'tbr_level1', 'tar_level1'].some((k) => metrics.has(k));
  const kind: ParsedReport['kind'] = hasCgm ? 'cgm_agp' : metrics.has('hba1c') ? 'lab' : 'unknown';
  if (kind === 'unknown') {
    throw new ReportParseError('no_metrics', 'No recognised diabetes metrics were found in this PDF.');
  }

  // ── Plausibility
  const pctKeys = ['tir', 'tar_level1', 'tar_level2', 'tbr_level1', 'tbr_level2', 'cv', 'cgm_active', 'automated_mode'];
  for (const k of pctKeys) {
    const m = metrics.get(k);
    if (m && m.value !== null && (m.value < BOUNDS.pct[0] || m.value > BOUNDS.pct[1])) {
      m.status = 'uncertain'; m.note = 'Value outside the possible 0–100% range.';
      checks.push({ key: 'implausible_value', level: 'fail', params: { metric: k, value: m.value } });
    }
  }
  const plaus = (k: string, b: [number, number]) => {
    const m = metrics.get(k);
    if (m && m.value !== null && (m.value < b[0] || m.value > b[1])) {
      m.status = 'uncertain'; m.note = `Value outside the plausible range ${b[0]}–${b[1]}.`;
      checks.push({ key: 'implausible_value', level: 'fail', params: { metric: k, value: m.value } });
    }
  };
  const meanUnit = metrics.get('mean_glucose')?.unit;
  plaus('mean_glucose', meanUnit === 'mmol/L' ? BOUNDS.mean_glucose_mmol : BOUNDS.mean_glucose_mg);
  plaus('sd', metrics.get('sd')?.unit === 'mmol/L' ? BOUNDS.sd_mmol : BOUNDS.sd_mg);
  plaus('gmi', BOUNDS.gmi);
  plaus('hba1c', BOUNDS.hba1c);

  if (kind === 'cgm_agp') {
    // ── Calculated totals
    const sumOf = (a: string, b: string, out: string, label: string) => {
      const x = metrics.get(a), y = metrics.get(b);
      if (x?.value != null && y?.value != null) {
        const v = Math.round((x.value + y.value) * 10) / 10;
        put(metric(out, {
          value: v, valueText: `${v}%`, status: x.status === 'uncertain' || y.status === 'uncertain' ? 'uncertain' : 'calculated',
          sourcePage: x.sourcePage, sourceLabel: label, note: `Calculated by Adeed: ${x.value}% + ${y.value}%.`,
        }));
      }
    };
    sumOf('tbr_level1', 'tbr_level2', 'tbr_total', 'Low + Very low');
    sumOf('tar_level1', 'tar_level2', 'tar_total', 'High + Very high');

    // ── Ranges should add up to ~100%
    const rangeKeys = ['tar_level2', 'tar_level1', 'tir', 'tbr_level1', 'tbr_level2'];
    if (rangeKeys.every((k) => metrics.get(k)?.value != null)) {
      const total = Math.round(rangeKeys.reduce((s, k) => s + (metrics.get(k)!.value as number), 0) * 10) / 10;
      const ok = Math.abs(total - 100) <= 1.5;
      checks.push({ key: 'ranges_sum', level: ok ? 'pass' : 'warn', params: { total } });
      if (!ok) for (const k of rangeKeys) { const m = metrics.get(k)!; if (m.status === 'extracted') { m.status = 'uncertain'; m.note = `Time-in-range values add up to ${total}% instead of 100%.`; } }
    } else {
      checks.push({ key: 'ranges_incomplete', level: 'warn' });
    }

    // ── GMI should match the mean glucose (GMI formula, mg/dL)
    const mean = metrics.get('mean_glucose'), gmi = metrics.get('gmi');
    if (mean?.value != null && gmi?.value != null && mean.unit === 'mg/dL') {
      const expected = gmiFromMean(mean.value);
      const ok = Math.abs(expected - gmi.value) <= 0.3;
      checks.push({ key: 'gmi_consistency', level: ok ? 'pass' : 'warn', params: { reported: gmi.value, expected } });
      if (!ok && gmi.status === 'extracted') { gmi.status = 'uncertain'; gmi.note = `GMI calculated from the reported average glucose would be ≈${expected}%.`; }
    }

    // ── CV should equal SD ÷ mean
    const sd = metrics.get('sd'), cv = metrics.get('cv');
    if (mean?.value && sd?.value != null && cv?.value != null && mean.unit === sd.unit) {
      const expected = Math.round((sd.value / mean.value) * 1000) / 10;
      const ok = Math.abs(expected - cv.value) <= 3;
      checks.push({ key: 'cv_consistency', level: ok ? 'pass' : 'warn', params: { reported: cv.value, expected } });
      if (!ok && cv.status === 'extracted') {
        cv.status = 'uncertain';
        cv.note = `The report's SD (${sd.value}) ÷ average (${mean.value}) gives ≈${expected}%, not ${cv.value}%. Check the original device report.`;
      }
    }

    // ── Data sufficiency
    const active = metrics.get('cgm_active');
    if (active?.value != null) {
      checks.push({ key: 'cgm_active', level: active.value >= 70 ? 'pass' : 'warn', params: { value: active.value } });
    } else {
      checks.push({ key: 'cgm_active_missing', level: 'warn', params: { automated_mode: metrics.get('automated_mode')?.value ?? null } });
    }
    if (periodDays != null) {
      checks.push({ key: 'period_length', level: periodDays >= 14 ? 'pass' : 'warn', params: { days: periodDays } });
      if (statedDays != null && Math.abs(statedDays - periodDays) > 1) {
        checks.push({ key: 'period_mismatch', level: 'warn', params: { stated: statedDays, computed: periodDays } });
      }
    } else {
      checks.push({ key: 'period_missing', level: 'warn' });
    }
    if (targetRange && !(targetRange.unit === 'mg/dL' && targetRange.low === 70 && targetRange.high === 180)) {
      checks.push({ key: 'nonstandard_target', level: 'warn', params: { low: targetRange.low, high: targetRange.high, unit: targetRange.unit } });
    }

    // ── Expected but missing → explicit "unavailable"
    for (const k of EXPECTED_CGM_KEYS) {
      if (!metrics.has(k)) metrics.set(k, metric(k, { status: 'unavailable', note: 'Not found in this report.' }));
    }
  }
  if (dateOrder === 'assumed_dmy') checks.push({ key: 'date_order_assumed', level: 'warn' });

  return {
    kind, sourceSystem, device, nameOnReport, generatedOn, periodStart, periodEnd, periodDays, statedDays, targetRange,
    dateOrder, pageCount: pages.length, metrics: [...metrics.values()], checks,
  };
}

export function qualityScore(checks: QualityCheck[]): 'good' | 'fair' | 'poor' {
  const fails = checks.filter((c) => c.level === 'fail').length;
  const warns = checks.filter((c) => c.level === 'warn').length;
  if (fails > 0 || warns >= 3) return 'poor';
  if (warns > 0) return 'fair';
  return 'good';
}

export function checkMessage(c: QualityCheck, lang: 'ar' | 'en'): string {
  const p = c.params ?? {};
  const ar: Record<string, string> = {
    ranges_sum: c.level === 'pass' ? `مجموع نسب النطاقات ${p.total}% (متسق).` : `مجموع نسب النطاقات ${p.total}% بدل 100%، لذلك اعتبرناها غير مؤكدة.`,
    ranges_incomplete: 'بعض نسب النطاقات غير موجودة في التقرير.',
    gmi_consistency: c.level === 'pass' ? `قيمة GMI (${p.reported}%) متسقة مع متوسط السكر.` : `قيمة GMI (${p.reported}%) لا تتطابق مع المتوقع من متوسط السكر (≈${p.expected}%).`,
    cv_consistency: c.level === 'pass' ? `معامل التذبذب (${p.reported}%) متسق مع SD والمتوسط.` : `معامل التذبذب المطبوع ${p.reported}% لا يتطابق مع SD ÷ المتوسط (≈${p.expected}%). يُنصح بمراجعة تقرير الجهاز الأصلي.`,
    cgm_active: c.level === 'pass' ? `عمل الحساس ${p.value}% من الوقت (كافٍ).` : `عمل الحساس ${p.value}% فقط، أقل من 70% الموصى بها؛ قد لا تمثّل الأرقام الفترة كاملة.`,
    cgm_active_missing: p.automated_mode != null
      ? `التقرير لا يذكر نسبة وقت عمل الحساس. نسبة "الوضع التلقائي" (${p.automated_mode}%) مقياس مختلف ولا تُغني عنها.`
      : 'التقرير لا يذكر نسبة وقت عمل الحساس، لذا لا يمكن التأكد من كفاية البيانات.',
    period_length: c.level === 'pass' ? `فترة التقرير ${p.days} يومًا (كافية).` : `فترة التقرير ${p.days} أيام فقط؛ يوصى بـ 14 يومًا على الأقل.`,
    period_mismatch: `عنوان التقرير يذكر ${p.stated} يومًا بينما التواريخ تغطي ${p.computed} يومًا.`,
    period_missing: 'لم نجد فترة التقرير (من–إلى)، لذا لن تتم مقارنته بتقارير أخرى.',
    nonstandard_target: `النطاق المستهدف في التقرير ${p.low}–${p.high} ${p.unit} وليس 70–180 ملغ/دل المعتاد.`,
    implausible_value: `قيمة غير منطقية (${p.metric} = ${p.value}) — تم وسمها كغير مؤكدة.`,
    date_order_assumed: 'صيغة التواريخ غير محسومة؛ افترضنا يوم/شهر/سنة.',
    name_mismatch: `الاسم في التقرير (${p.name}) يختلف عن اسم حسابك. تأكد أن التقرير يخصك.`,
    duplicate_period: 'لديك تقرير آخر لنفس الفترة تمامًا؛ قد يكون نسخة مكررة.',
    lab_date_missing: 'لم نجد تاريخ التحليل في التقرير، لذا لم نضفه لسجل HbA1c. يمكنك إضافته يدويًا مع التاريخ.',
  };
  const en: Record<string, string> = {
    ranges_sum: c.level === 'pass' ? `Range percentages add up to ${p.total}% (consistent).` : `Range percentages add up to ${p.total}% instead of 100%, so they are marked uncertain.`,
    ranges_incomplete: 'Some time-in-range values are missing from the report.',
    gmi_consistency: c.level === 'pass' ? `GMI (${p.reported}%) is consistent with the average glucose.` : `GMI (${p.reported}%) does not match the value expected from average glucose (≈${p.expected}%).`,
    cv_consistency: c.level === 'pass' ? `CV (${p.reported}%) is consistent with SD and average glucose.` : `The printed CV ${p.reported}% does not match SD ÷ average (≈${p.expected}%). Check the original device report.`,
    cgm_active: c.level === 'pass' ? `CGM was active ${p.value}% of the time (sufficient).` : `CGM was active only ${p.value}% of the time, below the recommended 70%.`,
    cgm_active_missing: p.automated_mode != null
      ? `CGM active time is not reported. "Automated mode" (${p.automated_mode}%) is a different measure and cannot replace it.`
      : 'CGM active time is not reported, so data sufficiency cannot be confirmed.',
    period_length: c.level === 'pass' ? `Report covers ${p.days} days (sufficient).` : `Report covers only ${p.days} days; at least 14 are recommended.`,
    period_mismatch: `The title says ${p.stated} days but the dates cover ${p.computed} days.`,
    period_missing: 'No reporting period was found, so this report will not be compared with others.',
    nonstandard_target: `The report's target range is ${p.low}–${p.high} ${p.unit}, not the usual 70–180 mg/dL.`,
    implausible_value: `Implausible value (${p.metric} = ${p.value}) — marked uncertain.`,
    date_order_assumed: 'Date format was ambiguous; day/month/year was assumed.',
    name_mismatch: `The name on the report (${p.name}) differs from your account name. Make sure the report is yours.`,
    duplicate_period: 'You already have another report for exactly the same period; this may be a duplicate.',
    lab_date_missing: 'No test date was found, so it was not added to your HbA1c history. You can add it manually with its date.',
  };
  return (lang === 'ar' ? ar : en)[c.key] ?? c.key;
}

/** Loose name comparison (Latin/Arabic tokens) used only to warn about a possibly wrong report. */
export function namesLikelyMatch(a: string | null | undefined, b: string | null | undefined): boolean | null {
  const tok = (s: string) => s.toLowerCase().replace(/\b(al|el)[- ]/g, '').replace(/ال/g, '').split(/[^a-z؀-ۿ]+/).filter((t) => t.length > 1);
  if (!a?.trim() || !b?.trim()) return null;
  const A = tok(a), B = new Set(tok(b));
  if (!A.length || !B.size) return null;
  return A.some((t) => B.has(t));
}
