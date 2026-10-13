import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../models/map_models.dart';
import '../state/map_store.dart';
import 'camera.dart';
import 'geometry.dart';
import 'hit_registry.dart';
import 'map_ops.dart';

enum _Mode {
  none,
  pan,
  pinch,
  dragNode,
  dragLabel,
  dragImage,
  resizeNode,
  resizeLabel,
  resizeImage,
  dragFoot,
  dragWalker,
}

class _Pending {
  _Pending(
    this.hostId,
    this.actionId,
    this.imgIdx,
    this.isLabel,
    this.start, {
    this.isFoot = false,
    this.isWalker = false,
    this.isTrophy = false,
  });
  final String hostId;
  final String actionId;
  final int? imgIdx;
  final bool isLabel;
  final bool isFoot;
  final bool isWalker;
  final bool isTrophy;
  final Offset start;
}

class MapInteraction {
  MapInteraction({
    required this.cam,
    required this.store,
    required this.hits,
    required this.isResizeMode,
    required this.onEditMe,
    required this.onEditGoal,
    required this.onEditRing,
    required this.onEditAction,
    this.onTimeBranch,
    this.onShowBranchMenu,
  });

  final CameraController cam;
  final MapStore store;
  final HitRegistry hits;
  final bool Function() isResizeMode;
  final void Function() onEditMe;
  final void Function(String id) onEditGoal;
  final void Function(String id) onEditRing;
  final void Function(String hostId, String actionId) onEditAction;
  final void Function(String hostId, String actionId)? onTimeBranch;
  // نگه داشته شده برای سازگاری با map_canvas.dart.
  // در این نسخه استفاده نمی‌شود.
  final void Function(String hostId, String actionId)? onShowBranchMenu;

  static const double _slop = 6;

  final Map<int, Offset> _ptrs = {};
  _Mode _mode = _Mode.none;
  bool _dirty = false;
  bool _slopPassed = true;
  Offset _downPtr = Offset.zero;
  HitEntry? _tap;

  // pan
  Offset _panStart = Offset.zero;
  double _panCamX = 0, _panCamY = 0;

  // pinch
  double _pinchDist = 1, _pinchScale = 1, _pinchCamX = 0, _pinchCamY = 0;
  Offset _pinchMid = Offset.zero;

  // drag
  String _dType = '', _dId = '', _dHost = '';
  Offset _dOff = Offset.zero;
  int _dImg = 0;
  double _dStartA = 0, _dStartB = 0;
  Offset _dStartWorld = Offset.zero;

  // long press
  Timer? _lp;
  bool _holdArmed = false;
  _Pending? _pending;

  // resize
  double _rsStartDist = 1, _rsStart = 1;

  void dispose() => _cancelLongPress();

  void _cancelLongPress() {
    _lp?.cancel();
    _lp = null;
  }

  // ───────────────────────── دسترسی به گره‌ها ─────────────────────────

  Object? _nodeRef(String type, String id, String hostId) {
    final s = store.state;
    switch (type) {
      case 'me':
        return s.me;
      case 'goal':
      case 'ring':
        return s.findHost(id);
      case 'action':
        final h = s.findHost(hostId);
        if (h is! MapHost) return null;
        return findActionNode(h.actions, id)?.node;
    }
    return null;
  }

  (double, double) _labelOff(Object n) => switch (n) {
        MeNode m => (m.labelDX, m.labelDY),
        Goal g => (g.labelDX, g.labelDY),
        Ring r => (r.labelDX, r.labelDY),
        ActionNode a => (a.labelDX, a.labelDY),
        _ => (0.0, 0.0),
      };

  void _setLabelOff(Object n, double dx, double dy) {
    switch (n) {
      case MeNode m:
        m.labelDX = dx;
        m.labelDY = dy;
      case Goal g:
        g.labelDX = dx;
        g.labelDY = dy;
      case Ring r:
        r.labelDX = dx;
        r.labelDY = dy;
      case ActionNode a:
        a.labelDX = dx;
        a.labelDY = dy;
    }
  }

  double? _labelSizeOf(Object n) => switch (n) {
        MeNode m => m.labelSize,
        Goal g => g.labelSize,
        Ring r => r.labelSize,
        ActionNode a => a.labelSize,
        _ => null,
      };

