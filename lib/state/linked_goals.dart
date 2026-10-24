import 'dart:async';

import 'package:flutter/foundation.dart';

import '../map/map_ops.dart';
import '../models/jalali.dart';
import '../models/map_models.dart';
import 'abundance_store.dart';
import 'beliefs_store.dart';
import 'goal_ops.dart';
import 'gratitude_store.dart';
import 'map_store.dart';

/// تب‌هایی که می‌شود به نقشه وصل کرد؛ هر کدام یک هدفِ جدا روی نقشه می‌شود
class LinkedTab {
  const LinkedTab(this.id, this.name, this.branch, this.icon, this.color);
  final String id, name, branch, icon, color;

  /// کلید تیک در تنظیمات (داخل MapState.extra)
  String get flag => 'link_$id';
}

const kLinkedTabs = [
  LinkedTab('gratitude', 'شکرگذاری', 'ثبت شکرگذاری', '🙏', '#f4c542'),
  LinkedTab('abundance', 'بازی فراوانی', 'خرید در بازی', '💰', '#63d6a8'),
  LinkedTab('beliefs', 'بازنویسی', 'خواندن متن خواسته', '✍️', '#8f7bf0'),
];

bool isTabLinked(MapStore m, LinkedTab t) => m.state.extra[t.flag] == true;

String _isoKey(String iso) {
  if (iso.isEmpty) return '';
  try {
    final d = DateTime.parse(iso).toLocal();
    return localKey(DateTime(d.year, d.month, d.day));
  } catch (_) {
    return '';
  }
}

/// روزهای انجام‌شده‌ی هر تب (کلید میلادی YYYY-MM-DD) + دوره‌ی پیشنهادی
class _Src {
  _Src(this.days, this.start, this.total);
  final Set<String> days;
  final String start;
  final int total;
}

_Src _sourceOf(
  LinkedTab t,
  GratitudeStore g,
  AbundanceStore a,
  BeliefsStore b,
) {
  switch (t.id) {
    case 'gratitude':
      return _Src(
        {
          for (final e in g.entries)
            if (e.source != 'purchase' && _isoKey(e.iso).isNotEmpty)
              _isoKey(e.iso),
        },
        g.journeyStart,
        g.journeyDays,
      );
    case 'abundance':
      return _Src(
        {
          for (final p in a.history)
            if (_isoKey(p.iso).isNotEmpty) _isoKey(p.iso),
        },
        a.settings.startDate,
        28,
      );
    default:
      final v = b.activeVersion;
      return _Src(
        {...?v?.readDays},
        v?.startDate ?? '',
        b.cycleDays,
      );
  }
}

ActionNode? _linkedBranch(Goal g, String tab) {
  for (final n in collectNodes(g.actions)) {
    if (n.extra['linkedTab'] == tab) return n;
  }
  return null;
}

/// نقشه را با تب‌های وصل‌شده هماهنگ می‌کند: هر تبِ تیک‌خورده یک هدف دارد و
/// روزهایی که در آن تب کار انجام شده، روی شاخه‌ی همان هدف ثبت می‌شود
/// (پس قدم، انیمیشن، تقویم و آمار مثل بقیه‌ی هدف‌ها کار می‌کند).
void syncLinkedGoals(
  MapStore map,
  GratitudeStore gratitude,
  AbundanceStore abundance,
  BeliefsStore beliefs,
) {
  var dirty = false;
  final now = DateTime.now().millisecondsSinceEpoch;
  final todayJK = jKey(DateTime.now());

  for (final t in kLinkedTabs) {
    Goal? g;
    for (final x in map.state.goals) {
      if (x.extra['linkedTab'] == t.id) g = x;
    }

    // تیک برداشته شده → هدفِ وصل‌شده از نقشه برداشته می‌شود
    if (!isTabLinked(map, t)) {
      if (g != null) {
        map.deleteGoal(g.id);
        dirty = true;
      }
      continue;
    }

    final src = _sourceOf(t, gratitude, abundance, beliefs);

    if (g == null) {
      final spot = pickGoalSpot(map.state);
      g = Goal(
        name: t.name,
        icon: t.icon,
        color: t.color,
        x: spot.dx,
        y: spot.dy,
        createdAt: now,
        extra: {'linkedTab': t.id},
      );
      map.state.goals.add(g);
      final p = ensurePeriod(g, map);
      if (src.start.isNotEmpty) p['startDate'] = src.start;
      p['days'] = src.total.clamp(1, kPcMaxDays);
      dirty = true;
    }

    var a = _linkedBranch(g, t.id);
    if (a == null) {
      a = newAction(radius: 12)
        ..text = t.branch
        ..extra['linkedTab'] = t.id;
      g.actions.add(a);
      dirty = true;
    }

    final want = {for (final k in src.days) jKey(parseLocalKey(k))};
    final prev = {
      for (final e in (a.extra['syncedDays'] is List
          ? a.extra['syncedDays'] as List
          : const []))
        '$e',
    };
    final next = <String>{};

    for (final jk in want) {
      if (prev.contains(jk)) {
        next.add(jk);
      } else if (!truthy(a.logs[jk])) {
        a.logs[jk] = kRoutineDoneMark;
        next.add(jk);
        dirty = true;
        if (jk == todayJK) g.lastActivity = now;
      }
    }
    for (final jk in prev.difference(want)) {
      if (a.logs[jk] == kRoutineDoneMark) {
        a.logs.remove(jk);
        dirty = true;
      }
    }
    if (!setEquals(prev, next)) {
      a.extra['syncedDays'] = next.toList()..sort();
      dirty = true;
    }
  }

  if (dirty) map.changed();
}

/// گوش دادن به تب‌ها و هماهنگ‌سازیِ خودکار (با کمی تأخیر برای کم‌کردن کار)
class LinkedGoalsWatcher {
  LinkedGoalsWatcher(this.map, this.gratitude, this.abundance, this.beliefs);
  final MapStore map;
  final GratitudeStore gratitude;
  final AbundanceStore abundance;
  final BeliefsStore beliefs;
  Timer? _t;

  void attach() {
    gratitude.addListener(_later);
    abundance.addListener(_later);
    beliefs.addListener(_later);
    _later();
  }

  void detach() {
    _t?.cancel();
    gratitude.removeListener(_later);
    abundance.removeListener(_later);
    beliefs.removeListener(_later);
  }

  void _later() {
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 400), () {
      syncLinkedGoals(map, gratitude, abundance, beliefs);
    });
  }
}
