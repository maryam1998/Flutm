import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/emotion_widget_prefs.dart';
import '../state/emotion_store.dart';
import '../state/map_store.dart';
import 'emotion_floating_button.dart';
import 'emotion_panel.dart';

const double _edge = 4;
const double _gap = 6;

class EmotionWidgetLayer extends StatefulWidget {
  const EmotionWidgetLayer({super.key});

  @override
  State<EmotionWidgetLayer> createState() => _EmotionWidgetLayerState();
}

class _EmotionWidgetLayerState extends State<EmotionWidgetLayer>
    with SingleTickerProviderStateMixin {
  final _prefs = EmotionWidgetPrefs();

  bool _loaded = false;
  bool _open = false;
  bool _glass = false;
  Offset _btnPos = Offset.zero;
  Offset? _panelPos;
  double _panelW = 250;

  Offset _btnDragStart = Offset.zero;
  Offset? _panelDragStart;
  Offset? _panelDragAnchor;
  double _panelDragStartW = 250;

  late final AnimationController _openCtrl;

  @override
  void initState() {
    super.initState();
    _openCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: 0,
    );
    _prefs.load().then((s) {
      if (!mounted) return;
      setState(() {
        _btnPos = Offset(s.left, s.top);
        _panelPos = (s.panelLeft != null && s.panelTop != null)
            ? Offset(s.panelLeft!, s.panelTop!)
            : null;
        _panelW = s.w;
        _open = s.open;
        _glass = s.glass;
        _loaded = true;
        if (_open) _openCtrl.value = 1;
      });
    });
  }

  @override
  void dispose() {
    _openCtrl.dispose();
    super.dispose();
  }

  Offset _clampBtn(Offset p, Size screen) {
    final maxX = screen.width - kEmotionBtnSize - _edge;
    final maxY = screen.height - kEmotionBtnSize - _edge;
    return Offset(
      p.dx.clamp(_edge, maxX),
      p.dy.clamp(_edge, maxY),
    );
  }

  Offset _defaultBtnPos(Size screen) => Offset(
        screen.width - kEmotionBtnSize - 16,
        screen.height - kEmotionBtnSize - 100,
      );

  Rect _computePanelRect(Offset btn, Size screen) {
    final maxPW = screen.width - 2 * _edge;
    final pw = _panelW.clamp(kPanelWMin, maxPW);
    final ph = pw * (400 / 260);

    double pl, pt;
    if (_panelPos != null) {
      pl = _panelPos!.dx.clamp(_edge, screen.width - pw - _edge);
      pt = _panelPos!.dy.clamp(_edge, screen.height - ph - _edge);
    } else {
      final bcx = btn.dx + kEmotionBtnSize / 2;
      final bcy = btn.dy + kEmotionBtnSize / 2;

      if (bcx + kEmotionBtnSize / 2 + _gap + pw <= screen.width - _edge) {
        pl = bcx + kEmotionBtnSize / 2 + _gap;
      } else if (bcx - kEmotionBtnSize / 2 - _gap - pw >= _edge) {
        pl = bcx - kEmotionBtnSize / 2 - _gap - pw;
      } else {
        pl = (bcx - pw / 2).clamp(_edge, screen.width - pw - _edge);
      }

      if (bcy + kEmotionBtnSize / 2 + _gap + ph <= screen.height - _edge) {
        pt = bcy + kEmotionBtnSize / 2 + _gap;
      } else if (bcy - kEmotionBtnSize / 2 - _gap - ph >= _edge) {
        pt = bcy - kEmotionBtnSize / 2 - _gap - ph;
      } else {
        pt = (bcy - ph / 2).clamp(_edge, screen.height - ph - _edge);
      }
    }
    return Rect.fromLTWH(pl, pt, pw, ph);
  }

  Future<void> _persist() async {
    await _prefs.save(EmotionWidgetState(
      left: _btnPos.dx,
      top: _btnPos.dy,
      panelLeft: _panelPos?.dx,
      panelTop: _panelPos?.dy,
      w: _panelW,
      open: _open,
      glass: _glass,
    ));
  }

  void _setOpen(bool v) {
    setState(() => _open = v);
    if (v) {
      _openCtrl.forward();
    } else {
      _openCtrl.reverse();
    }
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    // مخفی‌کردن کل ویجت اگر کاربر در تنظیمات خاموش کرده باشد
    final showWidget = context.watch<MapStore>().state.showEmotionWidget;
    if (!showWidget) return const SizedBox.shrink();

    final screen = MediaQuery.of(context).size;
    final store = context.watch<EmotionStore>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveOpen = _open || store.isCapturing;
    if (store.isCapturing && _openCtrl.value < 1) {
      _openCtrl.value = 1;
    }

    final btn = _btnPos == Offset.zero
        ? _defaultBtnPos(screen)
        : _clampBtn(_btnPos, screen);

    final rect = _computePanelRect(btn, screen);

    return AnimatedBuilder(
      animation: _openCtrl,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_openCtrl.value);

        final originSide = _panelOriginSide(rect, btn);
        final dx = originSide.dx * (1 - t) * 22;
        final dy = originSide.dy * (1 - t) * 22;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (effectiveOpen && t > 0.01)
              Positioned(
                left: rect.left + dx,
                top: rect.top + dy,
                width: rect.width,
                child: Transform.scale(
                  scale: 0.88 + 0.12 * t,
                  alignment: _originAlignment(originSide),
                  child: GestureDetector(
                    behavior: HitTestBehavior.deferToChild,
                    onScaleStart: (d) {
                      _panelDragStart =
                          _panelPos ?? Offset(rect.left, rect.top);
                      _panelDragAnchor = d.focalPoint;
                      if (d.pointerCount >= 2) {
                        _panelDragStartW = rect.width;
                      }
                    },
                    onScaleUpdate: (d) {
                      if (d.pointerCount >= 2) {
                        final w = (_panelDragStartW * d.scale)
                            .clamp(kPanelWMin, kPanelWMax);
                        setState(() => _panelW = w);
                        return;
                      }
                      if (_panelDragAnchor == null) return;
                      final delta = d.focalPoint - _panelDragAnchor!;
                      setState(() {
                        _panelPos = _panelDragStart! + delta;
                      });
                    },
                    onScaleEnd: (_) {
                      _panelDragStart = null;
                      _panelDragAnchor = null;
                      _persist();
                    },
                    child: EmotionPanel(
                      width: rect.width,
                      glass: _glass,
                      isDark: isDark,
                      opacity: t,
                      chartVisible: t > 0.05,
                      onToggleGlass: () {
                        setState(() => _glass = !_glass);
                        _persist();
                      },
                      tapSuppressed: () => _panelDragAnchor != null,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: btn.dx,
              top: btn.dy,
              child: EmotionFloatingButton(
                open: _open,
                onDragStart: () {
                  _btnDragStart = btn;
                },
                onDrag: (delta) {
                  setState(() => _btnPos = _btnDragStart + delta);
                },
                onDragEnd: () {
                  setState(() => _btnPos = _clampBtn(_btnPos, screen));
                  _persist();
                },
                onTap: () {
                  if (store.isCapturing) return;
                  if (_open) {
                    store.fireCommitClose();
                  }
                  _setOpen(!_open);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Alignment _originAlignment(Offset dir) {
    return Alignment(-dir.dx, -dir.dy);
  }

  Offset _panelOriginSide(Rect rect, Offset btn) {
    final bc = btn + const Offset(kEmotionBtnSize / 2, kEmotionBtnSize / 2);
    final pc = Offset(rect.left + rect.width / 2, rect.top + rect.height / 2);
    return Offset(
      pc.dx > bc.dx ? -1 : 1,
      pc.dy > bc.dy ? -1 : 1,
    );
  }
}
