// lib/services/supabase_service.dart - Updated with Quality Control methods
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:jala_as/services/fcm_service.dart';
import 'package:jala_as/utils/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:jala_as/models/contact_group.dart';
import 'package:jala_as/models/fuel_models.dart';
import 'package:jala_as/models/new_customer.dart';
import 'package:jala_as/models/quality_models.dart';
import 'package:jala_as/models/report_models.dart';
import 'package:jala_as/models/task_checklist_models.dart';
import 'package:jala_as/models/returns_models.dart';
import 'package:jala_as/models/salary_models.dart';
import 'package:jala_as/models/warehouse_models.dart';
import 'package:jala_as/services/api_service.dart';
import 'package:jala_as/services/device_info_service.dart';
import 'package:jala_as/services/local_database_service.dart';
import 'package:jala_as/utils/platform_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import '../models/contact.dart';
import '../models/position.dart';
import '../models/role.dart';
import '../models/custom_report.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  // NEW: Offline support services
  static final LocalDatabaseService _localDb = LocalDatabaseService();
  static final DeviceInfoService _deviceInfo = DeviceInfoService();

  // NEW: Current user cache
  static AppUser? _currentAppUser;
  static AppUser? get currentAppUser => _currentAppUser;

// lib/services/supabase_service.dart

  static Future<void> initialize() async {
    print('\n╔════════════════════════════════════════╗');
    print('║      INITIALIZING SUPABASE SERVICE     ║');
    print('╚════════════════════════════════════════╝');

    await Supabase.initialize(
      url: 'https://ykwnsmyvkwjctidhoqib.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlrd25zbXl2a3dqY3RpZGhvcWliIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExOTkzMzYsImV4cCI6MjA2Njc3NTMzNn0.W6WYYc-s24kX2H_-9bvWe1nG31lDlFCSVnDSqIKD5xk',
    );
    print('✓ Supabase client initialized');

    // NEW: Initialize local database for mobile
    if (PlatformUtils.isMobile) {
      print('\n📱 Initializing local database for mobile...');
      await LocalDatabaseService.initializeDatabase();
      print('✓ Local database initialized');
    }

    // Restore offline session for mobile
    if (PlatformUtils.isMobile) {
      await _restoreOfflineSession();
    } else {
      await _restoreWebSession();
    }

    print('╚════════════════════════════════════════╝\n');
  }

  final supabase = Supabase.instance.client;

// lib/services/supabase_service.dart

// Update the method signature and implementation
  static Future<List<CostCenterStatistics>> getCostCenterStatisticsWithFilters({
    required DateTime fromDate,
    required DateTime toDate,
    String? fromTruckNumber,
    String? toTruckNumber,
    int? fuelContactId, // NEW PARAMETER
  }) async {
    try {
      Map<String, dynamic> params = {
        'from_date': fromDate.toIso8601String().split('T')[0],
        'to_date': toDate.toIso8601String().split('T')[0],
      };

      // Add truck range parameters if provided
      if (fromTruckNumber?.isNotEmpty == true) {
        params['from_truck_number'] = fromTruckNumber;
      }

      if (toTruckNumber?.isNotEmpty == true) {
        params['to_truck_number'] = toTruckNumber;
      }

      // NEW: Add fuel contact parameter if provided
      if (fuelContactId != null) {
        params['fuel_contact_id_param'] = fuelContactId;
      }

      final response = await _client
          .rpc('get_cost_center_statistics_with_filters', params: params)
          .select();

      return response
          .map<CostCenterStatistics>(
              (json) => CostCenterStatistics.fromJson(json))
          .toList();
    } catch (e) {
      print('getCostCenterStatisticsWithFilters error: $e');
      rethrow;
    }
  }

// Method to check if truck number is within range
  static bool isTruckInRange(
      String truckNumber, String? fromTruck, String? toTruck) {
    if (fromTruck?.isEmpty != false && toTruck?.isEmpty != false) {
      return true; // No range specified, include all
    }

    // Try numeric comparison first
    final truckNum = int.tryParse(truckNumber);
    final fromNum =
        fromTruck?.isNotEmpty == true ? int.tryParse(fromTruck!) : null;
    final toNum = toTruck?.isNotEmpty == true ? int.tryParse(toTruck!) : null;

    if (truckNum != null) {
      // Numeric comparison
      bool fromCheck = fromNum == null || truckNum >= fromNum;
      bool toCheck = toNum == null || truckNum <= toNum;
      return fromCheck && toCheck;
    } else {
      // String comparison
      bool fromCheck =
          fromTruck?.isEmpty != false || truckNumber.compareTo(fromTruck!) >= 0;
      bool toCheck =
          toTruck?.isEmpty != false || truckNumber.compareTo(toTruck!) <= 0;
      return fromCheck && toCheck;
    }
  }

  static Map<String, dynamic> calculateChecklistStatistics(
      List<QualityResponse> responses, int checklistId) {
    if (responses.isEmpty) {
      return {
        'total_responses': 0,
        'overall_average': 0.0,
        'check_point_statistics': <String, dynamic>{},
      };
    }

    final checkPointStats = <String, dynamic>{};
    final checkPointTotals = <String, double>{};
    final checkPointCounts = <String, int>{};

    // Get unique checkpoint IDs from responses
    final Set<String> checkPointIds = {};
    for (final response in responses) {
      checkPointIds.addAll(response.checkPointRatings.keys);
    }

    // Initialize counters
    for (final checkPointId in checkPointIds) {
      checkPointTotals[checkPointId] = 0.0;
      checkPointCounts[checkPointId] = 0;
    }

    // Calculate totals
    for (final response in responses) {
      for (final entry in response.checkPointRatings.entries) {
        final checkPointId = entry.key;
        final ratingData = entry.value;

        int rating = 0;
        if (ratingData is Map<String, dynamic>) {
          rating = ratingData['rating'] as int? ?? 0;
        } else if (ratingData is int) {
          rating = ratingData;
        }

        if (rating > 0) {
          checkPointTotals[checkPointId] =
              checkPointTotals[checkPointId]! + rating;
          checkPointCounts[checkPointId] = checkPointCounts[checkPointId]! + 1;
        }
      }
    }

    // Calculate averages
    double overallTotal = 0.0;
    int overallCount = 0;

    for (final checkPointId in checkPointIds) {
      final count = checkPointCounts[checkPointId]!;
      final average = count > 0 ? checkPointTotals[checkPointId]! / count : 0.0;

      checkPointStats[checkPointId] = {
        'average': average,
        'total_responses': count,
      };

      if (count > 0) {
        overallTotal += average * count;
        overallCount += count;
      }
    }

    final overallAverage = overallCount > 0 ? overallTotal / overallCount : 0.0;

    return {
      'total_responses': responses.length,
      'overall_average': overallAverage,
      'check_point_statistics': checkPointStats,
    };
  }

// lib/services/supabase_service.dart

// lib/services/supabase_service.dart

// REPLACE the existing signIn method:
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // Perform online authentication
      final authResponse = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user != null) {
        // Fetch full user data from database (includes additional contacts now)
        final appUser = await getUserById(authResponse.user!.id);
        _currentAppUser = appUser;

        print('✓ User signed in: ${appUser.username}');
        print(
            '✓ Additional contacts loaded: ${appUser.additionalContactCodes?.length ?? 0}');

        // Save session for offline use (mobile only)
        if (PlatformUtils.isMobile) {
          await _saveOfflineSession(
            user: appUser,
            authUser: authResponse.user!,
          );

          // Save persistent login state
          await _localDb.saveLoginState(
            isLoggedIn: true,
            userId: appUser.id,
            username: appUser.username,
            email: appUser.email,
            userType: appUser.userType,
            salesman: appUser.salesman,
            area: appUser.area,
            periodicAreaAssignment: appUser.periodicAreaAssignment,
          );
        } else {
          await _saveWebSession(
            user: appUser,
            authUser: authResponse.user!,
          );
        }
      }

      return authResponse;
    } catch (e) {
      print('SignIn error: $e');
      rethrow;
    }
  }

  /// Sign out (UPDATED with persistent login state clearing)
  static Future<void> signOut() async {
    try {
      // Reset FCM so next login re-requests permission and saves fresh token
      FCMService.clearForLogout();

      // Clear online session
      await _client.auth.signOut();

      // Clear offline session
      if (PlatformUtils.isMobile) {
        await _localDb.clearUserSession();
        await _localDb.clearCachedData();

        // NEW: Clear persistent login state
        await _localDb.clearLoginState();
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('current_user');
        await prefs.remove('auth_token');
        await prefs.setBool('is_logged_in', false); // NEW
      }

      _currentAppUser = null;
    } catch (e) {
      print('SignOut error: $e');
      rethrow;
    }
  }

  static User? get currentAuthUser => _client.auth.currentUser;

  // Contact Groups Management
  static Future<List<ContactGroup>> getContactGroups() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _client
          .from('contact_groups')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return response
          .map<ContactGroup>((json) => ContactGroup.fromJson(json))
          .toList();
    } catch (e) {
      print('getContactGroups error: $e');
      rethrow;
    }
  }

  static Future<ContactGroup> createContactGroup({
    required String name,
    required List<String> contactCodes,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _client
          .from('contact_groups')
          .insert({
            'name': name,
            'user_id': user.id,
            'contact_codes': contactCodes,
          })
          .select()
          .single();

      return ContactGroup.fromJson(response);
    } catch (e) {
      print('createContactGroup error: $e');
      rethrow;
    }
  }

  static Future<ContactGroup> updateContactGroup({
    required int id,
    String? name,
    List<String>? contactCodes,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) updates['name'] = name;
      if (contactCodes != null) updates['contact_codes'] = contactCodes;

      final response = await _client
          .from('contact_groups')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return ContactGroup.fromJson(response);
    } catch (e) {
      print('updateContactGroup error: $e');
      rethrow;
    }
  }

  static Future<void> deleteContactGroup(int id) async {
    try {
      await _client.from('contact_groups').delete().eq('id', id);
    } catch (e) {
      print('deleteContactGroup error: $e');
      rethrow;
    }
  }

  static Future<ContactGroup> getContactGroupById(int id) async {
    try {
      final response =
          await _client.from('contact_groups').select().eq('id', id).single();

      return ContactGroup.fromJson(response);
    } catch (e) {
      print('getContactGroupById error: $e');
      rethrow;
    }
  }

// lib/services/supabase_service.dart
// lib/services/supabase_service.dart

// REPLACE the existing getCurrentUser method with this:
  static Future<AppUser?> getCurrentUser() async {
    print('\n========================================');
    print('🔍 GET CURRENT USER');
    print('========================================');

    // Try to get from Supabase (online)
    final authUser = _client.auth.currentUser;
    if (authUser != null) {
      print('📡 User found in Supabase auth');
      try {
        _currentAppUser = await getUserById(
            authUser.id); // This now includes additional contacts
        print(
            '✓ User details fetched from database: ${_currentAppUser!.username}');
        print(
            '✓ Additional contacts: ${_currentAppUser!.additionalContactCodes?.length ?? 0}');
        print('========================================\n');
        return _currentAppUser;
      } catch (e) {
        print('⚠️ Error getting user from Supabase (might be offline): $e');
      }
    } else {
      print('⚠️ No active Supabase auth session');
    }

    // Mobile: Try persistent login state (offline)
    if (PlatformUtils.isMobile) {
      print('\n📱 Checking mobile persistent login...');
      try {
        final isLoggedIn = await _localDb.isUserLoggedIn();
        print('Login state from DB: $isLoggedIn');

        if (isLoggedIn) {
          final savedUser = await _localDb.getSavedUserInfo();
          if (savedUser != null) {
            // Get additional contacts for saved user
            final additionalContacts =
                await getUserAdditionalContacts(savedUser.id);
            _currentAppUser = savedUser.copyWith(
              additionalContactCodes: additionalContacts,
            );
            print(
                '✓ User restored from local storage: ${_currentAppUser!.username}');
            print('✓ Additional contacts: ${additionalContacts.length}');
            print('========================================\n');
            return _currentAppUser;
          } else {
            print('⚠️ Login state true but no user info found');
          }
        }
      } catch (e) {
        print('❌ Error checking mobile login state: $e');
      }
    } else {
      // Web: Try persistent login state
      print('\n🌐 Checking web persistent login...');
      try {
        final prefs = await SharedPreferences.getInstance();
        final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
        print('Login state from SharedPreferences: $isLoggedIn');

        if (isLoggedIn) {
          final userId = prefs.getString('user_id');
          final username = prefs.getString('username');
          final email = prefs.getString('email');
          final userType = prefs.getString('user_type');
          final salesman = prefs.getString('salesman');
          final area = prefs.getString('area');
          final periodicAreaAssignment =
              prefs.getString('periodic_area_assignment');

          if (userId != null &&
              username != null &&
              email != null &&
              userType != null &&
              salesman != null) {
            // Get additional contacts for web user
            final additionalContacts = await getUserAdditionalContacts(userId);

            _currentAppUser = AppUser(
              id: userId,
              username: username,
              email: email,
              userType: userType,
              salesman: salesman,
              area: area,
              periodicAreaAssignment: periodicAreaAssignment,
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              additionalContactCodes: additionalContacts,
            );
            print(
                '✓ User restored from web storage: ${_currentAppUser!.username}');
            print('✓ Additional contacts: ${additionalContacts.length}');
            print('========================================\n');
            return _currentAppUser;
          }
        }
      } catch (e) {
        print('❌ Error checking web login state: $e');
      }
    }

    print('❌ No user found');
    print('========================================\n');
    return null;
  }

// lib/services/supabase_service.dart

  /// Check if user is logged in (with persistent login support) - UPDATED
// lib/services/supabase_service.dart

  /// Check if user is logged in (with persistent login support) - UPDATED
  static Future<bool> isLoggedIn() async {
    print('\n========================================');
    print('🔐 CHECKING IF USER IS LOGGED IN');
    print('========================================');

    // Check Supabase auth first (online)
    if (_client.auth.currentUser != null) {
      print('✓ User authenticated with Supabase');
      print('========================================\n');
      return true;
    }
    print('⚠️ No Supabase auth session');

    // Check persistent login state
    if (PlatformUtils.isMobile) {
      print('\n📱 Checking mobile persistent state...');
      try {
        final result = await _localDb.isUserLoggedIn();
        print('Result: ${result ? "LOGGED IN ✓" : "NOT LOGGED IN ✗"}');
        print('========================================\n');
        return result;
      } catch (e) {
        print('❌ ERROR checking mobile login: $e');
        print('========================================\n');
        return false;
      }
    } else {
      print('\n🌐 Checking web persistent state...');
      try {
        final prefs = await SharedPreferences.getInstance();
        final result = prefs.getBool('is_logged_in') ?? false;
        print('Result: ${result ? "LOGGED IN ✓" : "NOT LOGGED IN ✗"}');
        print('========================================\n');
        return result;
      } catch (e) {
        print('❌ ERROR checking web login: $e');
        print('========================================\n');
        return false;
      }
    }
  }

  // Users management
  static Future<List<AppUser>> getUsers() async {
    try {
      final response = await _client
          .from('users')
          .select('*, positions(id, name)')
          .order('created_at', ascending: false);

      return response.map<AppUser>((json) => AppUser.fromJson(json)).toList();
    } catch (e) {
      print('getUsers error: $e');
      rethrow;
    }
  }

  /// Save session to local database (mobile only)
  static Future<void> _saveOfflineSession({
    required AppUser user,
    required User authUser,
  }) async {
    try {
      final deviceId = await _deviceInfo.getDeviceId();
      final session = authUser.userMetadata?['session'];
      final accessToken = session?['access_token'] ?? '';
      final refreshToken = session?['refresh_token'];

      // Calculate expiry (default 7 days)
      final expiresAt = DateTime.now().add(const Duration(days: 7));

      await _localDb.saveUserSession(
        userId: user.id,
        username: user.username,
        email: user.email,
        userType: user.userType,
        salesman: user.salesman,
        area: user.area,
        periodicAreaAssignment: user.periodicAreaAssignment,
        isActive: user.isActive,
        deviceId: deviceId,
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt,
      );

      print('✓ Offline session saved for mobile');
    } catch (e) {
      print('Error saving offline session: $e');
    }
  }

  // ==================== WEB SESSION MANAGEMENT ====================
// lib/services/supabase_service.dart

  /// Save session to SharedPreferences (web only) - UPDATED
  static Future<void> _saveWebSession({
    required AppUser user,
    required User authUser,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', user.toJson().toString());
      await prefs.setString('auth_token', authUser.id);

      // NEW: Save persistent login state for web
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('user_id', user.id);
      await prefs.setString('username', user.username);
      await prefs.setString('email', user.email);
      await prefs.setString('user_type', user.userType);
      await prefs.setString('salesman', user.salesman);
      if (user.area != null) await prefs.setString('area', user.area!);
      if (user.periodicAreaAssignment != null) {
        await prefs.setString(
            'periodic_area_assignment', user.periodicAreaAssignment!);
      }

      print('✓ Web session saved with persistent login');
    } catch (e) {
      print('Error saving web session: $e');
    }
  }

  /// Restore session from SharedPreferences (web only) - UPDATED
  static Future<void> _restoreWebSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // NEW: Check persistent login state
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      if (!isLoggedIn) {
        print('⚠️ User not logged in on web');
        return;
      }

      // Restore user info
      final userId = prefs.getString('user_id');
      final username = prefs.getString('username');
      final email = prefs.getString('email');
      final userType = prefs.getString('user_type');
      final salesman = prefs.getString('salesman');
      final area = prefs.getString('area');
      final periodicAreaAssignment =
          prefs.getString('periodic_area_assignment');

      if (userId != null &&
          username != null &&
          email != null &&
          userType != null &&
          salesman != null) {
        _currentAppUser = AppUser(
          id: userId,
          username: username,
          email: email,
          userType: userType,
          salesman: salesman,
          area: area,
          periodicAreaAssignment: periodicAreaAssignment,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        print('✓ Web session restored for: $username');
      }
    } catch (e) {
      print('Error restoring web session: $e');
    }
  }

  static Future<AppUser> getUserById(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select('*, positions(id, name)')
          .eq('id', userId)
          .single();

      // Get additional contacts
      final additionalContactsResponse = await _client
          .rpc('get_user_additional_contacts', params: {'p_user_id': userId});

      final List<String> additionalContactCodes = [];
      if (additionalContactsResponse != null) {
        for (final row in additionalContactsResponse) {
          additionalContactCodes.add(row['contact_code'] as String);
        }
      }

      final userData = Map<String, dynamic>.from(response);
      userData['additional_contact_codes'] = additionalContactCodes;

      return AppUser.fromJson(userData);
    } catch (e) {
      throw Exception('Failed to fetch user: $e');
    }
  }

  static Future<List<AssignCostCenter>> getAssignCostCenters() async {
    try {
      final response = await _client.from('assign_cost_centers').select('''
        id,
        number,
        cost_center_id,
        fuel_type_id,
        created_by,
        created_at,
        updated_at,
        cost_center:cost_centers(id, code, name),
        fuel_type:fuel_types(id, code, name, price)
      ''').order('number', ascending: true);

      return response.map<AssignCostCenter>((json) {
        // Add debug logging to see what's causing the null issue
        print('Processing assign_cost_center: ${json}');
        return AssignCostCenter.fromJson(json);
      }).toList();
    } catch (e) {
      print('getAssignCostCenters error: $e');
      rethrow;
    }
  }

// 2. Updated createAssignCostCenter method to include fuel type
  static Future<AssignCostCenter> createAssignCostCenter({
    required String number,
    required int costCenterId,
    required int fuelTypeId, // NEW PARAMETER
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final response = await _client.from('assign_cost_centers').insert({
        'number': number,
        'cost_center_id': costCenterId,
        'fuel_type_id': fuelTypeId, // NEW FIELD
        'created_by': currentUser.id,
      }).select('''
        id,
        number,
        cost_center_id,
        fuel_type_id,
        created_by,
        created_at,
        updated_at,
        cost_center:cost_centers(id, code, name),
        fuel_type:fuel_types(id, code, name, price)
      ''').single();

      return AssignCostCenter.fromJson(response);
    } catch (e) {
      print('createAssignCostCenter error: $e');
      rethrow;
    }
  }

// 3. Updated updateAssignCostCenter method to include fuel type
  static Future<AssignCostCenter> updateAssignCostCenter({
    required int id,
    String? number,
    int? costCenterId,
    int? fuelTypeId, // NEW PARAMETER
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (number != null) updates['number'] = number;
      if (costCenterId != null) updates['cost_center_id'] = costCenterId;
      if (fuelTypeId != null) updates['fuel_type_id'] = fuelTypeId; // NEW FIELD

      final response = await _client
          .from('assign_cost_centers')
          .update(updates)
          .eq('id', id)
          .select('''
        id,
        number,
        cost_center_id,
        fuel_type_id,
        created_by,
        created_at,
        updated_at,
        cost_center:cost_centers(id, code, name),
        fuel_type:fuel_types(id, code, name, price)
      ''').single();

      return AssignCostCenter.fromJson(response);
    } catch (e) {
      print('updateAssignCostCenter error: $e');
      rethrow;
    }
  }

// 4. Updated createFuelFillingRecord method to use assign_cost_center_id
  static Future<FuelFillingRecord> createFuelFillingRecord({
    required DateTime fillingDate,
    required String truckNumber,
    required int assignCostCenterId, // NEW: Direct assign_cost_center_id
    required int fuelTypeId,
    required double amount,
    required double quantity,
    required String meterReading,
    String? imageUrl,
    String? imageName,
    int? imageSize,
    String? mimeType,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Prepare the data without any ID field - let the database handle it
      final Map<String, dynamic> insertData = {
        'filling_date': fillingDate.toIso8601String().split('T')[0],
        'truck_number': truckNumber,
        'assign_cost_center_id': assignCostCenterId, // Use direct ID
        'fuel_type_id': fuelTypeId,
        'amount': amount,
        'quantity': quantity,
        'meter_reading': meterReading.isEmpty ? null : meterReading,
        'user_id': currentUser.id,
      };

      // Only add optional fields if they have values
      if (imageUrl?.isNotEmpty == true) insertData['image_url'] = imageUrl;
      if (imageName?.isNotEmpty == true) insertData['image_name'] = imageName;
      if (imageSize != null && imageSize > 0)
        insertData['image_size'] = imageSize;
      if (mimeType?.isNotEmpty == true) insertData['mime_type'] = mimeType;

      print('Inserting fuel record with data: $insertData'); // Debug log

      final response = await _client
          .from('fuel_filling_records')
          .insert(insertData)
          .select('''
        *,
        fuel_type:fuel_types(*),
        assign_cost_center:assign_cost_centers(
          *,
          cost_center:cost_centers(*),
          fuel_type:fuel_types(*)
        )
      ''').single();

      return FuelFillingRecord.fromJson(response);
    } catch (e) {
      print('createFuelFillingRecord error: $e');
      if (e
          .toString()
          .contains('duplicate key value violates unique constraint')) {
        throw Exception('خطأ في قاعدة البيانات: يرجى المحاولة مرة أخرى');
      }
      rethrow;
    }
  }

// 5. Updated getFuelFillingRecords method to include fuel type relationship
  static Future<List<FuelFillingRecord>> getFuelFillingRecords({
    String? userId,
    DateTime? fromDate,
    DateTime? toDate,
    String? truckNumber,
    int? fuelTypeId,
  }) async {
    try {
      var query = _client.from('fuel_filling_records').select('''
        *,
        fuel_type:fuel_types(*),
        assign_cost_center:assign_cost_centers(
          *,
          cost_center:cost_centers(*),
          fuel_type:fuel_types(*)
        ),
        fuel_contact:fuel_contacts(*)  // ADD THIS LINE
      ''');

      if (userId != null) {
        query = query.eq('user_id', userId);
      }

      if (fromDate != null) {
        query =
            query.gte('filling_date', fromDate.toIso8601String().split('T')[0]);
      }

      if (toDate != null) {
        query =
            query.lte('filling_date', toDate.toIso8601String().split('T')[0]);
      }

      if (truckNumber != null) {
        query = query.eq('truck_number', truckNumber);
      }

      if (fuelTypeId != null) {
        query = query.eq('fuel_type_id', fuelTypeId);
      }

      final response = await query.order('filling_date', ascending: false);

      // Add debug logging to see what's being returned
      print('=== FUEL RECORDS QUERY RESPONSE ===');
      print('Total records: ${response.length}');
      if (response.isNotEmpty) {
        print('First record fuel_contact: ${response[0]['fuel_contact']}');
        print(
            'First record fuel_contact_id: ${response[0]['fuel_contact_id']}');
      }
      print('==================================');

      return response
          .map<FuelFillingRecord>((json) => FuelFillingRecord.fromJson(json))
          .toList();
    } catch (e) {
      print('getFuelFillingRecords error: $e');
      rethrow;
    }
  }

// 6. Updated updateFuelFillingRecord method to handle truck changes properly
  static Future<FuelFillingRecord> updateFuelFillingRecord({
    required int id,
    DateTime? fillingDate,
    String? truckNumber,
    int? fuelTypeId,
    double? amount,
    double? quantity,
    String? meterReading,
    String? imageUrl,
    String? imageName,
    int? imageSize,
    String? mimeType,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fillingDate != null) {
        updates['filling_date'] = fillingDate.toIso8601String().split('T')[0];
      }

      if (truckNumber != null) {
        // Find the assign_cost_center by truck number
        final assignCostCenter = await _client
            .from('assign_cost_centers')
            .select('id')
            .eq('number', truckNumber)
            .single();

        updates['truck_number'] = truckNumber;
        updates['assign_cost_center_id'] = assignCostCenter['id'] as int;
      }

      if (fuelTypeId != null) updates['fuel_type_id'] = fuelTypeId;
      if (amount != null) updates['amount'] = amount;
      if (quantity != null) updates['quantity'] = quantity;
      if (meterReading != null) updates['meter_reading'] = meterReading;
      if (imageUrl != null) updates['image_url'] = imageUrl;
      if (imageName != null) updates['image_name'] = imageName;
      if (imageSize != null) updates['image_size'] = imageSize;
      if (mimeType != null) updates['mime_type'] = mimeType;

      final response = await _client
          .from('fuel_filling_records')
          .update(updates)
          .eq('id', id)
          .select('''
      *,
      fuel_type:fuel_types(*),
      assign_cost_center:assign_cost_centers(
        *,
        cost_center:cost_centers(*),
        fuel_type:fuel_types(*)
      )
    ''').single();

      return FuelFillingRecord.fromJson(response);
    } catch (e) {
      print('updateFuelFillingRecord error: $e');
      rethrow;
    }
  }

