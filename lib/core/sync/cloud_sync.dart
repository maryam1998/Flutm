// 📁 مسیر: lib/core/sync/cloud_sync.dart
//
// همگام‌سازیِ داده‌های کاربر با حساب (گوگل/ایمیل) روی Supabase — جدول user_sync
// (اسکریپت: supabase/user_sync.sql).
//
//  • key='data'  : همه‌ی تنظیمات و داده‌های محلی (کلیدهای phrasebook-* و zflut-*)
//  • key='packs' : فهرستِ مدل‌های آفلاینِ دانلودشده، مثل 'tts:en' | 'speech:de' | 'song:base'
//
// خودِ فایلِ مدل‌ها (صدها مگابایت) ابری نمی‌شود؛ «فهرست» آن‌ها با حساب می‌ماند و
// روی دستگاه/نصبِ جدید پیشنهادِ دانلودِ دوباره داده می‌شود.
// کاربر مهمان (بدون حساب) هیچ‌چیز ابری نمی‌شود.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bridge/linlearn_bridge.dart';
import '../constants/supported_languages.dart';
import '../native/native_bridge.dart';
import '../storage/durable_store.dart';
import '../storage/local_storage.dart' show sharedPrefsProvider;
import 'app_restarter.dart';
import 'data_merge.dart';

const String _kMeta = 'zflut-cloud-meta-v1';
const String _kDeleted = 'zflut-cloud-deleted-packs-v1';
const String _kDismissed = 'zflut-cloud-dismissed-packs-v1';
const String _kTable = 'user_sync';

/// مدل‌هایی که در حساب هستند ولی روی این دستگاه دانلود نشده‌اند (برای دیالوگِ بازیابی).
final missingPacksProvider = StateProvider<List<String>>((ref) => const <String>[]);

bool _syncable(String k) {
  if (k.startsWith('zflut-cloud-') || k.startsWith('zflut-auth-')) return false;
  if (k == 'zflut-speaking-chat-v1' ||
      k == 'zflut-mascot-daily-v1' ||
      k == 'phrasebook-backend-url') {
    return false;
  }
  return k.startsWith('phrasebook-') ||
      k.startsWith('zflut-') ||
      k == 'voiceEnginePref' ||
      k == 'syncModelSize';
}

