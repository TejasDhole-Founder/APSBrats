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
    if (problem == null) {
      context.go('/onboarding/schools/socials');
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(onboardingFlowProvider);
    final notifier = ref.read(onboardingFlowProvider.notifier);

    return OnboardingFrame(
      step: 3,
      title: 'Which APS schools did you call home?',
      subtitle:
          'Add every school you attended — even one year counts. Your batchmates are waiting.',
      footer: _Footer(onNext: _next, error: _error),
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
  const _Footer({required this.onNext, this.error});

  final VoidCallback onNext;
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
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Next — connect my socials',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
