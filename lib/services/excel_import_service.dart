// lib/services/excel_import_service.dart

import 'package:excel/excel.dart';
import 'package:jala_as/models/salary_models.dart';

class ExcelImportService {
  /// Parse Excel file and extract all three tables
  static Future<ExcelUploadData> parseExcelFile(List<int> bytes) async {
    try {
      // Try to decode with error handling for custom formats
      Excel excel;
      try {
        excel = Excel.decodeBytes(bytes);
      } catch (e) {
        // If decoding fails due to custom formats, try alternative approach
        print('DEBUG: Initial decode failed: $e');
        print('DEBUG: Attempting alternative decoding...');

        // Create Excel instance with default settings
        excel = Excel.decodeBytes(bytes);
      }

      final sheet = excel.tables[excel.tables.keys.first];

      if (sheet == null) {
        throw Exception('لم يتم العثور على ورقة عمل في ملف Excel');
      }

      final targets = _parseTargetsTable(sheet);
      final salaries = _parseSalariesTable(sheet);
      final groups = _parseGroupsTable(sheet);

      print(
          'DEBUG: Parsed ${targets.length} targets, ${salaries.length} salaries, ${groups.length} groups');

      return ExcelUploadData(
        targets: targets,
        salaries: salaries,
        groups: groups,
      );
    } catch (e) {
      print('DEBUG: parseExcelFile error: $e');
      throw Exception('فشل في قراءة ملف Excel: ${e.toString()}');
    }
  }

