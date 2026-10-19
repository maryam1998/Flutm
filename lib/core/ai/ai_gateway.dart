import '../translate/translation_service.dart';

// ═══════════════════════════════════════════════════════════════════
// AI Gateway — تنها دروازه‌ی تمیزِ خروجیِ هوش مصنوعی برای همه‌ی بخش‌ها
// (مثال‌های لغت، داستان‌ساز، گرامر، تمرین مکالمه)
//
// ریشه‌ی دو باگی که می‌دیدی:
//  ۱) «به‌جای جواب، می‌نویسه User Safety: safe» → بعضی مدل‌های زنجیره‌ی
//     Worker خروجیِ «گارد/ایمنی» می‌دهند، نه جواب. قبلاً فقط ترجمه این را
//     می‌گرفت؛ داستان/گرامر/تالک نه.
//  ۲) «پرامپت و فکرکردنش را می‌فرستد» → مدل‌های reasoning متنِ تحلیل یا
//     خودِ دستورها را در content برمی‌گردانند. قبلاً فقط <think> حذف می‌شد.
// حالا هر خروجی اینجا چک می‌شود؛ اگر خراب بود یک بار با دستورِ سخت‌گیرانه
// دوباره می‌پرسد، و اگر باز خراب بود خطای تمیز می‌دهد (نه متنِ خراب).
// ═══════════════════════════════════════════════════════════════════

class AiOutputException implements Exception {
  final String reason; // 'empty' | 'guard' | 'reasoning' | 'echo'
  const AiOutputException(this.reason);
  @override
  String toString() => 'AiOutputException($reason)';
}

/// نشانه‌های قطعیِ «فکر کردن» (عمداً دقیق: «Okay, so…» که یک معلم می‌تواند
/// واقعاً بگوید اینجا نیست).
final RegExp _strongReasoningRe = RegExp(
  r"(thinking process|here'?s a thinking|analy[sz]e the (request|text|input|user)|\*\*\s*analy[sz]e|\bconstraints?\s*:|the user (wants|asks|is asking|said|wrote|has written) |let me (read|think|analy[sz]e|re-?read)|<\/?think(ing)?>|^\s*(we need to|we should|we must|i need to (write|produce|respond|output)|let'?s (craft|produce|compose|draft|write)))",
  caseSensitive: false,
  multiLine: true,
);

/// خودِ دستورهای پرامپت در جواب برگشته؟
final RegExp _promptEchoRe = RegExp(
  r"(how to respond\s*:|^\s*rules\s*:\s*$|learner'?s native language\s*:|output format\s*:|respond with only\b|^\s*important\s*:\s*output only)",
  caseSensitive: false,
  multiLine: true,
);

String cleanAiText(String raw) {
  var t = stripAIReasoning(raw);
  // برچسب نقش اول متن
  t = t.replaceFirst(
      RegExp(r'^\s*(assistant|teacher|jimmy|answer|response)\s*:\s*',
          caseSensitive: false),
      '');
  return t.trim();
}

/// null = سالم؛ وگرنه دلیلِ خراب‌بودن
String? aiOutputProblem(String text) {
  final t = text.trim();
  if (t.isEmpty) return 'empty';
  if (looksLikeGuardOutput(t)) return 'guard';
  if (_strongReasoningRe.hasMatch(t)) return 'reasoning';
  if (_promptEchoRe.hasMatch(t)) return 'echo';
  return null;
}

const String _strictSuffix =
    '\n\nIMPORTANT: Output ONLY the final answer, exactly in the requested format. '
    'No analysis, no thinking aloud, no safety labels (like "safe"), '
    'and do not repeat or quote these instructions.';

/// جوابِ تمیزِ AI. سرعت: یک تلاشِ معمولی؛ فقط اگر خروجی خراب بود، یک بار دیگر.
Future<String> aiGenerate({
  required TranslationService svc,
  required AiSettings settings,
  required String prompt,
  int maxTokens = 300,
  int retries = 1,
  int timeoutMs = 15000,
  bool Function(String text)? extraCheck,
}) async {
  String? problem;
  var text = '';

  Future<void> attempt(String p, int r) async {
    final raw = await svc.callAI(
      prompt: p,
      maxTokens: maxTokens,
      retries: r,
      settings: settings,
      timeoutMs: timeoutMs,
    );
    text = cleanAiText(raw);
    problem = aiOutputProblem(text);
    if (problem == null && extraCheck != null && !extraCheck(text)) {
      problem = 'echo';
    }
  }

  await attempt(prompt, retries);
  if (problem != null) {
    await attempt('$prompt$_strictSuffix', 0);
  }
  if (problem != null) throw AiOutputException(problem!);
  return text;
}
