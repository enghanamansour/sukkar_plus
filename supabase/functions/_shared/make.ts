// Backend-only Make.com webhook client with timeout, bounded retries and
// API-key authentication (Make custom webhooks read the key from the
// `x-make-apikey` header). The mobile app never calls Make directly.

export type FetchLike = (input: string, init: RequestInit) => Promise<Response>;

export interface MakeConfig {
  webhookUrl: string;
  apiKey?: string;
  timeoutMs?: number;
  maxAttempts?: number;
  backoffMs?: number;
}

export interface MakeResult {
  state: 'sent' | 'failed';
  attempts: number;
  status?: number;
  error?: string;
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export async function postToMake(
  cfg: MakeConfig,
  payload: Record<string, unknown>,
  idempotencyKey: string,
  fetchImpl: FetchLike = fetch,
): Promise<MakeResult> {
  const timeoutMs = cfg.timeoutMs ?? 8000;
  const maxAttempts = Math.max(1, Math.min(cfg.maxAttempts ?? 3, 5));
  const backoff = cfg.backoffMs ?? 500;
  let lastError = '';
  let lastStatus: number | undefined;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), timeoutMs);
    try {
      const res = await fetchImpl(cfg.webhookUrl, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'idempotency-key': idempotencyKey,
          ...(cfg.apiKey ? { 'x-make-apikey': cfg.apiKey } : {}),
        },
        body: JSON.stringify(payload),
        signal: ctrl.signal,
      });
      lastStatus = res.status;
      if (res.ok) return { state: 'sent', attempts: attempt, status: res.status };
      lastError = `http_${res.status}`;
      // 4xx (except 408/429) will not succeed on retry.
      if (res.status >= 400 && res.status < 500 && res.status !== 408 && res.status !== 429) {
        return { state: 'failed', attempts: attempt, status: res.status, error: lastError };
      }
    } catch (e) {
      lastError = (e as Error).name === 'AbortError' ? 'timeout' : 'network_error';
    } finally {
      clearTimeout(timer);
    }
    if (attempt < maxAttempts) await sleep(backoff * 2 ** (attempt - 1));
  }
  return { state: 'failed', attempts: maxAttempts, status: lastStatus, error: lastError };
}
