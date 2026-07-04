import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileSession {
  static Future<({String name, String role})> loadForCurrentUser() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return (name: 'Team Member', role: 'Staff');
    }

    final row = await Supabase.instance.client
        .from('profiles')
        .select('name, role')
        .eq('id', userId)
        .maybeSingle();

    return (
      name: row?['name'] as String? ?? 'Team Member',
      role: row?['role'] as String? ?? 'Staff',
    );
  }

  static Future<({String name, String role})> loadForUserId(String userId) async {
    final row = await Supabase.instance.client
        .from('profiles')
        .select('name, role')
        .eq('id', userId)
        .maybeSingle();

    return (
      name: row?['name'] as String? ?? 'Team Member',
      role: row?['role'] as String? ?? 'Staff',
    );
  }
}
