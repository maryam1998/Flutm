import 'package:flutter/material.dart';

import '../models/future_version.dart';
import 'format_bar.dart';

class MiniCalendar90 extends StatelessWidget {
  final FutureVersion? version;
  final int totalDays;
  final String Function(DateTime) dayKeyOf;
  final bool Function(DateTime) isFuture;
  final void Function(String dayKey)? onDayTap;
  final String? selectedKey;

  const MiniCalendar90({
    super.key,
    required this.version,
    required this.totalDays,
    required this.dayKeyOf,
    required this.isFuture,
    this.onDayTap,
    this.selectedKey,
  });

  static const _monthOrdinals = [
    'اول', 'دوم', 'سوم', 'چهارم', 'پنجم', 'ششم', 'هفتم',
    'هشتم', 'نهم', 'دهم', 'یازدهم', 'دوازدهم', 'سیزدهم'
  ];
  static const _jalaliMonths = [
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
  ];

  static String faDateFull(DateTime d) {
    try {
      final p = new DateTimeFormat('fa-IR-u-ca-persian').format(d);
      return p;
    } catch (_) {
      return '${d.year}/${d.month}/${d.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (version == null) return const SizedBox.shrink();

    final start = _parseKey(version!.startDate);
    final readSet = version!.readDays.toSet();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayKey = _key(today);

    final cells = <Widget>[];
    for (var d = 0; d < totalDays; d++) {
      final date = DateTime(start.year, start.month, start.day + d);
      final key = dayKeyOf(date);
      final has = readSet.contains(key);
      final future = isFuture(date);
      final isToday = key == todayKey;
      final monthEnd = (d % 30 == 29) || (d == totalDays - 1);
      final isSelected = key == selectedKey;

      if (d % 30 == 0) {
        final endDate = DateTime(start.year, start.month,
            start.day + (d + 29).clamp(0, totalDays - 1));
        cells.add(_monthHeader(
          monthIndex: d ~/ 30,
          fromDate: date,
          toDate: endDate,
        ));
      }

      cells.add(_dayCell(
        dayNum: d + 1,
        has: has,
        isToday: isToday,
        isFuture: future,
        monthEnd: monthEnd,
        isSelected: isSelected,
        onTap: onDayTap != null ? () => onDayTap!(key) : null,
      ));
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBeliefsCream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBeliefsBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('📅 پیشرفت روزانه',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: kBeliefsInk,
                  )),
              const Spacer(),
              Text(
                '${_toFa(readSet.length.clamp(0, totalDays))} از ${_toFa(totalDays)}',
                style: const TextStyle(fontSize: 11, color: kBeliefsMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: totalDays > 0 ? (readSet.length / totalDays).clamp(0.0, 1.0) : 0,
              minHeight: 4,
              color: kBeliefsGold,
              backgroundColor: kBeliefsCream,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (ctx, box) {
            const cols = 15;
            const gap = 3.0;
            final cellW = (box.maxWidth - (cols - 1) * gap) / cols;
            final size = cellW.clamp(18.0, 26.0);

            final rows = <Widget>[];
            var i = 0;
            while (i < cells.length) {
              final row = <Widget>[];
              while (row.length < cols && i < cells.length) {
                row.add(cells[i]);
                i++;
              }
              rows.add(Padding(
                padding: const EdgeInsets.only(bottom: gap),
                child: Row(
                  children: row
                      .map((c) => Padding(
                            padding: const EdgeInsets.only(left: gap),
                            child: c,
                          ))
                      .toList(),
                ),
              ));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows,
            );
          }),
        ],
      ),
    );
  }

  Widget _monthHeader({
    required int monthIndex,
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Row(
          children: [
            Text(
              'ماه ${_monthOrdinals[monthIndex] ?? _toFa(monthIndex + 1)}',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: kBeliefsInk,
              ),
            ),
            const Spacer(),
            Text(
              '${_shortDate(fromDate)} تا ${_shortDate(toDate)}',
              style: const TextStyle(fontSize: 10, color: kBeliefsMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCell({
    required int dayNum,
    required bool has,
    required bool isToday,
    required bool isFuture,
    required bool monthEnd,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
       opacity: isFuture ? 0.3 : 1.0,
       child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          gradient: has
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F5B53), Color(0xFF178A7C)],
                )
              : null,
          border: Border.all(
            color: isSelected
                ? kBeliefsInk
                : (isToday
                    ? const Color(0xFF178A7C)
                    : (has ? Colors.transparent : kBeliefsBorder)),
            width: isSelected ? 2 : (isToday ? 1.6 : 1),
          ),
          boxShadow: monthEnd
              ? const [
                  BoxShadow(
                    color: kBeliefsGold,
                    offset: Offset(0, 2),
                    blurRadius: 0,
                  )
                ]
              : null,
        ),
        child: has
            ? const Icon(Icons.check, size: 13, color: Colors.white)
            : Text(
                _toFa(dayNum),
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: isFuture
                      ? kBeliefsMuted.withValues(alpha: 0.4)
                      : kBeliefsInk,
                ),
              ),
      ),
      ),
    );
  }

  static DateTime _parseKey(String k) {
    final p = k.split('-').map((e) => int.tryParse(e) ?? 1).toList();
    if (p.length != 3) return DateTime.now();
    return DateTime(p[0], p[1], p[2]);
  }

  static String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

  static String _shortDate(DateTime d) {
    final j = _toJalali(d.year, d.month, d.day);
    return '${_toFa(j.$3)} ${_jalaliMonths[j.$2 - 1]}';
  }

  /// تبدیل گرگوری به جلالی
  static (int, int, int) _toJalali(int gy, int gm, int gd) {
    const gDaysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    final gy2 = (gm > 2) ? gy + 1 : gy;
    var days = 355666 + 365 * gy + ((gy2 + 3) ~/ 4) - ((gy2 + 99) ~/ 100) +
        ((gy2 + 399) ~/ 400) + gd;
    for (var i = 0; i < gm - 1; i++) {
      days += gDaysInMonth[i];
    }
    var jy = -1595 + 33 * (days ~/ 12053);
    days %= 12053;
    jy += 4 * (days ~/ 1461);
    days %= 1461;
    if (days > 365) {
      jy += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }
    final jm = (days < 186) ? 1 + days ~/ 31 : 7 + (days - 186) ~/ 30;
    final jd = 1 + ((days < 186) ? days % 31 : (days - 186) % 30);
    return (jy, jm, jd);
  }

  static String _toFa(int n) => n.toString().replaceAllMapped(
        RegExp(r'\d'),
        (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m.group(0)!)],
      );
}

/// wrapper ساده برای فرمت فارسی
class DateTimeFormat {
  final String locale;
  const DateTimeFormat(this.locale);
  String format(DateTime d) {
    try {
      return '${d.year}/${d.month}/${d.day}';
    } catch (_) {
      return '';
    }
  }
}
