import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'club_detail_screen.dart';

class PublicClubsScreen extends StatefulWidget {
  const PublicClubsScreen({super.key});

  @override
  State<PublicClubsScreen> createState() => _PublicClubsScreenState();
}

class _PublicClubsScreenState extends State<PublicClubsScreen> {
  final SupabaseClient _db = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<Map<String, dynamic>> _clubs = [];
  bool _loading = true;
  String? _error;
  String? _joiningClubId;

  @override
  void initState() {
    super.initState();
    _loadClubs();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), _loadClubs);
  }

  Future<void> _loadClubs() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _db.rpc(
        'search_public_clubs',
        params: {'p_search': _searchController.text.trim()},
      );
      final clubs = List<Map<String, dynamic>>.from(
        (response as List).map((row) => Map<String, dynamic>.from(row as Map)),
      );
      if (!mounted) return;
      setState(() {
        _clubs = clubs;
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

  Future<void> _joinOrOpen(Map<String, dynamic> club) async {
    final clubId = club['id']?.toString() ?? '';
    if (clubId.isEmpty || _joiningClubId != null) return;

    final alreadyMember = club['is_member'] == true;
    String role = club['membership_role']?.toString() ?? 'member';
    if (!alreadyMember) {
      setState(() => _joiningClubId = clubId);
      try {
        await _db.rpc('join_public_club', params: {'p_club_id': clubId});
        role = 'member';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You joined ${club['name'] ?? 'the club'}!'),
            ),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not join club: $error')),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _joiningClubId = null);
      }
    }

    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ClubDetailScreen(
          clubId: clubId,
          clubName: club['name']?.toString() ?? 'Club',
          description: club['description']?.toString() ?? '',
          role: role,
        ),
      ),
    );
    if (mounted) _loadClubs();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover clubs'),
        actions: [
          IconButton(
            tooltip: 'Refresh clubs',
            onPressed: _loading ? null : _loadClubs,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search clubs by name or description',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          _loadClubs();
                        },
                        icon: const Icon(Icons.close),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _MessageState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Could not load public clubs',
                    message:
                        'Check your connection and Supabase migration, then try again.\n$_error',
                    actionLabel: 'Try again',
                    onAction: _loadClubs,
                  )
                : _clubs.isEmpty
                ? _MessageState(
                    icon: Icons.search_off_rounded,
                    title: _searchController.text.trim().isEmpty
                        ? 'No public clubs yet'
                        : 'No matching clubs',
                    message: _searchController.text.trim().isEmpty
                        ? 'When a club owner makes their club public, it will appear here.'
                        : 'Try a different name or keyword.',
                    actionLabel: _searchController.text.trim().isEmpty
                        ? null
                        : 'Clear search',
                    onAction: _searchController.text.trim().isEmpty
                        ? null
                        : () {
                            _searchController.clear();
                            _loadClubs();
                          },
                  )
                : RefreshIndicator(
                    onRefresh: _loadClubs,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _clubs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final club = _clubs[index];
                        final id = club['id']?.toString() ?? '';
                        final name = club['name']?.toString() ?? 'Unnamed club';
                        final description =
                            club['description']?.toString() ?? '';
                        final logoUrl = club['logo_url']?.toString();
                        final isMember = club['is_member'] == true;
                        final isJoining = _joiningClubId == id;
                        final count =
                            int.tryParse('${club['member_count'] ?? 0}') ?? 0;

                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                  backgroundImage:
                                      logoUrl != null && logoUrl.isNotEmpty
                                      ? NetworkImage(logoUrl)
                                      : null,
                                  child: logoUrl == null || logoUrl.isEmpty
                                      ? Icon(
                                          Icons.groups_rounded,
                                          color: theme
                                              .colorScheme
                                              .onPrimaryContainer,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (description.isNotEmpty)
                                        Text(
                                          description,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.people_outline,
                                            size: 16,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$count ${count == 1 ? 'member' : 'members'}',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.public,
                                            size: 15,
                                            color: theme.colorScheme.primary,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            'Public',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color:
                                                      theme.colorScheme.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: FilledButton.tonalIcon(
                                          onPressed:
                                              isJoining ||
                                                  _joiningClubId != null
                                              ? null
                                              : () => _joinOrOpen(club),
                                          icon: isJoining
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : Icon(
                                                  isMember
                                                      ? Icons.open_in_new
                                                      : Icons
                                                            .group_add_outlined,
                                                ),
                                          label: Text(
                                            isJoining
                                                ? 'Joining…'
                                                : isMember
                                                ? 'Open club'
                                                : 'Join club',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
