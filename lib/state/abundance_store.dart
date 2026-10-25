import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import '../services/app_prefs.dart';

import '../models/abundance_models.dart';
import '../models/neural_container.dart';

class AbundanceStore extends ChangeNotifier {
  static const _kSettings = 'abundance_settings_v1';
  static const _kCard = 'abundance_card_v1';
  static const _kPending = 'abundance_pending_v1';
  static const _kCart = 'abundance_cart_v1';
  static const _kHistory = 'abundance_history_v1';
  // تقویم دوره و مسیر عصبی (مثل شکرگذاری)
  static const _kJourneyDays = 'abundance_journey_days';
  static const _kJourneyStart = 'abundance_journey_start';
  static const _kJourneyPast = 'abundance_journey_past';
  static const _kNeural = 'abundance_neural';

  AbundanceSettings settings = AbundanceSettings(startDate: _todayKey());
  BankCard card = BankCard();
  final List<ShopItem> pending = [];
  final List<ShopItem> cart = [];
  final List<Purchase> history = [];

  /// مسیر عصبی بازی فراوانی — هر خرید (تسویهٔ سبد) دقیقاً یک رشته
  NeuralContainer neural = NeuralContainer();

  /// تقویم دوره (مثل شکرگذاری)
  int journeyDays = 28;
  String journeyStart = '';

  /// دوره‌های تمام‌شده‌ی قبلی: [{days: int, startDate: 'yyyy-MM-dd'}]
  final List<Map<String, dynamic>> pastPeriods = [];

  bool loaded = false;

