// lib/services/fuel_service.dart - COMPLETE WEB-COMPATIBLE VERSION

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:jala_as/services/connectivity_service.dart';
import 'package:jala_as/services/fuel_cache_service.dart';
import 'package:jala_as/services/image_upload_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/fuel_models.dart';
import 'api_service.dart';
import 'supabase_service.dart';

// Imports for offline support (mobile only)
import 'local_database_service.dart';
import 'offline_queue_service.dart';
import '../utils/platform_utils.dart';

class FuelService {
  // Offline support services (mobile only)
  static final LocalDatabaseService _localDb = LocalDatabaseService();
  static final OfflineQueueService _offlineQueue = OfflineQueueService();
  static bool _isInitialized = false;
  final _supabase = Supabase.instance.client;

  final FuelCacheService _cacheService = FuelCacheService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final ImageUploadService _imageService = ImageUploadService();

  StreamSubscription<bool>? _connectivitySubscription;
  bool _isSyncing = false;

  // ==================== INITIALIZATION ====================

  /// Initialize service and set up auto-sync
  Future<void> initialize() async {
    try {
      print('🚀 Initializing Fuel Service...');

      // Initialize connectivity monitoring
      await _connectivityService.initialize();

      // Web: Skip cache initialization
      if (kIsWeb) {
        print('ℹ️ Running on web - cache not available');
        print('✅ Fuel Service initialized (web mode)');
        return;
      }

      // Mobile: Full initialization with cache
      print('📱 Mobile platform - initializing with cache support');

      // Listen to connectivity changes for auto-sync (mobile only)
      _connectivitySubscription =
          _connectivityService.connectivityStream.listen(
        (isOnline) async {
          if (isOnline && !_isSyncing) {
            print('🌐 Internet restored - triggering auto-sync');
            await _autoSyncWhenOnline();
          }
        },
      );

      // Initial sync if online
      if (_connectivityService.isOnline) {
        print('🌐 Online - performing initial sync');
        await _autoSyncWhenOnline();
      } else {
        print('📴 Offline - will use cached data');
      }

      print('✅ Fuel service initialized successfully');
    } catch (e) {
      print('❌ Error initializing fuel service: $e');
    }
  }

