import 'package:apsbrat_frontend/features/auth/data/auth_models.dart';
import 'package:apsbrat_frontend/features/auth/data/auth_repository.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_socket.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  const AuthState({
    this.user,
    this.loading = false,
    this.otpSent = false,
    this.error,
  });

  final AuthUser? user;
  final bool loading;
  final bool otpSent;
  final String? error;

  AuthState copyWith({
    AuthUser? user,
    bool? loading,
    bool? otpSent,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      loading: loading ?? this.loading,
      otpSent: otpSent ?? this.otpSent,
      error: error,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo, this._ref) : super(const AuthState());

  final AuthRepository _repo;
  final Ref _ref;

  Future<void> requestOtp(String email) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repo.requestOtp(email);
      state = state.copyWith(loading: false, otpSent: true);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'Could not send the code. Try again.',
      );
    }
  }

  /// Back to the email step (the "Edit" link on the OTP screen).
  void editEmail() {
    state = state.copyWith(otpSent: false, error: null);
  }

  Future<bool> verifyOtp(String email, String code) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final user = await _repo.verifyOtp(email, code);
      state = state.copyWith(loading: false, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'Incorrect or expired code.',
      );
      return false;
    }
  }

  /// True on success, false if the user cancelled the Google picker or it failed.
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final user = await _repo.signInWithGoogle();
      if (user == null) {
        state = state.copyWith(loading: false);
        return false;
      }
      state = state.copyWith(loading: false, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'Could not sign in with Google. Try again.',
      );
      return false;
    }
  }

  // TEMPORARY dev shortcut — logs in as the seeded demo user. Remove before release.
  static const _devEmail = 'arjun.singh@example.com';
  static const _devOtp = '000000';

  Future<bool> devSkipLogin() async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repo.requestOtp(_devEmail);
      final user = await _repo.verifyOtp(_devEmail, _devOtp);
      state = state.copyWith(loading: false, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'Skip failed — is the API running?',
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    _ref.read(chatSocketProvider).disconnect();
    state = const AuthState();
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(ref.watch(authRepositoryProvider), ref);
  },
);
