import 'dart:convert';

import 'package:apsbrat_frontend/core/app_root.dart';
import 'package:apsbrat_frontend/core/constants/social_platforms.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/auth/data/auth_repository.dart';
import 'package:apsbrat_frontend/features/auth/presentation/providers/auth_provider.dart';
import 'package:apsbrat_frontend/features/career/data/career_models.dart';
import 'package:apsbrat_frontend/features/career/data/career_repository.dart';
import 'package:apsbrat_frontend/features/career/presentation/journey_timeline.dart';
import 'package:apsbrat_frontend/features/community/data/community_repository.dart'
    show friendlyError;
import 'package:apsbrat_frontend/features/community/presentation/post_card.dart'
    show confirmDialog;
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_models.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_repository.dart';
import 'package:apsbrat_frontend/features/profile/presentation/widgets/profile_photo.dart';
import 'package:apsbrat_frontend/features/settings/data/account_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  int _tab = 0;

  static const _tabs = [
    (Icons.person_rounded, 'About'),
    (Icons.timeline_rounded, 'Journey'),
    (Icons.link_rounded, 'Socials'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _ProfileHeader(onSettings: () => _openSettings(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _ProfileTabBar(
              tabs: _tabs,
              current: _tab,
              onTap: (i) => setState(() => _tab = i),
            ),
          ),

          // ── Body: one section per tab ──
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: switch (_tab) {
                0 => [
                  _SectionTitle(
                    label: 'Personal info',
                    editTooltip: 'Edit profile',
                    onEdit: () => context.go('/home/edit-profile'),
                  ),
                  const SizedBox(height: 6),
                  const _PersonalInfoSection(),
                ],
                1 => [const _JourneySection()],
                _ => [
                  const SectionLabel('Socials'),
                  const SizedBox(height: 10),
                  const _SocialsSection(),
                ],
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _SettingsSheet(),
    );
  }
}

// ── Section title (label + edit pencil) ──────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.label,
    required this.editTooltip,
    required this.onEdit,
  });

  final String label;
  final String editTooltip;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SectionLabel(label),
        const Spacer(),
        IconButton(
          tooltip: editTooltip,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
          icon: const Icon(
            Icons.edit_outlined,
            size: 18,
            color: AppColors.crimson,
          ),
          onPressed: onEdit,
        ),
      ],
    );
  }
}

// ── Tab bar (About · Schools · Socials) ───────────────────────────────────────

class _ProfileTabBar extends StatelessWidget {
  const _ProfileTabBar({
    required this.tabs,
    required this.current,
    required this.onTap,
  });

  final List<(IconData, String)> tabs;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == current
                            ? AppColors.crimson
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tabs[i].$1,
                            size: 16,
                            color: i == current ? Colors.white : kTxt3,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tabs[i].$2,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: i == current
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: i == current ? Colors.white : kTxt2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: i == current ? 22 : 0,
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Stat item ─────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              color: Colors.white54,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.04,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header (real data from GET /users/me) ─────────────────────────────────────

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).valueOrNull;
    final username = me?.username;
    final profile = me == null
        ? null
        : ref.watch(profileProvider(me.id)).valueOrNull;
    final schools = ref.watch(mySchoolHistoryProvider).valueOrNull;
    final headline =
        careerHeadline(ref.watch(myCareerProvider).valueOrNull ?? const []) ??
        me?.profession;

    final name = (me?.fullName ?? '').isNotEmpty
        ? me!.fullName!
        : 'Your profile';
    final subtitleParts = [
      if (username != null && username.isNotEmpty) '@$username',
      if ((me?.city ?? '').isNotEmpty) me!.city!,
    ];
    final subtitle = me == null
        ? 'Log in to see your details'
        : subtitleParts.isEmpty
        ? 'Complete your profile in Settings'
        : subtitleParts.join(' · ');

    return Stack(
      children: [
        Container(
          color: AppColors.crimson,
          width: double.infinity,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 22),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: FeedIconBtn(
                      icon: Icons.settings_rounded,
                      onTap: onSettings,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ProfilePhotoButton(
                    initials: me == null ? null : _initials(me.fullName ?? ''),
                  ),
                  const SizedBox(height: 8),
                  if (me != null) _VerifiedPill(verified: me.isVerified),
                  const SizedBox(height: 10),
                  Text(
                    name,
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
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  if ((me?.bio ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      me!.bio!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        height: 1.55,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _StatItem(
                        value: '${profile?.batchmatesCount ?? 0}',
                        label: 'Batchmates',
                      ),
                      _StatItem(
                        value:
                            '${schools?.length ?? profile?.schoolsCount ?? 0}',
                        label: 'Schools',
                      ),
                      _StatItem(
                        value: '${profile?.connectedCount ?? 0}',
                        label: 'Connected',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: StripesPainter())),
        ),
      ],
    );
  }

  /// "Arjun Singh" → "AS"; single word → first letter.
  String _initials(String fullName) {
    final words = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    final first = words.first[0];
    final last = words.length > 1 ? words.last[0] : '';
    return (first + last).toUpperCase();
  }
}

