import 'package:apex/core/date_utils.dart';
import 'package:apex/core/notification_service.dart';
import 'package:apex/core/profile_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SwapService {
  SwapService(this._client);

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

  Future<void> postSwap({
    required String shiftTitle,
    required String originalStaff,
    required DateTime selectedDate,
  }) async {
    // Stamp the caller's org so the row satisfies the swaps RLS WITH CHECK
    // (the column default only covers the first venue).
    await _client.from('swaps').insert({
      'shift_title': shiftTitle,
      'original_staff': originalStaff,
      'shift_date': dateKey(selectedDate),
      'day_num': selectedDate.day,
      'status': 'Available',
      'organization_id': await _currentOrgId(),
    });
  }

  Future<void> claimShift({
    required String swapId,
    required String userId,
    required String userName,
  }) async {
    await _client.from('swaps').update({
      'status': 'Pending Approval',
      'claimed_by': userId,
      'claimed_by_name': userName,
    }).eq('id', swapId);

    final owners = await _client.from('profiles').select('id').eq('role', 'Owner');
    for (final owner in (owners as List)) {
      await NotificationService.notifyUser(
        targetUserId: owner['id'] as String,
        title: 'Swap needs approval',
        body: '$userName requested to cover a posted shift.',
      );
    }
  }

  Future<void> claimOpenShift({
    required String shiftId,
    required String userName,
  }) async {
    // Guard against the claim race: only take the shift if it is still 'Open'.
    // Without the staff='Open' predicate two claimers both succeed (last write
    // wins) and one silently loses their shift. select() lets us detect whether
    // our update actually matched a row.
    final claimed = await _client
        .from('shifts')
        .update({'staff': userName})
        .eq('id', shiftId)
        .eq('staff', 'Open')
        .select('id');
    if ((claimed as List).isEmpty) {
      throw StateError('That shift was just claimed by someone else.');
    }
  }

  Future<void> processAdminAction({
    required String swapId,
    required String status,
  }) async {
    if (status == 'Approved') {
      final swap = await _client
          .from('swaps')
          .select('shift_title, original_staff, shift_date, claimed_by_name, claimed_by')
          .eq('id', swapId)
          .single();

      final claimerName = swap['claimed_by_name'] as String?;
      final claimerId = swap['claimed_by'] as String?;
      if (claimerName == null || claimerName.isEmpty) {
        throw StateError('No staff member claimed this swap yet.');
      }

      final matchingShifts = await _client
          .from('shifts')
          .select('id')
          .eq('shift_date', swap['shift_date'])
          .eq('title', swap['shift_title'])
          .eq('staff', swap['original_staff']);

      if (matchingShifts.isNotEmpty) {
        final shiftTableId = matchingShifts.first['id'].toString();
        await _client.from('shifts').update({'staff': claimerName}).eq('id', shiftTableId);
      }
      await _client.from('swaps').update({'status': 'Swapped'}).eq('id', swapId);

      if (claimerId != null) {
        await NotificationService.notifyUser(
          targetUserId: claimerId,
          title: 'Swap approved',
          body: 'Your shift swap for ${swap['shift_title']} was approved.',
        );
      }
    } else {
      await _client.from('swaps').update({
        'status': 'Available',
        'claimed_by': null,
        'claimed_by_name': null,
      }).eq('id', swapId);
    }
  }
}
