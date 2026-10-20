import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../map/draw_utils.dart' show toFa;
import '../map/map_ops.dart';
import '../map/walker_photos.dart';
import '../models/constants.dart';
import '../models/map_models.dart';
import '../state/map_store.dart';
import '../widgets/icon_photo_editor.dart';
import '../widgets/web_color_picker.dart';

// ============================================================
// رنگ‌های ثابت (هماهنگ با تم وب)
// ============================================================
const _kBg = Color(0xFFFFFFFF);
const _kCard = Colors.white;
const _kInputBg = Color(0xFFF1F2F8); // --input-bg
const _kGold = Color(0xFFC9962B);
const _kInk = Color(0xFF000000);
const _kMuted = Color(0xFF5B5F77);
const _kBorder = Color.fromRGBO(20, 24, 50, 0.10); // --panel-border
const _kDanger = Color(0xFFE5484D);

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

  String _hexOf(Color c) {
    int v(double x) => (x * 255).round().clamp(0, 255);
    return '#${v(c.r).toRadixString(16).padLeft(2, '0')}'
        '${v(c.g).toRadixString(16).padLeft(2, '0')}'
        '${v(c.b).toRadixString(16).padLeft(2, '0')}';
  }

  Widget _swatches(
    String? current,
    void Function(String) onPick, {
    List<String> extra = const [],
    VoidCallback? onInherit,
    bool settingsStyle = false, // مثل «رنگ نوشته‌ها» در تنظیمات: بدون قطره‌چکان
  }) {
    final cur = (current ?? '').toLowerCase();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
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
                  width: cur.isEmpty ? 2 : 1.5,
                ),
              ),
              child: Text(
                'مثل هدف',
                style: TextStyle(
                  fontSize: 12,
                  color: cur.isEmpty ? _kGold : _kMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        // همان پالت و دیالوگ رنگ بخش «تنظیمات»
        WebColorPicker(
          value: hexColor(current, kWebPalette.first),
          showCustom: !settingsStyle,
          palette: [
            ...kWebPalette,
            for (final hex in extra) hexColor(hex),
          ],
          onChanged: (c) => _edit(() => onPick(_hexOf(c))),
        ),
        if (settingsStyle)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: hexColor(current, kWebPalette.first),
                  shape: BoxShape.circle,
                  border: Border.all(color: _kBorder, width: 1.5),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'رنگ انتخابی: ${cur.isNotEmpty ? cur : _hexOf(kWebPalette.first)}',
                style: const TextStyle(fontSize: 11.5, color: _kMuted),
              ),
            ],
          )
        else if (current != null && current.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'رنگ انتخابی: ${current.toLowerCase()}',
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 11.5, color: _kMuted),
            ),
          ),
      ],
    );
  }

  Widget _shapeGrid(String current, void Function(String) onPick,
      {bool inherit = false}) {
    const _icons = {
      'organic': Icons.gesture,
      'straight': Icons.trending_flat,
      'curve': Icons.trending_up,
      'wave': Icons.waves,
      'elbow': Icons.turn_right,
      'step': Icons.stairs,
      'zigzag': Icons.show_chart,
      '': Icons.auto_awesome,
    };
    final keys = <String>[
      if (inherit) '',
      ...kBranchStyles.keys,
    ];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.1,
      children: [
        for (final k in keys)
          GestureDetector(
            onTap: () => _edit(() => onPick(k)),
            child: Container(
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: current == k ? _kGold : _kBorder,
                  width: current == k ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _icons[k] ?? Icons.help_outline,
                    size: 28,
                    color: current == k ? _kGold : _kMuted,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    k.isEmpty ? 'مثل مجموعه' : (kBranchStyles[k] ?? k),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight:
                          current == k ? FontWeight.w700 : FontWeight.w500,
                      color: current == k ? _kGold : _kInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
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
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kMuted)),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _kGold.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(valueText,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kGold)),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _kGold,
            thumbColor: _kGold,
            inactiveTrackColor: _kBorder,
            overlayColor: _kGold.withAlpha(40),
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

  Widget _switchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _kInk)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11.5, color: _kMuted)),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: _kGold,
            onChanged: onChanged,
          ),
        ],
      ),
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

  // ============================================================
  // من
  // ============================================================
  List<Widget> _meBody() {
    final me = _s.me;
    return [
      _textField(
        ctlKey: 'me:name',
        initial: me.name,
        label: 'اسم',
        onChanged: (v) => _edit(() => me.name = v),
      ),
      _swatches(me.color, (c) => me.color = c),
      _sectionLabel('حال و هوای این فرکانس (اختیاری)'),
      _textField(
        ctlKey: 'me:note',
        initial: me.note,
        label: 'مثلاً: آرامش، اطمینان، شوق...',
        onChanged: (v) => _edit(() => me.note = v),
        maxLines: 3,
      ),
      const SizedBox(height: 16),
      MultiPhotoField(
        initial: me.images,
        onChange: (imgs) => _edit(() => me.images = imgs),
      ),
      _bottomActions(
        saveLabel: 'ذخیره',
        onSave: () {
          _store.changed();
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
      const SizedBox(height: 8),
      _sectionLabel('رنگ انیمیشن'),
      _swatches(
        (ex['footColor'] as String?) ?? '',
        (c) => ex['footColor'] = c,
        onInherit: () => ex.remove('footColor'),
      ),
      if (act != null) ...[
        _slider(
          label: 'اندازه‌ی انیمیشن',
          value: (act.footSize ?? 1.0).clamp(0.4, 2.5).toDouble(),
          min: 0.4,
          max: 2.5,
          divisions: 21,
          valueText: '${((act.footSize ?? 1.0) * 100).round()}٪',
          onChanged: (v) => _edit(() => act!.footSize = v),
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
        _switchTile(
          title: 'در حال حرکت',
          subtitle: 'روشن = انیمیشن فعال است',
          value: act.footPlaying,
          onChanged: (v) => _edit(() => act!.footPlaying = v),
        ),
      ] else ...[
        _slider(
          label: 'اندازه‌ی انیمیشن و دایره‌ی متصل',
          value: ((ex['walkerSize'] as num?)?.toDouble() ?? 1.0)
              .clamp(0.4, 3.0)
              .toDouble(),
          min: 0.4,
          max: 3.0,
          divisions: 26,
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
        _switchTile(
          title: 'در حال حرکت',
          subtitle: 'روشن = قدم‌زن راه می‌ره',
          value: ex['walkerPlaying'] as bool? ?? true,
          onChanged: (v) => _edit(() => ex['walkerPlaying'] = v),
        ),
      ],
      _bottomActions(
        saveLabel: 'ذخیره',
        onSave: () {
          _store.changed();
          Navigator.pop(context);
        },
      ),
    ];
  }

  // ============================================================
  // هدف
  // ============================================================
  List<Widget> _goalBody(Goal g) {
    return [
      _sectionLabel('عکس انیمیشن'),
      WalkerPhotoField(
        initial: walkerPhotosOf(g.extra),
        onChanged: (v) => _edit(() {
          setWalkerPhotos(g.extra, v);
          if (v.isNotEmpty) {
            g.extra['walkerPlaying'] = true;
            g.extra.remove('walkerPos');
          }
        }),
      ),
      _slider(
        label: 'اندازه‌ی انیمیشن و دایره‌ی متصل',
        value: ((g.extra['walkerSize'] as num?)?.toDouble() ?? 1.0)
            .clamp(0.4, 3.0),
        min: 0.4,
        max: 3.0,
        divisions: 26,
        valueText:
            '${(((g.extra['walkerSize'] as num?)?.toDouble() ?? 1.0) * 100).round()}٪',
        onChanged: (v) => _edit(() => g.extra['walkerSize'] = v),
      ),
      _textField(
        ctlKey: 'goal:${g.id}:name',
        initial: g.name,
        label: 'اسم هدف',
        onChanged: (v) => _edit(() => g.name = v),
      ),
      _sectionLabel('آیکون و عکس'),
      IconPhotoEditor(
        initialIcon: g.icon,
        initialImages: g.images,
        initialScale: g.iconScale,
        onChange: (icon, images, scale) => _edit(() {
          g.icon = icon.isEmpty ? '🎯' : icon;
          g.images = images;
          g.iconScale = scale;
        }),
      ),
      _swatches(g.color, (c) => g.color = c, settingsStyle: true),
      _switchTile(
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
      // ترتیب و متن‌ها مثل Maghz: اول خطِ مسیر (#trunk-block)، بعد شکل شاخه‌ها
      _sectionLabel('نوع خط مسیر این هدف (خطی که از «من» تا هدف کشیده می‌شه)'),
      _trunkGrid(g),
      _sectionLabel('شکل مسیر'),
      _shapeGrid(g.branchStyle, (v) => g.branchStyle = v.isEmpty ? 'organic' : v),
      ..._branchesSection(g),
      _bottomActions(
        saveLabel: 'ذخیره',
        onSave: () {
          _store.changed();
          Navigator.pop(context);
        },
        deleteLabel: 'حذف هدف',
        onDelete: () async {
          if (!await _confirm('')) {
            return;
          }
          _store.deleteGoal(g.id);
          if (mounted) Navigator.pop(context);
        },
      ),
    ];
  }

  Widget _trunkGrid(Goal g) {
    final keys = <String>['', ...kTrunkStyles.keys];
    final current = g.trunkStyle;
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.1,
      children: [
        for (final k in keys)
          GestureDetector(
            onTap: () => _edit(() => g.trunkStyle = k),
            child: Container(
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: current == k ? _kGold : _kBorder,
                  width: current == k ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 36,
                    height: 18,
                    child: CustomPaint(
                      painter: _TrunkPreview(
                        style: k.isEmpty ? 'dashed' : k,
                        color: current == k ? _kGold : _kMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    k.isEmpty ? 'مثل نقشه' : (kTrunkStyles[k] ?? k),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          current == k ? FontWeight.w700 : FontWeight.w500,
                      color: current == k ? _kGold : _kInk,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // حلقه (نشانه)
  // ============================================================
  List<Widget> _ringBody(Ring r) {
    return [
      _textField(
        ctlKey: 'ring:${r.id}:label',
        initial: r.label,
        label: 'عنوان نشانه',
        onChanged: (v) => _edit(() => r.label = v),
      ),
      _sectionLabel('آیکون و عکس'),
      IconPhotoEditor(
        initialIcon: r.icon,
        initialImages: r.images,
        initialScale: r.iconScale,
        onChange: (icon, images, scale) => _edit(() {
          r.icon = icon.isEmpty ? '🌟' : icon;
          r.images = images;
          r.iconScale = scale;
        }),
      ),
      _slider(
        label: 'اندازه‌ی دایره',
        value: r.radius.clamp(16.0, 120.0).toDouble(),
        min: 16,
        max: 120,
        divisions: 52,
        valueText: '${(r.radius / 30 * 100).round()}٪',
        onChanged: (v) => _edit(() => r.radius = v),
      ),
      _sectionLabel('رنگ'),
      _swatches(r.color, (c) => r.color = c, extra: const [kRingColor]),
      _sectionLabel('یادداشت'),
      _textField(
        ctlKey: 'ring:${r.id}:note',
        initial: r.note,
        label: 'چیزی که حس می‌کنی',
        onChanged: (v) => _edit(() => r.note = v),
        maxLines: 2,
      ),
      _sectionLabel('شکل مسیر'),
      _shapeGrid(r.branchStyle, (v) => r.branchStyle = v.isEmpty ? 'organic' : v),
      ..._branchesSection(r),
      _bottomActions(
        saveLabel: 'ذخیره',
        onSave: () {
          _store.changed();
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
  // شاخه (اکشن)
  // ============================================================
  List<Widget> _actionBody(MapHost host, ActionNode a) {
    final footPlaying = a.footPlaying;
    return [
      _sectionLabel(''),
      IconPhotoEditor(
        supportsIcon: false,
        supportsScale: false,
        initialIcon: '',
        initialImages: a.images,
        initialScale: 1,
        onChange: (_, images, __) => _edit(() => a.images = images),
      ),
      _sectionLabel(''),
      _textField(
        ctlKey: 'node:${a.id}',
        initial: a.text,
        label: '',
        onChanged: (v) => _edit(() => a.text = v),
      ),
      _sectionLabel(''),
      _swatches(a.color, (c) => a.color = c,
          onInherit: () => a.color = null),
      _slider(
        label: '',
        value: a.weight.clamp(1.0, 10.0).toDouble(),
        min: 1,
        max: 10,
        divisions: 9,
        valueText: toFa(a.weight.round()),
        onChanged: (v) => _edit(() => a.weight = v.roundToDouble()),
      ),
      _switchTile(
        title: 'این یه کار روتینه',
        subtitle: 'هر روز تکرار می‌شه، هفته‌ای یه بار نگاه کن',
        value: a.isRoutine,
        onChanged: (v) => _edit(() => a.isRoutine = v),
      ),
      _sectionLabel(''),
      _shapeGrid(a.style, (v) => a.style = v, inherit: true),

      // ═══════════ قدم روی مسیر 👣 ═══════════
      _sectionLabel('قدم روی مسیر 👣'),
      _slider(
        label: 'اندازه‌ی قدم',
        value: (a.footSize ?? 1.0).clamp(0.4, 2.5),
        min: 0.4,
        max: 2.5,
        divisions: 21,
        valueText: '${((a.footSize ?? 1.0) * 100).round()}٪',
        onChanged: (v) => _edit(() => a.footSize = v),
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
      _sectionLabel('عکس انیمیشن'),
      WalkerPhotoField(
        initial: walkerPhotosOf(a.extra),
        onChanged: (v) => _edit(() {
          setWalkerPhotos(a.extra, v);
          if (v.isNotEmpty) {
            a.footPlaying = true;
            a.footPos = null;
          }
        }),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 4, bottom: 4),
        child: Text(
          'می‌تونی قدم رو با انگشت روی نقشه بگیری و بکشی. با یک تپ روی قدم یا دایره‌ی جلوش کادر عکس‌ها باز می‌شه؛ نگه‌داشتن روش حرکت/توقفش می‌کنه.',
          style: TextStyle(fontSize: 11, color: _kMuted, height: 1.6),
        ),
      ),

      _slider(
        label: 'اندازه‌ی نوشته روی نقشه',
        value: a.labelSize ?? 14,
        min: 8,
        max: 60,
        divisions: 52,
        valueText: toFa((a.labelSize ?? 14).round()),
        onChanged: (v) => _edit(() => a.labelSize = v),
      ),

      // زیرشاخه‌ها
      const SizedBox(height: 8),
      _sectionLabel(''),
      ..._tree(host, a.children, 0),

      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: _kGold.withAlpha(30),
                foregroundColor: _kGold,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final c = _store.addSubBranch(host, a);
                setState(() => _focusId = c.id);
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _kMuted,
                side: const BorderSide(color: _kBorder),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                resetBranchPos(a);
                _store.changed();
                _store.toast?.call('');
              },
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('برگرداندن به جای اول',
                  style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),

      _bottomActions(
        saveLabel: 'ذخیره',
        onSave: () {
          _store.changed();
          Navigator.pop(context);
        },
        deleteLabel: 'حذف',
        onDelete: () async {
          if (!await _confirm('')) return;
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
  // لیست شاخه‌ها
  // ------------------------------------------------------------
  List<Widget> _branchesSection(MapHost host) {
    return [
      _sectionLabel(''),
      if (host.actions.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 8),
          child: Text('',
              style: TextStyle(color: _kMuted, fontSize: 12)),
        ),
      ..._tree(host, host.actions, 0),
      Padding(
        padding: const EdgeInsets.only(top: 8),
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
          label: const Text('',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
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
                    hintText: '',
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
                  if (!await _confirm('')) {
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

// ============================================================
// پیش‌نمایش خط (برای گرید تنه)
// ============================================================
class _TrunkPreview extends CustomPainter {
  _TrunkPreview({required this.style, required this.color});
  final String style;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = color;

    final a = Offset(0, size.height * 0.8);
    final b = Offset(size.width, size.height * 0.2);
    final dir = (b - a);
    final len = dir.distance;
    final n = dir / len;

    switch (style) {
      case 'solid':
        canvas.drawLine(a, b, p);
      case 'dotted':
        for (var i = 0; i < 8; i++) {
          final pt = a + n * (len * i / 7);
          canvas.drawCircle(pt, 1, Paint()..color = color);
        }
      case 'dashdot':
        _dash(canvas, a, b, p, len, n, [4, 2, 1, 2]);
      case 'long':
        _dash(canvas, a, b, p, len, n, [7, 4]);
      case 'double':
        final perp = Offset(-n.dy, n.dx) * 1.3;
        canvas.drawLine(a + perp, b + perp, p..strokeWidth = 1.3);
        canvas.drawLine(
            a - perp,
            b - perp,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.3
              ..strokeCap = StrokeCap.round
              ..color = color);
      case 'glow':
        canvas.drawLine(
            a,
            b,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5
              ..strokeCap = StrokeCap.round
              ..color = color.withAlpha(60));
        canvas.drawLine(a, b, p..strokeWidth = 1.5);
      case 'taper':
        for (var i = 0; i < 6; i++) {
          final p1 = a + n * (len * i / 6);
          final p2 = a + n * (len * (i + 1) / 6);
          canvas.drawLine(
              p1,
              p2,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3 - i * 0.35
                ..strokeCap = StrokeCap.round
                ..color = color);
        }
      default:
        _dash(canvas, a, b, p, len, n, [3, 3]);
    }
  }

  void _dash(Canvas canvas, Offset a, Offset b, Paint p, double len,
      Offset n, List<double> dashes) {
    var d = 0.0;
    var i = 0;
    while (d < len) {
      final seg = dashes[i % dashes.length];
      if (i.isEven) {
        final s = a + n * d;
        final e = a + n * (d + seg > len ? len : d + seg);
        canvas.drawLine(s, e, p);
      }
      d += seg;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _TrunkPreview old) =>
      old.style != style || old.color != color;
}
