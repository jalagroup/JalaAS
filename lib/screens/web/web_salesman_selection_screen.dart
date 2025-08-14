// lib/screens/web/web_salesman_selection_screen.dart
import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../models/salesman.dart';
import '../../models/area.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
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

class _WebSalesmanSelectionScreenState
    extends State<WebSalesmanSelectionScreen> {
  List<Salesman> _allSalesmen = [];
  List<Area> _allAreas = [];

  // Selection variables
  Salesman? _selectedSalesmanFrom;
  Salesman? _selectedSalesmanTo;
  Area? _selectedArea;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _isLoading = true;
    });

    try {
      _allSalesmen = ApiService.getAvailableSalesmen();
      _allAreas = ApiService.getAvailableAreas();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في تحميل البيانات: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Salesman> _getAvailableSalesmenTo() {
    if (_selectedSalesmanFrom == null) return _allSalesmen;

    final fromIndex =
        _allSalesmen.indexWhere((s) => s.code == _selectedSalesmanFrom!.code);
    if (fromIndex == -1) return _allSalesmen;

    return _allSalesmen.sublist(fromIndex);
  }

  void _onSalesmanFromChanged(Salesman? newValue) {
    setState(() {
      _selectedSalesmanFrom = newValue;
      // Reset "To" selection if it's now invalid
      if (_selectedSalesmanTo != null && newValue != null) {
        final availableTo = _getAvailableSalesmenTo();
        if (!availableTo.contains(_selectedSalesmanTo)) {
          _selectedSalesmanTo = null;
        }
      }
    });
  }

  bool _isValidSelection() {
    // Must have at least one of these combinations:
    // 1. Salesman From only (To will be auto-completed to last)
    // 2. Salesman To only (From will be auto-completed to first)
    // 3. Both Salesman From and To
    // 4. Area only
    // 5. Any combination of the above

    bool hasSalesmanSelection =
        _selectedSalesmanFrom != null || _selectedSalesmanTo != null;
    bool hasAreaSelection = _selectedArea != null;

    return hasSalesmanSelection || hasAreaSelection;
  }

  void _navigateToAgingReport() {
    if (!_isValidSelection()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار مندوب واحد على الأقل أو منطقة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebAgingReportScreen(
          user: widget.user,
          salesmanFrom: _selectedSalesmanFrom?.code,
          salesmanTo: _selectedSalesmanTo?.code,
          selectedArea: _selectedArea?.code,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isMobile = screenWidth < 768;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          elevation: 4,
          backgroundColor: const Color(AppConstants.primaryColor),
          title: Row(
            children: [
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
              const Expanded(
                child: Text(
                  'اختيار المندوبين والمنطقة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(AppConstants.accentColor),
                  ),
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 800 : double.infinity,
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    child: Column(
                      children: [
                        // Header Info
                        Container(
                          padding: EdgeInsets.all(isMobile ? 16 : 20),
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
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(isMobile ? 10 : 12),
                                decoration: BoxDecoration(
                                  color: const Color(AppConstants.accentColor),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.people,
                                  color: Colors.white,
                                  size: isMobile ? 20 : 24,
                                ),
                              ),
                              SizedBox(width: isMobile ? 12 : 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'اختيار نطاق المندوبين',
                                      style: TextStyle(
                                        fontSize: isMobile ? 16 : 18,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(
                                            AppConstants.primaryColor),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'يرجى اختيار المندوب من والمندوب إلى، والمنطقة (اختياري)',
                                      style: TextStyle(
                                        fontSize: isMobile ? 12 : 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: isMobile ? 20 : 24),

                        // Selection Form
                        Container(
                          padding: EdgeInsets.all(isMobile ? 20 : 24),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Salesman From Dropdown
                              Text(
                                'المندوب من (اختياري)',
                                style: TextStyle(
                                  fontSize: isMobile ? 14 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(AppConstants.primaryColor),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonFormField<Salesman>(
                                  value: _selectedSalesmanFrom,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    hintText:
                                        'اختر المندوب من (سيكمل تلقائياً إلى آخر مندوب)',
                                  ),
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem<Salesman>(
                                      value: null,
                                      child: Text('لا يوجد اختيار'),
                                    ),
                                    ..._allSalesmen.map((salesman) {
                                      return DropdownMenuItem<Salesman>(
                                        value: salesman,
                                        child: Text(
                                          '${salesman.name} (${salesman.code})',
                                          style: TextStyle(
                                            fontSize: isMobile ? 12 : 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                  onChanged: _onSalesmanFromChanged,
                                ),
                              ),

                              SizedBox(height: isMobile ? 16 : 20),

                              // Salesman To Dropdown
                              Text(
                                'المندوب إلى (اختياري)',
                                style: TextStyle(
                                  fontSize: isMobile ? 14 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(AppConstants.primaryColor),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonFormField<Salesman>(
                                  value: _selectedSalesmanTo,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    hintText:
                                        'اختر المندوب إلى (سيكمل تلقائياً من أول مندوب)',
                                  ),
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem<Salesman>(
                                      value: null,
                                      child: Text('لا يوجد اختيار'),
                                    ),
                                    ..._getAvailableSalesmenTo()
                                        .map((salesman) {
                                      return DropdownMenuItem<Salesman>(
                                        value: salesman,
                                        child: Text(
                                          '${salesman.name} (${salesman.code})',
                                          style: TextStyle(
                                            fontSize: isMobile ? 12 : 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedSalesmanTo = value;
                                    });
                                  },
                                ),
                              ),

                              SizedBox(height: isMobile ? 16 : 20),

                              // Area Dropdown (Optional)
                              Text(
                                'المنطقة (اختياري)',
                                style: TextStyle(
                                  fontSize: isMobile ? 14 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(AppConstants.primaryColor),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonFormField<Area>(
                                  value: _selectedArea,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    hintText: 'اختر المنطقة (اختياري)',
                                  ),
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem<Area>(
                                      value: null,
                                      child: Text('جميع المناطق'),
                                    ),
                                    ..._allAreas.map((area) {
                                      return DropdownMenuItem<Area>(
                                        value: area,
                                        child: Text(
                                          '${area.name} (${area.code})',
                                          style: TextStyle(
                                            fontSize: isMobile ? 12 : 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedArea = value;
                                    });
                                  },
                                ),
                              ),

                              SizedBox(height: isMobile ? 24 : 32),

                              // Current Selection Summary
                              if (_selectedSalesmanFrom != null ||
                                  _selectedSalesmanTo != null ||
                                  _selectedArea != null)
                                Container(
                                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                                  decoration: BoxDecoration(
                                    color: const Color(AppConstants.accentColor)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          const Color(AppConstants.accentColor)
                                              .withOpacity(0.3),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'الاختيار الحالي:',
                                        style: TextStyle(
                                          fontSize: isMobile ? 13 : 14,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(
                                              AppConstants.accentColor),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Show actual final values that will be used
                                      if (_selectedSalesmanFrom != null ||
                                          _selectedSalesmanTo != null) ...[
                                        Text(
                                          'من: ${_selectedSalesmanFrom?.name ?? _allSalesmen.first.name} (${_selectedSalesmanFrom?.code ?? _allSalesmen.first.code})',
                                          style: TextStyle(
                                            fontSize: isMobile ? 12 : 13,
                                          ),
                                        ),
                                        Text(
                                          'إلى: ${_selectedSalesmanTo?.name ?? _allSalesmen.last.name} (${_selectedSalesmanTo?.code ?? _allSalesmen.last.code})',
                                          style: TextStyle(
                                            fontSize: isMobile ? 12 : 13,
                                          ),
                                        ),
                                      ],
                                      if (_selectedArea != null)
                                        Text(
                                          'المنطقة: ${_selectedArea!.name} (${_selectedArea!.code})',
                                          style: TextStyle(
                                            fontSize: isMobile ? 12 : 13,
                                          ),
                                        ),
                                      if (_selectedArea == null &&
                                          (_selectedSalesmanFrom != null ||
                                              _selectedSalesmanTo != null))
                                        Text(
                                          'المنطقة: جميع المناطق',
                                          style: TextStyle(
                                            fontSize: isMobile ? 12 : 13,
                                          ),
                                        ),
                                      if (_selectedArea != null &&
                                          _selectedSalesmanFrom == null &&
                                          _selectedSalesmanTo == null)
                                        Text(
                                          'المندوبين: جميع المندوبين في المنطقة',
                                          style: TextStyle(
                                            fontSize: isMobile ? 12 : 13,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                              SizedBox(height: isMobile ? 20 : 24),

                              // Action Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _isValidSelection()
                                          ? _navigateToAgingReport
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                            AppConstants.accentColor),
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                          vertical: isMobile ? 14 : 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
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
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedSalesmanFrom = null;
                                        _selectedSalesmanTo = null;
                                        _selectedArea = null;
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[100],
                                      foregroundColor: Colors.grey[700],
                                      padding: EdgeInsets.symmetric(
                                        vertical: isMobile ? 14 : 16,
                                        horizontal: isMobile ? 16 : 20,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      'إعادة تعيين',
                                      style: TextStyle(
                                        fontSize: isMobile ? 14 : 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
