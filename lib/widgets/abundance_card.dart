import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../models/abundance_models.dart';
import '../utils/money_format.dart';

/// سه رنگ گرادیان هر تم کارت (`.bank-card.theme-*` وب)
const Map<String, List<Color>> kCardThemes = {
  'emerald':  [Color(0xFF0A3D38), Color(0xFF0F5B53), Color(0xFF178A7C)],
  'navy':     [Color(0xFF0B1D3A), Color(0xFF16386B), Color(0xFF2F5FA8)],
  'plum':     [Color(0xFF2C0F3A), Color(0xFF5C1F70), Color(0xFF8A3AA8)],
  'rose':     [Color(0xFF3A0F16), Color(0xFF7A1F2E), Color(0xFFC8425A)],
  'charcoal': [Color(0xFF14161C), Color(0xFF2A2D38), Color(0xFF454A5C)],
  'gold':     [Color(0xFF6B4A12), Color(0xFFA97A1F), Color(0xFFE0B64A)],
};

/// رنگ درخشش گوشه‌ی بالا-راست هر تم (radial-gradient اول هر تم وب)
const Map<String, Color> _kGlow = {
  'emerald':  Color.fromRGBO(230, 205, 142, 0.35),
  'navy':     Color.fromRGBO(180, 210, 255, 0.30),
  'plum':     Color.fromRGBO(230, 180, 255, 0.28),
  'rose':     Color.fromRGBO(255, 210, 205, 0.32),
  'charcoal': Color.fromRGBO(255, 255, 255, 0.14),
  'gold':     Color.fromRGBO(255, 255, 255, 0.30),
};

/// کارت بانکی تب خانه — کپی `.bank-card` مغز
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
    final glow = _kGlow[card.theme] ?? _kGlow['emerald']!;
    const white = Colors.white;

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A2823).withValues(alpha: 0.16),
              blurRadius: 45,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // پایه: linear-gradient(135deg, …)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                    stops: const [0.0, 0.52, 1.0],
                  ),
                ),
              ),
            ),
            // درخشش گوشه‌ی بالا-راست: radial-gradient(120% 140% at 100% 0%)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topRight,
                      radius: 1.2,
                      colors: [glow, glow.withValues(alpha: 0.0)],
                      stops: const [0.0, 0.55],
                    ),
                  ),
                ),
              ),
            ),
            // سایه‌روشن پایین-چپ: ::before وب
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.64, 2.4),
                      radius: 1.5,
                      colors: [
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.45],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── row-top: برند (راست) + چیپ (چپ) ───
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFE6CD8E), Color(0xFFA9812F)],
                          ),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 2),
                        ),
                        child: const Text('🌿', style: TextStyle(fontSize: 17)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              card.bankName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                                height: 1.2,
                              ),
                            ),
                            Text(
                              'کارت شکرگذاری',
                              style: TextStyle(
                                color: white.withValues(alpha: 0.8),
                                fontSize: 10.5,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 38,
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFF3E0A8), Color(0xFFC9A24B)],
                          ),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'موجودی فراوانی',
                    style: TextStyle(
                      color: white.withValues(alpha: 0.82),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatMoney(balance),
                    style: const TextStyle(
                      color: white,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 18),
                  // شماره‌ی کارت: direction:ltr; text-align:right
                  Text(
                    card.number,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: white.withValues(alpha: 0.92),
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // ─── row-bottom: دارنده (راست) / CVV2 (وسط) / معتبر تا (چپ) ───
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'دارنده کارت',
                              style: TextStyle(
                                color: white.withValues(alpha: 0.85),
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              card.holderName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            'CVV2',
                            style: TextStyle(
                              color: white.withValues(alpha: 0.8),
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            card.cvv,
                            style: const TextStyle(
                              color: white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'معتبر تا',
                              style: TextStyle(
                                color: white.withValues(alpha: 0.75),
                                fontSize: 10.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              card.expiry,
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                color: white.withValues(alpha: 0.75),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
