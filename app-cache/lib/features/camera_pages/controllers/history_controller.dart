import 'package:century_ai/features/camera_pages/data/models/edit_record.dart';

class HistoryController {
  const HistoryController();

  static List<EditRecord> mergeAndDeduplicate({
    required List<EditRecord> networkEdits,
    required List<EditRecord> localEdits,
  }) {
    final Map<String, EditRecord> uniqueMap = {};
    String getFileName(String path) => path.split('/').last.split('?').first;

    // Add Network records first (as the source of truth for remote URLs)
    for (var net in networkEdits) {
      if (net.id.isNotEmpty) {
        uniqueMap[net.id] = net;
      } else {
        final fallbackKey = getFileName(net.editedImageUrl);
        uniqueMap[fallbackKey] = net;
      }
    }

    // Add Local records only if they aren't already represented in uniqueMap by ID, Filename, or closely-matching metadata
    for (var record in localEdits) {
      final key = record.id;
      final fallbackKey = getFileName(record.editedImageUrl);

      // Check if this local record matches any already added network record by ID
      if (uniqueMap.containsKey(key)) {
        final existingNet = uniqueMap[key]!;
        if (existingNet.usedLaminatesJson == null ||
            existingNet.usedLaminatesJson!.isEmpty) {
          uniqueMap[key] = EditRecord(
            id: existingNet.id,
            originalImageUrl: existingNet.originalImageUrl,
            editedImageUrl: existingNet.editedImageUrl,
            ownerId: existingNet.ownerId,
            furnitureId: existingNet.furnitureId,
            createdAt: existingNet.createdAt,
            laminateName: record.laminateName,
            usedLaminatesJson: record.usedLaminatesJson,
          );
        }
        continue;
      }

      // Check if this local record matches any already added network record by Filename
      if (uniqueMap.containsKey(fallbackKey)) {
        final existingNet = uniqueMap[fallbackKey]!;
        if (existingNet.usedLaminatesJson == null ||
            existingNet.usedLaminatesJson!.isEmpty) {
          uniqueMap[fallbackKey] = EditRecord(
            id: existingNet.id,
            originalImageUrl: existingNet.originalImageUrl,
            editedImageUrl: existingNet.editedImageUrl,
            ownerId: existingNet.ownerId,
            furnitureId: existingNet.furnitureId,
            createdAt: existingNet.createdAt,
            laminateName: record.laminateName,
            usedLaminatesJson: record.usedLaminatesJson,
          );
        }
        continue;
      }

      // Deep/intelligent check to see if this local record represents the same edit as an existing network record (within 5 minutes)
      bool isDuplicate = false;
      for (var existingNet in uniqueMap.values) {
        final diffSeconds = record.createdAt
            .difference(existingNet.createdAt)
            .inSeconds
            .abs();
        if (diffSeconds < 300) {
          final netKey = existingNet.id.isNotEmpty
              ? existingNet.id
              : getFileName(existingNet.editedImageUrl);
          if (existingNet.usedLaminatesJson == null ||
              existingNet.usedLaminatesJson!.isEmpty) {
            uniqueMap[netKey] = EditRecord(
              id: existingNet.id,
              originalImageUrl: existingNet.originalImageUrl,
              editedImageUrl: existingNet.editedImageUrl,
              ownerId: existingNet.ownerId,
              furnitureId: existingNet.furnitureId,
              createdAt: existingNet.createdAt,
              laminateName: record.laminateName,
              usedLaminatesJson: record.usedLaminatesJson,
            );
          }
          isDuplicate = true;
          break;
        }
      }

      if (!isDuplicate) {
        uniqueMap[key] = record;
      }
    }

    final merged = uniqueMap.values.toList();
    // Sort by creation time descending (latest first)
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }
}
