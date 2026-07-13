// lib/services/api_service.dart - Updated with new methods
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jala_as/models/aging_report.dart';
import 'package:jala_as/models/area.dart';
import 'package:jala_as/models/contact_group.dart';
import 'package:jala_as/models/fuel_models.dart';
import 'package:jala_as/models/price_list_report.dart';
import 'package:jala_as/models/returns_models.dart';
import 'package:jala_as/models/salary_models.dart';
import 'package:jala_as/models/salesman.dart';
import 'package:jala_as/models/warehouse_models.dart';
import 'package:jala_as/services/local_database_service.dart';
import 'package:jala_as/services/offline_contact_service.dart';
import 'package:jala_as/services/offline_queue_service.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/platform_utils.dart';
import 'package:jala_as/utils/api_exception.dart';
import '../models/contact.dart';
import '../models/account_statement.dart';
import '../models/periodic_sales_report.dart';

// Helper classes for parsing
class SalesDataForSalesman {
  final String salesmanCode;
  final Map<String, BrandSalesInfo> brandSales;

  SalesDataForSalesman({
    required this.salesmanCode,
    required this.brandSales,
  });

  double get totalSales {
    return brandSales.values.fold(0.0, (sum, info) => sum + info.salesAmount);
  }

  int get totalCustomers {
    return brandSales.values.fold(0, (sum, info) => sum + info.customerCount);
  }
}

class BrandSalesInfo {
  final String brandCode;
  final String brandName;
  final double salesAmount;
  final int customerCount;

  BrandSalesInfo({
    required this.brandCode,
    required this.brandName,
    required this.salesAmount,
    required this.customerCount,
  });
}

class AgingDataForSalesman {
  final String salesmanCode;
  double total;
  double aging53Plus;

  AgingDataForSalesman({
    required this.salesmanCode,
    required this.total,
    required this.aging53Plus,
  });

  double get percentage {
    if (total == 0) return 0;
    return (aging53Plus / total) * 100;
  }
}

class WarehouseHelper {
  /// Get warehouse code based on salesman and type
  static String getWarehouseCode(String salesman, String warehouseType) {
    switch (warehouseType) {
      case WarehouseType.good:
        return '1$salesman'; // مخزن الصالح
      case WarehouseType.damaged:
        return '2$salesman'; // مخزن التالف
      case WarehouseType.main:
        return warehouseType == WarehouseType.good
            ? '0002'
            : '0010'; // مخزن رئيسي
      default:
        return '1$salesman';
    }
  }

  /// Get main warehouse code based on source warehouse type
  static String getMainWarehouseCode(String sourceWarehouseType) {
    if (sourceWarehouseType == WarehouseType.good) {
      return '0002'; // Main warehouse for good items
    } else {
      return '0010'; // Main warehouse for damaged items
    }
  }

  /// Check if warehouse types are compatible for transfer
  static bool areWarehouseTypesCompatible(
      String sourceType, String targetType) {
    // Good warehouses can only send to good warehouses
    // Damaged warehouses can only send to damaged warehouses
    // Main warehouse is always compatible
    if (targetType == WarehouseType.main) return true;
    return sourceType == targetType;
  }

  /// Get available salesmen for warehouse selection
  static List<Map<String, String>> getAvailableSalesmen() {
    return [
      {"code": "001", "name": "سليمان فؤاد سليمان دياب"},
      {"code": "002", "name": "معتز خالد ابراهيم الحموري"},
      {"code": "003", "name": "فراس منير فتحي سليمان"},
      {"code": "005", "name": "محمد عطية عبد عطيه"},
      {"code": "007", "name": "شركة جالا فود"},
      {"code": "015", "name": "مايك الياس باسيل غنيم"},
      {"code": "030", "name": "جوني خالد باسيل المصو"},
      {"code": "031", "name": "احمد علي حسن عكيله"},
      {"code": "044", "name": "محمد كنعان"},
      {"code": "043", "name": "نمر شمارخة"},
      {"code": "045", "name": "اسماعيل يعقوب احمد الهودلي"},
      {"code": "046", "name": "فؤاد سهيل فؤاد غنيم"},
      {"code": "047", "name": "مهند زياد عبد الحميد العيسه"},
      {"code": "048", "name": "اياد عزيز سليمان عبد"},
      {"code": "050", "name": "ايليا ماهر ابراهيم زيدان"},
    ];
  }
}

class ApiService {
  static const String _powerAutomateUrl =
      'https://prod-120.westeurope.logic.azure.com:443/workflows/74ef47faa1034d21a92631a0e89763e4/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=qZjaafZAfixqbG0MIILH9nh7J86f4gC1VTe81FYNwEI';

  static const String _emailAutomateUrl =
      'https://prod-124.westeurope.logic.azure.com:443/workflows/2656aea4480249f488c70ab46c73d826/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=RfOQZxYp9Gp6YkEoXlN35Ndu3Fzc1frxwt48JpZaSys';

  // NEW: Offline support services
  static final LocalDatabaseService _localDb = LocalDatabaseService();
  static final OfflineQueueService _offlineQueue = OfflineQueueService();
  static bool _isInitialized = false;

  /// NEW: Initialize API service with offline support
  static Future<void> initialize() async {
    if (_isInitialized) return;

    if (PlatformUtils.isMobile) {
      // Initialize offline queue with operation executor
      await _offlineQueue.initialize(
        executeOperation: _executeQueuedOperation,
      );
      print('✓ Offline queue initialized');
    }

    _isInitialized = true;
  }

  /// NEW: Execute a queued operation (for offline sync)
  static Future<bool> _executeQueuedOperation(
    String endpoint,
    String method,
    Map<String, dynamic> data,
  ) async {
    try {
      print('Executing queued operation: $method $endpoint');

      // Reconstruct the original API call
      final response = await makeApiRequest(
        url: data['url'] ?? endpoint,
        method: method,
        headers: data['headers'] != null
            ? Map<String, dynamic>.from(data['headers'])
            : null,
        body: data['body'],
      );

      return response != null;
    } catch (e) {
      print('Error executing queued operation: $e');
      return false;
    }
  }

  /// NEW: Check if device is online
  static Future<bool> _isOnline() async {
    if (!PlatformUtils.isMobile) return true;
    return _offlineQueue.isOnline;
  }

