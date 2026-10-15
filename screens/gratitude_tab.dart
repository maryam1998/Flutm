import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/gratitude_journey.dart';
import '../map/draw_utils.dart' show toFa;
import '../models/emotion.dart';
import '../models/gratitude_entry.dart';
import '../models/jalali.dart';
import '../services/image_service.dart';
import '../state/emotion_store.dart';
import '../state/gratitude_store.dart';
import '../theme/grat_palette.dart';
import '../widgets/neural_pathway.dart';
import '../widgets/voice_recorder_sheet.dart';
import '../widgets/web_theme_banner.dart';

// ============================================================
// کمک‌ها
// ============================================================

const _kWeekdays = [
  'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنج‌شنبه', 'جمعه', 'شنبه', 'یکشنبه'
];

String _two(int n) => n.toString().padLeft(2, '0');

String _dayKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

DateTime _parseKey(String k) {
  final p = k.split('-').map((e) => int.tryParse(e) ?? 1).toList();
  if (p.length != 3) return DateTime.now();
  return DateTime(p[0], p[1], p[2]);
}

String _faDayMonth(DateTime d) {
  final j = toJalaali(d.year, d.month, d.day);
  return '${toFa(j.jd)} ${kJalaliMonths[j.jm - 1]}';
}

/// normalizeDigits وب
String _normalizeDigits(String s) {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i1 = fa.indexOf(ch);
    final i2 = ar.indexOf(ch);
    if (i1 >= 0) {
      b.write(i1);
    } else if (i2 >= 0) {
      b.write(i2);
    } else {
      b.write(ch);
    }
  }
  return b.toString();
}

/// periodParseDays وب
int _parseDays(String input) {
  final n = int.tryParse(_normalizeDigits(input.trim()));
  if (n == null || n < 1 || n > GratitudeStore.maxPeriodDays) return 0;
  return n;
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));
}

Uint8List? _decodeSrc(String src) {
  try {
    if (!src.startsWith('data:')) return null;
    return base64Decode(src.substring(src.indexOf(',') + 1));
  } catch (_) {
    return null;
  }
}

Color _hexColor(String hex, Color fallback) {
  try {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  } catch (_) {
    return fallback;
  }
}

/// .btn.tiny وب (و .btn.gold)
class _TinyBtn extends StatelessWidget {
  const _TinyBtn({
    required this.p,
    required this.text,
    required this.onTap,
    this.gold = false,
  });
  final GratPalette p;
  final String text;
  final VoidCallback onTap;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final bg = gold ? p.accent : const Color.fromRGBO(255, 255, 255, 0.05);
    final border = gold ? p.accent : p.panelBorder;
    final fg = gold ? const Color(0xFF221800) : p.ink;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: border),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: fg,
              fontWeight: gold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// .gm-btn وب: دایره‌ی ۴۴، border=emerald-300، bg=surface، آیکون=emerald-700
class _MediaBtn extends StatelessWidget {
  const _MediaBtn({
    required this.p,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final GratPalette p;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.surface,
              border: Border.all(color: p.emerald300),
            ),
            child: Icon(icon, size: 22, color: p.emerald700),
          ),
        ),
      ),
    );
  }
}

/// .visibility-options وب: دو رادیو با آیکون قفل / کره‌ی زمین
class _VisRadios extends StatelessWidget {
  const _VisRadios({required this.p, required this.shared, required this.onChanged});
  final GratPalette p;
  final bool shared;
  final ValueChanged<bool> onChanged;

  Widget _opt(String label, IconData icon, bool value) {
    final sel = shared == value;
    return InkWell(
      onTap: () => onChanged(value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: sel ? p.emerald500 : p.muted, width: 1.6),
            ),
            child: sel
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: p.emerald500),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Icon(icon, size: 16, color: p.emerald700),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12.5, color: p.inkSoft)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _opt('فقط برای خودم', Icons.lock_outline, false),
        _opt('اشتراک‌گذاری با بقیه', Icons.public, true),
      ],
    );
  }
}

