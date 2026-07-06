import 'package:supabase_flutter/supabase_flutter.dart';

/// Loaded profile + business context for the authenticated user.
class UserProfile {
  const UserProfile({
    required this.userId,
    required this.name,
    required this.role,
    this.businessId,
    this.businessName,
    this.planTier = 'free',
    this.industryType,
  });

  final String userId;
  final String name;
  final String role;
  final String? businessId;
  final String? businessName;
  final String planTier;
  final String? industryType;

  bool get hasBusiness => businessId != null && businessId!.isNotEmpty;
  bool get isOwner => role == 'Owner';
  bool get isPro => planTier == 'pro';
}

class ProfileSession {
  static Future<UserProfile> loadForCurrentUser() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return const UserProfile(
        userId: '',
        name: 'Team Member',
        role: 'Staff',
      );
    }
    return loadForUserId(userId);
  }

  static Future<UserProfile> loadForUserId(String userId) async {
    final client = Supabase.instance.client;
    final row = await client
        .from('profiles')
        .select('name, role, business_id')
        .eq('id', userId)
        .maybeSingle();

    final businessId = row?['business_id'] as String?;
    String? businessName;
    String planTier = 'free';
    String? industryType;

    if (businessId != null) {
      final business = await client
          .from('businesses')
          .select('name, plan_tier, industry_type')
          .eq('id', businessId)
          .maybeSingle();
      businessName = business?['name'] as String?;
      planTier = business?['plan_tier'] as String? ?? 'free';
      industryType = business?['industry_type'] as String?;
    }

    return UserProfile(
      userId: userId,
      name: row?['name'] as String? ?? 'Team Member',
      role: row?['role'] as String? ?? 'Staff',
      businessId: businessId,
      businessName: businessName,
      planTier: planTier,
      industryType: industryType,
    );
  }

  /// Creates a new business and binds the user as owner.
  static Future<String> createBusiness({
    required String userId,
    required String name,
    required String industryType,
  }) async {
    final client = Supabase.instance.client;

    final business = await client.from('businesses').insert({
      'name': name.trim(),
      'industry_type': industryType,
      'owner_id': userId,
      'plan_tier': 'free',
    }).select('id').single();

    final businessId = business['id'] as String;

    await client.from('profiles').update({
      'business_id': businessId,
      'role': 'Owner',
    }).eq('id', userId);

    await client.from('locations').insert({
      'business_id': businessId,
      'name': '$name — Main',
    });

    await client.from('roles').insert([
      {'business_id': businessId, 'name': 'General Staff', 'sort_order': 0},
      {'business_id': businessId, 'name': 'Shift Lead', 'sort_order': 1},
    ]);

    return businessId;
  }
}
