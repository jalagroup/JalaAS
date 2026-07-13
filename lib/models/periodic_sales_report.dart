// lib/models/periodic_sales_report.dart
class PeriodicSalesReport {
  final Map<String, String> fieldLabels;
  final List<String> fields;
  final List<Map<String, dynamic>> rows;

  PeriodicSalesReport({
    required this.fieldLabels,
    required this.fields,
    required this.rows,
  });

  factory PeriodicSalesReport.fromJson(Map<String, dynamic> json) {
    return PeriodicSalesReport(
      fieldLabels: Map<String, String>.from(json['fieldLabels'] ?? {}),
      fields: List<String>.from(json['fields'] ?? []),
      rows: List<Map<String, dynamic>>.from(json['rows'] ?? []),
    );
  }

  // Get fixed columns (brand code and name)
  List<String> get fixedColumns => ['item.brand.name'];

  // Get period columns (dynamic based on date range)
  List<String> get periodColumns {
    return fields
        .where((field) =>
            field.startsWith('cur') &&
            field.endsWith('qnt') &&
            field != 'total')
        .toList();
  }

  // Get total column
  String get totalColumn => 'total';

  // Check if has data
  bool get hasData => rows.isNotEmpty;

  // Get display name for field
  String getFieldDisplayName(String field) {
    return fieldLabels[field] ?? field;
  }
}

// Date range presets
enum DateRangePreset {
  currentDay,
  yesterday, // Add this line
  currentWeek,
  currentMonth,
  previousMonth,
  currentQuarter,
  currentYear,
  custom
}

// Area selection options
enum AreaSelection {
  all, // كل المناطق
  south, // مناطق الجنوب (010-049)
  north // مناطق الشمال (050-080)
}

class DateRangeHelper {
  static Map<DateRangePreset, String> get presetLabels => {
        DateRangePreset.currentDay: 'اليوم الحالي',
        DateRangePreset.yesterday: 'البارحة', // Add this
        DateRangePreset.currentWeek: 'الأسبوع الحالي',
        DateRangePreset.currentMonth: 'الشهر الحالي',
        DateRangePreset.previousMonth: 'الشهر السابق',
        DateRangePreset.currentQuarter: 'الربع الحالي',
        DateRangePreset.currentYear: 'السنة الحالية',
        DateRangePreset.custom: 'فترة مخصصة',
      };

  static Map<AreaSelection, String> get areaLabels => {
        AreaSelection.all: 'كل المناطق',
        AreaSelection.south: 'مناطق الجنوب',
        AreaSelection.north: 'مناطق الشمال',
      };

  static Map<String, String> getDateRange(DateRangePreset preset) {
    final now = DateTime.now();
    String fromDate, toDate;

    switch (preset) {
      case DateRangePreset.currentDay:
        fromDate = toDate = formatDate(now);
        break;

      case DateRangePreset.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        return {
          'fromDate': formatDate(yesterday),
          'toDate': formatDate(yesterday),
        };

      case DateRangePreset.currentWeek:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        fromDate = formatDate(startOfWeek);
        toDate = formatDate(endOfWeek);
        break;

      case DateRangePreset.currentMonth:
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);
        fromDate = formatDate(startOfMonth);
        toDate = formatDate(endOfMonth);
        break;

      case DateRangePreset.previousMonth:
        final startOfPrevMonth = DateTime(now.year, now.month - 1, 1);
        final endOfPrevMonth = DateTime(now.year, now.month, 0);
        fromDate = formatDate(startOfPrevMonth);
        toDate = formatDate(endOfPrevMonth);
        break;

      case DateRangePreset.currentQuarter:
        final quarterStart =
            DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1, 1);
        final quarterEnd = DateTime(now.year, quarterStart.month + 3, 0);
        fromDate = formatDate(quarterStart);
        toDate = formatDate(quarterEnd);
        break;

      case DateRangePreset.currentYear:
        fromDate = formatDate(DateTime(now.year, 1, 1));
        toDate = formatDate(DateTime(now.year, 12, 31));
        break;

      case DateRangePreset.custom:
        fromDate = toDate = formatDate(now);
        break;
    }

    return {'fromDate': fromDate, 'toDate': toDate};
  }

  static String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static Map<String, String>? getAreaRange(AreaSelection selection) {
    switch (selection) {
      case AreaSelection.all:
        return null; // No area filter
      case AreaSelection.south:
        return {'fromArea': '010', 'toArea': '049'};
      case AreaSelection.north:
        return {'fromArea': '050', 'toArea': '080'};
    }
  }
}
