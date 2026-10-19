import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tabs/_hope_panel.dart' show uiContentDirection;
import '../../../app.dart';
import '../../../core/widgets/level_chips.dart';
import '../../../core/models/daily_word.dart';
import '../../../core/player_sync/player_track.dart';
import '../../../core/player_sync/sync_widgets.dart';
import '../../../core/providers/language_selection_provider.dart';
import '../../../core/providers/my_dictionary_provider.dart';
import '../../../core/providers/read_ids_provider.dart';
import '../../../core/providers/words_filter_provider.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/widgets/range_card.dart';
import '../../shell/widgets/shell_header.dart';
import 'word_card.dart';

/// تعدادِ لغتی که در هر «بخش» رندر می‌شود (مثل WORDS_PAGE_SIZE در Hope).
/// با رسیدنِ اسکرول به ته، بخشِ بعدی خودکار اضافه می‌شود.
const int kWordsPageSize = 60;

/// گزینه‌های مرتب‌سازیِ لیستِ لغات — همان WORD_LIST_SORT_OPTIONS در Hope
/// (sortHelpers.js): پیش‌فرض / نام الف→ی / نام ی→الف / سطح ساده→سخت / سطح سخت→ساده
enum WordListSort { byDefault, nameAsc, nameDesc, levelAsc, levelDesc }

const Map<String, int> _kLevelRank = {
  'A1': 1,
  'A2': 2,
  'B1': 3,
  'B2': 4,
  'C1': 5,
  'C2': 6,
};

class WordListView extends ConsumerStatefulWidget {
  /// شناسه‌ی لیست برای ذخیره‌ی «خوانده‌شده‌ها» ('words' / 'slang' / …)
  final String listId;

  /// لیست لغات (خالیه = حالت خالی)
  final List<DailyWord> words;

  /// آیا داده بارگذاری شده؟
  final bool hasAnyData;

  /// پیام حالت خالی
  /// (اگر null باشد، متنِ محلی‌شده‌ی «چیزی پیدا نشد» نشان داده می‌شود)
  final String? emptyMessage;

  /// هنوز در حال بارگذاری است؟ (به‌جای «بارگذاری نشد» چرخنده نشان بده)
  final bool loading;

  /// عنوانِ بالای لیست (مثل «لغات» در تبِ علاقه‌مندی‌های Hope)
  final String? heading;

  /// ویجتِ اضافه (مثلاً مثال‌های ⭐‌دار) درست زیرِ فیلتر/عنوان
  final Widget? afterHeading;

  const WordListView({
    super.key,
    required this.listId,
    required this.words,
    required this.hasAnyData,
    this.emptyMessage,
    this.loading = false,
    this.heading,
    this.afterHeading,
  });

  @override
  ConsumerState<WordListView> createState() => _WordListViewState();
}

class _WordListViewState extends ConsumerState<WordListView> {
  // بازه‌ی دستیِ کاربر (null = خودکار)
  int? _from;
  int? _to;

  // مرزِ بالاییِ «خودکار» — با اسکرول به ته، kWordsPageSize تا زیاد می‌شود.
  int _autoTo = kWordsPageSize;

  // مرتب‌سازی (مثل Hope) + کشِ لیستِ مرتب‌شده تا identity ثابت بماند
  WordListSort _sort = WordListSort.byDefault;
  List<DailyWord>? _sortedSrc;
  WordListSort? _sortedKey;
  List<DailyWord> _sortedList = const <DailyWord>[];

  List<DailyWord> _applySort(List<DailyWord> src) {
    if (_sort == WordListSort.byDefault) return src;
    if (identical(_sortedSrc, src) && _sortedKey == _sort) return _sortedList;
    final arr = [...src];
    int rank(DailyWord w) => _kLevelRank[w.level] ?? 99;
    switch (_sort) {
      case WordListSort.nameAsc:
        arr.sort((a, b) => a.en.toLowerCase().compareTo(b.en.toLowerCase()));
        break;
      case WordListSort.nameDesc:
        arr.sort((a, b) => b.en.toLowerCase().compareTo(a.en.toLowerCase()));
        break;
      case WordListSort.levelAsc:
        arr.sort((a, b) => rank(a).compareTo(rank(b)));
        break;
      case WordListSort.levelDesc:
        arr.sort((a, b) => rank(b).compareTo(rank(a)));
        break;
      case WordListSort.byDefault:
        break;
    }
    _sortedSrc = src;
    _sortedKey = _sort;
    _sortedList = arr;
    return arr;
  }

