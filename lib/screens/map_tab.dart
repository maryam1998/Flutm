import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../map/camera.dart';
import '../map/map_canvas.dart';
import '../services/storage.dart';
import '../state/map_store.dart';
import 'add_goal_dialog.dart';
import 'edit_sheet.dart';
import 'goals_sheet.dart';
import '../theme/app_theme.dart';
import 'settings_sheet.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});
  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final cam = CameraController();
  final bounds = MapBoundsBox();
  late final MapStore _store;
  bool _resizeMode = false;

  @override
  void initState() {
    super.initState();
    _store = context.read<MapStore>();
    _store.toast = _toast;
  }

  @override
  void dispose() {
    _store.toast = null;
    cam.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  void _fit() {
    final r = bounds.rect;
    if (r != null) cam.fitRect(r);
  }

  void _openGoals() {
    showGoalsSheet(
      context,
      onShowOnMap: (h) => cam.centerOn(Offset(h.x, h.y)),
      onAddGoal: () => showAddGoalDialog(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MapStore>();
    final empty = store.state.goals.isEmpty && store.state.rings.isEmpty;
    final anyOpen = store.anyOpen;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg1 = isDark ? kDarkBg : kLightBg;
    final bg2 = isDark ? kDarkBg2 : kLightBg2;
    final ink = isDark ? Colors.white : kLightInk;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,          // ← این خط حیاتی
        children: [
          // پس‌زمینه
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [bg1, bg2],
              ),
            ),
          ),

          // بوم نقشه
          MapCanvas(
            cam: cam,
            boundsBox: bounds,
            isResizeMode: () => _resizeMode,
            onEditMe: () => showEditSheet(context, const MeTarget()),
            onEditGoal: (id) => showEditSheet(context, GoalTarget(id)),
            onEditRing: (id) => showEditSheet(context, RingTarget(id)),
            onEditAction: (hostId, actionId) =>
                showEditSheet(context, ActionTarget(hostId, actionId)),
          ),

          // پیام حالت خالی
          if (empty)
            IgnorePointer(
              child: Align(
                alignment: const Alignment(0, 0.35),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'هنوز هدفی نیست.\nبا دکمه‌ی + یه هدف بساز، یا از منوی بالا «ورودی بکاپ» رو بزن.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ink.withAlpha(150), height: 1.8),
                  ),
                ),
              ),
            ),

          // نوار بالا (منوی سه‌نقطه + درصد زوم)
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: ink),
                      onSelected: (v) =>
                          v == 'in' ? _import(context, store) : _export(context, store),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'in', child: Text('ورودی بکاپ (JSON)')),
                        PopupMenuItem(value: 'out', child: Text('خروجی بکاپ')),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.settings, color: ink),
                      tooltip: 'تنظیمات نقشه',
                      onPressed: () => showSettingsSheet(context),
                    ),
                    const Spacer(),
                    if (_resizeMode)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5EC8F0).withAlpha(60),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF5EC8F0)),
                        ),
                        child: const Text('تغییر اندازه با دو انگشت',
                            style: TextStyle(fontSize: 12, color: Colors.white)),
                      ),
                    const SizedBox(width: 8),
                    ListenableBuilder(
                      listenable: cam,
                      builder: (_, __) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: isDark ? Colors.black38 : Colors.white70,
                            borderRadius: BorderRadius.circular(10)),
                        child: Text('${(cam.scale * 100).round()}٪',
                            style: TextStyle(fontSize: 12, color: ink)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // نشانگر ذخیره (پایین وسط)
          Positioned(
            bottom: 90,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ValueListenableBuilder<int>(
                  valueListenable: store.lastSaved,
                  builder: (_, ts, __) {
                    if (ts == 0) return const SizedBox.shrink();
                    return _SaveIndicator(key: ValueKey(ts));
                  },
                ),
              ),
            ),
          ),

          // دکمه‌های ابزار (چپ پایین)
          Positioned(
            left: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'goals',
                    tooltip: 'فهرست اهداف',
                    onPressed: _openGoals,
                    child: const Icon(Icons.format_list_bulleted),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton.small(
                    heroTag: 'resize',
                    tooltip: 'حالت تغییر اندازه',
                    backgroundColor: _resizeMode ? const Color(0xFF5EC8F0) : null,
                    foregroundColor: _resizeMode ? Colors.black : null,
                    onPressed: () => setState(() => _resizeMode = !_resizeMode),
                    child: const Icon(Icons.open_in_full),
                  ),
                  if (store.hasCollapsible) ...[
                    const SizedBox(height: 10),
                    FloatingActionButton.small(
                      heroTag: 'collapse',
                      tooltip: anyOpen ? 'جمع همه' : 'باز همه',
                      onPressed: () => store.collapseAll(anyOpen),
                      child: Icon(anyOpen ? Icons.unfold_less : Icons.unfold_more),
                    ),
                  ],
                  const SizedBox(height: 10),
                  FloatingActionButton.small(
                    heroTag: 'fit',
                    tooltip: 'نمایش همه',
                    onPressed: _fit,
                    child: const Icon(Icons.fit_screen),
                  ),
                ],
              ),
            ),
          ),

          // افزودن (راست پایین)
          Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'addRing',
                    tooltip: 'نشانه‌ی نزدیکی جدید',
                    onPressed: store.addRing,
                    child: const Icon(Icons.stars_outlined),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton(
                    heroTag: 'addGoal',
                    tooltip: 'هدف جدید',
                    onPressed: () => showAddGoalDialog(context),
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context, MapStore store) async {
    final msg = ScaffoldMessenger.of(context);
    try {
      final raw = await StorageService().pickBackup();
      if (raw == null) return;
      await store.importJson(raw);
      msg.showSnackBar(const SnackBar(content: Text('بکاپ وارد شد')));
    } catch (e) {
      msg.showSnackBar(SnackBar(content: Text('ورود بکاپ ناموفق بود: $e')));
    }
  }

  Future<void> _export(BuildContext context, MapStore store) async {
    final msg = ScaffoldMessenger.of(context);
    try {
      final ok = await StorageService().exportBackup(await store.exportJson());
      if (ok) msg.showSnackBar(const SnackBar(content: Text('بکاپ ذخیره شد')));
    } catch (e) {
      msg.showSnackBar(SnackBar(content: Text('خروجی ناموفق بود: $e')));
    }
  }
}

class _SaveIndicator extends StatefulWidget {
  const _SaveIndicator({super.key});
  @override
  State<_SaveIndicator> createState() => _SaveIndicatorState();
}

class _SaveIndicatorState extends State<_SaveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _hide = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) _c.reverse();
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(150),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(40)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: Color(0xFF63D6A8)),
            SizedBox(width: 6),
            Text('ذخیره شد',
                style: TextStyle(fontSize: 12, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
