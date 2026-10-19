import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../app.dart';
import '../../core/constants/supported_languages.dart' show langDisplayName;
import '../../core/models/grammar_note.dart';
import '../../core/models/saved_word.dart';
import '../../core/providers/ai_settings_provider.dart';
import '../../core/providers/language_selection_provider.dart';
import '../../core/providers/translation_provider.dart';
import '../../core/translate/translation_service.dart'
    show englishLangName, looksLikeGuardOutput;
import '../../core/providers/reader_providers.dart';
import '../../core/ai/ai_gateway.dart';
import '../../core/theme/app_theme_colors.dart';
import '../../core/utils/html_entities.dart';
import '../../core/widgets/ai_answer_tools.dart';
import '../../core/widgets/selection_card.dart' show SelectableSyncText;
import '_hope_panel.dart';

/// تب «گرامر» — هم‌شکل GrammarPanel در Hope.
/// حالتِ خالی: عنوان + توضیح + «هنوز نکته‌ی گرامری‌ای ذخیره نکردی...»
class GrammarTab extends ConsumerStatefulWidget {
  const GrammarTab({super.key});

  @override
  ConsumerState<GrammarTab> createState() => _GrammarTabState();
}

class _GrammarTabState extends ConsumerState<GrammarTab> {
  String? _expanded;
  bool _selectMode = false;
  final Set<String> _selected = {};

  static String _two(int n) => n.toString().padLeft(2, '0');
  // کلیدِ گروه‌بندی/مرتب‌سازی (مستقل از زبان)
  static String _dayKey(DateTime d) =>
      '${d.year}/${_two(d.month)}/${_two(d.day)}';

  // برچسب‌های نمایشی بر اساس زبانِ رابط کاربری (مثل Hope: «Sun, 18 Oct 2026» و «07:52 AM»)
  String _dayLabel(DateTime d) {
    final loc = Localizations.localeOf(context).toString();
    try {
      return DateFormat.yMMMEd(loc).format(d);
    } catch (_) {
      return _dayKey(d);
    }
  }

  String _timeLabel(DateTime d) {
    final loc = Localizations.localeOf(context).toString();
    try {
      return DateFormat.jm(loc).format(d);
    } catch (_) {
      return '${_two(d.hour)}:${_two(d.minute)}';
    }
  }

  void _exitSelect() => setState(() {
        _selectMode = false;
        _selected.clear();
      });

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final n = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(context.l10n.grammar_confirm_delete_notes('$n')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancel_button),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.grammar_delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final notifier = ref.read(grammarNotesProvider.notifier);
    for (final id in _selected.toList()) {
      notifier.removeNote(id);
    }
    _exitSelect();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final notes = ref.watch(grammarNotesProvider);
    final savedWords = ref.watch(savedWordsProvider);

