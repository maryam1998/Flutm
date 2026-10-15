// lib/screens/shenakht/cycle_screen.dart
import 'package:flutter/material.dart';

import '../../data/shenakht/schemas.dart';
import '../../models/shenakht/schema.dart' show SchemaItem;
import '../../data/shenakht/simple_language.dart';
import 'shenakht_tab.dart';

class CycleSelection {
  final List<String> triggerIds;
  final List<String> thoughtIds;
  final List<String> emotionIds;
  final List<String> behaviorIds;

  const CycleSelection({
    required this.triggerIds,
    required this.thoughtIds,
    required this.emotionIds,
    required this.behaviorIds,
  });
}

class CycleScreen extends StatefulWidget {
  final String schemaId;
  final VoidCallback onBack;
  final void Function(CycleSelection) onDone;

  const CycleScreen({
    super.key,
    required this.schemaId,
    required this.onBack,
    required this.onDone,
  });

  @override
  State<CycleScreen> createState() => _CycleScreenState();
}

class _CycleScreenState extends State<CycleScreen> {
  int _step = 0;
  final _selected = <int, Set<String>>{
    0: {},
    1: {},
    2: {},
    3: {},
  };

  Schema? get _schema => findSchemaById(widget.schemaId);

  List<SchemaItem> get _items {
    final s = _schema;
    if (s == null) return const [];
    switch (_step) {
      case 0: return s.triggers;
      case 1: return s.automaticThoughts;
      case 2: return s.emotionalSignals;
      default: return s.behavioralPatterns;
    }
  }

  String get _stepTitle {
    switch (_step) {
      case 0: return 'چه چیزی معمولاً این حالت را فعال می‌کند؟';
      case 1: return 'معمولاً چه فکری از ذهنت می‌گذرد؟';
      case 2: return 'چه احساسی بالا می‌آید؟';
      default: return 'معمولاً چه کار می‌کنی؟';
    }
  }

  void _toggle(String id) {
    setState(() {
      final set = _selected[_step]!;
      if (set.contains(id)) {
        set.remove(id);
      } else {
        set.add(id);
      }
    });
  }

  void _goNext() {
    if (_step < 3) {
      setState(() => _step++);
    } else {
      widget.onDone(CycleSelection(
        triggerIds: _selected[0]!.toList(),
        thoughtIds: _selected[1]!.toList(),
        emotionIds: _selected[2]!.toList(),
        behaviorIds: _selected[3]!.toList(),
      ));
    }
  }

  void _goBackStep() {
    if (_step == 0) {
      widget.onBack();
    } else {
      setState(() => _step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _schema;
    if (s == null) {
      return ShenakhtShell(
        title: 'چرخه',
        onBack: widget.onBack,
        child: const Center(child: Text('طرحواره پیدا نشد')),
      );
    }

    final plain = getPlainName(s.id) ?? s.nameFa;
    final items = _items;
    final selected = _selected[_step]!;

    return ShenakhtShell(
      title: plain,
      onBack: _goBackStep,
      child: Column(
        children: [
          // ── نوار پیشرفت ۴ مرحله ─────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(left: i < 3 ? 4 : 0),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _step
                            ? SK.primary
                            : const Color(0xFFEEEEEE),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFF0F0F0)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stepTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'می‌توانی چند مورد را انتخاب کنی — محدودیتی نیست.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF666666),
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (final it in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _optionBtn(it, selected.contains(it.id)),
                        ),
                    ],
                  ),
                ),
                if (selected.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF7EE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_faNum(selected.length)} مورد انتخاب کردی',
                      style: const TextStyle(fontSize: 13, height: 1.8),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Material(
                  color: selected.isEmpty
                      ? const Color(0xFFD1C4B5)
                      : SK.primary,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: selected.isEmpty ? null : _goNext,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          _step < 3 ? 'بعدی' : 'دیدن خلاصه',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionBtn(SchemaItem item, bool active) {
    return Material(
      color: active ? SK.primary : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _toggle(item.id),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? SK.primary : const Color(0xFFE5E5E5),
              width: active ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: active ? SK.primary : const Color(0xFFCCCCCC),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: active
                    ? const Text(
                        '✓',
                        style: TextStyle(
                          color: SK.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.text,
                  style: TextStyle(
                    fontSize: 14,
                    color: active ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _faNum(int n) => String.fromCharCodes(
    n.toString().codeUnits.map((c) => (c >= 48 && c <= 57) ? c + 1728 : c));