/// .primary-btn وب
class _GradButton extends StatelessWidget {
  const _GradButton({required this.p, required this.text, required this.onTap, this.busy = false});
  final GratPalette p;
  final String text;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [p.emerald700, p.emerald500],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(15, 91, 83, 0.25),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(text,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

/// .ghost-btn وب
Widget _ghostBtn(GratPalette p, String text, VoidCallback onTap) {
  return Material(
    color: p.card,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.line),
        ),
        alignment: Alignment.center,
        child: Text(text,
            style: TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w700, color: p.ink)),
      ),
    ),
  );
}

class _DashedPainter extends CustomPainter {
  _DashedPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(16)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPainter old) => old.color != color;
}

Widget _removeBadge(GratPalette p, VoidCallback onTap) {
  return Positioned(
    top: -6,
    right: -6,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(color: p.danger, shape: BoxShape.circle),
        child: const Icon(Icons.close, size: 14, color: Colors.white),
      ),
    ),
  );
}

Widget _pendingImg(GratPalette p, String src, VoidCallback onRemove) {
  final bytes = _decodeSrc(src);
  return Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: p.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: bytes != null
            ? Image.memory(bytes, fit: BoxFit.cover)
            : Icon(Icons.broken_image, color: p.muted),
      ),
      _removeBadge(p, onRemove),
    ],
  );
}

Widget _pendingAudio(GratPalette p, GratitudeAudio a, VoidCallback onRemove) {
  return Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(a.name.contains('ویس') ? Icons.mic_none : Icons.audiotrack,
                size: 16, color: p.emerald700),
            const SizedBox(width: 6),
            Text(a.name.isEmpty ? 'صوت' : a.name,
                style: TextStyle(fontSize: 11.5, color: p.muted)),
          ],
        ),
      ),
      _removeBadge(p, onRemove),
    ],
  );
}

InputDecoration _areaDecoration(GratPalette p, String hint, Color fill) {
  OutlineInputBorder b(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: p.muted, fontSize: 13),
    filled: true,
    fillColor: fill,
    contentPadding: const EdgeInsets.all(12),
    border: b(p.line),
    enabledBorder: b(p.line),
    focusedBorder: b(p.emerald300),
  );
}

// ============================================================
// تب شکرگذاری
// ============================================================

class GratitudeTab extends StatefulWidget {
  const GratitudeTab({super.key});
  @override
  State<GratitudeTab> createState() => _GratitudeTabState();
}

class _GratitudeTabState extends State<GratitudeTab> {
  final _text = TextEditingController();
  final List<GratitudeImage> _pendingImages = [];
  final List<GratitudeAudio> _pendingAudios = [];
  bool _shared = false;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  static String _fmtMoney(double amount) {
    final n = amount.toInt();
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return toFa((n < 0 ? '-' : '') + buf.toString());
  }

  // ─────────── pickers ───────────

  Future<void> _pickImages() async {
    final srcs = await ImageService.pickImages();
    if (!mounted || srcs.isEmpty) return;
    setState(() {
      for (final s in srcs) {
        _pendingImages.add(GratitudeImage(src: s));
      }
    });
  }

  Future<void> _pickVideo() async {
    final src = await ImageService.pickVideo();
    if (!mounted) return;
    if (src == null) {
      _toast(context, 'ویدیو انتخاب نشد یا حجمش بیشتر از ۸ مگابایت بود');
      return;
    }
    setState(() => _pendingImages.add(GratitudeImage(src: src)));
  }

  Future<void> _pickAudio() async {
    final src = await ImageService.pickAudio();
    if (!mounted) return;
    if (src == null) {
      _toast(context, 'صوت انتخاب نشد یا حجمش بیشتر از ۵ مگابایت بود');
      return;
    }
    setState(() => _pendingAudios.add(GratitudeAudio(src: src, name: 'صوت')));
  }

