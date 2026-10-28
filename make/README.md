# Make.com follow-up notification (optional)

The mobile app never calls Make.com. The `followup-dispatch` Edge Function sends one minimal event per submission:

```json
{
  "schema_version": 1,
  "event_type": "followup.submitted",
  "request_ref": "REQ-7Q2K9D",
  "status": "awaiting_review",
  "trigger_type": "rule",
  "rule_ids": ["EPI54-REPEATED", "TBR54-TARGET"],
  "rules_version": "2026.10-demo.1",
  "submitted_at": "2026-10-28T10:00:00.000Z",
  "environment": "demo"
}
```

It never contains names, national IDs, dates of birth, user IDs, metric or lab values, the shared snapshot, the reason text, or PDFs (enforced by `assertMinimal` in `supabase/functions/_shared/payload.ts` and by tests). The same file is in `example_payload.json`.

## Scenario (suggested)

1. **Webhooks → Custom webhook.** Create a webhook named `sukkar-plus-followup`.
   * Under **API Key authentication**, add a key (store it; Make will not show it again). The function sends it in the `x-make-apikey` header.
   * Optionally restrict **IP restrictions** to your Supabase region's egress addresses.
   * **Data structure:** create one from `example_payload.json` so Make rejects malformed requests (HTTP 400).
2. Add a demo action, for example **Google Sheets → Add a row** (columns: request_ref, status, trigger_type, rule_ids, submitted_at, environment) or **Slack → Create a message** to a test channel.
3. Add **Webhooks → Webhook response** with status 200 (so the function records `sent`).
4. Turn the scenario on and copy the webhook URL.

## Configure the backend

```powershell
supabase secrets set MAKE_WEBHOOK_URL=<webhook url> MAKE_WEBHOOK_API_KEY=<key>
```

## Behaviour

* Timeout 8 s per attempt; up to 3 attempts with exponential backoff for network errors, timeouts, 408, 429 and 5xx. Other 4xx responses fail immediately.
* Idempotency: each submission has the key `<request id>:followup.submitted:<submission number>` stored with a UNIQUE constraint in `integration_events`; the same submission is never sent twice. The key is also sent as the `idempotency-key` header so a scenario can de-duplicate.
* Failures are stored with the error code and shown to the patient and reviewer ("فشل الإرسال") with a **إعادة المحاولة** button (`action: "retry"`).
* Without `MAKE_WEBHOOK_URL` the function records `adapter = local_mock`, `state = mock_recorded`, and the app labels it as a mock.

No real scenario was triggered while building this project; the URL above is a placeholder.
