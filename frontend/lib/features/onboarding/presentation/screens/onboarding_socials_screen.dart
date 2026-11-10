import 'dart:async';

import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/auth/data/auth_repository.dart';
import 'package:apsbrat_frontend/features/auth/presentation/providers/auth_provider.dart';
import 'package:apsbrat_frontend/features/career/data/career_models.dart';
import 'package:apsbrat_frontend/features/career/data/career_repository.dart';
import 'package:apsbrat_frontend/features/onboarding/data/models/school_history_registration_model.dart';
import 'package:apsbrat_frontend/features/onboarding/data/models/social_link_registration_model.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/widgets/onboarding_frame.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class OnboardingSocialsScreen extends ConsumerStatefulWidget {
  const OnboardingSocialsScreen({super.key});

  @override
  ConsumerState<OnboardingSocialsScreen> createState() =>
      _OnboardingSocialsScreenState();
}

class _OnboardingSocialsScreenState
    extends ConsumerState<OnboardingSocialsScreen> {
  final _instagramCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _twitterCtrl = TextEditingController();
  final _customLabelCtrl = TextEditingController();
  final _customHandleCtrl = TextEditingController();

  late final OnboardingFlowNotifier _flow;
  Timer? _saveTimer;

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final flow = ref.read(onboardingFlowProvider);
    _instagramCtrl.text = flow.instagram;
    _linkedinCtrl.text = flow.linkedin;
    _whatsappCtrl.text = flow.whatsapp;
    _twitterCtrl.text = flow.twitter;
    _customLabelCtrl.text = flow.customLabel;
    _customHandleCtrl.text = flow.customHandle;
    _flow = ref.read(onboardingFlowProvider.notifier);
    for (final c in [
      _instagramCtrl,
      _linkedinCtrl,
      _whatsappCtrl,
      _twitterCtrl,
      _customLabelCtrl,
      _customHandleCtrl,
    ]) {
      c.addListener(_scheduleSave);
    }
  }

  /// Saves what has been typed so far, shortly after the user pauses.
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _syncDraft);
  }

  /// [deferred] is for dispose: Riverpod does not allow changing state while a
  /// screen is being torn down, so the values are read now and saved a moment
  /// later, after the frame.
  void _syncDraft({bool deferred = false}) {
    final instagram = _instagramCtrl.text.trim();
    final linkedin = _linkedinCtrl.text.trim();
    final whatsapp = _whatsappCtrl.text.trim();
    final twitter = _twitterCtrl.text.trim();
    final customLabel = _customLabelCtrl.text.trim();
    final customHandle = _customHandleCtrl.text.trim();
    final flow = _flow;

    void save() {
      if (!flow.mounted) return;
      flow.saveSocials(
        instagram: instagram,
        linkedin: linkedin,
        whatsapp: whatsapp,
        twitter: twitter,
        customLabel: customLabel,
        customHandle: customHandle,
      );
    }

    deferred ? Future(save) : save();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _syncDraft(deferred: true);
    _instagramCtrl.dispose();
    _linkedinCtrl.dispose();
    _whatsappCtrl.dispose();
    _twitterCtrl.dispose();
    _customLabelCtrl.dispose();
    _customHandleCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    ref
        .read(onboardingFlowProvider.notifier)
        .saveSocials(
          instagram: _instagramCtrl.text.trim(),
          linkedin: _linkedinCtrl.text.trim(),
          whatsapp: _whatsappCtrl.text.trim(),
          twitter: _twitterCtrl.text.trim(),
          customLabel: _customLabelCtrl.text.trim(),
          customHandle: _customHandleCtrl.text.trim(),
        );

    final flow = ref.read(onboardingFlowProvider);
    // The account exists from the moment the email (or Google) was verified —
    // this is filling in the profile that account still needs, not creating
    // a new one.
    // Read it from the device, not from memory: after the app is closed or
    // reloaded mid-registration the in-memory login is empty, but the saved
    // session (tokens + user id) is still valid.
    final userId =
        ref.read(authControllerProvider).user?.id ??
        await ref.read(authRepositoryProvider).currentUserId();
    if (userId == null || userId.isEmpty) {
      setState(() => _error = 'Your session expired — please log in again.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      // Only finished cards from "After school" are saved; Skip leaves none.
      final career = flow.career.where((c) => c.problem == null).toList();

      await profileRepo.updateMe(
        fullName: flow.fullName,
        username: flow.username,
        dob: apiDob(flow.dob),
        city: flow.city.isEmpty ? null : flow.city,
        profession: _profession(flow, career),
        gender: flow.gender.isEmpty ? null : flow.gender,
        currentStatus: flow.isStudent ? 'STUDENT' : 'ALUMNI',
      );

      final schoolItems = flow.schoolHistory
          .where((item) => item.schoolId.isNotEmpty)
          .map(SchoolHistoryRegistrationModel.fromDraft)
          .map((item) => item.toJson())
          .toList();
      if (schoolItems.isNotEmpty) {
        await profileRepo.replaceSchoolHistory(userId, schoolItems);
      }

      for (final social in SocialLinkRegistrationModel.fromFlow(flow)) {
        await profileRepo.saveSocialLink(
          userId: userId,
          platform: social.platform,
          handle: social.handle,
          label: social.label,
        );
      }

      // Best effort: a job that fails to save must not block finishing
      // registration. It can be added again from the profile's Journey tab.
      var careerSaved = true;
      final careerRepo = ref.read(careerRepositoryProvider);
      for (final draft in career) {
        try {
          await careerRepo.save(draft);
        } catch (_) {
          careerSaved = false;
        }
      }
      ref.invalidate(myCareerProvider);

      await ref.read(authRepositoryProvider).markOnboardingDone();
      ref.read(onboardingFlowProvider.notifier).reset();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            careerSaved
                ? 'Profile completed'
                : "Profile completed. Your work details didn't save, add them "
                      'from the Journey tab.',
          ),
        ),
      );
      context.go('/home');
    } on DioException catch (e) {
      String message = 'Could not save your profile';
      final payload = e.response?.data;
      if (payload is Map<String, dynamic>) {
        final err = payload['error'];
        if (err is String && err.isNotEmpty) message = err;
      }
      setState(() => _error = message);
    } catch (_) {
      setState(() => _error = 'Could not save your profile');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// The one-line "what I do" other screens still read (people cards etc.):
  /// the current job, else the current college, else the latest job.
  String? _profession(OnboardingFlowState flow, List<CareerDraft> career) {
    CareerDraft? pick(bool Function(CareerDraft) test) =>
        career.where(test).firstOrNull;
    final c =
        pick((c) => c.isWork && c.current) ??
        pick((c) => !c.isWork && c.current) ??
        pick((c) => c.isWork);
    if (c != null) {
      return c.isWork
          ? '${c.title.trim()} at ${c.organizationName.trim()}'
          : '${c.title.trim()} student at ${c.organizationName.trim()}';
    }
    final text = flow.profession.trim();
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = ref.watch(onboardingFlowProvider).isStudent;
    return OnboardingFrame(
      step: 4,
      showAfterSchool: !isStudent,
      title: 'Connect your socials',
      subtitle:
          'All fields are optional — add whatever you\'re comfortable sharing with your batchmates.',
      child: _FormBody(
        instagramCtrl: _instagramCtrl,
        linkedinCtrl: _linkedinCtrl,
        whatsappCtrl: _whatsappCtrl,
        twitterCtrl: _twitterCtrl,
        customLabelCtrl: _customLabelCtrl,
        customHandleCtrl: _customHandleCtrl,
      ),
      footer: _Footer(
        submitting: _submitting,
        error: _error,
        onFinish: _finish,
      ),
    );
  }
}

