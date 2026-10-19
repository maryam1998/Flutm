import '../../app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/word_examples.dart';
import '../constants/supported_languages.dart';
import '../providers/ai_settings_provider.dart';
import '../providers/translation_provider.dart';
import '../providers/example_favorites_provider.dart';
import '../providers/speech_provider.dart';
import '../../features/reader/widgets/neural_path_dialog.dart';
import 'sync_item_card.dart' show NeuralPathButton;
import '../theme/app_theme_colors.dart';

// ═══════════════════════════════════════════════════════════════════
// پنلِ «مثال (با هوش مصنوعی)» — پورتِ WordExamples در Hope
// • با باز شدن، اگر مثالی نیست خودکار اولین مثال ساخته می‌شود (بدون انتظارِ اضافه)
// • مثال‌ها روی گوشی کش می‌شوند؛ «مثالِ جدید» با لیستِ قبلی تکراری نمی‌سازد
// • هر مثال: 🔊، 🔁 (جایگزینیِ همان مثال)، و ترجمه به زبان‌های انتخابی
// ═══════════════════════════════════════════════════════════════════
class WordExamplesPanel extends ConsumerStatefulWidget {
  final String word;
  final String langCode;
  final String meaningNative;
  final String nativeCode;
  final List<String> targetLangs;

  /// عرضِ ستونِ کناریِ کارت: کنارِ هر جعبه‌ی مثال یک ⭐ (علاقه‌مندیِ همان مثال)
  /// دقیقاً زیرِ ⭐ِ لغتِ بالای کارت قرار می‌گیرد.
  final double gutter;

  const WordExamplesPanel({
    super.key,
    required this.word,
    required this.langCode,
    required this.meaningNative,
    required this.nativeCode,
    required this.targetLangs,
    this.gutter = 0,
  });

  @override
  ConsumerState<WordExamplesPanel> createState() => _WordExamplesPanelState();
}

class _WordExamplesPanelState extends ConsumerState<WordExamplesPanel> {
  List<WordExample> _examples = [];
  bool _generating = false;
  String? _refreshingId;
  String _err = '';

  String get _nativeLabel {
    for (final l in kSupportedLanguages) {
      if (l.code == widget.nativeCode) return l.enLabel;
    }
    return widget.nativeCode;
  }

  @override
  void initState() {
    super.initState();
    _examples = ref
        .read(wordExamplesStoreProvider)
        .load(widget.word, widget.langCode);
    if (_examples.isEmpty) _generate();
  }