  void _setLabelSize(Object n, double v) {
    switch (n) {
      case MeNode m:
        m.labelSize = v;
      case Goal g:
        g.labelSize = v;
      case Ring r:
        r.labelSize = v;
      case ActionNode a:
        a.labelSize = v;
    }
  }

  double _defaultLabelSize(String type, String id) {
    final fs = store.state.fontSize;
    switch (type) {
      case 'me':
        return math.max(14.0, fs) + 3;
      case 'goal':
        return math.max(14.0, fs);
      case 'ring':
        return math.max(14.0, fs) - 2;
      default:
        final sc = hits.geom[id]?.scale ?? 1.0;
        return math.max(12.0, fs * math.min(1.0, sc + 0.3));
    }
  }

  Offset _posOf(Object n) => switch (n) {
        MeNode m => Offset(m.x, m.y),
        Goal g => Offset(g.x, g.y),
        Ring r => Offset(r.x, r.y),
        _ => Offset.zero,
      };

  double _radiusOf(Object n) => switch (n) {
        MeNode m => m.radius,
        Goal g => g.radius,
        Ring r => r.radius,
        _ => 20.0,
      };

  void _setRadius(Object n, double v) {
    switch (n) {
      case MeNode m:
        m.radius = math.max(20.0, math.min(70.0, v));
      case Goal g:
        g.radius = math.max(12.0, math.min(90.0, v));
      case Ring r:
        r.radius = math.max(15.0, math.min(90.0, v));
    }
  }

  // ───────────────────────── pointer down ─────────────────────────

  void pointerDown(PointerDownEvent e) {
    final pos = e.localPosition;
    final hit = hits.hitTest(cam.screenToWorld(pos), cam.scale);

    if (_ptrs.isEmpty && hit != null && hit.type == 'goalToggle') {
      store.toggleGoalCollapse(hit.id);
      return;
    }

    if (_ptrs.isEmpty && hit != null && hit.type == 'actionTime') {
      onTimeBranch?.call(hit.hostId, hit.id);
      return;
    }

    _ptrs[e.pointer] = pos;
    if (_ptrs.length == 2) {
      _startTwoFingers();
      return;
    }
    if (_ptrs.length > 2) return;

    _downPtr = pos;
    _tap = null;
    _dirty = false;
    _holdArmed = false;
    _pending = null;
    _cancelLongPress();

    if (hit == null) {
      _startPan(pos);
      return;
    }

    final world = cam.screenToWorld(pos);

    // ─── قدم روی شاخه ───
    if (hit.type == 'foot') {
      _pending = _Pending(hit.hostId, hit.id, null, false, pos, isFoot: true);
      _slopPassed = false;
      return;
    }

    // ─── قدم‌زن روی تنه ───
    if (hit.type == 'walker') {
      _pending = _Pending(hit.id, '', null, false, pos, isWalker: true);
      _slopPassed = false;
      return;
    }

    // ─── جام روی هدف ───
    if (hit.type == 'trophy') {
      _pending = _Pending(hit.id, '', null, false, pos, isTrophy: true);
      _slopPassed = false;
      return;
    }

    if (hit.type == 'action') {
      _pending = _Pending(
          hit.hostId, hit.id,
          hit.kind == HitKind.image ? hit.imgIdx : null,
          hit.kind == HitKind.label, pos);
      _slopPassed = false;
      _lp = Timer(const Duration(milliseconds: 600), () {
        _holdArmed = true;
        HapticFeedback.lightImpact();
      });
      return;
    }

    final node = _nodeRef(hit.type, hit.id, hit.hostId);
    if (node == null) {
      _startPan(pos);
      return;
    }
    _tap = hit;
    _slopPassed = false;
    _dType = hit.type;
    _dId = hit.id;
    _dHost = hit.hostId;
    if (hit.kind == HitKind.label) {
      final off = _labelOff(node);
      _mode = _Mode.dragLabel;
      _dStartA = off.$1;
      _dStartB = off.$2;
      _dStartWorld = world;
    } else {
      _mode = _Mode.dragNode;
      _dOff = world - _posOf(node);
    }
  }

  void _startPan(Offset pos) {
    _mode = _Mode.pan;
    _slopPassed = true;
    _panStart = pos;
    _panCamX = cam.x;
    _panCamY = cam.y;
  }

