import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/feed/data/dummy_data.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:flutter/material.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.onOpenBatchmate,
    required this.onOpenChat,
    required this.onGoMessages,
  });

  final ValueChanged<AppPerson> onOpenBatchmate;
  final ValueChanged<AppPerson> onOpenChat;
  final VoidCallback onGoMessages;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CrimsonHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.25,
                              ),
                              children: [
                                const TextSpan(text: 'Good morning,\n'),
                                TextSpan(
                                  text: kShowDemoContent ? 'Arjun.' : 'Brat.',
                                  style: const TextStyle(color: AppColors.gold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            kShowDemoContent
                                ? 'APS Patiala · 12A · 2022'
                                : 'Welcome to APS Brat',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: kGoldLight,
                        border: Border.all(color: AppColors.gold, width: 2),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: kShowDemoContent
                          ? const Text(
                              'AS',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: kGoldDark,
                              ),
                            )
                          : const Icon(
                              Icons.person_outline_rounded,
                              size: 20,
                              color: kGoldDark,
                            ),
                    ),
                  ],
                ),
                if (kShowDemoContent) ...[
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: onGoMessages,
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const _PulseDot(),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  height: 1.45,
                                ),
                                children: [
                                  TextSpan(
                                    text: '3 new batchmates',
                                    style: TextStyle(
                                      color: AppColors.gold,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        ' from APS Patiala joined today — Priya, Rohit & Vikram are here!',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: const Text(
                              '3 new',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.crimsonDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Recently joined
          if (dummyRecentJoins.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SectionLabel('Recently joined'),
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      'See all →',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.crimson,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: dummyRecentJoins.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final p = dummyRecentJoins[i];
                  return GestureDetector(
                    onTap: () => onOpenBatchmate(p),
                    child: SizedBox(
                      width: 58,
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: p.bg,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x1F000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  p.initials,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: p.fg,
                                  ),
                                ),
                              ),
                              if (i < 3)
                                Positioned(
                                  bottom: -2,
                                  right: -2,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: AppColors.gold,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      size: 8,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            p.name.split(' ').first,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: kTxt,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _classAndCityLabel(p),
                            style: const TextStyle(fontSize: 9, color: kTxt3),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Memory card
          if (kShowDemoContent)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.crimsonDark, AppColors.crimson],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.favorite_border_rounded,
                              size: 11,
                              color: Color(0xCCD4A84A),
                            ),
                            SizedBox(width: 5),
                            Text(
                              'MEMORY',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                                color: Color(0xCCD4A84A),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          'You left APS Patiala\n3 years ago today.',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.3,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '34 of your batchmates from 12A are now on APS Brat.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white60,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 14,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Text(
                        '3',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: AppColors.gold.withValues(alpha: 0.2),
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: IgnorePointer(
                        child: CustomPaint(painter: StripesPainter()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),

          // Activity feed
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: SectionLabel('Activity feed'),
          ),
          const SizedBox(height: 12),

          if (!kShowDemoContent)
            const EmptyState(
              icon: Icons.dynamic_feed_rounded,
              title: 'Nothing in your feed yet',
              message:
                  'When batchmates join or connect with you, their activity will show up here.',
            ),

          if (kShowDemoContent) ...[
            _FeedCard(
              person: dummyRecentJoins[0],
              title: 'Priya Khanna joined APS Brat',
              time: '2 hours ago · APS Patiala 12A',
              typeLabel: 'New join',
              body:
                  "Priya is from your 12A batch at APS Patiala 2022. She's now based in Bengaluru working at Wipro.",
              primaryIcon: Icons.person_add_rounded,
              primaryLabel: 'Connect',
              secondaryLabel: 'View profile',
              onPrimary: () => onOpenBatchmate(dummyRecentJoins[0]),
              onSecondary: () => onOpenBatchmate(dummyRecentJoins[0]),
            ),
            const SizedBox(height: 10),
            _FeedCard(
              person: dummyRecentJoins[1],
              title: 'Rohit Singh connected with you',
              time: '5 hours ago · APS Patiala 12A',
              typeLabel: 'Connected',
              typeLabelBg: const Color(0xFFF0FFF4),
              typeLabelColor: const Color(0xFF166534),
              body:
                  'Rohit accepted your connection request. You can now message each other on APS Brat.',
              primaryIcon: Icons.chat_bubble_rounded,
              primaryLabel: 'Say hi',
              secondaryLabel: 'View profile',
              onPrimary: onGoMessages,
              onSecondary: () => onOpenBatchmate(dummyRecentJoins[1]),
            ),
            const SizedBox(height: 10),
            _FeedCard(
              person: dummyRecentJoins[3],
              title: 'Sneha Mehta from 9C Pune joined',
              time: 'Yesterday · APS Pune 9C',
              typeLabel: 'New join',
              body:
                  "Sneha is from your 9C batch at APS Pune 2019. She's currently in Mumbai at IIT Bombay.",
              primaryIcon: Icons.person_add_rounded,
              primaryLabel: 'Connect',
              secondaryLabel: 'View profile',
              onPrimary: () => onOpenBatchmate(dummyRecentJoins[3]),
              onSecondary: () => onOpenBatchmate(dummyRecentJoins[3]),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Feed card ─────────────────────────────────────────────────────────────────

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.person,
    required this.title,
    required this.time,
    required this.typeLabel,
    this.typeLabelBg,
    this.typeLabelColor,
    required this.body,
    required this.primaryIcon,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
  });

  final AppPerson person;
  final String title;
  final String time;
  final String typeLabel;
  final Color? typeLabelBg;
  final Color? typeLabelColor;
  final String body;
  final IconData primaryIcon;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: kBorder, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarCircle(
                  initials: person.initials,
                  bg: person.bg,
                  fg: person.fg,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kTxt,
                        ),
                      ),
                      Text(
                        time,
                        style: const TextStyle(fontSize: 11, color: kTxt3),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: typeLabelBg ?? kCrimsonLight,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: typeLabelColor ?? kCrimsonMed,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: const TextStyle(fontSize: 12, color: kTxt2, height: 1.6),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.crimson,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: onPrimary,
                    icon: Icon(primaryIcon, size: 13),
                    label: Text(
                      primaryLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kCrimsonMed,
                      backgroundColor: kCrimsonLight,
                      side: const BorderSide(color: Color(0x2F7B1414)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: onSecondary,
                    icon: const Icon(Icons.visibility_rounded, size: 13),
                    label: Text(
                      secondaryLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pulse dot ─────────────────────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _anim = Tween(
      begin: 1.0,
      end: 0.4,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.gold,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// "12A Patiala" — class part of the detail plus the city word of the school name.
String _classAndCityLabel(AppPerson p) {
  final classPart = p.detail.split(' · ').first;
  final schoolWords = p.school.split(' ');
  final city = schoolWords.length > 1 ? schoolWords[1] : '';
  return '$classPart $city';
}
