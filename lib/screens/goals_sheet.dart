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
import 'edit_sheet.dart';
import '../theme/app_theme.dart';
import '../widgets/emoji_stack.dart';
import '../widgets/icon_photo_editor.dart';
import '../widgets/panel_kit.dart';
import 'time_sheet.dart';
import 'weekly_sheet.dart';
import '../services/quiet_snack.dart';

const _kGold = Color(0xFF178A7C); // سبز هماهنگ با بقیه‌ی تب‌ها
const _kInk = Color(0xFF000000);
const _kMuted = Color(0xFF5B5F77);
const _kBorder = Color(0xFFE4E6EE);

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
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    elevation: 16,
    clipBehavior: Clip.antiAlias,
    barrierColor: Colors.transparent, // نقشه پشتش دیده می‌شود
    builder: (ctx) => goalsLightSheet(DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.46,
      minChildSize: 0.26,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.26, 0.46, 0.92],
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
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: size > 50 ? 2.5 : 1.5),
        ),
        child: ClipOval(
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: 240,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _fallback(icon),
          ),
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
          border: Border.all(color: color, width: size > 50 ? 2.5 : 1.5),
        ),
        child: icon.trim().isEmpty ? null : EmojiStack(icon: icon, size: size),
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

/// داده‌ی کشیدنِ یک شاخه (برای انداختن روی شاخه‌ی دیگر)
class _NodeDrag {
  const _NodeDrag(this.hostId, this.node);
  final String hostId;
  final ActionNode node;
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
  /// روز انتخاب‌شده در تقویم هر شاخه (پیش‌فرض امروز)
  final Map<String, DateTime> _selDay = {};

  /// هدف‌هایی که پنل ویرایش درجا (ایکون/عکس/اندازه) بازه
  final Set<String> _editing = {};

  /// هدف‌هایی که در حالت «ویرایش» لیست‌اند (جابه‌جایی شاخه/زیرشاخه با کشیدن)
  final Set<String> _reorderMode = {};

  int _tab = 0; // 0=در جریان, 1=محقق‌شده
  String _q = '';
  final _search = TextEditingController();
  final _addCtl = TextEditingController();
  final _open = <String>{};
  final _daysOpen = <String>{};
  final _statsOpen = <String>{};
  String? _addingFor;

  /// شاخه‌ای که همین الان با انگشت کشیده می‌شود (برای نشان‌دادنِ «شاخه‌ی اصلی» پایین لیست)
  ActionNode? _dragNode;
  String _dragHostId = '';
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

