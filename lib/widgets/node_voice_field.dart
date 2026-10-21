import 'package:flutter/material.dart';

import 'audio_clip_view.dart';
import 'inline_voice_button.dart';
import 'panel_kit.dart';

const _kGold = Color(0xFFC9962B);
const _kInk = Color(0xFF000000);
const _kBorder = Color(0xFFE4E6EE);
const _kDanger = Color(0xFFE5484D);

/// ضبط و پخش «صدای تاکیدی» (مثلاً جمله‌ی تاکیدی مسیر رسیدن به هدف) برای هر گره
/// (من، هدف، شاخه، زیرشاخه، نشانه، انیمیشن). صدا به‌صورت data-URL در `extra[key]` ذخیره می‌شود.
class NodeVoiceField extends StatefulWidget {
  const NodeVoiceField({
    super.key,
    required this.initial,
    required this.onChanged,
    this.label = 'صدای تاکیدی',
  });

  /// data-URL صدای ذخیره‌شده (خالی = بدون صدا)
  final String initial;

  /// صدای جدید (data-URL) یا رشته‌ی خالی هنگام حذف
  final ValueChanged<String> onChanged;
  final String label;

  @override
  State<NodeVoiceField> createState() => _NodeVoiceFieldState();
}

class _NodeVoiceFieldState extends State<NodeVoiceField> {
  late String _src = widget.initial;

  void _set(String v) {
    setState(() => _src = v);
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final has = _src.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelLabel(widget.label),
        if (has) ...[
          AudioClipView(
            key: ValueKey(_src.length ^ _src.hashCode),
            src: _src,
            onRemove: () => _set(''),
          ),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: InlineMicButton(
            onRecorded: _set,
            builder: (ctx, recording, busy, elapsed, onTap) {
              final col = recording ? _kDanger : _kGold;
              return GestureDetector(
                onTap: busy ? null : onTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: recording ? _kDanger.withAlpha(20) : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: col, width: 1.4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(recording ? Icons.stop_rounded : Icons.mic_rounded,
                          size: 20, color: col),
                      const SizedBox(width: 8),
                      Text(
                        recording
                            ? 'پایان ضبط  ${InlineMicButton.fmt(elapsed)}'
                            : (has ? 'ضبط دوباره' : 'ضبط صدا'),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: recording ? _kDanger : _kInk),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
