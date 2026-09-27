import 'dart:math' as math;

import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Shared look of the pre-login screens (welcome, login/OTP):
/// deep maroon canvas, gold accents, serif headlines.
class Welcome {
  const Welcome._();

  static const bg = AppColors.crimson;
  static const bgEdge = AppColors.crimsonDark;
  static const gold = AppColors.gold;
  static const goldLight = Color(0xFFE8C06A);
  static const goldDeep = Color(0xFFC9962E);
  static const muted = Color(0xFFD9C7B8);
  static const card = Color(0xFF5C1010);
  static const cardDeep = Color(0xFF4A0C0C);

  static const headline = TextStyle(
    fontFamily: 'serif',
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: Colors.white,
  );
}

/// Full-screen maroon vignette behind the content.
class WelcomeBackground extends StatelessWidget {
  const WelcomeBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.3),
          radius: 1.2,
          colors: [Welcome.bg, Welcome.bgEdge],
        ),
      ),
      child: child,
    );
  }
}

/// "APS Brat" + "ARMY PUBLIC SCHOOL · ALL OF INDIA".
class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key, this.fontSize = 40});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
            children: const [
              TextSpan(
                text: 'APS ',
                style: TextStyle(color: Colors.white),
              ),
              TextSpan(
                text: 'Brat',
                style: TextStyle(color: Welcome.gold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'ARMY PUBLIC SCHOOL · ALL OF INDIA',
          style: TextStyle(
            color: Welcome.muted,
            fontSize: 10,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Thin gold rule with a diamond in the middle.
class DiamondDivider extends StatelessWidget {
  const DiamondDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(height: 1, color: Welcome.gold.withValues(alpha: 0.35)),
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
                color: Welcome.gold,
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

class WelcomeFooter extends StatelessWidget {
  const WelcomeFooter({super.key, this.withDivider = false});

  final bool withDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'ONCE AN APS BRAT, ALWAYS AN APS BRAT',
          style: TextStyle(
            color: Welcome.muted,
            fontSize: 9,
            letterSpacing: 2.6,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (withDivider) ...[
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 90),
            child: DiamondDivider(),
          ),
        ],
      ],
    );
  }
}

/// Gold gradient button with a slow moving shine and a soft glow.
class ShimmerGoldButton extends StatefulWidget {
  const ShimmerGoldButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.icon = Icons.arrow_forward_rounded,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final IconData icon;

  @override
  State<ShimmerGoldButton> createState() => _ShimmerGoldButtonState();
}

class _ShimmerGoldButtonState extends State<ShimmerGoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null && !widget.loading;
    return GestureDetector(
      onTap: enabled ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: _shine,
        builder: (context, _) {
          // The highlight band sweeps from left (-1) to right (+2) and loops.
          final t = _shine.value * 3 - 1;
          return Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [
                  (t - 0.45).clamp(0.0, 1.0),
                  t.clamp(0.0, 1.0),
                  (t + 0.45).clamp(0.0, 1.0),
                ],
                colors: const [
                  Welcome.goldDeep,
                  Color(0xFFF6E3A1),
                  Welcome.goldDeep,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Welcome.gold.withValues(alpha: 0.45),
                  blurRadius: 22,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Opacity(
              opacity: enabled ? 1 : 0.6,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.loading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Color(0xFF3A0C0C),
                      ),
                    )
                  else
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3A0C0C),
                      ),
                    ),
                  Positioned(
                    right: 20,
                    child: Icon(
                      widget.icon,
                      size: 22,
                      color: const Color(0xFF3A0C0C),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
