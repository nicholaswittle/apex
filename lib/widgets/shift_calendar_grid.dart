import 'package:flutter/material.dart';
import 'package:apex/theme.dart';

class ShiftCalendarGrid extends StatelessWidget {
  final DateTime selectedDate;
  final bool isFullMonthView;
  final VoidCallback onToggleMonthView;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<int> onChangeMonth;
  final ValueChanged<int> onChangeWeek;
  final Widget body;

  const ShiftCalendarGrid({
    super.key,
    required this.selectedDate,
    required this.isFullMonthView,
    required this.onToggleMonthView,
    required this.onDateSelected,
    required this.onChangeMonth,
    required this.onChangeWeek,
    required this.body,
  });

  static const List<String> _shortNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const List<String> _monthNames = [
    'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
    'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
  ];

  static const double _swipeVelocityThreshold = 200;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _swipeNavigator({
    required Widget child,
    required ValueChanged<int> onSwipe,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < _swipeVelocityThreshold) return;
        onSwipe(velocity < 0 ? 1 : -1);
      },
      child: child,
    );
  }

  Widget _buildDayTile(String dayName, DateTime date) {
    final bool isSelected = _isSameDay(selectedDate, date);
    return GestureDetector(
      onTap: () => onDateSelected(date),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? UniversalTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? UniversalTheme.accent : Colors.brown.shade300,
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              dayName,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white : Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              date.day.toString(),
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? Colors.white : UniversalTheme.darkSlate,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullMonthGrid() {
    const List<String> weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final DateTime firstDay = DateTime(selectedDate.year, selectedDate.month, 1);
    final int totalDays = DateTime(selectedDate.year, selectedDate.month + 1, 0).day;
    final int weekdayOffset = firstDay.weekday - 1;

    return _swipeNavigator(
      onSwipe: onChangeMonth,
      child: Container(
        color: UniversalTheme.lightCard,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SELECT DATE FROM CALENDAR',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
                ),
                TextButton.icon(
                  onPressed: onToggleMonthView,
                  icon: const Icon(Icons.view_week, size: 16, color: UniversalTheme.accent),
                  label: const Text('Week View', style: TextStyle(color: UniversalTheme.accent, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weekdays
                  .map((w) => Text(w, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black38)))
                  .toList(),
            ),
            const Divider(),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: totalDays + weekdayOffset,
                itemBuilder: (context, index) {
                  if (index < weekdayOffset) return const SizedBox.shrink();
                  final int dayNum = index - weekdayOffset + 1;
                  final date = DateTime(selectedDate.year, selectedDate.month, dayNum);
                  final bool isSelected = _isSameDay(selectedDate, date);
                  return GestureDetector(
                    onTap: () {
                      onDateSelected(date);
                      onToggleMonthView();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? UniversalTheme.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? UniversalTheme.accent : Colors.grey.shade200,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$dayNum',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : UniversalTheme.darkSlate,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int currentWeekday = selectedDate.weekday;
    final DateTime monday = selectedDate.subtract(Duration(days: currentWeekday - 1));
    final List<DateTime> weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));
    final onNavigate = isFullMonthView ? onChangeMonth : onChangeWeek;

    return Column(
      children: [
        Container(
          color: UniversalTheme.bannerBg,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_left, color: UniversalTheme.darkSlate),
                    onPressed: () => onNavigate(-1),
                  ),
                  GestureDetector(
                    onTap: onToggleMonthView,
                    child: Row(
                      children: [
                        Text(
                          isFullMonthView
                              ? '${_monthNames[selectedDate.month - 1]} ${selectedDate.year}'
                              : '${_monthNames[selectedDate.month - 1]} ${selectedDate.day}, ${selectedDate.year}',
                          style: const TextStyle(
                            letterSpacing: 1.2,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: UniversalTheme.darkSlate,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: UniversalTheme.darkSlate),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_right, color: UniversalTheme.darkSlate),
                    onPressed: () => onNavigate(1),
                  ),
                ],
              ),
              if (!isFullMonthView)
                _swipeNavigator(
                  onSwipe: onChangeWeek,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        7,
                        (i) => _buildDayTile(_shortNames[i], weekDays[i]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: isFullMonthView
              ? _buildFullMonthGrid()
              : _swipeNavigator(
                  onSwipe: onChangeWeek,
                  child: body,
                ),
        ),
      ],
    );
  }
}
