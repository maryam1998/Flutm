// lib/screens/shenakht/shenakht_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/background_store.dart';
import '../../state/shenakht_store.dart';
import 'ysq_screen.dart';

// ═══════════════════════════════════════════════════════════
// رنگ‌های تب شناخت
// ═══════════════════════════════════════════════════════════
class SK {
  static const primary = Color(0xFF1A3D2C);
  static const grad1 = Color(0xFF0A3D38);
  static const grad2 = Color(0xFF0F5B53);
  static const grad3 = Color(0xFF178A7C);
  static const bg = Color(0xFFFAFAFA);
  static const border = Color(0xFFF0F0F0);
  static const yellow = Color(0xFFFFF8E1);
  static const yellowBorder = Color(0xFFFDE68A);

  static const grad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [grad1, grad2, grad3],
    stops: [0.0, 0.52, 1.0],
  );
}

// ═══════════════════════════════════════════════════════════
// Shell — هدر مشترک همه صفحه‌ها
// ═══════════════════════════════════════════════════════════
class ShenakhtShell extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onSOS;
  final Widget child;

  const ShenakhtShell({
    super.key,
    required this.title,
    this.onBack,
    this.onSOS,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
          ),
          child: Row(
            children: [
              if (onBack != null)
                _circleBtn(icon: Icons.arrow_back, onTap: onBack!)
              else
                const SizedBox(width: 32),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              if (onSOS != null)
                _sosBtn(onSOS!)
              else
                const SizedBox(width: 40),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget _circleBtn({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFEEEEEE)),
          color: Colors.white,
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }

  Widget _sosBtn(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE74C3C)),
          color: Colors.white,
        ),
        child: const Text('SOS',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Welcome Screen
// ═══════════════════════════════════════════════════════════
class WelcomeScreen extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onProfile;
  final VoidCallback onLifeCycles;
  final VoidCallback onSituations;
  final VoidCallback onRelationships;
  final VoidCallback onAcceptance;
  final VoidCallback onSOS;

  const WelcomeScreen({
    super.key,
    required this.onStart,
    required this.onProfile,
    required this.onLifeCycles,
    required this.onSituations,
    required this.onRelationships,
    required this.onAcceptance,
    required this.onSOS,
  });

  @override
  Widget build(BuildContext context) {
    final hasProfile =
        context.select<ShenakhtStore, bool>((s) => s.hasProfile);
    return ShenakhtShell(
      title: 'الگوهای من',
      onSOS: onSOS,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _hero(),
          const SizedBox(height: 12),
          _reminders(),
          const SizedBox(height: 16),
          _startBtn(hasProfile ? onProfile : onStart, hasProfile),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.only(right: 4, bottom: 8),
            child: Text('کاوش کن',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          _grid(),
          const SizedBox(height: 20),
          _disclaimer(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: SK.grad,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('شناخت الگوهای تکرارشونده',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w500)),
          SizedBox(height: 8),
          Text('چه چیزی در من\nتکرار می‌شود؟',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  height: 1.5,
                  fontWeight: FontWeight.w700)),
          SizedBox(height: 12),
          Text(
            'اینجا قرار نیست برچسبی به تو بزنیم. با هم می‌بینیم کجا فعال می‌شوی و چطور می‌توانی این بار جور دیگری پاسخ بدهی.',
            style: TextStyle(
                color: Colors.white, fontSize: 13, height: 1.9),
          ),
        ],
      ),
    );
  }

  Widget _reminders() {
    const reminders = [
      'خودت رو ببخش. همین امروز.',
      'نه گفتن، طرد کردن نیست.',
      'استراحت، تنبلی نیست.',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SK.yellow,
        border: Border.all(color: SK.yellowBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Text('💡', style: TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 8),
              const Text('یادآوری‌های امروز',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          for (final r in reminders)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
                border: const Border(
                  right:
                      BorderSide(color: Color(0xFFF59E0B), width: 3),
                ),
              ),
              child: Text(r,
                  style: const TextStyle(fontSize: 13, height: 1.9)),
            ),
        ],
      ),
    );
  }

  Widget _startBtn(VoidCallback onTap, bool hasProfile) {
    return Material(
      color: SK.primary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Text(hasProfile ? '🧭' : '✨',
                  style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Text(
                hasProfile ? 'پروفایل الگوهای من' : 'شروع ارزیابی',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              const Icon(Icons.arrow_back,
                  color: Colors.white70, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid() {
    final items = <_ExploreItem>[
      _ExploreItem('🔄', 'چرخه‌های زندگی', 'الگوهای عمیق‌تر',
          const Color(0xFF8B5CF6), onLifeCycles),
      _ExploreItem('🔍', 'حس الان من', 'موقعیت‌های واقعی',
          const Color(0xFF0EA5E9), onSituations),
      _ExploreItem('🕊️', 'پذیرش', 'آنچه انتخاب نکردم',
          const Color(0xFF14B8A6), onAcceptance),
      _ExploreItem('💞', 'روابط من', 'چطور برخورد کنم؟',
          const Color(0xFFEC4899), onRelationships),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.05,
      children: items.map(_exploreCard).toList(),
    );
  }

  Widget _exploreCard(_ExploreItem item) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E5E5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(item.emoji,
                    style: const TextStyle(fontSize: 20)),
              ),
              const Spacer(),
              Text(item.title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(item.subtitle,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF666666))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _disclaimer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('این اپ چه چیزی نیست:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
          SizedBox(height: 6),
          Text('• تشخیص پزشکی نمی‌دهد',
              style: TextStyle(
                  fontSize: 11, height: 1.9, color: Color(0xBF000000))),
          Text('• از AI برای قضاوت استفاده نمی‌کند',
              style: TextStyle(
                  fontSize: 11, height: 1.9, color: Color(0xBF000000))),
          Text('• جایگزین درمانگر نیست',
              style: TextStyle(
                  fontSize: 11, height: 1.9, color: Color(0xBF000000))),
        ],
      ),
    );
  }
}

class _ExploreItem {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ExploreItem(
      this.emoji, this.title, this.subtitle, this.color, this.onTap);
}

// ═══════════════════════════════════════════════════════════
// ShenakhtTab — تب شناخت (ناوبری داخلی)
// ═══════════════════════════════════════════════════════════
class ShenakhtTab extends StatefulWidget {
  const ShenakhtTab({super.key});
  @override
  State<ShenakhtTab> createState() => _ShenakhtTabState();
}

class _ShenakhtTabState extends State<ShenakhtTab> {
  String _route = 'welcome';

  void _go(String r) => setState(() => _route = r);

  @override
  Widget build(BuildContext context) {
    final hasBg = context.watch<BackgroundStore>().hasBackground;

    Widget screen;
    switch (_route) {
      case 'ysq':
        screen = YsqScreen(
          onBack: () => _go('welcome'),
          onDone: () => _go('profile'),
        );
        break;
      case 'profile':
        screen = ShenakhtShell(
          title: 'پروفایل',
          onBack: () => _go('welcome'),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉 ارزیابی انجام شد!',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Text(
                  'پروفایل واقعی رو در مرحله‌ی بعد می‌سازیم.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        );
        break;
      case 'welcome':
      default:
        screen = WelcomeScreen(
          onStart: () => _go('ysq'),
          onProfile: () => _go('profile'),
          onLifeCycles: () {},
          onSituations: () {},
          onRelationships: () {},
          onAcceptance: () {},
          onSOS: () {},
        );
        break;
    }

    return ColoredBox(
      color: hasBg ? Colors.transparent : SK.bg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: screen,
      ),
    );
  }
}
