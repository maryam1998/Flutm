import 'dart:io' show File;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../map/draw_utils.dart' show toFa;
import '../models/constants.dart';
import '../services/fast_image.dart';
import '../state/angels_store.dart';
import '../state/background_store.dart';
import '../state/map_store.dart';
import '../state/theme_store.dart';
import '../widgets/web_color_picker.dart';
import 'motivation_sheet.dart';

const _kCream = Color(0xFFFBF6EA);
const _kCard = Colors.white;
const _kGold = Color(0xFFC9972B);
const _kInk = Color(0xFF2A2218);
const _kMuted = Color(0xFF7A6B57);
const _kBorder = Color(0xFFE0D5C0);
const _kDanger = Color(0xFFE5484D);

/// منوی همبرگری: از سمت چپ باز می‌شود، کل صفحه را نمی‌گیرد.
Future<void> showSettingsSheet(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'بستن تنظیمات',
    barrierColor: Colors.black.withAlpha(100),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, _, __) {
      final w = MediaQuery.sizeOf(ctx).width;
      return Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: (w * 0.78).clamp(260.0, 340.0).toDouble(),
          height: double.infinity,
          child: const _SettingsSheet(),
        ),
      );
    },
    transitionBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();
  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late Color _textColor;
  late double _fontSize;
  late bool _showDates;
  late bool _showTimes;
  late bool _showRingLinks;
  late bool _showEmotionWidget;
  late String _trunkStyle;
  late double _footScale;
  late String _userName;
  late TextEditingController _nameCtrl;
  bool _inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    final s = context.read<MapStore>().state;
    _textColor = _parseTextColor(s.textColor);
    _fontSize = s.fontSize.clamp(8.0, 28.0).toDouble();
    _showDates = s.showDateStamps;
    _showTimes = s.showTimeStamps;
    _showRingLinks = s.showRingLinks;
    _showEmotionWidget = s.showEmotionWidget;
    _trunkStyle =
        kTrunkStyles.containsKey(s.trunkStyle) ? s.trunkStyle : 'dashed';
    _footScale = s.footScale.clamp(0.4, 3.0).toDouble();
    _userName = s.userName;
    _nameCtrl = TextEditingController(text: _userName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Color _parseTextColor(String c) {
    final lc = c.toLowerCase().trim();
    const auto = {'', '#eef0fa', '#ffffff', '#fff', '#000000', '#000'};
    if (auto.contains(lc)) return Colors.white;
    return hexColor(c, Colors.white);
  }

  void _save() {
    final store = context.read<MapStore>();
    final s = store.state;
    s.textColor = _hexFromColor(_textColor);
    s.fontSize = _fontSize;
    s.showDateStamps = _showDates;
    s.showTimeStamps = _showTimes;
    s.showRingLinks = _showRingLinks;
    s.showEmotionWidget = _showEmotionWidget;
    s.trunkStyle = _trunkStyle;
    s.footScale = _footScale;
    s.userName = _nameCtrl.text.trim();
    store.changed();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تنظیمات ذخیره شد')),
    );
  }

  String _hexFromColor(Color c) {
    int v(double x) => (x * 255).round().clamp(0, 255);
    return '#${v(c.r).toRadixString(16).padLeft(2, '0')}'
            '${v(c.g).toRadixString(16).padLeft(2, '0')}'
            '${v(c.b).toRadixString(16).padLeft(2, '0')}'
        .toLowerCase();
  }

  static const _imgExts = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'apng', 'bmp', 'avif', 'heic', 'heif',
  };
  static const _vidExts = {
    'mp4', 'mov', 'webm', 'm4v', 'mkv', '3gp', 'avi', 'ogv',
  };

  static String _extOf(String name) {
    final i = name.lastIndexOf('.');
    return i < 0 ? '' : name.substring(i + 1).toLowerCase();
  }

  /// نوع فایل: 'image' | 'video' | null — اول از روی پسوند، بعد از روی محتوای فایل
  static String? _kindOf(String name, Uint8List b) {
    final e = _extOf(name);
    if (_imgExts.contains(e)) return 'image';
    if (_vidExts.contains(e)) return 'video';
    if (b.length < 12) return null;
    bool at(int o, String t) {
      for (var i = 0; i < t.length; i++) {
        if (b[o + i] != t.codeUnitAt(i)) return false;
      }
      return true;
    }

    if (at(0, 'GIF8') || at(1, 'PNG') || (b[0] == 0xFF && b[1] == 0xD8)) {
      return 'image';
    }
    if (at(0, 'RIFF') && at(8, 'WEBP')) return 'image';
    if (at(4, 'ftyp')) return 'video';
    if (b[0] == 0x1A && b[1] == 0x45 && b[2] == 0xDF && b[3] == 0xA3) {
      return 'video';
    }
    return null;
  }

  static String _mimeOfVideo(String name) {
    switch (_extOf(name)) {
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'm4v':
        return 'video/x-m4v';
      case 'mkv':
        return 'video/x-matroska';
      case '3gp':
        return 'video/3gpp';
      case 'avi':
        return 'video/x-msvideo';
      case 'ogv':
        return 'video/ogg';
      default:
        return 'video/mp4';
    }
  }

  /// انتخاب از فایل‌منیجر (FileType.any تا روی کروم اندروید گالری/Google Photos
  /// باز نشه و همه‌ی فرمت‌ها — gif/webp/mp4/jpg/png و... — قابل انتخاب باشن).
  /// عکس‌ها دست‌نخورده ذخیره می‌شن تا GIF و WebP متحرک، متحرک بمونن.
  Future<void> _addAngelFiles(AngelsStore angels) async {
    var added = 0;
    var failed = 0;
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
        // روی موبایل/دسکتاپ فقط مسیر کافیه؛ روی وب بایت‌ها لازمه
        withData: kIsWeb,
      );
      if (res == null) return;
      for (final f in res.files) {
        Uint8List? bytes = f.bytes;
        if ((bytes == null || bytes.isEmpty) && !kIsWeb && f.path != null) {
          bytes = await File(f.path!).readAsBytes();
        }
        if (bytes == null || bytes.isEmpty) {
          failed++;
          continue;
        }
        final kind = _kindOf(f.name, bytes);
        bool ok = false;
        if (kind == 'image') {
          // فرشته‌ها کوچیک نمایش داده می‌شن؛ عکس خام چندمگابایتی فقط ذخیره و بالا اومدن رو کند می‌کرد
          final small =
              await fastDownscale(bytes, name: f.name, maxSide: 512);
          ok = await angels.addImage(small);
        } else if (kind == 'video') {
          ok = await angels.addVideo(
            name: f.name,
            mime: _mimeOfVideo(f.name),
            bytes: bytes,
          );
        }
        if (ok) {
          added++;
        } else {
          failed++;
        }
      }
    } catch (e) {
      debugPrint('angel pick files: $e');
      failed++;
    }
    if (!mounted || failed == 0) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(added > 0
          ? '$added فایل اضافه شد؛ ${failed.toString()} فایل پشتیبانی نشد'
          : 'فایل اضافه نشد؛ فرمت پشتیبانی نمی‌شود یا فایل خوانده نشد'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kCream,
      elevation: 12,
      borderRadius:
          const BorderRadius.horizontal(right: Radius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'تنظیمات',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _kInk,
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 36),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('انصراف',
                        style: TextStyle(color: _kMuted, fontSize: 12.5)),
                  ),
                  const SizedBox(width: 2),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _kGold,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    onPressed: _save,
                    child: const Text('ذخیره',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _kBorder),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ═══════════ تم ═══════════
                    Consumer<ThemeStore>(
                      builder: (_, theme, __) => _tile(
                        title: 'تم تاریک',
                        subtitle: theme.isDark
                            ? 'پس‌زمینه‌ی تیره با متن روشن'
                            : 'پس‌زمینه‌ی روشن',
                        trailing: Switch(
                          value: theme.isDark,
                          activeThumbColor: _kGold,
                          onChanged: (v) => theme.setDark(v),
                        ),
                      ),
                    ),
                    const _SectionDivider(),

                    // ═══════════ ایمیل ورود ═══════════
                    _sectionTitle('ایمیل ورود'),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kBorder),
                      ),
                      child: const Text(
                        '—',
                        style: TextStyle(fontSize: 13, color: _kMuted),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'در نسخه‌ی Flutter هنوز ورود پیاده نشده',
                      style: TextStyle(fontSize: 10.5, color: _kMuted),
                    ),
                    const _SectionDivider(),

                    // ═══════════ نام شما ═══════════
                    _sectionTitle(
                        'نام شما (در بخش دوستان با همین نام نمایش داده می‌شود)'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameCtrl,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(fontSize: 13, color: _kInk),
                      decoration: InputDecoration(
                        hintText: 'مثلاً مریم',
                        hintStyle: const TextStyle(
                            fontSize: 12, color: _kMuted),
                        filled: true,
                        fillColor: _kCard,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _kBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _kBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: _kGold, width: 1.5),
                        ),
                      ),
                    ),
                    const _SectionDivider(),

                    // ═══════════ رنگ نوشته‌ها ═══════════
                    _sectionTitle('رنگ نوشته‌ها'),
                    const SizedBox(height: 10),
                    WebColorPicker(
                      value: _textColor,
                      onChanged: (c) => setState(() => _textColor = c),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: _textColor,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: _kBorder, width: 1.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'رنگ انتخابی: ${_hexFromColor(_textColor)}',
                          style: const TextStyle(
                              fontSize: 11.5, color: _kMuted),
                        ),
                      ],
                    ),
                    const _SectionDivider(),

                    // ═══════════ اندازه فونت ═══════════
                    Row(
                      children: [
                        Flexible(
                            child: _sectionTitle('اندازه فونت (پیش‌فرض ۱۴)')),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: _kGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            toFa(_fontSize.round()),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _kGold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _kGold,
                        thumbColor: _kGold,
                        inactiveTrackColor: _kBorder,
                        overlayColor: _kGold.withValues(alpha: 0.15),
                      ),
                      child: Slider(
                        min: 8,
                        max: 28,
                        divisions: 20,
                        value: _fontSize,
                        label: toFa(_fontSize.round()),
                        onChanged: (v) => setState(() => _fontSize = v),
                      ),
                    ),
                    const _SectionDivider(),

                    // ═══════════ چک‌باکس‌ها ═══════════
                    _checkTile(
                      title:
                          'نمایش «تاریخ» ثبت هدف‌ها و شاخه‌ها روی صفحه اصلی',
                      value: _showDates,
                      onChanged: (v) => setState(() => _showDates = v),
                    ),
                    _checkTile(
                      title:
                          'نمایش «ساعت» ثبت هدف‌ها و شاخه‌ها روی صفحه اصلی',
                      value: _showTimes,
                      onChanged: (v) => setState(() => _showTimes = v),
                    ),
                    _checkTile(
                      title:
                          'نمایش خط‌چینِ اتصال نشانه‌های نزدیکی به هدف',
                      value: _showRingLinks,
                      onChanged: (v) => setState(() => _showRingLinks = v),
                    ),
                    const _SectionDivider(),

                    // ═══════════ نوع خط پیش‌فرض ═══════════
                    _sectionTitle(
                        'نوع خط پیش‌فرض مسیر اهداف (برای هر هدف جداگانه هم می‌شه عوضش کرد)'),
                    const SizedBox(height: 10),
                    _trunkPicker(),
                    const _SectionDivider(),

                    // ═══════════ اندازه‌ی رد پا ═══════════
                    Row(
                      children: [
                        Flexible(child: _sectionTitle('اندازه‌ی رد پا 👣')),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: _kGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${(_footScale * 100).round()}٪',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _kGold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _kGold,
                        thumbColor: _kGold,
                        inactiveTrackColor: _kBorder,
                        overlayColor: _kGold.withValues(alpha: 0.15),
                      ),
                      child: Slider(
                        min: 0.4,
                        max: 3.0,
                        divisions: 26,
                        value: _footScale,
                        label: '${(_footScale * 100).round()}٪',
                        onChanged: (v) => setState(() => _footScale = v),
                      ),
                    ),
                    const _SectionDivider(),

                    // ═══════════ ویجت شناور احساسات ═══════════
                    _checkTile(
                      title:
                          'نمایش ویجت شناور «آدم و احساسات» روی صفحه (در تمام تب‌ها)',
                      value: _showEmotionWidget,
                      onChanged: (v) =>
                          setState(() => _showEmotionWidget = v),
                    ),
                    const _SectionDivider(),

                    // ═══════════ پس‌زمینه ═══════════
                    _sectionTitle('پس‌زمینه'),
                    const SizedBox(height: 10),
                    Consumer<BackgroundStore>(
                      builder: (_, bg, __) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('رنگ پس‌زمینه‌ی اپ',
                              style:
                                  TextStyle(fontSize: 12, color: _kMuted)),
                          const SizedBox(height: 8),
                          WebColorPicker(
                            value: bg.color ?? Colors.white,
                            onChanged: (c) => bg.setColor(c),
                          ),
                          if (bg.color != null)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton(
                                onPressed: () => bg.setColor(null),
                                child: const Text('بازگشت به رنگ پیش‌فرض',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _kInk,
                                    side: const BorderSide(color: _kBorder),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final ok = await bg.pickImage();
                                    if (ok && context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'تصویر پس‌زمینه ثبت شد')));
                                    }
                                  },
                                  icon: const Icon(Icons.image_outlined,
                                      size: 18),
                                  label: const Text('تصویر (jpg/png/gif)',
                                      style: TextStyle(fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _kInk,
                                    side: const BorderSide(color: _kBorder),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final ok = await bg.pickVideo();
                                    if (ok && context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content:
                                                  Text('ویدیو پس‌زمینه ثبت شد')));
                                    }
                                  },
                                  icon: const Icon(Icons.videocam_outlined,
                                      size: 18),
                                  label: const Text('ویدیو (بی‌صدا)',
                                      style: TextStyle(fontSize: 12)),
                                ),
                              ),
                              if (bg.hasBackground) ...[
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: _kDanger),
                                  onPressed: () => bg.clear(),
                                ),
                              ],
                            ],
                          ),
                          if (bg.hasBackground) ...[
                            const SizedBox(height: 6),
                            Text(
                              bg.kind == BgKind.image
                                  ? 'تصویر فعال'
                                  : 'ویدیو فعال',
                              style: const TextStyle(
                                  fontSize: 11, color: _kMuted),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Text('محو بودن پس‌زمینه (Blur)',
                                    style: TextStyle(
                                        fontSize: 12, color: _kMuted)),
                                Expanded(
                                  child: Slider(
                                    min: 0,
                                    max: 20,
                                    divisions: 20,
                                    value: bg.blur,
                                    activeColor: _kGold,
                                    inactiveColor: _kBorder,
                                    onChanged: (v) => bg.setBlur(v),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Text('شفافیت پس‌زمینه',
                                    style: TextStyle(
                                        fontSize: 12, color: _kMuted)),
                                Expanded(
                                  child: Slider(
                                    min: 0.1,
                                    max: 1.0,
                                    value: bg.opacity,
                                    activeColor: _kGold,
                                    inactiveColor: _kBorder,
                                    onChanged: (v) => bg.setOpacity(v),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const _SectionDivider(),

                    // ═══════════ angels ═══════════
                    _sectionTitle('افزودن موارد بیشتر به پیش‌زمینه'),
                    const SizedBox(height: 10),
                    Consumer<AngelsStore>(
                      builder: (_, angels, __) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (angels.hasAssets)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final im in angels.images)
                                  _angelImageThumb(
                                    bytes: im.bytes,
                                    onDelete: () =>
                                        angels.removeImage(im.id),
                                  ),
                                for (final v in angels.videos)
                                  _angelVideoThumb(
                                    name: v.name,
                                    onDelete: () =>
                                        angels.removeVideo(v.id),
                                  ),
                              ],
                            ),
                          if (angels.hasAssets)
                            const SizedBox(height: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _kInk,
                              side: const BorderSide(color: _kBorder),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => _addAngelFiles(angels),
                            icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 18),
                            label: const Text(
                                '＋ افزودن عکس / GIF / ویدیو',
                                style: TextStyle(fontSize: 12.5)),
                          ),
                          const SizedBox(height: 10),
                          _checkTile(
                            title: 'نمایش روی همه‌ی تب‌ها',
                            value: angels.on,
                            onChanged: (v) => angels.setOn(v),
                          ),
                          _checkTile(
                            title:
                                'نمایش روی عکس‌ها و ویدیوها در حالت تمام‌صفحه',
                            value: angels.fs,
                            onChanged: (v) => angels.setFs(v),
                          ),
                          const SizedBox(height: 4),
                          _angelSlider(
                            label: 'اندازه',
                            value: angels.size,
                            min: 60,
                            max: 320,
                            onChanged: (v) => angels.setSize(v),
                          ),
                          _angelSlider(
                            label: 'سرعت',
                            value: angels.speed,
                            min: 1,
                            max: 12,
                            onChanged: (v) => angels.setSpeed(v),
                          ),
                          _angelSlider(
                            label: 'شفافیت',
                            value: angels.opacity * 100,
                            min: 20,
                            max: 100,
                            onChanged: (v) => angels.setOpacity(v / 100),
                          ),
                          _checkTile(
                            title: 'محو کردن لبه‌ها',
                            value: angels.soft,
                            onChanged: (v) => angels.setSoft(v),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _kBorder),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: angels.blend,
                                isExpanded: true,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _kInk,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'normal',
                                    child: Text('حالت: عادی'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'screen',
                                    child: Text('حالت: محو تیره‌ها'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'multiply',
                                    child: Text('حالت: محو سفیدها'),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v != null) angels.setBlend(v);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const _SectionDivider(),

                    // ═══════════ جمله‌های انگیزه‌بخش ═══════════
                    _sectionTitle('جمله‌های انگیزه‌بخش'),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kInk,
                          side: const BorderSide(color: _kBorder),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => showMotivationSheet(context),
                        icon: const Icon(Icons.auto_awesome,
                            size: 18, color: _kGold),
                        label: const Text(
                            'مدیریت جمله‌های انگیزه‌بخش',
                            style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ═══════════ دکمه‌های پایین ═══════════
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _kMuted,
                              side: const BorderSide(color: _kBorder),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('انصراف',
                                style: TextStyle(fontSize: 13.5)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _kGold,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _save,
                            child: const Text(
                              'ذخیره',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ═══════════ خروج از حساب ═══════════
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kDanger,
                          side: const BorderSide(color: _kDanger),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'خروج از حساب هنوز فعال نشده (نیاز به Supabase)'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('خروج از حساب',
                            style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _angelImageThumb({
    required Uint8List bytes,
    required VoidCallback onDelete,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.memory(bytes,
              fit: BoxFit.cover, gaplessPlayback: true),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close,
                  size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _angelVideoThumb({
    required String name,
    required VoidCallback onDelete,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: const Center(
            child: Icon(Icons.play_circle_outline,
                color: _kGold, size: 28),
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close,
                  size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: _kMuted,
        ),
      );

  Widget _tile({
    required String title,
    String? subtitle,
    required Widget trailing,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: _kInk)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle,
                          style: const TextStyle(
                              fontSize: 11.5, color: _kMuted)),
                    ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      );

  Widget _checkTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: value,
              activeColor: _kGold,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: const BorderSide(color: _kBorder, width: 1.5),
              onChanged: (v) => onChanged(v ?? false),
            ),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 12.5, color: _kInk),
              ),
            ),
          ],
        ),
      );

  Widget _angelSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: _kMuted),
            ),
          ),
          Expanded(
            child: Slider(
              min: min,
              max: max,
              value: value.clamp(min, max),
              activeColor: _kGold,
              inactiveColor: _kBorder,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trunkPicker() {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.05,
      children: [
        for (final e in kTrunkStyles.entries)
          GestureDetector(
            onTap: () => setState(() => _trunkStyle = e.key),
            child: Container(
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _trunkStyle == e.key ? _kGold : _kBorder,
                  width: _trunkStyle == e.key ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 44,
                    height: 24,
                    child: CustomPaint(
                      painter: _TrunkPreviewPainter(
                        style: e.key,
                        color: _trunkStyle == e.key
                            ? _kGold
                            : _kMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    e.value,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: _trunkStyle == e.key
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: _trunkStyle == e.key ? _kGold : _kInk,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Divider(height: 1, color: _kBorder),
      );
}

class _TrunkPreviewPainter extends CustomPainter {
  _TrunkPreviewPainter({required this.style, required this.color});
  final String style;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = color;

    final a = Offset(2, size.height * 0.8);
    final b = Offset(size.width - 2, size.height * 0.2);
    final dir = b - a;
    final len = dir.distance;
    if (len == 0) return;
    final n = dir / len;

    switch (style) {
      case 'solid':
        canvas.drawLine(a, b, p);
      case 'dotted':
        for (var i = 0; i < 8; i++) {
          final pt = a + n * (len * i / 7);
          canvas.drawCircle(pt, 1, Paint()..color = color);
        }
      case 'dashdot':
        _dash(canvas, a, b, p, len, n, [4, 2, 1, 2]);
      case 'long':
        _dash(canvas, a, b, p, len, n, [7, 4]);
      case 'double':
        final perp = Offset(-n.dy, n.dx) * 1.3;
        canvas.drawLine(a + perp, b + perp, p..strokeWidth = 1.3);
        canvas.drawLine(
            a - perp,
            b - perp,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.3
              ..strokeCap = StrokeCap.round
              ..color = color);
      case 'glow':
        canvas.drawLine(
            a,
            b,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5
              ..strokeCap = StrokeCap.round
              ..color = color.withValues(alpha: 0.30));
        canvas.drawLine(a, b, p..strokeWidth = 1.5);
      case 'taper':
        for (var i = 0; i < 6; i++) {
          final p1 = a + n * (len * i / 6);
          final p2 = a + n * (len * (i + 1) / 6);
          canvas.drawLine(
              p1,
              p2,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3 - i * 0.35
                ..strokeCap = StrokeCap.round
                ..color = color);
        }
      default:
        _dash(canvas, a, b, p, len, n, [3, 3]);
    }
  }

  void _dash(Canvas canvas, Offset a, Offset b, Paint p, double len, Offset n,
      List<double> dashes) {
    var d = 0.0;
    var i = 0;
    while (d < len) {
      final seg = dashes[i % dashes.length];
      if (i.isEven) {
        final s = a + n * d;
        final e = a + n * (d + seg > len ? len : d + seg);
        canvas.drawLine(s, e, p);
      }
      d += seg;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _TrunkPreviewPainter old) =>
      old.style != style || old.color != color;
}
