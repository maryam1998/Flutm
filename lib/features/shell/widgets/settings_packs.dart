// 📁 مسیر: lib/features/shell/widgets/settings_packs.dart
//
// بخش‌های «بسته‌های آفلاین» و «دانلود آفلاین لغات» تنظیمات — معادل
// OfflineSpeechSettings / VoiceSettings / AudioSyncSettings / OfflineWordsModal در Hope.

import '../../tabs/_hope_panel.dart' show uiContentDirection;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../core/bridge/linlearn_bridge.dart';
import '../../../core/constants/supported_languages.dart';
import '../../../core/data/data_repository.dart';
import '../../../core/models/filter_state.dart';
import '../../../core/providers/ai_settings_provider.dart';
import '../../../core/providers/translation_provider.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/translate/translation_service.dart'
    show looksLikelyMistranslated;

// ═══════════════════════════════════════════════════════════════════
// یک بستهٔ آفلاین (دانلود / توقف / حذف) — وضعیت از سمت نیتیو خوانده می‌شود
// ═══════════════════════════════════════════════════════════════════
class PackTile extends StatefulWidget {
  /// 'tts' | 'speech' | 'song' | 'sync'
  final String kind;
  final String id;
  final String title;
  final String? hint;
  final int approxMb;

  /// فقط برای حالت آهنگ: کلید روشن/خاموش بعد از دانلود
  final String? toggleTitle;

  /// بدون کادر و عنوان: فقط دکمه/وضعیت (مثل Hope که زیر لیست‌ها فقط دکمه دارد)
  final bool bare;

  /// دکمه‌ی دانلود به‌صورت پر (سبزِ تیره، متن روشن)
  final bool filled;

  /// متن دلخواه دکمه‌ی دانلود / ادامه (وگرنه متن پیش‌فرض l10n)
  final String Function(int mb)? downloadLabel;
  final String Function(String have, int mb)? resumeLabel;

  const PackTile({
    super.key,
    required this.kind,
    required this.id,
    required this.title,
    this.hint,
    this.approxMb = 0,
    this.toggleTitle,
    this.bare = false,
    this.filled = false,
    this.downloadLabel,
    this.resumeLabel,
  });

  @override
  State<PackTile> createState() => _PackTileState();
}

