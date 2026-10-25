import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../map/draw_utils.dart' show toFa;
import '../services/data_url_cache.dart';
import '../models/map_models.dart';
import '../services/image_service.dart';
import 'emoji_stack.dart';

const _kCard = Colors.white;
const _kGold = Color(0xFF178A7C); // سبز هماهنگ با بقیه‌ی تب‌ها
const _kInk = Color(0xFF000000);
const _kMuted = Color(0xFF5B5F77);
const _kBorder = Color(0xFFE4E6EE);
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

  Future<void> _cropAt(int idx) async {
    final n = await ImageService.cropDataUrl(context, _images[idx].src);
    if (!mounted || n == null) return;
    setState(() => _images[idx].src = n);
    _emit();
  }

  void _resetScale() {
    setState(() => _scale = 1.0);
    _emit();
  }

  Uint8List? _decode(String src) {
    return DataUrlCache.bytes(src);
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
                          cacheWidth: 240,
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
                    hintText: 'ایموجی یا نوشته',
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
                child: Text('',
                    style: TextStyle(fontSize: 12, color: _kMuted)),
              ),

          ],
        ),

        // ─── نوار اندازه ───
        if (widget.supportsScale && (widget.supportsIcon || _images.isNotEmpty)) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('اندازه',
                  style: TextStyle(fontSize: 12.5, color: _kMuted)),
              const SizedBox(width: 6),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: _kGold,
                    thumbColor: _kGold,
                    inactiveTrackColor: const Color(0xFFD3D7E6),
                    overlayColor: _kGold.withAlpha(40),
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
                onCrop: () => _cropAt(i),
              ),
          ],
        ),
        // فاصله از چیزی که زیرِ این بخش می‌آید (مثلاً پالت رنگ)
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _emojiPreview() => _iconCtl.text.trim().isEmpty
      ? const SizedBox(width: 58, height: 58)
      : EmojiStack(icon: _iconCtl.text, size: 58);
}

/// دکمه‌ی «افزودن عکس» — دقیقاً مثل مغز: کادر کوچک خاکستری، متن + آیکون دوربین
class PhotoAddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const PhotoAddButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF1F2F6),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFFD5D8E2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.photo_camera_outlined, size: 18, color: _kInk),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: _kInk,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

/// اندازه‌ی استاندارد بندانگشتی (دقیقاً مثل اسکرین‌شات مغز) — «من»، «پاها» و بقیه‌ی جاها
const double kPhotoThumbSize = 56;

/// بندانگشتی گرد + دکمه‌ی ✕ که **کنار پایین-چپِ** دایره می‌شینه (مثل مغز).
/// [selected] = عکسی که روی نقشه نمایش داده می‌شه (حلقه‌ی طلایی + ✓).
class PhotoThumb extends StatelessWidget {
  final Uint8List? bytes;
  final VoidCallback onRemove;
  final VoidCallback? onCrop;
  final double size;
  final bool selected;
  final bool showOrder;
  final int order;
  const PhotoThumb({
    super.key,
    required this.bytes,
    required this.onRemove,
    this.onCrop,
    this.size = kPhotoThumbSize,
    this.selected = false,
    this.showOrder = false,
    this.order = 0,
  });

