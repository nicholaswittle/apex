import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  static final _client = Supabase.instance.client;

  static Future<({String email, String name, String role, String subscriptionStatus})?> loadCurrentProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await _client
        .from('profiles')
        .select('email, name, role, subscription_status')
        .eq('id', userId)
        .maybeSingle();

    if (data == null) return null;

    return (
      email: data['email'] as String? ?? _client.auth.currentUser?.email ?? '',
      name: data['name'] as String? ?? 'Team Member',
      role: data['role'] as String? ?? 'Staff',
      subscriptionStatus: data['subscription_status'] as String? ?? 'inactive',
    );
  }

  static Future<bool> isSubscriptionActive() async {
    final profile = await loadCurrentProfile();
    return profile?.subscriptionStatus == 'active';
  }

  static Future<bool> hasOwnerAccount() async {
    final result = await _client.rpc('apex_has_owner');
    return result == true;
  }
}
