/// Compile-time configuration for Apex Scheduler.
abstract final class AppConfig {
  static const appName = 'Apex Scheduler';
  static const bundleId = 'com.wisense.apex';

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const stripePublishableKey =
      String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get hasStripe => stripePublishableKey.isNotEmpty;
}
