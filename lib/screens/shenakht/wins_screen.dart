// lib/screens/shenakht/wins_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/shenakht/schemas.dart';
import '../../data/shenakht/simple_language.dart';
import '../../models/shenakht/progress_entry.dart';
import '../../state/shenakht_store.dart';
import 'shenakht_tab.dart';

class WinsScreen extends StatelessWidget {
  final VoidCallback onBack;
  const WinsScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ShenakhtStore>();
    final wins = store.wins;

    return ShenakhtShell(
      title: 'لحظه‌های من',
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
                const Text('مجموع لحظه‌های برد',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Text('${_faNum(wins.length)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('این‌ها لحظه‌هایی هستند که تو انتخاب کردی.',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (wins.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                border: Border.all(color: const Color(0xFFFDE68A)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                children: [
                  Text('⭐', style: TextStyle(fontSize: 40)),
                  SizedBox(height: 12),
                  Text(
                    'هنوز لحظه‌ای ثبت نشده.\nهر بار که مکث کنی یا پاسخ جدیدی امتحان کنی، اینجا ذخیره می‌شود.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.9),
                  ),
                ],
              ),
            )
          else
            for (final w in wins) _winTile(w),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _winTile(ProgressEntry w) {
    final schema = findSchemaById(w.schemaId);
    final plain = w.schemaId == null
        ? '—'
        : getPlainName(w.schemaId!) ?? schema?.nameFa ?? '—';

    final type = w.reactionType == 'new'
        ? 'پاسخ جدید را امتحان کردی.'
        : w.reactionType == 'paused'
            ? 'قبل از واکنش، مکث کردی.'
            : w.missionDone
                ? 'مأموریت را انجام دادی.'
                : 'یک قدم کوچک برداشتی.';

    final icon = w.reactionType == 'new'
        ? '🟢'
        : w.reactionType == 'paused'
            ? '🟡'
            : '⭐';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF0F0F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('$plain • ${_fmt(w.createdAt)}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF999999))),
                if (w.notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(w.notes,
                      style: const TextStyle(
                          fontSize: 12, height: 1.7)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mn = d.minute.toString().padLeft(2, '0');
    return '$mm/$dd — $hh:$mn';
  }
}

String _faNum(int n) => String.fromCharCodes(
    n.toString().codeUnits.map((c) => (c >= 48 && c <= 57) ? c + 1728 : c));
