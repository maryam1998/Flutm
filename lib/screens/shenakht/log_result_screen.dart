// lib/screens/shenakht/log_result_screen.dart
import 'package:flutter/material.dart';

import '../../data/shenakht/schemas.dart';
import 'cycle_screen.dart';
import 'shenakht_tab.dart';

class LogResultScreen extends StatefulWidget {
  final String schemaId;
  final CycleSelection selection;
  final VoidCallback onBack;
  final void Function({
    required String reactionType,
    required bool missionDone,
    required String notes,
  }) onDone;

  const LogResultScreen({
    super.key,
    required this.schemaId,
    required this.selection,
    required this.onBack,
    required this.onDone,
  });

  @override
  State<LogResultScreen> createState() => _LogResultScreenState();
}

class _LogResultScreenState extends State<LogResultScreen> {
  String? _reaction;
  bool _missionDone = false;
  final _notes = '';

  @override
  Widget build(BuildContext context) {
    final options = [
      _Option('old', '🔴', 'واکنش قدیمی', 'همون کار قبلی رو کردم',
          const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
      _Option('paused', '🟡', 'مکث کردم', 'قبل از واکنش، صبر کردم',
          const Color(0xFFF59E0B), const Color(0xFFFFFBEB)),
      _Option('new', '🟢', 'پاسخ جدید', 'این بار جور دیگه‌ای عمل کردم',
          const Color(0xFF10B981), const Color(0xFFECFDF5)),
    ];

    return ShenakhtShell(
      title: 'چطور پیش رفت؟',
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
              children: [
                const Text('🎯', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                const Text(
                  'این بار چه اتفاقی افتاد؟',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'صادقانه انتخاب کن — این برای شناخت خودته',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 12, height: 1.8),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: _reaction == o.id ? o.bg : Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => setState(() => _reaction = o.id),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _reaction == o.id
                            ? o.color
                            : const Color(0xFFF0F0F0),
                        width: _reaction == o.id ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: o.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child:
                              Text(o.emoji, style: const TextStyle(fontSize: 24)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.label,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text(o.desc,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF666666))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 14),
          Material(
            color: _missionDone ? const Color(0xFFECFDF5) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => setState(() => _missionDone = !_missionDone),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _missionDone
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF0F0F0),
                    width: _missionDone ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _missionDone
                            ? const Color(0xFF10B981)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _missionDone
                              ? const Color(0xFF10B981)
                              : const Color(0xFFCCCCCC),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: _missionDone
                          ? const Text('✓',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900))
                          : null,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('مأموریت امروز را انجام دادم',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          SizedBox(height: 2),
                          Text('اگه انجامش دادی، این رو تیک بزن',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF666666))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Material(
            color: _reaction == null
                ? const Color(0xFFD1C4B5)
                : SK.primary,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _reaction == null
                  ? null
                  : () => widget.onDone(
                        reactionType: _reaction!,
                        missionDone: _missionDone,
                        notes: _notes,
                      ),
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('✓ ثبت کن',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _Option {
  final String id;
  final String emoji;
  final String label;
  final String desc;
  final Color color;
  final Color bg;
  const _Option(
      this.id, this.emoji, this.label, this.desc, this.color, this.bg);
}
