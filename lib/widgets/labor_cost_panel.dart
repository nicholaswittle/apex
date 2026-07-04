import 'package:flutter/material.dart';

class LaborCostPanel extends StatelessWidget {
  final String? selectedStaff;
  final Map<String, double> staffRates;
  final double shiftHours;

  const LaborCostPanel({
    super.key,
    required this.selectedStaff,
    required this.staffRates,
    required this.shiftHours,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedStaff == null || selectedStaff == 'Open') return const SizedBox.shrink();
    final double rate = staffRates[selectedStaff] ?? 0.0;
    if (rate == 0.0) return const SizedBox.shrink();
    final double cost = rate * shiftHours;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        'Est. \$${cost.toStringAsFixed(2)} (${shiftHours.toStringAsFixed(1)}h × \$$rate/hr)',
        style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600),
      ),
    );
  }
}
