-- Per-user club push notification preferences.
-- Users can read and change only their own preference for clubs they belong to.

create table if not exists public.club_notification_preferences (
  user_id uuid not null references auth.users(id) on delete cascade,
  club_id uuid not null references public.clubs(id) on delete cascade,
  muted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, club_id)
);

create index if not exists club_notification_preferences_muted_idx
  on public.club_notification_preferences (club_id, user_id)
  where muted = true;

alter table public.club_notification_preferences enable row level security;
revoke all on public.club_notification_preferences from public, anon;
grant select, insert, update on public.club_notification_preferences to authenticated;

drop policy if exists "Users read their own club notification preferences"
  on public.club_notification_preferences;
create policy "Users read their own club notification preferences"
  on public.club_notification_preferences
  for select to authenticated
  using (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.club_members cm
      where cm.club_id = club_notification_preferences.club_id
        and cm.user_id = (select auth.uid())
    )
  );

drop policy if exists "Users create their own club notification preferences"
  on public.club_notification_preferences;
create policy "Users create their own club notification preferences"
  on public.club_notification_preferences
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.club_members cm
      where cm.club_id = club_notification_preferences.club_id
        and cm.user_id = (select auth.uid())
    )
  );

drop policy if exists "Users update their own club notification preferences"
  on public.club_notification_preferences;
create policy "Users update their own club notification preferences"
  on public.club_notification_preferences
  for update to authenticated
  using (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.club_members cm
      where cm.club_id = club_notification_preferences.club_id
        and cm.user_id = (select auth.uid())
    )
  )
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.club_members cm
      where cm.club_id = club_notification_preferences.club_id
        and cm.user_id = (select auth.uid())
    )
  );
