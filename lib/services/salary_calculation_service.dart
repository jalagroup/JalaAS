// lib/services/salary_calculation_service.dart

import 'package:jala_as/models/salary_models.dart';
import 'package:jala_as/models/user.dart';
import 'package:jala_as/services/api_service.dart';
import 'package:jala_as/services/supabase_service.dart';

class SalaryCalculationService {
  static Future<GroupSalaryReport> buildGroupSalaryReport({
    required List<AppUser> users,
    required DateTime targetMonth,
    required AppUser currentUser,
  }) async {
    try {
      print('DEBUG: Building group salary report for ${users.length} users');

      // Filter out users who are not actual salesmen (salesman = '00' with no salesAdmin)
      final validSalesmenUsers = users.where((user) {
        if (user.salesman == '00' &&
            (user.salesAdmin == null || user.salesAdmin!.isEmpty)) {
          print(
              'DEBUG: Skipping user ${user.username} - not an actual salesman');
          return false;
        }
        return true;
      }).toList();

      if (validSalesmenUsers.isEmpty) {
        throw Exception('No valid salesmen found in the selected group');
      }

      final userIds = validSalesmenUsers.map((u) => u.id).toList();

      // Use effectiveSalesman codes for API calls
      final salesmenCodes =
          validSalesmenUsers.map((u) => u.effectiveSalesman).toList();

      // Get date range
      final fromDate = DateTime(targetMonth.year, targetMonth.month, 1);
      final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
      final toDate = DateTime(targetMonth.year, targetMonth.month, lastDay);

      // Get all targets for users
      final targetsMap = await SupabaseService.getSalaryTargetsForUsers(
        userIds: userIds,
        targetMonth: targetMonth,
      );

      // Filter out empty salesman codes for API calls
      final validSalesmenCodes =
          salesmenCodes.where((code) => code.isNotEmpty).toList();

      if (validSalesmenCodes.isEmpty) {
        throw Exception('No valid salesman codes found for API calls');
      }

      // Get retail sales data
      final retailSalesResponse = await ApiService.getSalesmanComparativeReport(
        fromDate: fromDate,
        toDate: toDate,
        fromSalesman:
            validSalesmenCodes.reduce((a, b) => a.compareTo(b) < 0 ? a : b),
        toSalesman:
            validSalesmenCodes.reduce((a, b) => a.compareTo(b) > 0 ? a : b),
        isRetail: true,
      );

      // Get wholesale sales data
      final wholesaleSalesResponse =
          await ApiService.getSalesmanComparativeReport(
        fromDate: fromDate,
        toDate: toDate,
        fromSalesman:
            validSalesmenCodes.reduce((a, b) => a.compareTo(b) < 0 ? a : b),
        toSalesman:
            validSalesmenCodes.reduce((a, b) => a.compareTo(b) > 0 ? a : b),
        isRetail: false,
      );

      // Parse sales data
      final retailSalesData = ApiService.parseSalesmanComparativeData(
        retailSalesResponse,
        validSalesmenCodes,
      );

      final wholesaleSalesData = ApiService.parseSalesmanComparativeData(
        wholesaleSalesResponse,
        validSalesmenCodes,
      );

      // Get aging data
      final agingResponse = await ApiService.getSalaryAgingReport(
        asOfDate: toDate,
        fromSalesman:
            validSalesmenCodes.reduce((a, b) => a.compareTo(b) < 0 ? a : b),
        toSalesman:
            validSalesmenCodes.reduce((a, b) => a.compareTo(b) > 0 ? a : b),
      );

      final agingData = ApiService.parseAgingData(
        agingResponse,
        validSalesmenCodes,
        null,
      );

      // Build individual reports
      final List<SalesmanSalaryReport> salesmenReports = [];

      for (final user in validSalesmenUsers) {
        final report = await _buildSalesmanReport(
          user: user,
          targetMonth: targetMonth,
          targets: targetsMap[user.id] ?? [],
          retailSalesData: retailSalesData[user.effectiveSalesman],
          wholesaleSalesData: wholesaleSalesData[user.effectiveSalesman],
          agingData: agingData[user.effectiveSalesman],
          fromDate: fromDate,
          toDate: toDate,
        );

        salesmenReports.add(report);
      }

      final groupReport = GroupSalaryReport(
        salesmenReports: salesmenReports,
        targetMonth: targetMonth,
      );

      // Update perfect salesman bonus
      final perfectSalesman = groupReport.perfectSalesman;
      if (perfectSalesman != null) {
        // Set bonus directly on the report object
        for (final report in salesmenReports) {
          if (report.userId == perfectSalesman.userId) {
            // This will be reflected in actualSalary calculation
            break;
          }
        }
      }

      return groupReport;
    } catch (e) {
      print('DEBUG: buildGroupSalaryReport error: $e');
      rethrow;
    }
  }

