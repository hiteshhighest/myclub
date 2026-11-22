-- Sends INSERT webhooks to the push-notification Edge Function.
-- Before running, create a Supabase Vault secret named
-- `klubb_push_webhook_secret` whose value matches the Edge Function secret
-- `PUSH_WEBHOOK_SECRET`. Do not commit the secret value to this file.

create or replace function public.notify_push_notification_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  webhook_secret text;
begin
  select decrypted_secret
    into webhook_secret
    from vault.decrypted_secrets
   where name = 'klubb_push_webhook_secret'
   limit 1;

  if webhook_secret is null or webhook_secret = '' then
    raise exception 'Vault secret klubb_push_webhook_secret is missing';
  end if;

  perform net.http_post(
    url := 'https://xfmajzcgculfgecchntx.supabase.co/functions/v1/push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-klubb-webhook-secret', webhook_secret
    ),
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', tg_table_name,
      'schema', tg_table_schema,
      'record', to_jsonb(new),
      'old_record', null
    ),
    timeout_milliseconds := 5000
  );

  return new;
end;
$$;

revoke all on function public.notify_push_notification_insert() from public, anon, authenticated;

drop trigger if exists push_notification_announcements_insert on public.announcements;
create trigger push_notification_announcements_insert
  after insert on public.announcements
  for each row execute function public.notify_push_notification_insert();

drop trigger if exists push_notification_events_insert on public.club_events;
create trigger push_notification_events_insert
  after insert on public.club_events
  for each row execute function public.notify_push_notification_insert();

drop trigger if exists push_notification_chat_messages_insert on public.club_chat_messages;
create trigger push_notification_chat_messages_insert
  after insert on public.club_chat_messages
  for each row execute function public.notify_push_notification_insert();
