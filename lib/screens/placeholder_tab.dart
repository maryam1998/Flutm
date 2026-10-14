import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/background_store.dart';
import '../theme/web_palette.dart';

class PlaceholderTab extends StatelessWidget {
  const PlaceholderTab({super.key, required this.title, required this.note});
  final String title, note;

  @override
  Widget build(BuildContext context) {
    final p = WebPalette.of(context);
    // وب: #shenakht-root پس‌زمینه‌ی --bg-2 دارد
    final hasBg = context.watch<BackgroundStore>().hasBackground;
    return ColoredBox(
      color: hasBg ? Colors.transparent : p.bg2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Text(note, style: TextStyle(color: p.textDim)),
        ),
      ),
    );
  }
}
