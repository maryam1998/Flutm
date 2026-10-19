import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/speech_provider.dart';
import '../tts/speech_state.dart';
import 'player_track.dart';

/// آیتمی که همین الان (در حین پخش یا مکث) خوانده می‌شود: {زبان، شناسه}
@immutable
class ActiveSync {
  final String code;
  final String id;
  const ActiveSync(this.code, this.id);

  @override
  bool operator ==(Object other) =>
      other is ActiveSync && other.code == code && other.id == id;

  @override
  int get hashCode => Object.hash(code, id);
}

@immutable
class PlayerSyncState {
  /// شناسه‌ی «اسکوپ» فعلی (هر تب/لیستِ بازشده یکی دارد)
  final String? scopeId;

  /// کدِ زبانِ «متنِ اصلی» این اسکوپ (برای لغات/مکالمات 'en'؛ برای داستان
  /// زبانِ خودِ داستان)
  final String mainCode;

  /// متنِ کاملِ هر زبان: [mainCode] = متنِ اصلی، بقیه = ترجمه‌ها
  final Map<String, PlayerTrack> tracks;

  const PlayerSyncState(
      {this.scopeId, this.mainCode = 'en', this.tracks = const {}});
}

/// قلبِ سیستمِ مشترکِ پلیر برای همه‌ی تب‌ها — معادلِ این الگوی Hope که
/// هر تب جداگانه تکرارش کرده بود (fullText + offsets + activeId):
///   1. تب آیتم‌هایش را ثبت می‌کند → متنِ کاملِ زبانِ اصلی ساخته می‌شود
///   2. هر ردیفِ ترجمه وقتی آماده شد گزارش می‌دهد → متنِ کاملِ هر زبان
///   3. [activeSyncProvider] از رویِ وضعیتِ پخش + آفست، آیتمِ فعال را می‌دهد
class PlayerSyncNotifier extends StateNotifier<PlayerSyncState> {
  PlayerSyncNotifier(this._ref) : super(const PlayerSyncState());

  final Ref _ref;

  List<SyncItem> _items = const [];
  TrackMode _mode = TrackMode.lines;
  String _mainCode = 'en';
  final Map<String, Map<String, String>> _trans = {};
  final Map<String, Map<String, String>> _pending = {};
  Timer? _debounce;

  /// متنِ اصلی (انگلیسی) آیتمی که این شناسه را دارد — برای اتصالِ پلیر به
  /// «مسیر عصبی» (همه‌ی زبان‌های یک آیتم یک تقویم دارند).
  String? itemText(String id) {
    for (final it in _items) {
      if (it.id == id) return it.text;
    }
    return null;
  }

  /// ثبتِ آیتم‌های اسکوپ. اگر اسکوپِ دیگری فعال بود جایگزین می‌شود.
  void setScope(String scopeId, List<SyncItem> items, TrackMode mode,
      {String mainCode = 'en'}) {
    _debounce?.cancel();
    _items = items;
    _mode = mode;
    _mainCode = mainCode;
    _trans.clear();
    _pending.clear();
    state = PlayerSyncState(
      scopeId: scopeId,
      mainCode: mainCode,
      tracks: {mainCode: PlayerTrack.build(mainCode, items, mode)},
    );
  }

  /// خروج از تب/لیست — فقط اگر اسکوپِ فعال همین باشد پاک می‌کند (تا
  /// dispose با تأخیرِ تبِ قبلی، اسکوپِ تبِ جدید را پاک نکند).
  void clearScope(String scopeId) {
    if (state.scopeId != scopeId) return;
    _debounce?.cancel();
    _items = const [];
    _trans.clear();
    _pending.clear();
    state = const PlayerSyncState();
  }

  /// هر ردیفِ ترجمه، به محضِ آماده‌شدنِ مقدارش صدا می‌زند
  /// (معادل onResolveTranslation / reportTranslation در Hope).
  void reportTranslation(String scopeId, String code, String id, String text) {
    if (state.scopeId != scopeId || code == _mainCode) return;
    final t = text.trim();
    if (t.isEmpty) return;
    if (_trans[code]?[id] == t || _pending[code]?[id] == t) return;
    (_pending[code] ??= {})[id] = t;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _flush);
  }

  void _flush() {
    if (!mounted) return;
    final sp = _ref.read(speechControllerProvider);
    final playingKey = sp.status == SpeechStatus.idle ? null : sp.key;

    var tracks = state.tracks;
    var changed = false;
    var deferred = false;

    for (final code in _pending.keys.toList()) {
      final cur = tracks[code];
      // وقتی همین ترجمه در حالِ پخش است، متنش را عوض نمی‌کنیم — کلیدِ پخش
      // عوض می‌شد و هایلایتِ وسطِ پخش قطع می‌شد. بعد از توقف اعمال می‌شود.
      if (cur != null && playingKey != null && cur.key == playingKey) {
        deferred = true;
        continue;
      }
      (_trans[code] ??= {}).addAll(_pending.remove(code)!);
      final entries = <SyncItem>[];
      final map = _trans[code]!;
      for (final it in _items) {
        final v = map[it.id];
        if (v != null && v.isNotEmpty) entries.add(SyncItem(it.id, v));
      }
      tracks = {...tracks, code: PlayerTrack.build(code, entries, _mode)};
      changed = true;
    }

    if (changed) {
      state = PlayerSyncState(
          scopeId: state.scopeId, mainCode: _mainCode, tracks: tracks);
    }
    if (deferred) {
      _debounce = Timer(const Duration(seconds: 1), _flush);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final playerSyncProvider =
    StateNotifierProvider<PlayerSyncNotifier, PlayerSyncState>(
        (ref) => PlayerSyncNotifier(ref));

/// آیتمِ در حال خواندن — null اگر چیزی از این اسکوپ پخش نمی‌شود.
/// (Hope: status === "idle" → null؛ مکث هم همچنان هایلایت دارد.)
final activeSyncProvider = Provider<ActiveSync?>((ref) {
  final sp = ref.watch(speechControllerProvider
      .select((s) => (key: s.key, status: s.status, offset: s.charOffset)));
  if (sp.key == null || sp.status == SpeechStatus.idle) return null;

  final tracks = ref.watch(playerSyncProvider.select((s) => s.tracks));
  for (final t in tracks.values) {
    if (t.key != sp.key) continue;
    final span = t.spanAt(sp.offset);
    return span == null ? null : ActiveSync(t.code, span.id);
  }
  return null;
});
