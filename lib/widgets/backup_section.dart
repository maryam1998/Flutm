import 'package:flutter/material.dart';

import '../map/draw_utils.dart' show toFa;
import '../services/full_backup.dart';
import '../services/storage.dart';

const _kInk = Color(0xFF000000);
const _kMuted = Color(0xFF5B5F77);
const _kBorder = Color.fromRGBO(23, 138, 124, 0.28);
const _kField = Color(0xFFF4F5FA);
const _kGreen = Color(0xFF178A7C);
const _kAmber = Color(0xFFC9962B);
const _kDanger = Color(0xFFE5484D);

/// بعد از این‌همه روز بدون بکاپ، وضعیت «هشدار» می‌شود
const int _kStaleDays = 7;

/// کارت جمع‌شونده‌ی «پشتیبان‌گیری و بازیابی روی گوشی» در تنظیمات: بکاپ و بازیابی کاملاً روی خود گوشی
/// (هیچ داده‌ای به سرور نمی‌رود).
class AdvancedBackupCard extends StatefulWidget {
  const AdvancedBackupCard({super.key});
  @override
  State<AdvancedBackupCard> createState() => _AdvancedBackupCardState();
}

class _AdvancedBackupCardState extends State<AdvancedBackupCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F141832), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _kGreen.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.tune_rounded,
                        size: 18, color: _kGreen),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('پشتیبان‌گیری و بازیابی روی گوشی',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _kInk)),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: _kMuted, size: 26),
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: BackupSection(),
            ),
        ],
      ),
    );
  }
}

/// بخش «پشتیبان‌گیری» — بکاپ کامل/سبک، بازیابی با پیش‌نمایش، وضعیت آخرین بکاپ.
class BackupSection extends StatefulWidget {
  const BackupSection({super.key});
  @override
  State<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<BackupSection> {
  bool _busy = false;
  bool _withMedia = true;
  DateTime? _last;
  bool _lastLoaded = false;
  String? _result;
  bool _resultOk = true;

  @override
  void initState() {
    super.initState();
    _loadLast();
  }

  Future<void> _loadLast() async {
    DateTime? d;
    try {
      d = await FullBackup.lastBackupAt();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _last = d;
      _lastLoaded = true;
    });
  }

  void _say(String msg, {bool ok = true}) {
    if (!mounted) return;
    setState(() {
      _result = msg;
      _resultOk = ok;
    });
  }

