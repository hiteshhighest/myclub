import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';

import '../clubs/club_detail_screen.dart';
import '../auth/brand_mark.dart';

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
            'clubs(id, name, description, logo_url)',
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
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: colors.primary, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.45),
            ),
          ),
          if (count != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: .7),
                ),
              ),
              child: Text(
                '$count',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _feedEmpty(IconData icon, String message) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .7)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: MyClubTheme.accentYellow.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 27, color: MyClubTheme.ink),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
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
      children: _events.asMap().entries.map((entry) {
        final index = entry.key;
        final event = entry.value;
        final clubId = event['club_id'].toString();
        final swatches = [
          MyClubTheme.accentMint,
          MyClubTheme.accentYellow,
          Color(0x246C63FF),
          Color(0x35FF8F7A),
        ];
        final tileColor = swatches[index % swatches.length];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 10,
            ),
            leading: Container(
              width: 52,
              height: 58,
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.event_available_rounded,
                color: MyClubTheme.ink,
                size: 25,
              ),
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
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(child: Text(event['location'].toString())),
                      ],
                    ),
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
      children: _announcements.asMap().entries.map((entry) {
        final index = entry.key;
        final announcement = entry.value;
        final clubId = announcement['club_id'].toString();
        final pinned = announcement['is_pinned'] == true;
        final swatches = [
          Color(0x35FF8F7A),
          Color(0x246C63FF),
          MyClubTheme.accentMint,
          MyClubTheme.accentYellow,
        ];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 10,
            ),
            leading: Container(
              width: 52,
              height: 58,
              decoration: BoxDecoration(
                color: swatches[index % swatches.length],
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(
                pinned ? Icons.push_pin_rounded : Icons.campaign_rounded,
                color: MyClubTheme.ink,
                size: 24,
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
      children: _clubs.asMap().entries.map((entry) {
        final index = entry.key;
        final membership = entry.value;
        final club = membership['clubs'];
        final clubName = club is Map
            ? club['name']?.toString() ?? 'Club'
            : 'Club';
        final description = club is Map
            ? club['description']?.toString() ?? ''
            : '';
        final role = membership['role']?.toString() ?? 'member';

        final clubSwatches = [
          Color(0x246C63FF),
          MyClubTheme.accentYellow,
          MyClubTheme.accentMint,
          Color(0x35FF8F7A),
        ];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 9,
            ),
            leading: CircleAvatar(
              radius: 27,
              backgroundColor: clubSwatches[index % clubSwatches.length],
              backgroundImage:
                  club is Map &&
                      (club['logo_url']?.toString().isNotEmpty ?? false)
                  ? NetworkImage(club['logo_url'].toString())
                  : null,
              child:
                  club is Map &&
                      (club['logo_url']?.toString().isNotEmpty ?? false)
                  ? null
                  : Text(
                      clubName.isNotEmpty ? clubName[0].toUpperCase() : 'C',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 19,
                        color: MyClubTheme.ink,
                      ),
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
    final metadataName =
        user?.userMetadata?['display_name']?.toString() ??
        user?.userMetadata?['full_name']?.toString() ??
        user?.userMetadata?['name']?.toString();
    final displayName = metadataName != null && metadataName.trim().isNotEmpty
        ? metadataName.trim()
        : email.split('@').first;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(size: 38),
            const SizedBox(width: 10),
            Text(
              'Klubb',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                color: MyClubTheme.brand,
              ),
            ),
          ],
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
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Color(0x246C63FF),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -24,
                            top: -28,
                            child: Container(
                              width: 142,
                              height: 142,
                              decoration: const BoxDecoration(
                                color: MyClubTheme.accentYellow,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 68,
                            bottom: -38,
                            child: Container(
                              width: 105,
                              height: 105,
                              decoration: const BoxDecoration(
                                color: MyClubTheme.accentCoral,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: MyClubTheme.canvas.withValues(
                                      alpha: .82,
                                    ),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: const Text(
                                    'YOUR PEOPLE. YOUR PLACE.',
                                    style: TextStyle(
                                      color: MyClubTheme.brand,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Hey, ',
                                      style: TextStyle(
                                        color: MyClubTheme.ink,
                                        fontSize: 29,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1.0,
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: MyClubTheme.brand,
                                          fontSize: 29,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -1.0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const SizedBox(
                                  width: 255,
                                  child: Text(
                                    'Good things happen when people come together.',
                                    style: TextStyle(
                                      color: MyClubTheme.ink,
                                      height: 1.45,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    _HomeStat(
                                      value: '${_clubs.length}',
                                      label: 'Your clubs',
                                      icon: Icons.groups_rounded,
                                    ),
                                    const SizedBox(width: 10),
                                    _HomeStat(
                                      value:
                                          '${_clubs.where((m) => m['role'] == 'owner').length}',
                                      label: 'You lead',
                                      icon: Icons.auto_awesome_rounded,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _createClub,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Create club'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _joinClub,
                            icon: const Icon(Icons.group_add_rounded),
                            label: const Text('Join a club'),
                          ),
                        ),
                      ],
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    const SizedBox(height: 28),
                    _sectionHeader(
                      'Your little communities',
                      Icons.diversity_3_rounded,
                      count: _clubs.length,
                    ),
                    _buildClubs(),
                    const SizedBox(height: 24),
                    _sectionHeader(
                      'Coming up',
                      Icons.event_rounded,
                      count: _events.length,
                    ),
                    _buildEvents(),
                    const SizedBox(height: 24),
                    _sectionHeader(
                      'The latest',
                      Icons.campaign_rounded,
                      count: _announcements.length,
                    ),
                    _buildAnnouncements(),
                    const SizedBox(height: 30),
                  ],
                ),
        ),
      ),
    );
  }
}

class _HomeStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _HomeStat({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: MyClubTheme.canvas.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MyClubTheme.canvas.withValues(alpha: 0.95)),
        ),
        child: Row(
          children: [
            Icon(icon, color: MyClubTheme.brand, size: 19),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: MyClubTheme.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: MyClubTheme.mutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
