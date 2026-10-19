import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../neural/neural_store.dart';
import '../player_sync/player_sync_provider.dart';
import '../tts/speech_controller.dart';
import '../tts/speech_state.dart';
import '../storage/local_storage.dart';
import 'voice_prefs_provider.dart';

final speechControllerProvider =
    StateNotifierProvider<SpeechController, SpeechState>((ref) {
  return SpeechController(
    // صدای انتخاب‌شده‌ی کاربر برای هر زبان (در صورت وجود)
    voicePref: (lang) => ref.read(voicePrefsProvider)[lang],
    // پیش‌فرض = صدای خودِ گوشی؛ فقط اگر کاربر خودش «صدای اپ» را انتخاب کرده باشد.
    preferPhoneVoice: () =>
        ref.read(sharedPrefsProvider).getString('voiceEnginePref') != 'model',
    // 🧬 هر بار که یک لغت/جمله با پلیر کامل خوانده شد → یک تکرار در «مسیر عصبی»
    onChunkPlayed: (e) => _recordNeuralFromPlayback(ref, e),
  );
});

/// تشخیصِ اینکه این خوانش مالِ کدام «مورد» است و ثبتش:
///  • اگر متنِ در حال پخش همان متنِ کاملِ یکی از ترک‌های پلیرِ همگام
///    (لغات، مکالمات، …) باشد → مورد = آیتمِ همان آفست؛ base همیشه متنِ
///    انگلیسیِ آیتم است، پس خوانشِ ترجمه‌ها هم به همان تقویم می‌رود.
///  • وگرنه (مثلاً 🔊 داخلِ کارتِ انتخاب) → مورد = خودِ متنِ خوانده‌شده.
void _recordNeuralFromPlayback(Ref ref, ChunkPlayedEvent e) {
  try {
    final sync = ref.read(playerSyncProvider);
    String? base;
    if (e.key != null) {
      for (final t in sync.tracks.values) {
        if (t.key != e.key) continue;
        final span = t.spanAt(e.charOffset);
        if (span != null) {
          final en = ref.read(playerSyncProvider.notifier).itemText(span.id);
          if (en != null && en.trim().isNotEmpty) base = neuralBase(en);
        }
        break;
      }
    }
    // پخش از داخلِ یک کارت (🔊 لغت/ترجمه‌اش) → همان لغتِ انتخاب‌شده
    base ??= ref.read(neuralPathProvider.notifier).hintFor(e.key);
    base ??= neuralBase(e.text);
    if (base.isEmpty) return;
    ref.read(neuralPathProvider.notifier).addRepeat(base, e.code);
  } catch (_) {
    // ثبتِ تکرار هرگز نباید پخش را خراب کند
  }
}