  void _startTwoFingers() {
    _cancelLongPress();
    _pending = null;
    _holdArmed = false;
    _tap = null;
    final pts = _ptrs.values.toList();
    final d = math.max(1.0, (pts[0] - pts[1]).distance);

    if (isResizeMode()) {
      final h1 = hits.hitTest(cam.screenToWorld(pts[0]), cam.scale);
      final h2 = hits.hitTest(cam.screenToWorld(pts[1]), cam.scale);
      if (h1 != null &&
          h2 != null &&
          h1.type == h2.type &&
          h1.id == h2.id &&
          h1.hostId == h2.hostId) {
        final node = _nodeRef(h1.type, h1.id, h1.hostId);
        if (node != null) {
          _dType = h1.type;
          _dId = h1.id;
          _dHost = h1.hostId;
          _rsStartDist = d;
          if (h1.kind == HitKind.image &&
              h2.kind == HitKind.image &&
              h1.imgIdx == h2.imgIdx &&
              node is ActionNode) {
            final idx = h1.imgIdx ?? 0;
            if (idx < node.images.length) {
              _dImg = idx;
              _rsStart = node.images[idx].size;
              _mode = _Mode.resizeImage;
              return;
            }
          }
          if (h1.kind == HitKind.label && h2.kind == HitKind.label) {
            _rsStart = _labelSizeOf(node) ?? _defaultLabelSize(h1.type, h1.id);
            _mode = _Mode.resizeLabel;
            return;
          }
          if (h1.kind == HitKind.node &&
              h2.kind == HitKind.node &&
              h1.type != 'action') {
            _rsStart = _radiusOf(node);
            _mode = _Mode.resizeNode;
            return;
          }
        }
      }
    }

    _mode = _Mode.pinch;
    _pinchDist = d;
    _pinchScale = cam.scale;
    _pinchMid = (pts[0] + pts[1]) / 2;
    _pinchCamX = cam.x;
    _pinchCamY = cam.y;
  }

  // ───────────────────────── pointer move ─────────────────────────

  void pointerMove(PointerMoveEvent e) {
    if (!_ptrs.containsKey(e.pointer)) return;
    _ptrs[e.pointer] = e.localPosition;
    _process(e.localPosition);
  }

  void _process(Offset cur) {
    switch (_mode) {
      case _Mode.pinch:
        _doPinch();
        return;
      case _Mode.resizeImage:
      case _Mode.resizeLabel:
      case _Mode.resizeNode:
        _doResize();
        return;
      default:
        break;
    }

    final p = _pending;
    if (p != null) {
      final moved = (cur - p.start).distance;
      if (moved < (_holdArmed ? 10 : _slop)) return;
      _cancelLongPress();
      _pending = null;
      _slopPassed = true;
      _beginFromPending(p, cur);
    }

    if (_mode == _Mode.none) return;
    if (!_slopPassed) {
      if ((cur - _downPtr).distance < _slop) return;
      _slopPassed = true;
      _tap = null;
    }

    final w = cam.screenToWorld(cur);
    switch (_mode) {
      case _Mode.pan:
        cam.setView(_panCamX + (cur.dx - _panStart.dx),
            _panCamY + (cur.dy - _panStart.dy), cam.scale);
      case _Mode.dragLabel:
        final lbNode = _nodeRef(_dType, _dId, _dHost);
        if (lbNode == null) return;
        _setLabelOff(lbNode, _dStartA + (w.dx - _dStartWorld.dx),
            _dStartB + (w.dy - _dStartWorld.dy));
        _mark();
      case _Mode.dragImage:
        final imNode = _nodeRef('action', _dId, _dHost);
        if (imNode is! ActionNode || _dImg >= imNode.images.length) return;
        imNode.images[_dImg].dx = _dStartA + (w.dx - _dStartWorld.dx);
        imNode.images[_dImg].dy = _dStartB + (w.dy - _dStartWorld.dy);
        _mark();
      case _Mode.dragNode:
        _doDragNode(w);
      case _Mode.dragFoot:
        _doDragFoot(w);
      case _Mode.dragWalker:
        _doDragWalker(w);
      default:
        break;
    }
  }

  void _mark() {
    _dirty = true;
    store.touch();
  }