class _VerifiedPill extends StatelessWidget {
  const _VerifiedPill({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    final color = verified ? AppColors.gold : Colors.white54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black26,
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.verified_user_rounded : Icons.shield_outlined,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            verified ? 'Verified' : 'Not verified',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Personal info section ─────────────────────────────────────────────────────

class _PersonalInfoSection extends ConsumerWidget {
  const _PersonalInfoSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).valueOrNull;
    final hasEmail = (me?.email ?? '').isNotEmpty;

    return _SocialsCard(
      children: [
        _InfoRow(
          icon: Icons.alternate_email_rounded,
          label: 'Username',
          value: me?.username == null ? null : '@${me!.username}',
          hint: 'Not set',
        ),
        const Divider(height: 1, color: kBorder),
        _InfoRow(
          icon: Icons.badge_outlined,
          label: 'Full name',
          value: me?.fullName,
          hint: 'Not set',
        ),
        const Divider(height: 1, color: kBorder),
        _InfoRow(
          icon: Icons.phone_outlined,
          label: 'Phone · used to log in',
          value: me?.phone,
          hint: 'Not set',
          verified: me == null ? null : me.isVerified,
        ),
        const Divider(height: 1, color: kBorder),
        _InfoRow(
          icon: Icons.email_outlined,
          label: 'Email',
          value: me?.email,
          hint: 'Not added',
          verified: hasEmail ? false : null,
        ),
        const Divider(height: 1, color: kBorder),
        _InfoRow(
          icon: Icons.cake_outlined,
          label: 'Date of birth',
          value: _formatDob(me?.dob),
          hint: 'Not added',
        ),
        const Divider(height: 1, color: kBorder),
        _InfoRow(
          icon: Icons.location_on_outlined,
          label: 'Current city',
          value: me?.city,
          hint: 'Not added',
        ),
        const Divider(height: 1, color: kBorder),
        _InfoRow(
          icon: Icons.work_outline_rounded,
          label: 'What I do now',
          value:
              careerHeadline(
                ref.watch(myCareerProvider).valueOrNull ?? const [],
              ) ??
              me?.profession,
          hint: 'Not added',
        ),
        const Divider(height: 1, color: kBorder),
        _InfoRow(
          icon: Icons.school_outlined,
          label: 'I am a',
          value: switch (me?.currentStatus) {
            'STUDENT' => 'Student',
            'ALUMNI' => 'Alumni',
            _ => null,
          },
          hint: 'Not set',
        ),
      ],
    );
  }

  /// Backend sends yyyy-MM-dd; show it the way the form collected it.
  String? _formatDob(String? dob) {
    if (dob == null || dob.isEmpty) return null;
    final parsed = DateTime.tryParse(dob);
    return parsed == null ? dob : DateFormat('dd MMM yyyy').format(parsed);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    this.verified,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String hint;

  /// null = no badge, true = "Verified", false = "Not verified".
  final bool? verified;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
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
                  hasValue ? value! : hint,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                    color: hasValue ? kTxt : const Color(0xFFBBBBBB),
                  ),
                ),
              ],
            ),
          ),
          if (verified != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: verified!
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFF3F0EC),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    verified!
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    size: 12,
                    color: verified! ? const Color(0xFF2E7D32) : kTxt3,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    verified! ? 'Verified' : 'Not verified',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: verified! ? const Color(0xFF2E7D32) : kTxt3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Journey section ───────────────────────────────────────────────────────────

