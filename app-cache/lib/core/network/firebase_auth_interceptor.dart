import 'package:century_ai/core/constants/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Adds `Authorization: Bearer <Firebase ID token>` to every request so the
/// backend can identify the signed-in user (it reads the UID from the token).
///
/// Signed-out requests go without the header; the backend treats those as the
/// shared `SYSTEM` owner. On a 401 the token is force-refreshed and the request
/// retried once.
class FirebaseAuthInterceptor extends QueuedInterceptor {
  final Dio _dio;
  final FirebaseAuth _auth;

  static const _retriedKey = 'firebase_auth_retried';

  static final _apiHost = Uri.parse(TApiConstants.baseUrl).host;

  static bool _isApiRequest(RequestOptions options) =>
      options.uri.host == _apiHost;

  FirebaseAuthInterceptor(this._dio, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Only our API gets the token; signed storage URLs reject extra auth.
    if (!_isApiRequest(options)) return handler.next(options);
    try {
      // Returns the cached token, refreshing it first if it is about to expire.
      final token = await _auth.currentUser?.getIdToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      debugPrint('🔐 [Auth] Could not get ID token: $e');
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final user = _auth.currentUser;
    if (err.response?.statusCode != 401 ||
        user == null ||
        !_isApiRequest(options) ||
        options.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    try {
      final token = await user.getIdToken(true);
      options.headers['Authorization'] = 'Bearer $token';
      options.extra[_retriedKey] = true;
      handler.resolve(await _dio.fetch(options));
    } catch (_) {
      handler.next(err);
    }
  }
}
