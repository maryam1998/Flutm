import '../../app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/supported_languages.dart';
import '../models/language_selection.dart';
import '../providers/ai_settings_provider.dart';
import '../providers/language_selection_provider.dart';
import '../providers/speech_provider.dart';
import '../providers/translation_provider.dart';
import '../theme/app_theme_colors.dart';
import '../translate/translation_service.dart' show runWithConcurrencyLimit;
import '../utils/html_entities.dart';
import '../../features/reader/widgets/neural_path_dialog.dart';
import 'sync_item_card.dart' show NeuralPathButton;
import 'selection_card.dart' show SelectableSyncText;

/// زبان‌هایی که زیر یک جوابِ AI دکمه‌ی ترجمه می‌گیرند:
/// زبانِ مبدأ (مادریِ کاربر) + زبان‌های مقصدِ او، بدونِ تکرار، و بدونِ
/// خودِ زبانِ جواب (جواب به همان زبان است و ترجمه‌اش لازم نیست).
List<String> answerTranslationLangs(LanguageSelection sel, String source) {
  final out = <String>[];
  for (final t in [sel.native, ...sel.targets]) {
    if (t.isNotEmpty && t != source && !out.contains(t)) out.add(t);
  }
  return out;
}

/// نوارِ زیرِ کادرِ جوابِ هوش مصنوعی — هم‌شکلِ کارتِ لغت:
///   [FA] [ES] [DE] …                      🧬 🔊   ← 🔊 سمتِ راست
/// با زدنِ هر زبان (مبدأ و تارگت‌های کاربر)، جواب به همان زبان ترجمه و در یک
/// ردیفِ ترجمه نشان داده می‌شود: [زبان] متن … 🔁 🧬 🔊
/// دوباره زدن، ترجمه را می‌بندد.
class AiAnswerTools extends ConsumerStatefulWidget {
  /// متنِ جواب
  final String text;

  /// زبانِ متنِ جواب؛ null = زبانِ مادریِ کاربر
  final String? sourceLang;

  const AiAnswerTools({super.key, required this.text, this.sourceLang});

  @override
  ConsumerState<AiAnswerTools> createState() => _AiAnswerToolsState();
}

class _AiAnswerToolsState extends ConsumerState<AiAnswerTools> {
  final List<String> _open = [];
  final Map<String, String> _results = {};
  final Set<String> _loading = {};
  final Set<String> _failed = {};

