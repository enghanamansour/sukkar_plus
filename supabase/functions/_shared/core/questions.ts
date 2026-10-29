/**
 * Personalised doctor questions — generated only from values actually present in the patient's reports.
 * Every question carries its evidence (metric, value, report) and is flagged uncertain when that evidence is
 * uncertain, comes from a limited comparison, or a data gap prevents a firm reading.
 */
import { METRIC_BY_KEY } from './catalog.ts';
import { compareMetric, getMetric, type Compatibility, type StoredReport } from './compare.ts';

export interface LabResult { value: number; measured_on: string; source: string; is_demo: boolean }

export interface Evidence {
  metric_key: string;
  value: number | null;
  unit: string | null;
  status: string;
  report_id: string;
  source_page?: number | null;
  role?: 'current' | 'previous' | 'lab';
  date?: string | null;
}

export interface GeneratedQuestion {
  rule_key: string;
  question: string;
  rationale: string;
  evidence: Evidence[];
  basis: 'finding' | 'comparison' | 'data_gap';
  is_uncertain: boolean;
}

interface Input {
  current: StoredReport;
  previous?: { report: StoredReport; compat: Compatibility } | null;
  labs: LabResult[];
  lang: 'ar' | 'en';
}

const fmt = (n: number | null | undefined) => (n == null ? '—' : String(Math.round(n * 10) / 10));

function ev(r: StoredReport, key: string, role: Evidence['role'] = 'current'): Evidence | null {
  const m = getMetric(r, key);
  if (!m || m.value == null || m.status === 'unavailable') return null;
  return { metric_key: key, value: m.value, unit: m.unit, status: m.status, report_id: r.id, source_page: m.source_page ?? null, role };
}
const val = (r: StoredReport, key: string) => { const m = getMetric(r, key); return m && m.status !== 'unavailable' ? m.value : null; };
const uncertainOf = (list: (Evidence | null)[]) => list.some((e) => e?.status === 'uncertain');

