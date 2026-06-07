import 'package:apsbrat_frontend/features/auth/data/auth_models.dart';
import 'package:apsbrat_frontend/features/auth/data/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  const AuthState({this.user, this.loading = false, this.otpSent = false, this.error});

  final AuthUser? user;
  final bool loading;
  final bool otpSent;
  final String? error;

  AuthState copyWith({AuthUser? user, bool? loading, bool? otpSent, String? error}) {
    return AuthState(
      user: user ?? this.user,
      loading: loading ?? this.loading,
      otpSent: otpSent ?? this.otpSent,
      error: error,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo) : super(const AuthState());

  final AuthRepository _repo;

  Future<void> requestOtp(String phone) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repo.requestOtp(phone);
      state = state.copyWith(loading: false, otpSent: true);
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Could not send OTP. Try again.');
    }
  }

  Future<bool> verifyOtp(String phone, String code) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final user = await _repo.verifyOtp(phone, code);
      state = state.copyWith(loading: false, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Incorrect or expired code.');
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState();
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

final currentUserIdProvider = FutureProvider<String?>((ref) {
  return ref.watch(authRepositoryProvider).currentUserId();
});
