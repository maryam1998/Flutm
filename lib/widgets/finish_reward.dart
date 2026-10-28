import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../map/draw_utils.dart' show toFa;
import '../map/map_ops.dart';
import '../models/map_models.dart';
import '../state/goal_ops.dart';
import '../state/map_store.dart';
import '../theme/web_palette.dart';

const _kGreen = Color(0xFF1E9E6A);
const _kGold = Color(0xFFC9962B);

/// پاداشِ مغز وقتی یک شاخه/قدم «کاملاً تمام شد»؛ بر پایه‌ی تمرینِ
/// «نوشتن، خواندن، تجسم و قدمِ کوچک»:
///  ۱) دیدنِ پیشرفتِ واقعی (حلقه‌ی باز بسته شد)
///  ۲) ۱۰ ثانیه حسِ پیروزی را نگه‌داشتن (پاداش به خودِ کار گره می‌خورد)
///  ۳) یک جمله نوشتن: این کار چه چیزی را برایم ممکن کرد؟
class FinishReward {
  FinishReward._();

  static bool _open = false;

  /// همین چند ثانیه‌ی پیش «تمام شد» خورده؟
  static bool isFresh(ActionNode n) {
    final t = n.extra['finishedAt'];
    return nodeFinished(n) &&
        t is num &&
        DateTime.now().millisecondsSinceEpoch - t.toInt() < 3000;
  }

  static ActionNode? _parentOf(List<ActionNode> list, String id) {
    for (final x in list) {
      if (x.id == id) return null;
      for (final k in x.children) {
        if (k.id == id) return x;
      }
      final r = _parentOf(x.children, id);
      if (r != null) return r;
    }
    return null;
  }

  static Future<void> show(
    BuildContext context, {
    required MapStore store,
    required MapHost host,
    required ActionNode node,
  }) async {
    if (_open) return;
    final found = findActionNode(host.actions, node.id);
    if (found == null) return;
    _open = true;

    bool counts(ActionNode n) => !n.isRoutine && n.extra['achieved'] != true;
    final sibs = found.list.where(counts).toList();
    final sibDone = sibs.where(nodeFinished).length;
    final all = collectNodes(host.actions).where(counts).toList();
    final allDone = all.where(nodeFinished).length;
    final parent = _parentOf(host.actions, node.id);
    final hostName = host is Goal ? host.name : (host is Ring ? host.label : '');
    final groupName = (parent?.text.isNotEmpty ?? false)
        ? parent!.text
        : (hostName.isNotEmpty ? hostName : 'این هدف');

    final ctl =
        TextEditingController(text: (node.extra['finishNote'] as String?) ?? '');
    HapticFeedback.heavyImpact();
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        builder: (ctx) => _FinishSheet(
          title: node.text.isEmpty ? 'این قدم' : node.text,
          groupName: groupName,
          sibDone: sibDone,
          sibTotal: sibs.length,
          allDone: allDone,
          allTotal: all.length,
          noteCtl: ctl,
        ),
      );
      final t = ctl.text.trim();
      if (t.isEmpty) {
        node.extra.remove('finishNote');
      } else {
        node.extra['finishNote'] = t;
      }
      store.changed();
    } finally {
      _open = false;
      ctl.dispose();
    }
  }
}

class _FinishSheet extends StatefulWidget {
  const _FinishSheet({
    required this.title,
    required this.groupName,
    required this.sibDone,
    required this.sibTotal,
    required this.allDone,
    required this.allTotal,
    required this.noteCtl,
  });

  final String title, groupName;
  final int sibDone, sibTotal, allDone, allTotal;
  final TextEditingController noteCtl;

  @override
  State<_FinishSheet> createState() => _FinishSheetState();
}

