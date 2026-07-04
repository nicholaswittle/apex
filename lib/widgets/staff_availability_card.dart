import 'package:flutter/material.dart';
import 'package:wisense_ui/wisense_ui.dart';

class StaffAvailabilityCard extends StatelessWidget {
  final bool isLoading;
  final List<Map<String, dynamic>> availabilityForDay;
  final bool isOwner;
  final String userName;
  final bool myAvailabilityToday;
  final bool isOnVacation;
  final VoidCallback onToggleAvailability;

  const StaffAvailabilityCard({
    super.key,
    required this.isLoading,
    required this.availabilityForDay,
    required this.isOwner,
    required this.userName,
    required this.myAvailabilityToday,
    required this.isOnVacation,
    required this.onToggleAvailability,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AVAILABILITY',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        if (isLoading)
          const Center(child: WiSenseLoadingIndicator(size: 18))
        else if (isOwner)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: availabilityForDay.map((staff) {
              final isAvail = staff['available'] as bool;
              final onVacation = staff['on_vacation'] as bool? ?? false;
              final chipColor = onVacation
                  ? const Color(0xFFFEF3C7)
                  : (isAvail ? const Color(0xFFD1FAE5) : const Color(0xFFF3F4F6));
              final borderColor = onVacation
                  ? const Color(0xFFD97706)
                  : (isAvail ? const Color(0xFF059669) : Colors.grey.shade300);
              final iconColor = onVacation
                  ? const Color(0xFFD97706)
                  : (isAvail ? const Color(0xFF059669) : Colors.grey.shade400);
              final textColor = onVacation
                  ? const Color(0xFF92400E)
                  : (isAvail ? const Color(0xFF065F46) : Colors.grey);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      onVacation ? Icons.beach_access : Icons.circle,
                      size: onVacation ? 11 : 7,
                      color: iconColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      staff['user_name'] as String,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                    ),
                  ],
                ),
              );
            }).toList(),
          )
        else
          Row(
            children: [
              Icon(
                isOnVacation ? Icons.beach_access : Icons.circle,
                size: isOnVacation ? 14 : 8,
                color: isOnVacation
                    ? const Color(0xFFD97706)
                    : (myAvailabilityToday ? const Color(0xFF059669) : Colors.grey.shade400),
              ),
              const SizedBox(width: 6),
              Text(
                isOnVacation
                    ? 'On approved vacation'
                    : (myAvailabilityToday ? 'Available' : 'Marked unavailable'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isOnVacation
                      ? const Color(0xFF92400E)
                      : (myAvailabilityToday ? const Color(0xFF065F46) : Colors.grey),
                ),
              ),
              const Spacer(),
              if (!isOnVacation)
                Switch(
                  value: myAvailabilityToday,
                  activeThumbColor: const Color(0xFF059669),
                  activeTrackColor: const Color(0xFFD1FAE5),
                  onChanged: (_) => onToggleAvailability(),
                ),
            ],
          ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 8),
      ],
    );
  }
}
