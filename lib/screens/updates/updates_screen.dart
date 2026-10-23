import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

      final membershipsRaw = await _db
          .from('club_members')
          .select('club_id, role, clubs(id, name, description)')
          .eq('user_id', user.id);

      final memberships = List<Map<String, dynamic>>.from(
        (membershipsRaw as List).map(
          (row) => Map<String, dynamic>.from(row as Map),
        ),
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
      if (ids.isNotEmpty) {
        final now = DateTime.now().toUtc().toIso8601String();
        final results = await Future.wait([
          _db
              .from('club_events')
              .select(
                'id, club_id, title, description, starts_at, location, visibility',
              )
              .inFilter('club_id', ids)
              .gte('starts_at', now)
              .order('starts_at')
              .limit(100),
          _db
              .from('announcements')
              .select(
                'id, club_id, title, body, is_pinned, created_at, visibility, created_by',
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
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFF236B63),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Stay in the loop',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'What’s happening',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${_items.length} updates from your clubs',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.campaign_outlined,
                      color: Colors.white,
                      size: 26,
                    ),
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
                      onTap: () => _openClub(clubId),
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
                                            ? 'EVENT'
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
                                if (item['visibility'] == 'executives')
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
