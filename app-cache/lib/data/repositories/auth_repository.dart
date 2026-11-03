import 'dart:async';

import 'package:century_ai/data/models/auth_session.dart';
import 'package:century_ai/utils/exceptions/firebase_auth_exceptions.dart';
import 'package:century_ai/utils/logging/auth_logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// A sign-in error with a message that can be shown to the user.
class AuthFailure implements Exception {
  final String message;

  const AuthFailure(this.message);

  @override
  String toString() => message;
}

/// Phone-number OTP sign-in backed by Firebase Authentication.
class AuthRepository {
  final FirebaseAuth _firebaseAuth;

  String? _verificationId;
  int? _resendToken;

  /// Fires when Android auto-reads the SMS and signs in without the user
  /// typing the code.
  final _autoSignIns = StreamController<AuthSession>.broadcast();

  /// The SMS code Android read on its own, so the OTP boxes can show it.
  final _autoCodes = StreamController<String>.broadcast();

  AuthRepository({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  Stream<AuthSession> get autoSignIns => _autoSignIns.stream;

  Stream<String> get autoCodes => _autoCodes.stream;

  bool get isSignedIn => _firebaseAuth.currentUser != null;

  /// Sends an OTP to [phone] (10-digit Indian number, without +91).
  /// Completes once the SMS has been sent.
  Future<void> requestOtp(String phone) {
    final completer = Completer<void>();
    final phoneNumber = '+91$phone';
    AuthLog.start();
    AuthLog.event('verifyPhoneNumber → request', {
      'phoneNumber': phoneNumber,
      'forceResendingToken': _resendToken,
    });

    _firebaseAuth
        .verifyPhoneNumber(
          phoneNumber: phoneNumber,
          timeout: const Duration(seconds: 60),
          forceResendingToken: _resendToken,
          verificationCompleted: (credential) async {
            _logCredential('verificationCompleted (auto)', credential);
            final code = credential.smsCode;
            if (code != null) _autoCodes.add(code);
            try {
              final session = await _signIn(credential, phone);
              _autoSignIns.add(session);
            } catch (_) {
              // The user can still type the code manually.
            }
            if (!completer.isCompleted) completer.complete();
          },
          verificationFailed: (e) {
            _logFailure('verificationFailed', e);
            AuthLog.flush('failed: verificationFailed');
            if (!completer.isCompleted) {
              // Blocked by the project's SMS region policy, not a sign-in issue.
              final regionBlocked =
                  e.code == 'operation-not-allowed' &&
                  (e.message ?? '').toLowerCase().contains('region');
              completer.completeError(
                AuthFailure(
                  regionBlocked
                      ? 'OTP via SMS is not enabled for this country yet.'
                      : TFirebaseAuthException(e.code).message,
                ),
              );
            }
          },
          codeSent: (verificationId, resendToken) {
            AuthLog.event('codeSent', {
              'phoneNumber': phoneNumber,
              'verificationId': verificationId,
              'forceResendingToken': resendToken,
            });
            _verificationId = verificationId;
            _resendToken = resendToken;
            if (!completer.isCompleted) completer.complete();
          },
          codeAutoRetrievalTimeout: (verificationId) {
            AuthLog.event('codeAutoRetrievalTimeout', {
              'verificationId': verificationId,
            });
            _verificationId = verificationId;
          },
        )
        .catchError((Object e, StackTrace st) {
          AuthLog.event('verifyPhoneNumber threw', {
            'type': e.runtimeType,
            'error': e,
            'stackTrace': st,
          });
          AuthLog.flush('failed: verifyPhoneNumber threw');
          if (!completer.isCompleted) {
            completer.completeError(
              AuthFailure(
                e is FirebaseAuthException
                    ? TFirebaseAuthException(e.code).message
                    : 'Could not send OTP. Please try again.',
              ),
            );
          }
        });

    return completer.future;
  }

  Future<AuthSession> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final verificationId = _verificationId;
    if (verificationId == null) {
      throw const AuthFailure('Please request a new OTP.');
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp.trim(),
    );
    _logCredential('verifyOtp → credential (typed code)', credential);
    return _signIn(credential, phone);
  }

  Future<void> logout() => _firebaseAuth.signOut();

  Future<AuthSession> _signIn(
    PhoneAuthCredential credential,
    String phone,
  ) async {
    try {
      final result = await _firebaseAuth.signInWithCredential(credential);
      final user = result.user!;
      _verificationId = null;
      final idToken = await user.getIdToken() ?? '';
      if (kDebugMode) await _logSignIn(result, idToken);
      return AuthSession(
        token: idToken,
        refreshToken: user.refreshToken ?? '',
        userId: 1,
        uid: user.uid,
        phone: phone,
      );
    } on FirebaseAuthException catch (e) {
      _logFailure('signInWithCredential failed', e);
      AuthLog.flush('failed: signInWithCredential');
      throw AuthFailure(TFirebaseAuthException(e.code).message);
    }
  }

  // --- Debug logging (no-ops in release builds; see AuthLog) ---

  void _logCredential(String title, PhoneAuthCredential c) {
    AuthLog.event(title, {
      'providerId': c.providerId,
      'signInMethod': c.signInMethod,
      'verificationId': c.verificationId,
      'smsCode': c.smsCode,
      'token': c.token,
      'accessToken': c.accessToken,
    });
  }

  void _logFailure(String title, FirebaseAuthException e) {
    AuthLog.event(title, {
      'code': e.code,
      'message': e.message,
      'plugin': e.plugin,
      'phoneNumber': e.phoneNumber,
      'tenantId': e.tenantId,
      'credential': e.credential,
      'exception': e,
      'stackTrace': e.stackTrace,
    });
  }

  Future<void> _logSignIn(UserCredential result, String idToken) async {
    final user = result.user!;
    AuthLog.event('signInWithCredential → user', {
      'uid': user.uid,
      'phoneNumber': user.phoneNumber,
      'displayName': user.displayName,
      'email': user.email,
      'isAnonymous': user.isAnonymous,
      'emailVerified': user.emailVerified,
      'tenantId': user.tenantId,
      'creationTime': user.metadata.creationTime,
      'lastSignInTime': user.metadata.lastSignInTime,
      'refreshToken': user.refreshToken,
      'providerData': user.providerData
          .map(
            (p) => {
              'providerId': p.providerId,
              'uid': p.uid,
              'phoneNumber': p.phoneNumber,
              'email': p.email,
              'displayName': p.displayName,
            },
          )
          .toList(),
    });

    final info = result.additionalUserInfo;
    AuthLog.event('signInWithCredential → additionalUserInfo', {
      'isNewUser': info?.isNewUser,
      'providerId': info?.providerId,
      'username': info?.username,
      'profile': info?.profile,
    });

    final cred = result.credential;
    AuthLog.event('signInWithCredential → credential', {
      'providerId': cred?.providerId,
      'signInMethod': cred?.signInMethod,
      'token': cred?.token,
      'accessToken': cred?.accessToken,
    });

    AuthLog.event('ID token (getIdToken)', {'idToken': idToken});

    try {
      final t = await user.getIdTokenResult();
      AuthLog.event('ID token claims (getIdTokenResult)', {
        'authTime': t.authTime,
        'issuedAtTime': t.issuedAtTime,
        'expirationTime': t.expirationTime,
        'signInProvider': t.signInProvider,
        'signInSecondFactor': t.signInSecondFactor,
        'claims': t.claims,
      });
    } catch (e) {
      AuthLog.event('getIdTokenResult failed', {'error': e});
    }
    AuthLog.flush('signed in');
  }
}