  /// UPDATED: makeApiRequest with offline queue support
  static Future<Map<String, dynamic>> makeApiRequest({
    required String url,
    required String method,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? body,
    bool queueIfOffline = false,
    String? operationType,
  }) async {
    // Check if online (mobile only)
    if (PlatformUtils.isMobile && queueIfOffline) {
      final isOnline = await _isOnline();

      if (!isOnline) {
        // Queue for later execution
        final user = await SupabaseService.getCurrentUser();
        await _offlineQueue.addOperation(
          operationType: operationType ?? 'API_$method',
          endpoint: url,
          method: method,
          data: {
            'url': url,
            'headers': headers,
            'body': body,
          },
          userId: user?.id ?? 'unknown',
        );

        print('Operation queued for offline sync: $method $url');

        return {
          'success': true,
          'queued': true,
          'message': 'تم حفظ العملية وسيتم إرسالها عند الاتصال بالإنترنت',
        };
      }
    }

    // Perform online request
    try {
      final requestBody = {
        'url': url,
        'method': method,
        if (headers != null) 'headers': headers,
        if (body != null) 'body': body,
      };

      final response = await http.post(
        Uri.parse(_powerAutomateUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw ApiException.fromResponse(response);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw Exception('API request failed: $e');
    }
  }

  /// NEW: Get data with offline cache support
  static Future<Map<String, dynamic>> getCachedApiRequest({
    required String url,
    required String method,
    required String cacheType,
    required String cacheKey,
    Map<String, dynamic>? headers,
    bool useCache = true,
  }) async {
    // Try to use cached data if offline (mobile only)
    if (PlatformUtils.isMobile && useCache) {
      final isOnline = await _isOnline();

      if (!isOnline) {
        print('Device offline - using cached data for $cacheType/$cacheKey');
        final cachedData = await _localDb.getCachedData(
          dataType: cacheType,
          dataKey: cacheKey,
        );

        if (cachedData != null) {
          return {
            'success': true,
            ...cachedData,
            'from_cache': true,
          };
        }
      }
    }

    // Make online request
    final response = await makeApiRequest(
      url: url,
      method: method,
      headers: headers,
    );

    // Cache successful response (mobile only)
    if (PlatformUtils.isMobile && useCache && response != null) {
      try {
        await _localDb.saveCachedData(
          dataType: cacheType,
          dataKey: cacheKey,
          data: response,
        );
        print('Cached data: $cacheType/$cacheKey');
      } catch (e) {
        print('Error caching data: $e');
      }
    }

    return response;
  }

  /// Get all stock items from a specific warehouse for bulk transfer
  static Future<List<Map<String, dynamic>>> getWarehouseStockForBulkTransfer({
    required String warehouseCode,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final now = DateTime.now();
      final from = fromDate ?? DateTime(now.year, 1, 1);
      final to = toDate ?? now;

      final fromDateStr =
          '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
      final toDateStr =
          '${to.year}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}';

      final String stockUrl =
          'https://gw.bisan.com/api/v2/jalaf/REPORT/stockBalance?search='
          'fromDate:$fromDateStr,'
          'toDate:$toDateStr,'
          'warehouse_From:$warehouseCode,'
          'warehouse_To:$warehouseCode,'
          'includeWhsDelivery:true,'
          'byWarehouse:true,'
          'lg_status:مرحل'
          '&fields=item,item.name,warehouse,binNum,item.reportUnit,partNumber,count,packVolume,begBalance,rptQntIn,rptQntOut,change,endBalance,item.warranty';

      print('DEBUG: Getting bulk stock for warehouse: $warehouseCode');

      final response = await makeApiRequest(
        url: stockUrl,
        method: 'GET',
      );

      final rows = response['rows'] as List? ?? [];

      // Filter items with positive end balance
      final itemsWithStock = rows.where((item) {
        final endBalance =
            double.tryParse(item['endBalance']?.toString() ?? '0') ?? 0;
        return endBalance > 0;
      }).toList();

      print(
          'DEBUG: Found ${itemsWithStock.length} items with stock in warehouse $warehouseCode');

      return itemsWithStock.cast<Map<String, dynamic>>();
    } catch (e) {
      print('DEBUG: getWarehouseStockForBulkTransfer error: $e');
      rethrow;
    }
  }

  /// Group stock items by warranty type for bulk transfer
  static Map<String, List<Map<String, dynamic>>> groupStockItemsByWarranty(
    List<Map<String, dynamic>> items,
  ) {
    final Map<String, List<Map<String, dynamic>>> groups = {
      'group1': [], // warranty: 03
      'group2': [], // warranty: 02, 04, 07
    };

    for (final item in items) {
      final warranty = item['item.warranty']?.toString() ?? '';
      final endBalance =
          double.tryParse(item['endBalance']?.toString() ?? '0') ?? 0;

      // Skip items with no stock
      if (endBalance <= 0) continue;

      if (warranty == '03') {
        groups['group1']!.add(item);
      } else if (warranty == '02' || warranty == '04' || warranty == '07') {
        groups['group2']!.add(item);
      }
      // Items with other warranty values are ignored
    }

    print('DEBUG: Group 1 (warranty 03): ${groups['group1']!.length} items');
    print(
        'DEBUG: Group 2 (warranty 02,04,07): ${groups['group2']!.length} items');

    return groups;
  }

  /// Create bulk store issue voucher for transferring all items to main warehouse
  static Future<Map<String, dynamic>> createBulkStoreIssueVoucher({
    required String sourceWarehouse,
    required String targetWarehouse,
    required List<Map<String, dynamic>> items,
    required String requesterName,
    required String warehouseType,
    String? comment,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final now = DateTime.now();
      final docDate =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      final time =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final warehouseTypeArabic =
          warehouseType == WarehouseType.good ? 'الصالح' : 'التالف';
      final autoComment = comment ??
          'ترحيل كامل البضاعة من مخزن $requesterName $warehouseTypeArabic إلى المخزن الرئيسي باستخدام التطبيق';

      // Prepare order details from items
      final orderDetail = items.map((item) {
        final endBalance =
            double.tryParse(item['endBalance']?.toString() ?? '0') ?? 0;
        return {
          'item': item['item'],
          'unit': item['item.reportUnit'] ?? 'PCS',
          'quantity': endBalance.toString(),
        };
      }).toList();

      final requestBody = {
        "TRANSACTION_ID": timestamp,
        "record": {
          "issueType": "مستودع",
          "docDate": docDate,
          "branch": "00",
          "costCenter": "000000",
          "activity": "0000",
          "comment": autoComment,
          "warehouse": sourceWarehouse,
          "truck": "121",
          "warehouseOther": targetWarehouse,
          "time": time,
          "delivered": "لا",
          "maintenanceDelivery": "لا",
          "orderDetail": orderDetail,
          "approval": "Entry",
        }
      };

      const String storeIssueUrl =
          'https://gw.bisan.com/api/v2/jalaf/storeIssueVoucher';

      print('DEBUG: Creating bulk store issue voucher');
      print('DEBUG: Source: $sourceWarehouse, Target: $targetWarehouse');
      print('DEBUG: Items count: ${items.length}');

      final response = await makeApiRequest(
        url: storeIssueUrl,
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      print('DEBUG: Bulk store issue voucher created successfully');

      final code = response['rows']?['code'] as String?;

      return {
        'transaction_id': timestamp,
        'bisan_code': code,
        'doc_date': docDate,
        'response': response,
        'success': true,
        'items_count': items.length,
      };
    } catch (e) {
      print('DEBUG: createBulkStoreIssueVoucher error: $e');
      rethrow;
    }
  }

  /// Execute bulk warehouse transfer (transfers all items to main warehouse)
  static Future<Map<String, dynamic>> executeBulkWarehouseTransfer({
    required String salesmanCode,
    required String warehouseType, // 'صالح' or 'تالف'
    required String requesterName,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      print('DEBUG: Starting bulk warehouse transfer');
      print('DEBUG: Salesman: $salesmanCode, Type: $warehouseType');

      // Determine source and target warehouses
      final isGoodWarehouse = warehouseType == WarehouseType.good;
      final sourceWarehouse =
          isGoodWarehouse ? '1$salesmanCode' : '2$salesmanCode';
      final targetWarehouse = isGoodWarehouse ? '0002' : '0010';

      // Get all stock items from source warehouse
      final stockItems = await getWarehouseStockForBulkTransfer(
        warehouseCode: sourceWarehouse,
        fromDate: fromDate,
        toDate: toDate,
      );

      if (stockItems.isEmpty) {
        return {
          'success': false,
          'error': 'لا توجد أصناف في المخزن المحدد',
          'items_count': 0,
        };
      }

      // Group items by warranty
      final groups = groupStockItemsByWarranty(stockItems);
      final group1Items = groups['group1']!; // warranty: 03
      final group2Items = groups['group2']!; // warranty: 02, 04, 07

      final List<Map<String, dynamic>> results = [];
      int totalItemsTransferred = 0;

      // Create store issue for Group 1 (warranty 03) if not empty
      if (group1Items.isNotEmpty) {
        print(
            'DEBUG: Creating store issue for Group 1 (${group1Items.length} items)');

        final group1Result = await createBulkStoreIssueVoucher(
          sourceWarehouse: sourceWarehouse,
          targetWarehouse: targetWarehouse,
          items: group1Items,
          requesterName: requesterName,
          warehouseType: warehouseType,
          comment: 'ترحيل بضاعة - مجموعة الكفالة 03',
        );

        results.add({
          'group': 'group1',
          'warranty': '03',
          ...group1Result,
        });
        totalItemsTransferred += group1Items.length;
      }

      // Create store issue for Group 2 (warranty 02, 04, 07) if not empty
      if (group2Items.isNotEmpty) {
        print(
            'DEBUG: Creating store issue for Group 2 (${group2Items.length} items)');

        final group2Result = await createBulkStoreIssueVoucher(
          sourceWarehouse: sourceWarehouse,
          targetWarehouse: targetWarehouse,
          items: group2Items,
          requesterName: requesterName,
          warehouseType: warehouseType,
          comment: 'ترحيل بضاعة - مجموعة الكفالة 02/04/07',
        );

        results.add({
          'group': 'group2',
          'warranty': '02/04/07',
          ...group2Result,
        });
        totalItemsTransferred += group2Items.length;
      }

      if (results.isEmpty) {
        return {
          'success': false,
          'error': 'لا توجد أصناف مع كفالة صالحة للترحيل (03, 02, 04, 07)',
          'items_count': 0,
        };
      }

      print('DEBUG: Bulk transfer completed successfully');
      print('DEBUG: Total items transferred: $totalItemsTransferred');

      return {
        'success': true,
        'results': results,
        'total_items': totalItemsTransferred,
        'source_warehouse': sourceWarehouse,
        'target_warehouse': targetWarehouse,
        'group1_count': group1Items.length,
        'group2_count': group2Items.length,
      };
    } catch (e) {
      print('DEBUG: executeBulkWarehouseTransfer error: $e');
      rethrow;
    }
  }

  /// NEW: Get pending operations count
  static Future<int> getPendingOperationsCount() async {
    if (!PlatformUtils.isMobile) return 0;
    return await _offlineQueue.getPendingCount();
  }

  /// NEW: Manually trigger sync
  static Future<void> syncPendingOperations() async {
    if (!PlatformUtils.isMobile) return;
    await _offlineQueue.processPendingOperations();
  }

  /// NEW: Clear cache
  static Future<void> clearCache() async {
    if (!PlatformUtils.isMobile) return;
    await _localDb.clearCachedData();
  }

// Add these methods to your existing ApiService class:

  /// Get stock balance for specific warehouse
  /// UPDATED: Get warehouse stock with caching
  static Future<List<StockItem>> getWarehouseStock({
    required String warehouseCode,
  }) async {
    try {
      final now = DateTime.now();
      final fromDate = '${now.year}-01-01';
      final toDate = '${now.year}-12-31';

      final String stockUrl =
          'https://gw.bisan.com/api/v2/jalaf/REPORT/stockBalance?search='
          'fromDate:$fromDate,'
          'toDate:$toDate,'
          'warehouse_From:$warehouseCode,'
          'warehouse_To:$warehouseCode,'
          'includeWhsDelivery:true,'
          'byWarehouse:true,'
          'lg_status:مرحل';

      print('DEBUG: Getting stock for warehouse: $warehouseCode');

      // NEW: Use cached request with offline support
      final response = await getCachedApiRequest(
        url: stockUrl,
        method: 'GET',
        cacheType: 'warehouse_stock',
        cacheKey: warehouseCode,
        useCache: true,
      );

      final rows = response['rows'] as List;
      final stockItems = rows.map((row) => StockItem.fromJson(row)).toList();

      // Filter only items with available quantity
      final availableItems =
          stockItems.where((item) => item.isAvailable).toList();

      print('DEBUG: Found ${availableItems.length} available items');

      return availableItems;
    } catch (e) {
      print('DEBUG: getWarehouseStock error: $e');
      rethrow;
    }
  }

  /// UPDATED: Create store issue voucher with offline queue
  static Future<Map<String, dynamic>> createStoreIssueVoucher({
    required String sourceWarehouse,
    required String targetWarehouse,
    required List<TransferItem> items,
    required String requesterName,
    required String targetUserName,
    required String warehouseType,
    required bool isToMainWarehouse,
    String? comment,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final now = DateTime.now();
      final docDate =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      final time =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      // Generate comment
      final warehouseTypeArabic =
          warehouseType == WarehouseType.good ? 'الصالح' : 'التالف';
      final targetDescription = isToMainWarehouse
          ? 'المخزن الرئيسي'
          : 'مخزن $targetUserName $warehouseTypeArabic';

      final autoComment = comment ??
          'ارسل $requesterName من مخزنه $warehouseTypeArabic إلى $targetDescription باستخدام التطبيق';

      final orderDetail = items.map((item) => item.toOrderDetail()).toList();

      final requestBody = isToMainWarehouse
          ? {
              "TRANSACTION_ID": timestamp,
              "record": {
                "issueType": "مستودع",
                "docDate": docDate,
                "branch": "00",
                "costCenter": "000000",
                "activity": "0000",
                "comment": autoComment,
                "warehouse": sourceWarehouse,
                "truck": "121",
                "warehouseOther": targetWarehouse,
                "time": time,
                "delivered": "لا",
                "maintenanceDelivery": "لا",
                "orderDetail": orderDetail,
                "approval": isToMainWarehouse ? "Entry" : "Posted",
              }
            }
          : {
              "TRANSACTION_ID": timestamp,
              "record": {
                "issueType": "مستودع",
                "docDate": docDate,
                "branch": "00",
                "costCenter": "000000",
                "activity": "0000",
                "comment": autoComment,
                "warehouse": sourceWarehouse,
                "truck": "121",
                "warehouseOther": targetWarehouse,
                "time": time,
                "delivered": "لا",
                "maintenanceDelivery": "لا",
                "orderDetail": orderDetail,
                "approval": isToMainWarehouse ? "Entry" : "Posted",
                "pending": "false"
              }
            };

      print('DEBUG: Creating store issue voucher');

      // NEW: Use makeApiRequest with offline queue support
      final response = await makeApiRequest(
        url: 'https://gw.bisan.com/api/v2/jalaf/storeissue',
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
        queueIfOffline: true, // Enable offline queue
        operationType: 'create_store_issue',
      );

      print('DEBUG: Store issue created successfully');
      return response;
    } catch (e) {
      print('DEBUG: createStoreIssueVoucher error: $e');
      rethrow;
    }
  }

  /// Create store issue voucher for user-to-user transfer (before approval)
  static Future<Map<String, dynamic>> createUserToUserStoreIssueVoucher({
    required String sourceWarehouse,
    required String targetWarehouse,
    required List<TransferItem> items,
    required String requesterName,
    required String targetUserName,
    required String warehouseType,
    String? comment,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final now = DateTime.now();
      final docDate =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      final time =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final warehouseTypeArabic =
          warehouseType == WarehouseType.good ? 'الصالح' : 'التالف';
      final autoComment = comment?.isNotEmpty == true
          ? comment!
          : 'ارسل $requesterName من مخزنه $warehouseTypeArabic إلى مخزن $targetUserName $warehouseTypeArabic باستخدام التطبيق';

      final orderDetail = items.map((item) => item.toOrderDetail()).toList();

      final requestBody = {
        "TRANSACTION_ID": timestamp,
        "record": {
          "issueType": "مستودع",
          "docDate": docDate,
          "branch": "00",
          "costCenter": "000000",
          "activity": "0000",
          "comment": autoComment,
          "warehouse": sourceWarehouse,
          "truck": "121",
          "warehouseOther": targetWarehouse,
          "time": time,
          "delivered": "لا",
          "maintenanceDelivery": "لا",
          "orderDetail": orderDetail,
          "approval": "Posted",
        }
      };

      const String storeIssueUrl =
          'https://gw.bisan.com/api/v2/jalaf/storeIssueVoucher';

      final response = await makeApiRequest(
        url: storeIssueUrl,
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      print('DEBUG: User-to-user store issue voucher created');

      // Extract code from response
      final code = response['rows']?['code'] as String?;
      if (code == null) {
        throw Exception('No code returned from store issue voucher creation');
      }

      return {
        'transaction_id': timestamp,
        'bisan_code': code,
        'doc_date': docDate,
        'response': response,
        'success': true,
      };
    } catch (e) {
      print('DEBUG: createUserToUserStoreIssueVoucher error: $e');
      rethrow;
    }
  }

  /// Create store issue voucher for immediate main warehouse transfer
  static Future<Map<String, dynamic>> createMainWarehouseStoreIssueVoucher({
    required String sourceWarehouse,
    required String targetWarehouse,
    required List<TransferItem> items,
    required String requesterName,
    required String warehouseType,
    String? comment,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final now = DateTime.now();
      final docDate =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      final time =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final warehouseTypeArabic =
          warehouseType == WarehouseType.good ? 'الصالح' : 'التالف';
      final autoComment = comment?.isNotEmpty == true
          ? comment!
          : 'ارسل $requesterName من مخزنه $warehouseTypeArabic إلى المخزن الرئيسي باستخدام التطبيق';

      final orderDetail = items.map((item) => item.toOrderDetail()).toList();

      final requestBody = {
        "TRANSACTION_ID": timestamp,
        "record": {
          "issueType": "مستودع",
          "docDate": docDate,
          "branch": "00",
          "costCenter": "000000",
          "activity": "0000",
          "comment": autoComment,
          "warehouse": sourceWarehouse,
          "truck": "121",
          "warehouseOther": targetWarehouse,
          "time": time,
          "delivered": "لا",
          "maintenanceDelivery": "لا",
          "orderDetail": orderDetail,
          "approval": "Entry",
        }
      };

      const String storeIssueUrl =
          'https://gw.bisan.com/api/v2/jalaf/storeIssueVoucher';

      final response = await makeApiRequest(
        url: storeIssueUrl,
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      print('DEBUG: Main warehouse store issue voucher created');

      // Extract code from response
      final code = response['rows']?['code'] as String?;

      return {
        'transaction_id': timestamp,
        'bisan_code': code,
        'doc_date': docDate,
        'response': response,
        'success': true,
      };
    } catch (e) {
      print('DEBUG: createMainWarehouseStoreIssueVoucher error: $e');
      rethrow;
    }
  }

  /// Get store issue voucher details by code
  static Future<Map<String, dynamic>> getStoreIssueVoucherByCode(
      String code) async {
    try {
      final String getUrl =
          'https://gw.bisan.com/api/v2/jalaf/storeIssueVoucher?'
          'fields=code,issueType,docFormat,contact,attachment,docDate,branch,costCenter,'
          'activity,comment,cusReference,shipTo,shipOn,warehouse,truck,customerTaxType,'
          'currency,curRate,discountPercent,discountTotal,totalNet,deliveryInst,shipment,'
          'warehouseOther,time,delivered,maintenanceDelivery,orderDetail.item,orderDetail.unit,'
          'orderDetail.quantity,orderDetail.desc,orderDetail.id,orderDetail.bonus,'
          'orderDetail.price,orderDetail.serial,orderDetail.batch.batch,orderDetail.batch.batch.manufacturerBatchCode,'
          'orderDetail.batch.batch.manufacturer,orderDetail.batch.batch.expiryDate,'
          'orderDetail.batch.quantity,orderDetail.discountPercent,deliveryDate,receivedBy,'
          'approval,pending&search=code:$code';

      final response = await makeApiRequest(
        url: getUrl,
        method: 'GET',
      );

      print('DEBUG: Store issue voucher retrieved: $code');
      return response;
    } catch (e) {
      print('DEBUG: getStoreIssueVoucherByCode error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createReverseStoreIssueVoucher({
    required String
        sourceWarehouse, // Now the target warehouse (where items are)
    required String
        targetWarehouse, // Now the original source warehouse (where items should return)
    required List<TransferItem> items,
    required String originalRequesterName,
    required String warehouseType,
    required String reason, // "deletion" or "rejection"
    String? comment,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final now = DateTime.now();
      final docDate =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      final time =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final warehouseTypeArabic =
          warehouseType == WarehouseType.good ? 'الصالح' : 'التالف';
      final reasonText = reason == "deletion" ? "حذف الطلب" : "رفض الطلب";
      final autoComment = comment?.isNotEmpty == true
          ? comment!
          : 'إعادة بضاعة $originalRequesterName إلى مخزنه $warehouseTypeArabic بسبب $reasonText باستخدام التطبيق';

      final orderDetail = items.map((item) => item.toOrderDetail()).toList();

      final requestBody = {
        "TRANSACTION_ID": timestamp,
        "record": {
          "issueType": "مستودع",
          "docDate": docDate,
          "branch": "00",
          "costCenter": "000000",
          "activity": "0000",
          "comment": autoComment,
          "warehouse": sourceWarehouse, // Where items currently are
          "truck": "121",
          "warehouseOther": targetWarehouse, // Where items should go back
          "time": time,
          "delivered": "لا",
          "maintenanceDelivery": "لا",
          "orderDetail": orderDetail,
          "approval": "Posted",
        }
      };

      const String storeIssueUrl =
          'https://gw.bisan.com/api/v2/jalaf/storeIssueVoucher';

      final response = await makeApiRequest(
        url: storeIssueUrl,
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      print('DEBUG: Reverse store issue voucher created for $reason');

      final code = response['rows']?['code'] as String?;
      if (code == null) {
        throw Exception(
            'No code returned from reverse store issue voucher creation');
      }

      return {
        'transaction_id': timestamp,
        'bisan_code': code,
        'doc_date': docDate,
        'response': response,
        'success': true,
      };
    } catch (e) {
      print('DEBUG: createReverseStoreIssueVoucher error: $e');
      rethrow;
    }
  }

  /// Execute complete reversal process (issue + receipt + reverse issue + reverse receipt)
  static Future<Map<String, dynamic>> executeCompleteReversal({
    required WarehouseTransferRequest request,
    required String reason, // "deletion" or "rejection"
    String? rejectionComment,
  }) async {
    try {
      print(
          'DEBUG: Starting complete reversal process for request ${request.id}');

      // Step 1: Get original store issue voucher details
      final issueVoucherData =
          await getStoreIssueVoucherByCode(request.bisanTransactionId!);

      // Step 2: Create store receipt voucher (complete the forward transfer)
      final receiptResult = await createStoreReceiptVoucher(
        issueVoucherData: issueVoucherData,
      );

      print('DEBUG: Forward transfer completed, now reversing...');

      // Step 3: Create reverse store issue voucher (to return items to source)
      final reverseIssueResult = await createReverseStoreIssueVoucher(
        sourceWarehouse: request.targetWarehouse, // Where items currently are
        targetWarehouse: request.sourceWarehouse, // Where items should return
        items: request.items,
        originalRequesterName: request.requesterName,
        warehouseType: request.warehouseType,
        reason: reason,
        comment: rejectionComment,
      );

      // Step 4: Get reverse issue voucher details
      final reverseIssueVoucherData =
          await getStoreIssueVoucherByCode(reverseIssueResult['bisan_code']);

      // Step 5: Create reverse receipt voucher (complete the return)
      final reverseReceiptResult = await createStoreReceiptVoucher(
        issueVoucherData: reverseIssueVoucherData,
      );

      print('DEBUG: Complete reversal process finished successfully');

      return {
        'forward_receipt_transaction_id': receiptResult['transaction_id'],
        'reverse_issue_code': reverseIssueResult['bisan_code'],
        'reverse_receipt_transaction_id':
            reverseReceiptResult['transaction_id'],
        'success': true,
      };
    } catch (e) {
      print('DEBUG: executeCompleteReversal error: $e');
      rethrow;
    }
  }

  /// Create store receipt voucher after approval
  static Future<Map<String, dynamic>> createStoreReceiptVoucher({
    required Map<String, dynamic> issueVoucherData,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      final rows = issueVoucherData['rows'] as List;
      if (rows.isEmpty) {
        throw Exception('No issue voucher data found');
      }

      final voucherData = rows.first as Map<String, dynamic>;
      final orderDetails = voucherData['orderDetail'] as List;

      final receiptOrderDetail = orderDetails
          .map((item) => {
                'item': item['item'],
                'unit': item['unit'],
                'quantity': item['quantity'],
                'desc': item['desc'],
                'source': item['id'],
              })
          .toList();

      final requestBody = {
        "TRANSACTION_ID": timestamp,
        "record": {
          "issueType": "مستودع",
          "docDate": voucherData['docDate'],
          "branch": "00",
          "costCenter": "000000",
          "activity": "0000",
          "comment": voucherData['comment'],
          "warehouse": voucherData['warehouseOther'],
          "warehouseOther": "0121",
          "orderDetail": receiptOrderDetail,
          "approval": "Posted",
          "pending": "لا",
        }
      };

      const String receiptUrl =
          'https://gw.bisan.com/api/v2/jalaf/storeReceiptVoucher';

      final response = await makeApiRequest(
        url: receiptUrl,
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      print('DEBUG: Store receipt voucher created successfully');
      return {
        'transaction_id': timestamp,
        'response': response,
        'success': true,
      };
    } catch (e) {
      print('DEBUG: createStoreReceiptVoucher error: $e');
      rethrow;
    }
  }

  /// Send warehouse transfer notification email
  static Future<void> sendWarehouseTransferNotification({
    required String toEmail,
    required String requesterName,
    required String targetUserName,
    required String warehouseType,
    required List<TransferItem> items,
    required bool isToMainWarehouse,
  }) async {
    try {
      final warehouseTypeArabic =
          warehouseType == WarehouseType.good ? 'الصالح' : 'التالف';
      final targetDescription = isToMainWarehouse
          ? 'المخزن الرئيسي'
          : 'مخزن $targetUserName $warehouseTypeArabic';

      final itemsList = items
          .map((item) =>
              '• ${item.itemName} - الكمية: ${item.requestedQuantity} ${item.unit}')
          .join('\n');

      final subject = isToMainWarehouse
          ? 'طلب نقل بضاعة إلى المخزن الرئيسي - $requesterName'
          : 'طلب نقل بضاعة - $requesterName إلى $targetUserName';

      final emailBody = '''
مرحباً<br><br>
${isToMainWarehouse ? 'تم إنشاء طلب نقل بضاعة إلى المخزن الرئيسي' : 'لديك طلب نقل بضاعة جديد يتطلب موافقتك'}<br><br>
<strong>تفاصيل الطلب:</strong><br>
المرسل: $requesterName<br>
${isToMainWarehouse ? '' : 'المستقبل: $targetUserName<br>'}
نوع المخزن: $warehouseTypeArabic<br>
${isToMainWarehouse ? 'المقصد: المخزن الرئيسي<br>' : ''}
<br>
<strong>الأصناف المطلوب نقلها:</strong><br>
${itemsList.replaceAll('\n', '<br>')}<br><br>
${isToMainWarehouse ? 'تم تنفيذ الطلب تلقائياً في النظام.' : 'يرجى مراجعة الطلب واتخاذ الإجراء المناسب.'}<br><br>
التاريخ: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}<br>
الوقت: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}
''';

      print('DEBUG: Warehouse transfer notification sent successfully');
    } catch (e) {
      print('DEBUG: sendWarehouseTransferNotification error: $e');
      rethrow;
    }
  }

  static Future<List<Contact>> getContacts() async {
    const String contactsUrl =
        'https://gw.bisan.com/api/v2/jalaf/contact?fields=code,nameAR,area,area.name,salesman,streetAddress,taxId,phone&search=enabled:yes AND type <: 009';

    final response = await makeApiRequest(
      url: contactsUrl,
      method: 'GET',
    );

    final rows = response['rows'] as List;
    return rows.map((row) => Contact.fromBisanJson(row)).toList();
  }

  // Fixed getAgingReport method in ApiService class
  static Future<List<AgingReport>> getAgingReport({
    required String salesman,
    String? area,
    String? specificArea, // New parameter for admin area selection
    String? salesmanFrom, // New parameter for admin salesman from
    String? salesmanTo, // New parameter for admin salesman to
    String? dateType, // New parameter: 'current' or 'month_end'
    String? contactType, // New parameter: 'customers' or 'defaulters'
  }) async {
    try {
      // Determine the date to use
      String asOfDate;
      final now = DateTime.now();

      if (dateType == 'current') {
        // Use current date
        asOfDate =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      } else {
        // Use last day of current month (default behavior)
        final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
        asOfDate =
            '${lastDayOfMonth.year}-${lastDayOfMonth.month.toString().padLeft(2, '0')}-${lastDayOfMonth.day.toString().padLeft(2, '0')}';
      }

      // Determine contact type parameters
      String fromContactType;
      String toContactType;

      if (contactType == 'defaulters') {
        fromContactType = '007';
        toContactType = '009';
      } else {
        // Default to customers
        fromContactType = '001';
        toContactType = '006';
      }

      String agingUrl;

      print('DEBUG ApiService: Input parameters:');
      print('  salesman: $salesman');
      print('  area: $area');
      print('  specificArea: $specificArea');
      print('  salesmanFrom: $salesmanFrom');
      print('  salesmanTo: $salesmanTo');

      // FIXED: Check if user is admin (salesman=00)
      if (salesman == '00') {
        // Admin user logic
        print('DEBUG: Processing admin user request');

        // Get available salesmen for default values
        final availableSalesmen = getAvailableSalesmen();
        final firstSalesman = availableSalesmen.first.code; // "001"
        final lastSalesman = availableSalesmen.last.code; // "050"

        // Handle salesman range selection with auto-completion
        String? finalSalesmanFrom = salesmanFrom;
        String? finalSalesmanTo = salesmanTo;

        // Auto-complete missing salesman values
        if (salesmanFrom != null && salesmanTo == null) {
          finalSalesmanTo = lastSalesman; // Use last salesman
        } else if (salesmanFrom == null && salesmanTo != null) {
          finalSalesmanFrom = firstSalesman; // Use first salesman
        }

        print(
            'DEBUG: Final salesman range: $finalSalesmanFrom to $finalSalesmanTo');
        print('DEBUG: Specific area: $specificArea');

        // Build URL based on provided parameters
        if (finalSalesmanFrom != null && finalSalesmanTo != null) {
          // Case 1 & 2: Salesman range with or without area
          String baseUrl =
              'https://gw.bisan.com/api/v2/jalaf/REPORT/aRAging?search=asOfDate:$asOfDate,groupType:دليل,fromContactType:$fromContactType,toContactType:$toContactType,fromSalesman:$finalSalesmanFrom,toSalesman:$finalSalesmanTo';

          // FIXED: Only add area if specificArea is provided and not null/empty
          if (specificArea != null &&
              specificArea.isNotEmpty &&
              specificArea != '00') {
            baseUrl += ',area:$specificArea';
            print('DEBUG: Added area filter: $specificArea');
          }

          baseUrl +=
              ',branch:00,numPeriods:3,daysPerPeriod:26,isCustomer:true,useContactSalesman:true,lg_status:مرحل';
          agingUrl = baseUrl;
        } else if (specificArea != null &&
            specificArea.isNotEmpty &&
            specificArea != '00') {
          // Case 3: Area only (no salesman range specified)
          agingUrl =
              'https://gw.bisan.com/api/v2/jalaf/REPORT/aRAging?search=asOfDate:$asOfDate,groupType:دليل,fromContactType:$fromContactType,toContactType:$toContactType,area:$specificArea,branch:00,numPeriods:3,daysPerPeriod:26,isCustomer:true,useContactSalesman:true,lg_status:مرحل';
          print('DEBUG: Using area-only filter: $specificArea');
        } else {
          // FIXED: If admin doesn't provide any filters, use all salesmen
          agingUrl =
              'https://gw.bisan.com/api/v2/jalaf/REPORT/aRAging?search=asOfDate:$asOfDate,groupType:دليل,fromContactType:$fromContactType,toContactType:$toContactType,fromSalesman:$firstSalesman,toSalesman:$lastSalesman,branch:00,numPeriods:3,daysPerPeriod:26,isCustomer:true,useContactSalesman:true,lg_status:مرحل';
          print('DEBUG: Using all salesmen (no specific filters)');
        }
      } else {
        // Regular user - use their salesman value
        print('DEBUG: Processing regular user request');

        // FIXED: For regular users, don't use the area parameter from admin selection
        // Use the user's own area if available
        if (area != null && area.isNotEmpty && area != '00') {
          agingUrl =
              'https://gw.bisan.com/api/v2/jalaf/REPORT/aRAging?search=asOfDate:$asOfDate,groupType:دليل,fromContactType:$fromContactType,toContactType:$toContactType,fromSalesman:$salesman,toSalesman:$salesman,area:$area,branch:00,numPeriods:3,daysPerPeriod:26,isCustomer:true,useContactSalesman:true,lg_status:مرحل';
          print('DEBUG: Regular user with area: $area');
        } else {
          agingUrl =
              'https://gw.bisan.com/api/v2/jalaf/REPORT/aRAging?search=asOfDate:$asOfDate,groupType:دليل,fromContactType:$fromContactType,toContactType:$toContactType,fromSalesman:$salesman,toSalesman:$salesman,branch:00,numPeriods:3,daysPerPeriod:26,isCustomer:true,useContactSalesman:true,lg_status:مرحل';
          print('DEBUG: Regular user without area');
        }
      }

      print('DEBUG: Final API URL: $agingUrl');

      // Add retry logic for 502 errors
      int maxRetries = 3;
      int retryDelay = 2; // seconds

      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          print('DEBUG: API request attempt $attempt/$maxRetries');

          final response = await makeApiRequest(
            url: agingUrl,
            method: 'GET',
          );

          print('DEBUG: API request successful');
          final rows = response['rows'] as List;
          return rows.map((row) => AgingReport.fromJson(row)).toList();
        } catch (e) {
          print('DEBUG: API request attempt $attempt failed: $e');

          if (attempt == maxRetries) {
            // Last attempt failed, throw the error
            throw Exception(
                'API request failed after $maxRetries attempts: $e');
          }

          // Wait before retry
          print('DEBUG: Waiting ${retryDelay}s before retry...');
          await Future.delayed(Duration(seconds: retryDelay));
          retryDelay *= 2; // Exponential backoff
        }
      }

      // This should never be reached, but just in case
      throw Exception('Unexpected error in API request logic');
    } catch (e) {
      print('DEBUG: getAgingReport error: $e');
      rethrow;
    }
  }

  // New method to get available areas
  static List<Area> getAvailableAreas() {
    return [
      Area(code: "008", name: "رام الله  -  فرع  الالبان"),
      Area(code: "009", name: "رام الله - فرع الالبان 2"),
      Area(code: "010", name: "مدينة الخليل"),
      Area(code: "011", name: "قرى الخليل"),
      Area(code: "012", name: "الخليل - مبرد"),
      Area(code: "013", name: "قرى الخليل - مبرد"),
      Area(code: "014", name: "العبيدية"),
      Area(code: "015", name: "العبيدية - مبرد"),
      Area(code: "016", name: "بيت لحم"),
      Area(code: "017", name: "بيت لحم - مبرد"),
      Area(code: "018", name: "بيت ساحور"),
      Area(code: "019", name: "بيت ساحور - مبرد"),
      Area(code: "020", name: "بيت جالا"),
      Area(code: "021", name: "بيت جالا - مبرد"),
      Area(code: "022", name: "شارع القدس الخليل"),
      Area(code: "023", name: "شارع القدس الخليل - مبرد"),
      Area(code: "024", name: "ابوديس، العيزرية"),
      Area(code: "025", name: "ابوديس، العيزرية - مبرد"),
      Area(code: "027", name: "قرى بيت لحم الشرقية - مبرد"),
      Area(code: "029", name: "قرى بيت لحم الغربية - مبرد"),
      Area(code: "030", name: "اريحا"),
      Area(code: "035", name: "خط فؤاد غنيم"),
      Area(code: "048", name: "مطاعم بيت لحم M"),
      Area(code: "049", name: "مطاعم بيت لحم J"),
      Area(code: "050", name: "رام الله"),
      Area(code: "051", name: "رام الله - مبرد"),
      Area(code: "052", name: "قرى رام الله - مبرد"),
      Area(code: "053", name: "قرى رام الله"),
      Area(code: "054", name: "عناتا، حزما ،الرام"),
      Area(code: "055", name: "عناتا، حزما ،الرام - مبرد"),
      Area(code: "056", name: "اريحا - مبرد"),
      Area(code: "059", name: "نابلس"),
      Area(code: "060", name: "طولكرم"),
      Area(code: "070", name: "قلقيلية"),
      Area(code: "080", name: "جنين"),
      Area(code: "090", name: "القدس عيدن"),
      Area(code: "100", name: "القدس"),
      Area(code: "997", name: "عالق"),
      Area(code: "998", name: "قضايا"),
      Area(code: "999", name: "موظفين"),
    ];
  }

  // Updated methods for lib/services/api_service.dart

  // Add this new method to get available salesmen
  static List<Salesman> getAvailableSalesmen() {
    return [
      Salesman(code: "001", name: "سليمان فؤاد سليمان دياب"),
      Salesman(code: "002", name: "معتز خالد ابراهيم الحموري"),
      Salesman(code: "003", name: "فراس منير فتحي سليمان"),
      Salesman(code: "005", name: "محمد عطية عبد  عطيه"),
      Salesman(code: "007", name: "شركة جالا فود"),
      Salesman(code: "015", name: "مايك الياس باسيل غنيم"),
      Salesman(code: "030", name: "جوني خالد باسيل المصو"),
      Salesman(code: "031", name: "احمد علي حسن عكيله"),
      Salesman(code: "043", name: "نمر شمارخة"),
      Salesman(code: "044", name: "محمد كنعان"),
      Salesman(code: "045", name: "اسماعيل يعقوب احمد الهودلي"),
      Salesman(code: "046", name: "فؤاد سهيل فؤاد غنيم"),
      Salesman(code: "047", name: "مهند زياد عبد الحميد العيسه"),
      Salesman(code: "048", name: "اياد عزيز سليمان عبد"),
      Salesman(code: "050", name: "ايليا ماهر  ابراهيم  زيدان")
    ];
  }

  static Future<List<Brand>> getBrandsFromBisan() async {
    try {
      const String brandsUrl =
          'https://gw.bisan.com/api/v2/jalaf/itemBrand?fields=code,name&search=enabled:true';

      print('DEBUG: Getting brands from Bisan');

      final response = await makeApiRequest(
        url: brandsUrl,
        method: 'GET',
      );

      final rows = response['rows'] as List;
      final brands = rows.map((row) => Brand.fromBisanJson(row)).toList();

      print('DEBUG: Fetched ${brands.length} brands from Bisan');
      return brands;
    } catch (e) {
      print('DEBUG: getBrandsFromBisan error: $e');
      rethrow;
    }
  }

  /// Get salesman comparative report (retail or wholesale)
  static Future<Map<String, dynamic>> getSalesmanComparativeReport({
    required DateTime fromDate,
    required DateTime toDate,
    required String fromSalesman,
    required String toSalesman,
    required bool
        isRetail, // true for retail (002-009), false for wholesale (001)
  }) async {
    try {
      final fromDateStr =
          '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';
      final toDateStr =
          '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}';

      final fromContactType = isRetail ? '002' : '001';
      final toContactType = isRetail ? '009' : '001';

      final String reportUrl =
          'https://gw.bisan.com/api/v2/jalaf/REPORT/salesmanComparativeRpt.json?'
          'search=fromDate:$fromDateStr,toDate:$toDateStr,'
          'brand_From:001,brand_To:905,'
          'fromSalesman:$fromSalesman,toSalesman:$toSalesman,'
          'branch_From:00,branch_To:00,'
          'useContactSalesman:true,lg_status:مرحل,'
          'reportType:مبلغ,groupType:حسب العلامة التجارية,'
          'summary:true,'
          'fromContactType:$fromContactType,toContactType:$toContactType';

      print(
          'DEBUG: Getting salesman comparative report (${isRetail ? "retail" : "wholesale"})');

      final response = await makeApiRequest(
        url: reportUrl,
        method: 'GET',
      );

      print('DEBUG: Salesman comparative report received');
      return response;
    } catch (e) {
      print('DEBUG: getSalesmanComparativeReport error: $e');
      rethrow;
    }
  }

  /// Get periodic sales report for user with area
  static Future<Map<String, dynamic>> getPeriodicSalesForArea({
    required DateTime fromDate,
    required DateTime toDate,
    required String fromArea,
    required String toArea,
  }) async {
    try {
      final fromDateStr =
          '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';
      final toDateStr =
          '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}';

      final String reportUrl =
          'https://gw.bisan.com/api/v2/jalaf/REPORT/periodicSalesRpt?'
          'search=fromDate:$fromDateStr,toDate:$toDateStr,'
          'reportType:Amount,groupType:By Brand,'
          'brand_From:001,brand_To:905,'
          'fromArea:$fromArea,toArea:$toArea,'
          'fromContactType:001,toContactType:006,'
          'branch_From:00,branch_To:00,'
          'periodType:Monthly,useContactSalesman:true,lg_status:Posted';

      print('DEBUG: Getting periodic sales for area $fromArea-$toArea');

      final response = await makeApiRequest(
        url: reportUrl,
        method: 'GET',
      );

      print('DEBUG: Periodic sales for area received');
      return response;
    } catch (e) {
      print('DEBUG: getPeriodicSalesForArea error: $e');
      rethrow;
    }
  }

  /// Get aging report
  static Future<Map<String, dynamic>> getSalaryAgingReport({
    required DateTime asOfDate,
    required String fromSalesman,
    required String toSalesman,
    String? specificArea,
  }) async {
    try {
      final asOfDateStr =
          '${asOfDate.year}-${asOfDate.month.toString().padLeft(2, '0')}-${asOfDate.day.toString().padLeft(2, '0')}';

      String reportUrl = 'https://gw.bisan.com/api/v2/jalaf/REPORT/aRAging?'
          'search=asOfDate:$asOfDateStr,groupType:دليل,'
          'fromContactType:001,toContactType:006,'
          'fromSalesman:$fromSalesman,toSalesman:$toSalesman,'
          'branch:00,numPeriods:3,daysPerPeriod:26,'
          'isCustomer:true,useContactSalesman:true,lg_status:مرحل'
          '&fields=shownCont,shownCont.name,shownCont.salesman,shownCont.area,'
          'total,balance,1-26days,27-52days,53%2Bdays';

      if (specificArea != null && specificArea.isNotEmpty) {
        reportUrl = 'https://gw.bisan.com/api/v2/jalaf/REPORT/aRAging?'
            'search=asOfDate:$asOfDateStr,groupType:دليل,'
            'fromContactType:001,toContactType:006,'
            'fromSalesman:$fromSalesman,toSalesman:$toSalesman,'
            'area:$specificArea,'
            'branch:00,numPeriods:3,daysPerPeriod:26,'
            'isCustomer:true,useContactSalesman:true,lg_status:مرحل'
            '&fields=shownCont,shownCont.name,shownCont.salesman,shownCont.area,'
            'total,balance,1-26days,27-52days,53%2Bdays';
      }

      print('DEBUG: Getting aging report');

      final response = await makeApiRequest(
        url: reportUrl,
        method: 'GET',
      );

      print('DEBUG: Aging report received');
      return response;
    } catch (e) {
      print('DEBUG: getSalaryAgingReport error: $e');
      rethrow;
    }
  }

  /// Parse sales data from salesman comparative report
  static Map<String, SalesDataForSalesman> parseSalesmanComparativeData(
    Map<String, dynamic> response,
    List<String> salesmenCodes,
  ) {
    final Map<String, SalesDataForSalesman> result = {};

    for (final salesmanCode in salesmenCodes) {
      result[salesmanCode] = SalesDataForSalesman(
        salesmanCode: salesmanCode,
        brandSales: {},
      );
    }

    final rows = response['rows'] as List<dynamic>? ?? [];

    for (final row in rows) {
      final brandCode = row['item.brand'] as String? ?? '';
      final brandName = row['name'] as String? ?? '';

      for (final salesmanCode in salesmenCodes) {
        final salesKey = salesmanCode;
        final custCountKey = '${salesmanCode}custCount';

        final salesStr = row[salesKey]?.toString() ?? '';
        final custCountStr = row[custCountKey]?.toString() ?? '';

        final sales = _parseAmount(salesStr);
        final custCount = _parseInt(custCountStr);

        if (sales > 0 || custCount > 0) {
          result[salesmanCode]!.brandSales[brandCode] = BrandSalesInfo(
            brandCode: brandCode,
            brandName: brandName,
            salesAmount: sales,
            customerCount: custCount,
          );
        }
      }
    }

    return result;
  }

  /// Parse aging data
  static Map<String, AgingDataForSalesman> parseAgingData(
    Map<String, dynamic> response,
    List<String> salesmenCodes,
    String? specificArea,
  ) {
    final Map<String, AgingDataForSalesman> result = {};

    for (final salesmanCode in salesmenCodes) {
      result[salesmanCode] = AgingDataForSalesman(
        salesmanCode: salesmanCode,
        total: 0,
        aging53Plus: 0,
      );
    }

    final rows = response['rows'] as List<dynamic>? ?? [];

    for (final row in rows) {
      final salesmanCode = row['shownCont.salesman'] as String? ?? '';
      final area = row['shownCont.area'] as String? ?? '';

      // Filter by area if specified
      if (specificArea != null &&
          specificArea.isNotEmpty &&
          area != specificArea) {
        continue;
      }

      if (result.containsKey(salesmanCode)) {
        final total = _parseAmount(row['total']?.toString() ?? '');
        final aging53Plus = _parseAmount(row['53+days']?.toString() ?? '');

        result[salesmanCode]!.total += total;
        result[salesmanCode]!.aging53Plus += aging53Plus;
      }
    }

    return result;
  }

  /// Parse periodic sales for area
  static Map<String, double> parsePeriodicSalesForArea(
    Map<String, dynamic> response,
  ) {
    final Map<String, double> result = {};

    final rows = response['rows'] as List<dynamic>? ?? [];

    for (final row in rows) {
      final brandCode = row['item.brand'] as String? ?? '';
      final totalStr = row['total']?.toString() ?? '';

      result[brandCode] = _parseAmount(totalStr);
    }

    return result;
  }

  /// Helper to parse amount string (removes commas)
  static double _parseAmount(String value) {
    if (value.isEmpty) return 0;
    try {
      return double.parse(value.replaceAll(',', ''));
    } catch (e) {
      return 0;
    }
  }

  /// Helper to parse integer string
  static int _parseInt(String value) {
    if (value.isEmpty) return 0;
    try {
      return int.parse(value.replaceAll(',', ''));
    } catch (e) {
      return 0;
    }
  }

  static Future<List<AccountStatement>> getAccountStatements({
    required String contactCode,
    required String fromDate,
    required String toDate,
  }) async {
    final String statementsUrl =
        'https://gw.bisan.com/api/v2/jalaf/REPORT/customerStatement.json?search=fromDate:$fromDate,toDate:$toDate,reference:$contactCode,currency:01,branch:00,showTotalPerAct:true,includeCashMov:true,showSettledAmounts:false,lg_status:مرحل';

    final response = await makeApiRequest(
      url: statementsUrl,
      method: 'GET',
    );

    final rows = response['rows'] as List;
    return rows.map((row) => AccountStatement.fromJson(row)).toList();
  }

  static Future<List<AccountStatementDetail>> getAccountStatementDetails({
    required String contactCode,
    required String fromDate,
    required String toDate,
  }) async {
    final String detailsUrl =
        'https://gw.bisan.com/api/v2/jalaf/REPORT/customerStatementDetail.json?search=fromDate:$fromDate,toDate:$toDate,reference:$contactCode,includeCashMov:true,priceIncludeTax:true,showCashInfo:true,showItemInfo:true,selectAll:true,lg_status:مرحل';

    final response = await makeApiRequest(
      url: detailsUrl,
      method: 'GET',
    );

    final rows = response['rows'] as List;
    return rows.map((row) => AccountStatementDetail.fromJson(row)).toList();
  }

  // NEW METHODS FOR CUSTOMER OPENING

  static Future<Map<String, dynamic>> createContact(
      Map<String, dynamic> contactData) async {
    const String createContactUrl = 'https://gw.bisan.com/api/v2/jalaf/contact';

    try {
      print('DEBUG: Creating contact with data: ${json.encode(contactData)}');

      final response = await makeApiRequest(
        url: createContactUrl,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: contactData,
      );

      print('DEBUG: Contact creation response: ${json.encode(response)}');
      return response;
    } catch (e) {
      print('DEBUG: createContact error: $e');
      rethrow;
    }
  }

  /// NEW: Enhanced contact creation with offline support
  /// Use this method instead of the original createContact
  static Future<Map<String, dynamic>> createContactWithOfflineSupport({
    required Map<String, dynamic> contactData,
    required String userId,
  }) async {
    final offlineService = OfflineContactService();

    return await offlineService.createContact(
      contactData: contactData,
      userId: userId,
      apiCreateFunction: createContact, // Pass the original method
    );
  }

// Add these new methods for fuel management to the existing ApiService class:

  /// UPDATED: Get cost centers with caching
  static Future<List<Map<String, dynamic>>> getCostCenters() async {
    const String costCentersUrl =
        'https://gw.bisan.com/api/v2/jalaf/costCenter?fields=name,code';

    try {
      // NEW: Use cached request
      final response = await getCachedApiRequest(
        url: costCentersUrl,
        method: 'GET',
        cacheType: 'cost_centers',
        cacheKey: 'all',
        useCache: true,
      );

      final rows = response['rows'] as List;

      // Filter cost centers with codes between 006500 and 006999
      final filteredRows = rows.where((row) {
        final code = row['code'] as String;
        if (code.length >= 6) {
          final numericPart = int.tryParse(code.substring(0, 6)) ?? 0;
          return numericPart >= 6500 && numericPart <= 6999;
        }
        return false;
      }).toList();

      return filteredRows.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching cost centers: $e');
      rethrow;
    }
  }

  /// UPDATED: Get fuel types with caching
  static Future<List<Map<String, dynamic>>> getFuelTypes() async {
    const String fuelTypesUrl =
        'https://gw.bisan.com/api/v2/jalaf/item?fields=name,code,itemPrice.price&search=code~B0000';

    try {
      // NEW: Use cached request
      final response = await getCachedApiRequest(
        url: fuelTypesUrl,
        method: 'GET',
        cacheType: 'fuel_types',
        cacheKey: 'all',
        useCache: true,
      );

      final rows = response['rows'] as List;
      return rows.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching fuel types: $e');
      rethrow;
    }
  }

  /// UPDATED: Post journal voucher with offline queue
  static Future<Map<String, dynamic>> postJournalVoucher({
    required Map<String, dynamic> journalData,
  }) async {
    const String journalUrl =
        'https://gw.bisan.com/api/v2/jalaf/journalVoucher';

    try {
      print('DEBUG: Posting journal voucher');

      // NEW: Use makeApiRequest with offline queue support
      final response = await makeApiRequest(
        url: journalUrl,
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: journalData,
        queueIfOffline: true, // Enable offline queue
        operationType: 'post_journal_voucher',
      );

      print('DEBUG: Journal voucher posted successfully');
      return response;
    } catch (e) {
      print('DEBUG: postJournalVoucher error: $e');
      rethrow;
    }
  }

  /// UPDATED: Get periodic sales report with caching and salesman support
  static Future<PeriodicSalesReport> getPeriodicSalesReport({
    required String fromDate,
    required String toDate,
    AreaSelection areaSelection = AreaSelection.all,
    Salesman? selectedSalesman, // Add this parameter
  }) async {
    try {
      // Base URL with fixed parameters
      String reportUrl =
          'https://gw.bisan.com/api/v2/jalaf/REPORT/periodicSalesRpt?search='
          'fromDate:$fromDate,'
          'toDate:$toDate,'
          'reportType:مبلغ,'
          'groupType:حسب العلامة التجارية,'
          'reportCurrency:01,'
          'brand_From:001,'
          'brand_To:905,'
          'fromContactType:001,'
          'toContactType:009,'
          'branch_From:00,'
          'branch_To:00,'
          'periodType:شهري,'
          'useContactSalesman:true';

      // Add area parameters if needed
      final areaRange = DateRangeHelper.getAreaRange(areaSelection);
      if (areaRange != null) {
        reportUrl +=
            ',fromArea:${areaRange['fromArea']},toArea:${areaRange['toArea']}';
      }

      // NEW: Add salesman parameters if selected
      if (selectedSalesman != null) {
        reportUrl +=
            ',fromSalesman:${selectedSalesman.code},toSalesman:${selectedSalesman.code}';
        print(
            'DEBUG: Added salesman filter: ${selectedSalesman.code} - ${selectedSalesman.name}');
      }

      print('DEBUG: Periodic Sales Report URL: $reportUrl');

      // Generate cache key (include salesman in cache key)
      final cacheKey =
          '${fromDate}_${toDate}_${areaSelection.toString()}_${selectedSalesman?.code ?? 'all'}';

      // Add retry logic for 502 errors
      int maxRetries = 3;
      int retryDelay = 2; // seconds

      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          print(
              'DEBUG: Periodic Sales API request attempt $attempt/$maxRetries');

          // NEW: Use cached request with offline support
          final response = await getCachedApiRequest(
            url: reportUrl,
            method: 'GET',
            cacheType: 'periodic_sales',
            cacheKey: cacheKey,
            useCache: true,
          );

          print('DEBUG: Periodic Sales API request successful');
          return PeriodicSalesReport.fromJson(response);
        } catch (e) {
          print(
              'DEBUG: Periodic Sales API request attempt $attempt failed: $e');

          if (attempt == maxRetries) {
            throw Exception(
                'API request failed after $maxRetries attempts: $e');
          }

          // Wait before retry
          print('DEBUG: Waiting ${retryDelay}s before retry...');
          await Future.delayed(Duration(seconds: retryDelay));
          retryDelay *= 2; // Exponential backoff
        }
      }

      throw Exception('Unexpected error in Periodic Sales API request logic');
    } catch (e) {
      print('DEBUG: getPeriodicSalesReport error: $e');
      rethrow;
    }
  }

  static Future<List<ContactStatementResult>> getGroupAccountStatements({
    required List<Contact> contacts,
    required String fromDate,
    required String toDate,
    Function(int current, int total, String contactName)? onProgress,
  }) async {
    final results = <ContactStatementResult>[];
    int current = 0;

    for (final contact in contacts) {
      current++;
      if (onProgress != null) {
        onProgress(current, contacts.length, contact.nameAr);
      }

      try {
        final statements = await getAccountStatements(
          contactCode: contact.code,
          fromDate: fromDate,
          toDate: toDate,
        );

        results.add(ContactStatementResult(
          contact: contact,
          statements: statements,
          success: true,
        ));

        // Small delay to avoid overwhelming the API
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        print('Error loading statements for ${contact.nameAr}: $e');
        results.add(ContactStatementResult(
          contact: contact,
          statements: [],
          success: false,
          errorMessage: e.toString(),
        ));
      }
    }

    return results;
  }

  static Future<List<FuelContact>> getFuelContactsFromBisan() async {
    const String fuelContactsUrl =
        'https://gw.bisan.com/api/v2/jalaf/contact?fields=code,nameAR&search=type:049';

    try {
      print('DEBUG: Fetching fuel contacts from Bisan API');

      final response = await getCachedApiRequest(
        url: fuelContactsUrl,
        method: 'GET',
        cacheType: 'fuel_contacts',
        cacheKey: 'all',
        useCache: true,
      );

      final rows = response['rows'] as List;
      final contacts =
          rows.map((row) => FuelContact.fromBisanJson(row)).toList();

      print('DEBUG: Fetched ${contacts.length} fuel contacts from Bisan API');
      return contacts;
    } catch (e) {
      print('DEBUG: getFuelContactsFromBisan error: $e');
      rethrow;
    }
  }

  // Add this method to lib/services/api_service.dart
  /// Get price list report
  static Future<PriceListReport> getPriceListReport() async {
    try {
      const String priceListUrl =
          'https://gw.bisan.com/api/v2/jalaf/REPORT/priceListRpt?search=fromPriceList:P,toPriceList:S,brand_From:001,brand_To:905&fields=item,item.name,item.brand,unit,partNumber,packVolume,P_currency,P_rawPrice,P_taxPrice,S_currency,S_rawPrice,S_taxPrice';

      print('DEBUG: Getting price list report');

      // Use cached request with offline support
      final response = await getCachedApiRequest(
        url: priceListUrl,
        method: 'GET',
        cacheType: 'price_list',
        cacheKey: 'P_to_S',
        useCache: true,
      );

      print('DEBUG: Price list API request successful');
      return PriceListReport.fromJson(response);
    } catch (e) {
      print('DEBUG: getPriceListReport error: $e');
      rethrow;
    }
  }

  /// Get items from Bisan API
  static Future<List<Item>> getItems() async {
    const String itemsUrl =
        'https://gw.bisan.com/api/v2/jalaf/item?fields=code,nameAR,brand,brand.nameAR,itemCategory,itemCategory.nameAR,name,unitList.unit,unitList.packVolume,partNumber,unit,warranty&search=enabled:yes AND brand>:001 AND brand<:905';

    try {
      print('DEBUG: Fetching items from Bisan API');

      final response = await makeApiRequest(
        url: itemsUrl,
        method: 'GET',
      );

      final rows = response['rows'] as List;
      final items = rows.map((row) => Item.fromBisanJson(row)).toList();

      print('DEBUG: Fetched ${items.length} items from Bisan API');
      return items;
    } catch (e) {
      print('DEBUG: getItems error: $e');
      rethrow;
    }
  }

  /// Get warehouses from Bisan API
  static Future<List<Warehouse>> getWarehouses() async {
    const String warehousesUrl =
        'https://gw.bisan.com/api/v2/jalaf/warehouse?fields=code,nameAR&search=enabled:yes';

    try {
      print('DEBUG: Fetching warehouses from Bisan API');

      final response = await makeApiRequest(
        url: warehousesUrl,
        method: 'GET',
      );

      final rows = response['rows'] as List;
      final warehouses =
          rows.map((row) => Warehouse.fromBisanJson(row)).toList();

      print('DEBUG: Fetched ${warehouses.length} warehouses from Bisan API');
      return warehouses;
    } catch (e) {
      print('DEBUG: getWarehouses error: $e');
      rethrow;
    }
  }

// Add this new method to ApiService class

  /// Get last price for an item from a specific contact
  static Future<double?> getLastItemPrice({
    required String contactCode,
    required String itemCode,
  }) async {
    try {
      final now = DateTime.now();
      final oneYearAgo = DateTime(now.year - 1, now.month, now.day);

      final fromDate =
          '${oneYearAgo.year}-${oneYearAgo.month.toString().padLeft(2, '0')}-${oneYearAgo.day.toString().padLeft(2, '0')}';
      final toDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final String priceUrl =
          'https://gw.bisan.com/api/v2/jalaf/REPORT/salesAmountDetail?search='
          'fromDate:$fromDate,'
          'toDate:$toDate,'
          'fromContact:$contactCode,'
          'toContact:$contactCode,'
          'item_From:$itemCode,'
          'item_To:$itemCode';

      print(
          'DEBUG: Getting last price for item $itemCode from contact $contactCode');

      final response = await makeApiRequest(
        url: priceUrl,
        method: 'GET',
      );

      final rows = response['rows'] as List?;

      if (rows == null || rows.isEmpty) {
        print(
            'DEBUG: No sales records found for item $itemCode to contact $contactCode');
        return null;
      }

      // Sort rows by docDate to get the most recent
      final sortedRows = List<Map<String, dynamic>>.from(rows);
      sortedRows.sort((a, b) {
        try {
          final dateA = _parseDocDate(a['docDate'] as String);
          final dateB = _parseDocDate(b['docDate'] as String);
          return dateB.compareTo(dateA); // Descending order (most recent first)
        } catch (e) {
          return 0;
        }
      });

      // Find the first row with a valid price
      for (final row in sortedRows) {
        final priceStr = row['price'] as String?;

        if (priceStr != null && priceStr.isNotEmpty) {
          final price = double.tryParse(priceStr.replaceAll(',', ''));
          if (price != null && price > 0) {
            print(
                'DEBUG: Found last price $price for item $itemCode (date: ${row['docDate']})');
            return price;
          }
        }
      }

      print('DEBUG: No valid price found in sales records for item $itemCode');
      return null;
    } catch (e) {
      print('DEBUG: getLastItemPrice error: $e');
      rethrow;
    }
  }

  /// Helper method to parse docDate from format "DD/MM/YYYY"
  static DateTime _parseDocDate(String docDate) {
    try {
      final parts = docDate.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (e) {
      print('DEBUG: Error parsing docDate: $docDate - $e');
    }
    return DateTime.now();
  }

  /// Get last prices for multiple items
  static Future<Map<String, double?>> getLastItemPrices({
    required String contactCode,
    required List<String> itemCodes,
    Function(int current, int total)? onProgress,
  }) async {
    final Map<String, double?> prices = {};

    for (int i = 0; i < itemCodes.length; i++) {
      if (onProgress != null) {
        onProgress(i + 1, itemCodes.length);
      }

      final itemCode = itemCodes[i];
      try {
        final price = await getLastItemPrice(
          contactCode: contactCode,
          itemCode: itemCode,
        );
        prices[itemCode] = price;
      } catch (e) {
        print('DEBUG: Error getting price for item $itemCode: $e');
        prices[itemCode] = null;
      }
    }

    return prices;
  }

  /// Submit sales return to Bisan API
  static Future<Map<String, dynamic>?> submitSalesReturn({
    required String contactCode,
    required String warehouseCode,
    required String returnReasonCode,
    required String comment,
    required String username,
    required List<Map<String, dynamic>> orderDetails,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      final bisanRequestBody = {
        'TRANSACTION_ID': timestamp,
        'stationId': 'STOCKCOUNT',
        'approval': 'entry',
        'record': {
          'contact': contactCode,
          'branch': '00',
          'costCenter': '000000',
          'comment': 'Jala App - $username - $comment',
          'warehouse': warehouseCode,
          'returnReason': returnReasonCode,
          'orderDetail': orderDetails,
        },
      };

      print('DEBUG: Submitting sales return to Bisan');

      final response = await makeApiRequest(
        url: 'https://gw.bisan.com/api/v2/jalaf/salesReturn',
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: bisanRequestBody,
        queueIfOffline: true,
        operationType: 'submit_sales_return',
      );

      print('DEBUG: Sales return submitted successfully');
      return response;
    } catch (e) {
      print('DEBUG: submitSalesReturn error: $e');
      rethrow;
    }
  }

  /// UPDATED: Send email with offline queue
  static Future<void> sendEmail({
    required String to,
    required String subject,
    required String body,
    List<Map<String, dynamic>>? attachments,
  }) async {
    try {
      // Validate and ensure attachment format
      List<Map<String, dynamic>>? validatedAttachments;

      if (attachments != null && attachments.isNotEmpty) {
        validatedAttachments = [];
        for (final attachment in attachments) {
          final validatedAttachment = <String, dynamic>{};

          validatedAttachment['name'] =
              attachment['name'] ?? attachment['Name'] ?? 'file';
          validatedAttachment['ContentBytes'] =
              attachment['ContentBytes'] ?? attachment['contentBytes'] ?? '';
          validatedAttachment['contentType'] = attachment['contentType'] ??
              attachment['ContentType'] ??
              'application/octet-stream';

          if (validatedAttachment['ContentBytes'].toString().isNotEmpty) {
            validatedAttachments.add(validatedAttachment);
          }
        }
      }

      final emailData = <String, dynamic>{
        'to': to,
        'subject': subject,
        'body': body,
      };

      if (validatedAttachments != null && validatedAttachments.isNotEmpty) {
        emailData['attachments'] = validatedAttachments;
      }

      print('DEBUG: Sending email to: $to');

      // Check if online (for email, we might want to always queue if offline)
      if (PlatformUtils.isMobile) {
        final isOnline = await _isOnline();
        if (!isOnline) {
          // Queue email for later
          final user = await SupabaseService.getCurrentUser();
          await _offlineQueue.addOperation(
            operationType: 'send_email',
            endpoint: _emailAutomateUrl,
            method: 'POST',
            data: emailData,
            userId: user?.id ?? 'unknown',
          );

          print('Email queued for later sending');
          return;
        }
      }

      // Send email immediately
      final response = await http.post(
        Uri.parse(_emailAutomateUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(emailData),
      );

      print('DEBUG: Email API response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 202) {
        print('DEBUG: Email sent successfully');
      } else {
        throw Exception(
            'Email sending failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('DEBUG: sendEmail error: $e');
      rethrow;
    }
  }
}
