import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/gratitude_journey.dart';
import '../map/draw_utils.dart' show toFa;
import '../models/gratitude_entry.dart';
import '../models/jalali.dart';
import '../services/image_service.dart';
import '../state/gratitude_store.dart';

const _kCream = Color(0xFFFBF6EA);
const _kCard = Colors.white;
const _kGold = Color(0xFFC9972B);
const _kInk = Color(0xFF2A2218);
const _kMuted = Color(0xFF7A6B57);
const _kBorder = Color(0xFFE0D5C0);
const _kDanger = Color(0xFFE5484D);
const _kEmerald = Color(0xFF2BBFAB);

class GratitudeTab extends StatefulWidget {
  const GratitudeTab({super.key});
  @override
  State<GratitudeTab> createState() => _GratitudeTabState();
}

class _GratitudeTabState extends State<GratitudeTab> {
  final _text = TextEditingController();
  final List<GratitudeImage> _pendingImages = [];
  bool _shared = false;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final srcs = await ImageService.pickImages();
    if (!mounted || srcs.isEmpty) return;
    setState(() {
      for (final s in srcs) {
        _pendingImages.add(GratitudeImage(src: s));
      }
    });
  }

  void _removePending(int i) {
    setState(() => _pendingImages.removeAt(i));
  }

  Future<void> _submit() async {
    final store = context.read<GratitudeStore>();
    final text = _text.text.trim();
    if (text.isEmpty && _pendingImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('یه متن یا عکس وارد کن 🌱')),
      );
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await store.add(
        text: text,
        images: List.of(_pendingImages),
        shared: _shared,
      );
      _text.clear();
      setState(() {
        _pendingImages.clear();
        _shared = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_shared
              ? 'ثبت شد و با بقیه به اشتراک گذاشته شد 🌍'
              : 'ثبت شد — فقط برای خودم 🤫')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editEntry(GratitudeEntry e) async {
    final store = context.read<GratitudeStore>();
    final res = await showModalBottomSheet<GratitudeEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (_) => _GratitudeEditor(entry: e, store: store),
    );
    if (res != null) setState(() {});
  }

  Future<void> _confirmDelete(GratitudeEntry e) async {
    final store = context.read<GratitudeStore>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        title: const Text('حذف',
            style: TextStyle(fontSize: 15, color: _kInk)),
        content: Text('این شکرگذاری حذف بشه؟',
            style: TextStyle(color: _kInk)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('نه', style: TextStyle(color: _kMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kDanger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await store.remove(e.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<GratitudeStore>();
    final phase = computeGratitudePhase(store.journeyDay, store.journeyDays);

    return Scaffold(
      backgroundColor: _kCream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            // هدر
            Row(
              children: [
                const Text(
                  'شکرگذاری',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${toFa(store.totalCount)} مورد',
                  style: const TextStyle(fontSize: 12, color: _kMuted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'هر چیزی که در زندگیت هست، همین‌جا ثبتش کن',
              style: TextStyle(fontSize: 12.5, color: _kMuted),
            ),
            const SizedBox(height: 14),

            // بنر مسیر ۲۸ روزه
            _JourneyBanner(phase: phase, store: store),
            const SizedBox(height: 16),

            // تقویم کوچک
            _MiniCalendar(store: store),
            const SizedBox(height: 16),

            // فرم افزودن
            _addForm(store),
            const SizedBox(height: 20),

            // لیست
            if (store.entries.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kBorder),
                ),
                child: const Text(
                  'هنوز هیچ شکرگذاری ثبت نشده.\nیه چیز خوب زندگیت رو همین بالا بنویس 🌱',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _kMuted, height: 1.9, fontSize: 13),
                ),
              )
            else
              for (final e in store.histSlice) _entryCard(store, e),

            if (store.hasMoreHist)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kInk,
                    side: const BorderSide(color: _kBorder),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: store.showMoreHist,
                  icon: const Icon(Icons.expand_more, size: 18),
                  label: Text(
                    'نمایش بیشتر (${toFa(store.entries.length - store.histLimit)} مورد دیگر)',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- فرم افزودن ----------
  Widget _addForm(GratitudeStore store) {
    final phase = computeGratitudePhase(store.journeyDay, store.journeyDays);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kGold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${toFa(store.totalCount + 1)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _kGold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'خدایا شکرت که:',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _kInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _text,
            maxLines: 4,
            minLines: 2,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 13, color: _kInk, height: 1.7),
            decoration: InputDecoration(
              hintText: '🎯 ${phase.prompt}',
              hintStyle: const TextStyle(color: _kMuted, fontSize: 12),
              filled: true,
              fillColor: _kCream,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kGold, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // دکمه‌ی افزودن عکس + پیش‌نمایش‌ها
          Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kMuted,
                  side: const BorderSide(color: _kBorder),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _pickImages,
                icon: const Icon(Icons.image_outlined, size: 18),
                label: const Text('افزودن عکس',
                    style: TextStyle(fontSize: 12.5)),
              ),
              const Spacer(),
              // رادیوهای اشتراک‌گذاری
              _visRadio('فقط خودم', !_shared, () => setState(() => _shared = false)),
              const SizedBox(width: 8),
              _visRadio('اشتراک', _shared, () => setState(() => _shared = true)),
            ],
          ),
          if (_pendingImages.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _pendingImages.length; i++)
                  _imgThumb(_pendingImages[i].src, () => _removePending(i)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _kGold,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'ثبت شکرگذاری',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _visRadio(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? _kGold.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? _kGold : _kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.lock : Icons.lock_outline,
              size: 12,
              color: selected ? _kGold : _kMuted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected ? _kGold : _kMuted,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgThumb(String src, VoidCallback onRemove) {
    final bytes = _decode(src);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: _kCream,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: bytes != null
              ? Image.memory(bytes, fit: BoxFit.cover)
              : const Icon(Icons.broken_image, color: _kMuted),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: _kDanger,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- کارت هر شکرگذاری ----------
  Widget _entryCard(GratitudeStore store, GratitudeEntry e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _editEntry(e),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kCream,
                shape: BoxShape.circle,
                border: Border.all(color: _kBorder),
              ),
              child: Text(e.icon, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.displayText(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: _kInk,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${e.day} ${_faDateShort(e.iso)} - ${e.time}',
                        style: const TextStyle(
                            fontSize: 10.5, color: _kMuted),
                      ),
                      if (e.editedAt != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: _kBorder),
                          ),
                          child: const Text('✏️ ویرایش‌شده',
                              style: TextStyle(
                                  fontSize: 9.5, color: _kMuted)),
                        ),
                      ],
                      if (e.shared) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.public,
                            size: 12, color: _kEmerald),
                      ],
                    ],
                  ),
                  if (e.images.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final im in e.images.take(6))
                          _imgThumbReadonly(im.src),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: _kDanger),
              onPressed: () => _confirmDelete(e),
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints.tightFor(width: 32, height: 32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgThumbReadonly(String src) {
    final bytes = _decode(src);
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: _kCream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes != null
          ? Image.memory(bytes, fit: BoxFit.cover)
          : const Icon(Icons.broken_image, color: _kMuted, size: 18),
    );
  }

  static Uint8List? _decode(String src) {
    try {
      if (!src.startsWith('data:')) return null;
      return base64Decode(src.substring(src.indexOf(',') + 1));
    } catch (_) {
      return null;
    }
  }

  static String _faDateShort(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      final j = toJalaali(d.year, d.month, d.day);
      return '${toFa(j.jd)} ${kJalaliMonths[j.jm - 1]}';
    } catch (_) {
      return '';
    }
  }
}

