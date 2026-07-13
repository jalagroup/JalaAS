// lib/utils/file_utils_stub.dart

import 'dart:typed_data';
import 'file_utils.dart';

class FileUtilsImpl extends FileUtils {
  @override
  Future<List<Uint8List>> pickImages() {
    throw UnimplementedError('Platform not supported');
  }

  @override
  Future<Uint8List?> pickSingleImage() {
    throw UnimplementedError('Platform not supported');
  }

  @override
  Future<void> downloadFile(Uint8List bytes, String filename,
      {String? mimeType}) {
    throw UnimplementedError('Platform not supported');
  }

  @override
  Future<Uint8List?> readFileAsBytes(dynamic file) {
    throw UnimplementedError('Platform not supported');
  }
}

FileUtils getFileUtils() => FileUtilsImpl();