  static Future<SalesmanSalaryReport> _buildSalesmanReport({
    required AppUser user,
    required DateTime targetMonth,
    required List<SalaryTarget> targets,
    SalesDataForSalesman? retailSalesData,
    SalesDataForSalesman? wholesaleSalesData,
    AgingDataForSalesman? agingData,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      // Get all brands
      final brands = await SupabaseService.getBrands(isActive: true);
      final Map<String, String> brandNames = {};
      for (final brand in brands) {
        brandNames[brand.code] = brand.name;
      }

      // Get adjustments
      final adjustments = await SupabaseService.getSalaryAdjustments(
        userId: user.id,
        targetMonth: targetMonth,
      );

      final Map<String, SalaryAdjustment> adjustmentsMap = {};
      for (final adj in adjustments) {
        adjustmentsMap[adj.brandCode] = adj;
      }

      final List<BrandSalesData> brandData = [];
      double totalTarget = 0;
      double totalSales = 0;
      double retailSalesTotal = 0;
      double wholesaleSalesTotal = 0;

      // Check if user should be treated as area-based user
      final bool shouldUseArea = user.area != null &&
          user.area!.isNotEmpty &&
          user.area != '00' &&
          user.area!.length <= 3; // Only use area if it's 3 characters or less

      // Handle special case: user with valid area OR user who is not an actual salesman
      if (shouldUseArea || !user.isActualSalesman) {
        // If user is not an actual salesman (sales manager without salesAdmin), create empty report
        if (!user.isActualSalesman) {
          print(
              'DEBUG: User ${user.username} is not an actual salesman - creating empty report');
          return _createEmptyReportForNonSalesman(
            user: user,
            targetMonth: targetMonth,
            targets: targets,
            brandNames: brandNames,
            adjustmentsMap: adjustmentsMap,
          );
        }

        // User has valid area (3 characters or less) - get periodic sales for area
        final periodicSalesResponse = await ApiService.getPeriodicSalesForArea(
          fromDate: fromDate,
          toDate: toDate,
          fromArea: user.area!,
          toArea: user.area!,
        );

        final areaSales =
            ApiService.parsePeriodicSalesForArea(periodicSalesResponse);

        // Build brand data from targets with area sales
        for (final target in targets) {
          final salesAmount = areaSales[target.brandCode] ?? 0;
          final deviation = target.targetAmount - salesAmount;
          final double deviationPercent = target.targetAmount > 0
              ? ((deviation / target.targetAmount) * 100).clamp(-500, 500)
              : 0;

          final adjustment = adjustmentsMap[target.brandCode];

          brandData.add(BrandSalesData(
            brandCode: target.brandCode,
            brandName: brandNames[target.brandCode] ?? target.brandCode,
            targetAmount: target.targetAmount,
            salesAmount: salesAmount,
            targetPercent: 0, // Will calculate later
            deviation: deviation,
            deviationPercent: deviationPercent,
            customerCount: 0, // No customer count for area-based users
            plusAmount: adjustment?.plusAmount ?? 0,
            minusAmount: adjustment?.minusAmount ?? 0,
          ));

          totalTarget += target.targetAmount;
          totalSales += salesAmount;
        }
      } else {
        // Regular salesman OR sales admin with long area code - use comparative data
        for (final target in targets) {
          final retailInfo = retailSalesData?.brandSales[target.brandCode];
          final wholesaleInfo =
              wholesaleSalesData?.brandSales[target.brandCode];

          final retailSales = retailInfo?.salesAmount ?? 0;
          final wholesaleSales = wholesaleInfo?.salesAmount ?? 0;
          final salesAmount = retailSales + wholesaleSales;

          final retailCust = retailInfo?.customerCount ?? 0;
          final wholesaleCust = wholesaleInfo?.customerCount ?? 0;
          final customerCount = retailCust + wholesaleCust;

          final deviation = target.targetAmount - salesAmount;
          final double deviationPercent = target.targetAmount > 0
              ? ((deviation / target.targetAmount) * 100).clamp(-500, 500)
              : 0;

          final adjustment = adjustmentsMap[target.brandCode];

          brandData.add(BrandSalesData(
            brandCode: target.brandCode,
            brandName: brandNames[target.brandCode] ?? target.brandCode,
            targetAmount: target.targetAmount,
            salesAmount: salesAmount,
            targetPercent: 0, // Will calculate later
            deviation: deviation,
            deviationPercent: deviationPercent,
            customerCount: customerCount,
            plusAmount: adjustment?.plusAmount ?? 0,
            minusAmount: adjustment?.minusAmount ?? 0,
          ));

          totalTarget += target.targetAmount;
          totalSales += salesAmount;
          retailSalesTotal += retailSales;
          wholesaleSalesTotal += wholesaleSales;
        }
      }

      // Calculate target percentages
      for (final brand in brandData) {
        if (totalTarget > 0) {
          final newBrand = BrandSalesData(
            brandCode: brand.brandCode,
            brandName: brand.brandName,
            targetAmount: brand.targetAmount,
            salesAmount: brand.salesAmount,
            targetPercent: (brand.targetAmount / totalTarget) * 100,
            deviation: brand.deviation,
            deviationPercent: brand.deviationPercent,
            customerCount: brand.customerCount,
            plusAmount: brand.plusAmount,
            minusAmount: brand.minusAmount,
          );
          brandData[brandData.indexOf(brand)] = newBrand;
        }
      }

      final double retailPercentage =
          totalSales > 0 ? (retailSalesTotal / totalSales) * 100 : 0;

      // Get aging data for this salesman
      double agingTotal = agingData?.total ?? 0;
      double aging53Plus = agingData?.aging53Plus ?? 0;

      // Check if we should use area for aging data
      final bool shouldUseAreaForAging = user.area != null &&
          user.area!.isNotEmpty &&
          user.area != '00' &&
          user.area!.length <= 3;

      // If user has valid area OR is not an actual salesman, handle aging data appropriately
      if (shouldUseAreaForAging || !user.isActualSalesman) {
        // For non-salesmen, set aging to zero
        if (!user.isActualSalesman) {
          agingTotal = 0;
          aging53Plus = 0;
        } else {
          // User has valid area - filter aging by area
          final agingResponse = await ApiService.getSalaryAgingReport(
            asOfDate: toDate,
            fromSalesman: user.effectiveSalesman,
            toSalesman: user.effectiveSalesman,
            specificArea: user.area,
          );

          final filteredAging = ApiService.parseAgingData(
            agingResponse,
            [user.effectiveSalesman],
            user.area,
          );

          agingTotal = filteredAging[user.effectiveSalesman]?.total ?? 0;
          aging53Plus = filteredAging[user.effectiveSalesman]?.aging53Plus ?? 0;
        }
      }

      final double agingPercentage =
          agingTotal > 0 ? (aging53Plus / agingTotal) * 100 : 0;

      return SalesmanSalaryReport(
        userId: user.id,
        username: user.username,
        salesman: user.effectiveSalesman,
        brandData: brandData,
        totalTarget: totalTarget,
        totalSales: totalSales,
        retailSalesTotal: retailSalesTotal,
        wholesaleSalesTotal: wholesaleSalesTotal,
        retailPercentage: retailPercentage,
        agingTotal: agingTotal,
        aging53Plus: aging53Plus,
        agingPercentage: agingPercentage,
        initialSalary: user.initialSalary,
        bonus: 0, // Will be set by user
      );
    } catch (e) {
      print('DEBUG: _buildSalesmanReport error: $e');
      rethrow;
    }
  }

