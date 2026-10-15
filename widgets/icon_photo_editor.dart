import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/map_models.dart';
import '../services/image_service.dart';
import '../services/media_db.dart';

const _kCard = Colors.white;
const _kGold = Color(0xFFC9972B);
const _kInk = Color(0xFF2A2218);
const _kMuted = Color(0xFF7A6B57);
const _kBorder = Color(0xFFE0D5C0);
const _kDanger = Color(0xFFE5484D);

class IconPhotoEditor extends StatefulWidget {
  const IconPhotoEditor({
    super.key,
    required this.initialIcon,
    required this.initialImages,
    required this.initialScale,
    this.supportsIcon = true,
    this.supportsScale = true,
    required this.onChange,
  });

  final String initialIcon;
  final List<ImageItem> initialImages;
  final double initialScale;
  final bool supportsIcon;
  final bool supportsScale;
  final void Function(String icon, List<ImageItem> images, double scale) onChange;

  @override
  State<IconPhotoEditor> createState() => _IconPhotoEditorState();
}

class _IconPhotoEditorState extends State<IconPhotoEditor> {
  late final TextEditingController _iconCtl;
  late List<ImageItem> _images;
  late double _scale;

  @override
  void initState() {
    super.initState();
    _iconCtl = TextEditingController(text: widget.initialIcon);
    _images = List.of(widget.initialImages);
    _scale = widget.initialScale;
  }

  @override
  void dispose() {
    _iconCtl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChange(_iconCtl.text.trim(), List.of(_images), _scale);
  }

  Future<void> _pick() async {
    final srcs = await ImageService.pickImages();
    if (!mounted || srcs.isEmpty) return;
    setState(() {
      for (final s in srcs) {
        _images.add(ImageItem(src: s, size: 50, dx: 0, dy: 0));
      }
    });
    _emit();
  }

  void _remove(int idx) {
    setState(() => _images.removeAt(idx));
    _emit();
  }

  void _resetScale() {
    setState(() => _scale = 1.0);
    _emit();
  }

  Uint8List? _decode(String src) {
    try {
      if (MediaDb.isRef(src)) return MediaDb.bytes(src);
      if (!src.startsWith('data:')) return null;
      return base64Decode(src.substring(src.indexOf(',') + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── ردیف بالایی: پیش‌نمایش + ایموجی + دکمه عکس ───
        Row(
          children: [
            // پیش‌نمایش
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kCard,
                border: Border.all(color: _kBorder, width: 1.5),
              ),
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              child: _images.isNotEmpty
                  ? (_decode(_images.first.src) != null
                      ? Image.memory(
                          _decode(_images.first.src)!,
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _emojiPreview(),
                        )
                      : _emojiPreview())
                  : _emojiPreview(),
            ),
            const SizedBox(width: 10),

            // ایموجی
            if (widget.supportsIcon)
              Expanded(
                child: TextField(
                  controller: _iconCtl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, color: _kInk),
                  decoration: InputDecoration(
                    hintText: 'ایموجی',
                    hintStyle: const TextStyle(color: _kMuted),
                    filled: true,
                    fillColor: _kCard,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
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
                  ),
                  onChanged: (_) => _emit(),
                ),
              )
            else
              const Expanded(
                child: Text('عکس روی نوک شاخه نمایش داده می‌شود',
                    style: TextStyle(fontSize: 12, color: _kMuted)),
              ),

            const SizedBox(width: 10),

            // دکمه عکس
            OutlinedButton(
              onPressed: _pick,
              style: OutlinedButton.styleFrom(
                backgroundColor: _kGold,
                foregroundColor: Colors.white,
                side: BorderSide.none,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('عکس',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            ),
          ],
        ),

        // ─── نوار اندازه ───
        if (widget.supportsScale && (widget.supportsIcon || _images.isNotEmpty)) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('اندازه‌ی ایکون و عکس',
                  style: TextStyle(fontSize: 12.5, color: _kMuted)),
              const SizedBox(width: 6),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF2DD4BF),
                    thumbColor: const Color(0xFF2DD4BF),
                    inactiveTrackColor: _kBorder,
                    trackHeight: 4,
                  ),
                  child: Slider(
                    min: 0.5,
                    max: 3.0,
                    divisions: 25,
                    value: _scale.clamp(0.5, 3.0).toDouble(),
                    onChanged: (v) {
                      setState(() => _scale = v);
                      _emit();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 46,
                child: Text(
                  '${(_scale * 100).round()}٪',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
              ),
              TextButton(
                onPressed: _resetScale,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('اولیه',
                    style: TextStyle(fontSize: 12, color: _kMuted)),
              ),
            ],
          ),
        ],

        // ─── گالری ───
        if (_images.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _images.length; i++)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBorder),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _decode(_images[i].src) != null
                          ? Image.memory(
                              _decode(_images[i].src)!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.broken_image,
                                  color: _kMuted),
                            )
                          : const Icon(Icons.image, color: _kMuted),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () => _remove(i),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: _kDanger,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _emojiPreview() => Text(
        _iconCtl.text.isEmpty ? '🎯' : _iconCtl.text,
        style: const TextStyle(fontSize: 26),
      );
}
