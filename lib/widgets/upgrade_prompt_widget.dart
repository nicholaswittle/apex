import 'package:flutter/material.dart';
import 'package:apex/features/settings/upgrade_screen.dart';

/// Shown when a free-tier user hits a plan cap.
class UpgradePromptWidget extends StatelessWidget {
  const UpgradePromptWidget({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Not now'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UpgradeScreen()),
            );
          },
          child: const Text('View Plans'),
        ),
      ],
    );
  }
}