  void _beginFromPending(_Pending p, Offset cur) {
    if (p.isWalker) {
      _mode = _Mode.dragWalker;
      _dType = 'walker';
      _dHost = p.hostId;
      _dId = p.hostId;
      _dStartWorld = cam.screenToWorld(p.start);
      _slopPassed = true;
      _tap = null;
      return;
    }

    if (p.isTrophy) {
      return;
    }

    if (p.isFoot) {
      _mode = _Mode.dragFoot;
      _dType = 'foot';
      _dHost = p.hostId;
      _dId = p.actionId;
      _dStartWorld = cam.screenToWorld(p.start);
      _slopPassed = true;
      _tap = null;
      return;
    }

    final host = store.state.findHost(p.hostId);
    if (host is! MapHost) return;
    final found = findActionNode(host.actions, p.actionId);
    if (found == null) return;
    final node = found.node;
    final ws = cam.screenToWorld(p.start);
    final w = cam.screenToWorld(cur);

    if (_holdArmed) {
      _holdArmed = false;
      _holdToggle(host, node, ws);
    } else if (node.detached && !p.isLabel && p.imgIdx == null) {
      _beginActionDrag(
          host.id, node.id, ws - Offset(node.originX ?? 0, node.originY ?? 0));
    } else if (p.imgIdx != null && p.imgIdx! < node.images.length) {
      final img = node.images[p.imgIdx!];
      _mode = _Mode.dragImage;
      _dId = node.id;
      _dHost = host.id;
      _dImg = p.imgIdx!;
      _dStartA = img.dx;
      _dStartB = img.dy;
      _dStartWorld = w;
    } else if (p.isLabel) {
      _mode = _Mode.dragLabel;
      _dType = 'action';
      _dId = node.id;
      _dHost = host.id;
      _dStartA = node.labelDX;
      _dStartB = node.labelDY;
      _dStartWorld = w;
    } else {
      final ent = hits.geom[node.id];
      if (ent != null) _beginActionDrag(host.id, node.id, ws - ent.end);
    }
  }

  void _beginActionDrag(String hostId, String actionId, Offset off) {
    _mode = _Mode.dragNode;
    _dType = 'action';
    _dHost = hostId;
    _dId = actionId;
    _dOff = off;
    _slopPassed = true;
    _tap = null;
  }

  void _holdToggle(MapHost host, ActionNode node, Offset ws) {
    if (node.detached) {
      resetBranchPos(node);
      _beginActionDrag(host.id, node.id, Offset.zero);
    } else {
      final ent = hits.geom[node.id];
      if (ent == null) return;
      node.detached = true;
      node.originX = ent.originPt.dx;
      node.originY = ent.originPt.dy;
      node.dir ??= 0;
      node.len ??= 30;
      node.bend1 ??= 0;
      node.bend2 ??= 0;
      _beginActionDrag(host.id, node.id, ws - ent.originPt);
    }
    _mark();
  }

  void _doDragNode(Offset w) {
    final s = store.state;
    final target = w - _dOff;
    if (_dType == 'me') {
      s.me.x = target.dx;
      s.me.y = target.dy;
    } else if (_dType == 'goal') {
      final g = s.findHost(_dId);
      if (g is Goal) {
        g.x = target.dx;
        g.y = target.dy;
      }
    } else if (_dType == 'ring') {
      final r = s.findHost(_dId);
      if (r is Ring) {
        Nearest? best;
        for (final g in s.goals) {
          final res = nearestOnCubic(trunkControlPoints(g, s.me), target);
          if (best == null || res.dist < best.dist) best = res;
        }
        if (best != null && best.dist < 18 / cam.scale) {
          r.x = best.pt.dx;
          r.y = best.pt.dy;
        } else {
          r.x = target.dx;
          r.y = target.dy;
        }
      }
    } else if (_dType == 'action') {
      final host = s.findHost(_dHost);
      if (host is! MapHost) return;
      final found = findActionNode(host.actions, _dId);
      if (found == null) return;
      final node = found.node;
      if (node.detached) {
        node.originX = target.dx;
        node.originY = target.dy;
        _snapOriginToTrunk(host, node);
      } else {
        final ent = hits.geom[node.id];
        if (ent == null) return;
        final d = target - ent.originPt;
        node.dir = math.atan2(d.dy, d.dx);
        node.len = math.max(8.0, d.distance);
      }
    }
    _mark();
  }

