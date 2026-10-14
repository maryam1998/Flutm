import 'package:flutter/material.dart';

import '../models/abundance_models.dart';
import '../utils/money_format.dart';

const _kGold = Color(0xFFC9A24B);
const _kInk = Color(0xFF000000);
const _kMuted = Color(0xFF7C8B87);
const _kBorder = Color(0xFFE7E5DB);
const _kCard = Colors.white;
const _kCream = Color(0xFFF7F6F1);
const _kEmerald = Color(0xFF178A7C);

class ReceiptSheet extends StatelessWidget {
  final Purchase record;

  const ReceiptSheet({super.key, required this.record});

  static Future<void> show({
    required BuildContext context,
    required Purchase record,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReceiptSheet(record: record),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: _kEmerald,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 32),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'پرداخت با موفقیت انجام شد',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: _kInk),
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Text(
                          formatMoney(record.total),
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _kInk),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'از حساب فراوانی کسر و به لیست شکرگذاری‌ات اضافه شد',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: _kMuted),
                      ),
                      const SizedBox(height: 14),
                      _row('تاریخ', record.date),
                      _row('روز هفته', record.day),
                      _row('ساعت', record.time),
                      _row('کد رهگیری', toFaDigits(record.track)),
                      _row('شماره کارت مبدا', record.card),
                      _row('بانک مقصد', 'بانک فراوانی'),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                const Text(
                  '🌿 اقلام این شکرگذاری',
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w800, color: _kInk),
                ),
                const SizedBox(height: 8),
                ...record.items.map((it) => _item(it)),

                const SizedBox(height: 16),
                SizedBox(
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _kGold,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('بازگشت',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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

  Widget _item(PurchaseItem it) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _kCream,
              shape: BoxShape.circle,
              border: Border.all(color: _kBorder),
            ),
            alignment: Alignment.center,
            child: Text(it.icon, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(it.name,
                style: const TextStyle(fontSize: 12.5, color: _kInk)),
          ),
          Text('×${toFaDigits(it.qty.toString())}',
              style: const TextStyle(fontSize: 11, color: _kMuted)),
          const SizedBox(width: 8),
          Text(formatMoney(it.qty * it.price),
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _kInk)),
        ],
      ),
    );
  }
}
