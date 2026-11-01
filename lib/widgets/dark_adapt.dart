import 'package:flutter/material.dart';

/// فیلترِ «وارونه‌کردنِ روشنایی با حفظ رنگ‌مایه» (مثل invert + hue-rotate(180) در CSS).
/// سفید ↔ سیاه؛ سبز/طلایی همچنان سبز/طلایی می‌مانند. دوبار اعمال = بدون تغییر.
const ColorFilter kDarkInvertFilter = ColorFilter.matrix(<double>[
  0.574, -1.43, -0.144, 0, 255, //
  -0.426, -0.43, -0.144, 0, 255, //
  -0.426, -1.43, 0.856, 0, 255, //
  0, 0, 0, 1, 0, //
]);

/// صفحه‌هایی که رنگ‌هایشان ثابتِ «روشن» نوشته شده‌اند (شناخت، بازنویسی):
/// در تم تیره پس‌زمینه تیره و نوشته‌ها سفید می‌شوند؛ در تم روشن هیچ تغییری ندارند.
class DarkAdapt extends StatefulWidget {
  const DarkAdapt({super.key, required this.child, this.undo = false});
  final Widget child;

  /// true = برای عکس/ویدیو داخلِ یک DarkAdapt: رنگ‌ها را به حالتِ اصلی برمی‌گرداند
  final bool undo;

  @override
  State<DarkAdapt> createState() => _DarkAdaptState();
}

class _DarkAdaptState extends State<DarkAdapt> {
  // با عوض‌شدن تم، state فرزند (تایمر، متن‌ها، ویدیو) از بین نرود
  final GlobalKey _childKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final kid = KeyedSubtree(key: _childKey, child: widget.child);
    if (Theme.of(context).brightness != Brightness.dark) return kid;
    return ColorFiltered(colorFilter: kDarkInvertFilter, child: kid);
  }
}
