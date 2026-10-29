import { describe, expect, it } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { extractText, getDocumentProxy } from 'unpdf';
import { parseReportPages, ReportParseError, checkMessage, namesLikelyMatch, gmiFromMean } from '../supabase/functions/_shared/core/index.ts';

const ROOT = join(__dirname, '..', 'fixtures');

async function pagesOf(path: string): Promise<string[]> {
  const pdf = await getDocumentProxy(new Uint8Array(readFileSync(path)));
  const { text } = await extractText(pdf, { mergePages: false });
  return text as string[];
}

// Ground truth = the four profiles used by fixtures/generate_reports.py (patient i → profile i % 4).
const PROFILES: Record<number, Record<string, number>> = {
  1: { tar_level2: 0.5, tar_level1: 2.0, tir: 48.0, tbr_level1: 16.0, tbr_level2: 33.5, mean_glucose: 94, gmi: 5.6, cv: 46.0, sd: 50.0 },
  2: { tar_level2: 25.0, tar_level1: 40.0, tir: 30.0, tbr_level1: 3.0, tbr_level2: 2.0, mean_glucose: 235, gmi: 9.0, cv: 40.0, sd: 65.0 },
  3: { tar_level2: 12.0, tar_level1: 22.0, tir: 45.0, tbr_level1: 11.0, tbr_level2: 10.0, mean_glucose: 168, gmi: 7.4, cv: 50.0, sd: 58.0 },
  0: { tar_level2: 0.1, tar_level1: 7.5, tir: 84.0, tbr_level1: 5.0, tbr_level2: 3.4, mean_glucose: 114, gmi: 6.0, cv: 30.0, sd: 34.0 },
};

describe('parser — all 20 supplied sample reports', () => {
  const files = readdirSync(join(ROOT, 'sample-reports')).filter((f) => f.endsWith('.pdf'));
  it('finds all 20 sample PDFs', () => expect(files.length).toBe(20));

  for (const f of files) {
    const n = Number(f.match(/(\d+)/)![1]);
    it(`extracts ${f} exactly`, async () => {
      const r = parseReportPages(await pagesOf(join(ROOT, 'sample-reports', f)));
      const truth = PROFILES[n % 4];
      expect(r.kind).toBe('cgm_agp');
      expect(r.periodStart).toBe('2026-08-01');
      expect(r.periodEnd).toBe('2026-08-30');
      expect(r.periodDays).toBe(30);
      expect(r.statedDays).toBe(30);
      expect(r.generatedOn).toBe('2026-08-30');
      expect(r.dateOrder).toBe('dmy');
      expect(r.pageCount).toBe(8);
      expect(r.sourceSystem).toBe('Omnipod Discover');
      expect(r.device).toBe('Omnipod 5 & Dexcom G7');
      expect(r.targetRange).toEqual({ low: 70, high: 180, unit: 'mg/dL' });
      const byKey = Object.fromEntries(r.metrics.map((m) => [m.key, m]));
      for (const [k, v] of Object.entries(truth)) {
        expect(byKey[k]?.value, `${f} ${k}`).toBe(v);
        expect(byKey[k]?.sourcePage).toBe(1);
      }
      // Never confuse GMI with a lab HbA1c
      expect(byKey.hba1c).toBeUndefined();
      // Calculated totals are labelled as calculated
      expect(byKey.tbr_total.status).toBe('calculated');
      expect(byKey.tbr_total.value).toBeCloseTo(truth.tbr_level1 + truth.tbr_level2, 5);
      // CGM active time is not in these reports → explicit unavailable, and automated mode is not substituted
      expect(byKey.cgm_active.status).toBe('unavailable');
      expect(byKey.cgm_active.value).toBeNull();
      expect(byKey.automated_mode.value).toBe(65);
      // Device settings captured as information only
      expect(byKey.setting_target_glucose.value).toBe(110);
      expect(byKey.setting_ic_ratio.value).toBe(10);
      expect(byKey.setting_max_basal.value).toBe(5);
      // Ranges sum to 100
      expect(r.checks.find((c) => c.key === 'ranges_sum')?.level).toBe('pass');
    });
  }

  it('flags the internally inconsistent CV values (SD ÷ mean ≠ CV) as uncertain', async () => {
    for (const n of [1, 2, 3]) {
      const r = parseReportPages(await pagesOf(join(ROOT, 'sample-reports', `report_patient_${n}.pdf`)));
      const cv = r.metrics.find((m) => m.key === 'cv')!;
      expect(cv.status).toBe('uncertain');
      expect(r.checks.find((c) => c.key === 'cv_consistency')?.level).toBe('warn');
    }
    const ok = parseReportPages(await pagesOf(join(ROOT, 'sample-reports', 'report_patient_4.pdf')));
    expect(ok.metrics.find((m) => m.key === 'cv')!.status).toBe('extracted');
  });

  it('keeps GMI extracted when it matches the mean glucose', async () => {
    const r = parseReportPages(await pagesOf(join(ROOT, 'sample-reports', 'report_patient_2.pdf')));
    expect(gmiFromMean(235)).toBeCloseTo(8.9, 1);
    expect(r.metrics.find((m) => m.key === 'gmi')!.status).toBe('extracted');
  });
});

