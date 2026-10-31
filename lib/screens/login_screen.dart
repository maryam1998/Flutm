import 'package:flutter/material.dart';

import '../app.dart' show Shell;
import '../services/auth_service.dart';

/// تا وقتی وارد نشده (یا مهمان نشده)، صفحه‌ی ورود؛ بعدش خودِ برنامه.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        switch (auth.state) {
          case AuthStatus.loading:
            return const _Loading();
          case AuthStatus.signedOut:
            return const LoginScreen();
          case AuthStatus.guest:
          case AuthStatus.signedIn:
            return const Shell();
        }
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: Color(0xFFC9962B)),
        ),
      );
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  static const _gold = Color(0xFFC9962B);

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFBF2),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: ListenableBuilder(
                  listenable: auth,
                  builder: (context, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.psychology_outlined,
                            size: 46, color: _gold),
                      ),
                      const SizedBox(height: 22),
                      const Text('خوش آمدی',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1B1B1B))),
                      const SizedBox(height: 8),
                      const Text(
                          'با ورود، اطلاعاتت ذخیره می‌شه و با دوستان هم‌فرکانس در ارتباط می‌مونی.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13,
                              height: 1.7,
                              color: Color(0xFF6B6B6B))),
                      const SizedBox(height: 34),
                      _GoogleButton(
                        busy: auth.busy,
                        onTap: auth.busy ? null : auth.signInWithGoogle,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: auth.busy ? null : auth.continueAsGuest,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          foregroundColor: const Color(0xFF3A3A3A),
                          side: BorderSide(color: _gold.withValues(alpha: 0.6)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('ادامه به‌عنوان مهمان',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                      if (auth.error != null) ...[
                        const SizedBox(height: 14),
                        Text(auth.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 12.5, color: Color(0xFFB3261E))),
                      ],
                      const SizedBox(height: 18),
                      const Text(
                          'مهمان: اطلاعات فقط روی همین دستگاه می‌مونه و با پاک شدن برنامه از بین می‌ره.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11.5,
                              height: 1.7,
                              color: Color(0xFF8A8A8A))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E2E2)),
          ),
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: Color(0xFFC9962B)))
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('G',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF4285F4))),
                    SizedBox(width: 12),
                    Text('ورود با Google',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2B2B2B))),
                  ],
                ),
        ),
      ),
    );
  }
}
