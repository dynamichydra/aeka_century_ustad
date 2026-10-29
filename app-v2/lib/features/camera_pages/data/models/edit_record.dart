import 'dart:convert';

class EditRecord {
  final String id;
  final String originalImageUrl;
  final String editedImageUrl;
  final String ownerId;
  final String furnitureId;
  final DateTime createdAt;
  final String? laminateName;
  final String? usedLaminatesJson; // JSON string of used laminates
  final double? systemArea;
  final double? userArea;

  EditRecord({
    required this.id,
    required this.originalImageUrl,
    required this.editedImageUrl,
    required this.ownerId,
    required this.furnitureId,
    required this.createdAt,
    this.laminateName,
    this.usedLaminatesJson,
    this.systemArea,
    this.userArea,
  });

  List<Map<String, dynamic>> get usedLaminatesList {
    if (usedLaminatesJson == null || usedLaminatesJson!.isEmpty) return [];
    try {
      final decoded = jsonDecode(usedLaminatesJson!);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else if (decoded is Map) {
        return [Map<String, dynamic>.from(decoded)];
      }
    } catch (e) {
      // fallback
    }
    return [];
  }

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
      usedLaminatesJson: json['usedLaminates'] != null ? jsonEncode(json['usedLaminates']) : null,
      systemArea: json['systemArea'] != null ? (json['systemArea'] as num).toDouble() : null,
      userArea: json['userArea'] != null ? (json['userArea'] as num).toDouble() : null,
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
      'systemArea': systemArea,
      'userArea': userArea,
    };
  }
}
