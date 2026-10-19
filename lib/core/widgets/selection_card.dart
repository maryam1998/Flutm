import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderBox;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/reader/widgets/neural_path_dialog.dart';
import '../neural/neural_store.dart';
import '../constants/app_languages.dart';
import '../constants/supported_languages.dart';
import '../models/grammar_note.dart';
import '../models/language_selection.dart';
import '../models/saved_word.dart';
import '../player_sync/player_sync_provider.dart';
import '../player_sync/sync_widgets.dart' show syncHighlightColor, kReadMarkerColor;
import '../providers/ai_settings_provider.dart';
import '../providers/app_prefs_provider.dart';
import '../providers/language_selection_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/reader_providers.dart';
import '../providers/speech_provider.dart';
import '../providers/translation_provider.dart';
import '../theme/app_theme_colors.dart';
import '../translate/translation_service.dart';
import '../tts/speech_state.dart';
import '../tts/tts_config.dart';

// ═══════════════════════════════════════════════════════════════════
// SelectionCard — «کارت مشترکِ انتخاب» (معادل GlobalAddToStorySelection
// وب و کادر لغتِ حباب LinLearn).
//
// همه‌جای برنامه (لغات، علاقه‌مندی‌ها، اسلنگ، مکالمات، داستان، ...) فقط از
// همین دو چیز استفاده می‌کنند، پس رفتار همه‌جا یکسان است:
//   1) SelectableSyncText  → متنی که با لمسِ لغت یا انتخابِ محدوده، کارت را باز می‌کند
//   2) showSelectionCard() → کارت را باز می‌کند (از هر جای دیگر هم قابل‌صدا زدن است)
//
// کارت: متنِ انتخاب‌شده + 🔊 + 📄 (کلِ جمله) + ✕، سپس ترجمه به «همه‌ی زبان‌های
// انتخابیِ کاربر» (هرکدام با 🔊 و دکمه‌ی ترجمه‌ی دوباره)، سپس چهار دکمه:
// ذخیره برای داستان بعدی | افزودن به گرامر | افزودن به لایتنر | مسیر عصبی.
// ═══════════════════════════════════════════════════════════════════

/// زبان‌هایی که کارت باید ترجمه‌شان را نشان بدهد — همان منطقِ effectiveDisplayLangs
/// (مقصدها به ترتیبِ انتخاب، زبان مادری اگر جزو مقصدها نیست اول) با این تفاوت
/// که زبانِ خودِ متنِ انتخاب‌شده (source) همیشه حذف می‌شود.
List<String> selectionCardLangs(LanguageSelection sel, String source) {
  final out = <String>[];
  for (final t in sel.targets) {
    if (t != source && !out.contains(t)) out.add(t);
  }
  if (sel.native.isNotEmpty && sel.native != source && !out.contains(sel.native)) {
    out.insert(0, sel.native);
  }
  if (out.isEmpty) out.add(source == 'fa' ? 'en' : 'fa');
  return out;
}

// ───────────────────────── رنگ‌های کارت (مثل پاپ‌آپِ Hope) ─────────────────────────
// سرمه‌ای + قابِ طلایی + دکمه‌های نیمه‌شفاف با ایموجی. مستقل از تمِ اپ است تا
// کارت همه‌جا یک‌شکل دیده شود (همان ظاهرِ تصویرِ مرجع).
const Color kCardBg = Color(0xFF26335F);
const Color kCardBorderGold = Color(0xFFC9A22E);
const Color kCardBtnBg = Color(0xFF37436D);
const Color kCardBtnBorder = Color(0xFF687198);
const Color kCardTextSoft = Color(0xFFD3D7E8);

