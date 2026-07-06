import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Staff invitation codes scoped to a business.
class InviteService {
  InviteService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _generateCode() {
    final random = Random.secure();
    return List.generate(6, (_) => _chars[random.nextInt(_chars.length)]).join();
  }

  Future<Map<String, dynamic>> createInvite({
    required String businessId,
    required String createdBy,
  }) async {
    final code = _generateCode();
    return _client.from('invitations').insert({
      'business_id': businessId,
      'code': code,
      'created_by': createdBy,
    }).select().single();
  }

  Future<List<Map<String, dynamic>>> listInvites(String businessId) async {
    final rows = await _client
        .from('invitations')
        .select('id, code, use_count, max_uses, expires_at, created_at')
        .eq('business_id', businessId)
        .order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> findByCode(String code) async {
    return _client
        .from('invitations')
        .select('id, business_id, code, use_count, max_uses, expires_at')
        .eq('code', code.trim().toUpperCase())
        .maybeSingle();
  }

  Future<void> joinBusinessWithCode({
    required String userId,
    required String code,
  }) async {
    final invite = await findByCode(code);
    if (invite == null) {
      throw Exception('Invalid invite code.');
    }

    final expiresAt = invite['expires_at'] as String?;
    if (expiresAt != null && DateTime.parse(expiresAt).isBefore(DateTime.now())) {
      throw Exception('This invite code has expired.');
    }

    final maxUses = invite['max_uses'] as int?;
    final useCount = invite['use_count'] as int? ?? 0;
    if (maxUses != null && useCount >= maxUses) {
      throw Exception('This invite code has reached its use limit.');
    }

    final businessId = invite['business_id'] as String;

    await _client.from('profiles').update({
      'business_id': businessId,
      'role': 'Staff',
    }).eq('id', userId);

    await _client.from('invitations').update({
      'use_count': useCount + 1,
    }).eq('id', invite['id']);
  }

  Future<void> revokeInvite(String inviteId) async {
    await _client.from('invitations').delete().eq('id', inviteId);
  }
}
