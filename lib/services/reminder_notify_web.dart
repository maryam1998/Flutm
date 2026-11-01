import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool notifySupported() {
  try {
    web.Notification.permission;
    return true;
  } catch (_) {
    return false;
  }
}

/// 'granted' | 'denied' | 'default' | 'unsupported'
String notifyPermission() {
  try {
    return web.Notification.permission;
  } catch (_) {
    return 'unsupported';
  }
}

/// باید از داخل یک لمسِ کاربر صدا زده شود (مرورگر غیر از این اجازه نمی‌دهد)
Future<String> requestNotifyPermission() async {
  try {
    final r = await web.Notification.requestPermission().toDart;
    return r.toDart;
  } catch (_) {
    return notifyPermission();
  }
}

/// اعلانِ سیستمی (وقتی صفحه در پس‌زمینه است). اندروید کروم فقط با Service Worker
/// اجازه‌ی اعلان می‌دهد، پس اول آن را امتحان می‌کنیم.
Future<bool> showSystemNotification(String title, String body) async {
  try {
    if (web.Notification.permission != 'granted') return false;
    final opts = web.NotificationOptions(
      body: body,
      tag: 'maghz-reminder',
      icon: 'icons/Icon-192.png',
    );
    try {
      final reg = await web.window.navigator.serviceWorker.ready.toDart
          .timeout(const Duration(seconds: 2));
      await reg.showNotification(title, opts).toDart;
      return true;
    } catch (_) {
      web.Notification(title, opts);
      return true;
    }
  } catch (_) {
    return false;
  }
}
