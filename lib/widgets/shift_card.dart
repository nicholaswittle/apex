import 'package:apex/core/zone_colors.dart';
import 'package:apex/theme.dart';
import 'package:flutter/material.dart';

class ShiftCard extends StatelessWidget {
  const ShiftCard({
    super.key,
    required this.shiftId,
    required this.title,
    required this.scheduled,
    this.notes,
    this.zone,
    this.isMyShift = false,
    this.isClockedIn = false,
    this.isOwner = false,
    this.isOnVacation = false,
    required this.onSwapPressed,
    this.onClaimPressed,
    this.onDeletePressed,
    this.onClockIn,
    this.onClockOut,
  });

  final String shiftId;
  final String title;
  final String scheduled;
  final String? notes;
  final String? zone;
  final bool isMyShift;
  final bool isClockedIn;
  final bool isOwner;
  final bool isOnVacation;
  final VoidCallback onSwapPressed;
  final VoidCallback? onClaimPressed;
  final VoidCallback? onDeletePressed;
  final VoidCallback? onClockIn;
  final VoidCallback? onClockOut;

  @override
  Widget build(BuildContext context) {
    final isUnassigned = scheduled == 'Open';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: isUnassigned ? const Color(0xFFF9F6F0) : UniversalTheme.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isUnassigned
              ? UniversalTheme.accent.withValues(alpha: 0.4)
              : Colors.brown.shade100,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: UniversalTheme.darkSlate,
                        ),
                      ),
                      if (zone != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: zoneColor(zone!).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: zoneColor(zone!).withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            zone!.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: zoneColor(zone!),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            isUnassigned
                                ? Icons.supervised_user_circle_outlined
                                : Icons.account_circle,
                            size: 14,
                            color: isUnassigned ? UniversalTheme.accent : Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isUnassigned
                                ? 'OPEN SLOT (UNASSIGNED)'
                                : 'Assigned to: $scheduled',
                            style: TextStyle(
                              color: isUnassigned ? UniversalTheme.accent : Colors.black54,
                              fontSize: 12,
                              fontWeight: isUnassigned ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      if (notes != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          notes!,
                          style: const TextStyle(
                            color: Colors.brown,
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    isUnassigned
                        ? ElevatedButton(
                            onPressed: isOnVacation ? null : onClaimPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isOnVacation ? Colors.grey.shade300 : Colors.green,
                            ),
                            child: Text(
                              isOnVacation ? 'On Vacation' : 'Claim Shift',
                              style: TextStyle(
                                color: isOnVacation ? Colors.grey : Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Scheduled',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
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
            if (!isUnassigned) ...[
              const Divider(height: 20),
              if (isMyShift) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isClockedIn ? onClockOut : onClockIn,
                    icon: Icon(
                      isClockedIn ? Icons.timer_off_outlined : Icons.timer_outlined,
                      size: 16,
                      color: isClockedIn
                          ? UniversalTheme.alertRed
                          : const Color(0xFF059669),
                    ),
                    label: Text(
                      isClockedIn ? 'Clock Out' : 'Clock In',
                      style: TextStyle(
                        fontSize: 12,
                        color: isClockedIn
                            ? UniversalTheme.alertRed
                            : const Color(0xFF059669),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isClockedIn
                            ? UniversalTheme.alertRed
                            : const Color(0xFF059669),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              OutlinedButton.icon(
                onPressed: onSwapPressed,
                icon: const Icon(Icons.swap_horiz, size: 16, color: UniversalTheme.darkSlate),
                label: const Text(
                  'Post to Swap Board',
                  style: TextStyle(fontSize: 11, color: UniversalTheme.darkSlate),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: UniversalTheme.darkSlate),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
