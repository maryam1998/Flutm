import 'package:flutter/material.dart';

import '../theme/web_palette.dart';

class WebTabItem {
  const WebTabItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
  final IconData icon, selectedIcon;
  final String label;
}

/// تب‌های اصلی پایین — کپی #bottom-tabs وب
class WebMainTabBar extends StatelessWidget {
  const WebMainTabBar({
    super.key,
    required this.items,
    required this.index,
    required this.onTap,
  });
  final List<WebTabItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final p = WebPalette.of(context);
    final base = Theme.of(context).textTheme.bodyMedium;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: EdgeInsets.fromLTRB(10, 8, 10, 8 + bottom),
        decoration: BoxDecoration(
          color: p.panelBg,
          border: Border(top: BorderSide(color: p.panelBorder, width: 1)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                    decoration: BoxDecoration(
                      color: i == index
                          ? const Color.fromRGBO(244, 197, 66, 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Center(
                            child: Icon(
                              i == index
                                  ? items[i].selectedIcon
                                  : items[i].icon,
                              size: 20,
                              color: i == index ? p.accent : p.textDim,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: base?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: i == index ? p.accent : p.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// زیرتب‌های «تمرین» — کپی #grat-root .bottom-nav وب
class WebSubTabBar extends StatelessWidget {
  const WebSubTabBar({
    super.key,
    required this.items,
    required this.index,
    required this.onTap,
  });
  final List<WebTabItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final p = WebPalette.of(context);
    final base = Theme.of(context).textTheme.bodyMedium;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Material(
      type: MaterialType.transparency,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: EdgeInsets.fromLTRB(6, 8, 6, 8 + bottom),
            decoration: BoxDecoration(
              color: p.navBg,
              border: Border(top: BorderSide(color: p.line, width: 1)),
            ),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: Center(
                                child: Icon(
                                  i == index
                                      ? items[i].selectedIcon
                                      : items[i].icon,
                                  size: 20,
                                  color: i == index ? p.subActive : p.muted,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              items[i].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: base?.copyWith(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: i == index ? p.subActive : p.muted,
                              ),
                            ),
                          ],
                        ),
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
