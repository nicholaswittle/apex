import 'package:apex/core/schedule_constants.dart';
import 'package:apex/core/shift_hours_util.dart';
import 'package:apex/theme.dart';
import 'package:apex/widgets/csv_time_card_exporter.dart';
import 'package:apex/widgets/labor_cost_panel.dart';
import 'package:apex/widgets/org_invite_panel.dart';
import 'package:flutter/material.dart';
import 'package:wisense_ui/wisense_ui.dart';

class AdminPublishPanel extends StatelessWidget {
  const AdminPublishPanel({
    super.key,
    required this.userName,
    required this.isOwner,
    required this.isPublishing,
    required this.isSyncing,
    required this.isLoadingStaff,
    required this.staffNames,
    required this.staffRates,
    required this.shiftTitleController,
    required this.selectedStaff,
    required this.selectedZone,
    required this.startTime,
    required this.endTime,
    required this.isEvent,
    required this.adminTargetWeekAnchor,
    required this.adminSelectedDays,
    required this.dayLabels,
    required this.onStaffChanged,
    required this.onZoneChanged,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
    required this.onEventChanged,
    required this.onDayToggled,
    required this.onWeekChanged,
    required this.onPublish,
    this.onCopyLastWeek,
    this.isCopyingWeek = false,
    this.smartSuggestionsPanel,
  });

  final String userName;
  final bool isOwner;
  final bool isPublishing;
  final bool isSyncing;
  final bool isLoadingStaff;
  final List<String> staffNames;
  final Map<String, double> staffRates;
  final TextEditingController shiftTitleController;
  final String? selectedStaff;
  final String? selectedZone;
  final String startTime;
  final String endTime;
  final bool isEvent;
  final DateTime adminTargetWeekAnchor;
  final Map<String, bool> adminSelectedDays;
  final Map<String, String> dayLabels;
  final ValueChanged<String?> onStaffChanged;
  final ValueChanged<String?> onZoneChanged;
  final ValueChanged<String> onStartTimeChanged;
  final ValueChanged<String> onEndTimeChanged;
  final ValueChanged<bool> onEventChanged;
  final void Function(String dateKey, bool value) onDayToggled;
  final void Function(int weekDelta) onWeekChanged;
  final VoidCallback onPublish;
  final VoidCallback? onCopyLastWeek;
  final bool isCopyingWeek;
  final Widget? smartSuggestionsPanel;

  @override
  Widget build(BuildContext context) {
    if (!isOwner) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person, size: 80, color: UniversalTheme.alertRed),
              const SizedBox(height: 16),
              const Text(
                'ACCESS RESTRICTED',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: UniversalTheme.darkSlate,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hey $userName, this module requires Owner credentials.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const OrgInvitePanel(),
        const SizedBox(height: WiSenseSpacing.base),
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
                    Icon(Icons.add_moderator, color: UniversalTheme.accent),
                    SizedBox(width: 8),
                    Text(
                      'CREATE NEW SHIFT SLOT',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: UniversalTheme.darkSlate,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                const Text(
                  'Shift Title / Role:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: shiftTitleController,
                  decoration: InputDecoration(
                    hintText: 'Leave blank for "General Support Shift"',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: UniversalTheme.accent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Zone / Section:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: selectedZone,
                      isExpanded: true,
                      hint: const Text('No zone (optional)'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('No zone')),
                        ...['Bar', 'Kitchen', 'Floor', 'Support'].map(
                          (z) => DropdownMenuItem<String?>(value: z, child: Text(z)),
                        ),
                      ],
                      onChanged: onZoneChanged,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Assign Slot:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedStaff,
                                isExpanded: true,
                                hint: const Text('Assign Staff'),
                                items: isLoadingStaff
                                    ? []
                                    : <String>['Open', ...staffNames].map((val) {
                                        return DropdownMenuItem<String>(
                                          value: val,
                                          child: Text(val),
                                        );
                                      }).toList(),
                                onChanged: isLoadingStaff ? null : onStaffChanged,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          LaborCostPanel(
                            selectedStaff: selectedStaff,
                            staffRates: staffRates,
                            shiftHours: calculateShiftHours(startTime, endTime),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Start Time:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: startTime,
                                isExpanded: true,
                                items: timeSlots
                                    .map(
                                      (time) => DropdownMenuItem(
                                        value: time,
                                        child: Text(time, style: const TextStyle(fontSize: 13)),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) onStartTimeChanged(val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'End Time:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: endTime,
                                isExpanded: true,
                                items: timeSlots
                                    .map(
                                      (time) => DropdownMenuItem(
                                        value: time,
                                        child: Text(time, style: const TextStyle(fontSize: 13)),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) onEndTimeChanged(val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Target Week:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_left,
                                      size: 18,
                                      color: UniversalTheme.darkSlate,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => onWeekChanged(-1),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_right,
                                      size: 18,
                                      color: UniversalTheme.darkSlate,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => onWeekChanged(1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Week of: ${monthNames[adminTargetWeekAnchor.month - 1]} ${adminTargetWeekAnchor.year}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: UniversalTheme.accent,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.white,
                            ),
                            child: Column(
                              children: adminSelectedDays.keys.map((dateKey) {
                                return CheckboxListTile(
                                  title: Text(
                                    dayLabels[dateKey] ?? dateKey,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: UniversalTheme.darkSlate,
                                    ),
                                  ),
                                  value: adminSelectedDays[dateKey],
                                  dense: true,
                                  activeColor: UniversalTheme.accent,
                                  contentPadding: EdgeInsets.zero,
                                  onChanged: (bool? val) {
                                    onDayToggled(dateKey, val ?? false);
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Checkbox(
                      value: isEvent,
                      activeColor: UniversalTheme.accent,
                      onChanged: (val) => onEventChanged(val ?? false),
                    ),
                    const Text(
                      'Mark as Private Catered Event',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: UniversalTheme.darkSlate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (onCopyLastWeek != null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isCopyingWeek || isPublishing ? null : onCopyLastWeek,
                      icon: isCopyingWeek
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.content_copy, size: 18),
                      label: const Text('Copy Last Week to Target Week'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: UniversalTheme.darkSlate,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (onCopyLastWeek != null) const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isPublishing ? null : onPublish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UniversalTheme.darkSlate,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: isPublishing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Publish Shifts Live',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (smartSuggestionsPanel != null) ...[
          const SizedBox(height: WiSenseSpacing.base),
          smartSuggestionsPanel!,
        ],
        const SizedBox(height: WiSenseSpacing.base),
        CsvTimeCardExporter(
          staffRates: staffRates,
          disabled: isSyncing,
        ),
      ],
    );
  }
}
