import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/feed/data/dummy_data.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:flutter/material.dart';

class BatchmateOverlay extends StatefulWidget {
  const BatchmateOverlay({
    super.key,
    required this.person,
    required this.onBack,
    required this.onMessage,
  });

  final AppPerson person;
  final VoidCallback onBack;
  final ValueChanged<AppPerson> onMessage;

  @override
  State<BatchmateOverlay> createState() => _BatchmateOverlayState();
}

class _BatchmateOverlayState extends State<BatchmateOverlay> {
  bool _connected = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.person;
    return Positioned.fill(
      child: Material(
        color: Colors.white,
        child: Column(
          children: [
            // Header
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: widget.onBack,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              FeedIconBtn(icon: Icons.more_vert_rounded),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: p.bg,
                              border: Border.all(
                                color: AppColors.gold,
                                width: 3,
                              ),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              p.initials,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: p.fg,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            p.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@${p.name.toLowerCase().replaceAll(' ', '.')} · ${p.city}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 7,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.2),
                                  border: Border.all(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  p.detail,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  p.tags.isNotEmpty ? p.tags.last : 'Alumni',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
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

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.crimson,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () => widget.onMessage(p),
                            icon: const Icon(
                              Icons.chat_bubble_rounded,
                              size: 14,
                              color: AppColors.gold,
                            ),
                            label: const Text(
                              'Message',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _connected = !_connected),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: _connected
                                    ? const Color(0xFFD1FAE5)
                                    : kCrimsonLight,
                                border: Border.all(
                                  color: _connected
                                      ? const Color(
                                          0xFF065F46,
                                        ).withValues(alpha: 0.3)
                                      : const Color(0x2F7B1414),
                                ),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _connected
                                        ? Icons.check_rounded
                                        : Icons.person_add_rounded,
                                    size: 14,
                                    color: _connected
                                        ? const Color(0xFF065F46)
                                        : kCrimsonMed,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _connected ? 'Connected' : 'Connect',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _connected
                                          ? const Color(0xFF065F46)
                                          : kCrimsonMed,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // About card
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: kBorder, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionLabel('About'),
                          const SizedBox(height: 10),
                          _InfoRow('Current city', p.city),
                          _InfoRow('Occupation', p.job),
                          _InfoRow(
                            'Batch year',
                            p.detail.contains('Class')
                                ? p.detail.split('Class ').last
                                : p.detail,
                          ),
                          _InfoRow('School', p.school),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    const SectionLabel('Schools'),
                    const SizedBox(height: 10),
                    Container(
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
                            child: const Text(
                              '1',
                              style: TextStyle(
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
                                  p.school,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: kTxt,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  p.detail,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: kTxt3,
                                  ),
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
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: kTxt3),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kTxt,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
