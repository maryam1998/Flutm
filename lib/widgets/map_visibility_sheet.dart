import 'package:flutter/material.dart' hide showDialog, showModalBottomSheet;
import 'package:provider/provider.dart';

import '../map/draw_utils.dart' show toFa;
import '../models/constants.dart';
import '../models/map_models.dart';
import '../state/map_store.dart';
import 'dark_dialogs.dart';

const _kGold = Color(0xFF178A7C);
const _kInk = Color(0xFF000000);
const _kMuted = Color(0xFF5B5F77);
const _kBorder = Color(0xFFE4E6EE);
const _kField = Color(0xFFF4F5FA);

/// کلیدهای ذخیره در `state.extra`
const kMapMaxLevelKey = 'mapMaxLevel'; // 0 = همه
const kMapHideTypesKey = 'mapHideTypes'; // routine | normal | done | flora | feet

/// «نمایش شاخه‌ها»: انتخابِ اینکه کدام جاده/شاخه/زیرشاخه و کدام مدل روی نقشه
/// دیده شود. پشتِ پنجره شفاف است تا اثرِ هر تغییر همان لحظه روی نقشه دیده شود.
Future<void> showMapVisibilitySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    barrierColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.22,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.22, 0.5, 0.92],
      builder: (_, controller) => _VisSheet(controller: controller),
    ),
  );
}

class _VisSheet extends StatelessWidget {
  const _VisSheet({required this.controller});
  final ScrollController controller;

  List<String> _types(MapState s) {
    final t = s.extra[kMapHideTypesKey];
    return t is List ? [for (final e in t) '$e'] : <String>[];
  }

  void _setType(MapStore store, String key, bool hidden) {
    final cur = _types(store.state);
    cur.remove(key);
    if (hidden) cur.add(key);
    if (cur.isEmpty) {
      store.state.extra.remove(kMapHideTypesKey);
    } else {
      store.state.extra[kMapHideTypesKey] = cur;
    }
    store.changed();
  }

  void _setLevel(MapStore store, int v) {
    if (v <= 0) {
      store.state.extra.remove(kMapMaxLevelKey);
    } else {
      store.state.extra[kMapMaxLevelKey] = v;
    }
    store.changed();
  }

  void _showAll(MapStore store) {
    final s = store.state;
    s.extra.remove(kMapMaxLevelKey);
    s.extra.remove(kMapHideTypesKey);
    void clear(List<ActionNode> l) {
      for (final a in l) {
        a.extra.remove('mapHidden');
        clear(a.children);
      }
    }

    for (final g in s.goals) {
      g.extra.remove('hidden');
      g.extra.remove('roadHidden');
      clear(g.actions);
    }
    for (final r in s.rings) {
      clear(r.actions);
    }
    store.changed();
  }

  void _setTop(MapStore store, List<ActionNode> list, bool hide) {
    for (final a in list) {
      if (hide) {
        a.extra['mapHidden'] = true;
      } else {
        a.extra.remove('mapHidden');
      }
    }
    store.changed();
  }

  void _toggleNode(MapStore store, ActionNode a) {
    if (a.extra['mapHidden'] == true) {
      a.extra.remove('mapHidden');
    } else {
      a.extra['mapHidden'] = true;
    }
    store.changed();
  }

