import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as picker;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../widgets/playful_page_banner.dart';

import '../admin/admin_panel_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;
  bool _showClubs = true;
  bool _isPublic = true;
  bool _isAdmin = false;
  String? _avatarUrl;
  String? _error;
  List<Map<String, dynamic>> _clubs = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Please log in again.');
      try {
        _isAdmin = await _supabase.rpc('is_myclub_admin') == true;
      } catch (_) {
        _isAdmin = false;
      }

      final profile = await _supabase
          .from('profiles')
          .select(
            'display_name, bio, avatar_url, show_clubs, is_profile_public',
          )
          .eq('id', user.id)
          .maybeSingle();

      _nameController.text =
          profile?['display_name']?.toString() ??
          user.userMetadata?['display_name']?.toString() ??
          user.userMetadata?['full_name']?.toString() ??
          user.userMetadata?['name']?.toString() ??
          user.email?.split('@').first ??
          '';

      _bioController.text = profile?['bio']?.toString() ?? '';
      _avatarUrl = profile?['avatar_url']?.toString();
      _showClubs = profile?['show_clubs'] as bool? ?? true;
      _isPublic = profile?['is_profile_public'] as bool? ?? true;

      final memberships = await _supabase
          .from('club_members')
          .select('club_id, role, clubs(id, name, description)')
          .eq('user_id', user.id)
          .order('joined_at', ascending: false);

      _clubs = List<Map<String, dynamic>>.from(
        (memberships as List).map(
          (row) => Map<String, dynamic>.from(row as Map),
        ),
      );

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Please log in again.');

      final name = _nameController.text.trim();

      await _supabase.from('profiles').upsert({
        'id': user.id,
        'display_name': name,
        'bio': _bioController.text.trim(),
        'avatar_url': _avatarUrl,
        'show_clubs': _showClubs,
        'is_profile_public': _isPublic,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      await _supabase.auth.updateUser(
        UserAttributes(data: {'display_name': name}),
      );

      if (!mounted) return;
      _message('Profile updated successfully.');
    } catch (e) {
      _message('Could not save profile: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final result = await picker.FilePicker.platform.pickFiles(
        type: picker.FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final Uint8List? bytes = file.bytes;

      if (bytes == null) {
        _message('Could not read the selected image.');
        return;
      }

      if (file.size > 5 * 1024 * 1024) {
        _message('Choose an image smaller than 5 MB.');
        return;
      }

      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Please log in again.');

      final extension = file.extension?.toLowerCase() ?? 'jpg';
      const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

      if (!allowedExtensions.contains(extension)) {
        _message('Choose a JPG, PNG, or WebP image.');
        return;
      }

      setState(() => _saving = true);

      final path =
          '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$extension';

      await _supabase.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: false,
              contentType: switch (extension) {
                'png' => 'image/png',
                'webp' => 'image/webp',
                _ => 'image/jpeg',
              },
            ),
          );

      final url = _supabase.storage.from('avatars').getPublicUrl(path);

      await _supabase.from('profiles').upsert({
        'id': user.id,
        'avatar_url': url,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (!mounted) return;

      setState(() => _avatarUrl = url);
      _message('Profile picture updated.');
    } catch (e) {
      _message('Could not upload profile picture: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _avatar({double radius = 48}) {
    final url = _avatarUrl;

    if (url != null && url.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(url));
    }

    final name = _nameController.text.trim();

    return CircleAvatar(
      radius: radius,
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(fontSize: radius * 0.7, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _profileContent() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const PlayfulPageBanner(
          eyebrow: 'Your corner',
          title: 'Your profile, your way',
          subtitle: 'Keep your details and club visibility up to date.',
          icon: Icons.face_retouching_natural_rounded,
          color: Color(0x35A7D7C5),
          accent: MyClubTheme.accentCoral,
          margin: EdgeInsets.zero,
        ),
        Center(
          child: Column(
            children: [
              _avatar(radius: 48),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickAvatar,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Change profile photo'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a display name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bioController,
                maxLength: 500,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  hintText: 'Tell people a little about yourself...',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Public profile'),
          subtitle: const Text(
            'Allow other signed-in users to view your profile.',
          ),
          value: _isPublic,
          onChanged: (value) => setState(() => _isPublic = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show my clubs'),
          subtitle: const Text(
            'Display your club memberships on your profile.',
          ),
          value: _showClubs,
          onChanged: (value) => setState(() => _showClubs = value),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _saving ? null : _saveProfile,
          icon: const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving...' : 'Save profile'),
        ),
        if (_saving) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: 32),
        Text('My Clubs', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (!_showClubs)
          const Text('Your club list is hidden on your profile.')
        else if (_clubs.isEmpty)
          const Text('You have not joined any clubs yet.')
        else
          ..._clubs.map((membership) {
            final club = membership['clubs'];
            final name = club is Map
                ? club['name']?.toString() ?? 'Club'
                : 'Club';
            final role = membership['role']?.toString() ?? 'member';

            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
                title: Text(name),
                subtitle: Text(role[0].toUpperCase() + role.substring(1)),
              ),
            );
          }),
        if (_isAdmin) ...[
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.admin_panel_settings_outlined),
              ),
              title: const Text('Klubb Control Room'),
              subtitle: const Text(
                'Review verification requests, monitor clubs, and message members.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _saving
              ? null
              : () async {
                  await _supabase.auth.signOut();
                },
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProfile,
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
                      'Could not load your profile.',
                      textAlign: TextAlign.center,
                    ),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Center(
                      child: FilledButton(
                        onPressed: _loadProfile,
                        child: const Text('Try again'),
                      ),
                    ),
                  ],
                )
              : _profileContent(),
        ),
      ),
    );
  }
}
