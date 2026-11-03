import 'package:century_ai/data/models/auth_session.dart';
import 'package:century_ai/db/repositories/local_user_profile_repository.dart';
import 'package:century_ai/router/app_routes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_storage/get_storage.dart';

/// Persists the logged-in session.
class AuthStorage {
  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _userIdKey = 'auth_user_id';
  static const _phoneKey = 'auth_phone';

  static final GetStorage _box = GetStorage();

  /// Firebase keeps the signed-in user across launches.
  static bool get isLoggedIn => FirebaseAuth.instance.currentUser != null;

  /// Where to go right after a sign-in: profile setup for new users and for
  /// users without a name or email yet, otherwise home.
  static Future<String> routeAfterSignIn() async {
    final complete = await LocalUserProfileRepository.loadForCurrentUser();
    return complete ? AppRoutes.home : AppRoutes.profileSetup;
  }

  static Future<void> saveSession(AuthSession session) async {
    await _box.write(_tokenKey, session.token);
    await _box.write(_refreshTokenKey, session.refreshToken);
    await _box.write(_userIdKey, session.userId);
    await _box.write(_phoneKey, session.phone);
  }

  static Future<void> clearSession() async {
    await _box.remove(_tokenKey);
    await _box.remove(_refreshTokenKey);
    await _box.remove(_userIdKey);
    await _box.remove(_phoneKey);
  }
}
