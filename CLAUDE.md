# CLAUDE.md — weflix-app (Supabase backend)

Rules for any agent working in this repo. They exist because, in one session,
schema was applied to the remote DB outside the migration system (twice),
feature files were left uncommitted, and a DB backup nearly got committed.
Follow them without exception.

## Database schema changes
1. Schema changes go through a committed migration file applied with
   `supabase db push`. Nothing else.
   - NEVER apply schema via `supabase db query -f`, the dashboard SQL editor,
     MCP "apply migration", or the Management API. They bypass the migration
     ledger and create drift.
   - `supabase db query --linked` is allowed ONLY for read-only inspection
     (SELECT, pg_catalog, information_schema). Never DDL or write DML.
2. A migration is not done until BOTH: applied via `supabase db push`, AND its
   file committed to git. Do both, together.
3. Definition of done for schema work: `supabase migration list` shows local and
   remote aligned, and `supabase db push --dry-run` reports nothing pending.
4. Migrations must be rebuild-safe: use `CREATE OR REPLACE`, `IF NOT EXISTS`, and
   `DROP ... IF EXISTS` before `CREATE TRIGGER`/`CREATE POLICY`.

## When something is already drifted
5. If push or its dry-run reports a mismatch, STOP. Do not work around it with
   raw SQL. Report it and wait — working around drift is what creates drift.
6. `supabase migration repair` only to record VERIFIED reality: `--status applied`
   after confirming objects exist and match the file; never `--status reverted`
   to silence an error you don't understand.

## Edge Functions
7. Committing a function to git does NOT deploy it. Deploy with
   `supabase functions deploy <name>`; confirm with `supabase functions list`.
   Git state and deployed state are independent.
8. Deploy via the Supabase CLI, not MCP — MCP is unreliable when functions share
   modules (`../_shared/`).

## Git hygiene (this repo specifically)
9. This repo's history also contains the frontend app, and the working tree holds
   frontend files, OS junk, and sometimes DB dumps. NEVER `git add -A` or
   `git add .`. Stage explicit paths only.
10. Never commit DB dumps/backups (*.dump) or secrets. Keep them out of the repo.

## General
11. Read relevant files before changing anything; identify conflicts; get explicit
    approval before modifying files or the database; commit and push after.
12. Secrets stay server-side. The TMDB API key lives only in Edge Function env
    config — never in a frontend .env or committed file.
