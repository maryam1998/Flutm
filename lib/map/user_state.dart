import 'dart:math' as math;

import '../models/map_models.dart';

class UserFreq {
  UserFreq(this.total, this.progress, this.band);
  final int total;
  final double progress;
  final String band;
}

int _neuralCount(dynamic c) {
  if (c is! Map) return 0;
  final logs = c['logs'];
  if (logs is! Map) return 0;
  var n = 0;
  for (final v in logs.values) {
    if (v == true) {
      n++;
    } else if (v == false) {
      n--;
    }
  }
  return math.max(0, n);
}

/// معادل getUserFrequencyState نسخه‌ی وب (مجموع رشته‌های عصبی بخش‌های مختلف)
UserFreq userFrequencyState(MapState s) {
  final cb = s.extra['currentBelief'];
  final cbm = cb is Map ? cb : const {};
  final total = _neuralCount(s.extra['gratitudeNeural']) +
      _neuralCount(cbm['neural']) +
      _neuralCount(s.extra['dispenzaNeural']) +
      _neuralCount(cbm['trackingNeural']) +
      _neuralCount(cbm['visualNeural']) +
      _neuralCount(s.extra['shopNeural']);
  var band = 'delta';
  if (total >= 500) {
    band = 'gamma';
  } else if (total >= 300) {
    band = 'beta';
  } else if (total >= 150) {
    band = 'alpha';
  } else if (total >= 50) {
    band = 'theta';
  }
  return UserFreq(total, math.min(1.0, total / 500), band);
}
