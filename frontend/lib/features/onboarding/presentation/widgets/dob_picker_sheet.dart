import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:apsbrat_frontend/core/theme/app_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Opens the Day / Month / Year wheel dialog in the middle of the screen.
/// Returns the chosen date, or null if it is dismissed.
Future<DateTime?> showDobSheet(BuildContext context, {DateTime? initial}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: _DobSheet(initial: initial),
    ),
  );
}

class _DobSheet extends StatefulWidget {
  const _DobSheet({this.initial});

  final DateTime? initial;

  @override
  State<_DobSheet> createState() => _DobSheetState();
}

class _DobSheetState extends State<_DobSheet> {
  static const _maroon = Color(0xFF7B1414);
  static const _maroonDark = Color(0xFF4A0C0C);
  static const _tan = Color(0xFFE3C9A4);
  static const _minYear = 1950;
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  late final int _maxYear = DateTime.now().year - 5;
  late int _day;
  late int _month;
  late int _year;
  late final FixedExtentScrollController _dayC;
  late final FixedExtentScrollController _monthC;
  late final FixedExtentScrollController _yearC;

  @override
  void initState() {
    super.initState();
    // Default to today's day and month in the latest allowed year (the wheel
    // cannot go past it), so the picker opens near the newest valid date.
    final now = DateTime.now();
    final init = widget.initial ?? DateTime(now.year - 5, now.month, now.day);
    _year = init.year.clamp(_minYear, _maxYear);
    _month = init.month;
    _day = init.day;
    _dayC = FixedExtentScrollController(initialItem: _day - 1);
    _monthC = FixedExtentScrollController(initialItem: _month - 1);
    _yearC = FixedExtentScrollController(initialItem: _year - _minYear);
  }

  @override
  void dispose() {
    _dayC.dispose();
    _monthC.dispose();
    _yearC.dispose();
    super.dispose();
  }

  int get _daysInMonth => DateUtils.getDaysInMonth(_year, _month);

  DateTime get _selected =>
      DateTime(_year, _month, _day.clamp(1, _daysInMonth));

  int get _age {
    final now = DateTime.now();
    final s = _selected;
    var age = now.year - s.year;
    if (now.month < s.month || (now.month == s.month && now.day < s.day)) {
      age--;
    }
    return age;
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required int selectedIndex,
    required String Function(int) label,
    required ValueChanged<int> onChanged,
  }) {
    return Stack(
      children: [
        _selectionBox(),
        ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: 40,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: onChanged,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: count,
            builder: (context, i) => Center(
              child: Text(
                label(i),
                style: i == selectedIndex
                    ? GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF5C0F13),
                      )
                    : GoogleFonts.playfairDisplay(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF9A9A9A),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The highlighted box behind the selected value. It sits under the wheel so
  /// the number stays visible.
  Widget _selectionBox() {
    return IgnorePointer(
      child: Center(
        child: Container(
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC76D68), width: 1.5),
            color: const Color(0xFFFDECE3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _columnTitle(AppIconData icon, String label) {
    return Column(
      children: [
        HugeIcon(icon: icon, size: 22, color: _maroon),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _maroon,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _columnTitle(HugeIcons.strokeRoundedCalendar01, 'Day'),
                ),
                Expanded(
                  child: _columnTitle(HugeIcons.strokeRoundedNote01, 'Month'),
                ),
                Expanded(
                  child: _columnTitle(
                    HugeIcons.strokeRoundedCalendar01,
                    'Year',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(
                    child: _wheel(
                      controller: _dayC,
                      count: 31,
                      selectedIndex: _day - 1,
                      label: (i) => '${i + 1}',
                      onChanged: (i) => setState(() => _day = i + 1),
                    ),
                  ),
                  Expanded(
                    child: _wheel(
                      controller: _monthC,
                      count: 12,
                      selectedIndex: _month - 1,
                      label: (i) => _months[i],
                      onChanged: (i) => setState(() {
                        _month = i + 1;
                        if (_day > _daysInMonth) _day = _daysInMonth;
                      }),
                    ),
                  ),
                  Expanded(
                    child: _wheel(
                      controller: _yearC,
                      count: _maxYear - _minYear + 1,
                      selectedIndex: _year - _minYear,
                      label: (i) => '${_minYear + i}',
                      onChanged: (i) => setState(() {
                        _year = _minYear + i;
                        if (_day > _daysInMonth) _day = _daysInMonth;
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7EFE4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE6D5BD)),
              ),
              child: Row(
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedCake,
                    size: 30,
                    color: _maroon,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _summary(
                      'Selected Date',
                      DateFormat('d MMMM yyyy').format(selected),
                    ),
                  ),
                  Container(width: 1, height: 36, color: _tan),
                  const SizedBox(width: 14),
                  Expanded(child: _summary('Age', '$_age years')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(selected),
              child: Container(
                width: double.infinity,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_maroon, _maroonDark],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFD4A84A),
                    width: 1.5,
                  ),
                ),
                child: const Text(
                  'Continue  →',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF8A7A6E)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _maroon,
          ),
        ),
      ],
    );
  }
}
