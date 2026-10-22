import 'package:flutter/material.dart';

import '../map/draw_utils.dart' show toFa;
import '../models/emotion.dart';
import '../models/friends_models.dart';
import '../services/content_filter.dart';
import '../state/friends_store.dart';
import '../theme/grat_palette.dart';
import 'friend_post_screen.dart';

/// رنگِ پست: رنگ حسِ نویسنده، وگرنه سبز برنامه
Color friendAccent(GratPalette pal, String? emotionId) {
  final e = emotionId == null ? null : emotionById(emotionId);
  return e == null ? pal.emerald500 : hexToColor(e.color);
}

IconData friendKindIcon(FriendKind k) {
  switch (k) {
    case FriendKind.question:
      return Icons.help_outline_rounded;
    case FriendKind.experience:
      return Icons.auto_stories_outlined;
    case FriendKind.gratitude:
      return Icons.volunteer_activism_outlined;
  }
}

/// دکمه‌ی «حس خوبی داد» (به‌جای لایک)
class GoodFeelButton extends StatelessWidget {
  const GoodFeelButton({
    super.key,
    required this.count,
    required this.active,
    required this.onTap,
    required this.pal,
    this.compact = false,
  });
  final int count;
  final bool active;
  final VoidCallback onTap;
  final GratPalette pal;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = active ? pal.emerald500 : pal.muted;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
        decoration: BoxDecoration(
          color: active ? pal.emerald500.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: active ? pal.emerald500.withValues(alpha: 0.6) : pal.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                active
                    ? Icons.volunteer_activism
                    : Icons.volunteer_activism_outlined,
                size: 18,
                color: c),
            const SizedBox(width: 6),
            Text(
              compact ? toFa(count) : 'حس خوبی داد  ${toFa(count)}',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: c),
            ),
          ],
        ),
      ),
    );
  }
}

class FriendAvatar extends StatelessWidget {
  const FriendAvatar({super.key, required this.name, this.size = 30});
  final String name;
  final double size;

  static const _cols = [
    Color(0xFF178A7C),
    Color(0xFFC9962B),
    Color(0xFF5B6FD6),
    Color(0xFFB04F8F),
    Color(0xFFD1704A),
    Color(0xFF3E9A5B),
  ];

  @override
  Widget build(BuildContext context) {
    final c = _cols[name.codeUnits.fold<int>(0, (a, b) => a + b) % _cols.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.withValues(alpha: 0.18), shape: BoxShape.circle),
      child: Text(name.isEmpty ? '؟' : name.substring(0, 1),
          style: TextStyle(
              fontSize: size * 0.46, fontWeight: FontWeight.w800, color: c)),
    );
  }
}

class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});
  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  final store = FriendsStore.instance;
  FriendKind? _kind;
  FriendSort _sort = FriendSort.newest;

  @override
  Widget build(BuildContext context) {
    final pal = GratPalette.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: pal.emerald700,
        foregroundColor: Colors.white,
        onPressed: () => showFriendComposer(context),
        icon: const Icon(Icons.edit_outlined, size: 20),
        label: const Text('بپرس یا بنویس',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            final posts = store.view(kind: _kind, sort: _sort);
            return ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                _header(pal),
                _kindChips(pal),
                _sortChips(pal),
                const SizedBox(height: 6),
                if (posts.isEmpty) _empty(pal),
                for (final p in posts) _PostCard(post: p, pal: pal, store: store),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(GratPalette pal) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('دوستان هم‌فرکانسی',
                      style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: pal.ink)),
                  const SizedBox(height: 4),
                  Text('بپرس، تجربه بگو و شکرگذاری‌ات رو با هم‌مسیرها شریک شو',
                      style: TextStyle(fontSize: 12, color: pal.muted)),
                ],
              ),
            ),
            if (FriendsStore.demo)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: pal.gold500.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('نمایشی',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: pal.gold600)),
              ),
          ],
        ),
      );

  Widget _chip(GratPalette pal, String label, bool on, VoidCallback tap,
      {IconData? icon}) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: tap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: on ? pal.emerald700 : pal.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: on ? pal.emerald700 : pal.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: on ? Colors.white : pal.muted),
                const SizedBox(width: 5),
              ],
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: on ? Colors.white : pal.inkSoft)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kindChips(GratPalette pal) => SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          children: [
            _chip(pal, 'همه', _kind == null, () => setState(() => _kind = null)),
            for (final k in FriendKind.values)
              _chip(pal, '${k.label}‌ها', _kind == k,
                  () => setState(() => _kind = k),
                  icon: friendKindIcon(k)),
          ],
        ),
      );

  Widget _sortChips(GratPalette pal) => SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          children: [
            _chip(pal, 'تازه‌ها', _sort == FriendSort.newest,
                () => setState(() => _sort = FriendSort.newest),
                icon: Icons.schedule_rounded),
            _chip(pal, 'بی‌پاسخ', _sort == FriendSort.unanswered,
                () => setState(() => _sort = FriendSort.unanswered),
                icon: Icons.mark_chat_unread_outlined),
            _chip(pal, 'پرگفتگو', _sort == FriendSort.hot,
                () => setState(() => _sort = FriendSort.hot),
                icon: Icons.local_fire_department_outlined),
          ],
        ),
      );

  Widget _empty(GratPalette pal) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
        child: Column(
          children: [
            Icon(Icons.forum_outlined, size: 44, color: pal.muted),
            const SizedBox(height: 10),
            Text('اینجا هنوز چیزی نیست',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: pal.inkSoft)),
            const SizedBox(height: 4),
            Text('اولین نفر باش که می‌پرسه یا تجربه‌اش رو می‌گه',
                style: TextStyle(fontSize: 12, color: pal.muted)),
          ],
        ),
      );
}

