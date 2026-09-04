import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/onboarding/data/services/onboarding_registration_service.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/widgets/onboarding_frame.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  }

  @override
  void dispose() {
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

    setState(() {
      _submitting = true;
      _error = null;
    });

    final dio = ref.read(dioProvider);
    try {
      await const OnboardingRegistrationService().registerSequential(
        dio: dio,
        flow: flow,
      );

      ref.read(onboardingFlowProvider.notifier).reset();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration completed successfully')),
      );
      context.go('/home');
    } on DioException catch (e) {
      String message = 'Registration failed';
      final payload = e.response?.data;
      if (payload is Map<String, dynamic>) {
        final err = payload['error'];
        if (err is String && err.isNotEmpty) message = err;
      }
      setState(() => _error = message);
    } catch (_) {
      setState(() => _error = 'Registration failed');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingFrame(
      step: 4,
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
