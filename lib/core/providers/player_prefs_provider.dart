import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/local_storage.dart';

/// مقدارهای مجازِ «پرشِ چندثانیه‌ای» (مثل SEEK_AMOUNT_STEPS در Hope).
const List<int> kSeekAmountSteps = [5, 10, 15, 20, 30, 45, 60];

const _kOpacityKey = 'phrasebook-player-opacity';
const _kSeekKey = 'phrasebook-seek-seconds';

/// شفافیتِ پلیر (۰ تا ۱۰۰) — ماندگار.
class PlayerOpacityNotifier extends StateNotifier<int> {
  final SharedPreferences _p;
  PlayerOpacityNotifier(this._p) : super(_p.getInt(_kOpacityKey) ?? 100);

  void set(int v) {
    final n = v.clamp(0, 100);
    state = n;
    _p.setInt(_kOpacityKey, n);
  }
}

final playerOpacityProvider =
    StateNotifierProvider<PlayerOpacityNotifier, int>((ref) {
  return PlayerOpacityNotifier(ref.watch(sharedPrefsProvider));
});

/// باز/بسته بودنِ ردیفِ اسلایدرِ شفافیت (پایین پلیر).
final playerOpacityPanelOpenProvider = StateProvider<bool>((ref) => false);

/// مقدارِ پرشِ لمسِ‌طولانیِ دکمه‌های قبلی/بعدی (ثانیه) — ماندگار.
class SeekAmountNotifier extends StateNotifier<int> {
  final SharedPreferences _p;
  SeekAmountNotifier(this._p) : super(_read(_p));

  static int _read(SharedPreferences p) {
    final v = p.getInt(_kSeekKey) ?? 10;
    return kSeekAmountSteps.contains(v) ? v : 10;
  }

  /// مقدارِ بعدی؛ بعد از آخرین مقدار به اولی برمی‌گردد.
  void cycle() {
    final i = kSeekAmountSteps.indexOf(state);
    state = kSeekAmountSteps[(i + 1) % kSeekAmountSteps.length];
    _p.setInt(_kSeekKey, state);
  }

  void step(int delta) {
    final i = kSeekAmountSteps.indexOf(state);
    final ni = (i + delta).clamp(0, kSeekAmountSteps.length - 1);
    state = kSeekAmountSteps[ni];
    _p.setInt(_kSeekKey, state);
  }
}

final seekAmountProvider =
    StateNotifierProvider<SeekAmountNotifier, int>((ref) {
  return SeekAmountNotifier(ref.watch(sharedPrefsProvider));
});
