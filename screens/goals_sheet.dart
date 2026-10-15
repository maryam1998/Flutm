import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../map/draw_utils.dart' show toFa;
import '../map/map_ops.dart';
import '../models/constants.dart';
import '../models/jalali.dart';
import '../models/map_models.dart';
import '../state/goal_ops.dart';
import '../state/map_store.dart';
import 'day_sheet.dart';
import 'edit_sheet.dart';
import '../theme/app_theme.dart';
import 'time_sheet.dart';
import 'weekly_sheet.dart';
import '../services/media_db.dart';

const _kGold = Color(0xFFC9972B);
const _kInk = Color(0xFF2A2218);
const _kMuted = Color(0xFF7A6B57);
const _kBorder = Color(0xFFE0D5C0);

/// فهرست اهداف — معادل «اهداف من» نسخه‌ی وب
Future<void> showGoalsSheet(
  BuildContext context, {
  required void Function(MapHost host) onShowOnMap,
  required VoidCallback onAddGoal,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: kGoalsBg,
    builder: (ctx) => goalsLightSheet(DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => GoalsSheet(
        controller: controller,
        parentContext: context,
        onShowOnMap: onShowOnMap,
        onAddGoal: onAddGoal,
      ),
    )),
  );
}

String _norm(String t) =>
    t.toLowerCase().replaceAll('ي', 'ی').replaceAll('ك', 'ک');

String? _findInActions(List<ActionNode> list, String q) {
  for (final a in list) {
    if (_norm(a.text).contains(q)) return a.text;
    final r = _findInActions(a.children, q);
    if (r != null) return r;
  }
  return null;
}

String _ago(int ts) {
  if (ts <= 0) return '';
  final d = DateTime.now()
      .difference(DateTime.fromMillisecondsSinceEpoch(ts))
      .inDays;
  if (d <= 0) return 'امروز';
  if (d == 1) return 'دیروز';
  return '${toFa(d)} روز پیش';
}

int? _parseDays(String s) {
  const fa = '۰۱۲۳۴۵۶۷۸۹', ar = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    var i = fa.indexOf(ch);
    if (i < 0) i = ar.indexOf(ch);
    b.write(i >= 0 ? '$i' : ch);
  }
  final n = int.tryParse(b.toString().trim());
  if (n == null || n < 1 || n > kPcMaxDays) return null;
  return n;
}

// ---------- کش تصاویر data: URI ----------
final _imgCache = <int, Uint8List>{};
Uint8List? _decodeSrc(String src) {
  if (MediaDb.isRef(src)) return MediaDb.bytes(src);
  if (!src.startsWith('data:')) return null;
  final k = Object.hash(src.length, src.hashCode);
  final hit = _imgCache[k];
  if (hit != null) return hit;
  try {
    final b = base64Decode(src.substring(src.indexOf(',') + 1));
    if (_imgCache.length > 60) _imgCache.clear();
    return _imgCache[k] = b;
  } catch (_) {
    return null;
  }
}

// ---------- آواتار هدف/حلقه ----------
class _Avatar extends StatelessWidget {
  const _Avatar({required this.host, required this.color, this.size = 40});
  final MapHost host;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final images =
        host is Goal ? (host as Goal).images : (host as Ring).images;
    final icon =
        host is Goal ? (host as Goal).icon : (host as Ring).icon;
    final bytes = images.isNotEmpty ? _decodeSrc(images.first.src) : null;
    if (bytes != null) {
      return ClipOval(
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: 120,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _fallback(icon),
        ),
      );
    }
    return _fallback(icon);
  }

  Widget _fallback(String icon) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withAlpha(60),
          border: Border.all(color: color.withAlpha(150)),
        ),
        child: Text(
          icon.trim().isEmpty ? '•' : icon,
          style: TextStyle(fontSize: size * 0.5),
        ),
      );
}

class _Row {
  _Row(this.h, this.hit);
  final MapHost h;
  final String hit;
}

class _Trophy {
  _Trophy(this.node, this.parentText);
  final ActionNode node;
  final String parentText;
}

class GoalsSheet extends StatefulWidget {
  const GoalsSheet({
    super.key,
    required this.controller,
    required this.parentContext,
    required this.onShowOnMap,
    required this.onAddGoal,
  });
  final ScrollController controller;
  final BuildContext parentContext;
  final void Function(MapHost host) onShowOnMap;
  final VoidCallback onAddGoal;

  @override
  State<GoalsSheet> createState() => _GoalsSheetState();
}

