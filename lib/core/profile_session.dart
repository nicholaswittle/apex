import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

/// Legacy default business id for migrated single-tenant data.
const legacyBusinessId = '00000000-0000-0000-0000-000000000001';

class ProfileSession {
  static Future<UserProfile> loadForCurrentUser() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return const UserProfile(id: '', name: 'Team Member', role: 'Staff');
    }
    return loadForUserId(userId);
  }

  static Future<UserProfile> loadForUserId(String userId) async {
    final row = await Supabase.instance.client
        .from('profiles')
        .select('name, role, business_id, email')
        .eq('id', userId)
        .maybeSingle();

    return UserProfile(
      id: userId,
      name: row?['name'] as String? ?? 'Team Member',
      role: row?['role'] as String? ?? 'Staff',
      businessId: row?['business_id'] as String?,
      email: row?['email'] as String?,
    );
  }

  /// Returns true when user has a real business (not null).
  static bool hasCompletedOnboarding(UserProfile profile) =>
      profile.businessId != null && profile.businessId!.isNotEmpty;
}
