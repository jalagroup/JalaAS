// lib/models/salary_models.dart

class Brand {
  final int id;
  final String code;
  final String name;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Brand({
    required this.id,
    required this.code,
    required this.name,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Brand.fromJson(Map<String, dynamic> json) {
    return Brand(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  factory Brand.fromBisanJson(Map<String, dynamic> json) {
    return Brand(
      id: 0,
      code: json['code'] as String,
      name: json['name'] as String,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'is_active': isActive,
    };
  }
}

class SalaryTarget {
  final int id;
  final String userId;
  final DateTime targetMonth;
  final String brandCode;
  final double targetAmount;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  SalaryTarget({
    required this.id,
    required this.userId,
    required this.targetMonth,
    required this.brandCode,
    required this.targetAmount,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SalaryTarget.fromJson(Map<String, dynamic> json) {
    return SalaryTarget(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      targetMonth: DateTime.parse(json['target_month']),
      brandCode: json['brand_code'] as String,
      targetAmount: double.parse(json['target_amount'].toString()),
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'target_month':
          '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}-01',
      'brand_code': brandCode,
      'target_amount': targetAmount,
    };
  }
}

class SalaryAdjustment {
  final int id;
  final String userId;
  final DateTime targetMonth;
  final String brandCode;
  final double plusAmount;
  final double minusAmount;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  SalaryAdjustment({
    required this.id,
    required this.userId,
    required this.targetMonth,
    required this.brandCode,
    required this.plusAmount,
    required this.minusAmount,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SalaryAdjustment.fromJson(Map<String, dynamic> json) {
    return SalaryAdjustment(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      targetMonth: DateTime.parse(json['target_month']),
      brandCode: json['brand_code'] as String,
      plusAmount: double.parse(json['plus_amount'].toString()),
      minusAmount: double.parse(json['minus_amount'].toString()),
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'target_month':
          '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}-01',
      'brand_code': brandCode,
      'plus_amount': plusAmount,
      'minus_amount': minusAmount,
    };
  }
}

class BrandSalesData {
  final String brandCode;
  final String brandName;
  final double targetAmount;
  final double salesAmount;
  final double targetPercent;
  final double deviation;
  final double deviationPercent;
  final int customerCount;

  // Adjustments
  double plusAmount;
  double minusAmount;

  BrandSalesData({
    required this.brandCode,
    required this.brandName,
    required this.targetAmount,
    required this.salesAmount,
    required this.targetPercent,
    required this.deviation,
    required this.deviationPercent,
    required this.customerCount,
    this.plusAmount = 0,
    this.minusAmount = 0,
  });

  double get adjustedSales => salesAmount + plusAmount;
  double get adjustedTarget => targetAmount - minusAmount;
  double get adjustedDeviation => adjustedTarget - adjustedSales;
  double get adjustedDeviationPercent {
    if (adjustedTarget == 0) return 0;
    final percent = (adjustedDeviation / adjustedTarget) * 100;
    return percent > 500 ? 500 : percent;
  }
}

class SalesmanSalaryReport {
  final String userId;
  final String username;
  final String salesman;
  final List<BrandSalesData> brandData;
  final double totalTarget;
  final double totalSales;
  final double retailSalesTotal;
  final double wholesaleSalesTotal;
  final double retailPercentage;
  final double agingTotal;
  final double aging53Plus;
  final double agingPercentage;
  final double initialSalary;

  // Calculated salary components
  double bonus;

  SalesmanSalaryReport({
    required this.userId,
    required this.username,
    required this.salesman,
    required this.brandData,
    required this.totalTarget,
    required this.totalSales,
    required this.retailSalesTotal,
    required this.wholesaleSalesTotal,
    required this.retailPercentage,
    required this.agingTotal,
    required this.aging53Plus,
    required this.agingPercentage,
    required this.initialSalary,
    this.bonus = 0,
  });

  double get adjustedTotalSales {
    return brandData.fold(0.0, (sum, brand) => sum + brand.adjustedSales);
  }

  double get adjustedTotalTarget {
    return brandData.fold(0.0, (sum, brand) => sum + brand.adjustedTarget);
  }

  double get targetMoney {
    if (adjustedTotalTarget == 0) return 0;
    return initialSalary * (adjustedTotalSales / adjustedTotalTarget);
  }

  double get targetCollectMoney {
    if (agingTotal == 0) return initialSalary;
    final agingRatio = aging53Plus / agingTotal;
    if (agingRatio < 0.04) {
      return initialSalary;
    } else {
      return initialSalary - (initialSalary * agingRatio);
    }
  }

  double get collectBonus {
    if (agingTotal == 0) return targetMoney * 0.1;
    final agingRatio = aging53Plus / agingTotal;
    if (agingRatio < 0.04) {
      return targetMoney * 0.1;
    } else {
      return 0;
    }
  }

  double get perfectSalesmanBonus {
    // This will be calculated at group level
    return 0;
  }

  double get actualSalary {
    return targetMoney +
        targetCollectMoney +
        bonus +
        collectBonus +
        perfectSalesmanBonus;
  }

  double get achievementPercentage {
    if (adjustedTotalTarget == 0) return 0;
    return (adjustedTotalSales / adjustedTotalTarget) * 100;
  }
}

class GroupSalaryReport {
  final List<SalesmanSalaryReport> salesmenReports;
  final DateTime targetMonth;

  GroupSalaryReport({
    required this.salesmenReports,
    required this.targetMonth,
  });

  SalesmanSalaryReport? get perfectSalesman {
    final qualifiedSalesmen = salesmenReports
        .where((report) => report.achievementPercentage >= 100)
        .toList();

    if (qualifiedSalesmen.isEmpty) return null;

    qualifiedSalesmen.sort(
        (a, b) => b.achievementPercentage.compareTo(a.achievementPercentage));

    return qualifiedSalesmen.first;
  }

  List<BrandSalesData> get consolidatedBrandData {
    final Map<String, BrandSalesData> brandMap = {};

    for (final report in salesmenReports) {
      for (final brand in report.brandData) {
        if (brandMap.containsKey(brand.brandCode)) {
          final existing = brandMap[brand.brandCode]!;
          brandMap[brand.brandCode] = BrandSalesData(
            brandCode: brand.brandCode,
            brandName: brand.brandName,
            targetAmount: existing.targetAmount + brand.targetAmount,
            salesAmount: existing.salesAmount + brand.salesAmount,
            targetPercent: 0, // Will recalculate
            deviation: 0, // Will recalculate
            deviationPercent: 0, // Will recalculate
            customerCount: existing.customerCount + brand.customerCount,
          );
        } else {
          brandMap[brand.brandCode] = brand;
        }
      }
    }

    final totalTarget =
        brandMap.values.fold(0.0, (sum, b) => sum + b.targetAmount);

    return brandMap.values.map((brand) {
      final double targetPercent =
          totalTarget > 0 ? (brand.targetAmount / totalTarget) * 100 : 0;
      final deviation = brand.targetAmount - brand.salesAmount;
      final double deviationPercent = brand.targetAmount > 0
          ? ((deviation / brand.targetAmount) * 100).clamp(-500, 500)
          : 0;

      return BrandSalesData(
        brandCode: brand.brandCode,
        brandName: brand.brandName,
        targetAmount: brand.targetAmount,
        salesAmount: brand.salesAmount,
        targetPercent: targetPercent,
        deviation: deviation,
        deviationPercent: deviationPercent,
        customerCount: brand.customerCount,
      );
    }).toList();
  }

  double get totalRetailSales {
    return salesmenReports.fold(0.0, (sum, r) => sum + r.retailSalesTotal);
  }

  double get totalWholesaleSales {
    return salesmenReports.fold(0.0, (sum, r) => sum + r.wholesaleSalesTotal);
  }

  double get totalSales => totalRetailSales + totalWholesaleSales;

  double get retailPercentage {
    if (totalSales == 0) return 0;
    return (totalRetailSales / totalSales) * 100;
  }

  double get totalAging {
    return salesmenReports.fold(0.0, (sum, r) => sum + r.agingTotal);
  }

  double get total53Plus {
    return salesmenReports.fold(0.0, (sum, r) => sum + r.aging53Plus);
  }

  double get agingPercentage {
    if (totalAging == 0) return 0;
    return (total53Plus / totalAging) * 100;
  }
}

// lib/models/sales_admin_group.dart

class SalesAdminGroup {
  final int id;
  final String salesAdminCode;
  final String salesmanCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  SalesAdminGroup({
    required this.id,
    required this.salesAdminCode,
    required this.salesmanCode,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SalesAdminGroup.fromJson(Map<String, dynamic> json) {
    return SalesAdminGroup(
      id: json['id'] as int,
      salesAdminCode: json['sales_admin_code'] as String,
      salesmanCode: json['salesman_code'] as String,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sales_admin_code': salesAdminCode,
      'salesman_code': salesmanCode,
    };
  }
}

// lib/models/excel_upload_data.dart

class ExcelUploadData {
  final List<TargetData> targets;
  final List<SalaryData> salaries;
  final List<GroupData> groups;

  ExcelUploadData({
    required this.targets,
    required this.salaries,
    required this.groups,
  });
}

class TargetData {
  final String brandCode;
  final String brandName;
  final String salesmanCode;
  final double targetAmount;

  TargetData({
    required this.brandCode,
    required this.brandName,
    required this.salesmanCode,
    required this.targetAmount,
  });
}

class SalaryData {
  final String salesmanCode;
  final double salary;

  SalaryData({
    required this.salesmanCode,
    required this.salary,
  });
}

class GroupData {
  final String salesmanCode;
  final String salesAdminCode;

  GroupData({
    required this.salesmanCode,
    required this.salesAdminCode,
  });
}
