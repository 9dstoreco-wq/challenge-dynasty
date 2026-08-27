-- Dynasty AI security/performance hardening
-- Applied to the live Supabase project and retained here for repository parity.

revoke execute on function public.get_dynasty_ai_context() from public;
revoke execute on function public.get_dynasty_ai_context() from anon;
grant execute on function public.get_dynasty_ai_context() to authenticated, service_role;
alter function public.get_dynasty_ai_context() set search_path = public, pg_temp;

revoke execute on function public.has_ai_entitlement(text, uuid, uuid, uuid) from public;
revoke execute on function public.has_ai_entitlement(text, uuid, uuid, uuid) from anon;
grant execute on function public.has_ai_entitlement(text, uuid, uuid, uuid) to authenticated, service_role;
alter function public.has_ai_entitlement(text, uuid, uuid, uuid) set search_path = public, pg_temp;

create or replace function public.has_ai_entitlement(
  p_feature_key text,
  p_profile_id uuid default auth.uid(),
  p_organization_id uuid default null,
  p_seller_profile_id uuid default null
)
returns boolean
language sql
security definer
set search_path = public, pg_temp
as $function$
  select exists (
    select 1
    from public.billing_entitlements e
    where e.feature_key = p_feature_key
      and (e.ends_at is null or e.ends_at > now())
      and (
        (p_profile_id is not null and p_profile_id = auth.uid() and e.profile_id = auth.uid())
        or (
          p_organization_id is not null
          and e.organization_id = p_organization_id
          and exists (
            select 1 from public.organization_memberships om
            where om.organization_id = p_organization_id
              and om.profile_id = auth.uid()
              and om.status = 'active'
          )
        )
        or (
          p_seller_profile_id is not null
          and e.seller_profile_id = p_seller_profile_id
          and exists (
            select 1 from public.marketplace_seller_profiles msp
            where msp.id = p_seller_profile_id
              and msp.owner_id = auth.uid()
          )
        )
      )
  );
$function$;

drop policy if exists ai_conversations_owner_all on public.ai_conversations;
create policy ai_conversations_owner_all on public.ai_conversations
  as permissive for all to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

drop policy if exists ai_messages_conversation_owner_select on public.ai_messages;
drop policy if exists ai_messages_owner_all on public.ai_messages;
create policy ai_messages_owner_all on public.ai_messages
  as permissive for all to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

drop policy if exists ai_memory_notes_owner_all on public.ai_memory_notes;
create policy ai_memory_notes_owner_all on public.ai_memory_notes
  as permissive for all to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

drop policy if exists ai_daily_coach_sessions_owner_all on public.ai_daily_coach_sessions;
create policy ai_daily_coach_sessions_owner_all on public.ai_daily_coach_sessions
  as permissive for all to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

drop policy if exists ai_usage_events_owner_read on public.ai_usage_events;
create policy ai_usage_events_owner_read on public.ai_usage_events
  as permissive for select to authenticated
  using (profile_id = (select auth.uid()));

create index if not exists ai_memory_notes_source_message_id_idx
  on public.ai_memory_notes(source_message_id);
create index if not exists ai_messages_profile_id_idx
  on public.ai_messages(profile_id);
