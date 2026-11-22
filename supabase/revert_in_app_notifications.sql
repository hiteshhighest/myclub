-- Removes the in-app notification table, policies, triggers, and helper RPC
-- created by the earlier notifications.sql migration.

drop trigger if exists notifications_on_announcement on public.announcements;
drop trigger if exists notifications_on_event on public.club_events;
drop function if exists public.notify_club_announcement();
drop function if exists public.notify_club_event();
drop function if exists public.create_invitation_notification(uuid, uuid, text);

do $$
begin
  if exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime drop table public.notifications;
  end if;
end;
$$;

drop table if exists public.notifications cascade;