export function generateDoctorQuestions({ current, previous, labs, lang }: Input): GeneratedQuestion[] {
  const out: GeneratedQuestion[] = [];
  const ar = lang === 'ar';
  const add = (q: GeneratedQuestion) => out.push(q);

  if (current.report_kind !== 'cgm_agp') {
    const h = ev(current, 'hba1c');
    if (h) {
      add({
        rule_key: 'lab_hba1c_target', basis: 'finding', is_uncertain: h.status === 'uncertain', evidence: [h],
        question: ar ? `نتيجة السكر التراكمي (HbA1c) عندي ${fmt(h.value)}%. ما الهدف المناسب لحالتي، ومتى أعيد التحليل؟`
          : `My HbA1c is ${fmt(h.value)}%. What target is right for me, and when should I repeat the test?`,
        rationale: ar ? 'يختلف هدف HbA1c من شخص لآخر حسب العمر وخطر الهبوط والحالة الصحية؛ معرفة هدفك الشخصي تساعدك على فهم نتائجك.'
          : 'HbA1c targets are individual (age, hypoglycaemia risk, other conditions); knowing yours makes the number meaningful.',
      });
    }
    return out;
  }

  const tbr1 = val(current, 'tbr_level1'), tbr2 = val(current, 'tbr_level2'), tbrT = val(current, 'tbr_total');
  const tir = val(current, 'tir'), tar2 = val(current, 'tar_level2'), tarT = val(current, 'tar_total');
  const cv = getMetric(current, 'cv'), gmi = getMetric(current, 'gmi');

  // 1. Hypoglycaemia — highest clinical priority
  if ((tbr2 != null && tbr2 >= 1) || (tbrT != null && tbrT >= 4)) {
    const e = [ev(current, 'tbr_total'), ev(current, 'tbr_level2'), ev(current, 'tbr_level1')].filter(Boolean) as Evidence[];
    add({
      rule_key: 'hypo_time', basis: 'finding', evidence: e, is_uncertain: uncertainOf(e),
      question: ar
        ? `تقريري يُظهر أن السكر كان أقل من 70 لمدة ${fmt(tbrT ?? tbr1)}% من الوقت، منها ${fmt(tbr2)}% أقل من 54. ما الأسباب المحتملة لهذه الانخفاضات، وهل نحتاج لمراجعة خطتي العلاجية معًا؟`
        : `My report shows glucose below 70 for ${fmt(tbrT ?? tbr1)}% of the time, including ${fmt(tbr2)}% below 54. What could be causing these lows, and should we review my treatment plan together?`,
      rationale: ar
        ? `الإجماع الدولي يوصي لأغلب البالغين بأن يكون الوقت تحت 70 أقل من 4%، وتحت 54 أقل من 1%. الانخفاضات المتكررة تستحق النقاش أولًا لأنها قد تكون خطرة.`
        : 'The international consensus recommends <4% of time below 70 and <1% below 54 for most adults. Frequent lows come first because they can be dangerous.',
    });
    add({
      rule_key: 'hypo_plan', basis: 'finding', evidence: e.slice(0, 1), is_uncertain: uncertainOf(e),
      question: ar ? 'ما خطتي الدقيقة لعلاج الهبوط، وهل أحتاج جلوكاجون للطوارئ، ومن يجب أن يعرف كيف يستخدمه؟'
        : 'What exactly is my plan for treating a low, do I need emergency glucagon, and who around me should know how to use it?',
      rationale: ar ? 'مع وجود وقت ملحوظ تحت 54، من المهم أن تكون خطة التعامل مع الهبوط واضحة ومكتوبة لك ولمن حولك.'
        : 'With meaningful time below 54, a clear written plan for lows — for you and the people around you — matters.',
    });
  }

  // 2. Time in range below target
  if (tir != null && tir < 70) {
    const e = [ev(current, 'tir')].filter(Boolean) as Evidence[];
    add({
      rule_key: 'tir_low', basis: 'finding', evidence: e, is_uncertain: uncertainOf(e),
      question: ar ? `الوقت ضمن النطاق عندي ${fmt(tir)}%. ما الهدف المناسب لي، وما أول تغيير عملي نركز عليه لرفعه؟`
        : `My time in range is ${fmt(tir)}%. What target suits me, and what is the first practical change we should focus on?`,
      rationale: ar ? 'الهدف العام لأغلب البالغين أكثر من 70% (حوالي 17 ساعة يوميًا)، لكن الطبيب قد يحدد هدفًا مختلفًا حسب حالتك.'
        : 'The general target for most adults is above 70% (about 17 hours a day), but your doctor may set a different one.',
    });
  }

  // 3. Hyperglycaemia
  if ((tar2 != null && tar2 > 5) || (tarT != null && tarT > 25)) {
    const e = [ev(current, 'tar_total'), ev(current, 'tar_level2')].filter(Boolean) as Evidence[];
    add({
      rule_key: 'hyper_time', basis: 'finding', evidence: e, is_uncertain: uncertainOf(e),
      question: ar ? `السكر كان أعلى من 180 لمدة ${fmt(tarT)}% من الوقت (منها ${fmt(tar2)}% فوق 250). في أي أوقات من اليوم يحدث الارتفاع غالبًا، وما الذي يمكن مراجعته؟`
        : `Glucose was above 180 for ${fmt(tarT)}% of the time (${fmt(tar2)}% above 250). When during the day do these highs usually happen, and what could we review?`,
      rationale: ar ? 'الهدف العام أقل من 25% فوق 180 وأقل من 5% فوق 250. معرفة توقيت الارتفاعات (بعد الوجبات، الليل) تساعد الطبيب على تحديد السبب.'
        : 'General targets are <25% above 180 and <5% above 250. Knowing when highs happen (after meals, overnight) helps find the cause.',
    });
  }

  // 4. Variability
  if (cv && cv.value != null && cv.status !== 'unavailable' && cv.value > 36) {
    const e = [ev(current, 'cv'), ev(current, 'sd')].filter(Boolean) as Evidence[];
    add({
      rule_key: 'variability', basis: 'finding', evidence: e, is_uncertain: cv.status === 'uncertain',
      question: ar ? `معامل التذبذب في تقريري ${fmt(cv.value)}%${cv.status === 'uncertain' ? ' (مع ملاحظة أن الرقم غير متسق مع باقي التقرير)' : ''}. ما الذي قد يسبب تقلب السكر بهذا الشكل، وكيف نقلله بأمان؟`
        : `My glucose variability (CV) is ${fmt(cv.value)}%${cv.status === 'uncertain' ? ' (though this figure is inconsistent with the rest of the report)' : ''}. What might cause swings like this, and how can we reduce them safely?`,
      rationale: ar ? 'التذبذب أعلى من 36% يرتبط بزيادة خطر الهبوط. ' + (cv.status === 'uncertain' ? 'وسمناه غير مؤكد لأن SD ÷ المتوسط يعطي قيمة مختلفة.' : '')
        : 'A CV above 36% is linked with a higher risk of lows. ' + (cv.status === 'uncertain' ? 'Marked uncertain because SD ÷ average gives a different value.' : ''),
    });
  } else if (cv && cv.status === 'uncertain') {
    const e = [ev(current, 'cv'), ev(current, 'sd'), ev(current, 'mean_glucose')].filter(Boolean) as Evidence[];
    add({
      rule_key: 'cv_inconsistent', basis: 'data_gap', evidence: e, is_uncertain: true,
      question: ar ? 'بعض أرقام التذبذب في التقرير غير متسقة فيما بينها. هل يمكن مراجعة التقرير الأصلي من الجهاز للتأكد منها؟'
        : 'Some variability figures in my report are inconsistent with each other. Could we check the original device report?',
      rationale: ar ? 'قراءة صحيحة للتذبذب مهمة لتقدير خطر الهبوط.' : 'An accurate variability reading matters for judging the risk of lows.',
    });
  }

  // 5. GMI vs lab HbA1c (kept distinct)
  if (gmi && gmi.value != null && gmi.status !== 'unavailable') {
    const sameKind = labs.filter((l) => l.is_demo === current.is_demo);
    const ref = current.period_end;
    const lab = ref
      ? sameKind.map((l) => ({ l, gap: Math.abs(Date.parse(l.measured_on) - Date.parse(ref)) / 86400000 }))
          .filter((x) => x.gap <= 120).sort((a, b) => a.gap - b.gap)[0]
      : undefined;
    const gE = ev(current, 'gmi')!;
    if (lab) {
      const diff = Math.round(Math.abs(lab.l.value - gmi.value) * 10) / 10;
      const labE: Evidence = { metric_key: 'hba1c', value: lab.l.value, unit: '%', status: 'extracted', report_id: current.id, role: 'lab', date: lab.l.measured_on };
      if (diff >= 0.5) {
        add({
          rule_key: 'gmi_vs_hba1c', basis: 'finding', evidence: [gE, labE], is_uncertain: gmi.status === 'uncertain' || lab.gap > 90,
          question: ar ? `مؤشر GMI من الحساس ${fmt(gmi.value)}% بينما تحليل HbA1c في المختبر ${fmt(lab.l.value)}% (بتاريخ ${lab.l.measured_on}). لماذا يختلفان، وأيهما نعتمد عليه في متابعتي؟`
            : `My sensor GMI is ${fmt(gmi.value)}% but my lab HbA1c is ${fmt(lab.l.value)}% (on ${lab.l.measured_on}). Why do they differ, and which should guide my care?`,
          rationale: ar ? `GMI تقدير من قراءات الحساس، وHbA1c تحليل دم؛ الفرق بينهما ${diff} نقطة. فروق كهذه شائعة لكنها تستحق التوضيح.${lab.gap > 90 ? ' تاريخ التحليل بعيد عن فترة التقرير، لذا المقارنة تقريبية.' : ''}`
            : `GMI is a sensor estimate; HbA1c is a blood test. They differ by ${diff} points — common, but worth explaining.${lab.gap > 90 ? ' The lab date is far from the report period, so this is approximate.' : ''}`,
        });
      }
    } else {
      add({
        rule_key: 'hba1c_missing', basis: 'data_gap', evidence: [gE], is_uncertain: true,
        question: ar ? `لدي مؤشر GMI (${fmt(gmi.value)}%) من الحساس، لكن لا يوجد عندي تحليل HbA1c حديث قريب من هذه الفترة. هل أحتاج لإجرائه، ومتى؟`
          : `I have a sensor GMI (${fmt(gmi.value)}%) but no recent lab HbA1c near this period. Do I need one, and when?`,
        rationale: ar ? 'GMI ليس بديلًا عن تحليل HbA1c؛ وجود الاثنين يعطي صورة أوضح.' : 'GMI does not replace a lab HbA1c; having both gives a clearer picture.',
      });
    }
  }

  // 6. Data sufficiency
  const active = getMetric(current, 'cgm_active');
  if (!active || active.status === 'unavailable') {
    add({
      rule_key: 'cgm_active_missing', basis: 'data_gap', evidence: [ev(current, 'automated_mode')].filter(Boolean) as Evidence[], is_uncertain: true,
      question: ar ? 'تقريري لا يذكر نسبة الوقت الذي كان فيه الحساس يعمل. كيف نتأكد أن البيانات كافية لاتخاذ قرارات؟'
        : "My report doesn't show how much of the time the sensor was active. How do we know there's enough data to make decisions?",
      rationale: ar ? 'يُوصى بعمل الحساس 70% على الأقل من الوقت خلال 14 يومًا لتكون الأرقام ممثِّلة.' : 'At least 70% sensor wear over 14 days is recommended for the numbers to be representative.',
    });
  } else if (active.value != null && active.value < 70) {
    const e = [ev(current, 'cgm_active')].filter(Boolean) as Evidence[];
    add({
      rule_key: 'cgm_active_low', basis: 'data_gap', evidence: e, is_uncertain: true,
      question: ar ? `الحساس كان يعمل ${fmt(active.value)}% فقط من الوقت. هل البيانات كافية، وكيف أحسّن استمرارية لبسه؟`
        : `My sensor was active only ${fmt(active.value)}% of the time. Is the data enough, and how can I wear it more consistently?`,
      rationale: ar ? 'أقل من 70% قد يجعل الأرقام لا تمثل الفترة كاملة.' : 'Below 70% the numbers may not represent the whole period.',
    });
  }

  // 7. Change since the previous comparable report
  if (previous) {
    const c = compareMetric('tir', current, previous.report, previous.compat);
    const h = compareMetric('tbr_total', current, previous.report, previous.compat);
    const notable = [c, h].filter((x) => x.comparable && (x.direction === 'improved' || x.direction === 'worsened'));
    if (notable.length) {
      const e: Evidence[] = [];
      for (const n of notable) {
        const cur = ev(current, n.key); const prev = ev(previous.report, n.key, 'previous');
        if (cur) e.push(cur); if (prev) e.push(prev);
      }
      const parts = notable.map((n) => {
        const name = METRIC_BY_KEY[n.key].short[lang];
        return ar ? `${name} من ${fmt(n.previous)}% إلى ${fmt(n.current)}%` : `${name} from ${fmt(n.previous)}% to ${fmt(n.current)}%`;
      }).join(ar ? '، و' : ', and ');
      const worse = notable.some((n) => n.direction === 'worsened');
      const limited = previous.compat.level !== 'compatible';
      add({
        rule_key: 'trend_change', basis: 'comparison', evidence: e, is_uncertain: limited || notable.some((n) => n.uncertain),
        question: ar ? `مقارنة بتقريري السابق تغيّر ${parts}. ${worse ? 'ما الذي قد يفسر هذا التراجع، وماذا نراجع؟' : 'ما الذي ساعد على هذا التحسن، وكيف أحافظ عليه؟'}`
          : `Compared with my previous report, ${parts}. ${worse ? 'What might explain this, and what should we review?' : 'What helped, and how do I keep it up?'}`,
        rationale: ar ? `المقارنة مع تقرير ${previous.report.period_start} – ${previous.report.period_end}.${limited ? ' المقارنة محدودة لأن مدة التقريرين مختلفة.' : ''}`
          : `Compared with the ${previous.report.period_start} – ${previous.report.period_end} report.${limited ? ' Limited comparison: the reports cover different lengths of time.' : ''}`,
      });
    }
  }

  // 8. Everything within targets → maintenance question (still grounded in data)
  if (out.filter((q) => q.basis !== 'data_gap').length === 0 && tir != null) {
    const e = [ev(current, 'tir'), ev(current, 'tbr_total')].filter(Boolean) as Evidence[];
    add({
      rule_key: 'on_target', basis: 'finding', evidence: e, is_uncertain: uncertainOf(e),
      question: ar ? `أغلب مؤشراتي ضمن الأهداف العامة (ضمن النطاق ${fmt(tir)}%). هل هذه الأهداف مناسبة لي، ومتى موعد المتابعة القادم؟`
        : `Most of my numbers are within general targets (time in range ${fmt(tir)}%). Are these targets right for me, and when is my next review?`,
      rationale: ar ? 'حتى مع النتائج الجيدة، يساعد تأكيد الأهداف الشخصية وخطة المتابعة.' : 'Even with good results, confirming personal targets and follow-up is useful.',
    });
  }

  // Device settings: never interpreted, but asking the doctor is appropriate when there are lows or highs.
  const hasSettings = ['setting_target_glucose', 'setting_ic_ratio'].some((k) => getMetric(current, k));
  if (hasSettings && out.some((q) => q.rule_key === 'hypo_time' || q.rule_key === 'hyper_time') && out.length < 8) {
    const e = [ev(current, 'setting_target_glucose'), ev(current, 'setting_ic_ratio')].filter(Boolean) as Evidence[];
    add({
      rule_key: 'settings_review', basis: 'finding', evidence: e, is_uncertain: false,
      question: ar ? 'هل إعدادات المضخة الحالية (مثل السكر المستهدف ونسبة الكربوهيدرات) ما زالت مناسبة لنتائجي؟ لن أغيّر شيئًا قبل أن نتفق.'
        : "Are my current pump settings (such as target glucose and carb ratio) still right for my results? I won't change anything until we agree.",
      rationale: ar ? 'التقرير يتضمن إعدادات الجهاز. عضيد لا يقترح تغييرها — هذا قرار طبيبك.' : 'The report includes device settings. Adeed never suggests changing them — that is your doctor’s decision.',
    });
  }

  return out.slice(0, 8);
}
