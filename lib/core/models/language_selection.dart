import 'package:flutter/foundation.dart';

@immutable
class LanguageSelection {
  /// کد زبان مادری — مثل 'fa', 'en', 'ar'
  final String native;

  /// زبان‌های مقصد (فعلاً یکی، ولی آماده برای چندتایی)
  final List<String> targets;

  const LanguageSelection({
    required this.native,
    required this.targets,
  });

  static const LanguageSelection defaults = LanguageSelection(
    native: 'fa',
    targets: ['en'],
  );

  String? get primaryTarget =>
      targets.isEmpty ? null : targets.first;

  LanguageSelection copyWith({
    String? native,
    List<String>? targets,
  }) {
    return LanguageSelection(
      native: native ?? this.native,
      targets: targets ?? this.targets,
    );
  }

  Map<String, dynamic> toJson() => {
        'native': native,
        'targets': targets,
      };

  factory LanguageSelection.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    return LanguageSelection(
      native: (json['native'] as String?) ?? defaults.native,
      targets: (json['targets'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          defaults.targets,
    );
  }
}
