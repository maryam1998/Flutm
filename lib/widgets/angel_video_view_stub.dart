import 'package:flutter/widgets.dart';

/// روی پلتفرم‌هایی که از HTML video پشتیبانی نمی‌کنند، خالی برمی‌گردونه.
Widget buildAngelVideo({
  required String id,
  required String url,
  required bool soft,
  required double size,
  required double opacity,
}) =>
    const SizedBox.shrink();
