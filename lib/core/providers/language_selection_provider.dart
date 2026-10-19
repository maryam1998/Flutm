import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/language_selection.dart';
import '../storage/local_storage.dart';
import '../storage/prefs_keys.dart';

class LanguageSelectionNotifier extends StateNotifier<LanguageSelection> {
  final LocalStorage _storage;

  LanguageSelectionNotifier(this._storage) : super(_read(_storage));

  static LanguageSelection _read(LocalStorage s) {
    final json = s.readJson(PrefsKeys.languageSelection);
    return LanguageSelection.fromJson(json);
  }

  Future<void> _persist(LanguageSelection next) async {
    state = next;
    await _storage.writeJson(PrefsKeys.languageSelection, next.toJson());
  }

  Future<void> setNative(String code) =>
      _persist(state.copyWith(native: code));

  Future<void> toggleTarget(String code) {
    final list = [...state.targets];
    if (list.contains(code)) {
      if (list.length > 1) list.remove(code);
    } else {
      list.add(code);
    }
    return _persist(state.copyWith(targets: list));
  }

  Future<void> removeTarget(String code) {
    final list = [...state.targets]..remove(code);
    if (list.isEmpty) list.add('en');
    return _persist(state.copyWith(targets: list));
  }

  /// جابجایی ترتیب زبان‌های مقصد — هم از چیپ، هم از دایره.
  Future<void> reorderTargets(int oldIndex, int newIndex) {
    final list = [...state.targets];
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    return _persist(state.copyWith(targets: list));
  }

  /// جابجایی ترتیب دایره‌های زبان مادری (فقط ترتیب نمایش).
  Future<void> reorderNativeDisplay(int oldIndex, int newIndex) {
    // در provider ذخیره نمی‌شه — فقط در memory برای نمایش.
    return Future.value();
  }
}

final languageSelectionProvider =
    StateNotifierProvider<LanguageSelectionNotifier, LanguageSelection>((ref) {
  return LanguageSelectionNotifier(ref.watch(localStorageProvider));
});

/// ترتیب دلخواه دایره‌های زبان مادری (فقط در memory).
class NativeOrderNotifier extends StateNotifier<List<String>> {
  NativeOrderNotifier() : super([]);

  void reorder(List<String> defaultOrder, int oldIndex, int newIndex) {
    final list = state.isEmpty ? [...defaultOrder] : [...state];
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
  }

  List<String> currentOr(List<String> defaultOrder) {
    if (state.isEmpty) return defaultOrder;
    // sync: هر زبان جدیدی که در defaults هست ولی در state نیست را اضافه کن.
    final result = [...state.where((c) => defaultOrder.contains(c))];
    for (final c in defaultOrder) {
      if (!result.contains(c)) result.add(c);
    }
    return result;
  }
}

final nativeOrderProvider =
    StateNotifierProvider<NativeOrderNotifier, List<String>>((ref) {
  return NativeOrderNotifier();
});

/// ترتیب دلخواه دایره‌های زبان مقصد (فقط در memory).
/// منطق: انتخاب‌شده‌ها اول (به ترتیب targets)، بعد بقیه به ترتیب دلخواه.
class TargetDisplayOrderNotifier extends StateNotifier<List<String>> {
  TargetDisplayOrderNotifier() : super([]);

  void setOrder(List<String> order) => state = order;

  void reorder(List<String> currentOrder, int oldIndex, int newIndex) {
    final list = [...currentOrder];
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
  }
}

final targetDisplayOrderProvider =
    StateNotifierProvider<TargetDisplayOrderNotifier, List<String>>((ref) {
  return TargetDisplayOrderNotifier();
});

/// نگاشت کد → نام فارسی.
String langFaName(String code) {
  switch (code) {
    case 'fa': return 'فارسی';
    case 'en': return 'انگلیسی';
    case 'ar': return 'عربی';
    case 'de': return 'آلمانی';
    case 'es': return 'اسپانیایی';
    case 'fr': return 'فرانسوی';
    case 'it': return 'ایتالیایی';
    case 'ru': return 'روسی';
    case 'tr': return 'ترکی';
    case 'hi': return 'هندی';
    case 'zh': return 'چینی';
    case 'ja': return 'ژاپنی';
    case 'ko': return 'کره‌ای';
    default:   return code.toUpperCase();
  }
}

// ═══════════════════════════════════════════════════════════════════
// زبان‌هایی که زیر هر لغت/جمله باید ترجمه نشان داده شود
// — همان منطقِ WordList.jsx وب (effectiveDisplayLangs):
//   • مقصدها منهای انگلیسی (انگلیسی خودِ سرلغت است)
//   • زبان مادری (اگر en نباشد و جزو مقصدها نباشد) اولِ لیست می‌آید
//   • اگر چیزی نماند، حداقل فارسی
// ═══════════════════════════════════════════════════════════════════
List<String> effectiveDisplayLangs(LanguageSelection sel) {
  final targets = <String>[];
  for (final t in sel.targets) {
    if (t != 'en' && !targets.contains(t)) targets.add(t);
  }
  final nativeExtra =
      sel.native.isNotEmpty && sel.native != 'en' && !targets.contains(sel.native)
          ? sel.native
          : null;
  if (nativeExtra != null) return [nativeExtra, ...targets];
  return targets.isNotEmpty ? targets : const ['fa'];
}

final displayLangsProvider = Provider<List<String>>((ref) {
  final sel = ref.watch(languageSelectionProvider);
  return effectiveDisplayLangs(sel);
});
