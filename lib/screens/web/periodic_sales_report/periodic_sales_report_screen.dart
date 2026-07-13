// lib/screens/web/periodic_sales_report_screen.dart - OPTIMIZED VERSION

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:jala_as/models/salesman.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../models/user.dart';
import '../../../models/periodic_sales_report.dart';
import '../../../services/api_service.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';
import '../../../utils/arabic_text_helper.dart';
import '../web_login_screen.dart';
import 'dart:ui' as ui;

class PeriodicSalesReportScreen extends StatefulWidget {
  final AppUser user;
  final String fromDate;
  final String toDate;
  final AreaSelection areaSelection;
  final Salesman? selectedSalesman;

  const PeriodicSalesReportScreen({
    super.key,
    required this.user,
    required this.fromDate,
    required this.toDate,
    required this.areaSelection,
    this.selectedSalesman,
  });

  @override
  State<PeriodicSalesReportScreen> createState() =>
      _PeriodicSalesReportScreenState();
}

class _PeriodicSalesReportScreenState extends State<PeriodicSalesReportScreen>
    with AutomaticKeepAliveClientMixin {
  PeriodicSalesReport? _report;
  bool _isLoading = true;
  bool _isGeneratingPdf = false;

  // Sorting state
  String? _sortColumn;
  bool _sortAscending = false;
  List<Map<String, dynamic>> _sortedRows = [];

  // Controllers for horizontal scrolling
  late final ScrollController _horizontalHeaderController;
  late final ScrollController _horizontalDataController;
  late final ScrollController _horizontalTotalController;
  late final ScrollController _screenVerticalController;

  // Cached calculations
  Map<String, dynamic>? _cachedTotals;
  double? _cachedScrollableWidth;

  // Cached styles
  static const _primaryColor = Color(AppConstants.primaryColor);
  static const _accentColor = Color(AppConstants.accentColor);

  // Dynamic header height based on content
  static const double _minHeaderHeight = 56.0;
  static const double _maxHeaderHeight = 80.0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadReport();
  }

  void _initializeControllers() {
    _horizontalHeaderController = ScrollController();
    _horizontalDataController = ScrollController();
    _horizontalTotalController = ScrollController();
    _screenVerticalController = ScrollController();

    // Sync horizontal scrolling
    _horizontalHeaderController.addListener(_syncFromHeader);
    _horizontalDataController.addListener(_syncFromData);
    _horizontalTotalController.addListener(_syncFromTotal);
  }

  void _syncFromHeader() {
    final offset = _horizontalHeaderController.offset;
    if (_horizontalDataController.hasClients &&
        _horizontalDataController.offset != offset) {
      _horizontalDataController.jumpTo(offset);
    }
    if (_horizontalTotalController.hasClients &&
        _horizontalTotalController.offset != offset) {
      _horizontalTotalController.jumpTo(offset);
    }
  }

  void _syncFromData() {
    final offset = _horizontalDataController.offset;
    if (_horizontalHeaderController.hasClients &&
        _horizontalHeaderController.offset != offset) {
      _horizontalHeaderController.jumpTo(offset);
    }
    if (_horizontalTotalController.hasClients &&
        _horizontalTotalController.offset != offset) {
      _horizontalTotalController.jumpTo(offset);
    }
  }

  void _syncFromTotal() {
    final offset = _horizontalTotalController.offset;
    if (_horizontalHeaderController.hasClients &&
        _horizontalHeaderController.offset != offset) {
      _horizontalHeaderController.jumpTo(offset);
    }
    if (_horizontalDataController.hasClients &&
        _horizontalDataController.offset != offset) {
      _horizontalDataController.jumpTo(offset);
    }
  }

  @override
  void dispose() {
    _horizontalHeaderController.removeListener(_syncFromHeader);
    _horizontalDataController.removeListener(_syncFromData);
    _horizontalTotalController.removeListener(_syncFromTotal);
    _horizontalHeaderController.dispose();
    _horizontalDataController.dispose();
    _horizontalTotalController.dispose();
    _screenVerticalController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _calculateTotals() {
    if (_cachedTotals != null) return _cachedTotals!;
    if (_report == null || _sortedRows.isEmpty) return {};

    final totals = <String, dynamic>{};
    final columns = [..._report!.periodColumns, _report!.totalColumn];

    // Initialize totals
    for (final column in columns) {
      totals[column] = 0.0;
    }

    // Calculate sums
    for (final row in _sortedRows) {
      for (final column in columns) {
        final value = row[column]?.toString() ?? '';
        final numValue = double.tryParse(value.replaceAll(',', ''));
        if (numValue != null) {
          totals[column] = (totals[column] ?? 0.0) + numValue;
        }
      }
    }

    _cachedTotals = totals;
    return totals;
  }

  void _invalidateTotalsCache() {
    _cachedTotals = null;
  }

  double _calculateScrollableWidth() {
    if (_cachedScrollableWidth != null) return _cachedScrollableWidth!;
    if (_report == null) return 300.0;

    final periodColumnsCount = _report!.periodColumns.length;
    _cachedScrollableWidth = (periodColumnsCount * 100.0) + 120.0;
    return _cachedScrollableWidth!;
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);

    try {
      final report = await ApiService.getPeriodicSalesReport(
        fromDate: widget.fromDate,
        toDate: widget.toDate,
        areaSelection: widget.areaSelection,
        selectedSalesman: widget.selectedSalesman,
      );

      if (mounted) {
        setState(() {
          _report = report;
          _sortedRows = List<Map<String, dynamic>>.from(report.rows);
          _isLoading = false;
          _cachedTotals = null;
          _cachedScrollableWidth = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Helpers.showApiErrorDialog(context, e);
      }
    }
  }

  void _showSnackBar(String message, bool isError) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _sortData(String column) {
    if (_report == null) return;

    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = false;
      }

      _sortedRows.sort((a, b) {
        dynamic aValue = a[column] ?? '';
        dynamic bValue = b[column] ?? '';

        // Parse numbers
        if (aValue is String && bValue is String) {
          final aNum = double.tryParse(aValue.replaceAll(',', ''));
          final bNum = double.tryParse(bValue.replaceAll(',', ''));

          if (aNum != null && bNum != null) {
            aValue = aNum;
            bValue = bNum;
          }
        }

        // Handle empty values
        final aEmpty = aValue.toString().isEmpty;
        final bEmpty = bValue.toString().isEmpty;

        if (aEmpty && !bEmpty) return _sortAscending ? -1 : 1;
        if (!aEmpty && bEmpty) return _sortAscending ? 1 : -1;
        if (aEmpty && bEmpty) return 0;

        // Compare
        int comparison;
        if (aValue is num && bValue is num) {
          comparison = aValue.compareTo(bValue);
        } else {
          comparison = aValue.toString().compareTo(bValue.toString());
        }

        return _sortAscending ? comparison : -comparison;
      });

      _invalidateTotalsCache();
    });
  }

  Future<void> _generatePdf() async {
    setState(() => _isGeneratingPdf = true);

    try {
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        setState(() => _isGeneratingPdf = false);
        _showSnackBar('سيتم إضافة ميزة PDF قريباً', false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
        _showSnackBar('فشل في إنشاء ملف PDF: ${e.toString()}', true);
      }
    }
  }

  Future<void> _logout() async {
    try {
      await SupabaseService.signOut();
      await Helpers.setLoggedIn(false);
      await Helpers.clearUserData();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const WebLoginScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('فشل في تسجيل الخروج', true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isMobile = screenWidth < 768;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _LightAppBar(
          user: widget.user,
          report: _report,
          onLogout: _logout,
          isGeneratingPdf: _isGeneratingPdf,
          onGeneratePdf: _report?.hasData == true ? _generatePdf : null,
          onRefresh: _loadReport,
          isDesktop: isDesktop,
          fromDate: widget.fromDate,
          toDate: widget.toDate,
          areaSelection: widget.areaSelection,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 1200 : double.infinity,
            ),
            child: Column(
              children: [
                _buildReportHeader(isDesktop, isMobile),
                Expanded(child: _buildContent(isDesktop, isMobile)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportHeader(bool isDesktop, bool isMobile) {
    final fromDateFormatted =
        DateFormat('dd/MM/yyyy', 'ar').format(DateTime.parse(widget.fromDate));
    final toDateFormatted =
        DateFormat('dd/MM/yyyy', 'ar').format(DateTime.parse(widget.toDate));
    final areaText = DateRangeHelper.areaLabels[widget.areaSelection]!;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(isMobile ? 16 : 24),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isMobile ? 50 : 60,
            height: isMobile ? 50 : 60,
            decoration: BoxDecoration(
              color: _accentColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.analytics_outlined,
              color: Colors.white,
              size: isMobile ? 24 : 30,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تقرير المبيعات بناءاً على الفترات',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
                  ),
                ),
                SizedBox(height: isMobile ? 4 : 6),
                Text(
                  'النطاق: $areaText',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: _accentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.selectedSalesman != null) ...[
                  SizedBox(height: isMobile ? 2 : 4),
                  Text(
                    'المندوب: ${widget.selectedSalesman!.name}',
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12,
                      color: Colors.blue.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                SizedBox(height: isMobile ? 6 : 8),
                Row(
                  children: [
                    Icon(Icons.date_range,
                        size: isMobile ? 14 : 16, color: Colors.grey.shade600),
                    SizedBox(width: isMobile ? 4 : 6),
                    Expanded(
                      child: Text(
                        '$fromDateFormatted - $toDateFormatted',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_report?.hasData == true)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 6 : 8,
              ),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _primaryColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    '${_report!.rows.length}',
                    style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: isMobile ? 14 : 16,
                    ),
                  ),
                  Text(
                    'عنصر',
                    style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.w500,
                      fontSize: isMobile ? 10 : 11,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDesktop, bool isMobile) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'جاري تحميل تقرير المبيعات...',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (_report == null || !_report!.hasData) {
      return _buildEmptyState(isMobile);
    }

    return _buildTableView(isDesktop, isMobile);
  }

  Widget _buildEmptyState(bool isMobile) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 24 : 32),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Icon(
              Icons.analytics_outlined,
              size: isMobile ? 60 : 80,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'لا توجد بيانات في هذه الفترة',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'لم يتم العثور على بيانات مبيعات خلال الفترة المحددة',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 24 : 32,
                vertical: isMobile ? 12 : 16,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(
              'إعادة التحميل',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: isMobile ? 14 : 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableView(bool isDesktop, bool isMobile) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fixedColumnWidth = screenWidth * 0.27;
    final scrollableContentWidth = _calculateScrollableWidth();
    final headerHeight =
        isMobile ? 64.0 : 72.0; // Increased height for multi-line headers

    return Container(
      margin: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Header Row with fixed height
            SizedBox(
              height: headerHeight,
              child: Row(
                children: [
                  // Fixed header columns
                  Container(
                    width: fixedColumnWidth,
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      border: const Border(
                        left: BorderSide(color: _primaryColor, width: 2),
                      ),
                    ),
                    child: Row(
                      children: _report!.fixedColumns.map((column) {
                        return Expanded(
                          child: _TableHeaderCell(
                            column: column,
                            label: _report!.getFieldDisplayName(column),
                            isMobile: isMobile,
                            isSorted: _sortColumn == column,
                            sortAscending: _sortAscending,
                            onTap: () => _sortData(column),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // Scrollable header columns
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _horizontalHeaderController,
                      child: Container(
                        width: scrollableContentWidth,
                        decoration: const BoxDecoration(color: _primaryColor),
                        child: Row(
                          children: [
                            ..._report!.periodColumns.map(
                              (column) => SizedBox(
                                width: 100,
                                child: _TableHeaderCell(
                                  column: column,
                                  label: _report!.getFieldDisplayName(column),
                                  isMobile: isMobile,
                                  isSorted: _sortColumn == column,
                                  sortAscending: _sortAscending,
                                  onTap: () => _sortData(column),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 120,
                              child: _TableHeaderCell(
                                column: _report!.totalColumn,
                                label: _report!
                                    .getFieldDisplayName(_report!.totalColumn),
                                isMobile: isMobile,
                                isSorted: _sortColumn == _report!.totalColumn,
                                sortAscending: _sortAscending,
                                onTap: () => _sortData(_report!.totalColumn),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Data Rows
            Expanded(
              child: SingleChildScrollView(
                controller: _screenVerticalController,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fixed columns data
                    SizedBox(
                      width: fixedColumnWidth,
                      child: Column(
                        children: List.generate(_sortedRows.length, (index) {
                          return _FixedRowPart(
                            row: _sortedRows[index],
                            index: index,
                            isMobile: isMobile,
                            fixedColumns: _report!.fixedColumns,
                          );
                        }),
                      ),
                    ),
                    // Scrollable columns data
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        controller: _horizontalDataController,
                        child: SizedBox(
                          width: scrollableContentWidth,
                          child: Column(
                            children:
                                List.generate(_sortedRows.length, (index) {
                              return _ScrollableRowPart(
                                row: _sortedRows[index],
                                index: index,
                                isMobile: isMobile,
                                periodColumns: _report!.periodColumns,
                                totalColumn: _report!.totalColumn,
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Total Row
            _buildTotalRow(fixedColumnWidth, scrollableContentWidth, isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(
      double fixedColumnWidth, double scrollableContentWidth, bool isMobile) {
    final totals = _calculateTotals();
    final rowHeight = isMobile ? 52.0 : 60.0;

    return Row(
      children: [
        // Fixed columns for total
        Container(
          width: fixedColumnWidth,
          height: rowHeight,
          decoration: BoxDecoration(
            color: _accentColor.withOpacity(0.1),
            border: Border(
              top: BorderSide(color: _accentColor, width: 2),
              left: const BorderSide(color: _primaryColor, width: 2),
            ),
          ),
          child: Row(
            children: _report!.fixedColumns.map((column) {
              return Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
                  child: Center(
                    child: Text(
                      column == _report!.fixedColumns.first ? 'الإجمالي' : '',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 13,
                        fontWeight: FontWeight.bold,
                        color: _accentColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // Scrollable columns for total
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _horizontalTotalController,
            child: Container(
              width: scrollableContentWidth,
              height: rowHeight,
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.1),
                border: Border(top: BorderSide(color: _accentColor, width: 2)),
              ),
              child: Row(
                children: [
                  ..._report!.periodColumns.map(
                    (column) => SizedBox(
                      width: 100,
                      child: _TotalCell(
                        value: totals[column]?.toString() ?? '0',
                        isMobile: isMobile,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: _TotalCell(
                      value: totals[_report!.totalColumn]?.toString() ?? '0',
                      isMobile: isMobile,
                      isGrandTotal: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Separate widget for header cell - reduces rebuilds
class _TableHeaderCell extends StatelessWidget {
  final String column;
  final String label;
  final bool isMobile;
  final bool isSorted;
  final bool sortAscending;
  final VoidCallback onTap;

  const _TableHeaderCell({
    required this.column,
    required this.label,
    required this.isMobile,
    required this.isSorted,
    required this.sortAscending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 4 : 8,
          vertical: isMobile ? 6 : 8,
        ),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.white.withOpacity(0.3), width: 1),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isMobile ? 10 : 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSorted) ...[
              const SizedBox(height: 2),
              Icon(
                sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: Colors.white,
                size: 10,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Separate widget for fixed row part
class _FixedRowPart extends StatelessWidget {
  final Map<String, dynamic> row;
  final int index;
  final bool isMobile;
  final List<String> fixedColumns;

  const _FixedRowPart({
    required this.row,
    required this.index,
    required this.isMobile,
    required this.fixedColumns,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: isMobile ? 48 : 56,
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
          left: const BorderSide(
            color: Color(AppConstants.primaryColor),
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: fixedColumns.map((column) {
          return Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
              child: Center(
                child: Text(
                  ArabicTextHelper.cleanText(row[column]?.toString() ?? ''),
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(AppConstants.primaryColor),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Separate widget for scrollable row part
class _ScrollableRowPart extends StatelessWidget {
  final Map<String, dynamic> row;
  final int index;
  final bool isMobile;
  final List<String> periodColumns;
  final String totalColumn;

  const _ScrollableRowPart({
    required this.row,
    required this.index,
    required this.isMobile,
    required this.periodColumns,
    required this.totalColumn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: isMobile ? 48 : 56,
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          ...periodColumns.map(
            (column) => SizedBox(
              width: 100,
              child: _DataCell(
                value: row[column]?.toString() ?? '',
                isMobile: isMobile,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: _DataCell(
              value: row[totalColumn]?.toString() ?? '',
              isMobile: isMobile,
              isTotal: true,
            ),
          ),
        ],
      ),
    );
  }
}

// Separate widget for data cell
class _DataCell extends StatelessWidget {
  final String value;
  final bool isMobile;
  final bool isTotal;

  const _DataCell({
    required this.value,
    required this.isMobile,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = value.isEmpty;
    final color = isEmpty
        ? Colors.grey.shade400
        : isTotal
            ? const Color(AppConstants.accentColor)
            : const Color(AppConstants.primaryColor);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 6),
      child: Center(
        child: Text(
          isEmpty ? '-' : Helpers.formatNumber(value),
          style: TextStyle(
            fontSize: isMobile ? 10 : 12,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
            color: color,
          ),
          textAlign: TextAlign.center,
          textDirection: ui.TextDirection.ltr,
        ),
      ),
    );
  }
}

// Separate widget for total cell
class _TotalCell extends StatelessWidget {
  final String value;
  final bool isMobile;
  final bool isGrandTotal;

  const _TotalCell({
    required this.value,
    required this.isMobile,
    this.isGrandTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final numValue = double.tryParse(value) ?? 0;
    final formattedValue = Helpers.formatNumber(numValue.toString());

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 6),
      child: Center(
        child: Text(
          formattedValue,
          style: TextStyle(
            fontSize: isMobile ? 11 : 13,
            fontWeight: FontWeight.bold,
            color: isGrandTotal
                ? const Color(AppConstants.primaryColor)
                : const Color(AppConstants.accentColor),
          ),
          textAlign: TextAlign.center,
          textDirection: ui.TextDirection.ltr,
        ),
      ),
    );
  }
}

// AppBar widget
class _LightAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppUser user;
  final PeriodicSalesReport? report;
  final VoidCallback onLogout;
  final bool isGeneratingPdf;
  final VoidCallback? onGeneratePdf;
  final VoidCallback onRefresh;
  final bool isDesktop;
  final String fromDate;
  final String toDate;
  final AreaSelection areaSelection;

  const _LightAppBar({
    required this.user,
    required this.report,
    required this.onLogout,
    required this.isGeneratingPdf,
    required this.onGeneratePdf,
    required this.onRefresh,
    required this.isDesktop,
    required this.fromDate,
    required this.toDate,
    required this.areaSelection,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back,
            color: Color(AppConstants.primaryColor)),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        isDesktop ? 'تقرير المبيعات بناءاً على الفترات' : 'تقرير المبيعات',
        style: const TextStyle(
          color: Color(AppConstants.primaryColor),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        if (report?.hasData == true)
          IconButton(
            icon: isGeneratingPdf
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(AppConstants.accentColor),
                    ),
                  )
                : const Icon(
                    Icons.picture_as_pdf,
                    color: Color(AppConstants.primaryColor),
                  ),
            onPressed: isGeneratingPdf ? null : onGeneratePdf,
            tooltip: 'إنشاء PDF',
          ),
        if (isDesktop)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Chip(
              label: Text(
                user.username,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              backgroundColor:
                  const Color(AppConstants.accentColor).withOpacity(0.1),
              side: BorderSide.none,
            ),
          ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'logout') {
              onLogout();
            } else if (value == 'refresh') {
              onRefresh();
            }
          },
          icon: const Icon(Icons.more_vert,
              color: Color(AppConstants.primaryColor)),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh,
                      color: const Color(AppConstants.accentColor), size: 18),
                  const SizedBox(width: 8),
                  const Text('تحديث'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.red.shade400, size: 18),
                  const SizedBox(width: 8),
                  const Text('تسجيل الخروج'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
