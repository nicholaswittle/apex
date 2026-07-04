import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'calendar_page.dart';
import 'auth_page.dart';
import 'core/app_config.dart';
import 'core/firebase_bootstrap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.hasStripe) {
    Stripe.publishableKey = AppConfig.stripePublishableKey;
  }

  if (AppConfig.hasSupabase) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  } else {
    debugPrint(
      'SUPABASE_URL / SUPABASE_ANON_KEY missing — pass --dart-define at build time.',
    );
  }

  await FirebaseBootstrap.initialize();

  final session = AppConfig.hasSupabase
      ? Supabase.instance.client.auth.currentSession
      : null;

  runApp(MyApp(initialSession: session));
}

class MyApp extends StatelessWidget {
  final Session? initialSession;
  const MyApp({super.key, this.initialSession});

  @override
  Widget build(BuildContext context) {
    String email = '';
    String name = 'Team Member';
    String role = 'Staff';

    if (initialSession != null) {
      email = initialSession!.user.email ?? '';
      final meta = initialSession!.user.userMetadata;
      if (meta != null) {
        name = meta['userName'] ?? meta['name'] ?? meta['display_name'] ?? 'Team Member';
        role = meta['userRole'] ?? meta['role'] ?? 'Staff';
      }
    }

    return MaterialApp(
      title: 'Apex',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF9F6F0), // Matches your light card background style
      ),
      home: initialSession != null
          ? CalendarPage(
              userEmail: email,
              userName: name,
              userRole: role,
            )
          : const AuthPage(),
    );
  }
}