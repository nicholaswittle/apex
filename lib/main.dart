import 'package:apex/auth_page.dart';
import 'package:apex/calendar_page.dart';
import 'package:apex/core/analytics_service.dart';
import 'package:apex/core/app_config.dart';
import 'package:apex/core/error_monitoring.dart';
import 'package:apex/core/firebase_bootstrap.dart';
import 'package:apex/core/profile_service.dart';
import 'package:apex/widgets/config_missing_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> _bootstrapApp() async {
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
    AnalyticsService.instance.logEvent('app_start');
    runApp(const MyApp());
  } catch (error, stackTrace) {
    debugPrint('Startup failed: $error');
    debugPrint('$stackTrace');
    runApp(_StartupErrorApp(message: error.toString()));
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initErrorMonitoring(appRunner: _bootstrapApp);
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
  int _authRevision = 0;

  @override
  void initState() {
    super.initState();
    if (!AppConfig.hasSupabase) return;
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() => _authRevision++);
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
      key: ValueKey('profile-$_authRevision-${session.user.id}'),
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
