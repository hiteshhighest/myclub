import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

      final memberships = await _supabase
          .from('club_members')
          .select('club_id, role, clubs(id, name, description)')
          .eq('user_id', user.id);

      final clubs = List<Map<String, dynamic>>.from(
        (memberships as List).map(
          (row) => Map<String, dynamic>.from(row as Map),
        ),
      );

      final clubIds = clubs
          .map((club) => club['club_id'].toString())
          .toSet()
          .toList();

      List<Map<String, dynamic>> events = [];

      if (clubIds.isNotEmpty) {
        final result = await _supabase
            .from('club_events')
            .select('id, club_id, title, description, starts_at, location')
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

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Date unavailable';
    final d = date.toLocal();
    return '${d.day}/${d.month}/${d.year} · '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
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
                physics: AlwaysScrollableScrollPhysics(),
                children: [
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
                padding: const EdgeInsets.all(16),
                itemCount: _events.length,
                itemBuilder: (context, index) {
                  final event = _events[index];
                  final clubId = event['club_id'].toString();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: const CircleAvatar(
                        child: Icon(Icons.event_available_outlined),
                      ),
                      title: Text(
                        event['title']?.toString() ?? 'Untitled event',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_clubName(clubId)),
                            const SizedBox(height: 4),
                            Text(_formatDate(event['starts_at'])),
                            if ((event['location'] ?? '').toString().isNotEmpty)
                              Text('Location: ${event['location']}'),
                            if ((event['description'] ?? '')
                                .toString()
                                .isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                event['description'].toString(),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openClub(clubId),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
