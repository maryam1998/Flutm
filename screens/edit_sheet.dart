import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../map/draw_utils.dart' show toFa;
import '../map/map_ops.dart';
import '../models/constants.dart';
import '../models/map_models.dart';
import '../state/map_store.dart';

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

class ActionTarget extends EditTarget {
  const ActionTarget(this.hostId, this.actionId);
  final String hostId, actionId;
  @override
  String get key => 'a:$actionId';
}

Future<void> showEditSheet(BuildContext context, EditTarget target) {
  final store = context.read<MapStore>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFF14172F),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: EditSheet(store: store, initial: target),
    ),
  );
}

/// پنل ویرایش «من» / هدف / نشانه / شاخه. تغییرها همون لحظه روی نقشه اعمال و ذخیره میشن.
class EditSheet extends StatefulWidget {
  const EditSheet({super.key, required this.store, required this.initial});
  final MapStore store;
  final EditTarget initial;

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

  static const _gap = SizedBox(height: 14);

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _c(String key, String initial) => _ctl.putIfAbsent(key, () => TextEditingController(text: initial));

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
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لغو')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('بله')),
        ],
      ),
    );
    return ok == true;
  }

  // ------------------------------------------------------------------ ساختار کلی

  @override
  Widget build(BuildContext context) {
    final body = _body();
    if (body == null) {
      // گره‌ی مورد نظر دیگه وجود نداره (مثلاً حذف شده)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const SizedBox(height: 80);
    }
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.82),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_header(), const SizedBox(height: 6), ...body],
          ),
        ),
      ),
    );
  }

  String _title() {
    final t = _t;
    if (t is MeTarget) return 'من';
    if (t is GoalTarget) {
      final g = _s.findHost(t.id);
      return g is Goal && g.name.isNotEmpty ? g.name : 'هدف';
    }
    if (t is RingTarget) {
      final r = _s.findHost(t.id);
      return r is Ring && r.label.isNotEmpty ? r.label : 'نشانه';
    }
    return 'ویرایش شاخه';
  }

  Widget _header() {
    return Row(
      children: [
        if (_back.isNotEmpty) IconButton(onPressed: _goBack, icon: const Icon(Icons.arrow_back)),
        Expanded(
          child: Text(_title(),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('تمام')),
      ],
    );
  }

  List<Widget>? _body() {
    final t = _t;
    if (t is MeTarget) return _meBody();
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

  // ------------------------------------------------------------------ اجزای مشترک

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(s, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      );

  Widget _text(String key, String initial, String label, void Function(String) set,
      {int maxLines = 1, bool center = false, int? maxLength, bool autofocus = false}) {
    return TextField(
      controller: _c(key, initial),
      autofocus: autofocus,
      maxLines: maxLines,
      maxLength: maxLength,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: center ? const TextStyle(fontSize: 22) : null,
      onChanged: (v) => _edit(() => set(v)),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _swatches(String? current, void Function(String) onPick, {List<String> extra = const [], VoidCallback? onInherit}) {
    final cur = (current ?? '').toLowerCase();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (onInherit != null)
          ChoiceChip(label: const Text('هم‌رنگ هدف'), selected: cur.isEmpty, onSelected: (_) => _edit(onInherit)),
        for (final hex in [...kPalette, ...extra])
          GestureDetector(
            onTap: () => _edit(() => onPick(hex)),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: hexColor(hex),
                shape: BoxShape.circle,
                border: Border.all(color: cur == hex ? Colors.white : Colors.transparent, width: 3),
              ),
            ),
          ),
      ],
    );
  }

  Widget _styleChips(String current, Map<String, String> options, void Function(String) onPick, {String? inheritLabel}) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        if (inheritLabel != null)
          ChoiceChip(label: Text(inheritLabel), selected: current.isEmpty, onSelected: (_) => _edit(() => onPick(''))),
        for (final e in options.entries)
          ChoiceChip(label: Text(e.value), selected: current == e.key, onSelected: (_) => _edit(() => onPick(e.key))),
      ],
    );
  }

  Widget _deleteButton(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFF0708A)),
          onPressed: onTap,
          icon: const Icon(Icons.delete_outline),
          label: Text(label),
        ),
      );

  // ------------------------------------------------------------------ من

  List<Widget> _meBody() {
    final me = _s.me;
    return [
      _text('me:name', me.name, 'نام', (v) => me.name = v),
      _gap,
      _label('رنگ'),
      _swatches(me.color, (c) => me.color = c),
      _gap,
      _text('me:note', me.note, 'یادداشت', (v) => me.note = v, maxLines: 3),
    ];
  }

  // ------------------------------------------------------------------ هدف

  List<Widget> _goalBody(Goal g) {
    return [
      _text('goal:${g.id}:name', g.name, 'نام هدف', (v) => g.name = v),
      _gap,
      _text('goal:${g.id}:icon', g.icon, 'آیکون (ایموجی)', (v) => g.icon = v.trim().isEmpty ? '🎯' : v.trim(),
          center: true, maxLength: 20),
      _gap,
      _label('رنگ'),
      _swatches(g.color, (c) => g.color = c),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('به این هدف رسیدم'),
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
      _label('شکل شاخه‌ها'),
      _styleChips(g.branchStyle, kBranchStyles, (v) => g.branchStyle = v.isEmpty ? 'organic' : v),
      _gap,
      _label('شکل مسیر (تنه)'),
      _styleChips(g.trunkStyle, kTrunkStyles, (v) => g.trunkStyle = v, inheritLabel: 'مثل تنظیمات نقشه'),
      ..._branchesSection(g),
      _deleteButton('حذف هدف', () async {
        if (!await _confirm('هدف «${g.name}» با همه‌ی شاخه‌هاش حذف بشه؟')) return;
        _store.deleteGoal(g.id);
        if (mounted) Navigator.pop(context);
      }),
    ];
  }

  // ------------------------------------------------------------------ نشانه (حلقه)

  List<Widget> _ringBody(Ring r) {
    return [
      _text('ring:${r.id}:label', r.label, 'عنوان نشانه', (v) => r.label = v),
      _gap,
      _text('ring:${r.id}:icon', r.icon, 'آیکون (ایموجی)', (v) => r.icon = v.trim().isEmpty ? '🌟' : v.trim(),
          center: true, maxLength: 20),
      _gap,
      _label('رنگ'),
      _swatches(r.color, (c) => r.color = c, extra: const [kRingColor]),
      _gap,
      _text('ring:${r.id}:note', r.note, 'یادداشت', (v) => r.note = v, maxLines: 2),
      _gap,
      _label('شکل شاخه‌ها'),
      _styleChips(r.branchStyle, kBranchStyles, (v) => r.branchStyle = v.isEmpty ? 'organic' : v),
      ..._branchesSection(r),
      _deleteButton('حذف نشانه', () async {
        if (!await _confirm('این نشانه حذف بشه؟')) return;
        _store.deleteRing(r.id);
        if (mounted) Navigator.pop(context);
      }),
    ];
  }

  // ------------------------------------------------------------------ شاخه

  List<Widget> _actionBody(MapHost host, ActionNode a) {
    return [
      _text('node:${a.id}', a.text, 'عنوان شاخه', (v) => a.text = v),
      _gap,
      _label('رنگ'),
      _swatches(a.color, (c) => a.color = c, onInherit: () => a.color = null),
      _gap,
      _label('ضخامت (اهمیت): ${toFa(a.weight.round())}'),
      Slider(
        min: 1,
        max: 10,
        divisions: 9,
        value: a.weight.clamp(1.0, 10.0).toDouble(),
        label: toFa(a.weight.round()),
        onChanged: (v) => _edit(() => a.weight = v.roundToDouble()),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('تمرین روزانه (روتین)'),
        value: a.isRoutine,
        onChanged: (v) => _edit(() => a.isRoutine = v),
      ),
      _label('شکل شاخه'),
      _styleChips(a.style, kBranchStyles, (v) => a.style = v, inheritLabel: 'مثل هدف'),
      const Divider(height: 28),
      Row(
        children: [
          Text('زیرشاخه‌ها (${toFa(countActions(a.children))})', style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          FilledButton.tonalIcon(
            onPressed: () {
              final c = _store.addSubBranch(host, a);
              setState(() => _focusId = c.id);
            },
            icon: const Icon(Icons.add),
            label: const Text('زیرشاخه'),
          ),
        ],
      ),
      ..._tree(host, a.children, 0),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () {
          resetBranchPos(a);
          _store.changed();
          _store.toast?.call('شاخه سرِ جای اولش برگشت');
        },
        icon: const Icon(Icons.restart_alt),
        label: const Text('برگرداندن به جای اول'),
      ),
      _deleteButton('حذف شاخه', () async {
        if (!await _confirm('این شاخه (و زیرشاخه‌هاش) حذف بشه؟')) return;
        _store.deleteAction(host.id, a.id);
        if (!mounted) return;
        if (_back.isNotEmpty) {
          _goBack();
        } else {
          Navigator.pop(context);
        }
      }),
    ];
  }

  // ------------------------------------------------------------------ لیست شاخه‌ها

  List<Widget> _branchesSection(MapHost host) {
    return [
      const Divider(height: 28),
      Row(
        children: [
          Text('شاخه‌ها (${toFa(countActions(host.actions))})', style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          FilledButton.tonalIcon(
            onPressed: () {
              final a = _store.addBranch(host);
              setState(() => _focusId = a.id);
            },
            icon: const Icon(Icons.add),
            label: const Text('شاخه'),
          ),
        ],
      ),
      if (host.actions.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('هنوز شاخه‌ای ثبت نشده.', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ),
      ..._tree(host, host.actions, 0),
      if (host.actions.isNotEmpty)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () async {
              if (!await _confirm('همه‌ی شاخه‌ها و زیرشاخه‌های این مجموعه به جای اولشان برگردند؟')) return;
              resetBranchTree(host.actions);
              _store.changed();
              _store.toast?.call('همه‌ی شاخه‌ها برگشتند');
            },
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text('برگرداندن همه به جای اول'),
          ),
        ),
    ];
  }

  List<Widget> _tree(MapHost host, List<ActionNode> list, int depth) {
    final out = <Widget>[];
    for (final a in list) {
      out.add(Padding(
        padding: EdgeInsetsDirectional.only(start: depth * 18.0, top: 6),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: hexColor(a.color, hexColor(host.color, hexColor(kPalette[0]))),
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
                decoration: const InputDecoration(isDense: true, hintText: 'عنوان شاخه'),
              ),
            ),
            IconButton(
              tooltip: 'ویرایش',
              icon: const Icon(Icons.tune),
              onPressed: () => _go(ActionTarget(host.id, a.id)),
            ),
            IconButton(
              tooltip: 'حذف',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await _confirm('این شاخه (و زیرشاخه‌هاش) حذف بشه؟')) return;
                _store.deleteAction(host.id, a.id);
                if (mounted) setState(() {});
              },
            ),
          ],
        ),
      ));
      out.addAll(_tree(host, a.children, depth + 1));
    }
    return out;
  }
}
