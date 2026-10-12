import 'package:flutter/material.dart';

import '../models/abundance_models.dart';
import '../utils/money_format.dart';

const Map<String, List<Color>> kCardThemes = {
  'emerald':  [Color(0xFF0A3D38), Color(0xFF63D6A8)],
  'navy':     [Color(0xFF0B1D3A), Color(0xFF6FB3FF)],
  'plum':     [Color(0xFF2C0F3A), Color(0xFFC07BE0)],
  'rose':     [Color(0xFF3A0F16), Color(0xFFE8748C)],
  'charcoal': [Color(0xFF14161C), Color(0xFF9AA0B2)],
  'gold':     [Color(0xFF6B4A12), Color(0xFFF3D98A)],
};

class AbundanceCard extends StatelessWidget {
  final double balance;
  final BankCard card;
  final VoidCallback? onEdit;

  const AbundanceCard({
    super.key,
    required this.balance,
    required this.card,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = kCardThemes[card.theme] ?? kCardThemes['emerald']!;

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors[0].withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      card.bankName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'کارت شکرگذاری',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('☀️', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'موجودی فراوانی',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              formatMoney(balance),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              card.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _cardInfo('معتبر تا', card.expiry),
                _cardInfo('CVV2', card.cvv),
                _cardInfo('دارنده کارت', card.holderName, align: TextAlign.right),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardInfo(String label, String value, {TextAlign align = TextAlign.left}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: align == TextAlign.right
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            textAlign: align,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            textAlign: align,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
