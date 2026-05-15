import 'dart:convert';

class EditRecord {
  final String id;
  final String originalImageUrl;
  final String editedImageUrl;
  final String ownerId;
  final String furnitureId;
  final DateTime createdAt;
  final String? laminateName;

  EditRecord({
    required this.id,
    required this.originalImageUrl,
    required this.editedImageUrl,
    required this.ownerId,
    required this.furnitureId,
    required this.createdAt,
    this.laminateName,
  });

  factory EditRecord.fromJson(Map<String, dynamic> json) {
    return EditRecord(
      id: json['id'] ?? '',
      originalImageUrl: json['originalImageUrl'] ?? '',
      editedImageUrl: json['editedImageUrl'] ?? '',
      ownerId: json['ownerId'] ?? '',
      furnitureId: json['furnitureId'] ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalImageUrl': originalImageUrl,
      'editedImageUrl': editedImageUrl,
      'ownerId': ownerId,
      'furnitureId': furnitureId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
