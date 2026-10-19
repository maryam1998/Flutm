import 'package:flutter/material.dart';

import '../map/draw_utils.dart' show toFa;
import '../map/map_ops.dart';
import '../models/jalali.dart';
import '../models/map_models.dart';
import '../state/goal_ops.dart';
import '../state/map_store.dart';

class _Step {
  _Step(this.jk, this.title, this.secs);
  final String jk, title;
  final double secs;
}

bool _isDone(dynamic v) =>
    v == true || v == 'انجام شد ✓' || (v is String && v.isNotEmpty);

List<int> _parts(String jk) =>
    jk.split('-').map((e) => int.tryParse(e) ?? 0).toList();

String _faDay(String jk) {
  final p = _parts(jk);
  if (p.length != 3 || p[1] < 1 || p[1] > 12) return jk;
  return '${toFa(p[2])} ${kJalaliMonths[p[1] - 1]} ${toFa(p[0])}';
}

int _cmp(String a, String b) {
  final x = _parts(a), y = _parts(b);
  for (var i = 0; i < 3 && i < x.length && i < y.length; i++) {
    if (x[i] != y[i]) return x[i].compareTo(y[i]);
  }
  return 0;
}

/// تپ روی «قدم فعلی»: تعداد قدم‌ها (از ثبت‌های تقویم) و فهرست روزها
Future<void> showStepsSheet(
  BuildContext context, {
  required MapStore store,
  required String hostId,
  required String actionId,
  required bool isWalker,
  required VoidCallback onEditPhotos,
}) {
  final host = store.state.findHost(hostId);
  if (host is! MapHost) return Future.value();

  final nodes = <ActionNode>[];
  if (isWalker) {
    nodes.addAll(collectNodes(host.actions));
  } else {
    final f = findActionNode(host.actions, actionId);
    if (f != null) nodes.add(f.node);
  }

  final steps = <_Step>[];
  for (final n in nodes) {
    n.logs.forEach((jk, v) {
      if (_isDone(v)) steps.add(_Step(jk, n.text, nodeDaySecs(n, jk)));
    });
  }
  steps.sort((a, b) => _cmp(b.jk, a.jk));

  final today = todayJK();
  final todayN = steps.where((s) => s.jk == today).length;
  final days = steps.map((s) => s.jk).toSet().length;
  final name = host is Goal ? host.name : 'نشانه';

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      builder: (_, controller) {
        final cs = Theme.of(ctx).colorScheme;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              const Text('قدم فعلی برای رسیدن به هدف',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(name,
                  style: TextStyle(
                      fontSize: 12.5,
                      color: cs.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  steps.isEmpty
                      ? 'هنوز قدمی ثبت نشده. با ثبت هر روز در تقویم، یک قدم اضافه می‌شه.'
                      : 'تا اینجا ${toFa(steps.length)} قدم اومدم'
                          ' (در ${toFa(days)} روز)'
                          '${todayN > 0 ? '\nامروز ${toFa(todayN)} قدم برداشتم' : ''}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, height: 1.7),
                ),
              ),
              const SizedBox(height: 12),
              for (final s in steps)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          size: 16, color: Color(0xFF3DBE8B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s.title.isEmpty ? 'قدم' : s.title,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      if (s.secs > 0)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 10),
                          child: Text('${toFa((s.secs / 60).round())} دقیقه',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color:
                                      cs.onSurface.withValues(alpha: 0.55))),
                        ),
                      Text(_faDay(s.jk),
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.65))),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onEditPhotos();
                  },
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('عکس قدم‌زن'),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
