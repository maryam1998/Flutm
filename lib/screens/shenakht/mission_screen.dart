// lib/screens/shenakht/mission_screen.dart
import 'package:flutter/material.dart';

import '../../data/shenakht/schemas.dart';
import 'shenakht_tab.dart';

class MissionRecord {
  final String id;
  final String text;
  const MissionRecord(this.id, this.text);
}

class MissionScreen extends StatefulWidget {
  final String schemaId;
  final VoidCallback onBack;
  final void Function(MissionRecord?) onDone;

  const MissionScreen({
    super.key,
    required this.schemaId,
    required this.onBack,
    required this.onDone,
  });

  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final schema = findSchemaById(widget.schemaId);
    final missions = schema?.realLifeMissions ?? const [];
    if (missions.isEmpty) {
      return ShenakhtShell(
        title: 'مأموریت امروز',
        onBack: widget.onBack,
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Center(
              child: Text('🎯', style: TextStyle(fontSize: 40)),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'برای این الگو مأموریتی تعریف نشده.\nولی همین که داری کار می‌کنی، خودش یک قدمه.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.9),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Material(
                color: SK.primary,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => widget.onDone(null),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text('ادامه',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final current = missions[_selected];

    return ShenakhtShell(
      title: 'مأموریت امروز',
      onBack: widget.onBack,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: SK.grad,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('یک قدم کوچیک برای امروز',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.5)),
                const SizedBox(height: 12),
                Text(
                  '${_faNum(missions.length)} مأموریت — یکی رو انتخاب کن',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7F4),
              border: Border.all(color: SK.primary, width: 2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              current.last,
              style: const TextStyle(
                  fontSize: 15, height: 1.9, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 16),
          const Text('همه مأموریت‌ها:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          for (var i = 0; i < missions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color:
                    _selected == i ? const Color(0xFFF0F7F4) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => setState(() => _selected = i),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _selected == i
                            ? SK.primary
                            : const Color(0xFFE5E5E5),
                        width: _selected == i ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: SK.primary,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _faNum(i + 1),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(missions[i].last,
                              style: const TextStyle(
                                  fontSize: 13, height: 1.7)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Material(
            color: SK.primary,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => widget.onDone(
                  MissionRecord(current.first, current.last)),
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('این یکی رو انتخاب می‌کنم',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => widget.onDone(null),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('الان نمی‌تونم — رد کن'),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

String _faNum(int n) => String.fromCharCodes(
    n.toString().codeUnits.map((c) => (c >= 48 && c <= 57) ? c + 1728 : c));
