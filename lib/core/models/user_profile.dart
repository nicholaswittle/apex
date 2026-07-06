/// Full authenticated user profile with business context.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.role,
    this.businessId,
    this.email,
  });

  final String id;
  final String name;
  final String role;
  final String? businessId;
  final String? email;

  bool get isOwner => role == 'Owner';
  bool get needsBusinessSetup => businessId == null || businessId!.isEmpty;
}
