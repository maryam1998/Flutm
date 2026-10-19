// lib/screens/shenakht/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/shenakht_store.dart';
import 'shenakht_tab.dart';

class CalendarScreen extends StatefulWidget {
  final VoidCallback onBack;
  const CalendarScreen({super.key, required this.onBack});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ShenakhtStore>();
    final entries = store.entries;
    final checkins = store.checkins;

    final today = _startOfDay(DateTime.now());
    final days = <_DayData>[];
    for (var i = 29; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final key = _key(d);
      final dayEntries =
          entries.where((e) => _key(_startOfDay(e.createdAt)) == key).toList();
      String dayMood = 'none';
      for (final c in checkins) {
        if (_key(_startOfDay(c.createdAt)) == key) {
          dayMood = c.mood;
          break;
        }
      }
      days.add(_DayData(
        date: d,
        dayNumber: d.day,
        mood: dayMood,
        activations: dayEntries.length,
        hasWin: dayEntries.any((e) =>
            e.reactionType == 'paused' ||
            e.reactionType == 'new' ||
            e.missionDone),
      ));
    }

    final totalActivations = days.fold<int>(0, (n, d) => n + d.activations);
    final recordedDays = days.where((d) => d.mood != 'none').length;
    final winDays = days.where((d) => d.hasWin).length;

    return ShenakhtShell(
      title: 'تقویم',
      onBack: widget.onBack,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: SK.grad,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('📅', style: TextStyle(fontSize: 28)),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('۳۰ روز اخیر',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 11)),
                        Text('سفر تو',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                        child: _stat(
                            label: 'فعال شدن', value: totalActivations)),
                    const SizedBox(width: 8),
                    Expanded(
                        child:
                            _stat(label: 'روز ثبت', value: recordedDays)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _stat(
                            label: '⭐ برد', value: winDays, icon: true)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFF0F0F0)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('نمای روزانه',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 12),
                _grid(days),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFFEEEEEE)),
                const SizedBox(height: 8),
                const Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _Legend(color: Color(0xFF27AE60), label: 'خوب'),
                    _Legend(color: Color(0xFFF39C12), label: 'متوسط'),
                    _Legend(color: Color(0xFFE74C3C), label: 'سخت'),
                    _Legend(color: Color(0xFFF0F0F0), label: 'بدون ثبت'),
                  ],
                ),
              ],
            ),
          ),
          if (_selected != null) ...[
            const SizedBox(height: 14),
            _selectedCard(),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: SK.grad,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'هر روزی که ثبت کردی،\nیه قدم به شناخت خودت نزدیک‌تر شدی.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white, fontSize: 13, height: 1.9),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _stat({required String label, required int value, bool icon = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            icon ? '⭐ ${_faNum(value)}' : _faNum(value),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(label,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _grid(List<_DayData> days) {
    final rows = <List<_DayData>>[];
    for (var i = 0; i < days.length; i += 7) {
      rows.add(days.sublist(i, (i + 7).clamp(0, days.length)));
    }

    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: i < row.length
                        ? _dayCell(row[i])
                        : const SizedBox(height: 40),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dayCell(_DayData d) {
    final color = _moodColor(d.mood);
    final selected = _selected != null && _key(_selected!) == _key(d.date);

    return Padding(
      padding: const EdgeInsets.all(2),
      child: GestureDetector(
        onTap: () => setState(() => _selected = selected ? null : d.date),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: selected
                  ? Border.all(color: SK.primary, width: 2)
                  : null,
            ),
            alignment: Alignment.center,
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _faNum(d.dayNumber),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: d.mood == 'none'
                              ? const Color(0xFF999999)
                              : Colors.white,
                        ),
                      ),
                      if (d.activations > 0)
                        Text(
                          _faNum(d.activations),
                          style: TextStyle(
                            fontSize: 9,
                            color: d.mood == 'none'
                                ? const Color(0xFF999999)
                                : Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
                if (d.hasWin)
                  const Positioned(
                    top: 2,
                    left: 2,
                    child: Text('⭐', style: TextStyle(fontSize: 8)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectedCard() {
    final d = _selected!;
    final store = context.read<ShenakhtStore>();
    final key = _key(d);
    final dayEntries = store.entries
        .where((e) => _key(_startOfDay(e.createdAt)) == key)
        .toList();
    String dayMood = 'none';
    for (final c in store.checkins) {
      if (_key(_startOfDay(c.createdAt)) == key) {
        dayMood = c.mood;
        break;
      }
    }

    final moodEmoji = dayMood == 'good'
        ? '😊'
        : dayMood == 'hard'
            ? '😔'
            : dayMood == 'meh'
                ? '😐'
                : '—';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F4),
        border: Border.all(color: const Color(0xFFA7F3D0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_faNum(d.day)} / ${_faNum(d.month)}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(moodEmoji, style: const TextStyle(fontSize: 28)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                    label: 'فعال شدن الگو',
                    value: _faNum(dayEntries.length)),
              ),
              if (dayEntries.any((e) =>
                  e.reactionType == 'paused' ||
                  e.reactionType == 'new' ||
                  e.missionDone))
                Expanded(
                  child: _miniStat(label: '⭐ لحظه‌ی برد', value: '✓'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF666666))),
        ],
      ),
    );
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Color _moodColor(String mood) {
    switch (mood) {
      case 'good':
        return const Color(0xFF27AE60);
      case 'meh':
        return const Color(0xFFF39C12);
      case 'hard':
        return const Color(0xFFE74C3C);
      default:
        return const Color(0xFFF0F0F0);
    }
  }
}

class _DayData {
  final DateTime date;
  final int dayNumber;
  final String mood;
  final int activations;
  final bool hasWin;
  const _DayData({
    required this.date,
    required this.dayNumber,
    required this.mood,
    required this.activations,
    required this.hasWin,
  });
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF666666))),
      ],
    );
  }
}

String _faNum(int n) => String.fromCharCodes(
    n.toString().codeUnits.map((c) => (c >= 48 && c <= 57) ? c + 1728 : c));
