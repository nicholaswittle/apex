import 'package:apex/theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SwapsTab extends StatelessWidget {
  const SwapsTab({
    super.key,
    required this.supabase,
    required this.selectedDate,
    required this.userName,
    required this.isOwner,
    required this.onClaimShift,
    required this.onAdminAction,
  });

  final SupabaseClient supabase;
  final DateTime selectedDate;
  final String userName;
  final bool isOwner;
  final void Function(String swapId) onClaimShift;
  final void Function(String swapId, String status) onAdminAction;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('swaps')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        final allSwaps = snapshot.data ?? [];
        final selectedDay =
            DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        final availableSwaps = allSwaps.where((swap) {
          final rawDate = swap['shift_date']?.toString();
          if (rawDate == null || rawDate.isEmpty) return false;
          final shiftDate = DateTime.parse(rawDate);
          final swapDay = DateTime(shiftDate.year, shiftDate.month, shiftDate.day);
          return !swapDay.isBefore(selectedDay);
        }).toList();

        if (availableSwaps.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swap_horizontal_circle, size: 64, color: Colors.black26),
                SizedBox(height: 12),
                Text(
                  'No open shifts posted yet.',
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: availableSwaps.length,
          itemBuilder: (context, index) {
            final swap = availableSwaps[index];
            final isMine = swap['original_staff'] == userName;
            final status = swap['status']?.toString() ?? 'Available';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              color: UniversalTheme.lightCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.brown.shade100),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            swap['shift_title']?.toString() ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: UniversalTheme.darkSlate,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            swap['shift_date'] != null
                                ? 'Date: ${swap['shift_date']}'
                                : 'Date unavailable',
                            style: const TextStyle(color: Colors.black54, fontSize: 13),
                          ),
                          Text(
                            'Posted By: ${swap['original_staff']}',
                            style: const TextStyle(
                              color: Colors.brown,
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == 'Available'
                                ? Colors.green.shade100
                                : (status == 'Swapped'
                                    ? Colors.blue.shade100
                                    : Colors.orange.shade100),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: status == 'Available'
                                  ? Colors.green.shade800
                                  : (status == 'Swapped'
                                      ? Colors.blue.shade800
                                      : Colors.orange.shade800),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (isOwner && status == 'Pending Approval') ...[
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
                                onPressed: () => onAdminAction(swap['id'], 'Approved'),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.cancel,
                                  color: UniversalTheme.alertRed,
                                  size: 28,
                                ),
                                onPressed: () => onAdminAction(swap['id'], 'Denied'),
                              ),
                            ],
                          ),
                        ] else if (status == 'Available' && !isMine) ...[
                          ElevatedButton(
                            onPressed: () => onClaimShift(swap['id']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: UniversalTheme.accent,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            ),
                            child: const Text(
                              'Cover Shift',
                              style: TextStyle(color: Colors.white, fontSize: 11),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
