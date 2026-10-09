import 'package:flutter/material.dart';

const _kMonthNames = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

const _kShortMonthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

const _kDayNames = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];

/// Fungsi panggil master modal rentang tanggal.
/// Mengembalikan [DateTimeRange] jika pengguna menekan Terapkan, atau `null` jika dibatalkan.
Future<DateTimeRange?> showAppDateRangePicker(
  BuildContext context, {
  required DateTime initialStartDate,
  required DateTime initialEndDate,
  DateTime? firstDate,
  DateTime? lastDate,
  String title = 'Pilih Rentang Tanggal',
}) async {
  return showModalBottomSheet<DateTimeRange>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AppDateRangePickerSheet(
      initialStartDate: initialStartDate,
      initialEndDate: initialEndDate,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime(2030),
      title: title,
    ),
  );
}

class _AppDateRangePickerSheet extends StatefulWidget {
  final DateTime initialStartDate;
  final DateTime initialEndDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;

  const _AppDateRangePickerSheet({
    required this.initialStartDate,
    required this.initialEndDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
  });

  @override
  State<_AppDateRangePickerSheet> createState() =>
      _AppDateRangePickerSheetState();
}

class _AppDateRangePickerSheetState extends State<_AppDateRangePickerSheet> {
  late DateTime _startDate;
  late DateTime _endDate;
  late DateTime _displayedMonth;

  // Mode pemilihan: 'start' = mengubah tanggal mulai, 'end' = mengubah tanggal selesai
  String _activeTarget = 'start';

  @override
  void initState() {
    super.initState();
    _startDate = DateTime(
      widget.initialStartDate.year,
      widget.initialStartDate.month,
      widget.initialStartDate.day,
    );
    _endDate = DateTime(
      widget.initialEndDate.year,
      widget.initialEndDate.month,
      widget.initialEndDate.day,
    );
    _displayedMonth = DateTime(_startDate.year, _startDate.month, 1);
  }

  String _formatDisplay(DateTime d) {
    return '${d.day} ${_kShortMonthNames[d.month - 1]} ${d.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _applyPreset(String preset) {
    final now = DateTime.now();
    DateTime s;
    DateTime e;

    switch (preset) {
      case 'today':
        s = DateTime(now.year, now.month, now.day);
        e = s;
        break;
      case '7days':
        e = DateTime(now.year, now.month, now.day);
        s = e.subtract(const Duration(days: 6));
        break;
      case 'thisMonth':
        s = DateTime(now.year, now.month, 1);
        final lastDay = DateTime(now.year, now.month + 1, 0).day;
        e = DateTime(now.year, now.month, lastDay);
        break;
      case 'lastMonth':
        s = DateTime(now.year, now.month - 1, 1);
        final lastDay = DateTime(now.year, now.month, 0).day;
        e = DateTime(now.year, now.month - 1, lastDay);
        break;
      default:
        return;
    }

    setState(() {
      _startDate = s;
      _endDate = e;
      _displayedMonth = DateTime(s.year, s.month, 1);
      _activeTarget = 'start';
    });
  }