// ════════════════════════════════════════════════════════════════
//                          کارت پست
// ════════════════════════════════════════════════════════════════
class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.pal, required this.store});
  final FriendPost post;
  final GratPalette pal;
  final FriendsStore store;

  @override
  Widget build(BuildContext context) {
    final accent = friendAccent(pal, post.emotionId);
    final answers = post.visibleAnswers.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Material(
        color: pal.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => FriendPostScreen(postId: post.id),
          )),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: pal.line),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 5, color: accent),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(friendKindIcon(post.kind),
                                    size: 15, color: accent),
                                const SizedBox(width: 5),
                                Text(post.kind.label,
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: accent)),
                                if (post.category.isNotEmpty &&
                                    post.kind != FriendKind.gratitude) ...[
                                  Text('  •  ',
                                      style: TextStyle(color: pal.muted)),
                                  Flexible(
                                    child: Text(post.category,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 11.5, color: pal.muted)),
                                  ),
                                ],
                                const Spacer(),
                                if (post.solved)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: pal.emerald500
                                          .withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle_rounded,
                                            size: 13, color: pal.emerald500),
                                        const SizedBox(width: 3),
                                        Text('جواب گرفت',
                                            style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: pal.emerald500)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(post.title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 15,
                                    height: 1.6,
                                    fontWeight: FontWeight.w800,
                                    color: pal.ink)),
                            if (post.body.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(post.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.7,
                                      color: pal.muted)),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                FriendAvatar(name: post.author, size: 28),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                      '${post.author} · ${faTimeAgo(post.createdAt)}',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 11.5, color: pal.muted)),
                                ),
                                if (post.kind != FriendKind.gratitude) ...[
                                  Icon(Icons.chat_bubble_outline_rounded,
                                      size: 16, color: pal.muted),
                                  const SizedBox(width: 4),
                                  Text(toFa(answers),
                                      style: TextStyle(
                                          fontSize: 12, color: pal.muted)),
                                  const SizedBox(width: 10),
                                ],
                                GoodFeelButton(
                                  compact: true,
                                  pal: pal,
                                  count: post.goodCount,
                                  active: post.goodByMe,
                                  onTap: () => store.toggleGood(post),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//                     فرمِ «بپرس یا بنویس»
// ════════════════════════════════════════════════════════════════
Future<void> showFriendComposer(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ComposerSheet(),
  );
}

class _ComposerSheet extends StatefulWidget {
  const _ComposerSheet();
  @override
  State<_ComposerSheet> createState() => _ComposerSheetState();
}

