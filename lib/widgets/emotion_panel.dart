import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../models/emotion.dart';
import '../state/emotion_store.dart';
import 'emotion_body_painter.dart';
import 'emotion_list.dart';

const double kPanelWMin = 170;
const double kPanelWMax = 460;

class EmotionPanel extends StatefulWidget {
  final bool glass;
  final VoidCallback onToggleGlass;
  final void Function(Offset delta) onDrag;
  final void Function() onDragStart;
  final void Function() onDragEnd;
  final void Function(double newW) onResize;
  final double panelW;

  const EmotionPanel({
    super.key,
    required this.glass,
    required this.onToggleGlass,
    required this.onDrag,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onResize,
    required this.panelW,
  });

  @override
  State<EmotionPanel> createState() => _EmotionPanelState();
}

class _EmotionPanelState extends State<EmotionPanel>
    with TickerProviderStateMixin {
  late final AnimationController _aura;
  late final AnimationController _wave;
  late final AnimationController _heart;

  Offset _dragStart = Offset.zero;
  double _pinchStartW = 0;
  double _pinchStartScale = 1.0;
  int _lastPointers = 0;

  @override
  void initState() {
    super.initState();
    _aura = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _wave = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat();
    _heart = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _aura.dispose();
    _wave.dispose();
    _heart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<EmotionStore>();
    final selected = store.selectedIds;
    final emotions = selected
        .map(emotionById)
        .whereType<Emotion>()
        .toList();

    final dominant = dominantEmotion(selected);
    final colors = emotions.map((e) => hexToColor(e.color)).toList();
    final freqs = emotions.map((e) => e.freq).toList();

    final hasSel = emotions.isNotEmpty;
    final auraColors = hasSel
        ? colors
        : <Color>[const Color(0xFF5A6178)];
    final strongHeart = hasSel;

    // ── فرم پنل ──
    final container = Container(
      decoration: widget.glass
          ? BoxDecoration(
              color: const Color(0xFFFFFFFF).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 36,
                  offset: Offset(0, 12),
                ),
              ],
            )
          : null,
      padding: widget.glass
          ? const EdgeInsets.fromLTRB(12, 16, 12, 10)
          : EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 260 / 400,
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 260,
                height: 400,
                child: _chart(
                  selected,
                  dominant,
                  auraColors,
                  colors,
                  freqs,
                  strongHeart,
                  hasSel,
                ),
              ),
            ),
          ),
          if (store.isCapturing) _captureBar(store),
        ],
      ),
    );

    // ── پوشش شیشه‌ای ──
    final content = widget.glass
        ? ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: container,
            ),
          )
        : container;

    // ── toggle شیشه + پنل ──
    return GestureDetector(
      onScaleStart: (d) {
        if (d.pointerCount >= 2) {
          _pinchStartW = widget.panelW;
          _pinchStartScale = d.scale;
        } else {
          _dragStart = d.focalPoint;
          widget.onDragStart();
        }
        _lastPointers = d.pointerCount;
      },
      onScaleUpdate: (d) {
        if (d.pointerCount != _lastPointers) {
          if (d.pointerCount >= 2) {
            _pinchStartW = widget.panelW;
            _pinchStartScale = d.scale;
          } else {
            _dragStart = d.focalPoint;
            widget.onDragStart();
          }
          _lastPointers = d.pointerCount;
        }
        if (d.pointerCount >= 2) {
          final factor = _pinchStartScale == 0 ? 1.0 : d.scale / _pinchStartScale;
          final w = (_pinchStartW * factor).clamp(kPanelWMin, kPanelWMax);
          widget.onResize(w);
        } else {
          widget.onDrag(d.focalPoint - _dragStart);
        }
      },
      onScaleEnd: (_) {
        _lastPointers = 0;
        widget.onDragEnd();
      },
      child: Stack(
        children: [
          content,
          Positioned(
            left: 6, top: 6,
            child: _GlassToggle(
              active: widget.glass,
              onTap: widget.onToggleGlass,
            ),
          ),
        ],
      ),
    );
  }

  // ── chart ──
  Widget _chart(
    List<String> selectedIds,
    Emotion? dominant,
    List<Color> auraColors,
    List<Color> colors,
    List<int> freqs,
    bool strongHeart,
    bool hasSel,
  ) {
    final heartColors = hasSel
        ? colors.take(5).toList()
        : <Color>[const Color(0xFF5A6178)];

    return Stack(
      children: [
        // ۱) لیست
        Positioned(
          left: 6, top: 6,
          width: 100,
          child: EmotionList(
            selectedIds: selectedIds.toSet(),
            onToggle: (id) => context.read<EmotionStore>().toggle(id),
          ),
        ),

        // ۲) هاله
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _aura,
            builder: (_, __) => CustomPaint(
              painter: AuraPainter(
                colors: auraColors,
                pulse: hasSel ? _aura.value : 0,
              ),
            ),
          ),
        ),

        // ۳) امواج
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _wave,
            builder: (_, __) => CustomPaint(
              painter: WavesPainter(
                colors: colors,
                freqs: freqs,
                phase: _wave.value,
              ),
            ),
          ),
        ),

        // ۴) قلب (پشت بدن)
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _heart,
            builder: (_, __) => CustomPaint(
              painter: HeartPainter(pulse: _heart.value),
            ),
          ),
        ),

        // ۵) تصویر بدن
        Positioned(
          left: 115, top: 125, width: 140, height: 140,
          child: SvgPicture.asset(
            'assets/body.svg',
            fit: BoxFit.contain,
          ),
        ),

        // ۶) هاله‌ی قلب (بالای بدن)
        if (hasSel)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _heart,
              builder: (_, __) => CustomPaint(
                painter: HeartEnergyPainter(
                  colors: heartColors,
                  pulse: _heart.value,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── نوار capture ──
  Widget _captureBar(EmotionStore store) {
    final isBefore = store.capturePhase == 'before';
    final label = store.captureLabel ?? '';
    final cnt = store.selectedIds.length;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x2E2BBFAB), Color(0x1F5EC8F0)],
        ),
        border: Border.all(color: const Color(0x8C2BBFAB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${isBefore ? "💗 قبل از تمرین" : "✨ بعد از تمرین"} — $label',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F5B53),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            cnt > 0
                ? '$cnt احساس انتخاب شد — دکمه‌ی ثبت را بزن'
                : 'از لیست کنار آدمک، یک یا چند احساس انتخاب کن',
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF0F5B53),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F5B53),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  onPressed: () => context.read<EmotionStore>().saveCapture(),
                  child: const Text('✓ ثبت',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F5B53),
                    side: const BorderSide(color: Color(0x402BBFAB)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  onPressed: () => context.read<EmotionStore>().cancelCapture(),
                  child: const Text('انصراف', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlassToggle extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _GlassToggle({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? const Color(0xC7141622)
              : Colors.white.withValues(alpha: 0.65),
          border: Border.all(
            color: active
                ? Colors.white.withValues(alpha: 0.28)
                : Colors.black.withValues(alpha: 0.12),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          active ? Icons.image : Icons.image_outlined,
          size: 14,
          color: active ? const Color(0xFFEEF1FB) : const Color(0xFF20232B),
        ),
      ),
    );
  }
}
