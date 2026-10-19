import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../app.dart';
import '../../core/constants/supported_languages.dart';
import '../../core/models/grammar_note.dart';
import '../../core/providers/ai_settings_provider.dart';
import '../../core/providers/language_selection_provider.dart';
import '../../core/providers/reader_providers.dart';
import '../../core/providers/translation_provider.dart';
import '../../core/storage/local_storage.dart';
import '../../core/theme/app_theme_colors.dart';
import '../../core/utils/html_entities.dart';
import '../../core/widgets/ai_answer_tools.dart';
import '../../core/widgets/selection_card.dart'
    show SelectableSyncText, SelectableRun;
import '_hope_panel.dart';

// ═══════════════════════════════════════════════════════════════════
// تب «تمرین مکالمه» — هم‌شکل SpeakingPractice.jsx در Hope
// عنوان + توضیح، انتخاب زبانِ تمرین، کادرِ چت (با پیامِ خوش‌آمدِ Jimmy)،
// نوارِ ورودیِ سبزآبی. گفتگو فقط روی همین گوشی ذخیره می‌شود.
// ═══════════════════════════════════════════════════════════════════

const String _kChatKey = 'zflut-speaking-chat-v1';
const String _kLangKey = 'zflut-speaking-lang-v1';
const String _kHistKey = 'zflut-speaking-history-v1';
const Color _kMistake = Color(0xFFC81E1E);
const Color _kCorrection = Color(0xFF166534);

class _Correction {
  final String original;
  final String corrected;
  final int oStart;
  final int oEnd;
  final int cStart;
  final int cEnd;

  const _Correction({
    required this.original,
    required this.corrected,
    required this.oStart,
    required this.oEnd,
    required this.cStart,
    required this.cEnd,
  });

  Map<String, dynamic> toJson() => {
        'original': original,
        'corrected': corrected,
        'oStart': oStart,
        'oEnd': oEnd,
        'cStart': cStart,
        'cEnd': cEnd,
      };

  factory _Correction.fromJson(Map<String, dynamic> j) => _Correction(
        original: (j['original'] ?? '').toString(),
        corrected: (j['corrected'] ?? '').toString(),
        oStart: (j['oStart'] as num?)?.toInt() ?? 0,
        oEnd: (j['oEnd'] as num?)?.toInt() ?? 0,
        cStart: (j['cStart'] as num?)?.toInt() ?? 0,
        cEnd: (j['cEnd'] as num?)?.toInt() ?? 0,
      );
}

class _Msg {
  final String role; // 'user' | 'ai'
  final String text;
  final List<_Correction> corrections;
  final bool savedToGrammar;
  final bool welcome; // پیامِ ثابتِ معرفیِ Jimmy — وارد تاریخچه نمی‌شود

  const _Msg({
    required this.role,
    required this.text,
    this.corrections = const [],
    this.savedToGrammar = false,
    this.welcome = false,
  });

  bool get isWelcome =>
      welcome || (role == 'ai' && text.startsWith("Hey there! I'm Jimmy"));

  _Msg copyWith({bool? savedToGrammar}) => _Msg(
        role: role,
        text: text,
        corrections: corrections,
        savedToGrammar: savedToGrammar ?? this.savedToGrammar,
        welcome: welcome,
      );

  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
        'corrections': corrections.map((c) => c.toJson()).toList(),
        'savedToGrammar': savedToGrammar,
        if (welcome) 'welcome': true,
      };

  factory _Msg.fromJson(Map<String, dynamic> j) {
    var text = (j['text'] ?? '').toString();
    var cs = <_Correction>[
      for (final e in (j['corrections'] as List? ?? const []))
        if (e is Map) _Correction.fromJson(Map<String, dynamic>.from(e)),
    ];
    // پیام‌های قدیمی ممکن است `&#39;` داشته باشند → رمزگشایی و جابه‌جاییِ آفست‌ها
    final dec = decodeHtmlEntities(text);
    if (dec != text) {
      text = dec;
      cs = _relocate(text, cs);
    }
    return _Msg(
      role: (j['role'] ?? 'ai').toString(),
      text: text,
      corrections: cs,
      savedToGrammar: j['savedToGrammar'] == true,
      welcome: j['welcome'] == true,
    );
  }
}

List<_Correction> _relocate(String text, List<_Correction> list) {
  final out = <_Correction>[];
  var cursor = 0;
  for (final c in list) {
    final o = decodeHtmlEntities(c.original);
    final k = decodeHtmlEntities(c.corrected);
    final oi = text.indexOf(o, cursor);
    final ki = oi < 0 ? -1 : text.indexOf(k, oi + o.length);
    if (oi < 0 || ki < 0) {
      out.add(_Correction(
          original: o, corrected: k, oStart: 0, oEnd: 0, cStart: 0, cEnd: 0));
      continue;
    }
    out.add(_Correction(
      original: o,
      corrected: k,
      oStart: oi,
      oEnd: oi + o.length,
      cStart: ki,
      cEnd: ki + k.length,
    ));
    cursor = ki + k.length;
  }
  return out;
}

class _Reply {
  final String text;
  final List<_Correction> corrections;
  const _Reply(this.text, this.corrections);
}

String _enName(String code) {
  for (final l in kSupportedLanguages) {
    if (l.code == code) return l.enLabel;
  }
  return code;
}

String _normalizeAiText(String t) => decodeHtmlEntities(t)
    .replaceAll('**', '')
    .replaceAll('*', '')
    .replaceAll(RegExp('[\u2018\u2019]'), "'")
    .replaceAll(RegExp('[\u201C\u201D]'), '"');

