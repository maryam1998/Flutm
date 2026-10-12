import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../map/camera.dart';
import '../map/map_canvas.dart';
import '../services/storage.dart';
import '../state/map_store.dart';
import 'add_goal_dialog.dart';
import 'edit_sheet.dart';

/// مرحله ۳: نقشه + لمس و درگ گره‌ها/شاخه‌ها + افزودن هدف/نشانه/شاخه + پنل ویرایش
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

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MapStore>();
    final empty = store.state.goals.isEmpty && store.state.rings.isEmpty;
    final anyOpen = store.anyOpen;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFF0B0D1E), Color(0xFF151933)],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: MapCanvas(
              cam: cam,
              boundsBox: bounds,
              isResizeMode: () => _resizeMode,
              onEditMe: () => showEditSheet(context, const MeTarget()),
              onEditGoal: (id) => showEditSheet(context, GoalTarget(id)),
              onEditRing: (id) => showEditSheet(context, RingTarget(id)),
              onEditAction: (hostId, actionId) => showEditSheet(context, ActionTarget(hostId, actionId)),
            ),
          ),
          if (empty)
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: const Alignment(0, 0.35),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'هنوز هدفی نیست.\nبا دکمه‌ی + یه هدف بساز، یا از منوی بالا «ورودی بکاپ» رو بزن تا نقشه‌ی قبلی‌ت بیاد.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withAlpha(140), height: 1.8),
                    ),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) => v == 'in' ? _import(context, store) : _export(context, store),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'in', child: Text('ورودی بکاپ (JSON)')),
                      PopupMenuItem(value: 'out', child: Text('خروجی بکاپ')),
                    ],
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
                      child: const Text('حالت تغییر اندازه: دو انگشت روی نوشته/آیکون', style: TextStyle(fontSize: 12)),
                    ),
                  ListenableBuilder(
                    listenable: cam,
                    builder: (_, __) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(10)),
                      child: Text('${(cam.scale * 100).round()}٪', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // دکمه‌های ابزار (چپ پایین)
          Positioned(
            left: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
          // افزودن (راست پایین)
          Positioned(
            right: 16,
            bottom: 16,
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
