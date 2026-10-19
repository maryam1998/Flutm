
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/gratitude_entry.dart';
import '../services/image_service.dart';
import '../services/visual_media_service.dart';
import '../state/beliefs_store.dart';
import '../utils/edit_mark.dart';
import 'audio_clip_view.dart';
import 'format_bar.dart'
    show kBeliefsBorder, kBeliefsCard, kBeliefsCream, kBeliefsGold, kBeliefsInk, kBeliefsMuted;
import 'grat_media.dart';
import 'media_slideshow.dart';
import 'inline_voice_button.dart';

const Color _kEmerald300 = Color(0xFF54B3A4);
const Color _kEmerald700 = Color(0xFF0F5B53);
const Color _kDanger = Color(0xFFE5484D);

/// کلید تنظیمات اسلایدشوی «تصاویر» (همان vizSlideshow وب)
const String kVizSlideshowKey = 'vizSlideshow';

// ═══════════════════════════ کمکی‌ها ═══════════════════════════

String _faStr(String s) => s.replaceAllMapped(
    RegExp(r'\d'), (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m.group(0)!)]);

String _fa(int n) => _faStr(n.toString());

void _toast(BuildContext context, String msg) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    duration: const Duration(milliseconds: 1800),
    behavior: SnackBarBehavior.floating,
  ));
}

Future<bool> _confirm(BuildContext context, String msg) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kBeliefsCard,
      content: Text(msg,
          style:
              const TextStyle(color: kBeliefsInk, fontSize: 13, height: 1.7)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('نه', style: TextStyle(color: kBeliefsMuted)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _kDanger),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('حذف'),
        ),
      ],
    ),
  );
  return ok == true;
}

const String _kStorageFullMsg =
    'ذخیره‌ی دائمی نشد؛ حافظه پر است. این مورد فقط تا بستن برنامه می‌مونه';

/// زمان ساخته‌شدن از روی id (۸ نویسه‌ی اول base36 = میلی‌ثانیه) — مثل tsOf وب
int _tsOfId(String id) {
  if (id.length < 8) return 0;
  final v = int.tryParse(id.substring(0, 8), radix: 36);
  if (v == null || v < 1000000000000 || v > 9999999999999) return 0;
  return v;
}

/// اسلایدهای تصویرسازی: عکس + ویدیو به ترتیب زمان افزودن
List<MediaSlide> beliefVisualSlides(BeliefsStore s) {
  final tmp = <({int ts, int n, MediaSlide slide})>[];
  for (var i = 0; i < s.visualImages.length; i++) {
    final im = s.visualImages[i];
    tmp.add((
      ts: _tsOfId(im.id),
      n: i,
      slide: MediaSlide(key: 'i${im.id}', isVideo: false, src: im.src),
    ));
  }
  for (var i = 0; i < s.visualVideos.length; i++) {
    final v = s.visualVideos[i];
    tmp.add((
      ts: _tsOfId(v.id),
      n: 1000000 + i,
      slide: MediaSlide(key: 'v${v.id}', isVideo: true, src: v.path),
    ));
  }
  tmp.sort((a, b) => a.ts != b.ts ? a.ts.compareTo(b.ts) : a.n.compareTo(b.n));
  return tmp.map((e) => e.slide).toList();
}

// ═══════════════════════════ بخش تصویرسازی ═══════════════════════════

/// یادداشت (با دکمه‌های ذخیره/لغو) + ضبط صدا / ویدیو / عکس با برش + اسلایدشو
class BeliefVisualSection extends StatefulWidget {
  const BeliefVisualSection({super.key});

  @override
  State<BeliefVisualSection> createState() => _BeliefVisualSectionState();
}

class _BeliefVisualSectionState extends State<BeliefVisualSection> {
  final TextEditingController _ctrl = TextEditingController();
  final GlobalKey _noteKey = GlobalKey();
  bool _editing = false;
  bool _busy = false;

  EditRange? _mark;
  int _markToken = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ─── یادداشت ───
  void _startEdit(BeliefsStore store) {
    _ctrl.text = store.visualNote;
    _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    setState(() => _editing = true);
  }

  void _cancelEdit() {
    FocusScope.of(context).unfocus();
    setState(() => _editing = false);
  }

