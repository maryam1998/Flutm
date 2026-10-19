import 'dart:async';

import 'package:flutter/material.dart';

import '../services/voice_service.dart';

/// ضبط صدای درجا (بدون کادر/شیت):
/// یک بار تپ = شروع ضبط، بار دوم تپ = پایان ضبط و بلافاصله `onRecorded` صدا می‌شه
/// (data-URL) تا همون‌جا ثبت و قابل پخش بشه.
typedef InlineMicBuilder = Widget Function(
  BuildContext context,
  bool recording,
  bool busy,
  Duration elapsed,
  VoidCallback onTap,
);

class InlineMicButton extends StatefulWidget {
  const InlineMicButton({
    super.key,
    required this.onRecorded,
    required this.builder,
  });

  final ValueChanged<String> onRecorded;
  final InlineMicBuilder builder;

  /// زمان به‌صورت «۰۰:۰۵» با رقم فارسی
  static String fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s'.replaceAllMapped(
        RegExp(r'\d'), (x) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(x.group(0)!)]);
  }

  @override
  State<InlineMicButton> createState() => _InlineMicButtonState();
}

class _InlineMicButtonState extends State<InlineMicButton> {
  Timer? _ticker;
  bool _recording = false;
  bool _busy = false;
  Duration _elapsed = Duration.zero;

  @override
  void dispose() {
    _ticker?.cancel();
    if (_recording) VoiceService.cancel();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(m),
        duration: const Duration(milliseconds: 1800),
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _toggle() async {
    if (_busy) return;
    if (_recording) {
      setState(() => _busy = true);
      _ticker?.cancel();
      final src = await VoiceService.stop();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _recording = false;
        _elapsed = Duration.zero;
      });
      if (src == null || src.isEmpty) {
        _toast('ضبط ذخیره نشد؛ دوباره امتحان کن');
        return;
      }
      widget.onRecorded(src);
      return;
    }

    setState(() => _busy = true);
    final ok = await VoiceService.start();
    if (!mounted) {
      if (ok) VoiceService.cancel();
      return;
    }
    setState(() {
      _busy = false;
      _recording = ok;
      _elapsed = Duration.zero;
    });
    if (!ok) {
      _toast('دسترسی به میکروفون داده نشد یا ضبط شروع نشد');
      return;
    }
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || !_recording) return;
      setState(() => _elapsed = VoiceService.elapsed);
    });
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _recording, _busy, _elapsed, _toggle);
}
