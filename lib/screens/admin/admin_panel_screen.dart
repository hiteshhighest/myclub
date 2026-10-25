import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _db = Supabase.instance.client;
  final _userSearch = TextEditingController();
  bool _checkingAccess = true;
  bool _isAdmin = false;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _clubs = [];
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _userSearch.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final result = await _db.rpc('is_myclub_admin');
      if (!mounted) return;
      setState(() {
        _isAdmin = result == true;
        _checkingAccess = false;
      });
      if (_isAdmin) await _loadAll();
    } catch (e) {
      if (mounted)
        setState(() {
          _checkingAccess = false;
          _error = e.toString();
        });
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        _db.rpc('admin_list_clubs'),
        _db.rpc('admin_list_verification_requests'),
        _db.rpc(
          'admin_search_users',
          params: {'p_query': _userSearch.text.trim()},
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _clubs = _maps(values[0]);
        _requests = _maps(values[1]);
        _users = _maps(values[2]);
        _loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  List<Map<String, dynamic>> _maps(dynamic value) => (value as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateOptionalUrl(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return 'Enter a valid http:// or https:// link';
    }
    return null;
  }

  Future<void> _reviewRequest(
    Map<String, dynamic> request,
    bool approve,
  ) async {
    final note = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Approve verification?' : 'Reject verification?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Club: ${request['club_name'] ?? 'Club'}'),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Private review note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              approve
                  ? 'The club will receive the verified badge. It can choose whether its club listing is public.'
                  : 'The request will be rejected and the club will remain private.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? 'Approve club' : 'Reject request'),
          ),
        ],
      ),
    );
    if (accepted != true) {
      note.dispose();
      return;
    }
    try {
      await _db.rpc(
        'admin_review_club_verification',
        params: {
          'p_request_id': request['request_id'],
          'p_approve': approve,
          'p_note': note.text.trim().isEmpty ? null : note.text.trim(),
        },
      );
      _toast(approve ? 'Club verified.' : 'Verification request rejected.');
      await _loadAll();
    } catch (e) {
      _toast('Could not review request: $e');
    } finally {
      note.dispose();
    }
  }

  Future<void> _sendMessage(Map<String, dynamic> user) async {
    final title = TextEditingController(text: 'A message from MyClub');
    final body = TextEditingController();
    final link = TextEditingController();
    final key = GlobalKey<FormState>();
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send private in-app message'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'To: ${user['display_name'] ?? user['email'] ?? 'User'}',
                      style: Theme.of(ctx).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: title,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Message title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter a title'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: body,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter a message'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: link,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Optional link',
                      hintText: 'https://example.com',
                      prefixIcon: Icon(Icons.link),
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateOptionalUrl,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This appears only in this user’s account. It disappears after they press Okay.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(ctx, true);
            },
            icon: const Icon(Icons.send_outlined),
            label: const Text('Send message'),
          ),
        ],
      ),
    );
    if (send != true) {
      title.dispose();
      body.dispose();
      link.dispose();
      return;
    }
    try {
      await _db.rpc(
        'admin_send_user_message',
        params: {
          'p_user_id': user['user_id'],
          'p_title': title.text.trim(),
          'p_body': body.text.trim(),
          'p_link_url': link.text.trim().isEmpty ? null : link.text.trim(),
        },
      );
      _toast(
        'Private message sent. It will appear when that user opens MyClub.',
      );
    } catch (e) {
      _toast('Could not send message: $e');
    } finally {
      title.dispose();
      body.dispose();
      link.dispose();
    }
  }

  Future<void> _broadcastMessage() async {
    final title = TextEditingController(text: 'Announcement from MyClub');
    final body = TextEditingController();
    final link = TextEditingController();
    final key = GlobalKey<FormState>();
    var audience = 'all';
    const audiences = <String, String>{
      'all': 'Every user',
      'android': 'Android users',
      'ios': 'iOS users',
      'web': 'Web users',
      'owners': 'Club owners',
      'executives': 'Club executives',
    };
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Send an admin message'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: key,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: audience,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Recipients',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.groups_outlined),
                      ),
                      items: audiences.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null)
                          setDialogState(() => audience = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.primaryContainer
                            .withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.campaign_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Send an in-app message to ${audiences[audience]!.toLowerCase()}. Platform targeting uses each account’s most recently recorded MyClub platform.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: title,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Message title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter a title'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: body,
                      minLines: 4,
                      maxLines: 8,
                      maxLength: 4000,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter a message'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: link,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Optional link',
                        hintText: 'https://example.com',
                        prefixIcon: Icon(Icons.link),
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateOptionalUrl,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Messages appear in recipients’ MyClub inbox when they open the app. This does not send an operating-system push notification.',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (key.currentState!.validate()) Navigator.pop(ctx, true);
              },
              icon: const Icon(Icons.send),
              label: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    if (send != true) {
      title.dispose();
      body.dispose();
      link.dispose();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.campaign_outlined),
        title: Text('Message ${audiences[audience]!.toLowerCase()}?'),
        content: Text(
          'This will send “${title.text.trim()}” to ${audiences[audience]!.toLowerCase()}. Messages cannot be recalled after sending.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Go back'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.send),
            label: const Text('Confirm send'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      title.dispose();
      body.dispose();
      link.dispose();
      return;
    }
    try {
      final result = await _db.rpc(
        'admin_broadcast_user_message',
        params: {
          'p_title': title.text.trim(),
          'p_body': body.text.trim(),
          'p_link_url': link.text.trim().isEmpty ? null : link.text.trim(),
          'p_audience': audience,
        },
      );
      _toast(
        'Message sent to ${result ?? 0} ${audiences[audience]!.toLowerCase()}.',
      );
    } catch (e) {
      _toast('Could not send message: $e');
    } finally {
      title.dispose();
      body.dispose();
      link.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('MyClub Control Room'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _checkingAccess || _loading ? null : _loadAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _checkingAccess
          ? const Center(child: CircularProgressIndicator())
          : !_isAdmin
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 48,
                      color: colors.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Admin access only',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This account is not authorised to access the MyClub Control Room.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : _error != null && _clubs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Could not load the control room\n$_error',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loadAll,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors.primary,
                        colors.primary.withValues(alpha: .78),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Admin control room',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Clubs • Verification • User broadcasts',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: .9),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: DefaultTabController(
                    length: 3,
                    child: Column(
                      children: [
                        const TabBar(
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          tabs: [
                            Tab(
                              icon: Icon(Icons.apartment_outlined),
                              text: 'Clubs',
                            ),
                            Tab(
                              icon: Icon(Icons.verified_user_outlined),
                              text: 'Verification',
                            ),
                            Tab(
                              icon: Icon(Icons.mark_email_unread_outlined),
                              text: 'Users & messages',
                            ),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildClubs(),
                              _buildRequests(),
                              _buildUsers(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildClubs() {
    if (_clubs.isEmpty && !_loading)
      return const Center(child: Text('No clubs found.'));
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _clubs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final club = _clubs[index];
          final verified = club['is_verified'] == true;
          final isPublic = club['is_public'] == true;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: verified
                            ? Colors.teal.withValues(alpha: .12)
                            : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                        child: Icon(
                          verified ? Icons.verified : Icons.groups_outlined,
                          color: verified ? Colors.teal : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              club['name']?.toString() ?? 'Unnamed club',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              club['description']?.toString() ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill(
                        verified ? 'Verified' : 'Unverified',
                        verified ? Colors.teal : Colors.orange,
                      ),
                      _pill(
                        isPublic ? 'Public listing' : 'Private listing',
                        isPublic ? Colors.blue : Colors.grey,
                      ),
                      _pill(
                        '${club['member_count'] ?? 0} members',
                        Colors.blueGrey,
                      ),
                      _pill(
                        '${club['open_positions_count'] ?? 0} open roles',
                        Colors.deepPurple,
                      ),
                    ],
                  ),
                  if (!verified)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'Verification is handled in the Verification tab after reviewing the owner’s proof.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequests() {
    final pending = _requests.where((r) => r['status'] == 'pending').toList();
    if (pending.isEmpty)
      return RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 60),
            const Icon(Icons.verified_user_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'You’re all caught up',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'No verification requests are waiting for review.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: pending.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final r = pending[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        color: Colors.teal,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r['club_name']?.toString() ?? 'Club verification',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      _pill('Pending', Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Owner: ${r['owner_name'] ?? 'Unknown'}'),
                  if ((r['owner_email'] ?? '').toString().isNotEmpty)
                    SelectableText(r['owner_email'].toString()),
                  const SizedBox(height: 12),
                  const Text(
                    'Social media ID',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SelectableText(r['social_media_id']?.toString() ?? ''),
                  const SizedBox(height: 10),
                  const Text(
                    'Proof of ownership',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SelectableText(r['owner_proof']?.toString() ?? ''),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _reviewRequest(r, false),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _reviewRequest(r, true),
                          icon: const Icon(Icons.verified_rounded),
                          label: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUsers() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userSearch,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _loadAll(),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Find by name or email',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _loading ? null : _loadAll,
                child: const Text('Search'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : _broadcastMessage,
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Send admin message'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Send admin announcements from Android, iOS, or web. Choose all users, a platform, club owners, or club executives as recipients.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        Expanded(
          child: _users.isEmpty
              ? const Center(child: Text('No matching users.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            ((user['display_name']
                                            ?.toString()
                                            .trim()
                                            .isNotEmpty ??
                                        false)
                                    ? user['display_name'].toString().trim()[0]
                                    : (user['email']
                                              ?.toString()
                                              .trim()
                                              .isNotEmpty ??
                                          false)
                                    ? user['email'].toString().trim()[0]
                                    : '?')
                                .toUpperCase(),
                          ),
                        ),
                        title: Text(
                          (user['display_name']?.toString().trim().isNotEmpty ??
                                  false)
                              ? user['display_name'].toString()
                              : 'MyClub user',
                        ),
                        subtitle: Text(user['email']?.toString() ?? 'No email'),
                        trailing: IconButton(
                          tooltip: 'Send private message',
                          onPressed: () => _sendMessage(user),
                          icon: const Icon(Icons.send_outlined),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _pill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}
