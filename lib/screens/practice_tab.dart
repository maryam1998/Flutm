import 'package:flutter/material.dart';

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
    return Scaffold(
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _sub,
        onDestinationSelected: (i) => setState(() => _sub = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'خانه',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
            label: 'بازی فراوانی',
          ),
          NavigationDestination(
            icon: Icon(Icons.volunteer_activism_outlined),
            selectedIcon: Icon(Icons.volunteer_activism),
            label: 'شکرگذاری',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(Icons.psychology),
            label: 'باورها',
          ),
        ],
      ),
    );
  }
}
