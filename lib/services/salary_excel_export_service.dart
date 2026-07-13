// lib/services/salary_excel_export_service.dart

import 'dart:typed_data';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:jala_as/models/salary_models.dart';
import 'package:jala_as/utils/helpers.dart';

class SalaryExcelExportService {
  /// Export group salary report to Excel
  static Future<Uint8List> exportGroupReport(GroupSalaryReport report) async {
    try {
      final xlsio.Workbook workbook = xlsio.Workbook();

      // Create summary sheet
      _createSummarySheet(workbook, report);

      // Create sheet for each salesman
      for (int i = 0; i < report.salesmenReports.length; i++) {
        final salesmanReport = report.salesmenReports[i];
        _createSalesmanSheet(workbook, salesmanReport, i + 1);
      }

      // Remove default sheet if exists
      if (workbook.worksheets.count > report.salesmenReports.length + 1) {}

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      return Uint8List.fromList(bytes);
    } catch (e) {
      print('Error exporting group report: $e');
      rethrow;
    }
  }

  /// Create summary sheet
  static void _createSummarySheet(
    xlsio.Workbook workbook,
    GroupSalaryReport report,
  ) {
    final sheet = workbook.worksheets[0];
    sheet.name = 'ملخص المجموعة';

    int row = 1;

    // Title
    sheet.getRangeByIndex(row, 1, row, 8).merge();
    final titleCell = sheet.getRangeByIndex(row, 1);
    titleCell.setText('تقرير رواتب المجموعة');
    titleCell.cellStyle.fontSize = 16;
    titleCell.cellStyle.bold = true;
    titleCell.cellStyle.hAlign = xlsio.HAlignType.center;
    row += 2;

    // Month
    sheet.getRangeByIndex(row, 1).setText('الشهر:');
    sheet.getRangeByIndex(row, 2).setText(
          Helpers.formatMonthYear(report.targetMonth),
        );
    row += 2;

    // Statistics
    sheet.getRangeByIndex(row, 1).setText('إجمالي المبيعات بالتجزئة:');
    sheet.getRangeByIndex(row, 2).setNumber(report.totalRetailSales);
    sheet.getRangeByIndex(row, 2).numberFormat = '#,##0.00';
    row++;

    sheet.getRangeByIndex(row, 1).setText('إجمالي المبيعات بالجملة:');
    sheet.getRangeByIndex(row, 2).setNumber(report.totalWholesaleSales);
    sheet.getRangeByIndex(row, 2).numberFormat = '#,##0.00';
    row++;

    sheet.getRangeByIndex(row, 1).setText('نسبة التجزئة:');
    sheet.getRangeByIndex(row, 2).setNumber(report.retailPercentage);
    sheet.getRangeByIndex(row, 2).numberFormat = '0.00"%"';
    row++;

    sheet.getRangeByIndex(row, 1).setText('إجمالي الذمم:');
    sheet.getRangeByIndex(row, 2).setNumber(report.totalAging);
    sheet.getRangeByIndex(row, 2).numberFormat = '#,##0.00';
    row++;

    sheet.getRangeByIndex(row, 1).setText('الذمم +53 يوم:');
    sheet.getRangeByIndex(row, 2).setNumber(report.total53Plus);
    sheet.getRangeByIndex(row, 2).numberFormat = '#,##0.00';
    row++;

    sheet.getRangeByIndex(row, 1).setText('نسبة الذمم المتأخرة:');
    sheet.getRangeByIndex(row, 2).setNumber(report.agingPercentage);
    sheet.getRangeByIndex(row, 2).numberFormat = '0.00"%"';
    row += 2;

    // Perfect salesman
    if (report.perfectSalesman != null) {
      sheet.getRangeByIndex(row, 1).setText('المندوب المثالي:');
      sheet.getRangeByIndex(row, 2).setText(report.perfectSalesman!.username);
      sheet.getRangeByIndex(row, 3).setText(
            '(${report.perfectSalesman!.achievementPercentage.toStringAsFixed(1)}%)',
          );
      row += 2;
    }

    // Brands table
    _createBrandsTable(sheet, report.consolidatedBrandData, row);

    // Auto-fit columns
    for (int i = 1; i <= 8; i++) {
      sheet.autoFitColumn(i);
    }
  }