  Future<void> _recordVoice() async {
    final src =
        await VoiceRecorderSheet.show(context, title: 'ضبط ویس شکرگذاری');
    if (!mounted || src == null) return;
    setState(() =>
        _pendingAudios.add(GratitudeAudio(src: src, name: 'ویس ضبط‌شده')));
  }

  // ─────────── submit ───────────

  Future<void> _submit() async {
    final store = context.read<GratitudeStore>();
    final emotions = context.read<EmotionStore>();
    final text = _text.text.trim();
    if (text.isEmpty && _pendingImages.isEmpty && _pendingAudios.isEmpty) {
      _toast(context, 'یه متن، عکس، ویدیو یا صدا وارد کن 🌱');
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    final wasShared = _shared;
    try {
      await store.add(
        text: text,
        images: List.of(_pendingImages),
        audios: List.of(_pendingAudios),
        shared: wasShared,
        emotions: emotions,
      );
      _text.clear();
      setState(() {
        _pendingImages.clear();
        _pendingAudios.clear();
        _shared = false;
      });
      if (mounted) {
        _toast(
            context,
            wasShared
                ? 'ثبت شد و با بقیه به اشتراک گذاشته شد 🌍'
                : 'ثبت شد — فقط برای خودم 🤫');
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

  // ─────────── build ───────────

  @override
  Widget build(BuildContext context) {
    final p = GratPalette.of(context);
    final store = context.watch<GratitudeStore>();
    final phase = computeGratitudePhase(store.journeyDay, store.journeyDays);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Row(
              children: [
                Text('شکرگذاری',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: p.ink)),
                const SizedBox(width: 8),
                Text('${toFa(store.totalCount)} مورد',
                    style: TextStyle(fontSize: 12, color: p.muted)),
              ],
            ),
            const SizedBox(height: 4),
            Text('هر چیزی که در زندگیت هست، همین‌جا ثبتش کن',
                style: TextStyle(fontSize: 12.5, color: p.muted)),
            const SizedBox(height: 14),

            _counterCard(p, store.totalCount),
            const SizedBox(height: 14),

            _JourneyBanner(phase: phase, store: store),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('📅 تقویم شکرگذاری',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: p.ink)),
            ),
            _PeriodCalendar(store: store),
            const SizedBox(height: 16),

            _sectionLabel(p, 'مسیر عصبی شکرگذاری'),
            NeuralPathway(
              webStyle: true,
              container: store.neural,
              label: 'شکرگذاری',
              showDayButtons: false,
              showHabitButton: true,
              emotionQualityToday: store.todayEmotionQuality,
              onChange: () {
                store.saveNeural();
              },
            ),
            const SizedBox(height: 16),

            _addForm(p, store, phase),
            const SizedBox(height: 20),

            if (store.entries.isEmpty)
              CustomPaint(
                painter: _DashedPainter(p.line),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'هنوز هیچ شکرگذاری ثبت نشده.\nیه چیز خوب زندگیت رو همین بالا بنویس 🌱',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.muted, height: 1.9, fontSize: 13),
                  ),
                ),
              )
            else
              for (final e in store.histSlice) _entryCard(p, store, e),

            if (store.hasMoreHist)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _ghostBtn(
                  p,
                  'نمایش بیشتر (${toFa(store.entries.length - store.histLimit)} مورد دیگر)',
                  store.showMoreHist,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _counterCard(GratPalette p, int total) {
    const bold = TextStyle(fontWeight: FontWeight.w800);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.emerald900, p.emerald700],
        ),
        boxShadow: const [
          BoxShadow(
              color: Color.fromRGBO(10, 40, 35, 0.06),
              blurRadius: 2,
              offset: Offset(0, 1)),
          BoxShadow(
              color: Color.fromRGBO(10, 40, 35, 0.07),
              blurRadius: 24,
              offset: Offset(0, 8)),
        ],
      ),
      child: Text.rich(
        TextSpan(children: [
          const TextSpan(text: 'لطف خدا رو '),
          TextSpan(text: toFa(total), style: bold),
          const TextSpan(text: ' بار شکر کردم'),
        ]),
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
      ),
    );
  }

  /// .section-label h2 + .section-icon وب
  Widget _sectionLabel(GratPalette p, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            margin: const EdgeInsetsDirectional.only(end: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              color: p.isDark
                  ? const Color.fromRGBO(84, 201, 184, 0.15)
                  : const Color(0xFFDCF3EE),
            ),
            child: Icon(Icons.biotech_outlined,
                size: 14, color: p.isDark ? p.emerald300 : p.emerald700),
          ),
          Text(title,
              style: TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w800, color: p.ink)),
        ],
      ),
    );
  }

  // ─────────── form ───────────

  Widget _addForm(GratPalette p, GratitudeStore store, GratitudePhaseInfo phase) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${toFa(store.totalCount + 1)} - خدایا شکرت که:',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: p.emerald700,
                  fontSize: 14.5),
            ),
          ),
          TextField(
            controller: _text,
            minLines: 4,
            maxLines: 8,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 14, color: p.ink, height: 1.6),
            decoration: _areaDecoration(p, '🎯 ${phase.prompt}', p.card),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MediaBtn(
                  p: p,
                  icon: Icons.image_outlined,
                  tooltip: 'عکس',
                  onTap: _pickImages),
              _MediaBtn(
                  p: p,
                  icon: Icons.videocam_outlined,
                  tooltip: 'ویدیو',
                  onTap: _pickVideo),
              _MediaBtn(
                  p: p,
                  icon: Icons.mic_none,
                  tooltip: 'ضبط ویس',
                  onTap: _recordVoice),
              _MediaBtn(
                  p: p,
                  icon: Icons.audiotrack,
                  tooltip: 'انتخاب صوت',
                  onTap: _pickAudio),
            ],
          ),
          if (_pendingImages.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < _pendingImages.length; i++)
                  _pendingImg(p, _pendingImages[i].src,
                      () => setState(() => _pendingImages.removeAt(i))),
              ],
            ),
          ],
          if (_pendingAudios.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _pendingAudios.length; i++)
                  _pendingAudio(p, _pendingAudios[i],
                      () => setState(() => _pendingAudios.removeAt(i))),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _VisRadios(
              p: p,
              shared: _shared,
              onChanged: (v) => setState(() => _shared = v)),
          const SizedBox(height: 12),
          _GradButton(
            p: p,
            text: 'ثبت شکرگذاری',
            busy: _saving,
            onTap: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }

  // ─────────── entry card ───────────

  static String _dateLine(GratitudeEntry e) {
    try {
      final d = DateTime.parse(e.iso).toLocal();
      final j = toJalaali(d.year, d.month, d.day);
      final date = '${toFa(j.jd)} ${kJalaliMonths[j.jm - 1]} ${toFa(j.jy)}';
      final t =
          toFa('${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}');
      final day = e.day.isNotEmpty ? e.day : _kWeekdays[d.weekday - 1];
      return '$day $date - $t';
    } catch (_) {
      return '${e.day} ${e.date} - ${e.time}';
    }
  }

  Widget _entryCard(GratPalette p, GratitudeStore store, GratitudeEntry e) {
    final hasAmount = e.amount != null && e.amount! > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _editEntry(e),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.line),
                  ),
                  child: Text(e.icon, style: const TextStyle(fontSize: 19)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        e.displayText(),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: p.ink,
                            height: 1.5),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        alignment: WrapAlignment.start,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Text(_dateLine(e),
                              style:
                                  TextStyle(fontSize: 11.5, color: p.muted)),
                          if (e.editedAt != null)
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 7),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: p.panelBorder),
                              ),
                              child: Text('✏️ ویرایش‌شده',
                                  style: TextStyle(
                                      fontSize: 10, color: p.textDim)),
                            ),
                          if (e.shared)
                            Icon(Icons.public, size: 12, color: p.emerald500),
                        ],
                      ),
                      if (e.emotionIds.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _emotionChips(p, e.emotionIds),
                        ),
                      ],
                      if (e.images.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final im in e.images.take(6))
                              _thumb(p, im.src),
                          ],
                        ),
                      ],
                      for (final a in e.audios)
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: p.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: p.line),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                  a.name.contains('ویس')
                                      ? Icons.mic_none
                                      : Icons.audiotrack,
                                  size: 16,
                                  color: p.emerald700),
                              const SizedBox(width: 8),
                              Text(a.name.isEmpty ? 'صوت' : a.name,
                                  style: TextStyle(
                                      fontSize: 11.5, color: p.muted)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (hasAmount) ...[
                  const SizedBox(width: 12),
                  Text('${_fmtMoney(e.amount!)} تومان',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: p.emerald700)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emotionChips(GratPalette p, List<String> ids) {
    final chips = <Widget>[];
    for (final id in ids.take(4)) {
      final e = emotionById(id);
      if (e == null) continue;
      final c = _hexColor(e.color, p.muted);
      chips.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.withValues(alpha: 0.5)),
        ),
        child: Text(e.fa,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: c)),
      ));
    }
    if (ids.length > 4) {
      chips.add(Text('+${toFa(ids.length - 4)}',
          style: TextStyle(fontSize: 10, color: p.muted)));
    }
    return Wrap(spacing: 5, runSpacing: 5, children: chips);
  }

  Widget _thumb(GratPalette p, String src) {
    final bytes = _decodeSrc(src);
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: p.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes != null
          ? Image.memory(bytes, fit: BoxFit.cover)
          : Icon(Icons.broken_image, color: p.muted, size: 18),
    );
  }
}

