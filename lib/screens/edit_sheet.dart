import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../map/draw_utils.dart' show toFa;
import '../map/map_ops.dart';
import '../map/walker_photos.dart';
import '../models/constants.dart';
import '../models/map_models.dart';
import '../state/map_store.dart';
import '../widgets/goal_path_card.dart';
import '../widgets/icon_photo_editor.dart';
import '../widgets/node_voice_field.dart';
import '../widgets/panel_kit.dart';
import '../widgets/web_color_picker.dart';

// ============================================================
// رنگ‌های ثابت (هماهنگ با تم وب)
// ============================================================
const _kBg = Color(0xFFFFFFFF);
const _kCard = Colors.white;
const _kInputBg = Color(0xFFF1F2F8); // --input-bg
const _kGold = Color(0xFF178A7C); // سبز هماهنگ با بقیه‌ی تب‌ها
const _kInk = Color(0xFF000000);
const _kMuted = Color(0xFF5B5F77);
const _kBorder = Color.fromRGBO(23, 138, 124, 0.28); // کادر سبز هماهنگ با تب‌ها
const _kDanger = Color(0xFFE5484D);
const _kMeBaseRadius = 34.0; // اندازه‌ی پیش‌فرض دایره‌ی «من»

// ============================================================
// انواع هدف ویرایش
// ============================================================
sealed class EditTarget {
  const EditTarget();
  String get key;
}

class MeTarget extends EditTarget {
  const MeTarget();
  @override
  String get key => 'me';
}

class GoalTarget extends EditTarget {
  const GoalTarget(this.id);
  final String id;
  @override
  String get key => 'g:$id';
}

class RingTarget extends EditTarget {
  const RingTarget(this.id);
  final String id;
  @override
  String get key => 'r:$id';
}

/// کادر «عکس پاها» — با تپ روی پاها/قدم‌زن نقشه باز می‌شه (همون کادر و اندازه‌ی «من»)
class WalkerPhotosTarget extends EditTarget {
  const WalkerPhotosTarget(this.hostId, this.actionId, this.isWalker);
  final String hostId, actionId;
  final bool isWalker; // true = قدم‌زنِ خودِ هدف، false = پاهای یک شاخه
  @override
  String get key => 'w:$hostId:$actionId';
}

class ActionTarget extends EditTarget {
  const ActionTarget(this.hostId, this.actionId);
  final String hostId, actionId;
  @override
  String get key => 'a:$actionId';
}

