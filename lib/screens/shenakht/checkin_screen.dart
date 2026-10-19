// lib/screens/shenakht/checkin_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/shenakht/schemas.dart';
import '../../data/shenakht/simple_language.dart';
import '../../state/shenakht_store.dart';
import 'shenakht_tab.dart';

class CheckinScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onDone;

  const CheckinScreen({
    super.key,
    required this.onBack,
    required this.onSkip,
    required this.onDone,
  });

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  int _step = 0;
  String? _mood;
  String? _schemaId;
  final _note = '';

  @override
  Widget build(BuildContext context) {
    if (_step == 0) return _moodStep();
    if (_step == 1) return _schemaStep();
    return _noteStep();
  }

  Widget _moodStep() {
    final moods = [
      _Mood('good', '😊', 'خوب', 'امروز حالت خوبه — بریم سراغ الگوها',
          const Color(0xFF27AE60)),
      _Mood('meh', '😐', 'متوسط', 'امروز متوسطه — با هم ببینیم چی می‌شه',
          const Color(0xFFF39C12)),
      _Mood('hard', '😔', 'سخت', 'امروز سخته — با هم آروم می‌ریم جلو',
          const Color(0xFFE74C3C)),
    ];

    return ShenakhtShell(
      title: 'صبح بخیر',
      onBack: widget.onBack,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: SK.grad,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_todayFa(),
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                const Text('امروز چه حالی داری؟',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.5)),
                const SizedBox(height: 8),
                const Text('این هفته بیشتر چه چیزی را لازم داری؟',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.9)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final m in moods)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _mood = m.id;
                      _step = 1;
                    });
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: const Color(0xFFF0F0F0)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: m.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Text(m.emoji,
                              style: const TextStyle(fontSize: 28)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.label,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text(m.sub,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF666666),
                                      height: 1.6)),
                            ],
                          ),
                        ),
                        const Text('←',
                            style: TextStyle(
                                fontSize: 18, color: Color(0xFFCCCCCC))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: widget.onSkip,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('رد کن، بعداً'),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _schemaStep() {
    final store = context.read<ShenakhtStore>();
    final active = store.analysis?.active ?? [];

    return ShenakhtShell(
      title: 'صبح بخیر',
      onBack: () => setState(() => _step = 0),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('کدام الگو امروز فعال‌تره؟',
              style:
                  TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('اگر مطمئن نیستی، می‌تونی رد کنی.',
              style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
          const SizedBox(height: 16),
          if (active.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                  'هنوز ارزیابی‌ای انجام نشده — بعداً دوباره امتحان کن.',
                  style: TextStyle(fontSize: 13, height: 1.8)),
            )
          else
            for (final score in active)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: _schemaId == score.schemaId
                      ? const Color(0xFFF0F7F4)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => setState(
                        () => _schemaId = score.schemaId),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _schemaId == score.schemaId
                              ? SK.primary
                              : const Color(0xFFF0F0F0),
                          width: _schemaId == score.schemaId ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              getPlainName(score.schemaId) ??
                                  score.name,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text('${_faNum(score.percentage)}%',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF999999))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _schemaId = null;
                    _step = 2;
                  }),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('مطمئن نیستم'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Material(
                  color: _schemaId == null
                      ? const Color(0xFFD1C4B5)
                      : SK.primary,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _schemaId == null
                        ? null
                        : () => setState(() => _step = 2),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Text('بعدی',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _noteStep() {
    return ShenakhtShell(
      title: 'صبح بخیر',
      onBack: () => setState(() => _step = 1),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: SK.grad,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('خلاصه‌ی امروز',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(_moodEmoji(_mood),
                        style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Text(_moodLabel(_mood),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFF0F0F0)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'ثبت شد. حالا بذار امروز یه قدم کوچیک برداریم.',
              style: TextStyle(fontSize: 14, height: 1.9),
            ),
          ),
          const SizedBox(height: 20),
          Material(
            color: SK.primary,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () async {
                await context.read<ShenakhtStore>().addCheckIn(
                      mood: _mood ?? 'meh',
                      schemaId: _schemaId,
                      note: _note,
                    );
                widget.onDone();
              },
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('✓ ثبت کن و ادامه',
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

  String _moodEmoji(String? m) {
    if (m == 'good') return '😊';
    if (m == 'hard') return '😔';
    return '😐';
  }

  String _moodLabel(String? m) {
    if (m == 'good') return 'خوب';
    if (m == 'hard') return 'سخت';
    return 'متوسط';
  }

  String _todayFa() {
    final d = DateTime.now();
    const months = [
      'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
    ];
    return '${_faNum(d.day)} ${months[d.month - 1]}';
  }
}

class _Mood {
  final String id;
  final String emoji;
  final String label;
  final String sub;
  final Color color;
  const _Mood(this.id, this.emoji, this.label, this.sub, this.color);
}

String _faNum(int n) => String.fromCharCodes(
    n.toString().codeUnits.map((c) => (c >= 48 && c <= 57) ? c + 1728 : c));
