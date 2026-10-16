import 'package:flutter/material.dart';

import '../data/neural_tiers.dart';
import '../models/neural_container.dart';
import 'neural_pathway_painter.dart';

/// ویجت «مسیر عصبی» — دو نورون رفتار و عادت با رشته‌های پویا.
/// مشترک بین شکرگذاری، باور، دیسپنزا، RAS، تصویرسازی و بازی فراوانی.
class NeuralPathway extends StatefulWidget {
  final NeuralContainer container;
  final String label;

  /// اگر مقدار داشته باشه، روزهای گذشته که تیک نخورده‌ن خودکار «انجام نشد» می‌شن
  final bool noMissPenalty;

  /// نمایش دکمه‌های «امروز انجام دادم / انجام ندادم»
  final bool showDayButtons;

  /// نمایش دکمه‌ی «این عادت جاافتاد»
  final bool showHabitButton;

  /// کیفیت حس امروز (۰..۷۰۰). اگه null باشه بج نشون داده نمی‌شه.
  final int? emotionQualityToday;

  /// اگه وصل به تقویم باشه، ثبتِ دستی برای تأیید لازمه
  final bool calendarLinked;
  final bool Function(String dayKey)? isConfirmed;

  /// هر بار تغییر داد (برای ذخیره در store)
  final VoidCallback? onChange;

  const NeuralPathway({
    super.key,
    required this.container,
    required this.label,
    this.noMissPenalty = false,
    this.showDayButtons = true,
    this.showHabitButton = true,
    this.emotionQualityToday,
    this.calendarLinked = false,
    this.isConfirmed,
    this.onChange,
  });

  @override
  State<NeuralPathway> createState() => _NeuralPathwayState();
}

class _NeuralPathwayState extends State<NeuralPathway>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // فقط اگه نورون عادت در تیر ۳ باشه، پالس شروع می‌شه
    if (_shouldPulse) _pulse.repeat(reverse: true);
  }

  bool get _shouldPulse {
    final t = neuralTier(
      widget.container.fiberCount,
      widget.container.habitFormed,
    );
    return t == 3 && widget.container.habitFormed;
  }

  @override
  void didUpdateWidget(covariant NeuralPathway old) {
    super.didUpdateWidget(old);
    if (_shouldPulse && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!_shouldPulse && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  // ---------------- actions ----------------

  void _onTodayDone() {
    widget.container.addFiber(
      calendarLinked: widget.calendarLinked,
    );
    widget.onChange?.call();
    setState(() {});
  }

  void _onTodayMiss() {
    widget.container.removeFiber();
    widget.onChange?.call();
    setState(() {});
  }

  void _onToggleHabit() {
    widget.container.habitFormed = !widget.container.habitFormed;
    widget.onChange?.call();
    setState(() {});
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    final fiberCount = widget.container.fiberCount;
    final habitFormed = widget.container.habitFormed;
    final status = _statusText(fiberCount, habitFormed);
    final qualityBadge = _qualityBadge();
    final showHabitBtn =
        widget.showHabitButton && (fiberCount > 0 || habitFormed);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: kNeuralCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kNeuralBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // هدر
          Row(
            children: [
              const Text('🧠 ', style: TextStyle(fontSize: 14)),
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: kNeuralInk,
                  ),
                ),
              ),
              Text(
                '${_toFa(fiberCount)} رشته',
                style: const TextStyle(fontSize: 11, color: kNeuralMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // نقشه‌ی دو نورون
          AspectRatio(
            aspectRatio: 380 / 175,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (ctx, _) => CustomPaint(
                painter: NeuralPathwayPainter(
                  fiberCount: fiberCount,
                  container: widget.container,
                  textColor: kNeuralInk,
                  pulseValue: _shouldPulse ? _pulse.value : 0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // وضعیت کلامی
          Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: kNeuralInk,
              height: 1.6,
            ),
          ),

          if (qualityBadge != null) ...[
            const SizedBox(height: 8),
            qualityBadge,
          ],

          // دکمه‌های روزانه
          if (widget.showDayButtons) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _pillButton(
                    text: '✨ امروز انجام دادم',
                    onTap: _onTodayDone,
                    filled: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _pillButton(
                    text: 'یک روز گذشت، انجام ندادم',
                    onTap: _onTodayMiss,
                    filled: false,
                  ),
                ),
              ],
            ),
          ],

          // دکمه‌ی «این عادت جاافتاد»
          if (showHabitBtn) ...[
            const SizedBox(height: 8),
            _pillButton(
              text: habitFormed
                  ? '↩️ هنوز کافی نیست، ادامه بده'
                  : '✅ همین‌ست، این عادت جاافتاد',
              onTap: _onToggleHabit,
              filled: false,
            ),
          ],
        ],
      ),
    );
  }

  // ---------------- status ----------------

  String _statusText(int fiberCount, bool habitFormed) {
    if (habitFormed) {
      return '🎉 این عادت کاملاً جاافتاده — یک مدار عصبی واقعی.';
    }
    if (fiberCount <= 0) {
      return 'هنوز مداری برای «${widget.label}» شکل نگرفته — امروز اولین قدم را بردار.';
    }
    if (fiberCount < 3) {
      return 'اولین رشته‌های «${widget.label}» شکل گرفته — ادامه بده.';
    }
    if (fiberCount < kNeuralFiberCap) {
      return 'رشته‌های «${widget.label}» دارن کنار هم جمع و ضخیم می‌شن.';
    }
    return '«${widget.label}» یک مسیر محکم شده — اگر واقعاً عادت شده، قفلش کن.';
  }

  // ---------------- quality badge ----------------

  Widget? _qualityBadge() {
    final q = widget.emotionQualityToday;
    if (q == null) return null;

    final Color color;
    final String text;
    if (q >= 500) {
      color = kEmerald500;
      text = '🔥 حس پرقدرت امروز — رشته‌ها ضخیم‌تر شدن';
    } else if (q < 200) {
      color = kGold500;
      text = '⚠️ حس امروز ضعیف بود — دفعه‌ی بعد عمیق‌تر';
    } else {
      color = const Color(0xFF5EC8F0);
      text = '✓ حس امروز ثبت شد';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ---------------- pill button ----------------

  Widget _pillButton({
    required String text,
    required VoidCallback onTap,
    required bool filled,
  }) {
    return Material(
      color: filled ? kEmerald700 : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: filled ? kEmerald700 : kNeuralBorder,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : kNeuralInk,
            ),
          ),
        ),
      ),
    );
  }

  static String _toFa(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'\d'),
      (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m.group(0)!)],
    );
  }
}
