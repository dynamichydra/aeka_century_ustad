import 'dart:io';

import 'package:century_ai/features/camera_pages/data/models/edit_record.dart';

class HistoryController {
  const HistoryController();

  /// Combines this phone's saved edits with the server's list into the
  /// Compare & select tiles, newest first.
  ///
  /// Every edit saved on this phone (one per Apply) gets its own tile with
  /// its own image. A server edit is added only when it is a different edit
  /// (no local edit with the same ID or image file), e.g. one made on another
  /// phone. There is deliberately no "created within N minutes" matching:
  /// that used to fold several quick Applies into one tile, and since the
  /// server keeps one overwritten record per furniture, the surviving tile
  /// showed the newest image instead of each edit.
  static List<EditRecord> mergeAndDeduplicate({
    required List<EditRecord> networkEdits,
    required List<EditRecord> localEdits,
  }) {
    String fileName(String path) => path.split('/').last.split('?').first;

    final networkById = {
      for (final net in networkEdits)
        if (net.id.isNotEmpty) net.id: net,
    };

    final merged = <String, EditRecord>{};
    final localFiles = <String>{};

    for (final local in localEdits) {
      final key = local.id.isNotEmpty
          ? local.id
          : fileName(local.editedImageUrl);
      if (merged.containsKey(key)) continue;

      var record = local;
      // Fall back to the server copy only if this phone lost the image file
      // (e.g. an old edit saved in a temp folder the OS has cleared).
      final net = networkById[local.id];
      final path = local.editedImageUrl;
      if (net != null && !path.startsWith('http') && !File(path).existsSync()) {
        record = EditRecord(
          id: local.id,
          originalImageUrl: local.originalImageUrl,
          editedImageUrl: net.editedImageUrl,
          ownerId: local.ownerId,
          furnitureId: local.furnitureId,
          createdAt: local.createdAt,
          laminateName: local.laminateName,
          usedLaminatesJson: local.usedLaminatesJson,
          systemArea: local.systemArea,
          userArea: local.userArea,
        );
      }

      merged[key] = record;
      localFiles.add(fileName(local.editedImageUrl));
    }

    for (final net in networkEdits) {
      final key = net.id.isNotEmpty ? net.id : fileName(net.editedImageUrl);
      if (merged.containsKey(key)) continue;
      if (localFiles.contains(fileName(net.editedImageUrl))) continue;
      merged[key] = net;
    }

    final list = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}
