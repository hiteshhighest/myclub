import 'package:supabase_flutter/supabase_flutter.dart';

/// Small in-memory cache for session-scoped data shared by the main screens.
/// It deliberately keeps auth and RLS decisions in Supabase; it only avoids
/// repeating the same read during one signed-in app session.
class SupabaseCache {
  SupabaseCache._();

  static final SupabaseCache instance = SupabaseCache._();

  static const _membershipTtl = Duration(minutes: 2);

  final Map<String, _CacheEntry<List<Map<String, dynamic>>>>
  _membershipsByUser = {};
  final Map<String, Future<List<Map<String, dynamic>>>> _inFlightMemberships =
      {};

  bool hasFreshMemberships(String userId) {
    final cached = _membershipsByUser[userId];
    return cached != null && !cached.isExpired;
  }

  Future<List<Map<String, dynamic>>> getMemberships(
    SupabaseClient client,
    String userId, {
    bool forceRefresh = false,
  }) async {
    final cached = _membershipsByUser[userId];
    if (!forceRefresh && cached != null && !cached.isExpired) {
      return cached.value
          .map((membership) => Map<String, dynamic>.from(membership))
          .toList();
    }

    final activeRequest = _inFlightMemberships[userId];
    if (activeRequest != null) return activeRequest;

    final request = _fetchMemberships(client, userId);
    _inFlightMemberships[userId] = request;
    try {
      final memberships = await request;
      _membershipsByUser[userId] = _CacheEntry(memberships);
      return memberships
          .map((membership) => Map<String, dynamic>.from(membership))
          .toList();
    } finally {
      _inFlightMemberships.remove(userId);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMemberships(
    SupabaseClient client,
    String userId,
  ) async {
    final rows = await client
        .from('club_members')
        .select(
          'club_id, role, position, joined_at, clubs(id, name, description, logo_url)',
        )
        .eq('user_id', userId)
        .order('joined_at', ascending: false);

    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  void invalidateMemberships(String userId) {
    _membershipsByUser.remove(userId);
  }

  void clear() {
    _membershipsByUser.clear();
    _inFlightMemberships.clear();
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime createdAt = DateTime.now();

  _CacheEntry(this.value);

  bool get isExpired =>
      DateTime.now().difference(createdAt) > SupabaseCache._membershipTtl;
}
