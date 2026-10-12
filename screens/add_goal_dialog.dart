import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/constants.dart';
import '../state/map_store.dart';

/// دیالوگ «هدف جدید»؛ هدف روی یک جای خالی دور «من» ساخته میشه
Future<void> showAddGoalDialog(BuildContext context) async {
  final store = context.read<MapStore>();
  final res = await showDialog<({String name, String icon, String color})>(
    context: context,
    builder: (_) => const _AddGoalDialog(),
  );
  if (res != null) store.addGoal(name: res.name, icon: res.icon, color: res.color);
}

class _AddGoalDialog extends StatefulWidget {
  const _AddGoalDialog();
  @override
  State<_AddGoalDialog> createState() => _AddGoalDialogState();
}

class _AddGoalDialogState extends State<_AddGoalDialog> {
  final _name = TextEditingController();
  final _icon = TextEditingController(text: '🎯');
  late String _color = kPalette[Random().nextInt(kPalette.length)];
  bool _err = false;

  @override
  void dispose() {
    _name.dispose();
    _icon.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _err = true);
      return;
    }
    Navigator.pop(context, (name: name, icon: _icon.text.trim().isEmpty ? '🎯' : _icon.text.trim(), color: _color));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('هدف جدید'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              onChanged: (_) {
                if (_err) setState(() => _err = false);
              },
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'نام هدف',
                errorText: _err ? 'یه اسم بنویس' : null,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _icon,
              maxLength: 20,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22),
              decoration: const InputDecoration(
                labelText: 'آیکون (ایموجی)',
                counterText: '',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final hex in kPalette)
                  GestureDetector(
                    onTap: () => setState(() => _color = hex),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: hexColor(hex),
                        shape: BoxShape.circle,
                        border: Border.all(color: _color == hex ? Colors.white : Colors.transparent, width: 3),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('لغو')),
        FilledButton(onPressed: _submit, child: const Text('ایجاد')),
      ],
    );
  }
}
