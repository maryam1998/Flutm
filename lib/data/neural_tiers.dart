import 'package:flutter/material.dart';

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

NeuralTierStyle neuralTierStyle(int tier, {required bool isHabitNode}) {
  switch (tier) {
    case 1:
      return const NeuralTierStyle(
        fill: Color(0x1A54C9B8),
        stroke: Color(0x8C54C9B8),
        textColor: kEmerald300,
        char: '◔',
      );
    case 2:
      return const NeuralTierStyle(
        fill: Color(0x2E2BBFAB),
        stroke: Color(0xFF54C9B8),
        textColor: kEmerald500,
        char: '◐',
      );
    case 3:
      return NeuralTierStyle(
        fill: const Color(0x472BBFAB),
        stroke: kEmerald500,
        textColor: kEmerald700,
        char: isHabitNode ? '◉' : '◕',
        glow: isHabitNode,
      );
    default:
      return const NeuralTierStyle(
        fill: kNeuralCream,
        stroke: kNeuralBorder,
        textColor: kNeuralMuted,
        char: '○',
      );
  }
}
