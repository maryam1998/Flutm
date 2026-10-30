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
    this.payload,
    this.voiceKey = '',
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

  /// برای دکمه‌ی پخش صدا: نقشه‌ی extra گره و کلید صدا ('voice' | 'walkerVoice')
  final Map<String, dynamic>? payload;
  final String voiceKey;

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

/// هندسه‌ی خودِ یک شاخه/زیرشاخه (از نوک تا محلِ شروعش؛ بدونِ مسیرِ جاده‌ی اصلی)
/// برای اینکه نمای راه‌رفتن همه‌ی شاخه‌ها را هم مثلِ نقشه کنارِ جاده بکشد.
class TwigGeom {
  const TwigGeom(this.pts, this.color, this.name);
  final List<Offset> pts;
  final Color color;
  final String name;
}

/// painter در هر فریم این لیست رو پر می‌کنه (به ترتیب رسم). آخری = روترین.
class HitRegistry {
  HitRegistry() {
    current = this;
  }

  /// آخرین ثبتِ ساخته‌شده (همان که نقشه‌ی روی صفحه پرش می‌کند)؛ نمای راه‌رفتن
  /// مسیرِ قدم‌زنِ شاخه‌ها را از اینجا می‌خواند.
  static HitRegistry? current;

  final List<HitEntry> entries = [];
  final Map<String, ActionGeomEntry> geom = {};

  /// مسیرِ کاملِ قدم‌زنِ هر شاخه (نوک شاخه → پدرها → تنه → هدف)
  final Map<String, List<Offset>> routes = {};

  /// هندسه‌ی خودِ هر شاخه/زیرشاخه (نوک ← ابتدای شاخه)
  final Map<String, TwigGeom> twigs = {};

  void clear() {
    entries.clear();
    geom.clear();
    routes.clear();
    twigs.clear();
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