// ── Form body ─────────────────────────────────────────────────────────────────

class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.instagramCtrl,
    required this.linkedinCtrl,
    required this.whatsappCtrl,
    required this.twitterCtrl,
    required this.customLabelCtrl,
    required this.customHandleCtrl,
  });

  final TextEditingController instagramCtrl;
  final TextEditingController linkedinCtrl;
  final TextEditingController whatsappCtrl;
  final TextEditingController twitterCtrl;
  final TextEditingController customLabelCtrl;
  final TextEditingController customHandleCtrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          // ── Main platforms card ──
          _SocialsCard(
            children: [
              _SocialField(
                badge: 'IG',
                badgeColor: const Color(0xFFE1306C),
                platform: 'Instagram',
                hint: '@yourhandle',
                controller: instagramCtrl,
              ),
              const _CardDivider(),
              _SocialField(
                badge: 'in',
                badgeColor: const Color(0xFF0A66C2),
                platform: 'LinkedIn',
                hint: 'linkedin.com/in/yourname',
                controller: linkedinCtrl,
              ),
              const _CardDivider(),
              _SocialField(
                badge: 'WA',
                badgeColor: const Color(0xFF25D366),
                platform: 'WhatsApp',
                hint: '+91 your number',
                controller: whatsappCtrl,
              ),
              const _CardDivider(),
              _SocialField(
                badge: 'X',
                badgeColor: Colors.black87,
                platform: 'Twitter / X',
                hint: '@yourx',
                controller: twitterCtrl,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Custom link card ──
          _SocialsCard(
            children: [
              _SocialField(
                badge: '↗',
                badgeColor: AppColors.crimson,
                platform: 'Custom link label',
                hint: 'Portfolio · YouTube · GitHub',
                controller: customLabelCtrl,
              ),
              const _CardDivider(),
              _SocialField(
                badge: '🔗',
                badgeColor: AppColors.crimsonMuted,
                platform: 'Link or handle',
                hint: 'url or @username',
                controller: customHandleCtrl,
                isEmoji: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Socials card ──────────────────────────────────────────────────────────────

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

// ── Social field row ──────────────────────────────────────────────────────────

class _SocialField extends StatelessWidget {
  const _SocialField({
    required this.badge,
    required this.badgeColor,
    required this.platform,
    required this.hint,
    required this.controller,
    this.isEmoji = false,
  });

  final String badge;
  final Color badgeColor;
  final String platform;
  final String hint;
  final TextEditingController controller;
  final bool isEmoji;

  @override
  Widget build(BuildContext context) {
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
                  color: isEmoji ? Colors.transparent : badgeColor,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: isEmoji ? badgeColor : Colors.white,
                    fontSize: isEmoji ? 14 : 9,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                platform.toUpperCase(),
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
          TextField(
            controller: controller,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFFBBBBBB),
                fontSize: 13,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.crimson,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppColors.crimson.withValues(alpha: 0.08),
      indent: 14,
      endIndent: 14,
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({required this.submitting, required this.onFinish, this.error});

  final bool submitting;
  final VoidCallback onFinish;
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
              disabledBackgroundColor: AppColors.crimsonDark.withValues(
                alpha: 0.5,
              ),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size(double.infinity, 0),
            ),
            onPressed: submitting ? null : onFinish,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (submitting) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const Text(
                  'Complete registration',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.check_circle_outline_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The form shows the birthday as 10/01/2006 (day/month/year); the API wants
/// 2006-01-10. Anything unreadable is left out rather than failing signup.
String? apiDob(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  try {
    return DateFormat(
      'yyyy-MM-dd',
    ).format(DateFormat('dd/MM/yyyy').parseStrict(t));
  } on FormatException {
    // Already in API form (e.g. an older saved draft)?
    final iso = DateTime.tryParse(t);
    return iso == null ? null : DateFormat('yyyy-MM-dd').format(iso);
  }
}
