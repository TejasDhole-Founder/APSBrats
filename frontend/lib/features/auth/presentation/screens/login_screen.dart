import 'dart:async';
import 'package:hugeicons/hugeicons.dart';

import 'package:apsbrat_frontend/features/auth/presentation/providers/auth_provider.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';
import 'package:apsbrat_frontend/features/auth/presentation/widgets/welcome_brand.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// The one entry point for both new and returning users: email + OTP, or
/// Google. Verifying logs you in if the email already has an account,
/// otherwise creates a bare one and the router sends you to onboarding.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.signUp = false});

  /// Opened from "Get Started" rather than "Log In". Same flow underneath --
  /// this only changes the wording.
  final bool signUp;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _resendSeconds = 30;

  late bool _signUp = widget.signUp;

  final _emailCtrl = TextEditingController();
  final _otp = List.generate(6, (_) => TextEditingController());
  final _otpFocus = List.generate(6, (_) => FocusNode());
  Timer? _timer;
  int _countdown = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    for (final c in _otp) {
      c.dispose();
    }
    for (final f in _otpFocus) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _otp.map((c) => c.text).join();

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = _resendSeconds);
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

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    // Catch an obvious typo here, so it isn't reported as a network failure.
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address')),
      );
      return;
    }
    await ref.read(authControllerProvider.notifier).requestOtp(email);
    if (mounted && ref.read(authControllerProvider).otpSent) {
      for (final c in _otp) {
        c.clear();
      }
      _startCountdown();
      _otpFocus.first.requestFocus();
    }
  }

  Future<void> _verify() async {
    if (_code.length < 6) return;
    final ok = await ref
        .read(authControllerProvider.notifier)
        .verifyOtp(_emailCtrl.text.trim(), _code);
    if (ok && mounted) _continue();
  }

  Future<void> _google() async {
    final ok = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle();
    if (ok && mounted) _continue();
  }

  Future<void> _continue() async {
    final user = ref.read(authControllerProvider).user;
    if (user != null && user.needsOnboarding) {
      // Pick up where an unfinished registration was left off.
      final route = await resumeOnboardingRoute(
        ref.read(onboardingFlowProvider.notifier),
      );
      if (mounted) context.go(route);
    } else {
      context.go('/home');
    }
  }

  void _editEmail() {
    _timer?.cancel();
    ref.read(authControllerProvider.notifier).editEmail();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    return PopScope(
      // On the OTP step the system back button returns to the email step;
      // on the email step it pops back to the welcome screen as usual.
      canPop: !state.otpSent,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _editEmail();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: Welcome.bg,
          resizeToAvoidBottomInset: false,
          body: WelcomeBackground(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          0,
                          24,
                          MediaQuery.viewInsetsOf(context).bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                onPressed: state.otpSent
                                    ? _editEmail
                                    : () => context.go('/'),
                                icon: const HugeIcon(
                                  icon: HugeIcons.strokeRoundedArrowLeft01,
                                  color: Welcome.gold,
                                  size: 26,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Image.asset(
                              'assets/images/aps_crest.png',
                              width: 104,
                              height: 104,
                              fit: BoxFit.contain,
                              semanticLabel: 'APS Brat logo',
                            ),
                            const SizedBox(height: 14),
                            const BrandTitle(),
                            const SizedBox(height: 22),
                            const DiamondDivider(),
                            const SizedBox(height: 40),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                final incoming = child.key == ValueKey(_signUp);
                                final fromRight = _signUp;
                                final begin = incoming
                                    ? Offset(fromRight ? 1 : -1, 0)
                                    : Offset(fromRight ? -1 : 1, 0);
                                return SlideTransition(
                                  position: Tween<Offset>(
                                    begin: begin,
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                );
                              },
                              child: Column(
                                key: ValueKey(_signUp),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      style: Welcome.headline,
                                      children: [
                                        TextSpan(
                                          text: _signUp
                                              ? 'Join us, '
                                              : 'Welcome back, ',
                                        ),
                                        const TextSpan(
                                          text: 'brat',
                                          style: TextStyle(
                                            color: Welcome.goldLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    state.otpSent
                                        ? 'Enter the 6-digit code we sent you'
                                        : _signUp
                                        ? 'Create your account with your email'
                                        : 'Enter your email to log in',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.mulish(
                                      fontSize: 14,
                                      height: 1.6,
                                      color: Welcome.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            if (state.otpSent)
                              ..._otpStep(state, controller)
                            else
                              ..._emailStep(state),
                            if (state.error != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                state.error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFFFB4A8),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            const SizedBox(height: 28),
                            ShimmerGoldButton(
                              label: state.otpSent
                                  ? 'Verify & Continue'
                                  : 'Send Code',
                              loading: state.loading,
                              onTap: state.otpSent ? _verify : _sendCode,
                            ),
                            if (!state.otpSent) ...[
                              const SizedBox(height: 22),
                              const _OrDivider(),
                              const SizedBox(height: 18),
                              _GoogleButton(
                                loading: state.loading,
                                onTap: _google,
                              ),
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: () =>
                                    setState(() => _signUp = !_signUp),
                                child: Text(
                                  _signUp
                                      ? 'Already an APS brat?  Log in'
                                      : 'New here?  Create an account',
                                  style: const TextStyle(
                                    color: Welcome.goldLight,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            if (kDebugMode) ...[
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: state.loading
                                    ? null
                                    : () async {
                                        final ok = await controller
                                            .devSkipLogin();
                                        if (ok && context.mounted) {
                                          context.go('/home');
                                        }
                                      },
                                child: Text(
                                  'Skip login (dev)',
                                  style: TextStyle(
                                    color: Welcome.gold.withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            const SizedBox(height: 24),
                            const WelcomeFooter(withDivider: true),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Email step ────────────────────────────────────────────────────────────

  List<Widget> _emailStep(AuthState state) {
    return [
      Container(
        decoration: BoxDecoration(
          color: Welcome.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Welcome.goldDeep, width: 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedMail01,
              size: 20,
              color: Welcome.gold,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                onSubmitted: (_) => _sendCode(),
                style: const TextStyle(fontSize: 18, color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Email address',
                  hintStyle: TextStyle(
                    color: Welcome.muted,
                    fontSize: 16,
                    letterSpacing: 0,
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // ── OTP step ──────────────────────────────────────────────────────────────

  List<Widget> _otpStep(AuthState state, AuthController controller) {
    final email = _emailCtrl.text.trim();
    final masked = _maskEmail(email);

    return [
      Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Welcome.card.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: Welcome.gold.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedMail01,
                size: 18,
                color: Welcome.gold,
              ),
              const SizedBox(width: 10),
              Text(
                masked,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(width: 22),
              GestureDetector(
                onTap: _editEmail,
                child: const Text(
                  'Edit',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Welcome.gold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 22),
      Row(
        children: [
          for (int i = 0; i < 6; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: _OtpBox(
                controller: _otp[i],
                focusNode: _otpFocus[i],
                onChanged: (v) => _onDigit(i, v),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 22),
      const Text(
        "Didn't receive the code?",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: Welcome.muted),
      ),
      const SizedBox(height: 4),
      GestureDetector(
        onTap: _countdown == 0 && !state.loading ? _sendCode : null,
        child: Text(
          _countdown > 0
              ? 'Resend in ${_timerLabel(_countdown)}'
              : 'Resend code',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Welcome.gold,
          ),
        ),
      ),
    ];
  }

  void _onDigit(int i, String value) {
    if (value.isNotEmpty && i < 5) {
      _otpFocus[i + 1].requestFocus();
    } else if (value.isEmpty && i > 0) {
      _otpFocus[i - 1].requestFocus();
    }
    setState(() {});
    if (_code.length == 6) _verify();
  }

  static String _timerLabel(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  /// "arjun.singh@example.com" → "ar***h@example.com"
  static String _maskEmail(String email) {
    final at = email.indexOf('@');
    if (at < 3) return email;
    final name = email.substring(0, at);
    final domain = email.substring(at);
    return '${name.substring(0, 2)}***${name.substring(name.length - 1)}$domain';
  }
}

// ── Pieces ────────────────────────────────────────────────────────────────────

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final filled = controller.text.isNotEmpty;
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: filled ? Welcome.card : Welcome.cardDeep.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: filled ? Welcome.gold : Welcome.goldDeep,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLength: 1,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        cursorColor: Welcome.gold,
        decoration: InputDecoration(
          counterText: '',
          hintText: '—',
          hintStyle: TextStyle(
            color: Welcome.gold.withValues(alpha: 0.3),
            fontSize: 22,
          ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(height: 1, color: Welcome.gold.withValues(alpha: 0.25)),
    );
    return Row(
      children: [
        const Spacer(),
        line,
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or',
            style: TextStyle(color: Welcome.muted, fontSize: 14),
          ),
        ),
        line,
        const Spacer(),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Welcome.goldDeep, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _GoogleG(),
            const SizedBox(width: 10),
            const Text(
              'Continue with Google',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Welcome.cream,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A plain "G" is close enough here — the real four-colour glyph is a brand
/// asset Google supplies separately; swap it in once the app has one.
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Color(0xFF4285F4),
      ),
    );
  }
}
