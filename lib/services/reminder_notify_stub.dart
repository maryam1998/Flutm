/// موبایل/دسکتاپ: اعلان سیستمی پیاده نشده؛ یادآور فقط داخل برنامه نشان داده می‌شود.
bool notifySupported() => false;

/// 'granted' | 'denied' | 'default' | 'unsupported'
String notifyPermission() => 'unsupported';

Future<String> requestNotifyPermission() async => 'unsupported';

Future<bool> showSystemNotification(String title, String body) async => false;
