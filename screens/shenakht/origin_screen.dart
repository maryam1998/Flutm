// lib/screens/shenakht/origin_screen.dart
import 'package:flutter/material.dart';

import '../../data/shenakht/origins.dart';
import '../../data/shenakht/schemas.dart';
import '../../data/shenakht/simple_language.dart';
import 'shenakht_tab.dart';

class OriginScreen extends StatelessWidget {
  final String schemaId;
  final VoidCallback onBack;
  final VoidCallback onStartWork;

  const OriginScreen({
    super.key,
    required this.schemaId,
    required this.onBack,
    required this.onStartWork,
  });

  @override
  Widget build(BuildContext context) {
    final schema = findSchemaById(schemaId);
    final origin = getOrigin(schemaId);
    final plain = getPlainName(schemaId) ?? schema?.nameFa ?? schemaId;
    final oneLiner = getOneLiner(schemaId);
    final nextSteps = getNextSteps(schemaId);

    if (origin == null) {
      return ShenakhtShell(
        title: 'ریشه',
        onBack: onBack,
        child: const Center(child: Text('اطلاعاتی موجود نیست')),
      );
    }

    return ShenakhtShell(
      title: plain,
      onBack: onBack,
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
                      child: const Text('🧸',
                          style: TextStyle(fontSize: 26)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'الگوی تو',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            plain,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (oneLiner != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      oneLiner,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.9,
                      ),
                    ),
                  ),
                ],
                if (schema != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'نام علمی: ${schema.nameFa}',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF4FF),
              border: Border.all(color: const Color(0xFFBFDBFE)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('💙', style: TextStyle(fontSize: 20)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'این توضیح برای سرزنش کسی نیست. فقط می‌خواهیم ببینیم این الگو از کجا آمده — چون فهمیدن ریشه، اولین قدم شکستنش است.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.9,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (origin.childhood.isNotEmpty) ...[
            const SizedBox(height: 12),
            _sectionCard(
              title: 'در کودکی چه اتفاقی افتاد؟',
              emoji: '🌱',
              note:
                  'این‌ها تجربه‌هایی هستند که ذهنت از آن‌ها این الگو را ساخت:',
              children: [
                for (var i = 0; i < origin.childhood.length; i++)
                  _numberedItem(
                    index: i + 1,
                    text: origin.childhood[i],
                    color: const Color(0xFF10B981),
                    bg: const Color(0xFFF0F7F4),
                  ),
              ],
            ),
          ],
          if (origin.familyPatterns.isNotEmpty) ...[
            const SizedBox(height: 12),
            _sectionCard(
              title: 'الگوی خانوادگی',
              emoji: '👨‍👩‍👧',
              note: 'الگوهایی که نسل به نسل منتقل شده:',
              bgColor: const Color(0xFFFAF5FF),
              borderColor: const Color(0xFFE9D5FF),
              children: [
                for (final p in origin.familyPatterns)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: const Border(
                        right: BorderSide(
                            color: Color(0xFF8E44AD), width: 3),
                      ),
                    ),
                    child: Text(
                      p,
                      style:
                          const TextStyle(fontSize: 13.5, height: 1.9),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFF8E1), Color(0xFFFEF3C7)],
              ),
              border:
                  Border.all(color: const Color(0xFFF59E0B), width: 2),
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
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: const Text('💡',
                          style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'کودکی که بودی، این را یاد گرفت',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    origin.whatChildLearned,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 2,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (origin.innerVoice.isNotEmpty) ...[
            const SizedBox(height: 12),
            _sectionCard(
              title: 'این صداها برایت آشناست؟',
              emoji: '🔊',
              note: 'صدای منتقد درونی که در سرت تکرار می‌شود:',
              children: [
                for (final v in origin.innerVoice)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '«$v»',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.9,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (origin.whatWasMissing.isNotEmpty) ...[
            const SizedBox(height: 12),
            _sectionCard(
              title: 'کودکی که بودی، این‌ها را لازم داشت',
              emoji: '🕊️',
              note: 'چیزهایی که اگر بود، این الگو شکل نمی‌گرفت:',
              bgColor: const Color(0xFFECFDF5),
              borderColor: const Color(0xFFA7F3D0),
              children: [
                for (final w in origin.whatWasMissing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '✓',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            w,
                            style: const TextStyle(
                                fontSize: 13.5, height: 1.9),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: SK.grad,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const Text('💙', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 12),
                Text(
                  origin.gentleReminder,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 2,
                  ),
                ),
              ],
            ),
          ),
          if (nextSteps.isNotEmpty) ...[
            const SizedBox(height: 20),
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
                    const Text(
                      'حالا باید چکار کنی؟',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${_faNum(nextSteps.length)} قدم — یکی‌یکی، نه یک‌جا',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF666666)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < nextSteps.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF0F0F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: SK.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _faNum(i + 1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        nextSteps[i],
                        style:
                            const TextStyle(fontSize: 14, height: 1.9),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 20),
          Material(
            color: SK.primary,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onStartWork,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    '▶ شروع کار روی این الگو',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String emoji,
    required String note,
    required List<Widget> children,
    Color? bgColor,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white,
        border: Border.all(
          color: borderColor ?? const Color(0xFFF0F0F0),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              note,
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Color(0xFF666666),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _numberedItem({
    required int index,
    required String text,
    required Color color,
    required Color bg,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border(right: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _faNum(index),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13.5, height: 1.9),
            ),
          ),
        ],
      ),
    );
  }
}

String _faNum(int n) => String.fromCharCodes(
    n.toString().codeUnits.map((c) => (c >= 48 && c <= 57) ? c + 1728 : c));
