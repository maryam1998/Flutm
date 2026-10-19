import 'package:flutter_riverpod/flutter_riverpod.dart';

/// معادلِ bridge.js — یک جای مشترک برای callbackها و contextهای سراسری
/// که threading prop برایشان بی‌دلیل سنگین است. در Riverpod همان اثر را
/// می‌گیریم بدون singletonهای دستی؛ اینجا فقط API نگه می‌داریم.
class LatestStoryTextContext {
  final String text;
  final String code;
  const LatestStoryTextContext({this.text = '', this.code = ''});

  LatestStoryTextContext copyWith({String? text, String? code}) =>
      LatestStoryTextContext(text: text ?? this.text, code: code ?? this.code);
}

class AppBridge {
  LatestStoryTextContext latestStoryTextContext = const LatestStoryTextContext();

  // پلیر صوتی کاربر (فاز ۳) این‌ها را ثبت می‌کند تا پاپ‌آپ لغت
  // (GlobalAddToStorySelection) بتواند صدا را موقتاً مکث/ادامه کند.
  Future<void> Function()? activeUserAudioFocusPause;
  Future<void> Function()? activeUserAudioPause;
  Future<void> Function()? activeUserAudioPlay;

  // پرش به تب گرامر از داخل پاپ‌آپ لغت.
  void Function(String word)? requestGrammarJump;

  // افزودن لغت به لایتنر از داخل پاپ‌آپ لغت.
  void Function(String word)? requestAddToLeitner;
}

final appBridgeProvider = Provider<AppBridge>((ref) => AppBridge());
