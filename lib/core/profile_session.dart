import 'package:supabase_flutter/supabase_flutter.dart';

/// Apex's first paying venue — every profile before the org/workspace
/// migration belongs here. See supabase/migrations/*_org_workspace_model.sql.
const defaultOrganizationId = '00000000-0000-0000-0000-000000000001';

class ProfileSession {
  static Future<({String name, String role, String organizationId})> loadForCurrentUser() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return (name: 'Team Member', role: 'Staff', organizationId: defaultOrganizationId);
    }
    return loadForUserId(userId);
  }

  static Future<({String name, String role, String organizationId})> loadForUserId(String userId) async {
    final row = await Supabase.instance.client
        .from('profiles')
        .select('name, role, organization_id')
        .eq('id', userId)
        .maybeSingle();

    return (
      name: row?['name'] as String? ?? 'Team Member',
      role: row?['role'] as String? ?? 'Staff',
      organizationId: row?['organization_id'] as String? ?? defaultOrganizationId,
    );
  }
}
