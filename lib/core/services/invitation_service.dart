import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Generates and manages staff invite codes for a business.
class InvitationService {
  InvitationService(this._client);

  final SupabaseClient _client;
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _generateCode({int length = 6}) {
    final rand = Random.secure();
    return List.generate(length, (_) => _chars[rand.nextInt(_chars.length)]).join();
  }

  Future<Map<String, dynamic>> createInvite({
    required String businessId,
    int maxUses = 50,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final code = _generateCode();
    final row = await _client.from('invitations').insert({
      'business_id': businessId,
      'invite_code': code,
      'created_by': userId,
      'max_uses': maxUses,
    }).select().single();
    return row;
  }

  Future<List<Map<String, dynamic>>> listInvites(String businessId) async {
    final rows = await _client
        .from('invitations')
        .select()
        .eq('business_id', businessId)
        .order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Join a business using an invite code during staff signup.
  Future<String?> joinWithCode(String inviteCode, String userId) async {
    final invite = await _client
        .from('invitations')
        .select('id, business_id, max_uses, use_count')
        .eq('invite_code', inviteCode.trim().toUpperCase())
        .maybeSingle();

    if (invite == null) return null;

    final businessId = invite['business_id'] as String;
    final maxUses = invite['max_uses'] as int?;
    final useCount = invite['use_count'] as int? ?? 0;
    if (maxUses != null && useCount >= maxUses) return null;

    await _client.from('profiles').update({
      'business_id': businessId,
      'role': 'Staff',
    }).eq('id', userId);

    await _client.from('invitations').update({
      'use_count': useCount + 1,
    }).eq('id', invite['id']);

    return businessId;
  }
}
