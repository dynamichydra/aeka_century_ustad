import 'dart:async';
import 'dart:io';

import 'package:century_ai/data/services/profile_cloud_sync.dart';
import 'package:century_ai/db/db_core.dart';
import 'package:century_ai/db/models/user_profile_data.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Stores the signed-in user's profile (name, email, language, occupation,
/// photo) in the local SQLite database, one row per Firebase UID.
class LocalUserProfileRepository {
  static const String tableName = 'user_profile';

  static const String _createTableScript =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      uid TEXT PRIMARY KEY,
      phone_number TEXT,
      first_name TEXT,
      last_name TEXT,
      email TEXT,
      address TEXT,
      mother_tongue TEXT,
      occupation TEXT,
      photo_file_name TEXT,
      updated_at TEXT NOT NULL
    )
  ''';

  /// Whether the current Firebase user has a complete profile. Loaded at
  /// startup by [loadForCurrentUser] so the router can decide synchronously.
  static bool currentUserComplete = false;

  /// The signed-in user's profile; widgets listen to this to show the latest
  /// name and photo (drawer, app bar, profile page).
  static final ValueNotifier<UserProfileData?> current = ValueNotifier(null);

  /// App documents folder, cached so photos can be resolved synchronously.
  static String? _docsPath;

  static Future<void> initializeTable() async {
    await DbCore.ensureTablesExist({tableName: _createTableScript});
    try {
      final db = await DbCore.database;
      await db.execute('ALTER TABLE $tableName ADD COLUMN address TEXT');
    } catch (_) {
      // Column may already exist
    }
  }

  static Future<UserProfileData?> getProfile(String uid) async {
    final db = await DbCore.database;
    final rows = await db.query(
      tableName,
      where: 'uid = ?',
      whereArgs: [uid],
      limit: 1,
    );
    return rows.isEmpty ? null : UserProfileData.fromMap(rows.first);
  }

  static Future<void> saveProfile(UserProfileData profile) async {
    final db = await DbCore.database;
    await db.insert(
      tableName,
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (profile.uid == FirebaseAuth.instance.currentUser?.uid) {
      currentUserComplete = profile.isComplete;
      current.value = profile;
    }
    debugPrint('👤 [Profile] Saved profile for ${profile.uid}');
  }

  /// Refreshes [currentUserComplete] for whoever is signed in now.
  ///
  /// When this phone has no complete profile (new phone, reinstall), the
  /// name, email, phone and photo saved on the Firebase account are restored
  /// first. A profile saved only on this phone fills in the account in the
  /// background.
  static Future<bool> loadForCurrentUser() async {
    _docsPath ??= (await getApplicationDocumentsDirectory()).path;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    var profile = uid == null ? null : await getProfile(uid);

    if (uid != null && !(profile?.isComplete ?? false)) {
      profile = await _restoreFromCloud(uid, profile) ?? profile;
    } else if (profile != null) {
      unawaited(
        ProfileCloudSync.backfillIfMissing(
          profile,
          photo: photoFileSync(profile.photoFileName),
        ),
      );
    }

    currentUserComplete = profile?.isComplete ?? false;
    current.value = profile;
    return currentUserComplete;
  }

  /// Fills this phone's profile from the Firebase account (name, email,
  /// phone, photo) and saves it to SQLite. Mother tongue and occupation are
  /// phone-only, so any already saved here are kept. Returns the merged
  /// profile, or null if the account has nothing to add.
  static Future<UserProfileData?> _restoreFromCloud(
    String uid,
    UserProfileData? local,
  ) async {
    final remote = await ProfileCloudSync.fetch();
    if (remote == null) return null;
    final r = remote.profile;

    var photoFileName = local?.photoFileName;
    final bytes = remote.photoBytes;
    if (photoFileSync(photoFileName) == null && bytes != null) {
      photoFileName =
          'profile_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(p.join(_docsPath!, photoFileName)).writeAsBytes(bytes);
    }

    String pick(String? phone, String cloud) =>
        (phone ?? '').trim().isNotEmpty ? phone!.trim() : cloud;

    final merged = UserProfileData(
      uid: uid,
      phoneNumber: local?.phoneNumber ?? r.phoneNumber,
      firstName: pick(local?.firstName, r.firstName),
      lastName: pick(local?.lastName, r.lastName),
      email: pick(local?.email, r.email),
      address: local?.address ?? r.address,
      motherTongue: local?.motherTongue,
      occupation: local?.occupation,
      photoFileName: photoFileName,
      updatedAt: DateTime.now(),
    );
    final db = await DbCore.database;
    await db.insert(
      tableName,
      merged.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint(
      '👤 [Profile] Restored profile for $uid from the Firebase account '
      '(complete: ${merged.isComplete})',
    );
    return merged;
  }

  /// Forgets the in-memory profile after logout (the saved row stays).
  static void clearCurrent() {
    currentUserComplete = false;
    current.value = null;
  }

  /// The stored photo for [fileName], if it exists. Needs
  /// [loadForCurrentUser] to have run once (it caches the documents folder).
  static File? photoFileSync(String? fileName) {
    if (fileName == null || fileName.isEmpty || _docsPath == null) return null;
    final file = File(p.join(_docsPath!, fileName));
    return file.existsSync() ? file : null;
  }

  /// Copies a picked photo into the app documents folder and returns its
  /// file name, to be saved in [UserProfileData.photoFileName].
  static Future<String> storePhoto(String uid, File picked) async {
    final docs = await getApplicationDocumentsDirectory();
    final ext = p.extension(picked.path).isEmpty
        ? '.jpg'
        : p.extension(picked.path);
    // New name each time so Image.file does not show a cached old photo.
    final fileName =
        'profile_${uid}_${DateTime.now().millisecondsSinceEpoch}$ext';
    await picked.copy(p.join(docs.path, fileName));
    return fileName;
  }

  /// Full path of a stored photo, or null if it no longer exists.
  static Future<File?> photoFile(String? fileName) async {
    if (fileName == null || fileName.isEmpty) return null;
    final docs = await getApplicationDocumentsDirectory();
    final file = File(p.join(docs.path, fileName));
    return await file.exists() ? file : null;
  }

  /// Deletes an old photo file after it was replaced.
  static Future<void> deletePhoto(String? fileName) async {
    final file = await photoFile(fileName);
    if (file != null) await file.delete();
  }
}
