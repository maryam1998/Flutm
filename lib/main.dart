import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/storage.dart';
import 'state/map_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = MapStore(StorageService());
  await store.load();
  runApp(ChangeNotifierProvider.value(value: store, child: const MaghzApp()));
}
