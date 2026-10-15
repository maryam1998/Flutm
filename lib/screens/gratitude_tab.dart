import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/gratitude_journey.dart';
import '../models/emotion.dart';
import '../models/gratitude_entry.dart';
import '../state/emotion_store.dart';
import '../state/gratitude_store.dart';
import '../theme/grat_palette.dart';
import '../widgets/gratitude_slideshow.dart';
import '../widgets/neural_pathway.dart';

// ═══════════════════════════════════════════════════════════════
//                        تب شکرگذاری
// ═══════════════════════════════════════════════════════════════
class GratitudeTab extends StatefulWidget {
  const GratitudeTab({super.key});

  @override
  State<GratitudeTab> createState() => _GratitudeTabState();
}

class _GratitudeTabState extends State<GratitudeTab> {
  final _scrollCtrl = ScrollController();

  // ── کمپوزر ──
  final _textCtrl = TextEditingController();
  final _textFocus = FocusNode();
  final List<GratitudeImage> _pendingImages = [];
  final List<GratitudeAudio> _pendingAudios = [];
  final List<GratitudeVideo> _pendingVideos = [];
  bool _pendingShare = false;

  // ── ویرایش ──
  String? _editingId;
  final _editCtrl = TextEditingController();
  final List<GratitudeImage> _editImages = [];
  final List<GratitudeAudio> _editAudios = [];
  final List<GratitudeVideo> _editVideos = [];
  bool _editShare = false;

  final _picker = ImagePicker();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _textCtrl.dispose();
    _textFocus.dispose();
    _editCtrl.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final pal = GratPalette.of(context);
    final store = context.watch<GratitudeStore>();