// ───────────────────────── متن‌های رابط ─────────────────────────
const Map<String, Map<String, String>> _kStr = {
  'fa': {
    'story': 'ذخیره برای داستان بعدی',
    'storyDone': 'ذخیره شد برای داستان بعدی',
    'grammar': 'افزودن به یادگیری گرامر',
    'grammarDone': 'ذخیره شد در گرامر',
    'leitner': 'افزودن به جعبه‌ی لایتنر',
    'leitnerDone': 'به جعبه‌ی لایتنر اضافه شد',
    'neural': 'مسیر عصبی',
    'loading': 'در حال ترجمه...',
    'failed': 'ترجمه پیدا نشد',
    'retry': 'تلاش دوباره',
    'wrong': 'ترجمه اشتباهه؟ دوباره امتحان کن',
    'close': 'بستن',
    'whole': 'ترجمه‌ی کل جمله',
    'speak': 'خواندن',
    'sentence': 'جمله',
    'translation': 'ترجمه',
  },
  'en': {
    'story': 'Save for next story',
    'storyDone': 'Saved for next story',
    'grammar': 'Add to grammar learning',
    'grammarDone': 'Saved to grammar',
    'leitner': 'Add to Leitner box',
    'leitnerDone': 'Added to Leitner box',
    'neural': 'Neural path',
    'loading': 'Translating…',
    'failed': 'No translation found',
    'retry': 'Retry',
    'wrong': 'Wrong translation? Try again',
    'close': 'Close',
    'whole': 'Translate the whole sentence',
    'speak': 'Listen',
    'sentence': 'Sentence',
    'translation': 'Translation',
  },
  'ar': {
    'story': 'حفظ للقصة التالية',
    'storyDone': 'تم الحفظ للقصة التالية',
    'grammar': 'إضافة إلى تعلّم القواعد',
    'grammarDone': 'تم الحفظ في القواعد',
    'leitner': 'إضافة إلى صندوق لايتنر',
    'leitnerDone': 'أُضيفت إلى صندوق لايتنر',
    'neural': 'المسار العصبي',
    'loading': 'جارٍ الترجمة…',
    'failed': 'لم يتم العثور على ترجمة',
    'retry': 'إعادة المحاولة',
    'wrong': 'الترجمة خاطئة؟ جرّب مرة أخرى',
    'close': 'إغلاق',
    'whole': 'ترجمة الجملة كاملة',
    'speak': 'استماع',
    'sentence': 'الجملة',
    'translation': 'الترجمة',
  },
  'de': {
    'story': 'Für nächste Geschichte speichern',
    'storyDone': 'Für nächste Geschichte gespeichert',
    'grammar': 'Zum Grammatiklernen hinzufügen',
    'grammarDone': 'In Grammatik gespeichert',
    'leitner': 'Zur Leitner-Box hinzufügen',
    'leitnerDone': 'Zur Leitner-Box hinzugefügt',
    'neural': 'Neuronaler Pfad',
    'loading': 'Wird übersetzt…',
    'failed': 'Keine Übersetzung gefunden',
    'retry': 'Erneut versuchen',
    'wrong': 'Falsche Übersetzung? Nochmal versuchen',
    'close': 'Schließen',
    'whole': 'Ganzen Satz übersetzen',
    'speak': 'Anhören',
    'sentence': 'Satz',
    'translation': 'Übersetzung',
  },
  'es': {
    'story': 'Guardar para la próxima historia',
    'storyDone': 'Guardado para la próxima historia',
    'grammar': 'Añadir al aprendizaje de gramática',
    'grammarDone': 'Guardado en gramática',
    'leitner': 'Añadir a la caja Leitner',
    'leitnerDone': 'Añadido a la caja Leitner',
    'neural': 'Ruta neuronal',
    'loading': 'Traduciendo…',
    'failed': 'No se encontró traducción',
    'retry': 'Reintentar',
    'wrong': '¿Traducción incorrecta? Inténtalo de nuevo',
    'close': 'Cerrar',
    'whole': 'Traducir la frase completa',
    'speak': 'Escuchar',
    'sentence': 'Frase',
    'translation': 'Traducción',
  },
  'fr': {
    'story': 'Enregistrer pour la prochaine histoire',
    'storyDone': 'Enregistré pour la prochaine histoire',
    'grammar': 'Ajouter à l’apprentissage de la grammaire',
    'grammarDone': 'Enregistré dans la grammaire',
    'leitner': 'Ajouter à la boîte de Leitner',
    'leitnerDone': 'Ajouté à la boîte de Leitner',
    'neural': 'Chemin neuronal',
    'loading': 'Traduction en cours…',
    'failed': 'Aucune traduction trouvée',
    'retry': 'Réessayer',
    'wrong': 'Mauvaise traduction ? Réessayer',
    'close': 'Fermer',
    'whole': 'Traduire toute la phrase',
    'speak': 'Écouter',
    'sentence': 'Phrase',
    'translation': 'Traduction',
  },
};

String _s(String ui, String key) => _kStr[ui]?[key] ?? _kStr['en']![key]!;

String _abbr(String code) {
  for (final l in kSupportedLanguages) {
    if (l.code == code) return l.abbr;
  }
  return code.toUpperCase();
}

bool _isLatinLang(String code) =>
    !const {'fa', 'ar', 'ru', 'hi', 'zh', 'ja', 'ko'}.contains(code);

// ═══════════════════════════════════════════════════════════════════
// باز کردن کارت (Overlay) — فقط یک کارت در هر لحظه
// ═══════════════════════════════════════════════════════════════════
VoidCallback? _closeActiveCard;

