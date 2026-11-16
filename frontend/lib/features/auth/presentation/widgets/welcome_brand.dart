import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:apsbrat_frontend/core/theme/app_icons.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared look of the pre-login screens (login/OTP), matching the splash:
/// deep maroon canvas, gold accents, Cinzel headlines, Mulish body text.
class Welcome {
  const Welcome._();

  static const bg = Color(0xFF4E0B0F);
  static const bgEdge = Color(0xFF2A0508);
  static const gold = Color(0xFFE8B84A);
  static const goldDeep = Color(0xFFD4A84A);
  static const goldLight = Color(0xFFF3D27A);
  static const cream = Color(0xFFF5EFE6);
  static const muted = Color(0xFFC9B49A);
  static const card = Color(0x59000000);
  static const cardDeep = Color(0x33000000);

  static TextStyle get headline => GoogleFonts.cinzel(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: cream,
  );
}

/// Full-screen maroon vignette with the gold swirls from the splash.
class WelcomeBackground extends StatelessWidget {
  const WelcomeBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.4),
          radius: 1.2,
          colors: [Color(0xFF6E1418), Welcome.bg, Welcome.bgEdge],
          stops: [0, 0.55, 1],
        ),
      ),
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
          child,
        ],
      ),
    );
  }
}

/// "APS Brat" + "ARMY PUBLIC SCHOOL · ALL OF INDIA".
class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key, this.fontSize = 32});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RichText(
          text: TextSpan(
            style: GoogleFonts.cinzel(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              height: 1,
              letterSpacing: 0.5,
            ),
            children: const [
              TextSpan(
                text: 'APS ',
                style: TextStyle(color: Welcome.cream),
              ),
              TextSpan(
                text: 'Brat',
                style: TextStyle(color: Welcome.gold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'ARMY PUBLIC SCHOOL · ALL OF INDIA',
          style: GoogleFonts.mulish(
            color: Welcome.muted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.5,
          ),
        ),
      ],
    );
  }
}

/// Thin gold rule with a diamond in the middle, fading at both ends.
class DiamondDivider extends StatelessWidget {
  const DiamondDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x00D4A84A), Welcome.goldDeep],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Transform.rotate(
          angle: 0.785398,
          child: Container(width: 6, height: 6, color: Welcome.goldDeep),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Welcome.goldDeep, Color(0x00D4A84A)],
              ),
            ),
          ),
        ),
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
        Text(
          'ONCE AN APS BRAT, ALWAYS AN APS BRAT',
          style: GoogleFonts.mulish(
            color: Welcome.muted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 3,
          ),
        ),
        if (withDivider) ...[
          const SizedBox(height: 14),
          const DiamondDivider(),
        ],
      ],
    );
  }
}

/// Primary button, styled like the splash: gold fill, 2px gold border,
/// 18px corners, 50px high, default font.
class ShimmerGoldButton extends StatelessWidget {
  const ShimmerGoldButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.icon = HugeIcons.strokeRoundedArrowRight01,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final AppIconData icon;

  static const _text = Color(0xFF4A0C0C);

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Material(
        color: enabled ? Welcome.gold : Welcome.gold.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Welcome.goldDeep, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: enabled ? onTap : null,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: _text,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: _text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      HugeIcon(icon: icon, size: 18, color: _text),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
