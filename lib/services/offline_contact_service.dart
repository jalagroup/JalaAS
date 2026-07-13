// lib/services/offline_contact_service.dart
// Service to handle offline contact creation with sync and error management

import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_database_service.dart';
import '../utils/platform_utils.dart';

class OfflineContactService {
  static final OfflineContactService _instance =
      OfflineContactService._internal();
  factory OfflineContactService() => _instance;
  OfflineContactService._internal();

  final LocalDatabaseService _dbService = LocalDatabaseService();
  EnhancedLocalDatabaseOperations? _enhancedOps;

  /// Initialize enhanced operations
  Future<void> initialize() async {
    if (PlatformUtils.isMobile) {
      final db = await _dbService.database;
      _enhancedOps = EnhancedLocalDatabaseOperations(db);
    }
  }

  Future<int> addPendingContactOperation({
    required Map<String, dynamic> contactData,
    required String userId,
  }) async {
    if (_enhancedOps == null) {
      await initialize();
    }

    // CRITICAL VALIDATION: Ensure record is a Map before storing
    if (contactData['record'] != null) {
      if (contactData['record'] is! Map<String, dynamic>) {
        print('ERROR: record is not a Map!');
        print('Type: ${contactData['record'].runtimeType}');
        print('Value: ${contactData['record']}');
        throw Exception('Invalid data structure: record must be a Map');
      }
    }

    print('DEBUG: Storing contact data in queue');
    print('DEBUG: Record type: ${contactData['record'].runtimeType}');
    print('DEBUG: Full data: ${jsonEncode(contactData)}');

    return await _enhancedOps!.addPendingContactOperation(
      contactData: contactData,
      userId: userId,
    );
  }

  /// Check if device has internet connectivity
  Future<bool> hasConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  /// Create contact with offline support
  /// Returns: {
  ///   'success': bool,
  ///   'data': Map<String, dynamic>?,
  ///   'pendingId': int?, // If queued for offline
  ///   'message': String,
  /// }
  Future<Map<String, dynamic>> createContact({
    required Map<String, dynamic> contactData,
    required String userId,
    required Future<Map<String, dynamic>> Function(Map<String, dynamic>)
        apiCreateFunction,
  }) async {
    // Check connectivity
    final isOnline = await hasConnectivity();

    if (!isOnline && PlatformUtils.isMobile) {
      // Queue for offline processing
      return await _queueContactForOffline(
        contactData: contactData,
        userId: userId,
      );
    }

    // Try to create contact online
    try {
      final response = await apiCreateFunction(contactData);
      return {
        'success': true,
        'data': response,
        'message': 'تم إنشاء العميل بنجاح',
      };
    } catch (e) {
      // If online but failed, queue for retry if on mobile
      if (PlatformUtils.isMobile) {
        return await _queueContactForOffline(
          contactData: contactData,
          userId: userId,
          error: e.toString(),
        );
      }

      // If web, just return error
      return {
        'success': false,
        'message': 'فشل إنشاء العميل: ${e.toString()}',
      };
    }
  }

  /// Queue contact for offline processing
  Future<Map<String, dynamic>> _queueContactForOffline({
    required Map<String, dynamic> contactData,
    required String userId,
    String? error,
  }) async {
    if (_enhancedOps == null) {
      await initialize();
    }

    final pendingId = await _enhancedOps!.addPendingContactOperation(
      contactData: contactData,
      userId: userId,
    );

    return {
      'success': true,
      'pendingId': pendingId,
      'message': error != null
          ? 'تم حفظ العميل للمزامنة لاحقاً بسبب خطأ في الاتصال'
          : 'تم حفظ العميل للمزامنة عند توفر الاتصال',
      'isQueued': true,
    };
  }

  /// Sync all pending contact operations
  /// Returns list of results with success/failure info
  Future<List<ContactSyncResult>> syncPendingContacts({
    required Future<Map<String, dynamic>> Function(Map<String, dynamic>)
        apiCreateFunction,
  }) async {
    if (_enhancedOps == null) {
      await initialize();
    }

    final results = <ContactSyncResult>[];
    final pendingOps = await _enhancedOps!.getPendingContactOperations();

    if (pendingOps.isEmpty) {
      return results;
    }

    // Check connectivity first
    final isOnline = await hasConnectivity();
    if (!isOnline) {
      return [
        ContactSyncResult(
          success: false,
          message: 'لا يوجد اتصال بالإنترنت',
          totalPending: pendingOps.length,
        ),
      ];
    }

    // Process each pending operation
    for (final operation in pendingOps) {
      try {
        // Attempt to create contact
        final response = await apiCreateFunction(operation.contactData);

        // Mark as completed
        await _enhancedOps!.markOperationCompleted(operation.id!);

        results.add(ContactSyncResult(
          success: true,
          operationId: operation.id,
          contactData: operation.contactData,
          response: response,
          message: 'تم إنشاء العميل بنجاح',
        ));
      } catch (e) {
        // Extract error details
        final errorInfo = _parseError(e);

        // Update operation with error
        await _enhancedOps!.updateOperationError(
          operationId: operation.id!,
          errorMessage: errorInfo['message'],
        );

        // Increment retry count
        await _enhancedOps!.incrementRetryCount(operation.id!);

        results.add(ContactSyncResult(
          success: false,
          operationId: operation.id,
          contactData: operation.contactData,
          error: errorInfo['message'],
          errorDetails: errorInfo['details'],
          errorCode: errorInfo['code'],
          message: 'فشل إنشاء العميل: ${errorInfo['message']}',
        ));
      }
    }

    return results;
  }

