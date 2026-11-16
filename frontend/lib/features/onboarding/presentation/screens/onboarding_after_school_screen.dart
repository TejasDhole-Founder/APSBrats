import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/career/data/career_models.dart';
import 'package:apsbrat_frontend/features/career/presentation/career_form.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/widgets/onboarding_frame.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:apsbrat_frontend/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Alumni only, optional: every company they've worked at and every college
/// they've been to. Cards left blank are ignored.
class OnboardingAfterSchoolScreen extends ConsumerStatefulWidget {
  const OnboardingAfterSchoolScreen({super.key});

  @override
  ConsumerState<OnboardingAfterSchoolScreen> createState() =>
      _OnboardingAfterSchoolScreenState();
}

class _OnboardingAfterSchoolScreenState
    extends ConsumerState<OnboardingAfterSchoolScreen> {
  String? _error;

  void _goOn() {
    ref.read(onboardingFlowProvider.notifier).markStep(4);
    context.go('/onboarding/schools/after-school/socials');
  }

  void _continue() {
    final flow = ref.read(onboardingFlowProvider);
    for (final c in flow.career.where((c) => !c.isBlank)) {
      final problem = c.problem;
      if (problem != null) {
        setState(() => _error = problem);
        return;
      }
    }
    setState(() => _error = null);
    _goOn();
  }

  void _skip() {
    ref.read(onboardingFlowProvider.notifier).skipAfterSchool();
    _goOn();
  }

  @override
  Widget build(BuildContext context) {
    final career = ref.watch(onboardingFlowProvider).career;

    return OnboardingFrame(
      step: 3,
      showAfterSchool: true,
      title: 'Life after school',
      subtitle:
          'Add the companies and colleges you\'ve been to. Juniors look for '
          'this when they need guidance. You can skip it.',
      footer: _Footer(error: _error, onSkip: _skip, onContinue: _continue),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 0, 17, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Section(
              title: 'Work Experience',
              subtitle:
                  'Add your work experience, internships or current role.',
              icon: HugeIcons.strokeRoundedBriefcase01,
              kind: kWork,
              career: career,
              addLabel: 'Add another company',
              cardLabel: 'Work Experience',
              onChangedError: () => setState(() => _error = null),
            ),
            const SizedBox(height: 18),
            _Section(
              title: 'Education',
              subtitle: 'Add your college and degree details.',
              icon: HugeIcons.strokeRoundedMortarboard01,
              kind: kEducation,
              career: career,
              addLabel: 'Add another college',
              cardLabel: 'Education',
              onChangedError: () => setState(() => _error = null),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFBEBD8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedInformationCircle,
                    size: 18,
                    color: AppColors.crimson,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You can skip either section and update your profile later.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.crimsonDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// All cards of one kind. Cards are stored in one list (jobs and colleges
/// mixed), so each card remembers its index in that list.
class _Section extends ConsumerWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.kind,
    required this.career,
    required this.addLabel,
    required this.cardLabel,
    required this.onChangedError,
  });

  final String title;
  final String subtitle;
  final AppIconData icon;
  final String kind;
  final List<CareerDraft> career;
  final String addLabel;
  final String cardLabel;
  final VoidCallback onChangedError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(onboardingFlowProvider.notifier);
    final indexes = [
      for (var i = 0; i < career.length; i++)
        if (career[i].kind == kind) i,
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6F1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.crimson.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.crimsonDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: HugeIcon(icon: icon, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.crimson,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8A7A6E),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBEBD8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Optional',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.crimson,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var n = 0; n < indexes.length; n++)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.crimson.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                    decoration: BoxDecoration(
                      color: AppColors.crimson.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$cardLabel ${n + 1}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.crimson,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => notifier.removeCareer(indexes[n]),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.crimson.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
                            child: const HugeIcon(
                              icon: HugeIcons.strokeRoundedDelete02,
                              size: 18,
                              color: AppColors.crimson,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  CareerForm(
                    // Removing a card shifts the ones after it; a fresh key
                    // per position and length keeps their text in sync.
                    key: ValueKey('${indexes[n]}-${career.length}'),
                    initial: career[indexes[n]],
                    onChanged: (d) {
                      onChangedError();
                      notifier.updateCareer(indexes[n], d);
                    },
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => notifier.addCareer(kind),
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedAddCircle,
                size: 18,
                color: AppColors.crimson,
              ),
              label: Text(
                indexes.isEmpty
                    ? addLabel.replaceFirst('another', 'a')
                    : addLabel,
                style: const TextStyle(
                  color: AppColors.crimson,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: AppColors.crimson.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.error,
    required this.onSkip,
    required this.onContinue,
  });

  final String? error;
  final VoidCallback onSkip;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(17, 4, 17, 20),
      child: Column(
        children: [
          if (error != null) ...[
            Text(
              error!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.crimson,
                    side: const BorderSide(
                      color: AppColors.crimson,
                      width: 1.5,
                    ),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: onSkip,
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.crimsonDark,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: onContinue,
                  child: const Text(
                    'Continue  →',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
