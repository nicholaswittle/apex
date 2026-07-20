import 'package:apex/theme.dart';
import 'package:flutter/material.dart';

class TutorialOverlay extends StatelessWidget {
  const TutorialOverlay({
    super.key,
    required this.visible,
    required this.isOwner,
    required this.userName,
    required this.step,
    required this.onNext,
  });

  final bool visible;
  final bool isOwner;
  final String userName;
  final int step;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final tutorialTitles = isOwner
        ? [
            'Welcome, $userName!',
            '⚡ Optional Branding',
            '⏰ Consistent Time Layout',
            '🗓️ Batch-Publish Week',
          ]
        : [
            'Welcome to Apex!',
            '📋 Check Work & Tasks',
            '🔀 The Swap Board',
            '🌴 Request Time Off',
          ];

    final tutorialTexts = isOwner
        ? [
            "I've tailored this layout completely around your coffee bar template operations. Let's run through the manager features in 10 seconds.",
            "You can now completely leave the 'Shift Title' text field blank. If left empty, the scheduler automatically records a 'General Support Shift' to speed up your routine!",
            'Start and end hours are now completely locked into dropdown wheels. This guarantees perfectly uniform formatting on calendar cards and prevents typos.',
            'Check off multiple target checkboxes at once (like Wed through Sun) to instantaneously stamp identical template operations across the entire week!',
          ]
        : [
            'This is your personalized workspace. Let\'s quickly show you how to manage your shifts, pick up hours, and coordinate with the team.',
            'The main calendar feed shows your scheduled hours. Below each shift card, you will see a master checklist showing any specific custom sidework assigned to you for that shift.',
            'Need to drop a day? Tap \'Post to Swap Board\' on your shift card. Your team can see it instantly under the Swaps tab and tap \'Cover Shift\' to request it.',
            'Need a future weekend off? Jump over to the Time Off tab, choose your target calendar block, and click submit. Your manager will be notified instantly to sign off on it!',
          ];

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.8),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: UniversalTheme.accent, width: 1.5),
            ),
            color: UniversalTheme.lightCard,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: UniversalTheme.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tutorialTitles[step],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: UniversalTheme.darkSlate,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(
                    tutorialTexts[step],
                    style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step ${step + 1} of 4',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: UniversalTheme.darkSlate),
                        onPressed: onNext,
                        child: Text(
                          step < 3 ? 'Next' : 'Let\'s Begin',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