  void _onDayTapped(DateTime day) {
    setState(() {
      if (_activeTarget == 'start') {
        _startDate = day;
        if (_endDate.isBefore(day)) {
          _endDate = day;
        }
        _activeTarget = 'end';
      } else {
        if (day.isBefore(_startDate)) {
          _startDate = day;
          _activeTarget = 'end';
        } else {
          _endDate = day;
          _activeTarget = 'start';
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle indicator
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 20, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 12, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 4),

          // Quick Presets Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetChip('Hari Ini', () => _applyPreset('today')),
                const SizedBox(width: 8),
                _buildPresetChip('7 Hari', () => _applyPreset('7days')),
                const SizedBox(width: 8),
                _buildPresetChip('Bulan Ini', () => _applyPreset('thisMonth')),
                const SizedBox(width: 8),
                _buildPresetChip('Bulan Lalu', () => _applyPreset('lastMonth')),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Two Target Date Selector Boxes (Mulai ➔ Selesai)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _activeTarget = 'start'),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _activeTarget == 'start'
                          ? const Color(0xFFEEF2FF)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _activeTarget == 'start'
                            ? const Color(0xFF4F46E5)
                            : const Color.fromRGBO(15, 23, 42, 0.08),
                        width: _activeTarget == 'start' ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mulai',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _activeTarget == 'start'
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatDisplay(_startDate),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: _activeTarget == 'start'
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 16, color: Color(0xFF64748B)),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _activeTarget = 'end'),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _activeTarget == 'end'
                          ? const Color(0xFFEEF2FF)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _activeTarget == 'end'
                            ? const Color(0xFF4F46E5)
                            : const Color.fromRGBO(15, 23, 42, 0.08),
                        width: _activeTarget == 'end' ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selesai',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _activeTarget == 'end'
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatDisplay(_endDate),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: _activeTarget == 'end'
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Month Switcher Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 22),
                onPressed: () {
                  setState(() {
                    _displayedMonth = DateTime(
                      _displayedMonth.year,
                      _displayedMonth.month - 1,
                      1,
                    );
                  });
                },
              ),
              Text(
                '${_kMonthNames[_displayedMonth.month - 1]} ${_displayedMonth.year}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 22),
                onPressed: () {
                  setState(() {
                    _displayedMonth = DateTime(
                      _displayedMonth.year,
                      _displayedMonth.month + 1,
                      1,
                    );
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Day Names Row (Min, Sen, Sel, ...)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _kDayNames.map((d) {
              return SizedBox(
                width: 38,
                child: Center(
                  child: Text(
                    d,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Calendar Grid
          _buildMonthGrid(),
          const SizedBox(height: 18),

          // Bottom Action Buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color.fromRGBO(15, 23, 42, 0.12),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Batal',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(
                        context,
                        DateTimeRange(start: _startDate, end: _endDate),
                      );
                    },
                    child: const Text(
                      'Terapkan',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.06)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthGrid() {
    final year = _displayedMonth.year;
    final month = _displayedMonth.month;

    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startingWeekday = firstDayOfMonth.weekday % 7; // 0 = Minggu

    final List<Widget> dayCells = [];

    // Empty cells before start of month
    for (int i = 0; i < startingWeekday; i++) {
      dayCells.add(const SizedBox(width: 38, height: 38));
    }

    // Days in current month
    for (int d = 1; d <= daysInMonth; d++) {
      final currentDay = DateTime(year, month, d);

      final isStart = _isSameDay(currentDay, _startDate);
      final isEnd = _isSameDay(currentDay, _endDate);
      final isInRange =
          currentDay.isAfter(_startDate) && currentDay.isBefore(_endDate);

      Color textColor = const Color(0xFF0F172A);
      BoxDecoration? decoration;

      if (isStart || isEnd) {
        decoration = BoxDecoration(
          color: const Color(0xFF4F46E5),
          borderRadius: BorderRadius.circular(10),
        );
        textColor = Colors.white;
      } else if (isInRange) {
        decoration = BoxDecoration(
          color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        );
        textColor = const Color(0xFF4F46E5);
      }

      dayCells.add(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onDayTapped(currentDay),
          child: Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: decoration,
            alignment: Alignment.center,
            child: Text(
              '$d',
              style: TextStyle(
                fontSize: 13,
                fontWeight: (isStart || isEnd)
                    ? FontWeight.w900
                    : (isInRange ? FontWeight.w800 : FontWeight.w600),
                color: textColor,
              ),
            ),
          ),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.start,
      spacing: (MediaQuery.of(context).size.width - 40 - (38 * 7)) / 6 > 0
          ? (MediaQuery.of(context).size.width - 40 - (38 * 7)) / 6
          : 6,
      children: dayCells,
    );
  }
}