  /// ساخت و ذخیره‌ی فایل بکاپ؛ true = کاربر فایل را ذخیره کرد
  Future<bool> _doExport({required bool media, String? prefix}) async {
    final json = await FullBackup.build(includeMedia: media);
    final ok = await StorageService().exportBackup(json,
        prefix: prefix ?? (media ? 'maghz-full-backup' : 'maghz-lite-backup'));
    if (ok) {
      await FullBackup.markBackedUp();
      await _loadLast();
    }
    return ok;
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final ok = await _doExport(media: _withMedia);
      _say(
          ok
              ? 'بکاپ ذخیره شد ✅\n${StorageService.describeExportLocation()}'
              : 'ذخیره‌ی بکاپ لغو شد',
          ok: ok);
    } catch (e) {
      _say('بکاپ ناموفق بود: $e', ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _result = null);
    String? raw;
    try {
      raw = await StorageService().pickBackup();
    } catch (e) {
      _say('خواندن فایل ناموفق بود: $e', ok: false);
      return;
    }
    if (raw == null || !mounted) return;

    BackupInfo info;
    try {
      info = FullBackup.describe(raw);
    } catch (e) {
      _say('این فایل بکاپ معتبر نیست', ok: false);
      return;
    }

    final safety = await _confirmRestore(info);
    if (safety == null || !mounted) return;

    setState(() => _busy = true);
    try {
      if (safety) {
        final saved =
            await _doExport(media: true, prefix: 'maghz-before-restore');
        if (!saved) {
          _say('بازیابی لغو شد (بکاپ ایمنی ذخیره نشد)', ok: false);
          return;
        }
      }
      final r = await FullBackup.restore(raw);
      _say('${toFa(r.prefs + r.files)} مورد و ${toFa(r.videos)} رسانه بازیابی شد ✅\n'
          'برنامه را کامل ببند و دوباره باز کن.');
    } catch (e) {
      _say('بازیابی ناموفق بود: $e', ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// null = انصراف؛ true/false = ادامه (با/بدون بکاپ ایمنی از داده‌ی فعلی)
  Future<bool?> _confirmRestore(BackupInfo info) {
    var safety = true;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('بازیابی از بکاپ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _infoRow('تاریخ بکاپ', _fmt(info.createdAt)),
              _infoRow('تعداد داده‌ها', toFa(info.items)),
              _infoRow(
                  'رسانه‌ها',
                  info.includesMedia
                      ? '${toFa(info.mediaFiles)} فایل'
                      : 'بدون رسانه (سبک)'),
              _infoRow('حجم', _fmtSize(info.bytes)),
              const SizedBox(height: 10),
              const Text('داده‌های فعلی با این بکاپ جایگزین می‌شن.',
                  style: TextStyle(fontSize: 12, color: _kMuted)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => setD(() => safety = !safety),
                child: Row(
                  children: [
                    Checkbox(
                      value: safety,
                      activeColor: _kGreen,
                      onChanged: (v) => setD(() => safety = v ?? true),
                    ),
                    const Expanded(
                      child: Text('اول از داده‌های فعلی بکاپ بگیر',
                          style: TextStyle(fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('انصراف')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kGreen),
              onPressed: () => Navigator.pop(ctx, safety),
              child: const Text('بازیابی'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(k, style: const TextStyle(fontSize: 12.5, color: _kMuted)),
            const Spacer(),
            Text(v,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  static String _fmt(DateTime? d) {
    if (d == null) return 'نامشخص';
    final l = d.toLocal();
    String p(int n) => n.toString().padLeft(2, '0');
    return toFa(
        '${l.year}/${p(l.month)}/${p(l.day)}  ${p(l.hour)}:${p(l.minute)}');
  }

  static String _fmtSize(int b) {
    if (b < 1024 * 1024) return '${toFa((b / 1024).round())} کیلوبایت';
    return '${toFa((b / (1024 * 1024)).toStringAsFixed(1))} مگابایت';
  }

  // ───────── وضعیت آخرین بکاپ ─────────
  Widget _status() {
    if (!_lastLoaded) return const SizedBox(height: 44);
    final d = _last;
    Color c;
    IconData ic;
    String t;
    if (d == null) {
      c = _kDanger;
      ic = Icons.shield_outlined;
      t = 'هنوز بکاپ نگرفته‌ای';
    } else {
      final days = DateTime.now().difference(d).inDays;
      if (days <= _kStaleDays) {
        c = _kGreen;
        ic = Icons.verified_user_outlined;
        t = days == 0
            ? 'آخرین بکاپ: امروز'
            : 'آخرین بکاپ: ${toFa(days)} روز پیش';
      } else {
        c = _kAmber;
        ic = Icons.warning_amber_rounded;
        t = 'آخرین بکاپ: ${toFa(days)} روز پیش — وقتشه دوباره بگیری';
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(ic, size: 20, color: c),
          const SizedBox(width: 8),
          Expanded(
            child: Text(t,
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: c)),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(String label, IconData icon, bool value) {
    final on = _withMedia == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _busy ? null : () => setState(() => _withMedia = value),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: on ? _kGreen.withValues(alpha: 0.12) : _kField,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: on ? _kGreen : _kBorder, width: on ? 1.5 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: on ? _kGreen : _kMuted),
              const SizedBox(width: 5),
              Flexible(
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: on ? _kGreen : _kMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, color: _kBorder),
        const SizedBox(height: 12),
        _status(),
        const SizedBox(height: 12),
        Row(
          children: [
            _modeChip('کامل (با رسانه)', Icons.perm_media_outlined, true),
            const SizedBox(width: 8),
            _modeChip('سبک (بدون رسانه)', Icons.bolt_outlined, false),
          ],
        ),
        const SizedBox(height: 10),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else ...[
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _export,
              icon: const Icon(Icons.save_alt_rounded, size: 20),
              label: const Text('گرفتن بکاپ',
                  style:
                      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _kInk,
                side: const BorderSide(color: _kBorder),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _import,
              icon:
                  const Icon(Icons.restore_rounded, size: 20, color: _kGreen),
              label: const Text('بازیابی از فایل بکاپ',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
        if (_result != null) ...[
          const SizedBox(height: 10),
          SelectableText(_result!,
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.6,
                  fontWeight: FontWeight.w700,
                  color: _resultOk ? _kGreen : _kDanger)),
        ],
      ],
    );
  }
}
