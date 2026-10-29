import 'dart:async';

import 'package:century_ai/cubit/auth/auth_state.dart';
import 'package:century_ai/data/repositories/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  late final StreamSubscription _autoSignInSub;

  AuthCubit(this._authRepository) : super(const AuthState()) {
    // Android can verify the SMS on its own; treat that as a normal sign-in.
    _autoSignInSub = _authRepository.autoSignIns.listen((session) {
      emit(state.copyWith(status: AuthStatus.authenticated, session: session));
    });
  }

  Future<void> requestOtp(String phone) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        errorMessage: null,
        phone: phone,
      ),
    );
    try {
      await _authRepository.requestOtp(phone);
      if (state.status == AuthStatus.authenticated) return;
      emit(state.copyWith(status: AuthStatus.otpSent));
    } catch (e) {
      emit(
        state.copyWith(status: AuthStatus.error, errorMessage: e.toString()),
      );
    }
  }

  Future<void> verifyOtp({required String phone, required String otp}) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        errorMessage: null,
        phone: phone,
      ),
    );
    try {
      final session = await _authRepository.verifyOtp(phone: phone, otp: otp);
      emit(state.copyWith(status: AuthStatus.authenticated, session: session));
    } catch (e) {
      emit(
        state.copyWith(status: AuthStatus.error, errorMessage: e.toString()),
      );
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    emit(const AuthState());
  }

  void resetStatus() {
    emit(state.copyWith(status: AuthStatus.initial, errorMessage: null));
  }

  @override
  Future<void> close() {
    _autoSignInSub.cancel();
    return super.close();
  }
}
