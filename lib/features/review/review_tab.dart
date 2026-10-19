import 'package:flutter/material.dart';

import 'screens/review_dashboard.dart';

/// ورودی تب «مرور» — جایگزین lib/features/tabs/review_tab.dart
class ReviewTab extends StatelessWidget {
  const ReviewTab({super.key});

  @override
  Widget build(BuildContext context) => const ReviewDashboard();
}
