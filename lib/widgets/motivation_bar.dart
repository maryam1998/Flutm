import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/motivation_store.dart';

class MotivationBar extends StatefulWidget {
  const MotivationBar({super.key});
  @override
  State<MotivationBar> createState() => _MotivationBarState();
}

class _MotivationBarState extends State<MotivationBar> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      final store = context.read<MotivationStore>();
      if (store.showBar && store.active.length > 1) {
        store.nextRandom();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MotivationStore>();
    if (!store.showBar) return const SizedBox.shrink();
    final item = store.current;
    if (item == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? const Color(0xFF1A1E3A)
        : const Color(0xFFFBF6EA);
    final fg = isDark ? Colors.white : const Color(0xFF2A2218);
    final gold = isDark ? const Color(0xFF5EC8F0) : const Color(0xFFC9972B);

    return SafeArea(
      top: true,
      bottom: false,
      child: Material(
        color: bg,
        child: InkWell(
          onTap: () {
            if (store.active.length > 1) store.nextRandom();
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: gold.withValues(alpha: 0.35),
                  width: 1,
                ),
                bottom: BorderSide(
                  color: gold.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 14, color: gold),
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Text(
                      item.text,
                      key: ValueKey(item.id),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.6,
                        color: fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (store.active.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      '${store.active.indexWhere((e) => e.id == item.id) + 1}/${store.active.length}',
                      style: TextStyle(
                        fontSize: 10,
                        color: fg.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
