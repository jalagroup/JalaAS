// lib/screens/web/salary/salary_calculation_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jala_as/models/user.dart';
import 'package:jala_as/models/salary_models.dart';
import 'package:jala_as/services/salary_calculation_service.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/helpers.dart';

class SalaryCalculationDetailScreen extends StatefulWidget {
  final AppUser user;
  final DateTime selectedMonth;
  final AppUser currentUser;

  const SalaryCalculationDetailScreen({
    super.key,
    required this.user,
    required this.selectedMonth,
    required this.currentUser,
  });

  @override
  State<SalaryCalculationDetailScreen> createState() =>
      _SalaryCalculationDetailScreenState();
}

class _SalaryCalculationDetailScreenState
    extends State<SalaryCalculationDetailScreen> {
  SalesmanSalaryReport? _report;
  bool _isLoading = false;
  bool _isSaving = false;

  // Adjustment controllers
  Map<String, TextEditingController> _plusControllers = {};
  Map<String, TextEditingController> _minusControllers = {};
  TextEditingController _bonusController = TextEditingController();

  // To track if user is perfect salesman in group
  bool _isPerfectSalesman = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final report = await SalaryCalculationService.buildGroupSalaryReport(
        users: [widget.user],
        targetMonth:
            DateTime(widget.selectedMonth.year, widget.selectedMonth.month, 1),
        currentUser: widget.currentUser,
      );

      if (report.salesmenReports.isNotEmpty) {
        _report = report.salesmenReports.first;

        for (final brand in _report!.brandData) {
          _plusControllers[brand.brandCode] = TextEditingController(
            text:
                brand.plusAmount > 0 ? brand.plusAmount.toStringAsFixed(2) : '',
          );
          _minusControllers[brand.brandCode] = TextEditingController(
            text: brand.minusAmount > 0
                ? brand.minusAmount.toStringAsFixed(2)
                : '',
          );
        }

        await _loadAdjustments();
        await _checkPerfectSalesman();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في تحميل البيانات: $e',
            isError: true);
      }
    }
  }

  Future<void> _loadAdjustments() async {
    try {
      final adjustments = await SupabaseService.getSalaryAdjustments(
        userId: widget.user.id,
        targetMonth:
            DateTime(widget.selectedMonth.year, widget.selectedMonth.month, 1),
      );

      for (final adjustment in adjustments) {
        if (_plusControllers.containsKey(adjustment.brandCode)) {
          _plusControllers[adjustment.brandCode]!.text =
              adjustment.plusAmount > 0
                  ? adjustment.plusAmount.toStringAsFixed(2)
                  : '';
        }
        if (_minusControllers.containsKey(adjustment.brandCode)) {
          _minusControllers[adjustment.brandCode]!.text =
              adjustment.minusAmount > 0
                  ? adjustment.minusAmount.toStringAsFixed(2)
                  : '';
        }
      }
    } catch (e) {
      print('Error loading adjustments: $e');
    }
  }

  Future<void> _checkPerfectSalesman() async {
    try {
      final allUsers = await SupabaseService.getUsers();
      List<AppUser> groupUsers;

      if (widget.currentUser.isSalesManager) {
        groupUsers =
            allUsers.where((u) => u.isRegularUser || u.isSalesAdmin).toList();
      } else if (widget.currentUser.isSalesAdmin &&
          widget.currentUser.salesAdmin != null) {
        final groupSalesmen = widget.currentUser.availableSalesmenCodes;
        groupUsers = allUsers
            .where((u) => u.isRegularUser && groupSalesmen.contains(u.salesman))
            .toList();
      } else {
        groupUsers = [widget.user];
      }

      final fullReport = await SalaryCalculationService.buildGroupSalaryReport(
        users: groupUsers,
        targetMonth:
            DateTime(widget.selectedMonth.year, widget.selectedMonth.month, 1),
        currentUser: widget.currentUser,
      );

      if (fullReport.perfectSalesman != null) {
        setState(() {
          _isPerfectSalesman =
              fullReport.perfectSalesman!.userId == widget.user.id;
        });
      }
    } catch (e) {
      print('Error checking perfect salesman: $e');
    }
  }

  void _applyAdjustment(String brandCode, String type) {
    if (_report == null) return;

    final brandIndex =
        _report!.brandData.indexWhere((b) => b.brandCode == brandCode);
    if (brandIndex == -1) return;

    final brand = _report!.brandData[brandIndex];

    if (type == 'plus') {
      final value = double.tryParse(_plusControllers[brandCode]!.text) ?? 0;
      brand.plusAmount = value;
    } else {
      final value = double.tryParse(_minusControllers[brandCode]!.text) ?? 0;
      brand.minusAmount = value;
    }

    setState(() {});
  }

  Future<void> _saveAdjustments() async {
    if (_report == null) return;

    setState(() => _isSaving = true);
    try {
      await SalaryCalculationService.saveAdjustments(
        userId: widget.user.id,
        targetMonth:
            DateTime(widget.selectedMonth.year, widget.selectedMonth.month, 1),
        brandData: _report!.brandData,
        createdBy: widget.currentUser.id,
      );

      if (mounted) {
        Helpers.showSnackBar(context, 'تم حفظ التعديلات بنجاح');
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في الحفظ: $e', isError: true);
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _plusControllers.values.forEach((c) => c.dispose());
    _minusControllers.values.forEach((c) => c.dispose());
    _bonusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: isMobile ? 1 : 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'حساب راتب ${widget.user.username}',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2C3E50),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                Helpers.formatMonthYear(widget.selectedMonth),
                style: TextStyle(
                  fontSize: isMobile ? 11 : 12,
                  color: const Color(0xFF546E7A),
                ),
              ),
            ],
          ),
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              isMobile
                  ? IconButton(
                      icon: const Icon(Icons.save, color: Color(0xFF135467)),
                      onPressed: _saveAdjustments,
                    )
                  : TextButton.icon(
                      onPressed: _saveAdjustments,
                      icon: const Icon(Icons.save),
                      label: const Text('حفظ التعديلات'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF135467),
                      ),
                    ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _report == null
                ? const Center(child: Text('لا توجد بيانات'))
                : SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Statistics Cards
                        _buildStatisticsCards(isMobile),
                        const SizedBox(height: 24),

                        // Brands Table with Adjustments
                        _buildBrandsTableWithAdjustments(isMobile),
                        const SizedBox(height: 24),

                        // Salary Calculations
                        _buildSalaryCalculations(isMobile),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildStatisticsCards(bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'إجمالي الهدف',
                  Helpers.formatCurrency(_report!.adjustedTotalTarget),
                  Icons.flag,
                  Colors.blue,
                  isMobile,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'إجمالي المبيعات',
                  Helpers.formatCurrency(_report!.adjustedTotalSales),
                  Icons.trending_up,
                  Colors.green,
                  isMobile,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'نسبة الإنجاز',
                  '${_report!.achievementPercentage.toStringAsFixed(1)}%',
                  Icons.percent,
                  _getAchievementColor(_report!.achievementPercentage),
                  isMobile,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'نسبة الذمم',
                  '${_report!.agingPercentage.toStringAsFixed(2)}%',
                  Icons.warning,
                  _report!.agingPercentage < 4 ? Colors.green : Colors.red,
                  isMobile,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'إجمالي الهدف',
                Helpers.formatCurrency(_report!.adjustedTotalTarget),
                Icons.flag,
                Colors.blue,
                isMobile,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'إجمالي المبيعات',
                Helpers.formatCurrency(_report!.adjustedTotalSales),
                Icons.trending_up,
                Colors.green,
                isMobile,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'نسبة الإنجاز',
                '${_report!.achievementPercentage.toStringAsFixed(1)}%',
                Icons.percent,
                _getAchievementColor(_report!.achievementPercentage),
                isMobile,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (_report!.retailSalesTotal > 0) ...[
              Expanded(
                child: _buildStatCard(
                  'نسبة التجزئة',
                  '${_report!.retailPercentage.toStringAsFixed(2)}%',
                  Icons.store,
                  Colors.orange,
                  isMobile,
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: _buildStatCard(
                'إجمالي الذمم',
                Helpers.formatCurrency(_report!.agingTotal),
                Icons.receipt_long,
                Colors.purple,
                isMobile,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'نسبة الذمم المتأخرة',
                '${_report!.agingPercentage.toStringAsFixed(2)}%',
                Icons.warning,
                _report!.agingPercentage < 4 ? Colors.green : Colors.red,
                isMobile,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 6 : 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: isMobile ? 16 : 24),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 10 : 14,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isMobile ? 2 : 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 14 : 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C3E50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandsTableWithAdjustments(bool isMobile) {
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
            child: Text(
              'تفاصيل العلامات التجارية',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2C3E50),
              ),
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
                        label: Text(
                          'العلامة التجارية',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'الهدف',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'المبيعات',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'الانحراف',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'الزبائن',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'إضافة (+)',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'طرح (-)',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ),
                    ],
                    rows: _report!.brandData.map((brand) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Text('${brand.brandCode} - ${brand.brandName}'),
                          ),
                          DataCell(
                            Text(Helpers.formatCurrency(brand.adjustedTarget)),
                          ),
                          DataCell(
                            Text(Helpers.formatCurrency(brand.adjustedSales)),
                          ),
                          DataCell(
                            Text(
                              Helpers.formatCurrency(brand.adjustedDeviation),
                              style: TextStyle(
                                color: brand.adjustedDeviation > 0
                                    ? Colors.red
                                    : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(brand.customerCount.toString()),
                          ),
                          DataCell(
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: _plusControllers[brand.brandCode],
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,2}'),
                                  ),
                                ],
                                decoration: InputDecoration(
                                  hintText: '0.00',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                ),
                                onChanged: (_) =>
                                    _applyAdjustment(brand.brandCode, 'plus'),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: _minusControllers[brand.brandCode],
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,2}'),
                                  ),
                                ],
                                decoration: InputDecoration(
                                  hintText: '0.00',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                ),
                                onChanged: (_) =>
                                    _applyAdjustment(brand.brandCode, 'minus'),
                              ),
                            ),
                          ),
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
      children: _report!.brandData.map((brand) {
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
                        'الهدف', Helpers.formatCurrency(brand.adjustedTarget)),
                  ),
                  Expanded(
                    child: _buildMiniStat('المبيعات',
                        Helpers.formatCurrency(brand.adjustedSales)),
                  ),
                  Expanded(
                    child: _buildMiniStat(
                      'الانحراف',
                      Helpers.formatCurrency(brand.adjustedDeviation),
                      valueColor: brand.adjustedDeviation > 0
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'إضافة (+)',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _plusControllers[brand.brandCode],
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}'),
                            ),
                          ],
                          decoration: InputDecoration(
                            hintText: '0.00',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          style: const TextStyle(fontSize: 12),
                          onChanged: (_) =>
                              _applyAdjustment(brand.brandCode, 'plus'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'طرح (-)',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _minusControllers[brand.brandCode],
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}'),
                            ),
                          ],
                          decoration: InputDecoration(
                            hintText: '0.00',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          style: const TextStyle(fontSize: 12),
                          onChanged: (_) =>
                              _applyAdjustment(brand.brandCode, 'minus'),
                        ),
                      ],
                    ),
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
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: valueColor ?? const Color(0xFF2C3E50),
          ),
        ),
      ],
    );
  }

  Widget _buildSalaryCalculations(bool isMobile) {
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
            child: Text(
              'حسابات الراتب',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2C3E50),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Column(
              children: [
                _buildSalaryRow(
                  'الراتب الأساسي',
                  Helpers.formatCurrency(_report!.initialSalary),
                  isHeader: true,
                  isMobile: isMobile,
                ),
                const Divider(height: 24),
                _buildSalaryRow(
                  'مبلغ الهدف الفعلي',
                  Helpers.formatCurrency(_report!.targetMoney),
                  description: 'الراتب الأساسي × (المبيعات / الهدف)',
                  isMobile: isMobile,
                ),
                const SizedBox(height: 12),
                _buildSalaryRow(
                  'مبلغ هدف التحصيل',
                  Helpers.formatCurrency(_report!.targetCollectMoney),
                  description: _report!.agingPercentage < 4
                      ? 'الراتب الأساسي (الذمم المتأخرة أقل من 4%)'
                      : 'الراتب الأساسي - (الراتب × نسبة الذمم المتأخرة)',
                  valueColor: _report!.agingPercentage < 4
                      ? Colors.green
                      : Colors.orange,
                  isMobile: isMobile,
                ),
                const SizedBox(height: 12),
                _buildSalaryRowWithInput(
                  'مكافآت',
                  _bonusController,
                  onChanged: (value) {
                    setState(() {
                      _report!.bonus = double.tryParse(value) ?? 0;
                    });
                  },
                  isMobile: isMobile,
                ),
                const SizedBox(height: 12),
                _buildSalaryRow(
                  'مكافأة تحصيل',
                  Helpers.formatCurrency(_report!.collectBonus),
                  description: _report!.agingPercentage < 4
                      ? 'مبلغ الهدف × 10%'
                      : 'لا يوجد (الذمم المتأخرة أكبر من 4%)',
                  valueColor:
                      _report!.collectBonus > 0 ? Colors.green : Colors.grey,
                  isMobile: isMobile,
                ),
                const SizedBox(height: 12),
                _buildSalaryRow(
                  'مكافأة المندوب المثالي',
                  Helpers.formatCurrency(_isPerfectSalesman ? 500 : 0),
                  description: _isPerfectSalesman
                      ? 'أعلى نسبة إنجاز في المجموعة (≥100%)'
                      : 'غير متوفر',
                  valueColor: _isPerfectSalesman ? Colors.amber : Colors.grey,
                  icon: _isPerfectSalesman ? Icons.emoji_events : null,
                  isMobile: isMobile,
                ),
                const Divider(height: 24),
                _buildSalaryRow(
                  'الراتب الفعلي',
                  Helpers.formatCurrency(_report!.actualSalary),
                  isTotal: true,
                  isMobile: isMobile,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryRow(
    String label,
    String value, {
    String? description,
    bool isHeader = false,
    bool isTotal = false,
    Color? valueColor,
    IconData? icon,
    bool isMobile = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (icon != null) ...[
                          Icon(icon,
                              color: valueColor ?? Colors.amber, size: 16),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: isHeader || isTotal ? 14 : 13,
                              fontWeight: isHeader || isTotal
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: const Color(0xFF2C3E50),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: isHeader || isTotal ? 16 : 14,
                        fontWeight: isHeader || isTotal
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: valueColor ?? const Color(0xFF135467),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (icon != null) ...[
                            Icon(icon,
                                color: valueColor ?? Colors.amber, size: 20),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: isHeader || isTotal ? 18 : 16,
                                fontWeight: isHeader || isTotal
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: const Color(0xFF2C3E50),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: isHeader || isTotal ? 20 : 18,
                        fontWeight: isHeader || isTotal
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: valueColor ?? const Color(0xFF135467),
                      ),
                    ),
                  ],
                ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: isMobile ? 10 : 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSalaryRowWithInput(
    String label,
    TextEditingController controller, {
    required Function(String) onChanged,
    bool isMobile = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    hintText: '0.00',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onChanged: onChanged,
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      hintText: '0.00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
    );
  }

  Color _getAchievementColor(double percentage) {
    if (percentage >= 100) return Colors.green;
    if (percentage >= 80) return Colors.orange;
    return Colors.red;
  }
}
