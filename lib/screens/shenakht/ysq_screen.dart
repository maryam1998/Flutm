// lib/screens/shenakht/ysq_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/shenakht/ysq_questions.dart';
import '../../state/shenakht_store.dart';
import 'shenakht_tab.dart';

class YsqScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onDone;

  const YsqScreen({
    super.key,
    required this.onBack,
    required this.onDone,
  });

  @override
  State<YsqScreen> createState() => _YsqScreenState();
}

class _YsqScreenState extends State<YsqScreen> {
  final Map<String, int> _answers = {};
  int _index = 0;

  YsqQuestion get _q => ysqQuestions[_index];
  bool get _isLast => _index == ysqQuestions.length - 1;
  YsqValidation get _check => validateAnswers(_answers);

  void _select(int v) {
    setState(() => _answers[_q.id] = v);
    if (!_isLast) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _index++);
      });
    }
  }

  Future<void> _submit() async {
    final analysis = analyzeYsq(_answers);
    await context.read<ShenakhtStore>().saveProfile(analysis);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final check = _check;
    return ShenakhtShell(
      title: 'ارزیابی',
      onBack: widget.onBack,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'سؤال ${_faNum(_index + 1)} از ${_faNum(ysqQuestions.length)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '${_faNum(check.progress)}%',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: check.progress / 100,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFEEEEEE),
                    valueColor:
                        const AlwaysStoppedAnimation(Color(0xFF1A3D2C)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFF0F0F0)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _q.text,
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.9,
                        ),
                      ),
                      const SizedBox(height: 20),
                      for (final l in likertScale)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _optionBtn(l),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _index == 0
                            ? null
                            : () => setState(() => _index--),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('قبلی'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLast
                            ? null
                            : () => setState(() => _index++),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('بعدی'),
                      ),
                    ),
                  ],
                ),
                if (check.valid) ...[
                  const SizedBox(height: 12),
                  Material(
                    color: SK.primary,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _submit,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'دیدن پروفایل من',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionBtn(LikertItem l) {
    final active = _answers[_q.id] == l.value;
    return Material(
      color: active ? SK.primary : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _select(l.value),
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
          child: Text(
            l.label,
            style: TextStyle(
              fontSize: 14,
              color: active ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}

String _faNum(int n) =>
    String.fromCharCodes(n.toString().codeUnits.map((c) {
      if (c >= 48 && c <= 57) return c + 1728;
      return c;
    }));
