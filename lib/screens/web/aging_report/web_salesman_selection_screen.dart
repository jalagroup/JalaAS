// lib/screens/web/web_salesman_selection_screen.dart - FULLY OPTIMIZED

import 'package:flutter/material.dart';
import '../../../models/user.dart';
import '../../../models/salesman.dart';
import '../../../models/area.dart';
import '../../../services/api_service.dart';
import '../../../utils/constants.dart';
import 'web_aging_report_screen.dart';
import 'dart:ui' as ui;

class WebSalesmanSelectionScreen extends StatefulWidget {
  final AppUser user;

  const WebSalesmanSelectionScreen({
    super.key,
    required this.user,
  });

  @override
  State<WebSalesmanSelectionScreen> createState() =>
      _WebSalesmanSelectionScreenState();
}

class _WebSalesmanSelectionScreenState extends State<WebSalesmanSelectionScreen>
    with AutomaticKeepAliveClientMixin {
  // Cached data
  List<Salesman> _allSalesmen = [];
  List<Area> _allAreas = [];
  List<Salesman>? _cachedAvailableSalesmen;

  // Selection state
  Salesman? _selectedSalesmanFrom;
  Salesman? _selectedSalesmanTo;
  Area? _selectedArea;
  String _selectedDateType = 'current';
  String _selectedContactType = 'customers';

  bool _isLoading = true;
  bool _canSelectSalesmen = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _canSelectSalesmen = widget.user.isSystemAdmin || widget.user.isSalesAdmin;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDataAsync());
  }

  Future<void> _loadDataAsync() async {
    if (!mounted) return;

    try {
      await Future.microtask(() {
        _allSalesmen = ApiService.getAvailableSalesmen();
        _allAreas = ApiService.getAvailableAreas();
      });

      if (mounted) {
        setState(() => _isLoading = false);
        _initializeUserData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('فشل في تحميل البيانات: $e', true);
      }
    }
  }

  void _initializeUserData() {
    if (widget.user.isRegularUser && _allSalesmen.isNotEmpty) {
      final userSalesman = _allSalesmen.firstWhere(
        (s) => s.code == widget.user.salesman,
        orElse: () => Salesman(
          code: widget.user.salesman,
          name: 'المندوب ${widget.user.salesman}',
        ),
      );
      _selectedSalesmanFrom = userSalesman;
      _selectedSalesmanTo = userSalesman;
    }
  }

  List<Salesman> _getAvailableSalesmenForUser() {
    if (_cachedAvailableSalesmen != null) return _cachedAvailableSalesmen!;

    if (widget.user.isSystemAdmin) {
      _cachedAvailableSalesmen = _allSalesmen;
    } else if (widget.user.isSalesAdmin) {
      if (widget.user.area == null ||
          widget.user.area!.isEmpty ||
          widget.user.area == '00') {
        _cachedAvailableSalesmen = _allSalesmen;
      } else {
        final allowedCodes = _parseSalesmenFromArea(widget.user.area!);
        _cachedAvailableSalesmen =
            _allSalesmen.where((s) => allowedCodes.contains(s.code)).toList();
      }
    } else {
      _cachedAvailableSalesmen =
          _allSalesmen.where((s) => s.code == widget.user.salesman).toList();
    }

    return _cachedAvailableSalesmen!;
  }

  List<String> _parseSalesmenFromArea(String areaValue) {
    if (areaValue == '00' || areaValue.isEmpty) return [];

    final List<String> salesmen = [];
    for (int i = 0; i < areaValue.length; i += 3) {
      if (i + 3 <= areaValue.length) {
        salesmen.add(areaValue.substring(i, i + 3));
      }
    }
    return salesmen;
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

  bool _isValidSelection() {
    if (!_canSelectSalesmen) return true;

    return (_selectedSalesmanFrom != null || _selectedSalesmanTo != null) ||
        _selectedArea != null;
  }

  void _navigateToAgingReport() {
    if (!_isValidSelection()) {
      _showSnackBar('يرجى اختيار مندوب واحد على الأقل أو منطقة', true);
      return;
    }

    String? areaForReport;
    if (widget.user.isSystemAdmin || widget.user.isSalesAdmin) {
      areaForReport = _selectedArea?.code;
    } else if (widget.user.area != null &&
        widget.user.area!.isNotEmpty &&
        widget.user.area != '00' &&
        widget.user.area!.length <= 3) {
      areaForReport = widget.user.area;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebAgingReportScreen(
          user: widget.user,
          salesmanFrom: _selectedSalesmanFrom?.code,
          salesmanTo: _selectedSalesmanTo?.code,
          selectedArea: areaForReport,
          dateType: _selectedDateType,
          contactType: _selectedContactType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isMobile = size.width < 768;
    final maxWidth = isDesktop ? 700.0 : double.infinity;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _LightAppBar(
          canSelectSalesmen: _canSelectSalesmen,
          isDesktop: isDesktop,
        ),
        body: _isLoading
            ? _buildLoadingState(isMobile)
            : _buildContent(maxWidth, isMobile, isDesktop),
      ),
    );
  }

  Widget _buildLoadingState(bool isMobile) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                Color(AppConstants.accentColor),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'جارٍ التحميل...',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(double maxWidth, bool isMobile, bool isDesktop) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRadioSelector(
                title: 'نوع التاريخ',
                groupValue: _selectedDateType,
                options: const [
                  {'value': 'current', 'label': 'التاريخ الحالي'},
                  {'value': 'month_end', 'label': 'آخر يوم في الشهر'},
                ],
                onChanged: (value) => setState(() => _selectedDateType = value),
                isMobile: isMobile,
              ),
              SizedBox(height: isMobile ? 16 : 20),
              _buildRadioSelector(
                title: 'نوع التقرير',
                groupValue: _selectedContactType,
                options: const [
                  {'value': 'customers', 'label': 'الزبائن'},
                  {'value': 'defaulters', 'label': 'المتعثرين'},
                ],
                onChanged: (value) =>
                    setState(() => _selectedContactType = value),
                isMobile: isMobile,
              ),
              if (_canSelectSalesmen) ...[
                SizedBox(height: isMobile ? 16 : 20),
                _buildSalesmanDropdown(isMobile),
                SizedBox(height: isMobile ? 16 : 20),
                _buildAreaDropdown(isMobile),
              ],
              SizedBox(height: isMobile ? 20 : 24),
              _buildSummary(isMobile),
              SizedBox(height: isMobile ? 20 : 24),
              _buildActionButtons(isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadioSelector({
    required String title,
    required String groupValue,
    required List<Map<String, String>> options,
    required ValueChanged<String> onChanged,
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isMobile ? 14 : 16,
            fontWeight: FontWeight.w500,
            color: const Color(AppConstants.primaryColor),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    value: option['value']!,
                    groupValue: groupValue,
                    onChanged: (val) => onChanged(val!),
                    title: Text(
                      option['label']!,
                      style: TextStyle(fontSize: isMobile ? 12 : 14),
                    ),
                    activeColor: const Color(AppConstants.accentColor),
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  if (index < options.length - 1)
                    Divider(height: 1, color: Colors.grey.shade300),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSalesmanDropdown(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'المندوب',
          style: TextStyle(
            fontSize: isMobile ? 14 : 16,
            fontWeight: FontWeight.w500,
            color: const Color(AppConstants.primaryColor),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonFormField<Salesman>(
            value: _selectedSalesmanFrom,
            items: [
              const DropdownMenuItem<Salesman>(
                value: null,
                child: Text('جميع المندوبين'),
              ),
              ..._getAvailableSalesmenForUser().map(
                (s) => DropdownMenuItem<Salesman>(
                  value: s,
                  child: Text('${s.name} (${s.code})'),
                ),
              ),
            ],
            onChanged: (value) => setState(() {
              _selectedSalesmanFrom = value;
              _selectedSalesmanTo = value;
            }),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            isExpanded: true,
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAreaDropdown(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'المنطقة (اختياري)',
          style: TextStyle(
            fontSize: isMobile ? 14 : 16,
            fontWeight: FontWeight.w500,
            color: const Color(AppConstants.primaryColor),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonFormField<Area>(
            value: _selectedArea,
            items: [
              const DropdownMenuItem<Area>(
                value: null,
                child: Text('جميع المناطق'),
              ),
              ..._allAreas.map(
                (area) => DropdownMenuItem<Area>(
                  value: area,
                  child: Text('${area.name} (${area.code})'),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _selectedArea = value),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            isExpanded: true,
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'الاختيار الحالي',
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(AppConstants.primaryColor),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.user.isSystemAdmin
                      ? Colors.orange.shade100
                      : widget.user.isSalesAdmin
                          ? Colors.green.shade100
                          : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.user.userTypeDisplayText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: widget.user.isSystemAdmin
                        ? Colors.orange.shade700
                        : widget.user.isSalesAdmin
                            ? Colors.green.shade700
                            : Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildSummaryItem(
            'التاريخ',
            _selectedDateType == 'current' ? 'الحالي' : 'آخر الشهر',
            isMobile,
          ),
          _buildSummaryItem(
            'التقرير',
            _selectedContactType == 'customers' ? 'الزبائن' : 'المتعثرين',
            isMobile,
          ),
          if (_selectedSalesmanFrom != null)
            _buildSummaryItem('المندوب', _selectedSalesmanFrom!.name, isMobile),
          if (_selectedArea != null)
            _buildSummaryItem('المنطقة', _selectedArea!.name, isMobile),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: isMobile ? 11 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                color: Colors.grey.shade700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isMobile) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isValidSelection() ? _navigateToAgingReport : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConstants.accentColor),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              'عرض التقرير',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _selectedDateType = 'current';
                _selectedContactType = 'customers';
                if (_canSelectSalesmen) {
                  _selectedSalesmanFrom = null;
                  _selectedSalesmanTo = null;
                  _selectedArea = null;
                } else {
                  _initializeUserData();
                }
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              side: BorderSide(color: Colors.grey.shade300),
              padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'إعادة تعيين',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LightAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool canSelectSalesmen;
  final bool isDesktop;

  const _LightAppBar({
    required this.canSelectSalesmen,
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
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        canSelectSalesmen ? 'اختيار المندوبين' : 'إعدادات التقرير',
        style: const TextStyle(
          color: Color(AppConstants.primaryColor),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