  Future<void> _saveEdit(BeliefsStore store) async {
    final old = store.visualNote;
    final nt = _ctrl.text.trim();
    FocusScope.of(context).unfocus();
    setState(() => _editing = false);
    if (nt == old) return;
    await store.setVisualNote(nt);
    if (!mounted) return;
    // بخش تغییرکرده را هایلایت کن و صفحه را روی همان‌جا ببر (مثل EditMark وب)
    final r = (old.isEmpty || nt.isEmpty) ? null : diffEditRange(old, nt);
    final token = ++_markToken;
    setState(() => _mark = r);
    if (r != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _noteKey.currentContext;
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(ctx,
              alignment: 0.3, duration: const Duration(milliseconds: 400));
        }
      });
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted && token == _markToken) setState(() => _mark = null);
      });
    }
  }

  // ─── رسانه ───
  Future<void> _pickImages() async {
    if (_busy) return;
    final store = context.read<BeliefsStore>();
    setState(() => _busy = true);
    try {
      // انتخاب چندتایی + صفحه‌ی «برش عکس» برای هر عکس
      final srcs = await ImageService.pickImagesCropped(context: context);
      if (!mounted || srcs.isEmpty) return;
      final ok = await store.addVisualImages(srcs);
      if (!mounted) return;
      if (!ok) _toast(context, _kStorageFullMsg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickVideo() async {
    if (_busy) return;
    final store = context.read<BeliefsStore>();
    setState(() => _busy = true);
    try {
      final r = await VisualMediaService.pickVideo();
      if (!mounted) return;
      if (r.error != null) {
        _toast(context, r.error!);
        return;
      }
      final v = r.video;
      if (v == null) return;
      final ok = await store.addVisualVideo(v);
      if (!mounted) return;
      if (!ok) _toast(context, _kStorageFullMsg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onRecorded(String src) async {
    final store = context.read<BeliefsStore>();
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ok = await store.addVisualVoice(src,
        name: 'ضبط ${_faStr('$hh:$mm')}');
    if (!mounted) return;
    if (!ok) _toast(context, _kStorageFullMsg);
  }

  void _openAlbum(BeliefsStore store, int start) {
    showGratAlbum(
      context,
      images: () => store.visualImages,
      start: start,
      cfgKey: kVizSlideshowKey,
      onRemove: (im) => store.visualImages.removeWhere((e) => e.id == im.id),
      onChanged: () => store.commitVisualImages(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BeliefsStore>();
    final hasMedia = store.visualImages.isNotEmpty ||
        store.visualVideos.isNotEmpty ||
        store.visualVoices.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _noteBlock(store),
        const SizedBox(height: 12),
        _mediaButtons(),
        const SizedBox(height: 10),
        if (!hasMedia) _emptyBox(),
        if (store.visualImages.isNotEmpty) _thumbs(store),
        for (final v in store.visualVideos) ...[
          const SizedBox(height: 10),
          GratVideoView(
            key: ValueKey(v.id),
            src: v.path,
            onRemove: () async {
              if (await _confirm(context, 'این ویدیو حذف بشه؟')) {
                await store.removeVisualVideo(v.id);
              }
            },
          ),
        ],
        for (final e in store.visualVoices.asMap().entries) ...[
          const SizedBox(height: 10),
          AudioClipView(
            key: ValueKey('vv${e.key}_${e.value.src.length}'),
            src: e.value.src,
            title: e.value.name,
            onRemove: () async {
              if (await _confirm(context, 'این صدا حذف بشه؟')) {
                await store.removeVisualVoice(e.key);
              }
            },
          ),
        ],
        if (beliefVisualSlides(store).isNotEmpty) ...[
          const SizedBox(height: 16),
          MediaSlideshow(
            key: const ValueKey('viz-slideshow'),
            listenable: store,
            collect: () => beliefVisualSlides(store),
            cfgKey: kVizSlideshowKey,
            title: '🖼️ اسلایدشوی تصاویر',
            onOpenAlbum: store.visualImages.isEmpty
                ? null
                : (key) {
                    var at = 0;
                    if (key != null && key.startsWith('i')) {
                      final id = key.substring(1);
                      final i =
                          store.visualImages.indexWhere((e) => e.id == id);
                      if (i >= 0) at = i;
                    }
                    _openAlbum(store, at);
                  },
          ),
        ],
      ],
    );
  }

  // ─── یادداشت: نمایش / ویرایش ───
  Widget _noteBlock(BeliefsStore store) {
    final note = store.visualNote;
    return Container(
      key: _noteKey,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBeliefsCream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBeliefsBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('📝 یادداشت من (اختیاری)',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: kBeliefsInk)),
              ),
              if (!_editing && note.isNotEmpty)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _startEdit(store),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Text('ویرایش ✏',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _kEmerald700)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_editing) ...[
            TextField(
              controller: _ctrl,
              autofocus: true,
              minLines: 3,
              maxLines: null,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                  fontSize: 13, color: kBeliefsInk, height: 1.8),
              decoration: InputDecoration(
                hintText: 'توضیح این تصویرسازی (اختیاری)...',
                hintStyle:
                    const TextStyle(color: kBeliefsMuted, fontSize: 12),
                filled: true,
                fillColor: kBeliefsCard,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kBeliefsBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kBeliefsBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: kBeliefsGold, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: kBeliefsGold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _saveEdit(store),
                    child: const Text('💾 ذخیره',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kBeliefsMuted,
                      backgroundColor: kBeliefsCard,
                      side: const BorderSide(color: kBeliefsBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _cancelEdit,
                    child: const Text('لغو'),
                  ),
                ),
              ],
            ),
          ] else
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _startEdit(store),
              child: note.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'روی همین کادر بزن و توضیح این تصویرسازی رو بنویس...',
                        style: TextStyle(
                            fontSize: 12, color: kBeliefsMuted, height: 1.7),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: EditMarkedText(
                        text: note,
                        range: _mark,
                        style: const TextStyle(
                            fontSize: 13, color: kBeliefsInk, height: 1.9),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  // ─── دکمه‌های ضبط صدا / ویدیو / عکس ───
  Widget _mediaButtons() {
    return Row(
      children: [
        InlineMicButton(
          onRecorded: _onRecorded,
          builder: (ctx, recording, busy, elapsed, onTap) => _RoundMediaBtn(
            icon: recording ? Icons.mic : Icons.mic_none_outlined,
            label: recording ? InlineMicButton.fmt(elapsed) : 'ضبط صدا',
            active: recording,
            onTap: onTap,
          ),
        ),
        const SizedBox(width: 14),
        _RoundMediaBtn(
            icon: Icons.videocam_outlined, label: 'ویدیو', onTap: _pickVideo),
        const SizedBox(width: 14),
        _RoundMediaBtn(
            icon: Icons.image_outlined, label: 'عکس', onTap: _pickImages),
        if (_busy) ...[
          const SizedBox(width: 14),
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ],
    );
  }

  Widget _emptyBox() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: kBeliefsCream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBeliefsBorder),
      ),
      child: const Column(
        children: [
          Text('✨', style: TextStyle(fontSize: 28)),
          SizedBox(height: 6),
          Text('هنوز تصویری اضافه نکردی',
              style: TextStyle(fontSize: 12, color: kBeliefsMuted)),
          SizedBox(height: 4),
          Text('عکس، ویدیو یا صدای مورد دلخواهت رو اضافه کن',
              style: TextStyle(fontSize: 10.5, color: kBeliefsMuted)),
        ],
      ),
    );
  }

  Widget _thumbs(BeliefsStore store) {
    final list = store.visualImages;
    return Wrap(
      spacing: 6,
      runSpacing: 10,
      children: [
        for (final e in list.asMap().entries)
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () => _openAlbum(store, e.key),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: kBeliefsCream,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kBeliefsBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: gratImageFromSrc(e.value.src),
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () async {
                    if (await _confirm(context, 'این عکس حذف بشه؟')) {
                      await store.removeVisualImage(e.value.id);
                    }
                  },
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                        color: _kDanger, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child:
                        const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _RoundMediaBtn extends StatelessWidget {
  const _RoundMediaBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: active ? _kDanger : kBeliefsCard,
          borderRadius: BorderRadius.circular(50),
          child: InkWell(
            borderRadius: BorderRadius.circular(50),
            onTap: onTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: active ? _kDanger : _kEmerald300),
              ),
              child: Icon(icon,
                  color: active ? Colors.white : _kEmerald700, size: 22),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(fontSize: 10, color: kBeliefsMuted)),
      ],
    );
  }
}

