import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../map/world_painter.dart' show WorldLayer;
import '../services/ambient_sound.dart';
import '../services/map_voice_player.dart';
import '../state/main_tab.dart';
import '../state/map_store.dart';

/// آیکونِ کوچک و کم‌رنگِ قطع/وصلِ «صدای طبیعت» بالای تب هدف‌گذاری (به‌جای لوگو).
/// همین ویجت صدا را هم راه می‌اندازد: فقط وقتی تب هدف‌گذاری دیده می‌شود و برنامه
/// جلوی صفحه است صدا پخش می‌شود.
class AmbientSoundButton extends StatefulWidget {
  const AmbientSoundButton({
    super.key,
    required this.night,
    required this.color,
    this.dawn = false,
  });

  /// آسمانِ نقشه شب است؟ (جیرجیرک)
  final bool night;

  /// دم‌دمای صبح است؟ (کلاغ)
  final bool dawn;

  /// رنگِ آیکون (کم‌رنگ، هماهنگ با پالتِ نقشه)
  final Color color;

  @override
  State<AmbientSoundButton> createState() => _AmbientSoundButtonState();
}

class _AmbientSoundButtonState extends State<AmbientSoundButton>
    with WidgetsBindingObserver {
  Timer? _t;
  bool _fg = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    kMainTabIndex.addListener(_sync);
    AmbientSound.instance.keepPlaying.addListener(_sync);
    MapVoicePlayer.instance.playing.addListener(_sync);
    AmbientSound.instance.init().then((_) => _sync());
    _t = Timer.periodic(const Duration(seconds: 3), (_) => _sync());
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(covariant AmbientSoundButton old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _fg = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    _t?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    kMainTabIndex.removeListener(_sync);
    AmbientSound.instance.keepPlaying.removeListener(_sync);
    MapVoicePlayer.instance.playing.removeListener(_sync);
    AmbientSound.instance.setActive(false);
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    var green = 0.0;
    try {
      final st = context.read<MapStore>().state;
      if (st.extra['worldOff'] != true) {
        // سبزیِ دنیا: از ~۵ ساعت کار شروع می‌شود و تا ~۱۰۵ ساعت کامل می‌شود
        final k = ((WorldLayer.totalMinutes(st) - 300.0) / 6000.0)
            .clamp(0.0, 1.0)
            .toDouble();
        green = k * k * (3 - 2 * k);
      }
    } catch (_) {}
    final s = AmbientSound.instance;
    s.update(night: widget.night, green: green, dawn: widget.dawn);
    s.setDucked(MapVoicePlayer.instance.playing.value.isNotEmpty);
    // اگر «ادامه در بقیه‌ی تب‌ها و پس‌زمینه» روشن باشد، تب و حالتِ برنامه مهم نیست
    s.setActive(s.keepPlaying.value || (kMainTabIndex.value == 1 && _fg));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AmbientSound.instance.muted,
      builder: (_, muted, __) => Tooltip(
        message: muted ? 'روشن کردن صدای طبیعت' : 'قطع صدای طبیعت',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => AmbientSound.instance.toggleMute(),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Center(
              child: Icon(
                muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                size: 17,
                color: widget.color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
