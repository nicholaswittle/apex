import 'package:flutter/material.dart';
import 'package:apex/theme.dart';
import 'package:apex/core/app_config.dart';

/// Owner billing — deferred until post-launch. Stripe integration remains in repo for later.
class BillingPage extends StatelessWidget {
  const BillingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UniversalTheme.background,
      appBar: AppBar(
        backgroundColor: UniversalTheme.darkSlate,
        foregroundColor: Colors.white,
        title: const Text(
          'Billing',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.schedule, size: 64, color: UniversalTheme.accent),
              const SizedBox(height: 16),
              const Text(
                'Billing coming soon',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: UniversalTheme.darkSlate,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppConfig.billingEnabled
                    ? 'Subscription billing is not configured yet.'
                    : 'All scheduling features are free during the Jigsy\'s pilot. '
                        'Stripe billing will be enabled in a future update.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
