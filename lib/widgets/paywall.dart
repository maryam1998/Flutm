import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../map/draw_utils.dart' show toFa;
import '../services/auth_service.dart';
import '../services/premium_service.dart';
import '../theme/grat_palette.dart';

/// دروازه‌ی بخش‌های کاملاً پولی: کاربرِ پولی → خودِ بخش؛ وگرنه صفحه‌ی اشتراک.
/// (تا پولی نشده باشد، بخش اصلاً ساخته نمی‌شود.)
class PremiumGate extends StatefulWidget {
  const PremiumGate({super.key, required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  State<PremiumGate> createState() => _PremiumGateState();
}

class _PremiumGateState extends State<PremiumGate> {
  final svc = PremiumService.instance;

  @override
  void initState() {
    super.initState();
    svc.init();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: svc,
      builder: (context, _) => svc.isPremium
          ? widget.child
          : Material(
              color: Colors.transparent,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: PaywallCard(
                      reason: '«${widget.title}» بخشِ ویژه‌ی اشتراک است.'),
                ),
              ),
            ),
    );
  }
}

/// سقفِ رایگانِ شکرگذاری/بازی فراوانی. true = اجازه هست.
/// وگرنه برگه‌ی اشتراک باز می‌شود و false برمی‌گردد.
Future<bool> premiumAllowOrPaywall(
  BuildContext context, {
  required int used,
  required int limit,
  required String what,
}) async {
  final svc = PremiumService.instance;
  await svc.init();
  if (svc.isPremium || used < limit) return true;
  if (!context.mounted) return false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final pal = GratPalette.of(ctx);
      return Container(
        decoration: BoxDecoration(
          color: pal.paper,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: PaywallCard(
              reason:
                  'سهمِ رایگانِ $what (${toFa(limit)} مورد) تمام شد. برای ادامه اشتراک بگیر.',
              onActivated: () => Navigator.of(ctx).maybePop()),
        ),
      );
    },
  );
  return svc.isPremium;
}

class PaywallCard extends StatefulWidget {
  const PaywallCard({super.key, required this.reason, this.onActivated});
  final String reason;
  final VoidCallback? onActivated;
  @override
  State<PaywallCard> createState() => _PaywallCardState();
}

class _PaywallCardState extends State<PaywallCard> {
  final svc = PremiumService.instance;
  final _code = TextEditingController();
  String? _msg;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    svc.addListener(_on);
    AuthService.instance.addListener(_on);
  }

  @override
  void dispose() {
    svc.removeListener(_on);
    AuthService.instance.removeListener(_on);
    _code.dispose();
    super.dispose();
  }

  void _on() {
    if (mounted) setState(() {});
  }

  Future<void> _redeem() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _msg = null;
    });
    final err = await svc.redeem(_code.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msg = err;
    });
    if (err == null) widget.onActivated?.call();
  }

  @override
  Widget build(BuildContext context) {
    final pal = GratPalette.of(context);
    Widget perk(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Icon(Icons.check_circle_rounded, size: 18, color: pal.emerald500),
            const SizedBox(width: 8),
            Expanded(
                child: Text(t,
                    style: TextStyle(
                        fontSize: 13, height: 1.6, color: pal.inkSoft))),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pal.gold500.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Icon(Icons.workspace_premium_rounded, size: 44, color: pal.gold500)),
          const SizedBox(height: 8),
          Text('اشتراک Same Frequency',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: pal.ink)),
          const SizedBox(height: 6),
          Text(widget.reason,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.7, color: pal.muted)),
          const SizedBox(height: 14),
          perk('هدف‌گذاری و نقشه‌ی بی‌نهایت راه'),
          perk('بخش شناخت'),
          perk('دوستان هم‌فرکانسی'),
          perk('شکرگذاری و بازی فراوانیِ نامحدود'),
          const SizedBox(height: 8),
          Text(kPremiumPriceText,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: pal.gold600)),
          const SizedBox(height: 12),
          if (!svc.signedIn) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: pal.emerald700,
                  minimumSize: const Size.fromHeight(46)),
              onPressed: () => AuthService.instance.signInWithGoogle(),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('ورود با Google (لازمِ فعال‌سازی)'),
            ),
          ] else ...[
            if (kPremiumPayUrl.isNotEmpty || kPremiumContact.isNotEmpty)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44)),
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                      text: kPremiumPayUrl.isNotEmpty
                          ? kPremiumPayUrl
                          : kPremiumContact));
                  setState(() => _msg = kPremiumPayUrl.isNotEmpty
                      ? 'لینک پرداخت کپی شد؛ در مرورگر باز کن.'
                      : 'آیدی کپی شد؛ برای خرید پیام بده.');
                },
                icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                label: Text(kPremiumPayUrl.isNotEmpty
                    ? 'کپی لینک پرداخت'
                    : 'ارتباط برای خرید: $kPremiumContact'),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _code,
              textDirection: TextDirection.ltr,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'کد فعال‌سازی',
                filled: true,
                fillColor: pal.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: pal.line)),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: pal.emerald700,
                  minimumSize: const Size.fromHeight(46)),
              onPressed: _busy ? null : _redeem,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('فعال‌سازی اشتراک'),
            ),
            TextButton(
                onPressed: svc.loading ? null : svc.refresh,
                child: const Text('پرداخت کردم؛ بررسی دوباره')),
          ],
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_msg!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, height: 1.6, color: pal.danger)),
            ),
        ],
      ),
    );
  }
}
