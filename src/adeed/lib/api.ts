import { supabase } from './supabase';
import type { StoredReport } from '@core/compare';
import type { QualityCheck } from '@core/parser';

export interface Profile {
  id: string;
  full_name: string | null;
  preferred_language: 'ar' | 'en';
  diabetes_type: 'type1' | 'type2' | 'gestational' | 'other' | 'unknown';
  next_appointment_at: string | null;
  clinic_name: string | null;
  appointment_notes: string | null;
}

export interface MetricRow {
  metric_key: string;
  category: string;
  value: number | null;
  value_text: string | null;
  unit: string | null;
  status: 'extracted' | 'calculated' | 'unavailable' | 'uncertain';
  source_page: number | null;
  source_label: string | null;
  note: string | null;
}

export interface Report extends StoredReport {
  user_id: string;
  title: string | null;
  file_path: string;
  file_name: string;
  file_size: number | null;
  status: 'uploaded' | 'processing' | 'processed' | 'failed';
  error_code: string | null;
  error_message: string | null;
  source_system: string | null;
  device: string | null;
  generated_on: string | null;
  name_on_report: string | null;
  page_count: number | null;
  quality: { score?: 'good' | 'fair' | 'poor'; checks?: QualityCheck[]; target_range?: { low: number; high: number; unit: string } | null };
  created_at: string;
  processed_at: string | null;
  metrics: MetricRow[];
}

export interface LabResult {
  id: string;
  test_key: 'hba1c';
  value: number;
  unit: '%';
  measured_on: string;
  source: 'manual' | 'demo' | 'report';
  report_id: string | null;
  note: string | null;
  is_demo: boolean;
}

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

export interface DoctorQuestion {
  id: string;
  report_id: string | null;
  rule_key: string | null;
  question: string;
  rationale: string | null;
  evidence: Evidence[];
  basis: 'finding' | 'comparison' | 'data_gap' | 'custom';
  is_uncertain: boolean;
  is_saved: boolean;
  is_edited: boolean;
  generated_by: 'rules' | 'assistant' | 'user';
  position: number;
  created_at: string;
}

export interface ChatMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  flags: { safety?: 'emergency' | 'urgent'; dose_request?: boolean; provider?: string; local?: boolean };
  created_at: string;
}

export class ApiError extends Error {
  constructor(public code: string, message: string, public extra: Record<string, unknown> = {}) { super(message); }
}

function check<T>(res: { data: T; error: { message: string; code?: string } | null }): T {
  if (res.error) throw new ApiError(res.error.code ?? 'db_error', res.error.message);
  return res.data;
}

// ───────── profile
export async function getProfile(): Promise<Profile | null> {
  return check(await supabase.from('profiles').select('*').maybeSingle()) as Profile | null;
}
export async function updateProfile(id: string, patch: Partial<Omit<Profile, 'id'>>): Promise<void> {
  check(await supabase.from('profiles').update(patch).eq('id', id));
}

// ───────── reports
const REPORT_SELECT = '*, metrics:report_metrics(metric_key, category, value, value_text, unit, status, source_page, source_label, note)';

export async function listReports(): Promise<Report[]> {
  const data = check(await supabase.from('reports').select(REPORT_SELECT)
    .order('period_end', { ascending: false, nullsFirst: true }).order('created_at', { ascending: false }));
  return (data ?? []) as unknown as Report[];
}

export const MAX_PDF_BYTES = 10 * 1024 * 1024;

export async function uploadReport(userId: string, file: File | Blob, fileName: string, isDemo = false): Promise<string> {
  if (file.size > MAX_PDF_BYTES) throw new ApiError('too_large', 'File larger than 10 MB');
  const head = new Uint8Array(await file.slice(0, 5).arrayBuffer());
  if (String.fromCharCode(...head).slice(0, 4) !== '%PDF') throw new ApiError('not_pdf', 'Not a PDF');
  const path = `${userId}/${crypto.randomUUID()}.pdf`;
  const up = await supabase.storage.from('reports').upload(path, file, { contentType: 'application/pdf', upsert: false });
  if (up.error) throw new ApiError('upload_failed', up.error.message);
  const ins = await supabase.from('reports').insert({ file_path: path, file_name: fileName.slice(0, 255), file_size: file.size, is_demo: isDemo })
    .select('id').single();
  if (ins.error) {
    await supabase.storage.from('reports').remove([path]);
    throw new ApiError('db_error', ins.error.message);
  }
  return ins.data.id as string;
}

