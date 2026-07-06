import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessService {
  BusinessService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const industryTypes = [
    ('restaurant', 'Restaurant'),
    ('retail', 'Retail'),
    ('fitness', 'Fitness / Gym'),
    ('healthcare', 'Healthcare / Clinic'),
    ('other', 'Other'),
  ];

  Future<Map<String, dynamic>> createBusiness({
    required String ownerId,
    required String name,
    required String industryType,
  }) async {
    final business = await _client
        .from('businesses')
        .insert({
          'name': name,
          'industry_type': industryType,
          'owner_id': ownerId,
          'plan_tier': 'free',
        })
        .select()
        .single();

    final businessId = business['id'] as String;

    await _client.from('profiles').update({
      'business_id': businessId,
      'role': 'Owner',
    }).eq('id', ownerId);

    await _client.from('locations').insert({
      'business_id': businessId,
      'name': 'Main Location',
    });

    for (final (index, role) in ['Team Member', 'Supervisor', 'Manager'].asMap().entries) {
      await _client.from('business_roles').insert({
        'business_id': businessId,
        'name': role,
        'sort_order': index,
      });
    }

    return business;
  }

  Future<Map<String, dynamic>?> loadBusiness(String businessId) async {
    return _client
        .from('businesses')
        .select('id, name, industry_type, owner_id, plan_tier, created_at')
        .eq('id', businessId)
        .maybeSingle();
  }

  Future<int> countStaff(String businessId) async {
    final rows = await _client
        .from('profiles')
        .select('id')
        .eq('business_id', businessId);
    return (rows as List).length;
  }

  Future<List<Map<String, dynamic>>> upcomingShifts(String businessId, {int limit = 5}) async {
    final today = DateTime.now().day;
    final rows = await _client
        .from('shifts')
        .select('id, title, staff, day_num, zone')
        .eq('business_id', businessId)
        .gte('day_num', today)
        .order('day_num')
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>();
  }
}
