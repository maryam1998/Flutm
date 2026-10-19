// ابزارِ ترجمه‌ی SRT — معادلِ SrtTranslatorTool.jsx در Hope.
// فایلِ .srt را می‌خواند، متنِ هر بلوک را (بدونِ دست‌زدن به شماره/تایم‌کد) ترجمه می‌کند
// و فایلِ SRTِ جدید را ذخیره می‌کند.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/audio/srt_utils.dart';
import '../../core/constants/supported_languages.dart';
import '../../core/providers/ai_settings_provider.dart';
import '../../core/providers/language_selection_provider.dart';
import '../../core/providers/translation_provider.dart';
import '../../core/theme/app_theme_colors.dart';

class SrtTranslatorTool extends ConsumerStatefulWidget {
  const SrtTranslatorTool({super.key});

  @override
  ConsumerState<SrtTranslatorTool> createState() => _SrtTranslatorToolState();
}

class _SrtTranslatorToolState extends ConsumerState<SrtTranslatorTool> {
  bool _open = false;
  String _fileName = '';
  List<SrtEntry> _entries = const [];
  List<SrtEntry>? _translated;
  String _target = '';
  bool _translating = false;
  bool _cancel = false;
  int _done = 0;
  String _error = '';
  String _info = '';

  @override
  void dispose() {
    _cancel = true;
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() {
      _error = '';
      _info = '';
    });
    try {
      final res = await FilePicker.platform
          .pickFiles(type: FileType.any, allowMultiple: false, withData: true);
      final f = res?.files.isNotEmpty == true ? res!.files.first : null;
      if (f == null || f.bytes == null) return;
      if (!f.name.toLowerCase().endsWith('.srt')) {
        setState(() => _error = context.l10n.srt_tool_err_not_srt);
        return;
      }
      final parsed = parseSrt(utf8.decode(f.bytes!, allowMalformed: true));
      if (parsed.isEmpty) {
        setState(() {
          _error = context.l10n.srt_tool_err_empty_file;
          _entries = const [];
        });
        return;
      }
      setState(() {
        _fileName = f.name;
        _entries = parsed;
        _translated = null;
        _done = 0;
      });
    } catch (_) {
      setState(() => _error = context.l10n.srt_tool_err_read);
    }
  }

  Future<void> _translateAll(String target) async {
    if (_entries.isEmpty || _translating) return;
    setState(() {
      _translating = true;
      _cancel = false;
      _error = '';
      _info = '';
      _done = 0;
    });
    final svc = ref.read(translationServiceProvider);
    final ai = ref.read(aiSettingsProvider);
    final out = <SrtEntry>[];
    for (var i = 0; i < _entries.length; i++) {
      if (_cancel || !mounted) break;
      final e = _entries[i];
      final plain = e.text.replaceAll('\n', ' ').trim();
      var tr = plain;
      if (plain.isNotEmpty) {
        try {
          final r = await svc.translate(
              text: plain, targetLang: target, sourceLang: 'auto', aiSettings: ai);
          if (r.trim().isNotEmpty) tr = r.trim();
        } catch (_) {
          // اگه ترجمه‌ی یه خط شکست خورد، متنِ اصلی می‌مونه (بهتر از خالی)
        }
      }
      out.add(e.withText(tr));
      if (mounted) setState(() => _done = i + 1);
    }
    if (!mounted) return;
    setState(() {
      _translated = out.length == _entries.length ? out : null;
      _translating = false;
      if (out.length != _entries.length) _info = context.l10n.srt_tool_stopped;
    });
  }

  Future<void> _save(String target) async {
    final t = _translated;
    if (t == null) return;
    final base = _fileName.replaceAll(RegExp(r'\.srt$', caseSensitive: false), '');
    final name = '${base.isEmpty ? 'subtitles' : base}.$target.srt';
    final bytes = Uint8List.fromList(utf8.encode(serializeSrt(t)));
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: context.l10n.srt_tool_save_dialog,
        fileName: name,
        bytes: bytes,
      );
      if (mounted && path != null) setState(() => _info = context.l10n.srt_tool_saved(name));
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.srt_tool_err_save);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final sel = ref.watch(languageSelectionProvider);
    if (_target.isEmpty) {
      _target = sel.targets.isNotEmpty ? sel.targets.first : 'en';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Row(
              children: [
                Expanded(
                  child: Text('🎬 ${context.l10n.srt_tool_title}',
                      style: TextStyle(
                          color: c.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
                Icon(_open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: c.inkSoft),
              ],
            ),
          ),
          if (_open) ...[
            const SizedBox(height: 8),
            Text(
context.l10n.srt_tool_desc,
              style: TextStyle(color: c.inkSoft, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: _translating ? null : _pick,
                  style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.cardBorder)),
                  child: Text(context.l10n.srt_tool_choose_file,
                      style: TextStyle(color: c.ink, fontSize: 13)),
                ),
                if (_fileName.isNotEmpty)
                  Text('$_fileName (${context.l10n.srt_tool_lines_count('${_entries.length}')})',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(color: c.inkSoft, fontSize: 12)),
              ],
            ),
            if (_entries.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<String>(
                    value: kSupportedLanguages.any((l) => l.code == _target)
                        ? _target
                        : 'en',
                    items: [
                      for (final l in kSupportedLanguages)
                        DropdownMenuItem(
                            value: l.code,
                            child: Text(langDisplayName(context, l.code))),
                    ],
                    onChanged: _translating
                        ? null
                        : (v) => setState(() {
                              _target = v ?? 'en';
                              _translated = null;
                            }),
                  ),
                  if (!_translating)
                    ElevatedButton(
                      onPressed: () => _translateAll(_target),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: c.gold,
                          foregroundColor: c.headerTo,
                          elevation: 0),
                      child: Text(context.l10n.srt_tool_translate),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => setState(() => _cancel = true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: c.rose,
                          foregroundColor: Colors.white,
                          elevation: 0),
                      child: Text(context.l10n.srt_tool_stop('$_done', '${_entries.length}')),
                    ),
                  if (_translated != null && !_translating)
                    OutlinedButton(
                      onPressed: () => _save(_target),
                      style: OutlinedButton.styleFrom(
                          side: BorderSide(color: c.teal)),
                      child: Text(context.l10n.srt_tool_download,
                          style: TextStyle(color: c.teal)),
                    ),
                ],
              ),
            ],
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error, style: TextStyle(color: c.rose, fontSize: 12)),
              ),
            if (_info.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_info, style: TextStyle(color: c.teal, fontSize: 12)),
              ),
          ],
        ],
      ),
    );
  }
}
