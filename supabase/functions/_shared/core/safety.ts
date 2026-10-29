/**
 * Deterministic safety layer applied before and independently of the language model.
 * It never replaces clinical judgement; it guarantees emergency guidance is shown even if the AI is
 * unavailable, slow or wrong.
 */

export type SafetyLevel = 'emergency' | 'urgent' | null;

const EMERGENCY = [
  // Arabic
  'فاقد الوعي', 'فقد الوعي', 'فقدان الوعي', 'غائب عن الوعي', 'مغمى عليه', 'مغمي عليه', 'أغمي عليه', 'اغمي عليه', 'إغماء', 'اغماء',
  'لا يستجيب', 'ما يستجيب', 'مايستجيب', 'ما يرد', 'تشنج', 'تشنجات', 'نوبة صرع', 'صرع', 'يتشنج',
  'لا يستطيع البلع', 'ما يقدر يبلع', 'مايقدر يبلع', 'لا يقدر يبلع', 'صعوبة في البلع',
  'مشوش جدا', 'مشوش جدًا', 'ارتباك شديد', 'تشوش شديد', 'هذيان', 'لا يتنفس', 'ما يتنفس',
  // English
  'unconscious', 'passed out', 'fainted', 'unresponsive', 'not responding', 'seizure', 'seizing', 'convuls', 'fitting',
  "can't swallow", 'cannot swallow', 'unable to swallow', 'severely confused', 'very confused', 'not breathing',
];

const URGENT = [
  'قيء مستمر', 'استفراغ مستمر', 'يستفرغ', 'ترجيع مستمر', 'صعوبة في التنفس', 'ضيق تنفس', 'رائحة فواكه', 'رائحة الفم مثل الفواكه', 'كيتون', 'الكيتونات',
  'ألم في الصدر', 'الم في الصدر', 'ألم شديد في البطن', 'هبوط شديد', 'السكر 40', 'السكر ٤٠', 'السكر أقل من 54', 'السكر فوق 400', 'السكر 500', 'hi على الجهاز', 'high على الجهاز',
  'vomiting', 'keep throwing up', 'trouble breathing', 'short of breath', 'fruity breath', 'ketone', 'chest pain', 'severe abdominal pain',
];

const DOSE = [
  'كم وحدة', 'كم وحده', 'جرعة الانسولين', 'جرعة الإنسولين', 'أزيد الجرعة', 'ازيد الجرعة', 'أنقص الجرعة', 'انقص الجرعة', 'أغير الجرعة', 'اغير الجرعة',
  'أعدل الجرعة', 'اعدل الجرعة', 'أغير إعدادات', 'اغير اعدادات', 'نسبة الكارب', 'معامل التصحيح', 'كم أاخذ', 'كم اخذ', 'كم آخذ',
  'how many units', 'insulin dose', 'increase my dose', 'decrease my dose', 'change my dose', 'adjust my dose', 'change my settings', 'carb ratio', 'correction factor', 'basal rate',
];

const norm = (s: string) => s.toLowerCase().replace(/[ًٌٍَُِّْـ]/g, '').replace(/[إأآ]/g, 'ا').replace(/ى/g, 'ي');
const has = (text: string, list: string[]) => { const t = norm(text); return list.some((k) => t.includes(norm(k))); };

export function detectSafetyLevel(text: string): SafetyLevel {
  if (has(text, EMERGENCY)) return 'emergency';
  if (has(text, URGENT)) return 'urgent';
  return null;
}

export function isDoseRequest(text: string): boolean {
  return has(text, DOSE);
}

export function emergencyNotice(level: Exclude<SafetyLevel, null>, lang: 'ar' | 'en'): string {
  if (level === 'emergency') {
    return lang === 'ar'
      ? '🚨 **هذه حالة طارئة.** اتصل بالإسعاف فورًا على **997** (أو 911) ولا تنتظر الرد هنا.\n\n' +
        '- إذا كان الشخص **فاقدًا للوعي أو يتشنج أو مشوشًا بشدة أو لا يستطيع البلع بأمان: لا تعطه أي شيء عن طريق الفم** (لا طعام ولا شراب ولا سكر) لخطر الاختناق.\n' +
        '- إذا كان لديه **جلوكاجون** للطوارئ ووصفه الطبيب ويعرف أحد الحاضرين استخدامه، فاستخدموه حسب التعليمات.\n' +
        '- ضعه على جانبه، وابقَ معه حتى وصول الإسعاف.'
      : '🚨 **This is an emergency.** Call emergency services now (**997** in Saudi Arabia, or your local number). Do not wait for replies here.\n\n' +
        '- If the person is **unconscious, having a seizure, severely confused or cannot swallow safely: give nothing by mouth** (no food, drink or sugar) — it can cause choking.\n' +
        '- If they have prescribed **emergency glucagon** and someone present knows how to use it, use it as instructed.\n' +
        '- Place them on their side and stay with them until help arrives.';
  }
  return lang === 'ar'
    ? '⚠️ **هذه الأعراض قد تحتاج تقييمًا طبيًا عاجلًا.** اتبع خطة الطوارئ التي وضعها فريقك الطبي، وتواصل معهم الآن أو توجه للطوارئ. إذا ساءت الحالة أو ظهر فقدان وعي أو تشنج أو صعوبة تنفس، اتصل بالإسعاف **997** فورًا.'
    : '⚠️ **These symptoms may need urgent medical assessment.** Follow the emergency plan from your care team and contact them now or go to the emergency department. If things get worse, or there is loss of consciousness, a seizure or trouble breathing, call **997** immediately.';
}

export function doseNotice(lang: 'ar' | 'en'): string {
  return lang === 'ar'
    ? 'لا أستطيع تحديد جرعات الإنسولين أو تغيير إعدادات الجهاز — هذا قرار يتخذه طبيبك أو فريق السكري بناءً على فحصك الكامل. اتبع خطتك الحالية، ويمكنني مساعدتك في تجهيز سؤال واضح لطبيبك.'
    : "I can't set insulin doses or change device settings — that decision belongs to your doctor or diabetes team. Keep following your current plan; I can help you prepare a clear question for them.";
}
