// lib/services/local_database_service.dart - SQLite Local Database Service

import 'package:jala_as/models/user.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../utils/platform_utils.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance =
      LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  static Database? _database;

  /// Initialize database (only for mobile)
  Future<Database> get database async {
    if (!PlatformUtils.isMobile) {
      throw Exception('Local database is only available on mobile platforms');
    }

    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

// lib/services/local_database_service.dart

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'jala_offline.db');

    // IMPORTANT: Check version and delete if needed
    try {
      final existingDb = await openDatabase(path);
      final currentVersion = await existingDb.getVersion();
      await existingDb.close();

      if (currentVersion != 1) {
        print(
            '⚠️ Database version mismatch (current: $currentVersion, needed: 1)');
        await deleteDatabase(path);
        print('✓ Database deleted for version reset');
      }
    } catch (e) {
      print('Note: Could not check database version: $e');
      try {
        await deleteDatabase(path);
        print('✓ Database deleted for fresh start');
      } catch (deleteError) {
        print('Note: Could not delete database: $deleteError');
      }
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // lib/services/local_database_service.dart

  /// Initialize database explicitly
  static Future<void> initializeDatabase() async {
    try {
      print('\n========================================');
      print('🗄️ INITIALIZING LOCAL DATABASE');
      print('========================================');

      final instance = LocalDatabaseService();
      final db = await instance.database;

      // Verify tables exist
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='login_state'");

      if (tables.isEmpty) {
        print('⚠️ login_state table does not exist! Creating...');
        await instance._onCreate(db, 1);
      } else {
        print('✓ login_state table exists');
      }

      // Test read/write
      final testData = await db.query('login_state', limit: 1);
      print('✓ Database read test successful');
      print('Current login state count: ${testData.length}');

      print('========================================\n');
    } catch (e) {
      print('❌ ERROR initializing database: $e');
      print('========================================\n');
      rethrow;
    }
  }
// lib/services/local_database_service.dart

// lib/services/local_database_service.dart

  Future<void> _onCreate(Database db, int version) async {
    // User session table
    await db.execute('''
    CREATE TABLE user_session (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      username TEXT NOT NULL,
      email TEXT NOT NULL,
      user_type TEXT NOT NULL,
      salesman TEXT NOT NULL,
      area TEXT,
      periodic_area_assignment TEXT,
      is_active INTEGER NOT NULL,
      device_id TEXT NOT NULL,
      access_token TEXT NOT NULL,
      refresh_token TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      expires_at TEXT NOT NULL
    )
  ''');

    // NEW: Login state table
    await db.execute('''
    CREATE TABLE login_state (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      is_logged_in INTEGER NOT NULL,
      user_id TEXT NOT NULL,
      username TEXT NOT NULL,
      email TEXT NOT NULL,
      user_type TEXT NOT NULL,
      salesman TEXT NOT NULL,
      area TEXT,
      periodic_area_assignment TEXT,
      saved_at TEXT NOT NULL
    )
  ''');

    // Cached data table
    await db.execute('''
    CREATE TABLE cached_data (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      data_type TEXT NOT NULL,
      data_key TEXT NOT NULL,
      data_value TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      UNIQUE(data_type, data_key)
    )
  ''');

    // Pending operations table
    await db.execute('''
    CREATE TABLE pending_operations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      operation_type TEXT NOT NULL,
      endpoint TEXT NOT NULL,
      method TEXT NOT NULL,
      data TEXT NOT NULL,
      user_id TEXT NOT NULL,
      created_at TEXT NOT NULL,
      retry_count INTEGER DEFAULT 0,
      last_retry_at TEXT,
      error_message TEXT,
      status TEXT DEFAULT 'pending'
    )
  ''');

    await db.execute('''
  CREATE TABLE cached_contacts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    contact_code TEXT NOT NULL,
    contact_data TEXT NOT NULL,
    created_at TEXT NOT NULL,
    UNIQUE(user_id, contact_code)
  )
''');

    await db.execute('''
  CREATE TABLE cached_warehouses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    warehouse_code TEXT NOT NULL UNIQUE,
    warehouse_data TEXT NOT NULL,
    created_at TEXT NOT NULL
  )
''');

    await db.execute('''
  CREATE TABLE cached_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    item_code TEXT NOT NULL UNIQUE,
    item_data TEXT NOT NULL,
    created_at TEXT NOT NULL
  )
''');

// Add to _onCreate method in fuel_cache_service.dart
    await db.execute('''
  CREATE TABLE IF NOT EXISTS cached_data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    data_type TEXT NOT NULL,
    data_key TEXT NOT NULL,
    data_value TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    UNIQUE(data_type, data_key)
  )
''');

    // Create indexes
    await db
        .execute('CREATE INDEX idx_cached_data_type ON cached_data(data_type)');
    await db.execute(
        'CREATE INDEX idx_pending_operations_status ON pending_operations(status)');
    await db.execute(
        'CREATE INDEX idx_pending_operations_user ON pending_operations(user_id)');
  }

  /// Save login state
  Future<void> saveLoginState({
    required bool isLoggedIn,
    String? userId,
    String? username,
    String? email,
    String? userType,
    String? salesman,
    String? area,
    String? periodicAreaAssignment,
  }) async {
    final db = await database;

    // Clear old login state
    await db.delete('login_state');

    if (isLoggedIn && userId != null) {
      // Save new login state
      await db.insert('login_state', {
        'is_logged_in': isLoggedIn ? 1 : 0,
        'user_id': userId,
        'username': username,
        'email': email,
        'user_type': userType,
        'salesman': salesman,
        'area': area,
        'periodic_area_assignment': periodicAreaAssignment,
        'saved_at': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Get login state
  Future<Map<String, dynamic>?> getLoginState() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'login_state',
      limit: 1,
    );

    if (results.isEmpty) return null;
    return results.first;
  }

  /// Check if user is logged in
  Future<bool> isUserLoggedIn() async {
    final loginState = await getLoginState();
    if (loginState == null) return false;
    return loginState['is_logged_in'] == 1;
  }

  /// Clear login state (for logout)
  Future<void> clearLoginState() async {
    final db = await database;
    await db.delete('login_state');
  }

  /// Get saved user info
  Future<AppUser?> getSavedUserInfo() async {
    final loginState = await getLoginState();
    if (loginState == null) return null;

    final isLoggedIn = loginState['is_logged_in'] == 1;
    if (!isLoggedIn) return null;

    return AppUser(
      id: loginState['user_id'] as String,
      username: loginState['username'] as String,
      email: loginState['email'] as String,
      userType: loginState['user_type'] as String,
      salesman: loginState['salesman'] as String,
      area: loginState['area'] as String?,
      periodicAreaAssignment: loginState['periodic_area_assignment'] as String?,
      isActive: true,
      createdAt: DateTime.parse(loginState['saved_at'] as String),
      updatedAt: DateTime.parse(loginState['saved_at'] as String),
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Upgrading database from version $oldVersion to $newVersion');

    if (oldVersion < 2) {
      await EnhancedLocalDatabaseOperations.upgradeSchema(db, oldVersion);
    }

    if (oldVersion < 3) {
      // Add missing columns for version 3
      List<String> columnsToAdd = [
        'ALTER TABLE pending_operations ADD COLUMN error_details TEXT',
        'ALTER TABLE pending_operations ADD COLUMN error_code INTEGER',
        'ALTER TABLE pending_operations ADD COLUMN last_modified_at TEXT',
      ];

      for (String sql in columnsToAdd) {
        try {
          await db.execute(sql);
          print('✓ Added column: ${sql.split(' ').last}');
        } catch (e) {
          print('Column might already exist: $e');
        }
      }
    }
  }

  // ==================== USER SESSION METHODS ====================
  Future<void> resetDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'jala_offline.db');

    try {
      await deleteDatabase(path);
      print('✓ Database deleted successfully');
    } catch (e) {
      print('Error deleting database: $e');
    }
  }

  /// Save user session
  Future<void> saveUserSession({
    required String userId,
    required String username,
    required String email,
    required String userType,
    required String salesman,
    String? area,
    String? periodicAreaAssignment,
    required bool isActive,
    required String deviceId,
    required String accessToken,
    String? refreshToken,
    required DateTime expiresAt,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    // Clear old sessions
    await db.delete('user_session');

    // Insert new session
    await db.insert('user_session', {
      'user_id': userId,
      'username': username,
      'email': email,
      'user_type': userType,
      'salesman': salesman,
      'area': area,
      'periodic_area_assignment': periodicAreaAssignment,
      'is_active': isActive ? 1 : 0,
      'device_id': deviceId,
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'created_at': now,
      'updated_at': now,
      'expires_at': expiresAt.toIso8601String(),
    });
  }

  /// Get user session
  Future<Map<String, dynamic>?> getUserSession() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'user_session',
      limit: 1,
    );

    if (results.isEmpty) return null;
    return results.first;
  }

  /// Check if session is valid
  Future<bool> isSessionValid() async {
    final session = await getUserSession();
    if (session == null) return false;

    final expiresAt = DateTime.parse(session['expires_at']);
    return DateTime.now().isBefore(expiresAt);
  }

  /// Update session tokens
  Future<void> updateSessionTokens({
    required String accessToken,
    String? refreshToken,
    required DateTime expiresAt,
  }) async {
    final db = await database;
    await db.update(
      'user_session',
      {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_at': expiresAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Clear user session (logout)
  Future<void> clearUserSession() async {
    final db = await database;
    await db.delete('user_session');
  }

  // ==================== CACHED DATA METHODS ====================

  /// Save cached data
  Future<void> saveCachedData({
    required String dataType,
    required String dataKey,
    required Map<String, dynamic> data,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.insert(
      'cached_data',
      {
        'data_type': dataType,
        'data_key': dataKey,
        'data_value': jsonEncode(data),
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get cached data
  Future<Map<String, dynamic>?> getCachedData({
    required String dataType,
    required String dataKey,
  }) async {
    final db = await database;
    final results = await db.query(
      'cached_data',
      where: 'data_type = ? AND data_key = ?',
      whereArgs: [dataType, dataKey],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return jsonDecode(results.first['data_value'] as String);
  }

  /// Get all cached data of a type
  Future<List<Map<String, dynamic>>> getCachedDataByType(
      String dataType) async {
    final db = await database;
    final results = await db.query(
      'cached_data',
      where: 'data_type = ?',
      whereArgs: [dataType],
    );

    return results.map((row) {
      return {
        'data_key': row['data_key'],
        'data_value': jsonDecode(row['data_value'] as String),
        'updated_at': row['updated_at'],
      };
    }).toList();
  }

  /// Clear cached data
  Future<void> clearCachedData({String? dataType}) async {
    final db = await database;
    if (dataType != null) {
      await db
          .delete('cached_data', where: 'data_type = ?', whereArgs: [dataType]);
    } else {
      await db.delete('cached_data');
    }
  }

  /// Delete specific cached data entry
  Future<void> deleteCachedData({
    required String dataType,
    required String dataKey,
  }) async {
    final db = await database;
    await db.delete(
      'cached_data',
      where: 'data_type = ? AND data_key = ?',
      whereArgs: [dataType, dataKey],
    );
  }

  // ==================== PENDING OPERATIONS METHODS ====================

  /// Add pending operation
  Future<int> addPendingOperation({
    required String operationType,
    required String endpoint,
    required String method,
    required Map<String, dynamic> data,
    required String userId,
  }) async {
    final db = await database;
    return await db.insert('pending_operations', {
      'operation_type': operationType,
      'endpoint': endpoint,
      'method': method,
      'data': jsonEncode(data),
      'user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
      'status': 'pending',
      'retry_count': 0,
    });
  }

  /// Get all pending operations
  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final db = await database;
    return await db.query(
      'pending_operations',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );
  }

  /// Update operation status
  Future<void> updateOperationStatus({
    required int operationId,
    required String status,
    String? errorMessage,
  }) async {
    final db = await database;
    await db.update(
      'pending_operations',
      {
        'status': status,
        'error_message': errorMessage,
        'last_retry_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }

  /// Increment retry count
  Future<void> incrementRetryCount(int operationId) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE pending_operations SET retry_count = retry_count + 1, last_retry_at = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), operationId],
    );
  }

  /// Delete operation
  Future<void> deleteOperation(int operationId) async {
    final db = await database;
    await db.delete('pending_operations',
        where: 'id = ?', whereArgs: [operationId]);
  }

  /// Clear completed operations
  Future<void> clearCompletedOperations() async {
    final db = await database;
    await db.delete(
      'pending_operations',
      where: 'status IN (?, ?)',
      whereArgs: ['completed', 'failed'],
    );
  }

  /// Get operation count by status
  Future<int> getOperationCount({String? status}) async {
    final db = await database;
    if (status != null) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM pending_operations WHERE status = ?',
        [status],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } else {
      final result =
          await db.rawQuery('SELECT COUNT(*) as count FROM pending_operations');
      return Sqflite.firstIntValue(result) ?? 0;
    }
  }

  // ==================== MAINTENANCE METHODS ====================

  /// Clear all data (for logout or reset)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('user_session');
    await db.delete('cached_data');
    await db.delete('pending_operations');
    await db.delete('login_state'); // NEW
  }

  /// Get database size info
  Future<Map<String, int>> getDatabaseInfo() async {
    final db = await database;

    final sessionCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM user_session')) ??
        0;

    final cachedDataCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM cached_data')) ??
        0;

    final pendingOpsCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM pending_operations')) ??
        0;

    return {
      'sessions': sessionCount,
      'cached_data': cachedDataCount,
      'pending_operations': pendingOpsCount,
    };
  }

  /// Close database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

// lib/services/local_database_service.dart (around line 440)

// lib/services/local_database_service.dart (around line 440)

class PendingContactOperation {
  final int? id;
  final String operationType;
  final String endpoint;
  final String method;
  final Map<String, dynamic> contactData;
  final String userId;
  final DateTime createdAt;
  final int retryCount;
  final DateTime? lastRetryAt;
  final String? errorMessage;
  final String status;

  PendingContactOperation({
    this.id,
    required this.operationType,
    required this.endpoint,
    required this.method,
    required this.contactData,
    required this.userId,
    required this.createdAt,
    this.retryCount = 0,
    this.lastRetryAt,
    this.errorMessage,
    this.status = 'pending',
  });

  factory PendingContactOperation.fromMap(Map<String, dynamic> map) {
    // Decode the JSON string back to Map
    final decodedData = jsonDecode(map['data'] as String);

    // CRITICAL FIX: Ensure 'record' is a proper object, not a string
    Map<String, dynamic> contactData;
    if (decodedData is Map<String, dynamic>) {
      contactData = Map<String, dynamic>.from(decodedData);

      // Check if 'record' is a string and decode it
      if (contactData['record'] is String) {
        print('WARNING: record is a string, attempting to parse...');
        try {
          // Try to parse it as JSON
          contactData['record'] = jsonDecode(contactData['record']);
        } catch (e) {
          print('ERROR: Failed to parse record as JSON: $e');
          print('Record value: ${contactData['record']}');

          // If it's not valid JSON, try to parse it as a Dart-style string
          contactData['record'] =
              _parseDartStyleString(contactData['record'] as String);
        }
      }
    } else {
      contactData = {};
    }

    return PendingContactOperation(
      id: map['id'] as int?,
      operationType: map['operation_type'] as String,
      endpoint: map['endpoint'] as String,
      method: map['method'] as String,
      contactData: contactData,
      userId: map['user_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      retryCount: map['retry_count'] as int? ?? 0,
      lastRetryAt: map['last_retry_at'] != null
          ? DateTime.parse(map['last_retry_at'] as String)
          : null,
      errorMessage: map['error_message'] as String?,
      status: map['status'] as String? ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    // CRITICAL FIX: Ensure we're encoding properly
    final dataToStore = Map<String, dynamic>.from(contactData);

    // Make absolutely sure 'record' is an object before encoding
    if (dataToStore['record'] != null && dataToStore['record'] is! Map) {
      print('WARNING: record is not a Map before encoding!');
      print('Record type: ${dataToStore['record'].runtimeType}');
      print('Record value: ${dataToStore['record']}');
    }

    return {
      if (id != null) 'id': id,
      'operation_type': operationType,
      'endpoint': endpoint,
      'method': method,
      'data': jsonEncode(dataToStore), // Encode the entire structure once
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'retry_count': retryCount,
      'last_retry_at': lastRetryAt?.toIso8601String(),
      'error_message': errorMessage,
      'status': status,
    };
  }

  // Helper to parse Dart-style string (without quotes) to Map
  static Map<String, dynamic> _parseDartStyleString(String dartString) {
    try {
      // Remove outer braces if present
      String cleaned = dartString.trim();
      if (cleaned.startsWith('{')) cleaned = cleaned.substring(1);
      if (cleaned.endsWith('}'))
        cleaned = cleaned.substring(0, cleaned.length - 1);

      final result = <String, dynamic>{};

      // Split by comma (basic parsing)
      final pairs = cleaned.split(', ');

      for (final pair in pairs) {
        final colonIndex = pair.indexOf(':');
        if (colonIndex > 0) {
          final key = pair.substring(0, colonIndex).trim();
          final value = pair.substring(colonIndex + 1).trim();
          result[key] = value;
        }
      }

      return result;
    } catch (e) {
      print('ERROR: Failed to parse Dart-style string: $e');
      return {};
    }
  }

  PendingContactOperation copyWith({
    int? id,
    String? operationType,
    String? endpoint,
    String? method,
    Map<String, dynamic>? contactData,
    String? userId,
    DateTime? createdAt,
    int? retryCount,
    DateTime? lastRetryAt,
    String? errorMessage,
    String? status,
  }) {
    return PendingContactOperation(
      id: id ?? this.id,
      operationType: operationType ?? this.operationType,
      endpoint: endpoint ?? this.endpoint,
      method: method ?? this.method,
      contactData: contactData ?? this.contactData,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastRetryAt: lastRetryAt ?? this.lastRetryAt,
      errorMessage: errorMessage ?? this.errorMessage,
      status: status ?? this.status,
    );
  }

  String getUserFriendlyError() {
    if (errorMessage == null) return 'خطأ غير معروف';

    if (errorMessage!.contains('network') ||
        errorMessage!.contains('connection') ||
        errorMessage!.contains('SocketException')) {
      return 'خطأ في الاتصال بالشبكة';
    } else if (errorMessage!.contains('timeout')) {
      return 'انتهت مهلة الاتصال';
    } else if (errorMessage!.contains('Format')) {
      return 'خطأ في تنسيق البيانات';
    }

    return errorMessage!;
  }

  String getContactName() {
    try {
      final record = contactData['record'];

      // Handle if record is a Map
      if (record is Map<String, dynamic>) {
        return record['nameAR'] as String? ?? 'غير محدد';
      }

      // Handle if record is a String (shouldn't happen but just in case)
      if (record is String && record.contains('nameAR:')) {
        final match = RegExp(r'nameAR:\s*([^,]+)').firstMatch(record);
        if (match != null) {
          return match.group(1)?.trim() ?? 'غير محدد';
        }
      }

      return 'غير محدد';
    } catch (e) {
      print('ERROR: Failed to get contact name: $e');
      return 'غير محدد';
    }
  }
}

/// Enhanced database operations for contact management
class EnhancedLocalDatabaseOperations {
  final Database db;

  EnhancedLocalDatabaseOperations(this.db);

  /// Upgrade database schema to support enhanced pending operations
  static Future<void> upgradeSchema(Database db, int version) async {
    if (version < 2) {
      // Add new columns to existing pending_operations table
      await db.execute(
          'ALTER TABLE pending_operations ADD COLUMN error_details TEXT');
      await db.execute(
          'ALTER TABLE pending_operations ADD COLUMN error_code INTEGER');
      await db.execute(
          'ALTER TABLE pending_operations ADD COLUMN last_modified_at TEXT');
    }
  }

  /// Add a new pending contact creation operation
  Future<int> addPendingContactOperation({
    required Map<String, dynamic> contactData,
    required String userId,
  }) async {
    final operation = PendingContactOperation(
      operationType: 'create_contact',
      endpoint: 'https://gw.bisan.com/api/v2/jalaf/contact',
      method: 'POST',
      contactData: contactData,
      userId: userId,
      createdAt: DateTime.now(),
      status: 'pending',
    );

    return await db.insert('pending_operations', operation.toMap());
  }

  /// Get all pending contact operations
  Future<List<PendingContactOperation>> getPendingContactOperations() async {
    final results = await db.query(
      'pending_operations',
      where: 'operation_type = ? AND status = ?',
      whereArgs: ['create_contact', 'pending'],
      orderBy: 'created_at ASC',
    );

    return results.map((map) => PendingContactOperation.fromMap(map)).toList();
  }

  /// Get all contact operations with errors
  Future<List<PendingContactOperation>> getFailedContactOperations() async {
    final results = await db.query(
      'pending_operations',
      where: 'operation_type = ? AND status = ?',
      whereArgs: ['create_contact', 'failed'],
      orderBy: 'created_at DESC',
    );

    return results.map((map) => PendingContactOperation.fromMap(map)).toList();
  }

  /// Get a specific pending operation by ID
  Future<PendingContactOperation?> getPendingOperationById(int id) async {
    final results = await db.query(
      'pending_operations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return PendingContactOperation.fromMap(results.first);
  }

  /// Update pending operation with error details
  Future<void> updateOperationError({
    required int operationId,
    required String errorMessage,
  }) async {
    await db.update(
      'pending_operations',
      {
        'status': 'failed',
        'error_message': errorMessage,
        'last_retry_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }

  /// Update pending operation data (when user edits)
  Future<void> updateOperationData({
    required int operationId,
    required Map<String, dynamic> newContactData,
  }) async {
    await db.update(
      'pending_operations',
      {
        'data': jsonEncode(newContactData),
        'status': 'pending',
        'error_message': null,
      },
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }

  /// Mark operation as successful
  Future<void> markOperationCompleted(int operationId) async {
    await db.update(
      'pending_operations',
      {
        'status': 'completed',
        'last_retry_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }

  /// Delete a specific pending operation
  Future<void> deletePendingOperation(int operationId) async {
    await db.delete(
      'pending_operations',
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }

  /// Get count of pending and failed operations
  Future<Map<String, int>> getOperationCounts() async {
    final pendingCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM pending_operations WHERE operation_type = ? AND status = ?',
            ['create_contact', 'pending'],
          ),
        ) ??
        0;

    final failedCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM pending_operations WHERE operation_type = ? AND status = ?',
            ['create_contact', 'failed'],
          ),
        ) ??
        0;

    return {
      'pending': pendingCount,
      'failed': failedCount,
      'total': pendingCount + failedCount,
    };
  }

  /// Increment retry count for an operation
  Future<void> incrementRetryCount(int operationId) async {
    await db.rawUpdate(
      'UPDATE pending_operations SET retry_count = retry_count + 1, last_retry_at = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), operationId],
    );
  }

  /// Reset operation to pending (after user fixes data)
  Future<void> resetOperationToPending(int operationId) async {
    await db.update(
      'pending_operations',
      {
        'status': 'pending',
        'error_message': null,
        'retry_count': 0,
      },
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }
}
