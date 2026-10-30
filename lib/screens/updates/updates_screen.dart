import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/supabase_cache.dart';
import '../../core/theme.dart';

import '../clubs/club_detail_screen.dart';

enum _UpdateFilter { all, events, announcements }

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _memberships = [];
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  _UpdateFilter _filter = _UpdateFilter.all;
  final Set<String> _joinedEventIds = <String>{};
  final Set<String> _attendanceBusy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final user = _db.auth.currentUser;
      if (user == null) throw Exception('Please sign in again.');

      final memberships = await SupabaseCache.instance.getMemberships(
        _db,
        user.id,
      );
      final ids = memberships
          .map((m) => m['club_id'].toString())
          .toSet()
          .toList();
      final roles = <String, String>{
        for (final m in memberships)
          m['club_id'].toString(): m['role']?.toString() ?? 'member',
      };
      final clubNames = <String, String>{
        for (final m in memberships)
          m['club_id'].toString():
              (m['clubs'] is Map ? m['clubs']['name']?.toString() : null) ??
              'Club',
      };

      final items = <Map<String, dynamic>>[];
      final joinedRows = await _db
          .from('event_attendees')
          .select('event_id')
          .eq('user_id', user.id);
      final joinedIds = (joinedRows as List)
          .map((row) => (row as Map)['event_id'].toString())
          .toSet();
      if (ids.isNotEmpty) {
        final now = DateTime.now().toUtc().toIso8601String();
        final results = await Future.wait([
          _db
              .from('club_events')
              .select(
                'id, club_id, title, description, starts_at, location, visibility, external_url, is_public',
              )
              .inFilter('club_id', ids)
              .gte('starts_at', now)
              .order('starts_at')
              .limit(100),
          _db
              .from('announcements')
              .select(
                'id, club_id, title, body, is_pinned, created_at, visibility, created_by, external_url',
              )
              .inFilter('club_id', ids)
              .order('is_pinned', ascending: false)
              .order('created_at', ascending: false)
              .limit(100),
        ]);

        for (final row in results[0] as List) {
          final item = Map<String, dynamic>.from(row as Map);
          final clubId = item['club_id'].toString();
          if (item['visibility'] == 'executives' &&
              !['owner', 'executive'].contains(roles[clubId]))
            continue;
          item['_kind'] = 'event';
          item['_when'] = DateTime.tryParse(
            item['starts_at']?.toString() ?? '',
          );
          item['_club_name'] = clubNames[clubId] ?? 'Club';
          items.add(item);
        }
        for (final row in results[1] as List) {
          final item = Map<String, dynamic>.from(row as Map);
          final clubId = item['club_id'].toString();
          if (item['visibility'] == 'executives' &&
              !['owner', 'executive'].contains(roles[clubId]))
            continue;
          item['_kind'] = 'announcement';
          item['_when'] = DateTime.tryParse(
            item['created_at']?.toString() ?? '',
          );
          item['_club_name'] = clubNames[clubId] ?? 'Club';
          items.add(item);
        }
      }

      // Public events from verified clubs are included even when the viewer is not a member.
      final publicEvents = await _db.rpc('get_public_verified_club_events');
      final seenEventIds = items
          .where((i) => i['_kind'] == 'event')
          .map((i) => i['id'].toString())
          .toSet();
      for (final row in publicEvents as List) {
        final item = Map<String, dynamic>.from(row as Map);
        if (seenEventIds.contains(item['id'].toString())) continue;
        item['_kind'] = 'event';
        item['_when'] = DateTime.tryParse(item['starts_at']?.toString() ?? '');
        item['_club_name'] = item['club_name']?.toString() ?? 'Verified club';
        item['_global_public'] = true;
        items.add(item);
      }

      items.sort((a, b) {
        final aDate = a['_when'] as DateTime?;
        final bDate = b['_when'] as DateTime?;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      if (!mounted) return;
      setState(() {
        _memberships = memberships;
        _items = items;
        _joinedEventIds
          ..clear()
          ..addAll(joinedIds);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  bool _matches(Map<String, dynamic> item) => switch (_filter) {
    _UpdateFilter.all => true,
    _UpdateFilter.events => item['_kind'] == 'event',
    _UpdateFilter.announcements => item['_kind'] == 'announcement',
  };

  Future<void> _showEventDetails(Map<String, dynamic> item) async {
    final eventId = item['id'].toString();
    final matchingMemberships = _memberships
        .where((m) => m['club_id'].toString() == item['club_id'].toString())
        .toList();
    final memberRecord = matchingMemberships.isEmpty
        ? null
        : matchingMemberships.first;
    final memberRole = memberRecord?['role']?.toString() ?? 'member';
    final canJoin =
        item['_kind'] == 'event' &&
        (item['visibility'] == 'public' ||
            (item['visibility'] == 'all_members' && memberRecord != null) ||
            (item['visibility'] == 'executives' &&
                ['owner', 'executive'].contains(memberRole)));
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final joined = _joinedEventIds.contains(eventId);
          final busy = _attendanceBusy.contains(eventId);
          return AlertDialog(
            title: Text(item['title']?.toString() ?? 'Event'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['_club_name']?.toString() ?? 'Club',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _dateLabel(
                      item['starts_at'] ?? item['created_at'],
                      includeTime: true,
                    ),
                  ),
                  if ((item['location'] ?? '')
                      .toString()
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Location: ${item['location']}'),
                  ],
                  if ((item['description'] ?? item['body'] ?? '')
                      .toString()
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text((item['description'] ?? item['body']).toString()),
                  ],
                  if (item['_kind'] == 'event') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            item['visibility'] == 'public'
                                ? Icons.public_rounded
                                : item['visibility'] == 'executives'
                                ? Icons.admin_panel_settings_outlined
                                : Icons.groups_2_outlined,
                            size: 20,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              item['visibility'] == 'public'
                                  ? 'Public event — anyone with a Klubb account can join without becoming a club member.'
                                  : item['visibility'] == 'executives'
                                  ? 'This event is for club executives only.'
                                  : 'This event is for club members.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (canJoin)
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          final wasJoined = joined;
                          _attendanceBusy.add(eventId);
                          if (wasJoined) {
                            _joinedEventIds.remove(eventId);
                          } else {
                            _joinedEventIds.add(eventId);
                          }
                          setDialogState(() {});
                          try {
                            if (wasJoined) {
                              await _db
                                  .from('event_attendees')
                                  .delete()
                                  .eq('event_id', eventId)
                                  .eq('user_id', _db.auth.currentUser!.id);
                            } else {
                              await _db.from('event_attendees').insert({
                                'event_id': eventId,
                                'user_id': _db.auth.currentUser!.id,
                              });
                            }
                            if (!mounted) return;
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  joined
                                      ? 'You left this event.'
                                      : 'You’re on the attendee list!',
                                ),
                              ),
                            );
                            setState(() {});
                          } catch (error) {
                            if (wasJoined) {
                              _joinedEventIds.add(eventId);
                            } else {
                              _joinedEventIds.remove(eventId);
                            }
                            if (mounted) {
                              setDialogState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Could not update attendance: $error',
                                  ),
                                ),
                              );
                            }
                          } finally {
                            _attendanceBusy.remove(eventId);
                            if (ctx.mounted) setDialogState(() {});
                          }
                        },
                  icon: Icon(
                    joined
                        ? Icons.event_busy_outlined
                        : Icons.event_available_outlined,
                  ),
                  label: Text(
                    busy
                        ? 'Please wait…'
                        : joined
                        ? 'Leave event'
                        : 'Join event',
                  ),
                ),
              if ((item['external_url'] ?? '').toString().trim().isNotEmpty)
                TextButton.icon(
                  onPressed: () async {
                    final uri = Uri.tryParse(item['external_url'].toString());
                    if (uri != null &&
                        (uri.scheme == 'https' || uri.scheme == 'http'))
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Event link'),
                ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openClub(String clubId) {
    for (final membership in _memberships) {
      if (membership['club_id'].toString() != clubId) continue;
      final club = membership['clubs'];
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ClubDetailScreen(
            clubId: clubId,
            clubName: club is Map ? club['name']?.toString() ?? 'Club' : 'Club',
            description: club is Map
                ? club['description']?.toString() ?? ''
                : '',
            role: membership['role']?.toString() ?? 'member',
          ),
        ),
      );
      return;
    }
  }

  String _dateLabel(dynamic value, {required bool includeTime}) {
    final date = value is DateTime
        ? value.toLocal()
        : DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'Date unavailable';
    final base =
        '${date.day.toString().padLeft(2, '0')} ${_month(date.month)} ${date.year}';
    if (!includeTime) return base;
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '$base · $hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _month(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filtered = _items.where(_matches).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Updates'),
        actions: [
          IconButton(
            tooltip: 'Refresh updates',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(27),
                color: Color(0x246C63FF),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -16,
                    top: -24,
                    child: Container(
                      width: 98,
                      height: 98,
                      decoration: const BoxDecoration(
                        color: MyClubTheme.accentYellow,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 44,
                    bottom: -38,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: MyClubTheme.accentCoral.withValues(alpha: .88),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'YOUR CLUB UNIVERSE',
                              style: TextStyle(
                                color: MyClubTheme.brand,
                                fontSize: 10,
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 7),
                            const Text(
                              'What’s happening?',
                              style: TextStyle(
                                color: MyClubTheme.ink,
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${_items.length} updates from your clubs',
                              style: TextStyle(color: MyClubTheme.mutedText),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: MyClubTheme.canvas.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(21),
                        ),
                        child: const Icon(
                          Icons.campaign_rounded,
                          color: MyClubTheme.brand,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SegmentedButton<_UpdateFilter>(
              segments: const [
                ButtonSegment(
                  value: _UpdateFilter.all,
                  label: Text('All'),
                  icon: Icon(Icons.dynamic_feed_outlined),
                ),
                ButtonSegment(
                  value: _UpdateFilter.events,
                  label: Text('Events'),
                  icon: Icon(Icons.event_outlined),
                ),
                ButtonSegment(
                  value: _UpdateFilter.announcements,
                  label: Text('News'),
                  icon: Icon(Icons.campaign_outlined),
                ),
              ],
              selected: {_filter},
              showSelectedIcon: false,
              onSelectionChanged: (selected) =>
                  setState(() => _filter = selected.first),
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _StateCard(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load updates',
                message: 'Check your connection and try again.',
                action: FilledButton.tonal(
                  onPressed: _load,
                  child: const Text('Try again'),
                ),
              )
            else if (filtered.isEmpty)
              _StateCard(
                icon: _filter == _UpdateFilter.events
                    ? Icons.event_available_outlined
                    : Icons.inbox_outlined,
                title: _filter == _UpdateFilter.events
                    ? 'No upcoming events'
                    : _filter == _UpdateFilter.announcements
                    ? 'No announcements yet'
                    : 'You’re all caught up',
                message: _filter == _UpdateFilter.all
                    ? 'New events and announcements from your clubs will appear here.'
                    : 'Try another filter or check back later.',
              )
            else
              ...filtered.map((item) {
                final isEvent = item['_kind'] == 'event';
                final clubId = item['club_id'].toString();
                final pinned = item['is_pinned'] == true;
                final date = isEvent ? item['starts_at'] : item['created_at'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        if (isEvent || item['_global_public'] == true) {
                          _showEventDetails(item);
                        } else {
                          _openClub(clubId);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color:
                                        (isEvent
                                                ? colors.tertiary
                                                : colors.primary)
                                            .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    isEvent
                                        ? Icons.event_rounded
                                        : pinned
                                        ? Icons.push_pin_rounded
                                        : Icons.campaign_rounded,
                                    color: isEvent
                                        ? colors.tertiary
                                        : colors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['_club_name']?.toString() ??
                                            'Club',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: colors.primary,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        isEvent
                                            ? ((item['visibility'] ==
                                                          'public' ||
                                                      item['is_public'] == true)
                                                  ? 'PUBLIC EVENT'
                                                  : item['visibility'] ==
                                                        'executives'
                                                  ? 'EXECUTIVES ONLY'
                                                  : 'CLUB MEMBERS')
                                            : pinned
                                            ? 'PINNED ANNOUNCEMENT'
                                            : 'ANNOUNCEMENT',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              letterSpacing: 0.8,
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isEvent && item['visibility'] == 'public')
                                  Icon(
                                    Icons.public_rounded,
                                    size: 19,
                                    color: colors.primary,
                                  )
                                else if (item['visibility'] == 'executives')
                                  const Icon(
                                    Icons.admin_panel_settings_outlined,
                                    size: 18,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              item['title']?.toString() ??
                                  (isEvent ? 'Untitled event' : 'Announcement'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if ((isEvent ? item['description'] : item['body'])
                                    ?.toString()
                                    .trim()
                                    .isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 7),
                              Text(
                                (isEvent ? item['description'] : item['body'])
                                    .toString(),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                            if (isEvent &&
                                (item['location']
                                        ?.toString()
                                        .trim()
                                        .isNotEmpty ??
                                    false)) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 17,
                                    color: colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      item['location'].toString(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if ((item['external_url'] ?? '')
                                .toString()
                                .trim()
                                .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final uri = Uri.tryParse(
                                      item['external_url'].toString(),
                                    );
                                    if (uri != null &&
                                        (uri.scheme == 'https' ||
                                            uri.scheme == 'http')) {
                                      await launchUrl(
                                        uri,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.open_in_new, size: 17),
                                  label: const Text('Open related link'),
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 16,
                                  color: colors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _dateLabel(date, includeTime: isEvent),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(icon, size: 42, color: colors.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
