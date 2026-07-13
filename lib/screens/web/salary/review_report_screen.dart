// lib/screens/web/salary/review_report_screen.dart

import 'package:flutter/material.dart';
import 'package:jala_as/models/user.dart';
import 'package:jala_as/models/salary_models.dart';
import 'package:jala_as/screens/web/salary/report_details_screen.dart';
import 'package:jala_as/screens/web/salary/set_targets_screen.dart';
import 'package:jala_as/services/salary_calculation_service.dart';
import 'package:jala_as/services/salary_excel_export_service.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/helpers.dart';
import 'package:jala_as/utils/file_saver.dart';

class ReviewReportScreen extends StatefulWidget {
  const ReviewReportScreen({super.key});

  @override
  State<ReviewReportScreen> createState() => _ReviewReportScreenState();
}

class _ReviewReportScreenState extends State<ReviewReportScreen> {
  AppUser? _currentUser;
  List<AppUser> _groupUsers = [];
  DateTime _selectedMonth = DateTime.now();
  GroupSalaryReport? _groupReport;
  bool _isLoading = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = await SupabaseService.getCurrentUser();
      if (_currentUser != null) {
        await _loadReport();
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في التحميل: $e', isError: true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadReport() async {
    if (_currentUser == null) return;

    setState(() => _isLoading = true);
    try {
      final allUsers = await SupabaseService.getUsers();

      if (_currentUser!.isSalesManager) {
        _groupUsers =
            allUsers.where((u) => u.isRegularUser || u.isSalesAdmin).toList();
      } else if (_currentUser!.isSalesAdmin &&
          _currentUser!.salesAdmin != null) {
        final groupSalesmenCodes =
            await SupabaseService.getSalesmenInAdminGroup(
                _currentUser!.salesAdmin!);

        _groupUsers = allUsers.where((u) {
          if (groupSalesmenCodes.contains(u.salesman)) return true;
          if (u.salesman == '00' && u.salesAdmin != null) {
            return groupSalesmenCodes.contains(u.salesAdmin);
          }
          return false;
        }).toList();
      } else {
        _groupUsers = [];
      }

      _groupReport = await SalaryCalculationService.buildGroupSalaryReport(
        users: _groupUsers,
        targetMonth: DateTime(_selectedMonth.year, _selectedMonth.month, 1),
        currentUser: _currentUser!,
      );

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في تحميل التقرير: $e',
            isError: true);
      }
    }
  }

  Future<void> _exportToExcel() async {
    if (_groupReport == null) return;

    setState(() => _isExporting = true);
    try {
      final excelBytes =
          await SalaryExcelExportService.exportGroupReport(_groupReport!);

      final fileName =
          'salary_report_${Helpers.formatMonthYear(_selectedMonth).replaceAll(' ', '_')}.xlsx';

      await FileSaver.saveFile(
        fileName: fileName,
        bytes: excelBytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (mounted) {
        Helpers.showSnackBar(context, 'تم تصدير التقرير بنجاح');
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في التصدير: $e', isError: true);
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: isMobile ? _buildMobileAppBar() : null,
        body: Column(
          children: [
            // Header - Desktop only
            if (!isMobile) _buildDesktopHeader(),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _groupReport == null
                      ? _buildEmptyState(isMobile)
                      : _buildReportContent(isMobile),
            ),
          ],
        ),
        // FAB for mobile actions
        floatingActionButton: isMobile && _groupReport != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    heroTag: 'export',
                    onPressed: _isExporting ? null : _exportToExcel,
                    backgroundColor: Colors.green,
                    mini: true,
                    child: _isExporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    heroTag: 'details',
                    onPressed: _navigateToDetails,
                    backgroundColor: const Color(0xFF135467),
                    child: const Icon(Icons.visibility, color: Colors.white),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'مراجعة التقرير',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          Text(
            Helpers.formatMonthYear(_selectedMonth),
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF546E7A),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.calendar_today, color: Color(0xFF135467)),
          onPressed: _selectMonth,
        ),
      ],
    );
  }

  Widget _buildDesktopHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back Button
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
            onPressed: () => Navigator.pop(context),
            tooltip: 'رجوع',
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF135467).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.analytics,
              color: Color(0xFF135467),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مراجعة التقرير',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'تقرير الأهداف والمبيعات للمجموعة',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF546E7A),
                  ),
                ),
              ],
            ),
          ),
          // Month Selector
          InkWell(
            onTap: _selectMonth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    Helpers.formatMonthYear(_selectedMonth),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Export Button
          if (_isExporting)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            ElevatedButton.icon(
              onPressed: _groupReport != null ? _exportToExcel : null,
              icon: const Icon(Icons.download, size: 20),
              label: const Text('تصدير Excel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF135467),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isMobile) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: isMobile ? 48 : 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد بيانات للعرض',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'قم باختيار الشهر لعرض التقرير',
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent(bool isMobile) {
    if (_groupReport == null) return const SizedBox();

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistics Cards
          _buildStatisticsCards(isMobile),
          const SizedBox(height: 24),

          // Perfect Salesman Card
          if (_groupReport!.perfectSalesman != null) ...[
            _buildPerfectSalesmanCard(isMobile),
            const SizedBox(height: 24),
          ],

          // Consolidated Brands Table
          _buildConsolidatedTable(isMobile),
          const SizedBox(height: 24),

          // See Details Button - Desktop only
          if (!isMobile)
            Center(
              child: ElevatedButton.icon(
                onPressed: _navigateToDetails,
                icon: const Icon(Icons.visibility),
                label: const Text('عرض التفاصيل'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF135467),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards(bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          _buildStatCard(
            'إجمالي المبيعات بالتجزئة',
            Helpers.formatCurrency(_groupReport!.totalRetailSales),
            Icons.shopping_cart,
            Colors.blue,
            isMobile,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'إجمالي المبيعات بالجملة',
            Helpers.formatCurrency(_groupReport!.totalWholesaleSales),
            Icons.business,
            Colors.green,
            isMobile,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'نسبة التجزئة',
            '${_groupReport!.retailPercentage.toStringAsFixed(2)}%',
            Icons.percent,
            Colors.orange,
            isMobile,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'إجمالي المبيعات بالتجزئة',
            Helpers.formatCurrency(_groupReport!.totalRetailSales),
            Icons.shopping_cart,
            Colors.blue,
            isMobile,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'إجمالي المبيعات بالجملة',
            Helpers.formatCurrency(_groupReport!.totalWholesaleSales),
            Icons.business,
            Colors.green,
            isMobile,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'نسبة التجزئة',
            '${_groupReport!.retailPercentage.toStringAsFixed(2)}%',
            Icons.percent,
            Colors.orange,
            isMobile,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: isMobile ? 20 : 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerfectSalesmanCard(bool isMobile) {
    final perfect = _groupReport!.perfectSalesman!;
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: Color(0xFFFFD700),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'المندوب المثالي',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            perfect.username,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'نسبة الإنجاز: ${perfect.achievementPercentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD700),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    color: Color(0xFFFFD700),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'المندوب المثالي',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        perfect.username,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${perfect.achievementPercentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD700),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildConsolidatedTable(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ملخص العلامات التجارية',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _groupReport!.agingPercentage < 4
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'الذمم المتأخرة: ${_groupReport!.agingPercentage.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _groupReport!.agingPercentage < 4
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Text(
                        'ملخص العلامات التجارية',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _groupReport!.agingPercentage < 4
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'الذمم المتأخرة: ${_groupReport!.agingPercentage.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _groupReport!.agingPercentage < 4
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const Divider(height: 1),
          isMobile
              ? _buildMobileBrandsList()
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(
                      const Color(0xFF135467).withOpacity(0.1),
                    ),
                    columns: const [
                      DataColumn(
                          label: Text('العلامة التجارية',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('الهدف الشهري',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('النسبة من الكلي',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('المبيعات الحالية',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('الانحراف',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('نسبة الإنحراف',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('عدد الزبائن',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: _groupReport!.consolidatedBrandData.map((brand) {
                      return DataRow(
                        cells: [
                          DataCell(
                              Text('${brand.brandCode} - ${brand.brandName}')),
                          DataCell(
                              Text(Helpers.formatCurrency(brand.targetAmount))),
                          DataCell(Text(
                              '${brand.targetPercent.toStringAsFixed(2)}%')),
                          DataCell(
                              Text(Helpers.formatCurrency(brand.salesAmount))),
                          DataCell(
                            Text(
                              Helpers.formatCurrency(brand.deviation),
                              style: TextStyle(
                                color: brand.deviation > 0
                                    ? Colors.red
                                    : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${brand.deviationPercent.toStringAsFixed(2)}%',
                              style: TextStyle(
                                color: brand.deviationPercent > 0
                                    ? Colors.red
                                    : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataCell(Text(brand.customerCount.toString())),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildMobileBrandsList() {
    return Column(
      children: _groupReport!.consolidatedBrandData.map((brand) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${brand.brandCode} - ${brand.brandName}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMiniStat(
                        'الهدف', Helpers.formatCurrency(brand.targetAmount)),
                  ),
                  Expanded(
                    child: _buildMiniStat(
                        'المبيعات', Helpers.formatCurrency(brand.salesAmount)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMiniStat(
                      'الانحراف',
                      Helpers.formatCurrency(brand.deviation),
                      valueColor:
                          brand.deviation > 0 ? Colors.red : Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildMiniStat(
                        'الزبائن', brand.customerCount.toString()),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMiniStat(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: valueColor ?? const Color(0xFF2C3E50),
          ),
        ),
      ],
    );
  }

  void _navigateToDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportDetailsScreen(
          groupReport: _groupReport!,
          selectedMonth: _selectedMonth,
        ),
      ),
    );
  }

  Future<void> _selectMonth() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => MonthYearPickerDialog(initialDate: _selectedMonth),
    );

    if (picked != null) {
      setState(() => _selectedMonth = picked);
      await _loadReport();
    }
  }
}
