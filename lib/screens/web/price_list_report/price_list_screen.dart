// lib/screens/web/price_list_screen.dart
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../../models/user.dart';
import '../../../models/price_list_report.dart';
import '../../../services/api_service.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';
import '../../../utils/arabic_text_helper.dart';
import '../web_login_screen.dart';

class PriceListScreen extends StatefulWidget {
  final AppUser user;

  const PriceListScreen({
    super.key,
    required this.user,
  });

  @override
  State<PriceListScreen> createState() => _PriceListScreenState();
}

class _PriceListScreenState extends State<PriceListScreen> {
  PriceListReport? _report;
  bool _isLoading = true;

  // Search and filtering
  final TextEditingController _searchController = TextEditingController();
  List<PriceListItem> _filteredItems = [];

  // Sorting state
  String? _sortColumn;
  bool _sortAscending = false;

  // Single scroll controller for the table
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadReport();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterItems();
  }

  void _filterItems() {
    if (_report == null) return;

    final query = _searchController.text.trim();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(_report!.items);
      } else {
        _filteredItems =
            _report!.items.where((item) => item.matchesSearch(query)).toList();
      }

      if (_sortColumn != null) {
        _applySorting();
      }
    });
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);

    try {
      final report = await ApiService.getPriceListReport();

      if (mounted) {
        setState(() {
          _report = report;
          _filteredItems = List.from(report.items);
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

  void _sortData(String column) {
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
    _filteredItems.sort((a, b) {
      dynamic aValue;
      dynamic bValue;

      switch (_sortColumn) {
        case 'item.brand':
          aValue = int.tryParse(a.itemBrand) ?? 0;
          bValue = int.tryParse(b.itemBrand) ?? 0;
          break;
        case 'item':
          aValue = a.itemCode;
          bValue = b.itemCode;
          break;
        case 'item.name':
          aValue = a.itemName;
          bValue = b.itemName;
          break;
        case 'unit':
          aValue = a.unit;
          bValue = b.unit;
          break;
        case 'P_rawPrice':
          aValue = double.tryParse(a.pTaxPrice) ?? 0;
          bValue = double.tryParse(b.pTaxPrice) ?? 0;
          break;
        case 'S_taxPrice':
          aValue = double.tryParse(a.sRawPrice) ?? 0;
          bValue = double.tryParse(b.sRawPrice) ?? 0;
          break;
        default:
          aValue = '';
          bValue = '';
      }

      if (aValue.toString().isEmpty && bValue.toString().isNotEmpty) {
        return _sortAscending ? -1 : 1;
      }
      if (bValue.toString().isEmpty && aValue.toString().isNotEmpty) {
        return _sortAscending ? 1 : -1;
      }
      if (aValue.toString().isEmpty && bValue.toString().isEmpty) {
        return 0;
      }

      int comparison;
      if (aValue is num && bValue is num) {
        comparison = aValue.compareTo(bValue);
      } else {
        comparison = aValue.toString().compareTo(bValue.toString());
      }

      return _sortAscending ? comparison : -comparison;
    });
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
          onRefresh: _loadReport,
          isDesktop: isDesktop,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 1400 : double.infinity,
            ),
            child: Column(
              children: [
                _buildHeader(isDesktop, isMobile),
                Expanded(
                  child: _buildContent(isDesktop, isMobile),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDesktop, bool isMobile) {
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
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: isMobile ? 50 : 60,
                height: isMobile ? 50 : 60,
                decoration: BoxDecoration(
                  color: const Color(AppConstants.accentColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.price_change_outlined,
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
                      'قائمة الأسعار',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(AppConstants.primaryColor),
                      ),
                    ),
                    SizedBox(height: isMobile ? 4 : 6),
                    Text(
                      'قوائم الأسعار P و S',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        color: const Color(AppConstants.accentColor),
                        fontWeight: FontWeight.w500,
                      ),
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
                    color:
                        const Color(AppConstants.primaryColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(AppConstants.primaryColor)
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${_filteredItems.length}',
                        style: TextStyle(
                          color: const Color(AppConstants.primaryColor),
                          fontWeight: FontWeight.w600,
                          fontSize: isMobile ? 14 : 16,
                        ),
                      ),
                      Text(
                        'صنف',
                        style: TextStyle(
                          color: const Color(AppConstants.primaryColor),
                          fontWeight: FontWeight.w500,
                          fontSize: isMobile ? 10 : 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 20),
          TextField(
            controller: _searchController,
            textDirection: ui.TextDirection.rtl,
            decoration: InputDecoration(
              hintText: 'ابحث في قائمة الأسعار...',
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: isMobile ? 13 : 14,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: const Color(AppConstants.accentColor),
                size: isMobile ? 20 : 22,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: Colors.grey.shade400,
                        size: isMobile ? 18 : 20,
                      ),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: const Color(AppConstants.accentColor),
                  width: 2,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 12 : 14,
              ),
            ),
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
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
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(AppConstants.accentColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'جاري تحميل قائمة الأسعار...',
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.price_change_outlined,
              size: isMobile ? 60 : 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            Text(
              'لا توجد بيانات',
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppConstants.accentColor),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 24 : 32,
                  vertical: isMobile ? 12 : 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'إعادة التحميل',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: isMobile ? 60 : 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            Text(
              'لا توجد نتائج',
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return _buildSimpleTable(isMobile);
  }

  Widget _buildSimpleTable(bool isMobile) {
    return Container(
      margin: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              color: const Color(AppConstants.primaryColor),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1.5), // Brand
                1: FlexColumnWidth(2), // Item code
                2: FlexColumnWidth(3), // Item name
                3: FlexColumnWidth(1), // Unit
                4: FlexColumnWidth(1.5), // P price
                5: FlexColumnWidth(1.5), // S price
              },
              children: [
                TableRow(
                  children: [
                    _buildSimpleHeaderCell(
                        'علامة تجارية', 'item.brand', isMobile),
                    _buildSimpleHeaderCell('صنف', 'item', isMobile),
                    _buildSimpleHeaderCell('اسم الصنف', 'item.name', isMobile),
                    _buildSimpleHeaderCell('وحدة', 'unit', isMobile),
                    _buildSinglePriceHeader(
                        'P', 'P_rawPrice', 'قبل الضريبة', isMobile),
                    _buildSinglePriceHeader(
                        'S', 'S_taxPrice', 'شامل الضريبة', isMobile),
                  ],
                ),
              ],
            ),
          ),
          // Data rows with ListView.builder for better performance
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                return _buildDataRow(item, index, isMobile);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleHeaderCell(String label, String column, bool isMobile) {
    final bool isSorted = _sortColumn == column;

    return InkWell(
      onTap: () => _sortData(column),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 12,
          vertical: isMobile ? 12 : 16,
        ),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isMobile ? 11 : 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSorted)
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: Colors.white,
                size: 12,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSinglePriceHeader(
    String priceList,
    String sortColumn,
    String priceLabel,
    bool isMobile,
  ) {
    final bool isSorted = _sortColumn == sortColumn;

    return InkWell(
      onTap: () => _sortData(sortColumn),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.white.withOpacity(0.5), width: 2),
          ),
        ),
        child: Column(
          children: [
            // Main header (P or S)
            Container(
              padding: EdgeInsets.symmetric(vertical: isMobile ? 4 : 6),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
              ),
              child: Text(
                priceList,
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Price label with sort indicator
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 4 : 8,
                vertical: isMobile ? 8 : 10,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      priceLabel,
                      style: TextStyle(
                        fontSize: isMobile ? 9 : 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSorted)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        _sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        color: Colors.white,
                        size: 10,
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

  Widget _buildPriceHeaderSection(String priceList, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.5), width: 2),
        ),
      ),
      child: Column(
        children: [
          // Main header
          Container(
            padding: EdgeInsets.symmetric(vertical: isMobile ? 4 : 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
            ),
            child: Text(
              priceList,
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Sub headers
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _sortData('${priceList}_rawPrice'),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 4 : 8,
                      vertical: isMobile ? 8 : 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'شامل الضريبة',
                          style: TextStyle(
                            fontSize: isMobile ? 9 : 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_sortColumn == '${priceList}_rawPrice')
                          Icon(
                            _sortAscending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: Colors.white,
                            size: 10,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => _sortData('${priceList}_taxPrice'),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 4 : 8,
                      vertical: isMobile ? 8 : 10,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'قبل الضريبة',
                          style: TextStyle(
                            fontSize: isMobile ? 9 : 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_sortColumn == '${priceList}_taxPrice')
                          Icon(
                            _sortAscending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: Colors.white,
                            size: 10,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(PriceListItem item, int index, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.5), // Brand
          1: FlexColumnWidth(2), // Item code
          2: FlexColumnWidth(3), // Item name
          3: FlexColumnWidth(1), // Unit
          4: FlexColumnWidth(1.5), // P price
          5: FlexColumnWidth(1.5), // S price
        },
        children: [
          TableRow(
            children: [
              _buildDataCell(item.itemBrand, isMobile),
              _buildDataCell(item.itemCode, isMobile),
              _buildDataCell(item.itemName, isMobile),
              _buildDataCell(item.unit, isMobile),
              _buildSinglePriceCell(item.pRawPrice, isMobile, true),
              _buildSinglePriceCell(item.sTaxPrice, isMobile, true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataCell(String value, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 12,
        vertical: isMobile ? 12 : 16,
      ),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Text(
        value.isEmpty ? '-' : ArabicTextHelper.cleanText(value),
        style: TextStyle(
          fontSize: isMobile ? 10 : 12,
          color: value.isEmpty
              ? Colors.grey.shade400
              : const Color(AppConstants.primaryColor),
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );
  }

  Widget _buildSinglePriceCell(
      String value, bool isMobile, bool isHighlighted) {
    final isEmpty = value.isEmpty;
    final numValue = double.tryParse(value);
    final formattedValue =
        numValue != null ? Helpers.formatNumber(value) : value;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 12,
        vertical: isMobile ? 12 : 16,
      ),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Text(
        isEmpty ? '-' : formattedValue,
        style: TextStyle(
          fontSize: isMobile ? 10 : 12,
          fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
          color: isEmpty
              ? Colors.grey.shade400
              : isHighlighted
                  ? const Color(AppConstants.accentColor)
                  : const Color(AppConstants.primaryColor),
        ),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      ),
    );
  }

  Widget _buildPriceDataSection(
      String rawPrice, String taxPrice, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 4 : 8,
                vertical: isMobile ? 12 : 16,
              ),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.grey.shade200, width: 0.5),
                ),
              ),
              child: _buildPriceText(rawPrice, isMobile, false),
            ),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 4 : 8,
                vertical: isMobile ? 12 : 16,
              ),
              child: _buildPriceText(taxPrice, isMobile, true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceText(String value, bool isMobile, bool isHighlighted) {
    final isEmpty = value.isEmpty;
    final numValue = double.tryParse(value);
    final formattedValue =
        numValue != null ? Helpers.formatNumber(value) : value;

    return Text(
      isEmpty ? '-' : formattedValue,
      style: TextStyle(
        fontSize: isMobile ? 10 : 12,
        fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
        color: isEmpty
            ? Colors.grey.shade400
            : isHighlighted
                ? const Color(AppConstants.accentColor)
                : const Color(AppConstants.primaryColor),
      ),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
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
        isDesktop ? 'قائمة الأسعار' : 'الأسعار',
        style: const TextStyle(
          color: Color(AppConstants.primaryColor),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        if (isDesktop)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Chip(
              label: Text(
                user.username,
                style: const TextStyle(fontSize: 12),
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
            const PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh,
                      color: Color(AppConstants.accentColor), size: 18),
                  SizedBox(width: 8),
                  Text('تحديث'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.red, size: 18),
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
