import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const _gold = Color(0xFFE8B84A);
  static const _goldDeep = Color(0xFFD4A84A);
  static const _cream = Color(0xFFF5EFE6);
  static const _body = Color(0xFFE9D3B8);
  static const _muted = Color(0xFFC9B49A);
  static const _maroonText = Color(0xFF4A0C0C);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.4),
              radius: 1.2,
              colors: [Color(0xFF6E1418), Color(0xFF4E0B0F), Color(0xFF2A0508)],
              stops: [0, 0.55, 1],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  child: Opacity(
                    opacity: 0.7,
                    child: Image.asset(
                      'assets/images/splash_swirl_top.png',
                      width: 110,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Opacity(
                    opacity: 0.7,
                    child: Image.asset(
                      'assets/images/splash_swirl_bottom.png',
                      width: 150,
                    ),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            children: [
                              const SizedBox(height: 64),
                              Image.asset(
                                'assets/images/aps_crest.png',
                                width: 104,
                                height: 104,
                                semanticLabel: 'APS Brat crest',
                              ),
                              const SizedBox(height: 20),
                              _Title(),
                              const SizedBox(height: 10),
                              const _Subtitle(),
                              const SizedBox(height: 18),
                              const _DiamondDivider(),
                              const SizedBox(height: 26),
                              _Headline(),
                              const SizedBox(height: 14),
                              const _BodyText(),
                              const SizedBox(height: 24),
                              const _StatsPill(),
                              const SizedBox(height: 40),
                              _JoinButton(
                                onTap: () => context.go('/login?mode=signup'),
                              ),
                              const SizedBox(height: 10),
                              _LoginButton(onTap: () => context.go('/login')),
                              const Spacer(),
                              const SizedBox(height: 20),
                              const _Footer(),
                              const SizedBox(height: 28),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Text sections ─────────────────────────────────────────────────────────────

class _Title extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.cinzel(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          height: 1,
          letterSpacing: 0.5,
        ),
        children: const [
          TextSpan(
            text: 'APS ',
            style: TextStyle(color: SplashScreen._cream),
          ),
          TextSpan(
            text: 'Brats',
            style: TextStyle(color: SplashScreen._gold),
          ),
        ],
      ),
    );
  }
}

class _Subtitle extends StatelessWidget {
  const _Subtitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      'ARMY PUBLIC SCHOOLS · ALL OF INDIA',
      style: GoogleFonts.mulish(
        color: SplashScreen._muted,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.5,
      ),
    );
  }
}

class _DiamondDivider extends StatelessWidget {
  const _DiamondDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x00D4A84A), SplashScreen._goldDeep],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Transform.rotate(
          angle: 0.785398,
          child: Container(width: 6, height: 6, color: SplashScreen._goldDeep),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [SplashScreen._goldDeep, Color(0x00D4A84A)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: GoogleFonts.cinzel(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          height: 1.35,
          color: SplashScreen._cream,
        ),
        children: const [
          TextSpan(text: 'Your batchmates\n'),
          TextSpan(
            text: 'are already here.',
            style: TextStyle(color: SplashScreen._gold),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _BodyText extends StatelessWidget {
  const _BodyText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Every school. Every batch. Thousands of faces\nyou still think about.',
      textAlign: TextAlign.center,
      style: GoogleFonts.mulish(
        color: SplashScreen._muted,
        fontSize: 14,
        height: 1.6,
      ),
    );
  }
}

class _StatsPill extends StatelessWidget {
  const _StatsPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: SplashScreen._goldDeep.withValues(alpha: 0.4),
        ),
      ),
      child: Text.rich(
        TextSpan(
          style: GoogleFonts.mulish(fontSize: 13, color: SplashScreen._cream),
          children: const [
            TextSpan(
              text: '4,200+',
              style: TextStyle(
                color: SplashScreen._gold,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: ' brats across '),
            TextSpan(
              text: '137',
              style: TextStyle(
                color: SplashScreen._gold,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: ' schools'),
          ],
        ),
      ),
    );
  }
}

// ── Buttons ───────────────────────────────────────────────────────────────────

class _JoinButton extends StatelessWidget {
  const _JoinButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Material(
        color: SplashScreen._gold,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: SplashScreen._goldDeep, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Join APS Brats',
                style: TextStyle(
                  color: SplashScreen._maroonText,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 8),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 18,
                color: SplashScreen._maroonText,
              ),
              SizedBox(width: 8),
              Text(
                'Register',
                style: TextStyle(
                  color: SplashScreen._maroonText,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: SplashScreen._goldDeep, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Already an APS Brat? ',
                style: TextStyle(color: SplashScreen._body, fontSize: 14),
              ),
              Text(
                'Log In',
                style: TextStyle(
                  color: SplashScreen._gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 8),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 16,
                color: SplashScreen._gold,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset('assets/images/splash_laurel_left.png', width: 18),
        const SizedBox(width: 10),
        Text(
          'ONCE A BRAT, ALWAYS A BRAT',
          style: GoogleFonts.mulish(
            color: SplashScreen._muted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(width: 10),
        Image.asset('assets/images/splash_laurel_right.png', width: 18),
      ],
    );
  }
}
