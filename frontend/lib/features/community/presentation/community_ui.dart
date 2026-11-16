import 'package:apsbrat_frontend/core/models/person.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/community/data/community_models.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:apsbrat_frontend/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared look of the community screens: warm page, soft cards, pills.
const kCommunityBg = Color(0xFFFBF8F6);
const kCardLine = Color(0xFFEADCDC);
const kTint = Color(0xFFF3ECEC);

/// The school banner for APS Patiala; null for every other community.
String? communityBannerAsset(Community c) =>
    c.isSchool && c.name.toLowerCase().contains('patiala')
    ? 'assets/images/aps_patiala_banner.webp'
    : null;

BoxDecoration communityCard({
  Color color = Colors.white,
  Color line = kCardLine,
}) => BoxDecoration(
  color: color,
  border: Border.all(color: line, width: 0.8),
  borderRadius: BorderRadius.circular(14),
);

/// Rounded action: filled crimson (main) or soft tint (secondary).
class CommunityPill extends StatelessWidget {
  const CommunityPill({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.filled = false,
    this.expand = false,
    this.trailing,
  });

  final String label;
  final AppIconData? icon;
  final VoidCallback? onTap;
  final bool filled;

  /// Grow to fill a Row (wraps itself in Expanded).
  final bool expand;
  final AppIconData? trailing;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : AppColors.crimsonDark;
    final pill = Material(
      color: filled ? AppColors.crimson : kTint,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                HugeIcon(icon: icon!, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 4),
                HugeIcon(icon: trailing!, size: 16, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
    return expand ? Expanded(child: pill) : pill;
  }
}

/// Small overlapping faces: "these people are here".
class AvatarStack extends StatelessWidget {
  const AvatarStack({super.key, required this.people, this.size = 24});

  final List<Person> people;
  final double size;

  @override
  Widget build(BuildContext context) {
    final shown = people.take(3).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: size + (shown.length - 1) * size * 0.65,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * size * 0.65,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: AvatarCircle(
                  initials: shown[i].initials,
                  imageUrl: shown[i].profilePicUrl,
                  bg: shown[i].bg,
                  fg: shown[i].fg,
                  size: size - 3,
                  fontSize: size * 0.38,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The signed-in user's face (for "share something" prompts).
class MyAvatar extends ConsumerWidget {
  const MyAvatar({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).valueOrNull;
    final parts = (me?.fullName ?? '').trim().split(RegExp(r'\s+'));
    final initials = [
      if (parts.first.isNotEmpty) parts.first[0],
      if (parts.length > 1) parts.last[0],
    ].join().toUpperCase();
    return AvatarCircle(
      initials: initials.isEmpty ? '?' : initials,
      imageUrl: me?.profilePicUrl,
      bg: kCrimsonLight,
      fg: AppColors.crimson,
      size: size,
      fontSize: size * 0.36,
    );
  }
}

/// A one-line card that opens something bigger (composer, add memory).
class PromptCard extends StatelessWidget {
  const PromptCard({
    super.key,
    required this.hint,
    required this.onTap,
    this.leading = const MyAvatar(size: 30),
    this.trailingIcon = HugeIcons.strokeRoundedImage01,
    this.actionIcons,
  });

  final String hint;
  final VoidCallback onTap;
  final Widget leading;
  final AppIconData trailingIcon;

  /// Several action icons in place of [trailingIcon].
  final List<AppIconData>? actionIcons;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: communityCard(),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F1F1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hint,
                    style: const TextStyle(fontSize: 13, color: kTxt3),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (actionIcons == null)
                HugeIcon(icon: trailingIcon, color: AppColors.crimson, size: 22)
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final icon in actionIcons!)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: HugeIcon(
                          icon: icon,
                          color: AppColors.crimson,
                          size: 22,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
