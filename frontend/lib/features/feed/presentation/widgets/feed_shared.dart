import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

// ── Local color constants ─────────────────────────────────────────────────────

const kCrimsonLight = Color(0xFFFEF3F3);
const kCrimsonMed = Color(0xFF9B1C1C);
const kGoldLight = Color(0xFFFEF9EE);
const kGoldDark = Color(0xFFA07010);
const kTxt = Color(0xFF1A0606);
const kTxt2 = Color(0xFF5A1414);
const kTxt3 = Color(0xFF9A7070);
const kBorder = Color(0x1F7B1414);
const kBorder2 = Color(0x387B1414);

// ── Stripe painter ────────────────────────────────────────────────────────────

class StripesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 0.7;
    for (double x = -size.height; x < size.width + size.height; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Crimson header shell ──────────────────────────────────────────────────────

class CrimsonHeader extends StatelessWidget {
  const CrimsonHeader({
    super.key,
    required this.child,
    this.waveColor = AppColors.cream,
  });

  final Widget child;
  final Color waveColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: AppColors.crimson,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
              child: child,
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: StripesPainter())),
        ),
      ],
    );
  }
}

// ── Icon button ───────────────────────────────────────────────────────────────

class FeedIconBtn extends StatelessWidget {
  const FeedIconBtn({super.key, required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class FeedSearchBar extends StatelessWidget {
  const FeedSearchBar({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
    this.focusNode,
    this.onFilterTap,
    this.filterActive = false,
    this.onClear,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Shows a sliders icon on the right when set.
  final VoidCallback? onFilterTap;

  /// Paints the sliders icon crimson (filters are applied).
  final bool filterActive;

  /// Shows an ✕ that clears the search when set.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 18, color: kTxt),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 13, color: kTxt),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: kTxt3, fontSize: 13),
                // The app theme fills inputs with a dark colour; the pill
                // itself is the background here, so keep the field clear.
                filled: false,
                // The theme defines outlined enabled/focused borders too;
                // all three must be cleared or a box appears inside the pill.
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (onClear != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close_rounded, size: 18, color: kTxt3),
            ),
          ],
          if (onFilterTap != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onFilterTap,
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: filterActive ? AppColors.crimson : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: filterActive ? Colors.white : kTxt,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Avatar circle ─────────────────────────────────────────────────────────────

class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.initials,
    required this.bg,
    required this.fg,
    this.imageUrl,
    this.size = 38,
    this.fontSize = 13,
    this.online = false,
  });

  final String initials;
  final Color bg;
  final Color fg;

  /// Real profile photo, when the person has one. Falls back to the
  /// initials circle below when null or empty.
  final String? imageUrl;
  final double size;
  final double fontSize;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = imageUrl != null && imageUrl!.isNotEmpty;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(
          child: hasPhoto
              ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _initialsCircle(),
                  errorWidget: (_, __, ___) => _initialsCircle(),
                )
              : _initialsCircle(),
        ),
        if (online)
          Positioned(
            bottom: 1,
            right: 1,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _initialsCircle() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: kCrimsonLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 26, color: kCrimsonMed),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kTxt,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: kTxt3, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: kTxt3,
      ),
    );
  }
}
