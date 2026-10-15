import 'package:flutter/material.dart';

import '../data/neural_tiers.dart';
import '../models/neural_container.dart';
import '../theme/grat_palette.dart';
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

  /// true → رنگ‌ها، هندسه و منطقِ دقیقِ وب (`#grat-root` + neural-pathway.js):
  /// کارت --surface، رشته‌ی پیش‌فرض --accent، دکمه‌های .btn.tiny،
  /// پالس نورون عادت در تیِر ۳، و autoSync/cleanup در هر رندر.
  final bool webStyle;

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
    this.webStyle = false,
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
    // وب: habitStyle.glow = (تیِر ۳) برای نورون عادت — حتی اگه هنوز «قفل» نشده
    if (widget.webStyle) return t == 3;
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

  /// renderNeuralPathway وب: در هر رندر ابتدا autoSync (روزهای گذشته‌ی ثبت‌نشده
  /// → «انجام نشد») و cleanupPending اجرا می‌شود، بعد رشته‌ها شمرده می‌شوند.
  void _syncContainer() {
    if (!widget.webStyle) return;
    var changed = false;
    if (!widget.noMissPenalty) {
      changed = widget.container.autoSync() || changed;
    }
    if (widget.calendarLinked) {
      changed = widget.container.cleanupPending(
            calendarLinked: true,
            isConfirmed: widget.isConfirmed ?? (_) => false,
          ) ||
          changed;
    }
    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onChange?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncContainer();
    final colors = widget.webStyle
        ? NeuralColors.web(GratPalette.of(context))
        : NeuralColors.legacy;
    final fiberCount = widget.container.fiberCount;
    final habitFormed = widget.container.habitFormed;
    final status = _statusText(fiberCount, habitFormed);
    final qualityBadge = _qualityBadge(colors);
    final showHabitBtn =
        widget.showHabitButton && (fiberCount > 0 || habitFormed);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
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
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: colors.ink,
                  ),
                ),
              ),
              Text(
                '${_toFa(fiberCount)} رشته',
                style: TextStyle(fontSize: 11, color: colors.muted),
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
                  textColor: colors.ink,
                  pulseValue: _shouldPulse ? _pulse.value : 0,
                  colors: colors,
                ),
              ),
            ),
          ),
          SizedBox(height: widget.webStyle ? 10 : 4),

          // وضعیت کلامی
          Text(
            status,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: colors.inkSoft,
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
                    colors: colors,
                    text: '✨ امروز انجام دادم',
                    onTap: _onTodayDone,
                    filled: !widget.webStyle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _pillButton(
                    colors: colors,
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
              colors: colors,
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

  Widget? _qualityBadge(NeuralColors colors) {
    final q = widget.emotionQualityToday;
    if (q == null) return null;

    final Color color;
    final String text;
    if (q >= 500) {
      color = const Color(0xFF2BBFAB);
      text = '🔥 حس پرقدرت امروز — رشته‌ها ضخیم‌تر شدن';
    } else if (q < 200) {
      color = colors.webStyle ? const Color(0xFFC9A24B) : kGold500;
      text = '⚠️ حس امروز ضعیف بود — دفعه‌ی بعد عمیق‌تر';
    } else {
      color = const Color(0xFF5EC8F0);
      text = '✓ حس امروز ثبت شد';
    }

    // وب: background: color+'15' ؛ border: color+'40'
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0x15 / 255),
        border: Border.all(color: color.withValues(alpha: 0x40 / 255)),
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
    required NeuralColors colors,
    required String text,
    required VoidCallback onTap,
    required bool filled,
  }) {
    // وب: .btn.tiny → padding 5×9، فونت ۱۱، شعاع ۷، border=--panel-border،
    // پس‌زمینه rgba(255,255,255,.05)، متن --text-main
    if (colors.webStyle) {
      return Material(
        color: colors.btnBg,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: colors.btnBorder),
            ),
            alignment: Alignment.center,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: colors.btnText),
            ),
          ),
        ),
      );
    }
    return Material(
      color: filled ? colors.gold : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: filled ? colors.gold : colors.btnBorder,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: filled ? colors.goldText : colors.btnText,
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
