import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/gratitude_journey.dart';
import '../models/emotion.dart';
import '../models/gratitude_entry.dart';
import '../state/emotion_store.dart';
import '../state/gratitude_store.dart';
import '../theme/grat_palette.dart';
import '../widgets/audio_player_box.dart';
import '../widgets/gratitude_slideshow.dart';
import '../widgets/neural_pathway.dart';
import '../widgets/voice_recorder_sheet.dart';
import '../services/media_db.dart';

// ════════════════════════════════════════════════════════════════
class GratitudeTab extends StatefulWidget {
  const GratitudeTab({super.key});
  @override
  State<GratitudeTab> createState() => _GratitudeTabState();
}

class _GratitudeTabState extends State<GratitudeTab> {
  final _scrollCtrl = ScrollController();
  final _textCtrl = TextEditingController();
  final List<GratitudeImage> _pendingImages = [];
  final List<GratitudeAudio> _pendingAudios = [];
  final List<GratitudeVideo> _pendingVideos = [];
  bool _pendingShare = false;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

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
            _ThemeBanner(info: info, pal: pal, pastCount: store.pastPeriods.length),
            const SizedBox(height: 14),
            _MiniCalendar(store: store, pal: pal),
            const SizedBox(height: 14),
            _Composer(
              pal: pal,
              prompt: info.prompt,
              number: store.totalCount + 1,
              onRecord: _recordVoice,
              textCtrl: _textCtrl,
              images: _pendingImages,
              audios: _pendingAudios,
              videos: _pendingVideos,
              share: _pendingShare,
              onShareChanged: (v) => setState(() => _pendingShare = v),
              onPickImages: _pickImages,
              onPickVideos: _pickVideos,
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
                webStyle: true,
                container: store.neural,
                label: 'شکرگذاری',
                showDayButtons: false,
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

  int? _emotionQualityToday(GratitudeStore store) => store.emotionQualityToday;

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
              pal: pal,
              onTap: () => _openEditor(context, g),
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

  // ─── افزودن ───
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

    // 🔑 ثبت خودکار رشته‌ی عصبی (با رنگ حسِ انتخاب‌شده روی ادمک؛ بعدش ادمک ریست می‌شه)
    await store.add(
      text: text,
      images: List.of(_pendingImages),
      audios: List.of(_pendingAudios),
      videos: List.of(_pendingVideos),
      shared: _pendingShare,
      emotions: emotions,
    );

    final wasShared = _pendingShare;
    final saved = store.lastPersistOk;
    setState(() {
      _textCtrl.clear();
      _pendingImages.clear();
      _pendingAudios.clear();
      _pendingVideos.clear();
      _pendingShare = false;
    });
    _toast(!saved
        ? 'ثبت شد، ولی حافظه‌ی مرورگر پر شده — با بستن صفحه ممکنه از دست بره. عکس/صدای قدیمی رو پاک کن'
        : (wasShared
            ? 'ثبت شد و با بقیه به اشتراک گذاشته شد 🌍'
            : 'ثبت شد — فقط برای خودم 🤫'));
  }

  /// ضبط ویس برای شکرگذاری (دکمه‌ی میکروفون وب)
  Future<void> _recordVoice() async {
    final src =
        await VoiceRecorderSheet.show(context, title: 'ضبط ویس شکرگذاری');
    if (!mounted || src == null) return;
    setState(() => _pendingAudios
        .add(GratitudeAudio(src: src, name: 'ویس ضبط‌شده')));
  }

  Future<void> _pickImages() async {
    try {
      final files =
          await _picker.pickMultiImage(imageQuality: 82, maxWidth: 1400);
      if (files.isEmpty) return;
      for (final f in files) {
        final bytes = await f.readAsBytes();
        final ref = await MediaDb.putBytes(bytes, 'image/jpeg');
        if (!mounted) return;
        setState(() => _pendingImages.add(GratitudeImage(src: ref)));
      }
    } catch (e) {
      _toast('عکس اضافه نشد');
    }
  }