class _JourneySection extends ConsumerWidget {
  const _JourneySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final career = ref.watch(myCareerProvider);
    final schools = ref.watch(mySchoolHistoryProvider);
    if (career.isLoading && !career.hasValue ||
        schools.isLoading && !schools.hasValue) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.crimson),
        ),
      );
    }
    return JourneyTimeline(
      career: career.valueOrNull ?? const [],
      schools: schools.valueOrNull ?? const [],
      editable: true,
      onEditSchools: () => context.go('/home/edit-schools'),
    );
  }
}

// ── Socials section ───────────────────────────────────────────────────────────
//
// Same layout as the registration socials page: every platform always gets a
// box. A saved handle fills the box; a missing one shows the blank hint.

class _SocialsSection extends ConsumerWidget {
  const _SocialsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links =
        ref.watch(mySocialLinksProvider).valueOrNull ?? const <SocialLink>[];
    final custom = _linkFor(links, kCustomSocialPlatform.key);

    return Column(
      children: [
        _SocialsCard(
          children: [
            for (int i = 0; i < kSocialPlatforms.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: kBorder),
              _SocialBox(
                info: kSocialPlatforms[i],
                value: _linkFor(links, kSocialPlatforms[i].key)?.handle,
                onTap: () => _edit(
                  context,
                  ref,
                  kSocialPlatforms[i],
                  _linkFor(links, kSocialPlatforms[i].key),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _SocialsCard(
          children: [
            _SocialBox(
              info: kCustomSocialPlatform,
              name: custom?.label,
              value: custom?.handle,
              onTap: () => _edit(context, ref, kCustomSocialPlatform, custom),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    SocialPlatformInfo info,
    SocialLink? current,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditSocialSheet(
        info: info,
        initialHandle: current?.handle ?? '',
        initialLabel: current?.label ?? '',
        onSave: (handle, label) async {
          final userId = await ref.read(authRepositoryProvider).currentUserId();
          if (userId == null || userId.isEmpty) {
            throw StateError('Not logged in');
          }
          await ref
              .read(profileRepositoryProvider)
              .saveSocialLink(
                userId: userId,
                platform: info.key,
                handle: handle,
                label: info.key == kCustomSocialPlatform.key ? label : null,
              );
        },
      ),
    );

    if (saved == true) {
      ref.invalidate(mySocialLinksProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${info.name} saved')));
      }
    }
  }

  SocialLink? _linkFor(List<SocialLink> links, String platformKey) {
    for (final link in links) {
      if (link.platform == platformKey && link.handle.isNotEmpty) return link;
    }
    return null;
  }
}

class _SocialsCard extends StatelessWidget {
  const _SocialsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.crimson.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.crimson.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SocialBox extends StatelessWidget {
  const _SocialBox({
    required this.info,
    required this.onTap,
    this.value,
    this.name,
  });

  final SocialPlatformInfo info;
  final VoidCallback onTap;
  final String? value;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: info.badgeColor,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  info.badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                (name ?? info.name).toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: AppColors.crimson,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDDDDDD)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hasValue ? value! : info.hint,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: hasValue ? kTxt : const Color(0xFFBBBBBB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.edit_outlined, size: 16, color: kTxt3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Edit social sheet ─────────────────────────────────────────────────────────

class _EditSocialSheet extends StatefulWidget {
  const _EditSocialSheet({
    required this.info,
    required this.initialHandle,
    required this.initialLabel,
    required this.onSave,
  });

  final SocialPlatformInfo info;
  final String initialHandle;
  final String initialLabel;
  final Future<void> Function(String handle, String label) onSave;

  @override
  State<_EditSocialSheet> createState() => _EditSocialSheetState();
}

class _EditSocialSheetState extends State<_EditSocialSheet> {
  late final _handleCtrl = TextEditingController(text: widget.initialHandle);
  late final _labelCtrl = TextEditingController(text: widget.initialLabel);
  bool _saving = false;
  String? _error;

  bool get _isCustom => widget.info.key == kCustomSocialPlatform.key;

  @override
  void dispose() {
    _handleCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final handle = _handleCtrl.text.trim();
    final label = _labelCtrl.text.trim();
    if (handle.isEmpty) {
      setState(() => _error = 'Please enter a handle or link.');
      return;
    }
    if (_isCustom && label.isEmpty) {
      setState(() => _error = 'Please give this link a label.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(handle, label);
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      final payload = e.response?.data;
      var message = 'Could not save. Please try again.';
      if (payload is Map<String, dynamic> && payload['error'] is String) {
        message = payload['error'] as String;
      }
      if (mounted) {
        setState(() {
          _saving = false;
          _error = message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + keyboard),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit ${widget.info.name}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: kTxt,
            ),
          ),
          const SizedBox(height: 14),
          if (_isCustom) ...[
            _field(_labelCtrl, 'Label — Portfolio · YouTube · GitHub'),
            const SizedBox(height: 10),
          ],
          _field(_handleCtrl, widget.info.hint, autofocus: !_isCustom),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.crimson,
              minimumSize: const Size(double.infinity, 46),
              shape: const StadiumBorder(),
            ),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    bool autofocus = false,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return TextField(
      controller: ctrl,
      autofocus: autofocus,
      style: const TextStyle(fontSize: 13, color: kTxt),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: border(const Color(0xFFDDDDDD)),
        enabledBorder: border(const Color(0xFFDDDDDD)),
        focusedBorder: border(AppColors.crimson, 1.5),
      ),
    );
  }
}

// ── Settings sheet ────────────────────────────────────────────────────────────

/// Public: everything visible to other APSians.
/// Private: everything visible EXCEPT phone number and social links.
/// Name and schools are always visible — that is the point of the app.
class _PrivacyRow extends ConsumerWidget {
  const _PrivacyRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrivate =
        ref.watch(mySettingsProvider).valueOrNull?.isPrivate ?? false;
    return _SettingsRow(
      iconBg: kGoldLight,
      icon: isPrivate ? Icons.lock_rounded : Icons.public_rounded,
      iconColor: kGoldDark,
      // The label never changes, so the switch always means "Private is on/off".
      title: 'Private profile',
      subtitle: isPrivate
          ? 'On: phone & socials hidden from others'
          : 'Off: everyone can see your phone & socials',
      trailing: _Toggle(
        value: isPrivate,
        onChanged: (v) async {
          try {
            await ref.read(profileRepositoryProvider).setPrivate(v);
            ref.invalidate(mySettingsProvider);
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not save. Try again.')),
              );
            }
          }
        },
      ),
      onTap: () {},
    );
  }
}

/// "Active now / 2h ago" for others. Like WhatsApp, turning it off also
/// hides everyone else's from me.
class _ActivityRow extends ConsumerWidget {
  const _ActivityRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show =
        ref.watch(mySettingsProvider).valueOrNull?.showActivity ?? true;
    return _SettingsRow(
      iconBg: kGoldLight,
      icon: show ? Icons.visibility_rounded : Icons.visibility_off_rounded,
      iconColor: kGoldDark,
      title: 'Show my activity',
      subtitle: show
          ? 'Others see when you were last active'
          : "Hidden. You won't see others' activity either",
      trailing: _Toggle(
        value: show,
        onChanged: (v) async {
          try {
            await ref.read(profileRepositoryProvider).setShowActivity(v);
            ref.invalidate(mySettingsProvider);
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not save. Try again.')),
              );
            }
          }
        },
      ),
      onTap: () {},
    );
  }
}

class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet();

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  bool _loggingOut = false;
  bool _exporting = false;
  bool _deleting = false;

  void _snack(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  void _openBlocked() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push('/home/blocked');
  }

  /// DPDP right of access: the server's export, as text, to the share sheet.
  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final data = await ref.read(accountRepositoryProvider).exportMyData();
      await Share.share(
        const JsonEncoder.withIndent('  ').convert(data),
        subject: 'My APS Brats data',
      );
    } catch (_) {
      _snack("Couldn't prepare your data. Try again.");
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _deleteAccount() async {
    if (_deleting) return;
    final confirmed = await confirmDialog(
      context,
      title: 'Delete your account?',
      message:
          "Your profile will be removed. Your posts and messages stay, shown as an unknown user. This can't be undone.",
      action: 'Delete account',
    );
    if (!confirmed || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(accountRepositoryProvider).deleteMyAccount();
    } catch (e) {
      if (mounted) setState(() => _deleting = false);
      _snack(friendlyError(e, "Couldn't delete your account. Try again."));
      return;
    }
    // Gone on the server: sign out and clear this device, as Log out does.
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) await AppRoot.restart(context);
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'This signs you out and removes your saved login and profile data from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Log out',
              style: TextStyle(color: Color(0xFFC53030)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loggingOut = true);
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) await AppRoot.restart(context);
  }

