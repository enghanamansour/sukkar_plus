/**
 * Metric catalogue shared by the server (extraction, questions, chatbot tools) and the browser (display).
 * Targets follow the International Consensus on Time in Range (Battelino et al., Diabetes Care 2019;42:1593)
 * for most adults with type 1 / type 2 diabetes. They are general reference points: a clinician may set
 * different individual targets (e.g. older or high-risk adults, pregnancy).
 */

export type MetricCategory = 'glycemic' | 'range' | 'variability' | 'usage' | 'device_setting' | 'lab';
export type MetricStatus = 'extracted' | 'calculated' | 'unavailable' | 'uncertain';
/** Which direction is generally favourable. 'neutral' = do not judge a change (e.g. mean glucose, GMI). */
export type Polarity = 'higher_better' | 'lower_better' | 'neutral';

export interface MetricTarget {
  op: '>' | '<' | '<=' | '>=';
  value: number;
  /** Reference the target comes from. */
  source: string;
}

export interface MetricDef {
  key: string;
  category: MetricCategory;
  unit: string | null;
  polarity: Polarity;
  label: { ar: string; en: string };
  short: { ar: string; en: string };
  explain: { ar: string; en: string };
  target?: MetricTarget;
  /** Minimum change (absolute, in the metric's unit) worth calling out when comparing compatible reports. */
  meaningfulDelta?: number;
  /** Shown in the main summary; device settings are informational only. */
  core?: boolean;
}

const CONSENSUS = 'ATTD International Consensus on Time in Range, 2019';

