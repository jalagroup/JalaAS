// lib/screens/web/web_aging_report_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Add this import
import '../../models/user.dart';
import '../../models/aging_report.dart';
import '../../services/supabase_service.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import 'web_login_screen.dart';
import 'dart:ui' as ui;

class WebAgingReportScreen extends StatefulWidget {
  final AppUser user;
  final String? selectedArea; // Legacy parameter for backward compatibility
  final String? salesmanFrom; // New parameter for admin salesman from
  final String? salesmanTo; // New parameter for admin salesman to

  const WebAgingReportScreen({
    super.key,
    required this.user,
    this.selectedArea,
    this.salesmanFrom,
    this.salesmanTo,
  });

  @override
  State<WebAgingReportScreen> createState() => _WebAgingReportScreenState();
}

class _WebAgingReportScreenState extends State<WebAgingReportScreen> {
  final _searchController = TextEditingController();
  List<AgingReport> _agingReports = [];
  List<AgingReport> _filteredReports = [];
  bool _isLoading = true;

  // Create a consistent number formatter for Arabic locale
  static final NumberFormat _numberFormatter =
      NumberFormat('#,##0.00', 'en_US');

  // New variables for table functionality
  final ScrollController _horizontalHeaderController = ScrollController();
  final ScrollController _horizontalDataController = ScrollController();
  final ScrollController _screenVerticalController = ScrollController();

  // Sorting variables
  String? _sortColumn;
  bool _sortAscending = true;

  // Filter variables
  String _activeFilterColumn = '';
  String _filterType = 'all'; // 'all', 'range', 'above', 'below'
  double _filterMin = 0;
  double _filterMax = 0;
  double _filterValue = 0;

