import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:apex/core/profile_session.dart';

class StaffRepository {
  StaffRepository(this._client);

  final SupabaseClient _client;

  Future<String> _currentOrgId() async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return defaultOrganizationId;
    final mine = await _client
        .from('profiles')
        .select('organization_id')
        .eq('id', myId)
        .maybeSingle();
    return mine?['organization_id'] as String? ?? defaultOrganizationId;
  }

  Future<List<Map<String, dynamic>>> loadStaffNames() async {
    final orgId = await _currentOrgId();
    final data = await _client
        .from('profiles')
        .select('name, role, hourly_rate')
        .eq('organization_id', orgId)
        .order('name');
    return (data as List).cast<Map<String, dynamic>>();
  }
}
