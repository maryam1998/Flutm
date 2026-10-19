# تغییرات این نسخه (سرعت لود + سرعت آپلود)

## لود کند
- فونت وزیرمتن حالا داخل خود برنامه است (assets/google_fonts) و از اینترنت دانلود نمی‌شود.
- CanvasKit از خود سایت (پوشه‌ی canvaskit) بارگذاری می‌شود، نه از gstatic (روی اینترنت ایران کند بود). → web/flutter_bootstrap.js
- صفحه‌ی بارگذاری HTML و یک splash سبک فلاتر؛ دیگر صفحه‌ی خالی نمی‌ماند. → web/index.html و main.dart
- خواندن IndexedDB هنگام شروع با getAll (خیلی سریع‌تر از cursor).

## آپلود کند
- ویدیو دیگر base64 داخل JSON نمی‌شود؛ در IndexedDB (وب) یا فایل (موبایل) ذخیره می‌شود. → services/media_blob.dart
- عکس‌ها ۱۲۸۰px/کیفیت ۸۰ (حدود نصف حجم قبلی) و بدون دیکُد دوباره‌ی base64.
- فرشته‌ها: عکس با موتور مرورگر به ۵۱۲px کوچک می‌شود؛ تغییر اسلایدرها دیگر همه‌ی عکس‌ها را دوباره رمزگذاری نمی‌کند.

## رفع خطای بیلد
- AppPrefs.exportAll / setStringList ، StorageService.readAllFiles و پارامتر prefix در exportBackup اضافه شد (full_backup.dart به آن‌ها نیاز داشت ولی تعریف نشده بودند).
- نسخه‌ی جدید settings_sheet.dart (که اشتباهی در screens/ ریشه مانده بود) در lib/screens قرار گرفت.
