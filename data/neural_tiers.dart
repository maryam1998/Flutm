import 'package:flutter/material.dart';

import '../theme/grat_palette.dart';

const int kNeuralFiberCap = 10;

const Color kEmerald300 = Color(0xFF54C9B8);
const Color kEmerald500 = Color(0xFF2BBFAB);
const Color kEmerald700 = Color(0xFF0F5B53);

const Color kNeuralInk = Color(0xFF2A2218);
const Color kNeuralMuted = Color(0xFF7A6B57);
const Color kNeuralBorder = Color(0xFFE0D5C0);
const Color kNeuralCard = Color(0xFFFFFFFF);
const Color kNeuralCream = Color(0xFFFBF6EA);
const Color kGold500 = Color(0xFFC9972B);

int neuralTier(int fiberCount, bool habitFormed) {
  if (habitFormed) return 3;
  if (fiberCount <= 0) return 0;
  if (fiberCount >= kNeuralFiberCap) return 3;
  if (fiberCount >= (kNeuralFiberCap / 2).ceil()) return 2;
  return 1;
}

/// رنگ‌های ویجت مسیر عصبی.
/// - [NeuralColors.legacy]: همان ظاهر قبلی (برای تب‌هایی که هنوز دست نخورده‌اند)
/// - [NeuralColors.web]: متغیرهای دقیق `#grat-root` وب (روشن/تاریک) — تب شکرگذاری
class NeuralColors {
  const NeuralColors({
    required this.card,
    required this.border,
    required this.ink,
    required this.inkSoft,
    required this.muted,
    required this.label,
    required this.baseFill,
    required this.baseStroke,
    required this.baseText,
    required this.fiberDefault,
    required this.e300,
    required this.e500,
    required this.e700,
    required this.btnBorder,
    required this.btnBg,
    required this.btnText,
    required this.gold,
    required this.goldText,
    required this.webStyle,
  });

  final Color card, border, ink, inkSoft, muted, label;
  final Color baseFill, baseStroke, baseText;
  final Color fiberDefault;
  final Color e300, e500, e700;
  final Color btnBorder, btnBg, btnText;
  final Color gold, goldText;

  /// true → هندسه/منطق رسم دقیقاً مثل وب
  final bool webStyle;

  static const legacy = NeuralColors(
    card: kNeuralCard,
    border: kNeuralBorder,
    ink: kNeuralInk,
    inkSoft: kNeuralInk,
    muted: kNeuralMuted,
    label: kNeuralMuted,
    baseFill: kNeuralCream,
    baseStroke: kNeuralBorder,
    baseText: kNeuralMuted,
    fiberDefault: kEmerald500,
    e300: kEmerald300,
    e500: kEmerald500,
    e700: kEmerald700,
    btnBorder: kNeuralBorder,
    btnBg: Colors.transparent,
    btnText: kNeuralInk,
    gold: kGold500,
    goldText: Colors.white,
    webStyle: false,
  );

  /// .neural-card وب:
  ///   background: var(--surface)  border: 1px solid var(--line)
  ///   نود پایه: fill=--input-bg  stroke=--panel-border  text=--muted
  ///   لیبل‌ها: fill=--text-dim   رشته‌ی پیش‌فرض: --accent
  ///   دکمه‌ها: .btn (border --panel-border، متن --text-main)
  factory NeuralColors.web(GratPalette p) => NeuralColors(
        card: p.surface,
        border: p.line,
        ink: p.ink,
        inkSoft: p.inkSoft,
        muted: p.muted,
        label: p.textDim,
        baseFill: p.inputBg,
        baseStroke: p.panelBorder,
        baseText: p.muted,
        fiberDefault: p.accent,
        e300: p.emerald300,
        e500: p.emerald500,
        e700: p.emerald700,
        btnBorder: p.panelBorder,
        btnBg: const Color.fromRGBO(255, 255, 255, 0.05),
        btnText: p.ink,
        gold: p.accent,
        goldText: const Color(0xFF221800),
        webStyle: true,
      );
}

class NeuralTierStyle {
  final Color fill;
  final Color stroke;
  final Color textColor;
  final String char;
  final bool glow;

  const NeuralTierStyle({
    required this.fill,
    required this.stroke,
    required this.textColor,
    required this.char,
    this.glow = false,
  });
}

/// neuralTierStyle وب (neural-pathway.js)
NeuralTierStyle neuralTierStyle(
  int tier, {
  required bool isHabitNode,
  NeuralColors colors = NeuralColors.legacy,
}) {
  switch (tier) {
    case 1:
      return NeuralTierStyle(
        fill: const Color.fromRGBO(84, 201, 184, 0.10),
        stroke: const Color.fromRGBO(84, 201, 184, 0.55),
        textColor: colors.e300,
        char: '◔',
      );
    case 2:
      return NeuralTierStyle(
        fill: const Color.fromRGBO(43, 191, 171, 0.18),
        stroke: colors.e300,
        textColor: colors.e500,
        char: '◐',
      );
    case 3:
      return NeuralTierStyle(
        fill: const Color.fromRGBO(43, 191, 171, 0.28),
        stroke: colors.e500,
        textColor: colors.e700,
        char: isHabitNode ? '◉' : '◕',
        glow: isHabitNode,
      );
    default:
      return NeuralTierStyle(
        fill: colors.baseFill,
        stroke: colors.baseStroke,
        textColor: colors.baseText,
        char: '○',
      );
  }
}
