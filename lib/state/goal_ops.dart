import 'dart:math' as math;

import '../map/draw_utils.dart' show toFa;
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

// ======================== زمان ========================

String fmtDur(num sec) {
  final s = sec.round();
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  if (h == 0 && m == 0) return s > 0 ? '${toFa(s)} ثانیه' : '${toFa(0)} دقیقه';
  final parts = <String>[];
  if (h > 0) parts.add('${toFa(h)} ساعت');
  if (m > 0) parts.add('${toFa(m)} دقیقه');
  return parts.join(' و ');
}

String fmtClock(num sec) {
  final s = sec.floor();
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final x = s % 60;
  String p(int v) => v.toString().padLeft(2, '0');
  if (h > 0) return toFa('${p(h)}:${p(m)}:${p(x)}');
  return toFa('${p(m)}:${p(x)}');
}

String fmtHM(int min) {
  final m = ((min % 1440) + 1440) % 1440;
  final h = m ~/ 60;
  final mm = m % 60;
  return toFa('${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}');
}

double nodeDaySecs(ActionNode n, String jk) =>
    (n.time[jk] as num?)?.toDouble() ?? 0;

double nodePeriodSecs(ActionNode n, Set<String> keys) {
  var t = 0.0;
  for (final e in n.time.entries) {
    if (keys.contains(e.key)) t += (e.value as num?)?.toDouble() ?? 0;
  }
  return t;
}

List<Map<String, dynamic>> nodeEntries(ActionNode n, String jk) {
  final v = n.entries[jk];
  if (v is! List) return const [];
  return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

bool timerRunning(ActionNode n) => (n.timerStart ?? 0) > 0;

void startTimer(ActionNode n) {
  n.timerStart = DateTime.now().millisecondsSinceEpoch;
}

/// صفر برمی‌گردونه اگه تایمر فعال نبود
int stopTimer(ActionNode n) {
  if (!timerRunning(n)) return 0;
  final start = DateTime.fromMillisecondsSinceEpoch(n.timerStart!);
  final elapsed =
      (DateTime.now().difference(start).inMilliseconds / 1000).floor();
  n.timerStart = null;
  if (elapsed > 0) {
    final jk = jKey(start);
    n.time[jk] = ((n.time[jk] as num?)?.toInt() ?? 0) + elapsed;
    final list = (n.entries[jk] is List)
        ? (n.entries[jk] as List)
        : (n.entries[jk] = <dynamic>[]);
    list.add({
      'kind': 'dur',
      'mins': (elapsed / 60).round(),
      'at': DateTime.now().millisecondsSinceEpoch,
    });
  }
  return elapsed;
}

void addDuration(ActionNode n, String jk, int mins, {String? note}) {
  if (mins <= 0) return;
  final secs = mins * 60;
  n.time[jk] = ((n.time[jk] as num?)?.toInt() ?? 0) + secs;
  final list = (n.entries[jk] is List)
      ? (n.entries[jk] as List)
      : (n.entries[jk] = <dynamic>[]);
  final e = <String, dynamic>{
    'kind': 'dur',
    'mins': mins,
    'at': DateTime.now().millisecondsSinceEpoch,
  };
  if (note != null && note.isNotEmpty) e['note'] = note;
  list.add(e);
}

void addRange(ActionNode n, String jk, int startMin, int endMin,
    {String? note}) {
  var e = endMin;
  if (e <= startMin) e += 1440;
  final mins = e - startMin;
  if (mins <= 0) return;
  n.time[jk] = ((n.time[jk] as num?)?.toInt() ?? 0) + mins * 60;
  final list = (n.entries[jk] is List)
      ? (n.entries[jk] as List)
      : (n.entries[jk] = <dynamic>[]);
  final entry = <String, dynamic>{
    'kind': 'range',
    's': startMin % 1440,
    'e': e % 1440,
    'mins': mins,
    'at': DateTime.now().millisecondsSinceEpoch,
  };
  if (note != null && note.isNotEmpty) entry['note'] = note;
  list.add(entry);
  final rl = (n.ranges[jk] is List)
      ? (n.ranges[jk] as List)
      : (n.ranges[jk] = <dynamic>[]);
  rl.add({'s': startMin % 1440, 'e': e % 1440});
}

void deleteEntry(ActionNode n, String jk, int idx) {
  final raw = n.entries[jk];
  if (raw is! List || idx < 0 || idx >= raw.length) return;
  final entry = raw[idx];
  raw.removeAt(idx);
  if (raw.isEmpty) n.entries.remove(jk);
  final mins =
      entry is Map ? ((entry['mins'] as num?)?.toInt() ?? 0) : 0;
  final cur = (n.time[jk] as num?)?.toInt() ?? 0;
  final nv = cur - mins * 60;
  if (nv > 0) {
    n.time[jk] = nv;
  } else {
    n.time.remove(jk);
  }
  if (entry is Map && entry['kind'] == 'range') {
    final rl = n.ranges[jk];
    if (rl is List) {
      rl.removeWhere((r) =>
          r is Map && r['s'] == entry['s'] && r['e'] == entry['e']);
      if (rl.isEmpty) n.ranges.remove(jk);
    }
  }
}

void clearDayTime(ActionNode n, String jk) {
  n.time.remove(jk);
  n.ranges.remove(jk);
  n.entries.remove(jk);
}

int routineStreak(ActionNode n) {
  var streak = 0;
  var d = DateTime.now();
  if (!truthy(n.logs[jKey(d)])) {
    d = d.subtract(const Duration(days: 1));
  }
  for (var i = 0; i < 90; i++) {
    if (!truthy(n.logs[jKey(d)])) break;
    streak++;
    d = d.subtract(const Duration(days: 1));
  }
  return streak;
}

int routineWeekDone(ActionNode n) {
  final days = jalaaliCurrentWeekDates();
  var done = 0;
  for (final k in days) {
    if (truthy(n.logs[k])) done++;
  }
  return done;
}