  void _toggleRoad(MapStore store, Goal g) {
    if (g.extra['roadHidden'] == true) {
      g.extra.remove('roadHidden');
    } else {
      g.extra['roadHidden'] = true;
    }
    store.changed();
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Text(t,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _kInk)),
      );

  Widget _chip(String label, bool on, ValueChanged<bool> onSel) {
    return FilterChip(
      label: Text(label,
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: on ? _kGold : _kMuted)),
      selected: on,
      showCheckmark: true,
      checkmarkColor: _kGold,
      selectedColor: _kGold.withAlpha(30),
      backgroundColor: _kField,
      side: const BorderSide(color: _kBorder),
      onSelected: onSel,
    );
  }

  List<Widget> _nodeRows(MapStore store, List<ActionNode> list, int depth,
      bool parentHidden) {
    final out = <Widget>[];
    for (final a in list) {
      final hidden = a.extra['mapHidden'] == true;
      final dim = hidden || parentHidden;
      final name = a.text.trim().isEmpty ? '(بدون نام)' : a.text.trim();
      final col = (a.color != null && a.color!.isNotEmpty)
          ? hexColor(a.color, _kGold)
          : _kGold;
      out.add(InkWell(
        onTap: () => _toggleNode(store, a),
        child: Padding(
          padding: EdgeInsetsDirectional.only(
              start: 6.0 + depth * 18.0, end: 4, top: 1, bottom: 1),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsetsDirectional.only(end: 8),
                decoration: BoxDecoration(
                    color: dim ? _kBorder : col, shape: BoxShape.circle),
              ),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      color: dim ? _kMuted.withAlpha(150) : _kInk,
                      decoration:
                          hidden ? TextDecoration.lineThrough : null),
                ),
              ),
              Text(depth == 0 ? 'شاخه' : 'زیرشاخه ${toFa(depth)}',
                  style: const TextStyle(fontSize: 10.5, color: _kMuted)),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: hidden ? 'نمایش' : 'پنهان کردن',
                onPressed: () => _toggleNode(store, a),
                icon: Icon(
                    hidden
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: hidden ? _kMuted : _kGold),
              ),
            ],
          ),
        ),
      ));
      if (a.children.isNotEmpty) {
        out.addAll(_nodeRows(store, a.children, depth + 1, dim));
      }
    }
    return out;
  }

  Widget _hostTile(
      BuildContext context, MapStore store, MapHost h, String name, String icon) {
    final g = h is Goal ? h : null;
    final goalHidden = g?.extra['hidden'] == true;
    final roadHidden = g?.extra['roadHidden'] == true;
    final n = countActions(h.actions);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey<String>('vis_${h.id}'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        childrenPadding: const EdgeInsets.only(bottom: 6),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: goalHidden ? 'نمایش هدف' : 'پنهان کردن کل هدف',
          onPressed: g == null
              ? null
              : () => store.toggleGoalHidden(g.id),
          icon: Icon(
              goalHidden
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 21,
              color: goalHidden ? _kMuted : _kGold),
        ),
        title: Row(
          children: [
            if (icon.isNotEmpty && icon.length <= 6)
              Text('$icon ', style: const TextStyle(fontSize: 14)),
            Expanded(
              child: Text(
                name.isEmpty ? '(بدون نام)' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: goalHidden ? _kMuted : _kInk),
              ),
            ),
          ],
        ),
        subtitle: Text('${toFa(n)} شاخه و زیرشاخه',
            style: const TextStyle(fontSize: 11, color: _kMuted)),
        children: [
          if (g != null)
            InkWell(
              onTap: () => _toggleRoad(store, g),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 2, 4, 2),
                child: Row(
                  children: [
                    const Icon(Icons.add_road, size: 18, color: _kMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('جاده‌ی اصلی',
                          style: TextStyle(
                              fontSize: 13,
                              color: roadHidden ? _kMuted : _kInk,
                              decoration: roadHidden
                                  ? TextDecoration.lineThrough
                                  : null)),
                    ),
                    Switch(
                      value: !roadHidden,
                      activeColor: _kGold,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (_) => _toggleRoad(store, g),
                    ),
                  ],
                ),
              ),
            ),
          if (h.actions.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 10, 2),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => _setTop(store, h.actions, false),
                    child: const Text('نمایش همه‌ی شاخه‌ها',
                        style: TextStyle(fontSize: 12, color: _kGold)),
                  ),
                  TextButton(
                    onPressed: () => _setTop(store, h.actions, true),
                    child: const Text('پنهان کردن همه',
                        style: TextStyle(fontSize: 12, color: _kMuted)),
                  ),
                ],
              ),
            ),
          ..._nodeRows(store, h.actions, 0, false),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MapStore>();
    final s = store.state;
    final types = _types(s);
    final lv = s.extra[kMapMaxLevelKey] is num
        ? (s.extra[kMapMaxLevelKey] as num).toInt()
        : 0;
    final goals = s.goals;
    final rings = [for (final r in s.rings) if (r.actions.isNotEmpty) r];

    const levels = <int, String>{
      0: 'همه‌ی سطح‌ها',
      1: 'فقط شاخه‌ها',
      2: 'تا زیرشاخه‌ی ۱',
      3: 'تا زیرشاخه‌ی ۲',
    };

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('نمایش شاخه‌ها',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _kInk)),
            ),
            TextButton.icon(
              onPressed: () => _showAll(store),
              icon: const Icon(Icons.visibility, size: 18, color: _kGold),
              label: const Text('نمایش همه',
                  style: TextStyle(fontSize: 12.5, color: _kGold)),
            ),
          ],
        ),
        const Text(
          'هر چیزی که خاموش کنی همان لحظه از روی نقشه برمی‌دارد؛ چیزی پاک نمی‌شود.',
          style: TextStyle(fontSize: 11.5, color: _kMuted, height: 1.7),
        ),
        _title('تا کدام سطح نمایش داده شود'),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final e in levels.entries)
              ChoiceChip(
                label: Text(e.value,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: lv == e.key ? _kGold : _kMuted)),
                selected: lv == e.key,
                showCheckmark: false,
                selectedColor: _kGold.withAlpha(30),
                backgroundColor: _kField,
                side: const BorderSide(color: _kBorder),
                onSelected: (_) => _setLevel(store, e.key),
              ),
          ],
        ),
        _title('کدام مدل‌ها دیده شوند'),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _chip('شاخه‌های روتین', !types.contains('routine'),
                (on) => _setType(store, 'routine', !on)),
            _chip('شاخه‌های عادی', !types.contains('normal'),
                (on) => _setType(store, 'normal', !on)),
            _chip('تمام‌شده‌ها', !types.contains('done'),
                (on) => _setType(store, 'done', !on)),
            _chip('گیاه و گل کنار شاخه', !types.contains('flora'),
                (on) => _setType(store, 'flora', !on)),
            _chip('قدم‌ها (پاها)', !types.contains('feet'),
                (on) => _setType(store, 'feet', !on)),
          ],
        ),
        _title('هدف‌ها، جاده‌ها و شاخه‌ها'),
        if (goals.isEmpty && rings.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('هنوز هدفی نیست.',
                style: TextStyle(fontSize: 12.5, color: _kMuted)),
          ),
        for (final g in goals) _hostTile(context, store, g, g.name, g.icon),
        for (final r in rings) _hostTile(context, store, r, r.label, r.icon),
      ],
    );
  }
}
