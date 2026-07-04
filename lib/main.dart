import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'calendar_page.dart';
import 'auth_page.dart';
import 'core/app_config.dart';
import 'core/firebase_bootstrap.dart';
import 'core/profile_session.dart';

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
    return MaterialApp(
      title: 'Apex',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF9F6F0),
      ),
      home: initialSession != null
          ? _AuthenticatedHome(session: initialSession!)
          : const AuthPage(),
    );
  }
}

class _AuthenticatedHome extends StatelessWidget {
  const _AuthenticatedHome({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({String name, String role, String organizationId})>(
      future: ProfileSession.loadForUserId(session.user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final profile = snapshot.data ??
            (name: 'Team Member', role: 'Staff', organizationId: defaultOrganizationId);
        return CalendarPage(
          userEmail: session.user.email ?? '',
          userName: profile.name,
          userRole: profile.role,
        );
      },
    );
  }
}
