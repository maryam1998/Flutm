import 'package:flutter/material.dart';

import '../theme/web_palette.dart';

/// متن راهنما: فقط کار با برنامه و تمرین بازنویسی (نوشتن و خواندن).
const List<(String, String)> _helpItems = [
  ('h2', 'راهنمای استفاده'),
  ('p', 'برنامه سه بخش اصلی دارد: «شناخت» برای ثبت و بررسی الگوهای ذهنی، «هدف‌گذاری» برای ساخت و پیگیری هدف‌ها روی نقشه، و «تمرین» برای تمرین‌های روزانه مانند شکرگذاری و بازنویسی. ظاهر برنامه (روشن یا تیره) را همیشه خودتان انتخاب می‌کنید؛ از تنظیمات یا دکمه‌ی بالای نقشه.'),
  ('h3', 'هدف‌گذاری: کار با نقشه'),
  ('p', 'این نقشه، آینه‌ی تلاش شماست. هرچه زمان و توجه بیشتری به اهدافتان اختصاص دهید، قدم‌های منظم‌تری بردارید و آن‌ها را ثبت کنید، نقشه زنده‌تر می‌شود: چشم‌انداز خشک و بیابانی آن به‌تدریج سرسبز می‌شود و به باغی بارور تبدیل می‌گردد.'),
  ('li', 'جابه‌جایی نقشه: کشیدن پس‌زمینه با یک انگشت. بزرگ‌نمایی و کوچک‌نمایی: دو انگشت.'),
  ('li', 'لمس یک هدف، نشانه یا شاخه: باز شدن پنجره‌ی ویرایش آن.'),
  ('li', 'جابه‌جایی یک گره: لمس طولانی و سپس کشیدن.'),
  ('li', 'لمس طولانی روی غنچه یا گل یک شاخه: باز شدن تقویم همان کار.'),
  ('li', 'لمس گل یا غنچه‌ی بین قدم‌ها: تقویم همان روز، با تاریخ و کار انجام‌شده.'),
  ('li', 'لمس بخش زمانِ یک شاخه: باز شدن پنجره‌ی ثبت زمان و تایمر.'),
  ('li', 'لمس طولانی روی قدم‌زن: توقف یا ادامه‌ی حرکت او روی مسیر.'),
  ('li', 'نوار پایین: «اهداف» فهرست و تقویم اهداف را باز می‌کند. «نمایش همه» کل نقشه را در یک قاب جا می‌دهد. «قدم‌زدن» نقشه را از نزدیک و از نمای قدم‌زدن نشان می‌دهد. «فقط امروز» فقط هدف فعال و قدم بعدی را پررنگ می‌کند. «نشانه» یک نشانه‌ی جدید اضافه می‌کند.'),
  ('li', 'بالای نقشه: دکمه‌ی تم برای تغییر روشن و تیره، و دکمه‌ی جمع و باز کردن همه‌ی شاخه‌ها.'),
  ('h3', 'تمرین بازنویسی: نوشتن و خواندن'),
  ('p', 'در این تمرین، متن خواسته‌ی خود را می‌نویسید و هر روز با حسِ آن می‌خوانید. مراحل از بالا به پایین است و هر مرحله پس از انجام، تیک می‌خورد.'),
  ('li', 'آمادگی: مراحل «رهاسازی»، «هیچ شدن»، «اتصال به قلمرو ممکن‌ها» و «مأموریت ذهن» ذهن و بدن را پیش از خواندن آماده می‌کنند.'),
  ('li', 'نوشتن: در مرحله‌ی «متن خواسته و تقویم»، دکمه‌ی «ویرایش» را بزنید و متن را بنویسید. از نوار ابزار ویرایشگر می‌توانید فونت، اندازه، پررنگی و تراز متن را تنظیم کنید.'),
  ('li', 'نسخه‌ها و یادداشت: نسخه‌های قبلی متن در «آرشیو» نگهداری می‌شوند و «یادداشت» برای نکته‌های شخصی شماست.'),
  ('li', 'خواندن: متن را یک بار، بلند یا در ذهن، با حس بخوانید و «امروز خوندم — ثبت کن» را بزنید. آن روز در تقویم و مسیر باورها ثبت می‌شود.'),
  ('li', 'ثبت حس: پس از ثبت خواندن، دکمه‌ی «ثبت حس» را بزنید، حس‌های خود را انتخاب کنید و ویجت را ببندید. رنگ حس شما روی رشته‌ی عصبیِ امروز می‌نشیند.'),
  ('li', 'تصاویر: در مرحله‌ی «تصاویر» عکس‌های تجسم را اضافه کنید تا به‌صورت اسلایدشو نمایش داده شوند.'),
  ('p', 'اثر این تمرین از تکرار روزانه می‌آید؛ بهتر است هر روز، در ساعتی ثابت، انجام شود.'),
];

/// پنجره‌ی راهنما — مثل `.overlay` + `.modal` در Maghz (max-height: 88vh).
Future<void> showHelpDialog(BuildContext context) {
  final wp = WebPalette.of(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'بستن راهنما',
    barrierColor: const Color.fromRGBO(5, 6, 14, 0.6),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, _, __) {
      final sz = MediaQuery.sizeOf(ctx);
      final w = sz.width * 0.9 < 360 ? sz.width * 0.9 : 360.0;
      return Center(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: w, maxHeight: sz.height * 0.88),
          child: Material(
            color: wp.panelBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: wp.panelBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(22),
                children: [
                  for (final (kind, text) in _helpItems)
                    _row(kind, text, wp),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: wp.accent,
                        foregroundColor: const Color(0xFF221800),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('بستن',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: child,
    ),
  );
}

Widget _row(String kind, String text, WebPalette wp) {
  switch (kind) {
    case 'h2':
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(text,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: wp.textMain)),
      );
    case 'h3':
      return Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(text,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: wp.textMain)),
      );
    case 'li':
      return Padding(
        padding: const EdgeInsets.only(bottom: 4, right: 4),
        child: Text('•  $text',
            style:
                TextStyle(fontSize: 12.5, height: 1.7, color: wp.textDim)),
      );
    default:
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style:
                TextStyle(fontSize: 12.5, height: 1.7, color: wp.textDim)),
      );
  }
}
