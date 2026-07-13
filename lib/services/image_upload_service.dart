// lib/services/image_upload_service.dart - WEB & MOBILE COMPATIBLE

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageUploadService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  /// Pick image from camera (MOBILE ONLY)
  Future<File?> pickImageFromCamera() async {
    if (kIsWeb) {
      print('⚠️ Camera not supported on web');
      return null;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image != null) {
        print('📷 Image captured: ${image.path}');
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('❌ Error picking image from camera: $e');
      rethrow;
    }
  }

  /// Pick image from gallery (WEB & MOBILE)
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image != null) {
        print('🖼️ Image selected: ${image.path}');
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('❌ Error picking image from gallery: $e');
      rethrow;
    }
  }

  /// Upload image to Supabase Storage (WEB & MOBILE COMPATIBLE)
  Future<Map<String, dynamic>?> uploadImageToSupabase({
    required File imageFile,
    required String userId,
  }) async {
    try {
      print('📤 Uploading image to Supabase...');

      // Generate unique filename
      final uuid = const Uuid().v4();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Get file extension
      String extension = '.jpg';
      String originalFileName = '';

      if (kIsWeb) {
        // On web, imageFile.path is a blob URL like: blob:http://localhost/...
        // We need to extract filename differently
        originalFileName = imageFile.path.split('/').last;

        // Try to get extension from the blob URL or default to .jpg
        if (originalFileName.contains('.')) {
          extension = '.${originalFileName.split('.').last}';
        }
      } else {
        // On mobile, we can use path package
        extension = path.extension(imageFile.path);
        originalFileName = path.basename(imageFile.path);
      }

      final fileName = 'fuel_receipt_${userId}_${timestamp}_$uuid$extension';
      final filePath = 'fuel-receipts/$fileName';

      // Read file as bytes (works on both web and mobile)
      Uint8List imageBytes;
      int fileSize;

      if (kIsWeb) {
        // On web, we need to read bytes from XFile
        final xFile = XFile(imageFile.path);
        imageBytes = await xFile.readAsBytes();
        fileSize = imageBytes.length;
      } else {
        // On mobile, read from File
        imageBytes = await imageFile.readAsBytes();
        fileSize = imageBytes.length;
      }

      print('📦 File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      // Determine MIME type
      final mimeType = _getMimeType(extension);

      // Upload to Supabase Storage using uploadBinary (works on web and mobile)
      await _supabase.storage.from('fuel-images').uploadBinary(
            filePath,
            imageBytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              cacheControl: '3600',
              upsert: false,
            ),
          );

      // Get public URL
      final publicUrl =
          _supabase.storage.from('fuel-images').getPublicUrl(filePath);

      print('✅ Image uploaded successfully');
      print('📍 URL: $publicUrl');

      return {
        'image_url': publicUrl,
        'image_name': fileName,
        'image_size': fileSize,
        'mime_type': mimeType,
      };
    } catch (e) {
      print('❌ Error uploading image: $e');
      print('Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Save image locally for offline use (MOBILE ONLY)
  Future<Map<String, dynamic>?> saveImageLocally({
    required File imageFile,
    required String userId,
  }) async {
    if (kIsWeb) {
      print('⚠️ Local storage not supported on web');
      return null;
    }

    try {
      print('💾 Saving image locally...');

      // Get app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final localImagesDir = Directory('${appDir.path}/fuel_images');

      // Create directory if it doesn't exist
      if (!await localImagesDir.exists()) {
        await localImagesDir.create(recursive: true);
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(imageFile.path);
      final fileName = 'fuel_receipt_${userId}_$timestamp$extension';
      final localPath = '${localImagesDir.path}/$fileName';

      // Copy file to local storage
      final savedFile = await imageFile.copy(localPath);
      final fileSize = await savedFile.length();

      print('✅ Image saved locally: $localPath');

      return {
        'image_url': localPath, // Local path for offline
        'image_name': fileName,
        'image_size': fileSize,
        'mime_type': _getMimeType(extension),
      };
    } catch (e) {
      print('❌ Error saving image locally: $e');
      return null;
    }
  }

  /// Upload local image when online (MOBILE ONLY)
  Future<Map<String, dynamic>?> uploadLocalImage({
    required String localPath,
    required String userId,
  }) async {
    if (kIsWeb) {
      print('⚠️ Local image upload not supported on web');
      return null;
    }

    try {
      final file = File(localPath);
      if (!await file.exists()) {
        print('❌ Local image file not found: $localPath');
        return null;
      }

      return await uploadImageToSupabase(
        imageFile: file,
        userId: userId,
      );
    } catch (e) {
      print('❌ Error uploading local image: $e');
      return null;
    }
  }

  /// Delete image from Supabase Storage (WEB & MOBILE)
  Future<bool> deleteImageFromSupabase(String imageUrl) async {
    try {
      // Extract file path from URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      // Find 'fuel-images' bucket in the path
      final bucketIndex = pathSegments.indexOf('fuel-images');

      if (bucketIndex == -1) {
        print('❌ Invalid image URL format: $imageUrl');
        return false;
      }

      // Get the file path after the bucket name
      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');

      await _supabase.storage.from('fuel-images').remove([filePath]);
      print('✅ Image deleted from Supabase: $filePath');
      return true;
    } catch (e) {
      print('❌ Error deleting image: $e');
      return false;
    }
  }

  /// Delete local image (MOBILE ONLY)
  Future<bool> deleteLocalImage(String localPath) async {
    if (kIsWeb) {
      print('⚠️ Local image deletion not supported on web');
      return false;
    }

    try {
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
        print('✅ Local image deleted: $localPath');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error deleting local image: $e');
      return false;
    }
  }

  /// Get MIME type from extension
  String _getMimeType(String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'image/jpeg';
    }
  }

  /// Get file size in human-readable format
  String getFileSizeString(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  /// Validate image file
  Future<Map<String, dynamic>> validateImage(File imageFile) async {
    try {
      // Read file size
      int fileSize;
      if (kIsWeb) {
        final xFile = XFile(imageFile.path);
        final bytes = await xFile.readAsBytes();
        fileSize = bytes.length;
      } else {
        fileSize = await imageFile.length();
      }

      // Check file size (max 10MB)
      const maxSize = 10 * 1024 * 1024; // 10MB
      if (fileSize > maxSize) {
        return {
          'valid': false,
          'error': 'حجم الصورة كبير جداً. الحد الأقصى 10 ميجابايت',
        };
      }

      // Check file type
      String extension;
      if (kIsWeb) {
        final fileName = imageFile.path.split('/').last;
        extension =
            fileName.contains('.') ? '.${fileName.split('.').last}' : '.jpg';
      } else {
        extension = path.extension(imageFile.path);
      }

      final validExtensions = [
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.webp',
        '.heic',
        '.heif'
      ];
      if (!validExtensions.contains(extension.toLowerCase())) {
        return {
          'valid': false,
          'error':
              'صيغة الصورة غير مدعومة. الصيغ المدعومة: JPG, PNG, GIF, WEBP',
        };
      }

      return {
        'valid': true,
        'size': fileSize,
        'extension': extension,
      };
    } catch (e) {
      print('❌ Error validating image: $e');
      return {
        'valid': false,
        'error': 'فشل التحقق من الصورة: $e',
      };
    }
  }

  /// Compress image if needed (MOBILE ONLY - web images are already compressed by browser)
  Future<File?> compressImageIfNeeded(File imageFile,
      {int maxSizeKB = 500}) async {
    if (kIsWeb) {
      // Web images are already compressed by the browser
      return imageFile;
    }

    try {
      final fileSize = await imageFile.length();
      final fileSizeKB = fileSize / 1024;

      if (fileSizeKB <= maxSizeKB) {
        print('✅ Image size OK: ${fileSizeKB.toStringAsFixed(2)} KB');
        return imageFile;
      }

      print(
          '⚠️ Image too large: ${fileSizeKB.toStringAsFixed(2)} KB, needs compression');

      // For now, just return the original file
      // You can add image compression library like flutter_image_compress here
      return imageFile;
    } catch (e) {
      print('❌ Error compressing image: $e');
      return imageFile;
    }
  }

  /// Get image metadata
  Future<Map<String, dynamic>?> getImageMetadata(File imageFile) async {
    try {
      int fileSize;
      String fileName;
      String extension;

      if (kIsWeb) {
        final xFile = XFile(imageFile.path);
        final bytes = await xFile.readAsBytes();
        fileSize = bytes.length;
        fileName = imageFile.path.split('/').last;
        extension =
            fileName.contains('.') ? '.${fileName.split('.').last}' : '.jpg';
      } else {
        fileSize = await imageFile.length();
        fileName = path.basename(imageFile.path);
        extension = path.extension(imageFile.path);
      }

      return {
        'fileName': fileName,
        'fileSize': fileSize,
        'fileSizeString': getFileSizeString(fileSize),
        'extension': extension,
        'mimeType': _getMimeType(extension),
        'isWeb': kIsWeb,
      };
    } catch (e) {
      print('❌ Error getting image metadata: $e');
      return null;
    }
  }
}
