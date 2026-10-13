import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/emotion_widget_prefs.dart';
import '../state/emotion_store.dart';
import 'emotion_floating_button.dart';
import 'emotion_panel.dart';

const double _edge = 4;
const double _gap = 6;

class EmotionWidgetLayer extends StatefulWidget {
  const EmotionWidgetLayer({super.key});

  @override
  State<EmotionWidgetLayer> createState() => _EmotionWidgetLayerState();
}

class _EmotionWidgetLayerState extends State<EmotionWidgetLayer> {
  final _prefs = EmotionWidgetPrefs();

  bool _loaded = false;
  bool _open = false;
  bool _glass = false;
  Offset _btnPos = Offset.zero;
  Offset? _panelPos;
  double _panelW = 250;

  Offset _btnDragStartPos = Offset.zero;
  Offset? _panelDragStartPos;

  @override
  void initState() {
    super.initState();
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
      });
    });
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

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final screen = MediaQuery.of(context).size;
    final store = context.watch<EmotionStore>();
    final effectiveOpen = _open || store.isCapturing;

    final btn = _btnPos == Offset.zero
        ? _defaultBtnPos(screen)
        : _clampBtn(_btnPos, screen);

    final rect = _computePanelRect(btn, screen);

    return Stack(
      // اجازه می‌دهد ویجت روی هر چیزی که زیرش است شناور باشد
      clipBehavior: Clip.none,
      children: [
        // ── پنل (زیر دکمه) ──
        if (effectiveOpen)
          Positioned(
            left: rect.left,
            top: rect.top,
            width: rect.width,
            child: EmotionPanel(
              key: const ValueKey('emotion-panel'),
              glass: _glass,
              panelW: rect.width,
              onToggleGlass: () {
                setState(() => _glass = !_glass);
                _persist();
              },
              onDragStart: () {
                _panelDragStartPos = _panelPos ?? Offset(rect.left, rect.top);
                setState(() => _panelPos = _panelDragStartPos);
              },
              onDrag: (delta) {
                if (_panelDragStartPos == null) return;
                setState(() {
                  _panelPos = _panelDragStartPos! + delta;
                });
              },
              onDragEnd: () {
                _panelDragStartPos = null;
                _persist();
              },
              onResize: (w) {
                setState(() => _panelW = w);
              },
            ),
          ),

        // ── دکمه‌ی شناور — همیشه آخرین فرزند، همیشه روی همه چیز ──
        Positioned(
          left: btn.dx,
          top: btn.dy,
          child: EmotionFloatingButton(
            open: _open,
            onDragStart: () {
              _btnDragStartPos = btn;
            },
            onDrag: (delta) {
              setState(() {
                _btnPos = _btnDragStartPos + delta;
              });
            },
            onDragEnd: () {
              final clamped = _clampBtn(_btnPos, screen);
              setState(() => _btnPos = clamped);
              _persist();
            },
            onTap: () {
              // در حالت capture/ویرایش، دکمه کاری نمی‌کند
              if (store.isCapturing) return;

              // اگر پنل باز است و انتخاب داریم، بستن پنل = ثبت خودکار
              if (_open) {
                store.fireCommitClose();
              }

              setState(() => _open = !_open);
              _persist();
            },
          ),
        ),
      ],
    );
  }
}