  /// Get all pending and failed operations for user review
  Future<List<PendingContactOperation>> getPendingOperations() async {
    if (_enhancedOps == null) {
      await initialize();
    }

    return await _enhancedOps!.getPendingContactOperations();
  }

  /// Get failed operations
  Future<List<PendingContactOperation>> getFailedOperations() async {
    if (_enhancedOps == null) {
      await initialize();
    }

    return await _enhancedOps!.getFailedContactOperations();
  }

  /// Get counts of pending/failed operations
  Future<Map<String, int>> getOperationCounts() async {
    if (_enhancedOps == null) {
      await initialize();
    }

    return await _enhancedOps!.getOperationCounts();
  }

  /// Update contact data for a pending operation
  Future<bool> updatePendingContactData({
    required int operationId,
    required Map<String, dynamic> newContactData,
  }) async {
    if (_enhancedOps == null) {
      await initialize();
    }

    try {
      await _enhancedOps!.updateOperationData(
        operationId: operationId,
        newContactData: newContactData,
      );
      return true;
    } catch (e) {
      print('Error updating pending contact: $e');
      return false;
    }
  }

  /// Delete a pending operation
  Future<bool> deletePendingOperation(int operationId) async {
    if (_enhancedOps == null) {
      await initialize();
    }

    try {
      await _enhancedOps!.deletePendingOperation(operationId);
      return true;
    } catch (e) {
      print('Error deleting pending operation: $e');
      return false;
    }
  }

  /// Retry a specific failed operation
  Future<ContactSyncResult> retryFailedOperation({
    required int operationId,
    required Future<Map<String, dynamic>> Function(Map<String, dynamic>)
        apiCreateFunction,
  }) async {
    if (_enhancedOps == null) {
      await initialize();
    }

    // Get operation
    final operation = await _enhancedOps!.getPendingOperationById(operationId);
    if (operation == null) {
      return ContactSyncResult(
        success: false,
        operationId: operationId,
        message: 'العملية غير موجودة',
      );
    }

    // Check connectivity
    final isOnline = await hasConnectivity();
    if (!isOnline) {
      return ContactSyncResult(
        success: false,
        operationId: operationId,
        message: 'لا يوجد اتصال بالإنترنت',
      );
    }

    // Reset to pending and try again
    await _enhancedOps!.resetOperationToPending(operationId);

    try {
      final response = await apiCreateFunction(operation.contactData);
      await _enhancedOps!.markOperationCompleted(operationId);

      return ContactSyncResult(
        success: true,
        operationId: operationId,
        contactData: operation.contactData,
        response: response,
        message: 'تم إنشاء العميل بنجاح',
      );
    } catch (e) {
      final errorInfo = _parseError(e);

      await _enhancedOps!.updateOperationError(
        operationId: operationId,
        errorMessage: errorInfo['message'],
      );

      await _enhancedOps!.incrementRetryCount(operationId);

      return ContactSyncResult(
        success: false,
        operationId: operationId,
        contactData: operation.contactData,
        error: errorInfo['message'],
        errorDetails: errorInfo['details'],
        errorCode: errorInfo['code'],
        message: 'فشل إنشاء العميل: ${errorInfo['message']}',
      );
    }
  }

  /// Parse error to extract useful information
  Map<String, dynamic> _parseError(dynamic error) {
    String message = error.toString();
    String? details;
    int? code;

    // Try to parse if it's a JSON error response
    try {
      if (error is Map) {
        message = error['message']?.toString() ?? message;
        details = error['details']?.toString();
        code = error['code'] as int?;
      } else if (message.contains('{')) {
        final jsonStart = message.indexOf('{');
        final jsonStr = message.substring(jsonStart);
        final errorJson = jsonDecode(jsonStr);
        message = errorJson['message']?.toString() ?? message;
        details = errorJson['details']?.toString();
        code = errorJson['code'] as int?;
      }
    } catch (e) {
      // Keep original message if parsing fails
    }

    return {
      'message': message,
      'details': details,
      'code': code,
    };
  }
}

/// Result object for sync operations
class ContactSyncResult {
  final bool success;
  final int? operationId;
  final Map<String, dynamic>? contactData;
  final Map<String, dynamic>? response;
  final String? error;
  final String? errorDetails;
  final int? errorCode;
  final String message;
  final int? totalPending;

  ContactSyncResult({
    required this.success,
    this.operationId,
    this.contactData,
    this.response,
    this.error,
    this.errorDetails,
    this.errorCode,
    required this.message,
    this.totalPending,
  });

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'operationId': operationId,
      'contactData': contactData,
      'response': response,
      'error': error,
      'errorDetails': errorDetails,
      'errorCode': errorCode,
      'message': message,
      'totalPending': totalPending,
    };
  }
}
