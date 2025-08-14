// lib/screens/mobile/aging_report_screen.dart
import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../models/aging_report.dart';
import '../../services/supabase_service.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import 'mobile_login_screen.dart';

class AgingReportScreen extends StatefulWidget {
  const AgingReportScreen({super.key});

  @override
  State<AgingReportScreen> createState() => _AgingReportScreenState();
}

// Update the _AgingReportScreenState class with search functionality

class _AgingReportScreenState extends State<AgingReportScreen> {
  final _searchController = TextEditingController();
  List<AgingReport> _agingReports = [];
  List<AgingReport> _filteredReports = [];
  bool _isLoading = true;
  AppUser? _currentUser;

  // New variables for sorting and filtering functionality
  String? _sortColumn;
  bool _sortAscending = true;
  String _activeFilterColumn = '';
  String _filterType = 'all'; // 'all', 'range', 'above', 'below'
  double _filterMin = 0;
  double _filterMax = 0;
  double _filterValue = 0;

  @override
  void initState() {
    super.initState();
    _loadUserAndReports();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndReports() async {
    try {
      _currentUser = await SupabaseService.getCurrentUser();

      if (_currentUser == null) {
        _navigateToLogin();
        return;
      }

      await _loadAgingReports();
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'فشل في تحميل بيانات المستخدم',
          isError: true,
        );
      }
    }
  }

  Future<void> _loadAgingReports() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final reports = await ApiService.getAgingReport(
        salesman: _currentUser!.salesman,
        area: _currentUser!.area,
      );

      if (mounted) {
        setState(() {
          _agingReports = reports;
          _filteredReports = List.from(reports); // Create a copy
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading aging reports: $e'); // Debug print

      // For testing purposes, let's add some mock data when API fails
      if (mounted) {
        setState(() {
          // Create mock data for testing with proper AgingReport constructor
          _agingReports = [
            AgingReport(
              currency: 'ر.س',
              contactCode: 'C001',
              contactName: 'شركة الاختبار الأولى',
              contactPhone: '123456789',
              total: '150,000.00',
              balance: '150,000.00',
              period1To26Days: '50,000.00',
              period27To52Days: '75,000.00',
              period53PlusDays: '25,000.00',
            ),
            AgingReport(
              currency: 'ر.س',
              contactCode: 'C002',
              contactName: 'شركة الاختبار الثانية',
              contactPhone: '987654321',
              total: '200,000.00',
              balance: '200,000.00',
              period1To26Days: '100,000.00',
              period27To52Days: '60,000.00',
              period53PlusDays: '40,000.00',
            ),
            AgingReport(
              currency: 'ر.س',
              contactCode: 'C003',
              contactName: 'شركة الاختبار الثالثة',
              contactPhone: '555666777',
              total: '80,000.00',
              balance: '80,000.00',
              period1To26Days: '30,000.00',
              period27To52Days: '30,000.00',
              period53PlusDays: '20,000.00',
            ),
            AgingReport(
              currency: 'ر.س',
              contactCode: 'C004',
              contactName: 'مؤسسة التجارة المتقدمة',
              contactPhone: '111222333',
              total: '300,000.00',
              balance: '300,000.00',
              period1To26Days: '150,000.00',
              period27To52Days: '100,000.00',
              period53PlusDays: '50,000.00',
            ),
            AgingReport(
              currency: 'ر.س',
              contactCode: 'C005',
              contactName: 'شركة الخدمات الشاملة',
              contactPhone: '444555666',
              total: '120,000.00',
              balance: '120,000.00',
              period1To26Days: '80,000.00',
              period27To52Days: '25,000.00',
              period53PlusDays: '15,000.00',
            ),
          ];
          _filteredReports = List.from(_agingReports);
          _isLoading = false;
        });

        // Add a small delay to ensure widget is fully built before showing snackbar
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

  // Updated filter method with value-based filtering
  void _filterReports(String query) {
    setState(() {
      List<AgingReport> searchFiltered = List.from(_agingReports);

      // Text search filter
      if (query.isNotEmpty) {
        searchFiltered = searchFiltered.where((report) {
          final nameMatch =
              report.contactName.toLowerCase().contains(query.toLowerCase());
          final codeMatch =
              report.contactCode.toLowerCase().contains(query.toLowerCase());
          return nameMatch || codeMatch;
        }).toList();
      }

      // Value-based filter
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

      // Apply sorting if there's an active sort column
      if (_sortColumn != null) {
        _applySorting();
      }
    });
  }

  // Get numeric value from report column using the model's helper methods
  double _getColumnValue(AgingReport report, String column) {
    switch (column) {
      case 'total':
        return report.totalAmount;
      case '1-26days':
        return report.period1To26Amount;
      case '27-52days':
        return report.period27To52Amount;
      case '53+days':
        return report.period53PlusAmount;
      default:
        return 0.0;
    }
  }

  // Sorting functionality
  void _sortByColumn(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = false; // Start with descending (bigger to smaller)
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

  // Show filter dialog
  void _showFilterDialog(String column) {
    String columnTitle = _getColumnTitle(column);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
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
                      // Filter type selection
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

                      // Input fields based on filter type
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
                            _filterValue = double.tryParse(value) ?? 0;
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
                            _filterMin = double.tryParse(value) ?? 0;
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
                            _filterMax = double.tryParse(value) ?? 0;
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
        _navigateToLogin();
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

  void _navigateToLogin() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
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

      if (value.isNotEmpty) {
        total += double.tryParse(value.replaceAll(',', '')) ?? 0.0;
      }
    }

    if (total == 0.0) return '-';

    return total.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _currentUser != null
            ? _AgingReportAppBar(
                currentUser: _currentUser!,
                onLogout: _logout,
                onRefresh: _loadAgingReports,
              )
            : AppBar(
                title: const Text('التعميرة'),
                backgroundColor: const Color(AppConstants.primaryColor),
                foregroundColor: Colors.white,
              ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Header Info
                if (_currentUser != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                                Text(
                                  'مندوب: ${_currentUser!.salesman}${_currentUser!.area != null ? ' - منطقة: ${_currentUser!.area}' : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_filteredReports.isNotEmpty)
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Search Field
                if (!_isLoading && _agingReports.isNotEmpty) ...[
                  _buildSearchField(),
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
                              : Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 15),
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
                                        // Table Header with sorting and filtering
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                          decoration: const BoxDecoration(
                                            color: Color(
                                                AppConstants.primaryColor),
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(16),
                                              topRight: Radius.circular(16),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Expanded(
                                                flex: 3,
                                                child: Text(
                                                  'العميل',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              _buildSortableHeader(
                                                  'total', 'المجموع'),
                                              _buildSortableHeader(
                                                  '1-26days', '1-26 أيام'),
                                              _buildSortableHeader(
                                                  '27-52days', '27-52 أيام'),
                                              _buildSortableHeader(
                                                  '53+days', '53+ أيام'),
                                            ],
                                          ),
                                        ),

                                        // Table Data
                                        Expanded(
                                          child: ListView.builder(
                                            itemCount: _filteredReports.length,
                                            itemBuilder: (context, index) {
                                              final report =
                                                  _filteredReports[index];
                                              final isEven = index % 2 == 0;

                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 12),
                                                decoration: BoxDecoration(
                                                  color: isEven
                                                      ? Colors.grey[50]
                                                      : Colors.white,
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
                                                      flex: 3,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            report.contactName,
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 12,
                                                              color: Color(
                                                                  AppConstants
                                                                      .primaryColor),
                                                            ),
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                          const SizedBox(
                                                              height: 2),
                                                          Text(
                                                            report.contactCode,
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: Colors
                                                                  .grey[600],
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),

                                                    // Total Amount
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                        report.total.isNotEmpty
                                                            ? report.total
                                                            : '-',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: report.total
                                                                  .isNotEmpty
                                                              ? const Color(
                                                                  AppConstants
                                                                      .accentColor)
                                                              : Colors
                                                                  .grey[500],
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ),

                                                    // 1-26 Days
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                        report.period1To26Days
                                                                .isNotEmpty
                                                            ? report
                                                                .period1To26Days
                                                            : '-',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: report
                                                                  .period1To26Days
                                                                  .isNotEmpty
                                                              ? Colors
                                                                  .green[600]
                                                              : Colors
                                                                  .grey[500],
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ),

                                                    // 27-52 Days
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                        report.period27To52Days
                                                                .isNotEmpty
                                                            ? report
                                                                .period27To52Days
                                                            : '-',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: report
                                                                  .period27To52Days
                                                                  .isNotEmpty
                                                              ? Colors
                                                                  .orange[600]
                                                              : Colors
                                                                  .grey[500],
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ),

                                                    // 53+ Days
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                        report.period53PlusDays
                                                                .isNotEmpty
                                                            ? report
                                                                .period53PlusDays
                                                            : '-',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: report
                                                                  .period53PlusDays
                                                                  .isNotEmpty
                                                              ? Colors.red[600]
                                                              : Colors
                                                                  .grey[500],
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
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
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                      AppConstants.accentColor)
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  const BorderRadius.only(
                                                bottomLeft: Radius.circular(16),
                                                bottomRight:
                                                    Radius.circular(16),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    'الإجمالي',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                      color: Color(AppConstants
                                                          .accentColor),
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    _calculateTotal('total'),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                      color: Color(AppConstants
                                                          .accentColor),
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    _calculateTotal('1-26days'),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                      color: Color(AppConstants
                                                          .accentColor),
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    _calculateTotal(
                                                        '27-52days'),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                      color: Color(AppConstants
                                                          .accentColor),
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    _calculateTotal('53+days'),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                      color: Color(AppConstants
                                                          .accentColor),
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                ),
                const SizedBox(height: 16.0),
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

          // Show clear filters button when there are active filters
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

  Widget _buildSortableHeader(String column, String title) {
    bool isActiveSort = _sortColumn == column;
    bool hasFilter = _activeFilterColumn == column;

    return Expanded(
      flex: 2,
      child: InkWell(
        onTap: () => _sortByColumn(column),
        onLongPress: () => _showFilterDialog(column),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasFilter) ...[
                const Icon(
                  Icons.filter_list,
                  color: Color(AppConstants.accentColor),
                  size: 12,
                ),
                const SizedBox(width: 2),
              ],
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isActiveSort) ...[
                const SizedBox(width: 2),
                Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  color: Colors.white,
                  size: 12,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
            suffixIcon: _searchController.text.isNotEmpty ||
                    _activeFilterColumn.isNotEmpty
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_activeFilterColumn.isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(AppConstants.accentColor)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.filter_list,
                                size: 14,
                                color: Color(AppConstants.accentColor),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getColumnTitle(_activeFilterColumn),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(AppConstants.accentColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _activeFilterColumn = '';
                            _filterType = 'all';
                          });
                          _filterReports('');
                        },
                        icon: const Icon(
                          Icons.clear,
                          color: Colors.grey,
                          size: 20,
                        ),
                      ),
                    ],
                  )
                : null,
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
          ),
        ),
      ),
    );
  }
}

class _AgingReportAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final AppUser currentUser;
  final VoidCallback onLogout;
  final VoidCallback onRefresh;

  const _AgingReportAppBar({
    required this.currentUser,
    required this.onLogout,
    required this.onRefresh,
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
          const Expanded(
            child: Text(
              'التعميرة',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
