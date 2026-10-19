import 'package:flutter/material.dart';

import '../models/abundance_models.dart';
import 'abundance_card.dart';

const _kGold = Color(0xFFC9972B);
const _kInk = Color(0xFF2A2218);
const _kMuted = Color(0xFF7A6B57);
const _kBorder = Color(0xFFE0D5C0);
const _kCard = Colors.white;
const _kCream = Color(0xFFFBF6EA);

class CardEditSheet extends StatefulWidget {
  final BankCard initial;
  final ValueChanged<BankCard> onSave;

  const CardEditSheet({super.key, required this.initial, required this.onSave});

  static Future<void> show({
    required BuildContext context,
    required BankCard initial,
    required ValueChanged<BankCard> onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CardEditSheet(initial: initial, onSave: onSave),
    );
  }

  @override
  State<CardEditSheet> createState() => _CardEditSheetState();
}

class _CardEditSheetState extends State<CardEditSheet> {
  late final TextEditingController _bank;
  late final TextEditingController _holder;
  late final TextEditingController _num;
  late final TextEditingController _exp;
  late final TextEditingController _cvv;
  late String _theme;

  @override
  void initState() {
    super.initState();
    _bank = TextEditingController(text: widget.initial.bankName);
    _holder = TextEditingController(text: widget.initial.holderName);
    _num = TextEditingController(text: widget.initial.number);
    _exp = TextEditingController(text: widget.initial.expiry);
    _cvv = TextEditingController(text: widget.initial.cvv);
    _theme = widget.initial.theme;
  }

  @override
  void dispose() {
    _bank.dispose();
    _holder.dispose();
    _num.dispose();
    _exp.dispose();
    _cvv.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(widget.initial.copyWith(
      bankName: _bank.text.trim().isEmpty ? 'بانک فراوانی' : _bank.text.trim(),
      holderName:
          _holder.text.trim().isEmpty ? 'کاربر فراوانی' : _holder.text.trim(),
      number: _num.text.trim().isEmpty ? '5859 8312 8347 6690' : _num.text.trim(),
      expiry: _exp.text.trim().isEmpty ? '∞ / ∞' : _exp.text.trim(),
      cvv: _cvv.text.trim().isEmpty ? '۱۴۰' : _cvv.text.trim(),
      theme: _theme,
    ));
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
                  'ویرایش کارت فراوانی',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: _kInk),
                ),
                const SizedBox(height: 4),
                const Text(
                  'کارتت رو دقیقاً مثل یک کارت واقعی بساز',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: _kMuted),
                ),
                const SizedBox(height: 14),

                _field('اسم بانک', _bank),
                const SizedBox(height: 10),
                _field('نام دارنده کارت', _holder),
                const SizedBox(height: 10),
                _field('شماره کارت', _num, keyboard: TextInputType.text),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _field('تاریخ انقضا', _exp)),
                    const SizedBox(width: 8),
                    Expanded(child: _field('CVV2', _cvv)),
                  ],
                ),
                const SizedBox(height: 14),

                const Text(
                  'رنگ کارت',
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700, color: _kInk),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: kCardThemes.entries.map((e) {
                    final active = e.key == _theme;
                    return GestureDetector(
                      onTap: () => setState(() => _theme = e.key),
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: e.value),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: active ? _kGold : Colors.transparent,
                            width: active ? 3 : 0,
                          ),
                        ),
                        child: active
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 18),
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
                        child: const Text('ذخیره کارت',
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

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboard}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w700, color: _kInk),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          style: const TextStyle(fontSize: 13, color: _kInk),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: _kCard,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kGold, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
