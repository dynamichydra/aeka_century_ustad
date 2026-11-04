import 'package:firebase_auth/firebase_auth.dart';

/// Owner value stored with records the app keeps on the device (local edit
/// history), so each signed-in user only sees their own.
///
/// Not sent to the Century Ustad API: the API identifies the user from the
/// `Authorization: Bearer <ID token>` header that FirebaseAuthInterceptor adds.
abstract final class CurrentUser {
  /// Owner used for signed-out / shared records.
  static const systemOwner = 'SYSTEM';

  /// Firebase UID of the signed-in user, or [systemOwner] when signed out.
  static String get ownerId =>
      FirebaseAuth.instance.currentUser?.uid ?? systemOwner;
}