class _ComposerSheetState extends State<_ComposerSheet> {
  final store = FriendsStore.instance;
  FriendKind _kind = FriendKind.question;
  String _category = kFriendCategories.first;
  String? _emotion;
  late final TextEditingController _title = TextEditingController();
  late final TextEditingController _body = TextEditingController();
  late final TextEditingController _name =
      TextEditingController(text: store.myName);
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    final body = _kind == FriendKind.gratitude ? '' : _body.text.trim();
    final name = _name.text.trim().isEmpty ? 'همسفر' : _name.text.trim();
    if (title.length < 6) {
      setState(() => _error = _kind == FriendKind.gratitude
          ? 'شکرگذاری‌ات رو کامل‌تر بنویس.'
          : 'عنوان خیلی کوتاهه.');
      return;
    }
    if (_kind == FriendKind.experience && body.length < 10) {
      setState(() => _error = 'تجربه‌ات رو کمی کامل‌تر توضیح بده.');
      return;
    }
    final bad = ContentFilter.check('$title\n$body\n$name');
    if (bad != null) {
      setState(() => _error = bad);
      return;
    }
    store.addPost(
      kind: _kind,
      title: title,
      body: body,
      category: _kind == FriendKind.gratitude ? '' : _category,
      emotionId: _emotion,
      author: name,
    );
    Navigator.pop(context);
  }

  InputDecoration _deco(GratPalette pal, String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: pal.muted, fontSize: 13),
        filled: true,
        fillColor: pal.surface,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: pal.line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: pal.line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: pal.emerald300, width: 1.5)),
      );

  Widget _choice(GratPalette pal, String label, bool on, VoidCallback tap,
      {Color? color, IconData? icon}) {
    final c = color ?? pal.emerald700;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: tap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: on ? c.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? c : pal.line, width: on ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: on ? c : pal.muted),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: on ? c : pal.inkSoft)),
          ],
        ),
      ),
    );
  }

  Widget _label(GratPalette pal, String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(t,
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w800, color: pal.ink)),
      );

  @override
  Widget build(BuildContext context) {
    final pal = GratPalette.of(context);
    final isG = _kind == FriendKind.gratitude;
    return Container(
      decoration: BoxDecoration(
        color: pal.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 14, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: pal.line, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              Text('بپرس یا بنویس',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: pal.ink)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in FriendKind.values)
                    _choice(pal, k.label, _kind == k,
                        () => setState(() {
                              _kind = k;
                              _error = null;
                            }),
                        icon: friendKindIcon(k)),
                ],
              ),
              if (!isG) ...[
                _label(pal, 'دسته'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in kFriendCategories)
                      _choice(pal, c, _category == c,
                          () => setState(() => _category = c)),
                  ],
                ),
              ],
              _label(
                  pal,
                  isG
                      ? 'شکرگذاری‌ات'
                      : (_kind == FriendKind.question ? 'سؤالت' : 'عنوان')),
              TextField(
                controller: _title,
                maxLines: isG ? 3 : 2,
                minLines: isG ? 2 : 1,
                maxLength: 140,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 14, color: pal.ink, height: 1.7),
                decoration:
                    _deco(pal, isG ? 'خدایا شکرت که...' : 'یک جمله‌ی روشن').copyWith(counterText: ''),
              ),
              if (!isG) ...[
                _label(pal,
                    _kind == FriendKind.question ? 'توضیح (اختیاری)' : 'تجربه‌ات'),
                TextField(
                  controller: _body,
                  maxLines: 6,
                  minLines: 4,
                  maxLength: 1200,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontSize: 14, color: pal.ink, height: 1.7),
                  decoration: _deco(pal, 'هرچی لازمه بنویس...').copyWith(counterText: ''),
                ),
              ],
              _label(pal, 'حس تو (اختیاری)'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in kEmotions.reversed)
                    _choice(pal, e.fa, _emotion == e.id,
                        () => setState(() =>
                            _emotion = _emotion == e.id ? null : e.id),
                        color: hexToColor(e.color)),
                ],
              ),
              _label(pal, 'نام مستعار'),
              TextField(
                controller: _name,
                maxLength: 20,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 14, color: pal.ink),
                decoration: _deco(pal, 'مثلاً همسفر').copyWith(counterText: ''),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: TextStyle(
                        fontSize: 12.5,
                        height: 1.6,
                        fontWeight: FontWeight.w700,
                        color: pal.danger)),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: pal.emerald700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _submit,
                  child: const Text('ارسال',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
