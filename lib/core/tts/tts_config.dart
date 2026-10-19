class TtsConfig {
  static const String backendUrl =
      'https://phrasebook-api.maryam-s-sharifiyan.workers.dev';

  static const Map<String, String> locale = {
    'fa': 'fa-IR', 'en': 'en-US', 'de': 'de-DE', 'es': 'es-ES',
    'fr': 'fr-FR', 'ar': 'ar-SA', 'tr': 'tr-TR', 'zh': 'zh-CN',
    'ru': 'ru-RU', 'it': 'it-IT', 'ko': 'ko-KR', 'ja': 'ja-JP',
    'hi': 'hi-IN', 'ga': 'ga-IE', 'uk': 'uk-UA',
  };

  static const Map<String, String> edgeVoice = {
    'fa': 'fa-IR-DilaraNeural', 'en': 'en-US-AriaNeural',
    'de': 'de-DE-KatjaNeural', 'es': 'es-ES-ElviraNeural',
    'fr': 'fr-FR-DeniseNeural', 'ar': 'ar-SA-ZariyahNeural',
    'tr': 'tr-TR-EmelNeural', 'zh': 'zh-CN-XiaoxiaoNeural',
    'ru': 'ru-RU-SvetlanaNeural', 'it': 'it-IT-ElsaNeural',
    'ko': 'ko-KR-SunHiNeural', 'ja': 'ja-JP-NanamiNeural',
    'hi': 'hi-IN-SwaraNeural', 'ga': 'ga-IE-OrlaNeural',
    'uk': 'uk-UA-PolinaNeural',
  };

  /// این دو زبان همیشه از مسیر آنلاین خونده می‌شن
  static const Set<String> onlineOnly = {'fa', 'ar'};
}
