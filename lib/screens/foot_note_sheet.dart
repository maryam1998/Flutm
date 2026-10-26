import 'package:flutter/material.dart';

import '../map/map_ops.dart';
import '../models/map_models.dart';
import '../services/note_fonts.dart';
import '../state/map_store.dart';
import '../theme/web_palette.dart';

const _kOk = Color(0xFF1E9E6A);
const _kGoldN = Color(0xFFC9962B);

const List<Color> _kNoteColors = [
  Color(0xFF000000),
  Color(0xFFFFFFFF),
  Color(0xFFD9534F),
  Color(0xFFE8408C),
  Color(0xFFF08A24),
  Color(0xFFE6B800),
  Color(0xFF1E9E6A),
  Color(0xFF1FA6A6),
  Color(0xFF2F6FED),
  Color(0xFF7A4BE0),
];

/// کادر ویرایشِ یادداشتِ کنار قدم (با تپ روی یادداشت روی نقشه باز می‌شود):
/// متن، فونت (دانلود با یک تپ)، اندازه، رنگ، برگشت به جای اول، حذف از نقشه.
/// «حذف از نقشه» فقط نمایشِ روی نقشه را خاموش می‌کند؛ متنِ یادداشت در تقویم می‌ماند.
Future<void> showFootNoteSheet(
  BuildContext context, {
  required MapStore store,
  required String hostId,
  required String actionId,
  required String jk,
}) {
  final host0 = store.state.findHost(hostId);
  if (host0 is! MapHost) return Future.value();
  final f0 = findActionNode(host0.actions, actionId);
  if (f0 == null) return Future.value();

  final wp = WebPalette.of(context);
  final node = f0.node;
  final ctl = TextEditingController(text: _noteText(node, jk));
  String? err;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(
        builder: (ctx, setS) {
          final st = footNoteStyle(node, jk);
          final curFont = (st['font'] as String?) ?? 'default';
          final size = ((st['size'] as num?)?.toDouble() ?? 1.0).clamp(0.4, 5.0);
          final colVal = st['color'] is int ? st['color'] as int : 0xFF000000;

          void save() {
            store.changed();
            setS(() {});
          }

          Future<void> pickFont(String id) async {
            if (id == 'default') {
              st.remove('font');
              err = null;
              save();
              return;
            }
            err = null;
            setS(() {});
            final ok = await NoteFonts.ensure(id);
            if (!ctx.mounted) return;
            if (ok) {
              st['font'] = id;
              err = null;
            } else {
              err = 'دانلود فونت انجام نشد؛ اینترنت را بررسی کن و دوباره بزن.';
            }
            save();
          }

          Widget fontTile(String id, String label) {
            final sel = curFont == id;
            final busy = id != 'default' && NoteFonts.isBusy(id);
            final ready = id == 'default' || NoteFonts.loaded.contains(id);
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: busy ? null : () => pickFont(id),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: sel ? _kOk.withValues(alpha: 0.12) : null,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: sel ? _kOk : wp.textDim.withValues(alpha: 0.35),
                      width: sel ? 1.6 : 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        color: wp.textMain,
                        fontFamily: id == 'default'
                            ? null
                            : NoteFonts.familyOf(id),
                        fontFamilyFallback: const ['Vazirmatn'],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (busy)
                      const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Icon(
                          sel
                              ? Icons.check_circle
                              : (ready
                                  ? Icons.check
                                  : Icons.download_rounded),
                          size: 16,
                          color: sel ? _kOk : wp.textDim),
                  ],
                ),
              ),
            );
          }

          return Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.82),
            padding: EdgeInsets.fromLTRB(
                16, 14, 16, 14 + MediaQuery.of(ctx).viewInsets.bottom),
            decoration: BoxDecoration(
              color: wp.panelBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('یادداشت روی نقشه',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: wp.textMain)),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.check_rounded),
                        color: _kOk,
                        tooltip: 'تأیید',
                      ),
                    ],
                  ),
                  TextField(
                    controller: ctl,
                    minLines: 1,
                    maxLines: 3,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'متن یادداشت',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (v) {
                      final m = _notes(node);
                      final t = v.trim();
                      if (t.isEmpty) {
                        m.remove(jk);
                      } else {
                        m[jk] = t;
                      }
                      node.extra['footNotes'] = m;
                      store.changed();
                    },
                  ),
                  const SizedBox(height: 14),
                  Text('فونت',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: wp.textMain)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      fontTile('default', 'وزیرمتن (پیش‌فرض)'),
                      for (final nf in kNoteFonts) fontTile(nf.id, nf.label),
                    ],
                  ),
                  if (err != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(err!,
                          style: const TextStyle(
                              fontSize: 11.5, color: Color(0xFFD9534F))),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text('اندازه',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: wp.textMain)),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(ctx).copyWith(
                              activeTrackColor: _kOk,
                              thumbColor: _kOk,
                              trackHeight: 3),
                          child: Slider(
                            min: 0.4,
                            max: 5.0,
                            value: size.toDouble(),
                            onChanged: (v) {
                              st['size'] = v;
                              save();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text('رنگ',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: wp.textMain)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final c in _kNoteColors)
                        GestureDetector(
                          onTap: () {
                            st['color'] = c.toARGB32();
                            save();
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colVal == c.toARGB32()
                                    ? _kGoldN
                                    : wp.textDim.withValues(alpha: 0.4),
                                width: colVal == c.toARGB32() ? 3 : 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            st.remove('dx');
                            st.remove('dy');
                            save();
                          },
                          icon: const Icon(Icons.undo_rounded, size: 18),
                          label: const Text('برگشت به جای اول',
                              style: TextStyle(fontSize: 12.5)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFD9534F)),
                          onPressed: () {
                            st['hidden'] = true;
                            store.changed();
                            Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.visibility_off_outlined,
                              size: 18),
                          label: const Text('حذف از نقشه',
                              style: TextStyle(fontSize: 12.5)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'با «حذف از نقشه» فقط نمایشش روی نقشه برداشته می‌شود؛ متن یادداشت در تقویم می‌ماند. برای نمایش دوباره، در تقویم همان روز را بزن. برای جابه‌جایی، یادداشت را روی نقشه بکش.',
                    style:
                        TextStyle(fontSize: 11, height: 1.7, color: wp.textDim),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  ).whenComplete(ctl.dispose);
}

Map<String, dynamic> _notes(ActionNode n) {
  final v = n.extra['footNotes'];
  return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
}

String _noteText(ActionNode n, String jk) => (_notes(n)[jk] as String?) ?? '';
