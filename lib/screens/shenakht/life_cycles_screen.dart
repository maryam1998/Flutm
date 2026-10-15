// lib/screens/shenakht/life_cycles_screen.dart
import 'package:flutter/material.dart';

import '../../data/shenakht/life_cycles_data.dart';
import 'shenakht_tab.dart';

class LifeCyclesScreen extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(String cycleId) onPickCycle;

  const LifeCyclesScreen({
    super.key,
    required this.onBack,
    required this.onPickCycle,
  });

  @override
  State<LifeCyclesScreen> createState() => _LifeCyclesScreenState();
}

class _LifeCyclesScreenState extends State<LifeCyclesScreen> {
  String _cat = 'all';

  @override
  Widget build(BuildContext context) {
    final list = getLifeCyclesByCategory(_cat);

    return ShenakhtShell(
      title: 'چرخه‌های زندگی',
      onBack: widget.onBack,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: SK.grad,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('🔄', style: TextStyle(fontSize: 36)),
                SizedBox(height: 10),
                Text('الگوهایی که در زندگی تکرار می‌شن',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.5)),
                SizedBox(height: 8),
                Text(
                  'این‌ها از ترکیب چند طرحواره ساخته می‌شن و در موقعیت‌های واقعی زندگی خودشون رو نشون می‌دن.',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 13, height: 1.9),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final c in lifeCycleCategories) ...[
                  _catChip(c),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final lc in list) _cycleCard(lc),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _catChip(LifeCycleCategory c) {
    final active = _cat == c.id;
    return Material(
      color: active ? SK.primary : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => setState(() => _cat = c.id),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? SK.primary : const Color(0xFFE5E5E5),
            ),
          ),
          child: Text('${c.emoji} ${c.label}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : Colors.black,
              )),
        ),
      ),
    );
  }

  Widget _cycleCard(LifeCycle lc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => widget.onPickCycle(lc.id),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFF0F0F0)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7F4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(lc.categoryLabel,
                      style: const TextStyle(
                          fontSize: 10,
                          color: SK.primary,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 10),
                Text(lc.title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.6)),
                const SizedBox(height: 8),
                Text(lc.shortDescription,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                        height: 1.8)),
                const SizedBox(height: 12),
                Text('مشاهده کامل ←',
                    style: TextStyle(
                        fontSize: 11,
                        color: SK.primary,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
