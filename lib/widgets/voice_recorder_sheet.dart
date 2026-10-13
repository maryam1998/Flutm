import 'dart:async';

import 'package:flutter/material.dart';

import '../services/voice_service.dart';

const _kGold = Color(0xFFC9972B);
const _kInk = Color(0xFF2A2218);
const _kMuted = Color(0xFF7A6B57);
const _kBorder = Color(0xFFE0D5C0);
const _kCream = Color(0xFFFBF6EA);
const _kDanger = Color(0xFFE5484D);

/// شیت پایین‌کشیدنی برای ضبط ویس.
/// اگر موفق شود، یک `String` (data URL) برمی‌گرداند.
class VoiceRecorderSheet extends StatefulWidget {
  final String title;

  const VoiceRecorderSheet({super.key, this.title = 'ضبط ویس'});

  static Future<String?> show(BuildContext context, {String? title}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceRecorderSheet(title: title ?? 'ضبط ویس'),
    );
  }

  @override
  State<VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<VoiceRecorderSheet> {
  Timer? _ticker;
  bool _recording = false;
  Duration _elapsed = Duration.zero;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      if (_recording) {
        setState(() => _elapsed = VoiceService.elapsed);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_recording) {
      VoiceService.cancel();
    }
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    final ok = await VoiceService.start();
    if (!mounted) return;
    setState(() {
      _starting = false;
      _recording = ok;
      if (ok) _elapsed = Duration.zero;
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('دسترسی به میکروفون داده نشد یا ضبط شروع نشد')),
      );
    }
  }

  Future<void> _stop({required bool save}) async {
    if (!_recording) return;
    final src = save ? await VoiceService.stop() : null;
    if (!save) await VoiceService.cancel();
    if (!mounted) return;
    setState(() => _recording = false);
    if (save) {
      if (src == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('ضبط ذخیره نشد یا حجمش بیشتر از ۵ مگابایت بود')),
        );
        return;
      }
      Navigator.pop(context, src);
    } else {
      Navigator.pop(context);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '${_toFa(m)}:${_toFa(s)}';
  }

  static String _toFa(String s) => s.replaceAllMapped(
        RegExp(r'\d'),
        (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m.group(0)!)],
      );

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
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
              const SizedBox(height: 18),

              GestureDetector(
                onTap: _recording ? () => _stop(save: true) : _start,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: _recording
                          ? const [Color(0xFFE5484D), Color(0xFFB0181E)]
                          : const [Color(0xFFC9972B), Color(0xFF8B6415)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_recording ? _kDanger : _kGold)
                            .withValues(alpha: 0.35),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    _recording
                        ? Icons.stop_rounded
                        : Icons.mic_none_rounded,
                    size: 52,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                _fmt(_elapsed),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _recording
                    ? 'در حال ضبط... برای پایان روی مربع بزن'
                    : 'برای شروع ضبط، دکمه را بزن',
                style: const TextStyle(
                  fontSize: 12,
                  color: _kMuted,
                ),
              ),
              const SizedBox(height: 20),

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
                      onPressed: () {
                        if (_recording) {
                          _stop(save: false);
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      child: Text(_recording ? 'لغو' : 'بستن'),
                    ),
                  ),
                  if (_recording) ...[
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
                        onPressed: () => _stop(save: true),
                        child: const Text('ذخیره و بستن',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
