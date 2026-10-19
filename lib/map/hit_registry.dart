import 'dart:ui';

enum HitKind { node, label, image, handle }

/// یک ناحیه‌ی قابل لمس روی نقشه (به مختصات «دنیا»، نه صفحه)
class HitEntry {
  const HitEntry({
    required this.type,
    required this.id,
    this.hostId = '',
    required this.kind,
    this.center = Offset.zero,
    this.radius = 0,
    this.rect,
    this.imgIdx,
  });

  /// me | goal | ring | action | goalToggle
  final String type;
  final String id;

  /// برای شاخه‌ها: شناسه‌ی هدف/حلقه‌ای که شاخه بهش تعلق داره
  final String hostId;
  final HitKind kind;
  final Offset center;
  final double radius;
  final Rect? rect;
  final int? imgIdx;

  bool contains(Offset p, double minR) {
    final r = rect;
    if (r != null) return r.inflate(minR * 0.35).contains(p);
    final rr = radius < minR ? minR : radius;
    return (p - center).distance <= rr;
  }
}

/// هندسه‌ی آخرین رسم هر شاخه (معادل actionGeomMap در نسخه‌ی وب)
class ActionGeomEntry {
  const ActionGeomEntry(this.hostId, this.originPt, this.end, this.scale);
  final String hostId;
  final Offset originPt, end;
  final double scale;
}

/// painter در هر فریم این لیست رو پر می‌کنه (به ترتیب رسم). آخری = روترین.
class HitRegistry {
  final List<HitEntry> entries = [];
  final Map<String, ActionGeomEntry> geom = {};

  void clear() {
    entries.clear();
    geom.clear();
  }

  void add(HitEntry e) => entries.add(e);

  HitEntry? hitTest(Offset world, double camScale) {
    final minR = 12 / camScale;
    for (var i = entries.length - 1; i >= 0; i--) {
      if (entries[i].contains(world, minR)) return entries[i];
    }
    return null;
  }
}
