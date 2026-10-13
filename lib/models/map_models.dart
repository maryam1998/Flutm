import 'dart:math';
import 'constants.dart';

String uid() =>
    DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
    Random().nextInt(1 << 30).toRadixString(36).padLeft(5, '0').substring(0, 5);

double _d(dynamic v, double def) => v is num ? v.toDouble() : def;
double? _dn(dynamic v) => v is num ? v.toDouble() : null;
String _s(dynamic v, String def) => v is String ? v : def;
bool _b(dynamic v, bool def) => v is bool ? v : def;
Map<String, dynamic> _m(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
Map<String, dynamic> _rest(Map<String, dynamic> j, Set<String> known) =>
    {for (final e in j.entries) if (!known.contains(e.key)) e.key: e.value};
double _clampScale(double v) =>
    v.clamp(kIconScaleMin, kIconScaleMax).toDouble();

abstract interface class MapHost {
  String get id;
  double get x;
  double get y;
  double get radius;
  String? get color;
  List<ActionNode> get actions;
  String get branchStyle;
  bool get isRing;
  bool get collapsed;
  set collapsed(bool v);
  int get lastActivity;
  set lastActivity(int v);
}

class ImageItem {
  String src;
  double size, dx, dy;
  Map<String, dynamic> extra;
  ImageItem({
    this.src = '',
    this.size = kDefaultImgSize,
    this.dx = 0,
    this.dy = 0,
    Map<String, dynamic>? extra,
  }) : extra = extra ?? {};

  static const _known = {'src', 'size', 'dx', 'dy'};

  factory ImageItem.fromAny(dynamic v) {
    if (v is String) return ImageItem(src: v);
    if (v is Map) {
      final j = _m(v);
      var size = _d(j['size'], kDefaultImgSize);
      if (size < 16) size = kDefaultImgSize;
      return ImageItem(
        src: _s(j['src'], ''),
        size: size,
        dx: _d(j['dx'], 0),
        dy: _d(j['dy'], 0),
        extra: _rest(j, _known),
      );
    }
    return ImageItem();
  }

  Map<String, dynamic> toJson() =>
      {...extra, 'src': src, 'size': size, 'dx': dx, 'dy': dy};
}

List<ImageItem> _images(dynamic v) =>
    v is List ? v.map(ImageItem.fromAny).toList() : <ImageItem>[];

class ActionNode {
  String id, text, style;
  String? color;
  double weight, labelDX, labelDY;
  double? labelSize;
  List<ActionNode> children;
  List<ImageItem> images;
  Map<String, dynamic> logs, entries;
  Map<String, dynamic> time;
  Map<String, dynamic> ranges;
  int? timerStart;
  bool isRoutine, detached;
  double? originX, originY, dir, len, bend1, bend2;

  // ─────────── قدم متحرک 👣 ───────────
  double? footSize;    // ضریب اندازه (پیش‌فرض 1.0)
  double? footSpeed;   // ثانیه برای یک دور (پیش‌فرض 3.2)
  bool footPlaying;    // آیا در حال حرکت است؟
  double? footPos;     // موقعیت 0..1 (اگر ثابت باشد)

  Map<String, dynamic> extra;

  ActionNode({
    String? id,
    this.text = '',
    this.style = '',
    this.color,
    this.weight = 5,
    this.labelDX = 0,
    this.labelDY = 0,
    this.labelSize,
    List<ActionNode>? children,
    List<ImageItem>? images,
    Map<String, dynamic>? logs,
    Map<String, dynamic>? entries,
    Map<String, dynamic>? time,
    Map<String, dynamic>? ranges,
    this.timerStart,
    this.isRoutine = false,
    this.detached = false,
    this.originX,
    this.originY,
    this.dir,
    this.len,
    this.bend1,
    this.bend2,
    this.footSize,
    this.footSpeed,
    this.footPlaying = true,
    this.footPos,
    Map<String, dynamic>? extra,
  })  : id = id ?? uid(),
        children = children ?? [],
        images = images ?? [],
        logs = logs ?? {},
        entries = entries ?? {},
        time = time ?? {},
        ranges = ranges ?? {},
        extra = extra ?? {};

  static const _known = {
    'id', 'text', 'style', 'color', 'weight', 'labelDX', 'labelDY',
    'labelSize', 'children', 'images', 'logs', 'entries', 'time', 'ranges',
    'timerStart', 'isRoutine', 'detached', 'originX', 'originY', 'dir', 'len',
    'bend1', 'bend2',
    'footSize', 'footSpeed', 'footPlaying', 'footPos',
  };

  factory ActionNode.fromJson(dynamic raw) {
    final j = _m(raw);
    final style = _s(j['style'], '');
    return ActionNode(
      id: j['id'] is String ? j['id'] as String : null,
      text: _s(j['text'], ''),
      style: (style.isEmpty || kBranchStyles.containsKey(style)) ? style : '',
      color: j['color'] is String ? j['color'] as String : null,
      weight: _d(j['weight'], 5),
      labelDX: _d(j['labelDX'], 0),
      labelDY: _d(j['labelDY'], 0),
      labelSize: _dn(j['labelSize']),
      children: j['children'] is List
          ? (j['children'] as List).map(ActionNode.fromJson).toList()
          : [],
      images: _images(j['images']),
      logs: _m(j['logs']),
      entries: _m(j['entries']),
      time: _m(j['time']),
      ranges: _m(j['ranges']),
      timerStart: j['timerStart'] is num
          ? (j['timerStart'] as num).toInt()
          : null,
      isRoutine: _b(j['isRoutine'], false),
      detached: _b(j['detached'], false),
      originX: _dn(j['originX']),
      originY: _dn(j['originY']),
      dir: _dn(j['dir']),
      len: _dn(j['len']),
      bend1: _dn(j['bend1']),
      bend2: _dn(j['bend2']),
      footSize: _dn(j['footSize']),
      footSpeed: _dn(j['footSpeed']),
      footPlaying: _b(j['footPlaying'], true),
      footPos: _dn(j['footPos']),
      extra: _rest(j, _known),
    );
  }

  Map<String, dynamic> toJson() => {
        ...extra,
        'id': id,
        'text': text,
        'style': style,
        'color': color,
        'weight': weight,
        'labelDX': labelDX,
        'labelDY': labelDY,
        'labelSize': labelSize,
        'children': children.map((c) => c.toJson()).toList(),
        'images': images.map((i) => i.toJson()).toList(),
        'logs': logs,
        'entries': entries,
        'isRoutine': isRoutine,
        'detached': detached,
        'time': time,
        'ranges': ranges,
        if (timerStart != null) 'timerStart': timerStart,
        if (originX != null) 'originX': originX,
        if (originY != null) 'originY': originY,
        if (dir != null) 'dir': dir,
        if (len != null) 'len': len,
        if (bend1 != null) 'bend1': bend1,
        if (bend2 != null) 'bend2': bend2,
        if (footSize != null) 'footSize': footSize,
        if (footSpeed != null) 'footSpeed': footSpeed,
        'footPlaying': footPlaying,
        if (footPos != null) 'footPos': footPos,
      };
}

int countActions(List<ActionNode> list) =>
    list.fold(0, (n, a) => n + 1 + countActions(a.children));

class Goal implements MapHost {
  @override
  String id;
  String name, icon, freq, trunkStyle, feeling;
  @override
  String branchStyle;
  @override
  String? color;
  @override
  double x, y;
  @override
  double radius;
  @override
  bool get isRing => false;
  double iconScale,
      feelingOffsetX,
      feelingOffsetY,
      feelingScale,
      labelDX,
      labelDY;
  double? labelSize;
  bool reached, collapsed;
  int? createdAt;
  int lastActivity;
  List<ImageItem> images;
  @override
  List<ActionNode> actions;
  Map<String, dynamic> logs, extra;

  Goal({
    String? id,
    this.name = '',
    this.icon = '🎯',
    this.freq = 'alpha',
    this.branchStyle = 'organic',
    this.trunkStyle = '',
    this.feeling = '',
    this.color,
    this.x = 0,
    this.y = 0,
    this.radius = 20,
    this.iconScale = 1,
    this.feelingOffsetX = 0,
    this.feelingOffsetY = 0,
    this.feelingScale = 1,
    this.labelDX = 0,
    this.labelDY = 0,
    this.labelSize,
    this.reached = false,
    this.collapsed = false,
    this.createdAt,
    int? lastActivity,
    List<ImageItem>? images,
    List<ActionNode>? actions,
    Map<String, dynamic>? logs,
    Map<String, dynamic>? extra,
  })  : id = id ?? uid(),
        lastActivity = lastActivity ??
            createdAt ??
            DateTime.now().millisecondsSinceEpoch,
        images = images ?? [],
        actions = actions ?? [],
        logs = logs ?? {},
        extra = extra ?? {};

  static const _known = {
    'id', 'name', 'icon', 'freq', 'branchStyle', 'trunkStyle', 'feeling',
    'color', 'x', 'y', 'radius', 'iconScale', 'feelingOffsetX',
    'feelingOffsetY', 'feelingScale', 'labelDX', 'labelDY', 'labelSize',
    'reached', 'collapsed', 'createdAt', 'lastActivity', 'images', 'actions',
    'logs',
  };

  factory Goal.fromJson(dynamic raw) {
    final j = _m(raw);
    final created =
        j['createdAt'] is num ? (j['createdAt'] as num).toInt() : null;
    final trunk = _s(j['trunkStyle'], '');
    var radius = _d(j['radius'], 20);
    if (radius < 12) radius = 20;
    var fs = _d(j['feelingScale'], 1);
    if (fs < 0.5) fs = 1;
    final freq = _s(j['freq'], 'alpha');
    final bs = _s(j['branchStyle'], 'organic');
    final icon = _s(j['icon'], '');
    return Goal(
      id: j['id'] is String ? j['id'] as String : null,
      name: _s(j['name'], ''),
      icon: icon.isEmpty ? '🎯' : icon,
      freq: kFreqBands.containsKey(freq) ? freq : 'alpha',
      branchStyle: kBranchStyles.containsKey(bs) ? bs : 'organic',
      trunkStyle:
          (trunk.isEmpty || kTrunkStyles.containsKey(trunk)) ? trunk : '',
      feeling: _s(j['feeling'], ''),
      color: j['color'] is String ? j['color'] as String : null,
      x: _d(j['x'], 0),
      y: _d(j['y'], 0),
      radius: radius,
      iconScale: _clampScale(_d(j['iconScale'], 1)),
      feelingOffsetX: _d(j['feelingOffsetX'], 0),
      feelingOffsetY: _d(j['feelingOffsetY'], 0),
      feelingScale: fs,
      labelDX: _d(j['labelDX'], 0),
      labelDY: _d(j['labelDY'], 0),
      labelSize: _dn(j['labelSize']),
      reached: _b(j['reached'], false),
      collapsed: _b(j['collapsed'], false),
      createdAt: created,
      lastActivity:
          j['lastActivity'] is num ? (j['lastActivity'] as num).toInt() : null,
      images: _images(j['images']),
      actions: j['actions'] is List
          ? (j['actions'] as List).map(ActionNode.fromJson).toList()
          : [],
      logs: _m(j['logs']),
      extra: _rest(j, _known),
    );
  }

  Map<String, dynamic> toJson() => {
        ...extra,
        'id': id,
        'name': name,
        'icon': icon,
        'freq': freq,
        'branchStyle': branchStyle,
        'trunkStyle': trunkStyle,
        'feeling': feeling,
        'color': color,
        'x': x,
        'y': y,
        'radius': radius,
        'iconScale': iconScale,
        'feelingOffsetX': feelingOffsetX,
        'feelingOffsetY': feelingOffsetY,
        'feelingScale': feelingScale,
        'labelDX': labelDX,
        'labelDY': labelDY,
        'labelSize': labelSize,
        'reached': reached,
        'collapsed': collapsed,
        'createdAt': createdAt,
        'lastActivity': lastActivity,
        'images': images.map((i) => i.toJson()).toList(),
        'actions': actions.map((a) => a.toJson()).toList(),
        'logs': logs,
      };
}

class Ring implements MapHost {
  @override
  String id;
  String label, note, icon, goalId;
  @override
  String color;
  @override
  String branchStyle;
  @override
  double x, y, radius;
  @override
  bool get isRing => true;
  double iconScale, labelDX, labelDY;
  double? labelSize;
  bool collapsed;
  int lastActivity;
  List<ImageItem> images;
  @override
  List<ActionNode> actions;
  Map<String, dynamic> logs, extra;

  Ring({
    String? id,
    this.label = 'نزدیک شدن به هدف',
    this.color = kRingColor,
    this.note = '',
    this.icon = '🌟',
    this.branchStyle = 'organic',
    this.goalId = '',
    this.x = 0,
    this.y = 0,
    this.radius = 30,
    this.iconScale = 1,
    this.labelDX = 0,
    this.labelDY = 0,
    this.labelSize,
    this.collapsed = false,
    int? lastActivity,
    List<ImageItem>? images,
    List<ActionNode>? actions,
    Map<String, dynamic>? logs,
    Map<String, dynamic>? extra,
  })  : id = id ?? uid(),
        lastActivity = lastActivity ?? DateTime.now().millisecondsSinceEpoch,
        images = images ?? [],
        actions = actions ?? [],
        logs = logs ?? {},
        extra = extra ?? {};

  static const _known = {
    'id', 'label', 'color', 'note', 'icon', 'branchStyle', 'goalId', 'x', 'y',
    'radius', 'iconScale', 'labelDX', 'labelDY', 'labelSize', 'collapsed',
    'lastActivity', 'images', 'actions', 'logs',
  };

  factory Ring.fromJson(dynamic raw) {
    final j = _m(raw);
    var radius = _d(j['radius'], 30);
    if (radius < 15) radius = 30;
    final bs = _s(j['branchStyle'], 'organic');
    final icon = _s(j['icon'], '');
    return Ring(
      id: j['id'] is String ? j['id'] as String : null,
      label: _s(j['label'], 'نزدیک شدن به هدف'),
      color: _s(j['color'], kRingColor),
      note: _s(j['note'], ''),
      icon: icon.isEmpty ? '🌟' : icon,
      branchStyle: kBranchStyles.containsKey(bs) ? bs : 'organic',
      goalId: _s(j['goalId'], ''),
      x: _d(j['x'], 0),
      y: _d(j['y'], 0),
      radius: radius,
      iconScale: _clampScale(_d(j['iconScale'], 1)),
      labelDX: _d(j['labelDX'], 0),
      labelDY: _d(j['labelDY'], 0),
      labelSize: _dn(j['labelSize']),
      collapsed: _b(j['collapsed'], false),
      lastActivity:
          j['lastActivity'] is num ? (j['lastActivity'] as num).toInt() : null,
      images: _images(j['images']),
      actions: j['actions'] is List
          ? (j['actions'] as List).map(ActionNode.fromJson).toList()
          : [],
      logs: _m(j['logs']),
      extra: _rest(j, _known),
    );
  }

  Map<String, dynamic> toJson() => {
        ...extra,
        'id': id,
        'label': label,
        'color': color,
        'note': note,
        'icon': icon,
        'branchStyle': branchStyle,
        'goalId': goalId,
        'x': x,
        'y': y,
        'radius': radius,
        'iconScale': iconScale,
        'labelDX': labelDX,
        'labelDY': labelDY,
        'labelSize': labelSize,
        'collapsed': collapsed,
        'lastActivity': lastActivity,
        'images': images.map((i) => i.toJson()).toList(),
        'actions': actions.map((a) => a.toJson()).toList(),
        'logs': logs,
      };
}

class MeNode {
  String color, note, name;
  double x, y, radius, labelDX, labelDY;
  double? labelSize;
  List<ImageItem> images;
  Map<String, dynamic> extra;

  MeNode({
    this.color = '#f4c542',
    this.note = '',
    this.name = 'من',
    this.x = 0,
    this.y = 0,
    this.radius = 34,
    this.labelDX = 0,
    this.labelDY = 0,
    this.labelSize,
    List<ImageItem>? images,
    Map<String, dynamic>? extra,
  })  : images = images ?? [],
        extra = extra ?? {};

  static const _known = {
    'color', 'note', 'name', 'x', 'y', 'radius', 'labelDX', 'labelDY',
    'labelSize', 'images',
  };

  factory MeNode.fromJson(dynamic raw) {
    final j = _m(raw);
    var r = _d(j['radius'], 34);
    if (r < 20) r = 34;
    return MeNode(
      color: _s(j['color'], '#f4c542'),
      note: _s(j['note'], ''),
      name: _s(j['name'], 'من'),
      x: _d(j['x'], 0),
      y: _d(j['y'], 0),
      radius: r,
      labelDX: _d(j['labelDX'], 0),
      labelDY: _d(j['labelDY'], 0),
      labelSize: _dn(j['labelSize']),
      images: _images(j['images']),
      extra: _rest(j, _known),
    );
  }

  Map<String, dynamic> toJson() => {
        ...extra,
        'color': color,
        'note': note,
        'name': name,
        'x': x,
        'y': y,
        'radius': radius,
        'labelDX': labelDX,
        'labelDY': labelDY,
        'labelSize': labelSize,
        'images': images.map((i) => i.toJson()).toList(),
      };
}

class MapState {
  MeNode me;
  List<Goal> goals;
  List<Ring> rings;
  String textColor, trunkStyle;
  double fontSize;
  bool showDateStamps, showTimeStamps, showRingLinks, showEmotionWidget;
  String userName;
  double footScale;
  Map<String, dynamic> extra;

  MapState({
    MeNode? me,
    List<Goal>? goals,
    List<Ring>? rings,
    this.textColor = kDefaultTextColor,
    this.trunkStyle = 'dashed',
    this.fontSize = 14,
    this.showDateStamps = true,
    this.showTimeStamps = true,
    this.showRingLinks = false,
    this.showEmotionWidget = true,
    this.userName = '',
    this.footScale = 1.0,
    Map<String, dynamic>? extra,
  })  : me = me ?? MeNode(),
        goals = goals ?? [],
        rings = rings ?? [],
        extra = extra ?? {};

  static const _known = {
    'me', 'goals', 'rings', 'textColor', 'trunkStyle', 'fontSize',
    'showDateStamps', 'showTimeStamps', 'showRingLinks', 'showEmotionWidget',
    'userName', 'footScale',
  };

  factory MapState.fromJson(dynamic raw) {
    final j = _m(raw);
    final ts = _s(j['trunkStyle'], 'dashed');
    var fs = _d(j['fontSize'], 14);
    if (fs < 8) fs = 14;
    final extra = _rest(j, _known)..remove('_lite');
    return MapState(
      me: MeNode.fromJson(j['me']),
      goals: j['goals'] is List
          ? (j['goals'] as List).map(Goal.fromJson).toList()
          : [],
      rings: j['rings'] is List
          ? (j['rings'] as List).map(Ring.fromJson).toList()
          : [],
      textColor: _s(j['textColor'], kDefaultTextColor),
      trunkStyle: kTrunkStyles.containsKey(ts) ? ts : 'dashed',
      fontSize: fs,
      showDateStamps: _b(j['showDateStamps'], true),
      showTimeStamps: _b(j['showTimeStamps'], true),
      showRingLinks: _b(j['showRingLinks'], false),
      showEmotionWidget: _b(j['showEmotionWidget'], true),
      userName: _s(j['userName'], ''),
      footScale: _d(j['footScale'], 1.0),
      extra: extra,
    );
  }

  Map<String, dynamic> toJson() => {
        ...extra,
        'me': me.toJson(),
        'goals': goals.map((g) => g.toJson()).toList(),
        'rings': rings.map((r) => r.toJson()).toList(),
        'textColor': textColor,
        'trunkStyle': trunkStyle,
        'fontSize': fontSize,
        'showDateStamps': showDateStamps,
        'showTimeStamps': showTimeStamps,
        'showRingLinks': showRingLinks,
        'showEmotionWidget': showEmotionWidget,
        'userName': userName,
        'footScale': footScale,
        '_savedAt': DateTime.now().millisecondsSinceEpoch,
      };

  bool get ringsCollapsed => extra['ringsCollapsed'] == true;
  set ringsCollapsed(bool v) => extra['ringsCollapsed'] = v;

  Object? findHost(String id) {
    for (final g in goals) {
      if (g.id == id) return g;
    }
    for (final r in rings) {
      if (r.id == id) return r;
    }
    return null;
  }

  List<Ring> ringsOfGoal(Goal g) =>
      rings.where((r) => r.goalId == g.id).toList();
}
