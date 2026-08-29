# CHALLENGE DYNASTY — Supabase

Use **only** `schema_master.sql` for a fresh project.

1. Create a Supabase project.
2. Open SQL Editor.
3. Run `schema_master.sql` once.
4. Create `.env.local` from `.env.example`.
5. Start Next.js.

For the 12-hour automatic confirmation, configure a Supabase Scheduled Function/cron to call:

```sql
select public.auto_confirm_due_matches();
```
