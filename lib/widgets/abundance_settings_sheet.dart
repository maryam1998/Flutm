import 'package:flutter/material.dart';

import '../utils/money_format.dart';

const _kGold = Color(0xFFC9972B);
const _kInk = Color(0xFF2A2218);
const _kMuted = Color(0xFF7A6B57);
const _kBorder = Color(0xFFE0D5C0);
const _kCard = Colors.white;
const _kCream = Color(0xFFFBF6EA);

class AbundanceSettingsSheet extends StatefulWidget {
  final double startAmount;
  final double step;
  final ValueChanged<({double startAmount, double step})> onSave;

  const AbundanceSettingsSheet({
    super.key,
    required this.startAmount,
    required this.step,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    required double startAmount,
    required double step,
    required ValueChanged<({double startAmount, double step})> onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AbundanceSettingsSheet(
        startAmount: startAmount,
        step: step,
        onSave: onSave,
      ),
    );
  }

  @override
  State<AbundanceSettingsSheet> createState() => _AbundanceSettingsSheetState();
}

class _AbundanceSettingsSheetState extends State<AbundanceSettingsSheet> {
  late final TextEditingController _start;
  late final TextEditingController _step;

  @override
  void initState() {
    super.initState();
    _start = TextEditingController(text: widget.startAmount.round().toString());
    _step = TextEditingController(text: widget.step.round().toString());
  }

  @override
  void dispose() {
    _start.dispose();
    _step.dispose();
    super.dispose();
  }

  void _save() {
    final s = double.tryParse(_start.text.trim()) ?? 0;
    final st = double.tryParse(_step.text.trim()) ?? 0;
    if (s <= 0 || st <= 0) return;
    widget.onSave((startAmount: s, step: st));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'تنظیم بازی فراوانی',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'هر روز مبلغ تازه و بزرگ‌تری واریز می‌شه و باید همون روز خرجش کنی.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: _kMuted, height: 1.7),
                ),
                const SizedBox(height: 16),

                _field('روز اول از چه مبلغی شروع کنم؟', _start),
                const SizedBox(height: 12),
                _field('هر روز چقدر بیشتر بشه؟', _step),

                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _kGold.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kGold.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    _preview(),
                    style: const TextStyle(fontSize: 11.5, color: _kInk, height: 1.7),
                  ),
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kMuted,
                          side: const BorderSide(color: _kBorder),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('انصراف'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _kGold,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _save,
                        child: const Text('ذخیره',
                            style: TextStyle(fontWeight: FontWeight.w800)),
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

  String _preview() {
    final s = double.tryParse(_start.text.trim()) ?? 0;
    final st = double.tryParse(_step.text.trim()) ?? 0;
    if (s <= 0 || st <= 0) return 'مبلغ شروع و افزایش روزانه رو وارد کن';
    return 'روز ۱: ${formatMoney(s)} ← روز ۲: ${formatMoney(s + st)} ← روز ۳: ${formatMoney(s + st * 2)}';
  }

  Widget _field(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: _kInk,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _kInk,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: _kCard,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixText: 'تومان',
            suffixStyle: const TextStyle(fontSize: 11, color: _kMuted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kGold, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