  @override
  Widget build(BuildContext context) {
    final ring = selected ? 3.0 : 0.0;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ✕ کنار دایره، پایین-چپ
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 0, 6),
              child: Container(
                width: 32,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEFEF),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: _kInk.withValues(alpha: 0.7)),
                ),
                child: const Icon(Icons.close, size: 14, color: _kInk),
              ),
            ),
          ),
          SizedBox(
            width: size + ring * 2,
            height: size + ring * 2,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Container(
                    padding: EdgeInsets.all(ring),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: _kGold, width: ring)
                          : null,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _kCard,
                        border: selected
                            ? null
                            : Border.all(color: _kBorder, width: 1),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: bytes != null
                          ? Image.memory(bytes!,
                              fit: BoxFit.cover,
                              cacheWidth: 200,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image, color: _kMuted))
                          : const Icon(Icons.image, color: _kMuted),
                    ),
                  ),
                ),
                if (showOrder)
                  Positioned(
                    right: -2,
                    top: -4,
                    child: Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? _kGold : _kInk.withValues(alpha: 0.75),
                        shape: BoxShape.circle,
                      ),
                      child: selected
                          ? const Icon(Icons.check, size: 12, color: Colors.white)
                          : Text(toFa(order),
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                if (onCrop != null)
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: GestureDetector(
                      onTap: onCrop,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _kGold,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                        child:
                            const Icon(Icons.crop, size: 13, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ردیف بندانگشتی‌های **قابل جابه‌جایی با انگشت** (مشترک بین «من» و «پاها»).
/// عکسِ اول (✓) همونیه که نمایش داده می‌شه؛ با لمس هر عکس همون انتخاب (می‌ره اول)،
/// یا بکش و جابه‌جاش کن.
class ReorderablePhotoStrip extends StatelessWidget {
  final List<int> ids;
  final List<Uint8List?> bytes;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int index) onSelect;
  final void Function(int index) onRemove;
  final void Function(int index) onCrop;
  const ReorderablePhotoStrip({
    super.key,
    required this.ids,
    required this.bytes,
    required this.onReorder,
    required this.onSelect,
    required this.onRemove,
    required this.onCrop,
  });

  @override
  Widget build(BuildContext context) {
    if (ids.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: kPhotoThumbSize + 24,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(top: 8),
            itemCount: ids.length,
            proxyDecorator: (child, index, animation) =>
                Material(color: Colors.transparent, child: child),
            onReorder: (o, n) {
              if (n > o) n -= 1;
              if (o == n) return;
              onReorder(o, n);
            },
            itemBuilder: (ctx, i) {
              return ReorderableDragStartListener(
                key: ValueKey(ids[i]),
                index: i,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(i),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: PhotoThumb(
                      bytes: bytes[i],
                      selected: i == 0,
                      showOrder: ids.length > 1,
                      order: i + 1,
                      onRemove: () => onRemove(i),
                      onCrop: () => onCrop(i),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (ids.length > 1)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'همه‌ی عکس‌ها ثبت می‌شن ولی فقط عکسِ ✓ نمایش داده می‌شه. روی هر عکس بزن تا انتخاب بشه، یا با انگشت بکش و جابه‌جا کن.',
              style: TextStyle(fontSize: 11, color: _kMuted, height: 1.6),
            ),
          ),
      ],
    );
  }
}

/// عکس پاهای متحرک (قدم‌زن) — چند عکس، قابل جابه‌جایی با انگشت؛ فقط عکس اول نمایش داده می‌شه.
class _WItem {
  _WItem(this.id, this.src);
  final int id;
  final String src;
}

class WalkerPhotoField extends StatefulWidget {
  final List<String> initial;
  final void Function(List<String> photos) onChanged;
  final String initialEmoji;
  final void Function(String emoji)? onEmojiChanged;
  const WalkerPhotoField({
    super.key,
    this.initial = const [],
    required this.onChanged,
    this.initialEmoji = '',
    this.onEmojiChanged,
  });

  @override
  State<WalkerPhotoField> createState() => _WalkerPhotoFieldState();
}

class _WalkerPhotoFieldState extends State<WalkerPhotoField> {
  final List<_WItem> _items = [];
  int _seq = 0;
  late final TextEditingController _emojiCtl;

  @override
  void initState() {
    super.initState();
    _emojiCtl = TextEditingController(text: widget.initialEmoji);
    for (final s in widget.initial) {
      if (s.isNotEmpty) _items.add(_WItem(_seq++, s));
    }
  }

  @override
  void dispose() {
    _emojiCtl.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged(_items.map((e) => e.src).toList());

  Future<void> _pick() async {
    final srcs = await ImageService.pickImagesCropped(context: context);
    if (!mounted || srcs.isEmpty) return;
    setState(() {
      for (final s in srcs) {
        _items.add(_WItem(_seq++, s));
      }
    });
    _emit();
  }

  void _select(int i) {
    if (i <= 0 || i >= _items.length) return;
    setState(() {
      final it = _items.removeAt(i);
      _items.insert(0, it);
    });
    _emit();
  }

  Future<void> _cropAt(int i) async {
    if (i < 0 || i >= _items.length) return;
    final it = _items[i];
    final n = await ImageService.cropDataUrl(context, it.src);
    if (!mounted || n == null) return;
    final at = _items.indexWhere((e) => e.id == it.id);
    if (at < 0) return;
    setState(() => _items[at] = _WItem(it.id, n));
    _emit();
  }

  Widget _defaultDot() => Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _kGold, width: 2),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: _kGold),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.onEmojiChanged != null) ...[
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kCard,
                  border: Border.all(color: _kBorder, width: 1.5),
                ),
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                child: _emojiCtl.text.trim().isNotEmpty
                    ? EmojiStack(icon: _emojiCtl.text, size: 44)
                    : (_items.isNotEmpty &&
                            DataUrlCache.bytes(_items.first.src) != null
                        ? Image.memory(
                            DataUrlCache.bytes(_items.first.src)!,
                            width: 44,
                            height: 44,
                            cacheWidth: 180,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _defaultDot(),
                          )
                        : _defaultDot()),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _emojiCtl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: _kInk),
                  decoration: InputDecoration(
                    hintText: 'ایموجی یا نوشته',
                    hintStyle: const TextStyle(color: _kMuted),
                    filled: true,
                    fillColor: _kCard,
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
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
                  onChanged: (v) {
                    // ایموجی یا نوشته‌ی آزاد (بدون محدودیت تعداد کلمه)
                    setState(() {});
                    widget.onEmojiChanged!(v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: PhotoAddButton(label: 'افزودن عکس (چندگانه)', onTap: _pick),
        ),
        if (_items.isNotEmpty) ...[
          const SizedBox(height: 12),
          ReorderablePhotoStrip(
            ids: [for (final e in _items) e.id],
            bytes: [for (final e in _items) DataUrlCache.bytes(e.src)],
            onReorder: (o, n) {
              setState(() {
                final it = _items.removeAt(o);
                _items.insert(n, it);
              });
              _emit();
            },
            onSelect: _select,
            onRemove: (i) {
              setState(() => _items.removeAt(i));
              _emit();
            },
            onCrop: _cropAt,
          ),
        ],
      ],
    );
  }
}

