// lib/screens/web/sales_returns_admin_screen.dart - PART 1

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jala_as/models/returns_models.dart';
import 'package:jala_as/models/user.dart';
import 'package:jala_as/services/pdf_service.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/helpers.dart';
import 'package:jala_as/screens/utils/file_utils.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

class SalesReturnsAdminScreen extends StatefulWidget {
  final AppUser user;

  const SalesReturnsAdminScreen({
    super.key,
    required this.user,
  });

  @override
  State<SalesReturnsAdminScreen> createState() =>
      _SalesReturnsAdminScreenState();
}

class _SalesReturnsAdminScreenState extends State<SalesReturnsAdminScreen> {
  List<SalesReturn> _returns = [];
  List<SalesReturn> _filteredReturns = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;

  // Track PDF generation state
  final Map<int, bool> _generatingPdf = {};

  @override
  void initState() {
    super.initState();
    _loadReturns();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReturns() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('🔄 Loading sales returns...');

      final returns = await SupabaseService.getSalesReturns(
        fromDate: _fromDate,
        toDate: _toDate,
      );

      print('📦 Returns loaded: ${returns.length} items');

      for (final returnItem in returns) {
        print(
            '📋 Return: ${returnItem.returnCode} - ${returnItem.contactName} - ${returnItem.items.length} items');
      }

      setState(() {
        _returns = returns;
        _filteredReturns = returns;
        _isLoading = false;
      });

      print('✅ Returns loaded successfully');
    } catch (e) {
      print('❌ Error loading returns: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'فشل في تحميل المرتجعات: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  void _filterReturns(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredReturns = _returns;
      } else {
        _filteredReturns = _returns.where((returnItem) {
          return returnItem.returnCode
                  .toLowerCase()
                  .contains(query.toLowerCase()) ||
              returnItem.contactName
                  .toLowerCase()
                  .contains(query.toLowerCase()) ||
              returnItem.contactCode
                  .toLowerCase()
                  .contains(query.toLowerCase()) ||
              returnItem.username.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
      locale: const Locale('ar'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF135467),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _loadReturns();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
    _loadReturns();
  }

  Future<void> _generateAndDownloadPdf(SalesReturn returnItem) async {
    if (_generatingPdf[returnItem.id] == true) {
      Helpers.showSnackBar(context, 'جارٍ إنشاء ملف PDF...', isError: false);
      return;
    }

    setState(() {
      _generatingPdf[returnItem.id!] = true;
    });

    try {
      Helpers.showSnackBar(context, 'جارٍ إنشاء ملف PDF...', isError: false);

      final pdfBytes = await PdfService.generateSalesReturnPdf(
        returnCode: returnItem.returnCode,
        contactCode: returnItem.contactCode,
        contactName: returnItem.contactName,
        returnDate: DateFormat('dd/MM/yyyy').format(returnItem.returnDate),
        returnReasonName: returnItem.returnReasonName,
        warehouseCode: returnItem.warehouseCode,
        warehouseName: returnItem.warehouseName ?? '',
        items: returnItem.items,
        username: returnItem.username,
        comment: returnItem.comment,
        paperWidth: 80,
      );

      final fileName = 'return_${returnItem.returnCode}.pdf';
      await FileUtils.instance.downloadFile(
        pdfBytes,
        fileName,
        mimeType: 'application/pdf',
      );

      if (mounted) {
        Helpers.showSnackBar(
          context,
          'تم تحميل ملف PDF بنجاح',
          isError: false,
        );
      }
    } catch (e) {
      print('Error generating PDF: $e');
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'فشل في إنشاء ملف PDF: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _generatingPdf[returnItem.id!] = false;
        });
      }
    }
  }

  void _showReturnDetails(SalesReturn returnItem) {
    showDialog(
      context: context,
      builder: (context) => ReturnDetailsDialog(returnItem: returnItem),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        final isTablet =
            constraints.maxWidth >= 768 && constraints.maxWidth < 1024;

        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: Scaffold(
            backgroundColor: const Color(0xFFF8F9FA),
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Colors.white,
              title: const Text(
                'مرتجعات المبيعات',
                style: TextStyle(
                  color: Color(0xFF135467),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF135467)),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF135467)),
                  onPressed: _loadReturns,
                  tooltip: 'تحديث',
                ),
              ],
            ),
            body: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 20),
              child: Column(
                children: [
                  _buildSearchAndFilters(isMobile),
                  const SizedBox(height: 20),
                  _buildStatsCards(isMobile),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _buildReturnsContent(isMobile, isTablet),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFilters(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF135467).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search field
          TextField(
            controller: _searchController,
            onChanged: _filterReturns,
            decoration: InputDecoration(
              hintText: 'البحث في المرتجعات...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF135467)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF135467)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Date filter
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    _fromDate != null && _toDate != null
                        ? '${DateFormat('dd/MM/yyyy').format(_fromDate!)} - ${DateFormat('dd/MM/yyyy').format(_toDate!)}'
                        : 'تحديد الفترة',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF135467),
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_fromDate != null || _toDate != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _clearDateFilter,
                  color: Colors.red,
                  tooltip: 'إلغاء الفلتر',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(bool isMobile) {
    final totalReturns = _filteredReturns.length;
    final totalItems = _filteredReturns.fold<int>(
      0,
      (sum, r) => sum + r.itemCount,
    );
    final totalQuantity = _filteredReturns.fold<double>(
      0,
      (sum, r) => sum + r.totalQuantity,
    );

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'إجمالي المرتجعات',
            value: totalReturns.toString(),
            icon: Icons.assignment_return,
            color: const Color(0xFF3B82F6),
            isMobile: isMobile,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'إجمالي الأصناف',
            value: totalItems.toString(),
            icon: Icons.inventory_2,
            color: const Color(0xFF10B981),
            isMobile: isMobile,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'إجمالي الكمية',
            value: totalQuantity.toStringAsFixed(0),
            icon: Icons.numbers,
            color: const Color(0xFFF59E0B),
            isMobile: isMobile,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF135467).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: isMobile ? 20 : 24),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF135467),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 11 : 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnsContent(bool isMobile, bool isTablet) {
    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF135467)),
        ),
      );
    }

    if (_filteredReturns.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.assignment_return,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد مرتجعات',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF135467).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: _filteredReturns.length,
        itemBuilder: (context, index) {
          final returnItem = _filteredReturns[index];
          return _buildReturnCard(returnItem, index, isMobile);
        },
      ),
    );
  }

  Widget _buildReturnCard(SalesReturn returnItem, int index, bool isMobile) {
    final isEven = index % 2 == 0;
    final isFirst = index == 0;
    final isLast = index == _filteredReturns.length - 1;
    final isGeneratingPdf = _generatingPdf[returnItem.id] == true;

    return Container(
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFFAFBFC),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFE1E5E9),
            width: isLast ? 0 : 0.5,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: isFirst
            ? const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              )
            : isLast
                ? const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  )
                : BorderRadius.zero,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF135467).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.assignment_return,
              color: Color(0xFF135467),
              size: 20,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  returnItem.returnCode,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF135467).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  DateFormat('dd/MM/yyyy').format(returnItem.returnDate),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF135467),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '${returnItem.contactCode} - ${returnItem.contactName}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                'المستخدم: ${returnItem.username}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // PDF button
              InkWell(
                onTap: isGeneratingPdf
                    ? null
                    : () => _generateAndDownloadPdf(returnItem),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isGeneratingPdf
                        ? Colors.grey.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: isGeneratingPdf
                      ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.red),
                          ),
                        )
                      : const Icon(
                          Icons.picture_as_pdf,
                          size: 16,
                          color: Colors.red,
                        ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.keyboard_arrow_down,
                color: Color(0xFF9CA3AF),
                size: 20,
              ),
            ],
          ),
          children: [
            _buildReturnDetails(returnItem),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnDetails(SalesReturn returnItem) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E5E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('المخزن',
              '${returnItem.warehouseCode} - ${returnItem.warehouseName ?? ""}'),
          _buildDetailRow('سبب الإرجاع', returnItem.returnReasonName),
          if (returnItem.comment != null && returnItem.comment!.isNotEmpty)
            _buildDetailRow('ملاحظة', returnItem.comment!),
          const Divider(height: 20),
          const Text(
            'الأصناف:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF135467),
            ),
          ),
          const SizedBox(height: 8),
          ...returnItem.items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF135467).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF135467),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.itemName ?? item.itemCode ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'الكمية: ${item.quantity.toStringAsFixed(2)} ${item.unit ?? ""}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'إجمالي الأصناف',
                  returnItem.itemCount.toString(),
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'إجمالي الكمية',
                  returnItem.totalQuantity.toStringAsFixed(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF135467).withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF135467),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

