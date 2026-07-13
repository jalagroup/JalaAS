// lib/utils/file_saver.dart

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

class FileSaver {
  static Future<void> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (kIsWeb) {
      // Web implementation
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // Mobile implementation would go here
      // For now, throw an error as we're focusing on web
      throw UnsupportedError('File saving not implemented for mobile yet');
    }
  }
}
