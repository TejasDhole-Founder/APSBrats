import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.crimson,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Welcome back',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  state.otpSent ? 'Enter the code we sent you' : 'Log in with your phone number',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 28),
                if (!state.otpSent) ...[
                  _field(_phoneCtrl, 'Phone number', TextInputType.phone),
                  const SizedBox(height: 14),
                  _button(
                    label: 'Send code',
                    loading: state.loading,
                    onTap: () => controller.requestOtp(_phoneCtrl.text.trim()),
                  ),
                ] else ...[
                  _field(_codeCtrl, '6-digit code', TextInputType.number),
                  const SizedBox(height: 14),
                  _button(
                    label: 'Verify & log in',
                    loading: state.loading,
                    onTap: () async {
                      final ok = await controller.verifyOtp(_phoneCtrl.text.trim(), _codeCtrl.text.trim());
                      if (ok && context.mounted) context.go('/home');
                    },
                  ),
                ],
                if (state.error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    state.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.gold, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () => context.go('/onboarding'),
                  child: const Text("New here? Create an account", style: TextStyle(color: Colors.white70)),
                ),
                if (kDebugMode)
                  TextButton(
                    onPressed: state.loading
                        ? null
                        : () async {
                            final ok = await controller.devSkipLogin();
                            if (ok && context.mounted) context.go('/home');
                          },
                    child: const Text('Skip login (dev)', style: TextStyle(color: AppColors.gold)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, TextInputType type) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.black26,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
      ),
    );
  }

  Widget _button({required String label, required bool loading, required VoidCallback onTap}) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.crimsonDark,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: loading ? null : onTap,
      child: loading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.crimsonDark),
            )
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}
