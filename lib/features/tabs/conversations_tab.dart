import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/constants/topic_icons.dart';
import '../../core/models/conversation.dart';
import '../../core/player_sync/player_track.dart';
import '../../core/player_sync/sync_widgets.dart';
import '../../core/providers/conversation_provider.dart';
import '../../core/providers/language_selection_provider.dart';
import '../../core/providers/read_ids_provider.dart';
import '../../core/theme/app_theme_colors.dart';
import '../../core/widgets/level_chips.dart';
import '../../core/widgets/range_card.dart';
import '../../core/widgets/sync_item_card.dart';
import '../shell/widgets/shell_header.dart';
import '_hope_panel.dart' show uiContentDirection;

class ConversationsTab extends ConsumerStatefulWidget {
  const ConversationsTab({super.key});

  @override
  ConsumerState<ConversationsTab> createState() => _ConversationsTabState();
}

class _ConversationsTabState extends ConsumerState<ConversationsTab> {
  String? _activeTopic;
  int? _openScenario;
  String _query = '';
  String _level = 'all';
  int _rangeFrom = 1;
  int _rangeTo = 60;

  @override
  Widget build(BuildContext context) => Directionality(
        // جهتِ محتوا طبقِ زبانِ رابط؛ ShellHeader خودش RTL می‌ماند
        textDirection: uiContentDirection(context),
        child: _buildBody(context),
      );

