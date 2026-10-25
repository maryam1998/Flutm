import 'package:flutter/foundation.dart' show StringCharacters;
import 'package:flutter/material.dart';

final _kLetterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// اگر آیکون «نوشته» باشد (حرف/عدد دارد یا بیشتر از ۳ نماد است) true.
/// نوشته بدون محدودیت تعداد کلمه است و کامل نمایش داده می‌شود.
bool isTextIcon(String icon) {
  final t = icon.trim();
  if (t.isEmpty) return false;
  if (_kLetterOrDigit.hasMatch(t)) return true;
  return t.characters.where((c) => c.trim().isNotEmpty).length > 3;
}

/// جدا کردن ایموجی‌های یک متن آیکون (تا ۳ تا) — ایموجی ترکیبی/پرچم یک واحد حساب می‌شه
List<String> splitIcons(String icon) => icon.characters
    .where((c) => c.trim().isNotEmpty)
    .take(3)
    .toList();

/// نمایش ایکون تک‌ایموجی یا چند ایموجی «روی‌هم» مثل مغز:
/// اولی جلو و بزرگ‌تر (پایین‌راست)، دومی پشتش (بالا)، سومی پایین‌چپ.
class EmojiStack extends StatelessWidget {
  const EmojiStack({super.key, required this.icon, required this.size});
  final String icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (isTextIcon(icon)) {
      return SizedBox(
        width: size,
        height: size,
        child: Padding(
          padding: EdgeInsets.all(size * 0.08),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(icon.trim(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: size * 0.4)),
          ),
        ),
      );
    }
    final cs = splitIcons(icon);
    if (cs.isEmpty) {
      return Text('•', style: TextStyle(fontSize: size * 0.5));
    }
    if (cs.length == 1) {
      return Text(cs.first, style: TextStyle(fontSize: size * 0.5));
    }
    // (dx, dy, scale) نسبت به اندازه
    const slots = [
      (0.13, 0.15, 0.50),
      (-0.06, -0.17, 0.42),
      (-0.22, 0.17, 0.34),
    ];
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          for (var i = cs.length - 1; i >= 0; i--)
            Transform.translate(
              offset: Offset(slots[i].$1 * size, slots[i].$2 * size),
              child: Text(cs[i],
                  style: TextStyle(fontSize: size * slots[i].$3, height: 1.1)),
            ),
        ],
      ),
    );
  }
}
