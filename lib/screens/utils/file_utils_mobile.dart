// lib/utils/file_utils_mobile.dart

import 'dart:typed_data';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'file_utils.dart';

class FileUtilsImpl extends FileUtils {
  final ImagePicker _picker = ImagePicker();

  @override
  Future<List<Uint8List>> pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85,
      );

      List<Uint8List> result = [];
      for (var image in images) {
        final bytes = await image.readAsBytes();
        result.add(bytes);
      }
      return result;
    } catch (e) {
      print('Error picking images: $e');
      return [];
    }
  }

  @override
  Future<Uint8List?> pickSingleImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return null;
      return await image.readAsBytes();
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  @override
  Future<void> downloadFile(Uint8List bytes, String filename,
      {String? mimeType}) async {
    try {
      Directory? directory;

      if (Platform.isAndroid) {
        // Request storage permission on Android
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            print('Storage permission denied');
            return;
          }
        }

        // Try to get external storage directory
        directory = await getExternalStorageDirectory();

        // Fallback to app documents directory
        directory ??= await getApplicationDocumentsDirectory();
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(bytes);

      print('File saved to: ${file.path}');
      // You might want to show a toast or snackbar here
    } catch (e) {
      print('Error saving file: $e');
    }
  }

  @override
  Future<Uint8List?> readFileAsBytes(dynamic file) async {
    if (file is XFile) {
      return await file.readAsBytes();
    } else if (file is File) {
      return await file.readAsBytes();
    } else if (file is String) {
      final f = File(file);
      if (await f.exists()) {
        return await f.readAsBytes();
      }
    }
    return null;
  }
}

FileUtils getFileUtils() => FileUtilsImpl();
