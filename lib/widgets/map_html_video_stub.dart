import 'package:flutter/widgets.dart';

/// فقط وب از `<video>` HTML استفاده می‌کند؛ جاهای دیگر خالی.
Widget buildMapHtmlVideo({
  required String id,
  required String url,
  required bool loop,
  required ValueChanged<double> onRatio,
  required VoidCallback onError,
}) =>
    const SizedBox.shrink();

void disposeMapHtmlVideo(String id) {}
