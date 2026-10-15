import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/abundance_models.dart';
import '../models/gratitude_entry.dart';
import '../services/image_service.dart';
import '../state/abundance_store.dart';
import '../state/gratitude_store.dart';
import '../utils/money_format.dart';
import '../widgets/receipt_sheet.dart';
import '../widgets/shop_history_sheet.dart';
import '../services/media_db.dart';

const _kCream = Color(0xFFF7F6F1);
const _kCard = Colors.white;
const _kGold = Color(0xFFC9A24B);
const _kInk = Color(0xFF000000);
const _kMuted = Color(0xFF7C8B87);
const _kBorder = Color(0xFFE7E5DB);
const _kDanger = Color(0xFFB3452F);

class StoreTab extends StatefulWidget {
  const StoreTab({super.key});
  @override
  State<StoreTab> createState() => _StoreTabState();
}

class _StoreTabState extends State<StoreTab> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  String? _image;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final srcs = await ImageService.pickImages();
    if (!mounted || srcs.isEmpty) return;
    setState(() => _image = srcs.first);
  }

  void _addItem() {
    final name = _name.text.trim();
    final price = double.tryParse(_price.text.trim()) ?? 0;
    if (name.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نام و مبلغ معتبر وارد کن')),
      );
      return;
    }
    final store = context.read<AbundanceStore>();
    store.addToPending(ShopItem(
      name: name,
      image: _image,
      price: price,
    ));
    _name.clear();
    _price.clear();
    setState(() => _image = null);
  }

  Future<void> _checkout() async {
    final store = context.read<AbundanceStore>();
    final grat = context.read<GratitudeStore>();

    if (store.cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سبد خریدت خالیه')),
      );
      return;
    }
    if (store.cartTotal > store.balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'این مبلغ از موجودی امروزت بیشتره — باقی‌مانده: ${formatMoney(store.balance)}')),
      );
      return;
    }

    // نمایش درگاه پرداخت
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PaymentDialog(
        amount: store.cartTotal,
        cardNumber: store.card.number,
        expiry: store.card.expiry,
        cvv: store.card.cvv,
      ),
    );
    if (ok != true) return;

    // نهایی‌سازی خرید
    final record = store.checkout(store.card.number);

    // ساخت شکرگذاری برای هر آیتم
    for (final item in record.items) {
      await grat.add(
        text: item.name,
        icon: item.icon,
        images: item.image != null ? [GratitudeImage(src: item.image!)] : null,
        amount: item.qty * item.price,
        source: 'purchase',
      );
    }

    if (!mounted) return;
    await ReceiptSheet.show(context: context, record: record);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AbundanceStore>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            // هدر
            Row(
              children: [
                const Text('🛍️',
                    style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'بازی فراوانی',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _kInk),
                  ),
                ),
                IconButton(
                  tooltip: 'تاریخچه خریدها',
                  icon: const Icon(Icons.history, color: _kInk),
                  onPressed: () => ShopHistorySheet.show(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'هر چیزی که دوستش داری رو یکی‌یکی اضافه کن، بعد همه رو با هم بریز تو سبد',
              style: TextStyle(fontSize: 11.5, color: _kMuted, height: 1.7),
            ),
            const SizedBox(height: 14),

            // بنر موجودی
            _balanceBanner(store),
            const SizedBox(height: 16),

            // فرم افزودن
            _addForm(),
            const SizedBox(height: 16),

            // لیست خرید
            if (store.pending.isNotEmpty) _pendingList(store),
            if (store.pending.isNotEmpty) const SizedBox(height: 16),

            // سبد
            _cartSection(store),
          ],
        ),
      ),
    );
  }

  Widget _balanceBanner(AbundanceStore store) {
    final left = store.remainingToday;
    final over = left < 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: over
            ? _kDanger.withValues(alpha: 0.08)
            : _kGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: over
              ? _kDanger.withValues(alpha: 0.4)
              : _kGold.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('💳 باقی‌مانده‌ی امروز',
                  style: TextStyle(fontSize: 12, color: _kInk)),
              const Spacer(),
              Text(
                formatMoney(left < 0 ? 0 : left),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: over ? _kDanger : _kInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            over
                ? 'جمع لیست از موجودی امروزت بیشتره؛ یک مورد رو کم کن.'
                : (left == 0
                    ? '✓ دقیقاً همه‌ی مبلغ امروز خرج شد — موجودی صفر!'
                    : 'هدف: امروز همه‌ی ${formatMoney(store.todayDeposit)} رو خرج کنی تا به صفر برسه.'),
            style: const TextStyle(fontSize: 11, color: _kMuted, height: 1.7),
          ),
        ],
      ),
    );
  }

  Widget _addForm() {
  final imageBytes = _image != null ? _decode(_image!) : null;
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('🛍️ خرید مورد دلخواه',
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: _kInk)),
        const SizedBox(height: 10),
        Row(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _kCream,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: imageBytes != null
                    ? Image.memory(imageBytes, fit: BoxFit.cover)
                    : const Icon(Icons.image_outlined,
                        color: _kMuted, size: 22),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _name,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontSize: 13, color: _kInk),
                    decoration: _inputDeco('اسم این خرید'),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _price,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontSize: 13, color: _kInk),
                    decoration: _inputDeco('قیمت (تومان)'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F5B53),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _addItem,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('افزودن به لیست',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    ),
  );
}

  Widget _pendingList(AbundanceStore store) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('📋 لیست خریدت',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: _kInk)),
          const SizedBox(height: 8),
          ...store.pending.map((it) => _pendingRow(it, store)),
          const Divider(height: 20),
          Row(
            children: [
              const Text('جمع کل',
                  style: TextStyle(fontSize: 12.5, color: _kMuted)),
              const Spacer(),
              Text(formatMoney(store.pendingTotal),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _kInk)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F5B53),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                store.moveAllPendingToCart();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🛍️ به سبد خرید اضافه شد')),
                );
              },
              icon: const Icon(Icons.shopping_cart_outlined, size: 18),
              label: const Text('افزودن به سبد خرید',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingRow(ShopItem it, AbundanceStore store) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _kCream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          _thumb(it),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.name,
                    style: const TextStyle(fontSize: 12.5, color: _kInk)),
                const SizedBox(height: 2),
                Text(formatMoney(it.price),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _kGold)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: _kDanger),
            onPressed: () => store.removeFromPending(it.id),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          ),
        ],
      ),
    );
  }

  Widget _cartSection(AbundanceStore store) {
    if (store.cart.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 30),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: const Column(
          children: [
            Icon(Icons.shopping_cart_outlined, size: 32, color: _kMuted),
            SizedBox(height: 8),
            Text('سبد خریدت خالیه 🌱',
                style: TextStyle(fontSize: 13, color: _kInk)),
            SizedBox(height: 4),
            Text('یک نعمت از بازی فراوانی اضافه کن',
                style: TextStyle(fontSize: 11, color: _kMuted)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('🛒 سبد خرید',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: _kInk)),
          const SizedBox(height: 8),
          ...store.cart.map((it) => _cartRow(it, store)),
          const Divider(height: 20),
          Row(
            children: [
              const Text('تعداد اقلام',
                  style: TextStyle(fontSize: 12, color: _kMuted)),
              const Spacer(),
              Text(toFaDigits(store.cartCount.toString()),
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _kInk)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('مبلغ قابل پرداخت',
                  style: TextStyle(fontSize: 12, color: _kMuted)),
              const Spacer(),
              Text(formatMoney(store.cartTotal),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _kInk)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F5B53),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _checkout,
              child: const Text('ادامه به درگاه پرداخت',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartRow(ShopItem it, AbundanceStore store) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _kCream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          _thumb(it),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.name,
                    style: const TextStyle(fontSize: 12.5, color: _kInk)),
                const SizedBox(height: 2),
                Text(formatMoney(it.price),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _kGold)),
              ],
            ),
          ),
          _stepper(it, store),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: _kDanger),
            onPressed: () => store.removeFromCart(it.id),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          ),
        ],
      ),
    );
  }

  Widget _stepper(ShopItem it, AbundanceStore store) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => store.changeCartQty(it.id, -1),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Icon(Icons.remove, size: 14, color: _kInk),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(toFaDigits(it.qty.toString()),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _kInk)),
          ),
          InkWell(
            onTap: () => store.changeCartQty(it.id, 1),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Icon(Icons.add, size: 14, color: _kInk),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumb(ShopItem it) {
    if (it.image != null) {
      final bytes = _decode(it.image!);
      if (bytes != null) {
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.memory(bytes, fit: BoxFit.cover),
        );
      }
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _kCream,
        shape: BoxShape.circle,
        border: Border.all(color: _kBorder),
      ),
      alignment: Alignment.center,
      child: Text(it.icon, style: const TextStyle(fontSize: 16)),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kMuted, fontSize: 12),
      isDense: true,
      filled: true,
      fillColor: _kCream,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kGold, width: 1.5),
      ),
    );
  }

  static Uint8List? _decode(String src) {
    try {
      if (MediaDb.isRef(src)) return MediaDb.bytes(src);
      if (!src.startsWith('data:')) return null;
      return base64Decode(src.substring(src.indexOf(',') + 1));
    } catch (_) {
      return null;
    }
  }
}

