import 'package:apsbrat_frontend/core/theme/app_inputs.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/career/data/career_models.dart';
import 'package:apsbrat_frontend/features/career/presentation/career_form.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/widgets/onboarding_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Alumni only, optional, LinkedIn-style: every company they've worked at
/// and every college they've been to, as many of each as they like.
/// Cards left blank are ignored.
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
              title: 'Work',
              kind: kWork,
              career: career,
              addLabel: 'Add another company',
              onChangedError: () => setState(() => _error = null),
            ),
            const SizedBox(height: 18),
            _Section(
              title: 'College',
              kind: kEducation,
              career: career,
              addLabel: 'Add another college',
              onChangedError: () => setState(() => _error = null),
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
    required this.kind,
    required this.career,
    required this.addLabel,
    required this.onChangedError,
  });

  final String title;
  final String kind;
  final List<CareerDraft> career;
  final String addLabel;
  final VoidCallback onChangedError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(onboardingFlowProvider.notifier);
    final indexes = [
      for (var i = 0; i < career.length; i++)
        if (career[i].kind == kind) i,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: appFieldLabelStyle),
        const SizedBox(height: 8),
        for (final i in indexes)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.crimson.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: CareerForm(
                      // Removing a card shifts the ones after it; a fresh key
                      // per position and length keeps their text in sync.
                      key: ValueKey('$i-${career.length}'),
                      initial: career[i],
                      onChanged: (d) {
                        onChangedError();
                        notifier.updateCareer(i, d);
                      },
                    ),
                  ),
                ),
                IconButton(
                  tooltip: kind == kWork ? 'Remove company' : 'Remove college',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => notifier.removeCareer(i),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: () => notifier.addCareer(kind),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(
            indexes.isEmpty ? addLabel.replaceFirst('another', 'a') : addLabel,
          ),
          style: TextButton.styleFrom(foregroundColor: AppColors.crimson),
        ),
      ],
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
                    foregroundColor: AppColors.crimsonDark,
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
                    'Continue',
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