  Widget _buildBody(BuildContext context) {
    final c = context.appColors;
    final topics = ref.watch(allTopicsProvider);

    if (topics.isEmpty) {
      final loading = ref.watch(conversationLoaderProvider).isLoading;
      return ListView(
        children: [
          const ShellHeader(),
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: c.gold),
                    )
                  : Text(context.l10n.dialogs_no_results,
                      style: TextStyle(color: c.inkSoft, fontSize: 15)),
            ),
          ),
        ],
      );
    }

    final filtered = topics.where((t) {
      // فیلتر سطح: موضوعی که دست‌کم یک جمله‌ی هم‌سطح دارد
      if (_level != 'all' &&
          !t.scenarios.any((s) =>
              s.speakerA.any((l) => l.level == _level) ||
              s.speakerB.any((l) => l.level == _level))) {
        return false;
      }
      if (_query.trim().isEmpty) return true;
      final q = _query.trim().toLowerCase();
      if (t.topic.toLowerCase().contains(q)) return true;
      return t.scenarios.any((s) =>
          s.scenario.toLowerCase().contains(q) ||
          s.speakerA.any((l) => l.en.toLowerCase().contains(q)) ||
          s.speakerB.any((l) => l.en.toLowerCase().contains(q)));
    }).toList();

    if (_activeTopic != null) {
      final topic = topics.firstWhere((t) => t.topic == _activeTopic,
          orElse: () => topics.first);
      return _buildTopicView(context, topic);
    }
    return _buildTopicsGrid(context, filtered);
  }

  /// ردیف فیلتر سطح (A1–C2) بالای لیست موضوع‌ها.
  Widget _levelBar() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: LevelChips(
          selected: _level,
          onSelect: (l) => setState(() {
            _level = l;
            _rangeFrom = 1;
            _rangeTo = 60;
          }),
        ),
      );

  Widget _buildTopicsGrid(
      BuildContext context, List<ConversationTopic> topics) {
    final c = context.appColors;
    final total = topics.length;

    if (total == 0) {
      return ListView(
        children: [
          const ShellHeader(),
          _levelBar(),
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text(context.l10n.dialogs_no_results,
                  style: TextStyle(color: c.inkSoft, fontSize: 14)),
            ),
          ),
        ],
      );
    }

    final from = _rangeFrom.clamp(1, total).toInt();
    final to = _rangeTo.clamp(from, total).toInt();
    final visible = topics.sublist(from - 1, to);
    // «خوانده‌شده‌ها» روی دستگاه ذخیره می‌شوند (مثل Hope)
    final topicRead = ref.watch(readIdsProvider('conv-topics'));
    final topicReadN = ref.read(readIdsProvider('conv-topics').notifier);
    final readInRange = visible.where((t) => topicRead.contains(t.topic)).length;
    final readTotal = topics.where((t) => topicRead.contains(t.topic)).length;

    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        const ShellHeader(),
        _levelBar(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
        RangeCard(
          label: context.l10n.dialogs_topics_label,
          max: total,
          from: from,
          to: to,
          totalInRange: visible.length,
          readInRange: readInRange,
          readTotal: readTotal,
          onFromChanged: (v) => setState(() {
            _rangeFrom = v;
            if (_rangeTo < v) _rangeTo = v;
          }),
          onToChanged: (v) => setState(() => _rangeTo = v),
          onMarkRead: () =>
              topicReadN.setMany(visible.map((t) => t.topic), true),
          onClear: () =>
              topicReadN.setMany(visible.map((t) => t.topic), false),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: visible.length,
          itemBuilder: (_, i) {
            final topic = visible[i];
            final visual = visualForTopic(topic.topic);
            return _TopicCard(
              topic: topic,
              visual: visual,
              badgeColor: kTopicBadgeColors[i % kTopicBadgeColors.length],
              isRead: topicRead.contains(topic.topic),
              onTap: () => setState(() {
                _activeTopic = topic.topic;
                _openScenario = 0;
              }),
              onToggleRead: () => topicReadN.toggle(topic.topic),
            );
          },
        ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopicView(BuildContext context, ConversationTopic topic) {
    final c = context.appColors;
    final visual = visualForTopic(topic.topic);
    final scenarioRead = ref.watch(readIdsProvider('conv-scenarios'));
    final scenarioReadN = ref.read(readIdsProvider('conv-scenarios').notifier);

    // سناریوی بازشده = «متنِ کاملِ» پلیر (اول «می‌شنوی»، بعد «می‌گی» — همان
    // ترتیبِ Hope). همین یک ویجتِ مشترک هایلایت/اسکرول/پرش را برای همه‌ی
    // تب‌ها یکسان انجام می‌دهد.
    final openIdx = _openScenario;
    final openSc = (openIdx != null && openIdx < topic.scenarios.length)
        ? topic.scenarios[openIdx]
        : null;

    return SyncPlayScope(
      revision: openSc ?? topic,
      mode: TrackMode.lines,
      itemsBuilder: () => openSc == null
          ? const <SyncItem>[]
          : [
              for (var i = 0; i < openSc.speakerA.length; i++)
                SyncItem('a$i', openSc.speakerA[i].en),
              for (var i = 0; i < openSc.speakerB.length; i++)
                SyncItem('b$i', openSc.speakerB[i].en),
            ],
      child: SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 90),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ShellHeader(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
        InkWell(
          onTap: () => setState(() {
            _activeTopic = null;
            _openScenario = null;
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.arrow_back, size: 18, color: c.teal),
                const SizedBox(width: 6),
                Text(context.l10n.dialogs_back_to_topics,
                    style: TextStyle(
                        color: c.teal,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(visual.icon, size: 22, color: visual.color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(topic.topic,
                  style: TextStyle(
                      color: c.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(topic.scenarios.length, (i) {
          final sc = topic.scenarios[i];
          final isOpen = _openScenario == i;
          final readKey = '${topic.topic}::$i';
          final isRead = scenarioRead.contains(readKey);
          return _ScenarioCard(
            scenario: sc,
            isOpen: isOpen,
            isRead: isRead,
            onToggle: () =>
                setState(() => _openScenario = isOpen ? null : i),
            onToggleRead: () => scenarioReadN.toggle(readKey),
          );
        }),
            ],
          ),
        ),
      ],
    ),
    ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// کارت موضوع
// ═══════════════════════════════════════════════════════════════════
class _TopicCard extends StatelessWidget {
  final ConversationTopic topic;
  final TopicVisual visual;
  final Color badgeColor;
  final bool isRead;
  final VoidCallback onTap, onToggleRead;

  const _TopicCard({
    required this.topic,
    required this.visual,
    required this.badgeColor,
    required this.isRead,
    required this.onTap,
    required this.onToggleRead,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 22, 6, 8),
              decoration: BoxDecoration(
                color: isRead ? const Color(0xFFF8F2DE) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      isRead ? const Color(0xFFE3D2A2) : c.cardBorder,
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRead
                          ? Colors.white.withOpacity(0.7)
                          : badgeBgColor(visual.color),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      visual.icon,
                      size: 24,
                      color: isRead
                          ? const Color(0xFF2E7D6C)
                          : visual.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Text(
                        topic.topic,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onToggleRead,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRead
                      ? const Color(0xFF3F9B72)
                      : Colors.white,
                  border: Border.all(
                    color: isRead
                        ? const Color(0xFF276E4F)
                        : const Color(0xFFC8BE95),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: isRead
                    ? const Icon(Icons.check,
                        size: 11, color: Colors.white)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// کارت سناریو
// ═══════════════════════════════════════════════════════════════════
class _ScenarioCard extends StatelessWidget {
  final ConversationScenario scenario;
  final bool isOpen, isRead;
  final VoidCallback onToggle, onToggleRead;

  const _ScenarioCard({
    required this.scenario,
    required this.isOpen,
    required this.isRead,
    required this.onToggle,
    required this.onToggleRead,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isRead ? const Color(0xFFF8F2DE) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isRead ? const Color(0xFFE3D2A2) : c.cardBorder),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onToggleRead,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isRead
                            ? const Color(0xFF3F9B72)
                            : Colors.transparent,
                        border: Border.all(
                          color: isRead
                              ? const Color(0xFF276E4F)
                              : const Color(0xFFC8BE95),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: isRead
                          ? const Icon(Icons.check,
                              size: 12, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(scenario.scenario,
                            style: TextStyle(
                                color: c.ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        if (scenario.context != null) ...[
                          const SizedBox(height: 2),
                          Text(scenario.context!,
                              style: TextStyle(
                                  color: c.inkSoft, fontSize: 11.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                  Icon(isOpen ? Icons.expand_less : Icons.expand_more,
                      color: c.teal, size: 22),
                ],
              ),
            ),
          ),
          if (isOpen) ...[
            const Divider(height: 1),
            if (scenario.speakerA.isNotEmpty)
              _SpeakerBox(
                  title: context.l10n.dialogs_you_hear,
                  idPrefix: 'a',
                  color: c.teal,
                  lines: scenario.speakerA),
            if (scenario.speakerB.isNotEmpty)
              _SpeakerBox(
                  title: context.l10n.dialogs_you_say,
                  idPrefix: 'b',
                  color: c.gold,
                  lines: scenario.speakerB),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
class _SpeakerBox extends ConsumerWidget {
  final String title;

  /// 'a' (می‌شنوی) یا 'b' (می‌گی) — شناسه‌ی هر خط = '$idPrefix$index'
  final String idPrefix;
  final Color color;
  final List<ConversationLine> lines;

  const _SpeakerBox({
    required this.title,
    required this.idPrefix,
    required this.color,
    required this.lines,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      color: c.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(
            lines.length,
            (i) => _LineRow(line: lines[i], id: '$idPrefix$i'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// هر خطِ مکالمه = همان کارتِ مشترکِ برنامه (SyncItemCard) — دقیقاً مثل لغات
// ═══════════════════════════════════════════════════════════════════
class _LineRow extends ConsumerWidget {
  final ConversationLine line;
  final String id;
  const _LineRow({
    required this.line,
    required this.id,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(languageSelectionProvider);

    // مبدأ و مقصدِ یکسان (مثلاً هر دو عربی) → هر زبان فقط یک‌بار
    final langsToShow = <String>[
      if (sel.native != 'en') sel.native,
      ...sel.targets.where((t) => t != 'en'),
    ].toSet().toList();

    return SyncItemCard(
      key: ValueKey('line-$id'),
      id: id,
      en: line.en,
      level: line.level,
      langsToShow: langsToShow,
      knownTranslations: line.fa.isNotEmpty
          ? <String, String>{'fa': line.fa}
          : const <String, String>{},
      compact: true,
    );
  }
}