    if (!store.loaded) {
      return Container(
        color: pal.paper,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    final info = computeGratitudePhase(store.journeyDay, store.journeyDays);

    return Container(
      color: pal.paper,
      child: SingleChildScrollView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 14),
            _CounterCard(store: store, pal: pal),
            const SizedBox(height: 8),
            _ThemeBanner(info: info, pal: pal),
            const SizedBox(height: 12),
            _MiniCalendar(store: store, pal: pal),
            const SizedBox(height: 14),
            _Composer(
              pal: pal,
              textCtrl: _textCtrl,
              textFocus: _textFocus,
              images: _pendingImages,
              audios: _pendingAudios,
              videos: _pendingVideos,
              share: _pendingShare,
              onShareChanged: (v) => setState(() => _pendingShare = v),
              onPickImages: _pickImages,
              onPickVideos: _pickVideos,
              onRecordAudio: _recordAudio,
              onRemoveImage: (i) => setState(() => _pendingImages.removeAt(i)),
              onRemoveAudio: (i) => setState(() => _pendingAudios.removeAt(i)),
              onRemoveVideo: (i) => setState(() => _pendingVideos.removeAt(i)),
              onSubmit: _submit,
            ),
            const SizedBox(height: 20),
            _SectionLabel(
              icon: Icons.psychology_alt_outlined,
              title: 'مسیر عصبی شکرگذاری',
              pal: pal,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: NeuralPathway(
                container: store.neural,
                label: 'شکرگذاری',
                onChange: () => store.saveNeural(),
                emotionQualityToday: _emotionQualityToday(store),
              ),
            ),
            const SizedBox(height: 18),
            if (store.entries.any(
                (e) => e.source != 'purchase' && e.images.isNotEmpty))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GratitudeSlideshow(store: store),
              ),
            const SizedBox(height: 18),
            _SectionLabel(
              icon: Icons.list_alt_outlined,
              title: 'لیست شکرگذاری',
              trailing: '${_toFa(store.totalCount)} ثبت',
              pal: pal,
            ),
            const SizedBox(height: 6),
            _buildList(store, pal),
          ],
        ),
      ),
    );
  }

  int? _emotionQualityToday(GratitudeStore store) {
    final dk = GratitudeStore.isoToKey(DateTime.now().toIso8601String());
    final ids = store.emotionIdsForDay(dk);
    if (ids.isEmpty) return null;
    int max = 0;
    for (final id in ids) {
      final e = emotionById(id);
      if (e != null && e.freq > max) max = e.freq;
    }
    return max;
  }

  // ─────────────────── لیست ───────────────────
  Widget _buildList(GratitudeStore store, GratPalette pal) {
    final all = store.allReversed;
    if (all.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          decoration: BoxDecoration(
            color: pal.surface,
            border: Border.all(color: pal.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'هنوز هیچ شکرگذاری ثبت نشده.\nیه چیز خوب زندگیت رو همین بالا بنویس 🌱',
            textAlign: TextAlign.center,
            style: TextStyle(color: pal.muted, fontSize: 13, height: 1.8),
          ),
        ),
      );
    }
    final slice = all.take(store.histLimit).toList();
    return Column(
      children: [
        ...slice.map((g) => _EntryRow(
              entry: g,
              store: store,
              pal: pal,
              onTap: () => _openEditor(g),
            )),
        if (all.length > slice.length)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: _GhostButton(
              text:
                  'نمایش بیشتر (${_toFa(all.length - slice.length)} مورد دیگر)',
              pal: pal,
              onTap: () => store.showMoreHist(),
            ),
          ),
      ],
    );
  }

  // ─────────────────── افزودن ───────────────────
  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty &&
        _pendingImages.isEmpty &&
        _pendingAudios.isEmpty &&
        _pendingVideos.isEmpty) {
      _toast('یه متن، عکس، ویدیو یا صدا وارد کن 🌱');
      return;
    }
    final store = context.read<GratitudeStore>();
    final emotions = context.read<EmotionStore>();

    await store.add(
      text: text,
      images: List.of(_pendingImages),
      audios: List.of(_pendingAudios),
      videos: List.of(_pendingVideos),
      shared: _pendingShare,
      emotions: emotions,
    );

    setState(() {
      _textCtrl.clear();
      _pendingImages.clear();
      _pendingAudios.clear();
      _pendingVideos.clear();
      _pendingShare = false;
    });
    _toast(_pendingShare
        ? 'ثبت شد و با بقیه به اشتراک گذاشته شد 🌍'
        : 'ثبت شد — فقط برای خودم 🤫');
  }

  // ─────────────────── انتخاب مدیا ───────────────────
  Future<void> _pickImages() async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 82, maxWidth: 1400);
      if (files.isEmpty) return;
      for (final f in files) {
        final bytes = await f.readAsBytes();
        final b64 = base64Encode(bytes);
        final src = 'data:image/jpeg;base64,$b64';
        setState(() => _pendingImages.add(GratitudeImage(src: src)));
      }
    } catch (e) {
      _toast('عکس اضافه نشد: $e');
    }
  }

  Future<void> _pickVideos() async {
    try {
      final f = await _picker.pickVideo(source: ImageSource.gallery);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        _toast('ویدیو بزرگ‌تر از ۸ مگابایت ذخیره نمی‌شه (نسخهٔ سبک)');
        return;
      }
      final b64 = base64Encode(bytes);
      final src = 'data:video/mp4;base64,$b64';
      setState(() => _pendingVideos.add(
            GratitudeVideo(path: src, name: f.name, size: bytes.length),
          ));
    } catch (e) {
      _toast('ویدیو اضافه نشد: $e');
    }
  }

  Future<void> _recordAudio() async {
    // ادغام با VoiceRecorderSheet اگر موجود باشد
    try {
      // ignore: avoid_dynamic_calls
      final dyn = await _dynamicShowVoice(context);
      if (dyn is String && dyn.isNotEmpty) {
        setState(() => _pendingAudios.add(
              GratitudeAudio(
                src: dyn,
                name: 'صدا ${_toFa(_pendingAudios.length + 1)}',
              ),
            ));
      }
    } catch (_) {
      _toast('ضبط صدا در دسترس نیست');
    }
  }

  Future<Object?> _dynamicShowVoice(BuildContext ctx) async {
    // از voice_recorder_sheet استفاده می‌کنیم بدون import مستقیم
    try {
      // ignore: avoid_dynamic_calls
      final result = await showModalBottomSheet<Object?>(
        context: ctx,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _VoiceFallbackSheet(),
      );
      return result;
    } catch (_) {
      return null;
    }
  }

  // ─────────────────── ویرایش ───────────────────
  void _openEditor(GratitudeEntry g) {
    _editingId = g.id;
    _editCtrl.text = g.text;
    _editImages
      ..clear()
      ..addAll(g.images);
    _editAudios
      ..clear()
      ..addAll(g.audios);
    _editVideos
      ..clear()
      ..addAll(g.videos);
    _editShare = g.shared;

    final pal = GratPalette.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final isPurchase = g.source == 'purchase';
          return Container(
            decoration: BoxDecoration(
              color: pal.paper,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: pal.line,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        isPurchase ? 'ویرایش خرید' : 'ویرایش شکرگذاری',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: pal.ink,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _editCtrl,
                        maxLines: null,
                        minLines: 3,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                            fontSize: 14, color: pal.ink, height: 1.7),
                        decoration: InputDecoration(
                          hintText: 'متن شکرگذاری...',
                          hintStyle: TextStyle(color: pal.muted),
                          filled: true,
                          fillColor: pal.surface,
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: pal.line),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: pal.line),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: pal.emerald300, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_editImages.isNotEmpty)
                        _ThumbGrid(
                          images: _editImages,
                          pal: pal,
                          onRemove: (i) => setSheet(
                              () => _editImages.removeAt(i)),
                        ),
                      if (_editAudios.isNotEmpty)
                        ..._editAudios.asMap().entries.map((e) =>
                            _AudioRow(
                              audio: e.value,
                              pal: pal,
                              onRemove: () => setSheet(
                                  () => _editAudios.removeAt(e.key)),
                            )),
                      if (_editVideos.isNotEmpty)
                        ..._editVideos.asMap().entries.map((e) => _VideoTile(
                              video: e.value,
                              pal: pal,
                              onRemove: () => setSheet(
                                  () => _editVideos.removeAt(e.key)),
                            )),
                      const SizedBox(height: 14),
                      if (!isPurchase)
                        _VisibilityRow(
                          value: _editShare,
                          pal: pal,
                          onChanged: (v) => setSheet(() => _editShare = v),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 46,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: pal.emerald700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            final store = context.read<GratitudeStore>();
                            await store.update(
                              g.id,
                              text: _editCtrl.text.trim(),
                              images: List.of(_editImages),
                              audios: List.of(_editAudios),
                              videos: List.of(_editVideos),
                              shared: _editShare,
                            );
                            if (mounted) Navigator.pop(ctx);
                            _toast('شکرگذاری ویرایش شد ✏️');
                          },
                          child: const Text('ذخیره تغییرات',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _GhostButton(
                        text: '🗑 حذف این شکرگذاری',
                        pal: pal,
                        onTap: () async {
                          final ok = await showDialog<bool>(
                            context: ctx,
                            builder: (dctx) => AlertDialog(
                              backgroundColor: pal.card,
                              content: Text('این مورد حذف شود؟',
                                  style: TextStyle(color: pal.ink)),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dctx, false),
                                  child: const Text('نه'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: pal.danger,
                                  ),
                                  onPressed: () =>
                                      Navigator.pop(dctx, true),
                                  child: const Text('بله'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await context
                                .read<GratitudeStore>()
                                .remove(g.id);
                            if (mounted) Navigator.pop(ctx);
                            _toast('شکرگذاری حذف شد 🗑');
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      _GhostButton(
                        text: 'انصراف',
                        pal: pal,
                        onTap: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1600),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//                        کارت شمارنده
// ═══════════════════════════════════════════════════════════════
class _CounterCard extends StatelessWidget {
  final GratitudeStore store;
  final GratPalette pal;
  const _CounterCard({required this.store, required this.pal});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [pal.emerald900, pal.emerald700],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: pal.emerald900.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'لطف خدا رو '),
              TextSpan(
                text: _toFa(store.totalCount),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const TextSpan(text: ' بار شکر کردم'),
            ],
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            height: 1.7,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//                        بنر فاز (theme-banner)
// ═══════════════════════════════════════════════════════════════
class _ThemeBanner extends StatelessWidget {
  final GratitudePhaseInfo info;
  final GratPalette pal;
  const _ThemeBanner({required this.info, required this.pal});

  @override
  Widget build(BuildContext context) {
    final pct = (info.day / info.totalDays).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [pal.emerald900, pal.emerald700],
            ),
          ),
          child: Stack(
            children: [
              // درخشش طلایی
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        pal.gold300.withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '🧭 دوره‌ی ${_toFa(info.totalDays)} روزه — ${info.phaseShort}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          'روز ${_toFa(info.day)} / ${_toFa(info.totalDays)}',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'فاز ${_toFa(info.phaseIndex + 1)} — ${info.phaseName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '🎯 ${info.prompt}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 5,
                        color: Colors.white.withValues(alpha: 0.2),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FractionallySizedBox(
                            widthFactor: pct,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [pal.gold300, pal.gold500],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//                        تقویم کوچک (15 ستون)
// ═══════════════════════════════════════════════════════════════
class _MiniCalendar extends StatelessWidget {
  final GratitudeStore store;
  final GratPalette pal;
  const _MiniCalendar({required this.store, required this.pal});

  static const _monthOrd = [
    'اول', 'دوم', 'سوم', 'چهارم', 'پنجم', 'ششم', 'هفتم',
    'هشتم', 'نهم', 'دهم', 'یازدهم', 'دوازدهم', 'سیزدهم',
  ];

  @override
  Widget build(BuildContext context) {
    final start = _parseKey(store.journeyStart);
    final total = store.journeyDays;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayKey = _key(today);

    final doneSet = <String>{};
    for (final e in store.entries) {
      if (e.source == 'purchase') continue;
      final k = GratitudeStore.isoToKey(e.iso);
      if (k.isNotEmpty) doneSet.add(k);
    }

    const cols = 15;
    const blockSize = 30;
    final cells = <Widget>[];

    for (var d = 0; d < total; d++) {
      final date = DateTime(start.year, start.month, start.day + d);
      final key = _key(date);
      final has = doneSet.contains(key);
      final future = date.isAfter(today);
      final isToday = key == todayKey;
      final monthEnd =
          (d % blockSize == blockSize - 1) || (d == total - 1);

      if (d % blockSize == 0) {
        final endIdx = (d + blockSize - 1).clamp(0, total - 1);
        final endDate =
            DateTime(start.year, start.month, start.day + endIdx);
        final jFrom = _toJalali(date.year, date.month, date.day);
        final jTo = _toJalali(endDate.year, endDate.month, endDate.day);
        final ordIdx = d ~/ blockSize;
        cells.add(_MonthHeader(
          pal: pal,
          label: 'ماه ${ordIdx < _monthOrd.length ? _monthOrd[ordIdx] : _toFa(ordIdx + 1)}',
          range:
              '${_toFa(jFrom.$3)} ${_jalaliMonths[jFrom.$2 - 1]} تا ${_toFa(jTo.$3)} ${_jalaliMonths[jTo.$2 - 1]}',
        ));
      }

      // رنگ احساس غالب روی این روز (حلقهٔ ۲px)
      final hex = store.dominantEmotionColorForDay(key);
      Color? ring;
      if (hex != null) {
        try {
          final h = hex.replaceFirst('#', '');
          ring = Color(int.parse('FF$h', radix: 16));
        } catch (_) {}
      }

      cells.add(_DayCell(
        pal: pal,
        done: has,
        today: isToday,
        future: future,
        monthEnd: monthEnd,
        ring: ring,
        onTap: has
            ? () => _openDayEmotions(context, store, key)
            : null,
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: pal.surface,
          border: Border.all(color: pal.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: LayoutBuilder(builder: (ctx, box) {
          const gap = 3.0;
          final cellW = (box.maxWidth - (cols - 1) * gap) / cols;
          final size = cellW.clamp(16.0, 26.0);

          final rows = <Widget>[];
          var i = 0;
          while (i < cells.length) {
            final row = <Widget>[];
            while (row.length < cols && i < cells.length) {
              final c = cells[i];
              if (c is _MonthHeader) {
                // هدر ماه کل ردیف را می‌گیرد
                if (row.isNotEmpty) {
                  rows.add(_row(row, gap, size));
                  row.clear();
                }
                rows.add(c);
                i++;
              } else {
                row.add(SizedBox(
                  width: size,
                  height: size,
                  child: c,
                ));
                i++;
              }
            }
            if (row.isNotEmpty) rows.add(_row(row, gap, size));
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          );
        }),
      ),
    );
  }

  Widget _row(List<Widget> items, double gap, double size) {
    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Row(
        children: [
          for (var j = 0; j < items.length; j++) ...[
            items[j],
            if (j < items.length - 1) SizedBox(width: gap),
          ],
        ],
      ),
    );
  }

  static const _jalaliMonths = [
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
  ];

  static DateTime _parseKey(String k) {
    final p = k.split('-').map((e) => int.tryParse(e) ?? 1).toList();
    if (p.length != 3) return DateTime.now();
    return DateTime(p[0], p[1], p[2]);
  }

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static (int, int, int) _toJalali(int gy, int gm, int gd) {
    const gDaysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    final gy2 = (gm > 2) ? gy + 1 : gy;
    var days = 355666 +
        365 * gy +
        ((gy2 + 3) ~/ 4) -
        ((gy2 + 99) ~/ 100) +
        ((gy2 + 399) ~/ 400) +
        gd;
    for (var i = 0; i < gm - 1; i++) {
      days += gDaysInMonth[i];
    }
    var jy = -1595 + 33 * (days ~/ 12053);
    days %= 12053;
    jy += 4 * (days ~/ 1461);
    days %= 1461;
    if (days > 365) {
      jy += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }
    final jm = (days < 186) ? 1 + days ~/ 31 : 7 + (days - 186) ~/ 30;
    final jd = 1 + ((days < 186) ? days % 31 : (days - 186) % 30);
    return (jy, jm, jd);
  }
}

class _MonthHeader extends StatelessWidget {
  final String label;
  final String range;
  final GratPalette pal;
  const _MonthHeader({required this.label, required this.range, required this.pal});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: pal.ink,
              )),
          const Spacer(),
          Text(range,
              style: TextStyle(fontSize: 10.5, color: pal.muted)),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final bool done, today, future, monthEnd;
  final Color? ring;
  final VoidCallback? onTap;
  final GratPalette pal;
  const _DayCell({
    required this.pal,
    required this.done,
    required this.today,
    required this.future,
    required this.monthEnd,
    required this.ring,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: future ? 0.3 : 1,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: done
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [pal.emerald700, pal.emerald500],
                  )
                : null,
            border: Border.all(
              color: today ? pal.emerald500 : pal.line,
              width: today ? 1.5 : 1,
            ),
            boxShadow: [
              if (ring != null)
                BoxShadow(
                  color: ring!,
                  spreadRadius: 1,
                  blurRadius: 0,
                ),
              if (monthEnd)
                BoxShadow(
                  color: pal.gold500,
                  offset: const Offset(0, 3),
                  blurRadius: 0,
                  spreadRadius: -1,
                ),
            ],
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.check, size: 11, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

// دکمهٔ مشاهده/ویرایش احساسات روز
void _openDayEmotions(
    BuildContext context, GratitudeStore store, String dayKey) {
  final pal = GratPalette.of(context);
  final current = store.emotionIdsForDay(dayKey).toList();
  final selected = <String>{...current};
  final emotions = context.read<EmotionStore>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (_, setSheet) => Container(
        decoration: BoxDecoration(
          color: pal.paper,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('💗 حس‌های این روز',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: pal.ink,
                    )),
                const SizedBox(height: 4),
                Text(dayKey,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: pal.muted)),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                  ),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: kEmotions.map((e) {
                        final on = selected.contains(e.id);
                        final color = hexToColor(e.color);
                        return GestureDetector(
                          onTap: () => setSheet(() {
                            if (on) {
                              selected.remove(e.id);
                            } else {
                              selected.add(e.id);
                            }
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: on
                                  ? color.withValues(alpha: 0.18)
                                  : pal.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: on ? color : pal.line,
                                width: on ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(e.fa,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: on ? color : pal.ink,
                                    )),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: pal.emerald700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      await store
                          .updateDayEmotions(dayKey, selected.toList());
                      if (mounted_) Navigator.pop(ctx);
                    },
                    child: const Text('ذخیره',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// چون این تابع خارج از State است، برای راحتی
bool get mounted_ => true;

// ═══════════════════════════════════════════════════════════════
//                        کمپوزر (ورودی جدید)
// ═══════════════════════════════════════════════════════════════
class _Composer extends StatelessWidget {
  final GratPalette pal;
  final TextEditingController textCtrl;
  final FocusNode textFocus;
  final List<GratitudeImage> images;
  final List<GratitudeAudio> audios;
  final List<GratitudeVideo> videos;
  final bool share;
  final ValueChanged<bool> onShareChanged;
  final VoidCallback onPickImages;
  final VoidCallback onPickVideos;
  final VoidCallback onRecordAudio;
  final ValueChanged<int> onRemoveImage;
  final ValueChanged<int> onRemoveAudio;
  final ValueChanged<int> onRemoveVideo;
  final VoidCallback onSubmit;

  const _Composer({
    required this.pal,
    required this.textCtrl,
    required this.textFocus,
    required this.images,
    required this.audios,
    required this.videos,
    required this.share,
    required this.onShareChanged,
    required this.onPickImages,
    required this.onPickVideos,
    required this.onRecordAudio,
    required this.onRemoveImage,
    required this.onRemoveAudio,
    required this.onRemoveVideo,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: pal.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: pal.emerald300.withValues(alpha: 0.55), width: 1.5),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [pal.card, pal.surface],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text.rich(
              const TextSpan(children: [
                TextSpan(text: 'خدایا شکرت که:'),
              ]),
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: pal.emerald700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: textCtrl,
              focusNode: textFocus,
              maxLines: null,
              minLines: 3,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 14, color: pal.ink, height: 1.7),
              decoration: InputDecoration(
                hintText: 'نعمت امروزت رو بنویس...',
                hintStyle: TextStyle(color: pal.muted, fontSize: 13),
                filled: true,
                fillColor: pal.surface,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: pal.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: pal.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: pal.emerald500, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _MediaBtn(
                  pal: pal,
                  icon: Icons.image_outlined,
                  onTap: onPickImages,
                ),
                const SizedBox(width: 8),
                _MediaBtn(
                  pal: pal,
                  icon: Icons.videocam_outlined,
                  onTap: onPickVideos,
                ),
                const SizedBox(width: 8),
                _MediaBtn(
                  pal: pal,
                  icon: Icons.mic_none_outlined,
                  onTap: onRecordAudio,
                ),
              ],
            ),
            if (images.isNotEmpty) ...[
              const SizedBox(height: 10),
              _ThumbGrid(
                images: images,
                pal: pal,
                onRemove: onRemoveImage,
              ),
            ],
            if (audios.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...audios.asMap().entries.map((e) => _AudioRow(
                    audio: e.value,
                    pal: pal,
                    onRemove: () => onRemoveAudio(e.key),
                  )),
            ],
            if (videos.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...videos.asMap().entries.map((e) => _VideoTile(
                    video: e.value,
                    pal: pal,
                    onRemove: () => onRemoveVideo(e.key),
                  )),
            ],
            const SizedBox(height: 10),
            _VisibilityRow(
              value: share,
              pal: pal,
              onChanged: onShareChanged,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 46,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: pal.emerald700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: onSubmit,
                child: const Text('ثبت شکرگذاری',
                    style: TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final GratPalette pal;
  const _MediaBtn({required this.icon, required this.onTap, required this.pal});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: pal.surface,
      borderRadius: BorderRadius.circular(50),
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: pal.emerald300),
          ),
          child: Icon(icon, color: pal.emerald700, size: 22),
        ),
      ),
    );
  }
}

class _ThumbGrid extends StatelessWidget {
  final List<GratitudeImage> images;
  final ValueChanged<int> onRemove;
  final GratPalette pal;
  const _ThumbGrid({
    required this.images,
    required this.onRemove,
    required this.pal,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: images.asMap().entries.map((e) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: pal.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: pal.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: _imgFromSrc(e.value.src),
            ),
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                onTap: () => onRemove(e.key),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: pal.danger,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.close,
                      size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _AudioRow extends StatelessWidget {
  final GratitudeAudio audio;
  final VoidCallback onRemove;
  final GratPalette pal;
  const _AudioRow({
    required this.audio,
    required this.onRemove,
    required this.pal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: pal.line),
      ),
      child: Row(
        children: [
          Icon(Icons.graphic_eq, size: 16, color: pal.emerald700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(audio.name.isEmpty ? 'صدا' : audio.name,
                style: TextStyle(fontSize: 11.5, color: pal.muted)),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pal.surface2,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.close, size: 13, color: pal.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final GratitudeVideo video;
  final VoidCallback onRemove;
  final GratPalette pal;
  const _VideoTile({
    required this.video,
    required this.onRemove,
    required this.pal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: pal.line),
      ),
      child: Row(
        children: [
          Icon(Icons.videocam_outlined, size: 18, color: pal.emerald700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              video.name.isEmpty ? 'ویدیو' : video.name,
              style: TextStyle(fontSize: 11.5, color: pal.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pal.surface2,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.close, size: 13, color: pal.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisibilityRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final GratPalette pal;
  const _VisibilityRow({
    required this.value,
    required this.onChanged,
    required this.pal,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _radio(
          label: 'فقط برای خودم',
          icon: Icons.lock_outline,
          active: !value,
          onTap: () => onChanged(false),
        ),
        const SizedBox(width: 14),
        _radio(
          label: 'اشتراک با بقیه',
          icon: Icons.public,
          active: value,
          onTap: () => onChanged(true),
        ),
      ],
    );
  }

  Widget _radio({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? pal.emerald500 : pal.line,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: active
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: pal.emerald500,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Icon(icon,
              size: 14, color: active ? pal.emerald700 : pal.muted),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                fontSize: 12.5,
                color: active ? pal.emerald700 : pal.muted,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//                        یک ردیف ورودی
// ═══════════════════════════════════════════════════════════════
class _EntryRow extends StatelessWidget {
  final GratitudeEntry entry;
  final GratitudeStore store;
  final GratPalette pal;
  final VoidCallback onTap;

  const _EntryRow({
    required this.entry,
    required this.store,
    required this.pal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final display = entry.displayText();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
      child: Material(
        color: pal.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: pal.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: pal.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: pal.line),
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: _entryIcon(entry),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        display,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: pal.ink,
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${entry.day} ${entry.date} - ${entry.time}',
                        style: TextStyle(fontSize: 11.5, color: pal.muted),
                      ),
                      if (entry.images.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _EntryImageGrid(images: entry.images, pal: pal),
                      ],
                      if (entry.audios.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        ...entry.audios.map((a) => _AudioRow(
                              audio: a,
                              pal: pal,
                              onRemove: () {},
                            )),
                      ],
                      if (entry.videos.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        ...entry.videos.map((v) => _VideoTile(
                              video: v,
                              pal: pal,
                              onRemove: () {},
                            )),
                      ],
                    ],
                  ),
                ),
                if (entry.amount != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      _formatMoney(entry.amount!),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: pal.emerald700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _entryIcon(GratitudeEntry g) {
    if (g.images.isNotEmpty) {
      return _imgFromSrc(g.images.first.src);
    }
    return Text(
      g.icon.isEmpty ? '🙏' : g.icon,
      style: const TextStyle(fontSize: 20),
    );
  }

  String _formatMoney(double v) {
    final rounded = v.round();
    return '${_toFa3(rounded)} تومان';
  }
}

class _EntryImageGrid extends StatelessWidget {
  final List<GratitudeImage> images;
  final GratPalette pal;
  const _EntryImageGrid({required this.images, required this.pal});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: images.map((im) {
        return GestureDetector(
          onTap: () => _openImageViewer(context, images, images.indexOf(im)),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: pal.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: pal.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: _imgFromSrc(im.src),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//                        متفرقه
// ═══════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  final GratPalette pal;
  const _SectionLabel({
    required this.icon,
    required this.title,
    required this.pal,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: pal.emerald500.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 14, color: pal.emerald700),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: pal.ink,
                )),
          ),
          if (trailing != null)
            Text(trailing!,
                style: TextStyle(
                    fontSize: 11.5,
                    color: pal.muted,
                    fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final GratPalette pal;
  const _GhostButton({
    required this.text,
    required this.onTap,
    required this.pal,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: pal.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: pal.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: pal.ink,
              )),
        ),
      ),
    );
  }
}

// ─── fallback ضبط صدا (اگر voice_recorder_sheet نبود) ───
class _VoiceFallbackSheet extends StatelessWidget {
  const _VoiceFallbackSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: const Text(
        'برای ضبط صدا، voice_recorder_sheet را وصل کن.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13),
      ),
    );
  }
}

// ─── نمایشگر ساده تصویر ───
void _openImageViewer(
    BuildContext context, List<GratitudeImage> images, int initial) {
  showDialog(
    context: context,
    builder: (_) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: PageController(initialPage: initial),
            itemCount: images.length,
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(child: _imgFromSrc(images[i].src)),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── decode data URL یا file path به Image ───
Widget _imgFromSrc(String src) {
  if (src.isEmpty) return const SizedBox.shrink();
  if (src.startsWith('data:')) {
    try {
      final bytes = base64Decode(src.substring(src.indexOf(',') + 1));
      return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    } catch (_) {
      return const Icon(Icons.broken_image, color: Colors.grey);
    }
  }
  // file path
  return Image.asset(src, fit: BoxFit.cover, errorBuilder: (_, __, ___) =>
      const Icon(Icons.broken_image, color: Colors.grey));
}

// ─── تبدیل عدد به فارسی ───
String _toFa(int n) => n.toString().replaceAllMapped(
      RegExp(r'\d'),
      (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m.group(0)!)],
    );

String _toFa3(num n) => n.round().toString().replaceAllMapped(
      RegExp(r'\d'),
      (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m.group(0)!)],
    ).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
