import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../clubs/club_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _clubs = [];
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _announcements = [];

  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _feedError;

  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  Future<void> _loadHome() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _feedError = null;
      });
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Please log in again.');

      final result = await _supabase
          .from('club_members')
          .select(
            'club_id, role, joined_at, '
            'clubs(id, name, description)',
          )
          .eq('user_id', user.id)
          .order('joined_at', ascending: false);

      final clubs = (result as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

      final clubIds = clubs
          .map((item) => item['club_id'].toString())
          .toSet()
          .toList();

      var events = <Map<String, dynamic>>[];
      var announcements = <Map<String, dynamic>>[];
      String? feedError;

      if (clubIds.isNotEmpty) {
        try {
          final now = DateTime.now().toUtc().toIso8601String();

          final results = await Future.wait([
            _supabase
                .from('club_events')
                .select('id, club_id, title, description, starts_at, location')
                .inFilter('club_id', clubIds)
                .gte('starts_at', now)
                .order('starts_at')
                .limit(5),
            _supabase
                .from('announcements')
                .select('id, club_id, title, body, is_pinned, created_at')
                .inFilter('club_id', clubIds)
                .order('created_at', ascending: false)
                .limit(5),
          ]);

          events = List<Map<String, dynamic>>.from(results[0]);
          announcements = List<Map<String, dynamic>>.from(results[1]);
        } catch (e) {
          feedError = e.toString();
        }
      }

      if (!mounted) return;

      setState(() {
        _clubs = clubs;
        _events = events;
        _announcements = announcements;
        _feedError = feedError;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _clubName(String clubId) {
    for (final membership in _clubs) {
      if (membership['club_id'].toString() == clubId) {
        final club = membership['clubs'];
        if (club is Map) {
          return club['name']?.toString() ?? 'Club';
        }
      }
    }
    return 'Club';
  }

  void _openClub(String clubId) {
    Map<String, dynamic>? membership;

    for (final item in _clubs) {
      if (item['club_id'].toString() == clubId) {
        membership = item;
        break;
      }
    }

    if (membership == null) {
      _message('You are no longer a member of this club.');
      return;
    }

    final club = membership['clubs'];
    final clubName = club is Map ? club['name']?.toString() ?? 'Club' : 'Club';
    final description = club is Map
        ? club['description']?.toString() ?? ''
        : '';
    final role = membership['role']?.toString() ?? 'member';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClubDetailScreen(
          clubId: clubId,
          clubName: clubName,
          description: description,
          role: role,
        ),
      ),
    );
  }

  Future<void> _createClub() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    try {
      final values = await showDialog<List<String>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Create a club'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Club name',
                      hintText: 'e.g. Robotics Club',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 2) {
                        return 'Enter at least 2 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    maxLength: 2000,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'What is your club about?',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, [
                    nameController.text.trim(),
                    descriptionController.text.trim(),
                  ]);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      );

      if (values == null || !mounted) return;

      setState(() => _busy = true);

      await _supabase.rpc(
        'create_club',
        params: {'p_name': values[0], 'p_description': values[1]},
      );

      if (!mounted) return;
      _message('Club created successfully!');
      await _loadHome();
    } catch (e) {
      _message('Could not create club: $e');
    } finally {
      nameController.dispose();
      descriptionController.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinClub() async {
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    try {
      final code = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Join a club'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: codeController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: 12,
              decoration: const InputDecoration(
                labelText: 'Invitation code',
                hintText: 'Enter your 12-character code',
              ),
              validator: (value) {
                if (value == null ||
                    !RegExp(r'^[a-fA-F0-9]{12}$').hasMatch(value.trim())) {
                  return 'Enter a valid 12-character code.';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, codeController.text.trim());
                }
              },
              child: const Text('Join'),
            ),
          ],
        ),
      );

      if (code == null || !mounted) return;

      setState(() => _busy = true);

      await _supabase.rpc('join_club_by_code', params: {'p_code': code});

      if (!mounted) return;
      _message('You joined the club!');
      await _loadHome();
    } catch (e) {
      _message('Could not join club: $e');
    } finally {
      codeController.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      _message('Could not sign out: $e');
    }
  }

  String _eventDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Date unavailable';

    final local = date.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '${local.day}/${local.month}/${local.year} · '
        '$hour:${local.minute.toString().padLeft(2, '0')} $period';
  }

  String _announcementDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '';

    final local = date.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  Widget _sectionHeader(String title, IconData icon, {int? count}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (count != null)
            Text('$count', style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }

  Widget _feedEmpty(IconData icon, String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 30, color: Theme.of(context).colorScheme.outline),
            const SizedBox(width: 14),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  Widget _buildEvents() {
    if (_feedError != null) {
      return _feedEmpty(
        Icons.cloud_off_outlined,
        'Events could not be loaded. Pull down to try again.',
      );
    }

    if (_events.isEmpty) {
      return _feedEmpty(
        Icons.event_outlined,
        'No upcoming events. Check back for new club activities.',
      );
    }

    return Column(
      children: _events.map((event) {
        final clubId = event['club_id'].toString();

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: CircleAvatar(
              child: const Icon(Icons.event_available_outlined),
            ),
            title: Text(
              event['title']?.toString() ?? 'Untitled event',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_clubName(clubId)),
                  const SizedBox(height: 4),
                  Text(_eventDate(event['starts_at'])),
                  if ((event['location'] ?? '').toString().isNotEmpty)
                    Text('📍 ${event['location']}'),
                ],
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openClub(clubId),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAnnouncements() {
    if (_feedError != null) {
      return _feedEmpty(
        Icons.cloud_off_outlined,
        'Announcements could not be loaded. Pull down to try again.',
      );
    }

    if (_announcements.isEmpty) {
      return _feedEmpty(
        Icons.campaign_outlined,
        'No announcements yet. Club updates will appear here.',
      );
    }

    return Column(
      children: _announcements.map((announcement) {
        final clubId = announcement['club_id'].toString();
        final pinned = announcement['is_pinned'] == true;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: CircleAvatar(
              child: Icon(
                pinned ? Icons.push_pin_outlined : Icons.campaign_outlined,
              ),
            ),
            title: Text(
              announcement['title']?.toString() ?? 'Announcement',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_clubName(clubId)),
                  const SizedBox(height: 4),
                  Text(
                    announcement['body']?.toString() ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(_announcementDate(announcement['created_at'])),
                ],
              ),
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openClub(clubId),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildClubs() {
    if (_error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40),
              const SizedBox(height: 12),
              const Text(
                'Could not load your clubs.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _loadHome,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_clubs.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            children: [
              Icon(
                Icons.groups_3_outlined,
                size: 54,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Your community starts here',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create your own club or join one using an invitation code.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _clubs.map((membership) {
        final club = membership['clubs'];
        final clubName = club is Map
            ? club['name']?.toString() ?? 'Club'
            : 'Club';
        final description = club is Map
            ? club['description']?.toString() ?? ''
            : '';
        final role = membership['role']?.toString() ?? 'member';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(
              radius: 26,
              child: Text(
                clubName.isNotEmpty ? clubName[0].toUpperCase() : 'C',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              clubName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Chip(
                  label: Text(role[0].toUpperCase() + role.substring(1)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openClub(membership['club_id'].toString()),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    final email = user?.email ?? 'Member';
    final metadataName = user?.userMetadata?['display_name'] as String?;
    final displayName = metadataName != null && metadataName.trim().isNotEmpty
        ? metadataName.trim()
        : email.split('@').first;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MyClub',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading || _busy ? null : _loadHome,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _busy ? null : _signOut,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadHome,
          child: _loading
              ? ListView(
                  physics: AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: 220),
                    Center(child: CircularProgressIndicator()),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Welcome back,',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your clubs, events and community — all in one place.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _createClub,
                            icon: const Icon(Icons.add),
                            label: const Text('Create club'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _joinClub,
                            icon: const Icon(Icons.group_add),
                            label: const Text('Join club'),
                          ),
                        ),
                      ],
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    const SizedBox(height: 30),

                    _sectionHeader(
                      'My Clubs',
                      Icons.groups_outlined,
                      count: _clubs.length,
                    ),
                    _buildClubs(),
                    const SizedBox(height: 24),
                  ],
                ),
        ),
      ),
    );
  }
}