// 7. Helper method to get truck with fuel type by number
  static Future<AssignCostCenter?> getTruckWithFuelTypeByNumber(
      String truckNumber) async {
    try {
      final response = await _client.from('assign_cost_centers').select('''
        id,
        number,
        cost_center_id,
        fuel_type_id,
        created_by,
        created_at,
        updated_at,
        cost_center:cost_centers(id, code, name),
        fuel_type:fuel_types(id, code, name, price)
      ''').eq('number', truckNumber).maybeSingle();

      return response != null ? AssignCostCenter.fromJson(response) : null;
    } catch (e) {
      print('getTruckWithFuelTypeByNumber error: $e');
      return null;
    }
  }

  // Quality Checklist Groups
  static Future<List<QualityChecklistGroup>> getQualityChecklistGroups(
      {bool? isActive}) async {
    try {
      var query = _client.from('quality_checklist_groups').select('''
        *,
        checklists:quality_checklists(*)
      ''');

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      final response = await query.order('created_at', ascending: false);

      return response
          .map<QualityChecklistGroup>(
              (json) => QualityChecklistGroup.fromJson(json))
          .toList();
    } catch (e) {
      print('getQualityChecklistGroups error: $e');
      rethrow;
    }
  }

  static Future<QualityChecklistGroup> createQualityChecklistGroup({
    required String title,
    String? description,
    required bool isMultipleActive,
    Determinant? selectorDeterminant,
    required List<QualityChecklist> checklists,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Create the group first
      final groupResponse = await _client
          .from('quality_checklist_groups')
          .insert({
            'title': title,
            'description': description,
            'is_multiple_active': isMultipleActive,
            'selector_determinant': selectorDeterminant?.toJson(),
            'created_by': currentUser.id,
            'is_active': true,
          })
          .select()
          .single();

      final groupId = groupResponse['id'] as int;

      // Create associated checklists
      for (final checklist in checklists) {
        await _client.from('quality_checklists').insert({
          'group_id': groupId,
          'title': checklist.title,
          'description': checklist.description,
          'selector_option_value': checklist.selectorOptionValue,
          'determinants':
              checklist.determinants.map((d) => d.toJson()).toList(),
          'rate_number': checklist.rateNumber,
          'rating_scale':
              checklist.ratingScale.map((rs) => rs.toJson()).toList(),
          'check_points':
              checklist.checkPoints.map((cp) => cp.toJson()).toList(),
          'created_by': currentUser.id,
          'is_active': true,
        });
      }

      // Return the complete group with checklists
      final completeResponse =
          await _client.from('quality_checklist_groups').select('''
            *,
            checklists:quality_checklists(*)
          ''').eq('id', groupId).single();

      return QualityChecklistGroup.fromJson(completeResponse);
    } catch (e) {
      print('createQualityChecklistGroup error: $e');
      rethrow;
    }
  }

