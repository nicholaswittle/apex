import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apex/theme.dart';
import 'package:wisense_ui/wisense_ui.dart';
import 'auth_page.dart';
import 'widgets/staff_availability_card.dart';
import 'widgets/shift_calendar_grid.dart';
import 'widgets/labor_cost_panel.dart';
import 'widgets/csv_time_card_exporter.dart';
import 'billing_page.dart';
import 'features/settings/role_config_screen.dart';
import 'features/staff/invite_management_screen.dart';
import 'features/settings/upgrade_screen.dart';
import 'widgets/location_selector.dart';


class CalendarPage extends StatefulWidget {
  final String userEmail;
  final String userName;
  final String userRole;
  final String businessId;

  const CalendarPage({
    super.key,
    required this.userEmail,
    required this.userName,
    required this.userRole,
    required this.businessId,
  });

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  bool _showAckBanner = false; 
  int _currentIndex = 0;
  
  bool _isSyncing = false;
  List<dynamic> _allRequests = [];
  bool _hasCheckedNotifications = false;

  DateTimeRange? _temporarySelectedRange;
  late DateTime _selectedDate; 
  bool _isFullMonthView = false;

  bool _showTutorial = true;
  int _tutorialStep = 0;

  final TextEditingController _sideWorkController = TextEditingController();
  final TextEditingController _timeOffReasonController = TextEditingController();
  String? _selectedAssignee;
  List<String> _staffNames = [];
  Map<String, double> _staffRates = {};
  bool _isLoadingStaff = true;

  List<Map<String, dynamic>> _availabilityForDay = [];
  bool _myAvailabilityToday = true;
  bool _isOnVacation = false;
  bool _isLoadingAvailability = false;

  Map<String, String> _clockedInEntries = {};
  String? _selectedLocationId;
  List<String> _configuredRoles = [];

  final TextEditingController _adminShiftTitleController = TextEditingController();
  String? _adminSelectedStaff;
  bool _adminIsEvent = false;
  String? _adminSelectedZone;

  String _adminStartTime = '10:30 AM';
  String _adminEndTime = '5:30 PM';

  final List<String> _timeSlots = [
    '5:00 AM', '5:30 AM', '6:00 AM', '6:30 AM', '7:00 AM', '7:30 AM', '8:00 AM', '8:30 AM',
    '9:00 AM', '9:30 AM', '10:00 AM', '10:30 AM', '11:00 AM', '11:30 AM', '12:00 PM', '12:30 PM',
    '1:00 PM', '1:30 PM', '2:00 PM', '2:30 PM', '3:00 PM', '3:30 PM', '4:00 PM', '4:30 PM',
    '5:00 PM', '5:30 PM', '6:00 PM', '6:30 PM', '7:00 PM', '7:30 PM', '8:00 PM', '8:30 PM',
    '9:00 PM', '9:30 PM', '10:00 PM', '10:30 PM', '11:00 PM'
  ];

  late DateTime _adminTargetWeekAnchor;
  final Map<int, bool> _adminSelectedDays = {};
  final Map<int, String> _dayLabels = {};

  final _supabase = Supabase.instance.client;