  Future<void> load() async {
    try {
      final sp = await AppPrefs.getInstance();

      final sRaw = sp.getString(_kSettings);
      settings = AbundanceSettings.fromJson(
        sRaw != null && sRaw.isNotEmpty
            ? Map<String, dynamic>.from(jsonDecode(sRaw))
            : null,
        _todayKey(),
      );

      final cRaw = sp.getString(_kCard);
      card = BankCard.fromJson(
        cRaw != null && cRaw.isNotEmpty
            ? Map<String, dynamic>.from(jsonDecode(cRaw))
            : null,
      );

      final pRaw = sp.getString(_kPending);
      if (pRaw != null && pRaw.isNotEmpty) {
        pending
          ..clear()
          ..addAll((jsonDecode(pRaw) as List)
              .map((e) => ShopItem.fromJson(Map<String, dynamic>.from(e))));
      }

      final cartRaw = sp.getString(_kCart);
      if (cartRaw != null && cartRaw.isNotEmpty) {
        cart
          ..clear()
          ..addAll((jsonDecode(cartRaw) as List)
              .map((e) => ShopItem.fromJson(Map<String, dynamic>.from(e))));
      }

      final hRaw = sp.getString(_kHistory);
      if (hRaw != null && hRaw.isNotEmpty) {
        history
          ..clear()
          ..addAll((jsonDecode(hRaw) as List)
              .map((e) => Purchase.fromJson(Map<String, dynamic>.from(e))));
      }

      // تقویم دوره + مسیر عصبی
      journeyDays = sp.getInt(_kJourneyDays) ?? 28;
      if (journeyDays < 1) journeyDays = 28;
      journeyStart = sp.getString(_kJourneyStart) ?? '';
      if (journeyStart.isEmpty) {
        // اولین بار: تقویم از روز شروع بازی شروع می‌شود
        journeyStart =
            settings.startDate.isNotEmpty ? settings.startDate : _todayKey();
      }
      final nRaw = sp.getString(_kNeural);
      if (nRaw != null && nRaw.isNotEmpty) {
        try {
          neural = NeuralContainer.fromJson(
              Map<String, dynamic>.from(jsonDecode(nRaw)));
        } catch (_) {}
      }
      final pRaw2 = sp.getString(_kJourneyPast);
      if (pRaw2 != null && pRaw2.isNotEmpty) {
        try {
          final l = jsonDecode(pRaw2);
          if (l is List) {
            pastPeriods
              ..clear()
              ..addAll(l.whereType<Map>().map((m) => {
                    'days': (m['days'] as num?)?.toInt() ?? 28,
                    'startDate': m['startDate']?.toString() ?? '',
                  }));
          }
        } catch (_) {}
      }
      // خریدهای قبلی هم رشته می‌گیرند
      neural.logs.removeWhere((_, v) => v == false);
      _syncPurchaseFibers();
    } catch (_) {}
    loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final sp = await AppPrefs.getInstance();
      await sp.setString(_kSettings, jsonEncode(settings.toJson()));
      await sp.setString(_kCard, jsonEncode(card.toJson()));
      await sp.setString(_kPending,
          jsonEncode(pending.map((e) => e.toJson()).toList()));
      await sp.setString(
          _kCart, jsonEncode(cart.map((e) => e.toJson()).toList()));
      await sp.setString(_kHistory,
          jsonEncode(history.map((e) => e.toJson()).toList()));
      _syncPurchaseFibers();
      await sp.setInt(_kJourneyDays, journeyDays);
      await sp.setString(_kJourneyStart, journeyStart);
      await sp.setString(_kNeural, jsonEncode(neural.toJson()));
      await sp.setString(_kJourneyPast, jsonEncode(pastPeriods));
    } catch (_) {}
  }

  // ═══════════════ تقویم دوره + مسیر عصبی ═══════════════

  /// کلیدِ ثابتِ رشته‌ی هر خرید
  static String _fiberKeyFor(Purchase p, int ms) => 'f$ms-p${p.id}';

  /// همیشه (idempotent): هر خرید ⇄ دقیقاً یک رشته. رشته‌ی بی‌خرید حذف می‌شود.
  void _syncPurchaseFibers() {
    try {
      final want = <String>{};
      for (final p in history) {
        DateTime t;
        try {
          t = DateTime.parse(p.iso).toLocal();
        } catch (_) {
          continue;
        }
        want.add(_fiberKeyFor(p, t.millisecondsSinceEpoch));
      }
      for (final k in neural.logs.keys.toList()) {
        if (neural.logs[k] != true) continue;
        if (want.contains(k)) continue;
        neural.logs.remove(k);
        neural.fiberEmotions.remove(k);
        neural.pendingManual.remove(k);
      }
      for (final k in want) {
        neural.logs[k] = true;
      }
    } catch (_) {}
  }

  /// روزهایی (yyyy-MM-dd) که حداقل یک خرید ثبت شده
  Set<String> get doneDayKeys {
    final out = <String>{};
    for (final p in history) {
      final k = _isoToKey(p.iso);
      if (k.isNotEmpty) out.add(k);
    }
    return out;
  }

  Future<void> saveNeural() async {
    await _persist();
    notifyListeners();
  }

  Future<void> setJourneyDays(int days) async {
    if (days < 1) days = 28;
    journeyDays = days;
    notifyListeners();
    await _persist();
  }

  /// شروع دوره‌ی بعدی: دوره‌ی فعلی می‌رود توی دوره‌های قبلی
  Future<void> startNewJourney({int? days}) async {
    pastPeriods.add({'days': journeyDays, 'startDate': journeyStart});
    if (days != null && days >= 1) journeyDays = days;
    journeyStart = _todayKey();
    notifyListeners();
    await _persist();
  }

  // ═══════════════ محاسبات ═══════════════

  int get daysPassed {
    final start = _parseKey(settings.startDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(start).inDays + 1;
    return diff < 1 ? 1 : diff;
  }

  double get todayDeposit =>
      settings.startAmount + (daysPassed - 1) * settings.step;

  double get spentToday {
    final k = _todayKey();
    return history
        .where((p) => _isoToKey(p.iso) == k)
        .fold<double>(0, (sum, p) => sum + p.total);
  }

  double get spentTotal => history.fold<double>(0, (sum, p) => sum + p.total);

  double get balance {
    final b = todayDeposit - spentToday;
    return b < 0 ? 0 : b;
  }

  double get cartTotal => cart.fold<double>(0, (sum, i) => sum + i.total);
  double get pendingTotal =>
      pending.fold<double>(0, (sum, i) => sum + i.price);
  double get remainingToday => balance - cartTotal - pendingTotal;

  int get cartCount => cart.fold<int>(0, (sum, i) => sum + i.qty);

  // ═══════════════ عملیات ═══════════════

  void addToPending(ShopItem item) {
    pending.add(item);
    notifyListeners();
    _persist();
  }

  void removeFromPending(String id) {
    pending.removeWhere((e) => e.id == id);
    notifyListeners();
    _persist();
  }

  void moveAllPendingToCart() {
    if (pending.isEmpty) return;
    for (final item in pending) {
      cart.add(ShopItem(
        id: item.id,
        name: item.name,
        icon: item.icon,
        image: item.image,
        price: item.price,
        qty: 1,
      ));
    }
    pending.clear();
    notifyListeners();
    _persist();
  }

  void changeCartQty(String id, int delta) {
    final idx = cart.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    cart[idx].qty += delta;
    if (cart[idx].qty <= 0) cart.removeAt(idx);
    notifyListeners();
    _persist();
  }

  void removeFromCart(String id) {
    cart.removeWhere((e) => e.id == id);
    notifyListeners();
    _persist();
  }

  void clearCart() {
    cart.clear();
    notifyListeners();
    _persist();
  }

  /// نهایی‌سازی خرید — یک رسید برمی‌گردونه
  Purchase checkout(String cardNumber) {
    final now = DateTime.now();
    final record = Purchase(
      date: _faDate(now),
      day: _faWeekday(now),
      time: _faTime(now),
      iso: now.toIso8601String(),
      track: _randomTrack(),
      card: cardNumber.isEmpty ? card.number : cardNumber,
      items: cart
          .map((e) => PurchaseItem(
                name: e.name,
                icon: e.icon,
                image: e.image,
                qty: e.qty,
                price: e.price,
              ))
          .toList(),
      total: cartTotal,
    );
    history.add(record);
    cart.clear();
    notifyListeners();
    _persist();
    return record;
  }

  void updateSettings({required double startAmount, required double step}) {
    settings.startAmount = startAmount;
    settings.step = step;
    notifyListeners();
    _persist();
  }

  void updateCard(BankCard c) {
    card = c;
    notifyListeners();
    _persist();
  }

  // ═══════════════ helpers ═══════════════

  static String _todayKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String _isoToKey(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  static DateTime _parseKey(String k) {
    final p = k.split('-').map((e) => int.tryParse(e) ?? 1).toList();
    if (p.length != 3) return DateTime.now();
    return DateTime(p[0], p[1], p[2]);
  }

  static const _faWeekdays = [
    'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنج‌شنبه',
    'جمعه', 'شنبه', 'یکشنبه'
  ];

  static String _faDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _faWeekday(DateTime d) => _faWeekdays[d.weekday - 1];

  static String _faTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _randomTrack() {
    final r = Random();
    return List.generate(12, (_) => r.nextInt(10)).join();
  }
}
