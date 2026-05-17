import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:flutter/material.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Crimson header ──
          Stack(
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
                            onTap: () => _openSettings(context),
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
                          child: const Text(
                            'AS',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: kGoldDark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.4),
                            ),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                size: 12,
                                color: AppColors.gold,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Verified',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.gold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Arjun Singh',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
                          '@arjun.singh · New Delhi',
                          style: TextStyle(fontSize: 12, color: Colors.white54),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'NDA Cadet · Army brat through and through 🪖\nAPS Patiala → APS Pune → APS Delhi',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                            height: 1.55,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        const Row(
                          children: [
                            _StatItem(value: '34', label: 'Batchmates'),
                            _StatItem(value: '3', label: 'Schools'),
                            _StatItem(value: '12', label: 'Connected'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: StripesPainter()),
                ),
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
          ),

          // ── Body ──
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('My APS Schools'),
                const SizedBox(height: 10),
                const _SchoolPill(
                  number: 1,
                  name: 'APS Patiala',
                  years: 'Class 10–12 · Section 12A · 2019–2022',
                  mostMissed: true,
                ),
                const SizedBox(height: 8),
                const _SchoolPill(
                  number: 2,
                  name: 'APS Pune',
                  years: 'Class 6–9 · Section 9C · 2015–2019',
                ),
                const SizedBox(height: 8),
                const _SchoolPill(
                  number: 3,
                  name: 'APS Delhi Cantt',
                  years: 'Class 1–5 · 2010–2015',
                ),
                const SizedBox(height: 20),
                const SectionLabel('Socials'),
                const SizedBox(height: 10),
                _SocialRow(
                  iconBg: const Color(0xFFFCE4EC),
                  icon: Icons.camera_alt_rounded,
                  iconColor: const Color(0xFFC2185B),
                  name: 'Instagram',
                  value: '@arjun.rawat',
                ),
                const SizedBox(height: 7),
                _SocialRow(
                  iconBg: const Color(0xFFE8F5E9),
                  icon: Icons.chat_rounded,
                  iconColor: const Color(0xFF25D366),
                  name: 'WhatsApp',
                  value: '+91 98765 43210',
                ),
                const SizedBox(height: 7),
                _SocialRow(
                  iconBg: const Color(0xFFE3F2FD),
                  icon: Icons.work_rounded,
                  iconColor: const Color(0xFF0077B5),
                  name: 'LinkedIn',
                  value: 'arjun-singh-nda',
                ),
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

// ── School pill ───────────────────────────────────────────────────────────────

class _SchoolPill extends StatelessWidget {
  const _SchoolPill({
    required this.number,
    required this.name,
    required this.years,
    this.mostMissed = false,
  });

  final int number;
  final String name;
  final String years;
  final bool mostMissed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kBorder, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: AppColors.crimson,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kTxt,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  years,
                  style: const TextStyle(fontSize: 11, color: kTxt3),
                ),
              ],
            ),
          ),
          if (mostMissed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: kGoldLight,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Text(
                'Most missed',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: kGoldDark,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Social row ────────────────────────────────────────────────────────────────

class _SocialRow extends StatelessWidget {
  const _SocialRow({
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.name,
    required this.value,
  });

  final Color iconBg;
  final IconData icon;
  final Color iconColor;
  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kBorder, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kTxt,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kCrimsonMed,
            ),
          ),
        ],
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
                _SettingsSection(label: 'Account', rows: [
                  _SettingsRow(
                    iconBg: kCrimsonLight,
                    icon: Icons.person_rounded,
                    iconColor: kCrimsonMed,
                    title: 'Edit profile',
                    subtitle: 'Name, photo, bio, username',
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: kTxt3,
                    ),
                    onTap: () {},
                  ),
                  _SettingsRow(
                    iconBg: kGoldLight,
                    icon: Icons.school_rounded,
                    iconColor: kGoldDark,
                    title: 'My schools',
                    subtitle: 'Add or edit APS schools',
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: kTxt3,
                    ),
                    onTap: () {},
                  ),
                  _SettingsRow(
                    iconBg: kCrimsonLight,
                    icon: Icons.link_rounded,
                    iconColor: kCrimsonMed,
                    title: 'Social links',
                    subtitle: 'Instagram, WhatsApp, LinkedIn',
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: kTxt3,
                    ),
                    onTap: () {},
                  ),
                ]),
                _SettingsSection(label: 'Privacy', rows: [
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
                ]),
                _SettingsSection(label: 'Notifications', rows: [
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
                ]),
                _SettingsSection(label: 'Support', rows: [
                  _SettingsRow(
                    iconBg: const Color(0xFFF0EDE5),
                    icon: Icons.help_outline_rounded,
                    iconColor: const Color(0xFF6A6050),
                    title: 'Help & FAQ',
                    subtitle: 'Common questions answered',
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: kTxt3,
                    ),
                    onTap: () {},
                  ),
                  _SettingsRow(
                    iconBg: const Color(0xFFF0EDE5),
                    icon: Icons.flag_outlined,
                    iconColor: const Color(0xFF6A6050),
                    title: 'Report a problem',
                    subtitle: 'Something not working right?',
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: kTxt3,
                    ),
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
                ]),
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
    required this.trailing,
    required this.onTap,
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
              boxShadow: [
                BoxShadow(color: Color(0x20000000), blurRadius: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
