import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';

/// وب: دقیقاً IndexedDB مرورگر (مثل Hope).
Future<Database> openCacheDatabase(String name) =>
    databaseFactoryWeb.openDatabase(name);
