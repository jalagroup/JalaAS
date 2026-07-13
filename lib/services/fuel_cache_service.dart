// lib/services/fuel_cache_service.dart - COMPLETE FIXED VERSION

import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../models/fuel_models.dart';
import '../utils/platform_utils.dart';

class FuelCacheService {
  static final FuelCacheService _instance = FuelCacheService._internal();
  factory FuelCacheService() => _instance;
  FuelCacheService._internal();

  static Database? _database;
  static const int _databaseVersion = 4; // INCREASED VERSION
  static const String _databaseName = 'fuel_cache.db';

  Future<Database> get database async {
    if (!PlatformUtils.isMobile) {
      throw Exception('Cache only available on mobile');
    }
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);

    print('📂 Database path: $path');

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        print('✅ Database opened (version: ${await db.getVersion()})');
      },
    );
  }

  /// Create database tables (for new installations)
  Future<void> _onCreate(Database db, int version) async {
    print('🔨 Creating database tables (version $version)...');

    // Assigned Cost Centers Cache with full_data column
    await db.execute('''
      CREATE TABLE assigned_cost_centers_cache (
        id INTEGER PRIMARY KEY,
        number TEXT NOT NULL UNIQUE,
        cost_center_id INTEGER NOT NULL,
        fuel_type_id INTEGER,
        full_data TEXT NOT NULL,
        synced_at TEXT NOT NULL
      )
    ''');

    // Pending Fuel Records
    await db.execute('''
      CREATE TABLE pending_fuel_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        filling_date TEXT NOT NULL,
        truck_number TEXT NOT NULL,
        assign_cost_center_id INTEGER NOT NULL,
        fuel_type_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        quantity REAL NOT NULL,
        meter_reading TEXT,
        image_url TEXT,
        image_name TEXT,
        image_size INTEGER,
        mime_type TEXT,
        user_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        status TEXT DEFAULT 'pending'
      )
    ''');

    print('✅ Database tables created successfully (version $version)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('🔄 Upgrading database from version $oldVersion to $newVersion...');

    if (oldVersion < 2) {
      // Upgrade from version 1 to 2
      await _migrateToVersion2(db);
    }

    if (oldVersion < 3) {
      // Upgrade from version 2 to 3 - force recreate to ensure full_data exists
      await _migrateToVersion3(db);
    }

    if (oldVersion < 4) {
      // NEW: Upgrade from version 3 to 4 - add fuel contact columns
      await _migrateToVersion4(db);
    }

    print('✅ Database upgrade completed to version $newVersion');
  }

// NEW: Migration to version 4
  Future<void> _migrateToVersion4(Database db) async {
    print('🔄 Migrating to version 4 - adding fuel contact columns...');

    try {
      // Add fuel_contact_id column
      await db.execute(
          'ALTER TABLE pending_fuel_records ADD COLUMN fuel_contact_id INTEGER');
      print('✅ Added fuel_contact_id column');

      // Add fuel_contact_code column
      await db.execute(
          'ALTER TABLE pending_fuel_records ADD COLUMN fuel_contact_code TEXT');
      print('✅ Added fuel_contact_code column');
    } catch (e) {
      print('⚠️ Could not add fuel contact columns: $e');
    }

    print('✅ Migration to version 4 complete');
  }

  Future<void> _migrateToVersion2(Database db) async {
    print('🔄 Migrating to version 2...');

    try {
      // Try to add full_data column
      await db.execute(
          'ALTER TABLE assigned_cost_centers_cache ADD COLUMN full_data TEXT');
      print('✅ Added full_data column');
    } catch (e) {
      print('⚠️ Could not add column: $e');
    }
  }

  Future<void> _migrateToVersion3(Database db) async {
    print('🔄 Migrating to version 3 - recreating tables...');

    // Backup pending records
    List<Map<String, dynamic>> pendingBackup = [];
    try {
      pendingBackup = await db.query('pending_fuel_records');
      print('💾 Backed up ${pendingBackup.length} pending records');
    } catch (e) {
      print('⚠️ No pending records to backup: $e');
    }

    // Drop and recreate assigned_cost_centers_cache
    try {
      await db.execute('DROP TABLE IF EXISTS assigned_cost_centers_cache');
      print('🗑️ Dropped old assigned_cost_centers_cache table');

      await db.execute('''
        CREATE TABLE assigned_cost_centers_cache (
          id INTEGER PRIMARY KEY,
          number TEXT NOT NULL UNIQUE,
          cost_center_id INTEGER NOT NULL,
          fuel_type_id INTEGER,
          full_data TEXT NOT NULL,
          synced_at TEXT NOT NULL
        )
      ''');
      print(
          '✅ Created new assigned_cost_centers_cache table with full_data column');
    } catch (e) {
      print('❌ Error recreating assigned_cost_centers_cache: $e');
    }

    // Ensure pending_fuel_records table exists with correct schema
    try {
      // Check if table exists
      final tableExists = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='pending_fuel_records'");

      if (tableExists.isEmpty) {
        await db.execute('''
          CREATE TABLE pending_fuel_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            filling_date TEXT NOT NULL,
            truck_number TEXT NOT NULL,
            assign_cost_center_id INTEGER NOT NULL,
            fuel_type_id INTEGER NOT NULL,
            amount REAL NOT NULL,
            quantity REAL NOT NULL,
            meter_reading TEXT,
            image_url TEXT,
            image_name TEXT,
            image_size INTEGER,
            mime_type TEXT,
            user_id TEXT NOT NULL,
            created_at TEXT NOT NULL,
            retry_count INTEGER DEFAULT 0,
            status TEXT DEFAULT 'pending'
          )
        ''');
        print('✅ Created pending_fuel_records table');
      }

      // Restore pending records
      if (pendingBackup.isNotEmpty) {
        for (var record in pendingBackup) {
          await db.insert('pending_fuel_records', record);
        }
        print('✅ Restored ${pendingBackup.length} pending records');
      }
    } catch (e) {
      print('❌ Error handling pending_fuel_records: $e');
    }

    print('✅ Migration to version 3 complete');
  }

  // ========== ASSIGNED COST CENTERS CACHE ==========

  /// Cache assigned cost centers from Supabase
  Future<void> cacheAssignedCostCenters(
      List<AssignCostCenter> costCenters) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    print('💾 Caching ${costCenters.length} assigned cost centers...');

    await db.transaction((txn) async {
      // Clear old cache
      await txn.delete('assigned_cost_centers_cache');
      print('🗑️ Cleared old cache');

      // Insert new data
      int successCount = 0;
      for (var cc in costCenters) {
        try {
          final fullDataJson = jsonEncode(cc.toJson());

          await txn.insert('assigned_cost_centers_cache', {
            'id': cc.id,
            'number': cc.number,
            'cost_center_id': cc.costCenterId,
            'fuel_type_id': cc.fuelTypeId,
            'full_data': fullDataJson,
            'synced_at': now,
          });

          successCount++;
        } catch (e) {
          print('❌ Error inserting cost center ${cc.number}: $e');
        }
      }

      print(
          '✅ Successfully cached $successCount/${costCenters.length} records');
    });

    print('✅ Cache operation completed');
  }

  /// Get cached assigned cost centers
  Future<List<AssignCostCenter>> getCachedAssignedCostCenters() async {
    try {
      final db = await database;
      final results = await db.query(
        'assigned_cost_centers_cache',
        orderBy: 'number ASC',
      );

      if (results.isEmpty) {
        print('⚠️ No cached assigned cost centers found');
        return [];
      }

      print('📦 Loading ${results.length} cached assigned cost centers');

      final costCenters = <AssignCostCenter>[];

      for (var row in results) {
        try {
          final fullDataStr = row['full_data'] as String;
          final fullData = jsonDecode(fullDataStr) as Map<String, dynamic>;
          costCenters.add(AssignCostCenter.fromJson(fullData));
        } catch (e) {
          print('❌ Error parsing cached row ${row['id']}: $e');
          // Continue with other records
        }
      }

      print('✅ Successfully loaded ${costCenters.length} cached records');
      return costCenters;
    } catch (e) {
      print('❌ Error getting cached cost centers: $e');
      return [];
    }
  }

  /// Check if cache has data
  Future<bool> hasCachedData() async {
    try {
      final db = await database;
      final count = Sqflite.firstIntValue(await db
          .rawQuery('SELECT COUNT(*) FROM assigned_cost_centers_cache'));
      return (count ?? 0) > 0;
    } catch (e) {
      print('❌ Error checking cached data: $e');
      return false;
    }
  }

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    try {
      final db = await database;
      final results = await db.query(
        'assigned_cost_centers_cache',
        columns: ['synced_at'],
        limit: 1,
      );

      if (results.isEmpty) return null;
      return DateTime.parse(results.first['synced_at'] as String);
    } catch (e) {
      print('❌ Error getting last sync time: $e');
      return null;
    }
  }

  /// Get cache age in hours
  Future<int?> getCacheAgeInHours() async {
    final lastSync = await getLastSyncTime();
    if (lastSync == null) return null;

    final now = DateTime.now();
    final difference = now.difference(lastSync);
    return difference.inHours;
  }

  /// Check if cache needs refresh (older than 24 hours)
  Future<bool> needsCacheRefresh() async {
    final ageInHours = await getCacheAgeInHours();
    if (ageInHours == null) return true;
    return ageInHours >= 24;
  }

  /// Sync assigned cost centers from Supabase (call when online)
  Future<bool> syncAssignedCostCentersFromSupabase(
      List<AssignCostCenter> costCenters) async {
    try {
      await cacheAssignedCostCenters(costCenters);
      print(
          '✅ Auto-synced ${costCenters.length} assigned cost centers to cache');
      return true;
    } catch (e) {
      print('❌ Failed to sync assigned cost centers: $e');
      return false;
    }
  }

  // ========== PENDING FUEL RECORDS ==========

  /// Update fuel_filling_records schema to store fuel contact
  Future<int> addPendingFuelRecord({
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
    final db = await database;

    final id = await db.insert('pending_fuel_records', {
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
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
      'status': 'pending',
    });

    print('✅ Added fuel record to pending queue (ID: $id)');
    return id;
  }

  /// Get all pending fuel records
  Future<List<Map<String, dynamic>>> getPendingFuelRecords() async {
    final db = await database;
    return await db.query(
      'pending_fuel_records',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );
  }

  /// Cache fuel contacts
  Future<void> saveFuelContactsCache(List<FuelContact> contacts) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    print('💾 Caching ${contacts.length} fuel contacts...');

    await db.transaction((txn) async {
      // Clear old cache
      await txn.execute(
          'DELETE FROM cached_data WHERE data_type = ?', ['fuel_contacts']);

      // Insert new data
      final data = {
        'contacts': contacts.map((c) => c.toJson()).toList(),
        'cached_at': now,
      };

      await txn.insert('cached_data', {
        'data_type': 'fuel_contacts',
        'data_key': 'all',
        'data_value': jsonEncode(data),
        'created_at': now,
        'updated_at': now,
      });

      print('✅ Cached ${contacts.length} fuel contacts');
    });
  }

  /// Get cached fuel contacts
  Future<List<FuelContact>> getCachedFuelContacts() async {
    try {
      final db = await database;
      final results = await db.query(
        'cached_data',
        where: 'data_type = ? AND data_key = ?',
        whereArgs: ['fuel_contacts', 'all'],
        limit: 1,
      );

      if (results.isEmpty) {
        print('⚠️ No cached fuel contacts found');
        return [];
      }

      final dataValue = jsonDecode(results.first['data_value'] as String);
      final contactsList = dataValue['contacts'] as List;

      final contacts = contactsList
          .map((json) => FuelContact.fromSupabaseJson(json))
          .toList();

      print('✅ Loaded ${contacts.length} cached fuel contacts');
      return contacts;
    } catch (e) {
      print('❌ Error getting cached fuel contacts: $e');
      return [];
    }
  }

  /// Get pending count
  Future<int> getPendingCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM pending_fuel_records WHERE status = ?',
        ['pending']));
    return count ?? 0;
  }

