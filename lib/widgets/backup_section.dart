import 'package:flutter/material.dart';

import '../services/full_backup.dart';
import '../services/storage.dart';

const _kInk = Color(0xFF2A2218);
const _kMuted = Color(0xFF7A6B57);
const _kBorder = Color(0xFFE0D5C0);
const _kGold = Color(0xFFC9972B);

/// بخش «پشتیبان‌گیری» در تنظیمات: بکاپ کامل همه‌ی تب‌ها + بازیابی.
class BackupSection extends StatefulWidget {
  const BackupSection({super.key});
  @override
  State<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<BackupSection> {
  bool _busy = false;

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    final msg = ScaffoldMessenger.of(context);
    try {
      final json = await FullBackup.build();
      final ok = await StorageService()
          .exportBackup(json, prefix: 'maghz-full-backup');
      if (ok) {
        msg.showSnackBar(const SnackBar(content: Text('بکاپ کامل ذخیره شد')));
      }
    } catch (e) {
      msg.showSnackBar(SnackBar(content: Text('بکاپ ناموفق بود: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    final msg = ScaffoldMessenger.of(context);
    final raw = await StorageService().pickBackup();
    if (raw == null || !mounted) return;
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بازیابی بکاپ'),
        content: const Text(
            'داده‌های داخل بکاپ جایگزین داده‌های فعلی می‌شن. ادامه بدم؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('بازیابی')),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final r = await FullBackup.restore(raw);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('بازیابی انجام شد ✅'),
          content: Text(
              '${r.prefs + r.files} مورد و ${r.videos} ویدیو بازیابی شد.\n'
              'برای دیدن همه‌چیز، برنامه رو کامل ببند و دوباره باز کن.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('باشه')),
          ],
        ),
      );
    } catch (e) {
      msg.showSnackBar(SnackBar(content: Text('بازیابی ناموفق بود: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  ButtonStyle get _style => OutlinedButton.styleFrom(
        foregroundColor: _kInk,
        side: const BorderSide(color: _kBorder),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('پشتیبان‌گیری و بازیابی',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: _kMuted)),
        const SizedBox(height: 6),
        const Text(
          'همه‌ی اطلاعات همه‌ی تب‌ها (اهداف، تمرین‌ها، عکس‌ها، ویدیوها، صداها، '
          'باورها، شناخت و تنظیمات) در یک فایل ذخیره می‌شه. با این فایل می‌تونی '
          'بعد از عوض‌کردن گوشی یا پاک‌کردن برنامه همه‌چیز رو برگردونی.',
          style: TextStyle(fontSize: 11.5, color: _kMuted, height: 1.6),
        ),
        const SizedBox(height: 10),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else ...[
          OutlinedButton.icon(
            style: _style,
            onPressed: _export,
            icon: const Icon(Icons.upload_file, size: 18, color: _kGold),
            label: const Text('گرفتن بکاپ کامل',
                style: TextStyle(fontSize: 12.5)),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: _style,
            onPressed: _import,
            icon: const Icon(Icons.download, size: 18, color: _kGold),
            label: const Text('بازیابی از فایل بکاپ',
                style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ],
    );
  }
}