String _stripThink(String t) => t
    .replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '')
    .replaceAll(RegExp(r'<think>[\s\S]*$', caseSensitive: false), '')
    .trim();

/// خطوطِ «FIX: X => Y» بالای پاسخ را استخراج می‌کند و متنِ نمایشی را با
/// آفستِ دقیقِ اشتباه/پیشنهاد می‌سازد (پورتِ extractCorrections وب).
_Reply _extractCorrections(String reply) {
  final normalized = _normalizeAiText(reply);
  final lines = normalized.split('\n');
  final fixRe = RegExp(r'^FIX:\s*(.+?)\s*=>\s*(.+)$', caseSensitive: false);
  final raw = <List<String>>[];
  var i = 0;
  while (i < lines.length) {
    final m = fixRe.firstMatch(lines[i].trim());
    if (m == null) break;
    raw.add([m.group(1)!.trim(), m.group(2)!.trim()]);
    i++;
  }
  final body = lines.sublist(i).join('\n').replaceFirst(RegExp(r'^\s+'), '');
  if (raw.isEmpty) return _Reply(normalized, const []);

  var built = '';
  final out = <_Correction>[];
  for (var idx = 0; idx < raw.length; idx++) {
    final prefix = '${idx + 1}. Instead of "';
    const mid = '", you should say "';
    final oStart = built.length + prefix.length;
    final oEnd = oStart + raw[idx][0].length;
    final cStart = oEnd + mid.length;
    final cEnd = cStart + raw[idx][1].length;
    built += '$prefix${raw[idx][0]}$mid${raw[idx][1]}".\n';
    out.add(_Correction(
      original: raw[idx][0],
      corrected: raw[idx][1],
      oStart: oStart,
      oEnd: oEnd,
      cStart: cStart,
      cEnd: cEnd,
    ));
  }
  return _Reply('$built\n$body', out);
}

class _Seg {
  final String text;
  final int type; // 0 plain, 1 mistake, 2 correction
  const _Seg(this.text, this.type);
}

List<_Seg> _segments(String text, List<_Correction> corrections) {
  if (text.isEmpty || corrections.isEmpty) return [_Seg(text, 0)];
  final ranges = <List<int>>[]; // start, end, type
  for (final c in corrections) {
    if (c.oEnd > c.oStart) ranges.add([c.oStart, c.oEnd, 1]);
    if (c.cEnd > c.cStart) ranges.add([c.cStart, c.cEnd, 2]);
  }
  if (ranges.isEmpty) return [_Seg(text, 0)];
  ranges.sort((a, b) => a[0].compareTo(b[0]));
  final segs = <_Seg>[];
  var cursor = 0;
  for (final r in ranges) {
    if (r[0] < cursor || r[1] > text.length) continue;
    if (r[0] > cursor) segs.add(_Seg(text.substring(cursor, r[0]), 0));
    segs.add(_Seg(text.substring(r[0], r[1]), r[2]));
    cursor = r[1];
  }
  if (cursor < text.length) segs.add(_Seg(text.substring(cursor), 0));
  return segs;
}