// ============================================================
// بنر مسیر ۲۸ روزه
// ============================================================
class _JourneyBanner extends StatelessWidget {
  const _JourneyBanner({required this.phase, required this.store});
  final GratitudePhaseInfo phase;
  final GratitudeStore store;

  @override
  Widget build(BuildContext context) {
    final pct = (phase.day / phase.totalDays).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            _kGold.withValues(alpha: 0.12),
            _kEmerald.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('🧭 مسیر ۲۸ روزه شکرگذاری',
                  style: TextStyle(fontSize: 12.5, color: _kMuted)),
              const Spacer(),
              Text(
                'روز ${toFa(phase.day)} / ${toFa(phase.totalDays)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _kInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'فاز ${toFa(phase.phaseIndex + 1)} — ${phase.phaseName}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '🎯 ${phase.prompt}',
            style: const TextStyle(
              fontSize: 12,
              color: _kMuted,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              color: _kGold,
              backgroundColor: _kGold.withValues(alpha: 0.12),
            ),
          ),
          if (store.journeyFinished) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kGold.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kGold.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🎉 این دوره‌ی ۲۸ روزه تموم شد. برای شروع دوره‌ی تازه، دکمه رو بزن.',
                    style: TextStyle(
                        fontSize: 11.5, color: _kInk, height: 1.7),
                  ),
                  const SizedBox(height: 6),
                  Material(
                    color: _kGold,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: _kCard,
                            content: const Text(
                                'دوره‌ی تازه شروع بشه؟ ثبت‌های قبلی حفظ می‌شن.',
                                style: TextStyle(color: _kInk)),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('نه')),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: _kGold),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('بله'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) await store.startNewJourney();
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        child: Text('▶ شروع دوره‌ی تازه',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// تقویم کوچک (۱۵ ستونی)
// ============================================================
class _MiniCalendar extends StatelessWidget {
  const _MiniCalendar({required this.store});
  final GratitudeStore store;

  @override
  Widget build(BuildContext context) {
    final start = store.journeyStart;
    final startDate = _parseKey(start);
    final total = store.journeyDays;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final doneSet = <String>{};
    for (final e in store.entries) {
      if (e.source == 'purchase') continue;
      final k = GratitudeStore.isoToKey(e.iso);
      if (k.isNotEmpty) doneSet.add(k);
    }

    const cols = 15;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('📅 تقویم شکرگذاری',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _kInk,
              )),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (ctx, box) {
            final cellW = (box.maxWidth - (cols - 1) * 3) / cols;
            final size = cellW.clamp(18.0, 26.0);

            final cells = <Widget>[];
            for (var d = 0; d < total; d++) {
              final date = DateTime(
                  startDate.year, startDate.month, startDate.day + d);
              final key =
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final j = toJalaali(date.year, date.month, date.day);
              final has = doneSet.contains(key);
              final future = date.isAfter(todayDate);
              final isToday = key == todayKey;
              cells.add(
                Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: has ? _kGold : _kCream,
                    border: Border.all(
                      color: isToday ? _kGold : _kBorder,
                      width: isToday ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    has ? '✓' : toFa(j.jd),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: has
                          ? Colors.white
                          : (future
                              ? _kMuted.withValues(alpha: 0.5)
                              : _kInk),
                    ),
                  ),
                ),
              );
            }
            return Wrap(
              spacing: 3,
              runSpacing: 3,
              children: cells,
            );
          }),
        ],
      ),
    );
  }

  static DateTime _parseKey(String k) {
    final p = k.split('-').map((e) => int.tryParse(e) ?? 1).toList();
    if (p.length != 3) return DateTime.now();
    return DateTime(p[0], p[1], p[2]);
  }
}

