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
  });

  final Set<String> selectedIds;
  final bool isDark;
  final void Function(String id) onToggle;

  /// وقتی پنل همین الان درگ شده، تپ روی ردیف‌ها نادیده گرفته می‌شه (مثل suppressClickUntil وب)
  final bool Function() tapSuppressed;

  @override
  State<EmotionChart> createState() => _EmotionChartState();
}

class _EmotionChartState extends State<EmotionChart>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _time.value = elapsed.inMicroseconds / 1000000.0;
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
          Positioned.fill(
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
        ],
      ),
    );
  }
}