// Add this to your SupabaseService class

  /// Updates a quality checklist group without affecting existing responses/sessions
  static Future<void> updateQualityChecklistGroup({
    required int id,
    String? title,
    String? description,
    bool? isMultipleActive,
    Determinant? selectorDeterminant,
    List<QualityChecklist>? checklists,
    bool? isActive,
  }) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Start transaction
      final response = await Supabase.instance.client
          .rpc('update_checklist_group_safe', params: {
        'p_group_id': id,
        'p_title': title,
        'p_description': description,
        'p_is_multiple_active': isMultipleActive,
        'p_selector_determinant': selectorDeterminant?.toJson(),
        'p_checklists': checklists?.map((c) => c.toJson()).toList(),
        'p_is_active': isActive,
      });

      if (response == null) {
        throw Exception('Failed to update checklist group');
      }
    } catch (e) {
      print('Error updating checklist group: $e');
      rethrow;
    }
  }

  /// Updates individual checklist without affecting responses/sessions
  static Future<void> updateQualityChecklistSafe({
    required int checklistId,
    String? title,
    String? description,
    String? selectorOptionValue,
    List<Determinant>? determinants,
    int? rateNumber,
    List<RatingScale>? ratingScale,
    List<CheckPoint>? checkPoints,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (selectorOptionValue != null)
        updates['selector_option_value'] = selectorOptionValue;
      if (determinants != null)
        updates['determinants'] = determinants.map((d) => d.toJson()).toList();
      if (rateNumber != null) updates['rate_number'] = rateNumber;
      if (ratingScale != null)
        updates['rating_scale'] = ratingScale.map((rs) => rs.toJson()).toList();
      if (checkPoints != null)
        updates['check_points'] = checkPoints.map((cp) => cp.toJson()).toList();
      if (isActive != null) updates['is_active'] = isActive;

      updates['updated_at'] = DateTime.now().toIso8601String();

      // Update checklist record directly - preserves foreign key relationships
      final response = await Supabase.instance.client
          .from('quality_checklists')
          .update(updates)
          .eq('id', checklistId)
          .select();

      if (response.isEmpty) {
        throw Exception('Failed to update checklist');
      }
    } catch (e) {
      print('Error updating checklist: $e');
      rethrow;
    }
  }

  static Future<void> deleteQualityChecklistGroup(int id) async {
    try {
      await _client.from('quality_checklist_groups').delete().eq('id', id);
    } catch (e) {
      print('deleteQualityChecklistGroup error: $e');
      rethrow;
    }
  }

  static Future<void> duplicateQualityChecklistGroup(int groupId) async {
    try {
      final groupData = await _client
          .from('quality_checklist_groups')
          .select('*, checklists:quality_checklists(*)')
          .eq('id', groupId)
          .single();

      final newTitle = '${groupData['title']} (نسخة 1)';
      final newGroupResponse = await _client.from('quality_checklist_groups').insert({
        'title': newTitle,
        'description': groupData['description'],
        'is_multiple_active': groupData['is_multiple_active'],
        'selector_determinant': groupData['selector_determinant'],
        'is_active': groupData['is_active'],
      }).select().single();

      final newGroupId = newGroupResponse['id'] as int;

      for (final cl in (groupData['checklists'] as List? ?? [])) {
        await _client.from('quality_checklists').insert({
          'group_id': newGroupId,
          'title': cl['title'],
          'description': cl['description'],
          'selector_option_value': cl['selector_option_value'],
          'determinants': cl['determinants'],
          'rate_number': cl['rate_number'],
          'rating_scale': cl['rating_scale'],
          'check_points': cl['check_points'],
          'is_active': cl['is_active'],
        });
      }
    } catch (e) {
      print('duplicateQualityChecklistGroup error: $e');
      rethrow;
    }
  }

  static Future<void> duplicateQualityChecklist(int checklistId) async {
    try {
      final data = await _client
          .from('quality_checklists')
          .select()
          .eq('id', checklistId)
          .single();
      await _client.from('quality_checklists').insert({
        'group_id': data['group_id'],
        'title': '${data['title']} (نسخة 1)',
        'description': data['description'],
        'selector_option_value': data['selector_option_value'],
        'determinants': data['determinants'],
        'rate_number': data['rate_number'],
        'rating_scale': data['rating_scale'],
        'check_points': data['check_points'],
        'is_active': data['is_active'],
      });
    } catch (e) {
      print('duplicateQualityChecklist error: $e');
      rethrow;
    }
  }

  static Future<WarehouseTransferRequest> createWarehouseTransferRequest({
    required String sourceWarehouse,
    required String targetWarehouse,
    required String warehouseType,
    required List<TransferItem> items,
    String? targetUserId,
    String? targetUserName,
    String? comment,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get current user details
      final userResponse = await _client
          .from('users')
          .select('username')
          .eq('id', currentUser.id)
          .single();

      final requesterName = userResponse['username'] as String;

      final requestData = {
        'requester_id': currentUser.id,
        'requester_name': requesterName,
        'target_user_id': targetUserId,
        'target_user_name': targetUserName,
        'source_warehouse': sourceWarehouse,
        'target_warehouse': targetWarehouse,
        'warehouse_type': warehouseType,
        'items': items
            .map((item) => {
                  'item_code': item.itemCode,
                  'item_name': item.itemName,
                  'unit': item.unit,
                  'available_quantity': item.availableQuantity,
                  'requested_quantity': item.requestedQuantity,
                })
            .toList(),
        'status': TransferStatus.pending.name,
        'comment': comment,
        'request_date': DateTime.now().toIso8601String(),
      };

      print('DEBUG: Creating warehouse transfer request');

      final response = await _client
          .from('warehouse_transfer_requests')
          .insert(requestData)
          .select()
          .single();

      print('DEBUG: Warehouse transfer request created successfully');
      return WarehouseTransferRequest.fromJson(response);
    } catch (e) {
      print('DEBUG: createWarehouseTransferRequest error: $e');
      rethrow;
    }
  }

  /// Create new customer record in Supabase
  static Future<int> createNewCustomerRecord({
    required String bisanCode,
    required String businessName,
    required String ownerName,
    String? responsiblePerson,
    String? taxId,
    String? idNumber,
    required String mobile,
    String? telephone,
    String? email,
    String? city,
    String? state,
    String? stateType,
    String? street,
    String? beside,
    String? businessType,
    String? businessTypeName,
    String? visitDays,
    String? paymentMethod,
    String? creditLimit,
    required DateTime createdDate,
    required String salesman,
    required String username,
    String? pdfUrl,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      final response = await _client
          .from('new_customers')
          .insert({
            'bisan_code': bisanCode,
            'business_name': businessName,
            'owner_name': ownerName,
            'responsible_person': responsiblePerson,
            'tax_id': taxId,
            'id_number': idNumber,
            'mobile': mobile,
            'telephone': telephone,
            'email': email,
            'city': city,
            'state': state,
            'state_type': stateType,
            'street': street,
            'beside': beside,
            'business_type': businessType,
            'business_type_name': businessTypeName,
            'visit_days': visitDays,
            'payment_method': paymentMethod,
            'credit_limit': creditLimit,
            'created_date': createdDate.toIso8601String(),
            'salesman': salesman,
            'username': username,
            'pdf_url': pdfUrl,
            'created_by': user.id,
            'status': 'unchecked',
          })
          .select()
          .single();

      return response['id'] as int;
    } catch (e) {
      print('Error creating new customer record: $e');
      rethrow;
    }
  }

  /// Upload new customer image to Supabase storage
  static Future<String> uploadNewCustomerImage({
    required int customerId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = fileName.split('.').last;
      final storagePath = 'customer_${customerId}/${timestamp}_$fileName';

      await _client.storage
          .from('new-customer-images')
          .uploadBinary(storagePath, imageBytes);

      final publicUrl =
          _client.storage.from('new-customer-images').getPublicUrl(storagePath);

      return publicUrl;
    } catch (e) {
      print('Error uploading new customer image: $e');
      rethrow;
    }
  }

  /// Create new customer image record
  static Future<void> createNewCustomerImageRecord({
    required int newCustomerId,
    required String imageUrl,
    required String imageName,
    required int imageSize,
    required String mimeType,
  }) async {
    try {
      await _client.from('new_customer_images').insert({
        'new_customer_id': newCustomerId,
        'image_url': imageUrl,
        'image_name': imageName,
        'image_size': imageSize,
        'mime_type': mimeType,
      });
    } catch (e) {
      print('Error creating new customer image record: $e');
      rethrow;
    }
  }

  /// Upload new customer PDF to Supabase storage
  static Future<String> uploadNewCustomerPdf({
    required int customerId,
    required Uint8List pdfBytes,
    required String fileName,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'customer_${customerId}/pdf_${timestamp}_$fileName';

      await _client.storage
          .from('new-customer-images')
          .uploadBinary(storagePath, pdfBytes);

      final publicUrl =
          _client.storage.from('new-customer-images').getPublicUrl(storagePath);

      return publicUrl;
    } catch (e) {
      print('Error uploading new customer PDF: $e');
      rethrow;
    }
  }

  /// Update new customer PDF URL
  static Future<void> updateNewCustomerPdfUrl({
    required int customerId,
    required String pdfUrl,
  }) async {
    try {
      await _client
          .from('new_customers')
          .update({'pdf_url': pdfUrl}).eq('id', customerId);
    } catch (e) {
      print('Error updating new customer PDF URL: $e');
      rethrow;
    }
  }

  /// Get new customers with optional status filter
  static Future<List<NewCustomer>> getNewCustomers({String? status}) async {
    try {
      final response =
          await _client.rpc('get_new_customers_with_images', params: {
        'filter_status': status,
      });

      return (response as List)
          .map((json) => NewCustomer.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting new customers: $e');
      rethrow;
    }
  }

  /// Mark customer as checked
  static Future<void> markCustomerAsChecked(int customerId) async {
    try {
      await _client.rpc('mark_customer_as_checked', params: {
        'customer_id': customerId,
      });
    } catch (e) {
      print('Error marking customer as checked: $e');
      rethrow;
    }
  }

  /// Get all items from Supabase
  static Future<List<Item>> getItems({String? search}) async {
    try {
      print('DEBUG: getItems called with search: "$search"');

      var query = _client.from('items').select();

      if (search != null && search.isNotEmpty) {
        query = query.or('name_ar.ilike.%$search%,code.ilike.%$search%');
      }

      final response = await query.order('name_ar', ascending: true);

      return response.map<Item>((json) => Item.fromJson(json)).toList();
    } catch (e) {
      print('getItems error: $e');
      rethrow;
    }
  }

  /// Get total items count
  static Future<int> getTotalItemsCount() async {
    try {
      final response = await _client.rpc('get_items_count').select();
      return response[0]['count'] as int;
    } catch (e) {
      print('Error getting items count: $e');
      return 0;
    }
  }

  /// Sync items from Bisan API (upsert - update existing, add new)
  static Future<void> syncItems(List<Item> items) async {
    try {
      print('DEBUG: Starting items sync with ${items.length} items');

      // Use upsert with batch processing
      const batchSize = 100;
      int successCount = 0;
      int errorCount = 0;

      for (int i = 0; i < items.length; i += batchSize) {
        final batch = items.skip(i).take(batchSize).map((item) {
          final json = item.toJson();
          json.remove('id'); // Remove ID to let database handle it
          json.remove('created_at'); // Don't update created_at
          return json;
        }).toList();

        try {
          // Upsert: Update if exists (based on code), insert if new
          await _client.from('items').upsert(
                batch,
                onConflict: 'code', // Use code as unique identifier
              );
          successCount += batch.length;
          print(
              'DEBUG: Synced batch ${(i ~/ batchSize) + 1}, items: ${batch.length}');
        } catch (e) {
          errorCount += batch.length;
          print('DEBUG: Error syncing batch ${(i ~/ batchSize) + 1}: $e');
        }
      }

      print(
          'DEBUG: Items sync completed - Success: $successCount, Errors: $errorCount');
    } catch (e) {
      print('syncItems error: $e');
      rethrow;
    }
  }

  /// Get item by code
  static Future<Item?> getItemByCode(String code) async {
    try {
      final response =
          await _client.from('items').select().eq('code', code).maybeSingle();

      return response != null ? Item.fromJson(response) : null;
    } catch (e) {
      print('getItemByCode error: $e');
      return null;
    }
  }

  /// Search items by multiple criteria
  static Future<List<Item>> searchItems({
    String? searchText,
    String? brandCode,
    String? categoryCode,
  }) async {
    try {
      var query = _client.from('items').select();

      if (searchText != null && searchText.isNotEmpty) {
        query = query.or(
          'name_ar.ilike.%$searchText%,code.ilike.%$searchText%,name_en.ilike.%$searchText%',
        );
      }

      if (brandCode != null && brandCode.isNotEmpty) {
        query = query.eq('brand_code', brandCode);
      }

      if (categoryCode != null && categoryCode.isNotEmpty) {
        query = query.eq('item_category_code', categoryCode);
      }

      final response = await query.order('name_ar', ascending: true);

      return response.map<Item>((json) => Item.fromJson(json)).toList();
    } catch (e) {
      print('searchItems error: $e');
      rethrow;
    }
  }

// ==================== WAREHOUSES MANAGEMENT ====================

  /// Get all warehouses from Supabase
  static Future<List<Warehouse>> getWarehouses({String? search}) async {
    try {
      print('DEBUG: getWarehouses called with search: "$search"');

      var query = _client.from('warehouses').select();

      if (search != null && search.isNotEmpty) {
        query = query.or('name_ar.ilike.%$search%,code.ilike.%$search%');
      }

      final response = await query.order('name_ar', ascending: true);

      return response
          .map<Warehouse>((json) => Warehouse.fromJson(json))
          .toList();
    } catch (e) {
      print('getWarehouses error: $e');
      rethrow;
    }
  }

// In SupabaseService class
  static Future<List<SalesReturn>> getSalesReturns({
    String? userId,
    DateTime? fromDate,
    DateTime? toDate,
    String? contactCode,
  }) async {
    try {
      print('🔍 Fetching sales returns from Supabase...');

      var query = _client.from('sales_returns').select();

      if (userId != null) {
        query = query.eq('user_id', userId);
      }

      if (fromDate != null) {
        query =
            query.gte('return_date', fromDate.toIso8601String().split('T')[0]);
      }

      if (toDate != null) {
        query =
            query.lte('return_date', toDate.toIso8601String().split('T')[0]);
      }

      if (contactCode != null) {
        query = query.eq('contact_code', contactCode);
      }

      final response = await query.order('created_at', ascending: false);

      print('📊 Raw response from Supabase:');
      print(response);

      if (response == null) {
        print('❌ Response is null');
        return [];
      }

      if (response.isEmpty) {
        print('ℹ️ No returns found in database');
        return [];
      }

      final returns = response.map<SalesReturn>((json) {
        print('🔄 Parsing return: ${json['return_code']}');
        return SalesReturn.fromJson(json);
      }).toList();

      print('✅ Successfully loaded ${returns.length} returns');
      return returns;
    } catch (e) {
      print('❌ getSalesReturns error: $e');
      print('Stack trace: ${e.toString()}');
      rethrow;
    }
  }

  /// Create sales return record in Supabase
  static Future<SalesReturn> createSalesReturn({
    required String returnCode,
    required String contactCode,
    required String contactName,
    required DateTime returnDate,
    required String returnReasonCode,
    required String returnReasonName,
    required String warehouseCode,
    String? warehouseName,
    String? comment,
    required List<ReturnItem> items,
    Map<String, dynamic>? bisanResponse,
    String? transactionId,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get username
      final userResponse = await _client
          .from('users')
          .select('username')
          .eq('id', currentUser.id)
          .single();

      final username = userResponse['username'] as String;

      // Prepare items data for storage
      final List<Map<String, dynamic>> itemsData = items.map((item) {
        return {
          'item_code': item.itemCode,
          'item_name': item.itemName,
          'quantity': item.quantity,
          'unit': item.unit,
          'price': item.price,
          'total_amount': (item.quantity * item.price),
        };
      }).toList();

      final response = await _client
          .from('sales_returns')
          .insert({
            'return_code': returnCode,
            'contact_code': contactCode,
            'contact_name': contactName,
            'return_date': returnDate.toIso8601String().split('T')[0],
            'return_reason_code': returnReasonCode,
            'return_reason_name': returnReasonName,
            'warehouse_code': warehouseCode,
            'warehouse_name': warehouseName,
            'comment': comment,
            'items': itemsData,
            'bisan_response': bisanResponse,
            'transaction_id': transactionId,
            'user_id': currentUser.id,
            'username': username,
          })
          .select()
          .single();

      print('✓ Sales return created in Supabase: $returnCode');
      return SalesReturn.fromJson(response);
    } catch (e) {
      print('createSalesReturn error: $e');
      rethrow;
    }
  }

  /// Get single sales return by code
  static Future<SalesReturn?> getSalesReturnByCode(String returnCode) async {
    try {
      final response = await _client
          .from('sales_returns')
          .select()
          .eq('return_code', returnCode)
          .maybeSingle();

      return response != null ? SalesReturn.fromJson(response) : null;
    } catch (e) {
      print('getSalesReturnByCode error: $e');
      return null;
    }
  }

  /// Get returns statistics
  static Future<Map<String, dynamic>> getReturnsStatistics({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final response = await _client.rpc('get_returns_statistics', params: {
        'from_date': fromDate?.toIso8601String().split('T')[0],
        'to_date': toDate?.toIso8601String().split('T')[0],
      }).single();

      return response as Map<String, dynamic>;
    } catch (e) {
      print('getReturnsStatistics error: $e');
      return {
        'total_returns': 0,
        'total_items': 0,
        'by_reason': {},
      };
    }
  }

  /// Get total warehouses count
  static Future<int> getTotalWarehousesCount() async {
    try {
      final response = await _client.rpc('get_warehouses_count').select();
      return response[0]['count'] as int;
    } catch (e) {
      print('Error getting warehouses count: $e');
      return 0;
    }
  }

  /// Sync warehouses from Bisan API (upsert - update existing, add new)
  static Future<void> syncWarehouses(List<Warehouse> warehouses) async {
    try {
      print(
          'DEBUG: Starting warehouses sync with ${warehouses.length} warehouses');

      // Use upsert with batch processing
      const batchSize = 100;
      int successCount = 0;
      int errorCount = 0;

      for (int i = 0; i < warehouses.length; i += batchSize) {
        final batch = warehouses.skip(i).take(batchSize).map((warehouse) {
          final json = warehouse.toJson();
          json.remove('id'); // Remove ID to let database handle it
          json.remove('created_at'); // Don't update created_at
          return json;
        }).toList();

        try {
          // Upsert: Update if exists (based on code), insert if new
          await _client.from('warehouses').upsert(
                batch,
                onConflict: 'code', // Use code as unique identifier
              );
          successCount += batch.length;
          print(
              'DEBUG: Synced batch ${(i ~/ batchSize) + 1}, warehouses: ${batch.length}');
        } catch (e) {
          errorCount += batch.length;
          print('DEBUG: Error syncing batch ${(i ~/ batchSize) + 1}: $e');
        }
      }

      print(
          'DEBUG: Warehouses sync completed - Success: $successCount, Errors: $errorCount');
    } catch (e) {
      print('syncWarehouses error: $e');
      rethrow;
    }
  }

  /// Get warehouse by code
  static Future<Warehouse?> getWarehouseByCode(String code) async {
    try {
      final response = await _client
          .from('warehouses')
          .select()
          .eq('code', code)
          .maybeSingle();

      return response != null ? Warehouse.fromJson(response) : null;
    } catch (e) {
      print('getWarehouseByCode error: $e');
      return null;
    }
  }

  /// Get warehouse transfer requests for current user
  static Future<List<WarehouseTransferRequest>> getWarehouseTransferRequests({
    bool? sentByMe,
    bool? receivedByMe,
    TransferStatus? status,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      var query = _client.from('warehouse_transfer_requests').select();

      if (sentByMe == true) {
        query = query.eq('requester_id', currentUser.id);
      } else if (receivedByMe == true) {
        query = query.eq('target_user_id', currentUser.id);
      } else {
        // Show both sent and received requests
        query = query.or(
            'requester_id.eq.${currentUser.id},target_user_id.eq.${currentUser.id}');
      }

      if (status != null) {
        query = query.eq('status', status.name);
      }

      final response = await query.order('created_at', ascending: false);

      return response
          .map<WarehouseTransferRequest>(
              (json) => WarehouseTransferRequest.fromJson(json))
          .toList();
    } catch (e) {
      print('DEBUG: getWarehouseTransferRequests error: $e');
      rethrow;
    }
  }

  /// Get pending transfer requests for current user (received)
  static Future<List<WarehouseTransferRequest>>
      getPendingTransferRequests() async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final response = await _client
          .from('warehouse_transfer_requests')
          .select()
          .eq('target_user_id', currentUser.id)
          .eq('status', TransferStatus.pending.name)
          .order('created_at', ascending: false);

      return response
          .map<WarehouseTransferRequest>(
              (json) => WarehouseTransferRequest.fromJson(json))
          .toList();
    } catch (e) {
      print('DEBUG: getPendingTransferRequests error: $e');
      rethrow;
    }
  }

  /// Approve warehouse transfer request - FIXED
  static Future<WarehouseTransferRequest> approveWarehouseTransferRequest({
    required int requestId,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      print(
          'DEBUG: Attempting to approve request ID: $requestId by user: ${currentUser.id}');

      // First, verify the request exists and the user can approve it
      final existingRequest = await _client
          .from('warehouse_transfer_requests')
          .select()
          .eq('id', requestId)
          .eq('target_user_id', currentUser.id)
          .eq('status', TransferStatus.pending.name)
          .maybeSingle();

      if (existingRequest == null) {
        throw Exception(
            'Request not found or you do not have permission to approve it');
      }

      print(
          'DEBUG: Found request to approve, current status: ${existingRequest['status']}');

      final updates = {
        'status': TransferStatus.approved.name,
        'approved_date': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Update without requiring return
      await _client
          .from('warehouse_transfer_requests')
          .update(updates)
          .eq('id', requestId)
          .eq('target_user_id', currentUser.id);

      print('DEBUG: Request approved successfully');

      // Then fetch the updated record
      final response = await _client
          .from('warehouse_transfer_requests')
          .select()
          .eq('id', requestId)
          .single();

      print('DEBUG: Warehouse transfer request approved: $requestId');
      return WarehouseTransferRequest.fromJson(response);
    } catch (e) {
      print('DEBUG: approveWarehouseTransferRequest error: $e');
      rethrow;
    }
  }

  /// Original method for simple rejection (without reversal) - keep for backwards compatibility
  static Future<WarehouseTransferRequest> rejectWarehouseTransferRequest({
    required int requestId,
    String? rejectionReason,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      print('DEBUG: Rejecting request without reversal: $requestId');

      final updates = {
        'status': TransferStatus.rejected.name,
        'comment': rejectionReason ?? 'تم الرفض',
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _client
          .from('warehouse_transfer_requests')
          .update(updates)
          .eq('id', requestId)
          .eq('target_user_id', currentUser.id);

      final response = await _client
          .from('warehouse_transfer_requests')
          .select()
          .eq('id', requestId)
          .single();

      print('DEBUG: Warehouse transfer request rejected: $requestId');
      return WarehouseTransferRequest.fromJson(response);
    } catch (e) {
      print('DEBUG: rejectWarehouseTransferRequest error: $e');
      rethrow;
    }
  }

  /// Original method for simple deletion (without reversal) - keep for backwards compatibility
  static Future<void> deleteWarehouseTransferRequest(int requestId) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _client
          .from('warehouse_transfer_requests')
          .delete()
          .eq('id', requestId)
          .eq('requester_id', currentUser.id)
          .eq('status', TransferStatus.pending.name);

      print('DEBUG: Warehouse transfer request deleted: $requestId');
    } catch (e) {
      print('DEBUG: deleteWarehouseTransferRequest error: $e');
      rethrow;
    }
  }

  /// Complete warehouse transfer request (after successful Bisan API call) - FIXED
  static Future<WarehouseTransferRequest> completeWarehouseTransferRequest({
    required int requestId,
    required String bisanTransactionId,
  }) async {
    try {
      print('DEBUG: Attempting to complete request ID: $requestId');

      // First, verify the request exists and get its current state
      final existingRequest = await _client
          .from('warehouse_transfer_requests')
          .select()
          .eq('id', requestId)
          .maybeSingle();

      if (existingRequest == null) {
        throw Exception('Request not found with ID: $requestId');
      }

      print('DEBUG: Found existing request: ${existingRequest['status']}');

      final updates = {
        'status': TransferStatus.completed.name,
        'completed_date': DateTime.now().toIso8601String(),
        'bisan_transaction_id': bisanTransactionId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Try the update without requiring a return value first
      await _client
          .from('warehouse_transfer_requests')
          .update(updates)
          .eq('id', requestId);

      print('DEBUG: Request updated successfully');

      // Then fetch the updated record
      final response = await _client
          .from('warehouse_transfer_requests')
          .select()
          .eq('id', requestId)
          .single();

      print('DEBUG: Warehouse transfer request completed: $requestId');
      return WarehouseTransferRequest.fromJson(response);
    } catch (e) {
      print('DEBUG: completeWarehouseTransferRequest error: $e');
      rethrow;
    }
  }

  /// Get warehouse transfer statistics for admin
  static Future<Map<String, dynamic>> getWarehouseTransferStatistics({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      var query = _client.from('warehouse_transfer_requests').select();

      if (fromDate != null) {
        query =
            query.gte('request_date', fromDate.toIso8601String().split('T')[0]);
      }

      if (toDate != null) {
        query =
            query.lte('request_date', toDate.toIso8601String().split('T')[0]);
      }

      final response = await query;

      final total = response.length;
      final pending = response
          .where((r) => r['status'] == TransferStatus.pending.name)
          .length;
      final approved = response
          .where((r) => r['status'] == TransferStatus.approved.name)
          .length;
      final completed = response
          .where((r) => r['status'] == TransferStatus.completed.name)
          .length;
      final rejected = response
          .where((r) => r['status'] == TransferStatus.rejected.name)
          .length;

      return {
        'total_requests': total,
        'pending_requests': pending,
        'approved_requests': approved,
        'completed_requests': completed,
        'rejected_requests': rejected,
        'completion_rate':
            total > 0 ? (completed / total * 100).toStringAsFixed(1) : '0.0',
      };
    } catch (e) {
      print('DEBUG: getWarehouseTransferStatistics error: $e');
      rethrow;
    }
  }

  // Add to lib/services/supabase_service.dart
  static Future<Map<String, String>> getUsersByIds(List<String> userIds) async {
    try {
      if (userIds.isEmpty) return {};

      final response = await _client
          .from('users')
          .select('id, username')
          .inFilter('id', userIds);

      final Map<String, String> result = {};
      for (final user in response) {
        result[user['id'] as String] = user['username'] as String;
      }

      return result;
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }

  // lib/services/supabase_service.dart

  /// Restore session from local database (mobile only) - UPDATED
  static Future<void> _restoreOfflineSession() async {
    try {
      // NEW: Check persistent login state first
      final isLoggedIn = await _localDb.isUserLoggedIn();
      if (!isLoggedIn) {
        print('⚠️ User not logged in - skipping session restore');
        return;
      }

      // Get saved user info
      final savedUser = await _localDb.getSavedUserInfo();
      if (savedUser == null) {
        print('⚠️ No saved user info found');
        await _localDb.clearLoginState();
        return;
      }

      // Set current user from saved info
      _currentAppUser = savedUser;
      print('✓ Persistent login restored for: ${savedUser.username}');

      // Try to restore full session if available
      final isValid = await _localDb.isSessionValid();
      if (isValid) {
        final sessionData = await _localDb.getUserSession();
        if (sessionData != null) {
          // Verify device binding
          final storedDeviceId = sessionData['device_id'] as String;
          final currentDeviceId = await _deviceInfo.getDeviceId();

          if (storedDeviceId != currentDeviceId) {
            print(
                '⚠️ Device mismatch - clearing session but keeping login state');
            await _localDb.clearUserSession();
            // Don't clear login state - user stays logged in
          } else {
            print('✓ Full offline session restored');
          }
        }
      }
    } catch (e) {
      print('Error restoring offline session: $e');
      // Don't clear login state on error - user stays logged in
    }
  }

  static Future<void> createUser({
    required String username,
    required String email,
    required String password,
    required String salesman,
    String? area,
    String? userType,
    String? periodicAreaAssignment,
    bool canSeeAllQualityForms = false,
    String? positionId,
  }) async {
    try {
      String finalSalesman = salesman;
      String? finalArea = area;
      String? finalPeriodicAreaAssignment = periodicAreaAssignment;

      if (userType == 'quality_controller') {
        if (finalSalesman.isEmpty) finalSalesman = '000';
        finalArea = null;
        finalPeriodicAreaAssignment = null;
      } else if (userType == 'quality_control_admin') {
        if (finalSalesman.isEmpty) finalSalesman = '000';
        finalArea = null;
        finalPeriodicAreaAssignment = null;
      } else if (userType == 'quality_control_inspector') {
        finalSalesman = salesman;
        finalArea = null;
        finalPeriodicAreaAssignment = null;
      } else if (userType == 'user' && salesman == '00') {
        finalPeriodicAreaAssignment = periodicAreaAssignment ?? 'all';
      }

      // Use Admin REST API — does NOT affect current session
      final adminApiResponse = await http.post(
        Uri.parse('${AppConstants.supabaseUrl}/auth/v1/admin/users'),
        headers: {
          'Authorization': 'Bearer ${AppConstants.supabaseServiceRoleKey}',
          'apikey': AppConstants.supabaseServiceRoleKey,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
          'password': password,
          'email_confirm': true,
          'user_metadata': {
            'username': username,
            'salesman': finalSalesman,
            'area': finalArea,
            'user_type': userType ?? 'user',
            'periodic_area_assignment': finalPeriodicAreaAssignment,
          },
        }),
      );

      if (adminApiResponse.statusCode != 200 &&
          adminApiResponse.statusCode != 201) {
        throw Exception(
            'Failed to create auth user: ${adminApiResponse.statusCode} ${adminApiResponse.body}');
      }

      final responseBody = json.decode(adminApiResponse.body);
      final newUserId = responseBody['id'] as String;

      final upsertData = <String, dynamic>{
        'id': newUserId,
        'username': username,
        'area': finalArea,
        'salesman': finalSalesman,
        'email': email,
        'user_type': userType ?? 'user',
        'periodic_area_assignment': finalPeriodicAreaAssignment,
        'is_active': false,
      };

      if (userType == 'quality_control_admin') {
        upsertData['can_see_all_quality_forms'] = canSeeAllQualityForms;
      }
      if (positionId != null && positionId.isNotEmpty) {
        upsertData['position_id'] = positionId;
      }

      await _client.from('users').upsert(upsertData);
    } catch (e) {
      print('createUser error: $e');
      rethrow;
    }
  }

// Update updateUser method
  static Future<void> updateUser({
    required String userId,
    String? username,
    String? area,
    String? salesman,
    String? email,
    String? userType,
    String? periodicAreaAssignment,
    bool? isActive,
    bool? canSeeAllQualityForms,
    String? positionId,
    bool clearPosition = false,
  }) async {
    try {
      final Map<String, dynamic> updates = {};

      if (username != null) updates['username'] = username;
      if (email != null) updates['email'] = email;
      if (isActive != null) updates['is_active'] = isActive;
      if (userType != null) updates['user_type'] = userType;
      // Only write can_see_all_quality_forms for quality_control_admin type
      if (canSeeAllQualityForms != null &&
          (userType == 'quality_control_admin')) {
        updates['can_see_all_quality_forms'] = canSeeAllQualityForms;
      }

      if (userType == 'quality_controller') {
        updates['area'] = null;
        updates['periodic_area_assignment'] = null;
        updates['salesman'] = (salesman != null && salesman.isNotEmpty) ? salesman : '000';
      } else if (userType == 'quality_control_admin') {
        updates['area'] = null;
        updates['periodic_area_assignment'] = null;
        updates['salesman'] = (salesman != null && salesman.isNotEmpty) ? salesman : '000';
      } else if (userType == 'quality_control_inspector') {
        if (salesman != null) updates['salesman'] = salesman;
        updates['area'] = null;
        updates['periodic_area_assignment'] = null;
      } else {
        if (salesman != null) updates['salesman'] = salesman;
        updates['area'] = area;

        // Only update periodic_area_assignment for sales admins
        if (salesman == '00' && periodicAreaAssignment != null) {
          updates['periodic_area_assignment'] = periodicAreaAssignment;
        }
      }

      if (clearPosition) {
        updates['position_id'] = null;
      } else if (positionId != null && positionId.isNotEmpty) {
        updates['position_id'] = positionId;
      }

      if (updates.isNotEmpty) {
        await _client.from('users').update(updates).eq('id', userId);
      }
    } catch (e) {
      print('updateUser error: $e');
      rethrow;
    }
  }

  // Updated signUp method to handle quality_controller
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
    required String salesman,
    String? area,
    String? userType,
  }) async {
    try {
      // Auto-set salesman to '000' for quality controllers
      String finalSalesman = salesman;
      String? finalArea = area;
      if (userType == 'quality_controller') {
        finalSalesman = '000';
        finalArea = null;
      }

      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'salesman': finalSalesman,
          'area': finalArea,
          'user_type': userType ?? 'user',
        },
      );

      if (response.user != null) {
        await Future.delayed(const Duration(milliseconds: 500));

        try {
          await _client.from('users').update({
            'username': username,
            'area': finalArea,
            'salesman': finalSalesman,
            'email': email,
            'user_type': userType ?? 'user',
            'is_active': false,
          }).eq('id', response.user!.id);
        } catch (e) {
          try {
            await _client.from('users').insert({
              'id': response.user!.id,
              'username': username,
              'area': finalArea,
              'salesman': finalSalesman,
              'email': email,
              'user_type': userType ?? 'user',
              'is_active': false,
            });
          } catch (insertError) {
            print('Failed to create user profile: $insertError');
          }
        }
      }

      return response;
    } catch (e) {
      print('SignUp error: $e');
      rethrow;
    }
  }

  static Future<void> deleteUser(String userId) async {
    try {
      await _client.from('users').delete().eq('id', userId);
      final response = await http.delete(
        Uri.parse('${AppConstants.supabaseUrl}/auth/v1/admin/users/$userId'),
        headers: {
          'Authorization': 'Bearer ${AppConstants.supabaseServiceRoleKey}',
          'apikey': AppConstants.supabaseServiceRoleKey,
        },
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
            'Failed to delete auth user: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('deleteUser error: $e');
      rethrow;
    }
  }

  static Future<void> changeUserPassword(
      String userId, String newPassword) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConstants.supabaseUrl}/auth/v1/admin/users/$userId'),
        headers: {
          'Authorization': 'Bearer ${AppConstants.supabaseServiceRoleKey}',
          'apikey': AppConstants.supabaseServiceRoleKey,
          'Content-Type': 'application/json',
        },
        body: json.encode({'password': newPassword}),
      );
      if (response.statusCode != 200) {
        throw Exception(
            'Failed to update password: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('changeUserPassword error: $e');
      rethrow;
    }
  }

  /// Get all brands from Supabase
  static Future<List<Brand>> getBrands({bool? isActive}) async {
    try {
      var query = _client.from('brands').select();

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      final response = await query.order('name', ascending: true);

      return response.map<Brand>((json) => Brand.fromJson(json)).toList();
    } catch (e) {
      print('getBrands error: $e');
      rethrow;
    }
  }

  /// Sync brands from Bisan (upsert - update existing, add new)
  static Future<void> syncBrands(List<Brand> brands) async {
    try {
      print('DEBUG: Starting brands sync with ${brands.length} brands');

      const batchSize = 100;
      int successCount = 0;
      int errorCount = 0;

      for (int i = 0; i < brands.length; i += batchSize) {
        final batch = brands.skip(i).take(batchSize).map((brand) {
          return brand.toJson();
        }).toList();

        try {
          await _client.from('brands').upsert(
                batch,
                onConflict: 'code',
              );
          successCount += batch.length;
          print(
              'DEBUG: Synced batch ${(i ~/ batchSize) + 1}, brands: ${batch.length}');
        } catch (e) {
          errorCount += batch.length;
          print('DEBUG: Error syncing batch ${(i ~/ batchSize) + 1}: $e');
        }
      }

      print(
          'DEBUG: Brands sync completed - Success: $successCount, Errors: $errorCount');
    } catch (e) {
      print('syncBrands error: $e');
      rethrow;
    }
  }

  /// Update brand active status
  static Future<void> updateBrandStatus(int brandId, bool isActive) async {
    try {
      await _client.from('brands').update({
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', brandId);
    } catch (e) {
      print('updateBrandStatus error: $e');
      rethrow;
    }
  }

  /// Delete brand
  static Future<void> deleteBrand(int brandId) async {
    try {
      await _client.from('brands').delete().eq('id', brandId);
    } catch (e) {
      print('deleteBrand error: $e');
      rethrow;
    }
  }

  // ==================== SALARY TARGETS MANAGEMENT ====================

  /// Get salary targets for a user and month
  static Future<List<SalaryTarget>> getSalaryTargets({
    required String userId,
    required DateTime targetMonth,
  }) async {
    try {
      final monthStr =
          '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}-01';

      final response = await _client
          .from('salary_targets')
          .select()
          .eq('user_id', userId)
          .eq('target_month', monthStr)
          .order('brand_code', ascending: true);

      return response
          .map<SalaryTarget>((json) => SalaryTarget.fromJson(json))
          .toList();
    } catch (e) {
      print('getSalaryTargets error: $e');
      rethrow;
    }
  }

  /// Delete salary target
  static Future<void> deleteSalaryTarget({
    required String userId,
    required DateTime targetMonth,
    required String brandCode,
  }) async {
    try {
      final monthStr =
          '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}-01';

      await _client
          .from('salary_targets')
          .delete()
          .eq('user_id', userId)
          .eq('target_month', monthStr)
          .eq('brand_code', brandCode);
    } catch (e) {
      print('deleteSalaryTarget error: $e');
      rethrow;
    }
  }

  /// Save salary adjustment
  static Future<void> saveSalaryAdjustment(SalaryAdjustment adjustment) async {
    try {
      await _client.from('salary_adjustments').upsert(
            adjustment.toJson(),
            onConflict: 'user_id,target_month,brand_code,created_by',
          );
    } catch (e) {
      print('saveSalaryAdjustment error: $e');
      rethrow;
    }
  }

  /// Delete salary adjustment
  static Future<void> deleteSalaryAdjustment(int adjustmentId) async {
    try {
      await _client.from('salary_adjustments').delete().eq('id', adjustmentId);
    } catch (e) {
      print('deleteSalaryAdjustment error: $e');
      rethrow;
    }
  }

  /// Update user initial salary
  static Future<void> updateUserInitialSalary({
    required String userId,
    required double initialSalary,
  }) async {
    try {
      await _client.from('users').update({
        'initial_salary': initialSalary,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      print('updateUserInitialSalary error: $e');
      rethrow;
    }
  }

  /// Update user sales_admin field
  static Future<void> updateUserSalesAdmin({
    required String userId,
    required String? salesAdmin,
  }) async {
    try {
      await _client.from('users').update({
        'sales_admin': salesAdmin,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      print('updateUserSalesAdmin error: $e');
      rethrow;
    }
  }

  static Future<void> saveSalesAdminGroups(List<GroupData> groups) async {
    try {
      final client = Supabase.instance.client;

      for (final group in groups) {
        // Check if group already exists
        final existing = await client
            .from('sales_admin_groups')
            .select()
            .eq('sales_admin_code', group.salesAdminCode)
            .eq('salesman_code', group.salesmanCode)
            .maybeSingle();

        if (existing == null) {
          // Insert new group
          await client.from('sales_admin_groups').insert({
            'sales_admin_code': group.salesAdminCode,
            'salesman_code': group.salesmanCode,
          });
          print(
              'DEBUG: Added salesman ${group.salesmanCode} to sales admin ${group.salesAdminCode} group');
        } else {
          print(
              'DEBUG: Group relationship already exists: ${group.salesAdminCode} - ${group.salesmanCode}');
        }
      }
    } catch (e) {
      print('DEBUG: saveSalesAdminGroups error: $e');
      rethrow;
    }
  }

  /// Get salesmen in sales admin's group
  static Future<List<String>> getSalesmenInAdminGroup(
      String salesAdminCode) async {
    try {
      final client = Supabase.instance.client;

      final response = await client
          .from('sales_admin_groups')
          .select('salesman_code')
          .eq('sales_admin_code', salesAdminCode);

      return (response as List)
          .map((row) => row['salesman_code'] as String)
          .toList();
    } catch (e) {
      print('DEBUG: getSalesmenInAdminGroup error: $e');
      rethrow;
    }
  }

  /// Update user's initial salary
  static Future<void> updateUserSalary(String userId, double salary) async {
    try {
      final client = Supabase.instance.client;

      await client.from('users').update({
        'initial_salary': salary,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', userId);

      print('DEBUG: Updated salary for user $userId to $salary');
    } catch (e) {
      print('DEBUG: updateUserSalary error: $e');
      rethrow;
    }
  }

  /// Get salary targets for a specific user and month
  static Future<List<SalaryTarget>> getSalaryTargetsForUser({
    required String userId,
    required DateTime targetMonth,
  }) async {
    try {
      final client = Supabase.instance.client;

      final response = await client
          .from('salary_targets')
          .select()
          .eq('user_id', userId)
          .eq('target_month',
              '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}-01')
          .order('brand_code');

      return (response as List)
          .map((json) => SalaryTarget.fromJson(json))
          .toList();
    } catch (e) {
      print('DEBUG: getSalaryTargetsForUser error: $e');
      rethrow;
    }
  }

  /// Save salary targets (replaces existing targets for the user and month)
  static Future<void> saveSalaryTargets(List<SalaryTarget> targets) async {
    try {
      if (targets.isEmpty) return;

      final client = Supabase.instance.client;
      final userId = targets.first.userId;
      final targetMonth = targets.first.targetMonth;

      // Delete existing targets for this user and month
      await client.from('salary_targets').delete().eq('user_id', userId).eq(
          'target_month',
          '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}-01');

      // Insert new targets
      final targetsJson = targets.map((target) => target.toJson()).toList();
      await client.from('salary_targets').insert(targetsJson);

      print('DEBUG: Saved ${targets.length} targets for user $userId');
    } catch (e) {
      print('DEBUG: saveSalaryTargets error: $e');
      rethrow;
    }
  }

  /// Get salary targets for multiple users
  static Future<Map<String, List<SalaryTarget>>> getSalaryTargetsForUsers({
    required List<String> userIds,
    required DateTime targetMonth,
  }) async {
    try {
      final client = Supabase.instance.client;

      final response = await client
          .from('salary_targets')
          .select()
          .inFilter('user_id', userIds)
          .eq('target_month',
              '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}-01')
          .order('user_id')
          .order('brand_code');

      // Group by user_id
      final Map<String, List<SalaryTarget>> targetsMap = {};
      for (final json in response as List) {
        final target = SalaryTarget.fromJson(json);
        if (!targetsMap.containsKey(target.userId)) {
          targetsMap[target.userId] = [];
        }
        targetsMap[target.userId]!.add(target);
      }

      return targetsMap;
    } catch (e) {
      print('DEBUG: getSalaryTargetsForUsers error: $e');
      rethrow;
    }
  }

  /// Get salary adjustments for a user
  static Future<List<SalaryAdjustment>> getSalaryAdjustments({
    required String userId,
    required DateTime targetMonth,
  }) async {
    try {
      final client = Supabase.instance.client;

      final response = await client
          .from('salary_adjustments')
          .select()
          .eq('user_id', userId)
          .eq('target_month',
              '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}-01')
          .order('brand_code');

      return (response as List)
          .map((json) => SalaryAdjustment.fromJson(json))
          .toList();
    } catch (e) {
      print('DEBUG: getSalaryAdjustments error: $e');
      return []; // Return empty list on error
    }
  }

  /// Save salary adjustments
  static Future<void> saveSalaryAdjustments(
      List<SalaryAdjustment> adjustments) async {
    try {
      if (adjustments.isEmpty) return;

      final client = Supabase.instance.client;
      final userId = adjustments.first.userId;
      final targetMonth = adjustments.first.targetMonth;

      // Delete existing adjustments for this user and month
      await client.from('salary_adjustments').delete().eq('user_id', userId).eq(
          'target_month',
          '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}-01');

      // Insert new adjustments (only if there are non-zero values)
      final nonZeroAdjustments = adjustments
          .where((adj) => adj.plusAmount > 0 || adj.minusAmount > 0)
          .toList();

      if (nonZeroAdjustments.isNotEmpty) {
        final adjustmentsJson =
            nonZeroAdjustments.map((adj) => adj.toJson()).toList();
        await client.from('salary_adjustments').insert(adjustmentsJson);
        print(
            'DEBUG: Saved ${nonZeroAdjustments.length} adjustments for user $userId');
      }
    } catch (e) {
      print('DEBUG: saveSalaryAdjustments error: $e');
      rethrow;
    }
  }

  /// Bulk save or update salary targets
  static Future<void> bulkSaveOrUpdateTargets({
    required String userId,
    required DateTime targetMonth,
    required List<TargetData> targetData,
    required String createdBy,
  }) async {
    try {
      final client = Supabase.instance.client;

      // Delete existing targets for this user and month
      await client.from('salary_targets').delete().eq('user_id', userId).eq(
          'target_month',
          '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}-01');

      // Insert new targets
      final targets = targetData.map((target) {
        return {
          'user_id': userId,
          'target_month':
              '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}-01',
          'brand_code': target.brandCode,
          'target_amount': target.targetAmount,
          'created_by': createdBy,
        };
      }).toList();

      if (targets.isNotEmpty) {
        await client.from('salary_targets').insert(targets);
        print('DEBUG: Inserted ${targets.length} targets for user $userId');
      }
    } catch (e) {
      print('DEBUG: bulkSaveOrUpdateTargets error: $e');
      rethrow;
    }
  }

  // UPDATED: Get user contacts - now includes additional contacts
  static Future<List<Contact>> getUserContacts({
    required String salesman,
    String? area,
    String? search,
    List<String>? additionalContactCodes,
  }) async {
    try {
      print(
          'DEBUG: getUserContacts called with salesman: "$salesman", area: "$area"');
      print('DEBUG: Additional contact codes: $additionalContactCodes');

      bool isAdminUser = salesman == '00';

      if (isAdminUser) {
        print('DEBUG: Admin user - using pagination to get all contacts');
        return await _getAllContactsWithPagination(search: search);
      } else {
        print('DEBUG: Regular user - applying filters');
        return await _getFilteredContactsWithAdditional(
          salesman: salesman,
          area: area,
          search: search,
          additionalContactCodes: additionalContactCodes,
        );
      }
    } catch (e) {
      print('getUserContacts error: $e');
      rethrow;
    }
  }
// lib/services/supabase_service.dart

// REPLACE the _getFilteredContactsWithAdditional method:
  static Future<List<Contact>> _getFilteredContactsWithAdditional({
    required String salesman,
    String? area,
    String? search,
    List<String>? additionalContactCodes,
  }) async {
    print('🔍 _getFilteredContactsWithAdditional called');
    print('   Salesman: $salesman');
    print('   Area: $area');
    print('   Additional contact codes: $additionalContactCodes');

    try {
      List<Contact> allContacts = [];

      // First, get contacts by salesman
      var salesmanQuery = _client.from('contacts').select();
      salesmanQuery = salesmanQuery.eq('salesman', salesman);

      if (area != null && area.isNotEmpty && area != '00') {
        salesmanQuery = salesmanQuery.eq('area', area);
        print('   Applied area filter: $area');
      }

      if (search != null && search.isNotEmpty) {
        salesmanQuery =
            salesmanQuery.or('name_ar.ilike.%$search%,code.ilike.%$search%');
      }

      // Load contacts by salesman
      int pageSize = 1000;
      int page = 0;
      bool hasMore = true;

      while (hasMore) {
        final response = await salesmanQuery
            .range(page * pageSize, (page + 1) * pageSize - 1)
            .order('name_ar', ascending: true);

        final pageContacts =
            response.map<Contact>((json) => Contact.fromJson(json)).toList();
        allContacts.addAll(pageContacts);

        print(
            '   Loaded ${pageContacts.length} contacts by salesman (page ${page + 1})');

        hasMore = pageContacts.length == pageSize;
        page++;

        if (page > 10) break;
      }

      print('   Total contacts by salesman: ${allContacts.length}');

      // Now, get additional contacts if any
      if (additionalContactCodes != null && additionalContactCodes.isNotEmpty) {
        print(
            '   Loading ${additionalContactCodes.length} additional contacts...');

        // Load additional contacts in batches
        const batchSize = 100;
        for (int i = 0; i < additionalContactCodes.length; i += batchSize) {
          final batch = additionalContactCodes.skip(i).take(batchSize).toList();

          var additionalQuery = _client.from('contacts').select();
          additionalQuery = additionalQuery.inFilter('code', batch);

          if (search != null && search.isNotEmpty) {
            additionalQuery = additionalQuery
                .or('name_ar.ilike.%$search%,code.ilike.%$search%');
          }

          final additionalResponse =
              await additionalQuery.order('name_ar', ascending: true);

          final additionalContacts = additionalResponse
              .map<Contact>((json) => Contact.fromJson(json))
              .toList();

          // Add only contacts that are not already in the list (avoid duplicates)
          for (final contact in additionalContacts) {
            if (!allContacts.any((c) => c.code == contact.code)) {
              allContacts.add(contact);
            }
          }

          print(
              '   Loaded ${additionalContacts.length} additional contacts in batch ${(i ~/ batchSize) + 1}');
        }
      }

      print('   Total contacts (including additional): ${allContacts.length}');

      // Sort all contacts by name
      allContacts.sort((a, b) => a.nameAr.compareTo(b.nameAr));

      return allContacts;
    } catch (e) {
      print('❌ Error in _getFilteredContactsWithAdditional: $e');
      rethrow;
    }
  }

  // NEW: Get contacts that user cannot see by default (for assignment dialog)
  static Future<List<Contact>> getContactsNotVisibleToUser({
    required String userSalesman,
    String? userArea,
    String? search,
  }) async {
    try {
      var query = _client.from('contacts').select();

      // Get contacts where salesman is NOT the user's salesman
      query = query.neq('salesman', userSalesman);

      if (search != null && search.isNotEmpty) {
        query = query.or('name_ar.ilike.%$search%,code.ilike.%$search%');
      }

      List<Contact> allContacts = [];
      int pageSize = 1000;
      int page = 0;
      bool hasMore = true;

      while (hasMore) {
        final response = await query
            .range(page * pageSize, (page + 1) * pageSize - 1)
            .order('name_ar', ascending: true);

        final pageContacts =
            response.map<Contact>((json) => Contact.fromJson(json)).toList();
        allContacts.addAll(pageContacts);

        hasMore = pageContacts.length == pageSize;
        page++;

        if (page > 10) break;
      }

      return allContacts;
    } catch (e) {
      print('getContactsNotVisibleToUser error: $e');
      rethrow;
    }
  }

  static Future<List<Contact>> _getAllContactsWithPagination(
      {String? search}) async {
    List<Contact> allContacts = [];
    int pageSize = 1000;
    int page = 0;
    bool hasMore = true;

    print('DEBUG: Starting pagination to load all contacts...');

    while (hasMore) {
      try {
        var query = _client.from('contacts').select();

        if (search != null && search.isNotEmpty) {
          query = query.or('name_ar.ilike.%$search%,code.ilike.%$search%');
        }

        final response = await query
            .range(page * pageSize, (page + 1) * pageSize - 1)
            .order('name_ar', ascending: true);

        final pageContacts =
            response.map<Contact>((json) => Contact.fromJson(json)).toList();
        allContacts.addAll(pageContacts);

        print(
            'DEBUG: Page ${page + 1}: loaded ${pageContacts.length} contacts (total: ${allContacts.length})');

        hasMore = pageContacts.length == pageSize;
        page++;

        if (page > 50) {
          print('DEBUG: Reached maximum page limit (50 pages)');
          break;
        }
      } catch (e) {
        print('DEBUG: Error loading page $page: $e');
        break;
      }
    }

    print(
        'DEBUG: Pagination complete. Total contacts loaded: ${allContacts.length}');
    return allContacts;
  }

  static Future<List<Contact>> _getFilteredContacts({
    required String salesman,
    String? area,
    String? search,
  }) async {
    var query = _client.from('contacts').select();

    query = query.eq('salesman', salesman);

    if (area != null && area.isNotEmpty && area != '00') {
      query = query.eq('area', area);
      print('DEBUG: Applied area filter: $area');
    }

    if (search != null && search.isNotEmpty) {
      query = query.or('name_ar.ilike.%$search%,code.ilike.%$search%');
    }

    List<Contact> allContacts = [];
    int pageSize = 1000;
    int page = 0;
    bool hasMore = true;

    while (hasMore) {
      final response = await query
          .range(page * pageSize, (page + 1) * pageSize - 1)
          .order('name_ar', ascending: true);

      final pageContacts =
          response.map<Contact>((json) => Contact.fromJson(json)).toList();
      allContacts.addAll(pageContacts);

      print(
          'DEBUG: Regular user page ${page + 1}: loaded ${pageContacts.length} contacts');

      hasMore = pageContacts.length == pageSize;
      page++;

      if (page > 10) break;
    }

    return allContacts;
  }

  static Future<List<Contact>> getContacts({String? search}) async {
    try {
      print('DEBUG: getContacts called with search: "$search"');
      return await _getAllContactsWithPagination(search: search);
    } catch (e) {
      print('getContacts error: $e');
      rethrow;
    }
  }

  static Future<int> getTotalContactsCount() async {
    try {
      final response = await _client.rpc('get_contacts_count').select();
      return response[0]['count'] as int;
    } catch (e) {
      print('Error getting contacts count: $e');
      return 0;
    }
  }

  static Future<void> syncContacts(List<Contact> contacts) async {
    try {
      await _client.from('contacts').delete().neq('id', 0);

      const batchSize = 100;
      for (int i = 0; i < contacts.length; i += batchSize) {
        final batch = contacts.skip(i).take(batchSize).map((contact) {
          final json = contact.toJson();
          json.remove('id');

          json['code'] = json['code'] ?? '';
          json['name_ar'] = json['name_ar'] ?? '';

          return json;
        }).toList();

        await _client.from('contacts').insert(batch);
      }
    } catch (e) {
      print('syncContacts error: $e');
      rethrow;
    }
  }

  static Future<Contact?> getContactByCode(String code) async {
    try {
      final response = await _client
          .from('contacts')
          .select()
          .eq('code', code)
          .maybeSingle();

      return response != null ? Contact.fromJson(response) : null;
    } catch (e) {
      print('getContactByCode error: $e');
      return null;
    }
  }

  // QUALITY CONTROL METHODS

// Quality Checklists
  static Future<List<QualityChecklist>> getQualityChecklists(
      {bool? isActive}) async {
    try {
      var query = _client.from('quality_checklists').select();

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      final response = await query.order('created_at', ascending: false);

      return response
          .map<QualityChecklist>((json) => QualityChecklist.fromJson(json))
          .toList();
    } catch (e) {
      print('getQualityChecklists error: $e');
      rethrow;
    }
  }

  static Future<QualityChecklist> createQualityChecklist({
    required String title,
    String? description,
    required List<Determinant> determinants,
    required int rateNumber,
    required List<CheckPoint> checkPoints,
  }) async {
    try {
      // Get current authenticated user
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      print('Creating checklist with user ID: ${currentUser.id}');

      final response = await _client
          .from('quality_checklists')
          .insert({
            'title': title,
            'description': description,
            'determinants': determinants.map((d) => d.toJson()).toList(),
            'rate_number': rateNumber,
            'check_points': checkPoints.map((cp) => cp.toJson()).toList(),
            'created_by': currentUser.id,
            'is_active': true,
          })
          .select()
          .single();

      return QualityChecklist.fromJson(response);
    } catch (e) {
      print('createQualityChecklist error: $e');
      rethrow;
    }
  }

  static Future<QualityChecklist> updateQualityChecklist({
    required int id,
    String? title,
    String? description,
    List<Determinant>? determinants,
    int? rateNumber,
    List<CheckPoint>? checkPoints,
    bool? isActive,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (determinants != null)
        updates['determinants'] = determinants.map((d) => d.toJson()).toList();
      if (rateNumber != null) updates['rate_number'] = rateNumber;
      if (checkPoints != null)
        updates['check_points'] = checkPoints.map((cp) => cp.toJson()).toList();
      if (isActive != null) updates['is_active'] = isActive;

      final response = await _client
          .from('quality_checklists')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return QualityChecklist.fromJson(response);
    } catch (e) {
      print('updateQualityChecklist error: $e');
      rethrow;
    }
  }

  static Future<void> deleteQualityChecklist(int id) async {
    try {
      await _client.from('quality_checklists').delete().eq('id', id);
    } catch (e) {
      print('deleteQualityChecklist error: $e');
      rethrow;
    }
  }

// Updated Quality Sessions
  static Future<QualitySession?> getActiveSession({
    required int groupId,
    required String userId,
    int? checklistId,
  }) async {
    try {
      var query = _client
          .from('quality_sessions')
          .select()
          .eq('group_id', groupId)
          .eq('user_id', userId)
          .eq('is_active', true);

      if (checklistId != null) {
        query = query.eq('checklist_id', checklistId);
      }

      final response = await query.maybeSingle();

      return response != null ? QualitySession.fromJson(response) : null;
    } catch (e) {
      print('getActiveSession error: $e');
      return null;
    }
  }

  static Future<QualitySession> createSession({
    required int groupId,
    required String userId,
    int? checklistId,
    Map<String, dynamic>? sessionData,
  }) async {
    try {
      final response = await _client
          .from('quality_sessions')
          .insert({
            'group_id': groupId,
            'checklist_id': checklistId,
            'user_id': userId,
            'session_data': sessionData ?? {},
            'is_active': true,
            'started_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return QualitySession.fromJson(response);
    } catch (e) {
      print('createSession error: $e');
      rethrow;
    }
  }

  static Future<QualitySession> updateSession({
    required int sessionId,
    Map<String, dynamic>? sessionData,
    bool? isActive,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (sessionData != null) updates['session_data'] = sessionData;
      if (isActive != null) {
        updates['is_active'] = isActive;
        if (!isActive) {
          updates['ended_at'] = DateTime.now().toIso8601String();
        }
      }

      final response = await _client
          .from('quality_sessions')
          .update(updates)
          .eq('id', sessionId)
          .select()
          .single();

      return QualitySession.fromJson(response);
    } catch (e) {
      print('updateSession error: $e');
      rethrow;
    }
  }

// Updated getQualityResponses to include checkpoint images
  static Future<List<QualityResponse>> getQualityResponses({
    int? groupId,
    int? checklistId,
    String? userId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      debugPrint('[QualityResponses] Loading: groupId=$groupId, checklistId=$checklistId, userId=$userId, from=${fromDate?.toIso8601String().split('T')[0]}, to=${toDate?.toIso8601String().split('T')[0]}');
      debugPrint('[QualityResponses] Current auth user: ${_client.auth.currentUser?.id}');

      var query = _client.from('quality_responses').select('''
        *,
        images:quality_images(*),
        checkpoint_images:quality_checkpoint_images(*)
      ''');

      if (groupId != null) {
        query = query.eq('group_id', groupId);
      }

      if (checklistId != null) {
        query = query.eq('checklist_id', checklistId);
      }

      if (userId != null) {
        query = query.eq('user_id', userId);
      }

      if (fromDate != null) {
        query = query.gte(
            'response_date', fromDate.toIso8601String().split('T')[0]);
      }

      if (toDate != null) {
        query =
            query.lte('response_date', toDate.toIso8601String().split('T')[0]);
      }

      final response = await query.order('response_date', ascending: false);

      debugPrint('[QualityResponses] Raw rows returned: ${response.length}');

      final parsed = response
          .map<QualityResponse>((json) {
            try {
              return QualityResponse.fromJson(json);
            } catch (parseErr) {
              debugPrint('[QualityResponses] Parse error for row id=${json['id']}: $parseErr');
              rethrow;
            }
          })
          .toList();

      debugPrint('[QualityResponses] Successfully parsed ${parsed.length} responses');
      return parsed;
    } catch (e, stack) {
      debugPrint('[QualityResponses] ERROR: $e');
      debugPrint('[QualityResponses] STACK: $stack');
      rethrow;
    }
  }

  // Updated submitQualityResponse to handle checkpoint images
  static Future<QualityResponse> submitQualityResponse({
    required int groupId,
    required int checklistId,
    required String userId,
    int? sessionId,
    required DateTime responseDate,
    required Map<String, dynamic> determinantValues,
    required Map<String, dynamic> checkPointRatings,
    List<File>? images, // Legacy general images
    Map<String, List<File>>?
        checkpointImages, // New: checkpoint-specific images
  }) async {
    try {
      final response = await _client
          .from('quality_responses')
          .insert({
            'group_id': groupId,
            'checklist_id': checklistId,
            'user_id': userId,
            'session_id': sessionId,
            'response_date': responseDate.toIso8601String().split('T')[0],
            'determinant_values': determinantValues,
            'check_point_ratings': checkPointRatings,
            'submitted_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final qualityResponse = QualityResponse.fromJson({
        ...response,
        'images': [],
        'checkpoint_images': [],
      });

      // Upload legacy general images if provided
      if (images != null && images.isNotEmpty) {
        await uploadQualityImages(
          responseId: qualityResponse.id,
          images: images,
        );
      }

      // Upload checkpoint-specific images if provided
      if (checkpointImages != null && checkpointImages.isNotEmpty) {
        for (final entry in checkpointImages.entries) {
          final checkPointId = entry.key;
          final imageFiles = entry.value;

          if (imageFiles.isNotEmpty) {
            await uploadCheckpointImages(
              responseId: qualityResponse.id,
              checkPointId: checkPointId,
              images: imageFiles,
            );
          }
        }
      }

      // Fetch the complete response with all images
      final completeResponse = await getQualityResponseById(qualityResponse.id);
      return completeResponse ?? qualityResponse;
    } catch (e) {
      print('submitQualityResponse error: $e');
      rethrow;
    }
  }



// ═══════════════════════════════════════════════════════════════════════════
// ADD THESE METHODS TO YOUR EXISTING supabase_service.dart file
// Place them alongside the existing quality management methods
// ═══════════════════════════════════════════════════════════════════════════

// ─── EXISTING method to update — change getQualityChecklistGroups to also
//     have a "my groups only" variant. Add this NEW method: ───────────────


static Future<List<QualityChecklistGroup>> getMyQualityChecklistGroups(
    {bool? isActive}) async {
  try {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    // Get the current app user to check their permissions
    final appUser = _currentAppUser ?? await getUserById(currentUser.id);

    var query = _client
        .from('quality_checklist_groups')
        .select('*, checklists:quality_checklists(*)');

    // If user does NOT have can_see_all_quality_forms, restrict to their own groups only
    if (appUser.canSeeAllQualityForms != true) {
      query = query.eq('created_by', currentUser.id);
    }

    if (isActive != null) {
      query = query.eq('is_active', isActive);
    }

    final response = await query.order('created_at', ascending: false);

    return response
        .map<QualityChecklistGroup>(
            (json) => QualityChecklistGroup.fromJson(json))
        .toList();
  } catch (e) {
    print('getMyQualityChecklistGroups error: $e');
    rethrow;
  }
}
// ─── Assign users to a quality group ────────────────────────────────────────

  /// Replace all user assignments for a quality group.
  /// Deletes existing assignments and inserts the new list.
  /// [userEditPermissions] maps userId -> canEditSubmissions flag.
  static Future<void> assignUsersToQualityGroup({
    required int groupId,
    required List<String> userIds,
    Map<String, bool>? userEditPermissions,
  }) async {
    try {
      await _client
          .from('quality_group_assignments')
          .delete()
          .eq('group_id', groupId);

      if (userIds.isNotEmpty) {
        final currentUser = _client.auth.currentUser;
        await _client.from('quality_group_assignments').insert(
          userIds
              .map((uid) => {
                    'group_id': groupId,
                    'user_id': uid,
                    if (currentUser != null) 'assigned_by': currentUser.id,
                    'can_edit_submissions':
                        userEditPermissions?[uid] ?? false,
                  })
              .toList(),
        );
      }
    } catch (e) {
      print('assignUsersToQualityGroup error: $e');
      rethrow;
    }
  }

// ─── Get assigned user IDs + edit permissions for a group ────────────────────

  /// Returns a map of userId -> canEditSubmissions for a quality group.
static Future<Map<String, bool>> getGroupAssignedUserIds(int groupId) async {
  try {
    final response = await _client
        .from('quality_group_assignments')
        .select('user_id, can_edit_submissions')
        .eq('group_id', groupId);

    final result = <String, bool>{};
    for (final item in response as List) {
      final uid = item['user_id']?.toString() ?? '';
      if (uid.isNotEmpty) {
        result[uid] = item['can_edit_submissions'] as bool? ?? false;
      }
    }
    return result;
  } catch (e) {
    print('getGroupAssignedUserIds error: $e');
    return {};
  }
}
// ─── Get count of assigned users for a group (used by the card badge) ────────

  /// Returns the number of users assigned to a quality group.
  static Future<int> getGroupAssignedUsersCount(int groupId) async {
    try {
      final response = await _client
          .from('quality_group_assignments')
          .select('id')
          .eq('group_id', groupId);

      return (response as List).length;
    } catch (e) {
      print('getGroupAssignedUsersCount error: $e');
      return 0;
    }
  }


static Future<void> sendIssueAssignmentEmail({
  required String toEmail,
  required String assignedToUsername,
  required String assignedByUsername,
  required String checkPointTitle,
  required String formTitle,
  required String description,
  required DateTime responseDate,
}) async {
  try {
    final arabicMonths = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    final dateStr =
        '${responseDate.day} ${arabicMonths[responseDate.month - 1]} ${responseDate.year}';

    final subject = 'تم تعيين مشكلة جديدة إليك - $formTitle';

    final body = '''
<div dir="rtl" style="font-family: Arial, sans-serif; font-size: 14px; color: #1A1F36; background: #f5f6fa; padding: 24px;">
  <div style="max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 10px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.08);">
    
    <div style="background: linear-gradient(135deg, #6C63FF, #4E46E5); padding: 24px; text-align: center;">
      <h2 style="color: #ffffff; margin: 0; font-size: 20px;">🔔 مشكلة جديدة تم تعيينها إليك</h2>
    </div>

    <div style="padding: 24px;">
      <p style="font-size: 15px; color: #374151;">مرحباً <strong>${assignedToUsername}</strong>،</p>
      <p style="color: #6B7280;">تم تعيين مشكلة جديدة إليك في نظام مراقبة الجودة. يرجى مراجعة التفاصيل أدناه واتخاذ الإجراء اللازم.</p>

      <div style="background: #f9fafb; border-radius: 8px; border: 1px solid #e5e7eb; padding: 16px; margin: 16px 0;">
        <table style="width: 100%; border-collapse: collapse;">
          <tr>
            <td style="padding: 8px 0; color: #6B7280; font-size: 13px; width: 40%;">📋 النموذج:</td>
            <td style="padding: 8px 0; font-weight: bold; color: #111827;">${formTitle}</td>
          </tr>
          <tr>
            <td style="padding: 8px 0; color: #6B7280; font-size: 13px;">🔍 نقطة الفحص:</td>
            <td style="padding: 8px 0; font-weight: bold; color: #111827;">${checkPointTitle}</td>
          </tr>
          <tr>
            <td style="padding: 8px 0; color: #6B7280; font-size: 13px;">📅 تاريخ التقرير:</td>
            <td style="padding: 8px 0; font-weight: bold; color: #111827;">${dateStr}</td>
          </tr>
          <tr>
            <td style="padding: 8px 0; color: #6B7280; font-size: 13px;">👤 معين بواسطة:</td>
            <td style="padding: 8px 0; font-weight: bold; color: #111827;">${assignedByUsername}</td>
          </tr>
        </table>
      </div>

      <div style="background: #FEF3C7; border-right: 4px solid #F59E0B; border-radius: 6px; padding: 14px; margin: 16px 0;">
        <p style="margin: 0; color: #92400E; font-weight: bold; font-size: 13px;">⚠️ وصف المشكلة:</p>
        <p style="margin: 8px 0 0; color: #78350F; font-size: 14px;">${description}</p>
      </div>

      <p style="color: #6B7280; font-size: 12px; margin-top: 24px; border-top: 1px solid #e5e7eb; padding-top: 16px;">
        يرجى تسجيل الدخول إلى النظام لمعالجة هذه المشكلة وتحديث حالتها في أقرب وقت ممكن.
        <br><br>
        مع التحية،<br>
        <strong>نظام مراقبة الجودة</strong>
      </p>
    </div>
  </div>
</div>
''';

    final payload = {
      'to': toEmail,
      'subject': subject,
      'body': body,
      'attachments': <Map<String, dynamic>>[],
    };

    final response = await _client.functions.invoke(
      'send-email-proxy',
      body: payload,
    );

    // If Supabase Edge Function isn't available, call Power Automate directly
    // (handled in the form screen via http package)
    debugPrint('Email send result: ${response.status}');
  } catch (e) {
    debugPrint('sendIssueAssignmentEmail error: $e');
    // Don't rethrow — email failure should not block issue creation
  }
}
// ─── Get all quality controller users (for the assignment picker) ─────────────

  /// Returns all users with user_type = 'quality_controller'.
  static Future<List<AppUser>> getQualityControllerUsers() async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('user_type', 'quality_controller')
          .order('username', ascending: true);

      return response
          .map<AppUser>((json) => AppUser.fromJson(json))
          .toList();
    } catch (e) {
      print('getQualityControllerUsers error: $e');
      rethrow;
    }
  }



static Future<QualityChecklist?> getQualityChecklistById(int checklistId) async {
  final response = await _client
      .from('quality_checklists')
      .select()
      .eq('id', checklistId)
      .eq('is_active', true)
      .maybeSingle();
  if (response == null) return null;
  return QualityChecklist.fromJson(response);
}

 static Future<List<QualityChecklistGroup>>
      getAssignedQualityGroupsForUser() async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      print('🔍 Fetching assigned groups for auth uid: ${currentUser.id}');

      // Use RPC (SECURITY DEFINER) to bypass RLS and fetch directly
      final response = await _client.rpc(
        'get_assigned_groups_for_user',
        params: {'p_user_id': currentUser.id},
      );

      print('✅ Groups fetched via RPC: ${(response as List).length}');

      final groups = (response as List)
          .map<QualityChecklistGroup>(
              (json) => QualityChecklistGroup.fromJson(json))
          .toList();

      // Fetch can_edit_submissions for the current user's assignments.
      // Wrapped in try/catch so RLS errors degrade gracefully (defaults to false).
      try {
        final assignments = await _client
            .from('quality_group_assignments')
            .select('group_id, can_edit_submissions')
            .eq('user_id', currentUser.id);

        final editMap = <int, bool>{};
        for (final a in assignments as List) {
          final gid = a['group_id'];
          final id = gid is int ? gid : int.tryParse(gid.toString()) ?? 0;
          editMap[id] = a['can_edit_submissions'] as bool? ?? false;
        }

        return groups
            .map((g) =>
                g.copyWith(canEditSubmissions: editMap[g.id] ?? false))
            .toList();
      } catch (_) {
        return groups;
      }
    } catch (e) {
      print('❌ getAssignedQualityGroupsForUser error: $e');
      rethrow;
    }
  }

// ─── 48-hour history for a quality controller ─────────────────────────────────

  /// Returns the current user's quality responses submitted in the last 48 hours
  /// for [groupId], ordered newest first.
  static Future<List<QualityResponse>> getRecentQualityResponses(
      int groupId) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) return [];

      final cutoff = DateTime.now()
          .subtract(const Duration(hours: 48))
          .toUtc()
          .toIso8601String();

      final response = await _client
          .from('quality_responses')
          .select()
          .eq('user_id', currentUser.id)
          .eq('group_id', groupId)
          .gte('submitted_at', cutoff)
          .order('submitted_at', ascending: false)
          .limit(20);

      return (response as List)
          .map<QualityResponse>((json) => QualityResponse.fromJson(json))
          .toList();
    } catch (e) {
      print('getRecentQualityResponses error: $e');
      return [];
    }
  }

// ─── Update an existing quality response (edit mode) ─────────────────────────

  /// Updates ratings, notes, and determinant values of an existing response.
  /// The Supabase RLS policy enforces the 48-hour window and can_edit_submissions
  /// permission check server-side.
  static Future<void> updateQualityResponse({
    required int responseId,
    required Map<String, dynamic> checkPointRatings,
    required Map<String, String> determinantValues,
    String? mainNotes,
  }) async {
    try {
      await _client.from('quality_responses').update({
        'check_point_ratings': checkPointRatings,
        'determinant_values': determinantValues,
        'main_notes': mainNotes,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', responseId);
    } catch (e) {
      print('updateQualityResponse error: $e');
      rethrow;
    }
  }

  // Add these methods to your SupabaseService class

// ==================== QUALITY CHECKPOINT ISSUES MANAGEMENT ====================

static Future<QualityCheckpointIssue> createQualityCheckpointIssue({
  required int responseId,
  required String checkPointId,
  required String checkPointTitle,
  required String formTitle,
  required String assignedTo,
  required String description,
  required DateTime responseDate,
  List<Uint8List>? imageBytes,
  List<String>? imageNames,
  // ── NEW: determinant values from the session ──────────────────────────────
  Map<String, dynamic>? determinantValues,
  // ── NEW: determinant definitions for label lookup ─────────────────────────
  List<Map<String, dynamic>>? determinantDefinitions,
}) async {
  try {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    final response = await _client
        .from('quality_checkpoint_issues')
        .insert({
          'response_id': responseId,
          'check_point_id': checkPointId,
          'check_point_title': checkPointTitle,
          'form_title': formTitle,
          'assigned_to': assignedTo,
          'assigned_by': currentUser.id,
          'description': description,
          'response_date': responseDate.toIso8601String().split('T')[0],
          'status': IssueStatus.open.name,
        })
        .select()
        .single();

    final issue = QualityCheckpointIssue.fromJson({
      ...response,
      'issue_images': [],
      'resolution_images': [],
    });

    if (imageBytes != null && imageNames != null && imageBytes.isNotEmpty) {
      await uploadIssueImages(
        issueId: issue.id,
        imageBytes: imageBytes,
        imageNames: imageNames,
      );
    }

    // ── Send email notification ──────────────────────────────────────────────
    try {
      final assignedUserResponse = await _client
          .from('users')
          .select('email, username')
          .eq('id', assignedTo)
          .single();

      final assignedEmail = assignedUserResponse['email'] as String?;
      final assignedUsername =
          assignedUserResponse['username'] as String? ?? '—';

      final currentUserResponse = await _client
          .from('users')
          .select('username')
          .eq('id', currentUser.id)
          .single();
      final assignedByUsername =
          currentUserResponse['username'] as String? ?? '—';

      if (assignedEmail != null && assignedEmail.isNotEmpty) {
        await _sendIssueEmailViaPowerAutomate(
          toEmail: assignedEmail,
          assignedToUsername: assignedUsername,
          assignedByUsername: assignedByUsername,
          checkPointTitle: checkPointTitle,
          formTitle: formTitle,
          description: description,
          responseDate: responseDate,
          // ── NEW ──────────────────────────────────────────────────────────
          determinantValues: determinantValues,
          determinantDefinitions: determinantDefinitions,
        );
      }
    } catch (emailError) {
      debugPrint('Email notification error (non-fatal): $emailError');
    }

    final completeIssue = await getQualityCheckpointIssueById(issue.id);
    return completeIssue ?? issue;
  } catch (e) {
    print('createQualityCheckpointIssue error: $e');
    rethrow;
  }
}



// ═══════════════════════════════════════════════════════════════
// ADD THESE METHODS to your existing supabase_service.dart
// ═══════════════════════════════════════════════════════════════

// ─── Task Checklists (Admin CRUD) ────────────────────────────────────────────

  /// Get all task checklists (admin view)
  static Future<List<TaskChecklist>> getTaskChecklists({bool? isActive}) async {
    try {
      var query = _client.from('task_checklists').select();
      if (isActive != null) query = query.eq('is_active', isActive);
      final response = await query.order('created_at', ascending: false);
      return response
          .map<TaskChecklist>((j) => TaskChecklist.fromJson(j))
          .toList();
    } catch (e) {
      debugPrint('getTaskChecklists error: $e');
      rethrow;
    }
  }

  /// Create a task checklist
  static Future<TaskChecklist> createTaskChecklist({
    required String title,
    String? description,
    required List<TaskItem> tasks,
    required TaskChecklistFrequency frequency,
    List<int> scheduledDays = const [],
    String? scheduledTime,
    DateTime? onceDate,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final response = await _client
          .from('task_checklists')
          .insert({
            'title': title,
            'description': description,
            'tasks': tasks.map((t) => t.toJson()).toList(),
            'frequency': frequency.name,
            'scheduled_days': scheduledDays,
            'scheduled_time': scheduledTime,
            'once_date': onceDate?.toIso8601String().split('T')[0],
            'created_by': currentUser.id,
            'is_active': true,
          })
          .select()
          .single();

      return TaskChecklist.fromJson(response);
    } catch (e) {
      debugPrint('createTaskChecklist error: $e');
      rethrow;
    }
  }

  /// Update a task checklist
  static Future<TaskChecklist> updateTaskChecklist({
    required int id,
    String? title,
    String? description,
    List<TaskItem>? tasks,
    TaskChecklistFrequency? frequency,
    List<int>? scheduledDays,
    String? scheduledTime,
    DateTime? onceDate,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (tasks != null) updates['tasks'] = tasks.map((t) => t.toJson()).toList();
      if (frequency != null) updates['frequency'] = frequency.name;
      if (scheduledDays != null) updates['scheduled_days'] = scheduledDays;
      if (scheduledTime != null) updates['scheduled_time'] = scheduledTime;
      if (onceDate != null) updates['once_date'] = onceDate.toIso8601String().split('T')[0];
      if (isActive != null) updates['is_active'] = isActive;

      final response = await _client
          .from('task_checklists')
          .update(updates)
          .eq('id', id)
          .select()
          .single();
      return TaskChecklist.fromJson(response);
    } catch (e) {
      debugPrint('updateTaskChecklist error: $e');
      rethrow;
    }
  }

  /// Delete a task checklist
  static Future<void> deleteTaskChecklist(int id) async {
    try {
      await _client.from('task_checklists').delete().eq('id', id);
    } catch (e) {
      debugPrint('deleteTaskChecklist error: $e');
      rethrow;
    }
  }

  static Future<void> duplicateTaskChecklist(int checklistId) async {
    try {
      final data = await _client
          .from('task_checklists')
          .select()
          .eq('id', checklistId)
          .single();
      final newTitle = '${data['title']} (نسخة 1)';
      final currentUser = _client.auth.currentUser;
      final newRow = await _client.from('task_checklists').insert({
        'title': newTitle,
        'description': data['description'],
        'tasks': data['tasks'],
        'frequency': data['frequency'],
        'scheduled_days': data['scheduled_days'],
        'scheduled_time': data['scheduled_time'],
        'once_date': data['once_date'],
        'created_by': currentUser?.id,
        'is_active': data['is_active'],
      }).select().single();
      final assignedIds = await getTaskChecklistAssignedUserIds(checklistId);
      if (assignedIds.isNotEmpty) {
        await assignUsersToTaskChecklist(
          checklistId: newRow['id'] as int,
          userIds: assignedIds,
        );
      }
    } catch (e) {
      debugPrint('duplicateTaskChecklist error: $e');
      rethrow;
    }
  }

// ─── Assignments ─────────────────────────────────────────────────────────────

  /// Replace all user assignments for a task checklist
  static Future<void> assignUsersToTaskChecklist({
    required int checklistId,
    required List<String> userIds,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');
      await _client.rpc('assign_users_to_task_checklist', params: {
        'p_checklist_id': checklistId,
        'p_user_ids': userIds,
        'p_assigned_by': currentUser.id,
      });
    } catch (e) {
      debugPrint('assignUsersToTaskChecklist error: $e');
      rethrow;
    }
  }

  /// Get assigned user IDs for a task checklist
  static Future<List<String>> getTaskChecklistAssignedUserIds(int checklistId) async {
    try {
      final response = await _client.rpc(
        'get_task_checklist_assigned_user_ids',
        params: {'p_checklist_id': checklistId},
      );
      if (response == null || response is! List) return [];
      return response
          .map((item) {
            if (item is String) return item;
            if (item is Map<String, dynamic>) return item['user_id']?.toString() ?? '';
            return item?.toString() ?? '';
          })
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('getTaskChecklistAssignedUserIds error: $e');
      return [];
    }
  }

// ─── Responses (User side) ────────────────────────────────────────────────────

  /// Get task checklists assigned to the current user
  static Future<List<TaskChecklist>> getMyTaskChecklists() async {
    try {
      final response = await _client.rpc('get_my_task_checklists');
      if (response == null) return [];
      final list = response is List ? response : (response as List<dynamic>);
      return list.map<TaskChecklist>((j) => TaskChecklist.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('getMyTaskChecklists error: $e');
      rethrow;
    }
  }

  /// Get today's responses for the current user
  static Future<List<TaskChecklistResponse>> getMyTodayTaskResponses() async {
    try {
      final response = await _client.rpc('get_my_today_task_responses');
      if (response == null) return [];
      final list = response is List ? response : (response as List<dynamic>);
      return list
          .map<TaskChecklistResponse>((j) => TaskChecklistResponse.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('getMyTodayTaskResponses error: $e');
      return [];
    }
  }

  /// Get a specific response for user + checklist + date
  static Future<TaskChecklistResponse?> getTaskChecklistResponse({
    required int checklistId,
    required DateTime date,
    String? userId,
  }) async {
    try {
      final uid = userId ?? _client.auth.currentUser?.id;
      if (uid == null) return null;
      final response = await _client
          .from('task_checklist_responses')
          .select()
          .eq('checklist_id', checklistId)
          .eq('user_id', uid)
          .eq('scheduled_date', date.toIso8601String().split('T')[0])
          .maybeSingle();
      return response != null ? TaskChecklistResponse.fromJson(response) : null;
    } catch (e) {
      debugPrint('getTaskChecklistResponse error: $e');
      return null;
    }
  }

  /// Upsert a response (called as user checks off tasks)
  static Future<TaskChecklistResponse?> upsertTaskChecklistResponse({
    required int checklistId,
    required DateTime scheduledDate,
    required List<TaskItemResponse> taskResponses,
    required TaskChecklistStatus status,
  }) async {
    try {
      final response = await _client.rpc(
        'upsert_task_checklist_response',
        params: {
          'p_checklist_id': checklistId,
          'p_scheduled_date': scheduledDate.toIso8601String().split('T')[0],
          'p_task_responses': taskResponses.map((r) => r.toJson()).toList(),
          'p_status': status.name,
        },
      );
      if (response == null) return null;
      final map = response is Map<String, dynamic> ? response : (response as Map<String, dynamic>);
      return TaskChecklistResponse.fromJson(map);
    } catch (e) {
      debugPrint('upsertTaskChecklistResponse error: $e');
      rethrow;
    }
  }

// ─── Admin reporting ─────────────────────────────────────────────────────────

  /// Get all responses for a checklist (admin)
  static Future<List<TaskChecklistResponse>> getTaskChecklistResponses({
    required int checklistId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final response = await _client.rpc(
        'get_task_checklist_responses',
        params: {
          'p_checklist_id': checklistId,
          'p_from_date': fromDate?.toIso8601String().split('T')[0],
          'p_to_date': toDate?.toIso8601String().split('T')[0],
        },
      );
      if (response == null) return [];
      final list = response is List ? response : (response as List<dynamic>);
      return list
          .map<TaskChecklistResponse>((j) => TaskChecklistResponse.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('getTaskChecklistResponses error: $e');
      return [];
    }
  }

// ─── FCM Token ────────────────────────────────────────────────────────────────

  /// Save or update the FCM token for the current user
  static Future<void> saveFcmToken(String token) async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return;
      await _client.from('users').update({'fcm_token': token}).eq('id', uid);
    } catch (e) {
      debugPrint('saveFcmToken error: $e');
    }
  }

  /// Send push notification to one or more users by their user IDs.
  /// Requires the `send-push` Supabase Edge Function to be deployed.
  static Future<void> sendPushNotification({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      await _client.functions.invoke(
        'send-push',
        body: {
          'user_ids': userIds,
          'title': title,
          'body': body,
          if (data != null) 'data': data,
        },
      );
    } catch (e) {
      debugPrint('sendPushNotification error: $e');
    }
  }

static Future<void> _sendIssueEmailViaPowerAutomate({
  required String toEmail,
  required String assignedToUsername,
  required String assignedByUsername,
  required String checkPointTitle,
  required String formTitle,
  required String description,
  required DateTime responseDate,
  // ── NEW ──────────────────────────────────────────────────────────────────
  Map<String, dynamic>? determinantValues,
  List<Map<String, dynamic>>? determinantDefinitions,
}) async {
  try {
    const url =
        'https://default2cf7d6cd9c34481c9d7810b848e31f.4f.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/2656aea4480249f488c70ab46c73d826/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=-VKZLP4wRUjRR_ZrrA5p9H0o9UnxIA9MU6A9DZJusEQ';

    final arabicMonths = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    final dateStr =
        '${responseDate.day} ${arabicMonths[responseDate.month - 1]} ${responseDate.year}';

    // ── Build determinants rows HTML ─────────────────────────────────────────
    String determinantsHtml = '';
    if (determinantValues != null &&
        determinantValues.isNotEmpty &&
        determinantDefinitions != null &&
        determinantDefinitions.isNotEmpty) {
      final rowsBuffer = StringBuffer();

      for (final def in determinantDefinitions) {
        final detId = def['id'] as String? ?? '';
        final detName = def['name'] as String? ?? detId;
        final detValue = determinantValues[detId]?.toString() ?? '—';
        if (detValue.isEmpty) continue;

        rowsBuffer.write('''
          <tr>
            <td style="
              padding: 10px 14px;
              font-size: 13px;
              color: #6B7280;
              background: #F9FAFB;
              border-bottom: 1px solid #F3F4F6;
              font-weight: 600;
              width: 40%;
            ">$detName</td>
            <td style="
              padding: 10px 14px;
              font-size: 13px;
              color: #111827;
              background: #FFFFFF;
              border-bottom: 1px solid #F3F4F6;
              font-weight: 700;
            ">$detValue</td>
          </tr>
        ''');
      }

      if (rowsBuffer.isNotEmpty) {
        determinantsHtml = '''
          <div style="margin: 16px 0;">
            <div style="
              display: flex;
              align-items: center;
              gap: 8px;
              margin-bottom: 8px;
            ">
              <span style="
                width: 3px;
                height: 16px;
                background: #6C63FF;
                border-radius: 2px;
                display: inline-block;
              "></span>
              <span style="
                font-size: 12px;
                font-weight: 700;
                color: #4B5563;
                letter-spacing: 0.5px;
                text-transform: uppercase;
              ">بيانات التقييم</span>
            </div>
            <table style="
              width: 100%;
              border-collapse: collapse;
              border-radius: 8px;
              overflow: hidden;
              border: 1px solid #E5E7EB;
              font-family: Arial, sans-serif;
            ">
              <thead>
                <tr>
                  <th style="
                    padding: 10px 14px;
                    background: #EEF2FF;
                    color: #4338CA;
                    font-size: 12px;
                    font-weight: 700;
                    text-align: right;
                    border-bottom: 2px solid #C7D2FE;
                  ">المحدد</th>
                  <th style="
                    padding: 10px 14px;
                    background: #EEF2FF;
                    color: #4338CA;
                    font-size: 12px;
                    font-weight: 700;
                    text-align: right;
                    border-bottom: 2px solid #C7D2FE;
                  ">القيمة المختارة</th>
                </tr>
              </thead>
              <tbody>
                ${rowsBuffer.toString()}
              </tbody>
            </table>
          </div>
        ''';
      }
    }

    final subject = 'تم تعيين مشكلة جديدة إليك — $formTitle';

    final body = '''<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin:0; padding:0; background:#F0F2FA; font-family: Arial, sans-serif; direction: rtl;">

  <table width="100%" cellpadding="0" cellspacing="0" style="background:#F0F2FA; padding: 32px 0;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="
          max-width: 600px;
          width: 100%;
          background: #FFFFFF;
          border-radius: 16px;
          overflow: hidden;
          box-shadow: 0 4px 24px rgba(0,0,0,0.10);
        ">

          <!-- ▸ Header banner -->
          <tr>
            <td style="
              background: linear-gradient(135deg, #4F46E5 0%, #7C3AED 60%, #A855F7 100%);
              padding: 32px 28px 24px 28px;
              text-align: center;
            ">
              <!-- Icon circle -->
              <div style="
                width: 56px;
                height: 56px;
                background: rgba(255,255,255,0.18);
                border-radius: 50%;
                display: inline-flex;
                align-items: center;
                justify-content: center;
                margin-bottom: 14px;
                font-size: 26px;
                line-height: 56px;
              ">🔔</div>
              <div style="font-size: 20px; font-weight: 800; color: #FFFFFF; margin-bottom: 6px;">
                مشكلة جديدة تم تعيينها إليك
              </div>
              <div style="
                display: inline-block;
                background: rgba(255,255,255,0.15);
                border: 1px solid rgba(255,255,255,0.30);
                border-radius: 20px;
                padding: 4px 16px;
                font-size: 12px;
                color: #E0E7FF;
                margin-top: 4px;
              ">نظام مراقبة الجودة</div>
            </td>
          </tr>

          <!-- ▸ Body -->
          <tr>
            <td style="padding: 28px;">

              <!-- Greeting -->
              <p style="margin: 0 0 6px 0; font-size: 15px; color: #1F2937; font-weight: 700;">
                مرحباً $assignedToUsername،
              </p>
              <p style="margin: 0 0 22px 0; font-size: 13px; color: #6B7280; line-height: 1.7;">
                تم تعيين مشكلة جديدة إليك في نظام مراقبة الجودة.
                يرجى مراجعة التفاصيل أدناه واتخاذ الإجراء اللازم في أقرب وقت ممكن.
              </p>

              <!-- ─── Main info card ──────────────────────────────────────── -->
              <table width="100%" cellpadding="0" cellspacing="0" style="
                background: #F8F9FF;
                border: 1px solid #E0E7FF;
                border-radius: 10px;
                overflow: hidden;
                margin-bottom: 16px;
              ">
                <tr>
                  <td style="padding: 0 0 0 0;">

                    <!-- Card header -->
                    <div style="
                      background: #EEF2FF;
                      padding: 10px 14px;
                      border-bottom: 1px solid #E0E7FF;
                    ">
                      <span style="font-size: 12px; font-weight: 700; color: #4338CA; letter-spacing: 0.4px;">
                        📋 تفاصيل البلاغ
                      </span>
                    </div>

                    <!-- Rows -->
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding:11px 14px; font-size:12px; color:#6B7280; font-weight:600; width:38%; border-bottom:1px solid #F3F4F6; background:#FAFBFF;">
                          📋 النموذج
                        </td>
                        <td style="padding:11px 14px; font-size:13px; color:#111827; font-weight:700; border-bottom:1px solid #F3F4F6;">
                          $formTitle
                        </td>
                      </tr>
                      <tr>
                        <td style="padding:11px 14px; font-size:12px; color:#6B7280; font-weight:600; border-bottom:1px solid #F3F4F6; background:#FAFBFF;">
                          🔍 نقطة الفحص
                        </td>
                        <td style="padding:11px 14px; font-size:13px; color:#111827; font-weight:700; border-bottom:1px solid #F3F4F6;">
                          $checkPointTitle
                        </td>
                      </tr>
                      <tr>
                        <td style="padding:11px 14px; font-size:12px; color:#6B7280; font-weight:600; border-bottom:1px solid #F3F4F6; background:#FAFBFF;">
                          📅 تاريخ التقرير
                        </td>
                        <td style="padding:11px 14px; font-size:13px; color:#111827; font-weight:700; border-bottom:1px solid #F3F4F6;">
                          $dateStr
                        </td>
                      </tr>
                      <tr>
                        <td style="padding:11px 14px; font-size:12px; color:#6B7280; font-weight:600; background:#FAFBFF;">
                          👤 معين بواسطة
                        </td>
                        <td style="padding:11px 14px; font-size:13px; color:#111827; font-weight:700;">
                          $assignedByUsername
                        </td>
                      </tr>
                    </table>

                  </td>
                </tr>
              </table>

              <!-- ─── Determinants table (injected if present) ────────────── -->
              $determinantsHtml

              <!-- ─── Description box ────────────────────────────────────── -->
              <table width="100%" cellpadding="0" cellspacing="0" style="
                background: #FFFBEB;
                border: 1px solid #FDE68A;
                border-right: 4px solid #F59E0B;
                border-radius: 8px;
                overflow: hidden;
                margin-bottom: 22px;
              ">
                <tr>
                  <td style="padding: 14px 16px;">
                    <div style="font-size: 12px; font-weight: 700; color: #92400E; margin-bottom: 8px;">
                      ⚠️ وصف المشكلة
                    </div>
                    <div style="font-size: 14px; color: #78350F; line-height: 1.7;">
                      $description
                    </div>
                  </td>
                </tr>
              </table>

              <!-- ─── CTA note ───────────────────────────────────────────── -->
              <table width="100%" cellpadding="0" cellspacing="0" style="
                background: #F0FDF4;
                border: 1px solid #BBF7D0;
                border-radius: 8px;
                margin-bottom: 8px;
              ">
                <tr>
                  <td style="padding: 12px 16px; font-size: 13px; color: #166534; line-height: 1.6;">
                    ✅ يرجى تسجيل الدخول إلى النظام، معالجة هذه المشكلة وتحديث حالتها.
                  </td>
                </tr>
              </table>

            </td>
          </tr>

          <!-- ▸ Footer -->
          <tr>
            <td style="
              background: #F8F9FF;
              border-top: 1px solid #E5E7EB;
              padding: 18px 28px;
              text-align: center;
            ">
              <p style="margin: 0; font-size: 12px; color: #9CA3AF; line-height: 1.6;">
                هذه الرسالة تلقائية من <strong style="color:#6C63FF;">نظام مراقبة الجودة</strong>.<br>
                يرجى عدم الرد على هذا البريد الإلكتروني مباشرةً.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>

</body>
</html>''';

    final payload = jsonEncode({
      'to': toEmail,
      'subject': subject,
      'body': body,
      'attachments': <dynamic>[],
    });

    final httpResponse = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: payload,
    );

    debugPrint('Power Automate email response: ${httpResponse.statusCode}');
    debugPrint('Power Automate response body: ${httpResponse.body}');
  } catch (e) {
    debugPrint('_sendIssueEmailViaPowerAutomate error: $e');
  }
}
  
  
  static Future<QualityCheckpointIssue?> getQualityCheckpointIssueById(
      int issueId) async {
    try {
      final response =
          await _client.from('quality_checkpoint_issues').select('''
          *,
          issue_images:quality_issue_images(*),
          resolution_images:quality_issue_resolution_images(*)
        ''').eq('id', issueId).single();

      return QualityCheckpointIssue.fromJson(response);
    } catch (e) {
      print('getQualityCheckpointIssueById error: $e');
      return null;
    }
  }

  /// Get quality checkpoint issues for a specific response
  static Future<List<QualityCheckpointIssue>> getQualityCheckpointIssues({
    int? responseId,
    String? assignedTo,
    String? assignedBy,
    IssueStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      var query = _client.from('quality_checkpoint_issues').select('''
        *,
        issue_images:quality_issue_images(*),
        resolution_images:quality_issue_resolution_images(*)
      ''');

      if (responseId != null) {
        query = query.eq('response_id', responseId);
      }

      if (assignedTo != null) {
        query = query.eq('assigned_to', assignedTo);
      }

      if (assignedBy != null) {
        query = query.eq('assigned_by', assignedBy);
      }

      if (status != null) {
        query = query.eq('status', status.name);
      }

      if (fromDate != null) {
        query = query.gte(
            'response_date', fromDate.toIso8601String().split('T')[0]);
      }

      if (toDate != null) {
        query =
            query.lte('response_date', toDate.toIso8601String().split('T')[0]);
      }

      final response = await query.order('created_at', ascending: false);

      return response
          .map<QualityCheckpointIssue>(
              (json) => QualityCheckpointIssue.fromJson(json))
          .toList();
    } catch (e) {
      print('getQualityCheckpointIssues error: $e');
      rethrow;
    }
  }

  /// Fetch issues for many responses in one query, grouped by response_id.
  static Future<Map<int, List<QualityCheckpointIssue>>>
      getQualityCheckpointIssuesBulk(List<int> responseIds) async {
    if (responseIds.isEmpty) return {};
    try {
      final response = await _client
          .from('quality_checkpoint_issues')
          .select('*, issue_images:quality_issue_images(*), resolution_images:quality_issue_resolution_images(*)')
          .inFilter('response_id', responseIds)
          .order('created_at', ascending: false);

      final Map<int, List<QualityCheckpointIssue>> map = {};
      for (final json in response as List) {
        final issue = QualityCheckpointIssue.fromJson(json);
        map.putIfAbsent(issue.responseId, () => []).add(issue);
      }
      return map;
    } catch (e) {
      print('getQualityCheckpointIssuesBulk error: $e');
      return {};
    }
  }

  /// Get pending issues count for a user
  static Future<int> getUserPendingIssuesCount([String? userId]) async {
    try {
      final targetUserId = userId ?? _client.auth.currentUser?.id;
      if (targetUserId == null) return 0;

      final response =
          await _client.rpc('get_user_pending_issues_count', params: {
        'user_id': targetUserId,
      });

      return response as int? ?? 0;
    } catch (e) {
      print('getUserPendingIssuesCount error: $e');
      return 0;
    }
  }

  /// Update issue status
  static Future<QualityCheckpointIssue> updateIssueStatus({
    required int issueId,
    required IssueStatus status,
  }) async {
    try {
      final updates = {
        'status': status.name,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (status == IssueStatus.resolved) {
        updates['resolved_at'] = DateTime.now().toIso8601String();
      }

      await _client
          .from('quality_checkpoint_issues')
          .update(updates)
          .eq('id', issueId);

      final response =
          await _client.from('quality_checkpoint_issues').select('''
          *,
          issue_images:quality_issue_images(*),
          resolution_images:quality_issue_resolution_images(*)
        ''').eq('id', issueId).single();

      return QualityCheckpointIssue.fromJson(response);
    } catch (e) {
      print('updateIssueStatus error: $e');
      rethrow;
    }
  }

  /// Reassign an issue to a different quality controller
  static Future<QualityCheckpointIssue> reassignIssue({
    required int issueId,
    required String newAssignedTo,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      await _client.from('quality_checkpoint_issues').update({
        'assigned_to': newAssignedTo,
        'assigned_by': currentUser.id,
        'status': IssueStatus.open.name,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', issueId);

      final response = await _client.from('quality_checkpoint_issues').select('''
        *,
        issue_images:quality_issue_images(*),
        resolution_images:quality_issue_resolution_images(*)
      ''').eq('id', issueId).single();

      return QualityCheckpointIssue.fromJson(response);
    } catch (e) {
      print('reassignIssue error: $e');
      rethrow;
    }
  }

  /// Resolve issue with resolution notes and images
  static Future<QualityCheckpointIssue> resolveIssue({
    required int issueId,
    required String resolutionNotes,
    List<Uint8List>? resolutionImageBytes,
    List<String>? resolutionImageNames,
  }) async {
    try {
      final updates = {
        'status': IssueStatus.resolved.name,
        'resolution_notes': resolutionNotes,
        'resolved_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _client
          .from('quality_checkpoint_issues')
          .update(updates)
          .eq('id', issueId);

      // Upload resolution images if provided
      if (resolutionImageBytes != null &&
          resolutionImageNames != null &&
          resolutionImageBytes.isNotEmpty) {
        await uploadIssueResolutionImages(
          issueId: issueId,
          imageBytes: resolutionImageBytes,
          imageNames: resolutionImageNames,
        );
      }

      // Fetch the complete issue
      final response =
          await _client.from('quality_checkpoint_issues').select('''
          *,
          issue_images:quality_issue_images(*),
          resolution_images:quality_issue_resolution_images(*)
        ''').eq('id', issueId).single();

      return QualityCheckpointIssue.fromJson(response);
    } catch (e) {
      print('resolveIssue error: $e');
      rethrow;
    }
  }

  /// Upload issue images
  static Future<List<QualityIssueImage>> uploadIssueImages({
    required int issueId,
    required List<Uint8List> imageBytes,
    required List<String> imageNames,
  }) async {
    try {
      final List<QualityIssueImage> uploadedImages = [];

      for (int i = 0; i < imageBytes.length; i++) {
        final uuid = const Uuid().v4();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = imageNames[i].contains('.')
            ? imageNames[i].substring(imageNames[i].lastIndexOf('.'))
            : '.jpg';
        final fileName = 'issue_${issueId}_${timestamp}_${uuid}$extension';

        try {
          // Upload to storage
          await _client.storage
              .from('quality-images')
              .uploadBinary(fileName, imageBytes[i]);

          // Get public URL
          final imageUrl =
              _client.storage.from('quality-images').getPublicUrl(fileName);

          // Prepare insert data
          final insertData = {
            'issue_id': issueId,
            'image_url': imageUrl,
            'image_name': imageNames[i],
            'image_size': imageBytes[i].length,
            'mime_type': _getMimeType(imageNames[i]),
            'uploaded_at': DateTime.now().toIso8601String(),
          };

          // Save to database
          final imageResponse = await _client
              .from('quality_issue_images')
              .insert(insertData)
              .select()
              .single();

          uploadedImages.add(QualityIssueImage.fromJson(imageResponse));
        } catch (e) {
          print('Error uploading issue image ${imageNames[i]}: $e');
          try {
            await _client.storage.from('quality-images').remove([fileName]);
          } catch (cleanupError) {
            print('Failed to cleanup uploaded file: $cleanupError');
          }
          continue;
        }
      }

      return uploadedImages;
    } catch (e) {
      print('uploadIssueImages error: $e');
      rethrow;
    }
  }

  /// Upload issue resolution images
  static Future<List<QualityIssueResolutionImage>> uploadIssueResolutionImages({
    required int issueId,
    required List<Uint8List> imageBytes,
    required List<String> imageNames,
  }) async {
    try {
      final List<QualityIssueResolutionImage> uploadedImages = [];

      for (int i = 0; i < imageBytes.length; i++) {
        final uuid = const Uuid().v4();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = imageNames[i].contains('.')
            ? imageNames[i].substring(imageNames[i].lastIndexOf('.'))
            : '.jpg';
        final fileName =
            'issue_resolution_${issueId}_${timestamp}_${uuid}$extension';

        try {
          // Upload to storage
          await _client.storage
              .from('quality-images')
              .uploadBinary(fileName, imageBytes[i]);

          // Get public URL
          final imageUrl =
              _client.storage.from('quality-images').getPublicUrl(fileName);

          // Prepare insert data
          final insertData = {
            'issue_id': issueId,
            'image_url': imageUrl,
            'image_name': imageNames[i],
            'image_size': imageBytes[i].length,
            'mime_type': _getMimeType(imageNames[i]),
            'uploaded_at': DateTime.now().toIso8601String(),
          };

          // Save to database
          final imageResponse = await _client
              .from('quality_issue_resolution_images')
              .insert(insertData)
              .select()
              .single();

          uploadedImages
              .add(QualityIssueResolutionImage.fromJson(imageResponse));
        } catch (e) {
          print('Error uploading resolution image ${imageNames[i]}: $e');
          try {
            await _client.storage.from('quality-images').remove([fileName]);
          } catch (cleanupError) {
            print('Failed to cleanup uploaded file: $cleanupError');
          }
          continue;
        }
      }

      return uploadedImages;
    } catch (e) {
      print('uploadIssueResolutionImages error: $e');
      rethrow;
    }
  }

  /// Delete issue
  static Future<void> deleteQualityCheckpointIssue(int issueId) async {
    try {
      await _client
          .from('quality_checkpoint_issues')
          .delete()
          .eq('id', issueId);
    } catch (e) {
      print('deleteQualityCheckpointIssue error: $e');
      rethrow;
    }
  }

  /// Get issues statistics
  static Future<Map<String, dynamic>> getIssuesStatistics({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final response = await _client.rpc('get_issues_statistics', params: {
        'from_date': fromDate?.toIso8601String().split('T')[0],
        'to_date': toDate?.toIso8601String().split('T')[0],
      }).single();

      return response as Map<String, dynamic>;
    } catch (e) {
      print('getIssuesStatistics error: $e');
      return {
        'total_issues': 0,
        'open_issues': 0,
        'in_progress_issues': 0,
        'resolved_issues': 0,
        'resolution_rate': 0.0,
      };
    }
  }

static Future<QualityResponse?> submitQualityResponseWithCheckpointImages({
    required int groupId,
    required int checklistId,
    required String userId,
    int? sessionId,
    required DateTime responseDate,
    required Map<String, dynamic> determinantValues,
    required Map<String, dynamic> checkPointRatings,
    List<Uint8List>? imageBytes,
    List<String>? imageNames,
    Map<String, List<Map<String, dynamic>>>? checkpointImagesData,
    String? mainNotes, // ── NEW ──
  }) async {
    try {
      // Insert the response
      final responseData = await _client
          .from('quality_responses')
          .insert({
            'group_id': groupId,
            'checklist_id': checklistId,
            'user_id': userId,
            'session_id': sessionId,
            'response_date': responseDate.toIso8601String().split('T')[0],
            'determinant_values': determinantValues,
            'check_point_ratings': checkPointRatings,
            'submitted_at': DateTime.now().toUtc().toIso8601String(),
            // ── NEW: only include if not null/empty ──
            if (mainNotes != null && mainNotes.isNotEmpty) 'main_notes': mainNotes,
          })
          .select()
          .single();

      final responseId = responseData['id'] as int;

      // Upload legacy general images if provided
      if (imageBytes != null && imageNames != null) {
        for (int i = 0; i < imageBytes.length; i++) {
          final bytes = imageBytes[i];
          final name = imageNames[i];
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = '${responseId}_${timestamp}_$name';

          // Upload to storage
          await _client.storage.from('quality-images').uploadBinary(
                fileName,
                bytes,
                fileOptions: const FileOptions(
                  contentType: 'image/jpeg',
                  upsert: true,
                ),
              );

          // Get public URL
          final imageUrl =
              _client.storage.from('quality-images').getPublicUrl(fileName);

          // Insert image record
          await _client.from('quality_images').insert({
            'response_id': responseId,
            'image_url': imageUrl,
            'image_name': name,
            'image_size': bytes.length,
            'mime_type': 'image/jpeg',
            'uploaded_at': DateTime.now().toUtc().toIso8601String(),
          });
        }
      }

      // Upload checkpoint-specific images if provided
      if (checkpointImagesData != null && checkpointImagesData.isNotEmpty) {
        for (final entry in checkpointImagesData.entries) {
          final checkPointId = entry.key;
          final imagesList = entry.value;

          for (int i = 0; i < imagesList.length; i++) {
            final imageData = imagesList[i];
            final bytes = imageData['bytes'] as Uint8List;
            final name = imageData['name'] as String;
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final fileName =
                '${responseId}_${checkPointId}_${timestamp}_$i.jpg';

            // Upload to storage
            await _client.storage.from('quality-images').uploadBinary(
                  fileName,
                  bytes,
                  fileOptions: const FileOptions(
                    contentType: 'image/jpeg',
                    upsert: true,
                  ),
                );

            // Get public URL
            final imageUrl =
                _client.storage.from('quality-images').getPublicUrl(fileName);

            // Insert checkpoint image record
            await _client.from('quality_checkpoint_images').insert({
              'response_id': responseId,
              'check_point_id': checkPointId,
              'image_url': imageUrl,
              'image_name': name,
              'image_size': bytes.length,
              'mime_type': 'image/jpeg',
              'uploaded_at': DateTime.now().toUtc().toIso8601String(),
            });
          }
        }
      }

      // Fetch the complete response with images
      return await getQualityResponseById(responseId);
    } catch (e) {
      print('Error submitting quality response with checkpoint images: $e');
      rethrow;
    }
  }
  // New method to get single response by ID with all images
  static Future<QualityResponse?> getQualityResponseById(int responseId) async {
    try {
      final response = await _client.from('quality_responses').select('''
            *,
            images:quality_images(*),
            checkpoint_images:quality_checkpoint_images(*)
          ''').eq('id', responseId).single();

      return QualityResponse.fromJson(response);
    } catch (e) {
      print('getQualityResponseById error: $e');
      return null;
    }
  }

  // New method to upload checkpoint-specific images
  static Future<List<QualityCheckpointImage>> uploadCheckpointImages({
    required int responseId,
    required String checkPointId,
    required List<File> images,
  }) async {
    try {
      final List<QualityCheckpointImage> uploadedImages = [];

      for (int i = 0; i < images.length; i++) {
        final image = images[i];
        final uuid = const Uuid().v4();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = image.path.contains('.')
            ? image.path.substring(image.path.lastIndexOf('.'))
            : '.jpg';
        final fileName =
            'checkpoint_${responseId}_${checkPointId}_${timestamp}_${uuid}$extension';

        try {
          // Upload to storage first
          await _client.storage.from('quality-images').upload(fileName, image);

          // Get public URL
          final imageUrl =
              _client.storage.from('quality-images').getPublicUrl(fileName);

          // Prepare insert data
          final insertData = {
            'response_id': responseId,
            'check_point_id': checkPointId,
            'image_url': imageUrl,
            'image_name': image.path.split('/').last,
            'image_size': await image.length(),
            'mime_type': _getMimeType(image.path),
            'uploaded_at': DateTime.now().toIso8601String(),
          };

          print('Inserting checkpoint image data: $insertData');

          // Save to database with retry logic
          Map<String, dynamic>? imageResponse;
          int retryCount = 0;
          const maxRetries = 3;

          while (retryCount < maxRetries) {
            try {
              imageResponse = await _client
                  .from('quality_checkpoint_images')
                  .insert(insertData)
                  .select()
                  .single();
              break;
            } catch (e) {
              retryCount++;
              print('Database insert attempt $retryCount failed: $e');

              if (retryCount >= maxRetries) {
                try {
                  await _client.storage
                      .from('quality-images')
                      .remove([fileName]);
                } catch (cleanupError) {
                  print('Failed to cleanup uploaded file: $cleanupError');
                }
                rethrow;
              }

              await Future.delayed(Duration(milliseconds: 500 * retryCount));
            }
          }

          if (imageResponse != null) {
            uploadedImages.add(QualityCheckpointImage.fromJson(imageResponse));
            print('Successfully uploaded checkpoint image: ${image.path}');
          }
        } catch (e) {
          print('Error uploading checkpoint image ${image.path}: $e');
          try {
            await _client.storage.from('quality-images').remove([fileName]);
          } catch (cleanupError) {
            print('Failed to cleanup uploaded file: $cleanupError');
          }
          continue;
        }
      }

      if (uploadedImages.isEmpty && images.isNotEmpty) {
        throw Exception('فشل في رفع جميع الصور المحددة لنقطة الفحص');
      }

      return uploadedImages;
    } catch (e) {
      print('uploadCheckpointImages error: $e');
      rethrow;
    }
  }

  // New method to upload checkpoint images from bytes (for web)
  static Future<List<QualityCheckpointImage>> uploadCheckpointImagesFromBytes({
    required int responseId,
    required String checkPointId,
    required List<Uint8List> imageBytes,
    required List<String> imageNames,
  }) async {
    try {
      final List<QualityCheckpointImage> uploadedImages = [];

      for (int i = 0; i < imageBytes.length; i++) {
        final uuid = const Uuid().v4();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = imageNames[i].contains('.')
            ? imageNames[i].substring(imageNames[i].lastIndexOf('.'))
            : '.jpg';
        final fileName =
            'checkpoint_${responseId}_${checkPointId}_${timestamp}_${uuid}$extension';

        try {
          // Upload to storage first
          await _client.storage
              .from('quality-images')
              .uploadBinary(fileName, imageBytes[i]);

          // Get public URL
          final imageUrl =
              _client.storage.from('quality-images').getPublicUrl(fileName);

          // Prepare insert data
          final insertData = {
            'response_id': responseId,
            'check_point_id': checkPointId,
            'image_url': imageUrl,
            'image_name': imageNames[i],
            'image_size': imageBytes[i].length,
            'mime_type': _getMimeType(imageNames[i]),
            'uploaded_at': DateTime.now().toIso8601String(),
          };

          print('Inserting checkpoint image data: $insertData');

          // Save to database with retry logic
          Map<String, dynamic>? imageResponse;
          int retryCount = 0;
          const maxRetries = 3;

          while (retryCount < maxRetries) {
            try {
              imageResponse = await _client
                  .from('quality_checkpoint_images')
                  .insert(insertData)
                  .select()
                  .single();
              break;
            } catch (e) {
              retryCount++;
              print('Database insert attempt $retryCount failed: $e');

              if (retryCount >= maxRetries) {
                try {
                  await _client.storage
                      .from('quality-images')
                      .remove([fileName]);
                } catch (cleanupError) {
                  print('Failed to cleanup uploaded file: $cleanupError');
                }
                rethrow;
              }

              await Future.delayed(Duration(milliseconds: 500 * retryCount));
            }
          }

          if (imageResponse != null) {
            uploadedImages.add(QualityCheckpointImage.fromJson(imageResponse));
            print('Successfully uploaded checkpoint image: ${imageNames[i]}');
          }
        } catch (e) {
          print('Error uploading checkpoint image ${imageNames[i]}: $e');
          try {
            await _client.storage.from('quality-images').remove([fileName]);
          } catch (cleanupError) {
            print('Failed to cleanup uploaded file after error: $cleanupError');
          }
          continue;
        }
      }

      if (uploadedImages.isEmpty && imageBytes.isNotEmpty) {
        throw Exception('فشل في رفع جميع الصور المحددة لنقطة الفحص');
      }

      return uploadedImages;
    } catch (e) {
      print('uploadCheckpointImagesFromBytes error: $e');
      rethrow;
    }
  }

  // New method to delete checkpoint image
  static Future<void> deleteCheckpointImage(int imageId) async {
    try {
      // Get image info first
      final imageResponse = await _client
          .from('quality_checkpoint_images')
          .select()
          .eq('id', imageId)
          .single();

      final image = QualityCheckpointImage.fromJson(imageResponse);

      // Extract filename from URL
      final uri = Uri.parse(image.imageUrl);
      final fileName = uri.pathSegments.last;

      // Delete from storage
      await _client.storage.from('quality-images').remove([fileName]);

      // Delete from database
      await _client
          .from('quality_checkpoint_images')
          .delete()
          .eq('id', imageId);
    } catch (e) {
      print('deleteCheckpointImage error: $e');
      rethrow;
    }
  }

  // Get images for a specific checkpoint in a response
  static Future<List<QualityCheckpointImage>> getCheckpointImages({
    required int responseId,
    String? checkPointId,
  }) async {
    try {
      var query = _client
          .from('quality_checkpoint_images')
          .select()
          .eq('response_id', responseId);

      if (checkPointId != null) {
        query = query.eq('check_point_id', checkPointId);
      }

      final response = await query.order('uploaded_at', ascending: true);

      return response
          .map<QualityCheckpointImage>(
              (json) => QualityCheckpointImage.fromJson(json))
          .toList();
    } catch (e) {
      print('getCheckpointImages error: $e');
      rethrow;
    }
  }

// Fixed uploadQualityImages method
  static Future<List<QualityImage>> uploadQualityImages({
    required int responseId,
    required List<File> images,
  }) async {
    try {
      final List<QualityImage> uploadedImages = [];

      for (int i = 0; i < images.length; i++) {
        final image = images[i];
        final uuid = const Uuid().v4();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = image.path.contains('.')
            ? image.path.substring(image.path.lastIndexOf('.'))
            : '.jpg';
        final fileName =
            'response_${responseId}_${timestamp}_${uuid}$extension';

        try {
          // Upload to storage first
          await _client.storage.from('quality-images').upload(fileName, image);

          // Get public URL
          final imageUrl =
              _client.storage.from('quality-images').getPublicUrl(fileName);

          // Prepare insert data without ID
          final insertData = {
            'response_id': responseId,
            'image_url': imageUrl,
            'image_name': image.path.split('/').last,
            'image_size': await image.length(),
            'mime_type': _getMimeType(image.path),
            'uploaded_at': DateTime.now().toIso8601String(),
          };

          print('Inserting image data: $insertData');

          // Save to database with retry logic
          Map<String, dynamic>? imageResponse;
          int retryCount = 0;
          const maxRetries = 3;

          while (retryCount < maxRetries) {
            try {
              imageResponse = await _client
                  .from('quality_images')
                  .insert(insertData)
                  .select()
                  .single();
              break; // Success, exit retry loop
            } catch (e) {
              retryCount++;
              print('Database insert attempt $retryCount failed: $e');

              if (retryCount >= maxRetries) {
                // Clean up uploaded file
                try {
                  await _client.storage
                      .from('quality-images')
                      .remove([fileName]);
                } catch (cleanupError) {
                  print('Failed to cleanup uploaded file: $cleanupError');
                }
                rethrow;
              }

              // Wait before retry with exponential backoff
              await Future.delayed(Duration(milliseconds: 500 * retryCount));
              print('Retrying image insert, attempt ${retryCount + 1}');
            }
          }

          // Verify we got a valid response
          if (imageResponse == null) {
            throw Exception(
                'Failed to get database response after $maxRetries attempts');
          }

          uploadedImages.add(QualityImage.fromJson(imageResponse));
          print('Successfully uploaded image: ${image.path}');
        } catch (e) {
          print('Error uploading image ${image.path}: $e');

          // Clean up and continue
          try {
            await _client.storage.from('quality-images').remove([fileName]);
          } catch (cleanupError) {
            print('Failed to cleanup uploaded file: $cleanupError');
          }
          continue;
        }
      }

      if (uploadedImages.isEmpty && images.isNotEmpty) {
        throw Exception('فشل في رفع جميع الصور المحددة');
      }

      return uploadedImages;
    } catch (e) {
      print('uploadQualityImages error: $e');
      rethrow;
    }
  }

// Fixed uploadQualityImagesFromBytes method
  static Future<List<QualityImage>> uploadQualityImagesFromBytes({
    required int responseId,
    required List<Uint8List> imageBytes,
    required List<String> imageNames,
  }) async {
    try {
      final List<QualityImage> uploadedImages = [];

      for (int i = 0; i < imageBytes.length; i++) {
        final uuid = const Uuid().v4();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = imageNames[i].contains('.')
            ? imageNames[i].substring(imageNames[i].lastIndexOf('.'))
            : '.jpg';
        final fileName =
            'response_${responseId}_${timestamp}_${uuid}$extension';

        try {
          // Upload to storage first
          await _client.storage
              .from('quality-images')
              .uploadBinary(fileName, imageBytes[i]);

          // Get public URL
          final imageUrl =
              _client.storage.from('quality-images').getPublicUrl(fileName);

          // Prepare insert data without ID (let database auto-generate)
          final insertData = {
            'response_id': responseId,
            'image_url': imageUrl,
            'image_name': imageNames[i],
            'image_size': imageBytes[i].length,
            'mime_type': _getMimeType(imageNames[i]),
            'uploaded_at': DateTime.now().toIso8601String(),
          };

          print('Inserting image data: $insertData');

          // Save to database with retry logic
          Map<String, dynamic>? imageResponse;
          int retryCount = 0;
          const maxRetries = 3;

          while (retryCount < maxRetries) {
            try {
              imageResponse = await _client
                  .from('quality_images')
                  .insert(insertData)
                  .select()
                  .single();
              break; // Success, exit retry loop
            } catch (e) {
              retryCount++;
              print('Database insert attempt $retryCount failed: $e');

              if (retryCount >= maxRetries) {
                // If all retries failed, clean up uploaded file
                try {
                  await _client.storage
                      .from('quality-images')
                      .remove([fileName]);
                } catch (cleanupError) {
                  print('Failed to cleanup uploaded file: $cleanupError');
                }
                rethrow;
              }

              // Wait before retry with exponential backoff
              await Future.delayed(Duration(milliseconds: 500 * retryCount));
              print('Retrying image insert, attempt ${retryCount + 1}');
            }
          }

          // Verify we got a valid response
          if (imageResponse == null) {
            throw Exception(
                'Failed to get database response after $maxRetries attempts');
          }

          uploadedImages.add(QualityImage.fromJson(imageResponse));
          print('Successfully uploaded image: ${imageNames[i]}');
        } catch (e) {
          print('Error uploading image ${imageNames[i]}: $e');

          // Try to clean up the uploaded file if database insert failed
          try {
            await _client.storage.from('quality-images').remove([fileName]);
          } catch (cleanupError) {
            print('Failed to cleanup uploaded file after error: $cleanupError');
          }

          // Continue with other images instead of failing completely
          continue;
        }
      }

      if (uploadedImages.isEmpty && imageBytes.isNotEmpty) {
        throw Exception('فشل في رفع جميع الصور المحددة');
      }

      return uploadedImages;
    } catch (e) {
      print('uploadQualityImagesFromBytes error: $e');
      rethrow;
    }
  }

  static Future<void> deleteQualityImage(int imageId) async {
    try {
      // Get image info first
      final imageResponse = await _client
          .from('quality_images')
          .select()
          .eq('id', imageId)
          .single();

      final image = QualityImage.fromJson(imageResponse);

      // Extract filename from URL
      final uri = Uri.parse(image.imageUrl);
      final fileName = uri.pathSegments.last;

      // Delete from storage
      await _client.storage.from('quality-images').remove([fileName]);

      // Delete from database
      await _client.from('quality_images').delete().eq('id', imageId);
    } catch (e) {
      print('deleteQualityImage error: $e');
      rethrow;
    }
  }

  static String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
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

  // Updated statistics method
  static Future<Map<String, dynamic>> getQualityStatistics({
    int? groupId,
    int? checklistId,
    DateTime? fromDate,
    DateTime? toDate,
    Map<String, String>? determinantFilters,
  }) async {
    try {
      var query = _client.from('quality_responses').select();

      if (groupId != null) {
        query = query.eq('group_id', groupId);
      }

      if (checklistId != null) {
        query = query.eq('checklist_id', checklistId);
      }

      if (fromDate != null) {
        query = query.gte(
            'response_date', fromDate.toIso8601String().split('T')[0]);
      }

      if (toDate != null) {
        query =
            query.lte('response_date', toDate.toIso8601String().split('T')[0]);
      }

      final responses = await query;

      // Filter by determinants if provided
      List<Map<String, dynamic>> filteredResponses = responses;
      if (determinantFilters != null && determinantFilters.isNotEmpty) {
        filteredResponses = responses.where((response) {
          final determinantValues =
              response['determinant_values'] as Map<String, dynamic>? ?? {};
          return determinantFilters.entries.every((filter) {
            return determinantValues[filter.key] == filter.value;
          });
        }).toList();
      }

      // Calculate statistics
      final Map<String, dynamic> statistics = {
        'total_responses': filteredResponses.length,
        'date_range': {
          'from': fromDate?.toIso8601String().split('T')[0],
          'to': toDate?.toIso8601String().split('T')[0],
        },
        'determinant_filters': determinantFilters,
        'check_point_statistics': <String, dynamic>{},
        'overall_average': 0.0,
      };

      if (filteredResponses.isEmpty) {
        return statistics;
      }

      // Calculate check point statistics
      final Map<String, List<int>> checkPointRatings = {};
      double totalSum = 0;
      int totalCount = 0;

      for (final response in filteredResponses) {
        final ratings =
            response['check_point_ratings'] as Map<String, dynamic>? ?? {};
        for (final entry in ratings.entries) {
          final checkPointId = entry.key;
          final ratingData = entry.value as Map<String, dynamic>? ?? {};
          final rating = ratingData['rating'] as int? ?? 0;

          if (!checkPointRatings.containsKey(checkPointId)) {
            checkPointRatings[checkPointId] = [];
          }
          checkPointRatings[checkPointId]!.add(rating);
          totalSum += rating;
          totalCount++;
        }
      }

      // Calculate averages for each check point
      for (final entry in checkPointRatings.entries) {
        final checkPointId = entry.key;
        final ratings = entry.value;
        final average = ratings.fold<double>(0, (sum, rating) => sum + rating) /
            ratings.length;

        statistics['check_point_statistics'][checkPointId] = {
          'average': average,
          'total_responses': ratings.length,
          'ratings_distribution': _calculateRatingsDistribution(ratings),
        };
      }

      // Calculate overall average
      if (totalCount > 0) {
        statistics['overall_average'] = totalSum / totalCount;
      }

      return statistics;
    } catch (e) {
      print('getQualityStatistics error: $e');
      rethrow;
    }
  }

  static Map<String, int> _calculateRatingsDistribution(List<int> ratings) {
    final Map<String, int> distribution = {};
    for (final rating in ratings) {
      final key = rating.toString();
      distribution[key] = (distribution[key] ?? 0) + 1;
    }
    return distribution;
  }

  // Export methods for quality data
  static Future<List<Map<String, dynamic>>> getQualityDataForExport({
    int? checklistId,
    DateTime? fromDate,
    DateTime? toDate,
    Map<String, String>? determinantFilters,
  }) async {
    try {
      final responses = await getQualityResponses(
        checklistId: checklistId,
        fromDate: fromDate,
        toDate: toDate,
      );

      // Get checklist details
      QualityChecklist? checklist;
      if (checklistId != null) {
        try {
          final checklistResponse = await _client
              .from('quality_checklists')
              .select()
              .eq('id', checklistId)
              .single();
          checklist = QualityChecklist.fromJson(checklistResponse);
        } catch (e) {
          print('Error getting checklist for export: $e');
        }
      }

      // Transform data for export
      final List<Map<String, dynamic>> exportData = [];

      for (final response in responses) {
        // Apply determinant filters if provided
        if (determinantFilters != null && determinantFilters.isNotEmpty) {
          bool matchesFilters = determinantFilters.entries.every((filter) {
            return response.determinantValues[filter.key] == filter.value;
          });
          if (!matchesFilters) continue;
        }

        // Get user details
        String username = 'Unknown';
        try {
          final userResponse = await _client
              .from('users')
              .select('username')
              .eq('id', response.userId)
              .single();
          username = userResponse['username'] ?? 'Unknown';
        } catch (e) {
          print('Error getting user for export: $e');
        }

        final Map<String, dynamic> exportRow = {
          'response_id': response.id,
          'checklist_id': response.checklistId,
          'checklist_title': checklist?.title ?? 'Unknown',
          'user': username,
          'response_date':
              response.responseDate.toIso8601String().split('T')[0],
          'submitted_at': response.submittedAt.toIso8601String(),
        };

        // Add determinant values
        for (final entry in response.determinantValues.entries) {
          exportRow['determinant_${entry.key}'] = entry.value;
        }

        // Add check point ratings
        for (final entry in response.checkPointRatings.entries) {
          final checkPointId = entry.key;
          final ratingData = entry.value as Map<String, dynamic>? ?? {};

          exportRow['checkpoint_${checkPointId}_rating'] = ratingData['rating'];
          exportRow['checkpoint_${checkPointId}_notes'] = ratingData['notes'];
          exportRow['checkpoint_${checkPointId}_corrective_action'] =
              ratingData['corrective_action'];
        }

        exportData.add(exportRow);
      }

      return exportData;
    } catch (e) {
      print('getQualityDataForExport error: $e');
      rethrow;
    }
  }

  // Helper method to check authentication status
  static bool get isAuthenticated => _client.auth.currentUser != null;

  // Helper method to get current user ID
  static String? get currentUserId => _client.auth.currentUser?.id;

// Add to SupabaseService - Enhanced statistics for multiple checklists
  static Future<Map<String, dynamic>> getMultipleChecklistsStatistics({
    required int groupId,
    DateTime? fromDate,
    DateTime? toDate,
    Map<int, Map<String, String>>?
        checklistDeterminantFilters, // checklistId -> determinant filters
  }) async {
    try {
      final responses = await getQualityResponses(
        groupId: groupId,
        fromDate: fromDate,
        toDate: toDate,
      );

      final Map<String, dynamic> result = {
        'group_statistics': {},
        'checklist_statistics': <int, Map<String, dynamic>>{},
        'total_responses': responses.length,
      };

      // Group responses by checklist
      final Map<int, List<QualityResponse>> responsesByChecklist = {};
      for (final response in responses) {
        responsesByChecklist[response.checklistId] ??= [];
        responsesByChecklist[response.checklistId]!.add(response);
      }

      // Calculate statistics for each checklist
      for (final entry in responsesByChecklist.entries) {
        final checklistId = entry.key;
        List<QualityResponse> checklistResponses = entry.value;

        // Apply determinant filters if provided
        if (checklistDeterminantFilters != null &&
            checklistDeterminantFilters.containsKey(checklistId)) {
          final filters = checklistDeterminantFilters[checklistId]!;
          checklistResponses = checklistResponses.where((response) {
            return filters.entries.every((filter) {
              final determinantId = filter.key;
              final selectedValue = filter.value;
              final responseValue = response.determinantValues[determinantId];
              return responseValue != null &&
                  responseValue.toString() == selectedValue;
            });
          }).toList();
        }

        result['checklist_statistics'][checklistId] =
            calculateChecklistStatistics(checklistResponses, checklistId);
      }

      return result;
    } catch (e) {
      print('getMultipleChecklistsStatistics error: $e');
      rethrow;
    }
  }

  // COST CENTERS MANAGEMENT
  static Future<List<CostCenter>> getCostCenters() async {
    try {
      final response = await _client
          .from('cost_centers')
          .select()
          .order('code', ascending: true);

      return response
          .map<CostCenter>((json) => CostCenter.fromJson(json))
          .toList();
    } catch (e) {
      print('getCostCenters error: $e');
      rethrow;
    }
  }

  static Future<void> syncCostCenters(List<CostCenter> costCenters) async {
    try {
      // Clear existing cost centers
      await _client.from('cost_centers').delete().neq('id', 0);

      // Insert new cost centers in batches
      const batchSize = 100;
      for (int i = 0; i < costCenters.length; i += batchSize) {
        final batch = costCenters.skip(i).take(batchSize).map((costCenter) {
          final json = costCenter.toJson();
          json.remove('id'); // Let database generate ID
          return json;
        }).toList();

        await _client.from('cost_centers').insert(batch);
      }
    } catch (e) {
      print('syncCostCenters error: $e');
      rethrow;
    }
  }

  static Future<AssignCostCenter?> getAssignCostCenterByNumber(
      String number) async {
    try {
      final response = await _client.from('assign_cost_centers').select('''
          *,
          cost_center:cost_centers(*)
        ''').eq('number', number).maybeSingle();

      return response != null ? AssignCostCenter.fromJson(response) : null;
    } catch (e) {
      print('getAssignCostCenterByNumber error: $e');
      return null;
    }
  }

  static Future<void> deleteAssignCostCenter(int id) async {
    try {
      await _client.from('assign_cost_centers').delete().eq('id', id);
    } catch (e) {
      print('deleteAssignCostCenter error: $e');
      rethrow;
    }
  }

// FUEL TYPES MANAGEMENT
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

  static Future<void> syncFuelTypes(List<FuelType> fuelTypes) async {
    try {
      // Update existing or insert new fuel types
      for (final fuelType in fuelTypes) {
        await _client.from('fuel_types').upsert({
          'code': fuelType.code,
          'name': fuelType.name,
          'price': fuelType.price,
        });
      }
    } catch (e) {
      print('syncFuelTypes error: $e');
      rethrow;
    }
  }

  /// Create warehouse transfer request with Bisan code
  static Future<WarehouseTransferRequest>
      createWarehouseTransferRequestWithBisanCode({
    required String sourceWarehouse,
    required String targetWarehouse,
    required String warehouseType,
    required List<TransferItem> items,
    required String bisanCode,
    required String docDate,
    String? targetUserId,
    String? targetUserName,
    String? comment,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get current user details
      final userResponse = await _client
          .from('users')
          .select('username')
          .eq('id', currentUser.id)
          .single();

      final requesterName = userResponse['username'] as String;

      final requestData = {
        'requester_id': currentUser.id,
        'requester_name': requesterName,
        'target_user_id': targetUserId,
        'target_user_name': targetUserName,
        'source_warehouse': sourceWarehouse,
        'target_warehouse': targetWarehouse,
        'warehouse_type': warehouseType,
        'items': items
            .map((item) => {
                  'item_code': item.itemCode,
                  'item_name': item.itemName,
                  'unit': item.unit,
                  'available_quantity': item.availableQuantity,
                  'requested_quantity': item.requestedQuantity,
                })
            .toList(),
        'status': targetUserId == null
            ? TransferStatus.completed.name
            : TransferStatus.pending.name,
        'comment': comment,
        'request_date': DateTime.now().toIso8601String(),
        'bisan_transaction_id': bisanCode,
        'doc_date': docDate,
      };

      // If it's to main warehouse, mark as completed immediately
      if (targetUserId == null) {
        requestData['completed_date'] = DateTime.now().toIso8601String();
      }

      print('DEBUG: Creating warehouse transfer request with Bisan code');

      final response = await _client
          .from('warehouse_transfer_requests')
          .insert(requestData)
          .select()
          .single();

      print('DEBUG: Warehouse transfer request created with code: $bisanCode');
      return WarehouseTransferRequest.fromJson(response);
    } catch (e) {
      print('DEBUG: createWarehouseTransferRequestWithBisanCode error: $e');
      rethrow;
    }
  }

  /// Approve warehouse transfer request and execute in Bisan
  static Future<WarehouseTransferRequest>
      approveAndExecuteWarehouseTransferRequest({
    required int requestId,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      print('DEBUG: Approving and executing request ID: $requestId');

      // First, get the request details
      final requestResponse = await _client
          .from('warehouse_transfer_requests')
          .select()
          .eq('id', requestId)
          .eq('target_user_id', currentUser.id)
          .eq('status', TransferStatus.pending.name)
          .single();

      if (requestResponse == null) {
        throw Exception('Request not found or unauthorized');
      }

      final request = WarehouseTransferRequest.fromJson(requestResponse);

      // Get store issue voucher details from Bisan
      final issueVoucherData = await ApiService.getStoreIssueVoucherByCode(
          request.bisanTransactionId!);

      // Create store receipt voucher
      final receiptResult = await ApiService.createStoreReceiptVoucher(
        issueVoucherData: issueVoucherData,
      );

      // Update request status to completed
      final updates = {
        'status': TransferStatus.completed.name,
        'approved_date': DateTime.now().toIso8601String(),
        'completed_date': DateTime.now().toIso8601String(),
        'receipt_transaction_id': receiptResult['transaction_id'],
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _client
          .from('warehouse_transfer_requests')
          .update(updates)
          .eq('id', requestId);

      // Fetch updated request
      final updatedResponse = await _client
          .from('warehouse_transfer_requests')
          .select()
          .eq('id', requestId)
          .single();

      print(
          'DEBUG: Warehouse transfer request approved and executed: $requestId');
      return WarehouseTransferRequest.fromJson(updatedResponse);
    } catch (e) {
      print('DEBUG: approveAndExecuteWarehouseTransferRequest error: $e');
      rethrow;
    }
  }

  /// Delete warehouse transfer request with complete reversal (using RPC)
  static Future<void> deleteWarehouseTransferRequestWithReversal(
      int requestId) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      print('DEBUG: Starting deletion with reversal for request: $requestId');

      // Get the request details
      final requestResponse = await _client
          .from('warehouse_transfer_requests')
          .select()
          .eq('id', requestId)
          .eq('requester_id', currentUser.id)
          .eq('status', TransferStatus.pending.name)
          .single();

      if (requestResponse == null) {
        throw Exception('Request not found or unauthorized');
      }

      final request = WarehouseTransferRequest.fromJson(requestResponse);

      // Execute complete reversal process
      final reversalResult = await ApiService.executeCompleteReversal(
        request: request,
        reason: "deletion",
      );

      // Use RPC function to safely update the request with corrected parameter names
      final response =
          await _client.rpc('delete_warehouse_transfer_with_reversal', params: {
        'p_request_id': requestId,
        'p_forward_receipt_transaction_id':
            reversalResult['forward_receipt_transaction_id'],
        'p_reverse_issue_code': reversalResult['reverse_issue_code'],
        'p_reverse_receipt_transaction_id':
            reversalResult['reverse_receipt_transaction_id'],
        'p_requester_user_id': currentUser.id,
      });

      if (response == null || response.isEmpty) {
        throw Exception('Failed to update request after reversal');
      }

      print(
          'DEBUG: Warehouse transfer request deleted with complete reversal: $requestId');
    } catch (e) {
      print('DEBUG: deleteWarehouseTransferRequestWithReversal error: $e');
      rethrow;
    }
  }

  /// Reject warehouse transfer request with complete reversal (using RPC)
  static Future<WarehouseTransferRequest>
      rejectWarehouseTransferRequestWithReversal({
    required int requestId,
    String? rejectionReason,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      print('DEBUG: Starting rejection with reversal for request: $requestId');

      // Get the request details
      final requestResponse = await _client
          .from('warehouse_transfer_requests')
          .select()
          .eq('id', requestId)
          .eq('target_user_id', currentUser.id)
          .eq('status', TransferStatus.pending.name)
          .single();

      if (requestResponse == null) {
        throw Exception('Request not found or unauthorized');
      }

      final request = WarehouseTransferRequest.fromJson(requestResponse);

      // Execute complete reversal process
      final reversalResult = await ApiService.executeCompleteReversal(
        request: request,
        reason: "rejection",
        rejectionComment: rejectionReason,
      );

      // Use RPC function to safely update the request with corrected parameter names
      final response =
          await _client.rpc('reject_warehouse_transfer_with_reversal', params: {
        'p_request_id': requestId,
        'p_rejection_reason': rejectionReason,
        'p_forward_receipt_transaction_id':
            reversalResult['forward_receipt_transaction_id'],
        'p_reverse_issue_code': reversalResult['reverse_issue_code'],
        'p_reverse_receipt_transaction_id':
            reversalResult['reverse_receipt_transaction_id'],
        'p_rejector_user_id': currentUser.id,
      });

      if (response == null || response.isEmpty) {
        throw Exception('Failed to update request after reversal');
      }

      // The RPC function returns the updated request
      final updatedRequest = WarehouseTransferRequest.fromJson(response[0]);

      print(
          'DEBUG: Warehouse transfer request rejected with complete reversal: $requestId');
      return updatedRequest;
    } catch (e) {
      print('DEBUG: rejectWarehouseTransferRequestWithReversal error: $e');
      rethrow;
    }
  }

// lib/services/supabase_service.dart

// UPDATED: Get user fuel statistics with fuel contact filter
  static Future<List<UserFuelStatistics>> getUserFuelStatistics({
    DateTime? fromDate,
    DateTime? toDate,
    int? fuelContactId, // NEW PARAMETER
  }) async {
    try {
      Map<String, dynamic> params = {};

      if (fromDate != null) {
        params['from_date'] = fromDate.toIso8601String().split('T')[0];
      }

      if (toDate != null) {
        params['to_date'] = toDate.toIso8601String().split('T')[0];
      }

      // NEW: Add fuel contact parameter if provided
      if (fuelContactId != null) {
        params['fuel_contact_id_param'] = fuelContactId;
      }

      final response = await _client
          .rpc('get_user_fuel_statistics', params: params)
          .select();

      return response
          .map<UserFuelStatistics>((json) => UserFuelStatistics.fromJson(json))
          .toList();
    } catch (e) {
      print('getUserFuelStatistics error: $e');
      rethrow;
    }
  }

  static Future<void> deleteFuelFillingRecord(int id) async {
    try {
      // Get record to check for image
      final record = await _client
          .from('fuel_filling_records')
          .select('image_url')
          .eq('id', id)
          .maybeSingle();

      // Delete image if exists
      if (record != null && record['image_url'] != null) {
        await deleteFuelImage(record['image_url']);
      }

      // Delete record
      await _client.from('fuel_filling_records').delete().eq('id', id);
    } catch (e) {
      print('deleteFuelFillingRecord error: $e');
      rethrow;
    }
  }

// STATISTICS
  static Future<List<CostCenterStatistics>> getCostCenterStatistics() async {
    try {
      final response = await _client.rpc('get_cost_center_statistics').select();
      return response
          .map<CostCenterStatistics>(
              (json) => CostCenterStatistics.fromJson(json))
          .toList();
    } catch (e) {
      print('getCostCenterStatistics error: $e');
      rethrow;
    }
  }

// NEW: Statistics with date range filter
  static Future<List<CostCenterStatistics>>
      getCostCenterStatisticsWithDateRange({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final response = await _client
          .rpc('get_cost_center_statistics_with_date_range', params: {
        'from_date': fromDate.toIso8601String().split('T')[0],
        'to_date': toDate.toIso8601String().split('T')[0],
      }).select();

      return response
          .map<CostCenterStatistics>(
              (json) => CostCenterStatistics.fromJson(json))
          .toList();
    } catch (e) {
      print('getCostCenterStatisticsWithDateRange error: $e');
      rethrow;
    }
  }

// IMAGE MANAGEMENT
  static Future<String> uploadFuelImage({
    required Uint8List imageBytes,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      final uuid = const Uuid().v4();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = fileName.contains('.')
          ? fileName.substring(fileName.lastIndexOf('.'))
          : '.jpg';
      final uniqueFileName = 'fuel_${timestamp}_${uuid}$extension';

      // Upload to storage
      await _client.storage
          .from('fuel-images')
          .uploadBinary(uniqueFileName, imageBytes);

      // Get public URL
      final imageUrl =
          _client.storage.from('fuel-images').getPublicUrl(uniqueFileName);

      return imageUrl;
    } catch (e) {
      print('uploadFuelImage error: $e');
      rethrow;
    }
  }

  static Future<void> deleteFuelImage(String imageUrl) async {
    try {
      // Extract filename from URL
      final uri = Uri.parse(imageUrl);
      final fileName = uri.pathSegments.last;

      // Delete from storage
      await _client.storage.from('fuel-images').remove([fileName]);
    } catch (e) {
      print('deleteFuelImage error: $e');
      rethrow;
    }
  }

  // Add to SupabaseService
  static Future<QualityResponse> submitQualityResponseWeb({
    required int groupId,
    required int checklistId,
    required String userId,
    int? sessionId,
    required DateTime responseDate,
    required Map<String, dynamic> determinantValues,
    required Map<String, dynamic> checkPointRatings,
    List<Uint8List>? imageBytes,
    List<String>? imageNames,
  }) async {
    try {
      final response = await _client
          .from('quality_responses')
          .insert({
            'group_id': groupId,
            'checklist_id': checklistId,
            'user_id': userId,
            'session_id': sessionId,
            'response_date': responseDate.toIso8601String().split('T')[0],
            'determinant_values': determinantValues,
            'check_point_ratings': checkPointRatings,
            'submitted_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final qualityResponse = QualityResponse.fromJson(response);

      // Upload images using bytes
      if (imageBytes != null && imageNames != null && imageBytes.isNotEmpty) {
        await uploadQualityImagesFromBytes(
          responseId: qualityResponse.id,
          imageBytes: imageBytes,
          imageNames: imageNames,
        );
      }

      return qualityResponse;
    } catch (e) {
      print('submitQualityResponseWeb error: $e');
      rethrow;
    }
  }

  static Future<AppUser> getUserByIdWithAdditionalContacts(
      String userId) async {
    try {
      final response =
          await _client.from('users').select().eq('id', userId).single();

      // Get additional contacts
      final additionalContactsResponse = await _client
          .rpc('get_user_additional_contacts', params: {'p_user_id': userId});

      final List<String> additionalContactCodes = [];
      if (additionalContactsResponse != null) {
        for (final row in additionalContactsResponse) {
          additionalContactCodes.add(row['contact_code'] as String);
        }
      }

      final userData = Map<String, dynamic>.from(response);
      userData['additional_contact_codes'] = additionalContactCodes;

      return AppUser.fromJson(userData);
    } catch (e) {
      throw Exception('Failed to fetch user with additional contacts: $e');
    }
  }

  // NEW: Get additional contacts for a user
  static Future<List<String>> getUserAdditionalContacts(String userId) async {
    try {
      final response = await _client
          .rpc('get_user_additional_contacts', params: {'p_user_id': userId});

      final List<String> contactCodes = [];
      if (response != null) {
        for (final row in response) {
          contactCodes.add(row['contact_code'] as String);
        }
      }

      return contactCodes;
    } catch (e) {
      print('getUserAdditionalContacts error: $e');
      return [];
    }
  }

  // NEW: Assign additional contacts to user
  static Future<void> assignAdditionalContactsToUser({
    required String userId,
    required List<String> contactCodes,
  }) async {
    try {
      await _client.rpc('assign_additional_contacts_to_user', params: {
        'p_user_id': userId,
        'p_contact_codes': contactCodes,
      });
    } catch (e) {
      print('assignAdditionalContactsToUser error: $e');
      rethrow;
    }
  }

  // Method to verify user authentication and permissions
  static Future<bool> verifyUserPermissions({required String action}) async {
    try {
      final user = await getCurrentUser();
      if (user == null) {
        print('User not authenticated for action: $action');
        return false;
      }

      if (!user.isActive) {
        print('User is not active for action: $action');
        return false;
      }

      // Check specific permissions based on action
      switch (action) {
        case 'create_checklist':
        case 'update_checklist':
        case 'delete_checklist':
          return user.isAdmin;
        case 'fill_checklist':
          return user.isQualityController || user.isAdmin;
        case 'view_reports':
          return user.isAdmin;
        default:
          return true;
      }
    } catch (e) {
      print('Error verifying user permissions: $e');
      return false;
    }
  }

// UPDATED: Get user contacts - now excludes contacts with "مبرد" in area_name
  static Future<List<Contact>> getUserContactsWithoutFreeze({
    required String salesman,
    String? area,
    String? search,
    List<String>? additionalContactCodes,
  }) async {
    try {
      print(
          'DEBUG: getUserContacts called with salesman: "$salesman", area: "$area"');
      print('DEBUG: Additional contact codes: $additionalContactCodes');

      bool isAdminUser = salesman == '00';

      if (isAdminUser) {
        print('DEBUG: Admin user - using pagination to get all contacts');
        return await _getAllContactsWithPaginationWithoutFreeze(search: search);
      } else {
        print('DEBUG: Regular user - applying filters');
        return await _getFilteredContactsWithAdditionalWithoutFreeze(
          salesman: salesman,
          area: area,
          search: search,
          additionalContactCodes: additionalContactCodes,
        );
      }
    } catch (e) {
      print('getUserContacts error: $e');
      rethrow;
    }
  }

// UPDATED: Get all contacts with pagination - now excludes "مبرد" contacts
  static Future<List<Contact>> _getAllContactsWithPaginationWithoutFreeze(
      {String? search}) async {
    List<Contact> allContacts = [];
    int pageSize = 1000;
    int page = 0;
    bool hasMore = true;

    print('DEBUG: Starting pagination to load all contacts...');

    while (hasMore) {
      try {
        var query = _client.from('contacts').select();

        if (search != null && search.isNotEmpty) {
          query = query.or('name_ar.ilike.%$search%,code.ilike.%$search%');
        }

        final response = await query
            .range(page * pageSize, (page + 1) * pageSize - 1)
            .order('name_ar', ascending: true);

        final pageContacts =
            response.map<Contact>((json) => Contact.fromJson(json)).toList();

        // NEW: Filter out contacts with "مبرد" in area_name
        final filteredContacts = pageContacts.where((contact) {
          final areaName = contact.areaName ?? '';
          return !areaName.contains('مبرد');
        }).toList();

        allContacts.addAll(filteredContacts);

        print(
            'DEBUG: Page ${page + 1}: loaded ${pageContacts.length} contacts, filtered to ${filteredContacts.length} (total: ${allContacts.length})');

        hasMore = pageContacts.length == pageSize;
        page++;

        if (page > 50) {
          print('DEBUG: Reached maximum page limit (50 pages)');
          break;
        }
      } catch (e) {
        print('DEBUG: Error loading page $page: $e');
        break;
      }
    }

    print(
        'DEBUG: Pagination complete. Total contacts loaded after filtering: ${allContacts.length}');
    return allContacts;
  }

// UPDATED: Get filtered contacts with additional contacts - now excludes "مبرد" contacts
  static Future<List<Contact>> _getFilteredContactsWithAdditionalWithoutFreeze({
    required String salesman,
    String? area,
    String? search,
    List<String>? additionalContactCodes,
  }) async {
    print('🔍 _getFilteredContactsWithAdditional called');
    print('   Salesman: $salesman');
    print('   Area: $area');
    print('   Additional contact codes: $additionalContactCodes');

    try {
      List<Contact> allContacts = [];

      // First, get contacts by salesman
      var salesmanQuery = _client.from('contacts').select();
      salesmanQuery = salesmanQuery.eq('salesman', salesman);

      if (area != null && area.isNotEmpty && area != '00') {
        salesmanQuery = salesmanQuery.eq('area', area);
        print('   Applied area filter: $area');
      }

      if (search != null && search.isNotEmpty) {
        salesmanQuery =
            salesmanQuery.or('name_ar.ilike.%$search%,code.ilike.%$search%');
      }

      // Load contacts by salesman
      int pageSize = 1000;
      int page = 0;
      bool hasMore = true;

      while (hasMore) {
        final response = await salesmanQuery
            .range(page * pageSize, (page + 1) * pageSize - 1)
            .order('name_ar', ascending: true);

        final pageContacts =
            response.map<Contact>((json) => Contact.fromJson(json)).toList();

        // NEW: Filter out contacts with "مبرد" in area_name
        final filteredContacts = pageContacts.where((contact) {
          final areaName = contact.areaName ?? '';
          return !areaName.contains('مبرد');
        }).toList();

        allContacts.addAll(filteredContacts);

        print(
            '   Loaded ${pageContacts.length} contacts by salesman, filtered to ${filteredContacts.length} (page ${page + 1})');

        hasMore = pageContacts.length == pageSize;
        page++;

        if (page > 10) break;
      }

      print(
          '   Total contacts by salesman after filtering: ${allContacts.length}');

      // Now, get additional contacts if any
      if (additionalContactCodes != null && additionalContactCodes.isNotEmpty) {
        print(
            '   Loading ${additionalContactCodes.length} additional contacts...');

        // Load additional contacts in batches
        const batchSize = 100;
        for (int i = 0; i < additionalContactCodes.length; i += batchSize) {
          final batch = additionalContactCodes.skip(i).take(batchSize).toList();

          var additionalQuery = _client.from('contacts').select();
          additionalQuery = additionalQuery.inFilter('code', batch);

          if (search != null && search.isNotEmpty) {
            additionalQuery = additionalQuery
                .or('name_ar.ilike.%$search%,code.ilike.%$search%');
          }

          final additionalResponse =
              await additionalQuery.order('name_ar', ascending: true);

          final additionalContacts = additionalResponse
              .map<Contact>((json) => Contact.fromJson(json))
              .toList();

          // NEW: Filter out additional contacts with "مبرد" in area_name
          final filteredAdditionalContacts =
              additionalContacts.where((contact) {
            final areaName = contact.areaName ?? '';
            return !areaName.contains('مبرد');
          }).toList();

          // Add only contacts that are not already in the list (avoid duplicates)
          for (final contact in filteredAdditionalContacts) {
            if (!allContacts.any((c) => c.code == contact.code)) {
              allContacts.add(contact);
            }
          }

          print(
              '   Loaded ${additionalContacts.length} additional contacts, filtered to ${filteredAdditionalContacts.length} in batch ${(i ~/ batchSize) + 1}');
        }
      }

      print(
          '   Total contacts (including additional after filtering): ${allContacts.length}');

      // Sort all contacts by name
      allContacts.sort((a, b) => a.nameAr.compareTo(b.nameAr));

      return allContacts;
    } catch (e) {
      print('❌ Error in _getFilteredContactsWithAdditional: $e');
      rethrow;
    }
  }

// UPDATED: Get all contacts - now excludes "مبرد" contacts
  static Future<List<Contact>> getContactsWithoutFreeze(
      {String? search}) async {
    try {
      print('DEBUG: getContacts called with search: "$search"');
      return await _getAllContactsWithPaginationWithoutFreeze(search: search);
    } catch (e) {
      print('getContacts error: $e');
      rethrow;
    }
  }

// UPDATED: Get contacts not visible to user - now excludes "مبرد" contacts
  static Future<List<Contact>> getContactsNotVisibleToUserWithoutFreeze({
    required String userSalesman,
    String? userArea,
    String? search,
  }) async {
    try {
      var query = _client.from('contacts').select();

      // Get contacts where salesman is NOT the user's salesman
      query = query.neq('salesman', userSalesman);

      if (search != null && search.isNotEmpty) {
        query = query.or('name_ar.ilike.%$search%,code.ilike.%$search%');
      }

      List<Contact> allContacts = [];
      int pageSize = 1000;
      int page = 0;
      bool hasMore = true;

      while (hasMore) {
        final response = await query
            .range(page * pageSize, (page + 1) * pageSize - 1)
            .order('name_ar', ascending: true);

        final pageContacts =
            response.map<Contact>((json) => Contact.fromJson(json)).toList();

        // NEW: Filter out contacts with "مبرد" in area_name
        final filteredContacts = pageContacts.where((contact) {
          final areaName = contact.areaName ?? '';
          return !areaName.contains('مبرد');
        }).toList();

        allContacts.addAll(filteredContacts);

        hasMore = pageContacts.length == pageSize;
        page++;

        if (page > 10) break;
      }

      return allContacts;
    } catch (e) {
      print('getContactsNotVisibleToUser error: $e');
      rethrow;
    }
  }

  // ─── Positions ────────────────────────────────────────────────────────────
  static Future<List<Position>> getPositions() async {
    try {
      final response = await _client
          .from('positions')
          .select()
          .order('name', ascending: true);
      return response.map<Position>((json) => Position.fromJson(json)).toList();
    } catch (e) {
      print('getPositions error: $e');
      rethrow;
    }
  }

  static Future<Position> createPosition(String name) async {
    try {
      final response = await _client
          .from('positions')
          .insert({'name': name.trim()})
          .select()
          .single();
      return Position.fromJson(response);
    } catch (e) {
      print('createPosition error: $e');
      rethrow;
    }
  }

  static Future<void> updatePosition(String id, String name) async {
    try {
      await _client
          .from('positions')
          .update({'name': name.trim()})
          .eq('id', id);
    } catch (e) {
      print('updatePosition error: $e');
      rethrow;
    }
  }

  static Future<void> deletePosition(String id) async {
    try {
      await _client.from('positions').delete().eq('id', id);
    } catch (e) {
      print('deletePosition error: $e');
      rethrow;
    }
  }

  // ─── Profile: update username (and optionally area) ───────────────────────
  static Future<void> updateUserProfile({
    required String userId,
    required String username,
    String? area,
  }) async {
    try {
      final updates = <String, dynamic>{'username': username};
      if (area != null) updates['area'] = area;
      await _client.from('users').update(updates).eq('id', userId);
      if (_currentAppUser != null) {
        _currentAppUser = _currentAppUser!.copyWith(
          username: username,
          area: area ?? _currentAppUser!.area,
        );
      }
    } catch (e) {
      print('updateUserProfile error: $e');
      rethrow;
    }
  }

  // ─── Notification preferences ─────────────────────────────────────────────
  static Future<Map<String, bool>> getNotificationPreferences(String userId) async {
    try {
      final data = await _client
          .from('users')
          .select('notification_preferences')
          .eq('id', userId)
          .single();
      final prefs = data['notification_preferences'];
      if (prefs == null) return _defaultNotificationPreferences();
      return Map<String, bool>.from(
          (prefs as Map<String, dynamic>).map((k, v) => MapEntry(k, v as bool? ?? true)));
    } catch (e) {
      print('getNotificationPreferences error: $e');
      return _defaultNotificationPreferences();
    }
  }

  static Map<String, bool> _defaultNotificationPreferences() => {
        'all_notifications': true,
        'hourly_reminders': true,
        'morning_reminders': true,
        'task_assigned': true,
        'task_list_notifications': true,
        'quality_issue_assigned': true,
        'quality_group_assigned': true,
        'quality_issue_resolved': true,
      };

  static Future<void> updateNotificationPreferences({
    required String userId,
    required Map<String, bool> preferences,
  }) async {
    try {
      await _client
          .from('users')
          .update({'notification_preferences': preferences})
          .eq('id', userId);
      if (_currentAppUser != null) {
        _currentAppUser = _currentAppUser!.copyWith(
          notificationPreferences: preferences,
        );
      }
    } catch (e) {
      print('updateNotificationPreferences error: $e');
      rethrow;
    }
  }

  // ─── Password change: method 1 (current password + new password) ──────────
  static Future<void> changePasswordWithCurrentPassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // Re-authenticate to verify current password
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      // Then update to new password
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      print('changePasswordWithCurrentPassword error: $e');
      rethrow;
    }
  }

  // ─── Password change: method 2 (OTP via email) ────────────────────────────
  static Future<void> sendPasswordResetOtp(String email) async {
    try {
      await _client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );
    } catch (e) {
      print('sendPasswordResetOtp error: $e');
      rethrow;
    }
  }

  static Future<void> verifyOtpAndChangePassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      await _client.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.email,
      );
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      print('verifyOtpAndChangePassword error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  REPORT LISTS
  // ══════════════════════════════════════════════════════════════

  /// Returns report lists assigned to [userId].
  /// Falls back to the authenticated user's ID if [userId] is null.
  static Future<List<ReportList>> getMyAssignedReportLists({String? userId}) async {
    try {
      final uid = userId ?? _client.auth.currentUser?.id;
      print('[ReportLists] getMyAssignedReportLists called');
      print('[ReportLists] passed userId=$userId');
      print('[ReportLists] auth.currentUser?.id=${_client.auth.currentUser?.id}');
      print('[ReportLists] using uid=$uid');
      if (uid == null) {
        print('[ReportLists] uid is null — returning empty');
        return [];
      }

      // Get active assignment IDs for this user
      final assignmentRows = await _client
          .from('report_list_assignments')
          .select('report_list_id')
          .eq('user_id', uid)
          .eq('is_active', true);

      print('[ReportLists] assignmentRows raw: $assignmentRows');

      final ids = assignmentRows
          .map<int>((r) => r['report_list_id'] as int)
          .toList();
      print('[ReportLists] assignment IDs: $ids');
      if (ids.isEmpty) {
        print('[ReportLists] no assignments found — returning empty');
        return [];
      }

      // Fetch the lists — no is_active filter here; the assignment itself
      // is the access gate and inactive lists should still be visible.
      final rows = await _client
          .from('report_lists')
          .select()
          .inFilter('id', ids)
          .order('created_at', ascending: true);

      print('[ReportLists] report_lists rows: $rows');

      final result = rows
          .map<ReportList>(
              (j) => ReportList.fromJson(j as Map<String, dynamic>))
          .toList();
      print('[ReportLists] parsed ${result.length} lists');
      return result;
    } catch (e, st) {
      print('[ReportLists] ERROR: $e');
      print('[ReportLists] STACK: $st');
      rethrow;
    }
  }

  /// Returns the latest response submitted for a given report list on a given date.
  /// Pass [forUserId] explicitly; falls back to the authenticated user's ID.
  static Future<ReportListResponse?> getMyReportListResponseForDate({
    required int reportListId,
    required DateTime date,
    String? forUserId,
  }) async {
    try {
      final userId = forUserId ?? _client.auth.currentUser?.id;
      if (userId == null) return null;
      final dateStr = date.toIso8601String().split('T')[0];
      final rows = await _client
          .from('report_list_responses')
          .select()
          .eq('report_list_id', reportListId)
          .eq('user_id', userId)
          .eq('response_date', dateStr)
          .order('submitted_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      return ReportListResponse.fromJson(rows.first as Map<String, dynamic>);
    } catch (e) {
      print('getMyReportListResponseForDate error: $e');
      return null;
    }
  }

  static Future<List<ReportListGroup>> getReportListGroups() async {
    try {
      final rows = await _client
          .from('report_list_groups')
          .select('*, report_lists(*)')
          .order('created_at', ascending: false);
      return rows
          .map<ReportListGroup>(
              (j) => ReportListGroup.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('getReportListGroups error: $e');
      rethrow;
    }
  }

  static Future<ReportListGroup> createReportListGroup({
    required String title,
    String? description,
    bool canEditSubmissions = false,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      final row = await _client
          .from('report_list_groups')
          .insert({
            'title': title,
            'description': description,
            'can_edit_submissions': canEditSubmissions,
            'is_active': true,
            'created_by': userId,
          })
          .select()
          .single();
      return ReportListGroup.fromJson(row);
    } catch (e) {
      print('createReportListGroup error: $e');
      rethrow;
    }
  }

  static Future<void> updateReportListGroup({
    required int id,
    String? title,
    String? description,
    bool? isActive,
    bool? canEditSubmissions,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (isActive != null) updates['is_active'] = isActive;
      if (canEditSubmissions != null)
        updates['can_edit_submissions'] = canEditSubmissions;
      if (updates.isEmpty) return;
      await _client.from('report_list_groups').update(updates).eq('id', id);
    } catch (e) {
      print('updateReportListGroup error: $e');
      rethrow;
    }
  }

  static Future<void> deleteReportListGroup(int id) async {
    try {
      await _client.from('report_list_groups').delete().eq('id', id);
    } catch (e) {
      print('deleteReportListGroup error: $e');
      rethrow;
    }
  }

  static Future<void> duplicateReportListGroup(int groupId) async {
    try {
      final groupData = await _client
          .from('report_list_groups')
          .select()
          .eq('id', groupId)
          .single();

      final reportLists = await _client
          .from('report_lists')
          .select()
          .eq('group_id', groupId)
          .eq('is_active', true);

      final newTitle = '${groupData['title']} (نسخة 1)';
      final newGroupResponse = await _client.from('report_list_groups').insert({
        'title': newTitle,
        'description': groupData['description'],
        'can_edit_submissions': groupData['can_edit_submissions'],
        'is_active': groupData['is_active'],
      }).select().single();

      final newGroupId = newGroupResponse['id'] as int;

      for (final rl in (reportLists as List)) {
        final newRl = await _client.from('report_lists').insert({
          'group_id': newGroupId,
          'title': rl['title'],
          'description': rl['description'],
          'fields': rl['fields'],
          'determinants': rl['determinants'],
          'schedule_type': rl['schedule_type'],
          'schedule_day_of_week': rl['schedule_day_of_week'],
          'schedule_day_of_month': rl['schedule_day_of_month'],
          'schedule_month': rl['schedule_month'],
          'schedule_date': rl['schedule_date'],
          'time_all_day': rl['time_all_day'],
          'time_start': rl['time_start'],
          'time_end': rl['time_end'],
          'can_edit_submissions': rl['can_edit_submissions'],
          'is_active': rl['is_active'],
        }).select().single();

        final assignments = await _client
            .from('report_list_assignments')
            .select('user_id')
            .eq('report_list_id', rl['id'])
            .eq('is_active', true);

        if ((assignments as List).isNotEmpty) {
          final assignedBy = _client.auth.currentUser?.id ?? '';
          await _client.from('report_list_assignments').insert(
            assignments.map<Map<String, dynamic>>((a) => {
              'report_list_id': newRl['id'],
              'user_id': a['user_id'],
              'assigned_by': assignedBy,
              'is_active': true,
            }).toList(),
          );
        }
      }
    } catch (e) {
      print('duplicateReportListGroup error: $e');
      rethrow;
    }
  }

  static Future<void> duplicateReportList(int reportListId) async {
    try {
      final data = await _client
          .from('report_lists')
          .select()
          .eq('id', reportListId)
          .single();
      final newRl = await _client.from('report_lists').insert({
        'group_id': data['group_id'],
        'title': '${data['title']} (نسخة 1)',
        'description': data['description'],
        'fields': data['fields'],
        'determinants': data['determinants'],
        'schedule_type': data['schedule_type'],
        'schedule_day_of_week': data['schedule_day_of_week'],
        'schedule_day_of_month': data['schedule_day_of_month'],
        'schedule_month': data['schedule_month'],
        'schedule_date': data['schedule_date'],
        'time_all_day': data['time_all_day'],
        'time_start': data['time_start'],
        'time_end': data['time_end'],
        'can_edit_submissions': data['can_edit_submissions'],
        'is_active': data['is_active'],
        'notification_rules': data['notification_rules'],
      }).select().single();
      final assignments = await _client
          .from('report_list_assignments')
          .select('user_id')
          .eq('report_list_id', reportListId)
          .eq('is_active', true);
      if ((assignments as List).isNotEmpty) {
        final assignedBy = _client.auth.currentUser?.id ?? '';
        await _client.from('report_list_assignments').insert(
          assignments.map<Map<String, dynamic>>((a) => {
            'report_list_id': newRl['id'],
            'user_id': a['user_id'],
            'assigned_by': assignedBy,
            'is_active': true,
          }).toList(),
        );
      }
    } catch (e) {
      print('duplicateReportList error: $e');
      rethrow;
    }
  }

  static Future<ReportList> createReportList({
    required int groupId,
    required String title,
    String? description,
    String? selectorOptionValue,
    required List<Map<String, dynamic>> determinants,
    required List<Map<String, dynamic>> fields,
    bool canEditSubmissions = false,
    required String scheduleType,
    int? scheduleDayOfWeek,
    int? scheduleDayOfMonth,
    int? scheduleMonth,
    String? scheduleDate,
    bool timeAllDay = true,
    String? timeStart,
    String? timeEnd,
    List<Map<String, dynamic>> notificationRules = const [],
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      final row = await _client
          .from('report_lists')
          .insert({
            'group_id': groupId,
            'title': title,
            'description': description,
            'selector_option_value': selectorOptionValue,
            'determinants': determinants,
            'fields': fields,
            'is_active': true,
            'can_edit_submissions': canEditSubmissions,
            'created_by': userId,
            'schedule_type': scheduleType,
            'schedule_day_of_week': scheduleDayOfWeek,
            'schedule_day_of_month': scheduleDayOfMonth,
            'schedule_month': scheduleMonth,
            'schedule_date': scheduleDate,
            'time_all_day': timeAllDay,
            'time_start': timeStart,
            'time_end': timeEnd,
            'notification_rules': notificationRules,
          })
          .select()
          .single();
      return ReportList.fromJson(row);
    } catch (e) {
      print('createReportList error: $e');
      rethrow;
    }
  }

  static Future<void> updateReportList({
    required int id,
    String? title,
    String? description,
    String? selectorOptionValue,
    List<Map<String, dynamic>>? determinants,
    List<Map<String, dynamic>>? fields,
    bool? isActive,
    bool? canEditSubmissions,
    String? scheduleType,
    int? scheduleDayOfWeek,
    int? scheduleDayOfMonth,
    int? scheduleMonth,
    String? scheduleDate,
    bool? timeAllDay,
    String? timeStart,
    String? timeEnd,
    List<Map<String, dynamic>>? notificationRules,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (selectorOptionValue != null) {
        updates['selector_option_value'] = selectorOptionValue;
      }
      if (determinants != null) updates['determinants'] = determinants;
      if (fields != null) updates['fields'] = fields;
      if (isActive != null) updates['is_active'] = isActive;
      if (canEditSubmissions != null) {
        updates['can_edit_submissions'] = canEditSubmissions;
      }
      if (scheduleType != null) updates['schedule_type'] = scheduleType;
      if (scheduleDayOfWeek != null) {
        updates['schedule_day_of_week'] = scheduleDayOfWeek;
      }
      if (scheduleDayOfMonth != null) {
        updates['schedule_day_of_month'] = scheduleDayOfMonth;
      }
      if (scheduleMonth != null) updates['schedule_month'] = scheduleMonth;
      if (scheduleDate != null) updates['schedule_date'] = scheduleDate;
      if (timeAllDay != null) updates['time_all_day'] = timeAllDay;
      if (timeStart != null) updates['time_start'] = timeStart;
      if (timeEnd != null) updates['time_end'] = timeEnd;
      if (notificationRules != null) {
        updates['notification_rules'] = notificationRules;
      }
      if (updates.isEmpty) return;
      await _client.from('report_lists').update(updates).eq('id', id);
    } catch (e) {
      print('updateReportList error: $e');
      rethrow;
    }
  }

  static Future<void> deleteReportList(int id) async {
    try {
      await _client.from('report_lists').delete().eq('id', id);
    } catch (e) {
      print('deleteReportList error: $e');
      rethrow;
    }
  }

  static Future<List<ReportListAssignment>> getReportListAssignments(
      int reportListId) async {
    try {
      final rows = await _client
          .from('report_list_assignments')
          .select()
          .eq('report_list_id', reportListId)
          .eq('is_active', true);
      return rows
          .map<ReportListAssignment>(
              (j) => ReportListAssignment.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('getReportListAssignments error: $e');
      rethrow;
    }
  }

  static Future<void> assignReportList({
    required int reportListId,
    required String reportListTitle,
    required List<String> userIds,
  }) async {
    try {
      final assignedBy = _client.auth.currentUser?.id ?? '';
      final now = DateTime.now().toIso8601String();

      // Capture existing assignments before replacing so we can notify only new ones
      final existingRows = await _client
          .from('report_list_assignments')
          .select('user_id')
          .eq('report_list_id', reportListId);
      final existingIds = Set<String>.from(
        (existingRows as List).map((r) => r['user_id'] as String),
      );
      final newUserIds = userIds.where((id) => !existingIds.contains(id)).toList();

      // Full replace
      await _client
          .from('report_list_assignments')
          .delete()
          .eq('report_list_id', reportListId);

      if (userIds.isNotEmpty) {
        final rows = userIds
            .map((uid) => {
                  'report_list_id': reportListId,
                  'user_id': uid,
                  'assigned_by': assignedBy,
                  'assigned_at': now,
                  'is_active': true,
                })
            .toList();
        await _client.from('report_list_assignments').insert(rows);
      }

      // Only notify users who were not previously assigned
      if (newUserIds.isNotEmpty) {
        await sendPushNotification(
          userIds: newUserIds,
          title: 'تم تعيين تقرير جديد 📋',
          body: 'تم تعيينك على قائمة التقارير: $reportListTitle',
          data: {'type': 'report_list_assigned', 'report_list_id': reportListId.toString()},
        );
      }
    } catch (e) {
      print('assignReportList error: $e');
      rethrow;
    }
  }

  static Future<void> removeReportListAssignment({
    required int reportListId,
    required String userId,
  }) async {
    try {
      await _client
          .from('report_list_assignments')
          .update({'is_active': false})
          .eq('report_list_id', reportListId)
          .eq('user_id', userId);
    } catch (e) {
      print('removeReportListAssignment error: $e');
      rethrow;
    }
  }

  static Future<List<ReportListResponse>> getReportListResponses(
      int reportListId) async {
    try {
      final rows = await _client
          .from('report_list_responses')
          .select()
          .eq('report_list_id', reportListId)
          .order('response_date', ascending: false);
      return rows
          .map<ReportListResponse>(
              (j) => ReportListResponse.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('getReportListResponses error: $e');
      rethrow;
    }
  }

  static Future<ReportListResponse> submitReportListResponse({
    required int reportListId,
    required DateTime responseDate,
    required Map<String, dynamic> determinantValues,
    required Map<String, String> fieldResponses,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id ?? '';
      final row = await _client
          .from('report_list_responses')
          .insert({
            'report_list_id': reportListId,
            'user_id': userId,
            'response_date': responseDate.toIso8601String().split('T')[0],
            'determinant_values': determinantValues,
            'field_responses': fieldResponses,
            'submitted_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return ReportListResponse.fromJson(row);
    } catch (e) {
      print('submitReportListResponse error: $e');
      rethrow;
    }
  }

  static Future<void> updateReportListResponse({
    required int responseId,
    required Map<String, dynamic> determinantValues,
    required Map<String, String> fieldResponses,
  }) async {
    try {
      await _client.from('report_list_responses').update({
        'determinant_values': determinantValues,
        'field_responses': fieldResponses,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', responseId);
    } catch (e) {
      print('updateReportListResponse error: $e');
      rethrow;
    }
  }

  // ── Report list draft (auto-save session) ──────────────────────────────────

  static Future<ReportListDraft?> getReportListDraft({
    required int reportListId,
    required String userId,
  }) async {
    try {
      final rows = await _client
          .from('report_list_drafts')
          .select()
          .eq('report_list_id', reportListId)
          .eq('user_id', userId)
          .limit(1);
      if (rows.isEmpty) return null;
      return ReportListDraft.fromJson(rows.first);
    } catch (e) {
      print('getReportListDraft error: $e');
      return null;
    }
  }

  static Future<void> upsertReportListDraft({
    required int reportListId,
    required String userId,
    required DateTime draftDate,
    required Map<String, dynamic> determinantValues,
    required Map<String, String> fieldResponses,
  }) async {
    try {
      await _client.from('report_list_drafts').upsert({
        'report_list_id': reportListId,
        'user_id': userId,
        'draft_date': draftDate.toIso8601String().split('T')[0],
        'determinant_values': determinantValues,
        'field_responses': fieldResponses,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'report_list_id,user_id');
    } catch (e) {
      print('upsertReportListDraft error: $e');
      rethrow;
    }
  }

  static Future<void> deleteReportListDraft({
    required int reportListId,
    required String userId,
  }) async {
    try {
      await _client
          .from('report_list_drafts')
          .delete()
          .eq('report_list_id', reportListId)
          .eq('user_id', userId);
    } catch (e) {
      print('deleteReportListDraft error: $e');
    }
  }

  static Future<void> sendReportListReminderEmails({
    required List<String> toEmails,
    required String reportListTitle,
    required String scheduleText,
  }) async {
    try {
      await _client.functions.invoke(
        'send-report-reminder',
        body: {
          'emails': toEmails,
          'report_title': reportListTitle,
          'schedule_text': scheduleText,
        },
      );
    } catch (e) {
      debugPrint('sendReportListReminderEmails error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ROLES & PERMISSIONS
  // ════════════════════════════════════════════════════════════════════════════

  /// Load the full Role (including its features) for the given user.
  static Future<Role?> getUserRole(String userId) async {
    try {
      // 1. Get role_id from users table
      final userRow = await _client
          .from('users')
          .select('role_id')
          .eq('id', userId)
          .maybeSingle();
      final roleId = userRow?['role_id'] as String?;
      if (roleId == null) return null;

      // 2. Fetch role + features
      final row = await _client
          .from('roles')
          .select('*, role_features(*)')
          .eq('id', roleId)
          .eq('is_active', true)
          .maybeSingle();
      if (row == null) return null;
      return Role.fromJson(row);
    } catch (e) {
      debugPrint('getUserRole error: $e');
      return null;
    }
  }

  /// Fetch all roles (admin use).
  static Future<List<Role>> getRoles() async {
    try {
      final rows = await _client
          .from('roles')
          .select('*, role_features(*)')
          .order('name_ar');
      return rows.map<Role>((r) => Role.fromJson(r)).toList();
    } catch (e) {
      debugPrint('getRoles error: $e');
      rethrow;
    }
  }

  /// Create a new role.  Returns the created row.
  static Future<Role> createRole({
    required String nameAr,
    String? description,
    required InterfaceType interfaceType,
  }) async {
    final row = await _client.from('roles').insert({
      'name_ar': nameAr,
      'description': description,
      'interface_type': interfaceType.name,
      'is_active': true,
    }).select('*, role_features(*)').single();
    return Role.fromJson(row);
  }

  /// Update an existing role's basic info.
  static Future<void> updateRole(
    String roleId, {
    required String nameAr,
    String? description,
    required InterfaceType interfaceType,
    required bool isActive,
  }) async {
    await _client.from('roles').update({
      'name_ar': nameAr,
      'description': description,
      'interface_type': interfaceType.name,
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', roleId);
  }

  /// Delete a role (cascades to role_features).
  static Future<void> deleteRole(String roleId) async {
    await _client.from('roles').delete().eq('id', roleId);
  }

  /// Replace all features for a role with the given list.
  static Future<void> setRoleFeatures(
      String roleId, List<RoleFeature> features) async {
    // Delete existing
    await _client.from('role_features').delete().eq('role_id', roleId);
    // Insert new (if any)
    if (features.isNotEmpty) {
      await _client.from('role_features').insert(
            features.map((f) => f.toInsertJson(roleId)).toList(),
          );
    }
  }

  /// Assign (or clear) a role for a user.
  static Future<void> assignUserRole(String userId, String? roleId) async {
    await _client
        .from('users')
        .update({'role_id': roleId}).eq('id', userId);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CUSTOM REPORTS
  // ════════════════════════════════════════════════════════════════════════════

  static Future<List<CustomReport>> getCustomReports() async {
    try {
      final rows = await _client
          .from('custom_reports')
          .select()
          .order('name_ar');
      return rows.map<CustomReport>((r) => CustomReport.fromJson(r)).toList();
    } catch (e) {
      debugPrint('getCustomReports error: $e');
      rethrow;
    }
  }

  static Future<CustomReport> createCustomReport(CustomReport report) async {
    final row = await _client
        .from('custom_reports')
        .insert(report.toUpsertJson())
        .select()
        .single();
    return CustomReport.fromJson(row);
  }

  static Future<void> updateCustomReport(CustomReport report) async {
    await _client
        .from('custom_reports')
        .update({
          ...report.toUpsertJson(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', report.id);
  }

  static Future<void> deleteCustomReport(String reportId) async {
    await _client.from('custom_reports').delete().eq('id', reportId);
  }
}
