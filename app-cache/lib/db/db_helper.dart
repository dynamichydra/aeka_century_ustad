// DB Helper - Facade for database operations
// This file re-exports the modular database components for convenience

export 'db_core.dart'; // Core database initialization
export 'models/selected_image_data.dart'; // Data models
export 'repositories/selected_images_repository.dart'; // Repositories by feature

/// Maintained for backward compatibility
/// New code should import specific components directly
class DbHelper {
  // All database operations have been moved to specific repositories
  // See SelectedImagesRepository for image-related operations
  
  @deprecated
  static void throwDeprecatedError() {
    throw UnimplementedError(
      'DbHelper methods are deprecated. Use specific repositories instead:\n'
      '- SelectedImagesRepository for image operations',
    );
  }
}
