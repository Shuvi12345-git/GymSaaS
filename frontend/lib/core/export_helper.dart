// ---------------------------------------------------------------------------
// Export helper – download Excel exports from backend and save to device.
// ---------------------------------------------------------------------------
// Used when admin taps "Export" for members, payments, or billing. Writes
// response bytes to Downloads (or app documents) and returns the file path.
// ---------------------------------------------------------------------------

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'api_client.dart';

/// Downloads an export file from the API and saves it to Downloads (or app documents).
/// Returns the save path on success, null on failure.
Future<String?> saveExportToDownloads(String path, String filename) async {
  try {
    final response = await ApiClient.instance.get(path, useCache: false);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final bytes = response.bodyBytes;
    if (bytes.isEmpty) return null;

    Directory dir;
    try {
      final d = await getDownloadsDirectory();
      dir = d ?? await getApplicationDocumentsDirectory();
    } catch (_) {
      dir = await getApplicationDocumentsDirectory();
    }

    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  } catch (_) {
    return null;
  }
}

/// User-facing label for the save location (e.g. "Downloads" or "Documents").
Future<String> exportLocationLabel() async {
  try {
    final d = await getDownloadsDirectory();
    return d != null ? 'Downloads' : 'Documents';
  } catch (_) {
    return 'Documents';
  }
}
