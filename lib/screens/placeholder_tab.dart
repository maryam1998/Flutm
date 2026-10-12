import 'package:flutter/material.dart';

class PlaceholderTab extends StatelessWidget {
  const PlaceholderTab({super.key, required this.title, required this.note});
  final String title, note;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(note, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(140)))),
    );
  }
}
