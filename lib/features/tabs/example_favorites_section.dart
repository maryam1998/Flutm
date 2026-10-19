import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/supported_languages.dart';
import '../../core/providers/ai_settings_provider.dart';
import '../../core/providers/example_favorites_provider.dart';
import '../../core/providers/language_selection_provider.dart';
import '../../core/providers/speech_provider.dart';
import '../../core/providers/translation_provider.dart';
import '../../core/theme/app_theme_colors.dart';
import '../../core/widgets/sync_item_card.dart' show NeuralPathButton;
import '../reader/widgets/neural_path_dialog.dart';

/// مثال‌های ⭐‌دارِ مثال‌ساز — بالای لیست علاقه‌مندی‌ها.
/// هر مثال با ترجمه به همه‌ی زبان‌های تارگتِ کاربر نشان داده می‌شود
/// (ترجمه‌ی ناموجود همین‌جا ساخته و ذخیره می‌شود).
class ExampleFavoritesSection extends ConsumerWidget {
  const ExampleFavoritesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(exampleFavoritesProvider);
    if (favs.isEmpty) return const SizedBox.shrink();
    final c = context.appColors;
    final fa = Localizations.localeOf(context).languageCode == 'fa';
    final sel = ref.watch(languageSelectionProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            fa ? 'مثال‌ها' : 'Examples',
            style: TextStyle(
                color: c.ink, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          for (final f in favs)
            _FavCard(
              key: ValueKey(f.key),
              fav: f,
              targets: [
                for (final t in sel.targets)
                  if (t.isNotEmpty && t != f.lang) t,
              ].toSet().toList(),
            ),
        ],
      ),
    );
  }
}

class _FavCard extends ConsumerWidget {
  final ExampleFav fav;
  final List<String> targets;
  const _FavCard({super.key, required this.fav, required this.targets});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final rtl = dirFor(fav.lang) == TextDirection.rtl;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.cardBorder),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Directionality(
                            textDirection:
                                rtl ? TextDirection.rtl : TextDirection.ltr,
                            child: Text(fav.text,
                                style: TextStyle(
                                    color: c.ink,
                                    fontSize: 13.5,
                                    height: 1.4,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                      _Btns(text: fav.text, lang: fav.lang, base: fav.text),
                    ],
                  ),
                  for (final t in targets)
                    _FavTranslation(
                      key: ValueKey('${fav.key}::$t'),
                      fav: fav,
                      target: t,
                    ),
                ],
              ),
            ),
            // ⭐ سمت راست (برداشتن از علاقه‌مندی‌ها)
            InkResponse(
              onTap: () => ref
                  .read(exampleFavoritesProvider.notifier)
                  .toggle(fav.text, fav.lang, fav.word),
              radius: 16,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.star, size: 20, color: Color(0xFFF5C518)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🧬 و 🔊 — از راست: 🔊 ← 🧬
class _Btns extends ConsumerWidget {
  final String text;
  final String lang;
  final String base;
  const _Btns({required this.text, required this.lang, required this.base});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NeuralPathButton(
          onTap: () => showNeuralPath(context,
              word: text, langCode: lang, baseText: base),
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
    );
  }
}

class _FavTranslation extends ConsumerStatefulWidget {
  final ExampleFav fav;
  final String target;
  const _FavTranslation({super.key, required this.fav, required this.target});

  @override
  ConsumerState<_FavTranslation> createState() => _FavTranslationState();
}

class _FavTranslationState extends ConsumerState<_FavTranslation> {
  String _text = '';
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _text = widget.fav.translations[widget.target] ?? '';
    if (_text.isEmpty) _load();
  }

  Future<void> _load() async {
    try {
      final t = await ref.read(translationServiceProvider).translate(
            text: widget.fav.text,
            targetLang: widget.target,
            sourceLang: widget.fav.lang,
            aiSettings: ref.read(aiSettingsProvider),
            forceVerify: true,
          );
      if (!mounted) return;
      final v = t.trim();
      if (v.isEmpty || v == widget.fav.text.trim()) {
        setState(() => _failed = true);
        return;
      }
      setState(() => _text = v);
      await ref.read(exampleFavoritesProvider.notifier).setTranslation(
          widget.fav.text, widget.fav.lang, widget.target, v);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    String abbr = widget.target.toUpperCase();
    final rtl = dirFor(widget.target) == TextDirection.rtl;
    for (final l in kSupportedLanguages) {
      if (l.code == widget.target) abbr = l.abbr;
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
                  ? Text(_failed ? '—' : 'در حال ترجمه...',
                      style: TextStyle(color: c.inkSoft, fontSize: 11))
                  : Directionality(
                      textDirection:
                          rtl ? TextDirection.rtl : TextDirection.ltr,
                      child: Text(_text,
                          style: TextStyle(
                              color: const Color(0xFF0F5C34),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              height: 1.45)),
                    ),
            ),
          ),
          if (_text.isNotEmpty)
            _Btns(text: _text, lang: widget.target, base: widget.fav.text),
        ],
      ),
    );
  }
}
