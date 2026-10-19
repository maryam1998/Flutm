import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_storage.dart';

const String _kStoriesKey = 'zflut-saved-stories-v1';

/// داستانِ ذخیره‌شده در «کتابخانه‌ی من».
@immutable
class SavedStory {
  final String id;
  final String title;
  final String text;
  final String langCode;
  final String level;
  final String contentType;
  final List<String> words;
  final DateTime createdAt;

  /// ترجمه‌ی هر پاراگراف به زبان‌های انتخابی: کد زبان → لیست ترجمه‌ی پاراگراف‌ها
  final Map<String, List<String>> translations;

  /// یادداشت‌های کاربر درباره‌ی این داستان
  final String notes;

  /// علاقه‌مندی (ستاره)
  final bool favorite;

  const SavedStory({
    required this.id,
    required this.title,
    required this.text,
    required this.langCode,
    required this.level,
    required this.contentType,
    required this.words,
    required this.createdAt,
    this.translations = const {},
    this.notes = '',
    this.favorite = false,
  });

  SavedStory copyWith({
    Map<String, List<String>>? translations,
    String? title,
    String? text,
    String? langCode,
    String? notes,
    bool? favorite,
  }) =>
      SavedStory(
        id: id,
        title: title ?? this.title,
        text: text ?? this.text,
        langCode: langCode ?? this.langCode,
        level: level,
        contentType: contentType,
        words: words,
        createdAt: createdAt,
        translations: translations ?? this.translations,
        notes: notes ?? this.notes,
        favorite: favorite ?? this.favorite,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'text': text,
        'langCode': langCode,
        'level': level,
        'contentType': contentType,
        'words': words,
        'createdAt': createdAt.toIso8601String(),
        'translations': translations,
        'notes': notes,
        'favorite': favorite,
      };

  factory SavedStory.fromJson(Map<String, dynamic> j) => SavedStory(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
        langCode: (j['langCode'] ?? 'en').toString(),
        level: (j['level'] ?? 'B1').toString(),
        contentType: (j['contentType'] ?? 'general').toString(),
        words: [
          for (final w in (j['words'] as List? ?? const [])) w.toString(),
        ],
        createdAt:
            DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.now(),
        notes: (j['notes'] ?? '').toString(),
        favorite: j['favorite'] == true,
        translations: {
          if (j['translations'] is Map)
            for (final e in (j['translations'] as Map).entries)
              e.key.toString(): [
                for (final v in (e.value as List? ?? const [])) v.toString(),
              ],
        },
      );
}

class StoryLibraryNotifier extends StateNotifier<List<SavedStory>> {
  final LocalStorage _storage;

  StoryLibraryNotifier(this._storage) : super(_read(_storage));

  static List<SavedStory> _read(LocalStorage s) {
    final raw = s.readJson(_kStoriesKey)['items'];
    if (raw is! List) return const [];
    final out = <SavedStory>[];
    for (final e in raw) {
      if (e is Map) {
        try {
          out.add(SavedStory.fromJson(Map<String, dynamic>.from(e)));
        } catch (_) {}
      }
    }
    return out;
  }

  void _set(List<SavedStory> next) {
    state = next;
    unawaited(_storage.writeJson(
        _kStoriesKey, {'items': next.map((e) => e.toJson()).toList()}));
  }

  /// جدیدترین اول.
  void add(SavedStory s) => _set([s, ...state]);

  void update(SavedStory s) =>
      _set([for (final e in state) e.id == s.id ? s : e]);

  void toggleFavorite(String id) => _set([
        for (final e in state)
          e.id == id ? e.copyWith(favorite: !e.favorite) : e,
      ]);

  void remove(String id) => _set(state.where((s) => s.id != id).toList());
}

final storyLibraryProvider =
    StateNotifierProvider<StoryLibraryNotifier, List<SavedStory>>(
  (ref) => StoryLibraryNotifier(ref.read(localStorageProvider)),
);

/// لغاتی که از «لغات ذخیره‌شده» با دکمه‌ی «افزودن به داستان‌ساز» فرستاده شده‌اند.
/// داستان‌ساز آن‌ها را برمی‌دارد و provider را دوباره null می‌کند.
@immutable
class StoryDraft {
  final String langCode;
  final List<String> words;
  const StoryDraft(this.langCode, this.words);
}

final storyDraftProvider = StateProvider<StoryDraft?>((ref) => null);