/// «افزودن عکس (چندگانه)» برای «من» — مثل پاها: با انگشت جابه‌جا کن؛ عکسِ اول (✓) نمایش داده می‌شه.
class MultiPhotoField extends StatefulWidget {
  final List<ImageItem> initial;
  final void Function(List<ImageItem> images) onChange;
  final String initialEmoji;
  final void Function(String emoji)? onEmojiChanged;
  const MultiPhotoField({
    super.key,
    required this.initial,
    required this.onChange,
    this.initialEmoji = '',
    this.onEmojiChanged,
  });

  @override
  State<MultiPhotoField> createState() => _MultiPhotoFieldState();
}

class _MItem {
  _MItem(this.id, this.item);
  final int id;
  final ImageItem item;
}

class _MultiPhotoFieldState extends State<MultiPhotoField> {
  final List<_MItem> _items = [];
  int _seq = 0;
  late final TextEditingController _emojiCtl;

  @override
  void dispose() {
    _emojiCtl.dispose();
    super.dispose();
  }

  Widget _defaultDot() => Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _kGold, width: 2),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: _kGold),
        ),
      );

  Widget _emojiRow() {
    final bytes = _items.isNotEmpty ? DataUrlCache.bytes(_items.first.item.src) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kCard,
                border: Border.all(color: _kBorder, width: 1.5),
              ),
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              child: _emojiCtl.text.trim().isNotEmpty
                  ? EmojiStack(icon: _emojiCtl.text, size: 44)
                  : (bytes != null
                      ? Image.memory(bytes,
                          width: 44,
                          height: 44,
                          cacheWidth: 240,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _defaultDot())
                      : _defaultDot()),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _emojiCtl,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: _kInk),
                decoration: InputDecoration(
                  hintText: 'ایموجی یا نوشته',
                  hintStyle: const TextStyle(color: _kMuted),
                  filled: true,
                  fillColor: _kCard,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
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
                onChanged: (v) {
                  // ایموجی یا نوشته‌ی آزاد (بدون محدودیت تعداد کلمه)
                  setState(() {});
                  widget.onEmojiChanged!(v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _emojiCtl = TextEditingController(text: widget.initialEmoji);
    for (final im in widget.initial) {
      if (im.src.isNotEmpty) _items.add(_MItem(_seq++, im));
    }
  }

  void _emit() => widget.onChange([for (final e in _items) e.item]);

  Future<void> _pick() async {
    final srcs = await ImageService.pickImagesCropped(context: context);
    if (!mounted || srcs.isEmpty) return;
    setState(() {
      for (final s in srcs) {
        _items.add(_MItem(_seq++, ImageItem(src: s, size: 50, dx: 0, dy: 0)));
      }
    });
    _emit();
  }

  void _select(int i) {
    if (i <= 0 || i >= _items.length) return;
    setState(() {
      final it = _items.removeAt(i);
      _items.insert(0, it);
    });
    _emit();
  }

  Future<void> _cropAt(int i) async {
    if (i < 0 || i >= _items.length) return;
    final it = _items[i];
    final n = await ImageService.cropDataUrl(context, it.item.src);
    if (!mounted || n == null) return;
    setState(() => it.item.src = n);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.onEmojiChanged != null) _emojiRow(),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: PhotoAddButton(label: 'افزودن عکس (چندگانه)', onTap: _pick),
        ),
        if (_items.isNotEmpty) ...[
          const SizedBox(height: 12),
          ReorderablePhotoStrip(
            ids: [for (final e in _items) e.id],
            bytes: [for (final e in _items) DataUrlCache.bytes(e.item.src)],
            onReorder: (o, n) {
              setState(() {
                final it = _items.removeAt(o);
                _items.insert(n, it);
              });
              _emit();
            },
            onSelect: _select,
            onRemove: (i) {
              setState(() => _items.removeAt(i));
              _emit();
            },
            onCrop: _cropAt,
          ),
        ],
      ],
    );
  }
}
