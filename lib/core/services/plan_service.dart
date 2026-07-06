import 'package:supabase_flutter/supabase_flutter.dart';

/// Freemium plan limits and feature gates for Apex Scheduler.
class PlanService {
  PlanService(this._client);

  final SupabaseClient _client;

  static const freeStaffCap = 10;
  static const freeLocationCap = 1;

  Future<PlanSnapshot> loadForBusiness(String businessId) async {
    final row = await _client
        .from('businesses')
        .select('plan_tier, name')
        .eq('id', businessId)
        .maybeSingle();

    final tier = row?['plan_tier'] as String? ?? 'free';
    final staffCount = await _countStaff(businessId);
    final locationCount = await _countLocations(businessId);

    return PlanSnapshot(
      businessId: businessId,
      businessName: row?['name'] as String? ?? 'Your Business',
      planTier: tier,
      staffCount: staffCount,
      locationCount: locationCount,
    );
  }

  Future<int> _countStaff(String businessId) async {
    final rows = await _client
        .from('profiles')
        .select('id')
        .eq('business_id', businessId);
    return (rows as List).length;
  }

  Future<int> _countLocations(String businessId) async {
    final rows = await _client
        .from('locations')
        .select('id')
        .eq('business_id', businessId);
    return (rows as List).length;
  }

  /// Beta manual upgrade path — no live payment in this phase.
  Future<void> upgradeToPro(String businessId) async {
    await _client
        .from('businesses')
        .update({'plan_tier': 'pro'})
        .eq('id', businessId);
  }
}

class PlanSnapshot {
  const PlanSnapshot({
    required this.businessId,
    required this.businessName,
    required this.planTier,
    required this.staffCount,
    required this.locationCount,
  });

  final String businessId;
  final String businessName;
  final String planTier;
  final int staffCount;
  final int locationCount;

  bool get isPro => planTier == 'pro';

  bool get canAddStaff => isPro || staffCount < PlanService.freeStaffCap;

  bool get canAddLocation => isPro || locationCount < PlanService.freeLocationCap;

  String get tierLabel => isPro ? 'Pro' : 'Free';
}