  @override
  void didUpdateWidget(covariant AiAnswerTools old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      // جواب عوض شد (مثلاً رفرش) → ترجمه‌های قبلی معتبر نیستند
      _open.clear();
      _results.clear();
      _loading.clear();
      _failed.clear();
    }
  }

  static String _plain(String t) => decodeHtmlEntities(t)
      .replaceAll(RegExp('[\u2066-\u2069]'), '')
      .replaceAll(RegExp(r'\*\*|__|`'), '')
      .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*[-*•]\s+', multiLine: true), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  String get _source =>
      widget.sourceLang ?? ref.read(languageSelectionProvider).native;

  void _speak(String text, String lang) {
    final t = _plain(text);
    if (t.isEmpty) return;
    ref.read(speechControllerProvider.notifier).toggle(t, lang);
  }

  /// بخش‌های کوتاه (برای سرویس‌های ترجمه که طولِ متن را محدود می‌کنند)
  static List<String> _chunks(String line) {
    final t = line.trim();
    if (t.length <= 380) return [t];
    final parts = t.split(RegExp(r'(?<=[.!?؟。])\s+'));
    final out = <String>[];
    var cur = '';
    for (final p in parts) {
      if (cur.isNotEmpty && cur.length + p.length + 1 > 380) {
        out.add(cur);
        cur = p;
      } else {
        cur = cur.isEmpty ? p : '$cur $p';
      }
    }
    if (cur.isNotEmpty) out.add(cur);
    return out;
  }

  /// ترجمه با همان سرویسِ ترجمه‌ی برنامه (Google/MyMemory/Lingva/Libre + کشِ
  /// دائمی + بررسیِ AI) — مثلِ ترجمه‌ی لغت‌ها و مثال‌ها؛ خط‌به‌خط/بخش‌به‌بخش.
  /// force = رفرش: بدونِ کش، اول AI.
  Future<void> _translate(String lang, {bool force = false}) async {
    if (_loading.contains(lang)) return;
    if (!force && _results.containsKey(lang)) return;
    setState(() {
      _loading.add(lang);
      _failed.remove(lang);
    });
    final original = widget.text;
    final svc = ref.read(translationServiceProvider);
    final ai = ref.read(aiSettingsProvider);
    final from = _source;
    try {
      var lines = _plain(original).split('\n');
      // خط‌هایی که تکه‌ی فارسی/عربی (زبانِ مادری/رابط) وسطِ متنِ زبانِ تمرین دارند،
      // اول به زبانِ مبدأ برمی‌گردند تا کلِ خط یک‌دست ترجمه شود و تکه‌ی فارسی
      // دست‌نخورده وسطِ ترجمه نماند.
      if (dirFor(from) != TextDirection.rtl &&
          dirFor(lang) != TextDirection.rtl) {
        lines = [for (final l in lines) await _unmix(l, svc, ai, from)];
      }
      final jobs = <String>[];
      for (final l in lines) {
        if (l.trim().isNotEmpty) jobs.addAll(_chunks(l));
      }
      var ok = 0;
      final outs = await runWithConcurrencyLimit<String, String>(jobs, 3,
          (seg, _) async {
        try {
          final t = force
              ? await svc.retranslate(
                  text: seg, targetLang: lang, sourceLang: from, aiSettings: ai)
              : await svc.translate(
                  text: seg, targetLang: lang, sourceLang: from, aiSettings: ai);
          final v = decodeHtmlEntities(t.trim());
          if (v.isEmpty || v == seg.trim()) return seg;
          ok++;
          return v;
        } catch (_) {
          return seg;
        }
      });
      if (!mounted || original != widget.text) return;
      if (ok == 0) throw Exception('failed');
      final buf = <String>[];
      var k = 0;
      for (final l in lines) {
        if (l.trim().isEmpty) {
          buf.add('');
          continue;
        }
        final n = _chunks(l).length;
        buf.add(outs.sublist(k, k + n).join(' '));
        k += n;
      }
      setState(() => _results[lang] = buf.join('\n').trim());
    } catch (_) {
      if (!mounted || original != widget.text) return;
      setState(() => _failed.add(lang));
    } finally {
      if (mounted && original == widget.text) {
        setState(() => _loading.remove(lang));
      }
    }
  }

  static final RegExp _arabicRun = RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]'
      r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF\u200c\u200d\s.,!?؟،؛:]*');

  /// هر تکه‌ی عربی‌نویس (فارسی/عربی) داخلِ خط را به زبانِ مبدأ ترجمه می‌کند.
  Future<String> _unmix(String line, dynamic svc, dynamic ai, String from) async {
    if (!_arabicRun.hasMatch(line)) return line;
    final buf = StringBuffer();
    var last = 0;
    for (final m in _arabicRun.allMatches(line)) {
      final run = m.group(0)!;
      final core = run.trimRight();
      final tail = run.substring(core.length);
      var t = core;
      try {
        final r = (await svc.translate(
          text: core,
          targetLang: from,
          sourceLang: 'auto',
          aiSettings: ai,
        ) as String)
            .trim();
        if (r.isNotEmpty) t = decodeHtmlEntities(r);
      } catch (_) {}
      buf
        ..write(line.substring(last, m.start))
        ..write(t)
        ..write(tail);
      last = m.end;
    }
    buf.write(line.substring(last));
    return buf.toString();
  }

  void _toggleLang(String lang) {
    if (_open.contains(lang)) {
      setState(() => _open.remove(lang));
      return;
    }
    setState(() => _open.add(lang));
    _translate(lang);
  }

  SupportedLanguage? _info(String code) {
    for (final l in kSupportedLanguages) {
      if (l.code == code) return l;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final sel = ref.watch(languageSelectionProvider);
    final source = _source;
    final langs = answerTranslationLangs(sel, source);
    if (widget.text.trim().isEmpty || langs.isEmpty) {
      return const SizedBox.shrink();
    }

    // داخلِ کادرِ جواب: خطِ‌چین ← 🌐 + چیپ‌های زبان ← جعبه‌ی ترجمه‌ی زبانِ انتخابی
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 10),
            child: CustomPaint(
              size: const Size(double.infinity, 1),
              painter: _DashedLinePainter(c.inkSoft.withOpacity(0.35)),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.language, size: 22, color: c.inkSoft),
              for (final l in langs)
                _Pill(
                  active: _open.contains(l),
                  onTap: () => _toggleLang(l),
                  label: _info(l)?.enLabel ?? l.toUpperCase(),
                ),
            ],
          ),
          for (final l in _open) _resultRow(c, l),
        ],
      ),
    );
  }

  /// جعبه‌ی ترجمه‌ی سفید زیرِ چیپ‌ها؛ از راست به چپ: 🧬 ← 🔊 ← 🔁
  Widget _resultRow(AppThemeColorsExt c, String lang) {
    final text = _results[lang];
    final loading = _loading.contains(lang);
    final failed = _failed.contains(lang);
    final rtl = dirFor(lang) == TextDirection.rtl;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.cardBorder, width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: loading
                  ? Text(context.l10n.grammar_translating,
                      style: TextStyle(color: c.inkSoft, fontSize: 13))
                  : failed || text == null
                      ? Text(context.l10n.reader_not_translated_retry,
                          style: TextStyle(color: c.rose, fontSize: 13))
                      : Directionality(
                          textDirection:
                              rtl ? TextDirection.rtl : TextDirection.ltr,
                          child: SelectableSyncText(
                            code: lang,
                            id: 'ai-tr-$lang-${text.hashCode}',
                            text: text,
                            textDirection:
                                rtl ? TextDirection.rtl : TextDirection.ltr,
                            style: TextStyle(
                                color: c.ink, fontSize: 14, height: 1.6),
                          ),
                        ),
            ),
          ),
          if (!loading && (text != null || failed))
            InkResponse(
              onTap: () => _translate(lang, force: true),
              radius: 16,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.refresh,
                    size: 16,
                    color: failed ? c.rose : c.inkSoft.withOpacity(0.7)),
              ),
            ),
          if (text != null && !loading) ...[
            InkResponse(
              onTap: () => _speak(text, lang),
              radius: 16,
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Icon(Icons.volume_up_outlined, size: 18, color: c.gold),
              ),
            ),
            NeuralPathButton(
              onTap: () => showNeuralPath(
                context,
                word: text,
                langCode: lang,
                baseText: _plain(widget.text),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 🧬 و 🔊 که داخلِ کادرِ جوابِ AI، بالا سمتِ راست می‌نشینند (از راست به چپ: 🧬 ← 🔊).
class AiBubbleActions extends ConsumerWidget {
  final String text;
  final String? sourceLang;
  const AiBubbleActions({super.key, required this.text, this.sourceLang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final lang = sourceLang ?? ref.read(languageSelectionProvider).native;
    final plain = _AiAnswerToolsState._plain(text);
    if (plain.isEmpty) return const SizedBox.shrink();
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkResponse(
            onTap: () =>
                ref.read(speechControllerProvider.notifier).toggle(plain, lang),
            radius: 16,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.volume_up_outlined, size: 18, color: c.gold),
            ),
          ),
          NeuralPathButton(
            onTap: () => showNeuralPath(context,
                word: plain, langCode: lang, baseText: plain),
          ),
        ],
      ),
    );
  }
}

/// چیپ‌ِ زبان — سفید و گرد؛ انتخاب‌شده: سبزِ تیره با متنِ سفید
class _Pill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool active;
  const _Pill({required this.label, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? c.teal : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? c.teal : c.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : c.ink.withOpacity(0.85),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), paint);
      x += 7;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) => old.color != color;
}