// ============================================================
// بنر مسیر (theme-banner وب)
// ============================================================
class _JourneyBanner extends StatelessWidget {
  const _JourneyBanner({required this.phase, required this.store});
  final GratitudePhaseInfo phase;
  final GratitudeStore store;

  @override
  Widget build(BuildContext context) {
    final pct = (phase.day / phase.totalDays).clamp(0.0, 1.0);
    final pastCount = store.journeyPast.length;
    final label =
        '🧭 دوره‌ی ${pastCount > 0 ? '${periodOrdFa(pastCount)} — ' : ''}${toFa(phase.totalDays)} روزه — ${phase.phaseShort}';

    return WebThemeBanner(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xD9FFFFFF))),
              ),
              Text('روز ${toFa(phase.day)} / ${toFa(phase.totalDays)}',
                  style: const TextStyle(
                      fontSize: 10.5, color: Color(0xBFFFFFFF))),
            ],
          ),
          const SizedBox(height: 8),
          Text('فاز ${toFa(phase.phaseIndex + 1)} — ${phase.phaseName}',
              style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Text('🎯 ${phase.prompt}',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xD9FFFFFF), height: 1.6)),
          const SizedBox(height: 12),
          WebBannerBar(value: pct),
        ],
      ),
    );
  }
}

// ============================================================
// تقویم دوره (periodGridHtml / periodInfoHtml وب)
// ============================================================
class _PeriodCalendar extends StatefulWidget {
  const _PeriodCalendar({required this.store});
  final GratitudeStore store;
  @override
  State<_PeriodCalendar> createState() => _PeriodCalendarState();
}