// ═══════════════ درگاه پرداخت ═══════════════
class _PaymentDialog extends StatefulWidget {
  final double amount;
  final String cardNumber;
  final String expiry;
  final String cvv;

  const _PaymentDialog({
    required this.amount,
    required this.cardNumber,
    required this.expiry,
    required this.cvv,
  });

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final TextEditingController _otp;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _otp = TextEditingController();
    // «ارسال» رمز پویا
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final code = (10000 + (DateTime.now().millisecondsSinceEpoch % 90000))
          .toString();
      _otp.text = code;
    });
  }

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() => _processing = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: _kCream,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🔒 ', style: TextStyle(fontSize: 14)),
                Text('درگاه پرداخت فراوانی',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _kInk)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('اتصال امن',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: _kMuted)),
            const SizedBox(height: 14),
            Center(
              child: Text(
                formatMoney(widget.amount),
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _kGold),
              ),
            ),
            const SizedBox(height: 16),
            _row('شماره کارت', widget.cardNumber),
            _row('تاریخ انقضا', widget.expiry),
            _row('CVV2', widget.cvv),
            const SizedBox(height: 10),
            TextField(
              controller: _otp,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  color: _kInk),
              decoration: InputDecoration(
                hintText: 'رمز پویا (دینامیک)',
                hintStyle:
                    const TextStyle(fontSize: 11, color: _kMuted),
                filled: true,
                fillColor: _kCard,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kGold, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '🕊️ این یک درگاه پرداخت نمادین است؛ هیچ اطلاعات بانکی واقعی ذخیره یا منتقل نمی‌شود.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: _kMuted, height: 1.7),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 46,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _kGold,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _processing ? null : _confirm,
                child: _processing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('تأیید و پرداخت',
                        style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            TextButton(
              onPressed: _processing ? null : () => Navigator.pop(context, false),
              child: const Text('انصراف',
                  style: TextStyle(fontSize: 12, color: _kMuted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11.5, color: _kMuted)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _kInk)),
        ],
      ),
    );
  }
}
