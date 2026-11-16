import 'package:apsbrat_frontend/core/constants/social_platforms.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:apsbrat_frontend/core/theme/app_icons.dart';
import 'package:apsbrat_frontend/core/models/person.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/auth/data/auth_repository.dart';
import 'package:apsbrat_frontend/features/community/data/community_repository.dart'
    show friendlyError;
import 'package:apsbrat_frontend/features/community/presentation/post_card.dart'
    show confirmDialog, showReportSheet;
import 'package:apsbrat_frontend/features/connections/data/connection_repository.dart';
import 'package:apsbrat_frontend/features/settings/data/block_repository.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:apsbrat_frontend/features/career/data/career_models.dart';
import 'package:apsbrat_frontend/features/career/data/career_repository.dart';
import 'package:apsbrat_frontend/features/career/presentation/journey_timeline.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_models.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Another APSian's profile, read-only. What is shown follows the owner's
/// privacy switch: Public = everything; Private = everything except phone
/// and socials. Name and schools are always visible.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider(userId));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: profile.when(
          loading: () => Column(
            children: [
              _Header(onBack: () => context.pop()),
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.crimson),
                ),
              ),
            ],
          ),
          error: (_, __) => Column(
            children: [
              _Header(onBack: () => context.pop()),
              const Expanded(
                child: EmptyState(
                  icon: HugeIcons.strokeRoundedUserBlock01,
                  title: 'Profile not available',
                  message: 'This APSian could not be loaded right now.',
                ),
              ),
            ],
          ),
          data: (p) => _ProfileBody(profile: p),
        ),
      ),
    );
  }
}

// ── Header (back only — no edit controls on someone else's profile) ───────────

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
    this.profile,
    this.headline,
    this.trailing,
  });

  final VoidCallback onBack;
  final Profile? profile;

  /// Top-right action (the Report / Block menu).
  final Widget? trailing;

  /// "Engineer at Zomato" — their current job or college.
  final String? headline;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final subtitle = p == null || p.deleted
        ? ''
        : [
            if ((p.username ?? '').isNotEmpty) '@${p.username}',
            if ((p.city ?? '').isNotEmpty) p.city!,
          ].join(' · ');

    return CrimsonHeader(
      waveColor: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              FeedIconBtn(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                onTap: onBack,
              ),
              const Spacer(),
              ?trailing,
            ],
          ),
          if (p != null && p.deleted) ...[
            const SizedBox(height: 6),
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: Colors.black26,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedUserBlock01,
                size: 34,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              p.fullName.isEmpty ? 'Unknown user' : p.fullName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const _HeaderPill(
              'Unknown user',
              icon: HugeIcons.strokeRoundedHelpCircle,
            ),
          ] else if (p != null) ...[
            const SizedBox(height: 6),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: kGoldLight,
                border: Border.all(color: AppColors.gold, width: 3),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _initials(p.fullName),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: kGoldDark,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              p.fullName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if ((headline ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: Text(
                  headline!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gold,
                  ),
                ),
              ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
            if (activeLabel(p.lastActiveAt) case final active?)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  active,
                  style: const TextStyle(fontSize: 12, color: AppColors.gold),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                _HeaderPill(
                  p.currentStatus == 'STUDENT' ? 'Student' : 'Alumni',
                ),
                if (p.isVerified)
                  const _HeaderPill(
                    'Verified',
                    icon: HugeIcons.strokeRoundedShieldUser,
                  ),
                if (p.isPrivate)
                  const _HeaderPill(
                    'Private',
                    icon: HugeIcons.strokeRoundedLockKey,
                  ),
              ],
            ),
            if ((p.bio ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                p.bio!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  static String _initials(String fullName) {
    final words = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    final last = words.length > 1 ? words.last[0] : '';
    return (words.first[0] + last).toUpperCase();
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill(this.text, {this.icon});

  final String text;
  final AppIconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black26,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            HugeIcon(icon: icon!, size: 12, color: AppColors.gold),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = profile;
    if (p.deleted) {
      return Column(
        children: [
          _Header(onBack: () => context.pop(), profile: p),
          const Expanded(
            child: EmptyState(
              icon: HugeIcons.strokeRoundedUserBlock01,
              title: 'This account was deleted',
              message:
                  'Their posts and messages are still here, shown as an unknown user.',
            ),
          ),
        ],
      );
    }
    final career = ref.watch(careerProvider(p.id)).valueOrNull ?? const [];
    final headline = careerHeadline(career) ?? p.profession;
    final isMe = ref.watch(myUserIdProvider).valueOrNull == p.id;
    return Column(
      children: [
        _Header(
          onBack: () => context.pop(),
          profile: p,
          headline: headline,
          trailing: isMe ? null : _SafetyMenu(userId: p.id, name: p.fullName),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              _ConnectButton(userId: p.id),
              const SizedBox(height: 18),
              const SectionLabel('About'),
              const SizedBox(height: 10),
              _AboutCard(profile: p, headline: headline),
              const SizedBox(height: 20),
              const SectionLabel('Journey'),
              const SizedBox(height: 10),
              JourneyTimeline(career: career, schools: p.schools),
              const SizedBox(height: 20),
              const SectionLabel('Socials'),
              const SizedBox(height: 10),
              _SocialsCard(profile: p),
            ],
          ),
        ),
      ],
    );
  }
}

