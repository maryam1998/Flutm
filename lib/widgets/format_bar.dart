import 'package:flutter/material.dart';

import '../models/future_text_format.dart';
import '../services/note_fonts.dart';

const Color kBeliefsGold = Color(0xFFC9A24B);
const Color kBeliefsInk = Color(0xFF000000);
const Color kBeliefsMuted = Color(0xFF7C8B87);
const Color kBeliefsBorder = Color(0xFFE7E5DB);
const Color kBeliefsCream = Color(0xFFF7F6F1);
const Color kBeliefsCard = Colors.white;

class FormatBar extends StatefulWidget {
  final FutureTextFormat format;
  final ValueChanged<FutureTextFormat> onChange;

  const FormatBar({
    super.key,
    required this.format,
    required this.onChange,
  });

  @override
  State<FormatBar> createState() => _FormatBarState();
}

class _FormatBarState extends State<FormatBar> {
  String? _err;
  bool _busy = false;

  FutureTextFormat get format => widget.format;
  ValueChanged<FutureTextFormat> get onChange => widget.onChange;

  @override
  void initState() {
    super.initState();
    final f = format.font;
    if (f.isNotEmpty) NoteFonts.ensure(f).then((_) {
      if (mounted) setState(() {});
    });
  }

  /// فونت را اول دانلود می‌کند؛ فقط اگر آماده شد اعمال می‌شود
  Future<void> _pickFont(String id) async {
    setState(() => _err = null);
    if (id.isEmpty) {
      onChange(format.copyWith(font: ''));
      return;
    }
    setState(() => _busy = true);
    final ok = await NoteFonts.ensure(id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) {
        _err = 'دانلود فونت انجام نشد؛ اینترنت را بررسی کن و دوباره بزن.';
      }
    });
    if (ok) onChange(format.copyWith(font: id));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: kBeliefsCream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBeliefsBorder),
      ),
      child: Column(
        children: [
          // فونت
          DropdownButtonFormField<String>(
            value: format.font,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: kBeliefsBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: kBeliefsBorder),
              ),
            ),
            style: const TextStyle(
              fontSize: 12.5,
              color: kBeliefsInk,
              fontFamily: 'Vazirmatn',
            ),
            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
            items: kFutureFonts
                .map((f) => DropdownMenuItem(
                      value: f.id,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(f.label,
                              style: TextStyle(
                                fontFamily: f.family,
                                fontFamilyFallback: const ['Vazirmatn'],
                                color: kBeliefsInk,
                              )),
                          if (f.id.isNotEmpty &&
                              !NoteFonts.loaded.contains(f.id)) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.download_rounded,
                                size: 14, color: kBeliefsMuted),
                          ],
                        ],
                      ),
                    ))
                .toList(),
            onChanged: _busy
                ? null
                : (v) {
                    if (v != null) _pickFont(v);
                  },
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_err!,
                  style: const TextStyle(
                      fontSize: 11.5, color: Color(0xFFD9534F))),
            ),
          const SizedBox(height: 8),

          // ردیف دوم: اندازه + تراز + بولد + ایتالیک
          Row(
            children: [
              _btn(
                text: 'A−',
                onTap: format.size > FutureTextFormat.minSize
                    ? () => onChange(format.copyWith(size: format.size - 1))
                    : null,
              ),
              Container(
                width: 32,
                alignment: Alignment.center,
                child: Text(
                  _toFa(format.size),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: kBeliefsInk,
                  ),
                ),
              ),
              _btn(
                text: 'A+',
                onTap: format.size < FutureTextFormat.maxSize
                    ? () => onChange(format.copyWith(size: format.size + 1))
                    : null,
              ),
              const _Sep(),
              _iconBtn(
                icon: Icons.format_align_right,
                active: format.align == 'right',
                onTap: () => onChange(format.copyWith(align: 'right')),
              ),
              _iconBtn(
                icon: Icons.format_align_center,
                active: format.align == 'center',
                onTap: () => onChange(format.copyWith(align: 'center')),
              ),
              _iconBtn(
                icon: Icons.format_align_left,
                active: format.align == 'left',
                onTap: () => onChange(format.copyWith(align: 'left')),
              ),
              const _Sep(),
              _btn(
                text: 'B',
                bold: true,
                active: format.bold,
                onTap: () => onChange(format.copyWith(bold: !format.bold)),
              ),
              _btn(
                text: 'I',
                italic: true,
                active: format.italic,
                onTap: () => onChange(format.copyWith(italic: !format.italic)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn({
    required String text,
    VoidCallback? onTap,
    bool active = false,
    bool bold = false,
    bool italic = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: active ? kBeliefsGold : kBeliefsCard,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                  color: active ? kBeliefsGold : kBeliefsBorder),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold || active ? FontWeight.w800 : FontWeight.w500,
                fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                color: active ? Colors.white : kBeliefsInk,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: active ? kBeliefsGold : kBeliefsCard,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                  color: active ? kBeliefsGold : kBeliefsBorder),
            ),
            child: Icon(
              icon,
              size: 18,
              color: active ? Colors.white : kBeliefsInk,
            ),
          ),
        ),
      ),
    );
  }

  static String _toFa(int n) => n.toString().replaceAllMapped(
        RegExp(r'\d'),
        (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m.group(0)!)],
      );
}

class _Sep extends StatelessWidget {
  const _Sep();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      color: kBeliefsBorder,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
