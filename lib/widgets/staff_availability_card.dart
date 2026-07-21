import 'package:flutter/material.dart';
import 'package:wisense_ui/wisense_ui.dart';

class StaffAvailabilityCard extends StatelessWidget {
  final bool isLoading;
  final List<Map<String, dynamic>> availabilityForDay;
  final bool isOwner;
  final String userName;
  final bool myAvailabilityToday;
  final bool isOnVacation;
  final bool isBookedToday;
  final VoidCallback onToggleAvailability;

  const StaffAvailabilityCard({
    super.key,
    required this.isLoading,
    required this.availabilityForDay,
    required this.isOwner,
    required this.userName,
    required this.myAvailabilityToday,
    required this.isOnVacation,
    required this.isBookedToday,
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
              final style = _styleFor(_resolveStatus(
                onVacation: staff['on_vacation'] as bool? ?? false,
                booked: staff['booked'] as bool? ?? false,
                available: staff['available'] as bool,
              ));
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: style.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: style.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(style.glyph, size: style.chipIconSize, color: style.icon),
                    const SizedBox(width: 5),
                    Text(
                      staff['user_name'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: style.text,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          )
        else
          Builder(builder: (context) {
            final style = _styleFor(_resolveStatus(
              onVacation: isOnVacation,
              booked: isBookedToday,
              available: myAvailabilityToday,
            ));
            return Row(
            children: [
              Icon(style.glyph, size: style.rowIconSize, color: style.icon),
              const SizedBox(width: 6),
              Text(
                style.selfLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: style.text,
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
          );
          }),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 8),
      ],
    );
  }
}

enum _StaffStatus { onVacation, booked, available, unavailable }

/// Vacation outranks booked, which outranks the self-declared availability flag:
/// an approved leave is authoritative, and an existing assignment is a fact.
_StaffStatus _resolveStatus({
  required bool onVacation,
  required bool booked,
  required bool available,
}) {
  if (onVacation) return _StaffStatus.onVacation;
  if (booked) return _StaffStatus.booked;
  return available ? _StaffStatus.available : _StaffStatus.unavailable;
}

typedef _StatusStyle = ({
  Color background,
  Color border,
  Color icon,
  Color text,
  IconData glyph,
  double chipIconSize,
  double rowIconSize,
  String selfLabel,
});

_StatusStyle _styleFor(_StaffStatus status) => switch (status) {
      _StaffStatus.onVacation => (
          background: const Color(0xFFFEF3C7),
          border: const Color(0xFFD97706),
          icon: const Color(0xFFD97706),
          text: const Color(0xFF92400E),
          glyph: Icons.beach_access,
          chipIconSize: 11,
          rowIconSize: 14,
          selfLabel: 'On approved vacation',
        ),
      _StaffStatus.booked => (
          background: const Color(0xFFDBEAFE),
          border: const Color(0xFF2563EB),
          icon: const Color(0xFF2563EB),
          text: const Color(0xFF1E3A8A),
          glyph: Icons.work_history,
          chipIconSize: 11,
          rowIconSize: 14,
          selfLabel: 'Booked — you have a shift',
        ),
      _StaffStatus.available => (
          background: const Color(0xFFD1FAE5),
          border: const Color(0xFF059669),
          icon: const Color(0xFF059669),
          text: const Color(0xFF065F46),
          glyph: Icons.circle,
          chipIconSize: 7,
          rowIconSize: 8,
          selfLabel: 'Available',
        ),
      _StaffStatus.unavailable => (
          background: const Color(0xFFF3F4F6),
          border: const Color(0xFFD1D5DB),
          icon: const Color(0xFF9CA3AF),
          text: Colors.grey,
          glyph: Icons.circle,
          chipIconSize: 7,
          rowIconSize: 8,
          selfLabel: 'Marked unavailable',
        ),
    };
