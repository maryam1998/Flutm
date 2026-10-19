enum SpeechStatus { idle, playing, paused }

class SpeechState {
  final String? key;
  final SpeechStatus status;
  final int chunkIndex;

  /// آفستِ کاراکتریِ شروعِ جمله‌ی در حال پخش داخل متنِ کامل
  /// (معادل speechController.getCharOffset() در Hope) — پایه‌ی هایلایت و
  /// اسکرول خودکار.
  final int charOffset;
  final int total;
  final double rate;

  /// 0 = خاموش | 2 = دوبار | 3 = سه‌بار | -1 = بی‌نهایت
  final int globalRepeat;
  final bool muted;
  final String? error;

  /// A-B state: 'idle' | 'waitingB' | 'looping'
  final String abState;
  final int? abChunkA;
  final int? abChunkB;

  /// آیا «قبلی/بعدی» کاری برای انجام دارد (جمله‌ی دیگر یا آیتم دیگرِ صف)
  final bool hasPrev;
  final bool hasNext;

  const SpeechState({
    this.key,
    this.status = SpeechStatus.idle,
    this.chunkIndex = 0,
    this.charOffset = 0,
    this.total = 0,
    this.rate = 1.0,
    this.globalRepeat = 0,
    this.muted = false,
    this.error,
    this.abState = 'idle',
    this.abChunkA,
    this.abChunkB,
    this.hasPrev = false,
    this.hasNext = false,
  });

  SpeechState copyWith({
    String? key,
    bool clearKey = false,
    SpeechStatus? status,
    int? chunkIndex,
    int? charOffset,
    int? total,
    double? rate,
    int? globalRepeat,
    bool? muted,
    String? error,
    bool clearError = false,
    String? abState,
    int? abChunkA,
    int? abChunkB,
    bool clearAB = false,
    bool? hasPrev,
    bool? hasNext,
  }) =>
      SpeechState(
        key: clearKey ? null : (key ?? this.key),
        status: status ?? this.status,
        chunkIndex: chunkIndex ?? this.chunkIndex,
        charOffset: charOffset ?? this.charOffset,
        total: total ?? this.total,
        rate: rate ?? this.rate,
        globalRepeat: globalRepeat ?? this.globalRepeat,
        muted: muted ?? this.muted,
        error: clearError ? null : (error ?? this.error),
        abState: abState ?? this.abState,
        abChunkA: clearAB ? null : (abChunkA ?? this.abChunkA),
        abChunkB: clearAB ? null : (abChunkB ?? this.abChunkB),
        hasPrev: hasPrev ?? this.hasPrev,
        hasNext: hasNext ?? this.hasNext,
      );
}