  /// Create salesman sheet
  static void _createSalesmanSheet(
    xlsio.Workbook workbook,
    SalesmanSalaryReport report,
    int sheetIndex,
  ) {
    final sheet = workbook.worksheets.addWithName(report.username);

    int row = 1;

    // Title
    sheet.getRangeByIndex(row, 1, row, 8).merge();
    final titleCell = sheet.getRangeByIndex(row, 1);
    titleCell.setText('تقرير راتب ${report.username}');
    titleCell.cellStyle.fontSize = 16;
    titleCell.cellStyle.bold = true;
    titleCell.cellStyle.hAlign = xlsio.HAlignType.center;
    row += 2;

    // Salesman info
    sheet.getRangeByIndex(row, 1).setText('رقم المندوب:');
    sheet.getRangeByIndex(row, 2).setText(report.salesman);
    row++;

    sheet.getRangeByIndex(row, 1).setText('الراتب الأساسي:');
    sheet.getRangeByIndex(row, 2).setNumber(report.initialSalary);
    sheet.getRangeByIndex(row, 2).numberFormat = '#,##0.00';
    row += 2;

    // Statistics
    sheet.getRangeByIndex(row, 1).setText('إجمالي الهدف:');
    sheet.getRangeByIndex(row, 2).setNumber(report.adjustedTotalTarget);
    sheet.getRangeByIndex(row, 2).numberFormat = '#,##0.00';
    row++;

    sheet.getRangeByIndex(row, 1).setText('إجمالي المبيعات:');
    sheet.getRangeByIndex(row, 2).setNumber(report.adjustedTotalSales);
    sheet.getRangeByIndex(row, 2).numberFormat = '#,##0.00';
    row++;

    sheet.getRangeByIndex(row, 1).setText('نسبة الإنجاز:');
    sheet.getRangeByIndex(row, 2).setNumber(report.achievementPercentage);
    sheet.getRangeByIndex(row, 2).numberFormat = '0.00"%"';
    row++;

    if (report.retailSalesTotal > 0) {
      sheet.getRangeByIndex(row, 1).setText('مبيعات التجزئة:');
      sheet.getRangeByIndex(row, 2).setNumber(report.retailSalesTotal);
      sheet.getRangeByIndex(row, 2).numberFormat = '#,##0.00';
      row++;

      sheet.getRangeByIndex(row, 1).setText('مبيعات الجملة:');
      sheet.getRangeByIndex(row, 2).setNumber(report.wholesaleSalesTotal);
      sheet.getRangeByIndex(row, 2).numberFormat = '#,##0.00';
      row++;

      sheet.getRangeByIndex(row, 1).setText('نسبة التجزئة:');
      sheet.getRangeByIndex(row, 2).setNumber(report.retailPercentage);
      sheet.getRangeByIndex(row, 2).numberFormat = '0.00"%"';
      row++;
    }

    sheet.getRangeByIndex(row, 1).setText('إجمالي الذمم:');
    sheet.getRangeByIndex(row, 2).setNumber(report.agingTotal);
    sheet.getRangeByIndex(row, 2).numberFormat = '#,##0.00';
    row++;

    sheet.getRangeByIndex(row, 1).setText('الذمم +53 يوم:');
    sheet.getRangeByIndex(row, 2).setNumber(report.aging53Plus);
    sheet.getRangeByIndex(row, 2).numberFormat = '#,##0.00';
    row++;

    sheet.getRangeByIndex(row, 1).setText('نسبة الذمم المتأخرة:');
    sheet.getRangeByIndex(row, 2).setNumber(report.agingPercentage);
    sheet.getRangeByIndex(row, 2).numberFormat = '0.00"%"';
    row += 2;

    // Salary calculations
    sheet.getRangeByIndex(row, 1).setText('=== حسابات الراتب ===');
    sheet.getRangeByIndex(row, 1).cellStyle.bold = true;
    row++;

    sheet.getRangeByIndex(row, 1).setText('مبلغ الهدف الفعلي:');
    sheet.getRangeByIndex(row, 2).setNumber(report.targetMoney);
    sheet.getRangeByIndex(row, 2).numberFormat = '#,##0.00';
    row++;

    sheet.getRangeByIndex(row, 1).setText('مبلغ هدف التحصيل:');
    sheet.getRangeByIndex(row, 2).setNumber(report.targetCollectMoney);
    sheet.getRangeByIndex(row, 2).numberFormat = '#,##0.00';
    row++;

    sheet.getRangeByIndex(row, 1).setText('مكافآت:');
    sheet.getRangeByIndex(row, 2).setNumber(report.bonus);
    sheet.getRangeByIndex(row, 2).numberFormat = '#,##0.00';
    row++;

    sheet.getRangeByIndex(row, 1).setText('مكافأة تحصيل:');
    sheet.getRangeByIndex(row, 2).setNumber(report.collectBonus);
    sheet.getRangeByIndex(row, 2).numberFormat = '#,##0.00';
    row++;

    sheet.getRangeByIndex(row, 1).setText('مكافأة المندوب المثالي:');
    sheet.getRangeByIndex(row, 2).setNumber(report.perfectSalesmanBonus);
    sheet.getRangeByIndex(row, 2).numberFormat = '#,##0.00';
    row++;

    sheet.getRangeByIndex(row, 1).setText('الراتب الفعلي:');
    sheet.getRangeByIndex(row, 2).setNumber(report.actualSalary);
    sheet.getRangeByIndex(row, 2).numberFormat = '#,##0.00';
    sheet.getRangeByIndex(row, 1).cellStyle.bold = true;
    sheet.getRangeByIndex(row, 2).cellStyle.bold = true;
    row += 2;

    // Brands table
    _createBrandsTable(sheet, report.brandData, row);

    // Auto-fit columns
    for (int i = 1; i <= 10; i++) {
      sheet.autoFitColumn(i);
    }
  }