  Future<void> _pickVideos() async {
    try {
      final f = await _picker.pickVideo(source: ImageSource.gallery);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (bytes.length > 100 * 1024 * 1024) {
        _toast('ویدیو بزرگ‌تر از ۱۰۰ مگابایت ذخیره نمی‌شه');
        return;
      }
      final ref = await MediaDb.putBytes(bytes, 'video/mp4');
      if (!mounted) return;
      setState(() => _pendingVideos.add(GratitudeVideo(
            path: ref,
            name: f.name,
            size: bytes.length,
          )));
    } catch (e) {
      _toast('ویدیو اضافه نشد');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(milliseconds: 1600),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ─── ویرایش ───
  void _openEditor(BuildContext context, GratitudeEntry g) {
    final pal = GratPalette.of(context);
    final editCtrl = TextEditingController(text: g.text);
    final images = List.of(g.images);
    final audios = List.of(g.audios);
    final videos = List.of(g.videos);
    bool share = g.shared;
    final isPurchase = g.source == 'purchase';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheet) {
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
                  bottom: MediaQuery.of(ctx2).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        controller: editCtrl,
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
                      if (images.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: images.asMap().entries.map((e) {
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
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
                                    onTap: () =>
                                        setSheet(() => images.removeAt(e.key)),
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
                        ),
                      ],
                      for (var i = 0; i < audios.length; i++) ...[
                        const SizedBox(height: 10),
                        AudioPlayerBox(
                          src: audios[i].src,
                          name: audios[i].name,
                          onRemove: () => setSheet(() => audios.removeAt(i)),
                        ),
                      ],
                      const SizedBox(height: 14),
                      if (!isPurchase)
                        Row(
                          children: [
                            _radioBtn('فقط برای خودم', Icons.lock_outline,
                                !share, () => setSheet(() => share = false), pal),
                            const SizedBox(width: 14),
                            _radioBtn('اشتراک', Icons.public, share,
                                () => setSheet(() => share = true), pal),
                          ],
                        ),
                      const SizedBox(height: 12),
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
                            await context.read<GratitudeStore>().update(
                                  g.id,
                                  text: editCtrl.text.trim(),
                                  images: images,
                                  audios: audios,
                                  videos: videos,
                                  shared: share,
                                );
                            if (context.mounted) Navigator.pop(ctx);
                            _toast('ویرایش شد ✏️');
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
                            context: ctx2,
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
                                      backgroundColor: pal.danger),
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
                            if (context.mounted) Navigator.pop(ctx);
                            _toast('حذف شد 🗑');
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

  static Widget _radioBtn(
    String label,
    IconData icon,
    bool active,
    VoidCallback onTap,
    GratPalette pal,
  ) {
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
          Icon(icon, size: 14, color: active ? pal.emerald700 : pal.muted),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: active ? pal.emerald700 : pal.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//                       کارت شمارنده
// ════════════════════════════════════════════════════════════════
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
                    fontSize: 20, fontWeight: FontWeight.w900),
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

// ════════════════════════════════════════════════════════════════
//                       بنر فاز
// ════════════════════════════════════════════════════════════════
class _ThemeBanner extends StatelessWidget {
  final GratitudePhaseInfo info;
  final GratPalette pal;
  final int pastCount;
  const _ThemeBanner(
      {required this.info, required this.pal, this.pastCount = 0});

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
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      pal.gold300.withValues(alpha: 0.35),
                      Colors.transparent,
                    ]),
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
                            '🧭 دوره‌ی ${pastCount > 0 ? '${_MiniCalendar.ord(pastCount)} — ' : ''}${_toFa(info.totalDays)} روزه — ${info.phaseShort}',
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
                                    colors: [pal.gold300, pal.gold500]),
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

// ════════════════════════════════════════════════════════════════
//                       تقویم کوچک ۱۵ستونی
// ════════════════════════════════════════════════════════════════
class _MiniCalendar extends StatelessWidget {
  final GratitudeStore store;
  final GratPalette pal;
  const _MiniCalendar({required this.store, required this.pal});

  static const _monthOrd = [
    'اول', 'دوم', 'سوم', 'چهارم', 'پنجم', 'ششم', 'هفتم',
    'هشتم', 'نهم', 'دهم', 'یازدهم', 'دوازدهم',
  ];
  static const _jalaliMonths = [
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
  ];

  static String ord(int i) =>
      i >= 0 && i < _monthOrd.length ? _monthOrd[i] : _toFa(i + 1);

  @override
  Widget build(BuildContext context) {
    final start = _parseKey(store.journeyStart);
    final total = store.journeyDays;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final doneSet = store.doneDayKeys;

    final grid = _PeriodGrid(
      pal: pal,
      store: store,
      start: start,
      total: total,
      doneSet: doneSet,
      withEmotions: true,
      onTapDone: (k) => _openDayEmotions(context, store, k),
    );

    // دوره تموم شده؟ (today >= start + total)
    final end = DateTime(start.year, start.month, start.day + total);
    final finished = !today.isBefore(end);
    var doneCount = 0;
    for (var d = 0; d < total; d++) {
      if (doneSet.contains(_key(DateTime(start.year, start.month, start.day + d)))) {
        doneCount++;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: pal.surface,
              border: Border.all(color: pal.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: grid,
          ),
          const SizedBox(height: 10),
          if (finished) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFE6CD8E).withValues(alpha: 0.25),
                border: Border.all(color: pal.gold300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '🎉🥳 دوره‌ی ${ord(store.pastPeriods.length)} رو تموم کردی! '
                '${_toFa(doneCount < total ? doneCount : total)} روز از ${_toFa(total)} روز شکرگذاری کردی.\n'
                'برای ادامه دوره‌ی بعدی رو شروع کن — دوره‌های قبلی همین‌جا می‌مونن.',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.8,
                  color: pal.ink,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _TinyBtn(
              pal: pal,
              gold: true,
              label: '▶️ شروع دوره‌ی ${ord(store.pastPeriods.length + 1)}',
              onTap: () => _askDays(
                context,
                title: 'دوره‌ی ${ord(store.pastPeriods.length + 1)} چند روزه باشه؟',
                initial: total,
                onOk: (n) async {
                  await store.startNewJourney(days: n);
                  _snack(context, 'دوره‌ی ${ord(store.pastPeriods.length)} شروع شد 🌱');
                },
              ),
            ),
          ] else
            _TinyBtn(
              pal: pal,
              icon: Icons.light_mode_outlined,
              label: 'روزهای دوره (الان ${_toFa(total)} روزه)',
              onTap: () => _askDays(
                context,
                title: 'دوره‌ی ${ord(store.pastPeriods.length)} چند روزه باشه؟',
                initial: total,
                onOk: (n) async {
                  await store.setJourneyDays(n);
                  _snack(context, 'دوره روی ${_toFa(n)} روز تنظیم شد 🌱');
                },
              ),
            ),
          if (store.pastPeriods.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (var i = store.pastPeriods.length - 1; i >= 0; i--) ...[
              _PastPeriod(
                pal: pal,
                store: store,
                index: i,
                doneSet: doneSet,
              ),
              if (i > 0) const SizedBox(height: 6),
            ],
          ],
        ],
      ),
    );
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(milliseconds: 1600),
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// معادل window.prompt وب برای تعداد روزهای دوره
  static Future<void> _askDays(
    BuildContext context, {
    required String title,
    required int initial,
    required Future<void> Function(int n) onOk,
  }) async {
    final ctrl = TextEditingController(text: '$initial');
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 14)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          textDirection: TextDirection.ltr,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(_normDigits(ctrl.text.trim()));
              Navigator.pop(ctx, (v != null && v >= 1) ? v : -1);
            },
            child: const Text('تأیید'),
          ),
        ],
      ),
    );
    if (n == null) return;
    if (n < 1) {
      if (context.mounted) _snack(context, 'یه عدد معتبر بزرگ‌تر از صفر وارد کن');
      return;
    }
    await onOk(n);
  }

  static String _normDigits(String s) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    final b = StringBuffer();
    for (final c in s.split('')) {
      final i = fa.indexOf(c);
      final j = ar.indexOf(c);
      b.write(i >= 0 ? '$i' : (j >= 0 ? '$j' : c));
    }
    return b.toString();
  }

  static DateTime _parseKey(String k) {
    final p = k.split('-').map((e) => int.tryParse(e) ?? 1).toList();
    if (p.length != 3) return DateTime.now();
    return DateTime(p[0], p[1], p[2]);
  }

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static (int, int, int) _toJalali(int gy, int gm, int gd) {
    const gDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    final gy2 = (gm > 2) ? gy + 1 : gy;
    var days = 355666 +
        365 * gy +
        ((gy2 + 3) ~/ 4) -
        ((gy2 + 99) ~/ 100) +
        ((gy2 + 399) ~/ 400) +
        gd;
    for (var i = 0; i < gm - 1; i++) {
      days += gDays[i];
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

/// شبکه‌ی ۱۵ ستونه‌ی یک دوره — periodGridHtml وب
class _PeriodGrid extends StatelessWidget {
  final GratPalette pal;
  final GratitudeStore store;
  final DateTime start;
  final int total;
  final Set<String> doneSet;
  final bool withEmotions;
  final void Function(String dayKey)? onTapDone;

  const _PeriodGrid({
    required this.pal,
    required this.store,
    required this.start,
    required this.total,
    required this.doneSet,
    this.withEmotions = false,
    this.onTapDone,
  });

  static const cols = 15;
  static const gap = 3.0;
  static const blockSize = 30;

  @override
  Widget build(BuildContext context) {
    // اندازه‌ی سلول از عرض واقعی ساخته می‌شه (۱۵ ستون + ۱۴ فاصله) تا هیچ‌وقت
    // از کادر بیرون نزنه.
    return LayoutBuilder(builder: (ctx, box) {
      final avail = box.maxWidth.isFinite ? box.maxWidth : 300.0;
      final cell = ((avail - gap * (cols - 1) - 0.5) / cols)
          .clamp(8.0, 60.0)
          .toDouble();
      return _buildGrid(context, cell);
    });
  }

  Widget _buildGrid(BuildContext context, double cell) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayKey = _MiniCalendar._key(today);

    final children = <Widget>[];
    var row = <Widget>[];

    void flush() {
      if (row.isEmpty) return;
      while (row.length < cols) {
        row.add(SizedBox(width: cell, height: cell));
      }
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: gap),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            for (var i = 0; i < row.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              row[i],
            ],
          ],
        ),
      ));
      row = <Widget>[];
    }

    for (var d = 0; d < total; d++) {
      final date = DateTime(start.year, start.month, start.day + d);
      final key = _MiniCalendar._key(date);

      if (d % blockSize == 0) {
        flush();
        final endIdx = (d + blockSize - 1) < total ? d + blockSize - 1 : total - 1;
        final endDate = DateTime(start.year, start.month, start.day + endIdx);
        final jF = _MiniCalendar._toJalali(date.year, date.month, date.day);
        final jT = _MiniCalendar._toJalali(endDate.year, endDate.month, endDate.day);
        children.add(Padding(
          padding: EdgeInsets.only(top: d == 0 ? 0 : 8, bottom: 3),
          child: Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ماه ${_MiniCalendar.ord(d ~/ blockSize)}',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: pal.ink)),
              Text(
                '${_toFa(jF.$3)} ${_MiniCalendar._jalaliMonths[jF.$2 - 1]} تا '
                '${_toFa(jT.$3)} ${_MiniCalendar._jalaliMonths[jT.$2 - 1]}',
                style: TextStyle(fontSize: 10.5, color: pal.muted),
              ),
            ],
          ),
        ));
      }

      final done = doneSet.contains(key);
      final monthEnd = (d % blockSize == blockSize - 1) || d == total - 1;
      Color? ring;
      if (withEmotions) {
        final hex = store.dayRingColor(key);
        if (hex != null) {
          try {
            ring = Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
          } catch (_) {}
        }
      }

      row.add(SizedBox(
        width: cell,
        height: cell,
        child: _DayCell(
          pal: pal,
          done: done,
          today: key == todayKey,
          future: date.isAfter(today),
          monthEnd: monthEnd,
          ring: ring,
          onTap: (done && onTapDone != null) ? () => onTapDone!(key) : null,
        ),
      ));
      if (row.length == cols) flush();
    }
    flush();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// یک روز — .mini-cal-day وب
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
    this.ring,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasRing = ring != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: future ? 0.3 : 1,
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(builder: (ctx, box) {
            final r = BorderRadius.circular(4);
            return Container(
              decoration: BoxDecoration(
                borderRadius: r,
                gradient: done
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [pal.emerald700, pal.emerald500],
                      )
                    : null,
                // box-shadow: inset 0 0 0 1px line  (فقط وقتی done/حلقه نیست)
                border: (done || hasRing)
                    ? null
                    : Border.all(color: pal.line, width: 1),
                boxShadow: [
                  if (today)
                    BoxShadow(
                        color: pal.emerald500,
                        spreadRadius: hasRing ? 3.5 : 1.5,
                        blurRadius: 0),
                  if (hasRing)
                    BoxShadow(color: ring!, spreadRadius: 2, blurRadius: 0),
                ],
              ),
              child: ClipRRect(
                borderRadius: r,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (done)
                      Icon(Icons.check,
                          size: box.maxWidth * 0.62, color: Colors.white),
                    if (monthEnd && !hasRing)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 3,
                        child: ColoredBox(color: pal.gold500),
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// دکمه‌ی .btn.tiny وب
class _TinyBtn extends StatelessWidget {
  final GratPalette pal;
  final String label;
  final IconData? icon;
  final bool gold;
  final VoidCallback onTap;
  const _TinyBtn({
    required this.pal,
    required this.label,
    required this.onTap,
    this.icon,
    this.gold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: gold ? pal.accent : pal.card,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: gold ? pal.accent : pal.line),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: pal.ink),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: gold ? FontWeight.w600 : FontWeight.w400,
                  color: gold ? const Color(0xFF221800) : pal.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// دوره‌ی تمام‌شده‌ی قبلی — details.mini-cal-past وب
class _PastPeriod extends StatefulWidget {
  final GratPalette pal;
  final GratitudeStore store;
  final int index;
  final Set<String> doneSet;
  const _PastPeriod({
    required this.pal,
    required this.store,
    required this.index,
    required this.doneSet,
  });

  @override
  State<_PastPeriod> createState() => _PastPeriodState();
}

class _PastPeriodState extends State<_PastPeriod> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final pal = widget.pal;
    final pd = widget.store.pastPeriods[widget.index];
    final days = (pd['days'] as int?) ?? 28;
    final start = _MiniCalendar._parseKey(pd['startDate']?.toString() ?? '');
    var done = 0;
    for (var d = 0; d < days; d++) {
      if (widget.doneSet.contains(
          _MiniCalendar._key(DateTime(start.year, start.month, start.day + d)))) {
        done++;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: pal.surface,
        border: Border.all(color: pal.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = !_open),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '✅ دوره‌ی ${_MiniCalendar.ord(widget.index)} — ${_toFa(days)} روزه',
                  style: TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w800, color: pal.ink),
                ),
                Text(
                  '${_toFa(done)} / ${_toFa(days)}',
                  style: TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w800, color: pal.ink),
                ),
              ],
            ),
          ),
          if (_open) ...[
            const SizedBox(height: 10),
            _PeriodGrid(
              pal: pal,
              store: widget.store,
              start: start,
              total: days,
              doneSet: widget.doneSet,
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//                مودال ویرایش احساسات یک روز
// ════════════════════════════════════════════════════════════════
void _openDayEmotions(
  BuildContext context,
  GratitudeStore store,
  String dayKey,
) {
  final pal = GratPalette.of(context);
  final current = store.emotionIdsForDay(dayKey).toList();
  final selected = <String>{...current};

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
                  '💗 حس‌های این روز',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: pal.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dayKey,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: pal.muted),
                ),
                const SizedBox(height: 14),
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
                        final color = _hex(e.color);
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
                                Text(
                                  e.fa,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: on ? color : pal.ink,
                                  ),
                                ),
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
                      // 🔑 این باعث می‌شود رنگ روز فوراً در تقویم عوض شود
                      await store.updateDayEmotions(
                        dayKey,
                        selected.toList(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
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

Color _hex(String hex) {
  try {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  } catch (_) {
    return const Color(0xFF2BBFAB);
  }
}

// ════════════════════════════════════════════════════════════════
//                       Composer
// ════════════════════════════════════════════════════════════════
class _Composer extends StatelessWidget {
  final GratPalette pal;
  final String prompt;
  final int number;
  final VoidCallback onRecord;
  final TextEditingController textCtrl;
  final List<GratitudeImage> images;
  final List<GratitudeAudio> audios;
  final List<GratitudeVideo> videos;
  final bool share;
  final ValueChanged<bool> onShareChanged;
  final VoidCallback onPickImages;
  final VoidCallback onPickVideos;
  final ValueChanged<int> onRemoveImage;
  final ValueChanged<int> onRemoveAudio;
  final ValueChanged<int> onRemoveVideo;
  final VoidCallback onSubmit;

  const _Composer({
    required this.pal,
    required this.prompt,
    required this.number,
    required this.onRecord,
    required this.textCtrl,
    required this.images,
    required this.audios,
    required this.videos,
    required this.share,
    required this.onShareChanged,
    required this.onPickImages,
    required this.onPickVideos,
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
              TextSpan(children: [
                TextSpan(text: '${_toFa(number)} - خدایا شکرت که:'),
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
              maxLines: null,
              minLines: 3,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 14, color: pal.ink, height: 1.7),
              decoration: InputDecoration(
                hintText: '🎯 $prompt',
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
                    icon: Icons.mic_none_outlined,
                    onTap: onRecord),
                const SizedBox(width: 8),
                _MediaBtn(
                    pal: pal,
                    icon: Icons.videocam_outlined,
                    onTap: onPickVideos),
                const SizedBox(width: 8),
                _MediaBtn(
                    pal: pal,
                    icon: Icons.image_outlined,
                    onTap: onPickImages),
              ],
            ),
            if (images.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: images.asMap().entries.map((e) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
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
                          onTap: () => onRemoveImage(e.key),
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
              ),
            ],
            for (var i = 0; i < audios.length; i++) ...[
              const SizedBox(height: 10),
              AudioPlayerBox(
                src: audios[i].src,
                name: audios[i].name,
                onRemove: () => onRemoveAudio(i),
              ),
            ],
            for (var i = 0; i < videos.length; i++) ...[
              const SizedBox(height: 10),
              _VideoChip(
                pal: pal,
                name: videos[i].name,
                onRemove: () => onRemoveVideo(i),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                _radioBtn('فقط برای خودم', Icons.lock_outline, !share,
                    () => onShareChanged(false), pal),
                const SizedBox(width: 14),
                _radioBtn('اشتراک‌گذاری با بقیه', Icons.public, share,
                    () => onShareChanged(true), pal),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 46,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: pal.ink,
                  side: BorderSide(color: pal.line),
                  backgroundColor: pal.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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

  Widget _radioBtn(
    String label,
    IconData icon,
    bool active,
    VoidCallback onTap,
    GratPalette pal,
  ) {
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
          Icon(icon, size: 14, color: active ? pal.emerald700 : pal.muted),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: active ? pal.emerald700 : pal.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final GratPalette pal;
  const _MediaBtn(
      {required this.icon, required this.onTap, required this.pal});

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

// ════════════════════════════════════════════════════════════════
//                       ردیف شکرگذاری
// ════════════════════════════════════════════════════════════════
class _EntryRow extends StatelessWidget {
  final GratitudeEntry entry;
  final GratPalette pal;
  final VoidCallback onTap;

  const _EntryRow({
    required this.entry,
    required this.pal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                  child: entry.images.isNotEmpty
                      ? _imgFromSrc(entry.images.first.src)
                      : Text(
                          entry.icon.isEmpty ? '🙏' : entry.icon,
                          style: const TextStyle(fontSize: 20),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        entry.displayText(),
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
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: entry.images.map((im) {
                            return GestureDetector(
                              onTap: () =>
                                  _openImageViewer(context, entry.images),
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
                        ),
                      ],
                      for (final a in entry.audios)
                        if (a.src.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: AudioPlayerBox(src: a.src, name: a.name),
                          ),
                      for (final v in entry.videos)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _VideoChip(pal: pal, name: v.name),
                        ),
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

  String _formatMoney(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${_toFa(int.parse(s))} تومان';
  }
}

// ════════════════════════════════════════════════════════════════
//                       اجزای کمکی
// ════════════════════════════════════════════════════════════════
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

// ─── نمایشگر تصویر ───
void _openImageViewer(BuildContext context, List<GratitudeImage> images) {
  showDialog(
    context: context,
    builder: (_) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
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

// ─── decode ───
Widget _imgFromSrc(String src) {
  if (src.isEmpty) return const SizedBox.shrink();
  if (src.startsWith('data:') || MediaDb.isRef(src)) {
    try {
      final bytes = MediaDb.bytes(src);
      if (bytes == null) {
        return const Icon(Icons.broken_image, color: Colors.grey);
      }
      return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    } catch (_) {
      return const Icon(Icons.broken_image, color: Colors.grey);
    }
  }
  return Image.asset(src,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.broken_image, color: Colors.grey));
}

String _toFa(int n) => n.toString().replaceAllMapped(
      RegExp(r'\d'),
      (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m.group(0)!)],
    );


/// چیپ ویدیو (پیش‌نمایش ساده؛ ویدیو داخل اسلایدشو/ثبت ذخیره می‌شه)
class _VideoChip extends StatelessWidget {
  final GratPalette pal;
  final String name;
  final VoidCallback? onRemove;
  const _VideoChip({required this.pal, required this.name, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.line),
      ),
      child: Row(
        children: [
          Icon(Icons.videocam_outlined, size: 16, color: pal.emerald700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name.isEmpty ? 'ویدیو' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: pal.muted)),
          ),
          if (onRemove != null)
            GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration:
                    BoxDecoration(color: pal.danger, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
