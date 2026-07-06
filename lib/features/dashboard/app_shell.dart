import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:apex/auth_page.dart';
import 'package:apex/calendar_page.dart';
import 'package:apex/core/profile_session.dart';
import 'package:apex/features/onboarding/business_setup_screen.dart';

/// Post-auth router: onboarding if no business, otherwise main schedule shell.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return const AuthPage();
    }

    return FutureBuilder(
      future: ProfileSession.loadForUserId(session.user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final profile = snapshot.data!;
        if (profile.needsBusinessSetup) {
          return BusinessSetupScreen(userId: profile.id);
        }

        return CalendarPage(
          userEmail: session.user.email ?? profile.email ?? '',
          userName: profile.name,
          userRole: profile.role,
          businessId: profile.businessId!,
        );
      },
    );
  }
}