  /// Create an empty report for users who are not actual salesmen
  static SalesmanSalaryReport _createEmptyReportForNonSalesman({
    required AppUser user,
    required DateTime targetMonth,
    required List<SalaryTarget> targets,
    required Map<String, String> brandNames,
    required Map<String, SalaryAdjustment> adjustmentsMap,
  }) {
    final List<BrandSalesData> brandData = [];
    double totalTarget = 0;

    for (final target in targets) {
      final adjustment = adjustmentsMap[target.brandCode];

      brandData.add(BrandSalesData(
        brandCode: target.brandCode,
        brandName: brandNames[target.brandCode] ?? target.brandCode,
        targetAmount: target.targetAmount,
        salesAmount: 0, // Zero sales for non-salesmen
        targetPercent: 0,
        deviation: target.targetAmount, // Full deviation (target - 0)
        deviationPercent: 100.0, // 100% deviation (no sales)
        customerCount: 0,
        plusAmount: adjustment?.plusAmount ?? 0,
        minusAmount: adjustment?.minusAmount ?? 0,
      ));

      totalTarget += target.targetAmount;
    }

    // Calculate target percentages
    for (final brand in brandData) {
      if (totalTarget > 0) {
        final newBrand = BrandSalesData(
          brandCode: brand.brandCode,
          brandName: brand.brandName,
          targetAmount: brand.targetAmount,
          salesAmount: brand.salesAmount,
          targetPercent: (brand.targetAmount / totalTarget) * 100,
          deviation: brand.deviation,
          deviationPercent: brand.deviationPercent,
          customerCount: brand.customerCount,
          plusAmount: brand.plusAmount,
          minusAmount: brand.minusAmount,
        );
        brandData[brandData.indexOf(brand)] = newBrand;
      }
    }

    return SalesmanSalaryReport(
      userId: user.id,
      username: user.username,
      salesman: user.effectiveSalesman,
      brandData: brandData,
      totalTarget: totalTarget,
      totalSales: 0, // Zero total sales
      retailSalesTotal: 0,
      wholesaleSalesTotal: 0,
      retailPercentage: 0,
      agingTotal: 0,
      aging53Plus: 0,
      agingPercentage: 0,
      initialSalary: user.initialSalary,
      bonus: 0,
    );
  }

  /// Calculate perfect salesman and update bonuses
  static void updatePerfectSalesmanBonus(GroupSalaryReport report) {
    final perfectSalesman = report.perfectSalesman;

    // Reset all perfect salesman bonuses
    for (final salesmanReport in report.salesmenReports) {
      // The bonus is calculated in the getter, but we can track it
      if (perfectSalesman != null &&
          salesmanReport.userId == perfectSalesman.userId) {
        // Perfect salesman gets 500
        // This is handled in the model's getter
      }
    }
  }

  /// Save adjustments for a salesman
  static Future<void> saveAdjustments({
    required String userId,
    required DateTime targetMonth,
    required List<BrandSalesData> brandData,
    required String createdBy,
  }) async {
    try {
      final adjustments = brandData.map((brand) {
        return SalaryAdjustment(
          id: 0,
          userId: userId,
          targetMonth: targetMonth,
          brandCode: brand.brandCode,
          plusAmount: brand.plusAmount,
          minusAmount: brand.minusAmount,
          createdBy: createdBy,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();

      await SupabaseService.saveSalaryAdjustments(adjustments);
    } catch (e) {
      print('DEBUG: saveAdjustments error: $e');
      rethrow;
    }
  }
}
