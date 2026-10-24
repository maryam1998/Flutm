import 'package:flutter/material.dart';

import '../map/draw_utils.dart' show toFa;
import '../map/map_ops.dart';
import '../models/jalali.dart';
import '../models/map_models.dart';
import '../state/goal_ops.dart';
import '../state/map_store.dart';
import '../theme/web_palette.dart';

/// آمار قدمِ آخر یک شاخه در دوره‌ی هدف
class FootStats {
  FootStats(this.done, this.missed, this.behind, this.remaining, this.total);
  final int done; // روزهای انجام‌شده (تا امروز)
  final int missed; // روزهای گذشته که انجام نشده
  final int behind; // قدم‌های عقب‌مانده تا امروز
  final int remaining; // روزهای باقی‌مانده تا پایان دوره
  final int total;
}

FootStats footStatsOf(MapHost host, ActionNode node, MapStore store) {
  final pi = periodInfo(host, store);
  var done = 0, missed = 0;
  for (var i = 0; i < pi.dayNum; i++) {
    final d = DateTime(pi.start.year, pi.start.month, pi.start.day + i);
    final jk = jKey(d);
    final isToday = !pi.finished && i == pi.dayNum - 1;
    final ok = isToday ? footDoneToday(node, jk) : footDoneOn(node, jk);
    if (ok) {
      done++;
    } else if (!isToday) {
      missed++;
    }
  }
  final behind = pi.dayNum - done;
  final remaining = pi.finished ? 0 : pi.total - pi.dayNum;
  return FootStats(done, missed, behind, remaining, pi.total);
}

Future<void> showFootStatsSheet(
  BuildContext context, {
  required MapStore store,
  required String hostId,
  required String actionId,
  VoidCallback? onPhotos,
}) {
  final host = store.state.findHost(hostId);
  if (host is! MapHost) return Future.value();
  final f = findActionNode(host.actions, actionId);
  if (f == null) return Future.value();
  final st = footStatsOf(host, f.node, store);
  final title = f.node.text.isEmpty ? 'قدم' : f.node.text;
  final wp = WebPalette.of(context);

  Widget row(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 13.5, color: wp.textDim)),
            ),
            Text(value,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color ?? wp.textMain)),
          ],
        ),
      );

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
        decoration: BoxDecoration(
          color: wp.panelBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: wp.panelBorder),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: wp.textMain)),
              const SizedBox(height: 6),
              row('روزهای انجام‌شده',
                  '${toFa(st.done)} از ${toFa(st.total)}',
                  color: const Color(0xFF1E9E6A)),
              row('روزهای انجام‌نشده', toFa(st.missed),
                  color: st.missed > 0 ? const Color(0xFFD9534F) : null),
              row('قدم‌های عقب‌مانده', toFa(st.behind),
                  color: st.behind > 0 ? const Color(0xFFD9534F) : null),
              row('روزهای باقی‌مانده', toFa(st.remaining)),
              if (onPhotos != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onPhotos();
                    },
                    child: const Text('عکس‌ها'),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
