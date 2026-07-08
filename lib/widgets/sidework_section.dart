import 'package:apex/theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SideworkSection extends StatelessWidget {
  const SideworkSection({
    super.key,
    required this.supabase,
    required this.selectedDateKey,
    required this.isOwner,
    required this.userName,
    required this.staffNames,
    required this.isLoadingStaff,
    required this.sideWorkController,
    required this.selectedAssignee,
    required this.isAddingSidework,
    required this.onAssigneeChanged,
    required this.onAddTask,
    required this.onToggleCompletion,
  });

  final SupabaseClient supabase;
  final String selectedDateKey;
  final bool isOwner;
  final String userName;
  final List<String> staffNames;
  final bool isLoadingStaff;
  final TextEditingController sideWorkController;
  final String? selectedAssignee;
  final bool isAddingSidework;
  final ValueChanged<String?> onAssigneeChanged;
  final VoidCallback onAddTask;
  final void Function(String taskId, bool completed) onToggleCompletion;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('sidework')
          .stream(primaryKey: ['id'])
          .eq('task_date', selectedDateKey),
      builder: (context, snapshot) {
        final allTasks = snapshot.data ?? [];
        final displayedTasks = isOwner
            ? allTasks
            : allTasks.where((t) => t['assigned_to'] == userName).toList();

        return Card(
          color: UniversalTheme.lightCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.brown.shade100),
          ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.assignment, size: 18, color: UniversalTheme.accent),
                    const SizedBox(width: 6),
                    Text(
                      isOwner
                          ? 'MASTER SIDE WORK (OWNER VIEW)'
                          : 'YOUR SIDE WORK (${userName.toUpperCase()} VIEW)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: UniversalTheme.darkSlate,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                if (displayedTasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'No custom tasks assigned here for today.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  ...displayedTasks.map((item) {
                    final taskId = item['id']?.toString() ?? '';
                    final completed = item['completed'] == true;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5.0),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: (isOwner || item['assigned_to'] == userName)
                                ? () => onToggleCompletion(taskId, !completed)
                                : null,
                            child: Icon(
                              completed ? Icons.check_box : Icons.check_box_outline_blank,
                              size: 18,
                              color: completed ? Colors.green : Colors.brown.shade300,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item['task']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: UniversalTheme.darkSlate,
                                decoration: completed ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          if (isOwner)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.brown.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item['assigned_to']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: UniversalTheme.darkSlate,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                if (isOwner) ...[
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: sideWorkController,
                          decoration: InputDecoration(
                            hintText: 'Add side work task...',
                            hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: UniversalTheme.accent),
                            ),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedAssignee,
                            hint: const Text('Assign', style: TextStyle(fontSize: 12)),
                            style: const TextStyle(
                              fontSize: 12,
                              color: UniversalTheme.darkSlate,
                              fontWeight: FontWeight.bold,
                            ),
                            onChanged: isLoadingStaff ? null : onAssigneeChanged,
                            items: staffNames.map<DropdownMenuItem<String>>((String val) {
                              return DropdownMenuItem<String>(value: val, child: Text(val));
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: isAddingSidework ? null : onAddTask,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: UniversalTheme.darkSlate,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: isAddingSidework
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Add', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
