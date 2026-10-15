// lib/screens/shenakht/response_guide_screen.dart
import 'package:flutter/material.dart';

import '../../data/shenakht/relationships_data.dart';
import 'shenakht_tab.dart';

class ResponseGuideScreen extends StatelessWidget {
  final String schemaId;
  final VoidCallback onBack;

  const ResponseGuideScreen({
    super.key,
    required this.schemaId,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final g = getResponseGuide(schemaId);
    if (g == null) {
      return ShenakhtShell(
        title: 'راهنما',
        onBack: onBack,
        child: const Center(child: Text('راهنما پیدا نشد')),
      );
    }

    return ShenakhtShell(
      title: g.plainName,
      onBack: onBack,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // هدر
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: SK.grad,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Text('💡',
                          style: TextStyle(fontSize: 26)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('چطور با این الگو برخورد کنم؟',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 11)),
                          const SizedBox(height: 4),
                          Text(g.plainName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(g.plainDescription,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.9)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // مثال
          _card(
            '📖 در زندگی واقعی چطور دیده می‌شه؟',
            bg: const Color(0xFFEEF4FF),
            border: const Color(0xFFBFDBFE),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: const Border(
                    right: BorderSide(
                        color: Color(0xFF3B82F6), width: 3),
                  ),
                ),
                child: Text(g.example,
                    style: const TextStyle(
                        fontSize: 14, height: 1.95)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // کودکی
          if (g.childhood.isNotEmpty) ...[
            _card(
              '🧸 این الگو از کجا آمد؟',
              bg: const Color(0xFFFAF5FF),
              border: const Color(0xFFE9D5FF),
              children: [
                for (var i = 0; i < g.childhood.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(
                            color: Color(0xFF8B5CF6),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(_faNum(i + 1),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: const Border(
                                right: BorderSide(
                                    color: Color(0xFF8B5CF6),
                                    width: 3),
                              ),
                            ),
                            child: Text(g.childhood[i],
                                style: const TextStyle(
                                    fontSize: 13.5, height: 1.9)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // قاعده طلایی
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: SK.grad,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: const Text('⭐',
                          style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 10),
                    const Text('قاعده طلایی',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(g.goldenRule,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 2,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ✅ این کارها رو بکن
          if (g.doThis.isNotEmpty) ...[
            _card(
              '✅ این کارها را بکن',
              bg: const Color(0xFFECFDF5),
              border: const Color(0xFFA7F3D0),
              children: [
                for (final d in g.doThis)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✓',
                            style: TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w900)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(d,
                              style: const TextStyle(
                                  fontSize: 13.5, height: 1.9)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // ❌ این کارها رو نکن
          if (g.dontDoThis.isNotEmpty) ...[
            _card(
              '❌ این کارها را نکن',
              bg: const Color(0xFFFEF2F2),
              border: const Color(0xFFFECACA),
              children: [
                for (final d in g.dontDoThis)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✕',
                            style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.w900)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(d,
                              style: const TextStyle(
                                  fontSize: 13.5, height: 1.9)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // حالا چه کار کنی
          if (g.whatToDoNow.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [SK.grad1, SK.grad3],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🚀',
                      style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('حالا باید چکار کنی؟',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    Text(
                      '${_faNum(g.whatToDoNow.length)} قدم',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF666666)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < g.whatToDoNow.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFF0F0F0)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border(
                      right: BorderSide(
                          color: i % 2 == 0
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF8B5CF6),
                          width: 4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: i % 2 == 0
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF8B5CF6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(_faNum(i + 1),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(g.whatToDoNow[i],
                            style: const TextStyle(
                                fontSize: 14, height: 1.9)),
                      ),
                    ],
                  ),
                ),
              ),
          ],

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F6F6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'تو نمی‌تونی دیگران رو تغییر بدی —\nولی می‌تونی خودت رو قوی‌تر کنی.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 1.9),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _card(
    String title, {
    required List<Widget> children,
    Color? bg,
    Color? border,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg ?? Colors.white,
        border: Border.all(color: border ?? const Color(0xFFF0F0F0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

String _faNum(int n) => String.fromCharCodes(
    n.toString().codeUnits.map((c) => (c >= 48 && c <= 57) ? c + 1728 : c));
