// Safety and grounding checks for model-generated Arabic explanations.
// Mirrors AiTextValidator in packages/sukkar_core/lib/src/ai/ai.dart.

const BANNED: RegExp[] = [
  /جرع/, /وحد(ة|ات) (من )?(ال)?[إا]نسولين/, /زد (من )?/, /ارفع جرعة/, /قلل/, /قلّل/, /أوقف/, /توقف عن/, /غيّ?ر (ال)?دواء/, /عدّ?ل (ال)?علاج/,
  /\bdos(e|es|ing|age)\b/i, /units? of insulin/i, /\b(increase|decrease|reduce|adjust) your\b/i, /\bstop taking\b/i,
  /تشخيص/, /مصاب ب/, /لديك مرض/, /خطير/, /غير طبيعي/, /حالة طارئة/, /diagnos/i, /\bdangerous\b/i, /\babnormal\b/i,
];

/** General reference numbers that may appear in grounded text. */
export const REFERENCE_NUMBERS = [14, 70, 180, 54, 250, 4, 1, 25, 5, 36, 2];

export function normalizeDigits(s: string): string {
  return s
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660))
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06f0))
    .replace(/٫/g, '.');
}

export interface GuardResult {
  ok: boolean;
  reasons: string[];
}

export function guardExplanation(text: string, allowedNumbers: number[], maxLength = 1500): GuardResult {
  const reasons: string[] = [];
  const t = (text ?? '').trim();
  if (!t) reasons.push('empty');
  if (t.length > maxLength) reasons.push('too_long');
  for (const re of BANNED) if (re.test(t)) reasons.push(`banned:${re.source}`);
  const allowed = [...allowedNumbers, ...REFERENCE_NUMBERS];
  for (const m of normalizeDigits(t).matchAll(/\d+(?:\.\d+)?/g)) {
    const n = Number(m[0]);
    if (!allowed.some((a) => Math.abs(a - n) <= 0.051)) reasons.push(`ungrounded_number:${m[0]}`);
  }
  return { ok: reasons.length === 0, reasons };
}

/** Allowed numbers from the context the app sent (values, period days, date parts). */
export function allowedNumbersFromContext(ctx: unknown): number[] {
  const out: number[] = [];
  if (!ctx || typeof ctx !== 'object') return out;
  const c = ctx as Record<string, unknown>;
  if (Array.isArray(c.verified_values)) {
    for (const v of c.verified_values) {
      const value = (v as Record<string, unknown>)?.value;
      if (typeof value === 'number' && Number.isFinite(value)) {
        out.push(value, Math.round(value), Math.round(value * 10) / 10, Math.round(value * 100) / 100);
      }
    }
  }
  if (typeof c.period_days === 'number') out.push(c.period_days);
  if (typeof c.period === 'string') {
    for (const m of c.period.matchAll(/\d+/g)) out.push(Number(m[0]));
  }
  return out;
}