  @override
  void initState() {
    super.initState();
    _loadAgingReports();

    // Synchronize horizontal scrolling
    _horizontalHeaderController.addListener(() {
      if (_horizontalHeaderController.offset !=
          _horizontalDataController.offset) {
        _horizontalDataController.jumpTo(_horizontalHeaderController.offset);
      }
    });

    _horizontalDataController.addListener(() {
      if (_horizontalDataController.offset !=
          _horizontalHeaderController.offset) {
        _horizontalHeaderController.jumpTo(_horizontalDataController.offset);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalHeaderController.dispose();
    _horizontalDataController.dispose();
    _screenVerticalController.dispose();
    super.dispose();
  }

// Helper method to safely parse numeric values from strings
  double _parseNumericValue(String value) {
    if (value.isEmpty || value == '-') return 0.0;

    // First, trim whitespace
    String cleanValue = value.trim();

    // Handle cases where the value might be in different formats
    if (cleanValue.contains('.') && cleanValue.contains(',')) {
      // Determine which is decimal separator based on position
      int lastDot = cleanValue.lastIndexOf('.');
      int lastComma = cleanValue.lastIndexOf(',');

      if (lastDot > lastComma) {
        // Dot is decimal separator, comma is thousands separator
        // Example: "1,234.56" -> remove commas, keep dot
        cleanValue = cleanValue.replaceAll(',', '');
      } else {
        // Comma is decimal separator, dot is thousands separator
        // Example: "1.234,56" -> remove dots, replace comma with dot
        cleanValue = cleanValue.replaceAll('.', '').replaceAll(',', '.');
      }
    } else if (cleanValue.contains(',')) {
      // Only comma - determine if it's thousands separator or decimal separator
      List<String> parts = cleanValue.split(',');
      if (parts.length == 2 && parts[1].length <= 2) {
        // Likely decimal separator (e.g., "123,45")
        cleanValue = cleanValue.replaceAll(',', '.');
      } else {
        // Likely thousands separator (e.g., "1,234" or "1,234,567")
        cleanValue = cleanValue.replaceAll(',', '');
      }
    }

    // Now remove any remaining non-numeric characters except dot and minus
    cleanValue = cleanValue.replaceAll(RegExp(r'[^\d.-]'), '');

    return double.tryParse(cleanValue) ?? 0.0;
  }

// COMPLETELY MANUAL FORMATTING - NO LOCALE DEPENDENCY
  String _formatNumber(double value) {
    if (value == 0.0) return '-';

    // Convert to string with 2 decimal places
    String numStr = value.toStringAsFixed(2);

    // Split into integer and decimal parts
    List<String> parts = numStr.split('.');
    String integerPart = parts[0];
    String decimalPart = parts[1];

    // Add commas manually to integer part (from right to left)
    String formattedInteger = '';
    for (int i = 0; i < integerPart.length; i++) {
      if (i > 0 && (integerPart.length - i) % 3 == 0) {
        formattedInteger += ',';
      }
      formattedInteger += integerPart[i];
    }

    return '$formattedInteger.$decimalPart';
  }

// Helper method to format string values consistently
  String _formatStringValue(String value) {
    if (value.isEmpty || value == '-') return '-';
    double numValue = _parseNumericValue(value);
    return _formatNumber(numValue);
  }

// Updated _loadAgingReports method
  Future<void> _loadAgingReports() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final reports = await ApiService.getAgingReport(
        salesman: widget.user.salesman,
        area: widget.user.area,
        specificArea: widget.selectedArea, // Legacy support
        salesmanFrom: widget.salesmanFrom, // New admin parameter
        salesmanTo: widget.salesmanTo, // New admin parameter
      );

      if (mounted) {
        setState(() {
          _agingReports = reports;
          _filteredReports = List.from(reports);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading aging reports: $e');

      if (mounted) {
        setState(() {
          _agingReports = [
            AgingReport(
              currency: 'ر.س',
              contactCode: 'C001',
              contactName: 'شركة الاختبار الأولى',
              contactPhone: '123456789',
              total: '150000.00',
              balance: '150000.00',
              period1To26Days: '50000.00',
              period27To52Days: '75000.00',
              period53PlusDays: '25000.00',
            ),
            AgingReport(
              currency: 'ر.س',
              contactCode: 'C002',
              contactName: 'شركة الاختبار الثانية',
              contactPhone: '987654321',
              total: '200000.00',
              balance: '200000.00',
              period1To26Days: '100000.00',
              period27To52Days: '60000.00',
              period53PlusDays: '40000.00',
            ),
            AgingReport(
              currency: 'ر.س',
              contactCode: 'C003',
              contactName: 'شركة الاختبار الثالثة',
              contactPhone: '555666777',
              total: '80000.00',
              balance: '80000.00',
              period1To26Days: '30000.00',
              period27To52Days: '30000.00',
              period53PlusDays: '20000.00',
            ),
            AgingReport(
              currency: 'ر.س',
              contactCode: 'C004',
              contactName: 'مؤسسة التجارة المتقدمة',
              contactPhone: '111222333',
              total: '300000.00',
              balance: '300000.00',
              period1To26Days: '150000.00',
              period27To52Days: '100000.00',
              period53PlusDays: '50000.00',
            ),
            AgingReport(
              currency: 'ر.س',
              contactCode: 'C005',
              contactName: 'شركة الخدمات الشاملة',
              contactPhone: '444555666',
              total: '120000.00',
              balance: '120000.00',
              period1To26Days: '80000.00',
              period27To52Days: '25000.00',
              period53PlusDays: '15000.00',
            ),
          ];
          _filteredReports = List.from(_agingReports);
          _isLoading = false;
        });

        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            try {
              Helpers.showSnackBar(
                context,
                'تم تحميل بيانات تجريبية (فشل الاتصال بالخادم)',
                isError: false,
              );
            } catch (snackBarError) {
              print('Failed to show snackbar: $snackBarError');
            }
          }
        });
      }
    }
  }

  // Method to calculate 53+ days percentage
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

      if (_activeFilterColumn.isNotEmpty && _filterType != 'all') {
        searchFiltered = searchFiltered.where((report) {
          double value = _getColumnValue(report, _activeFilterColumn);

          switch (_filterType) {
            case 'range':
              return value >= _filterMin && value <= _filterMax;
            case 'above':
              return value > _filterValue;
            case 'below':
              return value < _filterValue;
            default:
              return true;
          }
        }).toList();
      }

      _filteredReports = searchFiltered;

      if (_sortColumn != null) {
        _applySorting();
      }
    });
  }

  // Updated method to use consistent parsing
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

        int comparison = valueA.compareTo(valueB);
        return _sortAscending ? comparison : -comparison;
      });
    }
  }

  void _showFilterDialog(String column) {
    String columnTitle = _getColumnTitle(column);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(AppConstants.accentColor)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.filter_list,
                        color: Color(AppConstants.accentColor),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'تصفية $columnTitle',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(AppConstants.primaryColor),
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFilterOption(
                        'all',
                        'عرض الكل',
                        Icons.list,
                        setDialogState,
                      ),
                      _buildFilterOption(
                        'above',
                        'أكبر من',
                        Icons.keyboard_arrow_up,
                        setDialogState,
                      ),
                      _buildFilterOption(
                        'below',
                        'أقل من',
                        Icons.keyboard_arrow_down,
                        setDialogState,
                      ),
                      _buildFilterOption(
                        'range',
                        'بين قيمتين',
                        Icons.compare_arrows,
                        setDialogState,
                      ),
                      const SizedBox(height: 20),
                      if (_filterType == 'above' || _filterType == 'below') ...[
                        TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'القيمة',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.numbers),
                          ),
                          onChanged: (value) {
                            _filterValue = _parseNumericValue(value);
                          },
                        ),
                      ],
                      if (_filterType == 'range') ...[
                        TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'القيمة الدنيا',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.numbers),
                          ),
                          onChanged: (value) {
                            _filterMin = _parseNumericValue(value);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'القيمة العليا',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.numbers),
                          ),
                          onChanged: (value) {
                            _filterMax = _parseNumericValue(value);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _activeFilterColumn = '';
                        _filterType = 'all';
                      });
                      _filterReports(_searchController.text);
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'إزالة التصفية',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _activeFilterColumn = column;
                      });
                      _filterReports(_searchController.text);
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(AppConstants.accentColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'تطبيق',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterOption(
      String type, String title, IconData icon, StateSetter setDialogState) {
    return RadioListTile<String>(
      value: type,
      groupValue: _filterType,
      onChanged: (value) {
        setDialogState(() {
          _filterType = value!;
        });
      },
      title: Row(
        children: [
          Icon(icon, size: 20, color: const Color(AppConstants.accentColor)),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      activeColor: const Color(AppConstants.accentColor),
    );
  }

  String _getColumnTitle(String column) {
    switch (column) {
      case 'total':
        return 'المجموع';
      case '1-26days':
        return '1-26 أيام';
      case '27-52days':
        return '27-52 أيام';
      case '53+days':
        return '53+ أيام';
      default:
        return '';
    }
  }

  Future<void> _logout() async {
    try {
      await SupabaseService.signOut();
      await Helpers.setLoggedIn(false);
      await Helpers.clearUserData();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const WebLoginScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'فشل في تسجيل الخروج',
          isError: true,
        );
      }
    }
  }

  // Updated calculate total method with consistent formatting
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

  // Updated build method header section to show admin selection info
  String _buildHeaderSubtitle() {
    // Check if this is an admin user with salesman range selection
    if (widget.user.salesman == '00' && widget.user.area == '00') {
      List<String> parts = [];

      // Handle salesman range display
      if (widget.salesmanFrom != null || widget.salesmanTo != null) {
        // Get the actual values that will be used (with auto-completion)
        final salesmen = ApiService.getAvailableSalesmen();
        final actualFrom = widget.salesmanFrom ?? salesmen.first.code;
        final actualTo = widget.salesmanTo ?? salesmen.last.code;

        if (actualFrom == actualTo) {
          parts.add('مندوب: $actualFrom');
        } else {
          parts.add('مندوبين: $actualFrom - $actualTo');
        }
      }

      // Handle area display
      if (widget.selectedArea != null && widget.selectedArea!.isNotEmpty) {
        parts.add('منطقة: ${widget.selectedArea}');
      } else if (widget.salesmanFrom != null || widget.salesmanTo != null) {
        parts.add('جميع المناطق');
      }

      // If only area is selected (no salesman range)
      if (parts.isEmpty && widget.selectedArea != null) {
        parts.add('منطقة: ${widget.selectedArea} - جميع المندوبين');
      }

      return parts.isNotEmpty ? parts.join(' - ') : 'مدير النظام';
    } else {
      // Regular user
      return 'مندوب: ${widget.user.salesman}${widget.user.area != null ? ' - منطقة: ${widget.user.area}' : ''}';
    }
  }

// Updated build method with vertical layout for badges
// Updated build method header section to show admin selection info
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isDesktop = screenWidth >= 1024;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _WebAgingReportAppBar(
          currentUser: widget.user,
          onLogout: _logout,
          onRefresh: _loadAgingReports,
          isDesktop: isDesktop,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 1200 : 1000,
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Header Info - UPDATED SECTION
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(AppConstants.accentColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.analytics,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'تقرير التعميرة',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(AppConstants.primaryColor),
                                ),
                              ),
                              // Updated subtitle to show admin selection
                              Text(
                                _buildHeaderSubtitle(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_filteredReports.isNotEmpty)
                          Column(
                            children: [
                              // Customer count badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(AppConstants.accentColor)
                                      .withOpacity(0.1),
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
                              // 53+ Days percentage badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.red[600]!.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      size: 14,
                                      color: Colors.red[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '53+ : ${_calculate53PlusPercentage()}',
                                      style: TextStyle(
                                        color: Colors.red[600],
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                      textDirection: ui.TextDirection.ltr,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                // Search Field
                if (!_isLoading && _agingReports.isNotEmpty) ...[
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            spreadRadius: 2,
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _filterReports,
                        decoration: InputDecoration(
                          labelText: 'البحث في التقرير',
                          hintText: 'ادخل اسم العميل أو رقمه',
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(12),
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(AppConstants.accentColor),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.search,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(AppConstants.accentColor),
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 13, vertical: 15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Aging Reports Content
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 0),
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
                        )
                      : _agingReports.isEmpty
                          ? _buildEmptyState()
                          : _filteredReports.isEmpty
                              ? _buildNoSearchResults()
                              : _buildDataTable(isMobile, isDesktop),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Icon(
              Icons.analytics_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'لا توجد بيانات',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'لم يتم العثور على تقرير تعميرة',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadAgingReports,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConstants.accentColor),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 0,
            ),
            child: const Text(
              'إعادة التحميل',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResults() {
    bool hasActiveFilters =
        _activeFilterColumn.isNotEmpty || _searchController.text.isNotEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'لا توجد نتائج للبحث',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasActiveFilters
                ? 'جرب البحث بكلمات مختلفة أو امسح المرشحات'
                : 'جرب البحث بكلمات مختلفة',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          if (hasActiveFilters) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_searchController.text.isNotEmpty) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      _searchController.clear();
                      _filterReports('');
                    },
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('مسح البحث'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (_activeFilterColumn.isNotEmpty) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _activeFilterColumn = '';
                        _filterType = 'all';
                      });
                      _filterReports(_searchController.text);
                    },
                    icon: const Icon(Icons.filter_list_off, size: 18),
                    label: const Text('مسح المرشح'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(AppConstants.accentColor),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _activeFilterColumn = '';
                  _filterType = 'all';
                  _sortColumn = null;
                });
                _filterReports('');
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('مسح جميع المرشحات'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppConstants.primaryColor),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDataTable(bool isMobile, bool isDesktop) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;

    double getHeaderFontSize() {
      if (isMobile) return 10;
      if (isTablet) return 12;
      return 14;
    }

    double getDataFontSize() {
      if (isMobile) return 9;
      if (isTablet) return 11;
      return 12;
    }

    double getHorizontalPadding() {
      if (isMobile) return 8;
      if (isTablet) return 12;
      return 16;
    }

    double getVerticalPadding() {
      if (isMobile) return 8;
      if (isTablet) return 10;
      return 12;
    }

    double getRowHeight() {
      if (isMobile) return 70;
      if (isTablet) return 65;
      return 60;
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // Table Header
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: getHorizontalPadding(),
                vertical: getVerticalPadding(),
              ),
              decoration: const BoxDecoration(
                color: Color(AppConstants.primaryColor),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: isMobile ? 3 : 4,
                    child: Text(
                      'العميل',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: getHeaderFontSize(),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: isMobile ? 2 : 2,
                    child: _buildSimpleSortableHeader(
                        'total', 'المجموع', isMobile, getHeaderFontSize()),
                  ),
                  Expanded(
                    flex: isMobile ? 2 : 2,
                    child: _buildSimpleSortableHeader(
                        '1-26days',
                        isMobile ? '1-26' : '1-26 أيام',
                        isMobile,
                        getHeaderFontSize()),
                  ),
                  Expanded(
                    flex: isMobile ? 2 : 2,
                    child: _buildSimpleSortableHeader(
                        '27-52days',
                        isMobile ? '27-52' : '27-52 أيام',
                        isMobile,
                        getHeaderFontSize()),
                  ),
                  Expanded(
                    flex: isMobile ? 2 : 2,
                    child: _buildSimpleSortableHeader(
                        '53+days',
                        isMobile ? '53+' : '53+ أيام',
                        isMobile,
                        getHeaderFontSize()),
                  ),
                ],
              ),
            ),

            // Table Data
            Expanded(
              child: ListView.builder(
                itemCount: _filteredReports.length,
                itemBuilder: (context, index) {
                  final report = _filteredReports[index];
                  final isEven = index % 2 == 0;

                  return Container(
                    height: getRowHeight(),
                    padding: EdgeInsets.symmetric(
                      horizontal: getHorizontalPadding(),
                      vertical: getVerticalPadding(),
                    ),
                    decoration: BoxDecoration(
                      color: isEven ? Colors.grey[50] : Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey[200]!,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Customer Info
                        Expanded(
                          flex: isMobile ? 3 : 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                report.contactName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: getDataFontSize() + 1,
                                  color: const Color(AppConstants.primaryColor),
                                ),
                                maxLines: isMobile ? 2 : 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Total Amount - Using consistent formatting
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 2 : 4),
                            child: Text(
                              report.total,
                              style: TextStyle(
                                fontSize: getDataFontSize(),
                                fontWeight: FontWeight.w600,
                                color: _parseNumericValue(report.total) > 0
                                    ? const Color(AppConstants.accentColor)
                                    : Colors.grey[500],
                              ),
                              textDirection: ui.TextDirection.ltr,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),

                        // 1-26 Days - Using consistent formatting
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 2 : 4),
                            child: Text(
                              report.period1To26Days,
                              style: TextStyle(
                                fontSize: getDataFontSize(),
                                fontWeight: FontWeight.w500,
                                color:
                                    _parseNumericValue(report.period1To26Days) >
                                            0
                                        ? Colors.green[600]
                                        : Colors.grey[500],
                              ),
                              textDirection: ui.TextDirection.ltr,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),

                        // 27-52 Days - Using consistent formatting
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 2 : 4),
                            child: Text(
                              report.period27To52Days,
                              style: TextStyle(
                                fontSize: getDataFontSize(),
                                fontWeight: FontWeight.w500,
                                color: _parseNumericValue(
                                            report.period27To52Days) >
                                        0
                                    ? Colors.orange[600]
                                    : Colors.grey[500],
                              ),
                              textDirection: ui.TextDirection.ltr,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),

                        // 53+ Days - Using consistent formatting
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 2 : 4),
                            child: Text(
                              report.period53PlusDays,
                              style: TextStyle(
                                fontSize: getDataFontSize(),
                                fontWeight: FontWeight.w500,
                                color: _parseNumericValue(
                                            report.period53PlusDays) >
                                        0
                                    ? Colors.red[600]
                                    : Colors.grey[500],
                              ),
                              textDirection: ui.TextDirection.ltr,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
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
                padding: EdgeInsets.symmetric(
                  horizontal: getHorizontalPadding(),
                  vertical: getVerticalPadding(),
                ),
                decoration: BoxDecoration(
                  color: const Color(AppConstants.accentColor).withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: isMobile ? 3 : 4,
                      child: Text(
                        'الإجمالي',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: getHeaderFontSize(),
                          color: const Color(AppConstants.accentColor),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: isMobile ? 2 : 4),
                        child: Text(
                          _calculateTotal('total'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: getDataFontSize(),
                            color: const Color(AppConstants.accentColor),
                          ),
                          textDirection: ui.TextDirection.ltr,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: isMobile ? 2 : 4),
                        child: Text(
                          _calculateTotal('1-26days'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: getDataFontSize(),
                            color: const Color(AppConstants.accentColor),
                          ),
                          textDirection: ui.TextDirection.ltr,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: isMobile ? 2 : 4),
                        child: Text(
                          _calculateTotal('27-52days'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: getDataFontSize(),
                            color: const Color(AppConstants.accentColor),
                          ),
                          textDirection: ui.TextDirection.ltr,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: isMobile ? 2 : 4),
                        child: Text(
                          _calculateTotal('53+days'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: getDataFontSize(),
                            color: const Color(AppConstants.accentColor),
                          ),
                          textDirection: ui.TextDirection.ltr,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleSortableHeader(
      String column, String title, bool isMobile, double fontSize) {
    bool isActiveSort = _sortColumn == column;
    bool hasFilter = _activeFilterColumn == column;

    return InkWell(
      onTap: () => _sortByColumn(column),
      onLongPress: () => _showFilterDialog(column),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 2 : 4,
          vertical: isMobile ? 6 : 8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasFilter) ...[
              Icon(
                Icons.filter_list,
                color: const Color(AppConstants.accentColor),
                size: fontSize - 2,
              ),
              SizedBox(width: isMobile ? 1 : 2),
            ],
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                ),
                textAlign: TextAlign.center,
                maxLines: isMobile ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isActiveSort) ...[
              SizedBox(width: isMobile ? 1 : 2),
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: Colors.white,
                size: fontSize - 2,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WebAgingReportAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final AppUser currentUser;
  final VoidCallback onLogout;
  final VoidCallback onRefresh;
  final bool isDesktop;

  const _WebAgingReportAppBar({
    required this.currentUser,
    required this.onLogout,
    required this.onRefresh,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 4,
      backgroundColor: const Color(AppConstants.primaryColor),
      title: Row(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(
              AppConstants.logoPath,
              width: 28,
              height: 28,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.accentColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.account_balance,
                    size: 16,
                    color: Colors.white,
                  ),
                );
              },
            ),
          ),

          const SizedBox(width: 12),

          // Title
          Expanded(
            child: Text(
              'التعميرة',
              style: TextStyle(
                color: Colors.white,
                fontSize: isDesktop ? 20 : 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // User info for desktop
          if (isDesktop) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.white,
                    child: Text(
                      currentUser.username.isNotEmpty
                          ? currentUser.username[0].toUpperCase()
                          : 'م',
                      style: const TextStyle(
                        color: Color(AppConstants.primaryColor),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currentUser.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'logout') {
              onLogout();
            } else if (value == 'refresh') {
              onRefresh();
            }
          },
          icon: const Icon(Icons.more_vert, color: Colors.white),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh, color: Color(AppConstants.accentColor)),
                  SizedBox(width: 8),
                  Text('تحديث'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Color(AppConstants.errorColor)),
                  SizedBox(width: 8),
                  Text('تسجيل الخروج'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
