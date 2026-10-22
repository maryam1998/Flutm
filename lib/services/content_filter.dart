/// لایه‌ی اول فیلتر محتوا (روی خود گوشی، قبل از ارسال).
/// بعداً همین قانون‌ها روی سرور هم تکرار می‌شن؛ این فقط لایه‌ی اول است.
class ContentFilter {
  ContentFilter._();

  static String _norm(String s) {
    var t = s
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('ۀ', 'ه')
        .replaceAll('\u200c', '')
        .replaceAll('\u200d', '')
        .replaceAll('\u0640', '')
        .replaceAll(RegExp(r'[\u064B-\u065F]'), '')
        .toLowerCase();
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    for (var i = 0; i < 10; i++) {
      t = t.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
    }
    return t;
  }

  /// کلمه‌هایی که فقط وقتی «کل کلمه» باشن رد می‌شن (برای جلوگیری از اشتباه)
  static const List<String> _badTokens = [
    'کیر', 'کون', 'کونی', 'جنده', 'جندع', 'گوه', 'گه', 'عوضی', 'پفیوز',
    'مرتیکه', 'لاشی', 'کثافت', 'احمق', 'کودن', 'بیشعور', 'خر', 'خفه',
    'fuck', 'shit', 'bitch',
  ];

  /// عبارت‌هایی که داخل متنِ فشرده (بدون فاصله) هم پیدا بشن رد می‌شن
  static const List<String> _badPhrases = [
    'مادرجنده', 'کصکش', 'کسکش', 'کسننه', 'حرومزاده', 'کونکش', 'جنده‌باز',
  ];

  static const List<String> _political = [
    'سیاست', 'سیاسی', 'انتخابات', 'براندازی', 'اصلاح‌طلب', 'اصولگرا',
    'جمهوری اسلامی', 'خامنه‌ای', 'ترامپ', 'پهلوی', 'ریاست جمهور',
    'نماینده مجلس', 'تحریم‌ها',
  ];

  /// null = مشکلی نیست؛ وگرنه پیام مؤدبانه برای کاربر
  static String? check(String text) {
    final n = _norm(text);
    final compact = n.replaceAll(RegExp(r'\s+'), '');

    // لینک و راه تماس
    if (RegExp(r'(https?:|www\.|t\.me|instagram|\.com|\.ir|\.org|@\w{3,})')
        .hasMatch(n)) {
      return 'لینک و آی‌دی در پست‌ها مجاز نیست.';
    }
    if (RegExp(r'\d{8,}').hasMatch(compact)) {
      return 'شماره‌ی تماس در پست‌ها مجاز نیست.';
    }

    // الفاظ نامناسب
    final tokens = n.split(RegExp(r'[^\u0600-\u06FFa-z0-9]+'));
    for (final t in tokens) {
      if (t.isNotEmpty && _badTokens.map(_norm).contains(t)) {
        return 'لطفاً بدون توهین و الفاظ نامناسب بنویس.';
      }
    }
    for (final p in _badPhrases) {
      if (compact.contains(_norm(p).replaceAll(' ', ''))) {
        return 'لطفاً بدون توهین و الفاظ نامناسب بنویس.';
      }
    }

    // بحث سیاسی
    for (final p in _political) {
      if (compact.contains(_norm(p).replaceAll(' ', ''))) {
        return 'اینجا جای بحث سیاسی نیست؛ بیا درباره‌ی حس و باور و تجربه‌ها حرف بزنیم.';
      }
    }
    return null;
  }
}
