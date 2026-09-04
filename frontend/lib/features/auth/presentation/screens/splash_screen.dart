import 'dart:math' as math;

import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  // Crimson palette derived from the design
  static const _bg = AppColors.crimson;
  static const _gold = AppColors.gold;
  static const _goldLight = Color(0xFFE8C06A);
  static const _muted = Color(0xFFBBA898);
  static const _pillBg = Color(0xFF2A0808);
  static const _btnBg = Color(0xFF3A0C0C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        // Scrolls on short screens; on tall screens the Spacer keeps the
        // buttons pinned to the bottom as before.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 36),
                      _ApsLogo(),
                      const SizedBox(height: 20),
                      _Title(),
                      const SizedBox(height: 6),
                      _Subtitle(),
                      const SizedBox(height: 20),
                      _DiamondDivider(),
                      const SizedBox(height: 24),
                      _Headline(),
                      const SizedBox(height: 16),
                      _BodyText(),
                      const SizedBox(height: 20),
                      _StatsPill(),
                      const Spacer(),
                      _GetStartedButton(onTap: () => context.go('/onboarding')),
                      const SizedBox(height: 12),
                      _LoginButton(onTap: () => context.go('/login')),
                      const SizedBox(height: 20),
                      _Footer(),
                      const SizedBox(height: 16),
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

// ── Logo ──────────────────────────────────────────────────────────────────────

class _ApsLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: CustomPaint(painter: _CirclesPainter()),
    );
  }
}

class _CirclesPainter extends CustomPainter {
  static const _gold = SplashScreen._gold;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = _gold.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // outer ring
    canvas.drawCircle(center, size.width / 2 - 2, paint);
    // inner ring
    paint.color = _gold.withValues(alpha: 0.55);
    canvas.drawCircle(center, size.width / 2 - 14, paint);

    // hexagon shield fill
    final hexR = size.width / 2 - 26.0;
    final hexPath = _hexPath(center, hexR);
    canvas.drawPath(hexPath, Paint()..color = _gold.withValues(alpha: 0.18));
    canvas.drawPath(
      hexPath,
      Paint()
        ..color = _gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  Path _hexPath(Offset center, double r) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * math.pi / 180;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Text sections ─────────────────────────────────────────────────────────────

class _Title extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RichText(
      text: const TextSpan(
        style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, height: 1),
        children: [
          TextSpan(
            text: 'APS ',
            style: TextStyle(color: Colors.white),
          ),
          TextSpan(
            text: 'Brat',
            style: TextStyle(color: SplashScreen._gold),
          ),
        ],
      ),
    );
  }
}

class _Subtitle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Text(
      'ARMY PUBLIC SCHOOL · ALL OF INDIA',
      style: TextStyle(
        color: SplashScreen._muted,
        fontSize: 10,
        letterSpacing: 1.8,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _DiamondDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: SplashScreen._gold.withValues(alpha: 0.3),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: SplashScreen._gold,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: SplashScreen._gold.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: const TextSpan(
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          height: 1.3,
        ),
        children: [
          TextSpan(
            text: 'Your batchmates\nare ',
            style: TextStyle(color: Colors.white),
          ),
          TextSpan(
            text: 'already here.',
            style: TextStyle(color: SplashScreen._goldLight),
          ),
        ],
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Text(
      '3 schools. 12 years. Hundreds of faces you still think about. '
      'Find every APS brat you\'ve ever known.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: SplashScreen._muted,
        fontSize: 13.5,
        height: 1.55,
      ),
    );
  }
}

class _StatsPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: SplashScreen._pillBg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: SplashScreen._gold.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: RichText(
        text: const TextSpan(
          style: TextStyle(fontSize: 12.5),
          children: [
            TextSpan(
              text: '●  ',
              style: TextStyle(color: SplashScreen._gold, fontSize: 8),
            ),
            TextSpan(
              text: '4,200+',
              style: TextStyle(
                color: SplashScreen._gold,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(
              text: ' APS brats across ',
              style: TextStyle(color: SplashScreen._muted),
            ),
            TextSpan(
              text: '137',
              style: TextStyle(
                color: SplashScreen._gold,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(
              text: ' schools',
              style: TextStyle(color: SplashScreen._muted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Buttons ───────────────────────────────────────────────────────────────────

class _GetStartedButton extends StatelessWidget {
  const _GetStartedButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: SplashScreen._btnBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: SplashScreen._gold.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                border: Border.all(
                  color: SplashScreen._gold.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Get started — it's free",
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: Border.all(
            color: SplashScreen._gold.withValues(alpha: 0.2),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Already have an account? Log in',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: SplashScreen._muted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Text(
      'ONCE AN APS BRAT, ALWAYS AN APS BRAT',
      style: TextStyle(
        color: SplashScreen._muted,
        fontSize: 9,
        letterSpacing: 2.0,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