// ============================================================
// دیالوگ ویرایش
// ============================================================
class _GratitudeEditor extends StatefulWidget {
  const _GratitudeEditor({required this.entry, required this.store});
  final GratitudeEntry entry;
  final GratitudeStore store;

  @override
  State<_GratitudeEditor> createState() => _GratitudeEditorState();
}

class _GratitudeEditorState extends State<_GratitudeEditor> {
  late final TextEditingController _text;
  late List<GratitudeImage> _images;
  late bool _shared;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.entry.text);
    _images = List.of(widget.entry.images);
    _shared = widget.entry.shared;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _text.text.trim();
    await widget.store.update(
      widget.entry.id,
      text: text,
      images: _images,
      shared: _shared,
    );
    if (!mounted) return;
    Navigator.pop(context, widget.entry);
  }

  Future<void> _delete() async {
    await widget.store.remove(widget.entry.id);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _pickImages() async {
    final srcs = await ImageService.pickImages();
    if (!mounted || srcs.isEmpty) return;
    setState(() {
      for (final s in srcs) {
        _images.add(GratitudeImage(src: s));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('ویرایش شکرگذاری',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _kInk)),
                const SizedBox(height: 14),
                TextField(
                  controller: _text,
                  maxLines: 4,
                  minLines: 2,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                      fontSize: 13, color: _kInk, height: 1.7),
                  decoration: InputDecoration(
                    hintText: 'متن شکرگذاری...',
                    hintStyle: const TextStyle(color: _kMuted, fontSize: 12),
                    filled: true,
                    fillColor: _kCard,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kGold, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kMuted,
                        side: const BorderSide(color: _kBorder),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _pickImages,
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: const Text('افزودن عکس',
                          style: TextStyle(fontSize: 12.5)),
                    ),
                    const Spacer(),
                    Switch(
                      value: _shared,
                      activeThumbColor: _kGold,
                      onChanged: (v) => setState(() => _shared = v),
                    ),
                    const Text('اشتراک‌گذاری',
                        style: TextStyle(fontSize: 12, color: _kInk)),
                  ],
                ),
                if (_images.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _images.length; i++)
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: _kCard,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _kBorder),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _decode(_images[i].src) != null
                                  ? Image.memory(_decode(_images[i].src)!,
                                      fit: BoxFit.cover)
                                  : const Icon(Icons.broken_image,
                                      color: _kMuted),
                            ),
                            Positioned(
                              top: -6,
                              right: -6,
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => _images.removeAt(i)),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    color: _kDanger,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kDanger,
                          side: const BorderSide(color: _kDanger),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _delete,
                        child: const Text('حذف'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _kGold,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _save,
                        child: const Text('ذخیره تغییرات',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child:
                      const Text('انصراف', style: TextStyle(color: _kMuted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Uint8List? _decode(String src) {
    try {
      if (!src.startsWith('data:')) return null;
      return base64Decode(src.substring(src.indexOf(',') + 1));
    } catch (_) {
      return null;
    }
  }
}
