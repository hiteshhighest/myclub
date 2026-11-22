-- Firebase direct-send registration IDs (FIDs) for device push delivery.
-- Run in Supabase Dashboard > SQL Editor after deploying the Edge Function.

create table if not exists public.device_push_tokens (
  token text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios', 'web')),
  updated_at timestamptz not null default now()
);

create index if not exists device_push_tokens_user_idx
  on public.device_push_tokens(user_id);

alter table public.device_push_tokens enable row level security;
alter table public.device_push_tokens
  drop constraint if exists device_push_tokens_platform_check;
alter table public.device_push_tokens
  add constraint device_push_tokens_platform_check
  check (platform in ('android', 'ios', 'web'));
revoke all on public.device_push_tokens from anon, authenticated;
grant select, delete on public.device_push_tokens to service_role;

create or replace function public.register_device_push_token(
  p_token text,
  p_platform text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_token is null or length(p_token) < 20 then raise exception 'Invalid device token'; end if;
  if p_platform not in ('android', 'ios', 'web') then raise exception 'Unsupported platform'; end if;

  -- A single FCM token belongs to the account currently signed in on that device.
  delete from public.device_push_tokens where token = p_token;
  insert into public.device_push_tokens(token, user_id, platform, updated_at)
  values (p_token, auth.uid(), p_platform, now());
end;
$$;

create or replace function public.unregister_device_push_token(p_token text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  delete from public.device_push_tokens
  where token = p_token and user_id = auth.uid();
end;
$$;

revoke all on function public.register_device_push_token(text, text) from public, anon;
revoke all on function public.unregister_device_push_token(text) from public, anon;
grant execute on function public.register_device_push_token(text, text) to authenticated;
grant execute on function public.unregister_device_push_token(text) to authenticated;
