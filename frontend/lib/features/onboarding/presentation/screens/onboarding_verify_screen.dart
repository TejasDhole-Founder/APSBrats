import 'dart:async';

import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/widgets/onboarding_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _VerifyStep { phone, email, done }

class OnboardingVerifyScreen extends ConsumerStatefulWidget {
  const OnboardingVerifyScreen({super.key});

  @override
  ConsumerState<OnboardingVerifyScreen> createState() =>
      _OnboardingVerifyScreenState();
}

class _OnboardingVerifyScreenState
    extends ConsumerState<OnboardingVerifyScreen> {
  _VerifyStep _step = _VerifyStep.phone;
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  int _countdown = 60;
  Timer? _timer;

  static const _crimson = AppColors.crimson;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    _countdown = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  void _resend() {
    if (_countdown > 0) return;
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
    setState(_startCountdown);
  }

  String get _otp => _controllers.map((c) => c.text).join();

  String get _phoneLabel {
    final p = ref.read(onboardingFlowProvider).phone;
    return p.isEmpty ? '+91 98765 43210' : '+91 $p';
  }

  String get _emailLabel => ref.read(onboardingFlowProvider).email.trim();

  /// Email is optional — it is only verified when the user gave one.
  bool get _hasEmail => _emailLabel.isNotEmpty;

  String get _timerLabel {
    final m = _countdown ~/ 60;
    final s = _countdown % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _verify() {
    if (_otp.length < 6) return;
    for (final c in _controllers) {
      c.clear();
    }
    if (_step == _VerifyStep.phone && _hasEmail) {
      _startCountdown();
      setState(() => _step = _VerifyStep.email);
      return;
    }
    _timer?.cancel();
    setState(() => _step = _VerifyStep.done);
  }

  @override
  Widget build(BuildContext context) {
    final phone = _phoneLabel;
    final email = _emailLabel;
    final hasEmail = _hasEmail;

    final title = switch (_step) {
      _VerifyStep.phone => 'Verify your phone number.',
      _VerifyStep.email => 'Verify your email address.',
      _VerifyStep.done =>
        hasEmail ? 'Account fully verified.' : 'Phone number verified.',
    };
    final subtitle = switch (_step) {
      _VerifyStep.phone =>
        hasEmail
            ? 'Step 1 of 2 — OTP sent to your number.'
            : 'OTP sent to your number.',
      _VerifyStep.email => 'Step 2 of 2 — OTP sent to your email.',
      _VerifyStep.done =>
        hasEmail
            ? 'Both phone and email confirmed.'
            : 'Your account is confirmed.',
    };

    return OnboardingFrame(
      step: 2,
      title: title,
      subtitle: subtitle,
      footer: _buildFooter(context),
      child: _buildBody(phone, email),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody(String phone, String email) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
      child: switch (_step) {
        _VerifyStep.phone => _otpBody(
          icon: Icons.smartphone_outlined,
          titleParts: ('Enter the OTP sent\nto your ', 'phone'),
          target: phone,
          isPhone: true,
        ),
        _VerifyStep.email => _otpBody(
          icon: Icons.email_outlined,
          titleParts: ('Enter the OTP sent\nto your ', 'email'),
          target: email,
          isPhone: false,
        ),
        _VerifyStep.done => _doneBody(phone, email),
      },
    );
  }

  Widget _otpBody({
    required IconData icon,
    required (String, String) titleParts,
    required String target,
    required bool isPhone,
  }) {
    return Column(
      children: [
        // Icon circle
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: _crimson.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 28, color: _crimson.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 20),

        // Title
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.3,
              color: Color(0xFF1A0A0A),
            ),
            children: [
              TextSpan(text: titleParts.$1),
              TextSpan(
                text: titleParts.$2,
                style: const TextStyle(color: _crimson),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Sent-to label
        const Text(
          'We sent a 6-digit code to',
          style: TextStyle(fontSize: 13, color: Color(0xFF9A9280)),
        ),
        const SizedBox(height: 4),
        Text(
          target,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _crimson,
          ),
        ),
        const SizedBox(height: 22),

        // OTP boxes
        _OtpRow(controllers: _controllers, focusNodes: _focusNodes),
        const SizedBox(height: 18),

        // Resend row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't get it? ",
              style: TextStyle(fontSize: 12, color: Color(0xFF9A9280)),
            ),
            GestureDetector(
              onTap: _resend,
              child: Text(
                'Resend OTP',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _countdown > 0 ? const Color(0xFFCCC4B8) : _crimson,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Timer pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2DDD5)),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.access_time, size: 14, color: Color(0xFF9A9280)),
              const SizedBox(width: 5),
              Text(
                _timerLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9A9280),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // On the email step, show that the phone is already done.
        if (!isPhone) ...[
          _VerifyCard(
            icon: Icons.smartphone_outlined,
            title: 'Phone number',
            value: _phoneLabel,
            verified: true,
          ),
          const SizedBox(height: 12),
        ],

        // Wrong contact link
        GestureDetector(
          onTap: () => context.go('/onboarding'),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Color(0xFF9A9280)),
              children: [
                TextSpan(text: isPhone ? 'Wrong number? ' : 'Wrong email? '),
                const TextSpan(
                  text: 'Go back and change it',
                  style: TextStyle(
                    color: _crimson,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _doneBody(String phone, String email) {
    return Column(
      children: [
        // Shield icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.verified_user_outlined,
            size: 28,
            color: AppColors.gold,
          ),
        ),
        const SizedBox(height: 20),

        // Title
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
            children: [
              TextSpan(
                text: _hasEmail ? 'Both verified.\n' : 'Phone verified.\n',
                style: const TextStyle(color: Color(0xFF1A0A0A)),
              ),
              const TextSpan(
                text: "You're all set.",
                style: TextStyle(color: _crimson),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _hasEmail
              ? 'Your phone and email are confirmed.\nYour account is now secure.'
              : 'Your phone number is confirmed.\nYour account is now secure.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF9A9280),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),

        _VerifyCard(
          icon: Icons.smartphone_outlined,
          title: 'Phone number',
          value: phone,
          verified: true,
        ),
        if (_hasEmail) ...[
          const SizedBox(height: 8),
          _VerifyCard(
            icon: Icons.email_outlined,
            title: 'Email address',
            value: email,
            verified: true,
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter(BuildContext context) {
    if (_step == _VerifyStep.done) {
      return _ActionButton(
        label: 'Next — add my schools',
        icon: Icons.arrow_forward,
        onTap: () => context.go('/onboarding/verify/schools'),
      );
    }
    return _ActionButton(
      label: _step == _VerifyStep.phone
          ? 'Verify phone number'
          : 'Verify email & continue',
      icon: Icons.shield_outlined,
      onTap: _verify,
    );
  }
}

// ── OTP Row ───────────────────────────────────────────────────────────────────

class _OtpRow extends StatelessWidget {
  const _OtpRow({required this.controllers, required this.focusNodes});

  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;

  static const _crimson = AppColors.crimson;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) {
        return SizedBox(
          width: 42,
          height: 50,
          child: TextField(
            controller: controllers[i],
            focusNode: focusNodes[i],
            maxLength: 1,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _crimson,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: _crimson.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: _crimson.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _crimson, width: 1.8),
              ),
            ),
            onChanged: (v) {
              if (v.isNotEmpty && i < 5) {
                focusNodes[i + 1].requestFocus();
              } else if (v.isEmpty && i > 0) {
                focusNodes[i - 1].requestFocus();
              }
            },
          ),
        );
      }),
    );
  }
}

// ── Verify Card ───────────────────────────────────────────────────────────────

class _VerifyCard extends StatelessWidget {
  const _VerifyCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.verified,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: verified ? AppColors.gold.withValues(alpha: 0.08) : Colors.white,
        borderRadius: AppRadius.md,
        border: Border.all(
          color: verified
              ? AppColors.gold.withValues(alpha: 0.4)
              : const Color(0xFFE2DDD5),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: verified
                  ? AppColors.gold.withValues(alpha: 0.15)
                  : const Color(0xFFF5F0EA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: verified ? AppColors.gold : const Color(0xFF9A9280),
            ),
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
                    color: Color(0xFF1A0A0A),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9A9280),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: verified
                  ? AppColors.crimson.withValues(alpha: 0.08)
                  : const Color(0xFFF0EDE8),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (verified) ...[
                  const Icon(Icons.check, size: 11, color: AppColors.crimson),
                  const SizedBox(width: 3),
                ],
                Text(
                  verified ? 'Verified' : 'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: verified
                        ? AppColors.crimson
                        : const Color(0xFF9A9280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action Button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A0808),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.gold),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
