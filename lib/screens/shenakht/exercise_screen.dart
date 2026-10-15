// lib/screens/shenakht/exercise_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/shenakht/schemas.dart';
import '../../models/shenakht/schema.dart' show SchemaExercise;
import 'cycle_screen.dart';
import 'shenakht_tab.dart';

class ExerciseScreen extends StatefulWidget {
  final String schemaId;
  final CycleSelection selection;
  final VoidCallback onBack;
  final void Function(Map<String, dynamic>? result) onDone;
  final VoidCallback onSkip;

  const ExerciseScreen({
    super.key,
    required this.schemaId,
    required this.selection,
    required this.onBack,
    required this.onDone,
    required this.onSkip,
  });

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  // state انواع تمرین
  final _text = <String>[''];         // single_input
  String? _choice;                    // single_choice
  final _answers = <String>[''];      // reflection
  final _items = <String>['', '', '']; // list
  final _columns = <List<String>>[];  // two/three column

  Timer? _timer;
  int _remaining = 0;
  bool _timerRunning = false;
  bool _timerFinished = false;

  SchemaExercise? get _ex {
    final schema = findSchemaById(widget.schemaId);
    if (schema == null) return null;
    final triggerId = widget.selection.triggerIds.isNotEmpty
        ? widget.selection.triggerIds.first
        : null;
    final behaviorId = widget.selection.behaviorIds.isNotEmpty
        ? widget.selection.behaviorIds.first
        : null;
    final rule = resolveExercise(widget.schemaId, triggerId, behaviorId);
    if (rule == null || !rule.startsWith('showExercise:')) return null;
    final id = rule.substring('showExercise:'.length);
    for (final e in schema.exercises) {
      if (e.id == id) return e;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ex = _ex;
      if (ex == null) return;
      if (ex.columns != null) {
        for (final c in ex.columns!) {
          _columns.add(['']);
        }
      }
      if (ex.prompts != null) {
        _answers.clear();
        for (var i = 0; i < ex.prompts!.length; i++) {
          _answers.add('');
        }
      }
      if (ex.type == 'timer') {
        _remaining = ex.durationSeconds ?? 300;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── تایمر ──────────────────────────────────────────
  void _toggleTimer() {
    if (_timerRunning) {
      _timer?.cancel();
      setState(() => _timerRunning = false);
      return;
    }
    setState(() => _timerRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) {
        t.cancel();
        setState(() {
          _remaining = 0;
          _timerRunning = false;
          _timerFinished = true;
        });
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _remaining = _ex?.durationSeconds ?? 300;
      _timerRunning = false;
      _timerFinished = false;
    });
  }

  // ── تکمیل ─────────────────────────────────────────
  bool get _isComplete {
    final ex = _ex;
    if (ex == null) return false;
    switch (ex.type) {
      case 'timer':
        return _timerFinished;
      case 'single_choice':
        return _choice != null;
      case 'single_input':
        return _text.first.trim().length >= 2;
      case 'two_column':
        final hasAny = _columns.any((c) => c.any((v) => v.trim().isNotEmpty));
        return hasAny;
      case 'three_column':
        final hasAny = _columns.any((c) => c.any((v) => v.trim().isNotEmpty));
        return hasAny;
      case 'reflection':
        return _answers.every((a) => a.trim().length >= 2);
      case 'list':
        return _items.where((i) => i.trim().length >= 2).length >= 2;
      default:
        return false;
    }
  }

  void _finish() {
    final ex = _ex;
    if (ex == null) {
      widget.onDone(null);
      return;
    }
    Map<String, dynamic>? result;
    switch (ex.type) {
      case 'timer':
        result = {'finished': true};
        break;
      case 'single_choice':
        result = {'choice': _choice};
        break;
      case 'single_input':
        result = {'text': _text.first.trim()};
        break;
      case 'two_column':
      case 'three_column':
        result = {
          'columns': [
            for (var i = 0; i < _columns.length; i++)
              {
                'key': ex.columns?[i].first ?? 'col$i',
                'items': _columns[i]
                    .where((s) => s.trim().isNotEmpty)
                    .toList(),
              }
          ],
        };
        break;
      case 'reflection':
        result = {'answers': _answers.map((a) => a.trim()).toList()};
        break;
      case 'list':
        result = {
          'items': _items.where((i) => i.trim().isNotEmpty).toList(),
        };
        break;
      default:
        result = null;
    }
    widget.onDone({
      'exerciseId': ex.id,
      'type': ex.type,
      'result': result,
    });
  }

  @override
  Widget build(BuildContext context) {
    final ex = _ex;

    if (ex == null) {
      return ShenakhtShell(
        title: 'تمرین',
        onBack: widget.onBack,
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Center(
              child: Column(
                children: [
                  Text('🎯', style: TextStyle(fontSize: 40)),
                  SizedBox(height: 12),
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'برای این ترکیب، تمرین اختصاصی تعریف نشده.\nولی همین که چرخه رو شناختی، خودش یک قدمه.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, height: 1.9),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Material(
                color: SK.primary,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => widget.onDone(null),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text('ادامه',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ShenakhtShell(
      title: 'تمرین',
      onBack: widget.onBack,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(ex),
          const SizedBox(height: 16),
          _renderBody(ex),
          const SizedBox(height: 20),
          Material(
            color: _isComplete ? SK.primary : const Color(0xFFD1C4B5),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _isComplete ? _finish : null,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('✓ انجام دادم',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: widget.onSkip,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('فعلاً رد کن'),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _header(SchemaExercise ex) {
    const typeInfo = {
      'two_column': ['⚖️', 'تحلیل دو ستونه'],
      'three_column': ['🔬', 'بررسی شواهد'],
      'timer': ['⏱️', 'مکث زمان‌دار'],
      'single_choice': ['🎯', 'انتخاب'],
      'single_input': ['✍️', 'نوشتن'],
      'reflection': ['💭', 'تأمل'],
      'list': ['📝', 'فهرست'],
    };
    final info = typeInfo[ex.type] ?? ['🎯', 'تمرین'];

    return Container(
      padding: const EdgeInsets.all(18),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(info[0], style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info[1],
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 3),
                    Text(ex.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          if (ex.description != null || ex.question != null) ...[
            const SizedBox(height: 12),
            Text(
              ex.description ?? ex.question ?? '',
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, height: 1.9),
            ),
          ],
        ],
      ),
    );
  }

  Widget _renderBody(SchemaExercise ex) {
    switch (ex.type) {
      case 'timer':
        return _timerBody(ex);
      case 'single_choice':
        return _singleChoiceBody(ex);
      case 'single_input':
        return _singleInputBody(ex);
      case 'two_column':
      case 'three_column':
        return _columnBody(ex);
      case 'reflection':
        return _reflectionBody(ex);
      case 'list':
        return _listBody(ex);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── تایمر ─────────────────────────────────────────
  Widget _timerBody(SchemaExercise ex) {
    final total = ex.durationSeconds ?? 300;
    final progress = total == 0 ? 0.0 : (_remaining / total);
    final mm = (_remaining ~/ 60).toString().padLeft(2, '0');
    final ss = (_remaining % 60).toString().padLeft(2, '0');

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: const Color(0xFFEEEEEE),
                    valueColor:
                        const AlwaysStoppedAnimation(SK.primary),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$mm:$ss',
                      style: const TextStyle(
                          fontSize: 32, fontWeight: FontWeight.w700),
                    ),
                    if (_timerFinished)
                      const Text('✓ تمام شد',
                          style: TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Material(
                color: _timerRunning ? Colors.white : SK.primary,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: _toggleTimer,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF111111)),
                    ),
                    child: Center(
                      child: Text(
                        _timerRunning ? 'توقف' : 'شروع',
                        style: TextStyle(
                          color: _timerRunning ? Colors.black : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _resetTimer,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('بازنشانی'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── تک انتخابی ─────────────────────────────────────
  Widget _singleChoiceBody(SchemaExercise ex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ex.question != null) ...[
          Text(ex.question!,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
        ],
        for (final opt in ex.options ?? [])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: _choice == opt ? SK.primary : Colors.white,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => setState(() => _choice = opt),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _choice == opt
                          ? SK.primary
                          : const Color(0xFFE5E5E5),
                      width: _choice == opt ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    opt,
                    style: TextStyle(
                      fontSize: 14,
                      color: _choice == opt ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── متن کوتاه ─────────────────────────────────────
  Widget _singleInputBody(SchemaExercise ex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ex.question != null)
          Text(ex.question!,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        TextField(
          maxLines: 4,
          onChanged: (v) => setState(() => _text[0] = v),
          decoration: InputDecoration(
            hintText: 'اینجا بنویس...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  // ── دو/سه ستونه ───────────────────────────────────
  Widget _columnBody(SchemaExercise ex) {
    final cols = ex.columns ?? [];
    if (_columns.length != cols.length) {
      _columns.clear();
      for (var i = 0; i < cols.length; i++) {
        _columns.add(['']);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ex.question != null) ...[
          Text(ex.question!,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
        ],
        for (var ci = 0; ci < cols.length; ci++) ...[
          Text(cols[ci].last,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          for (var ii = 0; ii < _columns[ci].length; ii++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: TextField(
                onChanged: (v) => setState(() => _columns[ci][ii] = v),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.all(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          TextButton(
            onPressed: () => setState(() => _columns[ci].add('')),
            child: const Text('+ افزودن'),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  // ── تأمل ─────────────────────────────────────────
  Widget _reflectionBody(SchemaExercise ex) {
    final prompts = ex.prompts ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < prompts.length; i++) ...[
          Text('${_faNum(i + 1)}. ${prompts[i]}',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            maxLines: 3,
            onChanged: (v) => setState(() => _answers[i] = v),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.all(10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  // ── فهرست ─────────────────────────────────────────
  Widget _listBody(SchemaExercise ex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ex.prompt != null)
          Text(ex.prompt!,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        for (var i = 0; i < _items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text('${_faNum(i + 1)}. ',
                    style: const TextStyle(fontSize: 13)),
                Expanded(
                  child: TextField(
                    onChanged: (v) =>
                        setState(() => _items[i] = v),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        TextButton(
          onPressed: () => setState(() => _items.add('')),
          child: const Text('+ افزودن مورد'),
        ),
      ],
    );
  }
}

String _faNum(int n) => String.fromCharCodes(
    n.toString().codeUnits.map((c) => (c >= 48 && c <= 57) ? c + 1728 : c));
