import 'package:flutter/material.dart';

import '../services/visual_media_service.dart';
import 'grat_media.dart';

const _kBlue = Color(0xFF5B5BD6);
const _kInk = Color(0xFF000000);

/// افزودن ویدیو برای هر گره (من، هدف، شاخه، زیرشاخه، انیمیشن).
/// ویدیو بیرون از JSON ذخیره می‌شود و در `extra[key]` فقط یک مرجع کوتاه می‌ماند.
class NodeVideoField extends StatefulWidget {
  const NodeVideoField({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  /// مرجع ویدیوی ذخیره‌شده (خالی = بدون ویدیو)
  final String initial;

  /// مرجع جدید یا رشته‌ی خالی هنگام حذف
  final ValueChanged<String> onChanged;

  @override
  State<NodeVideoField> createState() => _NodeVideoFieldState();
}

class _NodeVideoFieldState extends State<NodeVideoField> {
  late String _src = widget.initial;
  bool _busy = false;
  bool _failed = false;

  void _set(String v) {
    setState(() => _src = v);
    widget.onChanged(v);
  }

  Future<void> _pick() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final r = await VisualMediaService.pickVideo();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failed = r.error != null;
    });
    final v = r.video;
    if (v != null) _set(v.path);
  }

  @override
  Widget build(BuildContext context) {
    final has = _src.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (has) ...[
          GratVideoView(
            key: ValueKey(_src),
            src: _src,
            onRemove: () => _set(''),
          ),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: GestureDetector(
            onTap: _busy ? null : _pick,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _kBlue, width: 1.4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_busy)
                    const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    const Icon(Icons.videocam_rounded,
                        size: 20, color: _kBlue),
                  const SizedBox(width: 8),
                  Text(
                    _busy
                        ? 'در حال افزودن…'
                        : (_failed
                            ? 'ویدیو اضافه نشد'
                            : (has ? 'تغییر ویدیو' : 'افزودن ویدیو')),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kInk),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
