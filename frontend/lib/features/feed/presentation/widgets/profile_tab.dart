import 'package:apsbrat_frontend/core/constants/social_platforms.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/auth/data/auth_repository.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/school_timeline.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_models.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _ProfileHeader(onSettings: () => _openSettings(context)),

          // ── Body ──
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Personal info'),
                const SizedBox(height: 10),
                const _PersonalInfoSection(),
                const SizedBox(height: 20),
                const SectionLabel('My APS Schools'),
                const SizedBox(height: 10),
                const _SchoolsSection(),
                const SizedBox(height: 20),
                const SectionLabel('Socials'),
                const SizedBox(height: 10),
                const _SocialsSection(),
                const SizedBox(height: 32),
              ],
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
    final profile = username == null
        ? null
        : ref.watch(profileProvider(username)).valueOrNull;
    final schools = ref.watch(mySchoolHistoryProvider).valueOrNull;

    final name = (me?.fullName ?? '').isNotEmpty
        ? me!.fullName
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
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
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
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: kGoldLight,
                      border: Border.all(color: AppColors.gold, width: 3),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: me == null
                        ? const Icon(
                            Icons.person_outline_rounded,
                            size: 34,
                            color: kGoldDark,
                          )
                        : Text(
                            _initials(me.fullName),
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: kGoldDark,
                            ),
                          ),
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
        Positioned(
          bottom: -1,
          left: 0,
          right: 0,
          child: Container(
            height: 22,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.elliptical(160, 22),
              ),
            ),
          ),
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
          value: me?.profession,
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

// ── Schools section ───────────────────────────────────────────────────────────

class _SchoolsSection extends ConsumerWidget {
  const _SchoolsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(mySchoolHistoryProvider)
        .when(
          data: (schools) => SchoolTimeline(schools: schools),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.crimson),
            ),
          ),
          error: (_, __) => const SchoolTimeline(schools: []),
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

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  bool _showPhone = true;
  bool _showProfileViews = false;
  bool _notifyJoins = true;
  bool _notifyMessages = true;
  bool _notifyRequests = true;

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
                _SettingsSection(
                  label: 'Account',
                  rows: [
                    _SettingsRow(
                      iconBg: kCrimsonLight,
                      icon: Icons.person_rounded,
                      iconColor: kCrimsonMed,
                      title: 'Edit profile',
                      subtitle: 'Name, photo, bio, username',
                      onTap: () {},
                    ),
                    _SettingsRow(
                      iconBg: kGoldLight,
                      icon: Icons.school_rounded,
                      iconColor: kGoldDark,
                      title: 'My schools',
                      subtitle: 'Add or edit APS schools',
                      onTap: () {},
                    ),
                    _SettingsRow(
                      iconBg: kCrimsonLight,
                      icon: Icons.link_rounded,
                      iconColor: kCrimsonMed,
                      title: 'Social links',
                      subtitle: 'Instagram, WhatsApp, LinkedIn',
                      onTap: () {},
                    ),
                  ],
                ),
                _SettingsSection(
                  label: 'Privacy',
                  rows: [
                    _SettingsRow(
                      iconBg: kGoldLight,
                      icon: Icons.visibility_rounded,
                      iconColor: kGoldDark,
                      title: 'Profile visibility',
                      subtitle: 'Who can see your profile',
                      trailing: const Text(
                        'Batchmates only',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: kCrimsonMed,
                        ),
                      ),
                      onTap: () {},
                    ),
                    _SettingsRow(
                      iconBg: kCrimsonLight,
                      icon: Icons.phone_rounded,
                      iconColor: kCrimsonMed,
                      title: 'Show phone number',
                      subtitle: 'Visible to connected batchmates',
                      trailing: _Toggle(
                        value: _showPhone,
                        onChanged: (v) => setState(() => _showPhone = v),
                      ),
                      onTap: () {},
                    ),
                    _SettingsRow(
                      iconBg: kGoldLight,
                      icon: Icons.visibility_off_rounded,
                      iconColor: kGoldDark,
                      title: 'Show profile views',
                      subtitle: 'Let others know you viewed them',
                      trailing: _Toggle(
                        value: _showProfileViews,
                        onChanged: (v) => setState(() => _showProfileViews = v),
                      ),
                      onTap: () {},
                    ),
                  ],
                ),
                _SettingsSection(
                  label: 'Notifications',
                  rows: [
                    _SettingsRow(
                      iconBg: kCrimsonLight,
                      icon: Icons.notifications_rounded,
                      iconColor: kCrimsonMed,
                      title: 'New batchmate joins',
                      subtitle: 'Alert when someone from your batch joins',
                      trailing: _Toggle(
                        value: _notifyJoins,
                        onChanged: (v) => setState(() => _notifyJoins = v),
                      ),
                      onTap: () {},
                    ),
                    _SettingsRow(
                      iconBg: kGoldLight,
                      icon: Icons.chat_bubble_rounded,
                      iconColor: kGoldDark,
                      title: 'New messages',
                      subtitle: 'Push notification for messages',
                      trailing: _Toggle(
                        value: _notifyMessages,
                        onChanged: (v) => setState(() => _notifyMessages = v),
                      ),
                      onTap: () {},
                    ),
                    _SettingsRow(
                      iconBg: kCrimsonLight,
                      icon: Icons.person_add_rounded,
                      iconColor: kCrimsonMed,
                      title: 'Connection requests',
                      subtitle: 'When someone wants to connect',
                      trailing: _Toggle(
                        value: _notifyRequests,
                        onChanged: (v) => setState(() => _notifyRequests = v),
                      ),
                      onTap: () {},
                    ),
                  ],
                ),
                _SettingsSection(
                  label: 'Support',
                  rows: [
                    _SettingsRow(
                      iconBg: const Color(0xFFF0EDE5),
                      icon: Icons.help_outline_rounded,
                      iconColor: const Color(0xFF6A6050),
                      title: 'Help & FAQ',
                      subtitle: 'Common questions answered',
                      onTap: () {},
                    ),
                    _SettingsRow(
                      iconBg: const Color(0xFFF0EDE5),
                      icon: Icons.flag_outlined,
                      iconColor: const Color(0xFF6A6050),
                      title: 'Report a problem',
                      subtitle: 'Something not working right?',
                      onTap: () {},
                    ),
                    _SettingsRow(
                      iconBg: const Color(0xFFFEF3F3),
                      icon: Icons.logout_rounded,
                      iconColor: const Color(0xFFC53030),
                      title: 'Log out',
                      subtitle: 'You can log back in anytime',
                      titleColor: const Color(0xFFC53030),
                      trailing: const SizedBox.shrink(),
                      onTap: () {},
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
