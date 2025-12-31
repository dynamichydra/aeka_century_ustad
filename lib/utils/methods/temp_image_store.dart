import 'dart:io';

class TempImageStore {
  static final Map<int, File> _images = {};

  static void setImage(int id, File file) {
    _images[id] = file;
  }

  static File? getImage(int id) {
    return _images[id];
  }

  static void clear(int id) {
    _images.remove(id);
  }
}
