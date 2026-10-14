import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/abundance_store.dart';
import '../utils/money_format.dart';
import 'receipt_sheet.dart';

const _kGold = Color(0xFFC9A24B);
const _kInk = Color(0xFF000000);
const _kMuted = Color(0xFF7C8B87);
const _kBorder = Color(0xFFE7E5DB);
const _kCard = Colors.white;
const _kCream = Color(0xFFF7F6F1);

class ShopHistorySheet extends StatelessWidget {
  const ShopHistorySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ShopHistorySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AbundanceStore>();
    final list = store.history.reversed.toList();

    return Container(
      decoration: const BoxDecoration(
        color: _kCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '📜 تاریخچه خریدها',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: _kInk),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'مجموع: ${formatMoney(store.spentTotal)}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: _kGold),
                ),
              ),
              const SizedBox(height: 12),

              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Text(
                    'هنوز هیچ خریدی ثبت نشده 🌱\nاز فروشگاه بازی فراوانی چیزی اضافه کن',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: _kMuted, height: 1.9),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _purchaseTile(context, list[i]),
                  ),
                ),

              const SizedBox(height: 14),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kInk,
                  side: const BorderSide(color: _kBorder),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('بستن'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _purchaseTile(BuildContext context, dynamic p) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        ReceiptSheet.show(context: context, record: p);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  p.day,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: _kInk),
                ),
                const SizedBox(width: 6),
                Text(p.date,
                    style: const TextStyle(fontSize: 11, color: _kMuted)),
                const Spacer(),
                Text(
                  formatMoney(p.total),
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _kGold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...(p.items as List).take(3).map((it) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '• ${it.name} ×${toFaDigits(it.qty.toString())}',
                    style: const TextStyle(fontSize: 11.5, color: _kInk),
                  ),
                )),
            if ((p.items as List).length > 3)
              Text(
                '… و ${toFaDigits((p.items.length - 3).toString())} مورد دیگر',
                style: const TextStyle(fontSize: 10.5, color: _kMuted),
              ),
          ],
        ),
      ),
    );
  }
}