  String _sortLabel(WordListSort m) {
    final L = context.l10n;
    switch (m) {
      case WordListSort.byDefault:
        return L.sort_default;
      case WordListSort.nameAsc:
        return L.sort_name_asc;
      case WordListSort.nameDesc:
        return L.sort_name_desc;
      case WordListSort.levelAsc:
        return L.sort_level_asc;
      case WordListSort.levelDesc:
        return L.sort_level_desc;
    }
  }

  String _sigLevel = 'all';
  String _sigQuery = '';

  // برای ثابت‌ماندنِ revision پلیر (identical) تا هر build دوباره ثبت نشود
  List<DailyWord> _visible = const <DailyWord>[];
  List<DailyWord>? _visibleSrc;
  int _visibleFrom = -1;
  int _visibleTo = -1;

  void _resetRange() {
    _from = null;
    _to = null;
    _autoTo = kWordsPageSize;
  }

  @override
  Widget build(BuildContext context) {
    final L = context.l10n;
    final words = _applySort(widget.words);
    final c = context.appColors;
    final sel = ref.watch(languageSelectionProvider);
    final filter = ref.watch(wordsFilterProvider);
    final notifier = ref.read(wordsFilterProvider.notifier);
    final readIds = ref.watch(readIdsProvider(widget.listId));
    final readNotifier = ref.read(readIdsProvider(widget.listId).notifier);

    // با عوض‌شدنِ سطح/جستجو، بازه به ابتدای لیست برمی‌گردد (مثل Hope)
    if (filter.level != _sigLevel || filter.query != _sigQuery) {
      _sigLevel = filter.level;
      _sigQuery = filter.query;
      _resetRange();
    }

    final total = words.length;
    final defaultTo = total == 0 ? 0 : math.min(total, _autoTo);
    final from = total == 0
        ? 1
        : (_from ?? 1).clamp(1, total).toInt();
    final to = total == 0
        ? 0
        : (_to ?? defaultTo).clamp(from, total).toInt();

    if (!identical(_visibleSrc, words) ||
        _visibleFrom != from ||
        _visibleTo != to) {
      _visible = total == 0
          ? const <DailyWord>[]
          : words.sublist(from - 1, to);
      _visibleSrc = words;
      _visibleFrom = from;
      _visibleTo = to;
    }
    final visible = _visible;
    final readInRange =
        visible.where((w) => readIds.contains(w.sid)).length;
    final readTotal = words.where((w) => readIds.contains(w.sid)).length;
    final hasMore = _to == null && to < total;

    // مبدأ و مقصدِ یکسان (مثلاً هر دو عربی) → هر زبان فقط یک‌بار
    final langsToShow = <String>[
      if (sel.native != 'en') sel.native,
      ...sel.targets.where((t) => t != 'en'),
    ].toSet().toList();

    // مثل Hope: سطح‌ها، مرتب‌سازی و جستجو بخشی از خودِ محتوا هستند و
    // همراه لیست اسکرول می‌شوند (ثابت روی صفحه نمی‌مانند). برای اینکه فیلدِ
    // جستجو هنگام خالی‌شدنِ نتایج از بین نرود، یک CustomScrollView ثابت
    // داریم و فقط اسلیورِ زیرِ فیلترها عوض می‌شود.
    final filterHeader =
    Container(
              color: c.paper,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LevelChips(
                    selected: filter.level,
                    onSelect: notifier.setLevel,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: PopupMenuButton<WordListSort>(
                      initialValue: _sort,
                      color: c.paper,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (m) => setState(() {
                        _sort = m;
                        _resetRange();
                      }),
                      itemBuilder: (_) => WordListSort.values.map((m) {
                        return PopupMenuItem<WordListSort>(
                          value: m,
                          height: 40,
                          child: Row(
                            children: [
                              if (m == _sort)
                                Icon(Icons.check, size: 16, color: c.gold)
                              else
                                const SizedBox(width: 16),
                              const SizedBox(width: 8),
                              Text(_sortLabel(m),
                                  style: TextStyle(
                                      color: c.ink, fontSize: 13.5)),
                            ],
                          ),
                        );
                      }).toList(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: c.paperDark.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: c.cardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sort, size: 14, color: c.inkSoft),
                            const SizedBox(width: 6),
                            Text('${L.sort_label}: ${_sortLabel(_sort)}',
                                style: TextStyle(
                                    color: c.ink,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 3),
                            Icon(Icons.keyboard_arrow_down,
                                size: 14, color: c.inkSoft),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.cardBorder, width: 1),
                    ),
                    child: TextField(
                      onChanged: notifier.setQuery,
                      textAlign: TextAlign.start,
                      style: TextStyle(color: c.ink, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: L.phrasebook_search_words,
                        hintStyle: TextStyle(
                            color: c.inkSoft.withOpacity(0.55), fontSize: 13.5),
                        prefixIcon:
                            Icon(Icons.search, color: c.inkSoft, size: 19),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                ],
              ),
            );

    return SyncPlayScope(
      // فقط بازه‌ی نمایش‌داده‌شده خوانده/ردیابی می‌شود (مثل Hope)
      revision: visible,
      mode: TrackMode.words,
      itemsBuilder: () => [
        for (final w in visible) SyncItem(w.sid, w.en),
      ],
      // محتوا طبقِ زبانِ رابط (فارسی/عربی RTL، بقیه LTR)؛ ShellHeader خودش RTL می‌ماند
      child: Directionality(
        textDirection: uiContentDirection(context),
        child: CustomScrollView(
        cacheExtent: 600,
        slivers: [
          const SliverToBoxAdapter(child: ShellHeader()),
          SliverToBoxAdapter(child: filterHeader),
          if (widget.afterHeading != null)
            SliverToBoxAdapter(child: widget.afterHeading!),
          if (widget.heading != null && words.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    widget.heading!,
                    style: TextStyle(
                      color: c.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          if (words.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: RangeCard(
                  label: widget.listId == 'favorites'
                      ? L.phrasebook_favorites_words_heading
                      : L.dictionary_range_label,
                  max: total,
                  from: from,
                  to: to,
                  readInRange: readInRange,
                  totalInRange: visible.length,
                  readTotal: readTotal,
                  onFromChanged: (v) => setState(() => _from = v),
                  onToChanged: (v) => setState(() => _to = v),
                  onMarkRead: () => readNotifier.setMany(
                      visible.map((w) => w.sid), true),
                  onClear: () => readNotifier.setMany(
                      visible.map((w) => w.sid), false),
                ),
              ),
            ),
          if (words.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                c: c,
                hasData: widget.hasAnyData,
                loading: widget.loading && !widget.hasAnyData,
                message: widget.emptyMessage ?? L.dialogs_no_results,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    if (i >= visible.length) {
                      // سنتینلِ اسکرولِ بی‌نهایت: با ورود به دید، بخشِ بعدی
                      return _LoadMoreSentinel(
                        key: ValueKey('more-$to'),
                        onVisible: () {
                          if (!mounted) return;
                          setState(() {
                            _autoTo = math.min(
                                math.max(_autoTo, to) + kWordsPageSize,
                                total);
                          });
                        },
                      );
                    }
                    final w = visible[i];
                    return WordCard(
                      key: ValueKey('word-${w.sid}'),
                      id: w.sid,
                      en: w.en,
                      fa: w.fa,
                      level: w.level,
                      pos: w.pos,
                      langsToShow: langsToShow,
                      isPersonal: w.isPersonal,
                      knownTranslations: w.translations,
                      isRead: readIds.contains(w.sid),
                      onToggleRead: () => readNotifier.toggle(w.sid),
                      onRemove: w.isPersonal
                          ? () => ref
                              .read(wordsTabHiddenProvider.notifier)
                              .hide(w.en)
                          : null,
                    );
                  },
                  childCount: visible.length + (hasMore ? 1 : 0),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}

/// نشانگرِ انتهای لیست: وقتی ساخته شد (یعنی کاربر به ته رسید) یک‌بار
/// onVisible را صدا می‌زند تا بخشِ بعدیِ لغات اضافه شود.
class _LoadMoreSentinel extends StatefulWidget {
  final VoidCallback onVisible;
  const _LoadMoreSentinel({super.key, required this.onVisible});

  @override
  State<_LoadMoreSentinel> createState() => _LoadMoreSentinelState();
}

class _LoadMoreSentinelState extends State<_LoadMoreSentinel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onVisible();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 48,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
}

/// حالت خالی / در حال بارگذاری لیست
class _EmptyState extends StatelessWidget {
  final AppThemeColorsExt c;
  final bool hasData;
  final bool loading;
  final String message;

  const _EmptyState({
    required this.c,
    required this.hasData,
    required this.message,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: c.gold),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasData ? Icons.search_off : Icons.hourglass_empty,
              size: 38,
              color: c.inkSoft.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              hasData ? message : context.l10n.wordlist_not_loaded,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.inkSoft,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
