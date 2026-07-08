import 'package:apex/core/analytics_service.dart';
import 'package:apex/core/date_utils.dart';
import 'package:apex/features/availability/availability_service.dart';
import 'package:apex/features/calendar/calendar_page_controller.dart';
import 'package:apex/features/schedule/conflict_detector.dart';
import 'package:apex/features/schedule/schedule_repository.dart';
import 'package:apex/features/smart_suggestions/suggestion_engine.dart';
import 'package:apex/features/sidework/sidework_service.dart';
import 'package:apex/features/staff/staff_repository.dart';
import 'package:apex/features/swaps/swap_service.dart';
import 'package:apex/features/time_clock/time_clock_service.dart';
import 'package:apex/features/time_off/time_off_service.dart';
import 'package:apex/theme.dart';
import 'package:apex/widgets/admin_publish_panel.dart';
import 'package:apex/widgets/calendar_tab.dart';
import 'package:apex/widgets/notification_bell.dart';
import 'package:apex/widgets/swaps_tab.dart';
import 'package:apex/widgets/time_off_tab.dart';
import 'package:apex/widgets/smart_suggestions_panel.dart';
import 'package:apex/widgets/tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CalendarPage extends StatefulWidget {
  final String userEmail;
  final String userName;
  final String userRole;

  const CalendarPage({
    super.key,
    required this.userEmail,
    required this.userName,
    required this.userRole,
  });

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  bool _showAckBanner = false;
  int _currentIndex = 0;
  bool _isSyncing = false;
  bool _isPublishing = false;
  bool _isAddingSidework = false;
  List<dynamic> _allRequests = [];
  bool _hasCheckedNotifications = false;
  DateTimeRange? _temporarySelectedRange;
  late DateTime _selectedDate;
  bool _isFullMonthView = false;
  bool _showTutorial = true;
  int _tutorialStep = 0;

  final _sideWorkController = TextEditingController();
  final _timeOffReasonController = TextEditingController();
  final _adminShiftTitleController = TextEditingController();
  String? _selectedAssignee;
  List<String> _staffNames = [];
  Map<String, double> _staffRates = {};
  bool _isLoadingStaff = true;
  List<Map<String, dynamic>> _availabilityForDay = [];
  bool _myAvailabilityToday = true;
  bool _isOnVacation = false;
  bool _isLoadingAvailability = false;
  Map<String, String> _clockedInEntries = {};
  String? _adminSelectedStaff;
  bool _adminIsEvent = false;
  String? _adminSelectedZone;
  String _adminStartTime = '10:30 AM';
  String _adminEndTime = '5:30 PM';
  late DateTime _adminTargetWeekAnchor;
  final Map<String, bool> _adminSelectedDays = {};
  final Map<String, String> _dayLabels = {};

  final _supabase = Supabase.instance.client;
  late final _services = _CalendarServices(_supabase);
  CalendarPageController? _controller;
  bool _initialized = false;
  List<ShiftSuggestion> _suggestions = [];
  bool _loadingSuggestions = false;
  bool _isCopyingWeek = false;

  bool get _isOwner => widget.userRole == 'Owner';

  CalendarPageController get _ctrl {
    assert(_controller != null, 'Controller accessed before didChangeDependencies');
    return _controller!;
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _adminTargetWeekAnchor = DateTime.now();
    AnalyticsService.instance.trackStaffOpen();
    _listenToNewShifts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= CalendarPageController(
      context: context,
      userEmail: widget.userEmail,
      userName: widget.userName,
      userRole: widget.userRole,
      supabase: _supabase,
      timeClock: _services.timeClock,
      staffRepo: _services.staffRepo,
      availabilityService: _services.availabilityService,
      sideworkService: _services.sideworkService,
      swapService: _services.swapService,
      scheduleRepo: _services.scheduleRepo,
      timeOffService: _services.timeOffService,
      conflictDetector: _services.conflictDetector,
      suggestionEngine: _services.suggestionEngine,
      analytics: AnalyticsService.instance,
      notify: (fn) {
        if (mounted) setState(fn);
      },
      sideWorkController: _sideWorkController,
      timeOffReasonController: _timeOffReasonController,
      adminShiftTitleController: _adminShiftTitleController,
    );
    if (_initialized) return;
    _initialized = true;
    _ctrl.generateDynamicWeekLabels(
      anchor: _adminTargetWeekAnchor,
      selectedDays: _adminSelectedDays,
      dayLabels: _dayLabels,
    );
    _syncDataCore();
    _loadStaffNames();
    _loadTimeEntries();
    _loadTutorialState();
    if (_isOwner) _refreshSmartSuggestions();
  }

  @override
  void dispose() {
    _sideWorkController.dispose();
    _timeOffReasonController.dispose();
    _adminShiftTitleController.dispose();
    super.dispose();
  }

  Future<void> _loadTutorialState() async {
    await _ctrl.loadTutorialState((show) {
      if (mounted) setState(() => _showTutorial = show);
    });
  }

  Future<void> _dismissTutorial() async {
    await _ctrl.dismissTutorial((show) {
      if (mounted) setState(() => _showTutorial = show);
    });
  }

  Future<void> _loadStaffNames() async {
    final result = await _ctrl.loadStaffNames();
    if (!mounted) return;
    if (result == null) {
      setState(() => _isLoadingStaff = false);
      return;
    }
    setState(() {
      _staffNames = result.names;
      _staffRates = result.rates;
      _adminSelectedStaff = 'Open';
      _selectedAssignee = result.names.isNotEmpty ? result.names.first : null;
      _isLoadingStaff = false;
    });
    _loadAvailabilityForDate(_selectedDate);
  }

  Future<void> _loadAvailabilityForDate(DateTime date) async {
    setState(() => _isLoadingAvailability = true);
    final result = await _ctrl.loadAvailabilityForDate(date: date, staffNames: _staffNames);
    if (!mounted) return;
    if (result == null) {
      setState(() => _isLoadingAvailability = false);
      return;
    }
    setState(() {
      _availabilityForDay = result.availabilityForDay;
      _myAvailabilityToday = result.myAvailabilityToday;
      _isOnVacation = result.isOnVacation;
      _isLoadingAvailability = false;
    });
  }

  Future<void> _loadTimeEntries() async {
    final active = await _ctrl.loadTimeEntries();
    if (mounted && active != null) setState(() => _clockedInEntries = active);
  }

  void _listenToNewShifts() {
    var initialLoad = true;
    _services.scheduleRepo.listenNewShifts().listen((data) {
      if (initialLoad) {
        initialLoad = false;
        return;
      }
      if (data.isNotEmpty && !_isOwner && mounted) setState(() => _showAckBanner = true);
    });
  }

  void _changeAdminWeek(int weekDelta) {
    setState(() {
      _adminTargetWeekAnchor = _adminTargetWeekAnchor.add(Duration(days: weekDelta * 7));
      _ctrl.generateDynamicWeekLabels(
        anchor: _adminTargetWeekAnchor,
        selectedDays: _adminSelectedDays,
        dayLabels: _dayLabels,
      );
    });
    if (_isOwner) _refreshSmartSuggestions();
  }

  Future<void> _refreshSmartSuggestions() async {
    setState(() => _loadingSuggestions = true);
    final selectedKeys = _adminSelectedDays.entries.where((e) => e.value).map((e) => e.key);
    final firstSelected = selectedKeys.isEmpty ? null : selectedKeys.first;
    final target = firstSelected != null ? parseDateKey(firstSelected) : _adminTargetWeekAnchor;
    final list = await _ctrl.loadSmartSuggestions(target);
    if (mounted) {
      setState(() {
        _suggestions = list;
        _loadingSuggestions = false;
      });
    }
  }

  void _applySuggestion(ShiftSuggestion s) {
    setState(() {
      _adminShiftTitleController.text = s.title;
      _adminSelectedZone = s.zone;
      if (s.notes != null && s.notes!.contains('Shift:')) {
        final parts = s.notes!.replaceFirst('Shift: ', '').split(' - ');
        if (parts.length == 2) {
          _adminStartTime = parts[0].trim();
          _adminEndTime = parts[1].trim();
        }
      }
    });
    AnalyticsService.instance.logEvent('smart_suggestion_applied', params: {'title': s.title});
    _ctrl.showBanner('Applied suggestion: ${s.title}', Colors.green);
  }

  void _changeMonth(int delta) {
    setState(() {
      var newMonth = _selectedDate.month + delta;
      var newYear = _selectedDate.year;
      if (newMonth > 12) {
        newMonth = 1;
        newYear++;
      } else if (newMonth < 1) {
        newMonth = 12;
        newYear--;
      }
      final daysInNewMonth = DateTime(newYear, newMonth + 1, 0).day;
      final targetDay = _selectedDate.day > daysInNewMonth ? daysInNewMonth : _selectedDate.day;
      _selectedDate = DateTime(newYear, newMonth, targetDay);
    });
    _loadAvailabilityForDate(_selectedDate);
  }

  void _changeWeek(int weekDelta) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: weekDelta * 7)));
    _loadAvailabilityForDate(_selectedDate);
  }

  Future<void> _syncDataCore() async {
    final data = await _ctrl.loadScheduleData();
    if (data != null && mounted) setState(() => _allRequests = data);
    if (mounted) {
      await _ctrl.checkFirstTimeStatus();
      await _ctrl.checkForApprovalNotifications(
        hasChecked: _hasCheckedNotifications,
        setChecked: (v) => _hasCheckedNotifications = v,
      );
    }
  }

  Future<void> _loadScheduleData() async {
    final data = await _ctrl.loadScheduleData();
    if (data != null && mounted) setState(() => _allRequests = data);
  }

  List<Widget> _buildTabs() => [
        CalendarTab(
          supabase: _supabase,
          selectedDate: _selectedDate,
          isFullMonthView: _isFullMonthView,
          showAckBanner: _showAckBanner,
          isOwner: _isOwner,
          userName: widget.userName,
          isLoadingAvailability: _isLoadingAvailability,
          availabilityForDay: _availabilityForDay,
          myAvailabilityToday: _myAvailabilityToday,
          isOnVacation: _isOnVacation,
          allRequests: _allRequests,
          clockedInEntries: _clockedInEntries,
          staffNames: _staffNames,
          isLoadingStaff: _isLoadingStaff,
          sideWorkController: _sideWorkController,
          selectedAssignee: _selectedAssignee,
          isAddingSidework: _isAddingSidework,
          onToggleMonthView: () => setState(() => _isFullMonthView = !_isFullMonthView),
          onDateSelected: (date) {
            setState(() => _selectedDate = date);
            _loadAvailabilityForDate(date);
          },
          onChangeMonth: _changeMonth,
          onChangeWeek: _changeWeek,
          onAckBannerDismiss: () => setState(() => _showAckBanner = false),
          onToggleAvailability: () => _ctrl.toggleMyAvailability(
            selectedDate: _selectedDate,
            currentAvailability: _myAvailabilityToday,
            apply: (v) => setState(() => _myAvailabilityToday = v),
            reload: _loadAvailabilityForDate,
          ),
          onAssigneeChanged: (val) => setState(() => _selectedAssignee = val),
          onAddSidework: () => _ctrl.addNewSideWork(
            selectedDateKey: dateKey(_selectedDate),
            dayNum: _selectedDate.day,
            selectedAssignee: _selectedAssignee,
            setAdding: (v) => setState(() => _isAddingSidework = v),
          ),
          onToggleSideworkCompletion: _ctrl.toggleSideworkCompletion,
          onPostSwap: (title, staff) => _ctrl.handlePostSwap(title, staff, _selectedDate),
          onClaimOpenShift: _ctrl.claimOpenTemplateShift,
          onDeleteShift: _ctrl.deleteShift,
          onClockIn: (id) => _ctrl.clockIn(id, (shiftId, entryId) {
            setState(() => _clockedInEntries[shiftId] = entryId);
          }),
          onClockOut: (id) => _ctrl.clockOut(id, _clockedInEntries[id], (shiftId) {
            setState(() => _clockedInEntries.remove(shiftId));
          }),
        ),
        SwapsTab(
          supabase: _supabase,
          selectedDate: _selectedDate,
          userName: widget.userName,
          isOwner: _isOwner,
          onClaimShift: _ctrl.claimShift,
          onAdminAction: _ctrl.processAdminSwapAction,
        ),
        TimeOffTab(
          supabase: _supabase,
          isOwner: _isOwner,
          isSyncing: _isSyncing,
          temporarySelectedRange: _temporarySelectedRange,
          timeOffReasonController: _timeOffReasonController,
          onSingleDayPick: () async {
            final single = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (single != null) {
              setState(() => _temporarySelectedRange = DateTimeRange(start: single, end: single));
            }
          },
          onMultiDayPick: () async {
            final picked = await _ctrl.pickMultiDayRange();
            if (picked != null) setState(() => _temporarySelectedRange = picked);
          },
          onSubmit: () => _ctrl.submitTimeOffRequest(
            range: _temporarySelectedRange,
            allRequests: _allRequests,
            setSyncing: (v) => setState(() => _isSyncing = v),
            clearSelection: () => setState(() {
              _temporarySelectedRange = null;
              _timeOffReasonController.clear();
            }),
            reload: _loadScheduleData,
          ),
          onUpdateStatus: (id, status) => _ctrl.updateVacationStatus(id, status, _loadScheduleData),
        ),
        AdminPublishPanel(
          userName: widget.userName,
          isOwner: _isOwner,
          isPublishing: _isPublishing,
          isSyncing: _isSyncing,
          isLoadingStaff: _isLoadingStaff,
          staffNames: _staffNames,
          staffRates: _staffRates,
          shiftTitleController: _adminShiftTitleController,
          selectedStaff: _adminSelectedStaff,
          selectedZone: _adminSelectedZone,
          startTime: _adminStartTime,
          endTime: _adminEndTime,
          isEvent: _adminIsEvent,
          adminTargetWeekAnchor: _adminTargetWeekAnchor,
          adminSelectedDays: _adminSelectedDays,
          dayLabels: _dayLabels,
          onStaffChanged: (val) => setState(() => _adminSelectedStaff = val),
          onZoneChanged: (val) => setState(() => _adminSelectedZone = val),
          onStartTimeChanged: (val) => setState(() => _adminStartTime = val),
          onEndTimeChanged: (val) => setState(() => _adminEndTime = val),
          onEventChanged: (val) => setState(() => _adminIsEvent = val),
          onDayToggled: (key, val) {
            setState(() => _adminSelectedDays[key] = val);
            if (_isOwner) _refreshSmartSuggestions();
          },
          onWeekChanged: _changeAdminWeek,
          onCopyLastWeek: _isOwner
              ? () => _ctrl.copyPreviousWeek(
                    targetWeekAnchor: _adminTargetWeekAnchor,
                    setCopying: (v) => setState(() => _isCopyingWeek = v),
                  )
              : null,
          isCopyingWeek: _isCopyingWeek,
          smartSuggestionsPanel: _isOwner
              ? SmartSuggestionsPanel(
                  suggestions: _suggestions,
                  isLoading: _loadingSuggestions,
                  onRefresh: _refreshSmartSuggestions,
                  onApply: _applySuggestion,
                )
              : null,
          onPublish: () => _ctrl.adminCreateShift(
            adminSelectedDays: _adminSelectedDays,
            adminSelectedStaff: _adminSelectedStaff,
            adminStartTime: _adminStartTime,
            adminEndTime: _adminEndTime,
            adminIsEvent: _adminIsEvent,
            adminSelectedZone: _adminSelectedZone,
            setPublishing: (v) => setState(() => _isPublishing = v),
            onSuccess: () => setState(() {
              _adminSelectedDays.updateAll((key, value) => false);
              _adminSelectedZone = null;
            }),
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final tabs = _buildTabs();
    return Scaffold(
      backgroundColor: UniversalTheme.background,
      appBar: AppBar(
        backgroundColor: UniversalTheme.darkSlate,
        elevation: 0,
        title: const Text(
          'APEX',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: Text(
                '${_isOwner ? 'OWNER' : 'STAFF'}: ${widget.userName}',
                style: const TextStyle(color: UniversalTheme.accent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white, size: 20),
            onPressed: _ctrl.handleLogOut,
          ),
          const NotificationBell(),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          tabs[_currentIndex],
          TutorialOverlay(
            visible: _showTutorial,
            isOwner: _isOwner,
            userName: widget.userName,
            step: _tutorialStep,
            onNext: () {
              setState(() {
                if (_tutorialStep < 3) {
                  _tutorialStep++;
                } else {
                  _dismissTutorial();
                }
              });
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: UniversalTheme.darkSlate,
        selectedItemColor: UniversalTheme.accent,
        unselectedItemColor: Colors.grey.shade400,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            if (index != 3 && _isOwner && _showTutorial) _dismissTutorial();
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.swap_horizontal_circle), label: 'Swaps'),
          BottomNavigationBarItem(icon: Icon(Icons.block), label: 'Time Off'),
          BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
        ],
      ),
    );
  }
}

class _CalendarServices {
  _CalendarServices(SupabaseClient client)
      : timeClock = TimeClockService(client),
        staffRepo = StaffRepository(client),
        availabilityService = AvailabilityService(client),
        sideworkService = SideworkService(client),
        swapService = SwapService(client),
        scheduleRepo = ScheduleRepository(client),
        timeOffService = TimeOffService(client),
        conflictDetector = ConflictDetector(client),
        suggestionEngine = SuggestionEngine(client);

  final TimeClockService timeClock;
  final StaffRepository staffRepo;
  final AvailabilityService availabilityService;
  final SideworkService sideworkService;
  final SwapService swapService;
  final ScheduleRepository scheduleRepo;
  final TimeOffService timeOffService;
  final ConflictDetector conflictDetector;
  final SuggestionEngine suggestionEngine;
}
