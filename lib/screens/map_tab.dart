import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../map/camera.dart';
import '../map/draw_utils.dart' show toFa;
import '../map/map_canvas.dart';
import '../map/map_ops.dart';
import '../map/today_focus.dart';
import '../map/walk_view.dart';
import '../models/jalali.dart';
import '../models/map_models.dart';
import '../state/background_store.dart';
import '../state/goal_ops.dart';
import '../state/map_store.dart';
import '../state/theme_store.dart';
import '../theme/web_palette.dart';
import '../widgets/backup_section.dart';
import '../widgets/map_video_overlay.dart';
import '../widgets/finish_reward.dart';
import '../widgets/garden_strip.dart';
import '../widgets/next_step_card.dart';
import '../widgets/step_reward.dart';
import 'add_goal_dialog.dart';
import 'edit_sheet.dart';
import 'foot_stats_sheet.dart';
import 'goals_sheet.dart';
import 'help_dialog.dart';
import 'settings_sheet.dart';
import 'time_sheet.dart';
import '../services/quiet_snack.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});
  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final cam = CameraController();
  final bounds = MapBoundsBox();
  late final MapStore _store;
  bool _resizeMode = false;

  @override
  void initState() {
    super.initState();
    _store = context.read<MapStore>();
    _store.toast = _toast;
    // پاداش فوری بعد از تیک زدنِ هر قدم
    _store.onStepDone = (h, n) {
      if (!mounted) return;
      // «کاملاً تمام شد» → پاداشِ کاملِ مغز (پیشرفت + حسِ پیروزی + یک جمله)
      if (FinishReward.isFresh(n)) {
        StepReward.play(context, sub: 'یک کار تمام شد ✅');
        Future.delayed(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          FinishReward.show(context, store: _store, host: h, node: n);
        });
        return;
      }
      final jk = jKey(DateTime.now());
      var total = 0;
      for (final g in _store.state.goals) {
        total += todayCount(g, jk);
      }
      StepReward.play(context, sub: 'قدم ${toFa(total)} امروز ✨');
    };
    // بار اول که تب باز شد، همه‌ی هدف‌ها در کادر بیایند
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoFit());
  }

  void _autoFit([int tries = 0]) {
    if (!mounted) return;
    final st = _store.state;
    if (st.goals.isEmpty && st.rings.isEmpty) return;
    if (bounds.rect == null) {
      if (tries < 5) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _autoFit(tries + 1));
      }
      return;
    }
    _fit();
  }

  @override
  void dispose() {
    _store.toast = null;
    _store.onStepDone = null;
    cam.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..quietSnack(SnackBar(content: Text(m)));
  }

  void _fit() {
    final r = bounds.rect;
    if (r != null) cam.fitRect(r);
  }

  /// «فقط امروز»: نقشه فقط هدفِ فعال و قدم بعدی را پررنگ نشان می‌دهد
  void _toggleTodayOnly(MapStore store) {
    final on = store.state.extra['todayOnly'] == true;
    if (on) {
      store.state.extra.remove('todayOnly');
    } else {
      store.state.extra['todayOnly'] = true;
      if (TodayFocus.goalId.isEmpty) {
        _toast('قدم باقی‌مانده‌ای برای امروز نیست؛ نقشه همان‌طور عادی می‌ماند.');
      }
    }
    store.changed();
  }

  void _openGoals({String? hostId, String? actionId, String? jk}) {
    showGoalsSheet(
      context,
      onShowOnMap: (h) => cam.centerOn(Offset(h.x, h.y)),
      onAddGoal: () => showAddGoalDialog(context),
      focusHostId: hostId,
      focusActionId: actionId,
      focusJk: jk,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MapStore>();
    final empty = store.state.goals.isEmpty && store.state.rings.isEmpty;
    final anyOpen = store.anyOpen;
    final wp = WebPalette.of(context);
    final ink = wp.textMain;

    final bgStore = context.watch<BackgroundStore>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // مثل بقیه‌ی تب‌ها: روشن = سفید؛ با تصویر/ویدیو/رنگ دلخواه شفاف
    final mapBg = (bgStore.overridesBackdrop || isDark)
        ? Colors.transparent
        : Colors.white;

    return ColoredBox(
      color: mapBg,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MapCanvas(
            cam: cam,
            boundsBox: bounds,
            isResizeMode: () => _resizeMode,
            onEditMe: () => showEditSheet(context, const MeTarget()),
            onWalkerPhotos: (hostId, actionId, isWalker) => showEditSheet(
                context, WalkerPhotosTarget(hostId, actionId, isWalker)),
            // لمسِ غنچه/گلِ یک روز: تقویمِ اهداف روی همان شاخه و همان روز
            onBloomDay: (hostId, actionId, jk) =>
                _openGoals(hostId: hostId, actionId: actionId, jk: jk),
            onFootStats: (hostId, actionId, jk) => showFootStatsSheet(
              context,
              store: store,
              hostId: hostId,
              actionId: actionId,
              initialJk: jk,
              onPhotos: () => showEditSheet(
                  context, WalkerPhotosTarget(hostId, actionId, false)),
            ),
            // تپ روی یادداشتِ روی نقشه: کادرِ اضافه باز نمی‌شود؛ همان تقویمِ قدم
            // (روزِ همان یادداشت) باز می‌شود و تنظیماتِ یادداشت زیرِ «نمایش یادداشت» است.
            onEditFootNote: (hostId, actionId, jk) => showFootStatsSheet(
              context,
              store: store,
              hostId: hostId,
              actionId: actionId,
              initialJk: jk,
              onPhotos: () => showEditSheet(
                  context, WalkerPhotosTarget(hostId, actionId, false)),
            ),
            onEditGoal: (id) => showEditSheet(context, GoalTarget(id)),
            onEditRing: (id) => showEditSheet(context, RingTarget(id)),
            onEditAction: (hostId, actionId) =>
                showEditSheet(context, ActionTarget(hostId, actionId)),
            onTimeBranch: (hostId, actionId) async {
              final h = store.state.findHost(hostId);
              if (h is! MapHost) return;
              final f = findActionNode(h.actions, actionId);
              if (f == null) return;
              final pi = periodInfo(h, store);
              await showTimeSheet(
                context,
                store: store,
                host: h,
                node: f.node,
                jk: pi.todayJK,
                dayLabel: 'امروز',
              );
              // زمان/تایمر ثبت شد → در تقویم هم «انجام شد» بخورد
              final secs = (f.node.time[pi.todayJK] as num?)?.toInt() ?? 0;
              if ((secs > 0 || timerRunning(f.node)) &&
                  !truthy(f.node.logs[pi.todayJK])) {
                f.node.logs[pi.todayJK] = 'انجام شد ✓';
                h.lastActivity = DateTime.now().millisecondsSinceEpoch;
                store.changed();
                store.onStepDone?.call(h, f.node);
              }
            },
          ),

          if (empty)
            IgnorePointer(
              child: Align(
                alignment: const Alignment(0, 0.35),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'هنوز هدفی نیست.\nبا دکمه‌ی + پایین یه هدف بساز.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.55),
                      height: 1.8,
                    ),
                  ),
                ),
              ),
            ),

          // نوار بالا — مثل `#topbar` در Maghz: راست = آیکون + نام اپ،
          // چپ = دکمه‌ی تم (☀️/🌙) و راهنما (؟)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    // برند (لمس = منوی بکاپ و حالت تغییر اندازه)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _showTopMenu(store),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color.fromRGBO(0, 0, 0, 0.25),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset('assets/icon-192.png',
                                fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'نقشه راه',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              color: wp.textMain,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // جمع/باز کردن همه — بالای صفحه تا با انگشت اشتباهی لمس نشه
                    if (store.hasCollapsible) ...[
                      _circleBtn(
                        Icon(anyOpen ? Icons.unfold_less : Icons.unfold_more,
                            size: 17, color: wp.textDim),
                        () => store.collapseAll(anyOpen),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _circleBtn(
                      Text(isDark ? '🌙' : '☀️',
                          style: const TextStyle(fontSize: 14, height: 1)),
                      () => context.read<ThemeStore>().toggle(),
                    ),
                    const SizedBox(width: 8),
                    _circleBtn(
                      Icon(Icons.help_outline, size: 16, color: wp.textDim),
                      () => showHelpDialog(context),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // باغچه: هدف‌های رسیده‌شده‌ای که به‌صورت درخت کاشته شده‌اند
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(8, 58, 8, 0),
                child: GardenStrip(),
              ),
            ),
          ),

          // کارت «قدم بعدیِ امروز» (یک قدم کوچک از بین همه‌ی هدف‌ها)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: ListenableBuilder(
                listenable: GardenStrip.collapsed,
                builder: (_, __) => Padding(
                  padding: EdgeInsets.only(top: 62 + GardenStrip.inset(store)),
                  child: const NextStepCard(),
                ),
              ),
            ),
          ),

          // ویدیوی گره‌ها روی نقشه
          const MapVideoOverlay(),

          // عدد زوم — `#zoom-readout`: چپ، بالای نوار ابزار
          Positioned(
            left: 12,
            bottom: 74,
            child: IgnorePointer(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: wp.panelBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: wp.panelBorder),
                ),
                child: ListenableBuilder(
                  listenable: cam,
                  builder: (_, __) => Text(
                    '${(cam.scale * 100).round()}٪',
                    style: TextStyle(fontSize: 10.5, color: wp.textDim),
                  ),
                ),
              ),
            ),
          ),

          if (_resizeMode)
            Positioned(
              left: 10,
              right: 10,
              bottom: 128,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: wp.panelBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: wp.accent),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'حالت تغییر اندازه روشن است؛ با دو انگشت روی نوشته، آیکون یا گره بکش. بیرون از آن‌ها، پینچ نقشه را زوم می‌کند.',
                          style: TextStyle(
                              fontSize: 11.5,
                              height: 1.7,
                              color: wp.textMain),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: wp.accent,
                          foregroundColor: const Color(0xFF221800),
                          minimumSize: const Size(0, 30),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        onPressed: () => setState(() => _resizeMode = false),
                        child: const Text('تمام',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // نوار ابزار پایین — دکمه‌ی تنظیمات اضافه شد
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: SafeArea(
              top: false,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                decoration: BoxDecoration(
                  color: wp.panelBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: wp.panelBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _toolBtn(Icons.format_list_bulleted, 'اهداف', ink,
                        _openGoals),
                    _toolBtn(Icons.fit_screen, 'نمایش همه', ink, _fit),
                    _toolBtn(Icons.directions_walk, 'قدم‌زدن', ink,
                        () => openWalkView(context, store.state)),
                    _toolBtn(
                      Icons.today,
                      'فقط امروز',
                      ink,
                      () => _toggleTodayOnly(store),
                      primary: store.state.extra['todayOnly'] == true,
                    ),
                    _toolBtn(
                        Icons.stars_outlined, 'نشانه', ink, store.addRing),
                    _toolBtn(
                      Icons.settings,
                      'تنظیمات',
                      ink,
                      () => showSettingsSheet(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _circleBtn(Widget child, VoidCallback onTap) {
    final wp = WebPalette.of(context);
    return Material(
      color: wp.panelBg,
      shape: CircleBorder(side: BorderSide(color: wp.panelBorder)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 30, height: 30, child: Center(child: child)),
      ),
    );
  }

  Widget _toolBtn(IconData icon, String label, Color color, VoidCallback onTap,
      {bool primary = false}) {
    final bg = primary ? const Color(0xFFC9962B) : Colors.transparent;
    final fg = primary ? Colors.white : color;
    return Expanded(
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTopMenu(MapStore store) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          MediaQuery.sizeOf(context).width - 220, 90, 16, 0),
      items: [
        PopupMenuItem(
            value: 'resize',
            child: Text(_resizeMode
                ? 'خاموش کردن حالت تغییر اندازه'
                : 'حالت تغییر اندازه')),
        const PopupMenuItem(
            value: 'backup', child: Text('بکاپ و بازیابی (کل برنامه)')),
      ],
    ).then((v) {
      if (v == 'resize') setState(() => _resizeMode = !_resizeMode);
      if (v == 'backup' && mounted) showFullBackupSheet(context);
    });
  }
}

class _SaveIndicator extends StatefulWidget {
  const _SaveIndicator({super.key});
  @override
  State<_SaveIndicator> createState() => _SaveIndicatorState();
}

class _SaveIndicatorState extends State<_SaveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  @override
  void initState() {
    super.initState();
    _c.forward();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) _c.reverse();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: Color(0xFF63D6A8)),
            SizedBox(width: 6),
            Text('ذخیره شد',
                style: TextStyle(fontSize: 12, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
