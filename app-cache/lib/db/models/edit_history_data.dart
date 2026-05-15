class EditHistoryData {
  final String id;
  final String furnitureId;
  final String sessionId;
  final String originalImagePath;
  final String editedImagePath;
  final DateTime editedAt;
  final String ownerId;

  EditHistoryData({
    required this.id,
    required this.furnitureId,
    required this.sessionId,
    required this.originalImagePath,
    required this.editedImagePath,
    required this.editedAt,
    required this.ownerId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'furniture_id': furnitureId,
      'session_id': sessionId,
      'original_image_path': originalImagePath,
      'edited_image_path': editedImagePath,
      'edited_at': editedAt.toIso8601String(),
      'owner_id': ownerId,
    };
  }

  factory EditHistoryData.fromMap(Map<String, dynamic> map) {
    return EditHistoryData(
      id: map['id'],
      furnitureId: map['furniture_id'],
      sessionId: map['session_id'] ?? '',
      originalImagePath: map['original_image_path'],
      editedImagePath: map['edited_image_path'],
      editedAt: DateTime.parse(map['edited_at']),
      ownerId: map['owner_id'],
    );
  }
}
