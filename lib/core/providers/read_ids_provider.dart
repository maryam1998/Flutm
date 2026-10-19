import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_storage.dart';

/// ردیابیِ «خوانده‌شده» — مثل loadReadWordIds/saveReadWordIds در Hope:
/// برای هر لیست (listId) یک مجموعه‌ی id روی دستگاه ذخیره می‌شود تا بعد از
/// بستنِ برنامه هم بماند.
class ReadIdsNotifier extends StateNotifier<Set<String>> {
  final LocalStorage _storage;
  final String _key;

  ReadIdsNotifier(this._storage, String listId)
      : _key = 'zflut-read-ids-$listId-v1',
        super(_read(_storage, 'zflut-read-ids-$listId-v1'));

  static Set<String> _read(LocalStorage s, String key) {
    final ids = s.readJson(key)['ids'];
    if (ids is List) return ids.map((e) => e.toString()).toSet();
    return <String>{};
  }

  void _persist(Set<String> next) {
    state = next;
    unawaited(_storage.writeJson(_key, {'ids': next.toList()}));
  }

  void toggle(String id) {
    final next = {...state};
    if (!next.remove(id)) next.add(id);
    _persist(next);
  }

  /// علامت‌گذاری/پاک‌کردنِ علامتِ یک دسته (مثلاً کلِ بازه) با یک بار نوشتن.
  void setMany(Iterable<String> ids, bool read) {
    final next = {...state};
    if (read) {
      next.addAll(ids);
    } else {
      next.removeAll(ids);
    }
    _persist(next);
  }
}

/// listId: 'words' / 'slang' / 'vocab-in-use' / 'favorites' / 'conv-topics' / …
final readIdsProvider =
    StateNotifierProvider.family<ReadIdsNotifier, Set<String>, String>(
  (ref, listId) => ReadIdsNotifier(ref.read(localStorageProvider), listId),
);
