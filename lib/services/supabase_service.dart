// lib/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart';
import '../models/contact.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://ykwnsmyvkwjctidhoqib.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlrd25zbXl2a3dqY3RpZGhvcWliIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExOTkzMzYsImV4cCI6MjA2Njc3NTMzNn0.W6WYYc-s24kX2H_-9bvWe1nG31lDlFCSVnDSqIKD5xk',
    );
  }

  // Auth methods
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
    required String salesman,
    String? area,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'salesman': salesman,
          'area': area,
        },
      );

      if (response.user != null) {
        // Wait a bit for the trigger to create the user profile
        await Future.delayed(const Duration(milliseconds: 500));

        // Try to update the user profile if it was created by trigger
        try {
          await _client.from('users').update({
            'username': username,
            'area': area,
            'salesman': salesman,
            'email': email,
            'user_type': 'user',
            'is_active': false,
          }).eq('id', response.user!.id);
        } catch (e) {
          // If update fails, try to insert
          try {
            await _client.from('users').insert({
              'id': response.user!.id,
              'username': username,
              'area': area,
              'salesman': salesman,
              'email': email,
              'user_type': 'user',
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

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('SignIn error: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      print('SignOut error: $e');
      rethrow;
    }
  }

  static Future<AppUser?> getCurrentUser() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final response =
          await _client.from('users').select().eq('id', user.id).single();

      return AppUser.fromJson(response);
    } catch (e) {
      print('getCurrentUser error: $e');
      return null;
    }
  }

  static User? get currentAuthUser => _client.auth.currentUser;

  // Users management
  static Future<List<AppUser>> getUsers() async {
    try {
      final response = await _client
          .from('users')
          .select()
          .order('created_at', ascending: false);

      return response.map<AppUser>((json) => AppUser.fromJson(json)).toList();
    } catch (e) {
      print('getUsers error: $e');
      rethrow;
    }
  }

  static Future<void> createUser({
    required String username,
    required String email,
    required String password,
    required String salesman,
    String? area,
  }) async {
    try {
      // Use regular signup instead of admin.createUser
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'salesman': salesman,
          'area': area,
        },
      );

      if (response.user != null) {
        // Wait for trigger to create user profile
        await Future.delayed(const Duration(milliseconds: 500));

        // Insert/update user profile
        await _client.from('users').upsert({
          'id': response.user!.id,
          'username': username,
          'area': area,
          'salesman': salesman,
          'email': email,
          'user_type': 'user',
          'is_active': false, // Admin needs to activate
        });

        // Sign out the newly created user so they don't auto-login
        await _client.auth.signOut();
      }
    } catch (e) {
      print('createUser error: $e');
      rethrow;
    }
  }

  static Future<void> updateUser({
    required String userId,
    String? username,
    String? area,
    String? salesman,
    String? email,
    bool? isActive,
  }) async {
    try {
      final Map<String, dynamic> updates = {};

      if (username != null) updates['username'] = username;
      if (area != null) updates['area'] = area;
      if (salesman != null) updates['salesman'] = salesman;
      if (email != null) updates['email'] = email;
      if (isActive != null) updates['is_active'] = isActive;

      if (updates.isNotEmpty) {
        await _client.from('users').update(updates).eq('id', userId);
      }
    } catch (e) {
      print('updateUser error: $e');
      rethrow;
    }
  }

  static Future<void> deleteUser(String userId) async {
    try {
      await _client.from('users').delete().eq('id', userId);
      await _client.auth.admin.deleteUser(userId);
    } catch (e) {
      print('deleteUser error: $e');
      rethrow;
    }
  }

// Replace your getUserContacts method with this pagination-based approach
// lib/services/supabase_service.dart

  static Future<List<Contact>> getUserContacts({
    required String salesman,
    String? area,
    String? search,
  }) async {
    try {
      print(
          'DEBUG: getUserContacts called with salesman: "$salesman", area: "$area"');

      bool isAdminUser = (salesman == '00' || salesman.isEmpty) &&
          (area == '00' || area == null || area.isEmpty);

      print('DEBUG: Is admin user in getUserContacts: $isAdminUser');

      if (isAdminUser) {
        print('DEBUG: Admin user - using pagination to get all contacts');
        return await _getAllContactsWithPagination(search: search);
      } else {
        print('DEBUG: Regular user - applying filters');
        return await _getFilteredContacts(
          salesman: salesman,
          area: area,
          search: search,
        );
      }
    } catch (e) {
      print('getUserContacts error: $e');
      rethrow;
    }
  }

// Private method to get all contacts using pagination (for admin users)
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

        // Get page with range
        final response = await query
            .range(page * pageSize, (page + 1) * pageSize - 1)
            .order('name_ar', ascending: true);

        final pageContacts =
            response.map<Contact>((json) => Contact.fromJson(json)).toList();
        allContacts.addAll(pageContacts);

        print(
            'DEBUG: Page ${page + 1}: loaded ${pageContacts.length} contacts (total: ${allContacts.length})');

        // If we got fewer than pageSize, we've reached the end
        hasMore = pageContacts.length == pageSize;
        page++;

        // Safety check to prevent infinite loops
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

// Private method to get filtered contacts (for regular users)
  static Future<List<Contact>> _getFilteredContacts({
    required String salesman,
    String? area,
    String? search,
  }) async {
    var query = _client.from('contacts').select();

    // Apply salesman filter
    query = query.eq('salesman', salesman);

    // Apply area filter if provided
    if (area != null && area.isNotEmpty && area != '00') {
      query = query.eq('area', area);
      print('DEBUG: Applied area filter: $area');
    }

    // Apply search filter if provided
    if (search != null && search.isNotEmpty) {
      query = query.or('name_ar.ilike.%$search%,code.ilike.%$search%');
    }

    // For regular users, we might still need pagination if they have many contacts
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

      // Safety check
      if (page > 10)
        break; // Regular users shouldn't have more than 10k contacts
    }

    return allContacts;
  }

// Update getContacts method to also use pagination
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

// Test method to verify pagination is working
  static Future<void> testPagination() async {
    try {
      print('=== TESTING PAGINATION ===');

      // Get total count
      int totalCount = await getTotalContactsCount();
      print('DEBUG: Database reports $totalCount total contacts');

      // Test pagination
      List<Contact> paginatedContacts = await _getAllContactsWithPagination();
      print('DEBUG: Pagination loaded ${paginatedContacts.length} contacts');

      // Compare
      if (paginatedContacts.length == totalCount) {
        print('✅ SUCCESS: All contacts loaded via pagination');
      } else {
        print(
            '⚠️  WARNING: Expected $totalCount, got ${paginatedContacts.length}');
      }

      print('=== END TEST ===');
    } catch (e) {
      print('DEBUG: Test failed: $e');
    }
  }

  static Future<void> syncContacts(List<Contact> contacts) async {
    try {
      // Delete all existing contacts
      await _client.from('contacts').delete().neq('id', 0);

      // Insert new contacts in batches
      const batchSize = 100;
      for (int i = 0; i < contacts.length; i += batchSize) {
        final batch = contacts.skip(i).take(batchSize).map((contact) {
          final json = contact.toJson();
          json.remove('id'); // Remove id to let database auto-generate

          // Ensure all required fields have values
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
}
