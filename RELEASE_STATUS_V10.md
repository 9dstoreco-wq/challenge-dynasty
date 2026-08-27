# CHALLENGE DYNASTY — MASTER PLATFORM V10

## Added
- Dedicated AI product surfaces:
  - /coach-ai
  - /fitness-intelligence
  - /club-intelligence
  - /coach-intelligence
  - /tournament-intelligence
  - /commerce-intelligence
- GitHub Actions CI for install, verification and build.
- Single-source release strategy remains GitHub -> Vercel.

## Important
These pages are product surfaces and contracts. They are not claimed to be a finished LLM runtime.
Actual AI execution requires a configured model provider/API, prompt orchestration, telemetry, permissions and product-specific data access.

## Verification limitation
A real package-lock.json could not be generated in this environment because npm registry resolution timed out. Do not fabricate a lockfile.
The GitHub CI workflow intentionally uses `npm install` until a real lockfile is committed.

## Production blockers
- Vercel project must be visible/connected to the active Vercel team.
- Supabase env vars must be configured in Vercel.
- AI provider credentials must be configured for AI runtime.
- Billing catalog and payment provider must be approved.
- Real end-to-end build must pass in CI/Vercel.
