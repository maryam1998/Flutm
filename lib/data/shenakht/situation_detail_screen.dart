// lib/screens/shenakht/situation_detail_screen.dart
import 'package:flutter/material.dart';

import '../../data/shenakht/origins.dart';
import '../../data/shenakht/schemas.dart';
import '../../data/shenakht/simple_language.dart';
import '../../data/shenakht/situations_data.dart';
import 'shenakht_tab.dart';

class SituationDetailScreen extends StatelessWidget {
  final String situationId;
  final VoidCallback onBack;
  final void Function(String schemaId) onPickSchema;

  const SituationDetailScreen({
    super.key,
    required this.situationId,
    required this.onBack,
    required this.onPickSchema,
  });

  @override
  Widget build(BuildContext context) {
    final s = getSituation(situationId);
    if (s == null) {
      return ShenakhtShell(
        title: 'موقعیت',
        onBack: onBack,
        child: const Center(child: Text('موقعیت پیدا نشد')),
      );
    }

    final relatedSchemas = s.schemas
        .map((id) => findSchemaById(id))
        .whereType<Schema>()
        .toList();
    final mainSchema =
        relatedSchemas.isNotEmpty ? relatedSchemas.first : null;
    final mainOrigin = mainSchema != null ? getOrigin(mainSchema.id) : null;

    return ShenakhtShell(
      title: s.categoryLabel,
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
                  child: Text(s.categoryLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 10),
                Text(s.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        height: 1.6)),
                const SizedBox(height: 10),
                const Text(
                  'این موقعیت رو با هم می‌شناسیم — تا بتونی این بار جور دیگه‌ای عمل کنی.',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 13, height: 1.9),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // آیا آشناست؟
          if (s.examples.isNotEmpty) ...[
            _card(
              '💭 آیا این جمله‌ها برایت آشناست؟',
              children: [
                for (final e in s.examples)
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
            const SizedBox(height: 12),
          ],

          // چرخه پنهان
          if (s.cycle.isNotEmpty) ...[
            _card(
              '🔁 چرخه‌ی پنهان این موقعیت',
              children: [
                for (var i = 0; i < s.cycle.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
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
                            child: Text(s.cycle[i],
                                style: const TextStyle(
                                    fontSize: 13, height: 1.7)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // ریشه
          if (mainOrigin != null) ...[
            _card(
              '🧸 این الگو از کجا آمد؟',
              bg: const Color(0xFFEEF4FF),
              border: const Color(0xFFBFDBFE),
              children: [
                Text(mainOrigin.whatChildLearned,
                    style: const TextStyle(
                        fontSize: 14,
                        height: 1.95,
                        fontStyle: FontStyle.italic)),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // الگوهای مرتبط
          if (relatedSchemas.isNotEmpty) ...[
            _card(
              '🔗 این موقعیت با این الگوها گره خورده',
              children: [
                for (var i = 0; i < relatedSchemas.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: i == 0
                          ? const Color(0xFFF0F7F4)
                          : const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () =>
                            onPickSchema(relatedSchemas[i].id),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: i == 0
                                  ? SK.primary
                                  : const Color(0xFFE5E5E5),
                              width: i == 0 ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    getPlainName(
                                            relatedSchemas[i].id) ??
                                        relatedSchemas[i].nameFa,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14),
                                  ),
                                  if (i == 0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2),
                                      decoration: BoxDecoration(
                                        color: SK.primary,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: const Text('اصلی',
                                          style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.white,
                                              fontWeight:
                                                  FontWeight.w700)),
                                    ),
                                  ],
                                ],
                              ),
                              if (relatedSchemas[i].shortDescription.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  relatedSchemas[i].shortDescription,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF666666),
                                      height: 1.5),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // حالا چه کار کنی
          if (s.whatToDo.isNotEmpty) ...[
            _card(
              '🚀 مراحل مواجهه با این موقعیت',
              children: [
                for (var i = 0; i < s.whatToDo.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
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
                          child: Text(s.whatToDo[i],
                              style: const TextStyle(
                                  fontSize: 14, height: 1.9)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // به خودت بگو
          if (s.selfTalk.isNotEmpty) ...[
            _card(
              '🗣️ به خودت این‌ها را بگو',
              bg: const Color(0xFFF3E8FF),
              border: const Color(0xFFE9D5FF),
              children: [
                for (final t in s.selfTalk)
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
                    child: Text('«$t»',
                        style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.9,
                            fontStyle: FontStyle.italic)),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 20),
          if (mainSchema != null)
            Material(
              color: SK.primary,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => onPickSchema(mainSchema.id),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('کار روی این الگو',
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
        border: Border.all(color: border ?? const Color(0xFFF0F0F0)),
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
