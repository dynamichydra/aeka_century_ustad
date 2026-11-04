/// Profile details for a signed-in Firebase user, stored in SQLite.
class UserProfileData {
  final String uid;
  final String? phoneNumber;
  final String firstName;
  final String lastName;
  final String email;
  final String? address;
  final String? motherTongue;
  final String? occupation;

  /// File name inside the app documents folder (not a full path, because the
  /// iOS app folder changes between installs and updates).
  final String? photoFileName;
  final DateTime updatedAt;

  const UserProfileData({
    required this.uid,
    this.phoneNumber,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.address,
    this.motherTongue,
    this.occupation,
    this.photoFileName,
    required this.updatedAt,
  });

  /// First name, last name and email are required before the app opens.
  bool get isComplete =>
      firstName.trim().isNotEmpty &&
      lastName.trim().isNotEmpty &&
      email.trim().isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phone_number': phoneNumber,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'address': address,
      'mother_tongue': motherTongue,
      'occupation': occupation,
      'photo_file_name': photoFileName,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserProfileData.fromMap(Map<String, dynamic> map) {
    return UserProfileData(
      uid: map['uid'] as String,
      phoneNumber: map['phone_number'] as String?,
      firstName: (map['first_name'] as String?) ?? '',
      lastName: (map['last_name'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      address: map['address'] as String?,
      motherTongue: map['mother_tongue'] as String?,
      occupation: map['occupation'] as String?,
      photoFileName: map['photo_file_name'] as String?,
      updatedAt:
          DateTime.tryParse((map['updated_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}
