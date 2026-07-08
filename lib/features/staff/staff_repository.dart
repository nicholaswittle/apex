import 'package:supabase_flutter/supabase_flutter.dart';

class StaffRepository {
  StaffRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> loadStaffNames() async {
    final data =
        await _client.from('profiles').select('name, role, hourly_rate').order('name');
    return (data as List).cast<Map<String, dynamic>>();
  }
}