  /// کشیدن قدم روی شاخه.
  /// پروجکشن نقطه روی پاره‌خط (origin → end) و clamp به [0.06, 0.94].
  void _doDragFoot(Offset w) {
    final host = store.state.findHost(_dHost);
    if (host is! MapHost) return;
    final found = findActionNode(host.actions, _dId);
    if (found == null) return;
    final node = found.node;

    final ent = hits.geom[node.id];
    if (ent == null) return;

    final o = ent.originPt;
    final e = ent.end;
    final dx = e.dx - o.dx;
    final dy = e.dy - o.dy;
    final len2 = dx * dx + dy * dy;
    if (len2 < 1) return;

    final t = ((w.dx - o.dx) * dx + (w.dy - o.dy) * dy) / len2;
    node.footPos = t.clamp(0.06, 0.94);
    node.footPlaying = false;
    _mark();
  }

  /// کشیدن قدم‌زن روی تنه‌ی هدف.
  /// پروجکشن روی منحنی بزیه‌ی تنه با ریز‌یابی ternary search.
  void _doDragWalker(Offset w) {
    final s = store.state;
    final g = s.findHost(_dHost);
    if (g is! Goal) return;

    final cp = trunkControlPoints(g, s.me);

    // درشت: نزدیک‌ترین نقطه روی نمونه‌های ۴۰گانه
    double bestT = 0.5;
    double bestD = double.infinity;
    for (var i = 0; i <= 40; i++) {
      final t = i / 40.0;
      final d = (cp.at(t) - w).distance;
      if (d < bestD) {
        bestD = d;
        bestT = t;
      }
    }
    // ریز: جست‌وجوی سه‌تایی در فاصله‌ی کوچک
    final refined = _refineT(cp, w, bestT);

    g.extra['walkerPos'] = refined.clamp(0.06, 0.94);
    g.extra['walkerPlaying'] = false;
    _mark();
  }

  double _refineT(Cubic cp, Offset w, double near) {
    var lo = math.max(0.0, near - 0.05);
    var hi = math.min(1.0, near + 0.05);
    for (var i = 0; i < 12; i++) {
      final t1 = lo + (hi - lo) / 3;
      final t2 = hi - (hi - lo) / 3;
      final d1 = (cp.at(t1) - w).distance;
      final d2 = (cp.at(t2) - w).distance;
      if (d1 < d2) {
        hi = t2;
      } else {
        lo = t1;
      }
    }
    return (lo + hi) / 2;
  }

  void _snapOriginToTrunk(MapHost host, ActionNode node) {
    final cp = trunkControlPoints(host, store.state.me);
    final res = nearestOnCubic(cp, Offset(node.originX ?? 0, node.originY ?? 0));
    final thr = math.max(34 / cam.scale, 14.0);
    if (res.dist < thr) {
      node.originX = res.pt.dx;
      node.originY = res.pt.dy;
    }
  }

  void _doPinch() {
    if (_ptrs.length != 2) return;
    final pts = _ptrs.values.toList();
    final d = (pts[0] - pts[1]).distance;
    final m = (pts[0] + pts[1]) / 2;
    final ns = math.max(0.05, math.min(4.0, _pinchScale * (d / _pinchDist)));
    final wx = (_pinchMid.dx - _pinchCamX) / _pinchScale;
    final wy = (_pinchMid.dy - _pinchCamY) / _pinchScale;
    cam.setView(m.dx - wx * ns, m.dy - wy * ns, ns);
  }

  void _doResize() {
    if (_ptrs.length != 2) return;
    final pts = _ptrs.values.toList();
    final ratio = (pts[0] - pts[1]).distance / _rsStartDist;
    final node = _nodeRef(_dType, _dId, _dHost);
    if (node == null) return;
    final v = _rsStart * ratio;
    switch (_mode) {
      case _Mode.resizeImage:
        if (node is ActionNode && _dImg < node.images.length) {
          node.images[_dImg].size = math.max(16.0, math.min(260.0, v));
        }
      case _Mode.resizeLabel:
        _setLabelSize(node, math.max(8.0, math.min(60.0, v)));
      case _Mode.resizeNode:
        _setRadius(node, v);
      default:
        break;
    }
    _mark();
  }

  // ───────────────────────── pointer up ─────────────────────────

