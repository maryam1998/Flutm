import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../map/camera.dart';
import '../map/map_canvas.dart';
import '../map/map_ops.dart';
import '../models/map_models.dart';
import '../services/storage.dart';
import '../state/goal_ops.dart';
import '../state/map_store.dart';
import '../theme/web_palette.dart';
import 'add_goal_dialog.dart';
import 'edit_sheet.dart';
import 'goals_sheet.dart';
import 'settings_sheet.dart';
import 'time_sheet.dart';

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
    final wp = WebPalette.of(context);
    final ink = wp.textMain;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MapCanvas(
            cam: cam,
            boundsBox: bounds,
            isResizeMode: () => _resizeMode,
            onEditMe: () => showEditSheet(context, const MeTarget()),
            onEditGoal: (id) => showEditSheet(context, GoalTarget(id)),
            onEditRing: (id) => showEditSheet(context, RingTarget(id)),
            onEditAction: (hostId, actionId) =>
                showEditSheet(context, ActionTarget(hostId, actionId)),
            onTimeBranch: (hostId, actionId) {
              final h = store.state.findHost(hostId);
              if (h is! MapHost) return;
              final f = findActionNode(h.actions, actionId);
              if (f == null) return;
              final pi = periodInfo(h, store);
              showTimeSheet(
                context,
                store: store,
                host: h,
                node: f.node,
                jk: pi.todayJK,
                dayLabel: 'امروز',
              );
            },
          ),

          if (empty)
            IgnorePointer(
              child: Align(
                alignment: const Alignment(0, 0.35),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'هنوز هدفی نیست.\nبا دکمه‌ی + پایین یه هدف بساز.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.55),
                      height: 1.8,
                    ),
                  ),
                ),
              ),
            ),

          // نوار بالا — بدون دکمه‌ی تنظیمات
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    _roundBtn(
                      Icons.more_vert,
                      ink,
                      () => _showTopMenu(store),
                    ),
                    const Spacer(),
                    if (_resizeMode)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5EC8F0)
                              .withValues(alpha: 0.24),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFF5EC8F0)),
                        ),
                        child: Text('تغییر اندازه',
                            style: TextStyle(fontSize: 11, color: ink)),
                      ),
                    _roundBtn(
                      Icons.open_in_full,
                      _resizeMode ? const Color(0xFF5EC8F0) : ink,
                      () => setState(() => _resizeMode = !_resizeMode),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: wp.panelBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: wp.panelBorder),
                      ),
                      child: ListenableBuilder(
                        listenable: cam,
                        builder: (_, __) => Text(
                          '${(cam.scale * 100).round()}٪',
                          style: TextStyle(fontSize: 12, color: ink),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // نشانگر ذخیره
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

          // نوار ابزار پایین — دکمه‌ی تنظیمات اضافه شد
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: SafeArea(
              top: false,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                decoration: BoxDecoration(
                  color: wp.panelBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: wp.panelBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _toolBtn(Icons.format_list_bulleted, 'اهداف', ink,
                        _openGoals),
                    _toolBtn(Icons.fit_screen, 'نمایش همه', ink, _fit),
                    _toolBtn(
                        Icons.stars_outlined, 'نشانه', ink, store.addRing),
                    if (store.hasCollapsible)
                      _toolBtn(
                        anyOpen ? Icons.unfold_less : Icons.unfold_more,
                        anyOpen ? 'جمع همه' : 'باز همه',
                        ink,
                        () => store.collapseAll(anyOpen),
                      ),
                    _toolBtn(
                      Icons.settings,
                      'تنظیمات',
                      ink,
                      () => showSettingsSheet(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData icon, Color color, VoidCallback onTap) {
    final wp = WebPalette.of(context);
    return Material(
      color: wp.panelBg,
      shape: CircleBorder(side: BorderSide(color: wp.panelBorder)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }

  Widget _toolBtn(IconData icon, String label, Color color, VoidCallback onTap,
      {bool primary = false}) {
    final bg = primary ? const Color(0xFFC9972B) : Colors.transparent;
    final fg = primary ? Colors.white : color;
    return Expanded(
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTopMenu(MapStore store) {
    showMenu<String>(
      context: context,
      items: const [
        PopupMenuItem(value: 'in', child: Text('ورودی بکاپ (JSON)')),
        PopupMenuItem(value: 'out', child: Text('خروجی بکاپ')),
      ],
    ).then((v) {
      if (v == 'in') _import(context, store);
      if (v == 'out') _export(context, store);
    });
  }

  Future<void> _import(BuildContext context, MapStore store) async {
    final msg = ScaffoldMessenger.of(context);
    try {
      final raw = await StorageService().pickBackup();
      if (raw == null) return;
      await store.importJson(raw);
      msg.showSnackBar(const SnackBar(content: Text('بکاپ وارد شد')));
    } catch (e) {
      msg.showSnackBar(
          SnackBar(content: Text('ورود بکاپ ناموفق بود: $e')));
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
  @override
  void initState() {
    super.initState();
    _c.forward();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) _c.reverse();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(20),
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
