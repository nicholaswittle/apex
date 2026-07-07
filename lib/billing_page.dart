import 'package:flutter/material.dart';
import 'package:apex/theme.dart';

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
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.schedule, size: 64, color: UniversalTheme.accent),
              SizedBox(height: 16),
              Text(
                'Billing coming soon',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: UniversalTheme.darkSlate,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'All scheduling features are free during the Jigsy\'s pilot. '
                'Stripe billing will be enabled in a future update.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
