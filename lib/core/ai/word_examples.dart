import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/supported_languages.dart';
import '../storage/local_storage.dart';
import '../translate/translation_service.dart';
import 'ai_gateway.dart';

// پورتِ app/words/wordExamples.js — همان کلیدِ وب، پس ساختار یکی است.
const String kWordExamplesKey = 'phrasebook-word-examples-v1';

class WordExample {
  final String id;
  final String text;
  final Map<String, String> translations;

  const WordExample({
    required this.id,
    required this.text,
    this.translations = const {},
  });

  WordExample copyWith({String? text, Map<String, String>? translations}) =>
      WordExample(
        id: id,
        text: text ?? this.text,
        translations: translations ?? this.translations,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'translations': translations,
        'createdAt': DateTime.now().toIso8601String(),
      };

  factory WordExample.fromJson(Map<String, dynamic> j) => WordExample(
        id: (j['id'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
        translations: {
          for (final e in ((j['translations'] as Map?) ?? const {}).entries)
            e.key.toString(): e.value.toString(),
        },
      );
}

class WordExamplesStore {
  final SharedPreferences _sp;
  WordExamplesStore(this._sp);

  static String _key(String word, String lang) =>
      '$lang::${word.trim().toLowerCase()}';

  Map<String, dynamic> _all() {
    final raw = _sp.getString(kWordExamplesKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final d = jsonDecode(raw);
      return d is Map<String, dynamic> ? d : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _write(Map<String, dynamic> all) =>
      _sp.setString(kWordExamplesKey, jsonEncode(all));

  List<WordExample> load(String word, String lang) {
    final list = _all()[_key(word, lang)];
    if (list is! List) return [];
    return [
      for (final e in list)
        if (e is Map) WordExample.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  Future<List<WordExample>> add(String word, String lang, String text) async {
    final all = _all();
    final k = _key(word, lang);
    final cur = load(word, lang);
    final ex = WordExample(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      text: text,
    );
    cur.insert(0, ex);
    all[k] = cur.map((e) => e.toJson()).toList();
    await _write(all);
    return cur;
  }

  Future<List<WordExample>> replace(
      String word, String lang, String id, String text) async {
    final all = _all();
    final k = _key(word, lang);
    final cur = load(word, lang);
    final i = cur.indexWhere((e) => e.id == id);
    if (i == -1) return cur;
    // ترجمه‌های قبلی مالِ متنِ قدیمی بودند
    cur[i] = cur[i].copyWith(text: text, translations: const {});
    all[k] = cur.map((e) => e.toJson()).toList();
    await _write(all);
    return cur;
  }

  Future<void> setTranslation(
      String word, String lang, String id, String target, String text) async {
    if (text.trim().isEmpty) return;
    final all = _all();
    final k = _key(word, lang);
    final cur = load(word, lang);
    final i = cur.indexWhere((e) => e.id == id);
    if (i == -1) return;
    cur[i] = cur[i].copyWith(
        translations: {...cur[i].translations, target: text.trim()});
    all[k] = cur.map((e) => e.toJson()).toList();
    await _write(all);
  }
}

final wordExamplesStoreProvider = Provider<WordExamplesStore>(
    (ref) => WordExamplesStore(ref.watch(sharedPrefsProvider)));

String _langLabel(String code) {
  for (final l in kSupportedLanguages) {
    if (l.code == code) return l.enLabel;
  }
  return englishLangName(code);
}

/// یک جمله‌ی مثالِ واقعی و امروزی — و صریحاً می‌گوییم کدام مثال‌ها قبلاً
/// ساخته شده‌اند تا تکراری نسازد (همان پرامپتِ وب).
Future<String> generateWordExample({
  required TranslationService svc,
  required AiSettings settings,
  required String word,
  required String langCode,
  String meaningNative = '',
  String nativeLabel = '',
  List<String> existing = const [],
}) async {
  final langLabel = _langLabel(langCode);
  final avoid = existing.isEmpty
      ? ''
      : 'Do NOT reuse or closely paraphrase any of these already-used examples for this same word:\n'
          '${[for (var i = 0; i < existing.length; i++) '${i + 1}. ${existing[i]}'].join('\n')}\n\n';
  final meaning = meaningNative.isEmpty
      ? ''
      : ' (its ${nativeLabel.isEmpty ? 'native-language' : nativeLabel} meaning is: "$meaningNative")';
  final prompt =
      'Write exactly ONE natural example sentence in $langLabel that uses the word/expression "$word"$meaning '
      'in a way that reflects REAL, current, everyday usage — the kind of sentence a native speaker might actually say or write today. '
      'Avoid textbook-sounding, generic sentences. '
      'Keep it natural length (roughly 8-20 words), grammatically correct, and appropriate for a language learner to study.\n\n'
      '${avoid}Respond with ONLY the example sentence itself in $langLabel — no quotes, no translation, no numbering, no explanation, nothing else.';

  final out = await aiGenerate(
    svc: svc,
    settings: settings,
    prompt: prompt,
    maxTokens: 200,
    retries: 1,
    timeoutMs: 12000,
    // بیشتر از یک خط یا خیلی بلند = جمله‌ی مثال نیست
    extraCheck: (t) => !t.trim().contains('\n') && t.length <= 300,
  );
  final s = out
      .replaceAll(RegExp(r'''^["'«»“”\s]+|["'«»“”.\s]+$'''), '')
      .trim();
  if (s.isEmpty) throw const AiOutputException('empty');
  return s;
}
