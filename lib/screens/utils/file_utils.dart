// lib/utils/file_utils.dart
// Cross-platform file handling utilities

import 'dart:typed_data';
import 'file_utils_stub.dart'
    if (dart.library.html) 'file_utils_web.dart'
    if (dart.library.io) 'file_utils_mobile.dart';

/// Abstract class for platform-specific file operations
abstract class FileUtils {
  /// Get the platform-specific implementation
  static FileUtils get instance => getFileUtils();

  /// Pick multiple images from device/browser
  Future<List<Uint8List>> pickImages();

  /// Pick a single image
  Future<Uint8List?> pickSingleImage();

  /// Download/save a file with given bytes and filename
  Future<void> downloadFile(Uint8List bytes, String filename,
      {String? mimeType});

  /// Read file as bytes (used internally)
  Future<Uint8List?> readFileAsBytes(dynamic file);
}
