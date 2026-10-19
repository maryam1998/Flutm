// 📁 مسیر: lib/core/providers/linlearn_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../bridge/linlearn_bridge.dart';

// ═══════════════════════════════════════════════════════════
// بررسی اجازه‌ی نمایش حباب شناور
// ═══════════════════════════════════════════════════════════
final overlayPermissionProvider = FutureProvider<bool>((ref) async {
  return LinLearnBridge.canDrawOverlays();
});

// ═══════════════════════════════════════════════════════════
// حباب شناور
// ═══════════════════════════════════════════════════════════
class BubbleState {
  /// آیا حباب در حال اجرا است؟
  final bool running;

  /// حالت حباب: 'both' | 'magnifier' | 'translator'
  final String mode;

  const BubbleState({this.running = false, this.mode = 'both'});

  BubbleState copyWith({bool? running, String? mode}) => BubbleState(
        running: running ?? this.running,
        mode: mode ?? this.mode,
      );
}

class BubbleNotifier extends StateNotifier<BubbleState> {
  BubbleNotifier() : super(const BubbleState());

  Future<void> start({String mode = 'both'}) async {
    await LinLearnBridge.startBubble(mode: mode);
    state = BubbleState(running: true, mode: mode);
  }

  Future<void> stop() async {
    await LinLearnBridge.stopBubble();
    state = const BubbleState();
  }

  /// بعد از باز شدن/برگشت به اپ: وضعیتِ واقعیِ حباب را از اندروید بخوان.
  Future<void> syncFromNative() async {
    final running = await LinLearnBridge.isBubbleRunning();
    if (running != state.running) {
      state = running ? BubbleState(running: true, mode: state.mode) : const BubbleState();
    }
  }
}

final bubbleProvider =
    StateNotifierProvider<BubbleNotifier, BubbleState>(
  (ref) => BubbleNotifier(),
);

// ═══════════════════════════════════════════════════════════
// ترجمه‌ی زنده‌ی صدا
// ═══════════════════════════════════════════════════════════
class LiveTranslatorNotifier extends StateNotifier<bool> {
  LiveTranslatorNotifier() : super(false);

  Future<void> start({
    required String sourceLang,
    required String targetLang,
  }) async {
    await LinLearnBridge.startLiveTranslator(
      sourceLang: sourceLang,
      targetLang: targetLang,
    );
    state = true;
  }

  Future<void> stop() async {
    await LinLearnBridge.stopLiveTranslator();
    state = false;
  }
}

final liveTranslatorProvider =
    StateNotifierProvider<LiveTranslatorNotifier, bool>(
  (ref) => LiveTranslatorNotifier(),
);
