// UI walkthrough with a mocked Supabase API (fixtures come from the real parser — see make-fixtures.ts).
// Usage: npm run dev (port 5173) then: node tests/e2e/ui-walkthrough.mjs [outDir]
import { createRequire } from 'node:module';
const { chromium } = createRequire(import.meta.url)('playwright');
import { readFileSync, mkdirSync } from 'node:fs';

const OUT = process.argv[2] ?? 'tests/e2e/screens';
mkdirSync(OUT, { recursive: true });
const fx = JSON.parse(readFileSync(new URL('./fixtures.json', import.meta.url)));
const SB = 'bmoblgikggxaidntdakx.supabase.co';
const user = { id: fx.uid, aud: 'authenticated', role: 'authenticated', email: 'qa.patient.a@adeed-test.dev', user_metadata: { full_name: 'Fatima Al-Qahtani' } };
const profile = { id: fx.uid, full_name: 'Fatima Al-Qahtani', preferred_language: 'ar', diabetes_type: 'type1', next_appointment_at: '2026-11-12T07:30:00Z', clinic_name: 'عيادة السكري', appointment_notes: null };
const state = { questions: structuredClone(fx.questions), chat: [] };
const errors = [];

async function mock(page, { chatMode = 'notConfigured' } = {}) {
  await page.route(`https://${SB}/**`, async (route) => {
    const req = route.request(); const url = new URL(req.url()); const p = url.pathname; const m = req.method();
    const j = (body, status = 200) => route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body), headers: { 'access-control-allow-origin': '*' } });
    if (m === 'OPTIONS') return route.fulfill({ status: 200, headers: { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': '*' } });
    if (p === '/auth/v1/token') return j({ access_token: 'mock.jwt.token', token_type: 'bearer', expires_in: 3600, expires_at: Math.floor(Date.now() / 1000) + 3600, refresh_token: 'r', user });
    if (p === '/auth/v1/user') return j(user);
    if (p === '/auth/v1/logout') return j({});
    if (p === '/rest/v1/profiles') return m === 'GET' ? j(profile) : j([]);
    if (p === '/rest/v1/reports') return j(fx.reports);
    if (p === '/rest/v1/lab_results') return j(fx.labs);
    if (p === '/rest/v1/doctor_questions') {
      if (m === 'PATCH') { const id = url.searchParams.get('id')?.replace('eq.', ''); const patch = JSON.parse(req.postData()); state.questions = state.questions.map((q) => q.id === id ? { ...q, ...patch } : q); return j([]); }
      return j(state.questions);
    }
    if (p === '/rest/v1/chat_messages') return j(state.chat);
    if (p === '/functions/v1/chat') {
      if (chatMode === 'notConfigured') return j({ configured: false, error: { code: 'ai_not_configured', message: 'not configured' }, safety: null }, 503);
      const msg = { id: 'a1', role: 'assistant', content: 'هذا رد تجريبي.\n\n- **نقطة** أولى\n- نقطة ثانية', flags: { provider: 'groq' }, created_at: new Date().toISOString() };
      return j({ configured: true, message: msg });
    }
    return j({ message: `unmocked ${m} ${p}` }, 404);
  });
}

const browser = await chromium.launch();
async function run(name, { lang = 'ar', theme = 'light', width = 390 } = {}, steps) {
  const ctx = await browser.newContext({ viewport: { width, height: 844 }, deviceScaleFactor: 2 });
  await ctx.addInitScript(([l, th]) => { localStorage.setItem('sehhaty-mockup.language', l); localStorage.setItem('sehhaty-mockup.theme', th); }, [lang, theme]);
  const page = await ctx.newPage();
  page.on('pageerror', (e) => errors.push(`${name}: ${e.message}`));
  page.on('console', (msg) => { if (msg.type() === 'error' && !/404|Failed to load resource/.test(msg.text())) errors.push(`${name}: ${msg.text()}`); });
  await mock(page);
  await steps(page);
  await ctx.close();
}
const shot = (page, n) => page.screenshot({ path: `${OUT}/${n}.png`, fullPage: true });
const BASE = 'http://localhost:5173/my-profile/diabetes-journey';

await run('ar-light', {}, async (page) => {
  await page.goto(BASE);
  await page.getByRole('heading', { name: 'تسجيل الدخول' }).waitFor();
  await shot(page, '01-auth-ar');
  await page.getByLabel('البريد الإلكتروني').fill('qa.patient.a@adeed-test.dev');
  await page.getByLabel('كلمة المرور').fill('x-password');
  await page.getByRole('button', { name: 'تسجيل الدخول' }).click();
  await page.getByText('أحدث تقرير').waitFor();
  await shot(page, '02-home-ar');
  await page.getByRole('button', { name: 'عرض التقرير' }).click();
  await page.getByText('توزيع الوقت على النطاقات').waitFor();
  await shot(page, '03-report-ar');
  await page.getByRole('button', { name: 'عرض كجدول' }).click();
  await page.locator('.ad-range table').waitFor();
  await page.locator('.ad-subnav').getByText('أسئلة الطبيب').click();
  await page.getByRole('heading', { name: 'أسئلة لطبيبك' }).waitFor();
  await page.locator('.ad-q__why summary').first().click();
  await shot(page, '04-questions-ar');
  await page.locator('.ad-subnav').getByText('السجل').click();
  await page.getByText('تقارير الحساس').waitFor();
  await shot(page, '05-history-ar');
  await page.locator('.ad-subnav').getByText('الموعد').click();
  await page.getByText('ملخص الموعد').first().waitFor();
  await shot(page, '06-appointment-ar');
  await page.locator('.ad-subnav').getByText('المساعد').click();
  await page.getByPlaceholder('اكتب سؤالك…').fill('أبوي فاقد الوعي والسكر منخفض');
  await page.getByRole('button', { name: 'إرسال' }).click();
  await page.getByText('تنبيه طوارئ').waitFor();
  await page.getByText('المساعد الذكي غير مفعّل').waitFor();
  await shot(page, '07-chat-emergency-ar');
});

await run('en-dark', { lang: 'en', theme: 'dark' }, async (page) => {
  await page.goto(BASE);
  await page.getByLabel('Email').fill('qa.patient.a@adeed-test.dev');
  await page.getByLabel('Password').fill('x');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.getByText('Latest report').waitFor();
  await shot(page, '08-home-en-dark');
  await page.getByRole('button', { name: 'View report' }).click();
  await page.getByText('Time in ranges').first().waitFor();
  await shot(page, '09-report-en-dark');
});

await run('desktop', { width: 1280 }, async (page) => {
  await page.goto(BASE);
  await page.getByLabel('البريد الإلكتروني').fill('qa.patient.a@adeed-test.dev');
  await page.getByLabel('كلمة المرور').fill('x');
  await page.getByRole('button', { name: 'تسجيل الدخول' }).click();
  await page.getByText('أحدث تقرير').waitFor();
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth);
  if (overflow) errors.push('desktop: horizontal overflow');
  await shot(page, '10-home-desktop');
});

await browser.close();
console.log(errors.length ? `ERRORS:\n${errors.join('\n')}` : 'UI walkthrough passed with no page errors');
process.exit(errors.length ? 1 : 0);
