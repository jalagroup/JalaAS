// lib/models/user.dart - Updated with Quality Controller support

import 'package:jala_as/models/periodic_sales_report.dart';
import 'package:jala_as/services/supabase_service.dart';

import '../services/api_service.dart';
import 'salesman.dart';

// Add to lib/models/user.dart
// Update lib/models/user.dart

class AppUser {
  final String id;
  final String username;
  final String? area;
  final String salesman;
  final String email;
  final String userType;
  final bool isActive;
  final String? periodicAreaAssignment;
  final String? salesAdmin;
  final double initialSalary;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String>? additionalContactCodes;
  final bool canSeeAllQualityForms;
  final Map<String, bool>? notificationPreferences;
  final String? positionId;
  final String? positionName;
  /// Non-null when the user has a role assigned from the roles table.
  final String? roleId;

  AppUser({
    required this.id,
    required this.username,
    this.area,
    required this.salesman,
    required this.email,
    required this.userType,
    required this.isActive,
    this.periodicAreaAssignment,
    this.salesAdmin,
    this.initialSalary = 0,
    required this.createdAt,
    required this.updatedAt,
    this.additionalContactCodes,
    this.canSeeAllQualityForms = false,
    this.notificationPreferences,
    this.positionId,
    this.positionName,
    this.roleId,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      username: json['username'] as String,
      area: json['area'] as String?,
      salesman: json['salesman'] as String,
      email: json['email'] as String,
      userType: json['user_type'] as String,
      isActive: json['is_active'] as bool,
      periodicAreaAssignment: json['periodic_area_assignment'] as String?,
      salesAdmin: json['sales_admin'] as String?, // NEW FIELD
      initialSalary: json['initial_salary'] != null
          ? double.parse(json['initial_salary'].toString())
          : 0, // NEW FIELD
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      additionalContactCodes: json['additional_contact_codes'] != null
          ? List<String>.from(json['additional_contact_codes'])
          : null,
      canSeeAllQualityForms: json['can_see_all_quality_forms'] as bool? ?? false,
      notificationPreferences: json['notification_preferences'] != null
          ? Map<String, bool>.from(
              (json['notification_preferences'] as Map<String, dynamic>)
                  .map((k, v) => MapEntry(k, v as bool? ?? true)))
          : null,
      positionId: json['position_id'] as String?,
      positionName: json['positions'] != null
          ? (json['positions'] as Map<String, dynamic>)['name'] as String?
          : null,
      roleId: json['role_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'area': area,
      'salesman': salesman,
      'email': email,
      'user_type': userType,
      'is_active': isActive,
      'periodic_area_assignment': periodicAreaAssignment,
      'sales_admin': salesAdmin, // NEW FIELD
      'initial_salary': initialSalary, // NEW FIELD
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'additional_contact_codes': additionalContactCodes,
      'can_see_all_quality_forms': canSeeAllQualityForms,
      'notification_preferences': notificationPreferences,
      'position_id': positionId,
    };
  }

  // NEW: Get effective salesman code - returns empty string for sales managers
  String get effectiveSalesman {
    if (isSalesAdmin) {
      if (salesAdmin != null && salesAdmin!.isNotEmpty) {
        return salesAdmin!; // Sales admin with specific code
      }
      return ''; // Sales manager (salesman = '00' with no salesAdmin)
    }
    return salesman; // Regular user
  }

  // NEW: Check if user is sales manager (salesman = '00' with no salesAdmin)
  bool get isSalesManager =>
      isSalesAdmin && (salesAdmin == null || salesAdmin!.isEmpty);

  // NEW: Check if user is actual salesman (has valid salesman code for API)
  bool get isActualSalesman => effectiveSalesman.isNotEmpty;

  // NEW: Get users in my group (users I can manage)
  List<String> getUsersInGroup(List<AppUser> allUsers) {
    if (isSalesManager) {
      // Sales manager can see all salesmen
      return allUsers
          .where((u) => u.isRegularUser || u.isSalesAdmin)
          .map((u) => u.id)
          .toList();
    } else if (isSalesAdmin && salesAdmin != null) {
      // Sales admin can see users with matching salesman
      return allUsers
          .where((u) =>
              u.isRegularUser &&
              (u.salesman == salesAdmin ||
                  (u.area != null &&
                      availableSalesmenCodes.contains(u.salesman))))
          .map((u) => u.id)
          .toList();
    }
    return [];
  }

  // NEW METHOD: Check if user can see this contact
  bool canSeeContact(String contactSalesman, String contactCode) {
    // System admin can see all
    if (isSystemAdmin) return true;

    // Sales admin can see all
    if (isSalesAdmin) return true;

    // Quality controller can see all
    if (isQualityController) return true;

    // Regular user: check default salesman or additional contacts
    if (isRegularUser) {
      // Default visibility by salesman
      if (contactSalesman == salesman) return true;

      // Check additional contacts
      if (additionalContactCodes != null &&
          additionalContactCodes!.contains(contactCode)) {
        return true;
      }
    }

    return false;
  }

  // Rest of existing code...
  bool get isSystemAdmin => userType == 'admin';
  bool get isSalesAdmin => userType == 'user' && salesman == '00';
  bool get isQualityController => userType == 'quality_controller';
  bool get isQualityControlAdmin => userType == 'quality_control_admin';
  bool get isSalesOfficer => userType == 'sales_officer'; // NEW

  bool get isRegularUser =>
      userType == 'user' && salesman != '00' && salesman != '000';
  bool get isAdmin => isSystemAdmin || isSalesAdmin;

  // Get assigned area for periodic reports
  AreaSelection get assignedPeriodicAreaSelection {
    if (!isSalesAdmin) return AreaSelection.all;

    switch (periodicAreaAssignment) {
      case 'north':
        return AreaSelection.north;
      case 'south':
        return AreaSelection.south;
      case 'all':
      default:
        return AreaSelection.all;
    }
  }

  // Check if user can change periodic area selection
  bool get canChangePeriodicAreaSelection {
    return !isSalesAdmin; // Only non-sales admins can change area
  }

  // Check if sales admin can choose between area options
  bool get canChoosePeriodicAreaSelection {
    if (!isSalesAdmin) return true; // Regular users can always choose

    // Sales admins can only choose if they have 'all' areas assigned
    return periodicAreaAssignment == null ||
        periodicAreaAssignment == 'all' ||
        periodicAreaAssignment!.isEmpty;
  }

  // Get the fixed area selection for restricted sales admins
  AreaSelection get fixedPeriodicAreaSelection {
    if (canChoosePeriodicAreaSelection) return AreaSelection.all;

    switch (periodicAreaAssignment) {
      case 'north':
        return AreaSelection.north;
      case 'south':
        return AreaSelection.south;
      default:
        return AreaSelection.all;
    }
  }

  String get effectiveSalesmanForBisan {
    String code;

    if (salesman == '00') {
      // Sales admin or manager
      if (salesAdmin != null && salesAdmin!.isNotEmpty) {
        // Sales admin with code
        code = salesAdmin!;
      } else {
        // Sales manager - no code
        return '';
      }
    } else {
      // Regular user
      code = salesman;
    }

    // Format to 3 digits
    final numCode = int.tryParse(code);
    if (numCode != null) {
      return numCode.toString().padLeft(3, '0');
    }

    return code.padLeft(3, '0');
  }

  /// Check if user should be fetched from Bisan (has valid salesman code)
  bool get shouldFetchFromBisan {
    if (salesman == '00') {
      // Only fetch if sales admin (has salesAdmin code), not sales manager
      return salesAdmin != null && salesAdmin!.isNotEmpty;
    }
    return true; // Regular users always fetch
  }

  /// Get users that this sales admin can manage (based on groups)
  Future<List<String>> getSalesmenInMyGroup() async {
    if (!isSalesAdmin || salesAdmin == null || salesAdmin!.isEmpty) {
      return [];
    }

    return await SupabaseService.getSalesmenInAdminGroup(salesAdmin!);
  }

  // Get display text for the assigned periodic area
  String get periodicAreaDisplayText {
    switch (periodicAreaAssignment) {
      case 'north':
        return 'مناطق الشمال';
      case 'south':
        return 'مناطق الجنوب';
      case 'all':
      default:
        return 'كل المناطق';
    }
  }

  // Get periodic area display text for sales admin
  String get assignedPeriodicAreaDisplayText {
    if (!isSalesAdmin) return '';

    switch (assignedPeriodicAreaSelection) {
      case AreaSelection.north:
        return 'مناطق الشمال';
      case AreaSelection.south:
        return 'مناطق الجنوب';
      case AreaSelection.all:
      default:
        return 'كل المناطق';
    }
  }

  // New method to get available salesmen codes for sales admin users
  List<String> get availableSalesmenCodes {
    if (isRegularUser)
      return [salesman]; // Regular users only have their own salesman
    if (isSystemAdmin) {
      // System admin has access to all salesmen
      return ApiService.getAvailableSalesmen().map((s) => s.code).toList();
    }
    if (isSalesAdmin) {
      if (area == null || area!.isEmpty || area == '00') {
        // Sales admin with full access - return all salesman codes
        return ApiService.getAvailableSalesmen().map((s) => s.code).toList();
      }
      // Sales admin with restricted access - parse area value
      return _parseSalesmenFromArea(area!);
    }
    if (isQualityController) {
      // Quality controllers don't have salesman codes
      return [];
    }

    return [];
  }

  // Add these methods to the AppUser class

// Super admin - can see everything (salesman = '0')
  bool get isSuperAdmin => isSystemAdmin && salesman == '0';

// Quality admin - only quality management (salesman = '1')
  bool get isQualityAdmin => isSystemAdmin && salesman == '1';

// Fuel admin - only fuel management (salesman = '2')
  bool get isFuelAdmin => isSystemAdmin && salesman == '2';

// Check if admin has access to user management
  bool get canAccessUserManagement => isSuperAdmin;

// Check if admin has access to quality management
  bool get canAccessQualityManagement => isSuperAdmin || isQualityAdmin;

// Check if admin has access to fuel management
  bool get canAccessFuelManagement => isSuperAdmin || isFuelAdmin;

// Check if admin has access to sync data
  bool get canAccessSyncData => isSuperAdmin;

// Get admin type display text
  String get adminTypeDisplayText {
    if (isSuperAdmin) return 'مدير عام';
    if (isQualityAdmin) return 'مدير مراقبة الجودة';
    if (isFuelAdmin) return 'مدير المحروقات';
    return userTypeDisplayText;
  }

  // Helper method to parse salesman codes from area value
  List<String> _parseSalesmenFromArea(String areaValue) {
    if (areaValue == '00' || areaValue.isEmpty) return [];

    List<String> salesmen = [];
    // Split the area value into 3-character chunks
    for (int i = 0; i < areaValue.length; i += 3) {
      if (i + 3 <= areaValue.length) {
        String salesmanCode = areaValue.substring(i, i + 3);
        salesmen.add(salesmanCode);
      }
    }
    return salesmen;
  }

  // Check if sales admin has full access
  bool get hasFullSalesAdminAccess =>
      isSalesAdmin && (area == null || area!.isEmpty || area == '00');

  // Get display text for admin's available salesmen
  String get adminSalesmenDisplayText {
    if (isRegularUser) return 'مندوب محدد: $salesman';
    if (isSystemAdmin) return 'جميع المندوبين (مدير النظام)';
    if (isQualityController) return 'مراقب جودة';

    if (isSalesAdmin) {
      if (hasFullSalesAdminAccess) return 'جميع المندوبين';

      final codes = availableSalesmenCodes;
      if (codes.isEmpty) return 'لا يوجد مندوبين متاحين';

      final salesmen = ApiService.getAvailableSalesmen();
      return codes.map((code) {
        final salesman = salesmen.firstWhere(
          (s) => s.code == code,
          orElse: () => Salesman(code: code, name: 'غير معروف'),
        );
        return '${salesman.name} ($code)';
      }).join(', ');
    }

    return '';
  }

  String get userTypeDisplayText {
    switch (userType) {
      case 'admin':
        return 'مدير النظام';
      case 'sales_officer':
        return 'ضابط مبيعات';
      case 'quality_controller':
        return 'مراقب جودة';
      case 'quality_control_admin':
        return 'مدير مراقبة الجودة';          // NEW
      case 'quality_control_inspector':
        return 'مفتش مراقبة الجودة';           // NEW
      case 'user':
        return isSalesAdmin ? 'مدير مبيعات' : 'مستخدم عادي';
      default:
        return userType;
    }
  }

  AppUser copyWith({
    String? id,
    String? username,
    String? area,
    String? salesman,
    String? email,
    String? userType,
    bool? isActive,
    String? periodicAreaAssignment,
    String? salesAdmin,
    double? initialSalary,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? additionalContactCodes,
    bool? canSeeAllQualityForms,
    Map<String, bool>? notificationPreferences,
    String? positionId,
    String? positionName,
    String? roleId,
  }) {
    return AppUser(
      id: id ?? this.id,
      username: username ?? this.username,
      area: area ?? this.area,
      salesman: salesman ?? this.salesman,
      email: email ?? this.email,
      userType: userType ?? this.userType,
      isActive: isActive ?? this.isActive,
      periodicAreaAssignment:
          periodicAreaAssignment ?? this.periodicAreaAssignment,
      salesAdmin: salesAdmin ?? this.salesAdmin,
      initialSalary: initialSalary ?? this.initialSalary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      additionalContactCodes:
          additionalContactCodes ?? this.additionalContactCodes,
      canSeeAllQualityForms:
          canSeeAllQualityForms ?? this.canSeeAllQualityForms,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,
      positionId: positionId ?? this.positionId,
      positionName: positionName ?? this.positionName,
      roleId: roleId ?? this.roleId,
    );
  }
}
