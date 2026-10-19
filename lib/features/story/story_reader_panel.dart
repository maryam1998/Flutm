import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/audio/story_audio_controller.dart';
import '../../core/constants/supported_languages.dart' show dirFor;
import '../../core/models/text_prefs.dart';
import '../../core/player_sync/player_track.dart' show SyncItem, TrackMode;
import '../../core/player_sync/sync_widgets.dart'
    show SyncAnchor, SyncPlayScope, SyncSpeakButton, syncReportTranslation;
import '../../core/providers/ai_settings_provider.dart';
import '../../core/providers/text_prefs_provider.dart';
import '../../core/providers/translation_provider.dart';
import '../../core/storage/local_storage.dart' show sharedPrefsProvider;
import '../../core/theme/app_theme_colors.dart';
import '../../core/widgets/selection_card.dart' show SelectableSyncText;
import '../../core/widgets/sync_item_card.dart' show NeuralPathButton;
import '../reader/widgets/neural_path_dialog.dart' show showNeuralPath;
import '../tabs/_hope_panel.dart' show HopeChoiceChip, autoDir;

// ═══════════════════════════════════════════════════════════════════
// پنل خواندنِ داستان — هم‌شکل StoryReaderPanel.jsx در Hope
//   • بالا: عنوان + ✏️ ویرایشِ متن + 🔖 ذخیره در کتابخانه
//   • جستجو داخلِ متنِ داستان (هر زبانی)
//   • نمایشِ ترجمه: هیچ / پاراگراف‌به‌پاراگراف / جمله‌به‌جمله
//   • برای هر جمله (یا پاراگراف) و هر ترجمه: 🧬 🔊 و ↻
//   • پایین: یادداشت‌های من
// ═══════════════════════════════════════════════════════════════════

const String _kModeKey = 'zflut-story-trans-mode';
const Color _kTrColor = Color(0xFF0F5C34);

class _P {
  final String text;
  final List<String> sents;
  final int firstGi;
  const _P(this.text, this.sents, this.firstGi);
}

class _Job {
  final String lang;
  final String src;
  final String key;
  const _Job(this.lang, this.src, this.key);
}

class _Hit {
  final int pi;
  final int gi;
  final String text;
  const _Hit(this.pi, this.gi, this.text);
}

class StoryReaderPanel extends ConsumerStatefulWidget {
  /// شناسه‌ی یکتا (برای کلیدِ دکمه‌های 🔊)
  final String storyId;
  final String title;

  /// متنِ نمایشی؛ پاراگراف‌ها با خطِ خالی جدا می‌شوند
  final String text;

  /// متنِ کاملِ داستان برای ویرایش (اگر null باشد همان [text])
  final String? fullText;
  final String langCode;

  /// زبان‌های ترجمه (بدونِ زبانِ خودِ متن)
  final List<String> targetLangs;

  /// ترجمه‌های آماده‌ی هر پاراگراف (کد زبان → لیست) — فقط برای پُر کردنِ اولیه
  final Map<String, List<String>> paraTranslations;
  final List<String> Function(String) splitSentences;

  final StoryAudioController? audio;
  final Widget? audioBar;

  /// دکمه‌ی 🔖: null = نمایش داده نمی‌شود
  final VoidCallback? onSave;
  final bool saved;

  /// دکمه‌ی ✏️: null = نمایش داده نمی‌شود
  final ValueChanged<String>? onTextEdited;

  /// یادداشت‌ها: null = بخشِ یادداشت نمایش داده نمی‌شود
  final ValueChanged<String>? onNotesChanged;
  final String notes;

  /// وقتی کاربر ↻ روی یک پاراگراف می‌زند
  final void Function(String lang, int paraIdx, String text)?
      onParagraphRetranslated;

  const StoryReaderPanel({
    super.key,
    required this.storyId,
    required this.title,
    required this.text,
    required this.langCode,
    required this.targetLangs,
    required this.splitSentences,
    this.fullText,
    this.paraTranslations = const {},
    this.audio,
    this.audioBar,
    this.onSave,
    this.saved = false,
    this.onTextEdited,
    this.onNotesChanged,
    this.notes = '',
    this.onParagraphRetranslated,
  });

  @override
  ConsumerState<StoryReaderPanel> createState() => _StoryReaderPanelState();
}

