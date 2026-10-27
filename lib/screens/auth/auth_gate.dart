import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/main_navigation_screen.dart';
import 'login_screen.dart';
import 'reset_password_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<AuthState>? _authSubscription;
  final Set<String> _syncingUserIds = <String>{};
  bool _recoveringPassword = false;

  @override
  void initState() {
    super.initState();

    // Covers an existing session as well as Google OAuth's callback session.
    final currentUser = _supabase.auth.currentUser;
    if (currentUser != null) {
      unawaited(_ensureProfile(currentUser));
    }

    _authSubscription = _supabase.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery && mounted) {
        setState(() => _recoveringPassword = true);
      } else if (state.event == AuthChangeEvent.signedOut && mounted) {
        setState(() => _recoveringPassword = false);
      }
      final user = state.session?.user ?? _supabase.auth.currentUser;
      if (user != null) {
        unawaited(_ensureProfile(user));
      }
    });
  }

  /// Ensures every authenticated account has a profile row. Google usually
  /// supplies `full_name` / `name`, not the app's custom `display_name` key.
  /// Existing non-empty display names are deliberately preserved.
  String get _appPlatform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return 'android';
      case TargetPlatform.iOS: return 'ios';
      default: return 'other';
    }
  }

  Future<void> _ensureProfile(User user) async {
    if (!_syncingUserIds.add(user.id)) return;

    try {
      final metadata = user.userMetadata ?? const <String, dynamic>{};
      final metadataName = _firstNonEmpty([
        metadata['display_name'],
        metadata['full_name'],
        metadata['name'],
        metadata['preferred_username'],
      ]);
      final emailName = user.email?.split('@').first.trim();
      final suggestedName = (metadataName?.isNotEmpty ?? false)
          ? metadataName!
          : ((emailName?.isNotEmpty ?? false) ? emailName! : 'MyClub member');
      final avatar = _firstNonEmpty([
        metadata['avatar_url'],
        metadata['picture'],
        metadata['photo_url'],
      ]);

      final existing = await _supabase
          .from('profiles')
          .select('display_name, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('profiles').upsert({
          'id': user.id,
          'display_name': suggestedName,
          if (avatar != null) 'avatar_url': avatar,
          'app_platform': _appPlatform,
          'platform_last_seen_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        return;
      }

      final currentName = existing['display_name']?.toString().trim() ?? '';
      final currentAvatar = existing['avatar_url']?.toString().trim() ?? '';
      final updates = <String, dynamic>{};

      if (currentName.isEmpty) updates['display_name'] = suggestedName;
      if (currentAvatar.isEmpty && avatar != null) {
        updates['avatar_url'] = avatar;
      }

      // Record the platform on each authenticated app launch so admins can
      // target the audience's most recently used MyClub platform.
      updates['app_platform'] = _appPlatform;
      updates['platform_last_seen_at'] = DateTime.now().toUtc().toIso8601String();
      updates['updated_at'] = DateTime.now().toUtc().toIso8601String();
      await _supabase.from('profiles').update(updates).eq('id', user.id);
    } catch (error, stackTrace) {
      // Do not block sign-in if profile syncing fails; keep details available
      // in the debug console so RLS/schema issues can be diagnosed.
      debugPrint('MyClub profile sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _syncingUserIds.remove(user.id);
    }
  }

  String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (_recoveringPassword) return const ResetPasswordScreen();
        final session = _supabase.auth.currentSession;
        if (session != null) return const MainNavigationScreen();
        return const LoginScreen();
      },
    );
  }
}