export const METRICS: MetricDef[] = [
  {
    key: 'tir', category: 'range', unit: '%', polarity: 'higher_better', core: true, meaningfulDelta: 5,
    label: { ar: 'الوقت ضمن النطاق (70–180 ملغ/دل)', en: 'Time in range (70–180 mg/dL)' },
    short: { ar: 'ضمن النطاق', en: 'In range' },
    explain: {
      ar: 'نسبة الوقت الذي كان فيه السكر بين 70 و180 ملغ/دل. كل 5% تقريبًا تعادل ساعة وربع يوميًا.',
      en: 'Share of time glucose stayed between 70 and 180 mg/dL. Every 5% is roughly 1 hour 12 minutes a day.',
    },
    target: { op: '>', value: 70, source: CONSENSUS },
  },
  {
    key: 'tar_level1', category: 'range', unit: '%', polarity: 'lower_better', core: true, meaningfulDelta: 5,
    label: { ar: 'مرتفع (181–250 ملغ/دل)', en: 'High (181–250 mg/dL)' },
    short: { ar: 'مرتفع', en: 'High' },
    explain: { ar: 'نسبة الوقت الذي كان فيه السكر بين 181 و250.', en: 'Share of time glucose was between 181 and 250.' },
  },
  {
    key: 'tar_level2', category: 'range', unit: '%', polarity: 'lower_better', core: true, meaningfulDelta: 3,
    label: { ar: 'مرتفع جدًا (أعلى من 250 ملغ/دل)', en: 'Very high (>250 mg/dL)' },
    short: { ar: 'مرتفع جدًا', en: 'Very high' },
    explain: { ar: 'نسبة الوقت الذي تجاوز فيه السكر 250.', en: 'Share of time glucose was above 250.' },
    target: { op: '<', value: 5, source: CONSENSUS },
  },
  {
    key: 'tar_total', category: 'range', unit: '%', polarity: 'lower_better', meaningfulDelta: 5,
    label: { ar: 'إجمالي الوقت فوق النطاق (>180)', en: 'Total time above range (>180)' },
    short: { ar: 'فوق النطاق', en: 'Above range' },
    explain: { ar: 'مجموع الوقت المرتفع والمرتفع جدًا.', en: 'High plus very high time combined.' },
    target: { op: '<', value: 25, source: CONSENSUS },
  },
  {
    key: 'tbr_level1', category: 'range', unit: '%', polarity: 'lower_better', core: true, meaningfulDelta: 2,
    label: { ar: 'منخفض (54–69 ملغ/دل)', en: 'Low (54–69 mg/dL)' },
    short: { ar: 'منخفض', en: 'Low' },
    explain: { ar: 'نسبة الوقت الذي كان فيه السكر بين 54 و69.', en: 'Share of time glucose was between 54 and 69.' },
  },
  {
    key: 'tbr_level2', category: 'range', unit: '%', polarity: 'lower_better', core: true, meaningfulDelta: 1,
    label: { ar: 'منخفض جدًا (أقل من 54 ملغ/دل)', en: 'Very low (<54 mg/dL)' },
    short: { ar: 'منخفض جدًا', en: 'Very low' },
    explain: {
      ar: 'نسبة الوقت الذي كان فيه السكر أقل من 54، وهو مستوى يحتاج انتباهًا خاصًا.',
      en: 'Share of time glucose was below 54, a level that needs particular attention.',
    },
    target: { op: '<', value: 1, source: CONSENSUS },
  },
  {
    key: 'tbr_total', category: 'range', unit: '%', polarity: 'lower_better', meaningfulDelta: 2,
    label: { ar: 'إجمالي الوقت تحت النطاق (<70)', en: 'Total time below range (<70)' },
    short: { ar: 'تحت النطاق', en: 'Below range' },
    explain: { ar: 'مجموع الوقت المنخفض والمنخفض جدًا.', en: 'Low plus very low time combined.' },
    target: { op: '<', value: 4, source: CONSENSUS },
  },
  {
    key: 'mean_glucose', category: 'glycemic', unit: 'mg/dL', polarity: 'neutral', core: true, meaningfulDelta: 10,
    label: { ar: 'متوسط السكر', en: 'Average glucose' },
    short: { ar: 'المتوسط', en: 'Average' },
    explain: {
      ar: 'متوسط قراءات الحساس خلال فترة التقرير. لا يوضح وحده التذبذب أو الانخفاضات.',
      en: 'Average sensor glucose over the report period. On its own it hides swings and lows.',
    },
  },
  {
    key: 'gmi', category: 'glycemic', unit: '%', polarity: 'neutral', core: true, meaningfulDelta: 0.3,
    label: { ar: 'مؤشر إدارة السكر (GMI)', en: 'Glucose Management Indicator (GMI)' },
    short: { ar: 'GMI', en: 'GMI' },
    explain: {
      ar: 'تقدير محسوب من متوسط قراءات الحساس، وليس تحليل دم. قد يختلف عن تحليل التراكمي (HbA1c) من المختبر.',
      en: 'An estimate calculated from average sensor glucose — not a blood test. It can differ from a lab HbA1c.',
    },
  },
  {
    key: 'cv', category: 'variability', unit: '%', polarity: 'lower_better', core: true, meaningfulDelta: 3,
    label: { ar: 'معامل التذبذب (CV)', en: 'Glucose variability (CV)' },
    short: { ar: 'التذبذب', en: 'Variability' },
    explain: {
      ar: 'يقيس مدى تقلب السكر صعودًا وهبوطًا. القيمة 36% أو أقل تعتبر تذبذبًا مستقرًا لدى أغلب البالغين.',
      en: 'How much glucose swings up and down. 36% or lower is considered stable for most adults.',
    },
    target: { op: '<=', value: 36, source: CONSENSUS },
  },
  {
    key: 'sd', category: 'variability', unit: 'mg/dL', polarity: 'lower_better', meaningfulDelta: 5,
    label: { ar: 'الانحراف المعياري (SD)', en: 'Standard deviation (SD)' },
    short: { ar: 'SD', en: 'SD' },
    explain: { ar: 'مقياس آخر لتذبذب السكر حول المتوسط.', en: 'Another measure of how glucose spreads around the average.' },
  },
  {
    key: 'cgm_active', category: 'usage', unit: '%', polarity: 'higher_better', core: true,
    label: { ar: 'نسبة وقت عمل الحساس', en: 'CGM active time' },
    short: { ar: 'عمل الحساس', en: 'CGM active' },
    explain: {
      ar: 'نسبة الوقت الذي سجّل فيه الحساس قراءات. يُنصح بأن تكون 70% أو أكثر لتكون الأرقام ممثِّلة.',
      en: 'Share of time the sensor recorded data. 70% or more is recommended for the numbers to be representative.',
    },
    target: { op: '>=', value: 70, source: CONSENSUS },
  },
  {
    key: 'automated_mode', category: 'usage', unit: '%', polarity: 'neutral',
    label: { ar: 'وقت الوضع التلقائي للمضخة', en: 'Pump automated mode time' },
    short: { ar: 'الوضع التلقائي', en: 'Automated mode' },
    explain: {
      ar: 'نسبة الوقت الذي عملت فيه المضخة بالوضع التلقائي. هذا ليس نفس وقت عمل الحساس.',
      en: 'Share of time the pump ran in automated mode. This is not the same as CGM wear time.',
    },
  },
  {
    key: 'hba1c', category: 'lab', unit: '%', polarity: 'neutral', core: true, meaningfulDelta: 0.3,
    label: { ar: 'السكر التراكمي (HbA1c) — تحليل مختبر', en: 'HbA1c — lab test' },
    short: { ar: 'HbA1c', en: 'HbA1c' },
    explain: {
      ar: 'تحليل دم يعكس متوسط السكر خلال 2–3 أشهر تقريبًا. يختلف عن GMI المحسوب من الحساس.',
      en: 'A blood test reflecting roughly the last 2–3 months. Different from sensor-derived GMI.',
    },
  },
  // Device settings: extracted for completeness and shown as-is. Adeed never interprets or suggests changes.
  {
    key: 'setting_target_glucose', category: 'device_setting', unit: 'mg/dL', polarity: 'neutral',
    label: { ar: 'السكر المستهدف في الجهاز', en: 'Device target glucose' },
    short: { ar: 'هدف الجهاز', en: 'Device target' },
    explain: { ar: 'إعداد مسجل في الجهاز. أي تغيير فيه يكون مع فريقك الطبي فقط.', en: 'A device setting. Only change it with your care team.' },
  },
  {
    key: 'setting_ic_ratio', category: 'device_setting', unit: 'g/U', polarity: 'neutral',
    label: { ar: 'نسبة الكربوهيدرات إلى الإنسولين', en: 'Insulin-to-carb ratio' },
    short: { ar: 'نسبة الكارب', en: 'IC ratio' },
    explain: { ar: 'إعداد مسجل في الجهاز. أي تغيير فيه يكون مع فريقك الطبي فقط.', en: 'A device setting. Only change it with your care team.' },
  },
  {
    key: 'setting_max_basal', category: 'device_setting', unit: 'U/hr', polarity: 'neutral',
    label: { ar: 'أقصى معدل قاعدي', en: 'Maximum basal rate' },
    short: { ar: 'أقصى قاعدي', en: 'Max basal' },
    explain: { ar: 'إعداد مسجل في الجهاز. أي تغيير فيه يكون مع فريقك الطبي فقط.', en: 'A device setting. Only change it with your care team.' },
  },
];