class _GoalsSheetState extends State<GoalsSheet> {
  int _tab = 0; // 0=در جریان, 1=محقق‌شده
  String _q = '';
  final _search = TextEditingController();
  final _addCtl = TextEditingController();
  final _open = <String>{};
  final _daysOpen = <String>{};
  final _statsOpen = <String>{};
  String? _addingFor;
  List<String> _currentVisibleOrder = [];

  @override
  void dispose() {
    _search.dispose();
    _addCtl.dispose();
    super.dispose();
  }

  String _name(MapHost h) {
    if (h is Goal) return h.name;
    final l = (h as Ring).label;
    return l.isEmpty ? 'نزدیک شدن به هدف' : l;
  }

  Color _hostColor(MapHost h) =>
      hexColor(h.color, hexColor(h.isRing ? kRingColor : kPalette[0]));

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MapStore>();
    final s = store.state;
    final active = s.goals.where((g) => !g.reached).toList();
    final reached = s.goals.where((g) => g.reached).toList();
    final isReachedTab = _tab == 1;

    final List<MapHost> pool = isReachedTab
        ? reached
        : <MapHost>[
            ...active,
            if (s.goals.isEmpty) ...s.rings.where((r) => ringIsOrphan(s, r)),
          ];

    // فیلتر
    final rows = <_Row>[];
    for (final h in pool) {
      if (_q.isEmpty) {
        rows.add(_Row(h, ''));
      } else {
        final hit =
            _norm(_name(h)).contains(_q) ? '' : _findInActions(h.actions, _q);
        if (hit != null) rows.add(_Row(h, hit));
      }
    }

    // مرتب‌سازی بر اساس goalOrder (اگه ذخیره شده باشه)، وگرنه lastActivity نزولی
    final savedOrder =
        (s.extra['goalOrder'] as List?)?.whereType<String>().toList() ??
            const <String>[];
    final orderMap = <String, int>{
      for (var i = 0; i < savedOrder.length; i++) savedOrder[i]: i,
    };
    rows.sort((a, b) {
      final pa = orderMap[a.h.id];
      final pb = orderMap[b.h.id];
      if (pa != null && pb != null) return pa.compareTo(pb);
      if (pa != null) return -1;
      if (pb != null) return 1;
      return b.h.lastActivity.compareTo(a.h.lastActivity);
    });

    // ترتیب نمایش‌داده‌شده (بعد از مرتب‌سازی) برای onReorder
    _currentVisibleOrder = rows.map((r) => r.h.id).toList();

    final freeRings =
        s.goals.isEmpty ? 0 : s.rings.where((r) => ringIsOrphan(s, r)).length;
    final countText = pool.isEmpty ? '' : '${toFa(pool.length)} مورد';

