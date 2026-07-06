import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/plan_tier.dart';

/// Reads plan tier from the businesses row and exposes freemium gates.
class PlanService {
  PlanService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<PlanTier> loadPlanTier(String businessId) async {
    final row = await _client
        .from('businesses')
        .select('plan_tier')
        .eq('id', businessId)
        .maybeSingle();
    return PlanTierX.fromDb(row?['plan_tier'] as String?);
  }

  bool get isPro => _cachedTier?.isPro ?? false;

  PlanTier? _cachedTier;

  Future<PlanTier> refresh(String businessId) async {
    _cachedTier = await loadPlanTier(businessId);
    return _cachedTier!;
  }

  bool canAddStaff({required int currentStaffCount, required PlanTier tier}) {
    if (tier.isPro) return true;
    return currentStaffCount < PlanLimits.freeStaffCap;
  }

  bool canAddLocation({required int currentLocationCount, required PlanTier tier}) {
    if (tier.isPro) return true;
    return currentLocationCount < PlanLimits.freeLocationCap;
  }

  bool hasAdvancedReporting(PlanTier tier) => tier.isPro;

  Future<void> upgradeToProManual(String businessId) async {
    await _client
        .from('businesses')
        .update({'plan_tier': PlanTier.pro.dbValue})
        .eq('id', businessId);
    _cachedTier = PlanTier.pro;
  }
}
