import 'package:supabase_flutter/supabase_flutter.dart';

/// Multi-location support per business.
class LocationService {
  LocationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> loadLocations(String businessId) async {
    final rows = await _client
        .from('locations')
        .select('id, name, address')
        .eq('business_id', businessId)
        .order('created_at');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addLocation({
    required String businessId,
    required String name,
    String? address,
  }) async {
    return _client.from('locations').insert({
      'business_id': businessId,
      'name': name.trim(),
      'address': address?.trim(),
    }).select().single();
  }
}