class _PackTileState extends State<PackTile> {
  Map<String, dynamic>? _st;
  bool _loaded = false;
  bool _stopping = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant PackTile old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id || old.kind != widget.kind) {
      _timer?.cancel();
      _stopping = false;
      _refresh();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _downloading => _st?['downloading'] == true;
  bool get _downloaded => _st?['downloaded'] == true;

  Future<void> _refresh() async {
    final st = await LinLearnBridge.packStatus(widget.kind, widget.id);
    if (!mounted) return;
    setState(() {
      _st = st;
      _loaded = true;
      if (!_downloading) _stopping = false;
    });
    _timer?.cancel();
    if (_downloading) {
      _timer = Timer(const Duration(seconds: 1), _refresh);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _download() async {
    final ok = await LinLearnBridge.packDownload(widget.kind, widget.id);
    if (!ok) _toast(context.l10n.st_download_failed);
    await _refresh();
  }

  Future<void> _cancel() async {
    setState(() => _stopping = true);
    await LinLearnBridge.packCancel(widget.kind, widget.id);
    await _refresh();
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => _dirDialog(ctx, AlertDialog(
        content: Text(context.l10n.st_pack_delete_confirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.st_no)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.st_delete)),
        ],
      )),
    );
    if (yes != true) return;
    await LinLearnBridge.packDelete(widget.kind, widget.id);
    await _refresh();
  }

  Future<void> _setEnabled(bool v) async {
    await LinLearnBridge.packSetEnabled(widget.kind, widget.id, v);
    await _refresh();
  }

  static String _mb(num bytes) => (bytes / (1024 * 1024)).round().toString();

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final note = TextStyle(color: c.inkSoft, fontSize: 11.5, height: 1.7);

    Widget btn(String label, VoidCallback? onTap,
            {Color? color, bool filled = false}) =>
        SizedBox(
          width: double.infinity,
          child: filled
              ? ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.headerFrom,
                    foregroundColor: c.headerText,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        vertical: 13, horizontal: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700)),
                )
              : OutlinedButton(
                  onPressed: onTap,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.35),
                    side: BorderSide(color: color ?? c.cardBorder),
                    padding: const EdgeInsets.symmetric(
                        vertical: 13, horizontal: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: color ?? c.ink,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                ),
        );

    Widget body;
    if (!_loaded) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: LinearProgressIndicator(minHeight: 2),
      );
    } else if (_st == null) {
      body = Text(context.l10n.st_pack_not_native, style: note);
    } else if (_downloading) {
      final bytes = (_st!['bytes'] as num?) ?? 0;
      final total = (_st!['total'] as num?) ?? 0;
      final pct = total > 0 ? (bytes / total).clamp(0, 1).toDouble() : null;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              context.l10n.st_pack_downloading(
                  _mb(bytes),
                  total > 0 ? ' (~${(pct! * 100).round()}%)' : ''),
              style: note),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: pct, minHeight: 4, color: c.teal),
          const SizedBox(height: 8),
          btn(_stopping ? context.l10n.st_pack_stopping : context.l10n.st_pack_stop,
              _stopping ? null : _cancel),
        ],
      );
    } else if (_downloaded) {
      final enabled = _st!['enabled'] == true;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.st_pack_ready, style: note),
          if (widget.toggleTitle != null && _st!.containsKey('enabled'))
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: c.teal,
              title: Text(widget.toggleTitle!,
                  style: TextStyle(
                      color: c.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
              value: enabled,
              onChanged: _setEnabled,
            ),
          const SizedBox(height: 6),
          btn(context.l10n.st_pack_delete_btn, _delete, color: c.inkSoft),
        ],
      );
    } else {
      final have = (_st!['partialBytes'] as num?) ?? 0;
      final mb = ((_st!['approxMb'] as num?) ?? widget.approxMb).round();
      final L = context.l10n;
      final label = have > 0
          ? (widget.resumeLabel?.call(_mb(have), mb) ??
              L.settings_pack_resume(_mb(have), '$mb'))
          : (mb > 0
              ? (widget.downloadLabel?.call(mb) ??
                  L.settings_pack_download('$mb'))
              : L.settings_download);
      body = btn('📥 $label', _download, filled: widget.filled);
    }

    if (widget.bare) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: body,
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title,
              style: TextStyle(
                  color: c.ink, fontSize: 13, fontWeight: FontWeight.w800)),
          if (widget.hint != null) ...[
            const SizedBox(height: 4),
            Text(widget.hint!, style: note),
          ],
          const SizedBox(height: 8),
          body,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// یک ردیف از «صدای آفلاینِ باکیفیت» — [نام زبان]  ........  [📥 دانلود]
// دانلود فقط وقتی شروع می‌شود که کاربر خودش دکمه را بزند.
// ═══════════════════════════════════════════════════════════════════
class TtsPackRow extends StatefulWidget {
  final String code;
  final String label;

  /// زبان‌هایی که بسته‌ی آفلاین ندارند و فقط با صدای خودِ گوشی خوانده می‌شوند
  final bool phoneOnly;

  const TtsPackRow({
    super.key,
    required this.code,
    required this.label,
    this.phoneOnly = false,
  });

  @override
  State<TtsPackRow> createState() => _TtsPackRowState();
}

class _TtsPackRowState extends State<TtsPackRow> {
  Map<String, dynamic>? _st;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (!widget.phoneOnly) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _downloading => _st?['downloading'] == true;
  bool get _downloaded => _st?['downloaded'] == true;

  Future<void> _refresh() async {
    final st = await LinLearnBridge.packStatus('tts', widget.code);
    if (!mounted) return;
    setState(() => _st = st);
    _timer?.cancel();
    if (_downloading) {
      _timer = Timer(const Duration(seconds: 1), _refresh);
    }
  }