  Future<void> _logoutEverywhere() async {
    if (_loggingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out of all devices?'),
        content: const Text(
          'Every phone, tablet and browser signed in to your account will be signed out, including this one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Log out everywhere',
              style: TextStyle(color: Color(0xFFC53030)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loggingOut = true);
    try {
      await ref.read(authControllerProvider.notifier).logoutEverywhere();
    } catch (e) {
      if (mounted) setState(() => _loggingOut = false);
      _snack(
        friendlyError(e, "Couldn't sign out your other devices. Try again."),
      );
      return;
    }
    if (mounted) await AppRoot.restart(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: kBorder2,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: kTxt,
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0x0F7B1414)),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: EdgeInsets.zero,
              children: [
                const _SettingsSection(
                  label: 'Privacy',
                  rows: [_PrivacyRow(), _ActivityRow()],
                ),
                _SettingsSection(
                  label: 'Account',
                  rows: [
                    _SettingsRow(
                      iconBg: const Color(0xFFF0EDE5),
                      icon: Icons.block_outlined,
                      iconColor: const Color(0xFF6A6050),
                      title: 'Blocked users',
                      subtitle: 'People you have blocked',
                      onTap: _openBlocked,
                    ),
                    _SettingsRow(
                      iconBg: const Color(0xFFF0EDE5),
                      icon: Icons.download_outlined,
                      iconColor: const Color(0xFF6A6050),
                      title: 'Download my data',
                      subtitle: _exporting
                          ? 'Preparing…'
                          : 'A copy of what we store about you',
                      onTap: _export,
                    ),
                    _SettingsRow(
                      iconBg: const Color(0xFFFEF3F3),
                      icon: Icons.delete_outline_rounded,
                      iconColor: const Color(0xFFC53030),
                      title: 'Delete account',
                      subtitle: _deleting
                          ? 'Deleting…'
                          : 'Remove your profile for good',
                      titleColor: const Color(0xFFC53030),
                      onTap: _deleteAccount,
                    ),
                    _SettingsRow(
                      iconBg: const Color(0xFFFEF3F3),
                      icon: Icons.logout_rounded,
                      iconColor: const Color(0xFFC53030),
                      title: 'Log out',
                      subtitle: _loggingOut
                          ? 'Logging out…'
                          : 'You can log back in anytime',
                      titleColor: const Color(0xFFC53030),
                      trailing: const SizedBox.shrink(),
                      onTap: _logout,
                    ),
                    _SettingsRow(
                      iconBg: const Color(0xFFFEF3F3),
                      icon: Icons.devices_other_rounded,
                      iconColor: const Color(0xFFC53030),
                      title: 'Log out of all devices',
                      subtitle: 'If you lost a phone or used a shared device',
                      titleColor: const Color(0xFFC53030),
                      trailing: const SizedBox.shrink(),
                      onTap: _logoutEverywhere,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.label, required this.rows});

  final String label;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
              color: kTxt3,
            ),
          ),
          const SizedBox(height: 10),
          ...rows,
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing = const Icon(
      Icons.chevron_right_rounded,
      size: 18,
      color: kTxt3,
    ),
    this.titleColor = kTxt,
  });

  final Color iconBg;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: kTxt3),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38,
        height: 22,
        decoration: BoxDecoration(
          color: value ? AppColors.crimson : const Color(0x2F7B1414),
          borderRadius: BorderRadius.circular(100),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x20000000), blurRadius: 3)],
            ),
          ),
        ),
      ),
    );
  }
}
