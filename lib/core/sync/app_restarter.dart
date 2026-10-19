import 'package:flutter/widgets.dart';

/// بعد از بازیابیِ داده‌ی ابری، کل درخت Riverpod از نو ساخته می‌شود تا همه‌ی
/// providerها داده‌ی تازه را از SharedPreferences بخوانند.
class AppRestarter extends StatefulWidget {
  final Widget Function() builder;
  const AppRestarter({super.key, required this.builder});

  static final ValueNotifier<int> _tick = ValueNotifier<int>(0);

  /// اپ را (بدون بستن) دوباره می‌سازد.
  static void restart() => _tick.value++;

  @override
  State<AppRestarter> createState() => _AppRestarterState();
}

class _AppRestarterState extends State<AppRestarter> {
  @override
  void initState() {
    super.initState();
    AppRestarter._tick.addListener(_onTick);
  }

  @override
  void dispose() {
    AppRestarter._tick.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey<int>(AppRestarter._tick.value),
      child: widget.builder(),
    );
  }
}
