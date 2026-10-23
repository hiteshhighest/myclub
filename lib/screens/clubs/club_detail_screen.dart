import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart' as picker;

import 'affiliated_clubs_tab.dart';

class ClubDetailScreen extends StatefulWidget {
  final String clubId;
  final String clubName;
  final String description;
  final String role;

  const ClubDetailScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.description,
    required this.role,
  });

  @override
  State<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends State<ClubDetailScreen> {
  final SupabaseClient _db = Supabase.instance.client;
  final TextEditingController _positionController = TextEditingController();

  bool _loadingPosition = true;
  bool _savingPosition = false;
  bool _generating = false;
  bool _savingClubDetails = false;
  bool _savingClubVisibility = false;
  bool _isPublicClub = false;

  late String _clubName;
  late String _clubDescription;
  String? _clubLogoUrl;

  String? _position;
  String? _positionError;

  bool get _isLeader => widget.role == 'owner' || widget.role == 'executive';

  bool get _isOwner => widget.role == 'owner';

  @override
  void initState() {
    super.initState();
    _clubName = widget.clubName;
    _clubDescription = widget.description;
    _loadPosition();
    _loadClubDetails();
  }

  @override
  void dispose() {
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _loadClubDetails() async {
    try {
      final club = await _db
          .from('clubs')
          .select('name, description, logo_url, is_public')
          .eq('id', widget.clubId)
          .maybeSingle();
      if (!mounted || club == null) return;
      setState(() {
        _clubName = club['name']?.toString() ?? _clubName;
        _clubDescription = club['description']?.toString() ?? _clubDescription;
        _clubLogoUrl = club['logo_url']?.toString();
        _isPublicClub = club['is_public'] == true;
      });
    } catch (_) {
      // Keep the values supplied by the parent if the optional logo column
      // has not been added to the database yet.
    }
  }

  Future<void> _setClubVisibility(bool isPublic) async {
    if (!_isOwner || _savingClubVisibility || isPublic == _isPublicClub) return;
    setState(() => _savingClubVisibility = true);
    try {
      await _db.rpc(
        'set_my_club_visibility',
        params: {'p_club_id': widget.clubId, 'p_is_public': isPublic},
      );
      if (!mounted) return;
      setState(() => _isPublicClub = isPublic);
      _message(
        isPublic
            ? 'Your club is now public and can be discovered.'
            : 'Your club is now private. Invite-code joining is required.',
      );
    } catch (error) {
      _message('Could not update club visibility: $error');
    } finally {
      if (mounted) setState(() => _savingClubVisibility = false);
    }
  }

  Future<void> _editClubDetails() async {
    if (!_isOwner || _savingClubDetails) return;
    final nameController = TextEditingController(text: _clubName);
    final descriptionController = TextEditingController(text: _clubDescription);
    final formKey = GlobalKey<FormState>();
    picker.PlatformFile? selectedLogoFile;
    bool removeLogo = false;

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit club details'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Club name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Enter a club name.';
                        if (text.length > 80)
                          return 'Use 80 characters or fewer.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descriptionController,
                      maxLength: 500,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Club logo',
                        style: Theme.of(dialogContext).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (selectedLogoFile != null)
                      Row(
                        children: [
                          const Icon(Icons.image_outlined),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedLogoFile!.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove selected image',
                            onPressed: () =>
                                setDialogState(() => selectedLogoFile = null),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      )
                    else if (!removeLogo && (_clubLogoUrl?.isNotEmpty ?? false))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _clubLogoUrl!,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(child: Text('Current logo')),
                          ],
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await picker.FilePicker.platform
                              .pickFiles(
                                type: picker.FileType.image,
                                allowMultiple: false,
                                withData: true,
                              );
                          if (picked == null || picked.files.isEmpty) return;
                          final file = picked.files.single;
                          if (file.bytes == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not read that image. Please choose it again.',
                                ),
                              ),
                            );
                            return;
                          }
                          setDialogState(() {
                            selectedLogoFile = file;
                            removeLogo = false;
                          });
                        },
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Attach logo image'),
                      ),
                    ),
                    if ((_clubLogoUrl?.isNotEmpty ?? false) && !removeLogo)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setDialogState(() {
                            removeLogo = true;
                            selectedLogoFile = null;
                          }),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remove current logo'),
                        ),
                      ),
                    if (removeLogo)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () =>
                              setDialogState(() => removeLogo = false),
                          child: const Text('Keep current logo'),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose an image from your device. JPG, PNG and WebP images are recommended.',
                      style: Theme.of(dialogContext).textTheme.bodySmall,
                    ),
                  ],
                ),
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
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(dialogContext, {
                  'name': nameController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'remove_logo': removeLogo ? 'true' : 'false',
                });
              },
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    descriptionController.dispose();
    if (result == null || !mounted) return;

    setState(() => _savingClubDetails = true);
    try {
      String? logoUrl = _clubLogoUrl;
      if (selectedLogoFile != null) {
        final file = selectedLogoFile!;
        final extension = (file.extension ?? 'png').toLowerCase();
        final safeExtension = RegExp(r'^[a-z0-9]{1,8}$').hasMatch(extension)
            ? extension
            : 'png';
        final path =
            '${widget.clubId}/logo_${DateTime.now().millisecondsSinceEpoch}.$safeExtension';
        final contentType = switch (safeExtension) {
          'jpg' || 'jpeg' => 'image/jpeg',
          'webp' => 'image/webp',
          'gif' => 'image/gif',
          'svg' => 'image/svg+xml',
          _ => 'image/png',
        };
        await _db.storage
            .from('club-logos')
            .uploadBinary(
              path,
              file.bytes!,
              fileOptions: FileOptions(contentType: contentType, upsert: false),
            );
        logoUrl = _db.storage.from('club-logos').getPublicUrl(path);
      } else if (result['remove_logo'] == 'true') {
        logoUrl = null;
      }

      await _db.rpc(
        'update_my_club_details',
        params: {
          'p_club_id': widget.clubId,
          'p_name': result['name'],
          'p_description': result['description'],
          'p_logo_url': logoUrl,
        },
      );
      if (!mounted) return;
      setState(() {
        _clubName = result['name']!;
        _clubDescription = result['description']!;
        _clubLogoUrl = logoUrl;
      });
      _message('Club details updated.');
    } catch (error) {
      _message('Could not update club details: $error');
    } finally {
      if (mounted) setState(() => _savingClubDetails = false);
    }
  }

  Future<void> _loadPosition() async {
    try {
      final user = _db.auth.currentUser;
      if (user == null) throw Exception('Please sign in again.');

      final result = await _db
          .from('club_members')
          .select('position')
          .eq('club_id', widget.clubId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final position = result?['position']?.toString();

      setState(() {
        _position = position;
        _positionController.text = position ?? '';
        _loadingPosition = false;
        _positionError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _positionError = error.toString();
        _loadingPosition = false;
      });
    }
  }

  Future<void> _savePosition() async {
    final value = _positionController.text.trim();

    if (value.isEmpty || value.length > 60) {
      _message('Enter a position between 1 and 60 characters.');
      return;
    }

    setState(() => _savingPosition = true);

    try {
      final result = await _db.rpc(
        'set_my_club_position',
        params: {'p_club_id': widget.clubId, 'p_position': value},
      );

      if (!mounted) return;

      setState(() {
        _position = result.toString();
        _positionController.text = result.toString();
      });

      _message('Position updated.');
    } catch (error) {
      if (mounted) _message('Could not save position: $error');
    } finally {
      if (mounted) setState(() => _savingPosition = false);
    }
  }

  Future<void> _leaveClub() async {
    if (_isOwner) {
      final action = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Leave or close this club?'),
          content: const Text(
            'You can permanently delete this club, or transfer ownership to another member and leave. Choose Transfer & leave to select the new owner.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'cancel'),
              child: const Text('Cancel'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, 'transfer'),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Transfer & leave'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(dialogContext, 'delete'),
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Delete club'),
            ),
          ],
        ),
      );

      if (!mounted || action == null || action == 'cancel') return;
      if (action == 'delete') {
        await _confirmAndDeleteClub();
      } else if (action == 'transfer') {
        await _transferOwnershipAndLeave();
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave club?'),
        content: Text(
          'You will lose access to ${_clubName} and its member-only content. '
          'You can rejoin later if you have a valid invite code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave club'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _db.rpc('leave_my_club', params: {'p_club_id': widget.clubId});
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      _message('Could not leave club: $error');
    }
  }

  Future<void> _confirmAndDeleteClub() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Permanently delete club?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This permanently deletes ${_clubName}, its membership, '
                'events, announcements, and chat history. This cannot be undone.',
              ),
              const SizedBox(height: 14),
              Text('Type "${_clubName}" to confirm.'),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Club name',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: controller.text.trim() == _clubName.trim()
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('Delete permanently'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (confirmed != true || !mounted) return;

    try {
      await _db.rpc('delete_my_club', params: {'p_club_id': widget.clubId});
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      _message('Could not delete club: $error');
    }
  }

  Future<void> _transferOwnershipAndLeave() async {
    try {
      final currentUserId = _db.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Please sign in again.');

      final memberships = await _db
          .from('club_members')
          .select('user_id, role')
          .eq('club_id', widget.clubId)
          .neq('user_id', currentUserId)
          .order('joined_at');

      if (!mounted) return;
      if (memberships.isEmpty) {
        _message(
          'Invite at least one other member before transferring ownership.',
        );
        return;
      }

      final userIds = memberships.map((m) => m['user_id'].toString()).toList();
      final profiles = await _db
          .from('profiles')
          .select('id, display_name')
          .inFilter('id', userIds);
      final names = <String, String>{
        for (final profile in profiles)
          profile['id'].toString():
              (profile['display_name']?.toString().trim().isNotEmpty ?? false)
              ? profile['display_name'].toString().trim()
              : 'Club member',
      };

      if (!mounted) return;
      final targetId = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Choose the new owner'),
          content: SizedBox(
            width: 360,
            child: ListView(
              shrinkWrap: true,
              children: memberships.map((membership) {
                final id = membership['user_id'].toString();
                final role = membership['role']?.toString() ?? 'member';
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(names[id] ?? 'Club member'),
                  subtitle: Text(role == 'executive' ? 'Executive' : 'Member'),
                  onTap: () => Navigator.pop(dialogContext, id),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (targetId == null || !mounted) return;

      final targetName = names[targetId] ?? 'this member';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Transfer ownership and leave?'),
          content: Text(
            '$targetName will become the owner. You will then leave the club '
            'and lose access to its member-only content.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Transfer & leave'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      await _db.rpc(
        'transfer_club_ownership',
        params: {'p_club_id': widget.clubId, 'p_new_owner_id': targetId},
      );
      await _db.rpc('leave_my_club', params: {'p_club_id': widget.clubId});
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      _message('Could not transfer ownership and leave: $error');
    }
  }

  Future<void> _generateInviteCode(String role) async {
    setState(() => _generating = true);

    try {
      final result = await _db.rpc(
        'create_invite_code',
        params: {
          'p_club_id': widget.clubId,
          'p_role': role,
          'p_expires_at': null,
          'p_max_uses': null,
        },
      );

      if (!mounted) return;
      final code = result.toString();

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Invitation code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invites ${role == 'member' ? 'members' : 'executives'}'),
              const SizedBox(height: 16),
              SelectableText(
                code,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const SizedBox(height: 12),
              const Text('No expiry or usage limit.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));

                if (!dialogContext.mounted) return;

                Navigator.pop(dialogContext);
                _message('Invitation code copied.');
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _message('Could not create invitation: $error');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_clubName, maxLines: 1, overflow: TextOverflow.ellipsis),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.home_outlined), text: 'Overview'),
              Tab(icon: Icon(Icons.campaign_outlined), text: 'Announcements'),
              Tab(icon: Icon(Icons.event_outlined), text: 'Events'),
              Tab(icon: Icon(Icons.people_outline), text: 'Members'),
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'),
              Tab(icon: Icon(Icons.handshake_outlined), text: 'Affiliations'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOverview(theme),
            _AnnouncementsTab(clubId: widget.clubId, canManage: _isLeader),
            _EventsTab(clubId: widget.clubId, canManage: _isLeader),
            _MembersTab(clubId: widget.clubId, currentUserRole: widget.role),
            _ClubChatTab(clubId: widget.clubId),
            AffiliatedClubsTab(clubId: widget.clubId, role: widget.role),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview(ThemeData theme) {
    final roleLabel = switch (widget.role) {
      'owner' => 'Owner',
      'executive' => 'Executive',
      _ => 'Member',
    };

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: theme.colorScheme.primaryContainer,
            backgroundImage: _clubLogoUrl != null && _clubLogoUrl!.isNotEmpty
                ? NetworkImage(_clubLogoUrl!)
                : null,
            child: _clubLogoUrl == null || _clubLogoUrl!.isEmpty
                ? Icon(
                    Icons.groups_rounded,
                    size: 40,
                    color: theme.colorScheme.onPrimaryContainer,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _clubName,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _clubDescription.isEmpty
              ? 'No club description yet.'
              : _clubDescription,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        if (_isOwner) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _savingClubDetails ? null : _editClubDetails,
            icon: _savingClubDetails
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.edit_outlined),
            label: const Text('Edit club details'),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile.adaptive(
              value: _isPublicClub,
              onChanged: _savingClubVisibility ? null : _setClubVisibility,
              title: const Text('Public club'),
              subtitle: Text(
                _isPublicClub
                    ? 'Discoverable in Public Clubs. Anyone signed in can join without an invite code.'
                    : 'Private club. People need an invite code to join.',
              ),
              secondary: _savingClubVisibility
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_isPublicClub ? Icons.public : Icons.lock_outline),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Your role'),
            subtitle: Text(roleLabel),
            trailing: _isOwner ? const Icon(Icons.verified_outlined) : null,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Your position',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingPosition)
          const Center(child: CircularProgressIndicator())
        else if (_positionError != null)
          Card(
            child: ListTile(
              title: const Text('Could not load position'),
              subtitle: Text(_positionError!),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() {
                    _loadingPosition = true;
                    _positionError = null;
                  });
                  _loadPosition();
                },
              ),
            ),
          )
        else if (_isLeader)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _positionController,
                    maxLength: 60,
                    enabled: !_savingPosition,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Position or title',
                      hintText: 'e.g. President, IT Head, Secretary',
                      prefixIcon: Icon(Icons.work_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _savingPosition ? null : _savePosition,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save position'),
                    ),
                  ),
                  if (_savingPosition)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
          )
        else
          Card(
            child: ListTile(
              leading: const Icon(Icons.work_outline),
              title: Text(
                (_position == null || _position!.isEmpty)
                    ? 'Member'
                    : _position!,
              ),
            ),
          ),
        const SizedBox(height: 24),
        if (_isLeader) ...[
          Text(
            'Invitations',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Invite people to join your club using a shareable code.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _generating ? null : () => _generateInviteCode('member'),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Invite members'),
          ),
          if (_isOwner) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _generating
                  ? null
                  : () => _generateInviteCode('executive'),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Invite executives'),
            ),
          ],
          if (_generating)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
            title: Text(
              'Leave club',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: Text(
              _isOwner
                  ? 'Delete the club or transfer ownership to another member before leaving.'
                  : 'Remove yourself from this club.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _leaveClub,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// ANNOUNCEMENTS AND FILE ATTACHMENTS
// -----------------------------------------------------------------------------

class _AnnouncementsTab extends StatefulWidget {
  final String clubId;
  final bool canManage;

  const _AnnouncementsTab({required this.clubId, required this.canManage});

  @override
  State<_AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<_AnnouncementsTab> {
  final SupabaseClient _db = Supabase.instance.client;

  static const String _bucket = 'club-announcements';
  static const int _maxFileSize = 20 * 1024 * 1024;
  static const int _maxAttachments = 5;

  List<Map<String, dynamic>> _items = [];
  Map<String, List<Map<String, dynamic>>> _attachments = {};

  bool _loading = true;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileViewScreen(userId: userId)),
    );
  }

  String _fileType(String name) {
    switch (name.split('.').last.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      default:
        throw Exception('Unsupported file type: $name');
    }
  }

  String _fileSize(dynamic value) {
    final bytes = int.tryParse(value?.toString() ?? '') ?? 0;

    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(bytes / 1024).ceil()} KB';
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _db
            .from('announcements')
            .select()
            .eq('club_id', widget.clubId)
            .order('is_pinned', ascending: false)
            .order('created_at', ascending: false),
        _db
            .from('announcement_attachments')
            .select()
            .eq('club_id', widget.clubId)
            .order('created_at'),
      ]);

      final announcements = List<Map<String, dynamic>>.from(results[0]);
      final attachmentRows = List<Map<String, dynamic>>.from(results[1]);

      // Fetch visible author profiles separately so profile RLS rules remain active.
      final authorIds = announcements
          .map((item) => item['created_by']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final profilesById = <String, Map<String, dynamic>>{};
      if (authorIds.isNotEmpty) {
        try {
          final profiles = await _db
              .from('profiles')
              .select(
                'id, display_name, avatar_url, bio, is_profile_public, show_clubs',
              )
              .inFilter('id', authorIds);
          for (final profile in profiles) {
            profilesById[profile['id'].toString()] = Map<String, dynamic>.from(
              profile,
            );
          }
        } catch (_) {
          // Announcements should still load if profile visibility blocks this query.
        }
      }
      for (final item in announcements) {
        final authorId = item['created_by']?.toString() ?? '';
        item['author_profile'] = profilesById[authorId];
      }

      final grouped = <String, List<Map<String, dynamic>>>{};

      for (final attachment in attachmentRows) {
        final id = attachment['announcement_id'].toString();
        grouped.putIfAbsent(id, () => []).add(attachment);
      }

      if (!mounted) return;

      setState(() {
        _items = announcements;
        _attachments = grouped;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickAttachments(
    List<picker.PlatformFile> selected,
    void Function(void Function()) setDialogState,
    BuildContext dialogContext,
  ) async {
    final remaining = _maxAttachments - selected.length;

    if (remaining <= 0) {
      _message('You can attach up to $_maxAttachments files.');
      return;
    }

    try {
      final result = await picker.FilePicker.platform.pickFiles(
        type: picker.FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'pdf',
          'doc',
          'docx',
          'ppt',
          'pptx',
        ],
        allowMultiple: true,
        withData: true,
      );

      if (result == null || !dialogContext.mounted) return;

      final additions = result.files.take(remaining).toList();

      for (final file in additions) {
        if (file.size <= 0 || file.size > _maxFileSize) {
          _message('${file.name} must be between 1 byte and 20 MB.');
          continue;
        }

        if (file.bytes == null) {
          _message('Could not read ${file.name}. Select it again.');
          continue;
        }

        if (selected.any((existing) => existing.name == file.name)) {
          continue;
        }

        selected.add(file);
      }

      setDialogState(() {});
    } catch (error) {
      _message('Could not select files: $error');
    }
  }

  Future<void> _create() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final selectedFiles = <picker.PlatformFile>[];
    bool pinned = false;
    String visibility = 'all_members';

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('New announcement'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        maxLength: 150,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter a title'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: bodyController,
                        maxLength: 10000,
                        minLines: 4,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Announcement',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter the announcement'
                            : null,
                      ),
                      DropdownButtonFormField<String>(
                        value: visibility,
                        decoration: const InputDecoration(
                          labelText: 'Audience',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all_members',
                            child: Text('All Club Members'),
                          ),
                          DropdownMenuItem(
                            value: 'executives',
                            child: Text('Executive Only'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => visibility = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Pin announcement'),
                        value: pinned,
                        onChanged: (value) {
                          setDialogState(() => pinned = value ?? false);
                        },
                      ),
                      const Divider(),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Attachments',
                          style: Theme.of(dialogContext).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _pickAttachments(
                          selectedFiles,
                          setDialogState,
                          dialogContext,
                        ),
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Attach files'),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'PDF, images, Word or PowerPoint. '
                        'Up to 5 files, 20 MB each.',
                        style: TextStyle(fontSize: 12),
                      ),
                      for (final file in selectedFiles)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            file.name.toLowerCase().endsWith('.pdf')
                                ? Icons.picture_as_pdf_outlined
                                : Icons.insert_drive_file_outlined,
                          ),
                          title: Text(
                            file.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(_fileSize(file.size)),
                          trailing: IconButton(
                            tooltip: 'Remove attachment',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setDialogState(() => selectedFiles.remove(file));
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(dialogContext, true);
                  }
                },
                child: const Text('Publish'),
              ),
            ],
          ),
        ),
      );

      if (result != true) return;

      final user = _db.auth.currentUser;

      if (user == null) {
        _message('Please sign in again.');
        return;
      }

      if (!mounted) return;
      setState(() => _working = true);

      String? announcementId;
      final uploadedPaths = <String>[];

      try {
        final created = await _db
            .from('announcements')
            .insert({
              'club_id': widget.clubId,
              'title': titleController.text.trim(),
              'body': bodyController.text.trim(),
              'is_pinned': pinned,
              'visibility': visibility,
              'created_by': user.id,
            })
            .select('id')
            .single();

        announcementId = created['id'].toString();

        for (var i = 0; i < selectedFiles.length; i++) {
          final file = selectedFiles[i];
          final bytes = file.bytes;

          if (bytes == null) {
            throw Exception('Could not read ${file.name}.');
          }

          final safeName = file.name.replaceAll(
            RegExp(r'[^a-zA-Z0-9._-]'),
            '_',
          );

          final path =
              '${widget.clubId}/$announcementId/'
              '${DateTime.now().microsecondsSinceEpoch}_${i}_$safeName';

          final mime = _fileType(file.name);

          await _db.storage
              .from(_bucket)
              .uploadBinary(
                path,
                bytes,
                fileOptions: FileOptions(contentType: mime, upsert: false),
              );

          uploadedPaths.add(path);

          await _db.from('announcement_attachments').insert({
            'announcement_id': announcementId,
            'club_id': widget.clubId,
            'storage_path': path,
            'file_name': file.name,
            'mime_type': mime,
            'size_bytes': file.size,
            'uploaded_by': user.id,
          });
        }

        if (!mounted) return;

        _message('Announcement published.');
        await _load();
      } catch (error) {
        // Best-effort cleanup if an upload or metadata insert fails.
        try {
          if (uploadedPaths.isNotEmpty) {
            await _db.storage.from(_bucket).remove(uploadedPaths);
          }

          if (announcementId != null) {
            await _db.from('announcements').delete().eq('id', announcementId);
          }
        } catch (_) {
          // Preserve the original error.
        }

        _message('Could not publish announcement: $error');
      }
    } finally {
      titleController.dispose();
      bodyController.dispose();

      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _openAttachment(Map<String, dynamic> attachment) async {
    try {
      final path = attachment['storage_path'].toString();

      // The bucket stays private. This link expires after 60 seconds.
      final signedUrl = await _db.storage
          .from(_bucket)
          .createSignedUrl(path, 60);

      if (!mounted) return;

      final opened = await launchUrl(
        Uri.parse(signedUrl),
        mode: LaunchMode.platformDefault,
      );

      if (!opened) {
        _message('Could not open this attachment.');
      }
    } catch (error) {
      _message('Could not open attachment: $error');
    }
  }

  Future<void> _togglePin(Map<String, dynamic> item) async {
    try {
      await _db
          .from('announcements')
          .update({'is_pinned': item['is_pinned'] != true})
          .eq('id', item['id']);

      await _load();
    } catch (error) {
      _message('Could not update announcement: $error');
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete announcement?'),
        content: const Text(
          'The announcement and its attachments will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final id = item['id'].toString();
      final attachments = _attachments[id] ?? [];
      final paths = attachments
          .map((file) => file['storage_path'].toString())
          .toList();

      // Remove storage objects before deleting the announcement record.
      if (paths.isNotEmpty) {
        await _db.storage.from(_bucket).remove(paths);
      }

      await _db.from('announcements').delete().eq('id', id);

      if (!mounted) return;

      _message('Announcement deleted.');
      await _load();
    } catch (error) {
      _message('Could not delete announcement: $error');
    }
  }

  String _dateLabel(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '';

    final local = date.toLocal();

    return '${local.day}/${local.month}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.canManage)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _working ? null : _create,
                icon: const Icon(Icons.add),
                label: const Text('New announcement'),
              ),
            ),
          ),
        if (_working) const LinearProgressIndicator(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _items.isEmpty
              ? const _EmptyView(
                  icon: Icons.campaign_outlined,
                  title: 'No announcements yet',
                  subtitle: 'Club updates will appear here.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final pinned = item['is_pinned'] == true;
                      final id = item['id'].toString();
                      final files = _attachments[id] ?? [];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['title']?.toString() ?? '',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  if (pinned)
                                    const Icon(Icons.push_pin, size: 18),
                                  if (widget.canManage)
                                    PopupMenuButton<String>(
                                      onSelected: (action) {
                                        if (action == 'pin') {
                                          _togglePin(item);
                                        } else if (action == 'delete') {
                                          _delete(item);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        PopupMenuItem(
                                          value: 'pin',
                                          child: Text(pinned ? 'Unpin' : 'Pin'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              if (item['visibility'] == 'executives')
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Chip(
                                      avatar: const Icon(
                                        Icons.admin_panel_settings_outlined,
                                        size: 16,
                                      ),
                                      label: const Text('Executive Only'),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              _AnnouncementAuthorRow(
                                profile: item['author_profile'] is Map
                                    ? Map<String, dynamic>.from(
                                        item['author_profile'] as Map,
                                      )
                                    : null,
                                onTap:
                                    (item['created_by']
                                            ?.toString()
                                            .isNotEmpty ??
                                        false)
                                    ? () => _openProfile(
                                        item['created_by'].toString(),
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 10),
                              Text(item['body']?.toString() ?? ''),
                              if (files.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                const Divider(),
                                const Text(
                                  'Attachments',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                for (final file in files)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      file['mime_type']?.toString().startsWith(
                                                'image/',
                                              ) ==
                                              true
                                          ? Icons.image_outlined
                                          : file['mime_type'] ==
                                                'application/pdf'
                                          ? Icons.picture_as_pdf_outlined
                                          : Icons.attach_file_outlined,
                                    ),
                                    title: Text(
                                      file['file_name']?.toString() ??
                                          'Attachment',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      _fileSize(file['size_bytes']),
                                    ),
                                    trailing: const Icon(Icons.open_in_new),
                                    onTap: () => _openAttachment(file),
                                  ),
                              ],
                              const SizedBox(height: 12),
                              Text(
                                _dateLabel(item['created_at']),
                                style: Theme.of(context).textTheme.bodySmall,
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
    );
  }
}

// -----------------------------------------------------------------------------
// EVENTS
// -----------------------------------------------------------------------------

class _EventsTab extends StatefulWidget {
  final String clubId;
  final bool canManage;

  const _EventsTab({required this.clubId, required this.canManage});

  @override
  State<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<_EventsTab> {
  final SupabaseClient _db = Supabase.instance.client;

  List<Map<String, dynamic>> _events = [];

  bool _loading = true;
  String? _error;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _load() async {
    try {
      final events = await _db
          .from('club_events')
          .select()
          .eq('club_id', widget.clubId)
          .order('starts_at');

      if (!mounted) return;

      setState(() {
        _events = List<Map<String, dynamic>>.from(events);
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createEvent() async {
    final title = TextEditingController();
    final description = TextEditingController();
    final location = TextEditingController();
    final formKey = GlobalKey<FormState>();

    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    String visibility = 'all_members';

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Create event'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: title,
                      maxLength: 150,
                      decoration: const InputDecoration(
                        labelText: 'Event name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter an event name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: description,
                      maxLength: 5000,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: location,
                      maxLength: 300,
                      decoration: const InputDecoration(
                        labelText: 'Venue or meeting link',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: visibility,
                      decoration: const InputDecoration(
                        labelText: 'Audience',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'all_members',
                          child: Text('All Club Members'),
                        ),
                        DropdownMenuItem(
                          value: 'executives',
                          child: Text('Executive Only'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => visibility = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month),
                      title: const Text('Date'),
                      subtitle: Text(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                        );

                        if (picked != null && dialogContext.mounted) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule),
                      title: const Text('Start time'),
                      subtitle: Text(selectedTime.format(dialogContext)),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: dialogContext,
                          initialTime: selectedTime,
                        );

                        if (picked != null && dialogContext.mounted) {
                          setDialogState(() => selectedTime = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(dialogContext, true);
                  }
                },
                child: const Text('Create event'),
              ),
            ],
          ),
        ),
      );

      if (result != true) return;

      final user = _db.auth.currentUser;

      if (user == null) {
        _message('Please sign in again.');
        return;
      }

      final start = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      if (!mounted) return;
      setState(() => _working = true);

      await _db.from('club_events').insert({
        'club_id': widget.clubId,
        'title': title.text.trim(),
        'description': description.text.trim(),
        'location': location.text.trim(),
        'starts_at': start.toUtc().toIso8601String(),
        'visibility': visibility,
        'created_by': user.id,
      });

      if (!mounted) return;

      _message('Event created.');
      await _load();
    } catch (error) {
      _message('Could not create event: $error');
    } finally {
      title.dispose();
      description.dispose();
      location.dispose();

      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _deleteEvent(Map<String, dynamic> event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete event?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _db.from('club_events').delete().eq('id', event['id']);

      if (!mounted) return;

      _message('Event deleted.');
      await _load();
    } catch (error) {
      _message('Could not delete event: $error');
    }
  }

  String _dateLabel(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');

    if (date == null) return 'Date unavailable';

    final local = date.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '${local.day}/${local.month}/${local.year} · '
        '$hour:${local.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.canManage)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _working ? null : _createEvent,
                icon: const Icon(Icons.add),
                label: const Text('Create event'),
              ),
            ),
          ),
        if (_working) const LinearProgressIndicator(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _events.isEmpty
              ? const _EmptyView(
                  icon: Icons.event_outlined,
                  title: 'No events scheduled',
                  subtitle: 'Upcoming club activities will appear here.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _events.length,
                    itemBuilder: (context, index) {
                      final event = _events[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      event['title']?.toString() ?? '',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  if (widget.canManage)
                                    PopupMenuButton<String>(
                                      onSelected: (action) {
                                        if (action == 'delete') {
                                          _deleteEvent(event);
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete event'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              if (event['visibility'] == 'executives')
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Chip(
                                      avatar: const Icon(
                                        Icons.admin_panel_settings_outlined,
                                        size: 16,
                                      ),
                                      label: const Text('Executive Only'),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(_dateLabel(event['starts_at'])),
                                  ),
                                ],
                              ),
                              if ((event['location'] ?? '')
                                  .toString()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(event['location'].toString()),
                                    ),
                                  ],
                                ),
                              ],
                              if ((event['description'] ?? '')
                                  .toString()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(event['description'].toString()),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// MEMBERS
// -----------------------------------------------------------------------------

class _MembersTab extends StatefulWidget {
  final String clubId;
  final String currentUserRole;

  const _MembersTab({required this.clubId, required this.currentUserRole});

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab> {
  final SupabaseClient _db = Supabase.instance.client;

  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final memberships = await _db
          .from('club_members')
          .select('user_id, role, position, joined_at')
          .eq('club_id', widget.clubId)
          .order('joined_at');

      final ids = memberships
          .map((row) => row['user_id'].toString())
          .toSet()
          .toList();

      final profilesById = <String, Map<String, dynamic>>{};

      if (ids.isNotEmpty) {
        final profiles = await _db
            .from('profiles')
            .select(
              'id, display_name, avatar_url, bio, is_profile_public, show_clubs',
            )
            .inFilter('id', ids);

        for (final profile in profiles) {
          profilesById[profile['id'].toString()] = Map<String, dynamic>.from(
            profile,
          );
        }
      }

      final merged = <Map<String, dynamic>>[];

      for (final row in memberships) {
        final member = Map<String, dynamic>.from(row);
        member['profile'] = profilesById[row['user_id'].toString()] ?? {};
        merged.add(member);
      }

      if (!mounted) return;

      setState(() {
        _members = merged;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  bool _canKick(String targetRole, String targetUserId) {
    final currentUserId = _db.auth.currentUser?.id;
    if (currentUserId == null || currentUserId == targetUserId) return false;
    if (targetRole == 'owner') return false;
    if (widget.currentUserRole == 'owner') return true;
    return widget.currentUserRole == 'executive' && targetRole == 'member';
  }

  Future<void> _kickMember(
    Map<String, dynamic> member,
    String displayName,
  ) async {
    final targetUserId = member['user_id'].toString();
    final targetRole = member['role']?.toString() ?? 'member';
    if (!_canKick(targetRole, targetUserId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          targetRole == 'executive' ? 'Remove executive?' : 'Kick member?',
        ),
        content: Text(
          'Remove $displayName from this club? They will lose access to its member-only content.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _db.rpc(
        'kick_club_member',
        params: {'p_club_id': widget.clubId, 'p_target_user_id': targetUserId},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$displayName was removed from the club.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove member: $error')),
      );
    }
  }

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileViewScreen(userId: userId)),
    );
  }

  bool _memberHasActions(Map<String, dynamic> member, String role) {
    final userId = member['user_id'].toString();
    return _canKick(role, userId);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }

    if (_members.isEmpty) {
      return const _EmptyView(
        icon: Icons.people_outline,
        title: 'No members found',
        subtitle: 'Club members will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _members.length,
        itemBuilder: (context, index) {
          final member = _members[index];
          final profile = member['profile'] as Map<String, dynamic>;
          final name = profile['display_name']?.toString().trim();
          final avatarUrl = profile['avatar_url']?.toString();
          final role = member['role']?.toString() ?? 'member';
          final position = member['position']?.toString().trim() ?? '';

          final displayName = name == null || name.isEmpty
              ? 'Club member'
              : name;

          final roleLabel = switch (role) {
            'owner' => 'Owner',
            'executive' => 'Executive',
            _ => 'Member',
          };

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? Text(
                        displayName.isEmpty
                            ? '?'
                            : displayName.substring(0, 1).toUpperCase(),
                      )
                    : null,
              ),
              title: Text(displayName),
              subtitle: Text(
                position.isNotEmpty ? '$position · $roleLabel' : roleLabel,
              ),
              trailing: _memberHasActions(member, role)
                  ? PopupMenuButton<String>(
                      tooltip: 'Member actions',
                      onSelected: (action) {
                        if (action == 'kick') {
                          _kickMember(member, displayName);
                        }
                      },
                      itemBuilder: (context) => [
                        if (_canKick(role, member['user_id'].toString()))
                          PopupMenuItem(
                            value: 'kick',
                            child: Text(
                              role == 'executive'
                                  ? 'Remove executive'
                                  : 'Kick member',
                            ),
                          ),
                      ],
                    )
                  : const Icon(Icons.chevron_right),
              onTap: () => _openProfile(member['user_id'].toString()),
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// CLUB CHAT
// -----------------------------------------------------------------------------

class _ClubChatTab extends StatefulWidget {
  final String clubId;

  const _ClubChatTab({required this.clubId});

  @override
  State<_ClubChatTab> createState() => _ClubChatTabState();
}

class _ClubChatTabState extends State<_ClubChatTab> {
  final SupabaseClient _db = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;
  String? _sendError;
  String? _lastSeenMessageId;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    final userId = _db.auth.currentUser?.id;
    if (message.isEmpty || userId == null || _sending) return;
    if (message.length > 2000) {
      setState(
        () => _sendError = 'Messages must be 2,000 characters or fewer.',
      );
      return;
    }

    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      await _db.from('club_chat_messages').insert({
        'club_id': widget.clubId,
        'sender_id': userId,
        'message': message,
      });
      _messageController.clear();
    } catch (error) {
      if (mounted)
        setState(() => _sendError = 'Could not send message: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text(
          'This message will be permanently deleted for everyone in the club.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _db
          .from('club_chat_messages')
          .delete()
          .eq('id', message['id'].toString());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete message: $error')),
        );
      }
    }
  }

  String _timeLabel(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<Map<String, Map<String, dynamic>>> _loadSenderProfiles(
    List<Map<String, dynamic>> messages,
  ) async {
    final ids = messages
        .map((message) => message['sender_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return {};
    final profiles = await _db
        .from('profiles')
        .select('id, display_name, avatar_url')
        .inFilter('id', ids);
    return {for (final profile in profiles) profile['id'].toString(): profile};
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _db.auth.currentUser?.id;
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _db
                .from('club_chat_messages')
                .stream(primaryKey: ['id'])
                .eq('club_id', widget.clubId)
                .order('created_at', ascending: true),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ErrorView(
                  message:
                      'Could not load club chat. Check that the chat migration has been applied and Realtime is enabled. ${snapshot.error}',
                  onRetry: () async => setState(() {}),
                );
              }
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final messages = snapshot.data!;
              if (messages.isNotEmpty) {
                final newestId = messages.last['id']?.toString();
                if (newestId != null && newestId != _lastSeenMessageId) {
                  _lastSeenMessageId = newestId;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                }
              }
              if (messages.isEmpty) {
                return const _EmptyView(
                  icon: Icons.forum_outlined,
                  title: 'Start the conversation',
                  subtitle: 'Messages sent here are visible to club members.',
                );
              }
              return FutureBuilder<Map<String, Map<String, dynamic>>>(
                future: _loadSenderProfiles(messages),
                builder: (context, profilesSnapshot) {
                  final profiles = profilesSnapshot.data ?? {};
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final senderId = message['sender_id']?.toString() ?? '';
                      final isMine = senderId == currentUserId;
                      final profile = profiles[senderId];
                      final rawName =
                          profile?['display_name']?.toString().trim() ?? '';
                      final senderName = rawName.isEmpty
                          ? (isMine ? 'You' : 'Club member')
                          : rawName;
                      final avatarUrl = profile?['avatar_url']?.toString();
                      final text = message['message']?.toString() ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: isMine
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          children: [
                            if (!isMine) ...[
                              CircleAvatar(
                                radius: 17,
                                backgroundImage:
                                    avatarUrl != null && avatarUrl.isNotEmpty
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: avatarUrl == null || avatarUrl.isEmpty
                                    ? Text(
                                        senderName.isEmpty
                                            ? '?'
                                            : senderName
                                                  .substring(0, 1)
                                                  .toUpperCase(),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 520,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMine
                                        ? theme.colorScheme.primaryContainer
                                        : theme
                                              .colorScheme
                                              .surfaceContainerHighest,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(
                                        isMine ? 16 : 4,
                                      ),
                                      bottomRight: Radius.circular(
                                        isMine ? 4 : 16,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              senderName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.labelMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ),
                                          if (isMine) ...[
                                            const SizedBox(width: 4),
                                            PopupMenuButton<String>(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                minWidth: 120,
                                              ),
                                              tooltip: 'Message actions',
                                              iconSize: 18,
                                              onSelected: (action) {
                                                if (action == 'delete')
                                                  _deleteMessage(message);
                                              },
                                              itemBuilder: (_) => const [
                                                PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text('Delete message'),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(text),
                                      const SizedBox(height: 4),
                                      Align(
                                        alignment: Alignment.bottomRight,
                                        child: Text(
                                          _timeLabel(message['created_at']),
                                          style: theme.textTheme.labelSmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (isMine) const SizedBox(width: 8),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        if (_sendError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Text(
              _sendError!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Message your club…',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Send message',
                  onPressed: _sending ? null : _sendMessage,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// REUSABLE EMPTY AND ERROR STATES
// -----------------------------------------------------------------------------

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyView({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 44),
            const SizedBox(height: 12),
            const Text('Something went wrong'),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PROFILE VIEWER
// -----------------------------------------------------------------------------

class _AnnouncementAuthorRow extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final VoidCallback? onTap;

  const _AnnouncementAuthorRow({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rawName = profile?['display_name']?.toString().trim() ?? '';
    final isPublic = profile?['is_profile_public'] != false;
    final name = !isPublic
        ? 'Private profile'
        : rawName.isEmpty
        ? 'Club member'
        : rawName;
    final authorProfile = profile;
    final String? avatarUrl;
    if (isPublic && authorProfile != null) {
      avatarUrl = authorProfile['avatar_url']?.toString();
    } else {
      avatarUrl = null;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? const Icon(Icons.person_outline, size: 17)
                : null,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Posted by $name',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: onTap == null
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileViewScreen extends StatefulWidget {
  final String userId;

  const ProfileViewScreen({super.key, required this.userId});

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  final SupabaseClient _db = Supabase.instance.client;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _clubs = [];
  bool _loading = true;
  bool _privateOrUnavailable = false;
  String? _error;

  bool get _isOwnProfile => _db.auth.currentUser?.id == widget.userId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
      _privateOrUnavailable = false;
    });

    try {
      final result = await _db
          .from('profiles')
          .select(
            'id, display_name, bio, avatar_url, is_profile_public, show_clubs',
          )
          .eq('id', widget.userId)
          .maybeSingle();

      if (!mounted) return;

      if (result == null) {
        setState(() {
          _privateOrUnavailable = true;
          _loading = false;
        });
        return;
      }

      final profile = Map<String, dynamic>.from(result);
      final isPublic = profile['is_profile_public'] != false;
      if (!isPublic && !_isOwnProfile) {
        setState(() {
          _profile = profile;
          _privateOrUnavailable = true;
          _loading = false;
        });
        return;
      }

      final showClubs = profile['show_clubs'] == true;
      List<Map<String, dynamic>> clubs = [];
      if (showClubs) {
        try {
          final memberships = await _db
              .from('club_members')
              .select('club_id, clubs(id, name, description)')
              .eq('user_id', widget.userId);
          clubs = List<Map<String, dynamic>>.from(
            (memberships as List).map(
              (row) => Map<String, dynamic>.from(row as Map),
            ),
          );
        } catch (_) {
          // A user's club list may be hidden by membership RLS policies.
        }
      }

      if (!mounted) return;
      setState(() {
        _profile = profile;
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

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final name = profile?['display_name']?.toString().trim();
    final displayName = name == null || name.isEmpty ? 'Club member' : name;
    final avatarUrl = profile?['avatar_url']?.toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 44),
                    const SizedBox(height: 12),
                    const Text('Could not load this profile.'),
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loadProfile,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : _privateOrUnavailable
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.lock_outline, size: 56),
                    SizedBox(height: 16),
                    Text(
                      'This profile is private or unavailable.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 52,
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? const Icon(Icons.person_outline, size: 52)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (profile?['bio']?.toString().trim().isNotEmpty ??
                                  false)
                              ? profile!['bio'].toString()
                              : 'No bio added yet.',
                        ),
                      ],
                    ),
                  ),
                ),
                if (profile?['show_clubs'] == true) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Clubs',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_clubs.isEmpty)
                    const Text('No clubs to display.')
                  else
                    for (final membership in _clubs)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.groups_outlined),
                          title: Text(
                            (membership['clubs'] is Map
                                    ? (membership['clubs'] as Map)['name']
                                          ?.toString()
                                    : null) ??
                                'Club',
                          ),
                        ),
                      ),
                ],
              ],
            ),
    );
  }
}
