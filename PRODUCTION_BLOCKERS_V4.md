# PRODUCTION BLOCKERS V4

## Resolved in this candidate
- Build-time Supabase client initialization is deferred/guarded.
- Server Supabase pages are explicitly dynamic.
- Client auth pages only create the browser client on interaction.

## Still required before production
1. Configure Vercel: NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY for Production and Preview.
2. Run a full Vercel build after env configuration.
3. Keep the current Supabase database unchanged until the seed/catalog values are approved.
4. Populate real billing plan catalog, Dynasty Shop catalog and Marketplace seller/listing data.
5. Verify write flows under authenticated RLS.
6. Upgrade from unsupported Next.js 14.x to a supported LTS line in a separate controlled change. Next.js currently lists 16.x as Active LTS and 15.x as Maintenance LTS.
