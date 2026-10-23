import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AffiliatedClubsTab extends StatefulWidget {
  final String clubId;
  final String role;

  const AffiliatedClubsTab({
    super.key,
    required this.clubId,
    required this.role,
  });

  @override
  State<AffiliatedClubsTab> createState() => _AffiliatedClubsTabState();
}

class _AffiliatedClubsTabState extends State<AffiliatedClubsTab> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _working = false;
  String? _error;

  bool get _isOwner => widget.role == 'owner';

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
      final result = await _db.rpc(
        'get_club_affiliations',
        params: {'p_club_id': widget.clubId},
      );
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(
          (result as List).map((row) => Map<String, dynamic>.from(row as Map)),
        );
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

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Set<String> get _linkedIds => _items
      .where((item) => item['status'] != 'rejected')
      .map((item) => item['other_club_id'].toString())
      .toSet();

  Future<List<Map<String, dynamic>>> _searchPublicClubs(String query) async {
    final result = await _db.rpc(
      'search_public_clubs',
      params: {'p_search': query.trim()},
    );
    return List<Map<String, dynamic>>.from(
          (result as List).map((row) => Map<String, dynamic>.from(row as Map)),
        )
        .where(
          (club) =>
              club['id'].toString() != widget.clubId &&
              !_linkedIds.contains(club['id'].toString()),
        )
        .toList();
  }

  Future<void> _requestByPublicClub() async {
    final controller = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool searching = true;
    String? searchError;
    String? selectedId;

    Future<void> runSearch(
      String query,
      void Function(void Function()) setDialogState,
    ) async {
      setDialogState(() {
        searching = true;
        searchError = null;
      });
      try {
        final found = await _searchPublicClubs(query);
        setDialogState(() {
          results = found;
          searching = false;
        });
      } catch (error) {
        setDialogState(() {
          searchError = error.toString();
          searching = false;
        });
      }
    }

    try {
      results = await _searchPublicClubs('');
      searching = false;
    } catch (error) {
      searchError = error.toString();
      searching = false;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (searching && results.isEmpty && searchError == null) {
            // The initial search is triggered immediately after the dialog is shown below.
          }
          return AlertDialog(
            title: const Text('Find a public club'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: (value) => runSearch(value, setDialogState),
                    decoration: const InputDecoration(
                      hintText: 'Search by club name or description',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 280,
                    child: searching
                        ? const Center(child: CircularProgressIndicator())
                        : searchError != null
                        ? Center(
                            child: Text(
                              'Could not search clubs.\n$searchError',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : results.isEmpty
                        ? const Center(
                            child: Text(
                              'No matching public clubs.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            itemCount: results.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final club = results[index];
                              final id = club['id'].toString();
                              final name = club['name']?.toString() ?? 'Club';
                              final description =
                                  club['description']?.toString() ?? '';
                              final logo = club['logo_url']?.toString();
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 3,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  backgroundImage:
                                      logo != null && logo.isNotEmpty
                                      ? NetworkImage(logo)
                                      : null,
                                  child: logo == null || logo.isEmpty
                                      ? const Icon(Icons.groups_outlined)
                                      : null,
                                ),
                                title: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: description.isEmpty
                                    ? const Text('Public club')
                                    : Text(
                                        description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                trailing: Radio<String>(
                                  value: id,
                                  groupValue: selectedId,
                                  onChanged: (value) =>
                                      setDialogState(() => selectedId = value),
                                ),
                                onTap: () =>
                                    setDialogState(() => selectedId = id),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: selectedId == null
                    ? null
                    : () => Navigator.pop(dialogContext, selectedId),
                child: const Text('Send request'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (!mounted) return;
    if (selected == null) return;
    await _sendRequest(selected);
  }

  Future<void> _sendRequest(String targetClubId) async {
    setState(() => _working = true);
    try {
      await _db.rpc(
        'request_club_affiliation',
        params: {
          'p_club_id': widget.clubId,
          'p_affiliated_club_id': targetClubId,
        },
      );
      _message('Request sent. The other club’s owner will need to approve it.');
      await _load();
    } catch (error) {
      _message('Could not send request: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _showMyCode({bool regenerate = false}) async {
    setState(() => _working = true);
    try {
      final result = await _db.rpc(
        'get_or_create_club_affiliation_code',
        params: {'p_club_id': widget.clubId, 'p_regenerate': regenerate},
      );
      if (!mounted) return;
      final code = result.toString();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            regenerate ? 'New affiliation code' : 'Your affiliation code',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share this code with another club’s owner. They can use it to request an affiliation; you still decide whether to approve it.',
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  code,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showMyCode(regenerate: true);
              },
              child: const Text('Regenerate'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Navigator.pop(dialogContext);
                _message('Affiliation code copied.');
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy code'),
            ),
          ],
        ),
      );
    } catch (error) {
      _message('Could not create affiliation code: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _useCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Use an affiliation code'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter the code shared by the other club’s owner.'),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Affiliation code',
                  hintText: 'e.g. 7F3A9C12BD',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim().toUpperCase(),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || code == null) return;
    if (code.length < 6) {
      _message('Enter a valid affiliation code.');
      return;
    }
    setState(() => _working = true);
    try {
      await _db.rpc(
        'request_club_affiliation_by_code',
        params: {'p_club_id': widget.clubId, 'p_code': code},
      );
      _message('Request sent. The other club’s owner will need to approve it.');
      await _load();
    } catch (error) {
      _message('Could not use that code: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _respond(Map<String, dynamic> item, bool approve) async {
    setState(() => _working = true);
    try {
      await _db.rpc(
        'respond_to_club_affiliation',
        params: {
          'p_affiliation_id': item['affiliation_id'].toString(),
          'p_approve': approve,
        },
      );
      _message(approve ? 'Affiliation approved.' : 'Request declined.');
      await _load();
    } catch (error) {
      _message('Could not update request: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> item) async {
    final name = item['other_club_name']?.toString() ?? 'this club';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove affiliation?'),
        content: Text(
          'Remove the affiliation with $name? Neither club will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    try {
      await _db.rpc(
        'remove_club_affiliation',
        params: {'p_affiliation_id': item['affiliation_id'].toString()},
      );
      _message('Affiliation removed.');
      await _load();
    } catch (error) {
      _message('Could not remove affiliation: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accepted = _items
        .where((item) => item['status'] == 'accepted')
        .toList();
    final incoming = _items
        .where(
          (item) =>
              item['status'] == 'pending' && item['direction'] == 'incoming',
        )
        .toList();
    final outgoing = _items
        .where(
          (item) =>
              item['status'] == 'pending' && item['direction'] == 'outgoing',
        )
        .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          Text(
            'Affiliations',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Build relationships with other clubs and communities.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_isOwner) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _working || _loading
                        ? null
                        : _requestByPublicClub,
                    icon: const Icon(Icons.search, size: 19),
                    label: const Text('Find a club'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _working || _loading ? null : _useCode,
                    icon: const Icon(Icons.key_outlined, size: 18),
                    label: const Text('Use a code'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _working ? null : () => _showMyCode(),
              icon: const Icon(Icons.ios_share, size: 18),
              label: const Text('Share your club code'),
            ),
            if (_working)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null) ...[
            const SizedBox(height: 20),
            _InfoCard(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load affiliations',
              message: 'Check that the affiliation migration has been applied, then retry.',
              action: TextButton(onPressed: _load, child: const Text('Retry')),
            ),
          ] else ...[
            if (_isOwner && incoming.isNotEmpty) ...[
              const SizedBox(height: 28),
              _SectionTitle(
                title: 'Requests to review',
                count: incoming.length,
              ),
              ...incoming.map(
                (item) => _AffiliationCard(
                  item: item,
                  statusLabel: 'Needs your decision',
                  actions: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _working
                              ? null
                              : () => _respond(item, false),
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: _working
                              ? null
                              : () => _respond(item, true),
                          child: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (accepted.isNotEmpty) ...[
              const SizedBox(height: 28),
              _SectionTitle(title: 'Affiliated clubs', count: accepted.length),
              ...accepted.map(
                (item) => _AffiliationCard(
                  item: item,
                  statusLabel: 'Affiliated',
                  actions: _isOwner
                      ? Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _working ? null : () => _remove(item),
                            icon: const Icon(Icons.link_off, size: 17),
                            label: const Text('Remove'),
                          ),
                        )
                      : null,
                ),
              ),
            ],
            if (outgoing.isNotEmpty) ...[
              const SizedBox(height: 28),
              _SectionTitle(title: 'Sent requests', count: outgoing.length),
              ...outgoing.map(
                (item) => _AffiliationCard(
                  item: item,
                  statusLabel: 'Waiting for approval',
                ),
              ),
            ],
            if (accepted.isEmpty && incoming.isEmpty && outgoing.isEmpty) ...[
              const SizedBox(height: 26),
              _InfoCard(
                icon: Icons.handshake_outlined,
                title: 'No affiliations yet',
                message: _isOwner
                    ? 'Find a public club or use an affiliation code to start a connection. The other club’s owner approves the request.'
                    : 'Affiliated clubs and incoming requests will appear here.',
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _AffiliationCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String statusLabel;
  final Widget? actions;
  const _AffiliationCard({
    required this.item,
    required this.statusLabel,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = item['other_club_name']?.toString() ?? 'Club';
    final logo = item['other_logo_url']?.toString();
    final description = item['other_description']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: colors.primaryContainer,
                    backgroundImage: logo != null && logo.isNotEmpty
                        ? NetworkImage(logo)
                        : null,
                    child: logo == null || logo.isEmpty
                        ? Icon(
                            Icons.groups_outlined,
                            color: colors.onPrimaryContainer,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (actions != null) ...[const SizedBox(height: 12), actions!],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;
  const _SectionTitle({required this.title, required this.count});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$count',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    ),
  );
}