  void pointerUp(PointerUpEvent e) {
    if (!_ptrs.containsKey(e.pointer)) return;

    final p = _pending;
    if (p != null && _ptrs.length == 1) {
      _cancelLongPress();
      _pending = null;
      _ptrs.remove(e.pointer);
      _holdArmed = false;
      final wasDrag = _slopPassed;
      _finish();

      // ─── قدم‌زن: تپ = toggle حرکت/توقف ───
      if (p.isWalker) {
        if (!wasDrag) {
          final g = store.state.findHost(p.hostId);
          if (g is Goal) {
            final playing = g.extra['walkerPlaying'] as bool? ?? true;
            g.extra['walkerPlaying'] = !playing;
            store.changed();
            store.toast?.call(
                !playing ? 'قدم‌زن به راه افتاد 👣' : 'قدم‌زن متوقف شد');
          }
        }
        return;
      }

      // ─── جام: تپ = نمایش درصد پیشرفت ───
      if (p.isTrophy) {
        if (!wasDrag) {
          final g = store.state.findHost(p.hostId);
          if (g is Goal) {
            var totalLogs = 0;
            var branches = 0;
            void walk(List<ActionNode> list) {
              for (final a in list) {
                branches++;
                for (final v in a.logs.values) {
                  if (v == true ||
                      v == 'انجام شد ✓' ||
                      (v is String && v.isNotEmpty)) {
                    totalLogs++;
                  }
                }
                walk(a.children);
              }
            }
            walk(g.actions);
            final pct =
                ((totalLogs / 30.0).clamp(0.0, 1.0) * 100).round();
            store.toast?.call(
                'رشد $pct٪ — $totalLogs از ۳۰ قدم در این هدف');
          }
        }
        return;
      }

      // ─── قدم روی شاخه: تپ = toggle ───
      if (p.isFoot) {
        if (!wasDrag) {
          final host = store.state.findHost(p.hostId);
          if (host is MapHost) {
            final found = findActionNode(host.actions, p.actionId);
            if (found != null) {
              found.node.footPlaying = !found.node.footPlaying;
              store.changed();
              store.toast?.call(found.node.footPlaying
                  ? 'قدم به راه افتاد 👣'
                  : 'قدم متوقف شد');
            }
          }
        }
        return;
      }

      // تپ روی شاخه → کادر ویرایش
      onEditAction(p.hostId, p.actionId);
      return;
    }

    final t = _tap;
    if (t != null && !_slopPassed && _ptrs.length == 1) {
      _ptrs.remove(e.pointer);
      _finish();
      switch (t.type) {
        case 'me':
          onEditMe();
        case 'goal':
          onEditGoal(t.id);
        case 'ring':
          onEditRing(t.id);
      }
      return;
    }
    _ptrs.remove(e.pointer);
    _afterRemoved();
  }

  void pointerCancel(PointerCancelEvent e) {
    if (!_ptrs.containsKey(e.pointer)) return;
    _cancelLongPress();
    _pending = null;
    _tap = null;
    _holdArmed = false;
    _ptrs.remove(e.pointer);
    _afterRemoved();
  }

  void _afterRemoved() {
    if (_ptrs.isEmpty) {
      _finish();
    } else if (_ptrs.length == 1) {
      _tap = null;
      _startPan(_ptrs.values.first);
    }
  }

  void _finish() {
    _cancelLongPress();
    _mode = _Mode.none;
    _pending = null;
    _tap = null;
    _holdArmed = false;
    _slopPassed = true;
    if (_dirty) {
      _dirty = false;
      store.changed();
    }
  }

  void reset() {
    _ptrs.clear();
    _finish();
  }

  // ───────────────────────── چرخ موس ─────────────────────────

  void scroll(PointerScrollEvent e) {
    final hit = hits.hitTest(cam.screenToWorld(e.localPosition), cam.scale);
    final f = math.exp(-e.scrollDelta.dy * 0.0018);
    if (hit != null &&
        (hit.kind == HitKind.image || hit.kind == HitKind.label)) {
      final node = _nodeRef(hit.type, hit.id, hit.hostId);
      if (node != null) {
        if (hit.kind == HitKind.image && node is ActionNode) {
          final i = hit.imgIdx ?? 0;
          if (i < node.images.length) {
            node.images[i].size =
                math.max(16.0, math.min(260.0, node.images[i].size * f));
            store.touch();
          }
        } else if (hit.kind == HitKind.label) {
          final cur = _labelSizeOf(node) ?? _defaultLabelSize(hit.type, hit.id);
          _setLabelSize(node, math.max(8.0, math.min(60.0, cur * f)));
          store.touch();
        }
        return;
      }
    }
    cam.zoomAt(e.localPosition, math.exp(-e.scrollDelta.dy * 0.0015));
  }
}
