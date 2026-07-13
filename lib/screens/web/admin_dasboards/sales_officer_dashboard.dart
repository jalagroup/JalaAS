// lib/screens/web/sales_officer_dashboard.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jala_as/screens/utils/file_utils.dart';
import '../../../models/new_customer.dart';
import '../../../models/user.dart';
import '../../../services/supabase_service.dart';
import '../../../services/pdf_service.dart';
import '../../../utils/helpers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/image_viewer_dialog.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
// REMOVE: import 'dart:html' as html;
// REMOVE: import 'package:flutter/foundation.dart' show kIsWeb;

class SalesOfficerDashboard extends StatefulWidget {
  final AppUser user;

  const SalesOfficerDashboard({
    super.key,
    required this.user,
  });

  @override
  State<SalesOfficerDashboard> createState() => _SalesOfficerDashboardState();
}

class _SalesOfficerDashboardState extends State<SalesOfficerDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<NewCustomer> _uncheckedCustomers = [];
  List<NewCustomer> _checkedCustomers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Track PDF generation state
  final Map<int, bool> _generatingPdf = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadCustomers();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    setState(() {});
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final unchecked =
          await SupabaseService.getNewCustomers(status: 'unchecked');
      final checked = await SupabaseService.getNewCustomers(status: 'checked');

      setState(() {
        _uncheckedCustomers = unchecked;
        _checkedCustomers = checked;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'فشل في تحميل البيانات',
          isError: true,
        );
      }
    }
  }

  List<NewCustomer> get _currentCustomers {
    final customers =
        _tabController.index == 0 ? _uncheckedCustomers : _checkedCustomers;

    if (_searchQuery.isEmpty) return customers;

    return customers.where((customer) {
      return customer.businessName
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          customer.bisanCode
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          customer.ownerName
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          customer.salesman.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _markAsChecked(NewCustomer customer) async {
    try {
      await SupabaseService.markCustomerAsChecked(customer.id);

      if (mounted) {
        Helpers.showSnackBar(context, 'تم تحديد العميل كمراجع');
        _loadCustomers();
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'فشل في تحديث حالة العميل',
          isError: true,
        );
      }
    }
  }

  Future<void> _downloadPdf(NewCustomer customer) async {
    if (customer.pdfUrl == null) {
      Helpers.showSnackBar(
        context,
        'ملف PDF غير متوفر',
        isError: true,
      );
      return;
    }

    try {
      final uri = Uri.parse(customer.pdfUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch PDF';
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'فشل في فتح ملف PDF',
          isError: true,
        );
      }
    }
  }

  void _showImagesGallery(NewCustomer customer) {
    if (customer.images.isEmpty) {
      Helpers.showSnackBar(
        context,
        'لا توجد صور مرفقة',
        isError: true,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => ImageViewerDialog(
        images: customer.images,
        customerName: customer.businessName,
      ),
    );
  }

  /// Helper method to get combined location
  String _getCombinedLocation(NewCustomer customer) {
    final city = customer.city ?? '';
    final state = customer.state ?? '';

    if (city.isNotEmpty && state.isNotEmpty) {
      return '$city - $state';
    } else if (city.isNotEmpty) {
      return city;
    } else if (state.isNotEmpty) {
      return state;
    }
    return '';
  }

  /// Generate and Download PDF using cross-platform FileUtils
  Future<void> _generateAndDownloadPdf(NewCustomer customer) async {
    // Check if already generating
    if (_generatingPdf[customer.id] == true) {
      Helpers.showSnackBar(
        context,
        'جارٍ إنشاء ملف PDF...',
        isError: false,
      );
      return;
    }

    setState(() {
      _generatingPdf[customer.id] = true;
    });

    try {
      // Show loading indicator
      Helpers.showSnackBar(
        context,
        'جارٍ إنشاء ملف PDF...',
        isError: false,
      );

      // Generate PDF with same logic as customer opening screen
      final pdfBytes = await PdfService.generateCustomerOpeningPdf(
        businessName: customer.businessName,
        ownerName: customer.ownerName,
        responsiblePerson: customer.responsiblePerson ?? '',
        taxId: customer.taxId ?? '',
        idNumber: customer.idNumber ?? '',
        mobile: customer.mobile,
        telephone: customer.telephone ?? '',
        email: customer.email ?? '',
        state: _getCombinedLocation(customer),
        stateType: customer.stateType ?? '',
        street: customer.street ?? '',
        beside: customer.beside ?? '',
        businessType: customer.businessTypeName ?? '',
        visitDays: customer.visitDays ?? '',
        paymentMethod: customer.paymentMethod ?? '',
        creditLimit: customer.creditLimit ?? '',
        date: DateFormat('dd/MM/yyyy').format(customer.createdDate),
        contactCode: customer.bisanCode,
        createdBy: customer.username,
        salesman: customer.salesman,
      );

      // Download the PDF using cross-platform FileUtils
      final fileName =
          'customer_${customer.bisanCode}_${customer.businessName}.pdf';
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
      setState(() {
        _generatingPdf[customer.id] = false;
      });
    }
  }

  // REMOVED: _downloadPdfBytes method (no longer needed)

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        final isTablet =
            constraints.maxWidth >= 768 && constraints.maxWidth < 1024;

        return Container(
          color: const Color(0xFFF8F9FA),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTabSelector(isMobile),
                const SizedBox(height: 20),
                _buildSearchAndStats(isMobile),
                const SizedBox(height: 20),
                Expanded(
                  child: _buildCustomersContent(isMobile, isTablet),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'لوحة تحكم ضابط المبيعات',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C3E50),
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.assignment_ind_outlined,
                      size: 16,
                      color: Color(0xFF3B82F6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.user.username,
                      style: const TextStyle(
                        color: Color(0xFF3B82F6),
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
      );
    }

    return Row(
      textDirection: ui.TextDirection.ltr,
      children: [
        IconButton(
          onPressed: _loadCustomers,
          icon: const Icon(
            Icons.refresh_outlined,
            size: 15,
          ),
          tooltip: 'تحديث',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF135467).withOpacity(0.1),
            foregroundColor: const Color(0xFF135467),
            padding: const EdgeInsets.all(3),
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'لوحة تحكم ضابط المبيعات',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.assignment_ind_outlined,
                    size: 14,
                    color: Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.user.username,
                    style: const TextStyle(
                      color: Color(0xFF3B82F6),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabSelector(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF135467).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              label: 'غير مراجع',
              count: _uncheckedCustomers.length,
              isSelected: _tabController.index == 0,
              color: const Color(0xFFF59E0B),
              onTap: () {
                _tabController.animateTo(0);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildTabButton(
              label: 'مراجع',
              count: _checkedCustomers.length,
              isSelected: _tabController.index == 1,
              color: const Color(0xFF10B981),
              onTap: () {
                _tabController.animateTo(1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required int count,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: color, width: 2)
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : const Color(0xFF546E7A),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? color : const Color(0xFF546E7A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndStats(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF135467).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFE1E5E9),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2C3E50),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'البحث في العملاء...',
                      hintStyle: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Color(0xFF9CA3AF),
                        size: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF135467).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.business_outlined,
                        color: Color(0xFF135467),
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'المجموع: ${_currentCustomers.length}',
                        style: const TextStyle(
                          color: Color(0xFF135467),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF135467).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.business_outlined,
                    color: Color(0xFF135467),
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'المجموع: ${_currentCustomers.length}',
                    style: const TextStyle(
                      color: Color(0xFF135467),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomersContent(bool isMobile, bool isTablet) {
    if (_isLoading) {
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
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(
              color: Color(0xFF135467),
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (_currentCustomers.isEmpty) {
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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF135467).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.business_outlined,
                    size: 32,
                    color: Color(0xFF135467),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? 'لا يوجد عملاء'
                      : 'لا توجد نتائج للبحث',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF546E7A),
                  ),
                ),
              ],
            ),
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
        itemCount: _currentCustomers.length,
        itemBuilder: (context, index) {
          final customer = _currentCustomers[index];
          return _buildCustomerCard(customer, index);
        },
      ),
    );
  }

  Widget _buildCustomerCard(NewCustomer customer, int index) {
    final isEven = index % 2 == 0;
    final isFirst = index == 0;
    final isLast = index == _currentCustomers.length - 1;
    final isGeneratingPdf = _generatingPdf[customer.id] == true;

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
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            leading: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF135467).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.business_outlined,
                color: Color(0xFF135467),
                size: 14,
              ),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF135467).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    customer.bisanCode,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF135467),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    customer.businessName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF135467).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    customer.salesman,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF135467),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat('dd/MM/yy').format(customer.createdDate),
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF546E7A),
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Generate PDF Button (NEW)
                InkWell(
                  onTap: isGeneratingPdf
                      ? null
                      : () => _generateAndDownloadPdf(customer),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isGeneratingPdf
                          ? Colors.grey.withOpacity(0.1)
                          : const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: isGeneratingPdf
                        ? const Padding(
                            padding: EdgeInsets.all(5),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF3B82F6),
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.picture_as_pdf,
                            size: 13,
                            color: Color(0xFF3B82F6),
                          ),
                  ),
                ),
                const SizedBox(width: 4),
                // Stored PDF Button (Original)
                if (customer.pdfUrl != null)
                  InkWell(
                    onTap: () => _downloadPdf(customer),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 13,
                        color: Colors.red,
                      ),
                    ),
                  ),
                if (customer.pdfUrl != null) const SizedBox(width: 4),
                if (customer.images.isNotEmpty)
                  InkWell(
                    onTap: () => _showImagesGallery(customer),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.image_outlined,
                        size: 13,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  ),
                if (customer.images.isNotEmpty) const SizedBox(width: 4),
                if (customer.isUnchecked)
                  InkWell(
                    onTap: () => _markAsChecked(customer),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        size: 13,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                if (customer.isUnchecked) const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Color(0xFF9CA3AF),
                  size: 18,
                ),
              ],
            ),
            children: [
              _buildCustomerDetails(customer),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerDetails(NewCustomer customer) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E5E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('المالك', customer.ownerName, Icons.person_outline),
          if (customer.responsiblePerson != null)
            _buildDetailRow('المسؤول', customer.responsiblePerson!,
                Icons.supervised_user_circle_outlined),
          if (customer.mobile.isNotEmpty)
            _buildDetailRow('الهاتف', customer.mobile, Icons.phone_outlined),
          if (customer.email != null && customer.email!.isNotEmpty)
            _buildDetailRow(
                'البريد الإلكتروني', customer.email!, Icons.email_outlined),
          if (customer.city != null || customer.state != null)
            _buildDetailRow(
              'العنوان',
              _getCombinedLocation(customer),
              Icons.location_on_outlined,
            ),
          if (customer.businessTypeName != null)
            _buildDetailRow('نوع العمل', customer.businessTypeName!,
                Icons.category_outlined),
          if (customer.visitDays != null && customer.visitDays!.isNotEmpty)
            _buildDetailRow(
                'أيام الزيارة', customer.visitDays!, Icons.calendar_today),
          _buildDetailRow('المستخدم', customer.username, Icons.account_circle),
          if (customer.images.isNotEmpty) ...[
            const Divider(height: 20, color: Color(0xFFE1E5E9)),
            Row(
              children: [
                const Icon(
                  Icons.photo_library_outlined,
                  size: 14,
                  color: Color(0xFF546E7A),
                ),
                const SizedBox(width: 6),
                Text(
                  'الصور المرفقة (${customer.images.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: customer.images.length,
                itemBuilder: (context, index) {
                  final image = customer.images[index];
                  return GestureDetector(
                    onTap: () => _showImagesGallery(customer),
                    child: Container(
                      width: 70,
                      margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE1E5E9)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          image.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFFF8F9FA),
                              child: const Icon(
                                Icons.broken_image,
                                color: Color(0xFF9CA3AF),
                                size: 24,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 14,
            color: const Color(0xFF546E7A),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF546E7A),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
