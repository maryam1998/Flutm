// lib/screens/shenakht/cycle_summary_screen.dart
import 'package:flutter/material.dart';

import '../../data/shenakht/schemas.dart';
import '../../models/shenakht/schema.dart' show SchemaItem;
import 'cycle_screen.dart';
import 'shenakht_tab.dart';

class CycleSummaryScreen extends StatelessWidget {
  final String schemaId;
  final CycleSelection selection;
  final VoidCallback onBack;
  final VoidCallback onViewOrigin;
  final VoidCallback onContinue;

  const CycleSummaryScreen({
    super.key,
    required this.schemaId,
    required this.selection,
    required this.onBack,
    required this.onViewOrigin,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final schema = findSchemaById(schemaId);
    if (schema == null) {
      return ShenakhtShell(
        title: 'خلاصه',
        onBack: onBack,
        child: const Center(child: Text('طرحواره پیدا نشد')),
      );
    }

    final sections = [
      _Section(
        emoji: '⚡',
        label: 'محرک‌ها',
        color: const Color(0xFFF59E0B),
        values: _findMany(schema.triggers, selection.triggerIds),
      ),
      _Section(
        emoji: '💭',
        label: 'فکرهای خودکار',
        color: const Color(0xFF8B5CF6),
        values: _findMany(schema.automaticThoughts, selection.thoughtIds),
      ),
      _Section(
        emoji: '💧',
        label: 'احساس‌ها',
        color: const Color(0xFF3B82F6),
        values: _findMany(schema.emotionalSignals, selection.emotionIds),
      ),
      _Section(
        emoji: '🔁',
        label: 'واکنش‌های قدیمی',
        color: const Color(0xFFEF4444),
        values: _findMany(schema.behavioralPatterns, selection.behaviorIds),
      ),
    ];

    final total = sections.fold<int>(0, (n, s) => n + s.values.length);

    return ShenakhtShell(
      title: 'الگوی تو',
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
              children: [
                const Text('🧩', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 8),
                const Text(
                  'چرخه‌ی تو',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_faNum(total)} بخش از این الگو رو شناختی\nاین شناخت، اولین قدم شکستنه',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.9,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < sections.length; i++) ...[
            if (sections[i].values.isNotEmpty) ...[
              _sectionBlock(sections[i]),
              if (i < sections.length - 1 && sections[i].values.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(color: Color(0xFFE5E5E5), height: 1),
                ),
            ],
          ],
          const SizedBox(height: 20),
          Material(
            color: SK.primary,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onContinue,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    SizedBox(width: 20),
                    Expanded(
                      child: Text(
                        'بعدی — بیا این چرخه رو بشکنیم',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_back,
                        color: Colors.white70, size: 18),
                    SizedBox(width: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onViewOrigin,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('🧸 این الگو از کجا آمده؟'),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _sectionBlock(_Section sec) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: sec.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child:
                  Text(sec.emoji, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                sec.label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: sec.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _faNum(sec.values.length),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: sec.color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final v in sec.values)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: sec.color.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  v.text,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  List<SchemaItem> _findMany(List<SchemaItem> list, List<String> ids) {
    final result = <SchemaItem>[];
    for (final id in ids) {
      for (final it in list) {
        if (it.id == id) {
          result.add(it);
          break;
        }
      }
    }
    return result;
  }
}

class _Section {
  final String emoji;
  final String label;
  final Color color;
  final List<SchemaItem> values;
  const _Section({
    required this.emoji,
    required this.label,
    required this.color,
    required this.values,
  });
}

String _faNum(int n) => String.fromCharCodes(
    n.toString().codeUnits.map((c) => (c >= 48 && c <= 57) ? c + 1728 : c));