// ═══════════════════════════ موسیقی مدیتیشن ═══════════════════════════

class BeliefMeditationMusic extends StatefulWidget {
  const BeliefMeditationMusic({super.key});

  @override
  State<BeliefMeditationMusic> createState() => _BeliefMeditationMusicState();
}

class _BeliefMeditationMusicState extends State<BeliefMeditationMusic> {
  bool _busy = false;

  Future<void> _pick() async {
    if (_busy) return;
    final store = context.read<BeliefsStore>();
    setState(() => _busy = true);
    try {
      final r = await VisualMediaService.pickMusic();
      if (!mounted) return;
      if (r.error != null) {
        _toast(context, r.error!);
        return;
      }
      final t = r.track;
      if (t == null) return;
      final ok = await store.setMeditationTrack(t);
      if (!mounted) return;
      if (!ok) _toast(context, _kStorageFullMsg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BeliefsStore>();
    final GratitudeAudio? track = store.meditationTrack;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '🎵 موسیقی مدیتیشن (اختیاری)',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: kBeliefsInk),
        ),
        const SizedBox(height: 8),
        if (track != null) ...[
          AudioClipView(
            key: ValueKey('med_${track.src.length}'),
            src: track.src,
            title: track.name,
            onRemove: () async {
              if (await _confirm(context, 'این موسیقی حذف بشه؟')) {
                await store.removeMeditationTrack();
              }
            },
          ),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: kBeliefsMuted,
              side: const BorderSide(color: kBeliefsBorder),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _busy ? null : _pick,
            icon: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(track == null ? Icons.add : Icons.swap_horiz,
                    size: 14),
            label: Text(track == null ? 'افزودن موسیقی' : 'تعویض موسیقی',
                style: const TextStyle(fontSize: 11)),
          ),
        ),
      ],
    );
  }
}
