import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  static final _client = Supabase.instance.client;

  static Future<({String email, String name, String role})?> loadCurrentProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await _client
        .from('profiles')
        .select('email, name, role')
        .eq('id', userId)
        .maybeSingle();

    if (data == null) return null;

    return (
      email: data['email'] as String? ?? _client.auth.currentUser?.email ?? '',
      name: data['name'] as String? ?? 'Team Member',
      role: data['role'] as String? ?? 'Staff',
    );
  }

  static Future<bool> hasOwnerAccount() async {
    final result = await _client.rpc('apex_has_owner');
    return result == true;
  }

  static Future<void> redeemInvite(String inviteCode) async {
    await _client.rpc('apex_redeem_invite', params: {
      'invite_code': inviteCode.trim().toUpperCase(),
    });
  }
}
