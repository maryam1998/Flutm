import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/background_store.dart';
import '../widgets/web_tab_bars.dart';

import 'beliefs_tab.dart';
import 'gratitude_tab.dart';
import 'home_tab.dart';
import 'store_tab.dart';

/// تب «تمرین» با ۴ زیرتب. ساختارش مثل نسخه‌ی وب:
///   [خانه] [بازی فراوانی] [شکرگذاری] [باورها]
/// ترتیب RTL: خانه سمت راست، باورها سمت چپ.
class PracticeTab extends StatefulWidget {
  const PracticeTab({super.key});

  @override
  State<PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<PracticeTab> {
  // 2 = شکرگذاری (پیش‌فرض)
  int _sub = 2;

  @override
  Widget build(BuildContext context) {
    // وب: #grat-root پس‌زمینه‌ی --paper دارد (سفید)، ولی وقتی پس‌زمینه‌ی
    // دلخواه (تصویر/ویدیو) فعاله شفاف می‌شه (body.bg-mode-image #grat-root).
    // محتوای زیرتب‌ها فعلاً روشنه، پس در تم تاریک همون کرم قبلی می‌مونه.
    final hasBg = context.watch<BackgroundStore>().hasBackground;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = hasBg
        ? Colors.transparent
        : (isDark ? const Color(0xFFFBF6EA) : Colors.white);

    return ColoredBox(
      color: paper,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(
          index: _sub,
          children: const [
            // 0 = خانه
            HomeTab(),
            // 1 = بازی فراوانی
            StoreTab(),
            // 2 = شکرگذاری
            GratitudeTab(),
            // 3 = باورها
            BeliefsTab(),
          ],
        ),
        bottomNavigationBar: WebSubTabBar(
          index: _sub,
          onTap: (i) => setState(() => _sub = i),
          items: const [
            WebTabItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: 'خانه',
            ),
            WebTabItem(
              icon: Icons.shopping_bag_outlined,
              selectedIcon: Icons.shopping_bag,
              label: 'بازی فراوانی',
            ),
            WebTabItem(
              icon: Icons.volunteer_activism_outlined,
              selectedIcon: Icons.volunteer_activism,
              label: 'شکرگذاری',
            ),
            WebTabItem(
              icon: Icons.psychology_outlined,
              selectedIcon: Icons.psychology,
              label: 'باورها',
            ),
          ],
        ),
      ),
    );
  }
}
