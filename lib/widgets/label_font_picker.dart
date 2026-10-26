import 'package:flutter/material.dart';

import '../services/note_fonts.dart';

const _kG = Color(0xFF178A7C);
const _kInkL = Color(0xFF000000);
const _kDimL = Color(0xFF5B5F77);

/// انتخاب فونت برای نوشته‌ی یک گره (من / هدف / شاخه / زیرشاخه / انیمیشن).
/// همان فهرست فونت‌های «یادداشت روی نقشه» ([kNoteFonts]) است؛ با اولین تپ دانلود می‌شود.
/// [current] = شناسه‌ی فونت یا null برای پیش‌فرض؛ [onChanged] با null یعنی پیش‌فرض.
class LabelFontPicker extends StatefulWidget {
  const LabelFontPicker({
    super.key,
    required this.current,
    required this.onChanged,
    this.title = 'فونت نوشته',
  });

  final String? current;
  final ValueChanged<String?> onChanged;
  final String title;

  @override
  State<LabelFontPicker> createState() => _LabelFontPickerState();
}

class _LabelFontPickerState extends State<LabelFontPicker> {
  String? _err;

  @override
  void initState() {
    super.initState();
    final c = widget.current;
    if (c != null && c != 'default') _load(c);
  }

  Future<bool> _load(String id) async {
    final ok = await NoteFonts.ensure(id);
    if (mounted) setState(() {});
    return ok;
  }

  Future<void> _pick(String id) async {
    if (id == 'default') {
      setState(() => _err = null);
      widget.onChanged(null);
      return;
    }
    setState(() => _err = null);
    final fut = _load(id);
    setState(() {}); // نمایش چرخنده
    final ok = await fut;
    if (!mounted) return;
    if (ok) {
      widget.onChanged(id);
    } else {
      setState(() => _err =
          'دانلود فونت انجام نشد؛ اینترنت را بررسی کن و دوباره بزن.');
    }
  }

  Widget _tile(String id, String label) {
    final cur = widget.current ?? 'default';
    final sel = cur == id;
    final busy = id != 'default' && NoteFonts.isBusy(id);
    final ready = id == 'default' || NoteFonts.loaded.contains(id);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: busy ? null : () => _pick(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? _kG.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: sel ? _kG : _kDimL.withValues(alpha: 0.35),
              width: sel ? 1.6 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                color: _kInkL,
                fontFamily: id == 'default' ? null : NoteFonts.familyOf(id),
                fontFamilyFallback: const ['Vazirmatn'],
              ),
            ),
            const SizedBox(width: 8),
            if (busy)
              const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(
                  sel
                      ? Icons.check_circle
                      : (ready ? Icons.check : Icons.download_rounded),
                  size: 16,
                  color: sel ? _kG : _kDimL),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _kInkL)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tile('default', 'وزیرمتن (پیش‌فرض)'),
              for (final nf in kNoteFonts) _tile(nf.id, nf.label),
            ],
          ),
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_err!,
                  style: const TextStyle(
                      fontSize: 11.5, color: Color(0xFFD9534F))),
            ),
        ],
      ),
    );
  }
}
