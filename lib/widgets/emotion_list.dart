import 'package:flutter/material.dart';
import '../models/emotion.dart';

Color hexToColor(String hex) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

class EmotionList extends StatelessWidget {
  final Set<String> selectedIds;
  final void Function(String id) onToggle;

  const EmotionList({
    super.key,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    // پایین‌ترین فرکانس پایین لیست
    final reversed = kEmotions.reversed.toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final e in reversed)
          _EmotionRow(
            emotion: e,
            selected: selectedIds.contains(e.id),
            onTap: () => onToggle(e.id),
          ),
      ],
    );
  }
}

class _EmotionRow extends StatelessWidget {
  final Emotion emotion;
  final bool selected;
  final VoidCallback onTap;

  const _EmotionRow({
    required this.emotion,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = hexToColor(emotion.color);
    const ink = Color(0xFF000000);
    const dim = Color(0xFF2A2D3A);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 21,
        child: Stack(
          children: [
            Positioned(
              left: 2, top: 0.5, right: 6, bottom: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: selected ? color.withValues(alpha: 0.14) : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            if (selected)
              Positioned(
                left: 2, top: 0.5, bottom: 0.5, width: 2.4,
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(1.2),
                  ),
                ),
              ),
            // چک‌مارک
            Positioned(
              right: 6, top: 3.3, bottom: 3.3,
              child: SizedBox(
                width: 14.4, height: 14.4,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                    Container(
                      width: 10.8, height: 10.8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? color : Colors.transparent,
                        border: Border.all(
                          color: selected ? color : ink,
                          width: 1.6,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check, size: 7.5, color: Colors.white)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            // متن
            Positioned(
              right: 22, left: 6, top: 0, bottom: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    emotion.fa,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 9,
                      height: 1.0,
                      fontWeight: FontWeight.w800,
                      color: selected ? color : ink,
                    ),
                  ),
                  const SizedBox(height: 1.5),
                  Text(
                    '${emotion.freq} Hz',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 6.8,
                      height: 1.0,
                      fontWeight: FontWeight.w700,
                      color: selected ? color : dim,
                    ),
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