class _FinishSheetState extends State<_FinishSheet>
    with SingleTickerProviderStateMixin {
  static const _holdSecs = 10;
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _holdSecs),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        HapticFeedback.mediumImpact();
        if (mounted) setState(() => _holdDone = true);
      }
    });
  bool _holdDone = false;

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  Widget _rich(String text, Color color, {double size = 12}) {
    final parts = text.split('**');
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: size, height: 1.9, color: color),
        children: [
          for (var i = 0; i < parts.length; i++)
            if (parts[i].isNotEmpty)
              TextSpan(
                  text: parts[i],
                  style: i.isOdd
                      ? const TextStyle(fontWeight: FontWeight.w800)
                      : null),
        ],
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
    );
  }

  Widget _bar(WebPalette wp, double from, double to, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: from, end: to),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: v.clamp(0.0, 1.0).toDouble(),
          minHeight: 8,
          color: color,
          backgroundColor: wp.textDim.withValues(alpha: 0.18),
        ),
      ),
    );
  }

  String _holdText(double t) {
    if (t < 0.3) return 'یک نفسِ عمیق بکش 🌬️';
    if (t < 0.7) return 'لبخند بزن؛ شانه‌هایت را سبک کن 😊';
    return 'به خودت بگو: «من انجامش دادم»';
  }

  @override
  Widget build(BuildContext context) {
    final wp = WebPalette.of(context);
    final kb = MediaQuery.of(context).viewInsets.bottom;
    final sibFrom = widget.sibTotal == 0
        ? 0.0
        : (widget.sibDone - 1).clamp(0, widget.sibTotal) / widget.sibTotal;
    final sibTo = widget.sibTotal == 0 ? 0.0 : widget.sibDone / widget.sibTotal;
    final allFrom = widget.allTotal == 0
        ? 0.0
        : (widget.allDone - 1).clamp(0, widget.allTotal) / widget.allTotal;
    final allTo = widget.allTotal == 0 ? 0.0 : widget.allDone / widget.allTotal;
    final pct = (allTo * 100).round();
    final groupDone =
        widget.sibTotal > 0 && widget.sibDone >= widget.sibTotal;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: EdgeInsets.fromLTRB(
            18, 8, 18, 12 + (kb > 0 ? kb : MediaQuery.of(context).padding.bottom)),
        decoration: BoxDecoration(
          color: wp.panelBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: wp.textDim.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // نشانِ بزرگِ تیک با موجِ نرم
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutBack,
                  builder: (_, v, __) => SizedBox(
                    width: 92,
                    height: 92,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: (1 - v).clamp(0.0, 1.0).toDouble() * 0.6,
                          child: Container(
                            width: 64 + 28 * v,
                            height: 64 + 28 * v,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: _kGreen, width: 3),
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: v.clamp(0.0, 1.2).toDouble(),
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: _kGreen,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: _kGreen.withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    spreadRadius: 2),
                              ],
                            ),
                            child: const Icon(Icons.check_rounded,
                                size: 40, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text('«${widget.title}» تمام شد 🎉',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16.5,
                      height: 1.6,
                      fontWeight: FontWeight.w800,
                      color: wp.textMain)),
              const SizedBox(height: 2),
              Text(
                  groupDone
                      ? 'همه‌ی شاخه‌های «${widget.groupName}» تمام شد! 🌟'
                      : 'یک حلقه‌ی باز بسته شد؛ ذهنت یک بارِ نیمه‌تمام کمتر دارد.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, height: 1.7, color: wp.textDim)),

              // ۱) پیشرفتِ واقعی
              const SizedBox(height: 12),
              _card(
                wp,
                _kGreen,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.sibTotal > 1) ...[
                      Text(
                          '${toFa(widget.sibDone)} از ${toFa(widget.sibTotal)} شاخه‌ی «${widget.groupName}» تمام شد',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: wp.textMain)),
                      const SizedBox(height: 6),
                      _bar(wp, sibFrom, sibTo, _kGreen),
                      const SizedBox(height: 10),
                    ],
                    Text(
                        'کلِ مسیر: ${toFa(widget.allDone)} از ${toFa(widget.allTotal)} قدم تمام شده (${toFa(pct)}٪)',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: wp.textMain)),
                    const SizedBox(height: 6),
                    _bar(wp, allFrom, allTo, _kGold),
                  ],
                ),
              ),

              // ۲) ده ثانیه حسِ پیروزی
              const SizedBox(height: 10),
              _card(
                wp,
                _kGold,
                AnimatedBuilder(
                  animation: _hold,
                  builder: (_, __) {
                    final running = _hold.isAnimating;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            _holdDone
                                ? 'پاداش ثبت شد 🧠✨'
                                : 'پاداشِ مغزت را کامل کن (۱۰ ثانیه)',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: wp.textMain)),
                        const SizedBox(height: 4),
                        Text(
                            _holdDone
                                ? 'مغز آنچه را با حسِ خوب همراه شود تکرار می‌کند؛ همین الان این کار را به «حسِ پیروزی» گره زدی.'
                                : running
                                    ? _holdText(_hold.value)
                                    : 'فقط ۱۰ ثانیه حسِ «انجامش دادم» را در بدنت نگه دار؛ همین، مسیرِ پاداش را به خودِ کار وصل می‌کند.',
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.8,
                                color: wp.textMain.withValues(alpha: 0.85))),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            SizedBox(
                              width: 34,
                              height: 34,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: _holdDone ? 1 : _hold.value,
                                    strokeWidth: 3.5,
                                    color: _holdDone ? _kGreen : _kGold,
                                    backgroundColor:
                                        wp.textDim.withValues(alpha: 0.18),
                                  ),
                                  if (_holdDone)
                                    const Icon(Icons.check_rounded,
                                        size: 18, color: _kGreen),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            if (!_holdDone && !running)
                              FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: _kGold,
                                    visualDensity: VisualDensity.compact),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  _hold.forward(from: 0);
                                  setState(() {});
                                },
                                child: const Text('شروع کن'),
                              ),
                            if (running)
                              Text(
                                  toFa(
                                      '${(_holdSecs - (_hold.value * _holdSecs)).ceil()}'),
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: wp.textMain)),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),

              // چرا مغز خوشش می‌آید؟
              const SizedBox(height: 10),
              _card(
                wp,
                _kGreen,
                _rich(
                    '**چرا مغزت خوشش می‌آید؟** وقتی یک کار را کامل می‌کنی، مدارِ پاداش (**دوپامین**) فعال می‌شود و مغز یاد می‌گیرد «این مسیر جواب می‌دهد». اگر همین لحظه چند ثانیه حسِ پیروزی را نگه داری (مثل تمرینِ تجسم)، پاداش به خودِ کار گره می‌خورد و با تکرار، **مسیرِ عصبیِ «من آدمِ انجام‌دهنده‌ام»** قوی‌تر می‌شود (نوروپلاستیسیتی). بسته‌شدنِ یک کارِ نیمه‌تمام هم بارِ حافظه‌ی کاری را از **قشر پیش‌پیشانی** (PFC) برمی‌دارد تا برای قدمِ بعدی انرژی داشته باشد.',
                    wp.textMain.withValues(alpha: 0.88)),
              ),

              // ۳) نوشتن
              const SizedBox(height: 10),
              Text('یک جمله بنویس: این کار چه چیزی را برایم ممکن کرد؟',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: wp.textMain)),
              const SizedBox(height: 6),
              TextField(
                controller: widget.noteCtl,
                minLines: 1,
                maxLines: 3,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'مثلاً: یک قدم به مهاجرت نزدیک‌تر شدم',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: _kGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ادامه می‌دهم 🚀',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(WebPalette wp, Color accent, Widget child) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: child,
      );
}
