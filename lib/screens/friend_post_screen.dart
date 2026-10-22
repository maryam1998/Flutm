import 'package:flutter/material.dart';

import '../map/draw_utils.dart' show toFa;
import '../models/friends_models.dart';
import '../services/content_filter.dart';
import '../state/friends_store.dart';
import '../theme/grat_palette.dart';
import 'friends_tab.dart';

/// صفحه‌ی یک پست: متن کامل + پاسخ‌ها (یک سطح) + نوار نوشتن پاسخ
class FriendPostScreen extends StatefulWidget {
  const FriendPostScreen({super.key, required this.postId});
  final String postId;
  @override
  State<FriendPostScreen> createState() => _FriendPostScreenState();
}

class _FriendPostScreenState extends State<FriendPostScreen> {
  final store = FriendsStore.instance;
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send(FriendPost p) {
    final t = _ctrl.text.trim();
    if (t.length < 2) return;
    final bad = ContentFilter.check(t);
    if (bad != null) {
      setState(() => _error = bad);
      return;
    }
    store.addAnswer(p, t);
    _ctrl.clear();
    setState(() => _error = null);
    FocusScope.of(context).unfocus();
  }

  Future<void> _report(VoidCallback onDone) async {
    final pal = GratPalette.of(context);
    const reasons = [
      'توهین یا الفاظ نامناسب',
      'بحث سیاسی',
      'تبلیغ یا لینک',
      'نامرتبط با موضوع',
    ];
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: pal.paper,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('چرا گزارش می‌کنی؟',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: pal.ink)),
            const SizedBox(height: 8),
            for (final r in reasons)
              ListTile(
                minVerticalPadding: 12,
                title: Text(r, style: TextStyle(color: pal.ink, fontSize: 13.5)),
                leading: Icon(Icons.flag_outlined, color: pal.danger),
                onTap: () => Navigator.pop(ctx, true),
              ),
          ],
        ),
      ),
    );
    if (ok == true) onDone();
  }

  @override
  Widget build(BuildContext context) {
    final pal = GratPalette.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final p = store.byId(widget.postId);
        if (p == null) {
          return Scaffold(backgroundColor: pal.paper, appBar: AppBar());
        }
        final accent = friendAccent(pal, p.emotionId);
        final answers = p.visibleAnswers
          ..sort((a, b) {
            if (a.helpful != b.helpful) return a.helpful ? -1 : 1;
            return a.createdAt.compareTo(b.createdAt);
          });
        return Scaffold(
          backgroundColor: pal.paper,
          appBar: AppBar(
            backgroundColor: pal.paper,
            foregroundColor: pal.ink,
            elevation: 0,
            title: Text(p.kind.label,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            actions: [
              if (!p.mine)
                IconButton(
                  tooltip: 'گزارش',
                  icon: const Icon(Icons.flag_outlined),
                  onPressed: () => _report(() {
                    store.hidePost(p);
                    Navigator.of(context).pop();
                  }),
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                      decoration: BoxDecoration(
                        color: pal.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: accent.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (p.category.isNotEmpty &&
                              p.kind != FriendKind.gratitude)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(p.category,
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: accent)),
                            ),
                          Text(p.title,
                              style: TextStyle(
                                  fontSize: 17,
                                  height: 1.7,
                                  fontWeight: FontWeight.w900,
                                  color: pal.ink)),
                          if (p.body.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(p.body,
                                style: TextStyle(
                                    fontSize: 14,
                                    height: 1.9,
                                    color: pal.inkSoft)),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              FriendAvatar(name: p.author),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                    '${p.author} · ${faTimeAgo(p.createdAt)}',
                                    style: TextStyle(
                                        fontSize: 12, color: pal.muted)),
                              ),
                              GoodFeelButton(
                                pal: pal,
                                count: p.goodCount,
                                active: p.goodByMe,
                                onTap: () => store.toggleGood(p),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (p.kind != FriendKind.gratitude) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                        child: Text(
                            answers.isEmpty
                                ? 'هنوز پاسخی نیست؛ اولین نفر باش'
                                : '${toFa(answers.length)} پاسخ',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: pal.ink)),
                      ),
                      for (final a in answers)
                        _AnswerTile(post: p, answer: a, pal: pal, store: store,
                            onReport: () => _report(() => store.hideAnswer(a))),
                    ],
                  ],
                ),
              ),
              if (p.kind != FriendKind.gratitude) _composer(pal, p),
            ],
          ),
        );
      },
    );
  }

  Widget _composer(GratPalette pal, FriendPost p) => Container(
        padding: EdgeInsets.fromLTRB(
            12, 8, 12, 8 + MediaQuery.of(context).viewInsets.bottom),
        decoration: BoxDecoration(
          color: pal.paper,
          border: Border(top: BorderSide(color: pal.line)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(_error!,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: pal.danger)),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 800,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontSize: 14, color: pal.ink),
                      decoration: InputDecoration(
                        hintText: 'پاسخت رو بنویس...',
                        hintStyle: TextStyle(color: pal.muted, fontSize: 13),
                        counterText: '',
                        filled: true,
                        fillColor: pal.surface,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(color: pal.line)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(color: pal.line)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide:
                                BorderSide(color: pal.emerald300, width: 1.5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: pal.emerald700,
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                      ),
                      onPressed: () => _send(p),
                      child: const Icon(Icons.send_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.post,
    required this.answer,
    required this.pal,
    required this.store,
    required this.onReport,
  });
  final FriendPost post;
  final FriendAnswer answer;
  final GratPalette pal;
  final FriendsStore store;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final a = answer;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: a.helpful ? pal.emerald500.withValues(alpha: 0.08) : pal.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: a.helpful ? pal.emerald500 : pal.line,
            width: a.helpful ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (a.helpful)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 16, color: pal.emerald500),
                  const SizedBox(width: 5),
                  Text('به پرسنده کمک کرد',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: pal.emerald500)),
                ],
              ),
            ),
          Row(
            children: [
              FriendAvatar(name: a.author, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${a.author} · ${faTimeAgo(a.createdAt)}',
                    style: TextStyle(fontSize: 11.5, color: pal.muted)),
              ),
              if (!a.mine)
                InkResponse(
                  onTap: onReport,
                  radius: 22,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child:
                        Icon(Icons.flag_outlined, size: 18, color: pal.muted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(a.body,
              style:
                  TextStyle(fontSize: 14, height: 1.9, color: pal.inkSoft)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              GoodFeelButton(
                compact: true,
                pal: pal,
                count: a.goodCount,
                active: a.goodByMe,
                onTap: () => store.toggleAnswerGood(a),
              ),
              if (post.mine && !a.mine)
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => store.markHelpful(post, a),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: pal.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            size: 17,
                            color: a.helpful ? pal.emerald500 : pal.muted),
                        const SizedBox(width: 5),
                        Text(a.helpful ? 'برداشتن «کمکم کرد»' : 'کمکم کرد',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color:
                                    a.helpful ? pal.emerald500 : pal.muted)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