    // گروه‌بندی بر اساس روز (جدیدترین اول)
    final groups = <String, List<GrammarNote>>{};
    for (final n in notes) {
      groups.putIfAbsent(_dayKey(n.savedAt), () => []).add(n);
    }
    final labels = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return HopePanel(
      contentDirection: uiContentDirection(context),
      title: context.l10n.grammar_title,
      intro: context.l10n.grammar_intro,
      children: [
        if (notes.isEmpty)
          HopeEmptyText(context.l10n.grammar_empty_notes),
        if (notes.isNotEmpty && !_selectMode)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: HopeTextAction(
              icon: Icons.checklist_rounded,
              label: context.l10n.grammar_select_delete,
              color: c.rose,
              onTap: () => setState(() => _selectMode = true),
            ),
          ),
        if (notes.isNotEmpty && _selectMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: c.goldSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  _selected.isNotEmpty
                      ? context.l10n.grammar_n_selected('${_selected.length}')
                      : context.l10n.grammar_select_items,
                  style: TextStyle(
                    color: c.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HopeTextAction(
                      icon: Icons.checklist_rounded,
                      label: context.l10n.select_all,
                      color: c.teal,
                      onTap: () => setState(() {
                        _selected
                          ..clear()
                          ..addAll(notes.map((n) => n.id));
                      }),
                    ),
                    const SizedBox(width: 12),
                    HopeTextAction(
                      icon: Icons.delete_outline,
                      label: context.l10n.grammar_delete,
                      color: _selected.isEmpty
                          ? c.rose.withOpacity(0.5)
                          : c.rose,
                      onTap: _selected.isEmpty ? null : _deleteSelected,
                    ),
                    const SizedBox(width: 12),
                    HopeTextAction(
                      label: context.l10n.cancel_button,
                      color: c.inkSoft,
                      onTap: _exitSelect,
                    ),
                  ],
                ),
              ],
            ),
          ),
        for (final label in labels)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Row(
                  children: [
                    if (_selectMode)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            final ids = groups[label]!.map((n) => n.id);
                            final all = ids.every(_selected.contains);
                            if (all) {
                              _selected.removeAll(ids);
                            } else {
                              _selected.addAll(ids);
                            }
                          }),
                          child: Icon(
                            groups[label]!
                                    .every((n) => _selected.contains(n.id))
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            size: 18,
                            color: groups[label]!
                                    .every((n) => _selected.contains(n.id))
                                ? c.gold
                                : c.inkSoft,
                          ),
                        ),
                      ),
                    Text(
                      _dayLabel(groups[label]!.first.savedAt),
                      style: TextStyle(
                        color: c.inkSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              for (final n in groups[label]!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _NoteCard(
                    note: n,
                    timeLabel: _timeLabel(n.savedAt),
                    open: _expanded == n.id && !_selectMode,
                    selectMode: _selectMode,
                    selected: _selected.contains(n.id),
                    wordSaved: n.word.trim().isNotEmpty &&
                        savedWords.any((w) =>
                            w.langCode == n.langCode &&
                            normWord(w.word) == normWord(n.word)),
                    onTap: () => setState(() {
                      if (_selectMode) {
                        if (!_selected.add(n.id)) _selected.remove(n.id);
                      } else {
                        _expanded = _expanded == n.id ? null : n.id;
                      }
                    }),
                    onToggleSaved: () {
                      if (n.word.trim().isEmpty) return;
                      ref.read(savedWordsProvider.notifier).toggleSave(
                            SavedWord(
                              word: n.word,
                              langCode: n.langCode,
                              meaning: '',
                              savedAt: DateTime.now(),
                            ),
                          );
                    },
                    onDelete: () =>
                        ref.read(grammarNotesProvider.notifier).removeNote(n.id),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _NoteCard extends ConsumerStatefulWidget {
  final GrammarNote note;
  final String timeLabel;
  final bool open;
  final bool selectMode;
  final bool selected;
  final bool wordSaved;
  final VoidCallback onTap;
  final VoidCallback onToggleSaved;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.timeLabel,
    required this.open,
    required this.selectMode,
    required this.selected,
    required this.wordSaved,
    required this.onTap,
    required this.onToggleSaved,
    required this.onDelete,
  });

  @override
  ConsumerState<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends ConsumerState<_NoteCard> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String _error = '';
  String _failedQ = ''; // آخرین پرسشی که جوابش نیامد (برای «تلاش دوباره»)
  int? _failedIndex;
  int? _editIndex; // اگر null نباشد، ارسال = ویرایشِ همان پرسش


  final _editCtrl = TextEditingController();

  /// زبانِ متنِ اصلیِ یادداشت: تصحیحِ مکالمه (بدون لغت) به زبانِ تمرین است،
  /// توضیحِ لغت به زبانِ مادری.
  String? get _mdLang =>
      widget.note.word.trim().isEmpty ? widget.note.langCode : null;

  /// ویرایشِ درجا (مثل تبِ مکالمه): پرسش در همان جا به کادرِ ویرایش تبدیل
  /// می‌شود؛ چیزی حذف نمی‌شود تا «ذخیره و ارسالِ مجدد» زده شود.
  void _startEdit(int i, String question) {
    if (_loading) return;
    setState(() {
      _editIndex = i;
      _editCtrl.text = question;
      _editCtrl.selection = TextSelection.collapsed(offset: question.length);
    });
  }

  void _cancelEdit() => setState(() => _editIndex = null);

  void _saveEdit() {
    final i = _editIndex;
    final q = _editCtrl.text.trim();
    if (i == null || q.isEmpty || _loading) return;
    setState(() => _editIndex = null);
    _ask(q, i);
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  static String _stripThink(String t) => t
      .replaceAll(
          RegExp(r'<think(ing)?>[\s\S]*?</think(ing)?>', caseSensitive: false),
          '')
      .replaceAll(RegExp(r'<think(ing)?>[\s\S]*$', caseSensitive: false), '')
      .trim();

  static final RegExp _reasoningRe = RegExp(
      r"(thinking process|here'?s a thinking|analy[sz]e the (request|text|input)|\bconstraint\s*:|the user wants me to|let me (read|think|analy[sz]e|re-?read)|^\s*okay,? (so|let'?s|the user))",
      caseSensitive: false,
      multiLine: true);

  /// پورتِ askGrammarTeacher در Hope — با تاریخچه‌ی خودِ یادداشت
  String _prompt(String question, {int? upTo}) {
    final note = widget.note;
    final sel = ref.read(languageSelectionProvider);
    final label = englishLangName(sel.native);
    final langLabel = englishLangName(note.langCode);
    final others = sel.targets
        .where((c) => c != note.langCode && c != sel.native)
        .map(englishLangName)
        .join(', ');
    final otherLangs = others.isEmpty ? 'None' : others;

    // توکن‌ها: هر پیام کوتاه می‌شود، پاسخ‌های خراب (گارد/خالی) اصلاً نمی‌روند،
    // و فقط یادداشتِ اصلی + ۲ نوبتِ آخر فرستاده می‌شود.
    String clip(String t, int n) {
      final x = t.replaceAll(RegExp(r'\s+'), ' ').trim();
      return x.length > n ? '${x.substring(0, n)}…' : x;
    }

    final base = upTo == null ? note.thread : note.thread.take(upTo).toList();
    final okThread = base
        .where((t) => t.answer.trim().isNotEmpty && !looksLikeGuardOutput(t.answer))
        .toList();
    final lastTurns =
        okThread.length > 2 ? okThread.sublist(okThread.length - 2) : okThread;
    final history = <String>[
      'Note: ${clip(note.sentence.isNotEmpty ? note.sentence : note.word, 200)}',
      'Explanation: ${clip(note.markdown, 500)}',
      for (final t in lastTurns) ...[
        'Learner: ${clip(t.question, 200)}',
        'Teacher: ${clip(t.answer, 400)}',
      ],
    ];

    return "You are a friendly $langLabel tutor in a language-learning app. "
        "Learner's native language: $label. Practicing: $langLabel. Also studies: $otherLangs.\n\n"
        "Context:\n${history.join('\n')}\n\n"
        "Learner asks: \"${clip(question, 400)}\"\n\n"
        "Answer this follow-up directly in $label, without redoing the full breakdown. "
        "Example sentences must be in $langLabel, each with a short $label translation. "
        "Be concise (under ~150 words), plain text.";
  }

  /// [index] = ایندکسِ پرسشی که ویرایش/رفرش می‌شود (پاسخ‌های بعدش حذف می‌شوند)؛
  /// null = پرسشِ جدید.
  Future<void> _ask([String? retryQuestion, int? index]) async {
    final question = (retryQuestion ?? _ctrl.text).trim();
    if (question.isEmpty || _loading) return;
    final target = retryQuestion == null ? null : index;
    if (retryQuestion == null) _ctrl.clear();
    _editIndex = null;
    setState(() {
      _loading = true;
      _error = '';
    });
    final noteId = widget.note.id;
    final notifier = ref.read(grammarNotesProvider.notifier);
    try {
      final svc = ref.read(translationServiceProvider);
      final ai = ref.read(aiSettingsProvider);
      final text = await aiGenerate(
        svc: svc,
        settings: ai,
        prompt: _prompt(question, upTo: target),
        maxTokens: 600,
        retries: 1,
        timeoutMs: 45000,
      );
      // جوابِ خالی/خراب (گارد، استدلال، پژواکِ پرامپت) → خطا؛ چیزی ذخیره نمی‌شود
      if (text.trim().isEmpty || aiOutputProblem(text) != null) {
        throw Exception('bad ai output');
      }
      final item = GrammarThreadItem(question: question, answer: text);
      if (target != null) {
        notifier.replaceThreadFrom(noteId, target, item);
      } else {
        notifier.appendThread(noteId, item);
      }
      if (!mounted) return;
      setState(() {
        _failedQ = '';
        _failedIndex = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failedQ = question;
        _failedIndex = target;
        _error = context.l10n.speaking_ai_no_response;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final note = widget.note;
    final open = widget.open;
    final selectMode = widget.selectMode;
    final selected = widget.selected;
    final title = note.word.trim().isEmpty
        ? context.l10n.grammar_conversation_correction
        : note.word;
    final canAsk = _ctrl.text.trim().isNotEmpty && !_loading;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? c.gold : c.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: widget.onTap,
            child: Row(
              children: [
                if (selectMode)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: Icon(
                      selected ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 18,
                      color: selected ? c.gold : c.inkSoft,
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        textDirection: autoDir(title),
                        style: TextStyle(
                          color: c.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${langDisplayName(context, note.langCode)} · ${widget.timeLabel}',
                        style: TextStyle(color: c.inkSoft, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (!selectMode) ...[
                  if (note.word.trim().isNotEmpty)
                    GestureDetector(
                      onTap: widget.onToggleSaved,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          widget.wordSaved
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          size: 18,
                          color: widget.wordSaved ? c.gold : c.inkSoft,
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: widget.onDelete,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 18, color: c.inkSoft),
                    ),
                  ),
                  Icon(
                    open ? Icons.keyboard_arrow_down : Icons.chevron_left,
                    size: 20,
                    color: c.inkSoft,
                  ),
                ],
              ],
            ),
          ),
          if (open)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.cardBorder)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 🧬 🔊 بالا سمتِ راست + چیپ‌های ترجمه — هم‌شکلِ جوابِ تبِ مکالمه
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.goldSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          textDirection: TextDirection.ltr,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: MiniMarkdown(
                                    code: _mdLang ?? note.langCode,
                                    text: decodeHtmlEntities(note.markdown))),
                            AiBubbleActions(
                                text: note.markdown, sourceLang: _mdLang),
                          ],
                        ),
                        AiAnswerTools(text: note.markdown, sourceLang: _mdLang),
                      ],
                    ),
                  ),

                  // ═══ پرسش‌وپاسخ‌های ذخیره‌شده‌ی همین یادداشت ═══
                  for (var ti = 0; ti < note.thread.length; ti++)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // پرسشِ کاربر + «ویرایش» (درجا) — یا کادرِ ویرایش
                          if (_editIndex == ti)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: _editCtrl,
                                    autofocus: true,
                                    minLines: 1,
                                    maxLines: 6,
                                    onChanged: (_) => setState(() {}),
                                    style: TextStyle(
                                        color: c.ink, fontSize: 12.5),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 9),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        borderSide:
                                            BorderSide(color: c.teal),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                            color: c.teal, width: 1.5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    alignment: WrapAlignment.end,
                                    children: [
                                      OutlinedButton(
                                        onPressed: _cancelEdit,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: c.inkSoft,
                                          side: BorderSide(
                                              color: c.cardBorder),
                                          visualDensity:
                                              VisualDensity.compact,
                                        ),
                                        child: Text(
                                            context.l10n.speaking_cancel,
                                            style: const TextStyle(
                                                fontSize: 12)),
                                      ),
                                      FilledButton(
                                        onPressed:
                                            _editCtrl.text.trim().isEmpty
                                                ? null
                                                : _saveEdit,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: c.teal,
                                          visualDensity:
                                              VisualDensity.compact,
                                        ),
                                        child: Text(
                                            context.l10n.speaking_save_resend,
                                            style: const TextStyle(
                                                fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: SelectableSyncText(
                                      code: note.langCode,
                                      id: 'grammar-q-${note.hashCode}-$ti',
                                      text: note.thread[ti].question,
                                      autoLang: true,
                                      textDirection:
                                          autoDir(note.thread[ti].question),
                                      style: TextStyle(
                                        color: c.inkSoft,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  _MiniAction(
                                    icon: Icons.edit_outlined,
                                    label: context.l10n.grammar_edit,
                                    color: c.teal,
                                    onTap: _loading
                                        ? null
                                        : () => _startEdit(
                                            ti, note.thread[ti].question),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: c.goldSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            // 🧬 🔊 بالا سمتِ راست + چیپ‌های ترجمه، همه داخلِ کادر
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  textDirection: TextDirection.ltr,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                        child: MiniMarkdown(
                                            code: note.langCode,
                                            text: decodeHtmlEntities(
                                                note.thread[ti].answer))),
                                    AiBubbleActions(
                                        text: note.thread[ti].answer),
                                  ],
                                ),
                                AiAnswerTools(text: note.thread[ti].answer),
                              ],
                            ),
                          ),
                          // جوابِ AI: فقط «رفرش» (آخرین جواب)، بدون «ویرایش»
                          if (ti == note.thread.length - 1)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _MiniAction(
                                    icon: Icons.refresh,
                                    label: context.l10n.speaking_refresh,
                                    color: c.teal,
                                    onTap: _loading
                                        ? null
                                        : () => _ask(
                                            note.thread[ti].question, ti),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                  // ═══ کادرِ پرسش از همین یادداشت ═══
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: c.cardBorder)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            minLines: 1,
                            maxLines: 5,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            onChanged: (_) => setState(() {}),
                            style: TextStyle(color: c.ink, fontSize: 12.5),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText:
                                  context.l10n.grammar_note_ask_placeholder,
                              hintStyle:
                                  TextStyle(color: c.inkSoft, fontSize: 12),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 9),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: c.cardBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: c.gold),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Opacity(
                          opacity: canAsk || _loading ? 1 : 0.6,
                          child: Material(
                            color: c.gold,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: canAsk ? () => _ask() : null,
                              child: Container(
                                constraints: const BoxConstraints(
                                    minWidth: 48, minHeight: 36),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                alignment: Alignment.center,
                                child: _loading
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 1.8,
                                            color: Colors.white),
                                      )
                                    : Text(
                                        context.l10n.grammar_ask,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _error,
                              style: TextStyle(color: c.rose, fontSize: 11),
                            ),
                          ),
                          if (_failedQ.isNotEmpty)
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: _loading ? null : () => _ask(_failedQ, _failedIndex),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: c.teal,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.replay,
                                        size: 12, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      context.l10n.grammar_try_again,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


class _MiniAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final col = onTap == null ? color.withOpacity(0.4) : color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: col),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    color: col, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