  /// Auto-sync when internet becomes available (mobile only)
  Future<void> _autoSyncWhenOnline() async {
    if (kIsWeb) return; // Skip for web
    if (_isSyncing) {
      print('⏳ Sync already in progress...');
      return;
    }

    _isSyncing = true;
    print('🔄 Starting auto-sync process...');

    try {
      // 1. Sync assigned cost centers if cache is old or empty
      final needsRefresh = await _cacheService.needsCacheRefresh();
      final hasCached = await _cacheService.hasCachedData();

      if (needsRefresh || !hasCached) {
        print('📥 Cache needs refresh - fetching from Supabase...');
        await _refreshAssignedCostCentersCache();
      } else {
        final cacheAge = await _cacheService.getCacheAgeInHours();
        print('✓ Cache is fresh (${cacheAge} hours old) - skipping refresh');
      }

      // 2. Process pending fuel records
      final pendingCount = await _cacheService.getPendingCount();
      if (pendingCount > 0) {
        print('📤 Processing $pendingCount pending fuel records...');
        final result = await _cacheService.processPendingFuelRecords(
          submitToSupabase: _submitFuelRecordToSupabase,
        );

        print(
            '✅ Pending records processed: ${result['success']} succeeded, ${result['failed']} failed');

        if (result['success'] > 0) {
          print('🎉 Successfully synced ${result['success']} records!');
        }
      } else {
        print('✓ No pending records to process');
      }

      print('✅ Auto-sync completed successfully');
    } catch (e) {
      print('❌ Auto-sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Get assigned cost centers (WEB & MOBILE COMPATIBLE)
  Future<List<AssignCostCenter>> getAssignedCostCenters() async {
    try {
      print('📋 Getting assigned cost centers...');

      // WEB: Always fetch from Supabase directly
      if (kIsWeb) {
        print('🌐 Web platform - fetching from Supabase');

        if (!_connectivityService.isOnline) {
          throw Exception('يرجى التحقق من اتصال الإنترنت');
        }

        return await _fetchFromSupabase();
      }

      // MOBILE: Use online/offline logic with cache
      if (_connectivityService.isOnline) {
        print('🌐 Mobile online - fetching from Supabase');
        try {
          final data = await _fetchFromSupabase();

          // Update cache in background
          await _cacheService.syncAssignedCostCentersFromSupabase(data);
          print('💾 Cache updated with ${data.length} records');

          return data;
        } catch (e) {
          print('❌ Error fetching from Supabase: $e');
          print('📴 Attempting to load from cache...');

          // Fallback to cache
          final cached = await _cacheService.getCachedAssignedCostCenters();
          if (cached.isNotEmpty) {
            print('✅ Loaded ${cached.length} records from cache');
            return cached;
          }

          rethrow;
        }
      } else {
        // Mobile offline: use cache
        print('📴 Mobile offline - loading from cache');
        final cached = await _cacheService.getCachedAssignedCostCenters();

        if (cached.isEmpty) {
          throw Exception(
              'لا يوجد اتصال بالإنترنت ولا توجد بيانات محفوظة محلياً');
        }

        print('✅ Loaded ${cached.length} records from cache');
        return cached;
      }
    } catch (e) {
      print('❌ Error in getAssignedCostCenters: $e');
      rethrow;
    }
  }

  /// Fetch assigned cost centers from Supabase
  Future<List<AssignCostCenter>> _fetchFromSupabase() async {
    final response = await _supabase.from('assign_cost_centers').select('''
      id,
      number,
      cost_center_id,
      fuel_type_id,
      created_by,
      created_at,
      updated_at,
      cost_center:cost_centers(
        id,
        code,
        name,
        created_at,
        updated_at
      ),
      fuel_type:fuel_types(
        id,
        code,
        name,
        price,
        created_at,
        updated_at
      )
    ''').order('number', ascending: true);

    final costCenters = (response as List).map<AssignCostCenter>((json) {
      return AssignCostCenter.fromJson(json);
    }).toList();

    print(
        '✅ Fetched ${costCenters.length} assigned cost centers from Supabase');
    return costCenters;
  }

  /// Refresh assigned cost centers cache (mobile only)
  Future<void> _refreshAssignedCostCentersCache() async {
    if (kIsWeb) return;

    try {
      print('🔄 Refreshing assigned cost centers cache...');
      final costCenters = await _fetchFromSupabase();
      await _cacheService.syncAssignedCostCentersFromSupabase(costCenters);
      print(
          '✅ Cache refreshed successfully with ${costCenters.length} records');
    } catch (e) {
      print('❌ Failed to refresh cache: $e');
      rethrow;
    }
  }

  /// Submit fuel record with image support (WEB & MOBILE COMPATIBLE)
  Future<Map<String, dynamic>> submitFuelRecordWithImage({
    required DateTime fillingDate,
    required String truckNumber,
    required int assignCostCenterId,
    required int fuelTypeId,
    required double amount,
    required double quantity,
    String? meterReading,
    File? imageFile,
    required String userId,
    int? fuelContactId, // NEW
    String? fuelContactCode, // NEW
  }) async {
    print('📝 Submitting fuel record for truck: $truckNumber');

    String? imageUrl;
    String? imageName;
    int? imageSize;
    String? mimeType;

    // Handle image upload/save
    if (imageFile != null) {
      if (_connectivityService.isOnline) {
        print('🌐 Uploading image to Supabase...');
        final uploadResult = await _imageService.uploadImageToSupabase(
          imageFile: imageFile,
          userId: userId,
        );

        if (uploadResult != null) {
          imageUrl = uploadResult['image_url'];
          imageName = uploadResult['image_name'];
          imageSize = uploadResult['image_size'];
          mimeType = uploadResult['mime_type'];
          print('✅ Image uploaded successfully');
        } else if (!kIsWeb) {
          // Save locally only on mobile
          print('⚠️ Image upload failed, will save locally');
          final localResult = await _imageService.saveImageLocally(
            imageFile: imageFile,
            userId: userId,
          );
          if (localResult != null) {
            imageUrl = localResult['image_url'];
            imageName = localResult['image_name'];
            imageSize = localResult['image_size'];
            mimeType = localResult['mime_type'];
          }
        }
      } else if (!kIsWeb) {
        // Save locally only on mobile
        print('📴 Saving image locally for offline use...');
        final localResult = await _imageService.saveImageLocally(
          imageFile: imageFile,
          userId: userId,
        );
        if (localResult != null) {
          imageUrl = localResult['image_url'];
          imageName = localResult['image_name'];
          imageSize = localResult['image_size'];
          mimeType = localResult['mime_type'];
          print('✅ Image saved locally');
        }
      }
    }

    // Create record data WITHOUT 'id' field
    final recordData = {
      'filling_date': fillingDate.toIso8601String().split('T')[0],
      'truck_number': truckNumber,
      'assign_cost_center_id': assignCostCenterId,
      'fuel_type_id': fuelTypeId,
      'amount': amount,
      'quantity': quantity,
      'meter_reading': meterReading,
      'image_url': imageUrl,
      'image_name': imageName,
      'image_size': imageSize,
      'mime_type': mimeType,
      'user_id': userId,
      'fuel_contact_id': fuelContactId, // NEW
      'fuel_contact_code': fuelContactCode, // NEW
    };

    // WEB: Must be online to submit
    if (kIsWeb) {
      if (!_connectivityService.isOnline) {
        throw Exception('لا يوجد اتصال بالإنترنت');
      }

      print('🌐 Web - submitting directly to Supabase...');
      final success = await _submitFuelRecordToSupabase(recordData);

      if (success) {
        return {
          'success': true,
          'message': 'تم إضافة السجل بنجاح',
          'submitted': true,
          'pending': false,
        };
      } else {
        throw Exception('فشل الإرسال إلى الخادم');
      }
    }

    // MOBILE: Online or offline submission
    if (_connectivityService.isOnline) {
      try {
        print('🌐 Mobile online - submitting to Supabase...');
        final success = await _submitFuelRecordToSupabase(recordData);

        if (success) {
          return {
            'success': true,
            'message': 'تم إضافة السجل بنجاح',
            'submitted': true,
            'pending': false,
          };
        } else {
          throw Exception('فشل الإرسال إلى الخادم');
        }
      } catch (e) {
        print('❌ Failed to submit online: $e');
        print('💾 Saving to pending queue...');

        await _saveToPending(
          fillingDate: fillingDate,
          truckNumber: truckNumber,
          assignCostCenterId: assignCostCenterId,
          fuelTypeId: fuelTypeId,
          amount: amount,
          quantity: quantity,
          meterReading: meterReading,
          imageUrl: imageUrl,
          imageName: imageName,
          imageSize: imageSize,
          mimeType: mimeType,
          userId: userId,
          fuelContactId: fuelContactId, // NEW
          fuelContactCode: fuelContactCode, // NEW
        );

        return {
          'success': true,
          'message':
              'حدث خطأ في الإرسال. تم حفظ السجل وسيتم إرساله تلقائياً لاحقاً',
          'submitted': false,
          'pending': true,
        };
      }
    } else {
      // Mobile offline: save to pending
      print('📴 Mobile offline - saving to pending queue...');

      await _saveToPending(
        fillingDate: fillingDate,
        truckNumber: truckNumber,
        assignCostCenterId: assignCostCenterId,
        fuelTypeId: fuelTypeId,
        amount: amount,
        quantity: quantity,
        meterReading: meterReading,
        imageUrl: imageUrl,
        imageName: imageName,
        imageSize: imageSize,
        mimeType: mimeType,
        userId: userId,
        fuelContactId: fuelContactId, // NEW
        fuelContactCode: fuelContactCode, // NEW
      );

      final pendingCount = await _cacheService.getPendingCount();
      print('✅ Saved to pending queue (Total pending: $pendingCount)');

      return {
        'success': true,
        'message':
            'لا يوجد اتصال بالإنترنت. تم حفظ السجل ($pendingCount في الانتظار) وسيتم إرساله تلقائياً عند الاتصال',
        'submitted': false,
        'pending': true,
        'pendingCount': pendingCount,
      };
    }
  }

  /// Submit fuel record to Supabase - ENSURING NO 'id' FIELD
  Future<bool> _submitFuelRecordToSupabase(
      Map<String, dynamic> recordData) async {
    try {
      print('📤 Inserting record into fuel_filling_records...');

      // Create clean data with ONLY allowed fields
      final cleanData = {
        'filling_date': recordData['filling_date'],
        'truck_number': recordData['truck_number'],
        'assign_cost_center_id': recordData['assign_cost_center_id'],
        'fuel_type_id': recordData['fuel_type_id'],
        'amount': recordData['amount'],
        'quantity': recordData['quantity'],
        'meter_reading': recordData['meter_reading'],
        'image_url': recordData['image_url'],
        'image_name': recordData['image_name'],
        'image_size': recordData['image_size'],
        'mime_type': recordData['mime_type'],
        'user_id': recordData['user_id'],
        'fuel_contact_id': recordData['fuel_contact_id'], // NEW
        'fuel_contact_code': recordData['fuel_contact_code'], // NEW
      };

      // Remove null values
      cleanData.removeWhere((key, value) => value == null);

      print('📝 Clean data fields: ${cleanData.keys.join(", ")}');

      // Insert without specifying id
      final result = await _supabase
          .from('fuel_filling_records')
          .insert(cleanData)
          .select('id')
          .single();

      print('✅ Record inserted successfully with ID: ${result['id']}');
      return true;
    } catch (e) {
      print('❌ Error submitting to Supabase: $e');
      return false;
    }
  }

  /// Save fuel record to pending queue (mobile only)
  Future<void> _saveToPending({
    required DateTime fillingDate,
    required String truckNumber,
    required int assignCostCenterId,
    required int fuelTypeId,
    required double amount,
    required double quantity,
    String? meterReading,
    String? imageUrl,
    String? imageName,
    int? imageSize,
    String? mimeType,
    required String userId,
    int? fuelContactId, // NEW
    String? fuelContactCode, // NEW
  }) async {
    if (kIsWeb) return;

    final recordId = await _cacheService.addPendingFuelRecord(
      fillingDate: fillingDate,
      truckNumber: truckNumber,
      assignCostCenterId: assignCostCenterId,
      fuelTypeId: fuelTypeId,
      amount: amount,
      quantity: quantity,
      meterReading: meterReading,
      imageUrl: imageUrl,
      imageName: imageName,
      imageSize: imageSize,
      mimeType: mimeType,
      userId: userId,
      fuelContactId: fuelContactId, // NEW
      fuelContactCode: fuelContactCode, // NEW
    );

    print('💾 Saved to pending with ID: $recordId');
  }

  /// Get pending records count
  Future<int> getPendingRecordsCount() async {
    if (kIsWeb) return 0;
    return await _cacheService.getPendingCount();
  }

  /// Get pending records details
  Future<List<Map<String, dynamic>>> getPendingRecords() async {
    if (kIsWeb) return [];
    return await _cacheService.getPendingFuelRecords();
  }

  /// Manual sync trigger
  Future<Map<String, dynamic>> manualSync() async {
    print('🔄 Manual sync triggered');

    if (kIsWeb) {
      return {
        'success': false,
        'message': 'المزامنة غير متاحة على الويب',
      };
    }

    if (!_connectivityService.isOnline) {
      print('❌ Cannot sync - no internet connection');
      return {
        'success': false,
        'message': 'لا يوجد اتصال بالإنترنت',
      };
    }

    try {
      await _autoSyncWhenOnline();
      final pendingCount = await getPendingRecordsCount();

      return {
        'success': true,
        'message': pendingCount == 0
            ? 'تم المزامنة بنجاح - لا توجد سجلات معلقة'
            : 'المزامنة جارية - يوجد $pendingCount سجلات قيد الانتظار',
        'pendingCount': pendingCount,
      };
    } catch (e) {
      print('❌ Manual sync failed: $e');
      return {
        'success': false,
        'message': 'فشلت المزامنة: $e',
      };
    }
  }

  /// Force refresh cache
  Future<Map<String, dynamic>> forceRefreshCache() async {
    print('🔄 Force refresh cache triggered');

    if (kIsWeb) {
      return {
        'success': false,
        'message': 'ذاكرة التخزين المؤقت غير متاحة على الويب',
      };
    }

    if (!_connectivityService.isOnline) {
      return {
        'success': false,
        'message': 'لا يوجد اتصال بالإنترنت',
      };
    }

    try {
      await _refreshAssignedCostCentersCache();
      final count = await _cacheService.hasCachedData()
          ? (await _cacheService.getCachedAssignedCostCenters()).length
          : 0;

      return {
        'success': true,
        'message': 'تم تحديث البيانات ($count سجل)',
        'count': count,
      };
    } catch (e) {
      print('❌ Force refresh failed: $e');
      return {
        'success': false,
        'message': 'فشل التحديث: $e',
      };
    }
  }

  /// Get cache info for debugging
  Future<Map<String, dynamic>> getCacheInfo() async {
    if (kIsWeb) {
      return {
        'available': false,
        'reason': 'Cache only available on mobile',
      };
    }

    try {
      final hasCached = await _cacheService.hasCachedData();
      final lastSync = await _cacheService.getLastSyncTime();
      final pendingCount = await _cacheService.getPendingCount();
      final cacheAge = await _cacheService.getCacheAgeInHours();
      final cachedRecords = hasCached
          ? (await _cacheService.getCachedAssignedCostCenters()).length
          : 0;

      return {
        'available': true,
        'hasCachedData': hasCached,
        'cachedRecordsCount': cachedRecords,
        'lastSyncTime': lastSync?.toIso8601String(),
        'lastSyncTimeFormatted': lastSync != null
            ? '${lastSync.year}-${lastSync.month.toString().padLeft(2, '0')}-${lastSync.day.toString().padLeft(2, '0')} ${lastSync.hour.toString().padLeft(2, '0')}:${lastSync.minute.toString().padLeft(2, '0')}'
            : 'Never',
        'cacheAgeHours': cacheAge,
        'needsRefresh': await _cacheService.needsCacheRefresh(),
        'pendingRecords': pendingCount,
        'isOnline': _connectivityService.isOnline,
        'isSyncing': _isSyncing,
      };
    } catch (e) {
      print('❌ Error getting cache info: $e');
      return {
        'available': false,
        'error': e.toString(),
      };
    }
  }

  /// Clear all cache and pending records (mobile only)
  Future<void> clearAllCache() async {
    if (kIsWeb) return;
    print('🗑️ Clearing all cache and pending records...');
    await _cacheService.clearAll();
    print('✅ Cache cleared');
  }

  /// Check if service is online
  bool get isOnline => _connectivityService.isOnline;

  /// Get connectivity stream
  Stream<bool> get connectivityStream =>
      _connectivityService.connectivityStream;

  /// Dispose resources
  void dispose() {
    print('🔌 Disposing fuel service...');
    _connectivitySubscription?.cancel();
    _connectivityService.dispose();
  }

  // ==================== STATIC METHODS (Keep all existing ones) ====================

  static final SupabaseClient _client = Supabase.instance.client;

  static Future<List<FuelType>> getFuelTypes() async {
    try {
      final response = await _client
          .from('fuel_types')
          .select()
          .order('name', ascending: true);

      return response.map<FuelType>((json) => FuelType.fromJson(json)).toList();
    } catch (e) {
      print('getFuelTypes error: $e');
      rethrow;
    }
  }

// lib/services/fuel_service.dart - Update _submitFuelRecordToSupabase

// lib/services/fuel_service.dart - Update _submitFuelRecordToSupabase

  static Future<List<FuelContact>> getFuelContacts() async {
    try {
      print('📋 Getting fuel contacts...');

      final response = await _client
          .from('fuel_contacts')
          .select()
          .order('name', ascending: true);

      return response
          .map<FuelContact>((json) => FuelContact.fromSupabaseJson(json))
          .toList();
    } catch (e) {
      print('getFuelContacts error: $e');
      rethrow;
    }
  }

  /// Sync fuel contacts from Bisan to Supabase
  static Future<void> syncFuelContacts() async {
    try {
      print('🔄 Syncing fuel contacts from Bisan...');

      // Get from Bisan
      final bisanContacts = await ApiService.getFuelContactsFromBisan();

      // Clear existing data (optional - or you can use upsert)
      await _client.from('fuel_contacts').delete().neq('id', 0);

      // Insert new data
      final insertData =
          bisanContacts.map((c) => c.toSupabaseInsert()).toList();
      await _client.from('fuel_contacts').insert(insertData);

      print('✅ Synced ${bisanContacts.length} fuel contacts');
    } catch (e) {
      print('❌ Error syncing fuel contacts: $e');
      rethrow;
    }
  }

// In fuel_service.dart - make sure this method exists
  Future<List<FuelContact>> getCachedFuelContacts() async {
    if (kIsWeb) {
      // Web: always fetch from Supabase
      return await FuelService.getFuelContacts();
    }

    // Mobile: try online first, fallback to cache
    if (_connectivityService.isOnline) {
      try {
        print('📡 Fetching fuel contacts from Supabase...');
        final contacts = await FuelService.getFuelContacts();
        print('✓ Fetched ${contacts.length} contacts');

        // Cache for offline use
        await _cacheService.saveFuelContactsCache(contacts);
        print('✓ Cached contacts');

        return contacts;
      } catch (e) {
        print('❌ Error fetching fuel contacts: $e');
        // Fallback to cache
        return await _cacheService.getCachedFuelContacts();
      }
    } else {
      // Offline - use cache
      print('📴 Offline - loading fuel contacts from cache');
      return await _cacheService.getCachedFuelContacts();
    }
  }

  /// NEW: Check if device is online
  static Future<bool> _isOnline() async {
    if (!PlatformUtils.isMobile) return true;
    return _offlineQueue.isOnline;
  }

  /// NEW: Cache assign cost centers locally
  static Future<void> _cacheAssignCostCenters(
      List<AssignCostCenter> assignCostCenters) async {
    if (!PlatformUtils.isMobile) return;

    try {
      final data = {
        'assign_cost_centers':
            assignCostCenters.map((acc) => acc.toJson()).toList(),
        'cached_at': DateTime.now().toIso8601String(),
      };

      await _localDb.saveCachedData(
        dataType: 'assign_cost_centers',
        dataKey: 'all',
        data: data,
      );
      print('✓ Cached ${assignCostCenters.length} assign cost centers');
    } catch (e) {
      print('Error caching assign cost centers: $e');
    }
  }

  /// NEW: Get cached assign cost centers
  static Future<List<AssignCostCenter>?> _getCachedAssignCostCenters() async {
    if (!PlatformUtils.isMobile) return null;

    try {
      final cached = await _localDb.getCachedData(
        dataType: 'assign_cost_centers',
        dataKey: 'all',
      );

      if (cached != null && cached['assign_cost_centers'] != null) {
        final list = cached['assign_cost_centers'] as List;
        return list.map((json) => AssignCostCenter.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error getting cached assign cost centers: $e');
    }
    return null;
  }

  /// NEW: Sync assign cost centers from Supabase and cache
  static Future<List<AssignCostCenter>> syncAssignCostCenters() async {
    try {
      print('🔄 Syncing assign cost centers from Supabase...');

      // Get from Supabase
      final assignCostCenters = await SupabaseService.getAssignCostCenters();

      // Cache for offline use
      await _cacheAssignCostCenters(assignCostCenters);

      print('✓ Synced ${assignCostCenters.length} assign cost centers');
      return assignCostCenters;
    } catch (e) {
      print('Error syncing assign cost centers: $e');
      rethrow;
    }
  }

  /// NEW: Get assign cost centers (with offline support)
  static Future<List<AssignCostCenter>> getAssignCostCenters() async {
    try {
      // Check if online
      final isOnline = await _isOnline();

      if (!isOnline && PlatformUtils.isMobile) {
        print('Offline - loading assign cost centers from cache');
        final cached = await _getCachedAssignCostCenters();
        if (cached != null) {
          return cached;
        }
        throw Exception(
            'لا توجد بيانات شاحنات محفوظة - يرجى الاتصال بالإنترنت أولاً');
      }

      // Online - fetch from Supabase and cache
      return await syncAssignCostCenters();
    } catch (e) {
      print('Error getting assign cost centers: $e');

      // Try cache as fallback
      if (PlatformUtils.isMobile) {
        final cached = await _getCachedAssignCostCenters();
        if (cached != null) {
          print('Using cached assign cost centers as fallback');
          return cached;
        }
      }

      rethrow;
    }
  }

  /// NEW: Cache cost centers locally
  static Future<void> _cacheCostCenters(List<CostCenter> costCenters) async {
    if (!PlatformUtils.isMobile) return;

    try {
      final data = {
        'cost_centers': costCenters.map((cc) => cc.toJson()).toList(),
        'cached_at': DateTime.now().toIso8601String(),
      };

      await _localDb.saveCachedData(
        dataType: 'cost_centers',
        dataKey: 'all',
        data: data,
      );
      print('✓ Cached ${costCenters.length} cost centers');
    } catch (e) {
      print('Error caching cost centers: $e');
    }
  }

  /// NEW: Get cached cost centers
  static Future<List<CostCenter>?> _getCachedCostCenters() async {
    if (!PlatformUtils.isMobile) return null;

    try {
      final cached = await _localDb.getCachedData(
        dataType: 'cost_centers',
        dataKey: 'all',
      );

      if (cached != null && cached['cost_centers'] != null) {
        final list = cached['cost_centers'] as List;
        return list.map((json) => CostCenter.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error getting cached cost centers: $e');
    }
    return null;
  }

  /// NEW: Cache fuel types locally
  static Future<void> _cacheFuelTypes(List<FuelType> fuelTypes) async {
    if (!PlatformUtils.isMobile) return;

    try {
      final data = {
        'fuel_types': fuelTypes.map((ft) => ft.toJson()).toList(),
        'cached_at': DateTime.now().toIso8601String(),
      };

      await _localDb.saveCachedData(
        dataType: 'fuel_types',
        dataKey: 'all',
        data: data,
      );
      print('✓ Cached ${fuelTypes.length} fuel types');
    } catch (e) {
      print('Error caching fuel types: $e');
    }
  }

  /// NEW: Get cached fuel types
  static Future<List<FuelType>?> _getCachedFuelTypes() async {
    if (!PlatformUtils.isMobile) return null;

    try {
      final cached = await _localDb.getCachedData(
        dataType: 'fuel_types',
        dataKey: 'all',
      );

      if (cached != null && cached['fuel_types'] != null) {
        final list = cached['fuel_types'] as List;
        return list.map((json) => FuelType.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error getting cached fuel types: $e');
    }
    return null;
  }

  // ==================== UPDATED METHODS WITH OFFLINE SUPPORT ====================

  /// UPDATED: Get cost centers with offline cache
  static Future<List<CostCenter>> getCostCentersFromBisan() async {
    const String costCentersUrl =
        'https://gw.bisan.com/api/v2/jalaf/costCenter?fields=code,name';

    try {
      // Check if online
      final isOnline = await _isOnline();

      if (!isOnline && PlatformUtils.isMobile) {
        print('Offline - loading cost centers from cache');
        final cached = await _getCachedCostCenters();
        if (cached != null) {
          return cached;
        }
        throw Exception('لا توجد بيانات محفوظة - يرجى الاتصال بالإنترنت');
      }

      // Online - fetch from API
      final response = await ApiService.makeApiRequest(
        url: costCentersUrl,
        method: 'GET',
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

      final costCenters =
          filteredRows.map((row) => CostCenter.fromBisanJson(row)).toList();

      // Cache for offline use
      await _cacheCostCenters(costCenters);

      return costCenters;
    } catch (e) {
      print('Error fetching cost centers: $e');

      // Try cache as fallback
      if (PlatformUtils.isMobile) {
        final cached = await _getCachedCostCenters();
        if (cached != null) {
          print('Using cached cost centers as fallback');
          return cached;
        }
      }

      rethrow;
    }
  }

  /// UPDATED: Get fuel types with offline cache
  static Future<List<FuelType>> getFuelTypesFromBisan() async {
    const String fuelTypesUrl =
        'https://gw.bisan.com/api/v2/jalaf/item?fields=name,code,itemPrice.price&search=code~B0000';

    try {
      // Check if online
      final isOnline = await _isOnline();

      if (!isOnline && PlatformUtils.isMobile) {
        print('Offline - loading fuel types from cache');
        final cached = await _getCachedFuelTypes();
        if (cached != null) {
          return cached;
        }
        throw Exception('لا توجد بيانات محفوظة - يرجى الاتصال بالإنترنت');
      }

      // Online - fetch from API
      final response = await ApiService.makeApiRequest(
        url: fuelTypesUrl,
        method: 'GET',
      );

      final rows = response['rows'] as List;
      final fuelTypes = rows.map((row) => FuelType.fromBisanJson(row)).toList();

      // Cache for offline use
      await _cacheFuelTypes(fuelTypes);

      return fuelTypes;
    } catch (e) {
      print('Error fetching fuel types: $e');

      // Try cache as fallback
      if (PlatformUtils.isMobile) {
        final cached = await _getCachedFuelTypes();
        if (cached != null) {
          print('Using cached fuel types as fallback');
          return cached;
        }
      }

      rethrow;
    }
  }

  /// UPDATED: Sync cost centers with offline queue
  static Future<void> syncCostCenters() async {
    try {
      final costCenters = await getCostCentersFromBisan();
      await SupabaseService.syncCostCenters(costCenters);
      await _cacheCostCenters(costCenters);
    } catch (e) {
      print('Error syncing cost centers: $e');
      rethrow;
    }
  }

  /// UPDATED: Sync fuel types with offline queue
  static Future<void> syncFuelTypes() async {
    try {
      final fuelTypes = await getFuelTypesFromBisan();
      await SupabaseService.syncFuelTypes(fuelTypes);
      await _cacheFuelTypes(fuelTypes);
    } catch (e) {
      print('Error syncing fuel types: $e');
      rethrow;
    }
  }

  /// UPDATED: Post journal voucher with offline queue
  static Future<Map<String, dynamic>> postJournalVoucher({
    required List<CostCenterStatistics> statistics,
    required JournalVoucherData voucherData,
  }) async {
    try {
      final String transactionId =
          DateTime.now().millisecondsSinceEpoch.toString();
      final String formattedDate = _formatDate(voucherData.invoiceDate);

      final List<Map<String, dynamic>> lgDetails = [];
      double totalAmount = 0.0;

      // Generate journal entries for each cost center
      for (final stat in statistics) {
        if (stat.totalAmount > 0) {
          // Get cost center code from assigned cost center
          final costCenterCode =
              await _getCostCenterCodeByTruckNumber(stat.truckNumber);

          // Main amount entry (debit)
          lgDetails.add({
            "account": "7950",
            "currency": "01",
            "subAct": "",
            "reference": "",
            "branch": "00",
            "costCenter": costCenterCode,
            "activity": "0000",
            "dbValue": "",
            "dbAmount": stat.totalAmount.toStringAsFixed(2),
            "crValue": "",
            "crAmount": "",
            "dateFrom": "",
            "dateTo": "",
            "deliveryDate": "",
            "comment": "",
            "vatCode": voucherData.taxReference,
            "invoiceDate": formattedDate,
            "authorizedDealer": "",
            "authorizedDealerName": ""
          });

          // 16% tax entry (debit)
          final taxAmount = stat.totalAmount * 0.16;
          lgDetails.add({
            "account": "5500",
            "currency": "01",
            "subAct": "",
            "reference": "",
            "branch": "00",
            "costCenter": costCenterCode,
            "activity": "0000",
            "dbValue": "",
            "dbAmount": taxAmount.toStringAsFixed(2),
            "crValue": "",
            "crAmount": "",
            "dateFrom": "",
            "dateTo": "",
            "deliveryDate": "",
            "comment": "",
            "vatCode": voucherData.taxReference,
            "invoiceDate": formattedDate,
            "authorizedDealer": "",
            "authorizedDealerName": ""
          });

          totalAmount += stat.totalAmount + taxAmount;
        }
      }

      // Add credit entry
      lgDetails.add({
        "account": "2300",
        "currency": "01",
        "subAct": "",
        "reference": voucherData.contactNumber,
        "branch": "00",
        "costCenter": "000000",
        "activity": "0000",
        "dbValue": "",
        "dbAmount": "",
        "crValue": "",
        "crAmount": totalAmount.toStringAsFixed(2),
        "dateFrom": "",
        "dateTo": "",
        "deliveryDate": "",
        "comment": "",
        "vatCode": voucherData.taxReference,
        "invoiceDate": formattedDate,
        "authorizedDealer": "",
        "authorizedDealerName": ""
      });

      final journalData = {
        "TRANSACTION_ID": transactionId,
        "record": {
          "docDate": formattedDate,
          "branch": "00",
          "costCenter": "000000",
          "activity": "0000",
          "lgDetails": lgDetails,
          "contact": voucherData.contactNumber,
          "comment": voucherData.notes,
          "approval": "entry"
        }
      };

      // NEW: Check if online
      final isOnline = await _isOnline();

      if (!isOnline && PlatformUtils.isMobile) {
        // Queue for offline submission
        final user = await SupabaseService.getCurrentUser();
        await _offlineQueue.addOperation(
          operationType: 'post_journal_voucher',
          endpoint: 'https://gw.bisan.com/api/v2/jalaf/journalVoucher',
          method: 'POST',
          data: journalData,
          userId: user?.id ?? 'unknown',
        );

        print('Journal voucher queued for offline submission');
        return {
          'success': true,
          'queued': true,
          'message': 'تم حفظ القيد وسيتم إرساله عند الاتصال بالإنترنت',
          'transaction_id': transactionId,
        };
      }

      // Online - post immediately
      const String journalUrl =
          'https://gw.bisan.com/api/v2/jalaf/journalVoucher';

      final response = await ApiService.makeApiRequest(
        url: journalUrl,
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: journalData,
        queueIfOffline: true,
        operationType: 'post_journal_voucher',
      );

      return response;
    } catch (e) {
      print('Error posting journal voucher: $e');
      rethrow;
    }
  }

  /// NEW: Submit fuel filling record with offline support
  static Future<Map<String, dynamic>> submitFuelFillingRecord({
    required DateTime fillingDate,
    required String truckNumber,
    required int fuelTypeId,
    required double amount,
    required double quantity,
    required String meterReading,
    String? imageUrl,
    String? imageName,
    int? imageSize,
    String? mimeType,
    String? notes,
  }) async {
    try {
      // Validate form
      final validationError = validateFuelFillingForm(
        fillingDate: fillingDate,
        truckNumber: truckNumber,
        fuelTypeId: fuelTypeId,
        amount: amount,
        quantity: quantity,
        meterReading: meterReading,
      );

      if (validationError != null) {
        throw Exception(validationError);
      }

      final user = await SupabaseService.getCurrentUser();
      if (user == null) throw Exception('User not authenticated');

      // Get assignCostCenterId from truck number
      final assignCostCenter =
          await SupabaseService.getAssignCostCenterByNumber(truckNumber);
      if (assignCostCenter == null) {
        throw Exception('لم يتم العثور على الشاحنة المحددة');
      }

      final recordData = {
        'filling_date': fillingDate.toIso8601String().split('T')[0],
        'truck_number': truckNumber,
        'assign_cost_center_id': assignCostCenter.id,
        'fuel_type_id': fuelTypeId,
        'amount': amount,
        'quantity': quantity,
        'meter_reading': meterReading,
        'image_url': imageUrl,
        'image_name': imageName,
        'image_size': imageSize,
        'mime_type': mimeType,
        'notes': notes,
        'user_id': user.id,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Check if online
      final isOnline = await _isOnline();

      if (!isOnline && PlatformUtils.isMobile) {
        // Queue for offline submission
        await _offlineQueue.addOperation(
          operationType: 'submit_fuel_filling',
          endpoint: 'fuel_filling_records',
          method: 'INSERT',
          data: recordData,
          userId: user.id,
        );

        print('Fuel filling record queued for offline submission');
        return {
          'success': true,
          'queued': true,
          'message': 'تم حفظ السجل وسيتم إرساله عند الاتصال بالإنترنت',
        };
      }

      // Online - submit immediately to Supabase
      final response = await SupabaseService.createFuelFillingRecord(
        fillingDate: fillingDate,
        truckNumber: truckNumber,
        assignCostCenterId: assignCostCenter.id,
        fuelTypeId: fuelTypeId,
        amount: amount,
        quantity: quantity,
        meterReading: meterReading,
        imageUrl: imageUrl,
        imageName: imageName,
        imageSize: imageSize,
        mimeType: mimeType,
      );

      return {
        'success': true,
        'queued': false,
        'record': response,
      };
    } catch (e) {
      print('Error submitting fuel filling record: $e');
      rethrow;
    }
  }

  /// NEW: Get trucks with offline cache (alias for getAssignCostCenters)
  static Future<List<AssignCostCenter>> getTrucks() async {
    return await getAssignCostCenters();
  }

  /// NEW: Get pending fuel operations count
  static Future<int> getPendingFuelOperations() async {
    if (!PlatformUtils.isMobile) return 0;

    try {
      final allPending = await _offlineQueue.getPendingOperations();

      // Count fuel-related operations
      final fuelOps = allPending.where((op) =>
          op['operation_type'] == 'submit_fuel_filling' ||
          op['operation_type'] == 'post_journal_voucher');

      return fuelOps.length;
    } catch (e) {
      print('Error getting pending fuel operations: $e');
      return 0;
    }
  }

  /// NEW: Sync all pending fuel operations
  static Future<void> syncPendingFuelOperations() async {
    if (!PlatformUtils.isMobile) return;

    try {
      await _offlineQueue.processPendingOperations();
      print('✓ Synced all pending fuel operations');
    } catch (e) {
      print('Error syncing pending fuel operations: $e');
      rethrow;
    }
  }

  /// NEW: Clear fuel cache
  static Future<void> clearFuelCache() async {
    if (!PlatformUtils.isMobile) return;

    try {
      // Delete specific cache entries
      await _localDb.deleteCachedData(dataType: 'cost_centers', dataKey: 'all');
      await _localDb.deleteCachedData(dataType: 'fuel_types', dataKey: 'all');
      await _localDb.deleteCachedData(
          dataType: 'assign_cost_centers', dataKey: 'all');
      print('✓ Cleared fuel cache');
    } catch (e) {
      print('Error clearing fuel cache: $e');
    }
  }

  // ==================== EXISTING HELPER METHODS ====================

  // Validate journal voucher data with contact number
  static String? validateJournalVoucherData(JournalVoucherData data) {
    if (data.contactNumber.isEmpty) {
      return 'يرجى إدخال رقم جهة الاتصال';
    }

    if (data.taxReference.isEmpty) {
      return 'يرجى إدخال مرجع الضريبة';
    }

    if (data.notes.isEmpty) {
      return 'يرجى إدخال الملاحظة';
    }

    // Validate contact number is numeric
    if (int.tryParse(data.contactNumber) == null) {
      return 'رقم جهة الاتصال يجب أن يكون رقماً';
    }

    // Validate tax reference is numeric
    if (int.tryParse(data.taxReference) == null) {
      return 'مرجع الضريبة يجب أن يكون رقماً';
    }

    return null; // Valid
  }

  // Helper method to format date as dd/MM/yyyy
  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Helper method to get cost center code by truck number
  static Future<String> _getCostCenterCodeByTruckNumber(
      String truckNumber) async {
    try {
      final assignCostCenter =
          await SupabaseService.getAssignCostCenterByNumber(truckNumber);
      if (assignCostCenter?.costCenter != null) {
        return assignCostCenter!.costCenter!.code;
      }
      return "000000"; // Default fallback
    } catch (e) {
      print('Error getting cost center code for truck $truckNumber: $e');
      return "000000"; // Default fallback
    }
  }

  // Upload fuel filling image
  static Future<String?> uploadFuelImage({
    required Uint8List imageBytes,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      return await SupabaseService.uploadFuelImage(
        imageBytes: imageBytes,
        fileName: fileName,
        mimeType: mimeType,
      );
    } catch (e) {
      print('Error uploading fuel image: $e');
      rethrow;
    }
  }

  // Delete fuel filling image
  static Future<void> deleteFuelImage(String imageUrl) async {
    try {
      await SupabaseService.deleteFuelImage(imageUrl);
    } catch (e) {
      print('Error deleting fuel image: $e');
      rethrow;
    }
  }

  static String? validateFuelFillingForm({
    required DateTime? fillingDate,
    required String? truckNumber,
    required int? fuelTypeId,
    required double? amount,
    required double? quantity,
    String? meterReading,
  }) {
    if (fillingDate == null) {
      return 'يرجى اختيار تاريخ التعبئة';
    }

    if (truckNumber == null || truckNumber.isEmpty) {
      return 'يرجى اختيار رقم الشاحنة';
    }

    if (fuelTypeId == null) {
      return 'يرجى اختيار نوع المحروقات';
    }

    if (amount == null || amount <= 0) {
      return 'يرجى إدخال مبلغ صحيح';
    }

    if (quantity == null || quantity <= 0) {
      return 'يرجى إدخال كمية صحيحة';
    }

    // Make meter reading required
    if (meterReading == null || meterReading.trim().isEmpty) {
      return 'يرجى إدخال رقم العداد';
    }

    if (fillingDate.isAfter(DateTime.now())) {
      return 'لا يمكن أن يكون تاريخ التعبئة في المستقبل';
    }

    if (amount > 999999.99) {
      return 'المبلغ كبير جداً';
    }

    if (quantity > 99999.999) {
      return 'الكمية كبيرة جداً';
    }

    return null; // Valid
  }

  // Format amount for display
  static String formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2);
  }

  // Get file extension from mime type
  static String getFileExtensionFromMimeType(String mimeType) {
    switch (mimeType.toLowerCase()) {
      case 'image/jpeg':
      case 'image/jpg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/gif':
        return '.gif';
      case 'image/webp':
        return '.webp';
      default:
        return '.jpg';
    }
  }

  // Generate unique filename for fuel images
  static String generateFuelImageFileName(String originalName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = originalName.contains('.')
        ? originalName.substring(originalName.lastIndexOf('.'))
        : '.jpg';
    return 'fuel_${timestamp}_${originalName.replaceAll(RegExp(r'[^\w\-_\.]'), '_')}$extension';
  }

  // Updated statistics summary calculation
  static Map<String, dynamic> calculateStatisticsSummary(
      List<CostCenterStatistics> statistics) {
    double totalAmount = 0.0;
    double totalQuantity = 0.0;
    int totalRecords = 0;
    int activeCostCenters = 0;

    for (final stat in statistics) {
      totalAmount += stat.totalAmount;
      totalQuantity += stat.totalQuantity;
      totalRecords += stat.recordCount;
      if (stat.totalAmount > 0) {
        activeCostCenters++;
      }
    }

    final double taxAmount = totalAmount * 0.16;
    final double grandTotal = totalAmount + taxAmount;

    return {
      'total_amount': totalAmount,
      'total_quantity': totalQuantity,
      'tax_amount': taxAmount,
      'grand_total': grandTotal,
      'total_records': totalRecords,
      'active_cost_centers': activeCostCenters,
      'cost_centers_count': statistics.length,
    };
  }

  // Calculate user statistics summary
  static Map<String, dynamic> calculateUserStatisticsSummary(
      List<UserFuelStatistics> statistics) {
    double totalAmount = 0.0;
    double totalQuantity = 0.0;
    int totalRecords = 0;

    for (final stat in statistics) {
      totalAmount += stat.totalAmount;
      totalQuantity += stat.totalQuantity;
      totalRecords += stat.recordCount;
    }

    return {
      'total_amount': totalAmount,
      'total_quantity': totalQuantity,
      'total_records': totalRecords,
      'users_count': statistics.length,
    };
  }

  // Group statistics by cost center
  static Map<String, List<CostCenterStatistics>> groupStatisticsByCostCenter(
      List<CostCenterStatistics> statistics) {
    final Map<String, List<CostCenterStatistics>> grouped = {};

    for (final stat in statistics) {
      final key = '${stat.costCenterCode} - ${stat.costCenterName}';
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(stat);
    }

    return grouped;
  }
}
