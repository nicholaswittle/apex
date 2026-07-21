import 'package:apex/auth_page.dart';
import 'package:apex/core/analytics_service.dart';
import 'package:apex/core/date_utils.dart';
import 'package:apex/core/profile_service.dart';
import 'package:apex/core/schedule_constants.dart';
import 'package:apex/features/availability/availability_service.dart';
import 'package:apex/features/schedule/conflict_detector.dart';
import 'package:apex/features/schedule/schedule_repository.dart';
import 'package:apex/features/sidework/sidework_service.dart';
import 'package:apex/features/smart_suggestions/suggestion_engine.dart';
import 'package:apex/features/staff/staff_repository.dart';
import 'package:apex/features/swaps/swap_service.dart';
import 'package:apex/features/time_clock/time_clock_service.dart';
import 'package:apex/features/time_off/time_off_service.dart';
import 'package:apex/theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Business logic and side-effects for [CalendarPage].
class CalendarPageController {
  CalendarPageController({
    required this.context,
    required this.userEmail,
    required this.userName,
    required this.userRole,
    required this.supabase,
    required this.timeClock,
    required this.staffRepo,
    required this.availabilityService,
    required this.sideworkService,
    required this.swapService,
    required this.scheduleRepo,
    required this.timeOffService,
    required this.conflictDetector,
    required this.suggestionEngine,
    required this.analytics,
    required this.notify,
    required this.sideWorkController,
    required this.timeOffReasonController,
    required this.adminShiftTitleController,
  });

  final BuildContext context;
  final String userEmail;
  final String userName;
  final String userRole;
  final SupabaseClient supabase;
  final TimeClockService timeClock;
  final StaffRepository staffRepo;
  final AvailabilityService availabilityService;
  final SideworkService sideworkService;
  final SwapService swapService;
  final ScheduleRepository scheduleRepo;
  final TimeOffService timeOffService;
  final ConflictDetector conflictDetector;
  final SuggestionEngine suggestionEngine;
  final AnalyticsService analytics;
  final void Function(VoidCallback fn) notify;
  final TextEditingController sideWorkController;
  final TextEditingController timeOffReasonController;
  final TextEditingController adminShiftTitleController;

  bool get isOwner => userRole == 'Owner';

  void showBanner(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }

  void showNotificationOverlay(String notice) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(notice, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: UniversalTheme.accent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
      ),
    );
  }

  Future<void> loadTutorialState(void Function(bool show) apply) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool('tutorial_dismissed_$userEmail') ?? false;
    apply(!dismissed);
  }

  Future<void> dismissTutorial(void Function(bool show) apply) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_dismissed_$userEmail', true);
    apply(false);
  }

  Future<({List<String> names, Map<String, double> rates})?> loadStaffNames() async {
    try {
      final rows = await staffRepo.loadStaffNames();
      final names = rows.map<String>((r) => r['name'] as String).toList();
      final rates = <String, double>{
        for (final r in rows) r['name'] as String: (r['hourly_rate'] as num?)?.toDouble() ?? 0.0,
      };
      return (names: names, rates: rates);
    } catch (e) {
      showBanner('Failed to load staff list: $e', UniversalTheme.alertRed);
      return null;
    }
  }

  Future<({
    List<Map<String, dynamic>> availabilityForDay,
    bool myAvailabilityToday,
    bool isOnVacation,
    bool isBooked,
  })?> loadAvailabilityForDate({
    required DateTime date,
    required List<String> staffNames,
  }) async {
    if (staffNames.isEmpty) return null;
    try {
      return await availabilityService.loadForDate(
        date: date,
        staffNames: staffNames,
        userName: userName,
      );
    } catch (e) {
      showBanner('Failed to load availability: $e', UniversalTheme.alertRed);
      return null;
    }
  }

  Future<Set<String>> loadBookedStaffForDates(List<String> dateKeys) async {
    try {
      return await availabilityService.loadBookedStaff(dateKeys: dateKeys);
    } catch (_) {
      // Advisory only — a failed lookup drops the warning rather than
      // banner-spamming the admin on every day toggle.
      return {};
    }
  }

  Future<void> toggleMyAvailability({
    required DateTime selectedDate,
    required bool currentAvailability,
    required void Function(bool) apply,
    required Future<void> Function(DateTime) reload,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final newAvail = !currentAvailability;
    try {
      await availabilityService.toggleAvailability(
        userId: userId,
        userName: userName,
        date: selectedDate,
        available: newAvail,
      );
      apply(newAvail);
      await reload(selectedDate);
    } catch (e) {
      showBanner('Failed to update availability: $e', UniversalTheme.alertRed);
    }
  }

  Future<Map<String, String>?> loadTimeEntries() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      return await timeClock.loadActiveEntriesForToday(userId);
    } catch (e) {
      showBanner('Failed to load clock-in status: $e', UniversalTheme.alertRed);
      return null;
    }
  }

  Future<void> clockIn(String shiftId, void Function(String, String) apply) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final entryId = await timeClock.clockIn(userId: userId, userName: userName, shiftId: shiftId);
      apply(shiftId, entryId);
    } catch (e) {
      showBanner('Clock in failed: $e', UniversalTheme.alertRed);
    }
  }

  Future<void> clockOut(String shiftId, String? entryId, void Function(String) apply) async {
    if (entryId == null) return;
    try {
      await timeClock.clockOut(entryId);
      apply(shiftId);
    } catch (e) {
      showBanner('Clock out failed: $e', UniversalTheme.alertRed);
    }
  }

  void generateDynamicWeekLabels({
    required DateTime anchor,
    required Map<String, bool> selectedDays,
    required Map<String, String> dayLabels,
  }) {
    final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
    selectedDays.clear();
    dayLabels.clear();
    for (var i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      final key = dateKey(day);
      selectedDays[key] = false;
      dayLabels[key] = '${shortDayNames[i]} (${monthNames[day.month - 1]} ${day.day})';
    }
  }

  Future<void> handleLogOut() async {
    await supabase.auth.signOut();
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthPage()),
    );
  }

  Future<void> addNewSideWork({
    required String selectedDateKey,
    required int dayNum,
    required String? selectedAssignee,
    required void Function(bool) setAdding,
  }) async {
    final taskText = sideWorkController.text.trim();
    if (taskText.isEmpty) {
      showBanner('Enter a sidework task first.', UniversalTheme.alertRed);
      return;
    }
    if (selectedAssignee == null) {
      showBanner('Select a staff member to assign this task.', UniversalTheme.alertRed);
      return;
    }
    if (!isOwner) {
      showBanner('Only owners can add sidework tasks.', UniversalTheme.alertRed);
      return;
    }
    setAdding(true);
    try {
      final orgId = await ProfileService.loadOrganizationId();
      if (orgId == null) {
        showBanner('Could not load your organization. Try signing out and back in.', UniversalTheme.alertRed);
        return;
      }
      await sideworkService.addTask(
        taskDate: selectedDateKey,
        dayNum: dayNum,
        task: taskText,
        assignedTo: selectedAssignee,
        organizationId: orgId,
      );
      sideWorkController.clear();
      showBanner('Sidework task added.', Colors.green);
    } on PostgrestException catch (e) {
      showBanner('Could not add sidework: ${e.message}', UniversalTheme.alertRed);
    } catch (e) {
      showBanner('Could not add sidework: $e', UniversalTheme.alertRed);
    } finally {
      setAdding(false);
    }
  }

  Future<void> handlePostSwap(String shiftTitle, String originalStaff, DateTime selectedDate) async {
    if (originalStaff == 'Open') return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Swap Marketplace'),
        content: Text('Are you sure you want to open this "$shiftTitle" shift to the team?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Post Shift', style: TextStyle(color: UniversalTheme.alertRed)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await swapService.postSwap(
      shiftTitle: shiftTitle,
      originalStaff: originalStaff,
      selectedDate: selectedDate,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Shift posted to Swaps Board successfully!'),
        backgroundColor: UniversalTheme.accent,
      ),
    );
  }

  Future<void> claimOpenTemplateShift(String shiftId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Claim Open Shift'),
        content: Text('Would you like to sign up and add "$title" to your personal work schedule?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Claim Shift', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await swapService.claimOpenShift(shiftId: shiftId, userName: userName);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully scheduled for $title!'), backgroundColor: Colors.green),
    );
  }

  Future<void> claimShift(String swapId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    await swapService.claimShift(swapId: swapId, userId: userId, userName: userName);
    notify(() {});
  }

  Future<void> toggleSideworkCompletion(String taskId, bool completed) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await sideworkService.toggleCompletion(taskId: taskId, completed: completed, userId: userId);
    } catch (e) {
      showBanner('Could not update sidework: $e', UniversalTheme.alertRed);
    }
  }

  Future<void> processAdminSwapAction(String swapId, String status) async {
    try {
      await swapService.processAdminAction(swapId: swapId, status: status);
    } on StateError catch (e) {
      showBanner(e.message, UniversalTheme.alertRed);
      return;
    }
    notify(() {});
  }

  Future<void> deleteShift(String shiftId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Shift'),
        content: Text('Are you sure you want to permanently remove the "$title" shift?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: UniversalTheme.alertRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await scheduleRepo.deleteShift(shiftId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Shift removed from schedule.'), backgroundColor: UniversalTheme.darkSlate),
    );
  }

  Future<void> adminCreateShift({
    required Map<String, bool> adminSelectedDays,
    required String? adminSelectedStaff,
    required String adminStartTime,
    required String adminEndTime,
    required bool adminIsEvent,
    required String? adminSelectedZone,
    required void Function(bool) setPublishing,
    required void Function() onSuccess,
  }) async {
    final enteredTitle = adminShiftTitleController.text.trim();
    final title = enteredTitle.isEmpty ? 'General Support Shift' : enteredTitle;
    final targetDates =
        adminSelectedDays.entries.where((e) => e.value).map((e) => e.key).toList();

    if (targetDates.isEmpty) {
      showBanner('Please check at least one day to publish.', UniversalTheme.alertRed);
      return;
    }
    if (!isOwner) {
      showBanner('Only owners can publish shifts.', UniversalTheme.alertRed);
      return;
    }

    setPublishing(true);
    analytics.trackScheduleCreateStart(dayCount: targetDates.length);

    try {
      final orgId = await ProfileService.loadOrganizationId();
      if (orgId == null) {
        showBanner('Could not load your organization. Try signing out and back in.', UniversalTheme.alertRed);
        analytics.trackPublishFail(error: 'missing_org_id');
        return;
      }

      final staff = adminSelectedStaff ?? 'Open';
      final conflicts = await conflictDetector.findPublishConflicts(
        targetDates: targetDates,
        staff: staff,
      );
      if (conflicts.isNotEmpty && context.mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Scheduling conflicts'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Review before publishing:'),
                  const SizedBox(height: 8),
                  ...conflicts.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $c', style: const TextStyle(fontSize: 13)),
                      )),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Publish anyway'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }

      await scheduleRepo.publishShifts(
        targetDates: targetDates,
        title: title,
        staff: staff,
        formattedHours: 'Shift: $adminStartTime - $adminEndTime',
        isEvent: adminIsEvent,
        zone: adminSelectedZone,
        organizationId: orgId,
        excludeUserId: supabase.auth.currentUser?.id,
      );

      adminShiftTitleController.clear();
      analytics.trackScheduleCreateEnd(success: true, dayCount: targetDates.length);
      analytics.trackPublishSuccess(dayCount: targetDates.length);
      onSuccess();
      showBanner('Shift successfully published across ${targetDates.length} days!', Colors.green);
    } on PostgrestException catch (e) {
      analytics.trackScheduleCreateEnd(success: false, error: e.message);
      analytics.trackPublishFail(error: e.message);
      showBanner('Could not publish shifts: ${e.message}', UniversalTheme.alertRed);
    } catch (e) {
      analytics.trackScheduleCreateEnd(success: false, error: e.toString());
      analytics.trackPublishFail(error: e.toString());
      showBanner('Could not publish shifts: $e', UniversalTheme.alertRed);
    } finally {
      setPublishing(false);
    }
  }

  Future<void> executeDatabaseInsert({
    required String startStr,
    required String endStr,
    required String reasonText,
    required void Function(bool) setSyncing,
    required void Function() onSuccess,
  }) async {
    setSyncing(true);
    try {
      await timeOffService.submitRequest(
        userId: supabase.auth.currentUser!.id,
        userName: userName,
        startDate: startStr,
        endDate: endStr,
        reason: reasonText.isEmpty ? 'Vacation Leave Request' : reasonText,
      );
      showBanner('Vacation layout requested successfully!', Colors.green);
      onSuccess();
    } catch (e) {
      showBanner('Submission error: $e', UniversalTheme.alertRed);
    } finally {
      setSyncing(false);
    }
  }

  void showOverlapWarningDialog({
    required String start,
    required String end,
    required String reasonText,
    required Future<void> Function() onSubmitAnyway,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: UniversalTheme.lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.orange, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Staffing Conflict Notice', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Another team member has already been approved for leave between $start and $end.',
              style: const TextStyle(color: UniversalTheme.darkSlate, fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'You can still submit this, but please note it may not receive approval due to minimum coverage requirements.',
              style: TextStyle(color: Colors.black87, fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Modify Dates', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await onSubmitAnyway();
            },
            child: const Text('Submit Anyway', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<DateTimeRange?> pickMultiDayRange() async {
    return showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF1E1E1E),
            colorScheme: const ColorScheme.dark(
              primary: UniversalTheme.accent,
              onPrimary: UniversalTheme.darkSlate,
              surface: Color(0xFF2D2D2D),
              onSurface: Colors.white,
              onSurfaceVariant: Colors.white70,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: UniversalTheme.darkSlate,
              foregroundColor: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  Future<List<dynamic>?> loadScheduleData() async {
    try {
      return await timeOffService.loadRequests();
    } catch (e) {
      showBanner('Error loading vacation logs: $e', UniversalTheme.alertRed);
      return null;
    }
  }

  Future<void> checkFirstTimeStatus() async {
    try {
      final data = await supabase
          .from('profiles')
          .select('first_time_login')
          .eq('email', userEmail)
          .maybeSingle();
      if (data != null && data['first_time_login'] == true) {
        showFirstTimeGuide();
      }
    } catch (_) {}
  }

  Future<void> checkForApprovalNotifications({
    required bool hasChecked,
    required void Function(bool) setChecked,
  }) async {
    if (hasChecked) return;
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;
      final unnotified = await timeOffService.checkUnnotified(currentUser.id);
      for (final request in unnotified) {
        showNotificationOverlay(
          'Schedule Notice: Your request from ${request['start_date']} to ${request['end_date']} was marked [${request['status']}].',
        );
        await timeOffService.markNotified(request['id'] as String);
      }
      setChecked(true);
    } catch (_) {}
  }

  Future<void> dismissFirstTimeFlag() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;
      await supabase.from('profiles').update({'first_time_login': false}).eq('id', currentUser.id);
    } catch (_) {}
  }

  Future<void> updateVacationStatus(String id, String targetStatus, Future<void> Function() reload) async {
    try {
      await timeOffService.updateStatus(id: id, targetStatus: targetStatus);
      showBanner('Request updated to $targetStatus', UniversalTheme.darkSlate);
      await reload();
    } catch (e) {
      showBanner('Update failed: $e', UniversalTheme.alertRed);
    }
  }

  Future<void> deleteVacationRequest(String id, Future<void> Function() reload) async {
    try {
      await timeOffService.deleteRequest(id);
      showBanner('Request deleted', UniversalTheme.darkSlate);
      await reload();
    } catch (e) {
      showBanner('Delete failed: $e', UniversalTheme.alertRed);
    }
  }

  void submitTimeOffRequest({
    required DateTimeRange? range,
    required List<dynamic> allRequests,
    required void Function(bool) setSyncing,
    required void Function() clearSelection,
    required Future<void> Function() reload,
  }) {
    if (range == null) {
      showBanner('Please pick your desired dates first.', UniversalTheme.alertRed);
      return;
    }
    final startStr = range.start.toIso8601String().split('T')[0];
    final endStr = range.end.toIso8601String().split('T')[0];
    final reasonText = timeOffReasonController.text.trim();

    final isOverlapping = allRequests.any((req) {
      if (req['status'] != 'Approved') return false;
      final reqStart = DateTime.parse(req['start_date']);
      final reqEnd = DateTime.parse(req['end_date']);
      return !(range.end.isBefore(reqStart) || range.start.isAfter(reqEnd));
    });

    if (isOverlapping) {
      showOverlapWarningDialog(
        start: startStr,
        end: endStr,
        reasonText: reasonText,
        onSubmitAnyway: () => executeDatabaseInsert(
          startStr: startStr,
          endStr: endStr,
          reasonText: reasonText,
          setSyncing: setSyncing,
          onSuccess: () {
            clearSelection();
            reload();
          },
        ),
      );
      return;
    }

    executeDatabaseInsert(
      startStr: startStr,
      endStr: endStr,
      reasonText: reasonText,
      setSyncing: setSyncing,
      onSuccess: () {
        clearSelection();
        reload();
      },
    );
  }

  void showFirstTimeGuide() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: UniversalTheme.lightCard,
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: UniversalTheme.accent),
            SizedBox(width: 8),
            Text('Welcome to Apex', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello $userName, let\'s configure your setup:', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const Divider(height: 24, color: Colors.white12),
            _guideRow(Icons.date_range, 'Request blocks of dates smoothly for multi-day vacations.'),
            _guideRow(Icons.notification_important, 'Receive automatic confirmations when an admin approves an entry.'),
            if (userRole == 'Owner')
              _guideRow(Icons.gavel, 'Owner Rights Active: You have administrative oversight to authorize operations.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              dismissFirstTimeFlag();
              Navigator.pop(context);
            },
            child: const Text('Got it, let\'s launch', style: TextStyle(color: UniversalTheme.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _guideRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: UniversalTheme.accent),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }

  Future<void> copyPreviousWeek({
    required DateTime targetWeekAnchor,
    required void Function(bool) setCopying,
  }) async {
    if (!isOwner) return;
    setCopying(true);
    try {
      final orgId = await ProfileService.loadOrganizationId();
      if (orgId == null) {
        showBanner('Could not load your organization.', UniversalTheme.alertRed);
        return;
      }
      final count = await scheduleRepo.copyPreviousWeek(
        targetWeekAnchor: targetWeekAnchor,
        organizationId: orgId,
        excludeUserId: supabase.auth.currentUser?.id,
      );
      if (count == 0) {
        showBanner('No shifts found in the previous week to copy.', UniversalTheme.alertRed);
      } else {
        analytics.logEvent('copy_week_success', params: {'shift_count': count});
        showBanner('Copied $count shifts from last week.', Colors.green);
      }
    } catch (e) {
      showBanner('Copy week failed: $e', UniversalTheme.alertRed);
    } finally {
      setCopying(false);
    }
  }

  Future<List<ShiftSuggestion>> loadSmartSuggestions(DateTime targetDate) async {
    final orgId = await ProfileService.loadOrganizationId();
    if (orgId == null) return [];
    return suggestionEngine.suggestForDate(orgId: orgId, targetDate: targetDate);
  }
}
