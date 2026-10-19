import 'dart:math';

String _uid(String prefix) =>
    '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 20)}';

// ═══════════════ کارت بانکی ═══════════════
class BankCard {
  String bankName;
  String holderName;
  String number;
  String expiry;
  String cvv;
  String theme; // emerald | navy | plum | rose | charcoal | gold

  BankCard({
    this.bankName = 'بانک فراوانی',
    this.holderName = 'کاربر فراوانی',
    this.number = '5859 8312 8347 6690',
    this.expiry = '∞ / ∞',
    this.cvv = '۱۴۰',
    this.theme = 'emerald',
  });

  factory BankCard.fromJson(Map<String, dynamic>? j) {
    if (j == null) return BankCard();
    return BankCard(
      bankName: j['bankName'] as String? ?? 'بانک فراوانی',
      holderName: j['holderName'] as String? ?? 'کاربر فراوانی',
      number: j['number'] as String? ?? '5859 8312 8347 6690',
      expiry: j['expiry'] as String? ?? '∞ / ∞',
      cvv: j['cvv'] as String? ?? '۱۴۰',
      theme: j['theme'] as String? ?? 'emerald',
    );
  }

  Map<String, dynamic> toJson() => {
        'bankName': bankName,
        'holderName': holderName,
        'number': number,
        'expiry': expiry,
        'cvv': cvv,
        'theme': theme,
      };

  BankCard copyWith({
    String? bankName,
    String? holderName,
    String? number,
    String? expiry,
    String? cvv,
    String? theme,
  }) {
    return BankCard(
      bankName: bankName ?? this.bankName,
      holderName: holderName ?? this.holderName,
      number: number ?? this.number,
      expiry: expiry ?? this.expiry,
      cvv: cvv ?? this.cvv,
      theme: theme ?? this.theme,
    );
  }
}

// ═══════════════ تنظیمات بازی ═══════════════
class AbundanceSettings {
  double startAmount;
  double step;
  String startDate;

  AbundanceSettings({
    this.startAmount = 1000000,
    this.step = 1000000,
    required this.startDate,
  });

  factory AbundanceSettings.fromJson(Map<String, dynamic>? j, String fallbackDate) {
    if (j == null) return AbundanceSettings(startDate: fallbackDate);
    return AbundanceSettings(
      startAmount: (j['startAmount'] as num?)?.toDouble() ?? 1000000,
      step: (j['step'] as num?)?.toDouble() ?? 1000000,
      startDate: j['startDate'] as String? ?? fallbackDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'startAmount': startAmount,
        'step': step,
        'startDate': startDate,
      };
}

// ═══════════════ آیتم فروشگاه ═══════════════
class ShopItem {
  String id;
  String name;
  String icon;
  String? image; // base64 data URL
  double price;
  int qty;

  ShopItem({
    String? id,
    required this.name,
    this.icon = '✨',
    this.image,
    required this.price,
    this.qty = 1,
  }) : id = id ?? _uid('it');

  factory ShopItem.fromJson(Map<String, dynamic> j) => ShopItem(
        id: j['id'] as String?,
        name: j['name'] as String? ?? '',
        icon: j['icon'] as String? ?? '✨',
        image: j['image'] as String?,
        price: (j['price'] as num).toDouble(),
        qty: (j['qty'] as num?)?.toInt() ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'image': image,
        'price': price,
        'qty': qty,
      };

  double get total => price * qty;
}

// ═══════════════ آیتم خرید (تاریخچه) ═══════════════
class PurchaseItem {
  final String name;
  final String icon;
  final String? image;
  final int qty;
  final double price;

  PurchaseItem({
    required this.name,
    required this.icon,
    this.image,
    required this.qty,
    required this.price,
  });

  factory PurchaseItem.fromJson(Map<String, dynamic> j) => PurchaseItem(
        name: j['name'] as String? ?? '',
        icon: j['icon'] as String? ?? '✨',
        image: j['image'] as String?,
        qty: (j['qty'] as num?)?.toInt() ?? 1,
        price: (j['price'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'icon': icon,
        'image': image,
        'qty': qty,
        'price': price,
      };
}

// ═══════════════ رسید خرید ═══════════════
class Purchase {
  final String id;
  final String date;
  final String day;
  final String time;
  final String iso;
  final String track;
  final String card;
  final List<PurchaseItem> items;
  final double total;

  Purchase({
    String? id,
    required this.date,
    required this.day,
    required this.time,
    required this.iso,
    required this.track,
    required this.card,
    required this.items,
    required this.total,
  }) : id = id ?? _uid('p');

  factory Purchase.fromJson(Map<String, dynamic> j) => Purchase(
        id: j['id'] as String?,
        date: j['date'] as String? ?? '',
        day: j['day'] as String? ?? '',
        time: j['time'] as String? ?? '',
        iso: j['iso'] as String? ?? '',
        track: j['track'] as String? ?? '',
        card: j['card'] as String? ?? '',
        items: (j['items'] as List?)
                ?.map((e) => PurchaseItem.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        total: (j['total'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'day': day,
        'time': time,
        'iso': iso,
        'track': track,
        'card': card,
        'items': items.map((e) => e.toJson()).toList(),
        'total': total,
      };
}
