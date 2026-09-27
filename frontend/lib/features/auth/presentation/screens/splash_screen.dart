import 'dart:math' as math;

import 'package:apsbrat_frontend/features/auth/presentation/widgets/welcome_brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  // Shared pre-login palette (see welcome_brand.dart).
  static const _bg = Welcome.bg;
  static const _bgEdge = Welcome.bgEdge;
  static const _gold = Welcome.gold;
  static const _goldLight = Welcome.goldLight;
  static const _muted = Welcome.muted;
  static const _pillBg = Welcome.cardDeep;
  static const _btnBg = Welcome.card;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: Container(
          // Soft vignette: slightly lighter centre, darker edges, like the design.
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3),
              radius: 1.2,
              colors: [_bg, _bgEdge],
            ),
          ),
          child: SafeArea(
            // Scrolls on short screens; on tall screens the Spacer keeps the
            // buttons pinned to the bottom.
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          _ApsLogo(),
                          const SizedBox(height: 22),
                          _Title(),
                          const SizedBox(height: 8),
                          _Subtitle(),
                          const SizedBox(height: 22),
                          _DiamondDivider(),
                          const SizedBox(height: 34),
                          _Headline(),
                          const SizedBox(height: 18),
                          _BodyText(),
                          const SizedBox(height: 24),
                          _StatsPill(),
                          const Spacer(),
                          // Both buttons land on the same email/Google screen —
                          // "new" vs "returning" is decided after verifying,
                          // not before.
                          _GetStartedButton(
                            onTap: () => context.go('/login'),
                          ),
                          const SizedBox(height: 12),
                          _LoginButton(onTap: () => context.go('/login')),
                          const SizedBox(height: 26),
                          _Footer(),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
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

// ── Logo: two rings + outlined hexagon ────────────────────────────────────────

class _ApsLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: CustomPaint(painter: _CirclesPainter()),
    );
  }
}

class _CirclesPainter extends CustomPainter {
  static const _gold = SplashScreen._gold;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _gold.withValues(alpha: 0.45);

    // Outer ring (thin) and inner ring (a touch brighter).
    canvas.drawCircle(center, size.width / 2 - 1, stroke);
    stroke.color = _gold.withValues(alpha: 0.75);
    canvas.drawCircle(center, size.width / 2 - 11, stroke);

    // Hexagon shield: faint fill + crisp gold outline.
    final hexPath = _hexPath(center, size.width / 2 - 22);
    canvas.drawPath(hexPath, Paint()..color = _gold.withValues(alpha: 0.10));
    canvas.drawPath(
      hexPath,
      Paint()
        ..color = _gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
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
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1),
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
        letterSpacing: 2.2,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _DiamondDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(
        height: 1,
        color: SplashScreen._gold.withValues(alpha: 0.35),
      ),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: SplashScreen._gold,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
        line,
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
        // Serif, like the design's editorial headline.
        style: TextStyle(
          fontFamily: 'serif',
          fontSize: 26,
          fontWeight: FontWeight.w600,
          height: 1.25,
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
      '3 schools. 12 years. Hundreds of faces you still think about.\n'
      "Find every APS brat you've ever known.",
      textAlign: TextAlign.center,
      style: TextStyle(color: SplashScreen._muted, fontSize: 13, height: 1.55),
    );
  }
}

class _StatsPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: SplashScreen._pillBg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: SplashScreen._gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.groups_rounded, size: 18, color: SplashScreen._gold),
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: SplashScreen._gold.withValues(alpha: 0.35),
          ),
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 13, color: Colors.white),
              children: [
                TextSpan(
                  text: '4,200+',
                  style: TextStyle(
                    color: SplashScreen._gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: ' APS brats across '),
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
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: SplashScreen._btnBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: SplashScreen._gold.withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 19,
              color: SplashScreen._gold,
            ),
            Expanded(
              child: Text(
                "Get Started — It's Free",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: SplashScreen._goldLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              size: 19,
              color: SplashScreen._gold,
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: SplashScreen._gold.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Already an APS brat?  ',
              style: TextStyle(color: SplashScreen._muted, fontSize: 13),
            ),
            const Text(
              'Log In',
              style: TextStyle(
                color: SplashScreen._gold,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: SplashScreen._gold,
            ),
          ],
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
        letterSpacing: 2.6,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
