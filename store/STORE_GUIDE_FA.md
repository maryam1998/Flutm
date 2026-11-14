# راهنمای انتشار Mana (بازار، مایکت، گوگل‌پلی)

## ۱) ساخت کلید امضا (فقط یک‌بار — و برای همیشه نگهش دار)
روی کامپیوتر (Java لازم است):
    keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias mana
- فایل `.jks` و رمزها را گم نکن؛ بدونش نمی‌توانی آپدیت بدهی. در گیت آپلودش نکن.
- بازار و مایکت: همین کلید برای همیشه. گوگل‌پلی: با «Play App Signing» این کلید فقط کلید آپلود است.

## ۲) Secrets در GitHub (Settings ← Secrets and variables ← Actions)
- ANDROID_KEYSTORE_BASE64 : خروجی `base64 -w0 upload-keystore.jks`
- ANDROID_KEYSTORE_PASSWORD، ANDROID_KEY_ALIAS (مثلاً mana)، ANDROID_KEY_PASSWORD

## ۳) بیلد
Actions ← Build Android APK ← Run workflow. دو خروجی:
- mana-apk (app-release.apk) → بازار و مایکت
- mana-aab (app-release.aab) → گوگل‌پلی
شماره‌ی نسخه (versionCode) با هر اجرا خودکار بالا می‌رود. نام نسخه از pubspec.yaml (`version: 1.0.0+1`).

## ۴) موارد لازم در خود فروشگاه‌ها (از کد قابل حل نیست)
- لینک «سیاست حریم خصوصی» (هر سه فروشگاه) — اپ میکروفون، عکس/ویدیو و حساب Google استفاده می‌کند؛ باید ذکر شود.
- گوگل‌پلی: فرم Data safety، Content rating، و چون ورود با حساب دارد، **امکان حذف حساب** (داخل اپ + لینک وب) لازم است. فعلاً در اپ نیست.
- آیکون ۵۱۲×۵۱۲ آماده است: store/play-icon-512.png. اسکرین‌شات‌ها (حداقل ۲ تا) و توضیحات را خودت بساز.
- گوگل‌پلی برای حساب‌های شخصیِ جدید: تست بسته با ۱۲ تستر در ۱۴ روز قبل از انتشار.
- ورود Google در ایران بدون فیلترشکن باز نمی‌شود؛ اپ بدون ورود هم کار می‌کند.

## ۵) هشدار
شناسه‌ی پکیج `app.mana.android` است و بعد از انتشار قابل تغییر نیست. اپ قبلی (com.example.maghz) جدا نصب می‌شود و داده‌هایش منتقل نمی‌شود؛ از «پشتیبان‌گیری» داخل اپ استفاده کن.
