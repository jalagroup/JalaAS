// lib/utils/image_storage_helper.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageStorageHelper {
  /// Convert image file to Base64 string for storage
  static Future<String> fileToBase64(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      print('Error converting file to Base64: $e');
      rethrow;
    }
  }

  /// Convert Base64 string back to bytes
  static Uint8List base64ToBytes(String base64String) {
    try {
      return base64Decode(base64String);
    } catch (e) {
      print('Error converting Base64 to bytes: $e');
      rethrow;
    }
  }

  /// Process formData to convert all image files to Base64
  /// This should be called BEFORE storing in offline queue
  static Future<Map<String, dynamic>> prepareFormDataForOffline(
    Map<String, dynamic> formData,
  ) async {
    final processedData = Map<String, dynamic>.from(formData);

    // Process images if they exist
    if (formData['images'] != null) {
      final images = formData['images'];

      if (images is List) {
        final base64Images = <Map<String, dynamic>>[];

        for (var image in images) {
          if (image is File) {
            // Convert File to Base64
            try {
              final base64String = await fileToBase64(image);
              final fileName = image.path.split('/').last;

              base64Images.add({
                'data': base64String,
                'fileName': fileName,
                'mimeType': _getMimeType(fileName),
              });

              print('Converted image to Base64: $fileName');
            } catch (e) {
              print('Failed to convert image: $e');
            }
          } else if (image is Map<String, dynamic>) {
            // Already in correct format (from previous queue)
            base64Images.add(image);
          } else if (image is String && image.startsWith('/')) {
            // File path string - convert to Base64
            try {
              final file = File(image);
              if (await file.exists()) {
                final base64String = await fileToBase64(file);
                final fileName = image.split('/').last;

                base64Images.add({
                  'data': base64String,
                  'fileName': fileName,
                  'mimeType': _getMimeType(fileName),
                });

                print('Converted file path to Base64: $fileName');
              }
            } catch (e) {
              print('Failed to convert file path: $e');
            }
          }
        }

        processedData['images'] = base64Images;
        print('Processed ${base64Images.length} images for offline storage');
      }
    }

    // Process single image if exists
    if (formData['image'] != null) {
      final image = formData['image'];

      if (image is File) {
        try {
          final base64String = await fileToBase64(image);
          final fileName = image.path.split('/').last;

          processedData['image'] = {
            'data': base64String,
            'fileName': fileName,
            'mimeType': _getMimeType(fileName),
          };

          print('Converted single image to Base64: $fileName');
        } catch (e) {
          print('Failed to convert single image: $e');
        }
      } else if (image is String && image.startsWith('/')) {
        try {
          final file = File(image);
          if (await file.exists()) {
            final base64String = await fileToBase64(file);
            final fileName = image.split('/').last;

            processedData['image'] = {
              'data': base64String,
              'fileName': fileName,
              'mimeType': _getMimeType(fileName),
            };
          }
        } catch (e) {
          print('Failed to convert single image path: $e');
        }
      }
    }

    return processedData;
  }

  /// Restore images from Base64 format and upload to Supabase Storage
  static Future<Map<String, dynamic>> restoreFormDataFromOffline(
    Map<String, dynamic> formData,
  ) async {
    final restoredData = Map<String, dynamic>.from(formData);

    try {
      final supabase = Supabase.instance.client;

      // Restore images list and upload to Supabase
      if (formData['images'] != null && formData['images'] is List) {
        final images = formData['images'] as List;
        final restoredImages = <String>[]; // Changed to List<String> for URLs

        for (var i = 0; i < images.length; i++) {
          final image = images[i];
          if (image is Map<String, dynamic> && image['data'] != null) {
            try {
              // Convert Base64 to bytes
              final bytes = base64ToBytes(image['data'] as String);
              print('Restored image bytes: ${bytes.length} bytes');

              // Generate unique filename
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              final fileName =
                  image['fileName'] as String? ?? 'image_${i}_$timestamp.jpg';
              final uniqueFileName = '${timestamp}_$fileName';

              print('Uploading image to Supabase: $uniqueFileName');

              // Upload to Supabase Storage
              await supabase.storage.from('contact-images').uploadBinary(
                    uniqueFileName,
                    bytes,
                    fileOptions: const FileOptions(
                      contentType: 'image/jpeg',
                      upsert: false,
                    ),
                  );

              // Get public URL
              final imageUrl = supabase.storage
                  .from('contact-images')
                  .getPublicUrl(uniqueFileName);

              restoredImages.add(imageUrl);
              print('Image uploaded successfully: $imageUrl');
            } catch (e) {
              print('Failed to upload image ${i}: $e');
              throw Exception('Failed to upload image to Supabase Storage: $e');
            }
          }
        }

        restoredData['images'] = restoredImages;
        print('Uploaded and restored ${restoredImages.length} images');
      }

      // Restore single image and upload to Supabase
      if (formData['image'] != null &&
          formData['image'] is Map<String, dynamic>) {
        final image = formData['image'] as Map<String, dynamic>;
        if (image['data'] != null) {
          try {
            // Convert Base64 to bytes
            final bytes = base64ToBytes(image['data'] as String);
            print('Restored single image bytes: ${bytes.length} bytes');

            // Generate unique filename
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final fileName =
                image['fileName'] as String? ?? 'single_image_$timestamp.jpg';
            final uniqueFileName = '${timestamp}_$fileName';

            print('Uploading single image to Supabase: $uniqueFileName');

            // Upload to Supabase Storage
            await supabase.storage.from('contact-images').uploadBinary(
                  uniqueFileName,
                  bytes,
                  fileOptions: const FileOptions(
                    contentType: 'image/jpeg',
                    upsert: false,
                  ),
                );

            // Get public URL
            final imageUrl = supabase.storage
                .from('contact-images')
                .getPublicUrl(uniqueFileName);

            restoredData['image'] = imageUrl;
            print('Single image uploaded successfully: $imageUrl');
          } catch (e) {
            print('Failed to upload single image: $e');
            throw Exception(
                'Failed to upload single image to Supabase Storage: $e');
          }
        }
      }

      // Process any other image fields dynamically
      for (final key in formData.keys) {
        if (key == 'images' || key == 'image') continue; // Already processed

        final value = formData[key];

        // Check if this is an image field (Map with 'data' key)
        if (value is Map<String, dynamic> && value['data'] != null) {
          try {
            // Convert Base64 to bytes
            final bytes = base64ToBytes(value['data'] as String);
            print('Restored $key image bytes: ${bytes.length} bytes');

            // Generate unique filename
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final fileName =
                value['fileName'] as String? ?? '${key}_$timestamp.jpg';
            final uniqueFileName = '${timestamp}_$fileName';

            print('Uploading $key to Supabase: $uniqueFileName');

            // Upload to Supabase Storage
            await supabase.storage.from('contact-images').uploadBinary(
                  uniqueFileName,
                  bytes,
                  fileOptions: const FileOptions(
                    contentType: 'image/jpeg',
                    upsert: false,
                  ),
                );

            // Get public URL
            final imageUrl = supabase.storage
                .from('contact-images')
                .getPublicUrl(uniqueFileName);

            restoredData[key] = imageUrl;
            print('$key uploaded successfully: $imageUrl');
          } catch (e) {
            print('Failed to upload $key: $e');
            throw Exception('Failed to upload $key to Supabase Storage: $e');
          }
        }
      }

      print('All images restored and uploaded to Supabase Storage');
      return restoredData;
    } catch (e) {
      print('Error in restoreFormDataFromOffline: $e');
      throw Exception('Failed to restore and upload images: $e');
    }
  }

  /// Get MIME type from file name
  static String _getMimeType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
