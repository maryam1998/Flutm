import 'dart:io' show File;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../map/draw_utils.dart' show toFa;
import '../models/constants.dart';
import '../models/map_models.dart';
import '../services/fast_image.dart';
import '../state/angels_store.dart';
import '../state/background_store.dart';
import '../state/map_store.dart';
import '../state/theme_store.dart';
import '../widgets/web_color_picker.dart';
import 'motivation_sheet.dart';
import '../services/quiet_snack.dart';

// پالت دقیقِ Maghz (html[data-theme="light"] در css/base-and-map.css)
const _kSheet = Color.fromRGBO(246, 247, 251, 0.98); // کفِ پنجره
const _kField = Color(0xFFF4F5FA); // زمینه‌ی ورودی/کلید
const _kGold = Color(0xFFC9962B); // --accent
const _kInk = Color(0xFF000000); // --text-main
const _kMuted = Color(0xFF5B5F77); // --text-dim
const _kBorder = Color.fromRGBO(20, 24, 50, 0.10); // --panel-border
const _kDanger = Color(0xFFE5484D);

/// پنجره‌ی تنظیمات — مثل `.overlay` + `.modal` در Maghz:
/// پرده‌ی rgba(5,6,14,.6)، کادر وسط‌صفحه تا min(360px, 90vw)، گوشه ۱۸،
/// پس‌زمینه‌ی نیمه‌شفاف (--panel-bg) تا پس‌زمینه‌ی برنامه پشتش دیده شود.
Future<void> showSettingsSheet(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'بستن تنظیمات',
    barrierColor: const Color.fromRGBO(5, 6, 14, 0.6),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, _, __) {
      final sz = MediaQuery.sizeOf(ctx);
      final w = sz.width * 0.94 < 420 ? sz.width * 0.94 : 420.0;
      // نوشته‌های پنجره‌ی تنظیمات کمی کوچک‌تر از اندازه‌ی کلی برنامه
      final base = MediaQuery.textScalerOf(ctx).scale(1.0);
      return MediaQuery(
        data: MediaQuery.of(ctx)
            .copyWith(textScaler: TextScaler.linear(base * 0.86)),
        child: Center(
          child: SizedBox(
            width: w,
            height: sz.height - 32,
            child: const _SettingsSheet(),
          ),
        ),
      );
    },
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
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
  late double _uiScale;
  bool _applyToAll = true;
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
    _fontSize = s.fontSize.clamp(8.0, 40.0).toDouble();
    _uiScale = context.read<ThemeStore>().textScale;
    _showDates = s.showDateStamps;
    _showTimes = s.showTimeStamps;
    _showRingLinks = s.showRingLinks;
    _showEmotionWidget = s.showEmotionWidget;
    _trunkStyle =
        kTrunkStyles.containsKey(s.trunkStyle) ? s.trunkStyle : 'dashed';
    _footScale = s.footScale.clamp(kWalkerSizeMin, kFootScaleMax).toDouble();
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
    final newColor = _hexFromColor(_textColor);
    final styleChanged =
        newColor != s.textColor || (_fontSize - s.fontSize).abs() > 0.01;
    s.textColor = newColor;
    s.fontSize = _fontSize;
    // اندازه/رنگ اختصاصیِ تک‌تک گره‌ها روی تنظیم کلی غلبه می‌کند؛
    // با این گزینه همه به تنظیم کلی برمی‌گردند تا تغییر واقعاً دیده شود.
    if (_applyToAll && styleChanged) _clearNodeStyles(s);
    s.showDateStamps = _showDates;
    s.showTimeStamps = _showTimes;
    s.showRingLinks = _showRingLinks;
    s.showEmotionWidget = _showEmotionWidget;
    s.trunkStyle = _trunkStyle;
    s.footScale = _footScale;
    s.userName = _nameCtrl.text.trim();
    store.changedNow();
    context.read<ThemeStore>().setTextScale(_uiScale);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).quietSnack(
      const SnackBar(content: Text('تنظیمات ذخیره شد')),
    );
  }

  void _clearNodeStyles(MapState s) {
    void acts(List<ActionNode> list) {
      for (final a in list) {
        a.labelSize = null;
        a.extra.remove('labelColor');
        acts(a.children);
      }
    }

    s.me.labelSize = null;
    for (final g in s.goals) {
      g.labelSize = null;
      g.extra.remove('labelColor');
      acts(g.actions);
    }
    for (final r in s.rings) {
      r.labelSize = null;
      r.extra.remove('labelColor');
      acts(r.actions);
    }
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
              await fastDownscale(bytes, name: f.name, maxSide: 1280);
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
    ScaffoldMessenger.of(context).quietSnack(SnackBar(
      content: Text(added > 0
          ? '$added فایل اضافه شد؛ ${failed.toString()} فایل پشتیبانی نشد'
          : 'فایل اضافه نشد؛ فرمت پشتیبانی نمی‌شود یا فایل خوانده نشد'),
    ));
  }

  // ───────────────────────── ساخت صفحه ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kSheet,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: _kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          children: [
            _header(),
            const Divider(height: 1, color: _kBorder),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _appearanceCard(),
                    _profileCard(),
                    _mapTextCard(),
                    _mapDisplayCard(),
                    _pathCard(),
                    _backgroundCard(),
                    _foregroundCard(),
                    _motivationCard(),
                    _logoutButton(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── سربرگ و پایین ─────────────────────────

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _kGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.tune_rounded, color: _kGold, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تنظیمات',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _kInk)),
                SizedBox(height: 1),
                Text('ظاهر برنامه، نقشه و پس‌زمینه',
                    style: TextStyle(fontSize: 11.5, color: _kMuted)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'بستن بدون ذخیره',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: _kMuted, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _kMuted,
                side: const BorderSide(color: _kBorder),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف', style: TextStyle(fontSize: 12.5)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _kGold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _save,
              icon: const Icon(Icons.check_rounded, size: 20),
              label: const Text('ذخیره‌ی تنظیمات',
                  style:
                      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── کارت‌ها ─────────────────────────

  /// ظاهر برنامه: تم + اندازه‌ی نوشته‌ی کل برنامه
  Widget _appearanceCard() {
    final cur = context.watch<ThemeStore>().textScale;
    final rel = _uiScale / cur; // پیش‌نمایشِ زنده نسبت به اندازه‌ی فعلیِ برنامه
    return _card(
      icon: Icons.palette_outlined,
      title: 'ظاهر برنامه',
      subtitle: 'تم و اندازه‌ی نوشته‌ی همه‌ی بخش‌ها',
      children: [
        Consumer<ThemeStore>(
          builder: (_, theme, __) => _switchRow(
            title: 'تم تاریک',
            subtitle: theme.isDark
                ? 'پس‌زمینه‌ی تیره با متن روشن'
                : 'پس‌زمینه‌ی روشن',
            value: theme.isDark,
            onChanged: (v) => theme.setDark(v),
          ),
        ),
        const _Hair(),
        _sliderBlock(
          label: 'اندازه‌ی نوشته‌های برنامه',
          hint: 'روی همه‌ی صفحه‌ها، کادرها و دکمه‌ها اعمال می‌شود',
          valueText: '${toFa((_uiScale * 100).round())}٪',
          value: _uiScale,
          min: ThemeStore.kTextScaleMin,
          max: ThemeStore.kTextScaleMax,
          divisions: 16,
          onChanged: (v) => setState(() => _uiScale = v),
          onReset: _uiScale == 1.0 ? null : () => setState(() => _uiScale = 1.0),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _kField,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('نمونه‌ی نوشته',
                  textScaler: TextScaler.linear(rel),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _kInk)),
              const SizedBox(height: 2),
              Text('اینطوری نوشته‌های برنامه دیده می‌شوند.',
                  textScaler: TextScaler.linear(rel),
                  style: const TextStyle(fontSize: 12.5, color: _kMuted)),
            ],
          ),
        ),
      ],
    );
  }

  /// حساب و پروفایل
  Widget _profileCard() {
    return _card(
      icon: Icons.person_outline_rounded,
      title: 'حساب و پروفایل',
      children: [
        _fieldLabel('ایمیل ورود'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: _kField,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: const Text('—',
              style: TextStyle(fontSize: 13, color: _kMuted)),
        ),
        const SizedBox(height: 4),
        const Text('در نسخه‌ی Flutter هنوز ورود پیاده نشده',
            style: TextStyle(fontSize: 10.5, color: _kMuted)),
        const _Hair(),
        _fieldLabel('نام شما'),
        TextField(
          controller: _nameCtrl,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontSize: 13.5, color: _kInk),
          decoration: _inputDeco('مثلاً مریم'),
        ),
        const SizedBox(height: 4),
        const Text('در بخش دوستان با همین نام نمایش داده می‌شود',
            style: TextStyle(fontSize: 10.5, color: _kMuted)),
      ],
    );
  }

  /// نوشته‌های نقشه: رنگ و اندازه
  Widget _mapTextCard() {
    return _card(
      icon: Icons.text_fields_rounded,
      title: 'نوشته‌های نقشه',
      subtitle: 'نام هدف‌ها، اقدام‌ها و نشانه‌ها روی نقشه',
      children: [
        _fieldLabel('رنگ نوشته‌ها'),
        WebColorPicker(
          value: _textColor,
          onChanged: (c) => setState(() => _textColor = c),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _textColor,
                shape: BoxShape.circle,
                border: Border.all(color: _kBorder, width: 1.5),
              ),
            ),
            const SizedBox(width: 8),
            Text('رنگ انتخابی: ${_hexFromColor(_textColor)}',
                style: const TextStyle(fontSize: 11.5, color: _kMuted)),
          ],
        ),
        const _Hair(),
        _sliderBlock(
          label: 'اندازه‌ی فونتِ نقشه',
          hint: 'پیش‌فرض ۱۴',
          valueText: toFa(_fontSize.round()),
          value: _fontSize,
          min: 8,
          max: 40,
          divisions: 32,
          onChanged: (v) => setState(() => _fontSize = v),
          onReset: _fontSize.round() == 14
              ? null
              : () => setState(() => _fontSize = 14),
        ),
        const SizedBox(height: 2),
        // پیش‌نمایش با همان اندازه‌ی واقعیِ نقشه (بدون اثر اندازه‌ی نوشته‌ی برنامه)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF9AA3C0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'نمونه‌ی نوشته‌ی نقشه',
            textAlign: TextAlign.center,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
                fontSize: _fontSize,
                fontWeight: FontWeight.w600,
                color: _textColor),
          ),
        ),
        const SizedBox(height: 6),
        _switchRow(
          title: 'اعمال روی همه‌ی نوشته‌ها',
          subtitle:
              'اندازه و رنگِ اختصاصیِ تک‌تک هدف‌ها و اقدام‌ها پاک می‌شود',
          value: _applyToAll,
          onChanged: (v) => setState(() => _applyToAll = v),
        ),
      ],
    );
  }

  /// نمایش روی نقشه
  Widget _mapDisplayCard() {
    return _card(
      icon: Icons.map_outlined,
      title: 'نمایش روی نقشه',
      children: [
        _switchRow(
          title: 'نمایش تاریخ',
          subtitle: 'تاریخ شمسیِ آخرین فعالیت زیر نام هدف‌ها و اقدام‌ها',
          value: _showDates,
          onChanged: (v) => setState(() => _showDates = v),
        ),
        const _Hair(),
        _switchRow(
          title: 'نمایش ساعت',
          subtitle: 'ساعتِ آخرین فعالیت زیر نام هدف‌ها و اقدام‌ها',
          value: _showTimes,
          onChanged: (v) => setState(() => _showTimes = v),
        ),
        const _Hair(),
        _switchRow(
          title: 'خط‌چینِ اتصال نشانه‌ها',
          subtitle: 'اتصال نشانه‌های نزدیک به هدف',
          value: _showRingLinks,
          onChanged: (v) => setState(() => _showRingLinks = v),
        ),
        const _Hair(),
        _switchRow(
          title: 'ویجت شناورِ «آدم و احساسات»',
          subtitle: 'روی صفحه در تمام تب‌ها دیده می‌شود',
          value: _showEmotionWidget,
          onChanged: (v) => setState(() => _showEmotionWidget = v),
        ),
      ],
    );
  }

  /// مسیر هدف‌ها و انیمیشن
  Widget _pathCard() {
    return _card(
      icon: Icons.route_outlined,
      title: 'مسیر و انیمیشن',
      subtitle: 'برای هر هدف جداگانه هم می‌شود عوضشان کرد',
      children: [
        _fieldLabel('نوع خطِ پیش‌فرضِ مسیر اهداف'),
        _trunkPicker(),
        const _Hair(),
        _sliderBlock(
          label: 'اندازه‌ی انیمیشن 👣',
          valueText: '${toFa((_footScale * 100).round())}٪',
          value: _footScale,
          min: kWalkerSizeMin,
          max: kFootScaleMax,
          divisions: 23,
          onChanged: (v) => setState(() => _footScale = v),
        ),
      ],
    );
  }

  /// پس‌زمینه
  Widget _backgroundCard() {
    return _card(
      icon: Icons.wallpaper_outlined,
      title: 'پس‌زمینه',
      children: [
        Consumer<BackgroundStore>(
          builder: (_, bg, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _bgModeBtn(
                      icon: Icons.crop_square_rounded,
                      label: 'ساده (Calm)',
                      active: !bg.custom,
                      onTap: () => bg.setCustom(false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _bgModeBtn(
                      icon: Icons.image_outlined,
                      label: 'پس‌زمینه‌ی دلخواه',
                      active: bg.custom,
                      onTap: () => bg.setCustom(true),
                    ),
                  ),
                ],
              ),
              if (bg.custom) ...[
                const SizedBox(height: 14),
                const Text(
                    'عکس، GIF، WebP متحرک یا ویدیو (mp4، webm، mov، mkv ...) — ویدیو بی‌صدا پخش می‌شود',
                    style: TextStyle(fontSize: 11.5, color: _kMuted)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (bg.hasBackground)
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _kField,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _kBorder),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: (bg.kind == BgKind.image ||
                                    bg.kind == BgKind.anim) &&
                                bg.imageBytes != null
                            ? Image.memory(bg.imageBytes!,
                                fit: BoxFit.cover, gaplessPlayback: true)
                            : const Center(
                                child: Icon(Icons.play_circle_outline,
                                    color: _kGold, size: 26)),
                      ),
                    _pillButton(
                      icon: Icons.add_photo_alternate_outlined,
                      label: 'انتخاب عکس، GIF یا ویدیو',
                      onTap: () async {
                        final err = await bg.pickAndSet(context);
                        if (err != null && context.mounted) {
                          ScaffoldMessenger.of(context)
                              .quietSnack(SnackBar(content: Text(err)));
                        }
                      },
                    ),
                    if (bg.kind == BgKind.image)
                      _pillButton(
                        icon: Icons.crop_rounded,
                        label: 'برش',
                        onTap: () async {
                          final err = await bg.cropCurrent(context);
                          if (err != null && context.mounted) {
                            ScaffoldMessenger.of(context)
                                .quietSnack(SnackBar(content: Text(err)));
                          }
                        },
                      ),
                    if (bg.hasBackground)
                      _pillButton(
                        icon: Icons.delete_outline_rounded,
                        label: 'حذف',
                        color: _kDanger,
                        onTap: () => bg.clear(),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _sliderBlock(
                  label: 'محو بودن پس‌زمینه (Blur)',
                  valueText: toFa(bg.blur.round()),
                  value: bg.blur,
                  min: 0,
                  max: 20,
                  divisions: 20,
                  onChanged: (v) => bg.setBlur(v),
                ),
                _sliderBlock(
                  label: 'شفافیت پس‌زمینه',
                  valueText: '${toFa((bg.opacity * 100).round())}٪',
                  value: (bg.opacity * 100).clamp(10, 100).toDouble(),
                  min: 10,
                  max: 100,
                  divisions: 90,
                  onChanged: (v) => bg.setOpacity(v / 100),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// پیش‌زمینه (فرشته‌ها)
  Widget _foregroundCard() {
    return _card(
      icon: Icons.auto_awesome_motion_outlined,
      title: 'پیش‌زمینه',
      subtitle: 'افزودن عکس، GIF یا ویدیو که روی صفحه شناور می‌شود',
      children: [
        Consumer<AngelsStore>(
          builder: (_, angels, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (angels.hasAssets) ...[
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final im in angels.images)
                      _angelImageThumb(
                        bytes: im.bytes,
                        onDelete: () => angels.removeImage(im.id),
                      ),
                    for (final v in angels.videos)
                      _angelVideoThumb(
                        name: v.name,
                        onDelete: () => angels.removeVideo(v.id),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kInk,
                  side: const BorderSide(color: _kBorder),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _addAngelFiles(angels),
                icon: const Icon(Icons.add_photo_alternate_outlined,
                    size: 18, color: _kGold),
                label: const Text('افزودن عکس / GIF / ویدیو',
                    style: TextStyle(fontSize: 12.5)),
              ),
              const SizedBox(height: 8),
              _switchRow(
                title: 'نمایش روی همه‌ی تب‌ها',
                value: angels.on,
                onChanged: (v) => angels.setOn(v),
              ),
              const _Hair(),
              _switchRow(
                title: 'نمایش روی عکس‌ها و ویدیوها',
                subtitle: 'در حالت تمام‌صفحه',
                value: angels.fs,
                onChanged: (v) => angels.setFs(v),
              ),
              const _Hair(),
              _switchRow(
                title: 'محو کردن لبه‌ها',
                value: angels.soft,
                onChanged: (v) => angels.setSoft(v),
              ),
              const SizedBox(height: 6),
              _sliderBlock(
                label: 'اندازه',
                valueText: toFa(angels.size.round()),
                value: angels.size,
                min: 60,
                max: 320,
                onChanged: (v) => angels.setSize(v),
              ),
              _sliderBlock(
                label: 'سرعت',
                valueText: toFa(angels.speed.round()),
                value: angels.speed,
                min: 1,
                max: 12,
                onChanged: (v) => angels.setSpeed(v),
              ),
              _sliderBlock(
                label: 'شفافیت',
                valueText: '${toFa((angels.opacity * 100).round())}٪',
                value: angels.opacity * 100,
                min: 20,
                max: 100,
                onChanged: (v) => angels.setOpacity(v / 100),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: _kField,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: angels.blend,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(12),
                    style: const TextStyle(fontSize: 13, color: _kInk),
                    items: const [
                      DropdownMenuItem(
                          value: 'normal', child: Text('حالت: عادی')),
                      DropdownMenuItem(
                          value: 'screen', child: Text('حالت: محو تیره‌ها')),
                      DropdownMenuItem(
                          value: 'multiply', child: Text('حالت: محو سفیدها')),
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
      ],
    );
  }

  Widget _motivationCard() {
    return _card(
      icon: Icons.format_quote_rounded,
      title: 'جمله‌های انگیزه‌بخش',
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _kInk,
            side: const BorderSide(color: _kBorder),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => showMotivationSheet(context),
          icon: const Icon(Icons.auto_awesome, size: 18, color: _kGold),
          label: const Text('مدیریت جمله‌های انگیزه‌بخش',
              style: TextStyle(fontSize: 12.5)),
        ),
      ],
    );
  }

  Widget _logoutButton() {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: _kDanger,
        side: BorderSide(color: _kDanger.withValues(alpha: 0.6)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      onPressed: () {
        ScaffoldMessenger.of(context).quietSnack(
          const SnackBar(
            content: Text('خروج از حساب هنوز فعال نشده (نیاز به Supabase)'),
          ),
        );
      },
      icon: const Icon(Icons.logout_rounded, size: 18),
      label: const Text('خروج از حساب', style: TextStyle(fontSize: 13)),
    );
  }

  // ───────────────────────── ابزارهای ظاهری ─────────────────────────

  Widget _card({
    required IconData icon,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F141832), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _kGold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: _kGold),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _kInk)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(subtitle,
                            style: const TextStyle(
                                fontSize: 11, color: _kMuted)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: _kInk)),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: _kMuted),
        filled: true,
        fillColor: _kField,
        isDense: true,
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
      );

  Widget _valueChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: _kGold.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w800, color: _kGold),
        ),
      );

  /// ردیفِ کلید (Switch) با عنوان و توضیح — به‌جای چک‌باکس
  Widget _switchRow({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kInk)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle,
                          style:
                              const TextStyle(fontSize: 11, color: _kMuted)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: value,
              activeThumbColor: Colors.white,
              activeTrackColor: _kGold,
              inactiveTrackColor: const Color(0xFFE3E5EE),
              inactiveThumbColor: Colors.white,
              trackOutlineColor:
                  const WidgetStatePropertyAll(Colors.transparent),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  /// اسلایدر با عنوان، مقدار و دکمه‌ی بازنشانی
  Widget _sliderBlock({
    required String label,
    String? hint,
    required String valueText,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
    VoidCallback? onReset,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kInk)),
            ),
            if (onReset != null)
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onReset,
                child: const Text('پیش‌فرض',
                    style: TextStyle(fontSize: 11.5, color: _kGold)),
              ),
            _valueChip(valueText),
          ],
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(hint,
                style: const TextStyle(fontSize: 11, color: _kMuted)),
          ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: _kGold,
            thumbColor: _kGold,
            inactiveTrackColor: const Color(0xFFE3E5EE),
            overlayColor: _kGold.withValues(alpha: 0.15),
            activeTickMarkColor: Colors.transparent,
            inactiveTickMarkColor: Colors.transparent,
          ),
          child: Slider(
            min: min,
            max: max,
            divisions: divisions,
            value: value.clamp(min, max).toDouble(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _pillButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = _kInk,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _kField,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color == _kInk ? _kGold : color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
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
            color: _kField,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child:
              Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
        ),
        _thumbClose(onDelete),
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
            color: _kField,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: const Center(
            child: Icon(Icons.play_circle_outline, color: _kGold, size: 28),
          ),
        ),
        _thumbClose(onDelete),
      ],
    );
  }

  Widget _thumbClose(VoidCallback onDelete) => Positioned(
        top: -5,
        right: -5,
        child: GestureDetector(
          onTap: onDelete,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.black87,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: const Icon(Icons.close, size: 12, color: Colors.white),
          ),
        ),
      );

  /// دکمه‌ی حالت پس‌زمینه (مثل `.bgmode-btn` در وب)
  Widget _bgModeBtn({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        decoration: BoxDecoration(
          color: active ? const Color.fromRGBO(244, 197, 66, 0.14) : _kField,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active ? _kGold : _kBorder, width: active ? 1.6 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 21, color: active ? _kGold : _kMuted),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: active ? _kInk : _kMuted,
              ),
            ),
          ],
        ),
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
      childAspectRatio: 0.95,
      children: [
        for (final e in kTrunkStyles.entries)
          GestureDetector(
            onTap: () => setState(() => _trunkStyle = e.key),
            child: Container(
              decoration: BoxDecoration(
                color: _trunkStyle == e.key
                    ? const Color.fromRGBO(244, 197, 66, 0.14)
                    : _kField,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _trunkStyle == e.key ? _kGold : _kBorder,
                  width: _trunkStyle == e.key ? 1.8 : 1,
                ),
              ),
              padding: const EdgeInsets.all(5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 44,
                    height: 24,
                    child: CustomPaint(
                      painter: _TrunkPreviewPainter(
                        style: e.key,
                        color: _trunkStyle == e.key ? _kGold : _kMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    e.value,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: _trunkStyle == e.key
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: _trunkStyle == e.key ? _kInk : _kMuted,
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

/// خطِ نازکِ جداکننده‌ی بین ردیف‌های داخل کارت
class _Hair extends StatelessWidget {
  const _Hair();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
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
