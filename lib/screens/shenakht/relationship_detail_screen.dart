// lib/screens/shenakht/relationship_detail_screen.dart
import 'package:flutter/material.dart';

import '../../data/shenakht/relationships_data.dart';
import '../../data/shenakht/schemas.dart';
import '../../data/shenakht/simple_language.dart';
import '../../models/shenakht/schema.dart' show Schema;
import 'shenakht_tab.dart';

class RelationshipDetailScreen extends StatelessWidget {
  final String patternId;
  final VoidCallback onBack;
  final void Function(String schemaId) onPickSchema;

  const RelationshipDetailScreen({
    super.key,
    required this.patternId,
    required this.onBack,
    required this.onPickSchema,
  });

  @override
  Widget build(BuildContext context) {
    final p = findAttractionPattern(patternId);
    if (p == null) {
      return ShenakhtShell(
        title: 'الگو',
        onBack: onBack,
        child: const Center(child: Text('الگو پیدا نشد')),
      );
    }

    final related = p.schemas
        .map((id) => findSchemaById(id))
        .whereType<Schema>()
        .toList();

    return ShenakhtShell(
      title: p.shortName,
      onBack: onBack,
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
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(p.shortName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 10),
                Text(p.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        height: 1.6)),
                const SizedBox(height: 12),
                Text(p.boxDescription,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.9)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (related.isNotEmpty) ...[
            _card(
              '🔗 این الگو از ترکیب این طرحواره‌ها ساخته شده',
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in related)
                      Material(
                        color: const Color(0xFFF0F7F4),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: () => onPickSchema(s.id),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: const Color(0xFFA7F3D0)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${getPlainName(s.id) ?? s.nameFa} ←',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: SK.primary,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (p.childhood.isNotEmpty) ...[
            _card(
              '🧸 این الگو از کجا آمد؟',
              bg: const Color(0xFFEEF4FF),
              border: const Color(0xFFBFDBFE),
              children: [
                for (final c in p.childhood)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('• $c',
                        style: const TextStyle(
                            fontSize: 13.5, height: 1.9)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          _card(
            '📖 در زندگی واقعی چطور دیده می‌شه؟',
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
                    right: BorderSide(
                        color: Color(0xFFE5E5E5), width: 3),
                  ),
                ),
                child: Text(p.realLife,
                    style:
                        const TextStyle(fontSize: 14, height: 1.95)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (p.challenges.isNotEmpty) ...[
            _card(
              '⚠️ چالش‌های این رابطه',
              bg: const Color(0xFFFEF2F2),
              border: const Color(0xFFFECACA),
              children: [
                for (final c in p.challenges)
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
            const SizedBox(height: 12),
          ],
          if (p.whatHelps.isNotEmpty) ...[
            _card(
              '✅ چه چیزی کمک می‌کند',
              bg: const Color(0xFFECFDF5),
              border: const Color(0xFFA7F3D0),
              children: [
                for (final h in p.whatHelps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✓',
                            style: TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w900)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(h,
                              style: const TextStyle(
                                  fontSize: 13.5, height: 1.9)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (p.whatHurts.isNotEmpty) ...[
            _card(
              '❌ چه چیزی اوضاع را بدتر می‌کند',
              bg: const Color(0xFFFFFBEB),
              border: const Color(0xFFFDE68A),
              children: [
                for (final h in p.whatHurts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✕',
                            style: TextStyle(
                                color: Color(0xFFF59E0B),
                                fontWeight: FontWeight.w900)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(h,
                              style: const TextStyle(
                                  fontSize: 13.5, height: 1.9)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (p.whatToDoNow.isNotEmpty) ...[
            const SizedBox(height: 8),
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
                  child:
                      const Text('🚀', style: TextStyle(fontSize: 18)),
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
                      '${_faNum(p.whatToDoNow.length)} قدم',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF666666)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < p.whatToDoNow.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border:
                        Border.all(color: const Color(0xFFF0F0F0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: SK.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(_faNum(i + 1),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(p.whatToDoNow[i],
                            style: const TextStyle(
                                fontSize: 14, height: 1.9)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 20),
          if (related.isNotEmpty)
            Material(
              color: SK.primary,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => onPickSchema(related.first.id),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'کار روی ${getPlainName(related.first.id) ?? related.first.nameFa}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
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
        border:
            Border.all(color: border ?? const Color(0xFFF0F0F0)),
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
