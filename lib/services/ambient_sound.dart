import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/gestures.dart';

import 'app_prefs.dart';

/// صدای زنده‌ی طبیعت برای نقشه‌ی هدف‌گذاری 🌾🌲
///
///  • نسیمِ ملایمِ همیشگی (بلندی‌اش آهسته بالا و پایین می‌رود)
///  • گاهی وزشِ تندترِ باد، در زمان‌های تصادفی و با سه صدای مختلف
///  • شب‌ها جیرجیرک (با ساعتِ گوشی؛ نرم وارد و خارج می‌شود)
///  • هرچه دنیای نقشه سبزتر شود، گاهی صدای پرنده (فقط روز)
///
/// همه‌ی صداها کم‌صدا هستند و از فایل‌های داخل برنامه (assets/ambient/) پخش می‌شوند؛
/// پس نیازی به اینترنت/VPN ندارد. قطع/وصل‌شدن در حافظه‌ی برنامه ذخیره می‌شود.
class AmbientSound {
  AmbientSound._();
  static final AmbientSound instance = AmbientSound._();

  static const String _prefKey = 'ambientMuted';

  // بلندیِ پایه‌ی هر صدا (۰..۱)؛ برای کم/زیاد کردن فقط همین‌ها را عوض کن
  static const double _kWind = 0.20;
  static const double _kCricket = 0.24;
  static const double _kGust = 0.30;
  static const double _kBird = 0.26;
  static const double _kCrow = 0.22;

  /// true = کاربر صدا را قطع کرده
  final ValueNotifier<bool> muted = ValueNotifier<bool>(false);

  final _Loop _wind = _Loop('ambient/wind.wav');
  final _Loop _cricket = _Loop('ambient/crickets.wav');
  AudioPlayer? _fx;
  AudioPlayer? _bird;
  AudioPlayer? _crow;

  final math.Random _rng = math.Random();
  Timer? _timer;
  bool _inited = false;
  bool _running = false;
  bool _active = false;
  bool _ducked = false;
  bool _night = false;
  double _green = 0;
  bool _dawn = false;
  bool _crowMorning = false;
  double _windCur = 0;
  double _windTarget = 0;
  DateTime _windSegEnd = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _crowAt;
  bool _gestureArmed = false;
  DateTime _t0 = DateTime.now();
  DateTime? _gustAt;
  DateTime? _birdAt;

