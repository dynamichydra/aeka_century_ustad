import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:century_ai/db/models/user_profile_data.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Keeps the profile basics in Firebase so a new phone or a reinstall does
/// not ask for them again. One rule: if Firebase has a name and an email for
/// the user, profile setup is skipped.
///
/// - `users/{uid}/profile.json` (Firebase Storage): name, email, phone
/// - `users/{uid}/profile.jpg`  (Firebase Storage): the photo
/// - the Firebase Auth display name and photo URL are kept in step too
///
/// The email is stored in profile.json rather than on the Auth account
/// because Firebase only sets an account email after a verification link is
/// tapped. Mother tongue and occupation stay on the phone only (SQLite).
/// Every call here is best-effort, so saving and sign-in work offline.
abstract final class ProfileCloudSync {
  static const _timeout = Duration(seconds: 30);

  static Reference _photoRef(String uid) =>
      FirebaseStorage.instance.ref('users/$uid/profile.jpg');

  static Reference _detailsRef(String uid) =>
      FirebaseStorage.instance.ref('users/$uid/profile.json');

  /// Saves name, email, phone and (when given) a new photo to Firebase.
  static Future<void> push(UserProfileData profile, {File? newPhoto}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != profile.uid) return;

    try {
      await _detailsRef(profile.uid)
          .putString(
            jsonEncode({
              'firstName': profile.firstName,
              'lastName': profile.lastName,
              'email': profile.email,
              'phoneNumber': profile.phoneNumber ?? user.phoneNumber,
              'address': profile.address,
              'updatedAt': DateTime.now().toUtc().toIso8601String(),
            }),
            format: PutStringFormat.raw,
            metadata: SettableMetadata(contentType: 'application/json'),
          )
          .timeout(_timeout);
      debugPrint('☁️ [Profile] Saved profile details to Firebase');
    } catch (e) {
      debugPrint('☁️ [Profile] Could not save profile details: $e');
    }

    final name = '${profile.firstName} ${profile.lastName}'.trim();
    if (name.isNotEmpty && user.displayName != name) {
      try {
        await user.updateDisplayName(name);
      } catch (e) {
        debugPrint('☁️ [Profile] Could not update display name: $e');
      }
    }

    if (newPhoto != null && await newPhoto.exists()) {
      try {
        final ref = _photoRef(profile.uid);
        await ref
            .putFile(newPhoto, SettableMetadata(contentType: 'image/jpeg'))
            .timeout(_timeout);
        await user.updatePhotoURL(await ref.getDownloadURL());
        debugPrint('☁️ [Profile] Uploaded profile photo');
      } catch (e) {
        debugPrint('☁️ [Profile] Could not upload profile photo: $e');
      }
    }
  }

  /// The profile saved in Firebase for the signed-in user, for a phone that
  /// has none yet. [photoBytes] is the saved photo, if any.
  static Future<({UserProfileData profile, Uint8List? photoBytes})?>
  fetch() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    Map<String, dynamic> details = {};
    try {
      final bytes = await _detailsRef(
        user.uid,
      ).getData(64 * 1024).timeout(_timeout);
      if (bytes != null) {
        details = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      }
    } on FirebaseException catch (e) {
      // object-not-found just means nothing was saved yet.
      if (e.code != 'object-not-found') {
        debugPrint('☁️ [Profile] Could not read profile details: ${e.code}');
      }
    } catch (e) {
      debugPrint('☁️ [Profile] Could not read profile details: $e');
    }

    // Fall back to the Auth account for anything profile.json lacks.
    final parts = (user.displayName ?? '').trim().split(RegExp(r'\s+'));
    final firstName =
        (details['firstName'] as String?)?.trim().nonEmpty ?? parts.first;
    final lastName =
        (details['lastName'] as String?)?.trim().nonEmpty ??
        parts.skip(1).join(' ');
    final email =
        (details['email'] as String?)?.trim().nonEmpty ?? (user.email ?? '');
    if (firstName.isEmpty && email.isEmpty) return null;

    Uint8List? photoBytes;
    try {
      photoBytes = await _photoRef(
        user.uid,
      ).getData(5 * 1024 * 1024).timeout(_timeout);
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        debugPrint('☁️ [Profile] Could not download photo: ${e.code}');
      }
    } catch (e) {
      debugPrint('☁️ [Profile] Could not download photo: $e');
    }

    return (
      profile: UserProfileData(
        uid: user.uid,
        phoneNumber: (details['phoneNumber'] as String?) ?? user.phoneNumber,
        firstName: firstName,
        lastName: lastName,
        email: email,
        address: (details['address'] as String?)?.trim().nonEmpty,
        updatedAt: DateTime.now(),
      ),
      photoBytes: photoBytes,
    );
  }

  /// Uploads a profile saved only on this phone (e.g. before this sync
  /// existed) if Firebase has no saved details for the user yet.
  static Future<void> backfillIfMissing(
    UserProfileData profile, {
    File? photo,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != profile.uid) return;
    try {
      await _detailsRef(profile.uid).getMetadata().timeout(_timeout);
      return; // already saved
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') return; // offline etc.; try later
    } catch (_) {
      return;
    }
    await push(profile, newPhoto: (user.photoURL ?? '').isEmpty ? photo : null);
  }
}

extension on String {
  String? get nonEmpty => isEmpty ? null : this;
}
