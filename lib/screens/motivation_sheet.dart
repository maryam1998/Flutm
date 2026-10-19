import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/motivation_item.dart';
import '../state/motivation_store.dart';

const _kCream = Color(0xFFFBF6EA);
const _kCard = Colors.white;
const _kGold = Color(0xFFC9972B);
const _kInk = Color(0xFF2A2218);
const _kMuted = Color(0xFF7A6B57);
const _kBorder = Color(0xFFE0D5C0);
const _kDanger = Color(0xFFE5484D);

Future<void> showMotivationSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => const _MotivationSheet(),
  );
}

class _MotivationSheet extends StatefulWidget {
  const _MotivationSheet();
  @override
  State<_MotivationSheet> createState() => _MotivationSheetState();
}

class _MotivationSheetState extends State<_MotivationSheet> {
  final _input = TextEditingController();
  final _editCtl = TextEditingController();
  bool _archivedOpen = false;

  @override
  void dispose() {
    _input.dispose();
    _editCtl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    final store = context.read<MotivationStore>();
    await store.add(t);
    _input.clear();
    if (mounted) FocusScope.of(context).unfocus();
  }

  Future<void> _edit(MotivationItem item) async {
    _editCtl.text = item.text;
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        title: const Text('ویرایش جمله',
            style: TextStyle(fontSize: 15, color: _kInk)),
        content: TextField(
          controller: _editCtl,
          autofocus: true,
          maxLines: 4,
          minLines: 2,
          style: const TextStyle(color: _kInk),
          decoration: InputDecoration(
            hintText: 'جمله‌ی انگیزشی...',
            hintStyle: const TextStyle(color: _kMuted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('لغو', style: TextStyle(color: _kMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kGold),
            onPressed: () => Navigator.pop(ctx, _editCtl.text.trim()),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    if (res != null && res.isNotEmpty && mounted) {
      final store = context.read<MotivationStore>();
      await store.update(item.id, res);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MotivationStore>();
    final active = store.active;
    final archived = store.archived;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: _kCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 18, color: _kGold),
                  const SizedBox(width: 8),
                  const Text(
                    'جمله‌های انگیزه‌بخش من',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _kInk,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child:
                        const Text('بستن', style: TextStyle(color: _kMuted)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _kBorder),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // نمایش نوار
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'نمایش نوار در همه‌ی تب‌ها',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _kInk),
                            ),
                          ),
                          Switch(
                            value: store.showBar,
                            activeThumbColor: _kGold,
                            onChanged: (v) => store.setShowBar(v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // افزودن
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            maxLines: 3,
                            minLines: 1,
                            onSubmitted: (_) => _add(),
                            style: const TextStyle(
                                fontSize: 13, color: _kInk),
                            decoration: InputDecoration(
                              hintText:
                                  'مثلاً: هر روز یک قدم به رویاهات نزدیک‌تر...',
                              hintStyle: const TextStyle(
                                  fontSize: 12.5, color: _kMuted),
                              isDense: true,
                              filled: true,
                              fillColor: _kCard,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: _kBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: _kBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: _kGold, width: 1.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _kGold,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _add,
                          child: const Text('افزودن',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (active.isEmpty && archived.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Text(
                          'هنوز جمله‌ای نداری.\nبالا بنویس و «افزودن» بزن.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: _kMuted, height: 1.9, fontSize: 13),
                        ),
                      )
                    else ...[
                      if (active.isNotEmpty) ...[
                        Text('فعال (${active.length})',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _kMuted)),
                        const SizedBox(height: 8),
                        for (final it in active) _itemTile(it, isArchived: false),
                      ],
                      if (archived.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(
                              () => _archivedOpen = !_archivedOpen),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 8),
                            child: Row(
                              children: [
                                Icon(
                                  _archivedOpen
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 18,
                                  color: _kMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'بایگانی (${archived.length})',
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: _kMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_archivedOpen)
                          for (final it in archived)
                            _itemTile(it, isArchived: true),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemTile(MotivationItem it, {required bool isArchived}) {
    final store = context.read<MotivationStore>();
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              it.text,
              style: TextStyle(
                fontSize: 13,
                height: 1.7,
                color: isArchived ? _kMuted : _kInk,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!isArchived) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 18, color: _kMuted),
              onPressed: () => _edit(it),
            ),
            IconButton(
              icon: const Icon(Icons.archive_outlined,
                  size: 18, color: _kMuted),
              onPressed: () => store.archive(it.id),
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.unarchive_outlined,
                  size: 18, color: _kGold),
              tooltip: 'بازگرداندن',
              onPressed: () => store.unarchive(it.id),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: _kDanger),
            onPressed: () => store.remove(it.id),
          ),
        ],
      ),
    );
  }
}