async function invoke<T>(fn: string, body: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.functions.invoke(fn, { body });
  if (error) {
    let payload: any = null;
    try { payload = await (error as any).context?.json?.(); } catch { /* ignore */ }
    const e = payload?.error;
    throw new ApiError(e?.code ?? 'network', e?.message ?? error.message, payload ?? {});
  }
  return data as T;
}

export function processReport(reportId: string) {
  return invoke<{ ok: boolean; questions_created: number; quality: string }>('process-report', { report_id: reportId });
}
export function regenerateQuestions(reportId: string) {
  return invoke<{ ok: boolean; questions_created: number }>('process-report', { report_id: reportId, action: 'regenerate_questions' });
}

export async function deleteReport(r: Pick<Report, 'id' | 'file_path'>): Promise<void> {
  await supabase.storage.from('reports').remove([r.file_path]);
  check(await supabase.from('reports').delete().eq('id', r.id));
}

export async function signedPdfUrl(path: string): Promise<string> {
  const { data, error } = await supabase.storage.from('reports').createSignedUrl(path, 120);
  if (error || !data) throw new ApiError('signed_url', error?.message ?? 'failed');
  return data.signedUrl;
}

// ───────── labs (HbA1c, kept separate from GMI)
export async function listLabs(): Promise<LabResult[]> {
  return (check(await supabase.from('lab_results').select('*').order('measured_on', { ascending: false })) ?? []) as LabResult[];
}
export async function addLab(value: number, measuredOn: string, note: string | null, isDemo = false): Promise<void> {
  check(await supabase.from('lab_results').insert({ test_key: 'hba1c', value, unit: '%', measured_on: measuredOn, note, source: isDemo ? 'demo' : 'manual', is_demo: isDemo }));
}
export async function deleteLab(id: string): Promise<void> {
  check(await supabase.from('lab_results').delete().eq('id', id));
}

// ───────── doctor questions
export async function listQuestions(): Promise<DoctorQuestion[]> {
  return (check(await supabase.from('doctor_questions').select('*').order('report_id').order('position')) ?? []) as DoctorQuestion[];
}
export async function updateQuestion(id: string, patch: Partial<Pick<DoctorQuestion, 'question' | 'is_saved' | 'is_edited'>>): Promise<void> {
  check(await supabase.from('doctor_questions').update(patch).eq('id', id));
}
export async function addCustomQuestion(question: string, reportId: string | null): Promise<void> {
  check(await supabase.from('doctor_questions').insert({ question, report_id: reportId, basis: 'custom', generated_by: 'user', is_saved: true, position: 999 }));
}
export async function deleteQuestion(id: string): Promise<void> {
  check(await supabase.from('doctor_questions').delete().eq('id', id));
}

// ───────── chat
export async function listChat(): Promise<ChatMessage[]> {
  return (check(await supabase.from('chat_messages').select('id, role, content, flags, created_at').order('created_at').limit(200)) ?? []) as ChatMessage[];
}
export async function clearChat(userId: string): Promise<void> {
  check(await supabase.from('chat_messages').delete().eq('user_id', userId));
}
export interface ChatReply {
  configured?: boolean;
  message?: ChatMessage;
  error?: { code: string; message: string };
  safety?: { level: 'emergency' | 'urgent'; notice: string } | null;
  dose_notice?: string | null;
}
export async function sendChat(message: string, lang: 'ar' | 'en'): Promise<ChatReply> {
  const { data, error } = await supabase.functions.invoke('chat', { body: { message, lang } });
  if (error) {
    try {
      const payload = await (error as any).context?.json?.();
      if (payload) return payload as ChatReply;
    } catch { /* ignore */ }
    return { error: { code: 'network', message: error.message } };
  }
  return data as ChatReply;
}

// ───────── account data
export async function deleteAllMyData(userId: string, reports: Report[], demoOnly = false): Promise<void> {
  const target = reports.filter((r) => !demoOnly || r.is_demo);
  if (target.length) await supabase.storage.from('reports').remove(target.map((r) => r.file_path));
  let q = supabase.from('reports').delete().eq('user_id', userId);
  if (demoOnly) q = q.eq('is_demo', true);
  check(await q);
  let l = supabase.from('lab_results').delete().eq('user_id', userId);
  if (demoOnly) l = l.eq('is_demo', true);
  check(await l);
  if (!demoOnly) {
    check(await supabase.from('doctor_questions').delete().eq('user_id', userId));
    check(await supabase.from('chat_messages').delete().eq('user_id', userId));
  }
}
