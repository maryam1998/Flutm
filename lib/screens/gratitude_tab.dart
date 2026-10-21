import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/gratitude_journey.dart';
import '../models/emotion.dart';
import '../models/gratitude_entry.dart';
import '../models/jalali.dart' as jal;
import '../services/data_url_cache.dart';
import '../state/emotion_store.dart';
import '../state/background_store.dart';
import '../state/gratitude_store.dart';
import '../theme/grat_palette.dart';
import '../widgets/audio_clip_view.dart';
import '../widgets/grat_media.dart';
import '../widgets/gratitude_slideshow.dart';
import '../widgets/grat_period_calendar.dart';
import '../widgets/neural_pathway.dart';
import '../widgets/inline_voice_button.dart';
import '../services/image_service.dart';
import '../services/media_blob.dart';
import '../services/quiet_snack.dart';

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
  static final _picker = ImagePicker();

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
    final custom = context.watch<BackgroundStore>().overridesBackdrop;

    if (!store.loaded) {
      return Container(
        color: custom ? Colors.transparent : pal.paper,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    final info = computeGratitudePhase(store.journeyDay, store.journeyDays);

    return Container(
      color: custom ? Colors.transparent : pal.paper,
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
            // .quick-add margin:4px 18px 16px
            const SizedBox(height: 4),
            _Composer(
              pal: pal,
              prompt: info.prompt,
              count: store.totalCount,
              textCtrl: _textCtrl,
              images: _pendingImages,
              audios: _pendingAudios,
              videos: _pendingVideos,
              share: _pendingShare,
              onShareChanged: (v) => setState(() => _pendingShare = v),
              onPickImages: _pickImages,
              onPickVideos: _pickVideos,
              onRecorded: _onRecorded,
              onCropImage: _cropImage,
              onImagesChanged: () => setState(() {}),
              onRemoveImage: (i) => setState(() => _pendingImages.removeAt(i)),
              onRemoveAudio: (i) => setState(() => _pendingAudios.removeAt(i)),
              onRemoveVideo: (i) => setState(() => _pendingVideos.removeAt(i)),
              onSubmit: _submit,
            ),
            // .quick-add margin-bottom:16 (با margin-top:10 عنوان ادغام می‌شه)
            const SizedBox(height: 16),
            // <div class="items-title" style="margin-top:10px">📅 تقویم شکرگذاری</div>
            // .items-title: font-size:13px; font-weight:800; margin: 22px 0 10px (بدون حاشیه‌ی کنار)
            Text(
              '📅 تقویم شکرگذاری',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: pal.ink,
              ),
            ),
            // عنوان margin-bottom:10 با #hist-gratitude-mini-cal margin-top:14 ادغام می‌شه → 14
            const SizedBox(height: 14),
            // #hist-gratitude-mini-cal + #hist-gratitude-mini-cal-info (margin:0 در راستای افقی)
            GratMiniCalendar(
              store: store,
              pal: pal,
              variant: GratCalVariant.history,
            ),
            // .section-label margin-top:26 (۸ تاش را خودِ _SectionLabel دارد)
            const SizedBox(height: 18),
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
                showDayButtons: true,
                onChange: () => store.saveNeural(),
                emotionQualityToday: _emotionQualityToday(store),
              ),
            ),
            const SizedBox(height: 18),
            if (store.entries.any(
                (e) => e.source != 'purchase' && e.images.isNotEmpty))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GratitudeSlideshow(
                  store: store,
                  onOpenAlbum: (key) => _openAlbumAll(store, key),
                ),
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
      _toast(context, 'یه متن، عکس، ویدیو یا صدا وارد کن 🌱');
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
    setState(() {
      _textCtrl.clear();
      _pendingImages.clear();
      _pendingAudios.clear();
      _pendingVideos.clear();
      _pendingShare = false;
    });
    _toast(context, !store.lastPersistOk
        ? 'ثبت شد، ولی حافظه‌ی مرورگر پر شده — با بستن صفحه ممکنه از دست بره. عکس/صدای قدیمی رو پاک کن'
        : (wasShared
            ? 'ثبت شد و با بقیه به اشتراک گذاشته شد 🌍'
            : 'ثبت شد — فقط برای خودم 🤫'));
  }

  /// آلبوم همه‌ی عکس‌های شکرگذاری‌ها (مثل openGratAlbumAll وب)
  void _openAlbumAll(GratitudeStore store, String? currentKey) {
    List<GratitudeImage> all() => [
          for (final e in store.entries)
            if (e.source != 'purchase') ...e.images,
        ];
    var start = 0;
    if (currentKey != null) {
      var i = 0;
      outer:
      for (final e in store.entries) {
        if (e.source == 'purchase') continue;
        for (final im in e.images) {
          if ('g${e.id}_${im.id}' == currentKey) {
            start = i;
            break outer;
          }
          i++;
        }
      }
    }
    showGratAlbum(
      context,
      images: all,
      start: start,
      onRemove: (im) {
        for (final e in store.entries) {
          final at = e.images.indexOf(im);
          if (at >= 0) {
            e.images.removeAt(at);
            e.image = e.images.isNotEmpty ? e.images.first.src : null;
          }
        }
      },
      onChanged: () => store.commitMedia(),
    );
  }

  /// انتخاب عکس‌ها: کوچک‌سازی تا ۱۴۰۰px و JPEG با کیفیت ۰٫۸۲ (مثل gratFileToDataUrl وب)
  static Future<List<GratitudeImage>> _pickImageItems(BuildContext context) async {
    try {
      final files =
          await _picker.pickMultiImage(imageQuality: 82, maxWidth: 1400, maxHeight: 1400);
      final out = <GratitudeImage>[];
      for (final f in files) {
        final bytes = await f.readAsBytes();
        out.add(GratitudeImage(src: 'data:image/jpeg;base64,${base64Encode(bytes)}'));
      }
      if (out.isNotEmpty) {
        _toast(context, out.length > 1 ? '${_toFa(out.length)} عکس اضافه شد 🖼️' : 'عکس اضافه شد 🖼️');
      }
      return out;
    } catch (e) {
      _toast(context, 'عکس خوانده نشد');
      return [];
    }
  }

  static Future<GratitudeVideo?> _pickVideoItem(BuildContext context) async {
    try {
      final f = await _picker.pickVideo(source: ImageSource.gallery);
      if (f == null) return null;
      final lower = f.name.toLowerCase();
      final mime = lower.endsWith('.webm')
          ? 'video/webm'
          : (lower.endsWith('.mov') ? 'video/quicktime' : 'video/mp4');
      final ref = await MediaBlob.saveXFile(f, mime: mime);
      return GratitudeVideo(path: ref, name: f.name, size: await f.length());
    } catch (e) {
      _toast(context, 'ویدیو اضافه نشد');
      return null;
    }
  }

  Future<void> _pickImages() async {
    final l = await _pickImageItems(context);
    if (l.isNotEmpty && mounted) setState(() => _pendingImages.addAll(l));
  }

  void _onRecorded(String src) {
    if (!mounted) return;
    setState(() => _pendingAudios.add(_audioFromSrc(src)));
  }

  Future<void> _cropImage(int i) async {
    if (i < 0 || i >= _pendingImages.length) return;
    final n = await ImageService.cropDataUrl(context, _pendingImages[i].src);
    if (n != null && mounted) setState(() => _pendingImages[i].src = n);
  }

  /// صدای ضبط‌شده (data-URL) → آیتم صدا با اسم «ضبط ساعت»
  static GratitudeAudio _audioFromSrc(String src) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final stamp = '$hh:$mm'.replaceAllMapped(
        RegExp(r'\d'), (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m.group(0)!)]);
    return GratitudeAudio(src: src, name: 'ضبط $stamp');
  }

  Future<void> _pickVideos() async {
    final v = await _pickVideoItem(context);
    if (v != null && mounted) setState(() => _pendingVideos.add(v));
  }

  static void _toast(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).quietSnack(SnackBar(
      content: Text(msg),
      duration: const Duration(milliseconds: 1600),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ─── ویرایش ───
  static void _openEditor(BuildContext context, GratitudeEntry g) {
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
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _MediaBtn(
                              pal: pal,
                              icon: Icons.videocam_outlined,
                              onTap: () async {
                                final v = await _pickVideoItem(context);
                                if (v != null) setSheet(() => videos.add(v));
                              }),
                          const SizedBox(width: 8),
                          _MediaBtn(
                              pal: pal,
                              icon: Icons.image_outlined,
                              onTap: () async {
                                final l = await _pickImageItems(context);
                                if (l.isNotEmpty) setSheet(() => images.addAll(l));
                              }),
                        ],
                      ),
                      for (final e in videos.asMap().entries) ...[
                        const SizedBox(height: 10),
                        GratVideoView(
                          key: ValueKey(e.value.id),
                          src: e.value.path,
                          onRemove: () => setSheet(() => videos.removeAt(e.key)),
                        ),
                      ],
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
                            _toast(context, 'ویرایش شد ✏️');
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
                            _toast(context, 'حذف شد 🗑');
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
                            '🧭 دوره‌ی ${pastCount > 0 ? '${GratMiniCalendar.ord(pastCount)} — ' : ''}${_toFa(info.totalDays)} روزه — ${info.phaseShort}',
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
//                مودال ویرایش احساسات یک روز
// ════════════════════════════════════════════════════════════════
// ignore: unused_element
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
  final int count;
  final TextEditingController textCtrl;
  final List<GratitudeImage> images;
  final List<GratitudeAudio> audios;
  final List<GratitudeVideo> videos;
  final bool share;
  final ValueChanged<bool> onShareChanged;
  final VoidCallback onPickImages;
  final VoidCallback onPickVideos;
  final ValueChanged<String> onRecorded;
  final ValueChanged<int>? onCropImage;
  final VoidCallback? onImagesChanged;
  final bool home;
  final ValueChanged<int> onRemoveImage;
  final ValueChanged<int> onRemoveAudio;
  final ValueChanged<int> onRemoveVideo;
  final VoidCallback onSubmit;

  const _Composer({
    required this.pal,
    required this.prompt,
    required this.count,
    required this.textCtrl,
    required this.images,
    required this.audios,
    required this.videos,
    required this.share,
    required this.onShareChanged,
    required this.onPickImages,
    required this.onPickVideos,
    required this.onRecorded,
    this.onCropImage,
    this.onImagesChanged,
    this.home = false,
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
        decoration: home
            // .quick-add وب: surface + کادر line + گوشه‌ی ۱۶
            ? BoxDecoration(
                color: pal.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: pal.line),
              )
            : BoxDecoration(
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
            if (home) ...[
              Text('🧠 مغزت رو تربیت کن تا داشته‌هات رو ببینه',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: pal.ink)),
              const SizedBox(height: 4),
              Text(
                  'طبق علم اعصاب، هر بار شکرگذاری می‌کنی، مسیرهای عصبیِ مثبت‌نگری در مغزت قوی‌تر می‌شن.',
                  style: TextStyle(
                      fontSize: 10.5, color: pal.muted, height: 1.6)),
              const SizedBox(height: 10),
            ],
            Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: home
                        ? '${_toFa(count + 1)} - خدایا شکرت که:'
                        : 'خدایا شکرت که:'),
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
                    icon: Icons.image_outlined,
                    onTap: onPickImages),
                const SizedBox(width: 10),
                _MediaBtn(
                    pal: pal,
                    icon: Icons.videocam_outlined,
                    onTap: onPickVideos),
                const SizedBox(width: 10),
                InlineMicButton(
                  onRecorded: onRecorded,
                  builder: (ctx, recording, busy, elapsed, onTap) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MediaBtn(
                        pal: pal,
                        icon: recording
                            ? Icons.mic
                            : Icons.mic_none_outlined,
                        active: recording,
                        onTap: onTap,
                      ),
                      if (recording) ...[
                        const SizedBox(width: 8),
                        Text(InlineMicButton.fmt(elapsed),
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: pal.danger)),
                      ],
                    ],
                  ),
                ),
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
                      GestureDetector(
                        onTap: () => showGratAlbum(
                          context,
                          images: () => images,
                          start: e.key,
                          onRemove: (im) => onRemoveImage(images.indexOf(im)),
                          onChanged: onImagesChanged,
                        ),
                        child: Container(
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
                      ),
                      if (onCropImage != null)
                        Positioned(
                          bottom: -6,
                          right: -6,
                          child: GestureDetector(
                            onTap: () => onCropImage!(e.key),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: pal.emerald700,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const Icon(Icons.crop,
                                  size: 13, color: Colors.white),
                            ),
                          ),
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
            for (final e in videos.asMap().entries) ...[
              const SizedBox(height: 10),
              GratVideoView(
                key: ValueKey(e.value.id),
                src: e.value.path,
                onRemove: () => onRemoveVideo(e.key),
              ),
            ],
            for (final e in audios.asMap().entries) ...[
              const SizedBox(height: 10),
              AudioClipView(
                key: ValueKey('pa${e.key}_${e.value.src.hashCode}'),
                src: e.value.src,
                title: e.value.name,
                onRemove: () => onRemoveAudio(e.key),
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
  final bool active;
  const _MediaBtn(
      {required this.icon,
      required this.onTap,
      required this.pal,
      this.active = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? pal.danger : pal.surface,
      borderRadius: BorderRadius.circular(50),
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: active ? pal.danger : pal.emerald300),
          ),
          child: Icon(icon,
              color: active ? Colors.white : pal.emerald700, size: 22),
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
              border: Border.all(color: pal.emerald300.withValues(alpha: 0.55)),
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
                      : (entry.icon.isEmpty || entry.icon == '🙏')
                          ? Icon(Icons.back_hand_outlined,
                              size: 22, color: pal.emerald700)
                          : Text(
                              entry.icon,
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
                        jal.faStampFromRecord(
                          iso: entry.iso,
                          date: entry.date,
                          day: entry.day,
                          time: entry.time,
                        ),
                        style: TextStyle(fontSize: 11.5, color: pal.muted),
                      ),
                      if (entry.emotionIds.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: entry.emotionIds
                              .map(emotionById)
                              .whereType<Emotion>()
                              .map((e) {
                            final c = hexToColor(e.color);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: c.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                    color: c.withValues(alpha: 0.55)),
                              ),
                              child: Text(
                                e.fa,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: HSLColor.fromColor(c)
                                      .withLightness(0.3)
                                      .toColor(),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      for (final v in entry.videos) ...[
                        const SizedBox(height: 8),
                        GratVideoView(key: ValueKey(v.id), src: v.path),
                      ],
                      for (final a in entry.audios) ...[
                        const SizedBox(height: 8),
                        AudioClipView(
                          key: ValueKey('ea${a.src.hashCode}'),
                          src: a.src,
                          title: a.name,
                        ),
                      ],
                      if (entry.images.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: entry.images.asMap().entries.map((en) {
                            final im = en.value;
                            return GestureDetector(
                              onTap: () => showGratAlbum(
                                context,
                                images: () => entry.images,
                                start: en.key,
                                onRemove: (x) {
                                  entry.images.remove(x);
                                  entry.image = entry.images.isNotEmpty
                                      ? entry.images.first.src
                                      : null;
                                },
                                onChanged: () =>
                                    context.read<GratitudeStore>().commitMedia(),
                              ),
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
    final fa = buf.toString().replaceAllMapped(
        RegExp(r'\d'), (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m.group(0)!)]);
    return '$fa تومان';
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

// ─── decode ───
Widget _imgFromSrc(String src) {
  if (src.isEmpty) return const SizedBox.shrink();
  if (src.startsWith('data:')) {
    final bytes = DataUrlCache.bytes(src);
    if (bytes == null) {
      return const Icon(Icons.broken_image, color: Colors.grey);
    }
    return Image.memory(bytes,
        fit: BoxFit.cover, cacheWidth: 1000, gaplessPlayback: true);
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

/// تقویم دوره‌ی شکرگذاری برای استفاده در تب «خانه» — دقیقاً همان تقویم تب شکرگذاری
class GratitudePeriodCalendar extends StatelessWidget {
  const GratitudePeriodCalendar({super.key});

  /// «اول، دوم، …» برای شماره‌ی دوره
  static String ord(int i) => GratMiniCalendar.ord(i);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<GratitudeStore>();
    if (!store.loaded) return const SizedBox.shrink();
    return GratMiniCalendar(
      store: store,
      pal: GratPalette.of(context),
      variant: GratCalVariant.home,
    );
  }
}

// ════════════════════════════════════════════════════════════════
//        اجزای تب خانه (همان quick-add / مسیر عصبی / لیست وب)
// ════════════════════════════════════════════════════════════════

/// ورودی سریع شکرگذاری تب خانه — `.quick-add` وب
/// (متن + عکس/ویدیو/صدا + «فقط برای خودم / اشتراک‌گذاری»)
class GratitudeQuickAdd extends StatefulWidget {
  const GratitudeQuickAdd({super.key});
  @override
  State<GratitudeQuickAdd> createState() => _GratitudeQuickAddState();
}

class _GratitudeQuickAddState extends State<GratitudeQuickAdd> {
  final _textCtrl = TextEditingController();
  final List<GratitudeImage> _images = [];
  final List<GratitudeAudio> _audios = [];
  final List<GratitudeVideo> _videos = [];
  bool _share = false;
  bool _saving = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final l = await _GratitudeTabState._pickImageItems(context);
    if (l.isNotEmpty && mounted) setState(() => _images.addAll(l));
  }

  Future<void> _pickVideos() async {
    final v = await _GratitudeTabState._pickVideoItem(context);
    if (v != null && mounted) setState(() => _videos.add(v));
  }

  void _onRecorded(String src) {
    if (!mounted) return;
    setState(() => _audios.add(_GratitudeTabState._audioFromSrc(src)));
  }

  Future<void> _cropImage(int i) async {
    if (i < 0 || i >= _images.length) return;
    final n = await ImageService.cropDataUrl(context, _images[i].src);
    if (n != null && mounted) setState(() => _images[i].src = n);
  }

  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty && _images.isEmpty && _audios.isEmpty && _videos.isEmpty) {
      _GratitudeTabState._toast(context, 'یه متن، عکس، ویدیو یا صدا وارد کن 🌱');
      return;
    }
    if (_saving) return;
    final store = context.read<GratitudeStore>();
    final emotions = context.read<EmotionStore>();
    final wasShared = _share;
    setState(() => _saving = true);
    try {
      await store.add(
        text: text,
        images: List.of(_images),
        audios: List.of(_audios),
        videos: List.of(_videos),
        shared: _share,
        emotions: emotions,
      );
      if (!mounted) return;
      setState(() {
        _textCtrl.clear();
        _images.clear();
        _audios.clear();
        _videos.clear();
        _share = false;
      });
      _GratitudeTabState._toast(
          context,
          !store.lastPersistOk
              ? 'ثبت شد، ولی حافظه‌ی دستگاه پر شده — عکس/صدای قدیمی رو پاک کن'
              : (wasShared
                  ? 'ثبت شد و با بقیه به اشتراک گذاشته شد 🌍'
                  : 'ثبت شد — فقط برای خودم 🤫'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = GratPalette.of(context);
    final store = context.watch<GratitudeStore>();
    if (!store.loaded) return const SizedBox.shrink();
    final info = computeGratitudePhase(store.journeyDay, store.journeyDays);
    return _Composer(
      pal: pal,
      home: true,
      prompt: info.prompt,
      count: store.totalCount,
      textCtrl: _textCtrl,
      images: _images,
      audios: _audios,
      videos: _videos,
      share: _share,
      onShareChanged: (v) => setState(() => _share = v),
      onPickImages: _pickImages,
      onPickVideos: _pickVideos,
      onRecorded: _onRecorded,
      onCropImage: _cropImage,
      onImagesChanged: () => setState(() {}),
      onRemoveImage: (i) => setState(() => _images.removeAt(i)),
      onRemoveAudio: (i) => setState(() => _audios.removeAt(i)),
      onRemoveVideo: (i) => setState(() => _videos.removeAt(i)),
      onSubmit: _submit,
    );
  }
}

/// «انجام این تمرین» + مسیر عصبی شکرگذاری — `#np-gratitude-mount` وب
class GratitudeNeuralSection extends StatelessWidget {
  const GratitudeNeuralSection({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = GratPalette.of(context);
    final store = context.watch<GratitudeStore>();
    if (!store.loaded) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(
          icon: Icons.psychology_alt_outlined,
          title: 'انجام این تمرین',
          pal: pal,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: NeuralPathway(
            container: store.neural,
            label: 'شکرگذاری',
            showDayButtons: true,
            onChange: () => store.saveNeural(),
            emotionQualityToday: store.emotionQualityToday,
          ),
        ),
      ],
    );
  }
}

/// «لیست شکرگذاری» تب خانه — `#home-recent` وب
/// (ردیف‌های کامل با عکس/ویدیو/صدا، لمس = ویرایش، «نمایش بیشتر»)
class GratitudeRecentList extends StatefulWidget {
  const GratitudeRecentList({super.key});
  @override
  State<GratitudeRecentList> createState() => _GratitudeRecentListState();
}

class _GratitudeRecentListState extends State<GratitudeRecentList> {
  int _limit = 40;

  @override
  Widget build(BuildContext context) {
    final pal = GratPalette.of(context);
    final store = context.watch<GratitudeStore>();
    if (!store.loaded) return const SizedBox.shrink();
    final all = store.allReversed;
    final slice = all.take(_limit).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(
          icon: Icons.list_alt_outlined,
          title: 'لیست شکرگذاری',
          pal: pal,
        ),
        if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              decoration: BoxDecoration(
                color: pal.surface,
                border: Border.all(color: pal.line),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'هنوز شکرگذاری‌ای ثبت نکردی. یا از بازی فراوانی بخر یا همین‌جا بنویس 🌱',
                textAlign: TextAlign.center,
                style: TextStyle(color: pal.muted, fontSize: 13, height: 1.8),
              ),
            ),
          )
        else ...[
          ...slice.map((g) => _EntryRow(
                entry: g,
                pal: pal,
                onTap: () => _GratitudeTabState._openEditor(context, g),
              )),
          if (all.length > slice.length)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: _GhostButton(
                text:
                    'نمایش بیشتر (${_toFa(all.length - slice.length)} مورد دیگر)',
                pal: pal,
                onTap: () => setState(() => _limit += 40),
              ),
            ),
        ],
      ],
    );
  }
}