class _PeriodCalendarState extends State<_PeriodCalendar> {
  final Set<int> _open = {};

  static int _countDone(DateTime start, int total, Set<String> done) {
    var n = 0;
    for (var d = 0; d < total; d++) {
      final dt = DateTime(start.year, start.month, start.day + d);
      if (done.contains(_dayKey(dt))) n++;
    }
    return n;
  }

  Widget _cell(GratPalette p, double size,
      {required bool done,
      required bool isToday,
      required bool future,
      required bool monthEnd,
      Color? ring,
      VoidCallback? onTap}) {
    final radius = BorderRadius.circular(4);
    Widget inner = Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: done
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [p.emerald700, p.emerald500])
            : null,
        border: (ring == null && !monthEnd && !done)
            ? Border.all(color: p.line)
            : null,
        boxShadow: ring != null
            ? [BoxShadow(color: ring, spreadRadius: 2)]
            : null,
      ),
      alignment: Alignment.center,
      child: done
          ? const Text('✓',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1))
          : null,
    );
    if (monthEnd && ring == null) {
      inner = ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned.fill(child: inner),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 3,
              child: ColoredBox(color: p.gold500),
            ),
          ],
        ),
      );
    }
    Widget cell = SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: inner),
          if (isToday)
            Positioned(
              left: -1.5,
              top: -1.5,
              right: -1.5,
              bottom: -1.5,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5.5),
                    border: Border.all(color: p.emerald500, width: 1.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (future) cell = Opacity(opacity: 0.3, child: cell);
    if (onTap != null) cell = GestureDetector(onTap: onTap, child: cell);
    return cell;
  }

  Widget _grid(GratPalette p, DateTime start, int total, Set<String> done,
      {required bool current}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayKey = _dayKey(today);
    const block = 30;
    const cols = 15;
    return LayoutBuilder(builder: (ctx, box) {
      final size = ((box.maxWidth - (cols - 1) * 3 - 0.5) / cols)
          .clamp(8.0, 60.0)
          .toDouble();
      final blocks = <Widget>[];
      for (var b = 0; b * block < total; b++) {
        final from = b * block;
        final to = (from + block) > total ? total : from + block;
        final d0 = DateTime(start.year, start.month, start.day + from);
        final d1 = DateTime(start.year, start.month, start.day + to - 1);
        final cells = <Widget>[];
        for (var d = from; d < to; d++) {
          final date = DateTime(start.year, start.month, start.day + d);
          final key = _dayKey(date);
          final isDone = done.contains(key);
          Color? ring;
          if (current) {
            final hex = widget.store.dominantEmotionColorForDay(key);
            if (hex != null) ring = _hexColor(hex, p.emerald500);
          }
          cells.add(_cell(
            p,
            size,
            done: isDone,
            isToday: key == todayKey,
            future: date.isAfter(today),
            monthEnd: (d % block) == block - 1 || d == total - 1,
            ring: ring,
            onTap: (current && isDone)
                ? () => _openDayEmotions(context, widget.store, key)
                : null,
          ));
        }
        blocks.add(Padding(
          padding: EdgeInsets.fromLTRB(2, b == 0 ? 0 : 8, 2, 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ماه ${periodOrdFa(b)}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: p.ink)),
              Text('${_faDayMonth(d0)} تا ${_faDayMonth(d1)}',
                  style: TextStyle(fontSize: 10.5, color: p.muted)),
            ],
          ),
        ));
        blocks.add(Wrap(
          textDirection: TextDirection.rtl,
          spacing: 3,
          runSpacing: 3,
          children: cells,
        ));
      }
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: blocks,
        ),
      );
    });
  }

  Future<String?> _askDays(GratPalette p, String title, int initial) {
    final ctrl = TextEditingController(text: '$initial');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.card,
        title: Text(title,
            style: TextStyle(
                fontSize: 14.5, fontWeight: FontWeight.w800, color: p.ink)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: TextStyle(color: p.ink),
          decoration: _areaDecoration(p, '', p.surface),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('انصراف', style: TextStyle(color: p.muted))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: Text('تأیید', style: TextStyle(color: p.emerald700))),
        ],
      ),
    );
  }

  Future<void> _setDays(GratPalette p) async {
    final store = widget.store;
    final input = await _askDays(
        p,
        'دوره‌ی ${periodOrdFa(store.journeyPast.length)} چند روزه باشه؟',
        store.journeyDays);
    if (input == null || !mounted) return;
    final n = _parseDays(input);
    if (n == 0) {
      _toast(context, 'یه عدد معتبر بزرگ‌تر از صفر وارد کن');
      return;
    }
    await store.setJourneyDays(n);
    if (mounted) _toast(context, 'دوره روی ${toFa(n)} روز تنظیم شد 🌱');
  }

  Future<void> _startNew(GratPalette p) async {
    final store = widget.store;
    final input = await _askDays(
        p,
        'دوره‌ی ${periodOrdFa(store.journeyPast.length + 1)} چند روزه باشه؟',
        store.journeyDays);
    if (input == null || !mounted) return;
    final n = _parseDays(input);
    if (n == 0) {
      _toast(context, 'یه عدد معتبر بزرگ‌تر از صفر وارد کن');
      return;
    }
    await store.startNewJourney(days: n);
    if (mounted) {
      _toast(context, 'دوره‌ی ${periodOrdFa(store.journeyPast.length)} شروع شد 🌱');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = GratPalette.of(context);
    final store = widget.store;
    final done = store.doneDayKeys;
    final start = _parseKey(store.journeyStart);
    final total = store.journeyDays;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(start.year, start.month, start.day + total);
    final finished = !today.isBefore(end);
    final doneCount = _countDone(start, total, done);
    final ord = periodOrdFa(store.journeyPast.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.line),
          ),
          child: _grid(p, start, total, done, current: true),
        ),
        const SizedBox(height: 10),
        if (finished) ...[
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color.fromRGBO(230, 205, 142, 0.25),
              border: Border.all(color: p.gold300),
            ),
            child: Text(
              '🎉🥳 دوره‌ی $ord رو تموم کردی! ${toFa(doneCount > total ? total : doneCount)} روز از ${toFa(total)} روز شکرگذاری کردی.\nبرای ادامه دوره‌ی بعدی رو شروع کن — دوره‌های قبلی همین‌جا می‌مونن.',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.8,
                  color: p.ink),
            ),
          ),
          const SizedBox(height: 8),
          _TinyBtn(
            p: p,
            gold: true,
            text: '▶️ شروع دوره‌ی ${periodOrdFa(store.journeyPast.length + 1)}',
            onTap: () => _startNew(p),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _TinyBtn(
              p: p,
              text: '⚙️ روزهای دوره (الان ${toFa(total)} روزه)',
              onTap: () => _setDays(p),
            ),
          ),
        if (store.journeyPast.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (var i = store.journeyPast.length - 1; i >= 0; i--)
            _pastCard(p, i, done),
        ],
      ],
    );
  }

  Widget _pastCard(GratPalette p, int i, Set<String> done) {
    final past = widget.store.journeyPast[i];
    final days = (past['days'] as int?) ?? 0;
    final st = _parseKey(past['startDate']?.toString() ?? '');
    final cnt = _countDone(st, days, done);
    final open = _open.contains(i);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() {
              if (open) {
                _open.remove(i);
              } else {
                _open.add(i);
              }
            }),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('✅ دوره‌ی ${periodOrdFa(i)} — ${toFa(days)} روزه',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: p.ink)),
                Text('${toFa(cnt)} / ${toFa(days)}',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: p.ink)),
              ],
            ),
          ),
          if (open) ...[
            const SizedBox(height: 10),
            _grid(p, st, days, done, current: false),
          ],
        ],
      ),
    );
  }

  static void _openDayEmotions(
    BuildContext context,
    GratitudeStore store,
    String dayKey,
  ) {
    final emotions = context.read<EmotionStore>();
    final current = store.emotionIdsForDay(dayKey).toList();
    final date = _parseKey(dayKey);

    emotions.beginCapture(
      phase: 'entry',
      practiceKey: 'gratitude',
      label: _faDayMonth(date),
      initial: current,
      entryId: dayKey,
      onSave: (ids) async {
        await store.updateDayEmotions(dayKey, ids);
      },
    );
  }
}

