# مغز (فلاتر) - مرحله ۱

## راه‌اندازی
1. فلاتر رو نصب کن (stable).
2. این پوشه رو باز کن و اجرا کن: `flutter create --platforms=android,ios,windows .`
   اگه lib/main.dart یا pubspec.yaml عوض شد، از zip دوباره کپی کن.
3. `flutter pub get` و بعد `flutter run`.
4. برای فونت وزیرمتن فایل‌های ttf رو در assets/fonts بگذار و بخش fonts رو در pubspec.yaml از کامنت دربیار.

## انتقال داده از نسخه‌ی وب
داده‌ی کامل نقشه در IndexedDB مرورگره (localStorage فقط نسخه‌ی سبک بدون عکس داره).
در کنسول مرورگر (روی سایت مغز) این کد رو بزن؛ متن کپی میشه، بعد در یک فایل .json ذخیره‌اش کن
و در تب نقشه «ورودی بکاپ» رو بزن:

    indexedDB.open('maghz-durable',1).onsuccess=e=>{e.target.result.transaction('kv').objectStore('kv').get('map:frequencyMapData').onsuccess=r=>{copy(r.target.result.json)}}

## ساختار
- lib/models: مدل داده (هدف، شاخه، حلقه، من) با حفظ فیلدهای ناشناخته
- lib/services/storage.dart: ذخیره‌ی فایل JSON + بکاپ
- lib/state/map_store.dart: وضعیت و ذخیره‌ی خودکار
- lib/screens: تب‌ها (نقشه فعلاً فقط خلاصه‌ی داده)
