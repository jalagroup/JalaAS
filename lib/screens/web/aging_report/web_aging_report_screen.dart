// lib/screens/web/web_aging_report_screen.dart - Part 1 (Fixed)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/user.dart';
import '../../../models/aging_report.dart';
import '../../../services/supabase_service.dart';
import '../../../services/api_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';
import '../../../utils/arabic_text_helper.dart';
import '../web_login_screen.dart';
import 'dart:ui' as ui;

class WebAgingReportScreen extends StatefulWidget {
  final AppUser user;
  final String? selectedArea;
  final String? salesmanFrom;
  final String? salesmanTo;
  final String? dateType;
  final String? contactType;

  const WebAgingReportScreen({
    super.key,
    required this.user,
    this.selectedArea,
    this.salesmanFrom,
    this.salesmanTo,
    this.dateType,
    this.contactType,
  });

  @override
  State<WebAgingReportScreen> createState() => _WebAgingReportScreenState();
}

class _WebAgingReportScreenState extends State<WebAgingReportScreen>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  List<AgingReport> _agingReports = [];
  List<AgingReport> _filteredReports = [];
  bool _isLoading = true;

  String? _sortColumn;
  bool _sortAscending = true;
  String _activeFilterColumn = '';
  String _filterType = 'all';
  double _filterMin = 0;
  double _filterMax = 0;
  double _filterValue = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAgingReports());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatNumber(double value) {
    if (value == 0.0) return '0.00';
    return value.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }

  // FIXED: Enhanced number parsing to handle all formats properly
  double _parseNumericValue(String value) {
    if (value.isEmpty || value == '-' || value == '0' || value == '0.00')
      return 0.0;

    // Remove Arabic/Persian digits and replace with English
    String cleanValue = value
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .trim();

    // Remove currency symbols and extra spaces
    cleanValue = cleanValue
        .replaceAll('ر.س', '')
        .replaceAll('SAR', '')
        .replaceAll('SR', '')
        .replaceAll(RegExp(r'\s+'), '');

    // Handle different number formats
    if (cleanValue.contains('.') && cleanValue.contains(',')) {
      int lastDot = cleanValue.lastIndexOf('.');
      int lastComma = cleanValue.lastIndexOf(',');

      if (lastDot > lastComma) {
        // Format: 1,234.56 - comma is thousands separator
        cleanValue = cleanValue.replaceAll(',', '');
      } else {
        // Format: 1.234,56 - dot is thousands separator
        cleanValue = cleanValue.replaceAll('.', '').replaceAll(',', '.');
      }
    } else if (cleanValue.contains(',')) {
      List<String> parts = cleanValue.split(',');
      if (parts.length == 2 && parts[1].length <= 2) {
        // Decimal separator (e.g., "123,45")
        cleanValue = cleanValue.replaceAll(',', '.');
      } else {
        // Thousands separator (e.g., "1,234,567")
        cleanValue = cleanValue.replaceAll(',', '');
      }
    }

    // Final cleanup - remove any remaining non-numeric characters except dot and minus
    cleanValue = cleanValue.replaceAll(RegExp(r'[^\d.-]'), '');

    return double.tryParse(cleanValue) ?? 0.0;
  }

  String _formatStringValue(String value) {
    if (value.isEmpty || value == '-') return '0.00';
    double numValue = _parseNumericValue(value);
    return _formatNumber(numValue);
  }

  Future<void> _loadAgingReports() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final reports = await ApiService.getAgingReport(
        salesman: widget.user.salesman,
        area: widget.user.area,
        specificArea: widget.selectedArea,
        salesmanFrom: widget.salesmanFrom,
        salesmanTo: widget.salesmanTo,
        dateType: widget.dateType ?? 'month_end',
        contactType: widget.contactType ?? 'customers',
      );

      if (mounted) {
        setState(() {
          _agingReports = reports;
          _filteredReports = List.from(reports);
          _isLoading = false;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _calculate53PlusPercentage() {
    double total53Plus = 0.0;
    double grandTotal = 0.0;

    for (final report in _filteredReports) {
      total53Plus += _parseNumericValue(report.period53PlusDays);
      grandTotal += _parseNumericValue(report.total);
    }

    if (grandTotal == 0.0) return '0%';

    double percentage = (total53Plus / grandTotal) * 100;
    return '${percentage.toStringAsFixed(1)}%';
  }

  void _filterReports(String query) {
    if (!mounted) return;

    setState(() {
      List<AgingReport> searchFiltered = List.from(_agingReports);

      if (query.isNotEmpty) {
        searchFiltered = searchFiltered.where((report) {
          final nameMatch =
              report.contactName.toLowerCase().contains(query.toLowerCase());
          final codeMatch =
              report.contactCode.toLowerCase().contains(query.toLowerCase());
          return nameMatch || codeMatch;
        }).toList();
      }

      _filteredReports = searchFiltered;

      if (_sortColumn != null) {
        _applySorting();
      }
    });
  }

  double _getColumnValue(AgingReport report, String column) {
    switch (column) {
      case 'total':
        return _parseNumericValue(report.total);
      case '1-26days':
        return _parseNumericValue(report.period1To26Days);
      case '27-52days':
        return _parseNumericValue(report.period27To52Days);
      case '53+days':
        return _parseNumericValue(report.period53PlusDays);
      default:
        return 0.0;
    }
  }

  void _sortByColumn(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = false;
      }
      _applySorting();
    });
  }

  void _applySorting() {
    if (_sortColumn != null && _filteredReports.isNotEmpty) {
      _filteredReports.sort((a, b) {
        double valueA = _getColumnValue(a, _sortColumn!);
        double valueB = _getColumnValue(b, _sortColumn!);
        return _sortAscending
            ? valueA.compareTo(valueB)
            : valueB.compareTo(valueA);
      });
    }
  }

  String _calculateTotal(String field) {
    double total = 0.0;

    for (final report in _filteredReports) {
      String value = '';
      switch (field) {
        case 'total':
          value = report.total;
          break;
        case '1-26days':
          value = report.period1To26Days;
          break;
        case '27-52days':
          value = report.period27To52Days;
          break;
        case '53+days':
          value = report.period53PlusDays;
          break;
      }

      total += _parseNumericValue(value);
    }

    return _formatNumber(total);
  }

  String _buildHeaderSubtitle() {
    List<String> parts = [];

    // Date type information
    String dateTypeText =
        widget.dateType == 'current' ? 'التاريخ الحالي' : 'آخر يوم في الشهر';
    parts.add('تاريخ: $dateTypeText');

    // Contact type information
    String contactTypeText =
        widget.contactType == 'customers' ? 'الزبائن' : 'المتعثرين';
    parts.add('نوع: $contactTypeText');

    // Handle admin users (salesman '00' and area '00')
    if (widget.user.salesman == '00' &&
        (widget.user.area == '00' || widget.user.area == null)) {
      // Admin user - show range or specific selection
      if (widget.salesmanFrom != null || widget.salesmanTo != null) {
        final salesmen = ApiService.getAvailableSalesmen();
        final actualFrom = widget.salesmanFrom ??
            (salesmen.isNotEmpty ? salesmen.first.code : '00');
        final actualTo = widget.salesmanTo ??
            (salesmen.isNotEmpty ? salesmen.last.code : '00');

        if (actualFrom == actualTo) {
          parts.add('مندوب: $actualFrom');
        } else {
          parts.add('مندوبين: $actualFrom - $actualTo');
        }
      }

      // Add area information if selected
      if (widget.selectedArea != null && widget.selectedArea!.isNotEmpty) {
        parts.add('منطقة: ${widget.selectedArea}');
      }
    } else {
      // Regular user - show their specific salesman
      parts.add('مندوب: ${widget.user.salesman ?? 'غير محدد'}');

      // Add area information only if it exists and is not empty
      if (widget.user.area != null &&
          widget.user.area!.isNotEmpty &&
          widget.user.area != '00') {
        parts.add('منطقة: ${widget.user.area}');
      }
    }

    return parts.join(' - ');
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
          onLogout: _logout,
          onRefresh: _loadAgingReports,
          isDesktop: isDesktop,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 1000 : double.infinity,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  _buildHeaderSection(isDesktop, isMobile),

                  SizedBox(height: isMobile ? 20 : 24),

                  // Search Section - FIXED
                  if (!_isLoading && _agingReports.isNotEmpty)
                    _buildSearchSection(isMobile),

                  if (!_isLoading && _agingReports.isNotEmpty)
                    SizedBox(height: isMobile ? 20 : 24),

                  // Content Section
                  _isLoading
                      ? _buildLoadingState()
                      : _agingReports.isEmpty
                          ? _buildEmptyState()
                          : _filteredReports.isEmpty
                              ? _buildNoResultsState()
                              : _buildReportContent(isDesktop, isMobile),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(bool isDesktop, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isMobile ? 50 : 60,
            height: isMobile ? 50 : 60,
            decoration: BoxDecoration(
              color: const Color(AppConstants.accentColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.analytics,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تقرير التعميرة',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(AppConstants.primaryColor),
                  ),
                ),
                SizedBox(height: isMobile ? 4 : 6),
                Text(
                  _buildHeaderSubtitle(),
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (_filteredReports.isNotEmpty) ...[
            Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        const Color(AppConstants.accentColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_filteredReports.length} عميل',
                    style: const TextStyle(
                      color: Color(AppConstants.accentColor),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: Colors.red.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '+53: ${_calculate53PlusPercentage()}',
                        style: TextStyle(
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // FIXED: Search bar with proper height and spacing
  Widget _buildSearchSection(bool isMobile) {
    return Container(
      height: 48, // FIXED: Set specific height
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _filterReports,
        decoration: InputDecoration(
          labelText: 'البحث في التقرير',
          hintText: 'ادخل اسم العميل أو كوده',
          prefixIcon: Container(
            margin: const EdgeInsets.all(8), // FIXED: Reduced margin
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(AppConstants.accentColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.search,
              color: Colors.white,
              size: 16, // FIXED: Smaller icon
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(AppConstants.accentColor),
              width: 1.5,
            ),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12), // FIXED: Proper padding
          isDense: true, // FIXED: Makes the field more compact
        ),
        style: const TextStyle(fontSize: 14), // FIXED: Consistent text size
      ),
    );
  }

  // lib/screens/web/web_aging_report_screen.dart - Part 2 (Fixed)

  Widget _buildLoadingState() {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.05),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    Color(AppConstants.accentColor)),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'جاري تحميل التقرير...',
              style: TextStyle(
                color: Color(AppConstants.primaryColor),
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.05),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(
                Icons.analytics_outlined,
                size: 80,
                color: Colors.grey.shade300,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'لا توجد بيانات',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لم يتم العثور على تقرير تعميرة',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadAgingReports,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppConstants.accentColor),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'إعادة التحميل',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.05),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(
                Icons.search_off,
                size: 80,
                color: Colors.grey.shade300,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'لا توجد نتائج للبحث',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'جرب البحث بكلمات مختلفة',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _activeFilterColumn = '';
                  _filterType = 'all';
                  _sortColumn = null;
                });
                _filterReports('');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppConstants.accentColor),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'مسح البحث',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // FIXED: Enhanced report content with better number display
  Widget _buildReportContent(bool isDesktop, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(isMobile ? 2 : 4),
            decoration: const BoxDecoration(
              color: Color(AppConstants.primaryColor),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'العميل',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: isMobile ? 12 : 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _buildHeaderCell('total', 'المجموع', isMobile),
                ),
                Expanded(
                  flex: 2,
                  child: _buildHeaderCell('1-26days', '1-26', isMobile),
                ),
                Expanded(
                  flex: 2,
                  child: _buildHeaderCell('27-52days', '27-52', isMobile),
                ),
                Expanded(
                  flex: 2,
                  child: _buildHeaderCell('53+days', '+53', isMobile),
                ),
              ],
            ),
          ),

          // Data Rows - FIXED: Better container height and scrolling
          SizedBox(
            height: 300, // FIXED: Set specific height for table content
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: _filteredReports.length,
              itemBuilder: (context, index) {
                final report = _filteredReports[index];
                final isEven = index % 2 == 0;

                // lib/screens/web/web_aging_report_screen.dart - Part 3 (Final)

                return Container(
                  padding: EdgeInsets.all(
                      isMobile ? 8 : 12), // FIXED: Better padding
                  decoration: BoxDecoration(
                    color: isEven ? Colors.grey.shade50 : Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade200,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Customer Info
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ArabicTextHelper.cleanText(report.contactName),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: isMobile ? 11 : 13,
                                color: const Color(AppConstants.primaryColor),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'كود: ${report.contactCode}',
                              style: TextStyle(
                                fontSize: isMobile ? 9 : 10,
                                color: const Color(AppConstants.accentColor),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Total - FIXED: Better number display
                      Expanded(
                        flex: 2,
                        child: _buildDataCell(
                          report.total,
                          _parseNumericValue(report.total),
                          isMobile,
                        ),
                      ),

                      // 1-26 Days
                      Expanded(
                        flex: 2,
                        child: _buildDataCell(
                          report.period1To26Days,
                          _parseNumericValue(report.period1To26Days),
                          isMobile,
                          color: Colors.green.shade600,
                        ),
                      ),

                      // 27-52 Days
                      Expanded(
                        flex: 2,
                        child: _buildDataCell(
                          report.period27To52Days,
                          _parseNumericValue(report.period27To52Days),
                          isMobile,
                          color: Colors.orange.shade600,
                        ),
                      ),

                      // 53+ Days
                      Expanded(
                        flex: 2,
                        child: _buildDataCell(
                          report.period53PlusDays,
                          _parseNumericValue(report.period53PlusDays),
                          isMobile,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Summary Footer
          if (_filteredReports.isNotEmpty)
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: const Color(AppConstants.accentColor).withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    flex: 3,
                    child: Text(
                      'الإجمالي',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(AppConstants.accentColor),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child:
                        _buildSummaryCell(_calculateTotal('total'), isMobile),
                  ),
                  Expanded(
                    flex: 2,
                    child: _buildSummaryCell(
                        _calculateTotal('1-26days'), isMobile),
                  ),
                  Expanded(
                    flex: 2,
                    child: _buildSummaryCell(
                        _calculateTotal('27-52days'), isMobile),
                  ),
                  Expanded(
                    flex: 2,
                    child:
                        _buildSummaryCell(_calculateTotal('53+days'), isMobile),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String column, String title, bool isMobile) {
    bool isActiveSort = _sortColumn == column;

    return InkWell(
      onTap: () => _sortByColumn(column),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: isMobile ? 11 : 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isActiveSort) ...[
              const SizedBox(width: 4),
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: Colors.white,
                size: 14,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // FIXED: Better data cell with proper number formatting
  Widget _buildDataCell(String value, double numValue, bool isMobile,
      {Color? color}) {
    // Format the number properly
    String displayValue = _formatStringValue(value);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        displayValue,
        style: TextStyle(
          fontSize: isMobile ? 9 : 11,
          fontWeight: FontWeight.w500,
          color: numValue > 0
              ? (color ?? const Color(AppConstants.accentColor))
              : Colors.grey.shade500,
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildSummaryCell(String value, bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: isMobile ? 10 : 12,
          color: const Color(AppConstants.accentColor),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _LightAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppUser user;
  final VoidCallback onLogout;
  final VoidCallback onRefresh;
  final bool isDesktop;

  const _LightAppBar({
    required this.user,
    required this.onLogout,
    required this.onRefresh,
    required this.isDesktop,
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
        isDesktop ? 'تقرير التعميرة' : 'التعميرة',
        style: const TextStyle(
          color: Color(AppConstants.primaryColor),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        if (isDesktop)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Chip(
              label: Text(
                user.username,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
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
          icon: const Icon(
            Icons.more_vert,
            color: Color(AppConstants.primaryColor),
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(
                    Icons.refresh,
                    color: const Color(AppConstants.accentColor),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text('تحديث'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(
                    Icons.logout,
                    color: Colors.red.shade400,
                    size: 18,
                  ),
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
