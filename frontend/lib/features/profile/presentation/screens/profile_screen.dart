import 'package:apsbrat_frontend/core/constants/social_platforms.dart';
import 'package:apsbrat_frontend/core/models/person.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/connections/data/connection_repository.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/school_timeline.dart';
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
                  icon: Icons.person_off_outlined,
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
  const _Header({required this.onBack, this.profile});

  final VoidCallback onBack;
  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final subtitle = p == null
        ? ''
        : [
            if ((p.username ?? '').isNotEmpty) '@${p.username}',
            if ((p.city ?? '').isNotEmpty) p.city!,
          ].join(' · ');

    return CrimsonHeader(
      waveColor: Colors.white,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FeedIconBtn(icon: Icons.arrow_back_rounded, onTap: onBack),
          ),
          if (p != null) ...[
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
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.white54),
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
                    icon: Icons.verified_user_rounded,
                  ),
                if (p.isPrivate)
                  const _HeaderPill(
                    'Private',
                    icon: Icons.lock_outline_rounded,
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
  final IconData? icon;

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
            Icon(icon, size: 12, color: AppColors.gold),
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
    return Column(
      children: [
        _Header(onBack: () => context.pop(), profile: p),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              _ConnectButton(userId: p.id),
              if (p.mutualCount > 0) ...[
                const SizedBox(height: 12),
                _MutualRow(userId: p.id, count: p.mutualCount),
              ],
              const SizedBox(height: 18),
              const SectionLabel('About'),
              const SizedBox(height: 10),
              _AboutCard(profile: p),
              const SizedBox(height: 20),
              const SectionLabel('APS Schools'),
              const SizedBox(height: 10),
              SchoolTimeline(schools: p.schools),
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

/// "N mutual batchmates" with a few stacked avatars; tap to see who.
class _MutualRow extends ConsumerWidget {
  const _MutualRow({required this.userId, required this.count});

  final String userId;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(mutualConnectionsProvider(userId)).valueOrNull;
    final preview = (people ?? const <Person>[]).take(3).toList();
    final names = preview.map((p) => p.name.split(' ').first).toList();
    final label = switch (names.length) {
      0 => '$count mutual ${count == 1 ? 'batchmate' : 'batchmates'}',
      1 when count == 1 => '${names[0]} is a mutual batchmate',
      1 => '${names[0]} and ${count - 1} more',
      2 when count == 2 => '${names[0]} and ${names[1]}',
      _ => '${names[0]}, ${names[1]} and ${count - 2} more',
    };

    return InkWell(
      onTap: () => _showMutual(context, ref),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFCF1F1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24.0 + 16.0 * (preview.isEmpty ? 0 : preview.length - 1),
              height: 28,
              child: Stack(
                children: [
                  for (var i = 0; i < preview.length; i++)
                    Positioned(
                      left: i * 16.0,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: AvatarCircle(
                          initials: preview[i].initials,
                          bg: preview[i].bg,
                          fg: preview[i].fg,
                          size: 24,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  if (preview.isEmpty)
                    const Icon(
                      Icons.people_alt_rounded,
                      size: 22,
                      color: AppColors.crimson,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kTxt,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: kTxt3),
          ],
        ),
      ),
    );
  }

  void _showMutual(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MutualSheet(userId: userId, count: count),
    );
  }
}

class _MutualSheet extends ConsumerWidget {
  const _MutualSheet({required this.userId, required this.count});

  final String userId;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(mutualConnectionsProvider(userId));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count mutual ${count == 1 ? 'batchmate' : 'batchmates'}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: kTxt,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'People you are both connected with.',
              style: TextStyle(fontSize: 12, color: kTxt3),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: people.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.crimson),
                  ),
                ),
                error: (_, __) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Could not load mutual batchmates.'),
                ),
                data: (list) => ListView.separated(
                  shrinkWrap: true,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = list[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: AvatarCircle(
                        initials: p.initials,
                        bg: p.bg,
                        fg: p.fg,
                      ),
                      title: Text(
                        p.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        [
                          if (p.detail.isNotEmpty) p.detail,
                          if (p.school.isNotEmpty) p.school,
                        ].join(' · '),
                        style: const TextStyle(fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        context.go('/home/profile/${p.id}');
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final rows = <(IconData, String, String?)>[
      (Icons.location_on_outlined, 'Current city', p.city),
      (Icons.work_outline_rounded, 'What they do now', p.profession),
      (Icons.phone_outlined, 'Phone', p.phone),
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

  final IconData icon;
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
          Icon(icon, size: 18, color: kTxt3),
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
            const Icon(Icons.lock_outline_rounded, size: 16, color: kTxt3),
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
        icon: p.isPrivate ? Icons.lock_outline_rounded : Icons.link_rounded,
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
      'CONNECTED' => ('Connected', Icons.check_rounded, false),
      'PENDING_OUT' => ('Requested', Icons.hourglass_top_rounded, false),
      'PENDING_IN' => ('Accept request', Icons.person_add_alt_1_rounded, true),
      _ => ('Connect', Icons.person_add_alt_1_rounded, true),
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
          : Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}