  Future<void> _generate() async {
    if (_generating) return;
    setState(() {
      _generating = true;
      _err = '';
    });
    try {
      final text = await generateWordExample(
        svc: ref.read(translationServiceProvider),
        settings: ref.read(aiSettingsProvider),
        word: widget.word,
        langCode: widget.langCode,
        meaningNative: widget.meaningNative,
        nativeLabel: _nativeLabel,
        existing: _examples.map((e) => e.text).toList(),
      );
      final list = await ref
          .read(wordExamplesStoreProvider)
          .add(widget.word, widget.langCode, text);
      if (!mounted) return;
      setState(() => _examples = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _err = context.l10n.word_examples_failed);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _refresh(String id) async {
    if (_refreshingId != null) return;
    setState(() {
      _refreshingId = id;
      _err = '';
    });
    try {
      final text = await generateWordExample(
        svc: ref.read(translationServiceProvider),
        settings: ref.read(aiSettingsProvider),
        word: widget.word,
        langCode: widget.langCode,
        meaningNative: widget.meaningNative,
        nativeLabel: _nativeLabel,
        existing:
            _examples.where((e) => e.id != id).map((e) => e.text).toList(),
      );
      final list = await ref
          .read(wordExamplesStoreProvider)
          .replace(widget.word, widget.langCode, id, text);
      if (!mounted) return;
      setState(() => _examples = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _err = context.l10n.word_examples_failed);
    } finally {
      if (mounted) setState(() => _refreshingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final targets =
        widget.targetLangs.where((l) => l != widget.langCode).toList();

    final g = widget.gutter;

    // ⭐ِ هر مثال: ستونِ کناری، هم‌راستا با ⭐ِ لغت
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                InkWell(
                  onTap: _generating ? null : _generate,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: c.goldSoft),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_generating)
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.6, color: c.gold),
                          )
                        else
                          Icon(Icons.auto_awesome, size: 12, color: c.gold),
                        const SizedBox(width: 4),
                        Text(
                          _generating
                              ? context.l10n.word_examples_generating
                              : (_examples.isEmpty
                                  ? context.l10n.word_examples_btn_generate
                                  : context.l10n.word_examples_btn_another),
                          style: TextStyle(
                              color: c.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                if (g > 0) SizedBox(width: g),
              ],
            ),
          ),
          if (_err.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 4, right: g),
              child: Text(_err, style: TextStyle(color: c.rose, fontSize: 11)),
            ),
          for (var i = 0; i < _examples.length; i++)
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ExampleRow(
                      key: ValueKey(_examples[i].id + _examples[i].text),
                      word: widget.word,
                      langCode: widget.langCode,
                      example: _examples[i],
                      targets: targets,
                      refreshing: _refreshingId == _examples[i].id,
                      onRefresh: () => _refresh(_examples[i].id),
                    ),
                  ),
                  if (g > 0)
                    SizedBox(
                      width: g,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _ExampleStar(
                            word: widget.word,
                            langCode: widget.langCode,
                            example: _examples[i],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// ⭐ِ مثال (ستونِ کناریِ جعبه‌ی مثال) — کلِ مثال با ترجمه‌هایش به علاقه‌مندی‌ها می‌رود.
class _ExampleStar extends ConsumerWidget {
  final String word;
  final String langCode;
  final WordExample example;

  const _ExampleStar({
    required this.word,
    required this.langCode,
    required this.example,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final key = '$langCode::${example.text.trim()}';
    final fav = ref.watch(
        exampleFavoritesProvider.select((l) => l.any((f) => f.key == key)));
    return Directionality(
      textDirection: TextDirection.ltr,
      child: InkResponse(
        onTap: () {
          // ترجمه‌هایی که تا الان گرفته شده‌اند، از حافظه‌ی مثال‌ها
          final stored = ref
              .read(wordExamplesStoreProvider)
              .load(word, langCode)
              .where((e) => e.id == example.id);
          final tr = stored.isNotEmpty ? stored.first.translations : example.translations;
          ref.read(exampleFavoritesProvider.notifier).toggle(
                example.text,
                langCode,
                word,
                translations: tr,
              );
        },
        radius: 16,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(fav ? Icons.star : Icons.star_border,
              size: 20,
              color: fav
                  ? const Color(0xFFF5C518)
                  : c.inkSoft.withOpacity(0.4)),
        ),
      ),
    );
  }
}

/// ردیفِ دکمه‌ها — از راست به چپ: 🔊 ← 🧬 ← رفرش (مثل ردیف‌های ترجمه)
class _ExActions extends ConsumerWidget {
  final String text;
  final String lang;
  final String baseText;
  final bool refreshing;
  final VoidCallback? onRefresh;

  const _ExActions({
    required this.text,
    required this.lang,
    required this.baseText,
    required this.refreshing,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkResponse(
            onTap: refreshing ? null : onRefresh,
            radius: 16,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: refreshing
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.6, color: c.inkSoft))
                  : Icon(Icons.refresh,
                      size: 16, color: c.inkSoft.withOpacity(0.7)),
            ),
          ),
          NeuralPathButton(
            onTap: () => showNeuralPath(
              context,
              word: text,
              langCode: lang,
              baseText: baseText,
            ),
          ),
          InkResponse(
            onTap: () =>
                ref.read(speechControllerProvider.notifier).toggle(text, lang),
            radius: 16,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.volume_up_outlined, size: 18, color: c.gold),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleRow extends ConsumerWidget {
  final String word;
  final String langCode;
  final WordExample example;
  final List<String> targets;
  final bool refreshing;
  final VoidCallback onRefresh;

  const _ExampleRow({
    super.key,
    required this.word,
    required this.langCode,
    required this.example,
    required this.targets,
    required this.refreshing,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: c.paperDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.cardBorder),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      example.text,
                      style: TextStyle(
                          color: c.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.45),
                    ),
                  ),
                ),
                _ExActions(
                  text: example.text,
                  lang: langCode,
                  baseText: example.text,
                  refreshing: refreshing,
                  onRefresh: onRefresh,
                ),
              ],
            ),
            for (final t in targets)
              _ExampleTranslation(
                key: ValueKey('${example.id}::${example.text.hashCode}::$t'),
                word: word,
                langCode: langCode,
                example: example,
                target: t,
              ),
          ],
        ),
      ),
    );
  }
}

