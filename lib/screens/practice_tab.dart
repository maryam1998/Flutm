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

  // زیرتب‌ها تنبل ساخته می‌شن: فقط زیرتبِ فعال موقع ورود به «تمرین»؛ بقیه اولین
  // باری که بازشون کنی. (قبلاً هر ۴ زیرتب با عکس/GIF/صدا یک‌جا ساخته می‌شد و تب هنگ می‌کرد.)
  // بعد از اولین ساخت، زنده می‌مونن (حالت حفظ می‌شه).
  final Set<int> _built = <int>{2};

  Widget _lazy(int i, Widget Function() make) => _built.contains(i)
      ? TickerMode(enabled: i == _sub, child: make())
      : const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    // وب: #grat-root پس‌زمینه‌ی --paper دارد (سفید)، ولی وقتی پس‌زمینه‌ی
    // دلخواه (تصویر/ویدیو) فعاله شفاف می‌شه (body.bg-mode-image #grat-root).
    // محتوای زیرتب‌ها فعلاً روشنه، پس در تم تاریک همون کرم قبلی می‌مونه.
    final hasBg = context.watch<BackgroundStore>().overridesBackdrop;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _built.add(_sub);
    final paper = hasBg
        ? Colors.transparent
        : (isDark ? const Color(0xFFFFFFFF) : Colors.white);

    return ColoredBox(
      color: paper,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(
          index: _sub,
          children: [
            // 0 = خانه
            _lazy(0, () => HomeTab(onOpenStore: () => setState(() => _sub = 1))),
            // 1 = بازی فراوانی
            _lazy(1, () => const StoreTab()),
            // 2 = شکرگذاری
            _lazy(2, () => const GratitudeTab()),
            // 3 = باورها
            _lazy(3, () => const BeliefsTab()),
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