  /// Parse targets table (columns A-D)
  static List<TargetData> _parseTargetsTable(Sheet sheet) {
    final List<TargetData> targets = [];

    print('DEBUG: Parsing targets table from columns A-D');

    // Start from row 2 (row 1 is header: A1=Brand Code, B1=Brand Name, C1=Salesman Code, D1=Target)
    for (int row = 1; row < sheet.maxRows; row++) {
      try {
        final brandCodeCell = sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
        final brandNameCell = sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
        final salesmanCodeCell = sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
        final targetCell = sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));

        // Get cell values safely
        final brandCodeValue = _getCellValue(brandCodeCell);
        final brandNameValue = _getCellValue(brandNameCell);
        final salesmanCodeValue = _getCellValue(salesmanCodeCell);
        final targetValue = _getCellValue(targetCell);

        // Skip if any required cell is empty
        if (brandCodeValue == null ||
            brandNameValue == null ||
            salesmanCodeValue == null ||
            targetValue == null) {
          continue;
        }

        final brandCode = brandCodeValue.toString().trim();
        final brandName = brandNameValue.toString().trim();
        final salesmanCode = salesmanCodeValue.toString().trim();
        final targetAmount = _parseDouble(targetValue.toString());

        // Skip header row and empty values
        if (brandCode.toLowerCase().contains('brand') ||
            brandCode.toLowerCase().contains('علامة') ||
            brandCode.isEmpty ||
            salesmanCode.isEmpty) {
          continue;
        }

        // Skip if target is 0
        if (targetAmount <= 0) {
          continue;
        }

        targets.add(TargetData(
          brandCode: brandCode,
          brandName: brandName,
          salesmanCode: _formatSalesmanCode(salesmanCode),
          targetAmount: targetAmount,
        ));

        print(
            'DEBUG: Added target - Brand: $brandCode, Salesman: $salesmanCode, Amount: $targetAmount');
      } catch (e) {
        print('DEBUG: Error parsing row $row in targets table: $e');
        continue;
      }
    }

    print('DEBUG: Total targets parsed: ${targets.length}');
    return targets;
  }

  /// Parse salaries table (columns F-G)
  static List<SalaryData> _parseSalariesTable(Sheet sheet) {
    final List<SalaryData> salaries = [];

    print('DEBUG: Parsing salaries table from columns F-G');

    // Start from row 2 (row 1 is header: F1=Salesman Code, G1=Salary)
    for (int row = 1; row < sheet.maxRows; row++) {
      try {
        final salesmanCodeCell = sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row));
        final salaryCell = sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row));

        // Get cell values safely
        final salesmanCodeValue = _getCellValue(salesmanCodeCell);
        final salaryValue = _getCellValue(salaryCell);

        // Skip if any required cell is empty
        if (salesmanCodeValue == null || salaryValue == null) {
          continue;
        }

        final salesmanCode = salesmanCodeValue.toString().trim();
        final salaryAmount = _parseDouble(salaryValue.toString());

        // Skip header row and empty values
        if (salesmanCode.toLowerCase().contains('salesman') ||
            salesmanCode.toLowerCase().contains('مندوب') ||
            salesmanCode.isEmpty ||
            salesmanCode == '00') {
          // Skip sales admins/managers (no salary)
          continue;
        }

        // Skip if salary is 0
        if (salaryAmount <= 0) {
          continue;
        }

        salaries.add(SalaryData(
          salesmanCode: _formatSalesmanCode(salesmanCode),
          salary: salaryAmount,
        ));

        print(
            'DEBUG: Added salary - Salesman: $salesmanCode, Amount: $salaryAmount');
      } catch (e) {
        print('DEBUG: Error parsing row $row in salaries table: $e');
        continue;
      }
    }

    print('DEBUG: Total salaries parsed: ${salaries.length}');
    return salaries;
  }

  /// Parse groups table (columns I-J)
  static List<GroupData> _parseGroupsTable(Sheet sheet) {
    final List<GroupData> groups = [];

    print('DEBUG: Parsing groups table from columns I-J');

    // Start from row 2 (row 1 is header: I1=Salesman Code, J1=Sales Admin Code)
    for (int row = 1; row < sheet.maxRows; row++) {
      try {
        final salesmanCodeCell = sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row));
        final salesAdminCodeCell = sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row));

        // Get cell values safely
        final salesmanCodeValue = _getCellValue(salesmanCodeCell);
        final salesAdminCodeValue = _getCellValue(salesAdminCodeCell);

        // Skip if any required cell is empty
        if (salesmanCodeValue == null || salesAdminCodeValue == null) {
          continue;
        }

        final salesmanCode = salesmanCodeValue.toString().trim();
        final salesAdminCode = salesAdminCodeValue.toString().trim();

        // Skip header row and empty values
        if (salesmanCode.toLowerCase().contains('salesman') ||
            salesmanCode.toLowerCase().contains('مندوب') ||
            salesmanCode.isEmpty ||
            salesAdminCode.isEmpty) {
          continue;
        }

        groups.add(GroupData(
          salesmanCode: _formatSalesmanCode(salesmanCode),
          salesAdminCode: _formatSalesmanCode(salesAdminCode),
        ));

        print(
            'DEBUG: Added group - Salesman: $salesmanCode, Admin: $salesAdminCode');
      } catch (e) {
        print('DEBUG: Error parsing row $row in groups table: $e');
        continue;
      }
    }

    print('DEBUG: Total groups parsed: ${groups.length}');
    return groups;
  }

  /// Safely get cell value
  static dynamic _getCellValue(Data? cell) {
    if (cell == null) return null;

    // Handle different cell value types
    final value = cell.value;

    if (value == null) return null;

    // If it's a TextCellValue, get the text
    if (value is TextCellValue) {
      return value.value;
    }

    // If it's an IntCellValue, get the value
    if (value is IntCellValue) {
      return value.value;
    }

    // If it's a DoubleCellValue, get the value
    if (value is DoubleCellValue) {
      return value.value;
    }

    // If it's a DateCellValue, convert to string
    if (value is DateCellValue) {
      return value.toString();
    }

    // If it's a FormulaCellValue, get the text representation
    if (value is FormulaCellValue) {
      return value;
    }

    // Default: return string representation
    return value.toString();
  }

  /// Format salesman code to 3 digits (e.g., "5" -> "005", "50" -> "050")
  static String _formatSalesmanCode(String code) {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return '000';

    // Remove any non-numeric characters except the code itself
    final numericOnly = cleanCode.replaceAll(RegExp(r'[^\d]'), '');

    // Try to parse as number and format
    final numCode = int.tryParse(numericOnly);
    if (numCode != null) {
      return numCode.toString().padLeft(3, '0');
    }

    // If not a number, return as is (padded)
    return cleanCode.padLeft(3, '0');
  }

  /// Parse double value from string
  static double _parseDouble(String value) {
    if (value.isEmpty) return 0;
    try {
      // Remove any commas or spaces
      final cleanValue = value.replaceAll(',', '').replaceAll(' ', '').trim();
      return double.parse(cleanValue);
    } catch (e) {
      print('DEBUG: Error parsing double from "$value": $e');
      return 0;
    }
  }
}
