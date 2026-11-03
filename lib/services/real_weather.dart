import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'app_prefs.dart';

/// وضعیتِ هوای همین لحظه (همه ۰..۱).
class WeatherNow {
  const WeatherNow({
    this.cloud = 0,
    this.rain = 0,
    this.snow = 0,
    this.wind = 12,
    this.windDir = 270,
  });
  final double cloud, rain, snow;

  /// سرعتِ باد (کیلومتر بر ساعت) و جهتی که باد «از آن» می‌وزد (درجه)؛
  /// ابرها طبقِ همین‌ها حرکت می‌کنند.
  final double wind, windDir;

  Map<String, dynamic> toJson() =>
      {'c': cloud, 'r': rain, 's': snow, 'wk': wind, 'wd': windDir};

  static WeatherNow fromJson(Map<String, dynamic> j) => WeatherNow(
        cloud: (j['c'] as num?)?.toDouble() ?? 0,
        rain: (j['r'] as num?)?.toDouble() ?? 0,
        snow: (j['s'] as num?)?.toDouble() ?? 0,
        wind: (j['wk'] as num?)?.toDouble() ?? 12,
        windDir: (j['wd'] as num?)?.toDouble() ?? 270,
      );
}

/// هوای واقعیِ شهرِ کاربر؛ کاملاً خودکار و بدونِ هیچ مجوزی:
///  ۱) شهر/مختصاتِ تقریبی از روی IP (چند ساعت کش می‌شود)
///  ۲) وضعیتِ هوا از Open-Meteo (۳۰ دقیقه کش می‌شود)
/// همه‌چیز در پس‌زمینه است و هیچ‌وقت جلوی بالا آمدنِ برنامه را نمی‌گیرد؛
/// اگر چیزی جواب نداد، بی‌صدا رد می‌شود.
class RealWeather {
  RealWeather._();

  static final ValueNotifier<WeatherNow?> now = ValueNotifier<WeatherNow?>(null);

  static const _kLoc = 'rw_loc';
  static const _kWx = 'rw_wx';
  static const _timeout = Duration(seconds: 3);
  static const _locTtl = Duration(hours: 6);
  static const _wxTtl = Duration(minutes: 30);

  static bool _busy = false;
  static bool _cacheRead = false;
  static Timer? _timer;
  static int _users = 0;

  /// لایه‌ی هوا که روی صفحه آمد صدا بزن؛ با [release] آزادش کن.
  static void attach() {
    _users++;
    _refresh();
    _timer ??= Timer.periodic(_wxTtl, (_) => _refresh());
  }

  static void release() {
    if (_users > 0) _users--;
    if (_users == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  static Future<void> _refresh() async {
    if (_busy) return;
    _busy = true;
    try {
      final prefs = await AppPrefs.getInstance();
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // آخرین هوای ذخیره‌شده: همان لحظه نشان داده می‌شود
      Map<String, dynamic>? wx = _readJson(prefs.getString(_kWx));
      if (!_cacheRead && wx != null && wx['w'] is Map) {
        _cacheRead = true;
        now.value = WeatherNow.fromJson(Map<String, dynamic>.from(wx['w'] as Map));
      }
      _cacheRead = true;
      if (wx != null && nowMs - ((wx['t'] as num?)?.toInt() ?? 0) < _wxTtl.inMilliseconds) {
        return; // هنوز تازه است
      }

      // مختصات
      var loc = _readJson(prefs.getString(_kLoc));
      final locFresh = loc != null &&
          nowMs - ((loc['t'] as num?)?.toInt() ?? 0) < _locTtl.inMilliseconds;
      if (!locFresh) {
        final fresh = await _locateByIp();
        if (fresh != null) {
          loc = {'lat': fresh.$1, 'lon': fresh.$2, 't': nowMs};
          await prefs.setString(_kLoc, jsonEncode(loc));
        }
      }
      if (loc == null) return;

      final w = await _fetchWeather(
          (loc['lat'] as num).toDouble(), (loc['lon'] as num).toDouble());
      if (w == null) return;
      now.value = w;
      await prefs.setString(_kWx, jsonEncode({'t': nowMs, 'w': w.toJson()}));
    } catch (_) {
      // بی‌صدا
    } finally {
      _busy = false;
    }
  }

  static Map<String, dynamic>? _readJson(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final v = jsonDecode(s);
      return v is Map ? Map<String, dynamic>.from(v) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<(double, double)?> _locateByIp() async {
    // سرویسِ اول
    try {
      final r = await http.get(Uri.parse('https://ipwho.is/')).timeout(_timeout);
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        if (j['success'] != false && j['latitude'] != null && j['longitude'] != null) {
          return ((j['latitude'] as num).toDouble(), (j['longitude'] as num).toDouble());
        }
      }
    } catch (_) {}
    // پشتیبان
    try {
      final r = await http.get(Uri.parse('https://ipapi.co/json/')).timeout(_timeout);
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        if (j['latitude'] != null && j['longitude'] != null) {
          return ((j['latitude'] as num).toDouble(), (j['longitude'] as num).toDouble());
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<WeatherNow?> _fetchWeather(double lat, double lon) async {
    try {
      final u = Uri.parse('https://api.open-meteo.com/v1/forecast'
          '?latitude=${lat.toStringAsFixed(3)}&longitude=${lon.toStringAsFixed(3)}'
          '&current=weather_code,cloud_cover,wind_speed_10m,wind_direction_10m');
      final r = await http.get(u).timeout(_timeout);
      if (r.statusCode != 200) return null;
      final cur = (jsonDecode(r.body) as Map<String, dynamic>)['current'];
      if (cur is! Map) return null;
      final code = (cur['weather_code'] as num?)?.toInt() ?? 0;
      final cover = ((cur['cloud_cover'] as num?)?.toDouble() ?? 0) / 100;
      final wind = (cur['wind_speed_10m'] as num?)?.toDouble() ?? 12;
      final dir = (cur['wind_direction_10m'] as num?)?.toDouble() ?? 270;
      return _fromCode(code, cover.clamp(0.0, 1.0).toDouble(), wind, dir);
    } catch (_) {
      return null;
    }
  }

  /// کدهای WMO → ابر/باران/برف
  static WeatherNow _fromCode(
      int code, double cover, double wind, double windDir) {
    double rain = 0, snow = 0, cloud = cover;
    switch (code) {
      case 45:
      case 48: // مه
        cloud = 1;
      case 51:
        rain = 0.25;
      case 53:
        rain = 0.4;
      case 55:
        rain = 0.55;
      case 56:
      case 57:
        rain = 0.45;
      case 61:
        rain = 0.5;
      case 63:
        rain = 0.75;
      case 65:
        rain = 1;
      case 66:
      case 67:
        rain = 0.8;
      case 71:
        snow = 0.45;
      case 73:
        snow = 0.7;
      case 75:
        snow = 1;
      case 77:
        snow = 0.5;
      case 80:
        rain = 0.6;
      case 81:
        rain = 0.8;
      case 82:
        rain = 1;
      case 85:
        snow = 0.6;
      case 86:
        snow = 1;
      case 95:
      case 96:
      case 99:
        rain = 1;
        cloud = 1;
      default:
        break;
    }
    if (rain > 0 || snow > 0) cloud = cloud < 0.9 ? 1.0 : cloud;
    return WeatherNow(
        cloud: cloud, rain: rain, snow: snow, wind: wind, windDir: windDir);
  }
}