  Future<void> _download() async {
    final ok = await LinLearnBridge.packDownload('tts', widget.code);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.settings_sync_download_failed)),
      );
    }
    await _refresh();
  }

  Future<void> _cancel() async {
    await LinLearnBridge.packCancel('tts', widget.code);
    await _refresh();
  }

  Future<void> _delete() async {
    final ml = MaterialLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => _dirDialog(ctx, AlertDialog(
        content: Text(context.l10n.settings_tts_delete_confirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ml.cancelButtonLabel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ml.deleteButtonTooltip)),
        ],
      )),
    );
    if (yes != true) return;
    await LinLearnBridge.packDelete('tts', widget.code);
    await _refresh();
  }

  Widget _pill(BuildContext context, String text, VoidCallback? onTap) {
    final c = context.appColors;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.cardBorder),
        ),
        child: Text(text,
            style: TextStyle(
                color: c.ink, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final L = context.l10n;

    Widget trailing;
    if (widget.phoneOnly) {
      trailing = Text(L.settings_tts_phone_only,
          style: TextStyle(color: c.inkSoft, fontSize: 11.5));
    } else if (_downloading) {
      final bytes = (_st?['bytes'] as num?) ?? 0;
      final total = (_st?['total'] as num?) ?? 0;
      final pct = total > 0 ? (bytes / total * 100).clamp(0, 100).round() : null;
      trailing = _pill(
        context,
        '⏹ ${pct != null ? '$pct%' : L.settings_stop}',
        _cancel,
      );
    } else if (_downloaded) {
      trailing = _pill(context, '✅ ${L.settings_tts_offline}', _delete);
    } else {
      trailing = _pill(context, '📥 ${L.settings_download}', _download);
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(widget.label,
                style: TextStyle(
                    color: c.ink, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// دانلود آفلاین لغات — ترجمه‌ی همه‌ی لغات و ذخیره در کش گوشی
// ═══════════════════════════════════════════════════════════════════
class OfflineWordsDialog extends ConsumerStatefulWidget {
  const OfflineWordsDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Directionality(
          textDirection: uiContentDirection(ctx),
          child: const OfflineWordsDialog(),
        ),
      );

  @override
  ConsumerState<OfflineWordsDialog> createState() => _OfflineWordsDialogState();
}

class _OfflineWordsDialogState extends ConsumerState<OfflineWordsDialog> {
  final Set<String> _selected = {};
  List<String> _words = const [];
  bool _running = false;
  bool _finished = false;
  bool _cancel = false;
  int _done = 0, _total = 0, _failed = 0, _bytes = 0;
  String _current = '';
  int _cached = 0;

  static const String _cachePrefix = 'tr3::';

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _countCached() => ref
      .read(sharedPrefsProvider)
      .getKeys()
      .where((k) => k.startsWith(_cachePrefix))
      .length;

  Future<void> _load() async {
    await DataRepository.instance.load();
    final all = DataRepository.instance
        .filterWords(const WordsFilterState())
        .map((w) => w.en.trim())
        .where((w) => w.isNotEmpty)
        .toSet()
        .toList();
    if (!mounted) return;
    setState(() {
      _words = all;
      _cached = _countCached();
    });
  }

  static String _size(BuildContext context, int bytes) {
    final kb = bytes / 1024;
    if (kb < 1024) {
      return context.l10n
          .st_unit_kb('${kb < 10 ? kb.toStringAsFixed(1) : kb.round()}');
    }
    return context.l10n.st_unit_mb((kb / 1024).toStringAsFixed(1));
  }

  Future<void> _start() async {
    if (_selected.isEmpty || _running) return;
    final service = ref.read(translationServiceProvider);
    final ai = ref.read(aiSettingsProvider);
    final jobs = <(String, String)>[
      for (final l in _selected)
        for (final w in _words) (w, l),
    ];
    setState(() {
      _running = true;
      _finished = false;
      _cancel = false;
      _done = 0;
      _failed = 0;
      _bytes = 0;
      _total = jobs.length;
    });

    var cursor = 0;
    Future<void> worker() async {
      while (cursor < jobs.length) {
        if (_cancel || !mounted) return;
        final (word, lang) = jobs[cursor++];
        _current = word;
        // لغت‌ها خودشان انگلیسی‌اند؛ برای «انگلیسی» ترجمه‌ای لازم نیست (آماده است).
        if (lang == 'en') {
          _done++;
          if (mounted && _done % 5 == 0) setState(() {});
          continue;
        }
        try {
          final r = await service.translate(
            text: word,
            targetLang: lang,
            sourceLang: 'en',
            aiSettings: ai,
          );
          if (r.isNotEmpty &&
              !looksLikelyMistranslated(word, r, lang, sourceLang: 'en')) {
            _bytes += r.length * 2;
          } else {
            _failed++;
          }
        } catch (_) {
          _failed++;
        }
        _done++;
        if (mounted && _done % 5 == 0) setState(() {});
      }
    }

    await Future.wait(List.generate(8, (_) => worker()));
    if (!mounted) return;
    setState(() {
      _running = false;
      _finished = !_cancel;
      _cached = _countCached();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final note = TextStyle(color: c.inkSoft, fontSize: 12, height: 1.8);
    final pct = _total == 0 ? 0 : ((_done / _total) * 100).round();
    final langs = kSupportedLanguages.toList(); // انگلیسی هم هست

    return Dialog(
      backgroundColor: c.paper,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(context.l10n.wd_title,
                        style: TextStyle(
                            color: c.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                  ),
                  if (!_running)
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.close, size: 18, color: c.inkSoft),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.wd_intro('${_words.length}'),
                style: note,
              ),
              const SizedBox(height: 14),
              if (!_running && !_finished) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final l in langs)
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => setState(() {
                          if (!_selected.remove(l.code)) _selected.add(l.code);
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _selected.contains(l.code)
                                ? c.goldSoft
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _selected.contains(l.code)
                                    ? c.gold
                                    : c.cardBorder,
                                width: 1.5),
                          ),
                          child: Text(langDisplayName(context, l.code),
                              style: TextStyle(
                                  color: c.ink,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _selected.isEmpty || _words.isEmpty ? null : _start,
                    style: FilledButton.styleFrom(
                      backgroundColor: c.ink,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(_selected.isNotEmpty
                        ? context.l10n
                            .wd_start_n('${_words.length * _selected.length}')
                        : context.l10n.wd_start),
                  ),
                ),
                if (_cached > 0) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                        context.l10n.wd_cached('$_cached'),
                        style: note.copyWith(fontSize: 11)),
                  ),
                ],
              ],
              if (_running) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                      value: _total == 0 ? null : _done / _total,
                      minHeight: 10,
                      color: c.gold),
                ),
                const SizedBox(height: 8),
                Text(
                    context.l10n.wd_progress('$_done', '$_total', '$pct',
                        _size(context, _bytes)),
                    style: note),
                if (_failed > 0)
                  Text(context.l10n.wd_pending('$_failed'),
                      style: note.copyWith(color: c.rose, fontSize: 11)),
                Text(_current,
                    textDirection: TextDirection.ltr,
                    style: note.copyWith(fontSize: 11)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _cancel = true;
                    }),
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: c.rose)),
                    child: Text(context.l10n.wd_cancel,
                        style: TextStyle(color: c.rose)),
                  ),
                ),
              ],
              if (_finished) ...[
                Center(
                  child: Column(
                    children: [
                      Text(context.l10n.wd_done,
                          style: TextStyle(
                              color: c.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                          context.l10n.wd_done_body('$_cached'),
                          style: note,
                          textAlign: TextAlign.center),
                      if (_failed > 0)
                        Text(
                            context.l10n.wd_failed('$_failed'),
                            style: note.copyWith(color: c.rose, fontSize: 11),
                            textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context),
                          style: FilledButton.styleFrom(backgroundColor: c.ink),
                          child: Text(context.l10n.wd_ok),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// دیالوگ‌های تنظیمات هم طبقِ زبانِ رابط جهت می‌گیرند.
Widget _dirDialog(BuildContext ctx, Widget child) =>
    Directionality(textDirection: uiContentDirection(ctx), child: child);
