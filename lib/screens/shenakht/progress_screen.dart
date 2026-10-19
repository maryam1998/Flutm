// lib/screens/shenakht/progress_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/shenakht/schemas.dart';
import '../../data/shenakht/simple_language.dart';
import '../../models/shenakht/progress_entry.dart';
import '../../state/shenakht_store.dart';
import 'shenakht_tab.dart';

class ProgressScreen extends StatelessWidget {
  final String schemaId;
  final VoidCallback onBack;
  final VoidCallback onGoProfile;

  const ProgressScreen({
    super.key,
    required this.schemaId,
    required this.onBack,
    required this.onGoProfile,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ShenakhtStore>();
    final entries = store.entriesForSchema(schemaId);
    final schema = findSchemaById(schemaId);
    final plain = getPlainName(schemaId) ?? schema?.nameFa ?? schemaId;

    final old = entries.where((e) => e.reactionType == 'old').length;
    final paused = entries.where((e) => e.reactionType == 'paused').length;
    final neu = entries.where((e) => e.reactionType == 'new').length;
    final total = entries.length;
    final wins = entries
        .where((e) =>
            e.reactionType == 'paused' ||
            e.reactionType == 'new' ||
            e.missionDone)
        .length;

    return ShenakhtShell(
      title: 'پیشرفت — $plain',
      onBack: onBack,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: SK.grad,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('فعال شدن الگو',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text('${_faNum(total)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('⭐ لحظه‌های برد',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text('${_faNum(wins)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _bar('واکنش قدیمی', old, total, const Color(0xFFEF4444)),
          const SizedBox(height: 10),
          _bar('مکث کردم', paused, total, const Color(0xFFF59E0B)),
          const SizedBox(height: 10),
          _bar('پاسخ جدید', neu, total, const Color(0xFF10B981)),
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('آخرین رکوردها:',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            for (final e in entries.reversed.take(10))
              _entryTile(e),
          ],
          const SizedBox(height: 20),
          Material(
            color: SK.primary,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onGoProfile,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('بازگشت به پروفایل',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _bar(String label, int value, int total, Color color) {
    final pct = total == 0 ? 0.0 : value / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            Text('${_faNum(value)}',
                style: const TextStyle(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: const Color(0xFFEEEEEE),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  Widget _entryTile(ProgressEntry e) {
    final icon = e.reactionType == 'new'
        ? '🟢'
        : e.reactionType == 'paused'
            ? '🟡'
            : e.reactionType == 'old'
                ? '🔴'
                : '⚪';
    final label = e.reactionType == 'new'
        ? 'پاسخ جدید'
        : e.reactionType == 'paused'
            ? 'مکث'
            : e.reactionType == 'old'
                ? 'واکنش قدیمی'
                : 'ثبت';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF0F0F0)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Text(label,
              style: const TextStyle(fontSize: 13))),
          if (e.missionDone)
            const Text('✓ مأموریت',
                style: TextStyle(
                    fontSize: 11, color: Color(0xFF10B981))),
          const SizedBox(width: 8),
          Text(_fmtDate(e.createdAt),
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF999999))),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mn = d.minute.toString().padLeft(2, '0');
    return '$mm/$dd $hh:$mn';
  }
}

String _faNum(int n) => String.fromCharCodes(
    n.toString().codeUnits.map((c) => (c >= 48 && c <= 57) ? c + 1728 : c));
