// lib/models/returns_models.dart - COMPLETE FILE

class Item {
  final int? id;
  final String code;
  final String nameAr;
  final String? nameEn;
  final String? brandCode;
  final String? brandNameAr;
  final String? itemCategoryCode;
  final String? itemCategoryNameAr;
  final List<UnitListItem> unitList;
  final String? partNumber;
  final String? unit;
  final String? warranty;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Item({
    this.id,
    required this.code,
    required this.nameAr,
    this.nameEn,
    this.brandCode,
    this.brandNameAr,
    this.itemCategoryCode,
    this.itemCategoryNameAr,
    required this.unitList,
    this.partNumber,
    this.unit,
    this.warranty,
    this.createdAt,
    this.updatedAt,
  });

  factory Item.fromBisanJson(Map<String, dynamic> json) {
    final unitListRaw = json['unitList'] as List? ?? [];
    final unitList = unitListRaw
        .map((u) => UnitListItem.fromJson(u as Map<String, dynamic>))
        .toList();

    return Item(
      code: json['code'] as String? ?? '',
      nameAr: json['nameAR'] as String? ?? '',
      nameEn: json['name'] as String?,
      brandCode: json['brand'] as String?,
      brandNameAr: json['brand.nameAR'] as String?,
      itemCategoryCode: json['itemCategory'] as String?,
      itemCategoryNameAr: json['itemCategory.nameAR'] as String?,
      unitList: unitList,
      partNumber: json['partNumber'] as String?,
      unit: json['unit'] as String?,
      warranty: json['warranty'] as String?,
    );
  }

