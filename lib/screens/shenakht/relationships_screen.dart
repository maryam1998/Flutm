// lib/screens/shenakht/relationships_screen.dart
import 'package:flutter/material.dart';

import '../../data/shenakht/relationships_data.dart';
import 'shenakht_tab.dart';

class RelationshipsScreen extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(String patternId) onPickPattern;
  final void Function(String schemaId) onPickResponseGuide;

  const RelationshipsScreen({
    super.key,
    required this.onBack,
    required this.onPickPattern,
    required this.onPickResponseGuide,
  });

  @override
  State<RelationshipsScreen> createState() => _RelationshipsScreenState();
}

class _RelationshipsScreenState extends State<RelationshipsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return ShenakhtShell(
      title: 'روابط من',
      onBack: widget.onBack,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: SK.grad,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: const [
                Text('💞', style: TextStyle(fontSize: 44)),
                SizedBox(height: 10),
                Text('روابط من',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                Text(
                  'چرا بعضی روابط تکرار می‌شن؟\nچطور بهتر برخورد کنم؟',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.9),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _tabBtn('💬 چطور برخورد کنم؟', 0),
                _tabBtn('🔁 چرا تکرار می‌شوند؟', 1),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_tab == 0) ..._respondTab(),
          if (_tab == 1) ..._whyTab(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, int i) {
    final active = _tab == i;
    return Expanded(
      child: Material(
        color: active ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => setState(() => _tab = i),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: active
                  ? [
                      const BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color:
                    active ? SK.primary : const Color(0xFF666666),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _respondTab() => [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF4FF),
            border: Border.all(color: const Color(0xFFBFDBFE)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            '💡 اگر کسی که تو زندگیت هست، این الگو را دارد — روی اسمش بزن تا ببینی چطور رفتار کنی.',
            style: TextStyle(
                fontSize: 12,
                color: Color(0xFF1E40AF),
                height: 1.9),
          ),
        ),
        const SizedBox(height: 14),
        for (final g in responseGuides)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => widget.onPickResponseGuide(g.schemaId),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: const Color(0xFFF0F0F0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F7F4),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        alignment: Alignment.center,
                        child: const Text('💡',
                            style: TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(g.plainName,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text(g.name,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF999999))),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_back,
                          size: 16, color: Color(0xFFCCCCCC)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ];

  List<Widget> _whyTab() => [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            border: Border.all(color: const Color(0xFFFDE68A)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            '🔁 این‌ها ترکیب‌های رایج روابط‌اند. روی هرکدوم بزن تا بفهمی چرا همیشه شبیه هم‌اند.',
            style: TextStyle(
                fontSize: 12, color: Color(0xFF92400E), height: 1.9),
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < attractionPatterns.length; i++)
          _patternCard(attractionPatterns[i], i),
      ];

  Widget _patternCard(AttractionPattern p, int idx) {
    const colors = [
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFFF59E0B),
      Color(0xFF0EA5E9),
      Color(0xFF10B981),
    ];
    final color = colors[idx % colors.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => widget.onPickPattern(p.id),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border(
                right: BorderSide(color: color, width: 4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(p.shortName,
                      style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 10),
                Text(p.boxTitle,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.6)),
                const SizedBox(height: 8),
                Text(p.boxDescription,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                        height: 1.8)),
                const SizedBox(height: 12),
                Text('مشاهده کامل ←',
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