// ============================================================
// ویرایش (grat-edit-modal وب)
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
  late List<GratitudeAudio> _audios;
  late bool _shared;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.entry.text);
    _images = List.of(widget.entry.images);
    _audios = List.of(widget.entry.audios);
    _shared = widget.entry.shared;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.store.update(
      widget.entry.id,
      text: _text.text.trim(),
      images: _images,
      audios: _audios,
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

  Future<void> _pickVideo() async {
    final src = await ImageService.pickVideo();
    if (!mounted) return;
    if (src == null) {
      _toast(context, 'ویدیو انتخاب نشد یا حجمش بیشتر از ۸ مگابایت بود');
      return;
    }
    setState(() => _images.add(GratitudeImage(src: src)));
  }

  Future<void> _pickAudio() async {
    final src = await ImageService.pickAudio();
    if (!mounted) return;
    if (src == null) {
      _toast(context, 'صوت انتخاب نشد یا حجمش بیشتر از ۵ مگابایت بود');
      return;
    }
    setState(() => _audios.add(GratitudeAudio(src: src, name: 'صوت')));
  }

  Future<void> _recordVoice() async {
    final src = await VoiceRecorderSheet.show(context, title: 'ضبط ویس جدید');
    if (!mounted || src == null) return;
    setState(() => _audios.add(GratitudeAudio(src: src, name: 'ویس ضبط‌شده')));
  }

  @override
  Widget build(BuildContext context) {
    final p = GratPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: const [
          BoxShadow(
              color: Color.fromRGBO(10, 40, 35, 0.16),
              blurRadius: 45,
              offset: Offset(0, 20)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 26,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🙏',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 34)),
                const SizedBox(height: 6),
                Text('ویرایش شکرگذاری',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: p.ink)),
                const SizedBox(height: 14),
                TextField(
                  controller: _text,
                  minLines: 4,
                  maxLines: 8,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontSize: 14, color: p.ink, height: 1.6),
                  decoration:
                      _areaDecoration(p, 'متن شکرگذاری...', p.surface),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MediaBtn(
                        p: p,
                        icon: Icons.image_outlined,
                        tooltip: 'عکس',
                        onTap: _pickImages),
                    _MediaBtn(
                        p: p,
                        icon: Icons.videocam_outlined,
                        tooltip: 'ویدیو',
                        onTap: _pickVideo),
                    _MediaBtn(
                        p: p,
                        icon: Icons.mic_none,
                        tooltip: 'ضبط ویس',
                        onTap: _recordVoice),
                    _MediaBtn(
                        p: p,
                        icon: Icons.audiotrack,
                        tooltip: 'انتخاب صوت',
                        onTap: _pickAudio),
                  ],
                ),
                if (_images.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < _images.length; i++)
                        _pendingImg(p, _images[i].src,
                            () => setState(() => _images.removeAt(i))),
                    ],
                  ),
                ],
                if (_audios.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _audios.length; i++)
                        _pendingAudio(p, _audios[i],
                            () => setState(() => _audios.removeAt(i))),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                _VisRadios(
                    p: p,
                    shared: _shared,
                    onChanged: (v) => setState(() => _shared = v)),
                const SizedBox(height: 16),
                _GradButton(p: p, text: 'ذخیره تغییرات', onTap: _save),
                const SizedBox(height: 8),
                _ghostBtn(p, '🗑 حذف این شکرگذاری', _delete),
                const SizedBox(height: 8),
                _ghostBtn(p, 'انصراف', () => Navigator.pop(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