class _ExampleTranslation extends ConsumerStatefulWidget {
  final String word;
  final String langCode;
  final WordExample example;
  final String target;

  const _ExampleTranslation({
    super.key,
    required this.word,
    required this.langCode,
    required this.example,
    required this.target,
  });

  @override
  ConsumerState<_ExampleTranslation> createState() =>
      _ExampleTranslationState();
}

class _ExampleTranslationState extends ConsumerState<_ExampleTranslation> {
  String _text = '';
  bool _failed = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _text = widget.example.translations[widget.target] ?? '';
    if (_text.isEmpty) _load();
  }

  Future<void> _load() async {
    try {
      final t = await ref.read(translationServiceProvider).translate(
            text: widget.example.text,
            targetLang: widget.target,
            sourceLang: widget.langCode,
            aiSettings: ref.read(aiSettingsProvider),
            forceVerify: true,
          );
      if (!mounted) return;
      if (t.trim().isEmpty || t.trim() == widget.example.text.trim()) {
        setState(() => _failed = true);
        return;
      }
      setState(() => _text = t.trim());
      await ref.read(wordExamplesStoreProvider).setTranslation(
          widget.word, widget.langCode, widget.example.id, widget.target, t);
      ref.read(exampleFavoritesProvider.notifier).setTranslation(
          widget.example.text, widget.langCode, widget.target, t);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// رفرش: ترجمه‌ی دوباره بدون کش (مترجم‌های رایگان + ناظر AI).
  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _failed = false;
    });
    try {
      final t = await ref.read(translationServiceProvider).retranslate(
            text: widget.example.text,
            targetLang: widget.target,
            sourceLang: widget.langCode,
            aiSettings: ref.read(aiSettingsProvider),
            previous: _text,
          );
      if (!mounted) return;
      final v = t.trim();
      if (v.isEmpty || v == widget.example.text.trim()) {
        setState(() => _failed = _text.isEmpty);
        return;
      }
      setState(() => _text = v);
      await ref.read(wordExamplesStoreProvider).setTranslation(
          widget.word, widget.langCode, widget.example.id, widget.target, v);
      ref.read(exampleFavoritesProvider.notifier).setTranslation(
          widget.example.text, widget.langCode, widget.target, v);
    } catch (_) {
      if (mounted && _text.isEmpty) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    String abbr = widget.target.toUpperCase();
    bool rtl = widget.target == 'fa' || widget.target == 'ar';
    for (final l in kSupportedLanguages) {
      if (l.code == widget.target) {
        abbr = l.abbr;
        rtl = l.dir == TextDirection.rtl;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              border: Border.all(color: c.goldSoft),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(abbr,
                style: TextStyle(
                    color: c.gold, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: _text.isEmpty
                  ? Text(_failed ? '—' : context.l10n.grammar_translating,
                      style: TextStyle(color: c.inkSoft, fontSize: 11))
                  : Directionality(
                      textDirection:
                          rtl ? TextDirection.rtl : TextDirection.ltr,
                      child: Text(_text,
                          style: TextStyle(
                              color: c.teal,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              height: 1.45)),
                    ),
            ),
          ),
          _ExActions(
            text: _text,
            lang: widget.target,
            baseText: widget.example.text,
            refreshing: _refreshing,
            onRefresh: _refresh,
          ),
        ],
      ),
    );
  }
}
