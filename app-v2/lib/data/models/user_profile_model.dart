class UserProfileModel {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String? companyTitle;

  const UserProfileModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    this.companyTitle,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final company = json['company'];
    return UserProfileModel(
      id: (json['id'] as num?)?.toInt() ?? 1,
      firstName: (json['firstName'] ?? '').toString(),
      lastName: (json['lastName'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      companyTitle:
          company is Map<String, dynamic> ? company['title']?.toString() : null,
    );
  }

  UserProfileModel copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? companyTitle,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      companyTitle: companyTitle ?? this.companyTitle,
    );
  }

  Map<String, dynamic> toUpdatePayload() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'company': {'title': companyTitle ?? ''},
    };
  }
}
