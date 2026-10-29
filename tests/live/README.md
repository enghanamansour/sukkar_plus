# Live backend checks (run in the Supabase SQL editor)

These scripts call the deployed API from inside Postgres using the `http` extension, so they work even where
your machine cannot. They need two confirmed test users (see `00_create_test_users.sql`).

1. `00_create_test_users.sql` — creates two synthetic, pre-confirmed QA users. **Test projects only.**
2. `01_pipeline.sql` — signs in as user B, uploads a tiny ASCII PDF to private storage, inserts the report row,
   calls `process-report`, and calls `chat` with an emergency message.
3. `02_isolation.sql` — signs in as user A and tries to read/process/download/forge user B's data. Every step must be blocked.
4. `99_cleanup.sql` — deletes the QA users (cascades to their rows) and drops the `http` extension.

Results observed on 2026-10-29 are recorded in the main README ("What was tested").
