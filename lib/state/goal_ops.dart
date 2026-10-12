import 'dart:math' as math;

import '../map/map_ops.dart';
import '../models/jalali.dart';
import '../models/map_models.dart';
import 'map_store.dart';

const kRoutineDoneMark = 'انجام شد ✓';
const kPcMaxDays = 365;
const kPeriodOrd = ['اول', 'دوم', 'سوم', 'چهارم', 'پنجم', 'ششم', 'هفتم', 'هشتم', 'نهم', 'دهم', 'یازدهم', 'دوازدهم', 'سیزدهم'];

String periodOrd(int i) => i >= 0 && i < kPeriodOrd.length ? kPeriodOrd[i] : '${i + 1}';

bool truthy(dynamic v) => v != null && v != false && v != '' && v != 0;

Map<String, dynamic> _extraOf(MapHost h) => h is Goal ? h.extra : (h as Ring).extra;

class PeriodInfo {
  PeriodInfo(this.raw, this.start, this.today, this.total, this.dayNum, this.finished, this.todayJK);
  final Map<String, dynamic> raw;
  final DateTime start, today;
  final int total, dayNum;
  final bool finished;
  final String todayJK;
  List get past => raw['past'] as List;
}

/// دوره‌ی هدف (پیش‌فرض ۲۸ روز از امروز). ذخیره در فیلد period همون هدف، سازگار با نسخه‌ی وب
Map<String, dynamic> ensurePeriod(MapHost h, MapStore store) {
  final ex = _extraOf(h);
  var p = ex['period'];
  if (p is! Map) {
    p = <String, dynamic>{'days': 28, 'startDate': null};
    ex['period'] = p;
  } else if (p is! Map<String, dynamic>) {
    p = Map<String, dynamic>.from(p);
    ex['period'] = p;
  }
  final m = p as Map<String, dynamic>;
  final n = m['days'] is num ? (m['days'] as num).toInt() : (int.tryParse('${m['days']}') ?? 0);
  m['days'] = n >= 1 ? math.min(n, kPcMaxDays) : 28;
  if (m['startDate'] is! String || (m['startDate'] as String).isEmpty) {
    m['startDate'] = localKey(DateTime.now());
    store.touch();
  }
  if (m['past'] is! List) m['past'] = [];
  return m;
}

PeriodInfo periodInfo(MapHost h, MapStore store) {
  final p = ensurePeriod(h, store);
  final start = parseLocalKey(p['startDate'] as String);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final total = p['days'] as int;
  final passed = DateTime.utc(today.year, today.month, today.day)
          .difference(DateTime.utc(start.year, start.month, start.day))
          .inDays +
      1;
  final end = DateTime(start.year, start.month, start.day + total);
  return PeriodInfo(p, start, today, total, passed.clamp(1, total).toInt(), !today.isBefore(end), jKey(today));
}

List<ActionNode> collectNodes(List<ActionNode> list, [List<ActionNode>? out]) {
  out ??= [];
  for (final n in list) {
    out.add(n);
    collectNodes(n.children, out);
  }
  return out;
}

int todayCount(MapHost h, String jk) => collectNodes(h.actions).where((n) => truthy(n.logs[jk])).length;

double sumWeight(List<ActionNode> list) =>
    list.fold(0.0, (s, a) => s + a.weight + sumWeight(a.children));

extension GoalListOps on MapStore {
  /// تیک روزانه: اگه آن روز انجام شده بود برمی‌دارد، وگرنه ثبت می‌کند
  void toggleLog(MapHost host, ActionNode n, String jk) {
    if (truthy(n.logs[jk])) {
      n.logs.remove(jk);
    } else {
      n.logs[jk] = kRoutineDoneMark;
      host.lastActivity = DateTime.now().millisecondsSinceEpoch;
    }
    changed();
  }

  void reachGoal(Goal g) {
    final now = DateTime.now().millisecondsSinceEpoch;
    g.reached = true;
    g.extra['reachedAt'] = now;
    g.lastActivity = now;
    changed();
  }

  void unreachGoal(Goal g) {
    g.reached = false;
    g.extra.remove('reachedAt');
    g.lastActivity = DateTime.now().millisecondsSinceEpoch;
    changed();
  }

  ActionNode addNamed(MapHost host, String name, {ActionNode? parent}) {
    final a = newAction(radius: parent == null ? 12 : 10)..text = name;
    (parent?.children ?? host.actions).add(a);
    host.collapsed = false;
    host.lastActivity = DateTime.now().millisecondsSinceEpoch;
    changed();
    return a;
  }

  /// تغییر متن بدون بازسازی UI (فقط ذخیره‌ی با تأخیر)
  void renameAction(ActionNode n, String text) {
    n.text = text;
    touch();
  }

  void removeActionNode(MapHost host, ActionNode n) {
    final f = findActionNode(host.actions, n.id);
    if (f == null) return;
    f.list.remove(f.node);
    host.lastActivity = DateTime.now().millisecondsSinceEpoch;
    changed();
  }

  void setPeriodDays(MapHost h, int days) {
    ensurePeriod(h, this)['days'] = days;
    changed();
  }

  void startNewPeriod(MapHost h, int days) {
    final p = ensurePeriod(h, this);
    (p['past'] as List).add({'days': p['days'], 'startDate': p['startDate']});
    p['days'] = days;
    p['startDate'] = localKey(DateTime.now());
    changed();
  }
}