  factory Item.fromJson(Map<String, dynamic> json) {
    final unitListRaw = json['unit_list'] as List? ?? [];
    final unitList = unitListRaw
        .map((u) => UnitListItem.fromJson(u as Map<String, dynamic>))
        .toList();

    return Item(
      id: json['id'] as int?,
      code: json['code'] as String? ?? '',
      nameAr: json['name_ar'] as String? ?? '',
      nameEn: json['name_en'] as String?,
      brandCode: json['brand_code'] as String?,
      brandNameAr: json['brand_name_ar'] as String?,
      itemCategoryCode: json['item_category_code'] as String?,
      itemCategoryNameAr: json['item_category_name_ar'] as String?,
      unitList: unitList,
      partNumber: json['part_number'] as String?,
      unit: json['unit'] as String?,
      warranty: json['warranty'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'code': code,
      'name_ar': nameAr,
      'name_en': nameEn,
      'brand_code': brandCode,
      'brand_name_ar': brandNameAr,
      'item_category_code': itemCategoryCode,
      'item_category_name_ar': itemCategoryNameAr,
      'unit_list': unitList.map((u) => u.toJson()).toList(),
      'part_number': partNumber,
      'unit': unit,
      'warranty': warranty,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  String getDisplayName([String locale = 'ar']) {
    if (locale == 'ar') {
      return nameAr;
    }
    return nameEn ?? nameAr;
  }

  String? getPrimaryUnit() {
    if (unitList.isNotEmpty) {
      return unitList.first.unit;
    }
    return unit;
  }

  double? getPackVolume(String unitCode) {
    try {
      final unitItem = unitList.firstWhere(
        (u) => u.unit == unitCode,
      );
      return unitItem.packVolume;
    } catch (e) {
      return null;
    }
  }
}

class UnitListItem {
  final String unit;
  final double? packVolume;

  UnitListItem({
    required this.unit,
    this.packVolume,
  });

  factory UnitListItem.fromJson(Map<String, dynamic> json) {
    return UnitListItem(
      unit: json['unit'] as String? ?? '',
      packVolume: json['packVolume'] != null
          ? double.tryParse(json['packVolume'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'unit': unit,
      if (packVolume != null) 'packVolume': packVolume.toString(),
    };
  }
}

class Warehouse {
  final int? id;
  final String code;
  final String nameAr;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Warehouse({
    this.id,
    required this.code,
    required this.nameAr,
    this.createdAt,
    this.updatedAt,
  });

  factory Warehouse.fromBisanJson(Map<String, dynamic> json) {
    return Warehouse(
      code: json['code'] as String? ?? '',
      nameAr: json['nameAR'] as String? ?? '',
    );
  }

  factory Warehouse.fromJson(Map<String, dynamic> json) {
    return Warehouse(
      id: json['id'] as int?,
      code: json['code'] as String? ?? '',
      nameAr: json['name_ar'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'code': code,
      'name_ar': nameAr,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }
}

class ReturnReason {
  final String code;
  final String nameAr;

  ReturnReason({
    required this.code,
    required this.nameAr,
  });

  static List<ReturnReason> getReturnReasons() {
    return [
      ReturnReason(code: '00006', nameAr: 'تالف - خطأ مصنعي'),
      ReturnReason(code: '00005', nameAr: 'تالف - انتهاء صلاحية'),
      ReturnReason(code: '00002', nameAr: 'صالح - إرجاع بضائع صالحة'),
    ];
  }

  @override
  String toString() => nameAr;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReturnReason &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;

  /// Get warehouse code based on return reason and user's salesman
  String getWarehouseCode(String salesmanCode) {
    // Remove any leading zeros and ensure 3 digits
    final cleanSalesman = int.parse(salesmanCode).toString().padLeft(3, '0');

    if (code == '00006' || code == '00005') {
      // Damaged items (manufacturing error or expiry)
      return '2$cleanSalesman';
    } else if (code == '00002') {
      // Good items (returning good items)
      return '1$cleanSalesman';
    }

    // Default to good warehouse
    return '1$cleanSalesman';
  }

  /// Check if this is a damaged return reason
  bool get isDamagedReason => code == '00006' || code == '00005';

  /// Check if this is a good return reason
  bool get isGoodReason => code == '00002';
}

class ReturnItem {
  final String? itemCode;
  final String? itemName;
  final double quantity;
  final double price;
  final String? unit;

  ReturnItem({
    this.itemCode,
    this.itemName,
    required this.quantity,
    this.price = 1.0,
    this.unit,
  });

  Map<String, dynamic> toJson() {
    return {
      'item_code': itemCode,
      'item_name': itemName,
      'quantity': quantity,
      'price': price,
      'unit': unit,
    };
  }

  factory ReturnItem.fromJson(Map<String, dynamic> json) {
    return ReturnItem(
      itemCode: json['item_code'] as String?,
      itemName: json['item_name'] as String?,
      quantity: (json['quantity'] ?? 0).toDouble(),
      price: (json['price'] ?? 1.0).toDouble(),
      unit: json['unit'] as String?,
    );
  }

  ReturnItem copyWith({
    String? itemCode,
    String? itemName,
    double? quantity,
    double? price,
    String? unit,
  }) {
    return ReturnItem(
      itemCode: itemCode ?? this.itemCode,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      unit: unit ?? this.unit,
    );
  }

// Update toOrderDetail to handle null/zero prices
  Map<String, dynamic> toOrderDetail() {
    final details = {
      'item': itemCode,
      'quantity': quantity.toString(),
    };

    // Only add price if it's valid (not null and greater than 0)
    if (price > 0) {
      details['price'] = price.toString();
    }

    return details;
  }

// Add helper to check if item has valid price
  bool get hasValidPrice => price > 0;
}

// lib/models/returns_models.dart
class SalesReturn {
  final int? id;
  final String returnCode;
  final String contactCode;
  final String contactName;
  final DateTime returnDate;
  final String returnReasonCode;
  final String returnReasonName;
  final String warehouseCode;
  final String? warehouseName;
  final String? comment;
  final List<ReturnItem> items;
  final Map<String, dynamic>? bisanResponse;
  final String? transactionId;
  final String userId;
  final String username;
  final DateTime createdAt;
  final DateTime updatedAt;

  SalesReturn({
    this.id,
    required this.returnCode,
    required this.contactCode,
    required this.contactName,
    required this.returnDate,
    required this.returnReasonCode,
    required this.returnReasonName,
    required this.warehouseCode,
    this.warehouseName,
    this.comment,
    required this.items,
    this.bisanResponse,
    this.transactionId,
    required this.userId,
    required this.username,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SalesReturn.fromJson(Map<String, dynamic> json) {
    // Parse items from JSON
    List<ReturnItem> items = [];
    if (json['items'] != null) {
      if (json['items'] is List) {
        items = (json['items'] as List).map((item) {
          if (item is Map<String, dynamic>) {
            return ReturnItem.fromJson(item);
          } else {
            // Handle case where item is already a ReturnItem object
            return ReturnItem(
              itemCode: item['item_code'] ?? '',
              itemName: item['item_name'] ?? '',
              quantity: (item['quantity'] ?? 0).toDouble(),
              unit: item['unit'] ?? '',
              price: (item['price'] ?? 0).toDouble(),
            );
          }
        }).toList();
      }
    }

    return SalesReturn(
      id: json['id'] as int?,
      returnCode: json['return_code'] as String? ?? '',
      contactCode: json['contact_code'] as String? ?? '',
      contactName: json['contact_name'] as String? ?? '',
      returnDate: DateTime.parse(
          json['return_date'] as String? ?? DateTime.now().toString()),
      returnReasonCode: json['return_reason_code'] as String? ?? '',
      returnReasonName: json['return_reason_name'] as String? ?? '',
      warehouseCode: json['warehouse_code'] as String? ?? '',
      warehouseName: json['warehouse_name'] as String?,
      comment: json['comment'] as String?,
      items: items,
      bisanResponse: json['bisan_response'] as Map<String, dynamic>?,
      transactionId: json['transaction_id'] as String?,
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      createdAt: DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toString()),
      updatedAt: DateTime.parse(
          json['updated_at'] as String? ?? DateTime.now().toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'return_code': returnCode,
      'contact_code': contactCode,
      'contact_name': contactName,
      'return_date': returnDate.toIso8601String(),
      'return_reason_code': returnReasonCode,
      'return_reason_name': returnReasonName,
      'warehouse_code': warehouseCode,
      'warehouse_name': warehouseName,
      'comment': comment,
      'items': items.map((item) => item.toJson()).toList(),
      'bisan_response': bisanResponse,
      'transaction_id': transactionId,
      'user_id': userId,
      'username': username,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper getters
  int get itemCount => items.length;

  double get totalQuantity =>
      items.fold<double>(0, (sum, item) => sum + item.quantity);

  double get totalAmount =>
      items.fold<double>(0, (sum, item) => sum + (item.quantity * item.price));
}
