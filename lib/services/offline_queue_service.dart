// lib/services/offline_queue_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data'; // ADD THIS
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:jala_as/screens/utils/image_storage_helper.dart';
import 'local_database_service.dart';
import '../utils/platform_utils.dart';

class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  final LocalDatabaseService _localDb = LocalDatabaseService();
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isProcessing = false;
  bool _isOnline = false;

  // Callback for executing operations
  Future<bool> Function(
    String endpoint,
    String method,
    Map<String, dynamic> data,
  )? onExecuteOperation;

  // NEW: Callbacks for PDF and email
  Future<Uint8List> Function(String contactCode, Map<String, dynamic> formData)?
      onGeneratePdf;
  Future<void> Function(String contactCode, Uint8List pdfBytes,
      Map<String, dynamic> formData)? onSendEmail; // UPDATED

  // NEW: Callback to show errors to user
  void Function(List<Map<String, dynamic>> errors)? onSyncErrors;

  // NEW: Callback for getting contact code from API response
  String Function(Map<String, dynamic> apiBody, dynamic response)?
      onGetContactCode;

  Future<void> initialize({
    required Future<bool> Function(
      String endpoint,
      String method,
      Map<String, dynamic> data,
    ) executeOperation,
    Future<Uint8List> Function(
      String contactCode,
      Map<String, dynamic> formData,
    )? generatePdf,
    Future<void> Function(String contactCode, Uint8List pdfBytes,
            Map<String, dynamic> formData)?
        sendEmail, // UPDATED signature
    void Function(List<Map<String, dynamic>> errors)? onErrors,
    String Function(Map<String, dynamic> apiBody, dynamic response)?
        getContactCode,
  }) async {
    if (!PlatformUtils.isMobile) return;

    onExecuteOperation = executeOperation;
    onGeneratePdf = generatePdf;
    onSendEmail = sendEmail;
    onSyncErrors = onErrors;
    onGetContactCode = getContactCode;
    // Check initial connectivity
    _isOnline = await _checkConnectivity();

    // Listen to connectivity changes
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      _handleConnectivityChange(results);
    });

    // Process pending operations if online
    if (_isOnline) {
      await processPendingOperations();
    }
  }

  /// Check if device is connected to internet
  Future<bool> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.isNotEmpty &&
          results.any((result) =>
              result == ConnectivityResult.mobile ||
              result == ConnectivityResult.wifi ||
              result == ConnectivityResult.ethernet);
    } catch (e) {
      print('Error checking connectivity: $e');
      return false;
    }
  }

  /// Handle connectivity changes
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.isNotEmpty &&
        results.any((result) =>
            result == ConnectivityResult.mobile ||
            result == ConnectivityResult.wifi ||
            result == ConnectivityResult.ethernet);

    print(
        'Connectivity changed: ${wasOnline ? "online" : "offline"} -> ${_isOnline ? "online" : "offline"}');

    // If we just came online, process pending operations automatically
    if (!wasOnline && _isOnline) {
      print('Device is now online - auto-syncing pending operations');
      processPendingOperations();
    }
  }

  /// Add operation to offline queue - UPDATED
  Future<void> addOperation({
    required String operationType,
    required String endpoint,
    required String method,
    required Map<String, dynamic> data,
    required String userId,
  }) async {
    if (!PlatformUtils.isMobile) {
      throw Exception('Offline queue is only available on mobile');
    }

    // CRITICAL: Process images before storing
    final processedData = Map<String, dynamic>.from(data);

    // If formData exists, prepare it for offline storage
    if (processedData['_formData'] != null) {
      print('Processing formData for offline storage...');
      final formData = processedData['_formData'] as Map<String, dynamic>;

      // Convert all image files to Base64
      final preparedFormData =
          await ImageStorageHelper.prepareFormDataForOffline(formData);
      processedData['_formData'] = preparedFormData;

      print('FormData prepared with images converted to Base64');
    }

    await _localDb.addPendingOperation(
      operationType: operationType,
      endpoint: endpoint,
      method: method,
      data: processedData, // Store processed data with Base64 images
      userId: userId,
    );

    print('Added operation to queue: $operationType - $endpoint');

    // Try to process immediately if online
    if (_isOnline && !_isProcessing) {
      await processPendingOperations();
    }
  }

  /// Process all pending operations with image upload to Supabase Storage - UPDATED
  Future<void> processPendingOperations() async {
    if (!PlatformUtils.isMobile) return;
    if (_isProcessing) {
      print('Already processing operations');
      return;
    }
    if (!_isOnline) {
      print('Device is offline - skipping operation processing');
      return;
    }
    if (onExecuteOperation == null) {
      print('No execute operation callback set');
      return;
    }

    _isProcessing = true;

    final errors = <Map<String, dynamic>>[];

    try {
      final operations = await _localDb.getPendingOperations();
      print('Processing ${operations.length} pending operations');

      for (final operation in operations) {
        final operationId = operation['id'] as int;
        final endpoint = operation['endpoint'] as String;
        final method = operation['method'] as String;
        final dataJson = operation['data'] as String;
        final retryCount = operation['retry_count'] as int;

        // Skip if too many retries
        if (retryCount >= 5) {
          print(
              'Operation $operationId exceeded retry limit - marking as failed');

          final errorData = {
            'operationId': operationId,
            'error': 'تجاوز الحد الأقصى لمحاولات إعادة الإرسال',
            'data': dataJson,
          };
          errors.add(errorData);

          await _localDb.updateOperationStatus(
            operationId: operationId,
            status: 'failed',
            errorMessage: 'Exceeded maximum retry attempts',
          );
          continue;
        }

        try {
          // Parse data
          final data = jsonDecode(dataJson) as Map<String, dynamic>;

          // Extract API body and form data
          final apiBody = Map<String, dynamic>.from(data);
          final formData = apiBody.remove('_formData') as Map<String, dynamic>?;

          print('Executing operation $operationId: $method $endpoint');
          print('API Body keys: ${apiBody.keys.toList()}');
          print('Has formData: ${formData != null}');

          // Step 1: Upload images to Supabase and restore formData with URLs
          Map<String, dynamic>? restoredFormData;
          bool imagesUploadedSuccessfully = false;

          if (formData != null) {
            print(
                'Operation $operationId: Uploading images to Supabase Storage');

            try {
              // Check if images exist in formData
              if (formData['images'] != null &&
                  (formData['images'] as List).isNotEmpty) {
                print(
                    'Operation $operationId: Found ${(formData['images'] as List).length} images to upload');

                restoredFormData =
                    await ImageStorageHelper.restoreFormDataFromOffline(
                        formData);
                imagesUploadedSuccessfully = true;
                print('Operation $operationId: Images uploaded successfully');
                print(
                    'Restored formData keys: ${restoredFormData.keys.toList()}');
              } else {
                print('Operation $operationId: No images to upload');
                restoredFormData = Map<String, dynamic>.from(formData);
                restoredFormData.remove('images');
              }
            } catch (imageError) {
              print(
                  '⚠️ Operation $operationId: Failed to upload images: $imageError');

              // Check if it's a bucket not found error
              final errorString = imageError.toString().toLowerCase();
              if (errorString.contains('bucket not found') ||
                  errorString.contains('404')) {
                print(
                    '❌ CRITICAL: Supabase Storage bucket "new-customer-images" does not exist!');
                print('📋 Please create the bucket in Supabase Dashboard:');
                print('   1. Go to Storage in Supabase');
                print('   2. Create bucket: new-customer-images');
                print('   3. Make it public');

                // FAIL the operation - don't continue without images
                final errorData = {
                  'operationId': operationId,
                  'error': 'فشل في رفع الصور - المخزن غير موجود في Supabase',
                  'data': dataJson,
                  'technicalError': imageError.toString(),
                };
                errors.add(errorData);

                await _localDb.incrementRetryCount(operationId);
                await _localDb.updateOperationStatus(
                  operationId: operationId,
                  status: 'pending',
                  errorMessage: 'Bucket not found: new-customer-images',
                );

                continue; // Skip this operation
              }

              // Other errors - also fail
              print(
                  '❌ Operation $operationId: Image upload failed - skipping operation');

              final errorData = {
                'operationId': operationId,
                'error': 'فشل في رفع الصور: ${imageError.toString()}',
                'data': dataJson,
              };
              errors.add(errorData);

              await _localDb.incrementRetryCount(operationId);
              await _localDb.updateOperationStatus(
                operationId: operationId,
                status: 'pending',
                errorMessage: imageError.toString(),
              );

              continue; // Skip this operation
            }
          }

// Step 2: Execute operation (create contact) ONLY if images uploaded successfully
          final success = await onExecuteOperation!(endpoint, method, apiBody);

          if (success) {
            print('Operation $operationId: Contact created successfully');

            // Step 3: Generate PDF and send email with images
            if (restoredFormData != null &&
                onGeneratePdf != null &&
                onSendEmail != null) {
              try {
                print('Operation $operationId: Generating PDF');

                String contactCode;
                if (onGetContactCode != null) {
                  contactCode = onGetContactCode!(apiBody, null);
                } else {
                  contactCode = apiBody['TRANSACTION_ID'] as String? ??
                      DateTime.now().millisecondsSinceEpoch.toString();
                }

                print('Operation $operationId: Contact code: $contactCode');

                // Generate PDF
                final pdfBytes =
                    await onGeneratePdf!(contactCode, restoredFormData);
                print(
                    'Operation $operationId: PDF generated (${pdfBytes.length} bytes)');

                // Send email with images
                print(
                    'Operation $operationId: Sending email${imagesUploadedSuccessfully ? " with images" : ""}');
                await onSendEmail!(contactCode, pdfBytes, restoredFormData);
                print('Operation $operationId: Email sent successfully');
              } catch (pdfError) {
                print('Operation $operationId: Error in PDF/email: $pdfError');
                // Don't fail the whole operation if PDF/email fails
              }
            }

            // Mark as completed
            await _localDb.updateOperationStatus(
              operationId: operationId,
              status: 'completed',
            );
            await _localDb.deleteOperation(operationId);
            print('✓ Operation $operationId completed successfully');
          } else {
            print('Operation $operationId: API call returned false');

            final errorData = {
              'operationId': operationId,
              'error': 'فشل في إنشاء العميل',
              'data': dataJson,
            };
            errors.add(errorData);

            await _localDb.incrementRetryCount(operationId);
            print('Operation $operationId failed - will retry later');
          }
        } catch (e) {
          print('Error executing operation $operationId: $e');

          final errorData = {
            'operationId': operationId,
            'error': e.toString(),
            'data': dataJson,
          };
          errors.add(errorData);

          await _localDb.incrementRetryCount(operationId);
          await _localDb.updateOperationStatus(
            operationId: operationId,
            status: 'pending',
            errorMessage: e.toString(),
          );
        }

        // Small delay between operations
        await Future.delayed(const Duration(milliseconds: 500));
      }

      print('Finished processing pending operations');

      // Show errors to user if any occurred
      if (errors.isNotEmpty && onSyncErrors != null) {
        print('Showing ${errors.length} errors to user');
        onSyncErrors!(errors);
      }
    } catch (e) {
      print('Error processing pending operations: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Get count of pending operations
  Future<int> getPendingCount() async {
    if (!PlatformUtils.isMobile) return 0;
    return await _localDb.getOperationCount(status: 'pending');
  }

  /// Get all pending operations (for UI display)
  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    if (!PlatformUtils.isMobile) return [];
    return await _localDb.getPendingOperations();
  }

  /// Clear all pending operations
  Future<void> clearAllOperations() async {
    if (!PlatformUtils.isMobile) return;
    await _localDb.clearCompletedOperations();
  }

  /// Check if online
  bool get isOnline => _isOnline;

  /// Check if currently processing
  bool get isProcessing => _isProcessing;

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