    return Stack(children: [
      Positioned.fill(child: ListView(
      controller: widget.controller,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 96),
      children: [
        // هدر
        Row(
          children: [
            const Text('اهداف من',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: kGoalsInk)),
            if (countText.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: kPanelField,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(countText,
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: kGoalsMuted)),
              ),
            ],
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.insights_rounded,
                  size: 20, color: _kGold),
              tooltip: 'نگاه هفته',
              onPressed: () => showWeeklySheet(context, store.state),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 14),

        // تب‌ها (قطعه‌ای)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: kPanelField,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: _seg('در جریان', active.length, _tab == 0,
                    () => setState(() => _tab = 0)),
              ),
              Expanded(
                child: _seg('محقق‌شده', reached.length, _tab == 1,
                    () => setState(() => _tab = 1)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // جست‌وجو
        TextField(
          controller: _search,
          onChanged: (v) => setState(() => _q = _norm(v.trim())),
          style: const TextStyle(fontSize: 14, color: kGoalsInk),
          decoration: InputDecoration(
            hintText: 'جست‌وجو در اهداف و اقدامات…',
            hintStyle: const TextStyle(fontSize: 13, color: kGoalsMuted),
            prefixIcon:
                const Icon(Icons.search_rounded, color: kGoalsMuted, size: 20),
            isDense: true,
            filled: true,
            fillColor: kPanelField,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _kGold, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 14),

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
    )),
      // دکمه‌ی «هدف جدید»: پایین-راست؛ بعد از ساخت مستقیم کادر ویرایش باز می‌شود
      Positioned(
        right: 16,
        bottom: 18,
        child: FloatingActionButton.extended(
          heroTag: 'goals_add_fab',
          backgroundColor: _kGold,
          foregroundColor: Colors.white,
          elevation: 4,
          onPressed: () => _quickAddGoal(store),
          icon: const Icon(Icons.add_rounded, size: 22),
          label: const Text('هدف جدید',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }

  /// افزودنِ فوری: بدون دیالوگ؛ هدف با نام پیش‌فرض ساخته می‌شود و بالای فهرست می‌آید
  void _quickAddGoal(MapStore store) {
    final g = store.addGoal(
      name: 'هدف جدید',
      icon: '🎯',
      color: kPalette[math.Random().nextInt(kPalette.length)],
    );
    final ex = store.state.extra;
    final order = (ex['goalOrder'] as List?)?.whereType<String>().toList();
    if (order != null && order.isNotEmpty) {
      ex['goalOrder'] = [g.id, ...order];
      store.changed();
    }
    if (_tab != 0) setState(() => _tab = 0);
    if (widget.controller.hasClients) {
      widget.controller.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
    // مستقیم برو توی ویرایش تا نام و آیکون هدف رو وارد کنی
    Navigator.pop(context);
    showEditSheet(widget.parentContext, GoalTarget(g.id));
  }

  // ------------------------------------------------------------------ کارت هدف

  BoxDecoration _cardDeco(Color c) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kPanelBorder),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14141832), blurRadius: 14, offset: Offset(0, 4)),
        ],
      );

  /// کارت سفید با نوار رنگیِ هدف در لبه‌ی شروع
  Widget _accentCard(Color color, Widget child, {EdgeInsets? padding}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _cardDeco(color),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 5)
                  .add(padding ?? EdgeInsets.zero),
              child: child,
            ),
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seg(String label, int n, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: on
              ? const [
                  BoxShadow(
                      color: Color(0x1A141832),
                      blurRadius: 6,
                      offset: Offset(0, 2)),
                ]
              : null,
        ),
        child: Text(
          n > 0 ? '$label · ${toFa(n)}' : label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: on ? FontWeight.w800 : FontWeight.w600,
            color: on ? kGoalsInk : kGoalsMuted,
          ),
        ),
      ),
    );
  }

  /// قدم بعدیِ امروز: اولین قدمِ کوچک (بدون زیرشاخه) که امروز انجام نشده
  String _nextStep(MapHost h) {
    final jk = jKey(DateTime.now());
    String? pick(List<ActionNode> l) {
      for (final n in l) {
        if (n.children.isEmpty) {
          if (n.text.trim().isNotEmpty && !truthy(n.logs[jk])) {
            return n.text.trim();
          }
        } else {
          final r = pick(n.children);
          if (r != null) return r;
        }
      }
      return null;
    }

    return pick(h.actions) ?? '';
  }

  Widget _action(IconData i, String label, Color color, VoidCallback onTap) =>
      Expanded(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(i, size: 17, color: color),
                const SizedBox(width: 5),
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ],
            ),
          ),
        ),
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

  /// دکمه‌ی کوچک و برچسب‌دار زیر هر اقدام
  Widget _miniAction(IconData i, String label, VoidCallback onTap,
      {Color? color, bool active = false}) {
    final c = color ?? kGoalsMuted;
    return Material(
      color: active ? c.withAlpha(30) : Colors.white,
      shape: StadiumBorder(
          side: BorderSide(color: active ? c : kGoalsBorder)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(i, size: 15, color: c),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: c,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(
          color: _kGold.withAlpha(34),
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
    final linked =
        h is Ring ? store.state.goals.where((g) => g.id == h.goalId).toList() : <Goal>[];
    final next = _nextStep(h);
    const divider = VerticalDivider(width: 1, thickness: 1, color: kGoalsBorder);

    return _accentCard(
      color,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() {
              if (!_open.remove(h.id)) _open.add(h.id);
              _addingFor = null;
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 14, 6, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (reorderIndex != null)
                    ReorderableDragStartListener(
                      index: reorderIndex,
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(0, 14, 4, 0),
                        child: Icon(Icons.drag_indicator_rounded,
                            size: 20, color: kGoalsMuted),
                      ),
                    ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() {
                      if (!_editing.remove(h.id)) _editing.add(h.id);
                    }),
                    child: _Avatar(host: h, color: color, size: 52),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_name(h),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16,
                                height: 1.35,
                                fontWeight: FontWeight.w800,
                                color: kGoalsInk)),
                        const SizedBox(height: 5),
                        if (h.isRing)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _tag(
                                'نزدیک شدن به هدف${linked.isEmpty ? '' : ' · «${linked.first.name.isEmpty ? 'هدف' : linked.first.name}»'}'),
                          ),
                        Row(
                          children: [
                            const Icon(Icons.arrow_circle_left_outlined,
                                size: 15, color: kGoalsMuted),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                next.isNotEmpty
                                    ? 'قدم بعدی: $next'
                                    : (h.actions.isEmpty
                                        ? 'هنوز قدمی نیست'
                                        : 'قدم‌های امروز انجام شد ✓'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12.5, color: kGoalsMuted),
                              ),
                            ),
                          ],
                        ),
                        if (r.hit.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('↳ ${r.hit}',
                                style: TextStyle(fontSize: 12, color: color),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: LinearProgressIndicator(
                                  value: power / 100,
                                  minHeight: 6,
                                  color: color,
                                  backgroundColor: kGoalsBorder,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${toFa(power.round())}٪',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: kGoalsMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 2),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.expand_more_rounded,
                          size: 24, color: kGoalsMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // نوار کارهای سریع
          const Divider(height: 1, thickness: 1, color: kGoalsBorder),
          SizedBox(
            height: 42,
            child: Row(
              children: [
                _action(
                    _reorderMode.contains(h.id)
                        ? Icons.check_rounded
                        : Icons.edit_outlined,
                    _reorderMode.contains(h.id) ? 'پایان ویرایش' : 'ویرایش',
                    _kGold, () {
                  // لیست اهداف (شاخه‌ها) باز می‌شود؛ با کشیدنِ دستگیره جابه‌جا می‌شوند
                  setState(() {
                    if (_reorderMode.remove(h.id)) return;
                    _reorderMode.add(h.id);
                    _open.add(h.id);
                    _addingFor = null;
                  });
                }),
                divider,
                _action(
                    Icons.tune_rounded,
                    _editing.contains(h.id) ? 'بستن شخصی‌سازی' : 'شخصی‌سازی',
                    _kGold, () {
                  setState(() {
                    if (!_editing.remove(h.id)) _editing.add(h.id);
                  });
                }),
                divider,
                _action(Icons.my_location_rounded, 'روی نقشه', kGoalsMuted, () {
                  Navigator.pop(context);
                  widget.onShowOnMap(h);
                }),
                // فعلاً مخفی: دکمه‌ی «رسیدم» (کد حفظ شده؛ برای نمایش دوباره کامنت را بردار)
                // if (h is Goal) ...[
                //   divider,
                //   _action(Icons.check_circle_outline_rounded, 'رسیدم',
                //       const Color(0xFF178A7C), () => _reach(store, h)),
                // ],
              ],
            ),
          ),
          if (_editing.contains(h.id)) _editPanel(store, h, color),
          if (isOpen) _body(store, h, color),
        ],
      ),
    );
  }

  /// پنل ویرایش درجا: ایکون/عکس + اندازه‌ی ایکون (اولیه) + تأیید
  Widget _editPanel(MapStore store, MapHost h, Color color) {
    final g = h is Goal ? h : null;
    final r = h is Ring ? h : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          IconPhotoEditor(
            key: ValueKey('ipe-${h.id}'),
            initialIcon: g != null ? g.icon : r!.icon,
            initialImages: g != null ? g.images : r!.images,
            initialScale: g != null ? g.iconScale : r!.iconScale,
            onChange: (icon, images, scale) {
              if (g != null) {
                g.icon = icon;
                g.images = images;
                g.iconScale = scale;
              } else {
                r!.icon = icon.isEmpty ? '🌟' : icon;
                r.images = images;
                r.iconScale = scale;
              }
              store.changed();
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _kGold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => setState(() => _editing.remove(h.id)),
                  child: const Text('تأیید',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  showEditSheet(
                    widget.parentContext,
                    h is Goal ? GoalTarget(h.id) : RingTarget(h.id),
                  );
                },
                child: const Text('ویرایش کامل',
                    style: TextStyle(color: _kMuted, fontSize: 12.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _reach(MapStore store, Goal g) {
    _open.remove(g.id);
    store.reachGoal(g);
    ScaffoldMessenger.of(widget.parentContext)
        .quietSnack(const SnackBar(content: Text('🏆 هدف محقق شد!')));
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
    return _accentCard(
      color,
      padding: const EdgeInsets.all(12),
      Row(
        children: [
          _Avatar(host: g, color: color, size: 48),
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
                color: _kGold.withAlpha(34),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kGold.withAlpha(110)),
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

          // اقدامات
          if (h.actions.isEmpty && !adding)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Text('با ＋ شروع کن؛ مثلاً «گوش دادن به پادکست».',
                  style: TextStyle(color: kGoalsMuted)),
            ),
          if (_reorderMode.contains(h.id) && h.actions.length > 1)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: h.actions.length,
              onReorder: (oldIdx, newIdx) {
                setState(() {
                  if (newIdx > oldIdx) newIdx--;
                  final item = h.actions.removeAt(oldIdx);
                  h.actions.insert(newIdx, item);
                  store.changed();
                });
              },
              itemBuilder: (ctx, i) => KeyedSubtree(
                key: ValueKey(h.actions[i].id),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _nodeTiles(
                      store, h, h.actions[i], pi, hostColor, 0, '',
                      reorderIndex: i),
                ),
              ),
            )
          else
            for (final a in h.actions)
              ..._nodeTiles(store, h, a, pi, hostColor, 0, ''),
          _rootDropZone(store, h),
          ..._trophiesSection(store, h, hostColor),

          const SizedBox(height: 6),

          // دکمه افزودن اقدام
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
                label: const Text('افزودن اقدام'),
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
                _reorderMode.remove(h.id);
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
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
      decoration: BoxDecoration(
        color: isSub ? const Color(0xFFFFFCF4) : kPanelField,
        border: BorderDirectional(start: BorderSide(color: color, width: 4)),
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
                  'اقدام',
                  style: TextStyle(
                    fontSize: 10,
                    color: isSub ? color : Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isSub && kShowSubActions)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 6),
                    child: Text(
                      parentName.isEmpty ? '' : 'از «$parentName»',
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
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Icon(Icons.drag_indicator,
                        size: 22, color: kGoalsMuted),
                  ),
                ),
              _moveHandle(h, n),
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
                    hintText: 'نام اقدام',
                    hintStyle: const TextStyle(color: kGoalsMuted),
                  ),
                ),
              ),
              // قرص زمان امروز: ⌚ ۱ ساعت — با لمس، پنل ثبت زمان باز می‌شه
              GestureDetector(
                onTap: () => showTimeSheet(
                  context,
                  store: store,
                  host: h,
                  node: n,
                  jk: pi.todayJK,
                  dayLabel: 'امروز',
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: timerRunning(n)
                        ? const Color(0xFFE5484D).withAlpha(30)
                        : Colors.white.withAlpha(150),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: timerRunning(n)
                            ? const Color(0xFFE5484D)
                            : kGoalsBorder),
                  ),
                  child: Text(
                    nodeDaySecs(n, pi.todayJK) > 0
                        ? '⌚ ${fmtDur(nodeDaySecs(n, pi.todayJK))}'
                        : '⌚',
                    style: const TextStyle(fontSize: 12, color: kGoalsInk),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4, right: 2, left: 2),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // دکمه‌ی «+»: افزودن زیرشاخه برای همین شاخه
                Material(
                  color: Colors.white,
                  shape: CircleBorder(
                      side: BorderSide(
                          color: _addingFor == n.id ? color : kGoalsBorder)),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() {
                      _addingFor = n.id;
                      _addCtl.clear();
                    }),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.add_rounded,
                          size: 18,
                          color: _addingFor == n.id ? color : kGoalsMuted),
                    ),
                  ),
                ),
                _miniAction(
                  Icons.calendar_month_outlined,
                  'روزها',
                  () => setState(() {
                    if (!_daysOpen.remove(n.id)) _daysOpen.add(n.id);
                  }),
                  color: daysOpen ? color : null,
                  active: daysOpen,
                ),
                _miniAction(
                  n.extra['achieved'] == true
                      ? Icons.emoji_events
                      : Icons.emoji_events_outlined,
                  'دستاورد',
                  () => _toggleAchieved(store, h, n),
                  color: n.extra['achieved'] == true
                      ? const Color(0xFFF4C542)
                      : null,
                  active: n.extra['achieved'] == true,
                ),
                _miniAction(
                  Icons.delete_outline_rounded,
                  'حذف',
                  () => _confirmDelete(store, h, n),
                  color: const Color(0xFFE5484D),
                ),
              ],
            ),
          ),
          if (timerRunning(n))
            const Padding(
              padding: EdgeInsets.only(top: 6, right: 4),
              child: Row(
                children: [
                  Icon(Icons.fiber_manual_record,
                      size: 10, color: Color(0xFFE5484D)),
                  SizedBox(width: 4),
                  Text('در حال ضبط',
                      style:
                          TextStyle(fontSize: 11, color: Color(0xFFE5484D))),
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
                        size: 12, color: _kGold),
                    const SizedBox(width: 3),
                    Text(
                      '${toFa(routineStreak(n))} روز پیاپی',
                      style: const TextStyle(
                          fontSize: 11,
                          color: _kGold,
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

    final tile = DragTarget<_NodeDrag>(
      onWillAcceptWithDetails: (d) => _canDropInto(h, d.data, n),
      onAcceptWithDetails: (d) => _moveNode(store, h, d.data.node, n),
      builder: (ctx, cand, rej) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, 2)),
            ],
          ),
          child: Container(
            foregroundDecoration: cand.isEmpty
                ? null
                : BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: color.withAlpha(40),
                    border: Border.all(color: color, width: 2.5),
                  ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: tileBody,
            ),
          ),
        ),
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
    // ── مربع‌های تقویم: دقیقاً مثل `.gs-day` در Maghz (css/base-and-map.css) ──
    // ۲۵×۲۵، گوشه ۷، فاصله ۴، چینش wrap؛ روزِ انجام‌شده با رنگ خود شاخه + «✓» تیره
    const cell = 25.0;
    const border = Color.fromRGBO(20, 24, 50, 0.30); // حاشیه‌ی پررنگ‌تر (مثل مغز روی پنل)
    const emptyBg = Color.fromRGBO(110, 114, 140, 0.22);
    const dim = Color(0xFF3F4258); // --text-dim (تیره‌تر)
    const accent = Color(0xFFC9962B); // --accent
    const mainInk = Color(0xFF000000); // --text-main
    const doneInk = Color(0xFF12142A); // رنگ ✓ روی رنگ شاخه
    final selD = _selDay[n.id] ?? pi.today;
    final cells = <Widget>[];
    for (var d = 0; d < pi.total; d++) {
      final date = DateTime(pi.start.year, pi.start.month, pi.start.day + d);
      final jk = jKey(date);
      final j = toJalaali(date.year, date.month, date.day);
      final has = truthy(n.logs[jk]);
      final future = date.isAfter(pi.today);
      final isToday = date.isAtSameMomentAs(pi.today);
      final isSel = date.year == selD.year &&
          date.month == selD.month &&
          date.day == selD.day;
      Widget c = SizedBox(
        width: cell,
        height: cell,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // body: پس‌زمینه + حاشیه + (today: box-shadow 0 0 0 2px accent)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  color: has ? color : emptyBg,
                  border: Border.all(
                      color: has ? Color.lerp(color, Colors.black, 0.35)! : border,
                      width: 1.2),
                  boxShadow: isToday
                      ? const [
                          BoxShadow(
                              color: accent, spreadRadius: 2, blurRadius: 0)
                        ]
                      : null,
                ),
              ),
            ),
            // sel: outline 2px --text-main با offset ۱px
            if (isSel)
              Positioned(
                left: -3,
                top: -3,
                right: -3,
                bottom: -3,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: mainInk, width: 2),
                    ),
                  ),
                ),
              ),
            Text(
              has ? '✓' : toFa(j.jd),
              style: TextStyle(
                fontSize: 10.5,
                height: 1,
                fontWeight: has ? FontWeight.w800 : FontWeight.w400,
                color: has ? doneInk : dim,
              ),
            ),
          ],
        ),
      );
      // .gs-day.future → opacity .35 و غیرقابل‌لمس
      if (future) {
        c = Opacity(opacity: 0.35, child: c);
      } else {
        c = GestureDetector(
          behavior: HitTestBehavior.opaque,
          // لمس: روز انتخاب می‌شه و تیکش عوض می‌شه؛ کادر ساعت‌های همان روز زیر تقویم باز می‌شه
          onTap: () {
            setState(() => _selDay[n.id] = date);
            store.toggleLog(h, n, jk);
          },
          child: c,
        );
      }
      cells.add(c);
    }
    final sel = _selDay[n.id] ?? pi.today;
    final selJk = jKey(sel);
    final selJ = toJalaali(sel.year, sel.month, sel.day);
    final selLabel = '${toFa(selJ.jd)} ${kJalaliMonths[selJ.jm - 1]}';
    final selEntries = nodeEntries(n, selJk);
    final selSecs = nodeDaySecs(n, selJk);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(spacing: 4, runSpacing: 4, children: cells),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // چیپ تاریخ + افزودن ساعت (دیالوگ ثبت زمان)
              GestureDetector(
                onTap: () => _addTimeFor(store, n, selJk, selLabel),
                child: _DashedBox(
                  radius: 14,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Text(
                    '⏱ $selLabel${selSecs > 0 ? ' · ${fmtDur(selSecs)}' : ''} · + ساعت',
                    style: const TextStyle(fontSize: 12.5, color: _kMuted),
                  ),
                ),
              ),
              if (selEntries.isNotEmpty)
                GestureDetector(
                  onTap: () => _clearDay(store, n, selJk),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _kBorder),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline, size: 16, color: _kInk),
                        SizedBox(width: 4),
                        Text('همه',
                            style: TextStyle(fontSize: 12, color: _kInk)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (selEntries.isNotEmpty) ...[
            const SizedBox(height: 10),
            _DashedBox(
              radius: 14,
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < selEntries.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _editEntry(store, n, selJk, i),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${toFa(i + 1)}. ${_entryLabel(selEntries[i])}',
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: _kInk),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.edit_outlined,
                                          size: 15, color: _kMuted),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          ((selEntries[i]['note'] as String?)
                                                      ?.isNotEmpty ==
                                                  true)
                                              ? selEntries[i]['note']
                                                  as String
                                              : 'ویرایش زمان و یادداشت',
                                          style: const TextStyle(
                                              fontSize: 12, color: _kMuted),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              deleteEntry(n, selJk, i);
                              store.changed();
                            },
                            child: Container(
                              width: 44,
                              height: 30,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: _kInk.withAlpha(150)),
                              ),
                              child: const Icon(Icons.close,
                                  size: 17, color: _kInk),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addTimeFor(
      MapStore store, ActionNode n, String jk, String dayLabel) async {
    final res = await askDurationTabbed(
      context,
      title: 'ثبت زمان جدید',
      sub: '$dayLabel · ${n.text.isEmpty ? 'بدون نام' : n.text}',
      defMin: 60,
    );
    if (res == null || res.mins <= 0) return;
    if (res.range != null) {
      addRange(n, jk, res.range!.start, res.range!.end, note: res.note);
    } else {
      addDuration(n, jk, res.mins, note: res.note);
    }
    // تیک خودکار نمی‌خوره؛ کاربر خودش تیک می‌زنه
    store.changed();
  }

  Future<void> _clearDay(MapStore store, ActionNode n, String jk) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('حذف همه',
            style: TextStyle(fontSize: 15, color: _kInk)),
        content: const Text('همه‌ی زمان‌های این روز حذف بشه؟',
            style: TextStyle(color: _kInk)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('نه', style: TextStyle(color: _kMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE5484D)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      clearDayTime(n, jk);
      store.changed();
    }
  }

  static String _en(String s) {
    const fa = '۰۱۲۳۴۵۶۷۸۹', ar = '٠١٢٣٤٥٦٧٨٩';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      var i = fa.indexOf(ch);
      if (i < 0) i = ar.indexOf(ch);
      b.write(i >= 0 ? '$i' : ch);
    }
    return b.toString().trim();
  }

  static int? _hm(String s) {
    final p = _en(s).split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return h * 60 + m;
  }

  /// ویرایش دوباره‌ی یک ثبت زمان: مدت (یا بازه‌ی ساعت) + یادداشت
  Future<void> _editEntry(
      MapStore store, ActionNode n, String jk, int idx) async {
    final raw = n.entries[jk];
    if (raw is! List || idx >= raw.length || raw[idx] is! Map) return;
    final e = raw[idx] as Map;
    final isRange = e['kind'] == 'range';
    final mins = (e['mins'] as num?)?.toInt() ?? 0;
    final hc = TextEditingController(text: toFa(mins ~/ 60));
    final mc = TextEditingController(text: toFa(mins % 60));
    final fc = TextEditingController(
        text: fmtHM((e['s'] as num?)?.toInt() ?? 0));
    final tc = TextEditingController(
        text: fmtHM((e['e'] as num?)?.toInt() ?? 0));
    final nc = TextEditingController(text: (e['note'] as String?) ?? '');

    InputDecoration dec(String l) => InputDecoration(
          labelText: l,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder),
          ),
        );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('ویرایش ثبت زمان',
            style: TextStyle(fontSize: 15, color: _kInk)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isRange)
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: fc,
                      keyboardType: TextInputType.datetime,
                      textAlign: TextAlign.center,
                      decoration: dec('از (ساعت:دقیقه)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: tc,
                      keyboardType: TextInputType.datetime,
                      textAlign: TextAlign.center,
                      decoration: dec('تا (ساعت:دقیقه)'),
                    ),
                  ),
                ])
              else
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: hc,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: dec('ساعت'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: mc,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: dec('دقیقه'),
                    ),
                  ),
                ]),
              const SizedBox(height: 10),
              TextField(
                controller: nc,
                minLines: 2,
                maxLines: 4,
                decoration: dec('یادداشت'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لغو', style: TextStyle(color: _kMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kGold),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    final note = nc.text.trim();
    final hText = hc.text, mText = mc.text, fText = fc.text, tText = tc.text;
    hc.dispose();
    mc.dispose();
    fc.dispose();
    tc.dispose();
    nc.dispose();
    if (ok != true) return;

    var newMins = mins;
    if (isRange) {
      final s0 = _hm(fText), e0 = _hm(tText);
      if (s0 == null || e0 == null) return;
      var e1 = e0;
      if (e1 <= s0) e1 += 1440;
      newMins = e1 - s0;
      final rl = n.ranges[jk];
      if (rl is List) {
        for (final r in rl) {
          if (r is Map && r['s'] == e['s'] && r['e'] == e['e']) {
            r['s'] = s0;
            r['e'] = e1 % 1440;
            break;
          }
        }
      }
      e['s'] = s0;
      e['e'] = e1 % 1440;
    } else {
      final hh = int.tryParse(_en(hText)) ?? 0;
      final mm = int.tryParse(_en(mText)) ?? 0;
      newMins = hh.clamp(0, 24) * 60 + mm.clamp(0, 59);
      if (newMins <= 0) return;
    }
    final cur = (n.time[jk] as num?)?.toInt() ?? 0;
    final nv = cur + (newMins - mins) * 60;
    if (nv > 0) {
      n.time[jk] = nv;
    } else {
      n.time.remove(jk);
    }
    e['mins'] = newMins;
    if (note.isEmpty) {
      e.remove('note');
    } else {
      e['note'] = note;
    }
    store.changed();
  }

  String _entryLabel(Map<String, dynamic> e) {
    final mins = (e['mins'] as num?)?.toInt() ?? 0;
    if (e['kind'] == 'range') {
      return '🕒 ${fmtHM((e['s'] as num?)?.toInt() ?? 0)} تا ${fmtHM((e['e'] as num?)?.toInt() ?? 0)} — ${fmtDur(mins * 60)}';
    }
    return '⏱ ${fmtDur(mins * 60)}';
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

  // ------------------------------------------------------------------ کشیدنِ شاخه زیرِ شاخه‌ی دیگر

  /// دستگیره‌ی ✥: نگه دار و با انگشت روی شاخه‌ی دیگر بکش تا زیرشاخه‌اش شود
  Widget _moveHandle(MapHost h, ActionNode n) {
    const grip = Padding(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Icon(Icons.open_with, size: 20, color: kGoalsMuted),
    );
    return LongPressDraggable<_NodeDrag>(
      data: _NodeDrag(h.id, n),
      delay: const Duration(milliseconds: 180),
      hapticFeedbackOnStart: true,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedbackOffset: const Offset(0, -56),
      onDragStarted: () => setState(() {
        _dragNode = n;
        _dragHostId = h.id;
      }),
      onDragEnd: (_) {
        if (mounted) setState(() => _dragNode = null);
      },
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: hexColor(n.color, kGoalsMuted), width: 2),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12,
                  offset: Offset(0, 4)),
            ],
          ),
          child: Text(
            n.text.isEmpty ? 'بدون نام' : n.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 14,
                color: kGoalsInk,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: grip),
      child: grip,
    );
  }

  /// آیا [drag] را می‌شود زیرِ [target] انداخت؟ (همان هدف، نه خودش، نه نوه‌اش، نه پدر فعلی‌اش)
  bool _canDropInto(MapHost h, _NodeDrag drag, ActionNode target) {
    if (drag.hostId != h.id) return false;
    if (drag.node.id == target.id) return false;
    if (findActionNode(drag.node.children, target.id) != null) return false;
    final f = findActionNode(h.actions, drag.node.id);
    if (f == null) return false;
    return !identical(f.list, target.children);
  }

  /// [newParent] == null یعنی شاخه‌ی اصلیِ هدف شود
  void _moveNode(
      MapStore store, MapHost h, ActionNode node, ActionNode? newParent) {
    final f = findActionNode(h.actions, node.id);
    if (f == null) return;
    final dest = newParent?.children ?? h.actions;
    if (identical(f.list, dest)) return;
    if (newParent != null) {
      if (newParent.id == node.id ||
          findActionNode(node.children, newParent.id) != null) {
        return;
      }
    }
    f.list.remove(node);
    dest.add(node);
    h.collapsed = false;
    h.lastActivity = DateTime.now().millisecondsSinceEpoch;
    store.changed();
    setState(() {
      _dragNode = null;
      _addingFor = null;
    });
  }

  /// فقط وقتی یک زیرشاخه در حال کشیده‌شدن است: انداختن اینجا = شاخه‌ی اصلی
  Widget _rootDropZone(MapStore store, MapHost h) {
    final dn = _dragNode;
    if (dn == null || _dragHostId != h.id) return const SizedBox.shrink();
    if (h.actions.any((a) => a.id == dn.id)) return const SizedBox.shrink();
    return DragTarget<_NodeDrag>(
      onWillAcceptWithDetails: (d) => d.data.hostId == h.id,
      onAcceptWithDetails: (d) => _moveNode(store, h, d.data.node, null),
      builder: (ctx, cand, rej) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cand.isEmpty ? Colors.transparent : _kGold.withAlpha(40),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kGold, width: cand.isEmpty ? 1.5 : 2.5),
        ),
        child: const Text('اینجا رها کن تا شاخه‌ی اصلی شود',
            style: TextStyle(
                fontSize: 13, color: kGoalsInk, fontWeight: FontWeight.w600)),
      ),
    );
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
          color: _kGold.withAlpha(34),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kGold.withAlpha(130)),
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
              _detailRow('', toFa(childCount)),
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
                ScaffoldMessenger.of(ctx).quietSnack(SnackBar(
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


/// کادر خط‌چین (مثل چیپ تاریخ و لیست ثبت‌های زمان در مغز)
class _DashedBox extends StatelessWidget {
  const _DashedBox({
    required this.child,
    this.radius = 14,
    this.padding = const EdgeInsets.all(8),
  });
  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _DashPainter(radius),
        child: Padding(padding: padding, child: child),
      );
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.radius);
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB9AE98)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, Radius.circular(radius)));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.radius != radius;
}