// Return Details Dialog Widget
class ReturnDetailsDialog extends StatelessWidget {
  final SalesReturn returnItem;

  const ReturnDetailsDialog({
    super.key,
    required this.returnItem,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'تفاصيل المرتجع',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF135467),
                    ),
                    textDirection: ui.TextDirection.rtl,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoSection(
                      'معلومات المرتجع',
                      [
                        _buildInfoRow('رقم المرتجع', returnItem.returnCode),
                        _buildInfoRow(
                            'التاريخ',
                            DateFormat('dd/MM/yyyy')
                                .format(returnItem.returnDate)),
                        _buildInfoRow('المستخدم', returnItem.username),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoSection(
                      'معلومات الدليل',
                      [
                        _buildInfoRow('كود الدليل', returnItem.contactCode),
                        _buildInfoRow('اسم الدليل', returnItem.contactName),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoSection(
                      'معلومات المخزن',
                      [
                        _buildInfoRow('كود المخزن', returnItem.warehouseCode),
                        _buildInfoRow(
                            'اسم المخزن', returnItem.warehouseName ?? ''),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoSection(
                      'تفاصيل الإرجاع',
                      [
                        _buildInfoRow(
                            'سبب الإرجاع', returnItem.returnReasonName),
                        if (returnItem.comment != null &&
                            returnItem.comment!.isNotEmpty)
                          _buildInfoRow('ملاحظة', returnItem.comment!),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'الأصناف',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF135467),
                      ),
                      textDirection: ui.TextDirection.rtl,
                    ),
                    const SizedBox(height: 8),
                    ...returnItem.items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF135467).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF135467),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.itemName ?? item.itemCode ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textDirection: ui.TextDirection.rtl,
                                    ),
                                    Text(
                                      'الكمية: ${item.quantity.toStringAsFixed(2)} ${item.unit ?? ""}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      textDirection: ui.TextDirection.rtl,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E5E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF135467),
            ),
            textDirection: ui.TextDirection.rtl,
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
              textDirection: ui.TextDirection.rtl,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              textDirection: ui.TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }
}
