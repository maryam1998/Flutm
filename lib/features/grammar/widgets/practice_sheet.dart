import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/ai_settings_provider.dart';
import '../../../core/providers/language_selection_provider.dart';
import '../../../core/providers/translation_provider.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/widgets/ai_answer_tools.dart';
import '../../../core/widgets/selection_card.dart' show SelectableSyncText;
import '../../../core/translate/translation_service.dart';
import '../../tabs/_hope_panel.dart' show MiniMarkdown, autoDir;

/// پنل تمرین گرامر — همیشه visible، بین محتوا و پلیر
/// کشیدنی: هدر رو بکش بالا/پایین → ارتفاع تغییر می‌کنه
class PracticeSheet extends StatefulWidget {
  const PracticeSheet({super.key});

  @override
  State<PracticeSheet> createState() => _PracticeSheetState();
}

class _PracticeSheetState extends State<PracticeSheet> {
  // ارتفاع: closed = فقط هدر | open = نصف صفحه
  bool _open = false;
  double _headerH = 52;
  double _viewportH = 800;
  double? _customHeight;

  // drag
  double _dragStartY = 0;
  double _dragStartHeight = 0;
  bool _dragMoved = false;
  double? _liveHeight;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewportH = MediaQuery.of(context).size.height;
  }

  double get _snapHeight {
    if (!_open) return _headerH;
    return _customHeight ?? _viewportH * 0.55;
  }

  double get _currentHeight => _liveHeight ?? _snapHeight;

  void _onDragStart(DragStartDetails d) {
    _dragStartY = d.globalPosition.dy;
    _dragStartHeight = _snapHeight;
    _dragMoved = false;
    setState(() => _liveHeight = _snapHeight);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_liveHeight == null) return;
    final delta = _dragStartY - d.globalPosition.dy;
    if (delta.abs() > 4) _dragMoved = true;
    final next = (_dragStartHeight + delta)
        .clamp(_headerH, _viewportH * 0.92)
        .toDouble();
    setState(() => _liveHeight = next);
  }

  void _onDragEnd(DragEndDetails d) {
    if (_liveHeight == null) return;
    final finalH = _liveHeight!;
    setState(() {
      _liveHeight = null;
      if (!_dragMoved) {
        _open = !_open;
        _customHeight = null;
      } else if (finalH <= _headerH + 10) {
        _open = false;
        _customHeight = null;
      } else {
        _open = true;
        _customHeight = finalH;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final currentH = _currentHeight;

    return AnimatedContainer(
      duration: _liveHeight == null
          ? const Duration(milliseconds: 240)
          : Duration.zero,
      curve: Curves.easeOutCubic,
      height: currentH,
      decoration: BoxDecoration(
        color: c.paperDark,
        border: Border(
          top: BorderSide(color: c.goldSoft, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: c.ink.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRect(
        child: Column(
          children: [
            // ═══ هدر — کشیدنی ═══
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: _onDragStart,
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              onTap: () => setState(() {
                _open = !_open;
                _customHeight = null;
              }),
              child: Container(
                height: _headerH,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.headerFrom, c.headerTo],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // دستگیره‌ی بالا (بصری)
                    Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.psychology_outlined,
                      size: 18,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'تمرین جمله‌سازی و گرامر',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(
                      _open
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      size: 20,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),

            // ═══ محتوا — وقتی بازه ═══
            if (_open && currentH > _headerH + 10)
              const Expanded(child: _GrammarPracticeContent()),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// چتِ معلمِ گرامر با هوش مصنوعی — پورتِ askGrammarTeacher + sendChat وب (Hope)
// ═══════════════════════════════════════════════════════════════════
class _ChatMsg {
  final bool isUser;
  final String text;
  const _ChatMsg(this.isUser, this.text);
}

class _GrammarPracticeContent extends ConsumerStatefulWidget {
  const _GrammarPracticeContent();

  @override
  ConsumerState<_GrammarPracticeContent> createState() =>
      _GrammarPracticeContentState();
}

class _GrammarPracticeContentState
    extends ConsumerState<_GrammarPracticeContent> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMsg> _msgs = [];
  bool _loading = false;
  String _error = '';
  String? _chatLang; // زبانِ تمرین (پیش‌فرض: اولین زبانِ مقصد)

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  static String _stripThink(String t) => t
      .replaceAll(RegExp(r'<think(ing)?>[\s\S]*?</think(ing)?>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<think(ing)?>[\s\S]*$', caseSensitive: false), '')
      .trim();

  static final RegExp _reasoningRe = RegExp(
      r"(thinking process|here'?s a thinking|analy[sz]e the (request|text|input)|\bconstraint\s*:|the user wants me to|let me (read|think|analy[sz]e|re-?read)|^\s*okay,? (so|let'?s|the user))",
      caseSensitive: false,
      multiLine: true);

  String _prompt({
    required String sentence,
    required String langCode,
    required String nativeCode,
    required List<String> targets,
    required List<_ChatMsg> history,
  }) {
    final label = englishLangName(nativeCode);
    final langLabel = englishLangName(langCode);
    final others = targets
        .where((c) => c != langCode && c != nativeCode)
        .map(englishLangName)
        .join(', ');
    final otherLangs = others.isEmpty ? 'None' : others;
    final recent = history.length > 8
        ? history.sublist(history.length - 8)
        : history;
    final historyText = recent.isEmpty
        ? 'None'
        : recent
            .map((m) => '${m.isUser ? 'Learner' : 'Teacher'}: ${m.text}')
            .join('\n');
    return "You are a friendly, knowledgeable AI chat assistant inside a language-learning app — talk with the learner the same natural way any general-purpose AI chat assistant would. You're not limited to grammar; you can help with anything they bring up. On top of that, you're great at $langLabel practice.\n\n"
        "Learner's native language: $label. Language they're currently practicing: $langLabel. Other languages they study: $otherLangs.\n\n"
        "Recent conversation:\n$historyText\n\n"
        "Learner just wrote: \"$sentence\"\n\n"
        "How to respond:\n"
        "- If this reads like a sentence they wrote in $langLabel to practice: check it warmly. Say if it's correct or not, give the corrected version if needed, explain briefly and simply why (in $label) — especially if the mistake looks like it came from mixing $label and $langLabel structure — then add one more example sentence in $langLabel with a $label translation.\n"
        "- Otherwise, just answer naturally, like a normal, capable AI assistant would — any topic, any question, no restriction. Weave in an example phrase in $langLabel with translation only if it genuinely fits.\n"
        "- Default to $langLabel for any language-practice content (translated into $label); only bring in $otherLangs or English if the learner specifically asks about them or it clearly helps.\n"
        "- CRITICAL: this learner is practicing $langLabel, NOT English. Every example sentence in your reply MUST be in $langLabel (unless $langLabel literally is English, or the learner explicitly asked about English/another language). Never default to English examples just out of habit — that is a mistake.\n"
        "- Write in $label. Keep sentences in both languages clean and well-ordered, never jumbled. Keep the reply clear, well-organized, and not too long.";
  }

  Future<void> _ask(String sentence, List<_ChatMsg> history) async {
    final sel = ref.read(languageSelectionProvider);
    final langCode = _chatLang ?? sel.primaryTarget ?? 'en';
    setState(() {
      _loading = true;
      _error = '';
    });
    _scrollDown();
    try {
      final svc = ref.read(translationServiceProvider);
      final ai = ref.read(aiSettingsProvider);
      final raw = await svc.callAI(
        prompt: _prompt(
          sentence: sentence,
          langCode: langCode,
          nativeCode: sel.native,
          targets: sel.targets,
          history: history,
        ),
        maxTokens: 700,
        retries: 1,
        timeoutMs: 45000,
        settings: ai,
      );
      final text = _stripThink(raw);
      if (text.isEmpty || _reasoningRe.hasMatch(text)) {
        throw Exception('empty');
      }
      if (!mounted) return;
      setState(() => _msgs.add(_ChatMsg(false, text)));
    } catch (e) {
      if (!mounted) return;
      final m = e.toString().replaceFirst(RegExp(r'^.*ai-backend-error:\s*'), '');
      setState(() => _error = (m.isEmpty || m.startsWith('Exception'))
          ? 'هوش مصنوعی جواب نداد. اینترنتت رو چک کن و دوباره امتحان کن.'
          : (m.contains("isn't responding")
              ? 'هوش مصنوعی جواب نداد. اینترنتت رو چک کن و دوباره امتحان کن.'
              : m));
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollDown();
    }
  }

  Future<void> _send() async {
    final sentence = _ctrl.text.trim();
    if (sentence.isEmpty || _loading) return;
    final history = List<_ChatMsg>.from(_msgs);
    _ctrl.clear();
    setState(() => _msgs.add(_ChatMsg(true, sentence)));
    await _ask(sentence, history);
  }

  Future<void> _retry() async {
    if (_msgs.isEmpty || !_msgs.last.isUser || _loading) return;
    final last = _msgs.last;
    await _ask(last.text, _msgs.sublist(0, _msgs.length - 1));
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final sel = ref.watch(languageSelectionProvider);
    final langCode = _chatLang ?? sel.primaryTarget ?? 'en';
    final langName = englishLangName(langCode);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: c.paper,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Text(
                'یه جمله به $langName بنویس؛ اگر غلط بود اصلاحش می‌کنم و کلمه‌به‌کلمه '
                'گرامرش رو توضیح می‌دم. یا هر سوال گرامری که داری — چه درباره‌ی این جمله، '
                'چه یه سوال کاملاً جدا — همین‌جا بپرس تا مثل یه معلم زبان جواب بدم.',
                style: TextStyle(color: c.inkSoft, fontSize: 12, height: 1.7),
                textAlign: TextAlign.right,
              ),
            ),
            if (sel.targets.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final t in sel.targets)
                        ChoiceChip(
                          label: Text(englishLangName(t),
                              style: const TextStyle(fontSize: 11.5)),
                          selected: t == langCode,
                          onSelected: (_) => setState(() => _chatLang = t),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                children: [
                  for (final m in _msgs) _bubble(c, m),
                  if (_loading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: c.teal),
                          ),
                          const SizedBox(width: 8),
                          Text('در حال نوشتن...',
                              style:
                                  TextStyle(color: c.inkSoft, fontSize: 12)),
                        ],
                      ),
                    ),
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(_error,
                                style: TextStyle(color: c.rose, fontSize: 12)),
                          ),
                          if (_msgs.isNotEmpty && _msgs.last.isUser)
                            TextButton.icon(
                              onPressed: _loading ? null : _retry,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('تلاش دوباره',
                                  style: TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: c.teal, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(6),
                child: Row(
                  textDirection: TextDirection.rtl, // دکمه‌ی ارسال سمتِ راست
                  children: [
                    Material(
                      color: _loading ? c.inkSoft : c.teal,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _loading ? null : _send,
                        child: const Padding(
                          padding: EdgeInsets.all(9),
                          child: Icon(Icons.send_rounded,
                              size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        minLines: 1,
                        maxLines: 4,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(color: c.ink, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'جمله‌ت رو بنویس یا سوال‌ت رو بپرس...',
                          hintStyle: TextStyle(
                            color: c.inkSoft.withOpacity(0.6),
                            fontSize: 11.5,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(AppThemeColorsExt c, _ChatMsg m) {
    return Align(
      alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _bubbleBox(c, m),
        ],
      ),
    );
  }

  Widget _bubbleBox(AppThemeColorsExt c, _ChatMsg m) {
    final chatCode =
        _chatLang ?? ref.read(languageSelectionProvider).primaryTarget ?? 'en';
    return Align(
      alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.92),
        decoration: BoxDecoration(
          color: m.isUser ? c.paper : c.goldSoft,
          border: Border.all(color: c.cardBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: m.isUser
            ? SelectableSyncText(
                code: chatCode,
                id: 'practice-user-${m.text.hashCode}',
                text: m.text,
                autoLang: true,
                textDirection: autoDir(m.text),
                style: TextStyle(color: c.ink, fontSize: 13, height: 1.6),
              )
            // 🧬 🔊 داخلِ کادر، بالا سمتِ راست
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    textDirection: TextDirection.ltr,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: MiniMarkdown(text: m.text, code: chatCode)),
                      AiBubbleActions(text: m.text),
                    ],
                  ),
                  AiAnswerTools(text: m.text),
                ],
              ),
      ),
    );
  }
}
