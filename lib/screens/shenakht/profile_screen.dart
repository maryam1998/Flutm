// lib/screens/shenakht/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/shenakht/schemas.dart';
import '../../data/shenakht/simple_language.dart';
import '../../data/shenakht/ysq_questions.dart';
import '../../state/shenakht_store.dart';
import 'shenakht_tab.dart';

class ProfileScreen extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onRetake;
  final VoidCallback onPickSchema;

  const ProfileScreen({
    super.key,
    required this.onBack,
    required this.onRetake,
    required this.onPickSchema,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ShenakhtStore>();
    final analysis = store.analysis;

    if (analysis == null) {
      return ShenakhtShell(
        title: 'پروفایل',
        onBack: onBack,
        child: const Center(child: Text('هنوز ارزیابی‌ای انجام نشده')),
      );
    }

    final rec = analysis.recommended;
    final active = [...analysis.high, ...analysis.medium];
    final low = analysis.low;

    return ShenakhtShell(
      title: 'پروفایل الگوهای من',
      onBack: onBack,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (rec != null) _recommendedCard(rec),
          const SizedBox(height: 14),
          _statsRow(analysis),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.only(right: 4, bottom: 10),
            child: Text('الگوهای فعال',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          if (active.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                border: Border.all(color: const Color(0xFFA7F3D0)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'هیچ الگوی فعالی پیدا نشد. یعنی حالت خوبه 🌱',
                style: TextStyle(fontSize: 13, height: 1.9),
              ),
            )
          else
            for (final r in active) _activeCard(context, r),
          if (low.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.only(right: 4, bottom: 10),
              child: Text('سایر الگوها',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF666666))),
            ),
            for (final r in low) _lowItem(context, r),
          ],
          const SizedBox(height: 22),
          OutlinedButton(
            onPressed: onRetake,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('ارزیابی مجدد'),
          ),
          const SizedBox(height: 20),
          const Text(
            'این نتایج یک ارزیابی خودگزارشی است و تشخیص بالینی نیست.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Color(0xFF999999), height: 1.8),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── کارت پیشنهاد شروع ──────────────────────────────
  Widget _recommendedCard(SchemaScore rec) {
    final plain = getPlainName(rec.schemaId) ?? rec.name;
    final schema = findSchemaById(rec.schemaId);
    final pct = rec.percentage;
    final color = rec.priority.color;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: SK.grad,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${rec.priority.emoji}  پیشنهاد شروع',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            plain,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          if (schema != null) ...[
            const SizedBox(height: 4),
            Text(
              schema.nameFa,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 6,
                    backgroundColor: Colors.white24,
                    valueColor:
                        const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_faNum(pct)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => onPickSchema(rec.schemaId),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white30),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'شروع کار روی این الگو',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_back,
                        color: Colors.white70, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── سه آمار بالا ─────────────────────────────────
  Widget _statsRow(YsqAnalysis analysis) {
    return Row(
      children: [
        Expanded(
          child: _statBox(
            count: analysis.high.length,
            label: 'بالا',
            color: const Color(0xFFDC2626),
            bg: const Color(0xFFFEF2F2),
            border: const Color(0xFFFECACA),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statBox(
            count: analysis.medium.length,
            label: 'متوسط',
            color: const Color(0xFFD97706),
            bg: const Color(0xFFFFFBEB),
            border: const Color(0xFFFDE68A),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statBox(
            count: analysis.low.length,
            label: 'پایین',
            color: const Color(0xFF059669),
            bg: const Color(0xFFECFDF5),
            border: const Color(0xFFA7F3D0),
          ),
        ),
      ],
    );
  }

  Widget _statBox({
    required int count,
    required String label,
    required Color color,
    required Color bg,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            _faNum(count),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }

  // ── کارت الگوی فعال ────────────────────────────────
  Widget _activeCard(BuildContext context, SchemaScore r) {
    final schema = findSchemaById(r.schemaId);
    final plain = getPlainName(r.schemaId) ?? schema?.nameFa ?? r.name;
    final oneLiner = getOneLiner(r.schemaId);
    final color = r.priority.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF0F0F0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onPickSchema(r.schemaId),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      plain,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (schema != null) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        schema.nameFa,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF999999),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${r.priority.emoji} ${_faNum(r.percentage)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: r.percentage / 100,
                              minHeight: 4,
                              backgroundColor: const Color(0xFFF0F0F0),
                              valueColor: AlwaysStoppedAnimation(color),
                            ),
                          ),
                          if (oneLiner != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              oneLiner,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF555555),
                                height: 1.7,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── آیتم الگوی پایین ───────────────────────────────
  Widget _lowItem(BuildContext context, SchemaScore r) {
    final schema = findSchemaById(r.schemaId);
    final plain = getPlainName(r.schemaId) ?? schema?.nameFa ?? r.name;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => onPickSchema(r.schemaId),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFF0F0F0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    plain,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Text(
                  '${_faNum(r.percentage)}%',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF999999)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _faNum(int n) => String.fromCharCodes(
    n.toString().codeUnits.map((c) => (c >= 48 && c <= 57) ? c + 1728 : c));
