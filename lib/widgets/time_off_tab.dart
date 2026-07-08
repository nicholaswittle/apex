import 'package:apex/theme.dart';
import 'package:flutter/material.dart';

class TimeOffTab extends StatelessWidget {
  const TimeOffTab({
    super.key,
    required this.requests,
    required this.isOwner,
    required this.isSyncing,
    required this.temporarySelectedRange,
    required this.timeOffReasonController,
    required this.onSingleDayPick,
    required this.onMultiDayPick,
    required this.onSubmit,
    required this.onUpdateStatus,
    required this.onDelete,
  });

  final List<Map<String, dynamic>> requests;
  final bool isOwner;
  final bool isSyncing;
  final DateTimeRange? temporarySelectedRange;
  final TextEditingController timeOffReasonController;
  final VoidCallback onSingleDayPick;
  final VoidCallback onMultiDayPick;
  final VoidCallback onSubmit;
  final void Function(String id, String status) onUpdateStatus;
  final void Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: UniversalTheme.lightCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.brown.shade100),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.edit_calendar, color: UniversalTheme.accent),
                    SizedBox(width: 8),
                    Text(
                      'SUBMIT TIME OFF REQUEST',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: UniversalTheme.darkSlate,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                const Text(
                  'Step 1: Choose Your Dates:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onSingleDayPick,
                        icon: const Icon(Icons.looks_one, size: 16),
                        label: const Text(
                          'Single Day',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: UniversalTheme.darkSlate,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onMultiDayPick,
                        icon: const Icon(Icons.date_range, size: 16),
                        label: const Text(
                          'Multi-Day Block',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: UniversalTheme.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.white,
                  ),
                  child: Text(
                    temporarySelectedRange == null
                        ? 'No dates selected yet'
                        : temporarySelectedRange!.start == temporarySelectedRange!.end
                            ? 'Selected Single Day: ${temporarySelectedRange!.start.month}/${temporarySelectedRange!.start.day}/${temporarySelectedRange!.start.year}'
                            : 'Selected Range: ${temporarySelectedRange!.start.month}/${temporarySelectedRange!.start.day} ➡️ ${temporarySelectedRange!.end.month}/${temporarySelectedRange!.end.day}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: temporarySelectedRange == null
                          ? Colors.black38
                          : UniversalTheme.darkSlate,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Step 2: Reason / Notes (Optional):',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: timeOffReasonController,
                  decoration: InputDecoration(
                    hintText: 'Add a short description...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: UniversalTheme.accent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSyncing ? null : onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UniversalTheme.darkSlate,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: isSyncing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Submit Request to Management',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'REQUEST HISTORY & STATUS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        _buildRequestHistory(context),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, Map<String, dynamic> req) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete time off request?'),
        content: Text(
          '${req['user_name']}: ${req['start_date']} to ${req['end_date']}. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: UniversalTheme.alertRed)),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete(req['id'] as String);
  }

  Widget _buildRequestHistory(BuildContext context) {
    if (requests.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0),
        child: Center(
          child: Text(
            'No active vacation request history found.',
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return Column(
      children: requests.map((req) {
        Color statusColor = Colors.orange;
        if (req['status'] == 'Approved') statusColor = Colors.green;
        if (req['status'] == 'Denied') statusColor = UniversalTheme.alertRed;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Text(
              '${req['start_date']} to ${req['end_date']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Staff: ${req['user_name']}',
                  style: const TextStyle(
                    color: Colors.brown,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                Text('Reason: ${req['reason']}', style: const TextStyle(fontSize: 12)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isOwner && req['status'] == 'Pending') ...[
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () => onUpdateStatus(req['id'], 'Approved'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: UniversalTheme.alertRed),
                    onPressed: () => onUpdateStatus(req['id'], 'Denied'),
                  ),
                ] else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      req['status'] ?? 'Pending',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                if (isOwner)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                    tooltip: 'Delete request',
                    onPressed: () => _confirmDelete(context, req),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
