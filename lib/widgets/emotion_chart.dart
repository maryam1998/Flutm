import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/emotion.dart';
import 'emotion_body_painter.dart';
import 'emotion_list.dart';

/// بومِ ۲۶۰×۴۰۰ ویجت (همان viewBox وب):
/// لیست احساسات + هاله + موج EEG + قلب تپنده + تصویر body.svg + درخشش قلب.
/// این ویجت باید داخل FittedBox قرار بگیره تا به اندازه‌ی پنل scale بشه.
class EmotionChart extends StatefulWidget {
  const EmotionChart({
    super.key,
    required this.selectedIds,
    required this.isDark,
    required this.onToggle,
    required this.tapSuppressed,
    this.figureOffset = Offset.zero,
    this.onFigureChange,
    this.onFigureDragStart,
    this.onFigureDragEnd,
  });

  final Set<String> selectedIds;
  final bool isDark;
  final void Function(String id) onToggle;

  /// وقتی پنل همین الان درگ شده، تپ روی ردیف‌ها نادیده گرفته می‌شه (مثل suppressClickUntil وب)
  final bool Function() tapSuppressed;

  /// جابه‌جایی آدمک (بدن + قلب + هاله + موج) به واحد بوم؛ با کشیدنِ خودِ آدمک عوض می‌شود
  final Offset figureOffset;
  final ValueChanged<Offset>? onFigureChange;
  final VoidCallback? onFigureDragStart;
  final VoidCallback? onFigureDragEnd;

  @override
  State<EmotionChart> createState() => _EmotionChartState();
}

class _EmotionChartState extends State<EmotionChart>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier<double>(0);

  // ── کشیدنِ آدمک ──
  static const double _figHalfW = 48, _figHalfH = 86;
  int? _figPointer;
  Offset _figLast = Offset.zero;
  Offset _figCur = Offset.zero;
  double _figScale = 1;
  bool _figMoved = false;
  int _figLastTapMs = 0;

  Offset _clampFig(Offset o) => Offset(
        o.dx.clamp(-(kBodyCX - _figHalfW), kChartW - (kBodyCX + _figHalfW)),
        o.dy.clamp(-(kBodyCY - _figHalfH), kChartH - (kBodyCY + _figHalfH)),
      );

  double _chartScale() {
    final ro = context.findRenderObject();
    if (ro is RenderBox && ro.attached) {
      final s = ro.getTransformTo(null).getMaxScaleOnAxis();
      if (s > 0.01) return s;
    }
    return 1;
  }

  void _figDown(PointerDownEvent e) {
    if (_figPointer != null) return;
    _figPointer = e.pointer;
    _figLast = e.position;
    _figCur = widget.figureOffset;
    _figScale = _chartScale();
    _figMoved = false;
    widget.onFigureDragStart?.call();
  }

  void _figMove(PointerMoveEvent e) {
    if (e.pointer != _figPointer) return;
    final raw = e.position - _figLast;
    if (!_figMoved && raw.distance < 2) return;
    _figMoved = true;
    _figLast = e.position;
    _figCur = _clampFig(_figCur + raw / _figScale);
    widget.onFigureChange?.call(_figCur);
  }

  void _figUp(PointerEvent e, {bool cancelled = false}) {
    if (e.pointer != _figPointer) return;
    _figPointer = null;
    // دوبار تپ پشت‌سرهم (بدون کشیدن) = برگرداندن آدمک به جای اول
    if (!cancelled && !_figMoved) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _figLastTapMs < 350) {
        _figLastTapMs = 0;
        widget.onFigureChange?.call(Offset.zero);
      } else {
        _figLastTapMs = now;
      }
    }
    widget.onFigureDragEnd?.call();
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      // ~۳۰ فریم در ثانیه برای موج/هاله/قلب (نصفِ بارِ رسم؛ فرقی دیده نمی‌شود)
      final t = elapsed.inMicroseconds / 1000000.0;
      if (t - _time.value < 0.028) return;
      _time.value = t;
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final sel =
        kEmotions.where((e) => widget.selectedIds.contains(e.id)).toList();
    final hasSel = sel.isNotEmpty;
    final selColors = sel.map((e) => hexToColor(e.color)).toList();
    final selFreqs = sel.map((e) => e.freq).toList();

    final neutralAura =
        isDark ? const Color(0xFF5A6178) : const Color(0xFFAAB0C4);
    final neutralWave =
        isDark ? const Color(0xFF7D84A0) : const Color(0xFF9FA5BA);

    final auraColors =
        hasSel ? selColors.take(5).toList() : <Color>[neutralAura];

    return SizedBox(
      width: kChartW,
      height: kChartH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // لیست (فقط با تغییر انتخاب/تم دوباره کشیده می‌شه)
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: EmotionListPainter(
                  selected: widget.selectedIds,
                  isDark: isDark,
                ),
              ),
            ),
          ),

          // لایه‌ی متحرک: هاله، موج، قلب، بدن، درخشش قلب (همه در یک لایه تا blend درست کار کنه)
          // کل این لایه با figureOffset جابه‌جا می‌شود (آدمک همراه قلبش)
          Positioned.fill(
            child: Transform.translate(
              offset: widget.figureOffset,
              child: RepaintBoundary(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: AuraPainter(
                        time: _time,
                        colors: auraColors,
                        hasSelection: hasSel,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: WavesPainter(
                        time: _time,
                        colors: selColors,
                        freqs: selFreqs,
                        hasSelection: hasSel,
                        neutral: neutralWave,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: HeartPainter(time: _time, hasSelection: hasSel),
                    ),
                  ),
                  Positioned(
                    left: kBodyCX - 70,
                    top: kBodyCY - 70,
                    width: 140,
                    height: 140,
                    child: SvgPicture.asset(
                      'assets/body.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                  if (hasSel)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: HeartEnergyPainter(
                          time: _time,
                          colors: selColors,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ),
          ),

          // سطح لمس ردیف‌ها
          for (var i = 0; i < kEmotions.length; i++)
            Positioned(
              left: 8,
              top: 6 + emotionRowY(i) - kListRowH / 2,
              width: 94,
              height: kListRowH,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (widget.tapSuppressed()) return;
                  widget.onToggle(kEmotions[i].id);
                },
              ),
            ),

          // سطح گرفتن و کشیدنِ آدمک (روی همه‌ی لایه‌ها، همراه جابه‌جایی)
          Positioned(
            left: kBodyCX - _figHalfW + widget.figureOffset.dx,
            top: kBodyCY - _figHalfH + widget.figureOffset.dy,
            width: _figHalfW * 2,
            height: _figHalfH * 2,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _figDown,
              onPointerMove: _figMove,
              onPointerUp: _figUp,
              onPointerCancel: (e) => _figUp(e, cancelled: true),
            ),
          ),
        ],
      ),
    );
  }
}
