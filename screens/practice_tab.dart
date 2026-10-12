import 'package:flutter/material.dart';

import 'beliefs_tab.dart';
import 'gratitude_tab.dart';
import 'placeholder_tab.dart';

/// تب «تمرین» — شامل چهار زیرتب: خانه، بازی فراوانی، شکرگذاری، باورها.
/// زیرتب‌ها با IndexedStack نگه داشته می‌شوند تا state هر کدام با جابه‌جایی حفظ شود.
class PracticeTab extends StatefulWidget {
  const PracticeTab({super.key});

  @override
  State<PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<PracticeTab> {
  // ترتیب RTL: اولین آیتم سمت راست نمایش داده می‌شود (مثل نسخه‌ی وب).
  int _sub = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: _sub,
            children: const [
              PlaceholderTab(title: 'خانه', note: 'به‌زودی منتقل می‌شود'),
              PlaceholderTab(
                  title: 'بازی فراوانی', note: 'به‌زودی منتقل می‌شود'),
              GratitudeTab(),
              BeliefsTab(),
            ],
          ),
        ),
        NavigationBarTheme(
          data: NavigationBarTheme.of(context).copyWith(height: 64),
          child: NavigationBar(
            selectedIndex: _sub,
            onDestinationSelected: (i) => setState(() => _sub = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'خانه'),
              NavigationDestination(
                  icon: Icon(Icons.shopping_bag_outlined),
                  selectedIcon: Icon(Icons.shopping_bag),
                  label: 'بازی فراوانی'),
              NavigationDestination(
                  icon: Icon(Icons.favorite_border),
                  selectedIcon: Icon(Icons.favorite),
                  label: 'شکرگذاری'),
              NavigationDestination(
                  icon: Icon(Icons.auto_awesome_outlined),
                  selectedIcon: Icon(Icons.auto_awesome),
                  label: 'باورها'),
            ],
          ),
        ),
      ],
    );
  }
}
