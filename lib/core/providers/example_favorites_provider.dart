import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_storage.dart';

const String _kExampleFavKey = 'phrasebook-example-favorites-v1';

/// جمله‌ی مثالِ مثال‌ساز که کاربر ⭐ زده — همراهِ ترجمه‌هایی که تا حالا
/// به زبان‌های دیگر (تارگت‌های کاربر) گرفته شده.
class ExampleFav {
  final String text;
  final String lang;
  final String word;

  /// کدِ زبان → ترجمه‌ی همین جمله
  final Map<String, String> translations;

  const ExampleFav({
    required this.text,
    required this.lang,
    required this.word,
    this.translations = const {},
  });

  String get key => '$lang::$text';

  ExampleFav withTranslation(String target, String t) =>
      ExampleFav(
        text: text,
        lang: lang,
        word: word,
        translations: {...translations, target: t},
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        'lang': lang,
        'word': word,
        if (translations.isNotEmpty) 'translations': translations,
      };

  factory ExampleFav.fromJson(Map<String, dynamic> j) => ExampleFav(
        text: (j['text'] ?? '').toString(),
        lang: (j['lang'] ?? 'en').toString(),
        word: (j['word'] ?? '').toString(),
        translations: {
          for (final e in ((j['translations'] as Map?) ?? const {}).entries)
            if (e.value.toString().trim().isNotEmpty)
              e.key.toString(): e.value.toString(),
        },
      );
}

class ExampleFavoritesNotifier extends StateNotifier<List<ExampleFav>> {
  final LocalStorage _storage;
  ExampleFavoritesNotifier(this._storage) : super(_read(_storage));

  static List<ExampleFav> _read(LocalStorage s) {
    final raw = s.readJson(_kExampleFavKey)['items'];
    if (raw is! List) return [];
    return [
      for (final e in raw)
        if (e is Map) ExampleFav.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  bool has(String text, String lang) =>
      state.any((f) => f.key == '$lang::$text');

  Future<void> _save(List<ExampleFav> next) async {
    state = next;
    await _storage.writeJson(
        _kExampleFavKey, {'items': next.map((f) => f.toJson()).toList()});
  }

  Future<void> toggle(
    String text,
    String lang,
    String word, {
    Map<String, String> translations = const {},
  }) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final key = '$lang::$t';
    final next = state.any((f) => f.key == key)
        ? state.where((f) => f.key != key).toList()
        : [
            ExampleFav(
              text: t,
              lang: lang,
              word: word,
              translations: {
                for (final e in translations.entries)
                  if (e.value.trim().isNotEmpty && e.key != lang)
                    e.key: e.value.trim(),
              },
            ),
            ...state,
          ];
    await _save(next);
  }

  /// ترجمه‌ای که بعد از ⭐ آمد (یا در تبِ علاقه‌مندی‌ها ساخته شد) به همان مثال اضافه می‌شود.
  Future<void> setTranslation(
      String text, String lang, String target, String translation) async {
    final key = '$lang::${text.trim()}';
    final v = translation.trim();
    if (v.isEmpty || target == lang) return;
    if (!state.any((f) => f.key == key)) return;
    await _save([
      for (final f in state)
        if (f.key == key) f.withTranslation(target, v) else f,
    ]);
  }
}

final exampleFavoritesProvider =
    StateNotifierProvider<ExampleFavoritesNotifier, List<ExampleFav>>(
        (ref) => ExampleFavoritesNotifier(ref.watch(localStorageProvider)));
