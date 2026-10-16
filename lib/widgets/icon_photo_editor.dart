import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/map_models.dart';
import '../services/image_service.dart';

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
    final srcs = await ImageService.pickImagesCropped(context: context);
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

        // ─── افزودن عکس (چندگانه) + بندانگشتی‌ها ───
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PhotoAddButton(label: 'افزودن عکس (چندگانه)', onTap: _pick),
            for (var i = 0; i < _images.length; i++)
              PhotoThumb(
                bytes: _decode(_images[i].src),
                onRemove: () => _remove(i),
              ),
          ],
        ),
      ],
    );
  }

  Widget _emojiPreview() => Text(
        _iconCtl.text.isEmpty ? '🎯' : _iconCtl.text,
        style: const TextStyle(fontSize: 26),
      );
}

/// دکمه‌ی «افزودن عکس» — خط‌چین/کادر خاکستری با آیکون دوربین (مثل مغز)
class PhotoAddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const PhotoAddButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF6EC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_camera_outlined, size: 20, color: _kInk),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 13.5, color: _kInk, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// بندانگشتی گرد با دکمه‌ی ✕ (مثل مغز)
class PhotoThumb extends StatelessWidget {
  final Uint8List? bytes;
  final VoidCallback onRemove;
  final double size;
  const PhotoThumb({
    super.key,
    required this.bytes,
    required this.onRemove,
    this.size = 74,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kCard,
                border: Border.all(color: _kBorder, width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: bytes != null
                  ? Image.memory(bytes!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image, color: _kMuted))
                  : const Icon(Icons.image, color: _kMuted),
            ),
          ),
          Positioned(
            left: -6,
            bottom: -4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 28,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEFEF),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kInk.withValues(alpha: 0.6)),
                ),
                child: const Icon(Icons.close, size: 16, color: _kInk),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// عکس پاهای متحرک (قدم‌زن) — یک عکس، با همون سیستم برش
class WalkerPhotoField extends StatefulWidget {
  final String? initial;
  final void Function(String? src) onChanged;
  const WalkerPhotoField({super.key, this.initial, required this.onChanged});

  @override
  State<WalkerPhotoField> createState() => _WalkerPhotoFieldState();
}

class _WalkerPhotoFieldState extends State<WalkerPhotoField> {
  String? _src;

  @override
  void initState() {
    super.initState();
    _src = (widget.initial != null && widget.initial!.isNotEmpty)
        ? widget.initial
        : null;
  }

  Uint8List? _bytes() {
    final s = _src;
    if (s == null || !s.startsWith('data:')) return null;
    try {
      return base64Decode(s.substring(s.indexOf(',') + 1));
    } catch (_) {
      return null;
    }
  }

  Future<void> _pick() async {
    final src = await ImageService.pickSingleCropped(context: context, ratio: 1);
    if (!mounted || src == null || src.isEmpty) return;
    setState(() => _src = src);
    widget.onChanged(src);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        PhotoAddButton(
          label: _src == null ? 'افزودن عکس' : 'تغییر عکس',
          onTap: _pick,
        ),
        if (_src != null)
          PhotoThumb(
            bytes: _bytes(),
            onRemove: () {
              setState(() => _src = null);
              widget.onChanged(null);
            },
          ),
      ],
    );
  }
}