  /// Create brands table
  static void _createBrandsTable(
    xlsio.Worksheet sheet,
    List<BrandSalesData> brandData,
    int startRow,
  ) {
    int row = startRow;

    // Headers
    final headers = [
      'العلامة التجارية',
      'الهدف الشهري',
      'النسبة من الكلي',
      'المبيعات الحالية',
      'الانحراف',
      'نسبة الإنحراف',
      'عدد الزبائن',
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(row, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#D3D3D3';
      cell.cellStyle.hAlign = xlsio.HAlignType.center;
    }
    row++;

    // Data rows
    for (final brand in brandData) {
      sheet
          .getRangeByIndex(row, 1)
          .setText('${brand.brandCode} - ${brand.brandName}');

      sheet.getRangeByIndex(row, 2).setNumber(brand.adjustedTarget);
      sheet.getRangeByIndex(row, 2).numberFormat = '#,##0.00';

      sheet.getRangeByIndex(row, 3).setNumber(brand.targetPercent);
      sheet.getRangeByIndex(row, 3).numberFormat = '0.00"%"';

      sheet.getRangeByIndex(row, 4).setNumber(brand.adjustedSales);
      sheet.getRangeByIndex(row, 4).numberFormat = '#,##0.00';

      sheet.getRangeByIndex(row, 5).setNumber(brand.adjustedDeviation);
      sheet.getRangeByIndex(row, 5).numberFormat = '#,##0.00';

      sheet.getRangeByIndex(row, 6).setNumber(brand.adjustedDeviationPercent);
      sheet.getRangeByIndex(row, 6).numberFormat = '0.00"%"';

      sheet.getRangeByIndex(row, 7).setNumber(brand.customerCount.toDouble());

      row++;
    }

    // Totals
    sheet.getRangeByIndex(row, 1).setText('المجموع');
    sheet.getRangeByIndex(row, 1).cellStyle.bold = true;

    final totalTarget = brandData.fold(0.0, (sum, b) => sum + b.adjustedTarget);
    sheet.getRangeByIndex(row, 2).setNumber(totalTarget);
    sheet.getRangeByIndex(row, 2).numberFormat = '#,##0.00';
    sheet.getRangeByIndex(row, 2).cellStyle.bold = true;

    final totalSales = brandData.fold(0.0, (sum, b) => sum + b.adjustedSales);
    sheet.getRangeByIndex(row, 4).setNumber(totalSales);
    sheet.getRangeByIndex(row, 4).numberFormat = '#,##0.00';
    sheet.getRangeByIndex(row, 4).cellStyle.bold = true;

    final totalCustomers = brandData.fold(0, (sum, b) => sum + b.customerCount);
    sheet.getRangeByIndex(row, 7).setNumber(totalCustomers.toDouble());
    sheet.getRangeByIndex(row, 7).cellStyle.bold = true;
  }
}