// Update in lib/services/fuel_cache_service.dart

  /// Process all pending fuel records (call when internet reconnects)
  Future<Map<String, dynamic>> processPendingFuelRecords({
    required Future<bool> Function(Map<String, dynamic>) submitToSupabase,
  }) async {
    final pending = await getPendingFuelRecords();

    if (pending.isEmpty) {
      print('ℹ️ No pending records to process');
      return {
        'success': 0,
        'failed': 0,
        'total': 0,
      };
    }

    print('📤 Processing ${pending.length} pending fuel records...');

    int successCount = 0;
    int failedCount = 0;

    for (var record in pending) {
      try {
        final recordId = record['id'] as int;
        final localImageUrl = record['image_url'] as String?;

        print('📝 Processing pending record (local ID: $recordId)...');

        // Upload image to Supabase Storage if it exists locally
        String? supabaseImageUrl;
        if (localImageUrl != null && localImageUrl.isNotEmpty) {
          try {
            print('📸 Found local image: $localImageUrl');

            // Check if it's a local file path (not already a Supabase URL)
            if (!localImageUrl.startsWith('http')) {
              // Read the image file from local storage
              final imageFile = File(localImageUrl);

              if (await imageFile.exists()) {
                final imageBytes = await imageFile.readAsBytes();
                final imageName = record['image_name'] as String? ??
                    'fuel_${DateTime.now().millisecondsSinceEpoch}.jpg';
                final mimeType = record['mime_type'] as String? ?? 'image/jpeg';

                print('📤 Uploading image to Supabase Storage...');
                print('   File size: ${imageBytes.length} bytes');
                print('   File name: $imageName');

                // Upload to Supabase Storage
                final supabase = Supabase.instance.client;

                // Generate unique filename
                final timestamp = DateTime.now().millisecondsSinceEpoch;
                final uniqueFileName = '${timestamp}_$imageName';

                await supabase.storage.from('fuel-images').uploadBinary(
                      uniqueFileName,
                      imageBytes,
                      fileOptions: FileOptions(
                        contentType: mimeType,
                        upsert: false,
                      ),
                    );

                // Get public URL
                supabaseImageUrl = supabase.storage
                    .from('fuel-images')
                    .getPublicUrl(uniqueFileName);

                print('✅ Image uploaded to Supabase: $supabaseImageUrl');

                // Delete local file after successful upload
                try {
                  await imageFile.delete();
                  print('🗑️ Deleted local image file');
                } catch (e) {
                  print('⚠️ Could not delete local file: $e');
                }
              } else {
                print('⚠️ Local image file not found: $localImageUrl');
                // Continue without image
              }
            } else {
              // Already a Supabase URL
              supabaseImageUrl = localImageUrl;
              print('✓ Image already has Supabase URL');
            }
          } catch (imageError) {
            print('❌ Error uploading image: $imageError');
            // Continue without image - don't fail the whole record
          }
        }

        // Prepare data for submission with Supabase image URL
        final recordData = {
          'filling_date': record['filling_date'],
          'truck_number': record['truck_number'],
          'assign_cost_center_id': record['assign_cost_center_id'],
          'fuel_type_id': record['fuel_type_id'],
          'amount': record['amount'],
          'quantity': record['quantity'],
          'meter_reading': record['meter_reading'],
          'image_url':
              supabaseImageUrl, // Use Supabase URL instead of local path
          'image_name': record['image_name'],
          'image_size': record['image_size'],
          'mime_type': record['mime_type'],
          'user_id': record['user_id'],
          'fuel_contact_id': record['fuel_contact_id'], // NEW
          'fuel_contact_code': record['fuel_contact_code'], // NEW
        };

        print('📝 Submitting to Supabase with image URL: $supabaseImageUrl');

        // Try to submit to Supabase
        final success = await submitToSupabase(recordData);

        if (success) {
          await deletePendingRecord(recordId);
          successCount++;
          print(
              '✅ Successfully submitted pending record (local ID: $recordId)');
        } else {
          await incrementRetryCount(recordId);

          // Mark as failed after 5 attempts
          final retryCount = record['retry_count'] as int;
          if (retryCount >= 4) {
            await markAsFailed(recordId);
            print(
                '❌ Marked record as failed after 5 attempts (local ID: $recordId)');
          }
          failedCount++;
        }
      } catch (e) {
        print('❌ Error processing pending record: $e');
        failedCount++;
      }

      // Small delay to avoid overwhelming the server
      await Future.delayed(const Duration(milliseconds: 500));
    }

    print('📊 Sync complete: $successCount succeeded, $failedCount failed');

    return {
      'success': successCount,
      'failed': failedCount,
      'total': pending.length,
    };
  }

  Future<void> clearAllPending() async {
    final db = await database;
    final deleted = await db.delete('pending_fuel_records');
    print('✅ Cleared $deleted pending records');
  }

  /// Delete pending record after successful submission
  Future<void> deletePendingRecord(int id) async {
    final db = await database;
    await db.delete(
      'pending_fuel_records',
      where: 'id = ?',
      whereArgs: [id],
    );
    print('✅ Deleted pending record (ID: $id)');
  }

  /// Increment retry count
  Future<void> incrementRetryCount(int id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE pending_fuel_records SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }

  /// Mark as failed
  Future<void> markAsFailed(int id) async {
    final db = await database;
    await db.update(
      'pending_fuel_records',
      {'status': 'failed'},
      where: 'id = ?',
      whereArgs: [id],
    );
    print('⚠️ Marked record as failed (ID: $id)');
  }

  /// Get all failed records (for manual review)
  Future<List<Map<String, dynamic>>> getFailedFuelRecords() async {
    final db = await database;
    return await db.query(
      'pending_fuel_records',
      where: 'status = ?',
      whereArgs: ['failed'],
      orderBy: 'created_at ASC',
    );
  }

  /// Retry a failed record
  Future<void> retryFailedRecord(int id) async {
    final db = await database;
    await db.update(
      'pending_fuel_records',
      {
        'status': 'pending',
        'retry_count': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    print('🔄 Reset failed record to pending (ID: $id)');
  }

  /// Clear all data
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('assigned_cost_centers_cache');
    await db.delete('pending_fuel_records');
    print('✅ Cleared all cached data');
  }

  /// Force delete and recreate database (for troubleshooting)
  Future<void> resetDatabase() async {
    try {
      print('🔄 Resetting database...');

      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      String path = join(await getDatabasesPath(), _databaseName);
      await deleteDatabase(path);
      print('🗑️ Database deleted: $path');

      // Reinitialize
      _database = await _initDatabase();
      print('✅ Database recreated successfully');
    } catch (e) {
      print('❌ Error resetting database: $e');
      rethrow;
    }
  }

  /// Close database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      print('🔌 Database closed');
    }
  }
}