/// کارتِ مشترک را کنار [anchor] (مستطیلِ سراسریِ متنِ انتخاب‌شده) باز می‌کند.
/// Future وقتی تمام می‌شود که کارت بسته شود.
Future<void> showSelectionCard(
  BuildContext context, {
  required String text,
  required String langCode,
  String? sentence,
  Rect? anchor,
}) {
  final picked = text.trim();
  if (picked.isEmpty) return Future<void>.value();
  _closeActiveCard?.call();

  final overlay = Overlay.of(context, rootOverlay: true);
  final done = Completer<void>();
  var removed = false;
  late final OverlayEntry entry;

  void close() {
    if (removed) return;
    removed = true;
    entry.remove();
    if (_closeActiveCard == close) _closeActiveCard = null;
    if (!done.isCompleted) done.complete();
  }

  entry = OverlayEntry(builder: (ctx) {
    final mq = MediaQuery.of(ctx);
    final fallback = Rect.fromCenter(
      center: Offset(mq.size.width / 2, mq.size.height / 2),
      width: 2,
      height: 2,
    );
    return Stack(
      children: [
        // لمسِ بیرون از کارت → بستن
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: close,
          ),
        ),
        Positioned.fill(
          child: CustomSingleChildLayout(
            delegate: _CardLayoutDelegate(
              anchor: anchor ?? fallback,
              safe: mq.padding,
              keyboard: mq.viewInsets.bottom,
            ),
            child: SelectionCard(
              text: picked,
              sentence: (sentence ?? picked),
              langCode: langCode,
              onClose: close,
            ),
          ),
        ),
      ],
    );
  });

  _closeActiveCard = close;
  overlay.insert(entry);
  return done.future;
}

/// کارت را بالای متنِ انتخاب‌شده می‌گذارد؛ اگر جا نبود پایینش؛ همیشه داخل صفحه.
class _CardLayoutDelegate extends SingleChildLayoutDelegate {
  final Rect anchor;
  final EdgeInsets safe;
  final double keyboard;

