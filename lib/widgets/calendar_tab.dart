import 'package:apex/core/date_utils.dart';
import 'package:apex/theme.dart';
import 'package:apex/widgets/event_shift_card.dart';
import 'package:apex/widgets/shift_card.dart';
import 'package:apex/widgets/shift_calendar_grid.dart';
import 'package:apex/widgets/sidework_section.dart';
import 'package:apex/widgets/staff_availability_card.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CalendarTab extends StatelessWidget {
  const CalendarTab({
    super.key,
    required this.supabase,
    required this.selectedDate,
    required this.isFullMonthView,
    required this.showAckBanner,
    required this.isOwner,
    required this.userName,
    required this.isLoadingAvailability,
    required this.availabilityForDay,
    required this.myAvailabilityToday,
    required this.isOnVacation,
    required this.allRequests,
    required this.clockedInEntries,
    required this.staffNames,
    required this.isLoadingStaff,
    required this.sideWorkController,
    required this.selectedAssignee,
    required this.isAddingSidework,
    required this.onToggleMonthView,
    required this.onDateSelected,
    required this.onChangeMonth,
    required this.onChangeWeek,
    required this.onAckBannerDismiss,
    required this.onToggleAvailability,
    required this.onAssigneeChanged,
    required this.onAddSidework,
    required this.onToggleSideworkCompletion,
    required this.onPostSwap,
    required this.onClaimOpenShift,
    required this.onDeleteShift,
    required this.onClockIn,
    required this.onClockOut,
  });

  final SupabaseClient supabase;
  final DateTime selectedDate;
  final bool isFullMonthView;
  final bool showAckBanner;
  final bool isOwner;
  final String userName;
  final bool isLoadingAvailability;
  final List<Map<String, dynamic>> availabilityForDay;
  final bool myAvailabilityToday;
  final bool isOnVacation;
  final List<dynamic> allRequests;
  final Map<String, String> clockedInEntries;
  final List<String> staffNames;
  final bool isLoadingStaff;
  final TextEditingController sideWorkController;
  final String? selectedAssignee;
  final bool isAddingSidework;
  final VoidCallback onToggleMonthView;
  final ValueChanged<DateTime> onDateSelected;
  final void Function(int delta) onChangeMonth;
  final void Function(int delta) onChangeWeek;
  final VoidCallback onAckBannerDismiss;
  final VoidCallback onToggleAvailability;
  final ValueChanged<String?> onAssigneeChanged;
  final VoidCallback onAddSidework;
  final void Function(String taskId, bool completed) onToggleSideworkCompletion;
  final void Function(String title, String staff) onPostSwap;
  final void Function(String shiftId, String title) onClaimOpenShift;
  final void Function(String shiftId, String title) onDeleteShift;
  final void Function(String shiftId) onClockIn;
  final void Function(String shiftId) onClockOut;

  String get _selectedDateKey => dateKey(selectedDate);

  @override
  Widget build(BuildContext context) {
    return ShiftCalendarGrid(
      selectedDate: selectedDate,
      isFullMonthView: isFullMonthView,
      onToggleMonthView: onToggleMonthView,
      onDateSelected: onDateSelected,
      onChangeMonth: onChangeMonth,
      onChangeWeek: onChangeWeek,
      body: Column(
        children: [
          if (showAckBanner)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: UniversalTheme.alertRed,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'New Schedule is Out! Sign off on your hours.',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: onAckBannerDismiss,
                    style: ElevatedButton.styleFrom(backgroundColor: UniversalTheme.darkSlate),
                    child: const Text(
                      'Acknowledge',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                StaffAvailabilityCard(
                  isLoading: isLoadingAvailability,
                  availabilityForDay: availabilityForDay,
                  isOwner: isOwner,
                  userName: userName,
                  myAvailabilityToday: myAvailabilityToday,
                  isOnVacation: isOnVacation,
                  onToggleAvailability: onToggleAvailability,
                ),
                SideworkSection(
                  supabase: supabase,
                  selectedDateKey: _selectedDateKey,
                  isOwner: isOwner,
                  userName: userName,
                  staffNames: staffNames,
                  isLoadingStaff: isLoadingStaff,
                  sideWorkController: sideWorkController,
                  selectedAssignee: selectedAssignee,
                  isAddingSidework: isAddingSidework,
                  onAssigneeChanged: onAssigneeChanged,
                  onAddTask: onAddSidework,
                  onToggleCompletion: onToggleSideworkCompletion,
                ),
                const SizedBox(height: 6),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: supabase
                      .from('shifts')
                      .stream(primaryKey: ['id'])
                      .eq('shift_date', _selectedDateKey),
                  builder: (context, snapshot) {
                    final currentShifts = snapshot.data ?? [];
                    final dateIsoStr = _selectedDateKey;

                    final approvedLeaves = allRequests.where((req) {
                      if (req['status'] != 'Approved') return false;
                      return dateIsoStr == req['start_date'] ||
                          dateIsoStr == req['end_date'] ||
                          (DateTime.parse(dateIsoStr).isAfter(DateTime.parse(req['start_date'])) &&
                              DateTime.parse(dateIsoStr).isBefore(DateTime.parse(req['end_date'])));
                    }).toList();

                    if (currentShifts.isEmpty && approvedLeaves.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 40.0),
                        child: Column(
                          children: [
                            Icon(Icons.calendar_today, size: 48, color: Colors.brown.shade200),
                            const SizedBox(height: 8),
                            const Text(
                              'No shifts or leaves logged for today!',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: [
                        ...approvedLeaves.map(
                          (leave) => Card(
                            color: Colors.blue.shade50,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: Colors.blue.shade200),
                            ),
                            child: ListTile(
                              leading: const Icon(Icons.flight_takeoff, color: Colors.blue),
                              title: Text(
                                '${leave['user_name']} ON VACATION',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                'Status: Authorized Leave Block | ${leave['reason']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                        ...currentShifts.map((shift) {
                          final id = shift['id']?.toString() ?? '';
                          final title = shift['title']?.toString() ?? '';
                          final staff = shift['staff']?.toString() ?? 'Open';
                          if (shift['is_event'] == true) {
                            return EventShiftCard(
                              shiftId: id,
                              tag: title,
                              title: staff,
                              time: shift['notes']?.toString() ?? 'See schedule',
                              isOwner: isOwner,
                              isOnVacation: isOnVacation,
                              onClaimPressed: () => onClaimOpenShift(id, title),
                              onDeletePressed: () => onDeleteShift(id, title),
                            );
                          }
                          return ShiftCard(
                            shiftId: id,
                            title: title,
                            scheduled: staff,
                            notes: shift['notes']?.toString(),
                            zone: shift['zone']?.toString(),
                            isMyShift: !isOwner && staff == userName,
                            isClockedIn: clockedInEntries.containsKey(id),
                            isOwner: isOwner,
                            isOnVacation: isOnVacation,
                            onSwapPressed: () => onPostSwap(title, staff),
                            onClaimPressed: () => onClaimOpenShift(id, title),
                            onDeletePressed: () => onDeleteShift(id, title),
                            onClockIn: () => onClockIn(id),
                            onClockOut: () => onClockOut(id),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
