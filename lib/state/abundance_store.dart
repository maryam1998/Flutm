import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import '../services/app_prefs.dart';

import '../models/abundance_models.dart';

class AbundanceStore extends ChangeNotifier {
  static const _kSettings = 'abundance_settings_v1';
  static const _kCard = 'abundance_card_v1';
  static const _kPending = 'abundance_pending_v1';
  static const _kCart = 'abundance_cart_v1';
  static const _kHistory = 'abundance_history_v1';

  AbundanceSettings settings = AbundanceSettings(startDate: _todayKey());
  BankCard card = BankCard();
  final List<ShopItem> pending = [];
  final List<ShopItem> cart = [];
  final List<Purchase> history = [];

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
    } catch (_) {}
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
