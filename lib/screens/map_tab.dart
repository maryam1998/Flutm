import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../map/camera.dart';
import '../map/day_cycle.dart';
import '../map/draw_utils.dart' show toFa;
import '../map/hit_registry.dart';
import '../map/map_canvas.dart';
import '../map/map_ops.dart';
import '../map/today_focus.dart';
import '../map/walk_view.dart';
import '../map/sky_weather.dart';
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

  // ───── کج‌کردنِ نقشه با دو انگشت → نمای راه‌رفتن ─────
  final Map<int, Offset> _tStart = {};
  final Map<int, Offset> _tNow = {};
  bool _tiltDone = false;

  // پای انیمیشنی (قدم‌زنِ هدف یا پای شاخه) که هر انگشت رویش شروع به لمس کرده
  final Map<int, HitEntry> _tFoot = {};
  // وضعیتِ پا پیش از لمس؛ چون کشیدنِ انگشت روی پا آن را جابه‌جا می‌کند و با
  // رفتن به نمای راه‌رفتن باید به حالت قبل برگردد
  Map<String, Object?>? _tSnap;

  void _tiltDown(PointerDownEvent e) {
    if (_tStart.isEmpty) {
      _tiltDone = false;
      _tFoot.clear();
      _tSnap = null;
    }
    _tStart[e.pointer] = e.position;
    _tNow[e.pointer] = e.position;
    final h = HitRegistry.current
        ?.hitTest(cam.screenToWorld(e.localPosition), cam.scale);
    if (h != null && (h.type == 'walker' || h.type == 'foot')) {
      _tFoot[e.pointer] = h;
      _tSnap ??= _snapFoot(h);
    } else if (h != null && h.type == 'face' && h.id.isNotEmpty) {
      // لمس روی چهره/عکسِ پا هم یعنی همان پا (قبلاً فقط بدنه‌ی پا شمرده می‌شد و
      // کشیدن روی عکس، به‌جای شاخه، جاده‌ی اصلیِ هدف را باز می‌کرد)
      final host = context.read<MapStore>().state.findHost(h.hostId);
      final isWalker = host is Goal && h.id == h.hostId;
      final fh = HitEntry(
        type: isWalker ? 'walker' : 'foot',
        id: h.id,
        hostId: h.hostId,
        kind: h.kind,
        center: h.center,
        radius: h.radius,
      );
      _tFoot[e.pointer] = fh;
      _tSnap ??= _snapFoot(fh);
    }
  }

  Map<String, Object?>? _snapFoot(HitEntry h) {
    final st = context.read<MapStore>().state;
    final host = st.findHost(h.hostId);
    if (host is! MapHost) return null;
    if (h.type == 'walker' && host is Goal) {
      return {
        'type': 'walker',
        'host': h.hostId,
        'pos': host.extra['walkerPos'],
        'playing': host.extra['walkerPlaying'],
      };
    }
    final f = findActionNode(host.actions, h.id);
    if (f == null) return null;
    return {
      'type': 'foot',
      'host': h.hostId,
      'id': h.id,
      'pos': f.node.footPos,
      'day': f.node.extra['footPosDay'],
    };
  }

  void _restoreFoot() {
    final sn = _tSnap;
    if (sn == null) return;
    final store = context.read<MapStore>();
    final host = store.state.findHost(sn['host'] as String);
    if (host is! MapHost) return;
    if (sn['type'] == 'walker') {
      if (host is! Goal) return;
      void put(String k, Object? v) {
        if (v == null) {
          host.extra.remove(k);
        } else {
          host.extra[k] = v;
        }
      }

      put('walkerPos', sn['pos']);
      put('walkerPlaying', sn['playing']);
    } else {
      final f = findActionNode(host.actions, sn['id'] as String);
      if (f == null) return;
      f.node.footPos = sn['pos'] as double?;
      if (sn['day'] == null) {
        f.node.extra.remove('footPosDay');
      } else {
        f.node.extra['footPosDay'] = sn['day'];
      }
    }
    store.touch();
  }

  /// کشیدنِ انگشت (یک یا دو) از پایین به بالا روی یک پای انیمیشنی → نمای راه‌رفتنِ همان پا
  bool _footSwipeUp() {
    for (final en in _tFoot.entries) {
      final s0 = _tStart[en.key], n = _tNow[en.key];
      if (s0 == null || n == null) continue;
      final d = n - s0;
      if (d.dy < -90 && d.dx.abs() < d.dy.abs() * 0.8) {
        _tiltDone = true;
        _restoreFoot();
        final h = en.value;
        openWalkViewForFoot(
            context, context.read<MapStore>().state, h.type, h.hostId, h.id);
        return true;
      }
    }
    return false;
  }

  void _tiltMove(PointerMoveEvent e) {
    if (!_tNow.containsKey(e.pointer)) return;
    _tNow[e.pointer] = e.position;
    if (_tiltDone) return;
    if (_tFoot.isNotEmpty && _footSwipeUp()) return;
    if (_tNow.length != 2) return;
    final ids = _tNow.keys.toList();
    final a0 = _tStart[ids[0]]!, b0 = _tStart[ids[1]]!;
    final a1 = _tNow[ids[0]]!, b1 = _tNow[ids[1]]!;
    final da = a1 - a0, db = b1 - b0;
    const need = 110.0;
    final up = da.dy < -need && db.dy < -need;
    final straight =
        da.dx.abs() < da.dy.abs() * 0.8 && db.dx.abs() < db.dy.abs() * 0.8;
    final pinch = ((a1 - b1).distance - (a0 - b0).distance).abs() < 70;
    if (up && straight && pinch) {
      _tiltDone = true;
      _openWalkHere();
    }
  }

  void _tiltEnd(PointerEvent e) {
    _tStart.remove(e.pointer);
    _tNow.remove(e.pointer);
    _tFoot.remove(e.pointer);
    if (_tStart.isEmpty) {
      _tiltDone = false;
      _tFoot.clear();
      _tSnap = null;
    }
  }

  /// نمای راه‌رفتن از چشمِ نزدیک‌ترین شاخه به وسطِ صفحه (بدونِ پرسش)
  void _openWalkHere() {
    final v = cam.view;
    if (v.isEmpty) return;
    final focus = cam.screenToWorld(Offset(v.width / 2, v.height / 2));
    final reach = v.shortestSide * 0.7 / cam.scale;
    openWalkViewAt(context, context.read<MapStore>().state, focus, reach);
  }

  /// پالتِ نقشه وقتی آسمانِ خودکار (ساعتِ گوشی) فعال است؛ وگرنه null = تمِ برنامه
  WebPalette? _skyPal;

  @override
  Widget build(BuildContext context) {
    final bgStore = context.watch<BackgroundStore>();
    // با تصویر/ویدیو/رنگِ دلخواهِ کاربر، آسمانِ خودکار کنار می‌رود
    return DayCycleScope(
      enabled: !bgStore.overridesBackdrop,
      paintGround: false,
      builder: (ctx, sky) => _buildMap(ctx, sky),
    );
  }

  Widget _buildMap(BuildContext context, SkyState? sky) {
    final store = context.watch<MapStore>();
    final empty = store.state.goals.isEmpty && store.state.rings.isEmpty;
    final anyOpen = store.anyOpen;
    // رنگ‌ها (روشن/تیره) همیشه از تمِ انتخابیِ کاربر می‌آید؛ ساعت فقط آسمان
    // (خورشید، ماه، ستاره، غروب و گرگ‌ومیش) را نشان می‌دهد.
    _skyPal = null;
    final bgStore = context.watch<BackgroundStore>();
    final themeStore = context.watch<ThemeStore>();
    // تیکِ «تم تاریک» خاموش و انتخابِ دستی نیست ← نقشه با ساعتِ گوشی روشن/تیره
    // می‌شود (روز سفید، طلوع/غروب گرم، شب تیره)؛ در غیر این صورت تمِ کاربر.
    final auto = sky != null && themeStore.isAuto;
    final isDark = auto
        ? sky!.ground.computeLuminance() < 0.4
        : Theme.of(context).brightness == Brightness.dark;
    final wp = isDark ? WebPalette.dark : WebPalette.light;
    final ink = wp.textMain;
    // روشن = سفید (یا رنگِ زمینِ ساعت در حالتِ خودکار)؛ با تصویر/ویدیو/رنگ دلخواه شفاف
    final Color mapBg = bgStore.overridesBackdrop
        ? Colors.transparent
        : auto
            ? sky!.ground
            : (isDark ? Colors.transparent : Colors.white);

    return AnimatedContainer(
      duration: const Duration(seconds: 2),
      color: mapBg,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MapCanvas(
            cam: cam,
            isDark: isDark,
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
          // رنگ‌مایه‌ی ملایمِ آسمان بر پایه‌ی ساعتِ گوشی (سپیده‌دم، غروب و گرگ‌ومیش)
          if (sky != null) ...[
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        sky.top.withValues(
                            alpha: 0.30 *
                                (1 - ((sky.altDeg + 2).abs() / 10))
                                    .clamp(0.0, 1.0)
                                    .toDouble()),
                        sky.bottom.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.6],
                    ),
                  ),
                ),
              ),
            ),
          ],

          // خورشید، ماه و ستاره‌ها طبقِ ساعتِ گوشی روی نقشه (طلوع، غروب، شب)
          if (sky != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _MapSkyPainter(
                      sky, MediaQuery.paddingOf(context).top + 108),
                  size: Size.infinite,
                ),
              ),
            ),

          // هوای تصادفی: گاهی ابری، گاهی بارانی
          if (sky != null)
            Positioned.fill(
              child: SkyWeatherLayer(night: sky.sunA < 0.5),
            ),

          // کشیدنِ دو انگشت از پایین به بالا (مثل کج‌کردنِ نقشه): نما از چشمِ پاها می‌شود.
          // فقط گوش می‌دهد؛ لمس‌های نقشه را نمی‌گیرد.
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _tiltDown,
              onPointerMove: _tiltMove,
              onPointerUp: _tiltEnd,
              onPointerCancel: _tiltEnd,
            ),
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
                        ],
                      ),
                    ),
                    // آسمانِ کوچکِ زنده (خورشید/ماه با ساعتِ گوشی) وسطِ نوار بالا
                    Expanded(
                      child: sky == null
                          ? const SizedBox(height: 46)
                          : Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              child: SizedBox(
                                height: 46,
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _MiniSkyPainter(sky, wp.textDim),
                                    size: Size.infinite,
                                  ),
                                ),
                              ),
                            ),
                    ),
                    _quickMenu(store, anyOpen, isDark, wp),
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

          // ویدیوی گره‌ها روی نقشه
          const MapVideoOverlay(),

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
                        _openWalkHere),
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

  /// منوی کوچکِ بالا: تم، جمع/باز کردنِ شاخه‌ها و راهنما (به‌جای سه دکمه‌ی جدا)
  Widget _quickMenu(MapStore store, bool anyOpen, bool isDark, WebPalette wp) {
    Widget row(IconData icon, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: wp.textDim),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(fontSize: 13.5, color: wp.textMain)),
          ],
        );
    return PopupMenuButton<String>(
      tooltip: 'منو',
      padding: EdgeInsets.zero,
      color: wp.panelBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: wp.panelBorder),
      ),
      onSelected: (v) {
        switch (v) {
          case 'theme':
            context.read<ThemeStore>().setChoice(isDark ? 'light' : 'dark');
          case 'auto':
            context.read<ThemeStore>().setChoice('auto');
          case 'fold':
            store.collapseAll(anyOpen);
          case 'help':
            showHelpDialog(context);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'theme',
          child: row(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              isDark ? 'تم روشن' : 'تم تیره'),
        ),
        if (!context.read<ThemeStore>().isAuto)
          PopupMenuItem<String>(
            value: 'auto',
            child: row(Icons.brightness_auto_outlined,
                'خودکار (طبق ساعت گوشی)'),
          ),
        if (store.hasCollapsible)
          PopupMenuItem<String>(
            value: 'fold',
            child: row(anyOpen ? Icons.unfold_less : Icons.unfold_more,
                anyOpen ? 'جمع کردن شاخه‌ها' : 'باز کردن شاخه‌ها'),
          ),
        PopupMenuItem<String>(
          value: 'help',
          child: row(Icons.help_outline, 'راهنما'),
        ),
      ],
      child: Container(
        width: 30,
        height: 30,
        decoration: ShapeDecoration(
          color: wp.panelBg,
          shape: CircleBorder(side: BorderSide(color: wp.panelBorder)),
        ),
        child: Icon(Icons.more_horiz, size: 18, color: wp.textDim),
      ),
    );
  }

  Widget _circleBtn(Widget child, VoidCallback onTap) {
    final wp = _skyPal ?? WebPalette.of(context);
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

/// آسمانِ کوچکِ نوار بالا: خطِ افق، چند ستاره، و خورشید/ماه روی کمانِ روز و شب
class _MiniSkyPainter extends CustomPainter {
  _MiniSkyPainter(this.s, this.line);
  final SkyState s;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    final base = h * 0.82;
    if (s.starA > 0.01) {
      final p = Paint()..color = line.withValues(alpha: 0.55 * s.starA);
      for (final st in SkyArt.stars.take(14)) {
        canvas.drawCircle(Offset(st[0] * w, st[1] * base * 0.9), 0.9, p);
      }
    }
    if (s.sunA > 0.01) {
      final x = w * (0.1 + 0.8 * s.dayFrac);
      final y = base - (base - 13) * math.sin(math.pi * s.dayFrac);
      SkyArt.sun(canvas, Offset(x, y), s, r: 11);
    }
    if (s.moonA > 0.01) {
      final x = w * (0.1 + 0.8 * s.nightFrac);
      final y = base - (base - 9.5) * math.sin(math.pi * s.nightFrac);
      SkyArt.moon(canvas, Offset(x, y), s, r: 7.5, plain: true);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniSkyPainter old) =>
      old.s != s || old.line != line;
}

/// خورشید، ماه و ستاره‌های بزرگِ روی نقشه (طبق ساعتِ گوشی)؛ لمس را نمی‌گیرد
class _MapSkyPainter extends CustomPainter {
  _MapSkyPainter(this.s, this.top);
  final SkyState s;

  /// بالاترین جای خورشید/ماه (زیرِ نوار بالا)
  final double top;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    if (s.starA > 0.01) {
      SkyArt.starField(canvas, Size(w, h * 0.17), s.starA * 0.85, scale: 0.6);
    }
    final horizon = top + 86;
    if (s.sunA > 0.01) {
      final x = w * (0.12 + 0.76 * s.dayFrac);
      final y = horizon - (horizon - top) * math.sin(math.pi * s.dayFrac);
      SkyArt.sun(canvas, Offset(x, y), s, r: 20);
    }
  }

  @override
  bool shouldRepaint(covariant _MapSkyPainter old) =>
      old.s != s || old.top != top;
}
