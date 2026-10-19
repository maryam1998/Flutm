# ───── R8 / ProGuard — Zflut ─────
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod

# Flutter (deferred components اختیاری‌اند و استفاده نمی‌شن)
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# کدِ خودِ اپ: LinglearnBridge با reflection (BubblePlugin.class.getMethod) متدها را صدا می‌زنه،
# و سرویس‌ها/اکتیویتی‌ها از مانیفست لود می‌شن
-keep class com.linglearn.app.** { *; }
-keep class com.getcapacitor.** { *; }

# Sherpa-ONNX: کدِ native فیلدها/کلاس‌های JNI را با نام می‌خونه → نباید rename/حذف بشن
-keep class com.k2fsa.sherpa.onnx.** { *; }
-keepclasseswithmembernames class * { native <methods>; }

# OkHttp: کلاس‌های اختیاریِ پلتفرم
-dontwarn okhttp3.internal.platform.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# ML Kit OCR: پلاگین google_mlkit_text_recognition به گزینه‌های چینی/ژاپنی/کره‌ای هم ارجاع می‌دهد،
# ولی ما فقط لاتین و هندی را در gradle داریم → R8 نباید بخاطر نبودنشان بیلد را بشکند.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
