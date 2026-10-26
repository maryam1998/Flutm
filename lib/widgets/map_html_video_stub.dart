import 'package:flutter/widgets.dart';

/// فقط وب از `<video>` HTML استفاده می‌کند؛ جاهای دیگر خالی.
Widget buildMapHtmlVideo({
  required String id,
  required String url,
  required bool loop,
  required ValueChanged<double> onRatio,
  required VoidCallback onError,
  required void Function(double frac, bool playing) onState,
}) =>
    const SizedBox.shrink();

void disposeMapHtmlVideo(String id) {}

void toggleMapHtmlVideo(String id) {}

void seekMapHtmlVideo(String id, double frac) {}
