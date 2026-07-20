/// Compile-time configuration for Apex Scheduler.
abstract final class AppConfig {
  static const appName = 'Apex';
  static const bundleId = 'com.wisense.apex';

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const stripePublishableKey =
      String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
  static const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get hasStripe => stripePublishableKey.isNotEmpty;

  /// Owner billing via Stripe — disabled until post-launch monetization.
  static const billingEnabled = false;
}