/// Report or block this person.
class _SafetyMenu extends ConsumerWidget {
  const _SafetyMenu({required this.userId, required this.name});

  final String userId;
  final String name;

  Future<void> _block(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Block $name?',
      message:
          "You won't see each other in search, communities or chat. You can unblock from Settings.",
      action: 'Block',
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref.read(blockRepositoryProvider).block(userId);
      refreshAfterBlock(ref, userId);
      messenger.showSnackBar(SnackBar(content: Text('$name is blocked')));
      router.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: const HugeIcon(
        icon: HugeIcons.strokeRoundedMoreVertical,
        color: Colors.white,
      ),
      onSelected: (v) => v == 'block'
          ? _block(context, ref)
          : showReportSheet(context, ref, 'USER', userId),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'report', child: Text('Report user')),
        PopupMenuItem(
          value: 'block',
          child: Text('Block user', style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.profile, this.headline});

  final Profile profile;
  final String? headline;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final rows = <(AppIconData, String, String?)>[
      (HugeIcons.strokeRoundedLocation01, 'Current city', p.city),
      (HugeIcons.strokeRoundedBriefcase01, 'What they do now', headline),
      (HugeIcons.strokeRoundedCall, 'Phone', p.phone),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kBorder, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: kBorder),
            _AboutRow(
              icon: rows[i].$1,
              label: rows[i].$2,
              value: rows[i].$3,
              hint: rows[i].$2 == 'Phone' && p.isPrivate
                  ? 'Private'
                  : 'Not added',
            ),
          ],
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
  });

  final AppIconData icon;
  final String label;
  final String? value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final has = (value ?? '').isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Row(
        children: [
          HugeIcon(icon: icon, size: 18, color: kTxt3),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: AppColors.crimson,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  has ? value! : hint,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: has ? FontWeight.w600 : FontWeight.w400,
                    color: has ? kTxt : const Color(0xFFBBBBBB),
                  ),
                ),
              ],
            ),
          ),
          if (!has && hint == 'Private')
            const HugeIcon(
              icon: HugeIcons.strokeRoundedLockKey,
              size: 16,
              color: kTxt3,
            ),
        ],
      ),
    );
  }
}

class _SocialsCard extends StatelessWidget {
  const _SocialsCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    if (p.socials.isEmpty) {
      return EmptyState(
        icon: p.isPrivate
            ? HugeIcons.strokeRoundedLockKey
            : HugeIcons.strokeRoundedLink01,
        title: p.isPrivate ? 'Socials are private' : 'No socials added',
        message: p.isPrivate
            ? '${p.fullName.split(' ').first} keeps contact details private.'
            : 'This APSian has not linked any social accounts yet.',
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kBorder, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (int i = 0; i < p.socials.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: kBorder),
            _SocialRow(link: p.socials[i]),
          ],
        ],
      ),
    );
  }
}

class _SocialRow extends StatelessWidget {
  const _SocialRow({required this.link});

  final SocialLink link;

  @override
  Widget build(BuildContext context) {
    final info =
        kSocialPlatforms.where((s) => s.key == link.platform).firstOrNull ??
        kCustomSocialPlatform;
    final name =
        link.platform == kCustomSocialPlatform.key &&
            (link.label ?? '').isNotEmpty
        ? link.label!
        : info.name;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: info.badgeColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              info.badge,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kTxt3,
                  ),
                ),
                Text(
                  link.handle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kTxt,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Connect button (real connection status) ───────────────────────────────────

class _ConnectButton extends ConsumerStatefulWidget {
  const _ConnectButton({required this.userId});

  final String userId;

  @override
  ConsumerState<_ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends ConsumerState<_ConnectButton> {
  bool _busy = false;

  Future<void> _act(String status) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(connectionRepositoryProvider);
      if (status == 'PENDING_IN') {
        await repo.accept(widget.userId);
      } else {
        await repo.request(widget.userId);
      }
      refreshConnections(ref, otherUserId: widget.userId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update connection. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status =
        ref.watch(connectionStatusProvider(widget.userId)).valueOrNull ??
        'NONE';
    final (label, icon, enabled) = switch (status) {
      'CONNECTED' => ('Connected', HugeIcons.strokeRoundedTick02, false),
      'PENDING_OUT' => ('Requested', HugeIcons.strokeRoundedHourglass, false),
      'PENDING_IN' => (
        'Accept request',
        HugeIcons.strokeRoundedUserAdd02,
        true,
      ),
      _ => ('Connect', HugeIcons.strokeRoundedUserAdd02, true),
    };
    final muted = !enabled;

    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: muted ? kCrimsonLight : AppColors.crimson,
        foregroundColor: muted ? kCrimsonMed : Colors.white,
        minimumSize: const Size(double.infinity, 44),
        shape: const StadiumBorder(),
      ),
      onPressed: enabled && !_busy ? () => _act(status) : null,
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : HugeIcon(icon: icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}
