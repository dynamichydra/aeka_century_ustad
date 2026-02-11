import 'package:century_ai/cubit/auth/auth_state.dart';
import 'package:century_ai/data/repositories/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;

  AuthCubit(this._authRepository) : super(const AuthState());

  Future<void> requestOtp(String phone) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null, phone: phone));
    try {
      await _authRepository.requestOtp(phone);
      emit(state.copyWith(status: AuthStatus.otpSent));
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null, phone: phone));
    try {
      final session = await _authRepository.verifyOtp(phone: phone, otp: otp);
      emit(state.copyWith(status: AuthStatus.authenticated, session: session));
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void resetStatus() {
    emit(state.copyWith(status: AuthStatus.initial, errorMessage: null));
  }
}