int _fnv1a(String s) {
  var h = 0x811c9dc5;
  for (final u in s.codeUnits) {
    h ^= u;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

class CloudSync with WidgetsBindingObserver {
  final Ref _ref;
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<NativeEvent>? _nativeSub;
  Timer? _timer;
  Timer? _debounce;
  String? _startedFor;
  String? _reconciledFor; // تا تطبیقِ موفق انجام نشده هیچ‌چیز روی ابر نوشته نمی‌شود
  Timer? _retry;
  bool _pushing = false;
  bool _disposed = false;

  CloudSync(this._ref) {
    _init();
  }

  SharedPreferences get _sp => _ref.read(sharedPrefsProvider);

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  void _init() {
    final c = _client;
    if (c == null) return;
    WidgetsBinding.instance.addObserver(this);
    LinLearnBridge.onPackDeleted = noteDeleted;

    _authSub = c.auth.onAuthStateChange.listen((s) {
      if (s.session != null) {
        unawaited(_start());
      } else {
        _timer?.cancel();
        _startedFor = null;
        _reconciledFor = null;
      }
    }, onError: (Object _) {});
    if (c.auth.currentSession != null) unawaited(_start());

    // پایان دانلودِ مدل ← ثبت در حساب
    if (NativeBridge.instance.isSupported) {
      _nativeSub = NativeBridge.instance.events.listen((e) {
        switch (e.name) {
          case 'ttsModelDownloadDone':
            _packDone('tts', e.data['lang']);
            break;
          case 'modelDownloadDone':
            _packDone('speech', e.data['lang']);
            break;
          case 'whisperDownloadDone':
            _packDone('song', e.data['model']);
            break;
        }
      }, onError: (Object _) {});
    }
  }

  void dispose() {
    _disposed = true;
    _authSub?.cancel();
    _nativeSub?.cancel();
    _timer?.cancel();
    _debounce?.cancel();
    _retry?.cancel();
    if (LinLearnBridge.onPackDeleted == noteDeleted) {
      LinLearnBridge.onPackDeleted = null;
    }
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(push());
    }
  }

  // ───────────────────────── متادیتای محلی ─────────────────────────
  Map<String, dynamic> _readMeta() {
    try {
      final raw = _sp.getString(_kMeta);
      if (raw == null || raw.isEmpty) return <String, dynamic>{};
      final d = jsonDecode(raw);
      return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeMeta(Map<String, dynamic> m) =>
      _sp.setString(_kMeta, jsonEncode(m));

  String _deviceId(Map<String, dynamic> meta) {
    final cur = meta['deviceId'];
    if (cur is String && cur.isNotEmpty) return cur;
    final r = Random.secure();
    final id = List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
    meta['deviceId'] = id;
    return id;
  }

  Set<String> _readSet(String key) =>
      (_sp.getStringList(key) ?? const <String>[]).toSet();

  Future<void> _writeSet(String key, Set<String> v) =>
      _sp.setStringList(key, v.toList());

  // ───────────────────────── مدل‌ها ─────────────────────────
  /// کاربر مدلی را حذف کرد ← از فهرستِ حساب هم برداشته شود.
  void noteDeleted(String kind, String id) {
    final s = _readSet(_kDeleted)..add('$kind:$id');
    unawaited(_writeSet(_kDeleted, s));
    _schedulePush();
  }

  void _packDone(String kind, dynamic id) {
    if (id == null) return;
    final key = '$kind:$id';
    final del = _readSet(_kDeleted);
    if (del.remove(key)) unawaited(_writeSet(_kDeleted, del));
    _schedulePush();
  }

  void _schedulePush() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () => unawaited(push()));
  }

  Future<Set<String>> _localPacks() async {
    final out = <String>{};
    if (!NativeBridge.instance.isSupported) return out;
    final n = NativeBridge.instance;
    try {
      final cat = await n.getTtsCatalog();
      final ls = cat['languages'];
      if (ls is List) {
        for (final l in ls) {
          if (l is Map && l['downloaded'] == true) out.add('tts:${l['lang']}');
        }
      }
    } catch (_) {}
    try {
      final s = await n.getWhisperStatus();
      final ms = s['models'];
      if (ms is List) {
        for (final m in ms) {
          if (m is Map && m['downloaded'] == true) out.add('song:${m['id']}');
        }
      }
    } catch (_) {}
    for (final l in kSupportedLanguages) {
      try {
        final s = await n.checkModelStatus(lang: l.code);
        if (s['downloaded'] == true) out.add('speech:${l.code}');
      } catch (_) {}
    }
    return out;
  }

  // ───────────────────────── داده‌ها ─────────────────────────
  Map<String, String> _collectData() {
    final sp = _sp;
    final keys = sp.getKeys().where(_syncable).toList()..sort();
    final out = <String, String>{};
    for (final k in keys) {
      final v = sp.get(k);
      if (v is String) out[k] = v;
    }
    return out;
  }

  /// داده‌ی ابری را با داده‌ی محلی «ادغام» می‌کند (به‌جای جایگزینی).
  Future<bool> _applyData(dynamic v) async {
    if (v is! Map) return false;
    var changed = false;
    for (final e in v.entries) {
      final k = e.key.toString();
      final val = e.value;
      if (val is! String || !_syncable(k)) continue;
      final cur = _sp.getString(k);
      final next = cur == null ? val : mergeSyncValue(cur, val);
      if (cur != next) {
        await _sp.setString(k, next);
        changed = true;
      }
    }
    if (changed) unawaited(DurableStore.instance.flush());
    return changed;
  }

  bool _cloudIsNewer(DateTime? cloudAt, DateTime? lastSync) =>
      cloudAt != null &&
      (lastSync == null ||
          cloudAt.isAfter(lastSync.add(const Duration(seconds: 2))));

  // ───────────────────────── شروع و تطبیق ─────────────────────────
  Future<void> _start() async {
    final user = _client?.auth.currentUser;
    if (user == null || _disposed) return;
    if (_startedFor == user.id) return;
    _startedFor = user.id;
    _reconciledFor = null;
    try {
      final restarting = await _reconcile(user.id);
      if (restarting) return;
    } catch (e) {
      debugPrint('CloudSync reconcile failed: $e');
      // اینترنت/سرور مشکل داشت: هرگز در این حالت چیزی روی ابر نمی‌نویسیم
      // (وگرنه داده‌ی خالیِ این دستگاه می‌توانست داده‌ی حساب را پاک کند).
      _startedFor = null;
      _retry?.cancel();
      _retry = Timer(const Duration(seconds: 20), () => unawaited(_start()));
      return;
    }
    _timer?.cancel();
    _timer = Timer.periodic(
        const Duration(seconds: 45), (_) => unawaited(push()));
  }

  /// true یعنی داده‌ی ابری روی دستگاه اعمال شد و اپ دوباره ساخته می‌شود.
  Future<bool> _reconcile(String uid) async {
    final c = _client!;
    final rows = await c
        .from(_kTable)
        .select('key,value,updated_at,device_id')
        .eq('user_id', uid);
    Map<String, dynamic>? dataRow;
    Map<String, dynamic>? packsRow;
    for (final r in (rows as List)) {
      if (r is! Map) continue;
      if (r['key'] == 'data') dataRow = Map<String, dynamic>.from(r);
      if (r['key'] == 'packs') packsRow = Map<String, dynamic>.from(r);
    }

    final meta = _readMeta();
    _deviceId(meta);
    var applied = false;

    if (dataRow != null) {
      final cloudAt = DateTime.tryParse('${dataRow['updated_at']}');
      final lastSync = DateTime.tryParse('${meta['lastSyncAt']}');
      final sameUser = meta['userId'] == uid;
      final cloudNewer = _cloudIsNewer(cloudAt, lastSync);

      if (!sameUser || cloudNewer) {
        // حسابِ دیگری قبلاً روی این دستگاه بوده: دادهٔ او با حساب جدید قاطی نشود.
        if (meta['userId'] != null && !sameUser) {
          final old = _sp.getKeys().where(_syncable).toList();
          for (final k in old) {
            await _sp.remove(k);
          }
          await DurableStore.instance.removeKeys(old);
        }
        applied = await _applyData(dataRow['value']);
        meta['lastSyncAt'] = cloudAt?.toUtc().toIso8601String();
        // بعد از ادغام، نسخه‌ی محلی ممکن است از ابر کامل‌تر باشد ← یک‌بار ارسال شود
        meta['lastHash'] = '';
      }
    }
    meta['userId'] = uid;
    await _writeMeta(meta);
    _reconciledFor = uid; // از این لحظه ارسال به ابر مجاز است

    // فهرست مدل‌ها: آنچه در حساب هست ولی روی این دستگاه نیست
    await _computeMissing(packsRow);

    if (applied) {
      AppRestarter.restart();
      return true;
    }
    await push(force: dataRow == null);
    return false;
  }

  Future<void> _computeMissing(Map<String, dynamic>? packsRow) async {
    if (!NativeBridge.instance.isSupported || packsRow == null) return;
    final v = packsRow['value'];
    final items = (v is Map && v['items'] is List)
        ? (v['items'] as List).map((e) => e.toString()).toSet()
        : <String>{};
    if (items.isEmpty) return;
    final local = await _localPacks();
    final missing = items
        .difference(local)
        .difference(_readSet(_kDismissed))
        .difference(_readSet(_kDeleted))
        .toList()
      ..sort();
    if (missing.isNotEmpty && !_disposed) {
      _ref.read(missingPacksProvider.notifier).state = missing;
    }
  }

  /// کاربر در دیالوگِ بازیابی «بعداً» زد — دوباره مزاحم نشویم.
  void dismissMissing(List<String> ids) {
    final s = _readSet(_kDismissed)..addAll(ids);
    unawaited(_writeSet(_kDismissed, s));
    _ref.read(missingPacksProvider.notifier).state = const <String>[];
  }

  /// دانلودِ دوبارهٔ مدل‌های حساب روی این دستگاه (تکی‌تکی برای speech/song).
  Future<void> restorePacks(List<String> ids) async {
    _ref.read(missingPacksProvider.notifier).state = const <String>[];
    for (final id in ids) {
      final i = id.indexOf(':');
      if (i <= 0) continue;
      final kind = id.substring(0, i);
      final pid = id.substring(i + 1);
      final ok = await LinLearnBridge.packDownload(kind, pid);
      if (!ok || kind == 'tts') continue;
      await Future<void>.delayed(const Duration(seconds: 2));
      for (var t = 0; t < 900; t++) {
        final st = await LinLearnBridge.packStatus(kind, pid);
        if (st == null || st['downloading'] != true) break;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    unawaited(push());
  }

  // ───────────────────────── ارسال ─────────────────────────
  Future<void> push({bool force = false}) async {
    if (_pushing) return;
    final c = _client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) return;
    if (_reconciledFor != user.id) return; // هنوز تطبیقِ موفق انجام نشده
    _pushing = true;
    try {
      final uid = user.id;
      final meta = _readMeta();
      final deviceId = _deviceId(meta);
      final now = DateTime.now().toUtc().toIso8601String();

      var data = _collectData();
      var h = _fnv1a(jsonEncode(data)).toString();
      if (force || meta['lastHash'] != h) {
        // ۱) اگر بعد از آخرین همگام‌سازیِ ما چیزی در ابر عوض شده (دستگاهِ دیگر یا
        //    بکاپِ قدیمیِ همین دستگاه)، اول ادغام کن؛ بازنویسی نکن.
        final heads = await c
            .from(_kTable)
            .select('updated_at')
            .eq('user_id', uid)
            .eq('key', 'data');
        if ((heads as List).isNotEmpty) {
          final cloudAt =
              DateTime.tryParse('${(heads.first as Map)['updated_at']}');
          final lastSync = DateTime.tryParse('${meta['lastSyncAt']}');
          if (_cloudIsNewer(cloudAt, lastSync)) {
            final full = await c
                .from(_kTable)
                .select('value')
                .eq('user_id', uid)
                .eq('key', 'data');
            if ((full as List).isNotEmpty) {
              final changed = await _applyData((full.first as Map)['value']);
              meta['lastSyncAt'] = cloudAt?.toUtc().toIso8601String();
              meta['lastHash'] = '';
              await _writeMeta(meta);
              if (changed) {
                AppRestarter.restart(); // نمونه‌ی تازه، داده‌ی ادغام‌شده را می‌فرستد
                return;
              }
              data = _collectData();
              h = _fnv1a(jsonEncode(data)).toString();
            }
          }
        }

        // ۲) نسخه‌ی پشتیبانِ ابر (حداکثر هر ۶ ساعت) تا هیچ اتفاقی کل داده را نابود نکند
        await _backupCloud(c, uid, deviceId, now, meta);

        await c.from(_kTable).upsert(<String, dynamic>{
          'user_id': uid,
          'key': 'data',
          'value': data,
          'device_id': deviceId,
          'updated_at': now,
        }, onConflict: 'user_id,key');
        meta['lastHash'] = h;
        meta['lastSyncAt'] = now;
      }
      meta['userId'] = uid;
      await _writeMeta(meta);

      await _pushPacks(c, uid, deviceId, now);
    } catch (e) {
      debugPrint('CloudSync push failed: $e');
    } finally {
      _pushing = false;
    }
  }

  /// نسخه‌ی قبلیِ ردیفِ «data» را در ردیفِ «data_prev» نگه می‌دارد.
  Future<void> _backupCloud(SupabaseClient c, String uid, String deviceId,
      String now, Map<String, dynamic> meta) async {
    try {
      final last = DateTime.tryParse('${meta['lastBackupAt']}');
      if (last != null &&
          DateTime.now().toUtc().difference(last) < const Duration(hours: 6)) {
        return;
      }
      final rows = await c
          .from(_kTable)
          .select('value')
          .eq('user_id', uid)
          .eq('key', 'data');
      if ((rows as List).isEmpty) return;
      final v = (rows.first as Map)['value'];
      if (v is! Map || jsonEncode(v).length < 500) return;
      await c.from(_kTable).upsert(<String, dynamic>{
        'user_id': uid,
        'key': 'data_prev',
        'value': v,
        'device_id': deviceId,
        'updated_at': now,
      }, onConflict: 'user_id,key');
      meta['lastBackupAt'] = now;
    } catch (_) {}
  }

  Future<void> _pushPacks(
      SupabaseClient c, String uid, String deviceId, String now) async {
    if (!NativeBridge.instance.isSupported) return;
    final local = await _localPacks();
    final deleted = _readSet(_kDeleted)..removeWhere(local.contains);

    final rows = await c
        .from(_kTable)
        .select('value')
        .eq('user_id', uid)
        .eq('key', 'packs');
    var cloud = <String>{};
    if ((rows as List).isNotEmpty) {
      final v = (rows.first as Map)['value'];
      if (v is Map && v['items'] is List) {
        cloud = (v['items'] as List).map((e) => e.toString()).toSet();
      }
    }
    final next = <String>{...cloud, ...local}..removeAll(deleted);
    if (next.length == cloud.length && next.containsAll(cloud)) {
      if (deleted.isNotEmpty) await _writeSet(_kDeleted, <String>{});
      return;
    }
    final sorted = next.toList()..sort();
    await c.from(_kTable).upsert(<String, dynamic>{
      'user_id': uid,
      'key': 'packs',
      'value': <String, dynamic>{'items': sorted},
      'device_id': deviceId,
      'updated_at': now,
    }, onConflict: 'user_id,key');
    await _writeSet(_kDeleted, <String>{});
  }
}

final cloudSyncProvider = Provider<CloudSync>((ref) {
  final s = CloudSync(ref);
  ref.onDispose(s.dispose);
  return s;
});
