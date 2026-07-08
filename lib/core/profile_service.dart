import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  static final _client = Supabase.instance.client;

  static Future<({String email, String name, String role, String organizationId})?> loadCurrentProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await _client
        .from('profiles')
        .select('email, name, role, organization_id')
        .eq('id', userId)
        .maybeSingle();

    if (data == null) return null;

    return (
      email: data['email'] as String? ?? _client.auth.currentUser?.email ?? '',
      name: data['name'] as String? ?? 'Team Member',
      role: data['role'] as String? ?? 'Staff',
      organizationId: data['organization_id'] as String? ?? '00000000-0000-0000-0000-000000000001',
    );
  }

  static Future<String?> loadOrganizationId() async {
    final profile = await loadCurrentProfile();
    return profile?.organizationId;
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

  static Future<String> createOrganization(String businessName) async {
    final result = await _client.rpc('apex_create_organization', params: {
      'business_name': businessName.trim(),
    });
    return result?.toString() ?? '';
  }
}
