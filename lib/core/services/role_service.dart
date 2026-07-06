import 'package:supabase_flutter/supabase_flutter.dart';

/// Configurable position/role names per business.
class RoleService {
  RoleService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<String>> loadRoleNames(String businessId) async {
    final rows = await _client
        .from('business_roles')
        .select('name')
        .eq('business_id', businessId)
        .order('sort_order');
    return (rows as List).map((r) => r['name'] as String).toList();
  }

  Future<void> addRole(String businessId, String name) async {
    final existing = await loadRoleNames(businessId);
    await _client.from('business_roles').insert({
      'business_id': businessId,
      'name': name.trim(),
      'sort_order': existing.length,
    });
  }

  Future<void> removeRole(String businessId, String name) async {
    await _client
        .from('business_roles')
        .delete()
        .eq('business_id', businessId)
        .eq('name', name);
  }
}
