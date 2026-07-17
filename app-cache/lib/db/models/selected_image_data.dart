/// Data model for selected images stored in SQLite
class SelectedImageData {
  final String id;
  final List<int> imageData; // BLOB data
  final String imagePath;
  final String? category;
  final String? subcategory;
  final DateTime selectedAt;
  /// "INTERIOR" or "EXTERIOR" — from the API's applicationType field
  final String? applicationType;
  final String? originalImageUrl;

  SelectedImageData({
    required this.id,
    required this.imageData,
    required this.imagePath,
    this.category,
    this.subcategory,
    required this.selectedAt,
    this.applicationType,
    this.originalImageUrl,
  });

  /// Convert model to database map
  Map<String, dynamic> toMap() {
    return {
      'product_id': id,
      'image_data': imageData,
      'image_path': imagePath,
      'category': category,
      'subcategory': subcategory,
      'selected_at': selectedAt.toIso8601String(),
      'application_type': applicationType,
      'original_image_url': originalImageUrl,
    };
  }

  /// Create model from database map
  factory SelectedImageData.fromMap(Map<String, dynamic> map) {
    return SelectedImageData(
      id: map['product_id'],
      imageData: map['image_data'],
      imagePath: map['image_path'],
      category: map['category'],
      subcategory: map['subcategory'],
      selectedAt: DateTime.parse(map['selected_at']),
      applicationType: map['application_type'],
      originalImageUrl: map['original_image_url'],
    );
  }
}
