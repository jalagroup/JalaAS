// lib/models/fuel_models.dart
import 'dart:typed_data';

import 'package:intl/intl.dart';

// lib/models/fuel_contact.dart

class FuelContact {
  final int? id;
  final String code;
  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FuelContact({
    this.id,
    required this.code,
    required this.name,
    this.createdAt,
    this.updatedAt,
  });

  factory FuelContact.fromBisanJson(Map<String, dynamic> json) {
    return FuelContact(
      code: json['code'] as String,
      name: json['nameAR'] as String,
    );
  }

  factory FuelContact.fromSupabaseJson(Map<String, dynamic> json) {
    // Handle both direct object and nested response
    final contactData = json is Map<String, dynamic> ? json : {};

    return FuelContact(
      id: contactData['id'] as int?,
      code: contactData['code'] as String? ?? '',
      name: contactData['name'] as String? ?? '',
      createdAt: contactData['created_at'] != null
          ? DateTime.parse(contactData['created_at'])
          : null,
      updatedAt: contactData['updated_at'] != null
          ? DateTime.parse(contactData['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'code': code,
      'name': name,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  Map<String, dynamic> toSupabaseInsert() {
    return {
      'code': code,
      'name': name,
    };
  }
}

class CostCenter {
  final int id;
  final String code;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  CostCenter({
    required this.id,
    required this.code,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CostCenter.fromJson(Map<String, dynamic> json) {
    try {
      return CostCenter(
        id: json['id'] as int,
        code: json['code'] as String? ?? '', // Handle potential null
        name: json['name'] as String? ?? '', // Handle potential null
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : DateTime.now(),
      );
    } catch (e) {
      print('Error parsing CostCenter JSON: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  factory CostCenter.fromBisanJson(Map<String, dynamic> json) {
    return CostCenter(
      id: 0, // Will be set by database
      code: json['code'] as String,
      name: json['name'] as String,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class AssignCostCenter {
  final int id;
  final String number;
  final int costCenterId;
  final int? fuelTypeId; // Keep as nullable
  final CostCenter? costCenter;
  final FuelType? fuelType; // Keep as nullable
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AssignCostCenter({
    required this.id,
    required this.number,
    required this.costCenterId,
    this.fuelTypeId, // Nullable
    this.costCenter,
    this.fuelType, // Nullable
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AssignCostCenter.fromJson(Map<String, dynamic> json) {
    try {
      print('Parsing AssignCostCenter JSON: ${json}');

      // Parse each field individually with null checks
      final id = json['id'] as int;
      print('✓ ID parsed: $id');

      final number = json['number'] as String;
      print('✓ Number parsed: $number');

      final costCenterId = json['cost_center_id'] as int;
      print('✓ Cost Center ID parsed: $costCenterId');

      final fuelTypeId = json['fuel_type_id'] as int?;
      print('✓ Fuel Type ID parsed: $fuelTypeId');

      final createdBy = json['created_by'] as String?;
      print('✓ Created By parsed: $createdBy');

      final createdAt = DateTime.parse(json['created_at']);
      print('✓ Created At parsed: $createdAt');

      final updatedAt = DateTime.parse(json['updated_at']);
      print('✓ Updated At parsed: $updatedAt');

      // Parse nested objects
      CostCenter? costCenter;
      if (json['cost_center'] != null) {
        print('Parsing CostCenter: ${json['cost_center']}');
        costCenter = CostCenter.fromJson(json['cost_center']);
        print('✓ Cost Center parsed: ${costCenter.name}');
      }

      FuelType? fuelType;
      if (json['fuel_type'] != null) {
        print('Parsing FuelType: ${json['fuel_type']}');
        fuelType = FuelType.fromJson(json['fuel_type']);
        print('✓ Fuel Type parsed: ${fuelType.name}');
      }

      return AssignCostCenter(
        id: id,
        number: number,
        costCenterId: costCenterId,
        fuelTypeId: fuelTypeId,
        costCenter: costCenter,
        fuelType: fuelType,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } catch (e) {
      print('Error parsing AssignCostCenter JSON: $e');
      print('JSON data: $json');
      rethrow;
    }
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'cost_center_id': costCenterId,
      'fuel_type_id': fuelTypeId,
      'cost_center': costCenter?.toJson(),
      'fuel_type': fuelType?.toJson(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// Updated DateRangeFilter class to include truck range
class DateRangeFilter {
  final DateTime fromDate;
  final DateTime toDate;
  final String? fromTruckNumber;
  final String? toTruckNumber;

  DateRangeFilter({
    required this.fromDate,
    required this.toDate,
    this.fromTruckNumber,
    this.toTruckNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'fromDate': fromDate.toIso8601String(),
      'toDate': toDate.toIso8601String(),
      'fromTruckNumber': fromTruckNumber,
      'toTruckNumber': toTruckNumber,
    };
  }

  factory DateRangeFilter.fromJson(Map<String, dynamic> json) {
    return DateRangeFilter(
      fromDate: DateTime.parse(json['fromDate']),
      toDate: DateTime.parse(json['toDate']),
      fromTruckNumber: json['fromTruckNumber'],
      toTruckNumber: json['toTruckNumber'],
    );
  }

  bool hasTruckRange() {
    return fromTruckNumber?.isNotEmpty == true ||
        toTruckNumber?.isNotEmpty == true;
  }

  String get description {
    String dateRange =
        'من ${DateFormat('dd/MM/yyyy').format(fromDate)} إلى ${DateFormat('dd/MM/yyyy').format(toDate)}';

    if (hasTruckRange()) {
      String truckRange = '';
      if (fromTruckNumber?.isNotEmpty == true &&
          toTruckNumber?.isNotEmpty == true) {
        truckRange = ' - الشاحنات من $fromTruckNumber إلى $toTruckNumber';
      } else if (fromTruckNumber?.isNotEmpty == true) {
        truckRange = ' - الشاحنات من $fromTruckNumber فما فوق';
      } else if (toTruckNumber?.isNotEmpty == true) {
        truckRange = ' - الشاحنات حتى $toTruckNumber';
      }
      dateRange += truckRange;
    }

    return dateRange;
  }
}

class FuelType {
  final int id;
  final String code;
  final String name;
  final double price;
  final DateTime createdAt;
  final DateTime updatedAt;

  FuelType({
    required this.id,
    required this.code,
    required this.name,
    required this.price,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FuelType.fromJson(Map<String, dynamic> json) {
    try {
      return FuelType(
        id: json['id'] as int,
        code: json['code'] as String? ?? '', // Handle potential null
        name: json['name'] as String? ?? '', // Handle potential null
        price:
            (json['price'] as num?)?.toDouble() ?? 0.0, // Handle potential null
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : DateTime.now(),
      );
    } catch (e) {
      print('Error parsing FuelType JSON: $e');
      print('JSON data: $json');
      rethrow;
    }
  }
  factory FuelType.fromBisanJson(Map<String, dynamic> json) {
    double price = 0.0;
    if (json['itemPrice'] != null && json['itemPrice'] is List) {
      final priceList = json['itemPrice'] as List;
      if (priceList.isNotEmpty) {
        final priceData = priceList.first;
        if (priceData['price'] != null) {
          price = double.parse(priceData['price'].toString());
        }
      }
    }

    return FuelType(
      id: 0, // Will be set by database
      code: json['code'] as String,
      name: json['name'] as String,
      price: price,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'price': price,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// Update FuelFillingRecord class to include fuel contact
class FuelFillingRecord {
  final int id;
  final DateTime fillingDate;
  final String truckNumber;
  final int assignCostCenterId;
  final int fuelTypeId;
  final double amount;
  final double quantity;
  final String? meterReading;
  final String? imageUrl;
  final String? imageName;
  final int? imageSize;
  final String? mimeType;
  final String userId;
  final int? fuelContactId; // NEW
  final String? fuelContactCode; // NEW
  final DateTime createdAt;
  final DateTime updatedAt;
  final FuelType? fuelType;
  final AssignCostCenter? assignCostCenter;
  final FuelContact? fuelContact; // NEW

  FuelFillingRecord({
    required this.id,
    required this.fillingDate,
    required this.truckNumber,
    required this.assignCostCenterId,
    required this.fuelTypeId,
    required this.amount,
    required this.quantity,
    this.meterReading,
    this.imageUrl,
    this.imageName,
    this.imageSize,
    this.mimeType,
    required this.userId,
    this.fuelContactId, // NEW
    this.fuelContactCode, // NEW
    required this.createdAt,
    required this.updatedAt,
    this.fuelType,
    this.assignCostCenter,
    this.fuelContact, // NEW
  });

  factory FuelFillingRecord.fromJson(Map<String, dynamic> json) {
    return FuelFillingRecord(
      id: json['id'] as int,
      fillingDate: DateTime.parse(json['filling_date']),
      truckNumber: json['truck_number'] as String,
      assignCostCenterId: json['assign_cost_center_id'] as int,
      fuelTypeId: json['fuel_type_id'] as int,
      amount: (json['amount'] is String)
          ? double.parse(json['amount'])
          : (json['amount'] as num).toDouble(),
      quantity: (json['quantity'] is String)
          ? double.parse(json['quantity'])
          : (json['quantity'] as num?)?.toDouble() ?? 0.0,
      meterReading: json['meter_reading'] as String?,
      imageUrl: json['image_url'] as String?,
      imageName: json['image_name'] as String?,
      imageSize: json['image_size'] as int?,
      mimeType: json['mime_type'] as String?,
      userId: json['user_id'] as String,
      fuelContactId: json['fuel_contact_id'] as int?,
      fuelContactCode: json['fuel_contact_code'] as String?,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      fuelType: json['fuel_type'] != null
          ? FuelType.fromJson(json['fuel_type'])
          : null,
      assignCostCenter: json['assign_cost_center'] != null
          ? AssignCostCenter.fromJson(json['assign_cost_center'])
          : null,
      fuelContact: json['fuel_contact'] != null
          ? FuelContact.fromSupabaseJson(json['fuel_contact'])
          : null,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// Updated CostCenterStatistics class
class CostCenterStatistics {
  final String costCenterCode;
  final String costCenterName;
  final String truckNumber;
  final double totalAmount;
  final double totalQuantity; // NEW FIELD
  final int recordCount;

  CostCenterStatistics({
    required this.costCenterCode,
    required this.costCenterName,
    required this.truckNumber,
    required this.totalAmount,
    required this.totalQuantity, // NEW FIELD
    required this.recordCount,
  });

  factory CostCenterStatistics.fromJson(Map<String, dynamic> json) {
    return CostCenterStatistics(
      costCenterCode: json['cost_center_code'] as String,
      costCenterName: json['cost_center_name'] as String,
      truckNumber: json['truck_number'] as String,
      totalAmount: (json['total_amount'] is String)
          ? double.parse(json['total_amount'])
          : (json['total_amount'] as num).toDouble(),
      totalQuantity: (json['total_quantity'] is String) // NEW FIELD
          ? double.parse(json['total_quantity'])
          : (json['total_quantity'] as num?)?.toDouble() ?? 0.0,
      recordCount: json['record_count'] as int,
    );
  }
}

// NEW: User fuel statistics model
class UserFuelStatistics {
  final String userId;
  final String username;
  final double totalAmount;
  final double totalQuantity;
  final int recordCount;

  UserFuelStatistics({
    required this.userId,
    required this.username,
    required this.totalAmount,
    required this.totalQuantity,
    required this.recordCount,
  });

  factory UserFuelStatistics.fromJson(Map<String, dynamic> json) {
    return UserFuelStatistics(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      totalAmount: (json['total_amount'] is String)
          ? double.parse(json['total_amount'])
          : (json['total_amount'] as num).toDouble(),
      totalQuantity: (json['total_quantity'] is String)
          ? double.parse(json['total_quantity'])
          : (json['total_quantity'] as num).toDouble(),
      recordCount: json['record_count'] as int,
    );
  }
}

// Updated JournalVoucherData class to include contactNumber
class JournalVoucherData {
  final String contactNumber;
  final String taxReference;
  final DateTime invoiceDate;
  final String notes;

  JournalVoucherData({
    required this.contactNumber,
    required this.taxReference,
    required this.invoiceDate,
    required this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'contactNumber': contactNumber,
      'taxReference': taxReference,
      'invoiceDate': invoiceDate.toIso8601String(),
      'notes': notes,
    };
  }

  factory JournalVoucherData.fromJson(Map<String, dynamic> json) {
    return JournalVoucherData(
      contactNumber: json['contactNumber'] ?? '',
      taxReference: json['taxReference'] ?? '',
      invoiceDate: DateTime.parse(json['invoiceDate']),
      notes: json['notes'] ?? '',
    );
  }
}
