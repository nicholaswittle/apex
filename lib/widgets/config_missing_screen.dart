import 'package:flutter/material.dart';
import 'package:apex/theme.dart';

/// Shown when Supabase env vars were not passed at build time (common on first Vercel deploy).
class ConfigMissingScreen extends StatelessWidget {
  const ConfigMissingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UniversalTheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.settings_suggest, size: 64, color: UniversalTheme.accent),
                const SizedBox(height: 20),
                const Text(
                  'Supabase not configured',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: UniversalTheme.darkSlate,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Set these Vercel environment variables and redeploy:\n\n'
                  '• SUPABASE_URL\n'
                  '• SUPABASE_ANON_KEY',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, height: 1.6),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Also add your Vercel URL to Supabase → Authentication → URL Configuration.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