    return ListView(
      controller: widget.controller,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
      children: [
        // هدر
        Row(
          children: [
            const Text('اهداف من',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kGoalsInk)),
            const SizedBox(width: 8),
            Text(countText,
                style: const TextStyle(fontSize: 12, color: kGoalsMuted)),
            IconButton(
              icon: const Icon(Icons.insights, size: 20, color: kGoalsGold),
              tooltip: 'نگاه هفته',
              onPressed: () => showWeeklySheet(context, store.state),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              visualDensity: VisualDensity.compact,
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.pop(context);
                widget.onAddGoal();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('هدف جدید'),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // تب‌ها
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text('اهداف در جریان',
                  style: TextStyle(color: _tab == 0 ? Colors.white : kGoalsInk)),
              selected: _tab == 0,
              onSelected: (_) => setState(() => _tab = 0),
            ),
            ChoiceChip(
              label: Text(
                'اهداف محقق‌شده${reached.isEmpty ? '' : ' (${toFa(reached.length)})'}',
                style: TextStyle(color: _tab == 1 ? Colors.white : kGoalsInk),
              ),
              selected: _tab == 1,
              onSelected: (_) => setState(() => _tab = 1),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // جست‌وجو
        TextField(
          controller: _search,
          onChanged: (v) => setState(() => _q = _norm(v.trim())),
          decoration: InputDecoration(
            hintText: 'جست‌وجو در نام هدف و متن شاخه‌ها...',
            prefixIcon: const Icon(Icons.search, color: kGoalsMuted),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kGoalsBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kGoalsBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kGoalsGold, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // لیست
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
            child: Text(
              _q.isNotEmpty
                  ? 'موردی پیدا نشد.'
                  : isReachedTab
                      ? 'هنوز هدفی محقق نشده.\nوقتی به هدفی رسیدی، با دکمه‌ی ✓ به این فهرست منتقلش کن.'
                      : 'هنوز هدفی نداری.\nبا «هدف جدید» شروع کن.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: kGoalsMuted, height: 1.8),
            ),
          )
        else if (isReachedTab)
          for (final r in rows) _reachedCard(store, r.h as Goal)
        else if (_q.isEmpty && rows.length > 1 && rows.every((r) => r.h is Goal))
          // حالت قابل‌کشیدن (فقط اهداف، نه حلقه‌ها؛ در حالت جستجو غیرفعال)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: rows.length,
            onReorder: _onReorderGoals,
            itemBuilder: (ctx, i) => KeyedSubtree(
              key: ValueKey(rows[i].h.id),
              child: _hostCard(store, rows[i], reorderIndex: i),
            ),
          )
        else
          for (final r in rows) _hostCard(store, r),

        if (freeRings > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${toFa(freeRings)} نشانه‌ی آزاد روی نقشه هست؛ روی مسیر یک هدف ببرش تا خودکار زیرمجموعه‌اش شود.',
              style: const TextStyle(fontSize: 11.5, color: kGoalsMuted, height: 1.7),
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------------ کارت هدف

  BoxDecoration _cardDeco(Color c) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGoalsBorder),
      );

  Widget _iconBtn(IconData i, String tip, VoidCallback onTap, {Color? color}) =>
      IconButton(
        icon: Icon(i, size: 20, color: color),
        tooltip: tip,
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        visualDensity: VisualDensity.compact,
      );

  Widget _tag(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(
          color: kGoalsGold.withAlpha(34),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(t,
            style: const TextStyle(fontSize: 10.5, color: kGoalsMuted)),
      );

  Widget _hostCard(MapStore store, _Row r, {int? reorderIndex}) {
    final h = r.h;
    final color = _hostColor(h);
    final isOpen =
        _open.contains(h.id) || (_q.isNotEmpty && r.hit.isNotEmpty);
    final power = math.min(100.0, sumWeight(h.actions) * 3);
    final stale = h.lastActivity > 0 &&
        DateTime.now().millisecondsSinceEpoch - h.lastActivity >
            30 * 86400000;
    final linked =
        h is Ring ? store.state.goals.where((g) => g.id == h.goalId).toList() : <Goal>[];
    final ago = _ago(h.lastActivity);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _cardDeco(color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() {
              if (!_open.remove(h.id)) _open.add(h.id);
              _addingFor = null;
            }),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  if (reorderIndex != null)
                    ReorderableDragStartListener(
                      index: reorderIndex,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(Icons.drag_indicator,
                            size: 20, color: kGoalsMuted),
                      ),
                    ),
                  _Avatar(host: h, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            Text(_name(h),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, color: kGoalsInk)),
                            if (h.isRing)
                              _tag(
                                  'نزدیک شدن به هدف${linked.isEmpty ? '' : ' · «${linked.first.name.isEmpty ? 'هدف' : linked.first.name}»'}'),
                            if (stale) _tag('کم‌فعالیت'),
                          ],
                        ),
                        if (ago.isNotEmpty)
                          Text(ago,
                              style: const TextStyle(
                                  fontSize: 11, color: kGoalsMuted)),
                        if (r.hit.isNotEmpty)
                          Text('↳ ${r.hit}',
                              style: TextStyle(fontSize: 12, color: color),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: power / 100,
                            minHeight: 5,
                            color: color,
                            backgroundColor: kGoalsBorder,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _iconBtn(
                    isOpen ? Icons.expand_less : Icons.expand_more,
                    'باز یا بسته کردن',
                    () => setState(() {
                      if (!_open.remove(h.id)) _open.add(h.id);
                      _addingFor = null;
                    }),
                  ),
                  if (h is Goal)
                    _iconBtn(Icons.check_circle_outline, 'به این هدف رسیدم',
                        () => _reach(store, h)),
                  _iconBtn(Icons.my_location, 'نمایش روی نقشه', () {
                    Navigator.pop(context);
                    widget.onShowOnMap(h);
                  }),
                  _iconBtn(Icons.edit_outlined, 'ویرایش', () {
                    Navigator.pop(context);
                    showEditSheet(
                      widget.parentContext,
                      h is Goal ? GoalTarget(h.id) : RingTarget(h.id),
                    );
                  }),
                ],
              ),
            ),
          ),
          if (isOpen) _body(store, h, color),
        ],
      ),
    );
  }

  void _reach(MapStore store, Goal g) {
    _open.remove(g.id);
    store.reachGoal(g);
    ScaffoldMessenger.of(widget.parentContext)
        .showSnackBar(const SnackBar(content: Text('🏆 هدف محقق شد!')));
  }

  // ------------------------------------------------------------------ کارت محقق‌شده

  Widget _reachedCard(MapStore store, Goal g) {
    final color = _hostColor(g);
    var when = '';
    final ra = g.extra['reachedAt'];
    if (ra is num) {
      final d = DateTime.fromMillisecondsSinceEpoch(ra.toInt());
      final j = toJalaali(d.year, d.month, d.day);
      when = 'محقق‌شده در ${toFa(j.jy)}/${toFa(j.jm)}/${toFa(j.jd)}';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: _cardDeco(color),
      child: Row(
        children: [
          _Avatar(host: g, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(g.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: kGoalsInk)),
                  _tag('محقق شد ✓'),
                ]),
                if (when.isNotEmpty)
                  Text(when,
                      style:
                          const TextStyle(fontSize: 11, color: kGoalsMuted)),
                if (g.feeling.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💗 ',
                            style: TextStyle(fontSize: 11)),
                        Expanded(
                          child: Text(
                            g.feeling,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                color: kGoalsMuted,
                                fontStyle: FontStyle.italic,
                                height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _editFeeling(store, g),
                      icon: const Text('💗', style: TextStyle(fontSize: 12)),
                      label: const Text('حس خودت را بنویس',
                          style: TextStyle(fontSize: 11.5)),
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => store.unreachGoal(g),
            child: const Text('بازگرداندن'),
          ),
          _iconBtn(Icons.my_location, 'نمایش روی نقشه', () {
            Navigator.pop(context);
            widget.onShowOnMap(g);
          }),
          _iconBtn(Icons.edit_outlined, 'ویرایش', () {
            Navigator.pop(context);
            showEditSheet(widget.parentContext, GoalTarget(g.id));
          }),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ بدنه‌ی هدف باز‌شده

  Widget _body(MapStore store, MapHost h, Color hostColor) {
    final pi = periodInfo(h, store);
    final todayCnt = todayCount(h, pi.todayJK);
    final statsOpen = _statsOpen.contains(h.id);
    final adding = _addingFor == h.id;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),

          // بنر پایان دوره
          if (pi.finished)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kGoalsGold.withAlpha(34),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kGoalsGold.withAlpha(110)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'دوره‌ی ${periodOrd(pi.past.length)} تموم شد! برای ادامه، دوره‌ی بعدی را شروع کن.',
                    style: const TextStyle(height: 1.7, color: kGoalsInk),
                  ),
                  const SizedBox(height: 6),
                  FilledButton.tonal(
                    onPressed: () async {
                      final n = await _askDays(
                        'دوره‌ی ${periodOrd(pi.past.length + 1)} چند روزه باشه؟ (۱ تا ${toFa(kPcMaxDays)})',
                        pi.total,
                      );
                      if (n != null) store.startNewPeriod(h, n);
                    },
                    child: Text('شروع دوره‌ی ${periodOrd(pi.past.length + 1)}'),
                  ),
                ],
              ),
            ),

          // شاخه‌ها
          if (h.actions.isEmpty && !adding)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Text('با ＋ شروع کن؛ مثلاً «گوش دادن به پادکست».',
                  style: TextStyle(color: kGoalsMuted)),
            ),
          for (final a in h.actions)
            ..._nodeTiles(store, h, a, pi, hostColor, 0, ''),
          ..._trophiesSection(store, h, hostColor),

          const SizedBox(height: 6),

          // دکمه افزودن شاخه
          if (adding)
            _addRow(store, h, null, 'نام (مثلاً گوش دادن به پادکست)')
          else
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                onPressed: () => setState(() {
                  _addingFor = h.id;
                  _addCtl.clear();
                }),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('شاخه'),
              ),
            ),
          const SizedBox(height: 8),

          // نوار آمار
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() {
              if (!_statsOpen.remove(h.id)) _statsOpen.add(h.id);
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: kGoalsBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kGoalsBorder),
              ),
              child: Row(
                children: [
                  Text(
                    'دوره‌ی ${toFa(pi.total)} روزه · روز ${toFa(pi.dayNum)}',
                    style: const TextStyle(fontSize: 13, color: kGoalsInk),
                  ),
                  const Spacer(),
                  Icon(statsOpen ? Icons.expand_less : Icons.expand_more,
                      size: 20),
                ],
              ),
            ),
          ),

          if (statsOpen)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${toFa(todayCnt)} کار انجام‌شده‌ی امروز',
                      style: const TextStyle(color: kGoalsMuted),
                    ),
                  ),
                  if (!pi.finished)
                    TextButton(
                      onPressed: () async {
                        final n = await _askDays(
                          'دوره‌ی ${periodOrd(pi.past.length)} چند روزه باشه؟',
                          pi.total,
                        );
                        if (n != null) store.setPeriodDays(h, n);
                      },
                      child: const Text('تنظیم روزهای دوره'),
                    ),
                ],
              ),
            ),
          if (statsOpen)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⏱ مجموع امروز: ${fmtDur(_sumDay(h, pi.todayJK))}',
                    style: const TextStyle(
                        fontSize: 12.5, color: kGoalsMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '📊 مجموع دوره: ${fmtDur(_sumPeriod(h, pi))}',
                    style: const TextStyle(
                        fontSize: 12.5, color: kGoalsMuted),
                  ),
                ],
              ),
            ),

          // جمع کردن
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _open.remove(h.id);
                _addingFor = null;
              }),
              icon: const Icon(Icons.expand_less, size: 18),
              label: const Text('جمع کردن'),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ درخت شاخه‌ها

  List<Widget> _nodeTiles(
    MapStore store,
    MapHost h,
    ActionNode n,
    PeriodInfo pi,
    Color hostColor,
    int depth,
    String parentName, {
    int? reorderIndex,
  }) {
    // شاخه‌ی دستاوردشده پنهان است؛ زیرشاخه‌هاش در همان سطح نشان داده می‌شن
    if (n.extra['achieved'] == true) {
      return [
        for (final c in n.children)
          ..._nodeTiles(store, h, c, pi, hostColor, depth, parentName),
      ];
    }
    final color = hexColor(n.color, hostColor);
    final todayDone = truthy(n.logs[pi.todayJK]);
    final daysOpen = _daysOpen.contains(n.id);
    final isSub = depth > 0;

    final tileBody = Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: isSub ? const Color(0xFFFFFCF4) : kGoalsBg,
        border: BorderDirectional(start: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  color: isSub ? Colors.transparent : color,
                  border: isSub ? Border.all(color: color) : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isSub ? 'زیرشاخه' : 'شاخه',
                  style: TextStyle(
                    fontSize: 10,
                    color: isSub ? color : Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isSub)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 6),
                    child: Text(
                      'زیرِ «${parentName.isEmpty ? 'شاخه' : parentName}»',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10.5, color: kGoalsMuted),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (reorderIndex != null)
                ReorderableDragStartListener(
                  index: reorderIndex,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(Icons.drag_indicator,
                        size: 18, color: kGoalsMuted),
                  ),
                ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => store.toggleLog(h, n, pi.todayJK),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: todayDone ? color : Colors.transparent,
                      border: Border.all(color: color, width: 2),
                    ),
                    child: todayDone
                        ? const Icon(Icons.check, size: 19, color: Colors.black87)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextFormField(
                  key: ValueKey('t-${n.id}'),
                  initialValue: n.text,
                  onChanged: (v) => store.renameAction(n, v),
                  style: const TextStyle(fontSize: 14, color: kGoalsInk),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: isSub ? 'نام زیرشاخه...' : 'نام شاخه...',
                    hintStyle: const TextStyle(color: kGoalsMuted),
                  ),
                ),
              ),
              _iconBtn(Icons.add, 'افزودن زیرشاخه', () => setState(() {
                    _addingFor = n.id;
                    _addCtl.clear();
                  })),
              _iconBtn(
                Icons.calendar_month_outlined,
                'روزها',
                () => setState(() {
                  if (!_daysOpen.remove(n.id)) _daysOpen.add(n.id);
                }),
                color: daysOpen ? color : null,
              ),
              _iconBtn(
                timerRunning(n) ? Icons.timer : Icons.timer_outlined,
                'زمان',
                () => showTimeSheet(
                  context,
                  store: store,
                  host: h,
                  node: n,
                  jk: pi.todayJK,
                  dayLabel: 'امروز',
                ),
                color: nodeDaySecs(n, pi.todayJK) > 0 ? color : null,
              ),
              _iconBtn(
                n.extra['achieved'] == true
                    ? Icons.emoji_events
                    : Icons.emoji_events_outlined,
                'دستاورد',
                () => _toggleAchieved(store, h, n),
                color: n.extra['achieved'] == true
                    ? const Color(0xFFF4C542)
                    : null,
              ),
              _iconBtn(Icons.close, 'حذف', () => _confirmDelete(store, h, n)),
            ],
          ),
          if (nodeDaySecs(n, pi.todayJK) > 0 || timerRunning(n))
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 4),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 13, color: kGoalsMuted),
                  const SizedBox(width: 4),
                  Text(
                    'امروز: ${fmtDur(nodeDaySecs(n, pi.todayJK))}',
                    style: const TextStyle(fontSize: 11, color: kGoalsMuted),
                  ),
                  if (timerRunning(n)) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.fiber_manual_record,
                        size: 10, color: Color(0xFFE5484D)),
                    const SizedBox(width: 4),
                    const Text('در حال ضبط',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFFE5484D))),
                  ],
                ],
              ),
            ),
          if (n.isRoutine)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 4),
              child: Row(
                children: [
                  const Icon(Icons.repeat,
                      size: 13, color: Color(0xFF1B8DB5)),
                  const SizedBox(width: 4),
                  Text(
                    '${toFa(routineWeekDone(n))} از ۷ روز این هفته',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF1B8DB5)),
                  ),
                  if (routineStreak(n) >= 2) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.local_fire_department,
                        size: 12, color: kGoalsGold),
                    const SizedBox(width: 3),
                    Text(
                      '${toFa(routineStreak(n))} روز پیاپی',
                      style: const TextStyle(
                          fontSize: 11,
                          color: kGoalsGold,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          if (daysOpen) _daysGrid(store, h, n, pi, color),
        ],
      ),
    );

    final tile = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: tileBody,
      ),
    );

    final kids = <Widget>[
      if (_addingFor == n.id)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _addRow(store, h, n, 'نام زیرشاخه'),
        ),
      ..._childrenList(store, h, n, pi, hostColor, depth),
    ];

    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tile,
          if (kids.isNotEmpty)
            Container(
              margin: const EdgeInsetsDirectional.only(start: 16),
              padding: const EdgeInsetsDirectional.only(start: 10),
              decoration: BoxDecoration(
                border: BorderDirectional(
                    start:
                        const BorderSide(color: kGoalsBorder, width: 2)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: kids),
            ),
        ],
      ),
    ];
  }

  // ------------------------------------------------------------------ شبکه‌ی روزها

  Widget _daysGrid(
    MapStore store,
    MapHost h,
    ActionNode n,
    PeriodInfo pi,
    Color color,
  ) {
    const cols = 15;
    final cells = <Widget>[];
    for (var d = 0; d < pi.total; d++) {
      final date = DateTime(pi.start.year, pi.start.month, pi.start.day + d);
      final jk = jKey(date);
      final j = toJalaali(date.year, date.month, date.day);
      final has = truthy(n.logs[jk]);
      final hasTime = nodeDaySecs(n, jk) > 0;
      final future = date.isAfter(pi.today);
      final isToday = date.isAtSameMomentAs(pi.today);
      cells.add(
        InkWell(
          onTap: future
              ? null
              : () => showDaySheet(
                    context,
                    store: store,
                    host: h,
                    node: n,
                    date: date,
                    accent: color,
                  ),
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 25,
                height: 25,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: has ? color : const Color(0xFFF5EFE0),
                  border: isToday
                      ? Border.all(color: _kGold, width: 2)
                      : Border.all(color: _kBorder, width: 1),
                ),
                child: Text(
                  has ? '✓' : toFa(j.jd),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: has
                        ? Colors.white
                        : (future
                            ? _kMuted.withValues(alpha: 0.5)
                            : _kInk),
                  ),
                ),
              ),
              // نقطه‌ی زمان ثبت‌شده (گوشه‌ی پایین)
              if (hasTime)
                Positioned(
                  bottom: 1,
                  right: 1,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: has ? Colors.white : color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: has ? color : Colors.transparent,
                        width: 0.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: LayoutBuilder(builder: (ctx, box) {
        final cellW = (box.maxWidth - (cols - 1) * 3) / cols;
        final size = cellW.clamp(18.0, 25.0);
        return Wrap(
          spacing: 3,
          runSpacing: 3,
          children: [
            for (final c in cells)
              SizedBox(width: size, height: size, child: c),
          ],
        );
      }),
    );
  }

  // ------------------------------------------------------------------ افزودن شاخه

  Widget _addRow(MapStore store, MapHost h, ActionNode? parent, String hint) {
    void submit() {
      final name = _addCtl.text.trim();
      if (name.isNotEmpty) store.addNamed(h, name, parent: parent);
      _addCtl.clear();
      setState(() => _addingFor = null);
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _addCtl,
            autofocus: true,
            onSubmitted: (_) => submit(),
            decoration: InputDecoration(
              hintText: '$hint...',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kGoalsBorder),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        FilledButton(onPressed: submit, child: const Text('افزودن')),
        TextButton(
          onPressed: () => setState(() => _addingFor = null),
          child: const Text('لغو'),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
      MapStore store, MapHost h, ActionNode n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف'),
        content: Text(
          '«${n.text.isEmpty ? 'بدون نام' : n.text}» ${n.children.isNotEmpty ? 'همراه با زیرمجموعه‌اش ' : ''}حذف بشه؟',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('نه')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) store.removeActionNode(h, n);
  }

  void _onReorderGoals(int oldIdx, int newIdx) {
    if (newIdx > oldIdx) newIdx--;
    final moved = _currentVisibleOrder.removeAt(oldIdx);
    _currentVisibleOrder.insert(newIdx, moved);

    final store = context.read<MapStore>();
    store.state.extra['goalOrder'] = List<String>.from(_currentVisibleOrder);
    store.changed();
    setState(() {});
  }

  List<Widget> _childrenList(
    MapStore store,
    MapHost h,
    ActionNode n,
    PeriodInfo pi,
    Color hostColor,
    int depth,
  ) {
    final kids = n.children;
    if (kids.isEmpty) return const [];

    if (kids.length == 1) {
      return _nodeTiles(
        store, h, kids[0], pi, hostColor, depth + 1,
        n.text.isEmpty ? 'بدون نام' : n.text,
      );
    }

    return [
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: kids.length,
        onReorder: (oldIdx, newIdx) {
          setState(() {
            if (newIdx > oldIdx) newIdx--;
            final item = kids.removeAt(oldIdx);
            kids.insert(newIdx, item);
            store.changed();
          });
        },
        itemBuilder: (ctx, i) => KeyedSubtree(
          key: ValueKey(kids[i].id),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _nodeTiles(
              store, h, kids[i], pi, hostColor, depth + 1,
              n.text.isEmpty ? 'بدون نام' : n.text,
              reorderIndex: i,
            ),
          ),
        ),
      ),
    ];
  }

  void _toggleAchieved(MapStore store, MapHost h, ActionNode n) {
    if (n.extra['achieved'] == true) {
      n.extra.remove('achieved');
      n.extra.remove('achievedAt');
    } else {
      n.extra['achieved'] = true;
      n.extra['achievedAt'] = DateTime.now().millisecondsSinceEpoch;
      // شاخه‌ی دستاوردشده از درخت پنهان می‌شه، پس اگه در حال افزودن زیرشاخه بودیم، لغو کن
      _addingFor = null;
    }
    store.changed();
  }

  // ---------- دستاوردها ----------

  List<_Trophy> _collectAchieved(List<ActionNode> list, [String parent = '']) {
    final out = <_Trophy>[];
    for (final n in list) {
      if (n.extra['achieved'] == true) out.add(_Trophy(n, parent));
      out.addAll(_collectAchieved(n.children, n.text));
    }
    return out;
  }

  List<Widget> _trophiesSection(MapStore store, MapHost h, Color hostColor) {
    final trophies = _collectAchieved(h.actions);
    if (trophies.isEmpty) return const [];

    return [
      const Divider(height: 24),
      Row(
        children: [
          const Icon(Icons.emoji_events,
              size: 18, color: Color(0xFFF4C542)),
          const SizedBox(width: 6),
          Text(
            'دستاوردها (${toFa(trophies.length)})',
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: kGoalsInk),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final t in trophies) _trophyChip(store, t),
        ],
      ),
    ];
  }

  Widget _trophyChip(MapStore store, _Trophy t) {
    var when = '';
    final at = t.node.extra['achievedAt'];
    if (at is num) {
      final d = DateTime.fromMillisecondsSinceEpoch(at.toInt());
      final j = toJalaali(d.year, d.month, d.day);
      when = ' · ${toFa(j.jy)}/${toFa(j.jm)}/${toFa(j.jd)}';
    }
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showTrophyDetail(store, t),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
        decoration: BoxDecoration(
          color: kGoalsGold.withAlpha(34),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kGoalsGold.withAlpha(130)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 5),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.node.text.isEmpty ? 'بدون نام' : t.node.text,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: kGoalsInk),
                ),
                if (when.isNotEmpty)
                  Text(
                    when.replaceFirst(' · ', ''),
                    style: const TextStyle(
                        fontSize: 10, color: kGoalsMuted),
                  ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.info_outline, size: 14, color: kGoalsMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _showTrophyDetail(MapStore store, _Trophy t) async {
    final n = t.node;
    final color = hexColor(n.color, const Color(0xFFF4C542));
    final days = n.logs.entries
        .where((e) => truthy(e.value))
        .map((e) => e.key)
        .toList()
      ..sort();
    final dayCount = days.length;
    final childCount = countActions(n.children);
    final totalSeconds = nodePeriodSecs(n, days.toSet());
    var when = '';
    final at = n.extra['achievedAt'];
    if (at is num) {
      final d = DateTime.fromMillisecondsSinceEpoch(at.toInt());
      final j = toJalaali(d.year, d.month, d.day);
      when = '${toFa(j.jy)}/${toFa(j.jm)}/${toFa(j.jd)}';
    }

    final undo = await showDialog<bool>(
      context: context,
      builder: (ctx) => goalsLightSheet(AlertDialog(
        backgroundColor: kGoalsBg,
        title: Row(
          children: [
            const Text('🏆', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                n.text.isEmpty ? 'بدون نام' : n.text,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (t.parentText.isNotEmpty)
              _detailRow('زیرِ', t.parentText),
            if (when.isNotEmpty) _detailRow('رسیدی در', when),
            _detailRow('روزهای انجام‌شده', toFa(dayCount)),
            if (childCount > 0)
              _detailRow('زیرشاخه‌ها', toFa(childCount)),
            if (totalSeconds > 0)
              _detailRow('مجموع زمان', fmtDur(totalSeconds)),
            if (days.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('آخرین روزها:',
                  style: TextStyle(fontSize: 11, color: kGoalsMuted)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final d in days.reversed.take(10))
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withAlpha(40),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(d,
                          style: TextStyle(
                              fontSize: 10.5,
                              color: color,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('بستن'),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF0708A)),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.undo, size: 16),
            label: const Text('برگرداندن به درخت'),
          ),
        ],
      )),
    );

    if (undo == true) {
      n.extra.remove('achieved');
      n.extra.remove('achievedAt');
      store.changed();
      setState(() {});
    }
  }

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text('$label: ',
                style: const TextStyle(fontSize: 12.5, color: kGoalsMuted)),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Future<void> _editFeeling(MapStore store, Goal g) async {
    final c = TextEditingController(text: g.feeling);
    final res = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: kGoalsBg,
      builder: (ctx) => goalsLightSheet(Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 0,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Text('💗 ', style: TextStyle(fontSize: 18)),
                Text('حالا که به این هدف رسیدی، چه حسی داری؟',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              autofocus: true,
              maxLines: 5,
              minLines: 3,
              decoration: const InputDecoration(
                hintText: 'همین‌جا بنویسش...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('لغو'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, c.text.trim()),
                    child: const Text('ذخیره'),
                  ),
                ),
              ],
            ),
          ],
        ),
      )),
    );
    c.dispose();
    if (res != null) {
      g.feeling = res;
      store.changed();
      setState(() {});
    }
  }

  double _sumDay(MapHost h, String jk) {
    double t = 0;
    void walk(List<ActionNode> list) {
      for (final n in list) {
        t += nodeDaySecs(n, jk);
        walk(n.children);
      }
    }

    walk(h.actions);
    return t;
  }

  double _sumPeriod(MapHost h, PeriodInfo pi) {
    final keys = <String>{};
    for (var d = 0; d < pi.total; d++) {
      keys.add(jKey(DateTime(pi.start.year, pi.start.month, pi.start.day + d)));
    }
    double t = 0;
    void walk(List<ActionNode> list) {
      for (final n in list) {
        t += nodePeriodSecs(n, keys);
        walk(n.children);
      }
    }

    walk(h.actions);
    return t;
  }

  Future<int?> _askDays(String title, int def) async {
    final c = TextEditingController(text: toFa(def));
    final res = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 15)),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('لغو')),
          FilledButton(
            onPressed: () {
              final n = _parseDays(c.text);
              if (n == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content:
                        Text('عدد بین ۱ تا ${toFa(kPcMaxDays)} وارد کن')));
                return;
              }
              Navigator.pop(ctx, n);
            },
            child: const Text('تأیید'),
          ),
        ],
      ),
    );
    c.dispose();
    return res;
  }
}