String _compactCoach(String text) {
  final kept = text
      .split('\n')
      .where((l) => !RegExp(r'^\s*\d+\.\s*Instead of\s').hasMatch(l))
      .join(' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  final s = kept.isEmpty ? text : kept;
  return s.length > 400 ? s.substring(0, 400) : s;
}

String _historyText(List<_Msg> history) {
  final from = math.max(0, history.length - 4);
  return history.sublist(from).map((m) {
    if (m.role == 'ai') return 'Coach: ${_compactCoach(m.text)}';
    final t = m.text.length > 300 ? m.text.substring(0, 300) : m.text;
    return 'Learner: $t';
  }).join('\n');
}

/// متنِ ترجمه را بدونِ ایموجیِ ابتدایی برمی‌گرداند (مثلاً «✅ Saved» → «Saved»).
String _plain(String t) =>
    t.replaceFirst(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '');

// ═══════════════════════════════════════════════════════════════════
// تاریخچه‌ی مکالمات — هر مکالمه‌ی ذخیره‌شده یک «جلسه» است با شناسه، زبان،
// زمانِ آخرین تغییر و پیام‌ها (بدون پیامِ ثابتِ معرفیِ Jimmy).
// ═══════════════════════════════════════════════════════════════════
class _Session {
  final String id;
  final String lang;
  final DateTime updatedAt;
  final List<_Msg> messages;

  const _Session({
    required this.id,
    required this.lang,
    required this.updatedAt,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'lang': lang,
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  static _Session? fromJson(Map<String, dynamic> j) {
    final id = (j['id'] ?? '').toString();
    final at = DateTime.tryParse((j['updatedAt'] ?? '').toString());
    if (id.isEmpty || at == null) return null;
    final msgs = <_Msg>[];
    for (final e in (j['messages'] as List? ?? const [])) {
      if (e is Map) {
        try {
          msgs.add(_Msg.fromJson(Map<String, dynamic>.from(e)));
        } catch (_) {}
      }
    }
    return _Session(
      id: id,
      lang: (j['lang'] ?? 'en').toString(),
      updatedAt: at,
      messages: msgs,
    );
  }
}

/// هر بار که تاریخچه عوض شود یکی زیاد می‌شود تا لیستِ تاریخچه تازه شود.
final ValueNotifier<int> _histTick = ValueNotifier<int>(0);

class _HistoryStore {
  static List<_Session> load(LocalStorage ls) {
    final raw = ls.readJson(_kHistKey)['sessions'];
    final out = <_Session>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          try {
            final x = _Session.fromJson(Map<String, dynamic>.from(e));
            if (x != null) out.add(x);
          } catch (_) {}
        }
      }
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  static _Session? find(LocalStorage ls, String id) {
    for (final x in load(ls)) {
      if (x.id == id) return x;
    }
    return null;
  }

  static void _save(LocalStorage ls, List<_Session> list) {
    unawaited(ls
        .writeJson(_kHistKey, {'sessions': list.map((x) => x.toJson()).toList()}));
    _histTick.value++;
  }

  static void upsert(LocalStorage ls, _Session s) {
    final list = load(ls).where((x) => x.id != s.id).toList()..add(s);
    _save(ls, list);
  }

  static void remove(LocalStorage ls, Iterable<String> ids) {
    final drop = ids.toSet();
    _save(ls, load(ls).where((x) => !drop.contains(x.id)).toList());
  }
}

String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

String _sessionTitle(_Session s) {
  for (final m in s.messages) {
    if (m.role == 'user' && m.text.trim().isNotEmpty) {
      return m.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    }
  }
  return '';
}

// ═══════════════════════════════════════════════════════════════════
// تب «تمرین مکالمه»: دو زیرتب — «مکالمه» و «تاریخچه‌ی مکالمات»
// ═══════════════════════════════════════════════════════════════════
class SpeakingTab extends ConsumerStatefulWidget {
  const SpeakingTab({super.key});

  @override
  ConsumerState<SpeakingTab> createState() => _SpeakingTabState();
}

class _SpeakingTabState extends ConsumerState<SpeakingTab> {
  int _sub = 0; // 0 = مکالمه، 1 = تاریخچه
  final GlobalKey<_ChatPaneState> _mainKey = GlobalKey<_ChatPaneState>();

  void _go(int i) {
    if (i == _sub) return;
    setState(() => _sub = i);
    if (i == 0) _mainKey.currentState?.reloadFromHistory();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    Widget seg(int i, String label, IconData icon) {
      final active = _sub == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => _go(i),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 5),
            decoration: BoxDecoration(
              color: active ? c.gold : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: active ? c.gold : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: active ? c.headerTo : c.inkSoft),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? c.headerTo : c.inkSoft,
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return HopePanel(
      contentDirection: uiContentDirection(context),
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: c.paperDark,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: c.cardBorder),
          ),
          child: Row(
            children: [
              seg(0, context.l10n.speaking_tab_speaking,
                  Icons.chat_bubble_outline),
              seg(1, context.l10n.speaking_tab_history, Icons.history),
            ],
          ),
        ),
        // هر دو زنده می‌مانند (مکالمه‌ی در حال ارسال با رفتن به تاریخچه گم نشود)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Offstage(offstage: _sub != 0, child: _ChatPane(key: _mainKey)),
            if (_sub == 1) const _HistoryList(),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// لیستِ تاریخچه — گروه‌بندی بر اساس روز (مثل گرامر)، جدیدترین اول.
// باز کردنِ هر مکالمه = همان چتِ کامل (ادامه، ویرایش، حذفِ پیام).
// ═══════════════════════════════════════════════════════════════════
class _HistoryList extends ConsumerStatefulWidget {
  const _HistoryList();

  @override
  ConsumerState<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends ConsumerState<_HistoryList> {
  String? _expanded;
  bool _selectMode = false;
  final Set<String> _selected = {};

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _dayKey(DateTime d) =>
      '${d.year}/${_two(d.month)}/${_two(d.day)}';

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
        content: Text(context.l10n.speaking_confirm_delete_chats('$n')),
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
    if (ok != true || !mounted) return;
    _HistoryStore.remove(ref.read(localStorageProvider), _selected.toList());
    if (_expanded != null && _selected.contains(_expanded)) _expanded = null;
    _exitSelect();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return ValueListenableBuilder<int>(
      valueListenable: _histTick,
      builder: (context, _, __) {
        final ls = ref.read(localStorageProvider);
        final sessions = _HistoryStore.load(ls);
        final groups = <String, List<_Session>>{};
        for (final x in sessions) {
          groups.putIfAbsent(_dayKey(x.updatedAt), () => []).add(x);
        }
        final labels = groups.keys.toList()..sort((a, b) => b.compareTo(a));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sessions.isEmpty)
              HopeEmptyText(context.l10n.speaking_history_empty),
            if (sessions.isNotEmpty && !_selectMode)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: HopeTextAction(
                  icon: Icons.checklist_rounded,
                  label: context.l10n.grammar_select_delete,
                  color: c.rose,
                  onTap: () => setState(() => _selectMode = true),
                ),
              ),
            if (sessions.isNotEmpty && _selectMode)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                              ..addAll(sessions.map((x) => x.id));
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
                            padding:
                                const EdgeInsetsDirectional.only(end: 8),
                            child: GestureDetector(
                              onTap: () => setState(() {
                                final ids = groups[label]!.map((x) => x.id);
                                if (ids.every(_selected.contains)) {
                                  _selected.removeAll(ids);
                                } else {
                                  _selected.addAll(ids);
                                }
                              }),
                              child: Icon(
                                groups[label]!
                                        .every((x) => _selected.contains(x.id))
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                size: 18,
                                color: groups[label]!
                                        .every((x) => _selected.contains(x.id))
                                    ? c.gold
                                    : c.inkSoft,
                              ),
                            ),
                          ),
                        Text(
                          _dayLabel(groups[label]!.first.updatedAt),
                          style: TextStyle(
                            color: c.inkSoft,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final x in groups[label]!)
                    Padding(
                      key: ValueKey('hist-card-${x.id}'),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _card(c, x),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _card(AppThemeColorsExt c, _Session x) {
    final open = _expanded == x.id && !_selectMode;
    final selected = _selected.contains(x.id);
    final t = _sessionTitle(x);
    final title = t.isEmpty ? context.l10n.speaking_history_untitled : t;
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
            onTap: () => setState(() {
              if (_selectMode) {
                if (!_selected.add(x.id)) _selected.remove(x.id);
              } else {
                _expanded = _expanded == x.id ? null : x.id;
              }
            }),
            child: Row(
              children: [
                if (_selectMode)
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: autoDir(title),
                        style: TextStyle(
                          color: c.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${langDisplayName(context, x.lang)} · ${_timeLabel(x.updatedAt)}',
                        style: TextStyle(color: c.inkSoft, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (!_selectMode) ...[
                  GestureDetector(
                    onTap: () {
                      if (_expanded == x.id) _expanded = null;
                      _HistoryStore.remove(
                          ref.read(localStorageProvider), [x.id]);
                    },
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
              padding: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.cardBorder)),
              ),
              child: _ChatPane(
                key: ValueKey('hist-pane-${x.id}'),
                historyId: x.id,
                onEmptied: () {
                  if (mounted) setState(() => _expanded = null);
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// خودِ چت. دو حالت دارد:
//  • historyId == null → چتِ جاری (تبِ مکالمه)، روی همین گوشی ذخیره می‌شود؛
//    با «ذخیره در تاریخچه» به یک جلسه‌ی تاریخچه گره می‌خورد و از آن به بعد
//    هر تغییرش (و زمانش) در تاریخچه به‌روز می‌شود.
//  • historyId != null → همان جلسه‌ی تاریخچه، درجا و کامل (مثل پیام‌رسان).
// ═══════════════════════════════════════════════════════════════════
class _ChatPane extends ConsumerStatefulWidget {
  final String? historyId;
  final VoidCallback? onEmptied;
  const _ChatPane({super.key, this.historyId, this.onEmptied});

  @override
  ConsumerState<_ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends ConsumerState<_ChatPane> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _editCtrl = TextEditingController();
  int? _editIdx; // اندیسِ پیامِ کاربری که درجا در حال ویرایش است

  List<_Msg> _messages = [];
  bool _loading = false;
  String _error = '';
  String _chatLang = 'en';
  List<_Correction> _corrections = [];
  bool _correctionsSaved = false;
  String? _failedText;
  List<_Msg>? _failedHistory;

  // تاریخچه
  String _sessionId = '';
  bool _inHistory = false;
  DateTime? _syncedAt;

  // انتخاب/حذفِ پیام‌ها
  bool _selectMode = false;
  final Set<int> _sel = {};

  bool get _embedded => widget.historyId != null;

  @override
  void initState() {
    super.initState();
    final ls = ref.read(localStorageProvider);
    if (_embedded) {
      final s = _HistoryStore.find(ls, widget.historyId!);
      _sessionId = widget.historyId!;
      _chatLang = s?.lang ?? 'en';
      _messages = s?.messages ?? [];
      _inHistory = s != null;
      _syncedAt = s?.updatedAt;
      return;
    }
    final sel = ref.read(languageSelectionProvider);
    final options = sel.targets.isNotEmpty ? sel.targets : const ['en'];
    // زبانِ تمرینِ انتخاب‌شده‌ی قبلی حفظ می‌شود (با جابجایی بین تب‌ها ریست نشود)
    final saved = (ls.readJson(_kLangKey)['lang'] ?? '').toString();
    _chatLang = options.contains(saved) ? saved : options.first;
    final raw = ls.readJson(_kChatKey);
    _sessionId = (raw['sessionId'] ?? '').toString();
    if (_sessionId.isEmpty) _sessionId = _newId();
    _messages = _load();
    final hs = _HistoryStore.find(ls, _sessionId);
    _inHistory = hs != null;
    _syncedAt = hs?.updatedAt;
    // اگر فقط پیامِ خوش‌آمد هست، با زبانِ فعلی بازسازی شود
    if (_messages.isEmpty ||
        (_messages.length == 1 && _messages.first.role == 'ai')) {
      _messages = [_welcome(_chatLang)];
      _persist(history: false);
    }
  }

  void _setChatLang(String v) {
    setState(() {
      _chatLang = v;
      if (_messages.length <= 1) _messages = [_welcome(v)];
    });
    unawaited(ref.read(localStorageProvider).writeJson(_kLangKey, {'lang': v}));
    _persist(history: false);
  }

  @override
  void dispose() {
    _input.dispose();
    _editCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ───────────── ذخیره/بازیابی ─────────────
  List<_Msg> _load() {
    final raw = ref.read(localStorageProvider).readJson(_kChatKey)['items'];
    if (raw is! List) return [];
    final out = <_Msg>[];
    for (final e in raw) {
      if (e is Map) {
        try {
          out.add(_Msg.fromJson(Map<String, dynamic>.from(e)));
        } catch (_) {}
      }
    }
    return out;
  }

  void _persist({bool history = true}) {
    if (!mounted) return;
    final ls = ref.read(localStorageProvider);
    if (!_embedded) {
      unawaited(ls.writeJson(_kChatKey, {
        'sessionId': _sessionId,
        'items': _messages.map((m) => m.toJson()).toList(),
      }));
    }
    if (history && _inHistory) _syncHistory();
  }

  /// جلسه را در تاریخچه به‌روز می‌کند (پیامِ معرفیِ Jimmy ذخیره نمی‌شود).
  /// اگر دیگر هیچ پیامی نمانده، جلسه از تاریخچه برداشته می‌شود.
  void _syncHistory() {
    final ls = ref.read(localStorageProvider);
    final real = _messages.where((m) => !m.isWelcome).toList();
    if (real.isEmpty) {
      _HistoryStore.remove(ls, [_sessionId]);
      _inHistory = false;
      _syncedAt = null;
      widget.onEmptied?.call();
      return;
    }
    final now = DateTime.now();
    _HistoryStore.upsert(
      ls,
      _Session(
        id: _sessionId,
        lang: _activeLang(),
        updatedAt: now,
        messages: real,
      ),
    );
    _inHistory = true;
    _syncedAt = now;
  }

  bool get _hasUserMsg => _messages.any((m) => m.role == 'user');

  void _saveToHistory() {
    if (!_hasUserMsg || _inHistory) return;
    setState(() {
      _inHistory = true;
      _syncHistory();
    });
  }

  /// وقتی از تبِ تاریخچه برمی‌گردیم: اگر همین مکالمه آن‌جا ادامه یافته/حذف شده،
  /// چتِ جاری با آن هم‌گام می‌شود.
  void reloadFromHistory() {
    if (_embedded || !_inHistory || _loading) return;
    final s = _HistoryStore.find(ref.read(localStorageProvider), _sessionId);
    if (s == null) {
      setState(() => _inHistory = false);
      return;
    }
    if (s.updatedAt == _syncedAt) return;
    setState(() {
      _messages = [_welcome(s.lang), ...s.messages];
      _syncedAt = s.updatedAt;
      _selectMode = false;
      _sel.clear();
      _editIdx = null;
      _corrections = [];
      _correctionsSaved = false;
    });
    _persist(history: false);
  }

  _Msg _welcome(String lang) => _Msg(
        role: 'ai',
        welcome: true,
        text: "Hey there! I'm Jimmy, your conversation coach. Let's practice "
            '${_enName(lang)} together.\n\n'
            "I'll help you with grammar, vocabulary, and natural expressions. "
            "Feel free to write anything you'd like to talk about!\n\n"
            "By the way, what's your name? Or tell me something about yourself.",
      );

  String _activeLang() {
    if (_embedded) return _chatLang;
    final sel = ref.read(languageSelectionProvider);
    final options = sel.targets.isEmpty ? ['en'] : sel.targets;
    return options.contains(_chatLang) ? _chatLang : options.first;
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  // ───────────── انتخاب/حذفِ پیام‌ها ─────────────
  void _enterSelect([int? first]) {
    if (_loading) return;
    setState(() {
      _selectMode = true;
      _editIdx = null;
      _sel.clear();
      if (first != null) _sel.add(first);
    });
  }

  void _exitSelect() => setState(() {
        _selectMode = false;
        _sel.clear();
      });

  void _toggleSel(int i) => setState(() {
        if (!_sel.add(i)) _sel.remove(i);
      });

  void _deleteSelected() {
    if (_sel.isEmpty) return;
    setState(() {
      _messages = [
        for (var i = 0; i < _messages.length; i++)
          if (!_sel.contains(i)) _messages[i],
      ];
      _selectMode = false;
      _sel.clear();
      _editIdx = null;
      _corrections = [];
      _correctionsSaved = false;
      _error = '';
      _failedText = null;
      _failedHistory = null;
      if (_messages.isEmpty && !_embedded) {
        _messages = [_welcome(_activeLang())];
      }
    });
    _persist();
  }

  // ───────────── AI ─────────────
  Future<String> _callAi(String prompt, int maxTokens) async {
    final svc = ref.read(translationServiceProvider);
    final ai = ref.read(aiSettingsProvider);
    final r = await svc.callAI(
      prompt: prompt,
      maxTokens: maxTokens,
      retries: 1,
      settings: ai,
    );
    final cleaned = _stripThink(r);
    if (cleaned.isEmpty) throw Exception('empty');
    return cleaned;
  }

  Future<_Reply> _askTeacher({
    required String sentence,
    required String lang,
    required String native,
    required List<_Msg> history,
    required bool writtenInNative,
  }) async {
    final langLabel = _enName(lang);
    final nativeLabel = _enName(native);
    final prompt = '''
You are Jimmy, a friendly patient $langLabel coach. Learner's native language: $nativeLabel.
They just wrote${writtenInNative ? ' (in $nativeLabel, not $langLabel)' : ''}: "$sentence"

Rules:
- If they wrote in $langLabel with mistakes, list each one on its own line at the very top, using EXACTLY this tag — keep the word FIX and the => symbol in English even though everything else you write is in $langLabel, do NOT translate this tag:
FIX: <what they wrote> => <the correct version>
(one FIX line per mistake, using their exact wording for "what they wrote")
- If they wrote in $nativeLabel instead of $langLabel (not a mistake, just the wrong language), use ONE such line: FIX: <what they wrote in $nativeLabel> => <$langLabel equivalent>
- After the FIX line(s) — or immediately if there were no mistakes — leave a blank line, then continue the chat: reply ENTIRELY in $langLabel, plain text only (no markdown/asterisks), naturally and briefly — react, ask a follow-up, like a real conversation, not a report. Do NOT explain the mistakes yourself in prose; the FIX lines above are enough.

Recent conversation:
${_historyText(history)}

Now respond to: "$sentence"
''';
    final result = await _callAi(prompt, 550);
    return _extractCorrections(result);
  }

  Future<String> _askContinuation({
    required String translated,
    required String lang,
    required String native,
    required List<_Msg> history,
  }) async {
    final langLabel = _enName(lang);
    final prompt =
        'You are Jimmy, a friendly $langLabel conversation partner. The learner '
        '(native language: ${_enName(native)}) just said, in $langLabel: "$translated"\n\n'
        'Reply ENTIRELY in $langLabel, briefly and naturally (1-3 short sentences) — '
        'react to what they said and/or ask a short follow-up question, like a real '
        'chat message. Plain text only, no markdown, no numbered lists.\n\n'
        'Recent conversation:\n${_historyText(history)}\n';
    final result = await _callAi(prompt, 180);
    return _normalizeAiText(result);
  }

  Future<_Reply> _coachReply(
      String text, List<_Msg> history, String lang) async {
    final native = ref.read(languageSelectionProvider).native;
    final writtenInNative = (native == 'fa' || native == 'ar') &&
        native != lang &&
        lang != 'fa' &&
        lang != 'ar' &&
        isMostlyArabicScript(text);

    if (writtenInNative) {
      // فارسی نوشته → فقط ترجمه است؛ اول ترجمه‌ی رایگان (بدون توکنِ AI)
      var translated = '';
      try {
        translated = decodeHtmlEntities((await ref
                .read(translationServiceProvider)
                .translate(
                  text: text,
                  targetLang: lang,
                  sourceLang: native,
                  aiSettings: ref.read(aiSettingsProvider),
                ))
            .trim());
      } catch (_) {
        translated = '';
      }
      if (translated.isEmpty || translated == text) {
        return _askTeacher(
          sentence: text,
          lang: lang,
          native: native,
          history: history,
          writtenInNative: true,
        );
      }
      final continuation = await _askContinuation(
        translated: translated,
        lang: lang,
        native: native,
        history: history,
      );
      const prefix = '1. Instead of "';
      const mid = '", you should say "';
      final oStart = prefix.length;
      final oEnd = oStart + text.length;
      final cStart = oEnd + mid.length;
      final cEnd = cStart + translated.length;
      return _Reply(
        '$prefix$text$mid$translated".\n\n$continuation',
        [
          _Correction(
            original: text,
            corrected: translated,
            oStart: oStart,
            oEnd: oEnd,
            cStart: cStart,
            cEnd: cEnd,
          ),
        ],
      );
    }

    return _askTeacher(
      sentence: text,
      lang: lang,
      native: native,
      history: history,
      writtenInNative: false,
    );
  }

  Future<void> _ask(String text, List<_Msg> history) async {
    final lang = _activeLang();
    setState(() {
      _editIdx = null;
      _selectMode = false;
      _sel.clear();
      _error = '';
      _corrections = [];
      _correctionsSaved = false;
      _messages = [...history, _Msg(role: 'user', text: text)];
      _loading = true;
    });
    _persist();
    _scrollDown();
    try {
      final r = await _coachReply(text, history, lang);
      if (!mounted) return;
      setState(() {
        if (r.corrections.isNotEmpty) _corrections = r.corrections;
        _messages = [
          ..._messages,
          _Msg(role: 'ai', text: r.text, corrections: r.corrections),
        ];
        _failedText = null;
        _failedHistory = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failedText = text;
        _failedHistory = history;
        _error = context.l10n.speaking_ai_no_response;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    _persist();
    _scrollDown();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _loading) return;
    _input.clear();
    await _ask(text, _messages);
  }

  /// ویرایشِ درجا (مثل چت‌های AI): پیام در همان حباب به یک کادرِ ویرایش تبدیل
  /// می‌شود؛ چیزی حذف نمی‌شود تا کاربر «ذخیره و ارسالِ مجدد» بزند. آن‌وقت
  /// پیام‌های بعد از آن جایگزینِ جوابِ جدیدِ AI می‌شوند. «انصراف» همه‌چیز را
  /// دست‌نخورده برمی‌گرداند.
  void _editMessage(int idx) {
    if (_loading || idx < 0 || idx >= _messages.length) return;
    final m = _messages[idx];
    if (m.role != 'user') return;
    setState(() {
      _editIdx = idx;
      _editCtrl.text = m.text;
      _editCtrl.selection = TextSelection.collapsed(offset: m.text.length);
    });
  }

  void _cancelEdit() {
    if (_editIdx == null) return;
    setState(() => _editIdx = null);
  }

  Future<void> _saveEdit() async {
    final idx = _editIdx;
    final text = _editCtrl.text.trim();
    if (idx == null || text.isEmpty || _loading) return;
    if (idx < 0 || idx >= _messages.length) {
      setState(() => _editIdx = null);
      return;
    }
    final history = _messages.sublist(0, idx);
    setState(() {
      _editIdx = null;
      _failedText = null;
      _failedHistory = null;
    });
    await _ask(text, history);
  }

  /// رفرشِ آخرین پاسخِ AI: همان پیامِ کاربر دوباره فرستاده می‌شود.
  void _refreshReply(int idx) {
    if (_loading || idx < 1 || idx >= _messages.length) return;
    if (_messages[idx].role != 'ai' || _messages[idx - 1].role != 'user') return;
    final text = _messages[idx - 1].text;
    final history = _messages.sublist(0, idx - 1);
    unawaited(_ask(text, history));
  }

  void _retry() {
    final t = _failedText;
    final h = _failedHistory;
    if (t == null || h == null || _loading) return;
    unawaited(_ask(t, h));
  }

  void _clearChat() {
    setState(() {
      _sessionId = _newId(); // مکالمه‌ی جدید = جلسه‌ی جدید؛ قبلی (اگر ذخیره شده) می‌ماند
      _inHistory = false;
      _syncedAt = null;
      _selectMode = false;
      _sel.clear();
      _messages = [_welcome(_activeLang())];
      _editIdx = null;
      _corrections = [];
      _correctionsSaved = false;
      _error = '';
      _failedText = null;
      _failedHistory = null;
    });
    _persist();
  }

  void _saveToGrammar(List<_Correction> list) {
    if (list.isEmpty) return;
    final md = [
      for (var i = 0; i < list.length; i++)
        '**${i + 1}. ${_plain(context.l10n.speaking_mistake)}** ${list[i].original}\n\n'
            '**${_plain(context.l10n.speaking_suggestion)}** ${list[i].corrected}',
    ].join('\n\n---\n\n');
    ref.read(grammarNotesProvider.notifier).addNote(GrammarNote(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          word: '',
          sentence: '',
          markdown: md,
          langCode: _activeLang(),
          savedAt: DateTime.now(),
        ));
  }

  // ───────────── UI ─────────────
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final sel = ref.watch(languageSelectionProvider);
    final options = sel.targets.isEmpty ? ['en'] : sel.targets;
    final lang = options.contains(_chatLang) ? _chatLang : options.first;
    final hasReal = _messages.any((m) => !m.isWelcome);

    final parts = <Widget>[
      // ── زبان تمرین + اکشن‌ها ──
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          if (!_embedded)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.speaking_practice_language,
                    style: TextStyle(color: c.inkSoft, fontSize: 12)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.cardBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: lang,
                      isDense: true,
                      style: TextStyle(color: c.ink, fontSize: 13),
                      dropdownColor: Colors.white,
                      items: [
                        for (final code in options)
                          DropdownMenuItem(
                            value: code,
                            child: Text(langDisplayName(context, code)),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) _setChatLang(v);
                      },
                    ),
                  ),
                ),
              ],
            ),
          Wrap(
            spacing: 14,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (hasReal && !_selectMode && !_loading)
                HopeTextAction(
                  icon: Icons.checklist_rounded,
                  label: context.l10n.grammar_select_delete,
                  color: c.rose,
                  onTap: () => _enterSelect(),
                ),
              if (!_embedded && _messages.isNotEmpty)
                HopeTextAction(
                  icon: Icons.delete_outline,
                  label: context.l10n.speaking_clear_chat,
                  color: c.rose,
                  onTap: _clearChat,
                ),
            ],
          ),
        ],
      ),

      // ── نوارِ انتخابِ پیام‌ها ──
      if (_selectMode) _selectBar(c),

      // ── کادر تصحیحات ──
      if (_corrections.isNotEmpty) _correctionsBox(c),

      // ── منطقه‌ی چت ──
      _chatArea(c),

      // ── نوار ورودی ──
      _inputBar(c),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          parts[i],
        ],
      ],
    );
  }

  Widget _selectBar(AppThemeColorsExt c) {
    return Container(
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
            _sel.isNotEmpty
                ? context.l10n.grammar_n_selected('${_sel.length}')
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
                  _sel
                    ..clear()
                    ..addAll(List<int>.generate(_messages.length, (i) => i));
                }),
              ),
              const SizedBox(width: 12),
              HopeTextAction(
                icon: Icons.delete_outline,
                label: context.l10n.grammar_delete,
                color: _sel.isEmpty ? c.rose.withOpacity(0.5) : c.rose,
                onTap: _sel.isEmpty ? null : _deleteSelected,
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
    );
  }

  Widget _correctionsBox(AppThemeColorsExt c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.goldSoft,
        border: Border.all(color: c.gold),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.edit_outlined, size: 15, color: c.ink),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _plain(context.l10n.speaking_corrections_title),
                  style: TextStyle(
                    color: c.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              HopeTextAction(
                label: _correctionsSaved
                    ? _plain(context.l10n.speaking_saved_to_grammar)
                    : _plain(context.l10n.speaking_save_to_grammar),
                color: _correctionsSaved ? c.inkSoft : c.teal,
                fontSize: 11,
                onTap: _correctionsSaved
                    ? null
                    : () {
                        _saveToGrammar(_corrections);
                        setState(() => _correctionsSaved = true);
                      },
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < _corrections.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text.rich(
                TextSpan(
                  style: TextStyle(color: c.ink, fontSize: 13, height: 1.7),
                  children: [
                    TextSpan(
                      text: '${i + 1}. ${_plain(context.l10n.speaking_mistake)} ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: _corrections[i].original,
                      style: const TextStyle(
                        color: _kMistake,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: _kMistake,
                      ),
                    ),
                    const TextSpan(text: '\n'),
                    TextSpan(
                      text: '${_plain(context.l10n.speaking_suggestion)} ',
                      style: const TextStyle(
                        color: _kCorrection,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: _corrections[i].corrected,
                      style: const TextStyle(
                        color: _kCorrection,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chatArea(AppThemeColorsExt c) {
    return Container(
      constraints: const BoxConstraints(minHeight: 200, maxHeight: 420),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, bc) {
          final maxW = bc.maxWidth * 0.88;
          return ListView(
            controller: _scroll,
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            children: [
              for (var i = 0; i < _messages.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _messageRow(i, _messages[i], maxW, c),
                ),
              if (_loading)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.gold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(context.l10n.speaking_checking,
                          style: TextStyle(color: c.inkSoft, fontSize: 13)),
                    ],
                  ),
                ),
              if (_error.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_error,
                          style: TextStyle(color: c.rose, fontSize: 12)),
                      if (_failedText != null) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _loading ? null : _retry,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: c.rose,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.refresh,
                                    size: 13, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  context.l10n.speaking_try_again,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _messageRow(int idx, _Msg m, double maxW, AppThemeColorsExt c) {
    final isUser = m.role == 'user';
    final dir = autoDir(m.text);

    Widget content;
    final editing = isUser && _editIdx == idx;
    if (editing) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _editCtrl,
            autofocus: true,
            minLines: 1,
            maxLines: 6,
            textDirection: dir,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: c.ink, fontSize: 13, height: 1.7),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.teal),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.teal),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.teal, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _cancelEdit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.inkSoft,
                  side: BorderSide(color: c.cardBorder),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(context.l10n.speaking_cancel,
                    style: const TextStyle(fontSize: 12)),
              ),
              FilledButton(
                onPressed:
                    _editCtrl.text.trim().isEmpty ? null : _saveEdit,
                style: FilledButton.styleFrom(
                  backgroundColor: c.teal,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(context.l10n.speaking_save_resend,
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      );
    } else if (isUser) {
      // لمسِ لغت یا انتخابِ محدوده → کادرِ پاپ‌آپِ مشترک (متن + ترجمه)
      content = SelectableSyncText(
        code: _activeLang(),
        id: 'speaking-user-$idx',
        text: m.text,
        autoLang: true,
        textDirection: dir,
        style: TextStyle(color: c.ink, fontSize: 13, height: 1.7),
      );
    } else {
      final segs = _segments(m.text, m.corrections);
      content = SelectableSyncText(
        code: _activeLang(),
        id: 'speaking-ai-$idx',
        text: segs.map((s) => s.text).join(),
        autoLang: true,
        textDirection: dir,
        style: TextStyle(color: c.ink, fontSize: 13, height: 1.7),
        runs: [
          for (final s in segs)
            SelectableRun(
              s.text,
              s.type == 1
                  ? const TextStyle(
                      color: _kMistake,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: _kMistake,
                    )
                  : s.type == 2
                      ? const TextStyle(
                          color: _kCorrection,
                          fontWeight: FontWeight.w700,
                        )
                      : null,
            ),
        ],
      );
    }

    // 🧬 🔊 داخلِ کادرِ جوابِ AI، بالا سمتِ راست
    if (!isUser && m.text.trim().isNotEmpty) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            textDirection: TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: content),
              AiBubbleActions(text: m.text, sourceLang: _activeLang()),
            ],
          ),
          // خطِ‌چین + چیپ‌های ترجمه داخلِ کادر
          AiAnswerTools(text: m.text, sourceLang: _activeLang()),
        ],
      );
    }

    final row = Align(
      alignment: isUser
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: editing ? maxW / 0.88 : maxW),
        child: Column(
          crossAxisAlignment: editing
              ? CrossAxisAlignment.stretch
              : (isUser ? CrossAxisAlignment.start : CrossAxisAlignment.end),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isUser ? c.paper : c.goldSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectMode && _sel.contains(idx)
                      ? c.gold
                      : c.cardBorder,
                  width: _selectMode && _sel.contains(idx) ? 2 : 1,
                ),
              ),
              child: content,
            ),
            if (isUser && !_loading && !editing && !_selectMode)
              HopeTextAction(
                icon: Icons.edit_outlined,
                label: context.l10n.speaking_edit,
                color: c.teal,
                fontSize: 11,
                onTap: () => _editMessage(idx),
              ),
            if (!isUser &&
                !_loading &&
                !_selectMode &&
                idx >= 1 &&
                idx == _messages.length - 1 &&
                _messages[idx - 1].role == 'user')
              HopeTextAction(
                icon: Icons.refresh,
                label: context.l10n.speaking_refresh,
                color: c.teal,
                fontSize: 11,
                onTap: () => _refreshReply(idx),
              ),
            if (!isUser && m.corrections.isNotEmpty && !_selectMode)
              HopeTextAction(
                label: m.savedToGrammar
                    ? _plain(context.l10n.speaking_saved_to_grammar)
                    : _plain(context.l10n.speaking_save_to_grammar),
                color: m.savedToGrammar ? c.inkSoft : c.teal,
                fontSize: 11,
                onTap: m.savedToGrammar
                    ? null
                    : () {
                        _saveToGrammar(m.corrections);
                        setState(() {
                          _messages = [
                            for (var i = 0; i < _messages.length; i++)
                              i == idx
                                  ? _messages[i].copyWith(savedToGrammar: true)
                                  : _messages[i],
                          ];
                        });
                        _persist();
                      },
              ),
            if (!_embedded &&
                !isUser &&
                !_loading &&
                !_selectMode &&
                idx == _messages.length - 1 &&
                _hasUserMsg)
              HopeTextAction(
                label: _inHistory
                    ? _plain(context.l10n.speaking_saved_to_history)
                    : _plain(context.l10n.speaking_save_to_history),
                color: _inHistory ? c.inkSoft : c.teal,
                fontSize: 11,
                onTap: _inHistory ? null : _saveToHistory,
              ),
          ],
        ),
      ),
    );

    if (_selectMode) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toggleSel(idx),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              _sel.contains(idx)
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              size: 18,
              color: _sel.contains(idx) ? c.gold : c.inkSoft,
            ),
            const SizedBox(width: 8),
            Expanded(child: IgnorePointer(child: row)),
          ],
        ),
      );
    }
    return GestureDetector(
      onLongPress: (_loading || editing) ? null : () => _enterSelect(idx),
      child: row,
    );
  }

  Widget _inputBar(AppThemeColorsExt c) {
    final canSend = !_loading && _input.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: c.teal, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        textDirection: TextDirection.ltr, // دکمه‌ی ارسال سمتِ راست
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 5,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: c.ink, fontSize: 13, height: 1.6),
              decoration: InputDecoration(
                hintText: context.l10n.speaking_input_placeholder,
                hintStyle: TextStyle(
                  color: c.inkSoft.withOpacity(0.6),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Opacity(
            opacity: canSend ? 1 : 0.5,
            child: Material(
              color: c.teal,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: canSend ? _send : null,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Icon(Icons.send_rounded, size: 17, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
