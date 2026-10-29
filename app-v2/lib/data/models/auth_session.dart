class AuthSession {
  final String token;
  final String refreshToken;
  final int userId;
  final String phone;

  const AuthSession({
    required this.token,
    required this.refreshToken,
    required this.userId,
    required this.phone,
  });
}