describe('parser — synthetic demo history', () => {
  it('reads the 14-day July report', async () => {
    const r = parseReportPages(await pagesOf(join(ROOT, 'demo', 'demo_history_2026-07.pdf')));
    expect(r.periodStart).toBe('2026-07-15');
    expect(r.periodDays).toBe(14);
    expect(r.statedDays).toBe(14);
    expect(r.metrics.find((m) => m.key === 'tir')!.value).toBe(44);
    expect(r.metrics.find((m) => m.key === 'cv')!.status).toBe('extracted'); // 61/170 ≈ 35.9
  });
});

describe('parser — other formats and failure modes', () => {
  it('rejects PDFs without text', () => {
    expect(() => parseReportPages(['', '  '])).toThrow(ReportParseError);
  });
  it('rejects unrelated documents', () => {
    expect(() => parseReportPages(['This is an invoice for office chairs. Total 450 SAR. Thank you for your business.'])).toThrowError(/No recognised/);
  });
  it('parses an inline-format CGM summary with CGM active time and ISO dates', () => {
    const r = parseReportPages([
      'Glucose Statistics and Targets\nReporting Period: 2026-09-01 to 2026-09-14\n% Time CGM is Active: 93.2%\n' +
      'Time in Range (70-180 mg/dL): 72%\nHigh (181-250 mg/dL): 18%\nVery High (>250 mg/dL): 6%\nLow (54-69 mg/dL): 3%\nVery Low (<54 mg/dL): 1%\n' +
      'Average Glucose: 156 mg/dL\nGlucose Management Indicator (GMI): 7.0%\nCoefficient of Variation: 33.1%',
    ]);
    const m = Object.fromEntries(r.metrics.map((x) => [x.key, x]));
    expect(r.periodDays).toBe(14);
    expect(r.dateOrder).toBe('iso');
    expect(m.tir.value).toBe(72);
    expect(m.tbr_level2.value).toBe(1);
    expect(m.tar_level2.value).toBe(6);
    expect(m.cgm_active.value).toBe(93.2);
    expect(m.gmi.value).toBe(7);
    expect(r.checks.find((c) => c.key === 'cgm_active')?.level).toBe('pass');
  });
  it('parses a lab report HbA1c and ignores "estimated A1C"', () => {
    const lab = parseReportPages(['Laboratory Report\nPatient Name: Test Person\nHbA1c: 7.9 %\nReport Date: 12/09/2026']);
    expect(lab.kind).toBe('lab');
    expect(lab.metrics.find((m) => m.key === 'hba1c')!.value).toBe(7.9);
    const est = parseReportPages(['Average Glucose: 150 mg/dL\nEstimated A1C: 6.9%\nGMI: 6.9%']);
    expect(est.metrics.find((m) => m.key === 'hba1c')).toBeUndefined();
  });
  it('marks implausible values and broken range sums as uncertain', () => {
    const r = parseReportPages(['Date Range: 01/08/2026-30/08/2026\nVery High (>250) High (181-250) Target (70-180) Low (54-69) Very Low (<54)\n10% 20% 30% 10% 10%\nAverage Glucose: 900 mg/dL']);
    expect(r.checks.find((c) => c.key === 'ranges_sum')?.level).toBe('warn');
    expect(r.metrics.find((m) => m.key === 'tir')!.status).toBe('uncertain');
    expect(r.metrics.find((m) => m.key === 'mean_glucose')!.status).toBe('uncertain');
  });
  it('localises quality messages', () => {
    expect(checkMessage({ key: 'period_length', level: 'warn', params: { days: 7 } }, 'ar')).toContain('7');
    expect(checkMessage({ key: 'period_length', level: 'warn', params: { days: 7 } }, 'en')).toContain('14');
  });
  it('matches names loosely', () => {
    expect(namesLikelyMatch('Fatima Al-Qahtani', 'fatima qahtani')).toBe(true);
    expect(namesLikelyMatch('Fatima Al-Qahtani', 'Khalid Al-Subaie')).toBe(false);
    expect(namesLikelyMatch('Fatima', '')).toBeNull();
  });
});
