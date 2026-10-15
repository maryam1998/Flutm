// ============================================================
// تقویم کوچک شکرگذاری (۱۵ ستونی) — هم‌رنگ دقیق Maghz
// ============================================================
class _MiniCalendar extends StatelessWidget {
  const _MiniCalendar({required this.store});
  final GratitudeStore store;

  // ثابت‌های رنگ دقیق از #grat-root (tamrin-and-beliefs.css)
  static const _surface = Color(0xFFF7F6F1); // --surface
  static const _card = Color(0xFFFFFFFF); // --card
  static const _line = Color(0xFFE7E5DB); // --line
  static const _ink = Color(0xFF000000); // --ink
  static const _muted = Color(0xFF7C8B87); // --muted
  static const _emerald700 = Color(0xFF0F5B53); // --emerald-700
  static const _emerald500 = Color(0xFF178A7C); // --emerald-500
  static const _gold500 = Color(0xFFC9A24B); // --gold-500

  static const _monthOrdinals = [
    'اول', 'دوم', 'سوم', 'چهارم', 'پنجم', 'ششم', 'هفتم',
    'هشتم', 'نهم', 'دهم', 'یازدهم', 'دوازدهم', 'سیزدهم',
  ];

  @override
  Widget build(BuildContext context) {
    final start = store.journeyStart;
    final startDate = _parseKey(start);
    final total = store.journeyDays;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final todayKey =
        '\( {today.year}- \){today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final doneSet = <String>{};
    for (final e in store.entries) {
      if (e.source == 'purchase') continue;
      final k = GratitudeStore.isoToKey(e.iso);
      if (k.isNotEmpty) doneSet.add(k);
    }

    const cols = 15;
    const blockSize = 30; // مثل periodGridHtml وب

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface, // وب: background:var(--surface)
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line), // border:1px solid var(--line)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '📅 تقویم شکرگذاری',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (ctx, box) {
            final cellW = (box.maxWidth - (cols - 1) * 3) / cols;
            final size = cellW.clamp(18.0, 26.0);

            final cells = <Widget>[];
            for (var d = 0; d < total; d++) {
              final date = DateTime(
                startDate.year,
                startDate.month,
                startDate.day + d,
              );
              final key =
                  '\( {date.year}- \){date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final j = toJalaali(date.year, date.month, date.day);
              final has = doneSet.contains(key);
              final future = date.isAfter(todayDate);
              final isToday = key == todayKey;
              final monthEnd = (d % blockSize == blockSize - 1) || (d == total - 1);

              // هدر ماه هر ۳۰ روز (مثل .mini-cal-month وب)
              if (d % blockSize == 0) {
                final endIdx = (d + blockSize - 1).clamp(0, total - 1);
                final endDate = DateTime(
                  startDate.year,
                  startDate.month,
                  startDate.day + endIdx,
                );
                final jEnd = toJalaali(endDate.year, endDate.month, endDate.day);
                final monthIdx = d \~/ blockSize;
                final ord = monthIdx < _monthOrdinals.length
                    ? _monthOrdinals[monthIdx]
                    : toFa(monthIdx + 1);
                cells.add(
                  SizedBox(
                    width: box.maxWidth,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: d == 0 ? 0 : 8,
                        bottom: 3,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ماه $ord',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          Text(
                            '${toFa(j.jd)} ${kJalaliMonths[j.jm - 1]} تا ${toFa(jEnd.jd)} ${kJalaliMonths[jEnd.jm - 1]}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // رنگ احساس غالب → حلقه ۲px (box-shadow وب)
              final hexColor = store.dominantEmotionColorForDay(key);
              Color? emotionRing;
              if (hexColor != null) {
                try {
                  final h = hexColor.replaceFirst('#', '');
                  emotionRing = Color(int.parse('FF$h', radix: 16));
                } catch (_) {}
              }

              cells.add(
                GestureDetector(
                  onTap: has
                      ? () => _openDayEmotions(context, store, key)
                      : null,
                  child: Opacity(
                    // .mini-cal-day.future { opacity:.3 }
                    opacity: future ? 0.3 : 1.0,
                    child: Container(
                      width: size,
                      height: size,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4), // وب: 4px
                        // .done → linear-gradient(135deg, emerald-700, emerald-500)
                        gradient: has
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [_emerald700, _emerald500],
                              )
                            : null,
                        color: has ? null : Colors.transparent,
                        // خالی: inset line | امروز: outline emerald-500
                        border: Border.all(
