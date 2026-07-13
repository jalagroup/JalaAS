// lib/models/warehouse_models.dart - Warehouse Transfer System Models

class WarehouseType {
  static const String good = 'مخزن الصالح'; // Warehouse prefix: 1
  static const String damaged = 'مخزن التالف'; // Warehouse prefix: 2
  static const String main = 'مخزن رئيسي'; // Main warehouse
}

class StockItem {
  final String itemCode;
  final String itemName;
  final String warehouse;
  final String unit;
  final String partNumber;
  final double beginBalance;
  final double endBalance;
  final double rptQntIn;
  final double rptQntOut;
  final double change;
  final String count;
  final String packVolume;

  StockItem({
    required this.itemCode,
    required this.itemName,
    required this.warehouse,
    required this.unit,
    required this.partNumber,
    required this.beginBalance,
    required this.endBalance,
    required this.rptQntIn,
    required this.rptQntOut,
    required this.change,
    required this.count,
    required this.packVolume,
  });

  factory StockItem.fromJson(Map<String, dynamic> json) {
    return StockItem(
      itemCode: json['item'] ?? '',
      itemName: json['item.name'] ?? '',
      warehouse: json['warehouse'] ?? '',
      unit: json['item.reportUnit'] ?? '',
      partNumber: json['partNumber'] ?? '',
      beginBalance: _parseDouble(json['begBalance']),
      endBalance: _parseDouble(json['endBalance']),
      rptQntIn: _parseDouble(json['rptQntIn']),
      rptQntOut: _parseDouble(json['rptQntOut']),
      change: _parseDouble(json['change']),
      count: json['count']?.toString() ?? '',
      packVolume: json['packVolume']?.toString() ?? '',
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null || value == '') return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      // Remove commas and parse
      String cleaned = value.replaceAll(',', '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  bool get isAvailable => endBalance > 0;

  Map<String, dynamic> toJson() {
    return {
      'item_code': itemCode,
      'item_name': itemName,
      'warehouse': warehouse,
      'unit': unit,
      'part_number': partNumber,
      'begin_balance': beginBalance,
      'end_balance': endBalance,
      'rpt_qnt_in': rptQntIn,
      'rpt_qnt_out': rptQntOut,
      'change': change,
      'count': count,
      'pack_volume': packVolume,
    };
  }
}

class TransferItem {
  final String itemCode;
  final String itemName;
  final String unit;
  final double availableQuantity;
  double requestedQuantity;

  TransferItem({
    required this.itemCode,
    required this.itemName,
    required this.unit,
    required this.availableQuantity,
    this.requestedQuantity = 0.0,
  });

  bool get isValid =>
      requestedQuantity > 0 && requestedQuantity <= availableQuantity;

  Map<String, dynamic> toOrderDetail() {
    return {
      'item': itemCode,
      'quantity': requestedQuantity.toStringAsFixed(2),
      'desc': itemName,
    };
  }
}

enum TransferStatus {
  pending,
  approved,
  rejected,
  completed,
}

// Add these fields to your WarehouseTransferRequest class

class WarehouseTransferRequest {
  final int? id;
  final String requesterId;
  final String requesterName;
  final String? targetUserId;
  final String? targetUserName;
  final String sourceWarehouse;
  final String targetWarehouse;
  final String warehouseType;
  final List<TransferItem> items;
  final TransferStatus status;
  final String? comment;
  final DateTime requestDate;
  final DateTime? approvedDate;
  final DateTime? completedDate;
  final String? bisanTransactionId;
  final String? receiptTransactionId;
  final String? docDate;
  final String? reverseIssueCode; // NEW FIELD
  final String? reverseReceiptTransactionId; // NEW FIELD
  final DateTime createdAt;
  final DateTime updatedAt;

  WarehouseTransferRequest({
    this.id,
    required this.requesterId,
    required this.requesterName,
    this.targetUserId,
    this.targetUserName,
    required this.sourceWarehouse,
    required this.targetWarehouse,
    required this.warehouseType,
    required this.items,
    required this.status,
    this.comment,
    required this.requestDate,
    this.approvedDate,
    this.completedDate,
    this.bisanTransactionId,
    this.receiptTransactionId,
    this.docDate,
    this.reverseIssueCode, // NEW FIELD
    this.reverseReceiptTransactionId, // NEW FIELD
    required this.createdAt,
    required this.updatedAt,
  });

  factory WarehouseTransferRequest.fromJson(Map<String, dynamic> json) {
    return WarehouseTransferRequest(
      id: json['id'] as int?,
      requesterId: json['requester_id'] as String,
      requesterName: json['requester_name'] as String,
      targetUserId: json['target_user_id'] as String?,
      targetUserName: json['target_user_name'] as String?,
      sourceWarehouse: json['source_warehouse'] as String,
      targetWarehouse: json['target_warehouse'] as String,
      warehouseType: json['warehouse_type'] as String,
      items: (json['items'] as List<dynamic>)
          .map((item) => TransferItem(
                itemCode: item['item_code'] as String,
                itemName: item['item_name'] as String,
                unit: item['unit'] as String,
                availableQuantity:
                    (item['available_quantity'] as num).toDouble(),
                requestedQuantity:
                    (item['requested_quantity'] as num).toDouble(),
              ))
          .toList(),
      status: TransferStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => TransferStatus.pending,
      ),
      comment: json['comment'] as String?,
      requestDate: DateTime.parse(json['request_date']),
      approvedDate: json['approved_date'] != null
          ? DateTime.parse(json['approved_date'])
          : null,
      completedDate: json['completed_date'] != null
          ? DateTime.parse(json['completed_date'])
          : null,
      bisanTransactionId: json['bisan_transaction_id'] as String?,
      receiptTransactionId: json['receipt_transaction_id'] as String?,
      docDate: json['doc_date'] as String?,
      reverseIssueCode: json['reverse_issue_code'] as String?, // NEW FIELD
      reverseReceiptTransactionId:
          json['reverse_receipt_transaction_id'] as String?, // NEW FIELD
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'requester_id': requesterId,
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
      'status': status.name,
      'comment': comment,
      'request_date': requestDate.toIso8601String(),
      'approved_date': approvedDate?.toIso8601String(),
      'completed_date': completedDate?.toIso8601String(),
      'bisan_transaction_id': bisanTransactionId,
      'receipt_transaction_id': receiptTransactionId,
      'doc_date': docDate,
      'reverse_issue_code': reverseIssueCode, // NEW FIELD
      'reverse_receipt_transaction_id':
          reverseReceiptTransactionId, // NEW FIELD
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isToMainWarehouse => targetUserId == null;
  bool get isPending => status == TransferStatus.pending;
  bool get isApproved => status == TransferStatus.approved;
  bool get isCompleted => status == TransferStatus.completed;
  bool get isRejected => status == TransferStatus.rejected;
  bool get hasReversal => reverseIssueCode != null; // NEW GETTER
  bool get isFullyReversed =>
      reverseIssueCode != null &&
      reverseReceiptTransactionId != null; // NEW GETTER

  String get statusDisplayText {
    switch (status) {
      case TransferStatus.pending:
        return 'في الانتظار';
      case TransferStatus.approved:
        return 'موافق عليه';
      case TransferStatus.rejected:
        if (hasReversal) {
          return isFullyReversed
              ? 'مرفوض - تم إعادة البضاعة'
              : 'مرفوض - جارٍ الإعادة';
        }
        return 'مرفوض';
      case TransferStatus.completed:
        return 'مكتمل';
    }
  }

  String get warehouseTypeDisplayText {
    switch (warehouseType) {
      case WarehouseType.good:
        return 'مخزن الصالح';
      case WarehouseType.damaged:
        return 'مخزن التالف';
      case WarehouseType.main:
        return 'مخزن رئيسي';
      default:
        return warehouseType;
    }
  }
}
