// lib/screens/shenakht/situations_screen.dart
import 'package:flutter/material.dart';

import '../../data/shenakht/situations_data.dart';
import 'shenakht_tab.dart';

class SituationsScreen extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(String situationId) onPickSituation;

  const SituationsScreen({
    super.key,
    required this.onBack,
    required this.onPickSituation,
  });

  @override
  State<SituationsScreen> createState() => _SituationsScreenState();
}

class _SituationsScreenState extends State<SituationsScreen> {
  String _cat = 'all';

  static const _catColors = {
    'work': Color(0xFF3B82F6),
    'relationship': Color(0xFFEC4899),
    'family': Color(0xFFF59E0B),
    'social': Color(0xFF8B5CF6),
    'self': Color(0xFF10B981),
    'health': Color(0xFFEF4444),
    'online': Color(0xFF0891B2),
  };

  static const _catIcons = {
    'work': '💼',
    'relationship': '💞',
    'family': '🏠',
    'social': '👥',
    'self': '🧠',
    'health': '💪',
    'online': '📱',
  };

  @override
  Widget build(BuildContext context) {
    final list = getSituationsByCategory(_cat);

    return ShenakhtShell(
      title: 'موقعیت‌های من',
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
            child: Row(
              children: [
                const Text('🔍', style: TextStyle(fontSize: 36)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('الان چه حسی داری؟',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text(
                        'موقعیتت رو انتخاب کن — بعد با هم می‌بینیم چیکار می‌شه کرد',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final c in situationCategories) ...[
                  _catChip(c),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final s in list) _situationCard(s),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _catChip(SituationCategory c) {
    final active = _cat == c.id;
    final color = _catColors[c.id] ?? SK.primary;
    return Material(
      color: active ? color : Colors.white,
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
              color: active ? color : const Color(0xFFE5E5E5),
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

  Widget _situationCard(Situation s) {
    final color = _catColors[s.category] ?? SK.primary;
    final icon = _catIcons[s.category] ?? '📍';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => widget.onPickSituation(s.id),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFF0F0F0)),
              borderRadius: BorderRadius.circular(14),
              border: Border(
                right: BorderSide(color: color, width: 4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(icon,
                      style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.6)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(s.categoryLabel,
                            style: TextStyle(
                                fontSize: 9,
                                color: color,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Icon(Icons.arrow_back,
                      size: 16, color: Color(0xFFCCCCCC)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