  bool get _isOwner => widget.userRole == 'Owner';

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _adminTargetWeekAnchor = DateTime.now();
    _generateDynamicWeekLabels();
    _syncDataCore();
    _loadStaffNames();
    _loadConfiguredRoles();
    _loadTimeEntries();
    _listenToNewShifts();
  }

  Map<String, dynamic> _tenantFields() => {'business_id': widget.businessId};

  Future<void> _loadConfiguredRoles() async {
    try {
      final rows = await _supabase
          .from('roles')
          .select('name')
          .eq('business_id', widget.businessId)
          .order('sort_order');
      if (!mounted) return;
      setState(() {
        _configuredRoles = (rows as List).map((r) => r['name'] as String).toList();
      });
    } catch (_) {}
  }

  Future<void> _loadStaffNames() async {
    try {
      final data = await _supabase
          .from('profiles')
          .select('name, role, hourly_rate')
          .eq('business_id', widget.businessId)
          .order('name');
      if (!mounted) return;
      final rows = (data as List).cast<Map<String, dynamic>>();
      final names = rows.map<String>((r) => r['name'] as String).toList();
      final rates = <String, double>{
        for (final r in rows) r['name'] as String: (r['hourly_rate'] as num?)?.toDouble() ?? 0.0,
      };
      setState(() {
        _staffNames = names;
        _staffRates = rates;
        _adminSelectedStaff = 'Open';
        _selectedAssignee = names.isNotEmpty ? names.first : null;
        _isLoadingStaff = false;
      });
      _loadAvailabilityForDate(_selectedDate);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingStaff = false);
      _showBanner('Failed to load staff list: $e', UniversalTheme.alertRed);
    }
  }

  Future<void> _loadAvailabilityForDate(DateTime date) async {
    if (_staffNames.isEmpty) return;
    setState(() => _isLoadingAvailability = true);
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final results = await Future.wait([
        _supabase.from('availability').select('user_name, available').eq('date', dateStr),
        _supabase.from('time_off_requests').select('user_name').eq('status', 'Approved').lte('start_date', dateStr).gte('end_date', dateStr),
      ]);
      if (!mounted) return;
      final rows = ((results[0] as List?)?.cast<Map<String, dynamic>>()) ?? [];
      final vacationRows = ((results[1] as List?)?.cast<Map<String, dynamic>>()) ?? [];
      final Map<String, bool> avMap = {
        for (final row in rows)
          if (row['user_name'] is String && row['available'] is bool)
            row['user_name'] as String: row['available'] as bool,
      };
      final vacationSet = <String>{
        for (final row in vacationRows)
          if (row['user_name'] is String) row['user_name'] as String,
      };
      setState(() {
        _availabilityForDay = _staffNames.map((name) => {
          'user_name': name,
          'available': vacationSet.contains(name) ? false : (avMap[name] ?? true),
          'on_vacation': vacationSet.contains(name),
        }).toList();
        _myAvailabilityToday = vacationSet.contains(widget.userName) ? false : (avMap[widget.userName] ?? true);
        _isOnVacation = vacationSet.contains(widget.userName);
        _isLoadingAvailability = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingAvailability = false);
      _showBanner('Failed to load availability: $e', UniversalTheme.alertRed);
    }
  }

  Future<void> _toggleMyAvailability() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    final newAvail = !_myAvailabilityToday;
    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    try {
      await _supabase.from('availability').upsert(
        {
          'user_id': userId,
          'user_name': widget.userName,
          'date': dateStr,
          'available': newAvail,
          ..._tenantFields(),
        },
        onConflict: 'user_id,date',
      );
      setState(() => _myAvailabilityToday = newAvail);
      await _loadAvailabilityForDate(_selectedDate);
    } catch (e) {
      _showBanner('Failed to update availability: $e', UniversalTheme.alertRed);
    }
  }

  Color _zoneColor(String zone) => switch (zone) {
    'Bar'     => const Color(0xFF1D4ED8),
    'Kitchen' => const Color(0xFFD97706),
    'Floor'   => const Color(0xFF059669),
    _         => Colors.grey,
  };

  double _calculateShiftHours() {
    double parse(String t) {
      try {
        final p = t.split(' ');
        final hm = p[0].split(':');
        int h = int.parse(hm[0]);
        final m = int.parse(hm[1]);
        if (p[1] == 'PM' && h != 12) h += 12;
        if (p[1] == 'AM' && h == 12) h = 0;
        return h + m / 60.0;
      } catch (_) {
        return 0.0;
      }
    }
    final start = parse(_adminStartTime);
    var end = parse(_adminEndTime);
    if (end < start) end += 24;
    return end - start;
  }

  Future<void> _loadTimeEntries() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final data = await _supabase
          .from('time_entries')
          .select('id, shift_id')
          .eq('user_id', userId)
          .gte('clock_in', '${dateStr}T00:00:00')
          .isFilter('clock_out', null);
      if (!mounted) return;
      final rows = ((data as List?)?.cast<Map<String, dynamic>>()) ?? [];
      setState(() {
        _clockedInEntries = {for (final r in rows) r['shift_id'] as String: r['id'] as String};
      });
    } catch (e) {
    if (!mounted) return;
    _showBanner('Failed to load clock-in status: $e', UniversalTheme.alertRed);
  }
  }

  Future<void> _clockIn(String shiftId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final result = await _supabase.from('time_entries').insert({
        'user_id': userId,
        'user_name': widget.userName,
        'shift_id': shiftId,
        ..._tenantFields(),
      }).select('id').single();
      setState(() => _clockedInEntries[shiftId] = result['id'] as String);
    } catch (e) {
      _showBanner('Clock in failed: $e', UniversalTheme.alertRed);
    }
  }

  Future<void> _clockOut(String shiftId) async {
    final entryId = _clockedInEntries[shiftId];
    if (entryId == null) return;
    try {
      await _supabase.from('time_entries')
          .update({'clock_out': DateTime.now().toIso8601String()})
          .eq('id', entryId);
      setState(() => _clockedInEntries.remove(shiftId));
    } catch (e) {
      _showBanner('Clock out failed: $e', UniversalTheme.alertRed);
    }
  }

  void _listenToNewShifts() {
    bool initialLoad = true;
    _supabase
        .from('shifts')
        .stream(primaryKey: ['id'])
        .listen((List<Map<String, dynamic>> data) {
          if (initialLoad) {
            initialLoad = false;
            return;
          }
          if (data.isNotEmpty && !_isOwner) {
            setState(() => _showAckBanner = true);
          }
        });
  }

  void _generateDynamicWeekLabels() {
    int currentWeekday = _adminTargetWeekAnchor.weekday; 
    DateTime monday = _adminTargetWeekAnchor.subtract(Duration(days: currentWeekday - 1));

    List<String> shortNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    List<String> monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    _adminSelectedDays.clear();
    _dayLabels.clear();

    for (int i = 0; i < 7; i++) {
      DateTime day = monday.add(Duration(days: i));
      _adminSelectedDays[day.day] = false;
      _dayLabels[day.day] = '${shortNames[i]} (${monthNames[day.month - 1]} ${day.day})';
    }
  }

  void _changeAdminWeek(int weekDelta) {
    setState(() {
      _adminTargetWeekAnchor = _adminTargetWeekAnchor.add(Duration(days: weekDelta * 7));
      _generateDynamicWeekLabels();
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      if (_isFullMonthView) {
        int newMonth = _selectedDate.month + delta;
        int newYear = _selectedDate.year;

        if (newMonth > 12) {
          newMonth = 1;
          newYear++;
        } else if (newMonth < 1) {
          newMonth = 12;
          newYear--;
        }

        int daysInNewMonth = DateTime(newYear, newMonth + 1, 0).day;
        int targetDay = _selectedDate.day > daysInNewMonth ? daysInNewMonth : _selectedDate.day;

        _selectedDate = DateTime(newYear, newMonth, targetDay);
      } else {
        _selectedDate = _selectedDate.add(Duration(days: delta));
      }
    });
  }

  void _handleLogOut() async {
    await _supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthPage()),
    );
  }

  void _addNewSideWork() async {
    final taskText = _sideWorkController.text.trim();
    if (taskText.isEmpty || _selectedAssignee == null) return;

    await _supabase.from('sidework').insert({
      'day_num': _selectedDate.day,
      'task': taskText,
      'assigned_to': _selectedAssignee,
      ..._tenantFields(),
    });

    _sideWorkController.clear();
    setState(() {}); 
  }

  void _handlePostSwap(String shiftTitle, String originalStaff) async {
    if (originalStaff == 'Open') return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
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

    if (confirm == true) {
      await _supabase.from('swaps').insert({
        'shift_title': shiftTitle,
        'original_staff': originalStaff,
        'day_num': _selectedDate.day,
        'status': 'Available',
        ..._tenantFields(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shift posted to Swaps Board successfully!'), backgroundColor: UniversalTheme.accent),
      );
    }
  }

  void _claimOpenTemplateShift(String shiftId, String title) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
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

    if (confirm == true) {
      await _supabase.from('shifts').update({'staff': widget.userName}).eq('id', shiftId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully scheduled for $title!'), backgroundColor: Colors.green),
      );
    }
  }

  void _claimShift(String swapId) async {
    await _supabase.from('swaps').update({'status': 'Pending Approval'}).eq('id', swapId);
    setState(() {});
  }

  void _processAdminSwapAction(String swapId, String status, String title, String currentStaff, int dayNum) async {
    if (status == 'Approved') {
      final List<dynamic> matchingShifts = await _supabase
          .from('shifts')
          .select('id')
          .eq('day_num', dayNum)
          .eq('title', title)
          .eq('staff', currentStaff);

      if (matchingShifts.isNotEmpty) {
        String shiftTableId = matchingShifts.first['id'].toString();
        await _supabase.from('shifts').update({'staff': 'Covered'}).eq('id', shiftTableId);
      }
      await _supabase.from('swaps').update({'status': 'Swapped'}).eq('id', swapId);
    } else {
      await _supabase.from('swaps').update({'status': 'Available'}).eq('id', swapId);
    }
    setState(() {});
  }

  Future<void> _executeDatabaseInsert(String startStr, String endStr, String reasonText) async {
    setState(() => _isSyncing = true);
    try {
      await _supabase.from('time_off_requests').insert({
        'user_id': _supabase.auth.currentUser!.id,
        'user_name': widget.userName,
        'start_date': startStr,
        'end_date': endStr,
        'reason': reasonText.isEmpty ? 'Vacation Leave Request' : reasonText,
        ..._tenantFields(),
      });

      _showBanner('Vacation layout requested successfully!', Colors.green);
      
      setState(() {
        _temporarySelectedRange = null;
        _timeOffReasonController.clear();
      });
      
      await _loadScheduleData();
    } catch (e) {
      _showBanner('Submission error: $e', UniversalTheme.alertRed);
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  void _submitTimeOffRequest() async {
    if (_temporarySelectedRange == null) {
      _showBanner('Please pick your desired dates first.', UniversalTheme.alertRed);
      return;
    }

    final startStr = _temporarySelectedRange!.start.toIso8601String().split('T')[0];
    final endStr = _temporarySelectedRange!.end.toIso8601String().split('T')[0];
    final reasonText = _timeOffReasonController.text.trim();

    bool isOverlapping = _allRequests.any((req) {
      if (req['status'] != 'Approved') return false;
      DateTime reqStart = DateTime.parse(req['start_date']);
      DateTime reqEnd = DateTime.parse(req['end_date']);
      return !(_temporarySelectedRange!.end.isBefore(reqStart) || _temporarySelectedRange!.start.isAfter(reqEnd));
    });

    if (isOverlapping) {
      _showOverlapWarningDialog(startStr, endStr, reasonText);
      return;
    }

    await _executeDatabaseInsert(startStr, endStr, reasonText);
  }

  void _adminCreateShift() async {
    final enteredTitle = _adminShiftTitleController.text.trim();
    final title = enteredTitle.isEmpty ? 'General Support Shift' : enteredTitle;

    final List<int> targetDays = _adminSelectedDays.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();

    if (targetDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please check at least one day to publish.'), backgroundColor: UniversalTheme.alertRed),
      );
      return;
    }

    final formattedHours = 'Shift: $_adminStartTime - $_adminEndTime';

    final rowsToInsert = targetDays.map((dayNum) => {
      'day_num': dayNum,
      'title': title,
      'staff': _adminSelectedStaff ?? 'Open',
      'notes': formattedHours,
      'is_event': _adminIsEvent,
      'zone': _adminSelectedZone,
      'location_id': _selectedLocationId,
      ..._tenantFields(),
    }).toList();

    await _supabase.from('shifts').insert(rowsToInsert);
    _adminShiftTitleController.clear();
    
    setState(() {
      _adminSelectedDays.updateAll((key, value) => false);
      _adminSelectedZone = null;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Shift successfully published across ${targetDays.length} days!'), backgroundColor: Colors.green),
    );
  }

  void _deleteShift(String shiftId, String title) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
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

    if (confirm == true) {
      await _supabase.from('shifts').delete().eq('id', shiftId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shift removed from schedule.'), backgroundColor: UniversalTheme.darkSlate),
      );
    }
  }

  Widget _buildSideWorkSection() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('sidework').stream(primaryKey: ['id']).eq('day_num', _selectedDate.day).eq('business_id', widget.businessId),
      builder: (context, snapshot) {
        final allTasks = snapshot.data ?? [];
        final displayedTasks = _isOwner ? allTasks : allTasks.where((t) => t['assigned_to'] == widget.userName).toList();

        return Card(
          color: UniversalTheme.lightCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.brown.shade100)),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.assignment, size: 18, color: UniversalTheme.accent),
                        const SizedBox(width: 6),
                        Text(
                          _isOwner ? 'MASTER SIDE WORK (OWNER VIEW)' : 'YOUR SIDE WORK (${widget.userName.toUpperCase()} VIEW)',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: UniversalTheme.darkSlate, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 20),
                if (displayedTasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('No custom tasks assigned here for today.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 13)),
                  )
                else
                  ...displayedTasks.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5.0),
                      child: Row(
                        children: [
                          Icon(Icons.check_box_outline_blank, size: 18, color: Colors.brown.shade300),
                          const SizedBox(width: 8),
                          Expanded(child: Text(item['task']?.toString() ?? '', style: const TextStyle(fontSize: 14, color: UniversalTheme.darkSlate))),
                          if (_isOwner)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.brown.shade100, borderRadius: BorderRadius.circular(4)),
                              child: Text(item['assigned_to']?.toString() ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: UniversalTheme.darkSlate)),
                            ),
                        ],
                      ),
                    );
                  }),
                if (_isOwner) ...[
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _sideWorkController,
                          decoration: InputDecoration(
                            hintText: 'Add side work task...',
                            hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: UniversalTheme.accent)),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(6)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedAssignee,
                            hint: const Text('Assign', style: TextStyle(fontSize: 12)),
                            style: const TextStyle(fontSize: 12, color: UniversalTheme.darkSlate, fontWeight: FontWeight.bold),
                            onChanged: _isLoadingStaff ? null : (String? newVal) => setState(() => _selectedAssignee = newVal),
                            items: _staffNames.map<DropdownMenuItem<String>>((String val) {
                              return DropdownMenuItem<String>(value: val, child: Text(val));
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addNewSideWork,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: UniversalTheme.darkSlate,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 12)),
                      )
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

  Widget _buildCalendarTab() {
    return ShiftCalendarGrid(
      selectedDate: _selectedDate,
      isFullMonthView: _isFullMonthView,
      onToggleMonthView: () => setState(() => _isFullMonthView = !_isFullMonthView),
      onDateSelected: (date) {
        setState(() => _selectedDate = date);
        _loadAvailabilityForDate(date);
      },
      onChangeMonth: _changeMonth,
      body: Column(
        children: [
          if (_showAckBanner)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: UniversalTheme.alertRed, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Expanded(child: Text('New Schedule is Out! Sign off on your hours.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                  ElevatedButton(
                    onPressed: () => setState(() => _showAckBanner = false),
                    style: ElevatedButton.styleFrom(backgroundColor: UniversalTheme.darkSlate),
                    child: const Text('Acknowledge', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                LocationSelector(
                  businessId: widget.businessId,
                  selectedLocationId: _selectedLocationId,
                  isOwner: _isOwner,
                  onLocationChanged: (id) => setState(() => _selectedLocationId = id),
                ),
                StaffAvailabilityCard(
                  isLoading: _isLoadingAvailability,
                  availabilityForDay: _availabilityForDay,
                  isOwner: _isOwner,
                  userName: widget.userName,
                  myAvailabilityToday: _myAvailabilityToday,
                  isOnVacation: _isOnVacation,
                  onToggleAvailability: _toggleMyAvailability,
                ),
                _buildSideWorkSection(),
                const SizedBox(height: 6),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _supabase.from('shifts').stream(primaryKey: ['id']).eq('day_num', _selectedDate.day).eq('business_id', widget.businessId),
                  builder: (context, snapshot) {
                    var currentShifts = snapshot.data ?? [];
                    if (_selectedLocationId != null) {
                      currentShifts = currentShifts
                          .where((s) => s['location_id'] == null || s['location_id'] == _selectedLocationId)
                          .toList();
                    }
                    final dateIsoStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

                    final approvedLeaves = _allRequests.where((req) =>
                      req['status'] == 'Approved' &&
                      (dateIsoStr == req['start_date'] || dateIsoStr == req['end_date'] ||
                      (DateTime.parse(dateIsoStr).isAfter(DateTime.parse(req['start_date'])) &&
                       DateTime.parse(dateIsoStr).isBefore(DateTime.parse(req['end_date']))))
                    ).toList();

                    if (currentShifts.isEmpty && approvedLeaves.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 40.0),
                        child: Column(
                          children: [
                            Icon(Icons.calendar_today, size: 48, color: Colors.brown.shade200),
                            const SizedBox(height: 8),
                            const Text('No shifts or leaves logged for today!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: [
                        ...approvedLeaves.map((leave) => Card(
                          color: Colors.blue.shade50,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.blue.shade200)),
                          child: ListTile(
                            leading: const Icon(Icons.flight_takeoff, color: Colors.blue),
                            title: Text('${leave['user_name']} ON VACATION', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 14)),
                            subtitle: Text('Status: Authorized Leave Block | ${leave['reason']}', style: const TextStyle(fontSize: 12)),
                          ),
                        )),
                        ...currentShifts.map((shift) {
                          final id = shift['id']?.toString() ?? '';
                          final title = shift['title']?.toString() ?? '';
                          final staff = shift['staff']?.toString() ?? 'Open';
                          if (shift['is_event'] == true) {
                            return _buildEventCard(id, title, staff, '1pm - 5pm');
                          }
                          return _buildShiftCard(
                            shiftId: id,
                            title: title,
                            scheduled: staff,
                            notes: shift['notes']?.toString(),
                            zone: shift['zone']?.toString(),
                            isMyShift: !_isOwner && staff == widget.userName,
                            isClockedIn: _clockedInEntries.containsKey(id),
                            onSwapPressed: () => _handlePostSwap(title, staff),
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

  Widget _buildSwapsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('swaps').stream(primaryKey: ['id']).eq('business_id', widget.businessId).order('created_at', ascending: false),
      builder: (context, snapshot) {
        final allSwaps = snapshot.data ?? [];
        final availableSwaps = allSwaps.where((swap) => (swap['day_num'] as int) >= _selectedDate.day).toList();

        if (availableSwaps.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swap_horizontal_circle, size: 64, color: Colors.black26),
                SizedBox(height: 12),
                Text('No open shifts posted yet.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: availableSwaps.length,
          itemBuilder: (context, index) {
            final swap = availableSwaps[index];
            bool isMine = swap['original_staff'] == widget.userName;
            String status = swap['status']?.toString() ?? 'Available';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              color: UniversalTheme.lightCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.brown.shade100)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(swap['shift_title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: UniversalTheme.darkSlate)),
                          const SizedBox(height: 4),
                          Text('Day: ${swap['day_num']}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                          Text('Posted By: ${swap['original_staff']}', style: const TextStyle(color: Colors.brown, fontStyle: FontStyle.italic, fontSize: 12)),
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
                                : (status == 'Swapped' ? Colors.blue.shade100 : Colors.orange.shade100),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10, 
                              fontWeight: FontWeight.bold, 
                              color: status == 'Available' 
                                  ? Colors.green.shade800 
                                  : (status == 'Swapped' ? Colors.blue.shade800 : Colors.orange.shade800),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_isOwner && status == 'Pending Approval') ...[
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
                                onPressed: () => _processAdminSwapAction(
                                  swap['id'], 'Approved', swap['shift_title'], swap['original_staff'], swap['day_num']
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel, color: UniversalTheme.alertRed, size: 28),
                                onPressed: () => _processAdminSwapAction(
                                  swap['id'], 'Denied', swap['shift_title'], swap['original_staff'], swap['day_num']
                                ),
                              ),
                            ],
                          )
                        ] else if (status == 'Available' && !isMine) ...[
                          ElevatedButton(
                            onPressed: () => _claimShift(swap['id']),
                            style: ElevatedButton.styleFrom(backgroundColor: UniversalTheme.accent, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                            child: const Text('Cover Shift', style: TextStyle(color: Colors.white, fontSize: 11)),
                          ),
                        ],
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTimeOffTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: UniversalTheme.lightCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.brown.shade100)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.edit_calendar, color: UniversalTheme.accent),
                    SizedBox(width: 8),
                    Text('SUBMIT TIME OFF REQUEST', style: TextStyle(fontWeight: FontWeight.bold, color: UniversalTheme.darkSlate)),
                  ],
                ),
                const Divider(height: 24),
                const Text('Step 1: Choose Your Dates:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final DateTime? single = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (single != null) {
                            setState(() => _temporarySelectedRange = DateTimeRange(start: single, end: single));
                          }
                        },
                        icon: const Icon(Icons.looks_one, size: 16),
                        label: const Text('Single Day', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: UniversalTheme.darkSlate,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12)
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _submitMultiDayRequest,
                        icon: const Icon(Icons.date_range, size: 16),
                        label: const Text('Multi-Day Block', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: UniversalTheme.accent, 
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12)
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6), color: Colors.white),
                  child: Text(
                    _temporarySelectedRange == null
                        ? 'No dates selected yet'
                        : _temporarySelectedRange!.start == _temporarySelectedRange!.end
                            ? 'Selected Single Day: ${_temporarySelectedRange!.start.month}/${_temporarySelectedRange!.start.day}/${_temporarySelectedRange!.start.year}'
                            : 'Selected Range: ${_temporarySelectedRange!.start.month}/${_temporarySelectedRange!.start.day} ➡️ ${_temporarySelectedRange!.end.month}/${_temporarySelectedRange!.end.day}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      color: _temporarySelectedRange == null ? Colors.black38 : UniversalTheme.darkSlate,
                      fontSize: 13
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Step 2: Reason / Notes (Optional):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                TextField(
                  controller: _timeOffReasonController,
                  decoration: InputDecoration(
                    hintText: 'Add a short description...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: UniversalTheme.accent)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSyncing ? null : _submitTimeOffRequest,
                    style: ElevatedButton.styleFrom(backgroundColor: UniversalTheme.darkSlate, padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: _isSyncing 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Request to Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text('REQUEST HISTORY & STATUS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _supabase.from('time_off_requests').stream(primaryKey: ['id']).eq('business_id', widget.businessId).order('created_at', ascending: false),
          builder: (context, snapshot) {
            final requests = snapshot.data ?? [];

            if (requests.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(child: Text('No active vacation request history found.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))),
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
                    title: Text('${req['start_date']} to ${req['end_date']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Staff: ${req['user_name']}', style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.bold, fontSize: 11)),
                        Text('Reason: ${req['reason']}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    trailing: _isOwner && req['status'] == 'Pending'
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () => _updateVacationStatus(req['id'], 'Approved')),
                              IconButton(icon: const Icon(Icons.cancel, color: UniversalTheme.alertRed), onPressed: () => _updateVacationStatus(req['id'], 'Denied')),
                            ],
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text(req['status'] ?? 'Pending', style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAdminTab() {
    if (!_isOwner) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person, size: 80, color: UniversalTheme.alertRed),
              const SizedBox(height: 16),
              const Text('ACCESS RESTRICTED', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: UniversalTheme.darkSlate)),
              const SizedBox(height: 8),
              Text('Hey ${widget.userName}, this module requires Owner credentials.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, height: 1.4)),
            ],
          ),
        ),
      );
    }

    List<String> monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: UniversalTheme.lightCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.brown.shade100)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.add_moderator, color: UniversalTheme.accent),
                    SizedBox(width: 8),
                    Text('CREATE NEW SHIFT SLOT', style: TextStyle(fontWeight: FontWeight.bold, color: UniversalTheme.darkSlate)),
                  ],
                ),
                const Divider(height: 24),
                const Text('Shift Title / Role:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 6),
                if (_configuredRoles.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _configuredRoles.contains(_adminShiftTitleController.text.trim())
                            ? _adminShiftTitleController.text.trim()
                            : null,
                        isExpanded: true,
                        hint: const Text('Pick a configured role'),
                        items: _configuredRoles
                            .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            _adminShiftTitleController.text = val;
                            setState(() {});
                          }
                        },
                      ),
                    ),
                  ),
                TextField(
                  controller: _adminShiftTitleController,
                  decoration: InputDecoration(
                    hintText: 'Leave blank for "General Support Shift"',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: UniversalTheme.accent)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Zone / Section:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _adminSelectedZone,
                      isExpanded: true,
                      hint: const Text('No zone (optional)'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('No zone')),
                        ...['Bar', 'Kitchen', 'Floor', 'Support'].map((z) => DropdownMenuItem<String?>(value: z, child: Text(z))),
                      ],
                      onChanged: (val) => setState(() => _adminSelectedZone = val),
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
                          const Text('Assign Slot:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _adminSelectedStaff,
                                isExpanded: true,
                                hint: const Text('Assign Staff'),
                                items: _isLoadingStaff ? [] : <String>['Open', ..._staffNames].map((val) {
                                  return DropdownMenuItem<String>(value: val, child: Text(val));
                                }).toList(),
                                onChanged: _isLoadingStaff ? null : (val) => setState(() => _adminSelectedStaff = val),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          LaborCostPanel(
                            selectedStaff: _adminSelectedStaff,
                            staffRates: _staffRates,
                            shiftHours: _calculateShiftHours(),
                          ),
                          const SizedBox(height: 12),

                          const Text('Start Time:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _adminStartTime,
                                isExpanded: true,
                                items: _timeSlots.map((time) => DropdownMenuItem(value: time, child: Text(time, style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: (val) => setState(() => _adminStartTime = val!),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('End Time:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _adminEndTime,
                                isExpanded: true,
                                items: _timeSlots.map((time) => DropdownMenuItem(value: time, child: Text(time, style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: (val) => setState(() => _adminEndTime = val!),
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
                              const Text('Target Week:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_left, size: 18, color: UniversalTheme.darkSlate),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _changeAdminWeek(-1),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.arrow_right, size: 18, color: UniversalTheme.darkSlate),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _changeAdminWeek(1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Week of: ${monthNames[_adminTargetWeekAnchor.month - 1]} ${_adminTargetWeekAnchor.year}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: UniversalTheme.accent, letterSpacing: 0.3),
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
                              children: _adminSelectedDays.keys.map((dayNum) {
                                return CheckboxListTile(
                                  title: Text(_dayLabels[dayNum] ?? 'Day $dayNum', style: const TextStyle(fontSize: 12, color: UniversalTheme.darkSlate)),
                                  value: _adminSelectedDays[dayNum],
                                  dense: true,
                                  activeColor: UniversalTheme.accent,
                                  contentPadding: EdgeInsets.zero,
                                  onChanged: (bool? val) {
                                    setState(() {
                                      _adminSelectedDays[dayNum] = val ?? false;
                                    });
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
                      value: _adminIsEvent,
                      activeColor: UniversalTheme.accent,
                      onChanged: (val) => setState(() => _adminIsEvent = val!),
                    ),
                    const Text('Mark as Private Catered Event', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: UniversalTheme.darkSlate)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _adminCreateShift,
                    style: ElevatedButton.styleFrom(backgroundColor: UniversalTheme.darkSlate, padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Publish Shifts Live', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: WiSenseSpacing.base),
        CsvTimeCardExporter(
          staffRates: _staffRates,
          disabled: _isSyncing,
        ),
        const SizedBox(height: WiSenseSpacing.base),
        Card(
          color: UniversalTheme.lightCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.brown.shade100),
          ),
          child: ListTile(
            leading: const Icon(Icons.payment, color: UniversalTheme.accent),
            title: const Text(
              'Manage Billing',
              style: TextStyle(fontWeight: FontWeight.bold, color: UniversalTheme.darkSlate),
            ),
            subtitle: const Text(
              'View subscription plan and payment gateway',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: const Icon(Icons.chevron_right, color: UniversalTheme.darkSlate),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BillingPage()),
            ),
          ),
        ),
        Card(
          color: UniversalTheme.lightCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.brown.shade100),
          ),
          child: ListTile(
            leading: const Icon(Icons.person_add, color: UniversalTheme.accent),
            title: const Text('Invite Staff', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Generate invite codes for new team members', style: TextStyle(fontSize: 12, color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InviteManagementScreen())),
          ),
        ),
        Card(
          color: UniversalTheme.lightCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.brown.shade100),
          ),
          child: ListTile(
            leading: const Icon(Icons.badge_outlined, color: UniversalTheme.accent),
            title: const Text('Configure Roles', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Define shift position names for your business', style: TextStyle(fontSize: 12, color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoleConfigScreen())),
          ),
        ),
        Card(
          color: UniversalTheme.lightCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.brown.shade100),
          ),
          child: ListTile(
            leading: const Icon(Icons.workspace_premium, color: UniversalTheme.accent),
            title: const Text('Upgrade Plan', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Compare Free vs Pro features', style: TextStyle(fontSize: 12, color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UpgradeScreen())),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      _buildCalendarTab(),
      _buildSwapsTab(), 
      _buildTimeOffTab(), 
      _buildAdminTab(), 
    ];

    return Scaffold(
      backgroundColor: UniversalTheme.background,
      appBar: AppBar(
        backgroundColor: UniversalTheme.darkSlate,
        elevation: 0,
        title: const Text('Apex Scheduler', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
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
          IconButton(icon: const Icon(Icons.logout, color: Colors.white, size: 20), onPressed: _handleLogOut),
        ],
      ),
      body: Stack(
        children: [
          tabs[_currentIndex],
          _buildInteractiveTutorialOverlay(), 
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
            if (index != 3 && _isOwner) _showTutorial = false;
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

  Widget _buildShiftCard({required String shiftId, required String title, required String scheduled, String? notes, String? zone, bool isMyShift = false, bool isClockedIn = false, required VoidCallback onSwapPressed}) {
    bool isUnassigned = scheduled == 'Open';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: isUnassigned ? const Color(0xFFF9F6F0) : UniversalTheme.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10), 
        side: BorderSide(color: isUnassigned ? UniversalTheme.accent.withValues(alpha: 0.4) : Colors.brown.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: UniversalTheme.darkSlate)),
                      if (zone != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _zoneColor(zone).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: _zoneColor(zone).withValues(alpha: 0.5)),
                          ),
                          child: Text(zone.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _zoneColor(zone), letterSpacing: 1.0)),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(isUnassigned ? Icons.supervised_user_circle_outlined : Icons.account_circle, size: 14, color: isUnassigned ? UniversalTheme.accent : Colors.black54),
                          const SizedBox(width: 4),
                          Text(isUnassigned ? 'OPEN SLOT (UNASSIGNED)' : 'Assigned to: $scheduled', style: TextStyle(color: isUnassigned ? UniversalTheme.accent : Colors.black54, fontSize: 12, fontWeight: isUnassigned ? FontWeight.bold : FontWeight.normal)),
                        ],
                      ),
                      if (notes != null) ...[
                        const SizedBox(height: 6),
                        Text(notes, style: const TextStyle(color: Colors.brown, fontStyle: FontStyle.italic, fontSize: 12)),
                      ]
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    isUnassigned
                        ? ElevatedButton(
                            onPressed: _isOnVacation ? null : () => _claimOpenTemplateShift(shiftId, title),
                            style: ElevatedButton.styleFrom(backgroundColor: _isOnVacation ? Colors.grey.shade300 : Colors.green),
                            child: Text(_isOnVacation ? 'On Vacation' : 'Claim Shift', style: TextStyle(color: _isOnVacation ? Colors.grey : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                            child: const Text('Scheduled', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                    if (_isOwner) ...[
                      const SizedBox(width: 4),
                      IconButton(icon: const Icon(Icons.delete_outline, color: UniversalTheme.alertRed, size: 20), onPressed: () => _deleteShift(shiftId, title)),
                    ],
                  ],
                ),
              ],
            ),
            if (!isUnassigned) ...[
              const Divider(height: 20),
              if (isMyShift) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isClockedIn ? () => _clockOut(shiftId) : () => _clockIn(shiftId),
                    icon: Icon(isClockedIn ? Icons.timer_off_outlined : Icons.timer_outlined, size: 16,
                        color: isClockedIn ? UniversalTheme.alertRed : const Color(0xFF059669)),
                    label: Text(isClockedIn ? 'Clock Out' : 'Clock In',
                        style: TextStyle(fontSize: 12, color: isClockedIn ? UniversalTheme.alertRed : const Color(0xFF059669))),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isClockedIn ? UniversalTheme.alertRed : const Color(0xFF059669)),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              OutlinedButton.icon(
                onPressed: onSwapPressed,
                icon: const Icon(Icons.swap_horiz, size: 16, color: UniversalTheme.darkSlate),
                label: const Text('Post to Swap Board', style: TextStyle(fontSize: 11, color: UniversalTheme.darkSlate)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: UniversalTheme.darkSlate)),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(String shiftId, String tag, String title, String time) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: const Color(0xFFFFF9E6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: UniversalTheme.accent)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tag, style: const TextStyle(color: UniversalTheme.accent, fontWeight: FontWeight.bold, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: UniversalTheme.darkSlate)),
                  Text('Time: $time', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: UniversalTheme.accent), child: const Text('Sign Up', style: TextStyle(color: Colors.white))),
                if (_isOwner) ...[
                  const SizedBox(width: 4),
                  IconButton(icon: const Icon(Icons.delete_outline, color: UniversalTheme.alertRed, size: 20), onPressed: () => _deleteShift(shiftId, title)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveTutorialOverlay() {
    if (!_showTutorial) return const SizedBox.shrink();

    List<String> tutorialTitles = _isOwner 
      ? ["Welcome, ${widget.userName}!", "⚡ Optional Branding", "⏰ Consistent Time Layout", "🗓️ Batch-Publish Week"]
      : ["Welcome to Apex!", "📋 Check Work & Tasks", "🔀 The Swap Board", "🌴 Request Time Off"];

    List<String> tutorialTexts = _isOwner
      ? [
          "I've tailored this layout completely around your coffee bar template operations. Let's run through the manager features in 10 seconds.",
          "You can now completely leave the 'Shift Title' text field blank. If left empty, the scheduler automatically records a 'General Support Shift' to speed up your routine!",
          "Start and end hours are now completely locked into dropdown wheels. This guarantees perfectly uniform formatting on calendar cards and prevents typos.",
          "Check off multiple target checkboxes at once (like Wed through Sun) to instantaneously stamp identical template operations across the entire week!"
        ]
      : [
          "This is your personalized workspace. Let's quickly show you how to manage your shifts, pick up hours, and coordinate with the team.",
          "The main calendar feed shows your scheduled hours. Below each shift card, you will see a master checklist showing any specific custom sidework assigned to you for that shift.",
          "Need to drop a day? Tap 'Post to Swap Board' on your shift card. Your team can see it instantly under the Swaps tab and tap 'Cover Shift' to request it.",
          "Need a future weekend off? Jump over to the Time Off tab, choose your target calendar block, and click submit. Your manager will be notified instantly to sign off on it!"
        ];

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.8),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: UniversalTheme.accent, width: 1.5)),
            color: UniversalTheme.lightCard,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: UniversalTheme.accent),
                      const SizedBox(width: 8),
                      Expanded(child: Text(tutorialTitles[_tutorialStep], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: UniversalTheme.darkSlate))),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(tutorialTexts[_tutorialStep], style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Step ${_tutorialStep + 1} of 4", style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: UniversalTheme.darkSlate),
                        onPressed: () {
                          setState(() {
                            if (_tutorialStep < 3) {
                              _tutorialStep++;
                            } else {
                              _showTutorial = false;
                            }
                          });
                        },
                        child: Text(_tutorialStep < 3 ? "Next" : "Let's Begin", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _syncDataCore() async {
    await _loadScheduleData();
    if (mounted) {
      await _checkFirstTimeStatus();
      await _checkForApprovalNotifications();
    }
  }

  Future<void> _loadScheduleData() async {
    try {
      final data = await _supabase
          .from('time_off_requests')
          .select()
          .order('start_date', ascending: true);
      setState(() => _allRequests = data);
    } catch (e) {
      _showBanner('Error loading vacation logs: $e', UniversalTheme.alertRed);
    }
  }

  Future<void> _checkFirstTimeStatus() async {
    try {
      final data = await _supabase
          .from('profiles')
          .select('first_time_login')
          .eq('email', widget.userEmail)
          .maybeSingle();

      if (data != null && data['first_time_login'] == true) {
        _showFirstTimeGuide();
      }
    } catch (_) {}
  }

  Future<void> _checkForApprovalNotifications() async {
    if (_hasCheckedNotifications) return;
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      final unnotified = await _supabase
          .from('time_off_requests')
          .select()
          .eq('user_id', currentUser.id)
          .eq('notified', false)
          .or('status.eq.Approved,status.eq.Denied');

      for (var request in unnotified) {
        _showNotificationOverlay(
          "Schedule Notice: Your request from ${request['start_date']} to ${request['end_date']} was marked [${request['status']}]."
        );

        await _supabase
            .from('time_off_requests')
            .update({'notified': true}).eq('id', request['id']);
      }
      _hasCheckedNotifications = true;
    } catch (_) {}
  }

  Future<void> _dismissFirstTimeFlag() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;
      
      await _supabase
          .from('profiles')
          .update({'first_time_login': false})
          .eq('id', currentUser.id);
    } catch (_) {}
  }

  Future<void> _submitMultiDayRequest() async {
    final DateTimeRange? picked = await showDateRangePicker(
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

    if (picked != null) {
      setState(() {
        _temporarySelectedRange = picked;
      });
    }
  }

  Future<void> _updateVacationStatus(String id, String targetStatus) async {
    try {
      await _supabase
          .from('time_off_requests')
          .update({'status': targetStatus, 'notified': false})
          .eq('id', id);

      _showBanner('Request updated to $targetStatus', UniversalTheme.darkSlate);
      _loadScheduleData();
    } catch (e) {
      _showBanner('Update failed: $e', UniversalTheme.alertRed);
    }
  }

  void _showOverlapWarningDialog(String start, String end, String reasonText) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: UniversalTheme.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.orange, width: 1.5)),
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
              await _executeDatabaseInsert(start, end, reasonText); 
            }, 
            child: const Text('Submit Anyway', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showNotificationOverlay(String notice) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(notice, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: UniversalTheme.accent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
      ),
    );
  }

  void _showBanner(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }

  void _showFirstTimeGuide() {
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
            Text('Hello ${widget.userName}, let\'s configure your setup:', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const Divider(height: 24, color: Colors.white12),
            _buildGuideRow(Icons.date_range, 'Request blocks of dates smoothly for multi-day vacations.'),
            _buildGuideRow(Icons.notification_important, 'Receive automatic confirmations when an admin approves an entry.'),
            if (widget.userRole == 'Owner')
              _buildGuideRow(Icons.gavel, 'Owner Rights Active: You have administrative oversight to authorize operations.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _dismissFirstTimeFlag();
              Navigator.pop(context);
            },
            child: const Text('Got it, let\'s launch', style: TextStyle(color: UniversalTheme.accent, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildGuideRow(IconData icon, String text) {
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
}