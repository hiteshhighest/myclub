import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_cache.dart';
import '../../core/theme.dart';
import '../../widgets/club_info_card.dart';
import '../../widgets/playful_page_banner.dart';

import '../clubs/club_detail_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _memberships = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Please log in again.');

      final clubs = await SupabaseCache.instance.getMemberships(
        _supabase,
        user.id,
      );

      final clubIds = clubs
          .map((club) => club['club_id'].toString())
          .toSet()
          .toList();

      List<Map<String, dynamic>> events = [];

      if (clubIds.isNotEmpty) {
        final result = await _supabase
            .from('club_events')
            .select(
              'id, club_id, title, description, starts_at, location, visibility, is_public, external_url',
            )
            .inFilter('club_id', clubIds)
            .gte('starts_at', DateTime.now().toUtc().toIso8601String())
            .order('starts_at');

        events = List<Map<String, dynamic>>.from(
          (result as List).map((row) => Map<String, dynamic>.from(row as Map)),
        );
      }

      if (!mounted) return;

      setState(() {
        _memberships = clubs;
        _events = events;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openClub(String clubId) {
    for (final membership in _memberships) {
      if (membership['club_id'].toString() != clubId) continue;

      final club = membership['clubs'];
      final name = club is Map ? club['name']?.toString() ?? 'Club' : 'Club';
      final description = club is Map
          ? club['description']?.toString() ?? ''
          : '';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClubDetailScreen(
            clubId: clubId,
            clubName: name,
            description: description,
            role: membership['role']?.toString() ?? 'member',
          ),
        ),
      );
      return;
    }
  }

  String _clubName(String clubId) {
    for (final membership in _memberships) {
      if (membership['club_id'].toString() == clubId) {
        final club = membership['clubs'];
        if (club is Map) return club['name']?.toString() ?? 'Club';
      }
    }
    return 'Club';
  }

  Widget _eventCard(Map<String, dynamic> event) {
    final clubId = event['club_id'].toString();
    final start = DateTime.tryParse(event['starts_at']?.toString() ?? '')
        ?.toLocal();
    final isPublic =
        event['visibility'] == 'public' || event['is_public'] == true;
    final isExec = event['visibility'] == 'executives';
    final time = start == null
        ? 'Time unavailable'
        : '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final loc = (event['location'] ?? '').toString();

    return ClubInfoCard(
      leading: DateBadge(date: start),
      clubName: _clubName(clubId),
      title: event['title']?.toString() ?? 'Untitled event',
      body: event['description']?.toString(),
      tags: [
        if (isPublic)
          const MiniTag(icon: Icons.public_rounded, label: 'Public')
        else if (isExec)
          const MiniTag(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Executives',
            color: MyClubTheme.accentCoral,
          )
        else
          const MiniTag(icon: Icons.groups_2_outlined, label: 'Members'),
      ],
      footerIcon: Icons.schedule_rounded,
      footer: loc.isEmpty ? time : '$time · $loc',
      onTap: () => _openClub(clubId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming Events'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadEvents,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadEvents,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 240),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Could not load events.',
                    textAlign: TextAlign.center,
                  ),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Center(
                    child: FilledButton(
                      onPressed: _loadEvents,
                      child: const Text('Try again'),
                    ),
                  ),
                ],
              )
            : _events.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 90),
                  Icon(Icons.event_busy_outlined, size: 56),
                  SizedBox(height: 16),
                  Text(
                    'No upcoming events',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Events from clubs you join will appear here.',
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: _events.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const PlayfulPageBanner(
                      eyebrow: 'Save the date',
                      title: 'Good times ahead!',
                      subtitle: 'Discover what your clubs have planned next.',
                      icon: Icons.celebration_rounded,
                      color: Color(0x35FF8F7A),
                      accent: MyClubTheme.accentYellow,
                    );
                  }
                  return _eventCard(_events[index - 1]);
                },
              ),
      ),
    );
  }
}
