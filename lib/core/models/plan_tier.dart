/// Freemium plan limits for Apex Scheduler.
abstract final class PlanLimits {
  static const int freeStaffCap = 10;
  static const int freeLocationCap = 1;
}

enum PlanTier { free, pro }

extension PlanTierX on PlanTier {
  String get dbValue => name;

  bool get isPro => this == PlanTier.pro;

  static PlanTier fromDb(String? value) =>
      value == 'pro' ? PlanTier.pro : PlanTier.free;
}