export const METRIC_BY_KEY: Record<string, MetricDef> = Object.fromEntries(METRICS.map((m) => [m.key, m]));

/** Metrics that should always appear in a CGM report summary — shown as "unavailable" when missing. */
export const EXPECTED_CGM_KEYS = ['tir', 'tar_level1', 'tar_level2', 'tbr_level1', 'tbr_level2', 'mean_glucose', 'gmi', 'cv', 'cgm_active'];

export function meetsTarget(key: string, value: number | null | undefined): boolean | null {
  const def = METRIC_BY_KEY[key];
  if (!def?.target || value === null || value === undefined || Number.isNaN(value)) return null;
  const t = def.target;
  switch (t.op) {
    case '>': return value > t.value;
    case '>=': return value >= t.value;
    case '<': return value < t.value;
    case '<=': return value <= t.value;
  }
}

export function targetText(key: string, lang: 'ar' | 'en'): string | null {
  const t = METRIC_BY_KEY[key]?.target;
  if (!t) return null;
  const unit = METRIC_BY_KEY[key].unit ?? '';
  const opAr: Record<string, string> = { '>': 'أكثر من', '>=': 'على الأقل', '<': 'أقل من', '<=': 'لا يزيد عن' };
  const opEn: Record<string, string> = { '>': 'above', '>=': 'at least', '<': 'below', '<=': 'at most' };
  return lang === 'ar' ? `${opAr[t.op]} ${t.value}${unit}` : `${opEn[t.op]} ${t.value}${unit}`;
}

/** GMI (%) = 3.31 + 0.02392 × mean glucose (mg/dL)  — Bergenstal et al., Diabetes Care 2018. */
export function gmiFromMean(meanMgDl: number): number {
  return Math.round((3.31 + 0.02392 * meanMgDl) * 10) / 10;
}

/** Target split into operator words and the numeric part, so UIs can isolate the number for correct bidi rendering. */
export function targetParts(key: string, lang: 'ar' | 'en'): { op: string; value: string } | null {
  const t = METRIC_BY_KEY[key]?.target;
  if (!t) return null;
  const opAr: Record<string, string> = { '>': 'أكثر من', '>=': 'على الأقل', '<': 'أقل من', '<=': 'لا يزيد عن' };
  const opEn: Record<string, string> = { '>': 'above', '>=': 'at least', '<': 'below', '<=': 'at most' };
  return { op: (lang === 'ar' ? opAr : opEn)[t.op], value: `${t.value}${METRIC_BY_KEY[key].unit ?? ''}` };
}

/** The range part of a label, e.g. "70–180 mg/dL" from "Time in range (70–180 mg/dL)". */
export function rangeOf(key: string, lang: 'ar' | 'en'): string | null {
  const m = METRIC_BY_KEY[key]?.label[lang].match(/\(([^)]+)\)/);
  return m ? m[1] : null;
}
