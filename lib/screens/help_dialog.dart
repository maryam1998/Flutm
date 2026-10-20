import 'package:flutter/material.dart';

import '../theme/web_palette.dart';

/// متن راهنما — عیناً از `#help-modal-overlay` در index.html مغز.
const List<(String, String)> _helpItems = [
  ('h2', 'راهنمای اپ'),
  ('p', 'این اپ یه فضای شخصیه با سه بخش که کنار هم کار می‌کنن: توی شناخت، الگوهای ذهنی‌ات رو می‌شناسی؛ روی نقشه، هدف‌هات رو می‌بینی و پیش می‌بری؛ و توی تمرین، حس و حالت درونت رو با چشم باز نگه می‌داری.'),
  ('h3', '🧭 چطور با نقشه کار کنم؟'),
  ('li', 'برای جابه‌جایی نقشه، پس‌زمینه رو بکش.'),
  ('li', 'برای زوم، دو انگشت یا اسکرول موس.'),
  ('li', 'برای دیدن جزئیات هر گره، روش بزن.'),
  ('li', 'برای جابه‌جای گره، نگه‌دار و بکش.'),
  ('li', ''),
  ('h3', '🎨 آیکون هدف و نشانه'),
  ('p', 'هر هدف و هر نشانه‌ی نزدیکی روی نقشه، حالا یا یک ایموجی است (از کیبورد خودت) یا یک عکس که خودت آپلود کردی.'),
  ('p', 'اگر عکس آپلود کنی، عکس جای ایموجی را می‌گیرد و داخل یک دایره‌ی نازک به رنگ فرکانس هدف نشان داده می‌شود.'),
  ('h3', '🛍️ بازی فراوانی چیه؟'),
  ('p', 'یه فروشگاه نمادینه، نه واقعی. هر روز یه مبلغ تازه و بزرگ‌تر به کارتت واریز می‌شه (از مبلغی که خودت تعیین می‌کنی شروع می‌شه) و باید همون روز تمامش رو خرج کنی. پول دیروز به امروز اضافه نمی‌شه. هدف خریدن چیزها نیست؛ ساختن حس فراوانی توی ذهنه. اگه روزی انجام ندی، بازی از اول شروع نمی‌شه و از همون‌جا ادامه می‌دی.'),
  ('p', 'هر چیزی که دوست داری — کوچیک یا بزرگ — با عکس و قیمت دلخواه به سبدت اضافه می‌کنی.'),
  ('p', 'وقتی «پرداخت» می‌زنی، هیچ پول واقعی جابه‌جا نمی‌شه. فقط یه رسید نمادین می‌گیری، و همون مورد می‌ره توی لیست شکرگذاری‌ات. این تمرین، حسِ داشتن رو توی دلت زنده می‌کنه — قبل از اینکه واقعاً بهش برسی.'),
  ('p', 'هدف این تمرین: تو با این بازی، حسِ حالت درونت رو می‌بینی. شکرگذاری می‌کنی. ولی خودِ شناخت الگوها، توی تب «شناخت» اتفاق می‌افته.'),
  ('h3', '🧠 چرا تکرار این‌قدر مهمه؟ سه قانون مغز'),
  ('p', '۱. RAS — فیلتر توجه مغز. توی هر لحظه، میلیون‌ها چیز به مغزت می‌رسه. ولی مغز فقط یه بخش کوچیک رو به آگاهیت می‌آره. این فیلتر، RAS نام داره. وقتی تصمیم می‌گیری به چیزی توجه کنی — مثل «امروز سه نعمت رو می‌بینم» — مغزت یاد می‌گیره همون‌ها رو برات علامت بزنه. دقیقاً همین اتفاق، توی تمرین شکرگذاری می‌افته.'),
  ('p', '۲. قانون هب. یه جمله‌ی معروف از دونالد هب (۱۹۴۹): «نورون‌هایی که با هم روشن می‌شن، به هم می‌چسبن.» هر فکری که تکرار کنی، یه مسیر ذهنی می‌سازه که هر بار قوی‌تر می‌شه — تا خودبه‌خود فعال شه. این قانون هم برای عادت بد کار می‌کنه، هم برای عادت خوب.'),
  ('p', '۳. نوروپلاستیسیتی. تا یه زمانی فکر می‌کردن مغز بزرگسال ثابته. الان می‌دونیم مغزت تا آخر عمر می‌تونه خودش رو بازسازی کنه. تکرار + احساس قوی، سریع‌ترین راه ساخت مسیر تازه‌ست — به همین دلیل توی این اپ، هر تمرین رو با یه حس همراه می‌کنیم.'),
  ('h3', ''),
  ('li', 'رنگ هر هدف: فرکانسی که براش انتخاب کردی.'),
  ('li', ''),
  ('li', ''),
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
