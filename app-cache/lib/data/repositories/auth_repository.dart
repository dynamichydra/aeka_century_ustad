import 'dart:async';

import 'package:century_ai/data/models/auth_session.dart';
import 'package:century_ai/utils/exceptions/firebase_auth_exceptions.dart';
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

    _firebaseAuth
        .verifyPhoneNumber(
          phoneNumber: phoneNumber,
          timeout: const Duration(seconds: 60),
          forceResendingToken: _resendToken,
          verificationCompleted: (credential) async {
            debugPrint('🔐 [Auth] SMS code read automatically');
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
            debugPrint(
              '🔐 [Auth] verifyPhoneNumber failed: ${e.code} ${e.message}',
            );
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
            debugPrint('🔐 [Auth] OTP sent to $phoneNumber');
            _verificationId = verificationId;
            _resendToken = resendToken;
            if (!completer.isCompleted) completer.complete();
          },
          codeAutoRetrievalTimeout: (verificationId) {
            _verificationId = verificationId;
          },
        )
        .catchError((Object e) {
          debugPrint('🔐 [Auth] verifyPhoneNumber threw: $e');
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
      return AuthSession(
        token: await user.getIdToken() ?? '',
        refreshToken: user.refreshToken ?? '',
        userId: 1,
        uid: user.uid,
        phone: phone,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('🔐 [Auth] sign-in failed: ${e.code} ${e.message}');
      throw AuthFailure(TFirebaseAuthException(e.code).message);
    }
  }
}
