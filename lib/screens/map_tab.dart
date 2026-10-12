import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../map/camera.dart';
import '../map/map_canvas.dart';
import '../services/storage.dart';
import '../state/map_store.dart';

/// مرحله ۲: رسم نقشه + pan/zoom. لمس گره‌ها و ویرایش در مرحله ۳.
class MapTab extends StatefulWidget {
  const MapTab({super.key});
  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final cam = CameraController();
  final bounds = MapBoundsBox();

  @override
  void dispose() {
    cam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MapStore>();
    final empty = store.state.goals.isEmpty && store.state.rings.isEmpty;
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
          Positioned.fill(child: MapCanvas(cam: cam, boundsBox: bounds)),
          if (empty)
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: const Alignment(0, 0.35),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'هنوز هدفی نیست.\nاز منوی بالا «ورودی بکاپ» رو بزن تا نقشه‌ی قبلی‌ت بیاد.\n(افزودن هدف جدید در مرحله‌ی بعد اضافه میشه)',
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
          Positioned(
            left: 16,
            bottom: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'fit',
                  tooltip: 'نمایش همه',
                  onPressed: () {
                    final r = bounds.rect;
                    if (r != null) cam.fitRect(r);
                  },
                  child: const Icon(Icons.fit_screen),
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
