import 'package:flutter/material.dart' as m;
import 'package:flutter/material.dart' show BuildContext, Color, WidgetBuilder;

import 'dark_adapt.dart';

/// جایگزینِ showDialog/showModalBottomSheet برای پنجره‌هایی که رنگ‌هایشان ثابتِ
/// «روشن» نوشته شده: وقتی تمِ برنامه تیره است، مثل بقیه‌ی تب‌ها (DarkAdapt)
/// تیره می‌شوند؛ در تمِ روشن هیچ تغییری ندارند.
Future<T?> showDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
}) {
  return m.showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    builder: (ctx) => DarkAdapt(child: Builder0(builder: builder)),
  );
}

Future<T?> showModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  Color? barrierColor,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool? showDragHandle,
}) {
  return m.showModalBottomSheet<T>(
    context: context,
    backgroundColor: backgroundColor,
    barrierColor: barrierColor,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    showDragHandle: showDragHandle,
    builder: (ctx) => DarkAdapt(child: Builder0(builder: builder)),
  );
}

/// همان Builder، با نامِ جدا تا با `hide` در فایل‌ها قاطی نشود
class Builder0 extends m.StatelessWidget {
  const Builder0({super.key, required this.builder});
  final WidgetBuilder builder;
  @override
  m.Widget build(BuildContext context) => builder(context);
}
