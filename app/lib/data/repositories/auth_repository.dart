import 'package:century_ai/data/models/auth_session.dart';
import 'package:century_ai/data/services/api_service.dart';

class AuthRepository {
  final ApiService _apiService;

  AuthRepository(this._apiService);

  Future<void> requestOtp(String phone) async {
    await _apiService.requestOtp(phone);
  }

  Future<AuthSession> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final response = await _apiService.verifyOtp(phone: phone, otp: otp);
    return AuthSession(
      token: (response['token'] ?? '').toString(),
      refreshToken: (response['refreshToken'] ?? '').toString(),
      userId: (response['userId'] as num?)?.toInt() ?? 1,
      phone: (response['phone'] ?? phone).toString(),
    );
  }
}
