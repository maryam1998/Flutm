import 'package:flutter/widgets.dart';

/// فقط وب از `<video>` HTML استفاده می‌کند؛ جاهای دیگر خالی.
Widget buildBackgroundVideo({
  required String url,
  required double opacity,
  required double blur,
}) =>
    const SizedBox.shrink();
