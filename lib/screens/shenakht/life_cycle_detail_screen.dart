// lib/screens/shenakht/life_cycle_detail_screen.dart
import 'package:flutter/material.dart';

import '../../data/shenakht/life_cycles_data.dart';
import 'shenakht_tab.dart';

class LifeCycleDetailScreen extends StatelessWidget {
  final String cycleId;
  final VoidCallback onBack;
  final void Function(String schemaId) onPickSchema;

  const LifeCycleDetailScreen({
    super.key,
    required this.cycleId,
    required this.onBack,
    required this.onPickSchema,
  });

  @override
  Widget build(BuildContext context) {
    final lc = getLifeCycle(cycleId);
    if (lc == null) {
      return ShenakhtShell(
        title: 'چرخه',
        onBack: onBack,
        child: const Center(child: Text('چرخه پیدا نشد')),
      );
    }

    return ShenakhtShell(
      title: lc.categoryLabel,
      onBack: onBack,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── هدر ─────────────────
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: SK.grad,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lc.categoryLabel,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 6),
                Text(lc.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        height: 1.6)),
                const SizedBox(height: 10),
                Text(lc.shortDescription,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.9)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── آیا آشناست؟ ─────────────
          if (lc.examples.isNotEmpty) ...[
            _card(
              '💭 آیا این جمله‌ها برایت آشناست؟',
              children: [
                for (final e in lc.examples)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(8),
                      border: const Border(
                        right: BorderSide(
                            color: Color(0xFFE5E5E5), width: 3),
                      ),
                    ),
                    child: Text('«$e»',
                        style: const TextStyle(
                            fontSize: 14, height: 1.9)),
                  ),
              ],
            ),
          ],

          // ── ریشه ─────────────────
          if (lc.rootWound != null) ...[
            const SizedBox(height: 12),
            _card(
              '🧸 این الگو از کجا آمد؟',
              bg: const Color(0xFFEEF4FF),
              border: const Color(0xFFBFDBFE),
              children: [
                Text(lc.rootWound!,
                    style: const TextStyle(
                        fontSize: 14, height: 1.95)),
              ],
            ),
          ],

          // ── کودکی ────────────────
          if (lc.childhood.isNotEmpty) ...[
            const SizedBox(height: 12),
            _card(
              '🌱 در کودکی چه اتفاقی افتاد؟',
              children: [
                for (final c in lc.childhood)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(
                            color: Color(0xFFA7F3D0), width: 2),
                      ),
                    ),
                    child: Text(c,
                        style: const TextStyle(
                            fontSize: 13.5, height: 1.9)),
                  ),
              ],
            ),
          ],

          // ── چرخه ─────────────────
          if (lc.cycle.isNotEmpty) ...[
            const SizedBox(height: 12),
            _card(
              '🔁 چرخه‌ی این الگو',
              children: [
                for (var i = 0; i < lc.cycle.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(
                            color: SK.primary,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(_faNum(i + 1),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F6F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(lc.cycle[i],
                                style: const TextStyle(
                                    fontSize: 13, height: 1.7)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],

          // ── نفع پنهان ─────────────
          if (lc.hiddenPayoff != null) ...[
            const SizedBox(height: 12),
            _card(
              '🎭 چرا ذهنت ولش نمی‌کنه؟',
              bg: const Color(0xFFFFFBEB),
              border: const Color(0xFFFDE68A),
              children: [
                const Text('هر الگویی که ادامه داره، یک نفع پنهان داره:',
                    style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF78350F))),
                const SizedBox(height: 10),
                for (final p in lc.hiddenPayoff!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•',
                            style: TextStyle(
                                color: Color(0xFFF59E0B),
                                fontWeight: FontWeight.w900)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(p,
                              style: const TextStyle(
                                  fontSize: 13.5, height: 1.9)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],

          // ── هزینه پنهان ────────────
          if (lc.hiddenCost != null) ...[
            const SizedBox(height: 12),
            _card(
              '💔 چه چیزی داری از دست می‌دی؟',
              bg: const Color(0xFFFEF2F2),
              border: const Color(0xFFFECACA),
              children: [
                for (final c in lc.hiddenCost!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•',
                            style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.w900)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(c,
                              style: const TextStyle(
                                  fontSize: 13.5, height: 1.9)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],

          // ── دام‌های فکری ───────────
          if (lc.thinkingTraps != null) ...[
            const SizedBox(height: 12),
            _card(
              '🧠 دام‌های فکری',
              children: [
                for (final t in lc.thinkingTraps!)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(8),
                      border: const Border(
                        right: BorderSide(
                            color: Color(0xFF8B5CF6), width: 3),
                      ),
                    ),
                    child: Text(t,
                        style: const TextStyle(
                            fontSize: 13, height: 1.9)),
                  ),
              ],
            ),
          ],

          // ── علائم بدنی ────────────
          if (lc.bodySignals != null) ...[
            const SizedBox(height: 12),
            _card(
              '🫀 بدنت کِی خبر می‌ده؟',
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in lc.bodySignals!)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCE7F3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(s,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF831843))),
                      ),
                  ],
                ),
              ],
            ),
          ],

          // ── چرا تکرار می‌شود ────────
          if (lc.whyItRepeats.isNotEmpty) ...[
            const SizedBox(height: 12),
            _card(
              '🤔 چرا این چرخه تکرار می‌شود؟',
              bg: const Color(0xFFFEF3C7),
              border: const Color(0xFFFDE68A),
              children: [
                for (final w in lc.whyItRepeats)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $w',
                        style: const TextStyle(
                            fontSize: 13, height: 1.9)),
                  ),
              ],
            ),
          ],

          // ── مراحل شکستن ────────────
          if (lc.breakingStages != null && lc.breakingStages!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [SK.grad1, SK.grad3],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🚀',
                      style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('مراحل شکستن این چرخه',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    Text(
                      '${_faNum(lc.breakingStages!.length)} مرحله',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF666666)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final st in lc.breakingStages!)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFF0F0F0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: SK.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(_faNum(st.n),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(st.title,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text('⏱ ${st.duration}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF666666))),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F7F4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('🎯 هدف: ${st.goal}',
                            style: const TextStyle(
                                fontSize: 12.5, height: 1.7)),
                      ),
                      const SizedBox(height: 10),
                      const Text('اقدام‌ها:',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF666666))),
                      const SizedBox(height: 6),
                      for (final a in st.actions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('• $a',
                              style: const TextStyle(
                                  fontSize: 13, height: 1.85)),
                        ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('✓ نشانه موفقیت: ${st.marker}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF78350F),
                                height: 1.7)),
                      ),
                    ],
                  ),
                ),
              ),
          ],

          // ── هشدار بازگشت ──────────
          if (lc.relapseSigns != null && lc.relapseSigns!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _card(
              '⚠️ نشانه‌های بازگشت',
              bg: const Color(0xFFFEF2F2),
              border: const Color(0xFFFECACA),
              children: [
                for (final s in lc.relapseSigns!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $s',
                        style: const TextStyle(
                            fontSize: 13, height: 1.85)),
                  ),
              ],
            ),
          ],

          // ── آزمایش‌های کوچک ────────
          if (lc.smallExperiments.isNotEmpty) ...[
            const SizedBox(height: 12),
            _card(
              '🧪 آزمایش‌های کوچک امروز',
              bg: const Color(0xFFECFEFF),
              border: const Color(0xFFA5F3FC),
              children: [
                for (final e in lc.smallExperiments)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: const Border(
                        right: BorderSide(
                            color: Color(0xFF06B6D4), width: 3),
                      ),
                    ),
                    child: Text(e,
                        style: const TextStyle(
                            fontSize: 13, height: 1.85)),
                  ),
              ],
            ),
          ],

          // ── جمله‌های خودگویی ────────
          if (lc.selfTalk.isNotEmpty) ...[
            const SizedBox(height: 12),
            _card(
              '🗣️ به خودت این‌ها رو بگو',
              bg: const Color(0xFFF3E8FF),
              border: const Color(0xFFE9D5FF),
              children: [
                for (final s in lc.selfTalk)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: const Border(
                        right: BorderSide(
                            color: Color(0xFF8B5CF6), width: 3),
                      ),
                    ),
                    child: Text('«$s»',
                        style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.9,
                            fontStyle: FontStyle.italic)),
                  ),
              ],
            ),
          ],

          // ── پیام پایانی ────────────
          if (lc.compassionNote != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: SK.grad,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💙', style: TextStyle(fontSize: 24)),
                  const SizedBox(height: 10),
                  Text(lc.compassionNote!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 2)),
                ],
              ),
            ),
          ],

          // ── طرحواره‌های مرتبط ───────
          if (lc.schemas.isNotEmpty) ...[
            const SizedBox(height: 12),
            _card(
              '🔗 این چرخه به این الگوها مربوط است',
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in lc.schemas)
                      Material(
                        color: const Color(0xFFF0F7F4),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: () => onPickSchema(s),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: const Color(0xFFA7F3D0)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('$s ←',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: SK.primary,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _card(
    String title, {
    required List<Widget> children,
    Color? bg,
    Color? border,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg ?? Colors.white,
        border: Border.all(
            color: border ?? const Color(0xFFF0F0F0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

String _faNum(int n) => String.fromCharCodes(
    n.toString().codeUnits.map((c) => (c >= 48 && c <= 57) ? c + 1728 : c));
