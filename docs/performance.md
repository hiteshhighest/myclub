# MyClub performance notes

## Query and state optimisations

- Membership reads are shared through `SupabaseCache`, with a short session TTL and in-flight request coalescing. Home renders fresh cached memberships immediately and refreshes in the background.
- Club detail tabs are lazy. Announcements, events, members, chat, and affiliations do not mount or query until their tab is opened.
- Club announcements, events, and members use bounded pages with scroll-triggered loading. Each query selects only fields rendered by that screen.
- Home uses an animated skeleton for its initial load. Event attendance and club visibility update optimistically and roll back when Supabase rejects the write.
- Refresh actions still force a network read, while normal navigation can reuse the cache. RLS and authentication remain enforced by Supabase for every network request.

## Recommended indexes

Verify existing indexes before creating duplicates. Apply these in Supabase migrations and validate each with `EXPLAIN (ANALYZE, BUFFERS)` on production-like data:

```sql
create index if not exists club_members_user_joined_idx
  on public.club_members (user_id, joined_at desc);

create index if not exists club_members_club_joined_idx
  on public.club_members (club_id, joined_at);

create index if not exists club_events_club_start_idx
  on public.club_events (club_id, starts_at);

create index if not exists announcements_club_pinned_created_idx
  on public.announcements (club_id, is_pinned desc, created_at desc);

create index if not exists event_attendees_user_event_idx
  on public.event_attendees (user_id, event_id);

create index if not exists event_attendees_event_user_idx
  on public.event_attendees (event_id, user_id);

create index if not exists announcement_attachments_announcement_created_idx
  on public.announcement_attachments (announcement_id, created_at);

create index if not exists club_chat_messages_club_created_idx
  on public.club_chat_messages (club_id, created_at);

create index if not exists club_verification_requests_club_created_idx
  on public.club_verification_requests (club_id, created_at desc);
```

The partial visibility predicates used by feeds depend on the existing RLS policies and should not be replaced with client-side filtering. For very large public feeds, review the SQL behind `get_public_verified_club_events` and index the columns used inside that function rather than adding a speculative client index.
