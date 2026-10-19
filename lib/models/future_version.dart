import 'dart:math';

String _uid() =>
    DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
    Random().nextInt(1 << 30).toRadixString(36).padLeft(5, '0').substring(0, 5);

/// یک دوره‌ی تمام‌شده از خواندن متن آینده
class FutureReadCycle {
  final String startDate; // 'YYYY-M-D'
  final String? endDate;
  final List<String> readDays;
  final Map<String, int> readTimes; // dayKey → timestamp

  FutureReadCycle({
    required this.startDate,
    this.endDate,
    List<String>? readDays,
    Map<String, int>? readTimes,
  })  : readDays = readDays ?? [],
        readTimes = readTimes ?? {};

  Map<String, dynamic> toJson() => {
        'startDate': startDate,
        'endDate': endDate,
        'readDays': readDays,
        'readTimes': readTimes,
      };

  factory FutureReadCycle.fromJson(Map<String, dynamic> j) => FutureReadCycle(
        startDate: j['startDate'] as String? ?? '',
        endDate: j['endDate'] as String?,
        readDays: (j['readDays'] as List?)?.cast<String>() ?? [],
        readTimes: (j['readTimes'] as Map?)
                ?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ??
            {},
      );
}

/// یک نسخه از متن آینده. هر بار که کاربر متن رو کامل عوض می‌کنه،
/// نسخه‌ی قبلی آرشیو می‌شه و نسخه‌ی جدید فعال.
class FutureVersion {
  String id;
  String text;
  String? audioDataUrl; // ضبط ویس اختیاری (base64 data URL)

  /// تاریخ شروع این نسخه
  String startDate;

  /// اگه این نسخه آرشیو شده باشه، تاریخ پایانش
  String? endDate;

  /// روزهایی که کاربر متن رو خونده
  List<String> readDays;
  Map<String, int> readTimes;

  /// دوره‌های تمام‌شده‌ی این نسخه
  List<FutureReadCycle> cycles;

  /// متن‌های قبلیِ همین نسخه (تاریخچه‌ی ویرایش)
  List<PrevText> prevTexts;

  FutureVersion({
    String? id,
    this.text = '',
    this.audioDataUrl,
    required this.startDate,
    this.endDate,
    List<String>? readDays,
    Map<String, int>? readTimes,
    List<FutureReadCycle>? cycles,
    List<PrevText>? prevTexts,
  })  : id = id ?? _uid(),
        readDays = readDays ?? [],
        readTimes = readTimes ?? {},
        cycles = cycles ?? [],
        prevTexts = prevTexts ?? [];

  bool get isActive => endDate == null;

  bool get hasContent => text.trim().isNotEmpty || audioDataUrl != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'audio': audioDataUrl,
        'startDate': startDate,
        'endDate': endDate,
        'readDays': readDays,
        'readTimes': readTimes,
        'cycles': cycles.map((c) => c.toJson()).toList(),
        'prevTexts': prevTexts.map((p) => p.toJson()).toList(),
      };

  factory FutureVersion.fromJson(Map<String, dynamic> j) => FutureVersion(
        id: j['id'] as String?,
        text: j['text'] as String? ?? '',
        audioDataUrl: j['audio'] as String?,
        startDate: j['startDate'] as String? ?? '',
        endDate: j['endDate'] as String?,
        readDays: (j['readDays'] as List?)?.cast<String>() ?? [],
        readTimes: (j['readTimes'] as Map?)
                ?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ??
            {},
        cycles: (j['cycles'] as List?)
                ?.map((e) => FutureReadCycle.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        prevTexts: (j['prevTexts'] as List?)
                ?.map((e) => PrevText.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
      );
}

class PrevText {
  final String text;
  final int at;
  PrevText({required this.text, required this.at});

  Map<String, dynamic> toJson() => {'text': text, 'at': at};

  factory PrevText.fromJson(Map<String, dynamic> j) => PrevText(
        text: j['text'] as String? ?? '',
        at: (j['at'] as num?)?.toInt() ?? 0,
      );
}
