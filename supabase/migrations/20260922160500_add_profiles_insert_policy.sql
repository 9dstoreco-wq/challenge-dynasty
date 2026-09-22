-- Fix: new user signup could never create a public.profiles row.
-- profiles had SELECT and UPDATE policies but no INSERT policy, so
-- onboarding's player_sports write failed with a foreign key violation
-- (player_sports_profile_id_fkey) for every new user. This adds the
-- missing policy, scoped to a user inserting only their own row.
create policy "profiles own insert" on public.profiles
  for insert
  to authenticated
  with check (id = (select auth.uid()));
