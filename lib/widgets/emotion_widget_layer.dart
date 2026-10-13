import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/emotion_widget_prefs.dart';
import '../state/emotion_store.dart';
import '../state/theme_store.dart';
import 'emotion_floating_button.dart';
import 'emotion_panel.dart';

const double _edge = 4;
const double _gap = 6;
const double _dragThreshold = 3;

/// cubic-bezier(.34,1.42,.64,1) وب — با کمی overshoot
const Cubic _openCurve = Cubic(0.34, 1.42, 0.64, 1.0);

/// لایه‌ی سراسری ویجت (معادل #echw با position:fixed در وب).
/// داخل MaterialApp.builder سوار می‌شه تا روی همه‌ی صفحه‌ها بمونه.
class EmotionWidgetLayer extends StatefulWidget {
  const EmotionWidgetLayer({super.key});

  @override
  State<EmotionWidgetLayer> createState() => _EmotionWidgetLayerState();
}

class _EmotionWidgetLayerState extends State<EmotionWidgetLayer>
    with SingleTickerProviderStateMixin {
  final _prefs = EmotionWidgetPrefs();
  late final AnimationController _anim;

  bool _loaded = false;
  bool _open = false;
  bool _glass = false;
  Offset? _btnPos; // null = جای پیش‌فرض
  Offset? _panelPos; // null = کنار دکمه
  double _panelW = 250;
  bool _wasCapturing = false;

  // درگ دکمه
  Offset _btnDragStart = Offset.zero;
  Offset _lastBtn = Offset.zero;

  // درگ/پینچ پنل (همان منطق pointer وب، با آستانه‌ی ۳ پیکسل)
  final Map<int, Offset> _pointers = {};
  int? _dragPointer;
  Offset _dragStartPointer = Offset.zero;
  Offset _dragStartPanel = Offset.zero;
  bool _dragMoved = false;
  bool _gestureMoved = false;
  double _pinchStartDist = 0;
  double _pinchStartW = 250;
  Rect _lastRect = Rect.zero;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..addStatusListener((s) {
        if (s == AnimationStatus.dismissed && mounted) setState(() {});
      });

    _prefs.load().then((s) {
      if (!mounted) return;
      setState(() {
        _btnPos = (s.left >= 0 && s.top >= 0) ? Offset(s.left, s.top) : null;
        _panelPos = (s.panelLeft != null && s.panelTop != null)
            ? Offset(s.panelLeft!, s.panelTop!)
            : null;
        _panelW = s.w.clamp(kPanelWMin, kPanelWMax).toDouble();
        _open = s.open;
        _glass = s.glass;
        _loaded = true;
        if (_open) _anim.value = 1;
      });
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  // ───────── هندسه ─────────

  Offset _defaultBtn(Size screen) => Offset(
        screen.width - kEmotionBtnSize - 16,
        screen.height - kEmotionBtnSize - 100,
      );

  Offset _clampBtn(Offset p, Size screen) {
    final maxX = math.max(_edge, screen.width - kEmotionBtnSize - _edge);
    final maxY = math.max(_edge, screen.height - kEmotionBtnSize - _edge);
    return Offset(
      p.dx.clamp(_edge, maxX).toDouble(),
      p.dy.clamp(_edge, maxY).toDouble(),
    );
  }

  /// معادل applyPanelPosition وب
  Rect _panelRect(Offset btn, Size screen) {
    const half = kEmotionBtnSize / 2;
    final bcx = btn.dx + half;
    final bcy = btn.dy + half;
    final maxPW = screen.width - 2 * _edge;
    final maxPH = screen.height - 2 * _edge;
    var pw = math.min(_panelW, maxPW);
    var ph = pw * kPanelAspect;
    if (ph > maxPH) {
      ph = maxPH;
      pw = ph / kPanelAspect;
    }

    double pl, pt;
    if (_panelPos != null) {
      pl = _panelPos!.dx.clamp(_edge, screen.width - pw - _edge).toDouble();
      pt = _panelPos!.dy.clamp(_edge, screen.height - ph - _edge).toDouble();
    } else {
      if (bcx + half + _gap + pw <= screen.width - _edge) {
        pl = bcx + half + _gap;
      } else if (bcx - half - _gap - pw >= _edge) {
        pl = bcx - half - _gap - pw;
      } else {
        pl = (bcx - pw / 2).clamp(_edge, screen.width - pw - _edge).toDouble();
      }

      if (bcy + half + _gap + ph <= screen.height - _edge) {
        pt = bcy + half + _gap;
      } else if (bcy - half - _gap - ph >= _edge) {
        pt = bcy - half - _gap - ph;
      } else {
        pt = (bcy - ph / 2).clamp(_edge, screen.height - ph - _edge).toDouble();
      }
    }
    return Rect.fromLTWH(pl, pt, pw, ph);
  }

  // ───────── وضعیت ─────────

  Future<void> _persist() async {
    await _prefs.save(EmotionWidgetState(
      left: _btnPos?.dx ?? -1,
      top: _btnPos?.dy ?? -1,
      panelLeft: _panelPos?.dx,
      panelTop: _panelPos?.dy,
      w: _panelW,
      open: _open,
      glass: _glass,
    ));
  }

  void _setOpen(bool v, {bool force = false}) {
    final store = context.read<EmotionStore>();
    if (!v && store.isCapturing && !force) return; // در حالت ثبت، بسته نمی‌شه
    if (_open == v) return;
    setState(() => _open = v);
    if (v) {
      _anim.forward();
    } else {
      _anim.reverse();
    }
    _persist();
  }

  // ───────── درگ دکمه ─────────

  void _onBtnDragStart() {
    _btnDragStart = _lastBtn;
  }

  void _onBtnDrag(Offset delta) {
    final screen = MediaQuery.sizeOf(context);
    setState(() => _btnPos = _clampBtn(_btnDragStart + delta, screen));
  }

  void _onBtnDragEnd(bool moved) {
    if (moved) _persist();
  }

  void _onBtnTap() {
    final store = context.read<EmotionStore>();
    if (store.isCapturing) return; // در حالت ثبت دکمه کاری نمی‌کند
    _setOpen(!_open);
  }

  // ───────── درگ و پینچ پنل ─────────

  void _onPanelDown(PointerDownEvent e) {
    _gestureMoved = false;
    if (e.kind == PointerDeviceKind.touch) {
      _pointers[e.pointer] = e.position;
      if (_pointers.length == 2) {
        _dragPointer = null;
        _dragMoved = false;
        final pts = _pointers.values.toList();
        _pinchStartDist = (pts[0] - pts[1]).distance;
        _pinchStartW = _panelW;
        return;
      }
    }
    if (_pointers.length <= 1) {
      _dragPointer = e.pointer;
      _dragStartPointer = e.position;
      _dragStartPanel = _lastRect.topLeft;
      _dragMoved = false;
    }
  }

  void _onPanelMove(PointerMoveEvent e) {
    if (_pointers.containsKey(e.pointer)) {
      _pointers[e.pointer] = e.position;
    }
    if (_pointers.length == 2 && _pinchStartDist > 0) {
      final pts = _pointers.values.toList();
      final d = (pts[0] - pts[1]).distance;
      final nw = (_pinchStartW * (d / _pinchStartDist))
          .clamp(kPanelWMin, kPanelWMax)
          .toDouble();
      _gestureMoved = true;
      setState(() => _panelW = nw);
      return;
    }
    if (_dragPointer != e.pointer) return;
    final d = e.position - _dragStartPointer;
    if (!_dragMoved &&
        (d.dx.abs() > _dragThreshold || d.dy.abs() > _dragThreshold)) {
      _dragMoved = true;
    }
    if (!_dragMoved) return;
    _gestureMoved = true;
    setState(() => _panelPos = _dragStartPanel + d);
  }

  void _onPanelUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2 && _pinchStartDist > 0) {
      _pinchStartDist = 0;
      _persist();
    }
    if (_dragPointer == e.pointer) {
      _dragPointer = null;
      if (_dragMoved) _persist();
      _dragMoved = false;
    }
  }

  // ───────── ساخت ─────────

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final screen = MediaQuery.sizeOf(context);
    final store = context.watch<EmotionStore>();
    final isDark = context.watch<ThemeStore>().isDark;

    // ورود/خروج حالت ثبت: پنل خودکار باز و بعد از پایان بسته می‌شه (beginCapture / endCapture وب)
    if (store.isCapturing != _wasCapturing) {
      final cap = store.isCapturing;
      _wasCapturing = cap;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _setOpen(cap, force: true);
      });
    }

    final btn = _clampBtn(_btnPos ?? _defaultBtn(screen), screen);
    _lastBtn = btn;
    final rect = _panelRect(btn, screen);
    _lastRect = rect;

    final visible = _open || _anim.status != AnimationStatus.dismissed;

    // جهت باز شدن پنل نسبت به دکمه (transform-origin و slide وب)
    const half = kEmotionBtnSize / 2;
    final fromLeft = rect.center.dx > btn.dx + half;
    final fromTop = rect.center.dy > btn.dy + half;
    final align = Alignment(fromLeft ? -1.0 : 1.0, fromTop ? -1.0 : 1.0);
    final slide = Offset(fromLeft ? -22.0 : 22.0, fromTop ? -22.0 : 22.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (visible)
          Positioned(
            left: rect.left,
            top: rect.top,
            width: rect.width,
            child: IgnorePointer(
              ignoring: !_open,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onPanelDown,
                onPointerMove: _onPanelMove,
                onPointerUp: _onPanelUp,
                onPointerCancel: _onPanelUp,
                child: AnimatedBuilder(
                  animation: _anim,
                  builder: (context, _) {
                    final v = _anim.value;
                    final t = _openCurve.transform(v.clamp(0.0, 1.0));
                    final scale = 0.88 + 0.12 * t;
                    final offset = slide * (1 - t);

                    // opacity .26s (ease) از کل ۴۲۰ms
                    double op;
                    if (_anim.status == AnimationStatus.reverse) {
                      op = 1 -
                          Curves.ease
                              .transform(((1 - v) / 0.619).clamp(0.0, 1.0));
                    } else {
                      op = Curves.ease.transform((v / 0.619).clamp(0.0, 1.0));
                    }

                    return Transform.translate(
                      offset: offset,
                      child: Transform.scale(
                        scale: scale,
                        alignment: align,
                        child: EmotionPanel(
                          width: rect.width,
                          glass: _glass,
                          isDark: isDark,
                          opacity: op,
                          chartVisible: _open,
                          onToggleGlass: () {
                            setState(() => _glass = !_glass);
                            _persist();
                          },
                          tapSuppressed: () => _gestureMoved,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        Positioned(
          left: btn.dx,
          top: btn.dy,
          child: EmotionFloatingButton(
            open: _open,
            onDragStart: _onBtnDragStart,
            onDrag: _onBtnDrag,
            onDragEnd: _onBtnDragEnd,
            onTap: _onBtnTap,
          ),
        ),
      ],
    );
  }
}