Future<void> showEditSheet(BuildContext context, EditTarget target) {
  final store = context.read<MapStore>();

  // همه‌ی کادرهای ویرایش: کادر کوچکِ کناری که از سمت چپ باز می‌شه (مثل مغز)
  {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'بستن',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, a1, a2) {
        final mq = MediaQuery.of(ctx);
        // #panel{ position:fixed; top:0; bottom:64px; left:0; width:min(300px,86vw) }
        final sw = mq.size.width * 0.86;
        final w = sw < 300 ? sw : 300.0;
        final kb = mq.viewInsets.bottom;
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(bottom: kb > 64 ? kb : 64),
            child: SizedBox(
              width: w,
              height: double.infinity,
              child: Material(
                color: Colors.transparent,
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: EditSheet(
                      store: store, initial: target, panel: true),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, _, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(80),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: EditSheet(store: store, initial: target),
    ),
  );
}

// ============================================================
// ویجت اصلی
// ============================================================
class EditSheet extends StatefulWidget {
  const EditSheet({
    super.key,
    required this.store,
    required this.initial,
    this.panel = false,
  });
  final MapStore store;
  final EditTarget initial;

  /// true = کادر کناریِ کوچک (به‌جای صفحه‌ی پایین)
  final bool panel;

  @override
  State<EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<EditSheet> {
  late EditTarget _t = widget.initial;
  final List<EditTarget> _back = [];
  final Map<String, TextEditingController> _ctl = {};
  String? _focusId;

  MapStore get _store => widget.store;
  MapState get _s => _store.state;

  @override
  void dispose() {
    // هر تغییرِ ذخیره‌نشده همین الان نوشته شود (بستن کادر با کشیدن/بیرون‌زدن)
    _store.flushIfDirty();
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _c(String key, String initial) =>
      _ctl.putIfAbsent(key, () => TextEditingController(text: initial));

  void _go(EditTarget t) => setState(() {
        _back.add(_t);
        _t = t;
      });

  void _goBack() => setState(() => _t = _back.removeLast());

  void _edit(VoidCallback fn) {
    setState(fn);
    _store.changed();
  }

  /// مثل [_edit] ولی همان لحظه روی حافظه می‌نویسد (ایموجی/آیکون): با رفرشِ
  /// فوریِ صفحه هم چیزی گم نمی‌شود.
  void _editNow(VoidCallback fn) {
    setState(fn);
    _store.changedNow();
  }

  Future<bool> _confirm(String msg) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        content: Text(msg, style: const TextStyle(color: _kInk)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لغو', style: TextStyle(color: _kMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kGold),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('بله'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ------------------------------------------------------------
  // ساختار کلی
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final body = _body();
    if (body == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const SizedBox(height: 80);
    }
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * (widget.panel ? 0.86 : 0.9),
      ),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: widget.panel
            ? const BorderRadius.horizontal(right: Radius.circular(22))
            : const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: widget.panel
            ? const [BoxShadow(color: Color(0x33000000), blurRadius: 18)]
            : null,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            if (!widget.panel)
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            SizedBox(height: widget.panel ? 2 : 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  if (_back.isNotEmpty)
                    IconButton(
                      onPressed: _goBack,
                      icon: const Icon(Icons.arrow_forward,
                          color: _kInk, size: 22),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints.tightFor(width: 32, height: 32),
                    ),
                  Expanded(
                    child: Text(
                      _title(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _kInk,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: _kMuted, size: 22),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 36, height: 36),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: body,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _title() {
    final t = _t;
    if (t is MeTarget) return 'من';
    if (t is WalkerPhotosTarget) return 'عکس انیمیشن';
    if (t is GoalTarget) {
      final g = _s.findHost(t.id);
      return g is Goal && g.name.isNotEmpty ? g.name : 'هدف';
    }
    if (t is RingTarget) {
      final r = _s.findHost(t.id);
      return r is Ring && r.label.isNotEmpty ? r.label : 'نشانه';
    }
    return '';
  }

  List<Widget>? _body() {
    final t = _t;
    if (t is MeTarget) return _meBody();
    if (t is WalkerPhotosTarget) return _walkerSheetBody(t);
    if (t is GoalTarget) {
      final g = _s.findHost(t.id);
      return g is Goal ? _goalBody(g) : null;
    }
    if (t is RingTarget) {
      final r = _s.findHost(t.id);
      return r is Ring ? _ringBody(r) : null;
    }
    if (t is ActionTarget) {
      final h = _s.findHost(t.hostId);
      if (h is! MapHost) return null;
      final f = findActionNode(h.actions, t.actionId);
      return f == null ? null : _actionBody(h, f.node);
    }
    return null;
  }

  // ------------------------------------------------------------
  // اجزای مشترک
  // ------------------------------------------------------------
  /// کارتِ بخش؛ کلیدش به هدفِ ویرایش وابسته است تا باز/بسته‌بودنِ بخش‌ها
  /// موقع رفتن به یک اقدام دیگر نشت نکند.
  Widget _card({
    required IconData icon,
    required String title,
    required List<Widget> children,
    String? subtitle,
    bool collapsible = false,
  }) =>
      PanelCard(
        key: ValueKey('${_t.key}|$title'),
        icon: icon,
        title: title,
        subtitle: subtitle,
        collapsible: collapsible,
        children: children,
      );

  /// `#panel label.small`: ۱۱px، --text-dim، فاصله‌ی ۶ پایین
  Widget _sectionLabel(String s) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Text(
          s,
          style: const TextStyle(fontSize: 11, color: _kMuted),
        ),
      );

  Widget _textField({
    required String ctlKey,
    required String initial,
    required String label,
    required void Function(String) onChanged,
    int maxLines = 1,
    bool center = false,
    int? maxLength,
    bool autofocus = false,
    TextInputType? keyboard,
  }) {
    const bd = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(9)),
      borderSide: BorderSide(color: _kBorder),
    );
    // در Maghz این‌ها placeholder هستند، نه برچسب
    final isHint =
        label.startsWith('مثلاً') || label.startsWith('چیزی');
    final field = TextField(
      controller: _c(ctlKey, initial),
      autofocus: autofocus,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboard,
      textAlign: center ? TextAlign.center : TextAlign.start,
      textDirection: TextDirection.rtl,
      style: TextStyle(
        fontSize: center ? 22 : (maxLines > 1 ? 13 : 14),
        color: _kInk,
      ),
      onChanged: onChanged,
      decoration: InputDecoration(
        counterText: '',
        hintText: isHint ? label : null,
        hintStyle: const TextStyle(fontSize: 13, color: _kMuted),
        filled: true,
        fillColor: _kInputBg, // --input-bg
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        border: bd,
        enabledBorder: bd,
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(9)),
          borderSide: BorderSide(color: _kGold),
        ),
      ),
    );
    // `label.small`: ۱۱px، --text-dim، فاصله‌ی ۶ از ورودی
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isHint)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label,
                style: const TextStyle(fontSize: 11, color: _kMuted)),
          ),
        field,
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _swatches(
    String? current,
    void Function(String) onPick, {
    List<String> extra = const [],
    VoidCallback? onInherit,
    String inheritText = 'مثل هدف',
  }) {
    final cur = (current ?? '').toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onInherit != null)
          GestureDetector(
            onTap: () => _edit(onInherit),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cur.isEmpty
                    ? _kGold.withAlpha(30)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: cur.isEmpty ? _kGold : _kBorder,
                  width: cur.isEmpty ? 1.5 : 1,
                ),
              ),
              child: Text(
                inheritText,
                style: TextStyle(
                  fontSize: 12,
                  color: cur.isEmpty ? _kGold : _kMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (onInherit != null) const SizedBox(height: 10),
        // همان پالت و ظاهر کارت «ظاهر مسیر هدف»
        GoalColorGrid(
          noSelection: onInherit != null && cur.isEmpty,
          color: hexColor(current, kWebPalette.first),
          extra: [for (final hex in extra) hexColor(hex)],
          onColor: (hex) => _edit(() => onPick(hex)),
        ),
      ],
    );
  }

  /// نمایش تاریخ و ساعت ثبتِ یک گره روی نقشه (جدا برای هر گره).
  /// اگر انتخاب نشده باشد، همان تنظیم کلیِ نقشه اعمال می‌شود.
  Widget _stampCard(Map<String, dynamic> extra) {
    bool val(String key, bool global) {
      final v = extra[key];
      return v is bool ? v : global;
    }

    return _card(
      icon: Icons.schedule_rounded,
      title: 'تاریخ و ساعت روی نقشه',
      collapsible: true,
      children: [
        _switchTile(
          title: 'نمایش تاریخ',
          value: val('showDate', _s.showDateStamps),
          onChanged: (v) => _edit(() => extra['showDate'] = v),
        ),
        _switchTile(
          title: 'نمایش ساعت',
          value: val('showTime', _s.showTimeStamps),
          onChanged: (v) => _edit(() => extra['showTime'] = v),
        ),
      ],
    );
  }

  /// نمایش هاله‌ی دور یک گره (جدا برای هر گره). اگر انتخاب نشده باشد،
  /// همان تنظیم کلیِ نقشه (پیش‌فرض: خاموش) اعمال می‌شود.
  Widget _haloCard(Map<String, dynamic> extra, bool global) {
    final v = extra['showHalo'];
    return _card(
      icon: Icons.blur_circular_rounded,
      title: 'هاله',
      collapsible: true,
      children: [
        _switchTile(
          title: 'نمایش هاله',
          value: v is bool ? v : global,
          onChanged: (b) => _edit(() => extra['showHalo'] = b),
        ),
      ],
    );
  }

  Widget _shapeGrid(String current, void Function(String) onPick,
      {bool inherit = false, String inheritLabel = 'مثل مجموعه'}) {
    return PanelChoiceGrid(
      current: current,
      onPick: (k) => _edit(() => onPick(k)),
      preview: (k, c) => BranchShapePainter(k, c),
      choices: [
        if (inherit) PanelChoice('', inheritLabel),
        for (final e in kBranchStyles.entries) PanelChoice(e.key, e.value),
      ],
    );
  }

  /// اندازه و رنگ نوشته‌ی یک گره (هدف / اقدام / زیراقدام / نشانه).
  /// اگر اندازه‌ی اختصاصی نباشد، همان اندازه‌ی کلیِ تنظیمات نشان داده می‌شود.
  List<Widget> _labelStyleControls({
    required double defaultSize,
    required double? size,
    required void Function(double?) onSize,
    required Map<String, dynamic> extra,
  }) {
    final eff = (size ?? defaultSize).clamp(8.0, 60.0).toDouble();
    return [
      _slider(
        label: 'اندازه‌ی نوشته',
        value: eff,
        min: 8,
        max: 60,
        divisions: 52,
        valueText: size == null
            ? '${toFa(eff.round())} (کلی)'
            : toFa(eff.round()),
        onChanged: (v) => _edit(() => onSize(v.roundToDouble())),
      ),
      if (size != null)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => _edit(() => onSize(null)),
            child: const Text('برگرداندن به اندازه‌ی تنظیمات کلی',
                style: TextStyle(fontSize: 12, color: _kGold)),
          ),
        ),
      const PanelLabel('رنگ نوشته'),
      _swatches(
        (extra['labelColor'] as String?) ?? '',
        (c) => extra['labelColor'] = c,
        onInherit: () => extra.remove('labelColor'),
        inheritText: 'مثل تنظیمات کلی',
        extra: const ['#000000', '#ffffff'],
      ),
    ];
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String valueText,
    required void Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _kInk)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(
                  color: _kGold.withAlpha(24),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(valueText,
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _kGold)),
              ),
            ],
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: _kGold,
            thumbColor: _kGold,
            inactiveTrackColor: _kBorder,
            overlayColor: _kGold.withAlpha(36),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            tickMarkShape: SliderTickMarkShape.noTickMark,
          ),
          child: Slider(
            min: min,
            max: max,
            divisions: divisions,
            value: value.clamp(min, max).toDouble(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  /// کلیدِ روشن/خاموش. پیش‌فرض تخت و جمع‌وجور (داخل کارت‌ها)؛
  /// با [boxed] کادر مستقل می‌گیرد.
  /// حالت انیمیشن: متحرک (می‌رود و می‌آید) / ثابت (فقط ثبت، بدون حرکت) / پنهان
  Widget _walkerModeTile(Map<String, dynamic> ex) {
    final cur = ex['showWalker'] == false
        ? 'hidden'
        : (ex['walkerMode'] == 'still' ? 'still' : 'moving');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text('حالت انیمیشن',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _kInk)),
        ),
        SegmentedButton<String>(
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
          ),
          segments: const [
            ButtonSegment(value: 'moving', label: Text('متحرک')),
            ButtonSegment(value: 'still', label: Text('ثابت')),
            ButtonSegment(value: 'hidden', label: Text('نمایش نده')),
          ],
          selected: {cur},
          onSelectionChanged: (s) => _edit(() {
            final v = s.first;
            ex.remove('showWalker');
            ex.remove('walkerMode');
            if (v == 'still') ex['walkerMode'] = 'still';
            if (v == 'hidden') ex['showWalker'] = false;
          }),
        ),
      ],
    );
  }

  Widget _switchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool boxed = false,
  }) {
    final row = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kInk)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle,
                      style: const TextStyle(fontSize: 11, color: _kMuted)),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // کلیدِ کوچک
        SizedBox(
          width: 38,
          height: 24,
          child: FittedBox(
            child: Switch(
              value: value,
              activeThumbColor: Colors.white,
              activeTrackColor: _kGold,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFD9DDE8),
              trackOutlineColor:
                  const WidgetStatePropertyAll(Colors.transparent),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
    if (!boxed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: row,
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: row,
    );
  }

  Widget _bottomActions({
    required String saveLabel,
    required VoidCallback onSave,
    String? deleteLabel,
    Future<void> Function()? onDelete,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Row(
        children: [
          if (deleteLabel != null)
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _kDanger),
                  foregroundColor: _kDanger,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onDelete,
                child: Text(deleteLabel,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          if (deleteLabel != null) const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _kGold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onSave,
              child: Text(saveLabel,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  /// صدای تاکیدی (ضبط/پخش) ذخیره‌شده در extra
  Widget _voiceField(Map<String, dynamic> ex, String key, String idKey,
      {String label = ''}) {
    final cur = ex[key];
    return NodeVoiceField(
      key: ValueKey('voice-$idKey-$key'),
      label: label,
      initial: cur is String ? cur : '',
      onChanged: (v) => _editNow(() {
        if (v.isEmpty) {
          ex.remove(key);
        } else {
          ex[key] = v;
        }
      }),
    );
  }

  // ============================================================
  // من
  // ============================================================
  List<Widget> _meBody() {
    final me = _s.me;
    return [
      _card(
        icon: Icons.person_rounded,
        title: 'من',
        children: [
          _textField(
            ctlKey: 'me:name',
            initial: me.name,
            label: 'اسم',
            onChanged: (v) => _edit(() => me.name = v),
          ),
          const SizedBox(height: 4),
          MultiPhotoField(
            initial: me.images,
            onChange: (imgs) => _edit(() => me.images = imgs),
            initialEmoji: (me.extra['emoji'] as String? ?? '').trim(),
            onEmojiChanged: (e) => _editNow(() {
              final t = e.trim();
              if (t.isEmpty) {
                me.extra.remove('emoji');
              } else {
                me.extra['emoji'] = t;
              }
            }),
          ),
          _voiceField(me.extra, 'voice', 'me'),
          _slider(
            label: 'اندازه',
            value: (me.radius / _kMeBaseRadius).clamp(0.6, 10.0).toDouble(),
            min: 0.6,
            max: 10.0,
            divisions: 47,
            valueText: '${(me.radius / _kMeBaseRadius * 100).round()}٪',
            onChanged: (v) => _edit(() => me.radius = _kMeBaseRadius * v),
          ),
          const SizedBox(height: 8),
          const PanelLabel('رنگ'),
          _swatches(me.color, (c) => me.color = c),
        ],
      ),
      _haloCard(me.extra, false),
      _bottomActions(
        saveLabel: 'ذخیره',
        onSave: () {
          _store.changedNow();
          Navigator.pop(context);
        },
      ),
    ];
  }

  // ============================================================
  // عکس پاها — همون کادرِ «من» (نام/رنگ نداره، فقط عکس‌ها + ذخیره)
  // ============================================================
  List<Widget>? _walkerSheetBody(WalkerPhotosTarget t) {
    final Map<String, dynamic> ex;
    final ActionNode? act;
    final host = _s.findHost(t.hostId);
    if (t.isWalker) {
      if (host is! Goal) return null;
      act = null;
      ex = host.extra;
    } else {
      if (host is! MapHost) return null;
      final found = findActionNode(host.actions, t.actionId);
      if (found == null) return null;
      act = found.node;
      ex = found.node.extra;
    }
    return [
      WalkerPhotoField(
        initial: walkerPhotosOf(ex),
        initialEmoji: walkerEmojiOf(ex),
        onEmojiChanged: (e) => _editNow(() => setWalkerEmoji(ex, e)),
        onChanged: (v) => _edit(() {
          setWalkerPhotos(ex, v);
          if (v.isNotEmpty) {
            final a0 = act;
            if (a0 != null) {
              a0.footPlaying = true;
              a0.footPos = null;
            } else {
              ex['walkerPlaying'] = true;
              ex.remove('walkerPos');
            }
          }
        }),
      ),
      _walkerEmojiSizeSlider(ex),
      const SizedBox(height: 8),
      _walkerModeTile(ex),
      const SizedBox(height: 8),
      _voiceField(ex, 'walkerVoice', 'walker:${t.hostId}:${t.actionId}'),
      ..._walkerHaloControls(ex),
      const SizedBox(height: 8),
      _sectionLabel('رنگ انیمیشن'),
      _swatches(
        (ex['footColor'] as String?) ?? '',
        (c) => ex['footColor'] = c,
        onInherit: () => ex.remove('footColor'),
      ),
      if (act != null) ...[
        _slider(
          label: 'اندازه‌ی انیمیشن و دایره‌ی متصل',
          value: (act.footSize ?? 1.0).clamp(kWalkerSizeMin, kFootSizeMax).toDouble(),
          min: kWalkerSizeMin,
          max: kFootSizeMax,
          divisions: kWalkerSizeDivisions,
          valueText: '${((act.footSize ?? 1.0) * 100).round()}٪',
          onChanged: (v) => _edit(() => act!.footSize = v),
        ),
        _slider(
          label: 'اندازه‌ی قدم‌های ثبت‌شده',
          value: ((act.extra['pastFootSize'] as num?)?.toDouble() ?? 0.6)
              .clamp(0.2, 6.0)
              .toDouble(),
          min: 0.2,
          max: 6.0,
          divisions: 58,
          valueText:
              '${(((act.extra['pastFootSize'] as num?)?.toDouble() ?? 0.6) * 100).round()}٪',
          onChanged: (v) => _edit(() => act!.extra['pastFootSize'] = v),
        ),
        _slider(
          label: 'سرعت قدم زدن',
          value: (act.footSpeed ?? 1.0).clamp(0.2, 3.0).toDouble(),
          min: 0.2,
          max: 3.0,
          divisions: 28,
          valueText: '${(act.footSpeed ?? 1.0).toStringAsFixed(1)}×',
          onChanged: (v) => _edit(() => act!.footSpeed = v),
        ),
      ] else ...[
        _slider(
          label: 'اندازه‌ی انیمیشن و دایره‌ی متصل',
          value: ((ex['walkerSize'] as num?)?.toDouble() ?? 1.0)
              .clamp(kWalkerSizeMin, kWalkerSizeMax)
              .toDouble(),
          min: kWalkerSizeMin,
          max: kWalkerSizeMax,
          divisions: kWalkerSizeDivisions,
          valueText:
              '${(((ex['walkerSize'] as num?)?.toDouble() ?? 1.0) * 100).round()}٪',
          onChanged: (v) => _edit(() => ex['walkerSize'] = v),
        ),
        _slider(
          label: 'سرعت قدم زدن',
          value: ((ex['walkerSpeed'] as num?)?.toDouble() ?? 1.5)
              .clamp(0.3, 4.0)
              .toDouble(),
          min: 0.3,
          max: 4.0,
          divisions: 37,
          valueText:
              '${((ex['walkerSpeed'] as num?)?.toDouble() ?? 1.5).toStringAsFixed(1)}×',
          onChanged: (v) => _edit(() => ex['walkerSpeed'] = v),
        ),
      ],
      _bottomActions(
        saveLabel: 'ذخیره',
        onSave: () {
          _store.changedNow();
          Navigator.pop(context);
        },
      ),
    ];
  }

  /// اندازه‌ی نوشته/ایکونِ انیمیشن (همان کادر «ایموجی یا نوشته»)
  Widget _walkerEmojiSizeSlider(Map<String, dynamic> ex) {
    final v = ((ex['walkerEmojiSize'] as num?)?.toDouble() ?? 1.0)
        .clamp(kEmojiSizeMin, 3.0)
        .toDouble();
    return _slider(
      label: 'اندازه‌ی نوشته و ایکون',
      value: v,
      min: kEmojiSizeMin,
      max: 3.0,
      divisions: 29,
      valueText: '${(v * 100).round()}٪',
      onChanged: (x) => _edit(() => ex['walkerEmojiSize'] = x),
    );
  }

  /// هاله‌ی دور انیمیشن (پا و دایره‌ی متصل): نمایش و اندازه، جدا برای هر هدف/شاخه/زیرشاخه
  List<Widget> _walkerHaloControls(Map<String, dynamic> ex) {
    final on = ex['walkerHalo'] != false;
    final scale = ((ex['walkerHaloScale'] as num?)?.toDouble() ?? 1.0)
        .clamp(0.3, 2.5)
        .toDouble();
    return [
      _switchTile(
        boxed: true,
        title: 'نمایش هاله‌ی انیمیشن',
        value: on,
        onChanged: (v) => _edit(() {
          if (v) {
            ex.remove('walkerHalo');
          } else {
            ex['walkerHalo'] = false;
          }
        }),
      ),
      if (on)
        _slider(
          label: 'اندازه‌ی هاله‌ی انیمیشن',
          value: scale,
          min: 0.3,
          max: 2.5,
          divisions: 22,
          valueText: '${(scale * 100).round()}٪',
          onChanged: (v) => _edit(() => ex['walkerHaloScale'] = v),
        ),
    ];
  }

  // ============================================================
  // هدف
  // ============================================================
  List<Widget> _goalBody(Goal g) {
    final walkerSize = ((g.extra['walkerSize'] as num?)?.toDouble() ?? 1.0);
    return [
      _card(
        icon: Icons.flag_rounded,
        title: 'هدف',
        children: [
          _textField(
            ctlKey: 'goal:${g.id}:name',
            initial: g.name,
            label: 'اسم هدف',
            onChanged: (v) => _edit(() => g.name = v),
          ),
          const PanelLabel('آیکون و عکس'),
          IconPhotoEditor(
            initialIcon: g.icon,
            initialImages: g.images,
            initialScale: g.iconScale,
            onChange: (icon, images, scale) => _editNow(() {
              g.icon = icon;
              g.images = images;
              g.iconScale = scale;
            }),
          ),
          _voiceField(g.extra, 'voice', 'goal:${g.id}'),
        ],
      ),
      _card(
        icon: Icons.text_fields_rounded,
        title: 'دایره و نوشته‌ی هدف',
        collapsible: true,
        children: [
          _slider(
            label: 'اندازه‌ی دایره',
            value: g.radius.clamp(12.0, 90.0).toDouble(),
            min: 12,
            max: 90,
            divisions: 78,
            valueText: '${(g.radius / 20 * 100).round()}٪',
            onChanged: (v) => _edit(() => g.radius = v.roundToDouble()),
          ),
          ..._labelStyleControls(
            defaultSize: _s.fontSize,
            size: g.labelSize,
            onSize: (v) => g.labelSize = v,
            extra: g.extra,
          ),
        ],
      ),
      _stampCard(g.extra),
      // رنگ هدف + نوع خط + ضخامت، با پیش‌نمایش زنده‌ی مسیر
      GoalPathCard(
        color: g.color,
        width: g.trunkWidth,
        styleKey: g.trunkStyle,
        onColor: (hex) => _edit(() => g.color = hex),
        onWidth: (w) => _edit(() => g.trunkWidth = w),
        onStyle: (v) => _edit(() => g.trunkStyle = v),
        onReset: () => _edit(() {
          g.trunkWidth = 0;
          g.trunkStyle = '';
        }),
      ),
      ..._branchesSection(g),
      _card(
        icon: Icons.directions_walk_rounded,
        title: 'انیمیشن روی مسیر',
        collapsible: true,
        children: [
          _walkerModeTile(g.extra),
          const SizedBox(height: 10),
          WalkerPhotoField(
            initial: walkerPhotosOf(g.extra),
            initialEmoji: walkerEmojiOf(g.extra),
            onEmojiChanged: (e) => _editNow(() => setWalkerEmoji(g.extra, e)),
            onChanged: (v) => _edit(() {
              setWalkerPhotos(g.extra, v);
              if (v.isNotEmpty) {
                g.extra['walkerPlaying'] = true;
                g.extra.remove('walkerPos');
              }
            }),
          ),
          _walkerEmojiSizeSlider(g.extra),
          const SizedBox(height: 6),
          _slider(
            label: 'اندازه‌ی انیمیشن و دایره‌ی متصل',
            value: walkerSize.clamp(kWalkerSizeMin, kWalkerSizeMax),
            min: kWalkerSizeMin,
            max: kWalkerSizeMax,
            divisions: kWalkerSizeDivisions,
            valueText: '${(walkerSize * 100).round()}٪',
            onChanged: (v) => _edit(() => g.extra['walkerSize'] = v),
          ),
          _voiceField(g.extra, 'walkerVoice', 'walker:${g.id}'),
          ..._walkerHaloControls(g.extra),
        ],
      ),
      _switchTile(
        boxed: true,
        title: 'به این هدف رسیدم',
        subtitle: 'روی نقشه از من می‌پرسه چه حسی دارم',
        value: g.reached,
        onChanged: (v) => _edit(() {
          g.reached = v;
          if (v) {
            g.extra['reachedAt'] = DateTime.now().millisecondsSinceEpoch;
          } else {
            g.extra.remove('reachedAt');
          }
        }),
      ),
      _bottomActions(
        saveLabel: 'ذخیره',
        onSave: () {
          _store.changedNow();
          Navigator.pop(context);
        },
        deleteLabel: 'حذف هدف',
        onDelete: () async {
          if (!await _confirm('این هدف و همه‌ی اقدام‌هایش حذف بشه؟')) return;
          _store.deleteGoal(g.id);
          if (mounted) Navigator.pop(context);
        },
      ),
    ];
  }

  // ============================================================
  // حلقه (نشانه)
  // ============================================================
  List<Widget> _ringBody(Ring r) {
    return [
      _card(
        icon: Icons.stars_rounded,
        title: 'نشانه',
        children: [
          _textField(
            ctlKey: 'ring:${r.id}:label',
            initial: r.label,
            label: 'عنوان نشانه',
            onChanged: (v) => _edit(() => r.label = v),
          ),
          const PanelLabel('آیکون و عکس'),
          IconPhotoEditor(
            initialIcon: r.icon,
            initialImages: r.images,
            initialScale: r.iconScale,
            onChange: (icon, images, scale) => _editNow(() {
              r.icon = icon.isEmpty ? '🌟' : icon;
              r.images = images;
              r.iconScale = scale;
            }),
          ),
          _voiceField(r.extra, 'voice', 'ring:${r.id}'),
          const PanelLabel('یادداشت'),
          _textField(
            ctlKey: 'ring:${r.id}:note',
            initial: r.note,
            label: 'چیزی که حس می‌کنی',
            onChanged: (v) => _edit(() => r.note = v),
            maxLines: 2,
          ),
        ],
      ),
      _card(
        icon: Icons.palette_rounded,
        title: 'ظاهر نشانه',
        children: [
          _slider(
            label: 'اندازه‌ی دایره',
            value: r.radius.clamp(16.0, 120.0).toDouble(),
            min: 16,
            max: 120,
            divisions: 52,
            valueText: '${(r.radius / 30 * 100).round()}٪',
            onChanged: (v) => _edit(() => r.radius = v),
          ),
          const PanelLabel('رنگ'),
          _swatches(r.color, (c) => r.color = c, extra: const [kRingColor]),
        ],
      ),
      _haloCard(r.extra, false),
      _card(
        icon: Icons.text_fields_rounded,
        title: 'نوشته‌ی نشانه',
        collapsible: true,
        children: [
          ..._labelStyleControls(
            defaultSize: _s.fontSize - 2,
            size: r.labelSize,
            onSize: (v) => r.labelSize = v,
            extra: r.extra,
          ),
        ],
      ),
      ..._branchesSection(r),
      _bottomActions(
        saveLabel: 'ذخیره',
        onSave: () {
          _store.changedNow();
          Navigator.pop(context);
        },
        deleteLabel: 'حذف نشانه',
        onDelete: () async {
          if (!await _confirm('این نشانه حذف بشه؟')) return;
          _store.deleteRing(r.id);
          if (mounted) Navigator.pop(context);
        },
      ),
    ];
  }

  // ============================================================
  // اقدام (اکشن)
  // ============================================================
  List<Widget> _actionBody(MapHost host, ActionNode a) {
    final footPlaying = a.footPlaying;
    return [
      _card(
        icon: Icons.eco_rounded,
        title: 'اقدام',
        children: [
          _textField(
            ctlKey: 'node:${a.id}',
            initial: a.text,
            label: 'متن اقدام',
            onChanged: (v) => _edit(() => a.text = v),
          ),
          const PanelLabel('عکس'),
          IconPhotoEditor(
            supportsIcon: false,
            supportsScale: false,
            initialIcon: '',
            initialImages: a.images,
            initialScale: 1,
            onChange: (_, images, __) => _edit(() => a.images = images),
          ),
          _voiceField(a.extra, 'voice', 'node:${a.id}'),
        ],
      ),
      _card(
        icon: Icons.palette_rounded,
        title: 'ظاهر اقدام',
        children: [
          const PanelLabel('رنگ'),
          _swatches(a.color, (c) => a.color = c,
              onInherit: () => a.color = null),
          const PanelLabel('شکل خط'),
          _shapeGrid(a.style, (v) => a.style = v,
              inherit: true, inheritLabel: 'مثل هدف'),
          const SizedBox(height: 4),
          _slider(
            label: 'ضخامت',
            value: a.weight.clamp(1.0, 10.0).toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            valueText: toFa(a.weight.round()),
            onChanged: (v) => _edit(() => a.weight = v.roundToDouble()),
          ),
          _slider(
            label: 'اندازه‌ی دایره‌ی روتین',
            value: ((a.extra['circleScale'] as num?)?.toDouble() ?? 1.0)
                .clamp(0.3, 8.0)
                .toDouble(),
            min: 0.3,
            max: 8.0,
            divisions: 77,
            valueText:
                '${(((a.extra['circleScale'] as num?)?.toDouble() ?? 1.0) * 100).round()}٪',
            onChanged: (v) => _edit(() => a.extra['circleScale'] = v),
          ),
        ],
      ),
      _card(
        icon: Icons.text_fields_rounded,
        title: 'نوشته‌ی اقدام',
        collapsible: true,
        children: [
          ..._labelStyleControls(
            defaultSize: _s.fontSize,
            size: a.labelSize,
            onSize: (v) => a.labelSize = v,
            extra: a.extra,
          ),
        ],
      ),
      _stampCard(a.extra),
      _switchTile(
        boxed: true,
        title: 'این یه کار روتینه',
        subtitle: 'هر روز تکرار می‌شه، هفته‌ای یه بار نگاه کن',
        value: a.isRoutine,
        onChanged: (v) => _edit(() => a.isRoutine = v),
      ),
      _card(
        icon: Icons.directions_walk_rounded,
        title: 'قدم روی مسیر 👣',
        collapsible: true,
        children: [
      _walkerModeTile(a.extra),
      _slider(
        label: 'اندازه‌ی قدم و دایره‌ی متصل',
        value: (a.footSize ?? 1.0).clamp(kWalkerSizeMin, kFootSizeMax),
        min: kWalkerSizeMin,
        max: kFootSizeMax,
        divisions: kWalkerSizeDivisions,
        valueText: '${((a.footSize ?? 1.0) * 100).round()}٪',
        onChanged: (v) => _edit(() => a.footSize = v),
      ),
      _slider(
        label: 'اندازه‌ی قدم‌های ثبت‌شده',
        value: ((a.extra['pastFootSize'] as num?)?.toDouble() ?? 0.6)
            .clamp(0.2, 6.0)
            .toDouble(),
        min: 0.2,
        max: 6.0,
        divisions: 58,
        valueText:
            '${(((a.extra['pastFootSize'] as num?)?.toDouble() ?? 0.6) * 100).round()}٪',
        onChanged: (v) => _edit(() => a.extra['pastFootSize'] = v),
      ),
      _slider(
        label: 'سرعت قدم زدن (بالاتر = سریع‌تر)',
        value: (a.footSpeed ?? 1.0).clamp(0.2, 3.0),
        min: 0.2,
        max: 3.0,
        divisions: 28,
        valueText: '${(a.footSpeed ?? 1.0).toStringAsFixed(1)}×',
        onChanged: (v) => _edit(() => a.footSpeed = v),
      ),
      Container(
        margin: const EdgeInsets.only(top: 6, bottom: 4),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: footPlaying
                ? const Color(0xFFE5484D)
                : const Color(0xFF0F5B53),
            side: BorderSide(
              color: footPlaying
                  ? const Color(0xFFE5484D)
                  : const Color(0xFF63D6A8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => _edit(() => a.footPlaying = !a.footPlaying),
          icon: Icon(
            footPlaying
                ? Icons.pause_circle_outline
                : Icons.play_circle_outline,
            size: 20,
          ),
          label: Text(
            footPlaying ? 'توقف قدم' : 'شروع حرکت قدم',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      const PanelLabel('عکس انیمیشن'),
      WalkerPhotoField(
        initial: walkerPhotosOf(a.extra),
        initialEmoji: walkerEmojiOf(a.extra),
        onEmojiChanged: (e) => _editNow(() => setWalkerEmoji(a.extra, e)),
        onChanged: (v) => _edit(() {
          setWalkerPhotos(a.extra, v);
          if (v.isNotEmpty) {
            a.footPlaying = true;
            a.footPos = null;
          }
        }),
      ),
      _walkerEmojiSizeSlider(a.extra),
      _voiceField(a.extra, 'walkerVoice', 'walker:${a.id}'),
      ..._walkerHaloControls(a.extra),
      const Padding(
        padding: EdgeInsets.only(top: 4, bottom: 4),
        child: Text(
          'می‌تونی قدم رو با انگشت روی نقشه بگیری و بکشی. با یک تپ روی قدم یا دایره‌ی جلوش کادر عکس‌ها باز می‌شه؛ نگه‌داشتن روش حرکت/توقفش می‌کنه.',
          style: TextStyle(fontSize: 11, color: _kMuted, height: 1.6),
        ),
      ),

        ],
      ),
      // زیراقدام‌ها: فقط یک کادرِ «+» (بدون نوشته)
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ..._tree(host, a.children, 0),
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  final c = _store.addSubBranch(host, a);
                  setState(() => _focusId = c.id);
                },
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kGold, width: 1.2),
                  ),
                  child: const Icon(Icons.add_rounded, size: 24, color: _kGold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _kMuted,
                side: const BorderSide(color: _kBorder),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                resetBranchPos(a);
                _store.changed();
                _store.toast?.call('اقدام به جای اولش برگشت');
              },
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('برگرداندن به جای اول',
                  style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
      _bottomActions(
        saveLabel: 'ذخیره',
        onSave: () {
          _store.changedNow();
          Navigator.pop(context);
        },
        deleteLabel: 'حذف',
        onDelete: () async {
          if (!await _confirm('این اقدام حذف بشه؟')) return;
          _store.deleteAction(host.id, a.id);
          if (!mounted) return;
          if (_back.isNotEmpty) {
            _goBack();
          } else {
            Navigator.pop(context);
          }
        },
      ),
    ];
  }

  // ------------------------------------------------------------
  // لیست اقدامات
  // ------------------------------------------------------------
  List<Widget> _branchesSection(MapHost host) {
    return [
      _card(
        icon: Icons.account_tree_rounded,
        title: 'اقدامات',
        subtitle: 'کارهای کوچکی که تو را به اینجا می‌رسانند. با ⚙ جزئیات هر اقدام را عوض کن.',
        children: [
          if (host is Goal)
            _shapeGrid(host.branchStyle,
                (v) => host.branchStyle = v.isEmpty ? 'organic' : v)
          else if (host is Ring)
            _shapeGrid(host.branchStyle,
                (v) => host.branchStyle = v.isEmpty ? 'organic' : v),
          const SizedBox(height: 10),
          if (host.actions.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('هنوز اقدامی نیست.',
                  style: TextStyle(color: _kMuted, fontSize: 12)),
            ),
          ..._tree(host, host.actions, 0),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _kGold,
                side: const BorderSide(color: _kGold),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final a = _store.addBranch(host);
                setState(() => _focusId = a.id);
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('افزودن اقدام',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _tree(MapHost host, List<ActionNode> list, int depth) {
    final out = <Widget>[];
    for (final a in list) {
      out.add(Padding(
        padding: EdgeInsetsDirectional.only(start: depth * 14.0, top: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: hexColor(
                    a.color,
                    hexColor(host.color, hexColor(kPalette[0])),
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _c('node:${a.id}', a.text),
                  autofocus: _focusId == a.id,
                  onChanged: (v) {
                    a.text = v;
                    _store.changed();
                  },
                  style: const TextStyle(fontSize: 13, color: _kInk),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'متن اقدام',
                    hintStyle: TextStyle(color: _kMuted, fontSize: 12.5),
                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 30, height: 30),
                icon: const Icon(Icons.tune, size: 18, color: _kMuted),
                onPressed: () => _go(ActionTarget(host.id, a.id)),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 30, height: 30),
                icon: const Icon(Icons.close, size: 18, color: _kDanger),
                onPressed: () async {
                  if (!await _confirm('این اقدام حذف بشه؟')) {
                    return;
                  }
                  _store.deleteAction(host.id, a.id);
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
        ),
      ));
      out.addAll(_tree(host, a.children, depth + 1));
    }
    return out;
  }
}
