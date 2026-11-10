import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/widgets/onboarding_frame.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/widgets/school_history_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OnboardingSchoolsScreen extends ConsumerStatefulWidget {
  const OnboardingSchoolsScreen({super.key});

  @override
  ConsumerState<OnboardingSchoolsScreen> createState() =>
      _OnboardingSchoolsScreenState();
}

class _OnboardingSchoolsScreenState
    extends ConsumerState<OnboardingSchoolsScreen> {
  String? _error;

  void _next() {
    final problem = schoolDraftsProblem(
      ref.read(onboardingFlowProvider).schoolHistory,
    );
    setState(() => _error = problem);
    if (problem != null) return;
    final notifier = ref.read(onboardingFlowProvider.notifier);
    if (notifier.isStudent) {
      notifier.markStep(4);
      context.go('/onboarding/schools/socials');
    } else {
      notifier.markStep(3);
      context.go('/onboarding/schools/after-school');
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(onboardingFlowProvider);
    final notifier = ref.read(onboardingFlowProvider.notifier);

    return OnboardingFrame(
      step: 2,
      showAfterSchool: !flow.isStudent,
      title: 'Which APS schools did you call home?',
      subtitle:
          'Add every school you attended — even one year counts. Your batchmates are waiting.',
      footer: _Footer(
        onNext: _next,
        error: _error,
        nextLabel: flow.isStudent
            ? 'Next — connect my socials'
            : 'Next — life after school',
      ),
      child: SchoolHistoryEditor(
        drafts: flow.schoolHistory,
        onAdd: notifier.addSchoolDraft,
        onRemove: notifier.removeSchoolDraft,
        onUpdate: notifier.updateSchoolDraft,
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({required this.onNext, required this.nextLabel, this.error});

  final VoidCallback onNext;
  final String nextLabel;
  final String? error;

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
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.crimsonDark,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size(double.infinity, 0),
            ),
            onPressed: onNext,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  nextLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