  _CardLayoutDelegate({
    required this.anchor,
    required this.safe,
    required this.keyboard,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final w = math.min(300.0, constraints.maxWidth - 24);
    final h = constraints.maxHeight - safe.top - safe.bottom - keyboard - 32;
    return BoxConstraints(
      minWidth: w,
      maxWidth: w,
      maxHeight: math.max(180.0, h),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = (anchor.center.dx - childSize.width / 2)
        .clamp(12.0, math.max(12.0, size.width - childSize.width - 12.0))
        .toDouble();
    final topLimit = safe.top + 8;
    final bottomLimit = size.height - safe.bottom - keyboard - 8;
    var top = anchor.top - childSize.height - 10;
    if (top < topLimit) top = anchor.bottom + 10;
    if (top + childSize.height > bottomLimit) {
      top = math.max(topLimit, bottomLimit - childSize.height);
    }
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(covariant _CardLayoutDelegate old) =>
      old.anchor != anchor || old.safe != safe || old.keyboard != keyboard;
}

// ═══════════════════════════════════════════════════════════════════
// SelectionCard — خودِ کارت
// ═══════════════════════════════════════════════════════════════════
class SelectionCard extends ConsumerStatefulWidget {
  /// متنِ انتخاب‌شده (لغت یا محدوده)
  final String text;

  /// متنِ کاملی که انتخاب از داخلش آمده (برای دکمه‌ی 📄 و یادداشتِ گرامر)
  final String sentence;

  /// زبانِ متنِ انتخاب‌شده
  final String langCode;
  final VoidCallback onClose;

  const SelectionCard({
    super.key,
    required this.text,
    required this.sentence,
    required this.langCode,
    required this.onClose,
  });

  @override
  ConsumerState<SelectionCard> createState() => _SelectionCardState();
}

class _SelectionCardState extends ConsumerState<SelectionCard> {
  late String _text = widget.text.trim();
  bool _whole = false;
  final Map<String, String> _results = {};

  bool get _canExpand =>
      !_whole &&
      widget.sentence.trim().isNotEmpty &&
      widget.sentence.trim() != widget.text.trim();

  void _expand() {
    setState(() {
      _text = widget.sentence.trim();
      _whole = true;
      _results.clear();
    });
  }

  void _onResolved(String lang, String value) => _results[lang] = value;

  /// کارتِ مسیر عصبی را باز می‌کند و کارتِ انتخاب را می‌بندد تا روی هم نیفتند.
  void _openNeural(String word, String code, String? base) {
    unawaited(showNeuralPath(context,
        word: word, langCode: code, baseText: base));
    widget.onClose();
  }

  String _meaning(LanguageSelection sel) =>
      _results[sel.native] ??
      (_results.values.isEmpty ? '' : _results.values.first);

  String _grammarMarkdown(String ui) {
    final sentence = _whole ? _text : widget.sentence.trim();
    final b = StringBuffer('## 🧩 $_text\n\n**${_s(ui, 'sentence')}:** '
        '${sentence.isEmpty ? _text : sentence}');
    if (_results.isNotEmpty) {
      b.write('\n\n**${_s(ui, 'translation')}:**');
      _results.forEach((k, v) => b.write('\n- ${k.toUpperCase()}: $v'));
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(localeProvider).languageCode;
    final sel = ref.watch(languageSelectionProvider);
    final lang = widget.langCode;
    final langs = selectionCardLangs(sel, lang);

    final storySaved = ref.watch(savedWordsProvider.select((l) => l.any(
        (w) => w.langCode == lang && normWord(w.word) == normWord(_text))));
    final grammarSaved = ref.watch(grammarNotesProvider.select((l) => l.any(
        (n) => n.langCode == lang && normWord(n.word) == normWord(_text))));
    final leitnerAdded = ref.watch(leitnerProvider.select((l) => l.any(
        (w) => w.langCode == lang && normWord(w.word) == normWord(_text))));
    return Directionality(
      textDirection: kAppLanguages[ui]?.dir ?? TextDirection.rtl,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kCardBorderGold, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ═══ هدر: متنِ اصلی + ✕ + 🧬 + 🔊 (از راست: 🔊 🧬 ✕) ═══
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 84),
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Align(
                              alignment: dirFor(lang) == TextDirection.rtl
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Text(
                                _text,
                                textDirection: dirFor(lang),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: _whole ? 15 : 21,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _CardIconButton(
                      icon: Icons.close,
                      color: Colors.white,
                      size: 21,
                      tooltip: _s(ui, 'close'),
                      onTap: widget.onClose,
                    ),
                    // از راست به چپ: 🔊 ← 🧬 ← ✕
                    _CardIconButton(
                      icon: Icons.hub_outlined,
                      emoji: '🧬',
                      color: Colors.white,
                      size: 20,
                      tooltip: _s(ui, 'neural'),
                      onTap: () => _openNeural(_text, lang, null),
                    ),
                    _SpeakIcon(
                      text: _text,
                      code: lang,
                      color: Colors.white,
                      size: 20,
                      tooltip: _s(ui, 'speak'),
                      hintBase: neuralBase(_text),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // ═══ ترجمه به همه‌ی زبان‌های انتخابیِ کاربر ═══
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final code in langs)
                        _TranslationLine(
                          key: ValueKey('$lang::$code::$_text'),
                          text: _text,
                          from: lang,
                          to: code,
                          ui: ui,
                          showBadge: langs.length > 1,
                          onNeural: (word, code) =>
                              _openNeural(word, code, _text),
                          onResolved: _onResolved,
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ═══ دکمه‌ها ═══
              _ActionButton(
                emoji: '🔖',
                label: _s(ui, storySaved ? 'storyDone' : 'story'),
                active: storySaved,
                onTap: () => ref.read(savedWordsProvider.notifier).toggleSave(
                      SavedWord(
                        word: _text,
                        langCode: lang,
                        meaning: _meaning(sel),
                        savedAt: DateTime.now(),
                      ),
                    ),
              ),
              _ActionButton(
                emoji: '🧩',
                label: _s(ui, grammarSaved ? 'grammarDone' : 'grammar'),
                active: grammarSaved,
                onTap: () {
                  if (grammarSaved) return;
                  final sentence = _whole ? _text : widget.sentence.trim();
                  ref.read(grammarNotesProvider.notifier).addNote(
                        GrammarNote(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          word: _text,
                          sentence: sentence.isEmpty ? _text : sentence,
                          markdown: _grammarMarkdown(ui),
                          langCode: lang,
                          savedAt: DateTime.now(),
                        ),
                      );
                },
              ),
              _ActionButton(
                emoji: '🔁',
                label: _s(ui, leitnerAdded ? 'leitnerDone' : 'leitner'),
                active: leitnerAdded,
                onTap: () {
                  if (leitnerAdded) return;
                  ref.read(leitnerProvider.notifier).addToLeitner(
                        SavedWord(
                          word: _text,
                          langCode: lang,
                          meaning: _meaning(sel),
                          savedAt: DateTime.now(),
                        ),
                      );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// یک ردیفِ ترجمه: [EN] متنِ ترجمه … [🔄] [🔊]
// ═══════════════════════════════════════════════════════════════════
class _TranslationLine extends ConsumerStatefulWidget {
  final String text;
  final String from;
  final String to;
  final String ui;
  final bool showBadge;
  final void Function(String word, String code) onNeural;
  final void Function(String lang, String value) onResolved;

  const _TranslationLine({
    super.key,
    required this.text,
    required this.from,
    required this.to,
    required this.ui,
    required this.onResolved,
    required this.onNeural,
    this.showBadge = true,
  });

  @override
  ConsumerState<_TranslationLine> createState() => _TranslationLineState();
}

class _TranslationLineState extends ConsumerState<_TranslationLine> {
  String? _res;
  bool _busy = true;
  bool _failed = false;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    final service = ref.read(translationServiceProvider);
    final hit = service.peekCached(widget.text, widget.from, widget.to);
    if (hit != null && _ok(hit)) {
      _res = hit.trim();
      _busy = false;
      widget.onResolved(widget.to, _res!);
    } else {
      unawaited(_fetch());
    }
  }

  @override
  void dispose() {
    _gen++;
    super.dispose();
  }

  bool _ok(String r) {
    final out = r.trim();
    if (out.isEmpty) return false;
    final src = widget.text.trim();
    // نام‌ها/هم‌ریشه‌ها (مثل Edgar → Edgar) در زبان‌های لاتین
    if (out.toLowerCase() == src.toLowerCase()) {
      return out != src &&
          !src.contains(RegExp(r'\s')) &&
          _isLatinLang(widget.from) &&
          _isLatinLang(widget.to);
    }
    return !looksLikelyMistranslated(src, out, widget.to,
        sourceLang: widget.from);
  }

  void _accept(String v) {
    if (!mounted) return;
    setState(() {
      _res = v.trim();
      _busy = false;
      _failed = false;
    });
    widget.onResolved(widget.to, _res!);
  }

  Future<void> _fetch({bool retry = false}) async {
    final gen = ++_gen;
    final service = ref.read(translationServiceProvider);
    final ai = ref.read(aiSettingsProvider);
    final text = widget.text;
    final from = widget.from;
    final to = widget.to;

    if (retry) {
      setState(() {
        _busy = true;
        _failed = false;
      });
    }

    String? r;
    try {
      r = retry
          ? await service.retranslate(
              text: text, targetLang: to, sourceLang: from, aiSettings: ai)
          : await service.translate(
              text: text, targetLang: to, sourceLang: from, aiSettings: ai);
    } catch (_) {
      r = null;
    }
    if (!mounted || gen != _gen) return;
    if (r != null && _ok(r)) {
      _accept(r);
      return;
    }

    // یک بار دیگر، این‌بار با بازبینیِ AI
    if (!retry) {
      try {
        r = await service.translate(
          text: text,
          targetLang: to,
          sourceLang: from,
          aiSettings: ai,
          forceVerify: true,
        );
      } catch (_) {
        r = null;
      }
      if (!mounted || gen != _gen) return;
      if (r != null && _ok(r)) {
        _accept(r);
        return;
      }
    }

    setState(() {
      _busy = false;
      _failed = _res == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final res = _res;
    final rtl = dirFor(widget.to) == TextDirection.rtl;

    Widget body;
    if (res != null) {
      body = Align(
        alignment: rtl ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          res,
          textDirection: dirFor(widget.to),
          textAlign: rtl ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
              color: kCardTextSoft, fontSize: 17, height: 1.3),
        ),
      );
    } else if (_failed) {
      body = Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _s(widget.ui, 'failed'),
          style: const TextStyle(color: Color(0xFFFF9A9A), fontSize: 13),
        ),
      );
    } else {
      body = Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: const CircularProgressIndicator(
                strokeWidth: 1.6, color: kCardBorderGold),
          ),
          const SizedBox(width: 8),
          Text(
            _s(widget.ui, 'loading'),
            style: const TextStyle(color: kCardTextSoft, fontSize: 12),
          ),
        ],
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showBadge) ...[
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: kCardBtnBg,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: kCardBtnBorder, width: 0.8),
                  ),
                  child: Text(
                    _abbr(widget.to),
                    style: const TextStyle(
                      color: kCardBorderGold,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(child: body),
            // از راست به چپ: 🔊 ← 🧬 ← رفرش
            if (res != null || _failed)
              _CardIconButton(
                icon: Icons.refresh,
                color: Colors.white70,
                size: 17,
                tooltip: _s(widget.ui, res != null ? 'wrong' : 'retry'),
                busy: _busy,
                onTap: _busy ? null : () => _fetch(retry: true),
              ),
            if (res != null)
              _CardIconButton(
                icon: Icons.hub_outlined,
                emoji: '🧬',
                color: Colors.white,
                size: 16,
                tooltip: _s(widget.ui, 'neural'),
                onTap: () => widget.onNeural(res, widget.to),
              ),
            if (res != null)
              _SpeakIcon(
                text: res,
                code: widget.to,
                color: Colors.white,
                size: 17,
                tooltip: _s(widget.ui, 'speak'),
                hintBase: neuralBase(widget.text),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// اجزای کوچک
// ═══════════════════════════════════════════════════════════════════
class _SpeakIcon extends ConsumerWidget {
  final String text;
  final String code;
  final Color color;
  final double size;
  final String tooltip;

  /// مسیرِ عصبیِ این پخش به کدام «لغتِ پایه» برود (اختیاری)
  final String? hintBase;

  const _SpeakIcon({
    required this.text,
    required this.code,
    required this.color,
    required this.tooltip,
    this.size = 22,
    this.hintBase,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = '${TtsConfig.locale[code] ?? 'en-US'}::$text';
    final playing = ref.watch(speechControllerProvider
        .select((s) => s.key == key && s.status == SpeechStatus.playing));
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: () {
          final hb = hintBase;
          if (hb != null && hb.isNotEmpty) {
            ref.read(neuralPathProvider.notifier).hint(key, hb);
          }
          ref.read(speechControllerProvider.notifier).toggle(text, code);
        },
        radius: size,
        child: Padding(
          padding: const EdgeInsets.all(5),
          // 🔊 ایموجی، مثلِ پاپ‌آپِ Hope
          child: Text(
            playing ? '⏸️' : '🔊',
            style: TextStyle(fontSize: size, height: 1.1),
          ),
        ),
      ),
    );
  }
}

class _CardIconButton extends StatelessWidget {
  final IconData icon;

  /// اگر داده شود به‌جای آیکون، این ایموجی نشان داده می‌شود
  final String? emoji;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final bool busy;

  const _CardIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.emoji,
    this.size = 22,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: size,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: busy
              ? SizedBox(
                  width: size - 4,
                  height: size - 4,
                  child: CircularProgressIndicator(strokeWidth: 1.6, color: color),
                )
              : (emoji != null
                  ? Text(emoji!, style: TextStyle(fontSize: size, height: 1.1))
                  : Icon(icon, size: size, color: color)),
        ),
      ),
    );
  }
}

/// دکمه‌ی عملِ کارت: ایموجی + برچسب، راست‌چین (در RTL)، پس‌زمینه‌ی نیمه‌شفافِ
/// آبی با قابِ روشن — مثلِ پاپ‌آپِ Hope.
class _ActionButton extends StatelessWidget {
  final String emoji;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ActionButton({
    required this.emoji,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? kCardBorderGold : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: kCardBtnBg,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: active ? kCardBorderGold : kCardBtnBorder,
              width: 1.2,
            ),
          ),
          // مثلِ تصویرِ مرجع: محتوا چپ‌چین، «برچسب» و بعدش ایموجی در انتها
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              textDirection: TextDirection.ltr,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(emoji, style: const TextStyle(fontSize: 15, height: 1.1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SelectableSyncText — جایگزینِ SyncText برای متن‌هایی که باید با لمسِ لغت
// یا انتخابِ محدوده، کارتِ مشترک را باز کنند.
//   • لمسِ یک لغت            → کارت برای همان لغت (لغت هایلایت می‌شود)
//   • لمسِ طولانی/دابل‌تپ/درگ → کارت برای محدوده‌ی انتخاب‌شده
// هایلایتِ پخشِ همگام (SyncText) دقیقاً مثل قبل کار می‌کند.
// ═══════════════════════════════════════════════════════════════════
final RegExp _wordChar =
    RegExp(r"[\p{L}\p{M}\p{N}'’\-\u200c]", unicode: true);
final RegExp _edgeChar = RegExp(r"['’\-\u200c]");

TextRange? _wordRangeAt(String text, int offset, String code) {
  if (text.isEmpty) return null;
  var i = offset.clamp(0, text.length - 1).toInt();
  if (!_wordChar.hasMatch(text[i])) {
    if (i > 0 && _wordChar.hasMatch(text[i - 1])) {
      i -= 1;
    } else {
      return null;
    }
  }
  if (code == 'zh' || code == 'ja') {
    return TextRange(start: i, end: i + 1);
  }
  var s = i;
  var e = i + 1;
  while (s > 0 && _wordChar.hasMatch(text[s - 1])) {
    s--;
  }
  while (e < text.length && _wordChar.hasMatch(text[e])) {
    e++;
  }
  while (s < e && _edgeChar.hasMatch(text[s])) {
    s++;
  }
  while (e > s && _edgeChar.hasMatch(text[e - 1])) {
    e--;
  }
  return s < e ? TextRange(start: s, end: e) : null;
}

/// تکه‌ای از متنِ رنگی/استایل‌دار برای [SelectableSyncText.runs]؛ مجموعِ متنِ تکه‌ها باید دقیقاً برابرِ `text` باشد.
class SelectableRun {
  final String text;
  final TextStyle? style;
  const SelectableRun(this.text, [this.style]);
}

/// زبانِ «خودِ متنِ انتخاب‌شده»: عربی‌خط → fa (یا ar/ur اگر fallback همان باشد)، سیریلیک → ru،
/// هان → zh، دیوانگری → hi؛ لاتین → fallback اگر لاتین‌خط باشد وگرنه en.
String guessTextLang(String text, String fallback) {
  const latin = {
    'en', 'de', 'fr', 'es', 'it', 'pt', 'nl', 'tr', 'pl', 'sv', 'no', 'da', 'fi',
    'cs', 'ro', 'hu', 'id', 'vi'
  };
  var ar = 0, lat = 0, cyr = 0, han = 0, dev = 0;
  for (final r in text.runes) {
    if (r >= 0x0600 && r <= 0x06FF ||
        r >= 0x0750 && r <= 0x077F ||
        r >= 0x08A0 && r <= 0x08FF ||
        r >= 0xFB50 && r <= 0xFDFF ||
        r >= 0xFE70 && r <= 0xFEFF) {
      ar++;
    } else if (r >= 0x0400 && r <= 0x04FF) {
      cyr++;
    } else if (r >= 0x4E00 && r <= 0x9FFF) {
      han++;
    } else if (r >= 0x0900 && r <= 0x097F) {
      dev++;
    } else if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A) || (r >= 0xC0 && r <= 0x24F)) {
      lat++;
    }
  }
  final best = [ar, lat, cyr, han, dev].fold<int>(0, (a, b) => b > a ? b : a);
  if (best == 0) return fallback;
  if (ar == best) return const {'fa', 'ar', 'ur'}.contains(fallback) ? fallback : 'fa';
  if (cyr == best) return 'ru';
  if (han == best) return 'zh';
  if (dev == best) return 'hi';
  return latin.contains(fallback) ? fallback : 'en';
}

class SelectableSyncText extends ConsumerStatefulWidget {
  final String code;
  final String id;
  final String text;

  /// متنِ کامل برای دکمه‌ی 📄 (پیش‌فرض: همین [text])
  final String? sentence;
  final TextStyle style;
  final TextDirection? textDirection;
  final TextAlign? textAlign;
  final Duration duration;

  /// متنِ رنگی (مثلاً غلط/اصلاحِ مکالمه)؛ اگر بدهید، مجموعِ متنِ تکه‌ها باید برابرِ [text] باشد.
  final List<SelectableRun>? runs;

  /// true = زبانِ هر انتخاب از روی خطِ خودِ متن تشخیص داده شود ([code] فقط پیش‌فرض است).
  final bool autoLang;

  const SelectableSyncText({
    super.key,
    required this.code,
    required this.id,
    required this.text,
    required this.style,
    this.sentence,
    this.textDirection,
    this.textAlign,
    this.duration = const Duration(milliseconds: 350),
    this.runs,
    this.autoLang = false,
  });

  @override
  ConsumerState<SelectableSyncText> createState() => _SelectableSyncTextState();
}

class _SelectableSyncTextState extends ConsumerState<SelectableSyncText> {
  int _gen = 0; // با تغییرش انتخابِ باقی‌مانده پاک می‌شود
  TextRange? _hl; // لغتِ لمس‌شده (هایلایتِ طلایی تا بسته شدن کارت)
  Timer? _debounce;
  bool _open = false;
  Offset? _ptr;
  DateTime? _ptrAt;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSelectionChanged(TextSelection sel, SelectionChangedCause? cause) {
    if (_open || !sel.isValid) return;
    _debounce?.cancel();
    final len = widget.text.length;
    if (sel.isCollapsed) {
      if (cause != SelectionChangedCause.tap) return;
      final r = _wordRangeAt(widget.text, sel.baseOffset, widget.code);
      if (r == null) return;
      // کمی صبر: اگر این لمس نیمه‌ی اولِ یک دابل‌تپ باشد، انتخابِ محدوده جایش را می‌گیرد
      _debounce = Timer(const Duration(milliseconds: 220), () {
        if (!mounted || _open) return;
        _openCard(r, highlight: true);
      });
      return;
    }
    final start = sel.start.clamp(0, len).toInt();
    final end = sel.end.clamp(0, len).toInt();
    if (end <= start) return;
    final quick = cause == SelectionChangedCause.longPress ||
        cause == SelectionChangedCause.doubleTap;
    // کمی صبر می‌کنیم تا کاربر بتواند دسته‌های انتخاب را جابه‌جا کند
    _debounce = Timer(Duration(milliseconds: quick ? 400 : 700), () {
      if (!mounted || _open) return;
      _openCard(TextRange(start: start, end: end), highlight: false);
    });
  }

  Rect _anchor() {
    var widgetRect = Rect.zero;
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      widgetRect = box.localToGlobal(Offset.zero) & box.size;
    }
    final p = _ptr;
    final at = _ptrAt;
    if (p != null &&
        at != null &&
        DateTime.now().difference(at) < const Duration(seconds: 6) &&
        widgetRect.inflate(60).contains(p)) {
      return Rect.fromCenter(center: p, width: 24, height: 24);
    }
    return widgetRect;
  }

  void _openCard(TextRange r, {required bool highlight}) {
    if (r.end > widget.text.length || r.end <= r.start) return;
    final picked = widget.text.substring(r.start, r.end).trim();
    if (picked.isEmpty) return;
    final anchor = _anchor();
    setState(() {
      _open = true;
      _hl = highlight ? r : null;
    });
    showSelectionCard(
      context,
      text: picked,
      langCode: widget.autoLang ? guessTextLang(picked, widget.code) : widget.code,
      sentence: widget.sentence ?? widget.text,
      anchor: anchor,
    ).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _open = false;
        _hl = null;
        _gen++; // انتخابِ بومی را پاک کن
      });
    });
  }

  /// متنِ رنگی با هایلایتِ لغتِ لمس‌شده روی هر تکه‌ای که با محدوده‌ی [r] هم‌پوشانی دارد.
  TextSpan _runsSpan(TextStyle base, List<SelectableRun> runs, TextRange? r, Color? hlBg) {
    final kids = <InlineSpan>[];
    var off = 0;
    for (final run in runs) {
      final t = run.text;
      final s = off, e = off + t.length;
      off = e;
      if (t.isEmpty) continue;
      if (r == null || r.end <= s || r.start >= e) {
        kids.add(TextSpan(text: t, style: run.style));
        continue;
      }
      final a = (r.start - s).clamp(0, t.length).toInt();
      final b = (r.end - s).clamp(0, t.length).toInt();
      if (a > 0) kids.add(TextSpan(text: t.substring(0, a), style: run.style));
      kids.add(TextSpan(
        text: t.substring(a, b),
        style: (run.style ?? const TextStyle()).copyWith(backgroundColor: hlBg),
      ));
      if (b < t.length) kids.add(TextSpan(text: t.substring(b), style: run.style));
    }
    return TextSpan(style: base, children: kids);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final active = ref.watch(activeSyncProvider.select(
        (a) => a != null && a.code == widget.code && a.id == widget.id));
    final pref = ref.watch(appPrefsProvider.select((p) => p.highlightColor));
    final hl = syncHighlightColor(pref);

    final Color target = (hl != null && active)
        ? hl
        : (hl ?? kReadMarkerColor).withOpacity(0);

    final text = widget.text;

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: widget.duration,
      builder: (_, bg, __) {
        final base = widget.style.copyWith(backgroundColor: bg);
        final r = _hl;
        final hlBg = hl == null ? null : hl.withOpacity(0.75);
        final span = widget.runs != null
            ? _runsSpan(base, widget.runs!, (r == null || r.end > text.length) ? null : r, hlBg)
            : (r == null || r.end > text.length)
            ? TextSpan(text: text, style: base)
            : TextSpan(
                style: base,
                children: [
                  TextSpan(text: text.substring(0, r.start)),
                  TextSpan(
                    text: text.substring(r.start, r.end),
                    // رنگِ هایلایتِ تنظیمات؛ اگر «بدون هایلایت» باشد، لغتِ لمس‌شده رنگی نمی‌شود
                    style: TextStyle(
                        backgroundColor: hl == null ? null : hl.withOpacity(0.75)),
                  ),
                  TextSpan(text: text.substring(r.end)),
                ],
              );
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            _ptr = e.position;
            _ptrAt = DateTime.now();
          },
          onPointerUp: (e) {
            _ptr = e.position;
            _ptrAt = DateTime.now();
          },
          child: SelectableText.rich(
            span,
            key: ValueKey('sel-$_gen'),
            textDirection: widget.textDirection,
            textAlign: widget.textAlign ?? TextAlign.start,
            // منوی پیش‌فرضِ سیستم (Copy / Select all) نشان داده نشود؛
            // به‌جایش کارتِ مشترکِ خودمان باز می‌شود.
            contextMenuBuilder: (_, __) => const SizedBox.shrink(),
            onSelectionChanged: _onSelectionChanged,
          ),
        );
      },
    );
  }
}
