import 'package:century_ai/data/models/auth_session.dart';
import 'package:equatable/equatable.dart';

enum AuthStatus { initial, loading, otpSent, authenticated, error }

class AuthState extends Equatable {
  final AuthStatus status;
  final String phone;
  final AuthSession? session;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.phone = '',
    this.session,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? phone,
    AuthSession? session,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      phone: phone ?? this.phone,
      session: session ?? this.session,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, phone, session, errorMessage];
}