  bool get _wantRun => _active && !_ducked && !muted.value;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      final p = await AppPrefs.getInstance();
      muted.value = p.getBool(_prefKey) ?? false;
    } catch (_) {}
    _reconcile();
  }

  /// [night]: آسمان شب است؟  [green]: سبزیِ دنیا از ۰ (بیابان) تا ۱ (جنگل)
  void update({required bool night, required double green, bool dawn = false}) {
    _night = night;
    _green = green;
    if (dawn && !_dawn) {
      // شروعِ دم‌دمِ صبح: بعضی صبح‌ها کلاغ هست و بعضی صبح‌ها نیست (حدود نیمی از صبح‌ها)
      _crowMorning = _rng.nextDouble() < 0.5;
      _crowAt = DateTime.now().add(Duration(seconds: 25 + _rng.nextInt(120)));
    } else if (!dawn) {
      _crowMorning = false;
    }
    _dawn = dawn;
  }

  /// تب نقشه دیده می‌شود و برنامه جلوی صفحه است؟
  void setActive(bool v) {
    if (_active == v) return;
    _active = v;
    _reconcile();
  }

  /// وقتی صدای ضبط‌شده‌ی یک گره پخش می‌شود، صدای طبیعت موقتاً قطع می‌شود
  void setDucked(bool v) {
    if (_ducked == v) return;
    _ducked = v;
    _reconcile();
  }

  Future<void> toggleMute() async {
    muted.value = !muted.value;
    _reconcile();
    try {
      final p = await AppPrefs.getInstance();
      await p.setBool(_prefKey, muted.value);
    } catch (_) {}
  }

  // ───────────────────────── کنترل ─────────────────────────

  void _reconcile() {
    if (_wantRun) {
      _start();
    } else {
      _halt();
    }
  }

  void _start() {
    if (_running) return;
    _running = true;
    _t0 = DateTime.now();
    _cricket.vol = 0;
    _windCur = 0;
    final now = DateTime.now();
    _pickWindSeg(now);
    _gustAt = now.add(Duration(seconds: 14 + _rng.nextInt(22)));
    _birdAt = now.add(Duration(seconds: 6 + _rng.nextInt(10)));
    _armGesture();
    _kick(force: true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  void _halt() {
    if (!_running) return;
    _running = false;
    _timer?.cancel();
    _timer = null;
    _disarmGesture();
    _wind.pause();
    _cricket.pause();
    _cricket.vol = 0;
    try {
      _fx?.stop();
    } catch (_) {}
    try {
      _bird?.stop();
    } catch (_) {}
    try {
      _crow?.stop();
    } catch (_) {}
  }

  // نسیم گاهی هست و گاهی نیست: بین «آرام» و «وزش» با مدت و شدتِ تصادفی
  void _pickWindSeg(DateTime now) {
    if (_rng.nextDouble() < 0.45) {
      _windTarget = _kWind * 0.03 * _rng.nextDouble();
      _windSegEnd = now.add(Duration(seconds: 15 + _rng.nextInt(50)));
    } else {
      _windTarget = _kWind * (0.35 + 0.65 * _rng.nextDouble());
      _windSegEnd = now.add(Duration(seconds: 12 + _rng.nextInt(45)));
    }
  }

  // مرورگرها قبل از اولین لمسِ کاربر اجازه‌ی پخش نمی‌دهند؛ با اولین لمس دوباره تلاش می‌کنیم
  void _armGesture() {
    if (_gestureArmed) return;
    _gestureArmed = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  void _disarmGesture() {
    if (!_gestureArmed) return;
    _gestureArmed = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
  }

  void _onPointer(PointerEvent e) {
    if (e is! PointerDownEvent && e is! PointerUpEvent) return;
    if (!_wantRun) return;
    if (_wind.playing) {
      _disarmGesture();
      return;
    }
    _kick(force: true);
  }

  void _kick({bool force = false}) {
    _wind.tryPlay(force: force);
    if (_cricket.vol > 0.004) _cricket.tryPlay(force: force);
  }

  // ───────────────────────── تیک (هر ۲۵۰ میلی‌ثانیه) ─────────────────────────

  void _tick() {
    if (!_wantRun) {
      _halt();
      return;
    }
    final now = DateTime.now();
    final t = now.difference(_t0).inMilliseconds / 1000.0;
    const tau = 2 * math.pi;
    final fade = math.min(1.0, t / 4.0);

    // نسیم: بلندی با سه موجِ کند (۱۳، ۲۹ و ۴۷ ثانیه) آرام بالا و پایین می‌رود
    final w = (0.5 +
            0.25 * math.sin(t * tau / 13) +
            0.15 * math.sin(t * tau / 29 + 1.3) +
            0.10 * math.sin(t * tau / 47 + 2.1))
        .clamp(0.0, 1.0)
        .toDouble();
    if (now.isAfter(_windSegEnd)) _pickWindSeg(now);
    _windCur += (_windTarget - _windCur) * 0.04;
    final windV = _windCur * (0.55 + 0.45 * w) * fade;
    _wind.tryPlay();
    _wind.setVol(windV);

    // جیرجیرک: شب نرم وارد می‌شود، روز نرم خارج
    final cTarget =
        _night ? _kCricket * (0.88 + 0.12 * math.sin(t * tau / 9)) : 0.0;
    _cricket.vol += (cTarget - _cricket.vol) * 0.035;
    if (_cricket.vol > 0.004) {
      _cricket.tryPlay();
      _cricket.setVol(_cricket.vol);
    } else if (cTarget == 0.0 && _cricket.playing) {
      _cricket.vol = 0;
      _cricket.pause();
    }

    // وزشِ باد و پرنده فقط وقتی پخش اصلی واقعاً کار می‌کند
    if (!_wind.playing) return;

    final g = _gustAt;
    if (g != null && now.isAfter(g)) {
      _playGust();
      final again = _rng.nextDouble() < 0.15;
      _gustAt = now.add(again
          ? Duration(seconds: 6 + _rng.nextInt(5))
          : Duration(seconds: 35 + _rng.nextInt(80)));
    }

    // کلاغ: فقط دم‌دمای صبح، کم و تصادفی (گاهی یکی جوابش را می‌دهد)
    final c = _crowAt;
    if (c != null && now.isAfter(c)) {
      if (_dawn && _crowMorning) {
        _playCrow();
        // کم: بینِ دو بار ۴ تا ۱۲ دقیقه؛ گاهی هم کلاغِ دیگری جوابش را می‌دهد
        _crowAt = now.add(_rng.nextDouble() < 0.2
            ? Duration(seconds: 3 + _rng.nextInt(4))
            : Duration(seconds: 240 + _rng.nextInt(480)));
      } else {
        _crowAt = now.add(const Duration(seconds: 60));
      }
    }

    final b = _birdAt;
    if (b != null && now.isAfter(b)) {
      final ok = !_night && _green >= 0.04 && _cricket.vol < 0.03;
      if (ok) {
        _playBird();
        // گاهی پرنده‌ی دیگری جوابش را می‌دهد
        if (_rng.nextDouble() < 0.25) {
          _birdAt = now.add(Duration(seconds: 2 + _rng.nextInt(3)));
          return;
        }
        // هرچه سبزتر، پرنده‌ها بیشترند (ولی همیشه «گاهی»)
        final base = 75.0 - 47.0 * _green.clamp(0.0, 1.0);
        final sec = base * (0.6 + 0.8 * _rng.nextDouble());
        _birdAt = now.add(Duration(milliseconds: (sec * 1000).round()));
      } else {
        _birdAt = now.add(Duration(seconds: 20 + _rng.nextInt(20)));
      }
    }
  }

  Future<AudioPlayer> _mk() async {
    final p = AudioPlayer();
    try {
      await p.setAudioContext(
          AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
              .build());
    } catch (_) {}
    return p;
  }

  Future<void> _playGust() async {
    try {
      final p = _fx ??= await _mk();
      final i = 1 + _rng.nextInt(3);
      final v = _kGust * (0.55 + 0.45 * _rng.nextDouble());
      await p.play(AssetSource('ambient/gust$i.wav'), volume: v);
    } catch (_) {}
  }

  Future<void> _playCrow() async {
    try {
      final p = _crow ??= await _mk();
      final i = 1 + _rng.nextInt(3);
      final v = _kCrow * (0.6 + 0.4 * _rng.nextDouble());
      await p.play(AssetSource('ambient/crow$i.wav'), volume: v);
    } catch (_) {}
  }

  Future<void> _playBird() async {
    try {
      final p = _bird ??= await _mk();
      final i = 1 + _rng.nextInt(5);
      final v = _kBird * (0.55 + 0.45 * _rng.nextDouble());
      await p.play(AssetSource('ambient/bird$i.wav'), volume: v);
    } catch (_) {}
  }
}

/// یک صدای حلقه‌ایِ پیوسته (باد / جیرجیرک)
class _Loop {
  _Loop(this.asset);
  final String asset;

  AudioPlayer? _p;
  StreamSubscription<PlayerState>? _sub;
  double vol = 0;
  bool playing = false;
  bool _busy = false;
  bool _ready = false;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  double _sent = -1;

  Future<void> _ensure() async {
    if (_ready) return;
    final p = _p ??= AudioPlayer();
    try {
      await p.setAudioContext(
          AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
              .build());
    } catch (_) {}
    await p.setReleaseMode(ReleaseMode.loop);
    await p.setVolume(0);
    await p.setSource(AssetSource(asset));
    _sub ??= p.onPlayerStateChanged.listen((s) {
      if (s != PlayerState.playing) playing = false;
    });
    _ready = true;
    _sent = 0;
  }

  /// اگر پخش نمی‌شود، (حداکثر هر ۱٫۵ ثانیه) دوباره تلاش می‌کند
  void tryPlay({bool force = false}) {
    if (playing || _busy) return;
    final now = DateTime.now();
    if (!force && now.difference(_last).inMilliseconds < 1500) return;
    _last = now;
    _play();
  }

  Future<void> _play() async {
    _busy = true;
    try {
      await _ensure();
      await _p!.resume();
      playing = true;
    } catch (_) {
      playing = false;
    } finally {
      _busy = false;
    }
  }

  Future<void> setVol(double v) async {
    final x = v.clamp(0.0, 1.0).toDouble();
    if ((x - _sent).abs() < 0.004) return;
    _sent = x;
    try {
      await _p?.setVolume(x);
    } catch (_) {}
  }

  Future<void> pause() async {
    playing = false;
    try {
      await _p?.pause();
    } catch (_) {}
  }
}
