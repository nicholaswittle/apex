import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_page.dart';
import 'calendar_page.dart';
import 'core/app_config.dart';
import 'core/firebase_bootstrap.dart';
import 'core/profile_service.dart';
import 'widgets/config_missing_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
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
    runApp(const MyApp());
  } catch (error, stackTrace) {
    debugPrint('Startup failed: $error');
    debugPrint('$stackTrace');
    runApp(_StartupErrorApp(message: error.toString()));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apex',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF9F6F0),
      ),
      home: const _AuthGate(),
    );
  }
}

class _StartupErrorApp extends StatelessWidget {
  final String message;

  const _StartupErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFF9F6F0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Apex failed to start:\n$message',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF991B1B)),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    if (!AppConfig.hasSupabase) return;
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.hasSupabase) {
      return const ConfigMissingScreen();
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return const AuthPage();
    }

    return FutureBuilder(
      future: ProfileService.loadCurrentProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final profile = snapshot.data;
        if (profile == null) {
          return const AuthPage();
        }

        return CalendarPage(
          userEmail: profile.email,
          userName: profile.name,
          userRole: profile.role,
        );
      },
    );
  }
}
