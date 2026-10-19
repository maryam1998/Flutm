import 'package:flutter/material.dart';

@immutable
class SupportedLanguage {
  final String code;
  final String abbr;
  final String faLabel;
  final String enLabel;
  final TextDirection dir;

  const SupportedLanguage({
    required this.code,
    required this.abbr,
    required this.faLabel,
    required this.enLabel,
    required this.dir,
  });
}

/// ترتیب نمایش دایره‌ها:
/// انگلیسی → اسپانیایی → آلمانی → فرانسوی → فارسی → بقیه
const List<SupportedLanguage> kSupportedLanguages = [
  SupportedLanguage(code: 'en', abbr: 'EN', faLabel: 'انگلیسی',   enLabel: 'English',   dir: TextDirection.ltr),
  SupportedLanguage(code: 'es', abbr: 'ES', faLabel: 'اسپانیایی', enLabel: 'Spanish',   dir: TextDirection.ltr),
  SupportedLanguage(code: 'de', abbr: 'DE', faLabel: 'آلمانی',    enLabel: 'German',    dir: TextDirection.ltr),
  SupportedLanguage(code: 'fr', abbr: 'FR', faLabel: 'فرانسوی',   enLabel: 'French',    dir: TextDirection.ltr),
  SupportedLanguage(code: 'fa', abbr: 'FA', faLabel: 'فارسی',     enLabel: 'Persian',   dir: TextDirection.rtl),
  SupportedLanguage(code: 'it', abbr: 'IT', faLabel: 'ایتالیایی', enLabel: 'Italian',   dir: TextDirection.ltr),
  SupportedLanguage(code: 'ar', abbr: 'AR', faLabel: 'عربی',      enLabel: 'Arabic',    dir: TextDirection.rtl),
  SupportedLanguage(code: 'tr', abbr: 'TR', faLabel: 'ترکی',      enLabel: 'Turkish',   dir: TextDirection.ltr),
  SupportedLanguage(code: 'ru', abbr: 'RU', faLabel: 'روسی',      enLabel: 'Russian',   dir: TextDirection.ltr),
  SupportedLanguage(code: 'hi', abbr: 'HI', faLabel: 'هندی',      enLabel: 'Hindi',     dir: TextDirection.ltr),
  SupportedLanguage(code: 'zh', abbr: 'ZH', faLabel: 'چینی',      enLabel: 'Chinese',   dir: TextDirection.ltr),
  SupportedLanguage(code: 'ja', abbr: 'JA', faLabel: 'ژاپنی',     enLabel: 'Japanese',  dir: TextDirection.ltr),
  SupportedLanguage(code: 'ko', abbr: 'KO', faLabel: 'کره‌ای',    enLabel: 'Korean',    dir: TextDirection.ltr),
];

const List<String> kRtlLangCodes = ['fa', 'ar'];

TextDirection dirFor(String code) =>
    kRtlLangCodes.contains(code) ? TextDirection.rtl : TextDirection.ltr;

/// نامِ زبان بر اساس زبانِ رابط: فارسی → نام فارسی، بقیه → نام انگلیسی.
String langDisplayName(BuildContext context, String code) {
  final fa = Localizations.localeOf(context).languageCode == 'fa';
  for (final l in kSupportedLanguages) {
    if (l.code == code) return fa ? l.faLabel : l.enLabel;
  }
  return code.toUpperCase();
}
