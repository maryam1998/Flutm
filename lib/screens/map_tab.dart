import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/map_models.dart';
import '../services/storage.dart';
import '../state/map_store.dart';

/// مرحله ۱: فقط خلاصه‌ی داده + بکاپ. بوم نقشه در مرحله ۲ اضافه میشه.
class MapTab extends StatelessWidget {
  const MapTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MapStore>();
    final s = store.state;
    final branches = s.goals.fold<int>(0, (n, g) => n + countActions(g.actions)) +
        s.rings.fold<int>(0, (n, r) => n + countActions(r.actions));
    final images = s.me.images.length +
        s.goals.fold<int>(0, (n, g) => n + g.images.length) +
        s.rings.fold<int>(0, (n, r) => n + r.images.length);

    return Scaffold(
      appBar: AppBar(title: const Text('نقشه')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('داده‌ی نقشه', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _row('اهداف', s.goals.length),
                  _row('حلقه‌ها', s.rings.length),
                  _row('شاخه‌ها و زیرشاخه‌ها', branches),
                  _row('تصاویر گره‌ها', images),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _import(context, store),
            icon: const Icon(Icons.file_open),
            label: const Text('ورودی بکاپ (JSON)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _export(context, store),
            icon: const Icon(Icons.save_alt),
            label: const Text('خروجی بکاپ'),
          ),
          const SizedBox(height: 16),
          const Text('بوم نقشه در مرحله‌ی بعد اضافه میشه.', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _row(String label, int n) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Expanded(child: Text(label)), Text('$n')]),
      );

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
