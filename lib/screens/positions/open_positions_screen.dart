import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OpenPositionsScreen extends StatefulWidget {
  final String? clubId;
  final String? clubName;
  final bool canManage;

  const OpenPositionsScreen({
    super.key,
    this.clubId,
    this.clubName,
    this.canManage = false,
  });

  @override
  State<OpenPositionsScreen> createState() => _OpenPositionsScreenState();
}

class _OpenPositionsScreenState extends State<OpenPositionsScreen> {
  final _db = Supabase.instance.client;
  final _search = TextEditingController();
  List<Map<String, dynamic>> _positions = [];
  List<Map<String, dynamic>> _applications = [];
  bool _loading = true;
  bool _showApplications = false;
  String? _error;
  String? _submittingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final result = await _db.rpc(
        'get_verified_club_positions',
        params: {'p_club_id': widget.clubId},
      );
      final positions = List<Map<String, dynamic>>.from(
        (result as List).map((r) {
          final row = Map<String, dynamic>.from(r as Map);
          row['clubs'] = {'name': row.remove('club_name')};
          return row;
        }),
      );
      List<Map<String, dynamic>> applications = [];
      if (widget.canManage && widget.clubId != null) {
        final apps = await _db
            .from('club_position_applications')
            .select(
              'id, position_id, applicant_name, applicant_email, why_interested, experience, portfolio_url, created_at, status, club_open_positions!inner(title, club_id)',
            )
            .eq('club_open_positions.club_id', widget.clubId!)
            .order('created_at', ascending: false);
        applications = List<Map<String, dynamic>>.from(
          (apps as List).map((r) => Map<String, dynamic>.from(r as Map)),
        );
      }
      if (!mounted) return;
      setState(() {
        _positions = positions;
        _applications = applications;
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

  Future<void> _apply(Map<String, dynamic> position) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
    final email = TextEditingController(
      text: _db.auth.currentUser?.email ?? '',
    );
    final why = TextEditingController();
    final experience = TextEditingController();
    final portfolio = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Apply: ${position['title'] ?? 'Open position'}'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter your name'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                      ),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Enter a valid email'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: why,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Why are you interested?',
                      ),
                      validator: (v) => (v == null || v.trim().length < 10)
                          ? 'Please write at least 10 characters'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: experience,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Relevant experience / skills (optional)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: portfolio,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Portfolio or profile link (optional)',
                        hintText: 'https://…',
                      ),
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
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Submit application'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      if (_db.auth.currentUser == null)
        throw Exception('Please sign in again.');
      setState(() => _submittingId = position['id'].toString());
      await _db
          .from('club_position_applications')
          .insert({
            'position_id': position['id'],
            'applicant_user_id': _db.auth.currentUser!.id,
            'applicant_name': name.text.trim(),
            'applicant_email': email.text.trim(),
            'why_interested': why.text.trim(),
            'experience': experience.text.trim().isEmpty
                ? null
                : experience.text.trim(),
            'portfolio_url': portfolio.text.trim().isEmpty
                ? null
                : portfolio.text.trim(),
          })
          .select('id')
          .single();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Application submitted. The club can review it in MyClub.',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit application: $e')),
        );
    } finally {
      name.dispose();
      email.dispose();
      why.dispose();
      experience.dispose();
      portfolio.dispose();
      if (mounted) setState(() => _submittingId = null);
    }
  }

  Future<void> _createPosition() async {
    final key = GlobalKey<FormState>();
    final title = TextEditingController();
    final description = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Create open position'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Form(
                key: key,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: title,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Position title',
                        hintText: 'e.g. IT Head, Design Lead, Member',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter a title'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: description,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        labelText: 'Role and requirements',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Describe the role'
                          : null,
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
            FilledButton(
              onPressed: () {
                if (key.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Publish position'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await _db
          .from('club_open_positions')
          .insert({
            'club_id': widget.clubId,
            'title': title.text.trim(),
            'description': description.text.trim(),
            'created_by': _db.auth.currentUser!.id,
          })
          .select('id')
          .single();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Open position published.')),
        );
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not publish position: $e')),
        );
    } finally {
      title.dispose();
      description.dispose();
    }
  }

  Future<void> _closePosition(Map<String, dynamic> position) async {
    try {
      await _db
          .from('club_open_positions')
          .update({'is_open': false})
          .eq('id', position['id']);
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not close position: $e')));
    }
  }

  Future<void> _setStatus(Map<String, dynamic> app, String status) async {
    try {
      await _db
          .from('club_position_applications')
          .update({'status': status})
          .eq('id', app['id']);
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update application: $e')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isManager = widget.canManage && widget.clubId != null;
    final visible = _positions
        .where(
          (p) =>
              '${p['title']} ${p['description']} ${(p['clubs'] as Map?)?['name'] ?? ''}'
                  .toLowerCase()
                  .contains(_search.text.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isManager
              ? '${widget.clubName ?? 'Club'} · Positions'
              : 'Open positions',
        ),
        actions: [
          if (isManager)
            IconButton(
              tooltip: 'View applications',
              icon: const Icon(Icons.inbox_outlined),
              onPressed: () =>
                  setState(() => _showApplications = !_showApplications),
            ),
          if (isManager)
            IconButton(
              tooltip: 'Add position',
              icon: const Icon(Icons.add),
              onPressed: _createPosition,
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load open positions. Apply the MyClub feature migration and try again.\n$_error',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : isManager && _showApplications
          ? _buildApplications()
          : Column(
              children: [
                if (!isManager)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search roles or clubs',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                Expanded(
                  child: visible.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              isManager
                                  ? 'No open positions yet. Tap + to publish one.'
                                  : 'No open positions right now.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final p = visible[index];
                            final club = p['clubs'] is Map
                                ? Map<String, dynamic>.from(p['clubs'] as Map)
                                : <String, dynamic>{};
                            final busy = _submittingId == p['id'].toString();
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.verified,
                                          color: Colors.teal,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            club['name']?.toString() ??
                                                widget.clubName ??
                                                'Verified club',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(
                                                  color: Colors.teal,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      p['title']?.toString() ?? 'Open position',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(p['description']?.toString() ?? ''),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        if (isManager)
                                          TextButton.icon(
                                            onPressed: () => _closePosition(p),
                                            icon: const Icon(Icons.close),
                                            label: const Text('Close position'),
                                          ),
                                        const Spacer(),
                                        if (!isManager)
                                          FilledButton.icon(
                                            onPressed: busy
                                                ? null
                                                : () => _apply(p),
                                            icon: busy
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : const Icon(
                                                    Icons.send_outlined,
                                                  ),
                                            label: Text(
                                              busy ? 'Submitting…' : 'Apply',
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
                ),
              ],
            ),
    );
  }

  Widget _buildApplications() {
    if (_applications.isEmpty)
      return const Center(child: Text('No applications received yet.'));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _applications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final a = _applications[index];
        final position = a['club_open_positions'] is Map
            ? (a['club_open_positions'] as Map)['title']?.toString() ??
                  'Position'
            : 'Position';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  position,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 6),
                Text(
                  a['applicant_name']?.toString() ?? 'Applicant',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                SelectableText(a['applicant_email']?.toString() ?? ''),
                const SizedBox(height: 10),
                const Text(
                  'Why they are interested',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(a['why_interested']?.toString() ?? ''),
                if ((a['experience'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Experience / skills',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(a['experience'].toString()),
                ],
                if ((a['portfolio_url'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SelectableText(a['portfolio_url'].toString()),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('Status: ${a['status'] ?? 'new'}'),
                    const Spacer(),
                    PopupMenuButton<String>(
                      onSelected: (s) => _setStatus(a, s),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'reviewing',
                          child: Text('Mark reviewing'),
                        ),
                        PopupMenuItem(value: 'accepted', child: Text('Accept')),
                        PopupMenuItem(value: 'rejected', child: Text('Reject')),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
