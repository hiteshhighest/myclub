import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../widgets/club_info_card.dart';
import '../../widgets/playful_page_banner.dart';

import '../clubs/club_detail_screen.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _memberships = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
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

      List<Map<String, dynamic>> announcements = [];

      if (clubIds.isNotEmpty) {
        final result = await _supabase
            .from('announcements')
            .select(
              'id, club_id, title, body, is_pinned, created_at, created_by, visibility',
            )
            .inFilter('club_id', clubIds)
            .order('is_pinned', ascending: false)
            .order('created_at', ascending: false);

        announcements = List<Map<String, dynamic>>.from(
          (result as List).map((row) => Map<String, dynamic>.from(row as Map)),
        );

        // Fetch author profiles separately so profile RLS policies are respected.
        final authorIds = announcements
            .map((item) => item['created_by']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
        final profilesById = <String, Map<String, dynamic>>{};
        if (authorIds.isNotEmpty) {
          try {
            final profiles = await _supabase
                .from('profiles')
                .select('id, display_name, avatar_url, is_profile_public')
                .inFilter('id', authorIds);
            for (final profile in profiles) {
              profilesById[profile['id'].toString()] =
                  Map<String, dynamic>.from(profile);
            }
          } catch (_) {
            // Keep the announcements available if profile rows are not visible.
          }
        }
        for (final item in announcements) {
          item['author_profile'] =
              profilesById[item['created_by']?.toString() ?? ''];
        }
      }

      if (!mounted) return;

      setState(() {
        _memberships = clubs;
        _announcements = announcements;
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

  String _clubName(String clubId) {
    for (final membership in _memberships) {
      if (membership['club_id'].toString() == clubId) {
        final club = membership['clubs'];
        if (club is Map) return club['name']?.toString() ?? 'Club';
      }
    }
    return 'Club';
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

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '';
    final d = date.toLocal();
    return '${d.day}/${d.month}/${d.year}';
  }

  String _authorName(Map<String, dynamic> announcement) {
    final profile = announcement['author_profile'] is Map
        ? Map<String, dynamic>.from(announcement['author_profile'] as Map)
        : null;
    final isPublic = profile?['is_profile_public'] != false;
    final rawName = profile?['display_name']?.toString().trim() ?? '';
    if (!isPublic) return 'Private profile';
    return rawName.isEmpty ? 'Club member' : rawName;
  }

  Widget _announcementCard(Map<String, dynamic> announcement) {
    final clubId = announcement['club_id'].toString();
    final pinned = announcement['is_pinned'] == true;
    final date = _formatDate(announcement['created_at']);
    final author = _authorName(announcement);

    return ClubInfoCard(
      leading: IconTile(
        icon: pinned ? Icons.push_pin_rounded : Icons.campaign_rounded,
        color: pinned ? MyClubTheme.accentCoral : null,
      ),
      clubName: _clubName(clubId),
      title: announcement['title']?.toString() ?? 'Announcement',
      body: announcement['body']?.toString(),
      tags: [
        if (pinned)
          const MiniTag(
            icon: Icons.push_pin_outlined,
            label: 'Pinned',
            color: MyClubTheme.accentCoral,
          ),
        if (announcement['visibility'] == 'executives')
          const MiniTag(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Executives only',
          ),
      ],
      footerIcon: Icons.edit_outlined,
      footer: date.isEmpty ? author : '$author · $date',
      onTap: () => _openClub(clubId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadAnnouncements,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAnnouncements,
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
                    'Could not load announcements.',
                    textAlign: TextAlign.center,
                  ),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Center(
                    child: FilledButton(
                      onPressed: _loadAnnouncements,
                      child: const Text('Try again'),
                    ),
                  ),
                ],
              )
            : _announcements.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 90),
                  Icon(Icons.campaign_outlined, size: 56),
                  SizedBox(height: 16),
                  Text(
                    'No announcements yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Updates from your clubs will appear here.',
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: _announcements.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const PlayfulPageBanner(
                      eyebrow: 'Fresh from your clubs',
                      title: 'Little updates, big news',
                      subtitle: 'The things your community wants you to know.',
                      icon: Icons.mark_chat_unread_rounded,
                      color: Color(0x35FFD76E),
                      accent: MyClubTheme.accentCoral,
                    );
                  }
                  return _announcementCard(_announcements[index - 1]);
                },
              ),
      ),
    );
  }
}
