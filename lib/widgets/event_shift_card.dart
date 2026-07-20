import 'package:apex/theme.dart';
import 'package:flutter/material.dart';

class EventShiftCard extends StatelessWidget {
  const EventShiftCard({
    super.key,
    required this.shiftId,
    required this.tag,
    required this.title,
    required this.time,
    required this.isOwner,
    required this.isOnVacation,
    required this.onClaimPressed,
    required this.onDeletePressed,
  });

  final String shiftId;
  final String tag;
  final String title;
  final String time;
  final bool isOwner;
  final bool isOnVacation;
  final VoidCallback onClaimPressed;
  final VoidCallback onDeletePressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: const Color(0xFFFFF9E6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: UniversalTheme.accent),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tag,
                    style: const TextStyle(
                      color: UniversalTheme.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: UniversalTheme.darkSlate,
                    ),
                  ),
                  Text(
                    'Time: $time',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: isOnVacation ? null : onClaimPressed,
                  style: ElevatedButton.styleFrom(backgroundColor: UniversalTheme.accent),
                  child: Text(
                    isOnVacation ? 'On Vacation' : 'Sign Up',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                if (isOwner) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: UniversalTheme.alertRed,
                      size: 20,
                    ),
                    onPressed: onDeletePressed,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