class _StoryReaderPanelState extends ConsumerState<StoryReaderPanel> {
  /// 0 = هیچ، 1 = پاراگراف‌به‌پاراگراف، 2 = جمله‌به‌جمله
  int _mode = 2;

  final _searchCtrl = TextEditingController();
  final _editCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _editing = false;
  Timer? _notesTimer;
  Timer? _flashTimer;
  int _flashGi = -1;
  int? _lastActive;
  String _sig = '';

  // ثبتِ متنِ داستان در پلیرِ همگام (هایلایت + اسکرولِ خودکارِ 🔊 و پلیرِ پایین)
  Object _scopeRev = Object();
  String _scopeSig = '';

  final Map<String, String> _tr = {};
  final Set<String> _inflight = {};
  final Set<String> _failed = {};
  final Set<String> _retrying = {};
  final Map<int, GlobalKey> _pk = {};

  static String _k(String lang, String src) => '$lang\u0001$src';

  @override
  void initState() {
    super.initState();
    try {
      final v = ref.read(sharedPrefsProvider).getInt(_kModeKey);
      if (v != null && v >= 0 && v <= 2) _mode = v;
    } catch (_) {}
    _notesCtrl.text = widget.notes;
    _seed();
    _sig = _signature();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensure());
  }

  @override
  void didUpdateWidget(covariant StoryReaderPanel old) {
    super.didUpdateWidget(old);
    final s = _signature();
    if (s != _sig) {
      _sig = s;
      _seed();
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensure());
    }
    if (old.notes != widget.notes && widget.notes != _notesCtrl.text) {
      _notesCtrl.text = widget.notes;
    }
  }

  @override
  void dispose() {
    _notesTimer?.cancel();
    _flashTimer?.cancel();
    _searchCtrl.dispose();
    _editCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _signature() {
    var n = 0;
    for (final e in widget.paraTranslations.entries) {
      for (final v in e.value) {
        n += v.length + 1;
      }
    }
    return '${widget.text.hashCode}|${widget.langCode}|'
        '${widget.targetLangs.join(',')}|$n';
  }

  // ───────────── ساختارِ متن ─────────────
  List<_P> _structure() {
    final out = <_P>[];
    var gi = 0;
    for (final raw in widget.text.split(RegExp(r'\n\s*\n'))) {
      final p = raw.trim();
      if (p.isEmpty) continue;
      var ss = widget.splitSentences(p);
      if (ss.isEmpty) ss = [p];
      out.add(_P(p, ss, gi));
      gi += ss.length;
    }
    return out;
  }

  List<String> get _langs =>
      widget.targetLangs.where((l) => l != widget.langCode).toList();

  // ───────────── ترجمه ─────────────
  /// ترجمه‌های آماده‌ی پاراگراف را (و اگر تعدادِ جمله‌ها برابر بود، جمله‌به‌جمله) در کش می‌گذارد
  void _seed() {
    final paras = _structure();
    for (final lang in _langs) {
      final list = widget.paraTranslations[lang];
      if (list == null) continue;
      for (var i = 0; i < paras.length && i < list.length; i++) {
        final t = list[i].trim();
        if (t.isEmpty) continue;
        _tr.putIfAbsent(_k(lang, paras[i].text), () => t);
        final ts = widget.splitSentences(t);
        if (paras[i].sents.length > 1 && ts.length == paras[i].sents.length) {
          for (var k = 0; k < ts.length; k++) {
            _tr.putIfAbsent(_k(lang, paras[i].sents[k]), () => ts[k]);
          }
        }
      }
    }
  }

  void _ensure() {
    if (!mounted || _mode == 0) return;
    final langs = _langs;
    if (langs.isEmpty) return;
    final units = <String>[
      for (final p in _structure()) ...(_mode == 1 ? [p.text] : p.sents),
    ];
    final jobs = <_Job>[];
    for (final lang in langs) {
      for (final src in units) {
        final key = _k(lang, src);
        if (_tr.containsKey(key) ||
            _inflight.contains(key) ||
            _failed.contains(key)) {
          continue;
        }
        _inflight.add(key);
        jobs.add(_Job(lang, src, key));
      }
    }
    if (jobs.isNotEmpty) unawaited(_run(jobs));
  }

  Future<void> _run(List<_Job> jobs) async {
    final svc = ref.read(translationServiceProvider);
    final ai = ref.read(aiSettingsProvider);
    var next = 0;
    Future<void> worker() async {
      while (mounted) {
        final i = next++;
        if (i >= jobs.length) return;
        final j = jobs[i];
        var r = '';
        try {
          r = (await svc.translate(
            text: j.src,
            targetLang: j.lang,
            sourceLang: widget.langCode,
            aiSettings: ai,
          ))
              .trim();
        } catch (_) {}
        if (!mounted) return;
        setState(() {
          _inflight.remove(j.key);
          if (r.isEmpty || r == j.src.trim()) {
            _failed.add(j.key);
          } else {
            _tr[j.key] = r;
          }
        });
      }
    }

    await Future.wait([worker(), worker(), worker()]);
  }

  Future<void> _retry(String lang, String src, {int? paraIdx}) async {
    final key = _k(lang, src);
    if (_retrying.contains(key)) return;
    setState(() => _retrying.add(key));
    try {
      final r = (await ref.read(translationServiceProvider).retranslate(
                text: src,
                targetLang: lang,
                sourceLang: widget.langCode,
                aiSettings: ref.read(aiSettingsProvider),
              ))
          .trim();
      if (!mounted) return;
      if (r.isNotEmpty && r != src.trim()) {
        setState(() {
          _tr[key] = r;
          _failed.remove(key);
        });
        if (paraIdx != null) {
          widget.onParagraphRetranslated?.call(lang, paraIdx, r);
        }
      } else if (!_tr.containsKey(key)) {
        setState(() => _failed.add(key));
      }
    } catch (_) {
      if (mounted && !_tr.containsKey(key)) setState(() => _failed.add(key));
    } finally {
      if (mounted) setState(() => _retrying.remove(key));
    }
  }

  void _setMode(int m) {
    if (m == _mode) return;
    setState(() => _mode = m);
    try {
      ref.read(sharedPrefsProvider).setInt(_kModeKey, m);
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensure());
  }

  // ───────────── ویرایش / یادداشت / جستجو ─────────────
  void _toggleEdit() {
    setState(() {
      if (_editing) {
        _editing = false;
      } else {
        _editCtrl.text = widget.fullText ?? widget.text;
        _editing = true;
      }
    });
  }

  void _applyEdit() {
    final t = _editCtrl.text.trim();
    if (t.isEmpty) return;
    setState(() => _editing = false);
    widget.onTextEdited?.call(t);
  }

  void _onNotes(String v) {
    _notesTimer?.cancel();
    _notesTimer = Timer(const Duration(milliseconds: 600), () {
      widget.onNotesChanged?.call(v);
    });
  }

  List<_Hit> _hits(List<_P> paras) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final out = <_Hit>[];
    for (var pi = 0; pi < paras.length; pi++) {
      final p = paras[pi];
      for (var si = 0; si < p.sents.length; si++) {
        final s = p.sents[si];
        var hit = s.toLowerCase().contains(q);
        if (!hit) {
          for (final lang in _langs) {
            final t = _tr[_k(lang, s)];
            if (t != null && t.toLowerCase().contains(q)) {
              hit = true;
              break;
            }
          }
        }
        if (hit) out.add(_Hit(pi, p.firstGi + si, s));
        if (out.length >= 30) return out;
      }
    }
    return out;
  }

  void _jumpTo(_Hit h) {
    FocusScope.of(context).unfocus();
    setState(() => _flashGi = h.gi);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _flashGi = -1);
    });
    final ctx = _pk[h.pi]?.currentContext;
    if (ctx != null && ctx.mounted) {
      Scrollable.ensureVisible(ctx,
          alignment: 0.2,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut);
    }
  }

  /// آیتم‌های پلیر: جمله‌به‌جمله (حالتِ ۲) یا پاراگراف‌به‌پاراگراف (حالتِ ۰ و ۱)
  /// — همان شناسه‌هایی که ردیف‌ها برای هایلایت/اسکرول استفاده می‌کنند.
  List<SyncItem> _syncItems() {
    final out = <SyncItem>[];
    final paras = _structure();
    for (var pi = 0; pi < paras.length; pi++) {
      final p = paras[pi];
      if (_mode == 2) {
        for (var si = 0; si < p.sents.length; si++) {
          out.add(SyncItem('${widget.storyId}-s${p.firstGi + si}', p.sents[si]));
        }
      } else {
        out.add(SyncItem('${widget.storyId}-p$pi', p.text));
      }
    }
    return out;
  }

  // ───────────── ساخت ─────────────
  @override
  Widget build(BuildContext context) {
    final audio = widget.audio;
    // ref.watch فقط همین‌جا (داخلِ build) — نه داخلِ builderِ فرزند
    final tp = ref.watch(textPrefsProvider);
    if (audio == null) return _card(context, tp, null);
    // با هر تغییرِ خطِ فعالِ صدا، هایلایت و اسکرول به‌روز می‌شود
    return ListenableBuilder(
      listenable: audio,
      builder: (ctx, _) => _card(ctx, tp, audio.hasAudio ? audio : null),
    );
  }

  Widget _card(
      BuildContext context, TargetTextPrefs tp, StoryAudioController? audio) {
    final c = context.appColors;
    final paras = _structure();
    final hits = _hits(paras);
    final q = _searchCtrl.text.trim();

    // اسکرولِ خودکار به پاراگرافِ جمله‌ی فعالِ صدا
    if (audio != null && _lastActive != audio.activeIndex) {
      final was = _lastActive;
      _lastActive = audio.activeIndex;
      if (was != null) {
        var pi = -1;
        for (var i = 0; i < paras.length; i++) {
          if (audio.activeIndex < paras[i].firstGi + paras[i].sents.length) {
            pi = i;
            break;
          }
        }
        if (pi >= 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = _pk[pi]?.currentContext;
            if (ctx != null && ctx.mounted) {
              Scrollable.ensureVisible(ctx,
                  alignment: 0.25,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut);
            }
          });
        }
      }
    }

    final hasEdit = widget.onTextEdited != null;
    final hasSave = widget.onSave != null || widget.saved;

    final sig = '${widget.storyId}|${widget.text.hashCode}|$_mode|'
        '${widget.langCode}|$_editing';
    if (sig != _scopeSig) {
      _scopeSig = sig;
      _scopeRev = Object();
    }

    return SyncPlayScope(
      revision: _scopeRev,
      mode: TrackMode.lines,
      mainCode: widget.langCode,
      itemsBuilder: () => _editing ? const <SyncItem>[] : _syncItems(),
      child: Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: c.cardBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── سرتیتر: عنوان | ✏️ | 🔖 ──
            // (این پنل همیشه RTL است؛ پس اولین فرزند = راست‌ترین)
            Row(
              children: [
                if (hasEdit)
                  _HeadIcon(
                    icon: _editing ? Icons.close : Icons.edit_outlined,
                    color: _editing ? c.rose : c.teal,
                    tooltip: _editing
                        ? context.l10n.reader_cancel_editing
                        : context.l10n.reader_edit_text,
                    onTap: _toggleEdit,
                  ),
                if (hasSave)
                  _HeadIcon(
                    icon: widget.saved ? Icons.bookmark_added : Icons.bookmark_border,
                    color: widget.saved ? c.teal : c.gold,
                    tooltip:
                        widget.saved
                            ? context.l10n.grammar_saved
                            : context.l10n.reader_save_story,
                    onTap: widget.saved ? null : widget.onSave,
                  ),
                if (hasEdit || hasSave) const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: autoDir(widget.title),
                    style: TextStyle(
                        color: c.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (!_editing) ...[
              // ── جستجو ──
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: c.cardBorder),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(color: c.ink, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: context.l10n.reader_search_placeholder,
                          hintStyle: TextStyle(
                              color: c.inkSoft.withOpacity(0.6), fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (q.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(_searchCtrl.clear),
                        child: Icon(Icons.close, size: 16, color: c.inkSoft),
                      )
                    else
                      Icon(Icons.search, size: 18, color: c.inkSoft),
                  ],
                ),
              ),
              if (q.isNotEmpty) ...[
                const SizedBox(height: 6),
                if (hits.isEmpty)
                  Text(context.l10n.reader_nothing_found,
                      style: TextStyle(color: c.inkSoft, fontSize: 12))
                else ...[
                  Text(context.l10n.reader_n_results('${hits.length}'),
                      style: TextStyle(color: c.inkSoft, fontSize: 11)),
                  for (final h in hits)
                    GestureDetector(
                      onTap: () => _jumpTo(h),
                      child: Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: c.paper,
                          border: Border.all(color: c.cardBorder),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          h.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: autoDir(h.text),
                          style: TextStyle(color: c.ink, fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ],
              const SizedBox(height: 12),

              // ── نمایشِ ترجمه ──
              Text(context.l10n.reader_translation_display,
                  style: TextStyle(color: c.inkSoft, fontSize: 13)),
              const SizedBox(height: 6),
              // از راست به چپ: جمله به جمله ← پاراگراف به پاراگراف ← هیچ
              // (جهتِ فیزیکی ثابت، مستقل از زبانِ برنامه)
              Directionality(
                textDirection: TextDirection.rtl,
                child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in [
                    [2, context.l10n.reader_sentence_by_sentence],
                    [1, context.l10n.reader_paragraph_by_paragraph],
                    [0, context.l10n.reader_none],
                  ])
                    HopeChoiceChip(
                      label: m[1] as String,
                      active: _mode == m[0],
                      activeBorder: c.teal,
                      activeFill: c.teal,
                      activeText: Colors.white,
                      onTap: () => _setMode(m[0] as int),
                    ),
                ],
              ),
              ),
              if (widget.audioBar != null) ...[
                const SizedBox(height: 12),
                widget.audioBar!,
              ],
              const SizedBox(height: 12),
              ..._body(c, tp, paras, audio),
            ] else
              _editBox(c),

            if (widget.onNotesChanged != null && !_editing) ..._notes(c),
          ],
        ),
      ),
    ),
    );
  }

  Widget _editBox(AppThemeColorsExt c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.reader_edit_hint,
          style: TextStyle(color: c.inkSoft, fontSize: 12),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _editCtrl,
          minLines: 8,
          maxLines: 16,
          textDirection: autoDir(_editCtrl.text),
          style: TextStyle(color: c.ink, fontSize: 13, height: 1.7),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: c.cardBorder),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _applyEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.gold,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(context.l10n.reader_apply_edit,
                      style: TextStyle(
                          color: c.headerTo,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _toggleEdit,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  border: Border.all(color: c.cardBorder),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(context.l10n.cancel_button,
                    style: TextStyle(color: c.ink, fontSize: 13)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _notes(AppThemeColorsExt c) => [
        const SizedBox(height: 14),
        Divider(color: c.cardBorder, height: 1),
        const SizedBox(height: 12),
        Text(context.l10n.reader_notes_title,
            style: TextStyle(
                color: c.ink, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: _notesCtrl,
          onChanged: _onNotes,
          minLines: 4,
          maxLines: 12,
          textDirection: autoDir(_notesCtrl.text),
          style: TextStyle(color: c.ink, fontSize: 13, height: 1.7),
          decoration: InputDecoration(
            hintText: context.l10n.reader_notes_placeholder,
            hintStyle:
                TextStyle(color: c.inkSoft.withOpacity(0.6), fontSize: 13),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: c.cardBorder),
            ),
          ),
        ),
      ];

  // ───────────── بدنه ─────────────
  List<Widget> _body(
      AppThemeColorsExt c, TargetTextPrefs tp, List<_P> paras, StoryAudioController? audio) {
    final boldText =
        tp.bold == TargetBoldMode.both || tp.bold == TargetBoldMode.text;
    final out = <Widget>[];
    for (var pi = 0; pi < paras.length; pi++) {
      final p = paras[pi];
      final key = _pk.putIfAbsent(pi, () => GlobalKey());
      final rows = <Widget>[];

      if (_mode == 2) {
        for (var si = 0; si < p.sents.length; si++) {
          final gi = p.firstGi + si;
          rows.add(_unit(
            c, tp,
            src: p.sents[si],
            id: '${widget.storyId}-s$gi',
            active: (audio != null && audio.activeIndex == gi) ||
                _flashGi == gi,
            seekTo: gi,
            audio: audio,
            boldText: boldText,
            showTr: true,
            paraIdx: null,
          ));
        }
      } else {
        final last = p.firstGi + p.sents.length;
        final act = (audio != null &&
                audio.activeIndex >= p.firstGi &&
                audio.activeIndex < last) ||
            (_flashGi >= p.firstGi && _flashGi < last);
        rows.add(_unit(
          c, tp,
          src: p.text,
          id: '${widget.storyId}-p$pi',
          active: act,
          seekTo: p.firstGi,
          audio: audio,
          boldText: boldText,
          showTr: _mode == 1,
          paraIdx: pi,
        ));
      }

      out.add(Padding(
        key: key,
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      ));
    }
    return out;
  }

  /// یک جمله (یا پاراگراف) + ترجمه‌هایش
  Widget _unit(
    AppThemeColorsExt c,
    TargetTextPrefs tp, {
    required String src,
    required String id,
    required bool active,
    required int seekTo,
    required StoryAudioController? audio,
    required bool boldText,
    required bool showTr,
    required int? paraIdx,
  }) {
    final dir = autoDir(src);
    final rtl = dir == TextDirection.rtl;
    return SyncAnchor(
      code: widget.langCode,
      id: id,
      child: Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: active ? c.gold.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Align(
                  alignment: rtl ? Alignment.centerRight : Alignment.centerLeft,
                  child: SelectableSyncText(
                    code: widget.langCode,
                    id: id,
                    text: src,
                    sentence: src,
                    style: TextStyle(
                      color: c.ink,
                      fontSize: 15 * tp.scaleFactor,
                      height: 1.9,
                      fontWeight: boldText ? FontWeight.w700 : FontWeight.w400,
                    ),
                    textDirection: dir,
                    textAlign: rtl ? TextAlign.right : TextAlign.left,
                  ),
                ),
              ),
              if (audio != null)
                InkWell(
                  onTap: () => audio.setActiveLine(seekTo),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.my_location, size: 16, color: c.teal),
                  ),
                ),
              NeuralPathButton(
                onTap: () => showNeuralPath(
                  context,
                  word: src,
                  langCode: widget.langCode,
                ),
              ),
              SyncSpeakButton(
                code: widget.langCode,
                id: id,
                text: src,
                color: c.gold,
                size: 20,
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
          if (showTr)
            for (final lang in _langs) _trRow(c, tp, lang, src, id, paraIdx),
        ],
      ),
    ),
    );
  }

  Widget _trRow(
      AppThemeColorsExt c, TargetTextPrefs tp, String lang, String src, String id, int? paraIdx) {
    final key = _k(lang, src);
    final t = _tr[key];
    final failed = _failed.contains(key);
    final busy = _retrying.contains(key);
    final dir = dirFor(lang);
    final rtl = dir == TextDirection.rtl;
    final boldTr =
        tp.bold == TargetBoldMode.both || tp.bold == TargetBoldMode.translation;

    final tag = Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: c.paperDark,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: c.cardBorder, width: 0.6),
        ),
        child: Text(
          lang.toUpperCase(),
          style: TextStyle(
            color: c.gold,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );

    // Builder: contextِ زیرِ SyncPlayScope لازم است (گزارشِ ترجمه به پلیر)
    return Builder(builder: (bctx) {
      if (t != null) syncReportTranslation(bctx, ref, lang, id, t);
      return SyncAnchor(
        code: lang,
        id: id,
        child: Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              textDirection: dir,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tag,
                const SizedBox(width: 10),
                Expanded(
                  child: t != null
                      ? Align(
                          alignment: rtl
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: SelectableSyncText(
                            code: lang,
                            id: id,
                            text: t,
                            sentence: t,
                            style: TextStyle(
                              color: _kTrColor,
                              fontSize: 15 * tp.scaleFactor,
                              height: 1.7,
                              fontWeight:
                                  boldTr ? FontWeight.w600 : FontWeight.w400,
                            ),
                            textDirection: dir,
                            textAlign: rtl ? TextAlign.right : TextAlign.left,
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            failed
                                ? context.l10n.reader_not_translated_retry
                                : context.l10n.grammar_translating,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              color: failed ? c.rose : c.inkSoft,
                              fontSize: 12,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          // از راست به چپ: 🔊 ← 🧬 ← رفرش
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              onTap: busy ? null : () => _retry(lang, src, paraIdx: paraIdx),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: busy
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.6, color: c.inkSoft),
                      )
                    : Icon(Icons.refresh,
                        size: 16, color: c.inkSoft.withOpacity(0.7)),
              ),
            ),
          ),
          if (t != null)
            NeuralPathButton(
              onTap: () => showNeuralPath(
                context,
                word: t,
                langCode: lang,
                baseText: src,
              ),
            ),
          if (t != null)
            SyncSpeakButton(
              code: lang,
              id: id,
              text: t,
              color: c.gold,
              size: 16,
              padding: const EdgeInsets.all(5),
            ),
        ],
      ),
        ),
      );
    });
  }
}

class _HeadIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;
  const _HeadIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
