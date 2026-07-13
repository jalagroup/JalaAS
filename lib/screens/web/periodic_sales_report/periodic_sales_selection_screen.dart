// lib/screens/web/periodic_sales_selection_screen.dart - Part 1
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jala_as/models/salesman.dart';
import '../../../models/user.dart';
import '../../../models/periodic_sales_report.dart';
import '../../../utils/constants.dart';
import 'periodic_sales_report_screen.dart';
import 'dart:ui' as ui;

class PeriodicSalesSelectionScreen extends StatefulWidget {
  final AppUser user;

  const PeriodicSalesSelectionScreen({
    super.key,
    required this.user,
  });

  @override
  State<PeriodicSalesSelectionScreen> createState() =>
      _PeriodicSalesSelectionScreenState();
}

class _PeriodicSalesSelectionScreenState
    extends State<PeriodicSalesSelectionScreen> {
  DateRangePreset _selectedPreset = DateRangePreset.currentMonth;
  AreaSelection _selectedArea = AreaSelection.all;

  DateTime _customFromDate = DateTime.now();
  DateTime _customToDate = DateTime.now();

  Salesman? _selectedSalesman;

  final DateFormat _displayDateFormat = DateFormat('dd/MM/yyyy', 'ar');

  @override
  void initState() {
    super.initState();
    _initializeAreaSelection();
    _updateCustomDatesFromPreset();
  }

  void _initializeAreaSelection() {
    if (widget.user.isSalesAdmin &&
        !widget.user.canChoosePeriodicAreaSelection) {
      // Fixed area for restricted sales admins
      _selectedArea = widget.user.fixedPeriodicAreaSelection;
    } else {
      // Default selection for users who can choose
      _selectedArea = AreaSelection.all;
    }
  }

  static List<Salesman> getAvailableSalesmen() {
    return [
      Salesman(code: "001", name: "سليمان فؤاد سليمان دياب"),
      Salesman(code: "002", name: "معتز خالد ابراهيم الحموري"),
      Salesman(code: "003", name: "فراس منير فتحي سليمان"),
      Salesman(code: "005", name: "محمد عطية عبد  عطيه"),
      Salesman(code: "007", name: "شركة جالا فود"),
      Salesman(code: "015", name: "مايك الياس باسيل غنيم"),
      Salesman(code: "030", name: "جوني خالد باسيل المصو"),
      Salesman(code: "031", name: "احمد علي حسن عكيله"),
      Salesman(code: "045", name: "اسماعيل يعقوب احمد الهودلي"),
      Salesman(code: "046", name: "فؤاد سهيل فؤاد غنيم"),
      Salesman(code: "047", name: "مهند زياد عبد الحميد العيسه"),
      Salesman(code: "048", name: "اياد عزيز سليمان عبد"),
      Salesman(code: "050", name: "ايليا ماهر  ابراهيم  زيدان"),
      Salesman(code: "044", name: "محمد كنعان"),
      Salesman(code: "043", name: "نمر شمارخة")
    ];
  }

  Widget _buildAreaSelector(bool isMobile) {
    // Check if sales admin has restricted area selection
    if (widget.user.isSalesAdmin &&
        !widget.user.canChoosePeriodicAreaSelection) {
      return _buildFixedAreaDisplay(isMobile);
    }

    // Show selectable options for users who can choose (including sales admins with 'all' areas)
    return _buildSelectableAreaOptions(isMobile);
  }

  // Add this method to build the salesman selector
  Widget _buildSalesmanSelector(bool isMobile) {
    final salesmen = getAvailableSalesmen();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'مندوب المبيعات (اختياري)',
          style: TextStyle(
            fontSize: isMobile ? 14 : 16,
            fontWeight: FontWeight.w500,
            color: const Color(AppConstants.primaryColor),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<Salesman>(
          value: _selectedSalesman,
          decoration: InputDecoration(
            hintText: 'اختر مندوب المبيعات',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: isMobile ? 12 : 14,
            ),
          ),
          style: TextStyle(
            fontSize: isMobile ? 14 : 16,
            color: Colors.black87,
          ),
          items: [
            DropdownMenuItem<Salesman>(
              value: null,
              child: Text(
                'كل مناديب المبيعات',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ...salesmen.map((salesman) {
              return DropdownMenuItem<Salesman>(
                value: salesman,
                child: Text(
                  salesman.name,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
          ],
          onChanged: (Salesman? value) {
            setState(() {
              _selectedSalesman = value;
            });
          },
        ),
        if (_selectedSalesman != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.person, color: Colors.blue.shade600, size: 16),
                const SizedBox(width: 8),
                Text(
                  'المندوب المحدد: ${_selectedSalesman!.name}',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(كود: ${_selectedSalesman!.code})',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectableAreaOptions(bool isMobile) {
    final areaOptions = [
      _AreaOption(AreaSelection.all, 'كل المناطق', Icons.map),
      _AreaOption(AreaSelection.south, 'مناطق الجنوب', Icons.south),
      _AreaOption(AreaSelection.north, 'مناطق الشمال', Icons.north),
    ];

    return Wrap(
      spacing: isMobile ? 8 : 12,
      runSpacing: isMobile ? 8 : 12,
      children: areaOptions.map((area) {
        final isSelected = _selectedArea == area.selection;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedArea = area.selection;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 8 : 10,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(AppConstants.accentColor).withOpacity(0.1)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? const Color(AppConstants.accentColor)
                    : Colors.grey.shade300,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  area.icon,
                  size: isMobile ? 14 : 16,
                  color: isSelected
                      ? const Color(AppConstants.accentColor)
                      : Colors.grey.shade600,
                ),
                SizedBox(width: isMobile ? 6 : 8),
                Text(
                  area.title,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? const Color(AppConstants.accentColor)
                        : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFixedAreaDisplay(bool isMobile) {
    IconData areaIcon;
    String areaTitle;
    Color accentColor = const Color(AppConstants.accentColor);

    switch (_selectedArea) {
      case AreaSelection.north:
        areaIcon = Icons.north;
        areaTitle = 'مناطق الشمال';
        break;
      case AreaSelection.south:
        areaIcon = Icons.south;
        areaTitle = 'مناطق الجنوب';
        break;
      case AreaSelection.all:
      default:
        areaIcon = Icons.map;
        areaTitle = 'كل المناطق';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 20,
        vertical: isMobile ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              areaIcon,
              size: isMobile ? 18 : 20,
              color: accentColor,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'النطاق المخصص لك',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: accentColor.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  areaTitle,
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
                Text(
                  'لا يمكن تغييره',
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 11,
                    color: accentColor.withOpacity(0.7),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'ثابت',
              style: TextStyle(
                fontSize: isMobile ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getAreaSectionTitle() {
    if (widget.user.isSalesAdmin &&
        !widget.user.canChoosePeriodicAreaSelection) {
      return 'النطاق الجغرافي المخصص';
    }
    return 'نطاق المناطق';
  }

  Widget _buildReadOnlyPeriodicAreaDisplay(bool isMobile) {
    IconData areaIcon;
    String areaTitle;

    switch (_selectedArea) {
      case AreaSelection.north:
        areaIcon = Icons.north;
        areaTitle = 'مناطق الشمال';
        break;
      case AreaSelection.south:
        areaIcon = Icons.south;
        areaTitle = 'مناطق الجنوب';
        break;
      case AreaSelection.all:
      default:
        areaIcon = Icons.map;
        areaTitle = 'كل المناطق';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 20,
        vertical: isMobile ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: const Color(AppConstants.accentColor).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(AppConstants.accentColor).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(AppConstants.accentColor).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              areaIcon,
              size: isMobile ? 18 : 20,
              color: const Color(AppConstants.accentColor),
            ),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'النطاق المخصص للتقارير الدورية',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color:
                        const Color(AppConstants.accentColor).withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  areaTitle,
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(AppConstants.accentColor),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(AppConstants.accentColor).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'مخصص',
              style: TextStyle(
                fontSize: isMobile ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: const Color(AppConstants.accentColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateCustomDatesFromPreset() {
    if (_selectedPreset != DateRangePreset.custom) {
      final dateRange = DateRangeHelper.getDateRange(_selectedPreset);
      _customFromDate = DateTime.parse(dateRange['fromDate']!);
      _customToDate = DateTime.parse(dateRange['toDate']!);
    }
  }

  void _selectPredefinedPeriod(DateRangePreset preset) {
    setState(() {
      _selectedPreset = preset;
      _updateCustomDatesFromPreset();
    });
  }

  Future<void> _selectDate(bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? _customFromDate : _customToDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ar'),
      builder: (context, child) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(AppConstants.accentColor),
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _customFromDate = picked;
          if (_customFromDate.isAfter(_customToDate)) {
            _customToDate = _customFromDate;
          }
        } else {
          _customToDate = picked;
          if (_customToDate.isBefore(_customFromDate)) {
            _customFromDate = _customToDate;
          }
        }
        _selectedPreset = DateRangePreset.custom;
      });
    }
  }

// Update the _navigateToReport method to include salesman
  void _navigateToReport() {
    String fromDate, toDate;

    if (_selectedPreset == DateRangePreset.custom) {
      fromDate = DateRangeHelper.formatDate(_customFromDate);
      toDate = DateRangeHelper.formatDate(_customToDate);
    } else {
      final dateRange = DateRangeHelper.getDateRange(_selectedPreset);
      fromDate = dateRange['fromDate']!;
      toDate = dateRange['toDate']!;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PeriodicSalesReportScreen(
          user: widget.user,
          fromDate: fromDate,
          toDate: toDate,
          areaSelection: _selectedArea,
          selectedSalesman: _selectedSalesman, // Add this line
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isMobile) {
    return Text(
      title,
      style: TextStyle(
        fontSize: isMobile ? 16 : 18,
        fontWeight: FontWeight.w600,
        color: const Color(AppConstants.primaryColor),
      ),
    );
  }

  Widget _buildQuickSelection(bool isMobile) {
    final predefinedPeriods = [
      _PeriodOption(DateRangePreset.currentDay, 'اليوم الحالي', Icons.today),
      _PeriodOption(
          DateRangePreset.yesterday, 'البارحة', Icons.today), // Add this line
      _PeriodOption(
          DateRangePreset.currentWeek, 'الأسبوع الحالي', Icons.view_week),
      _PeriodOption(DateRangePreset.currentMonth, 'الشهر الحالي',
          Icons.calendar_view_month),
      _PeriodOption(DateRangePreset.previousMonth, 'الشهر السابق',
          Icons.calendar_view_month),
      _PeriodOption(DateRangePreset.currentQuarter, 'الربع الحالي',
          Icons.calendar_view_day),
      _PeriodOption(
          DateRangePreset.currentYear, 'السنة الحالية', Icons.calendar_today),
    ];

    return Wrap(
      spacing: isMobile ? 8 : 12,
      runSpacing: isMobile ? 8 : 12,
      children: predefinedPeriods.map((period) {
        final isSelected = _selectedPreset == period.preset;
        return GestureDetector(
          onTap: () => _selectPredefinedPeriod(period.preset),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 8 : 10,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(AppConstants.accentColor).withOpacity(0.1)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? const Color(AppConstants.accentColor)
                    : Colors.grey.shade300,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  period.icon,
                  size: isMobile ? 14 : 16,
                  color: isSelected
                      ? const Color(AppConstants.accentColor)
                      : Colors.grey.shade600,
                ),
                SizedBox(width: isMobile ? 6 : 8),
                Text(
                  period.title,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? const Color(AppConstants.accentColor)
                        : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateSelection(bool isDesktop, bool isMobile) {
    return Column(
      children: [
        _buildDateField(
          title: 'من تاريخ',
          date: _customFromDate,
          icon: Icons.event,
          onTap: () => _selectDate(true),
          isMobile: isMobile,
        ),
        SizedBox(height: isMobile ? 12 : 16),
        _buildDateField(
          title: 'إلى تاريخ',
          date: _customToDate,
          icon: Icons.event_available,
          onTap: () => _selectDate(false),
          isMobile: isMobile,
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String title,
    required DateTime date,
    required IconData icon,
    required VoidCallback onTap,
    required bool isMobile,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isMobile ? 14 : 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(AppConstants.accentColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: isMobile ? 18 : 20,
              ),
            ),
            SizedBox(width: isMobile ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: isMobile ? 2 : 4),
                  Text(
                    _displayDateFormat.format(date),
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(AppConstants.primaryColor),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.calendar_today,
              size: isMobile ? 16 : 18,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(bool isMobile) {
    String dateRangeText;
    if (_selectedPreset == DateRangePreset.custom) {
      dateRangeText =
          '${_displayDateFormat.format(_customFromDate)} - ${_displayDateFormat.format(_customToDate)}';
    } else {
      final dateRange = DateRangeHelper.getDateRange(_selectedPreset);
      final fromDate = DateTime.parse(dateRange['fromDate']!);
      final toDate = DateTime.parse(dateRange['toDate']!);
      dateRangeText =
          '${_displayDateFormat.format(fromDate)} - ${_displayDateFormat.format(toDate)}';
    }

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.summarize_outlined,
                color: const Color(AppConstants.accentColor),
                size: isMobile ? 18 : 20,
              ),
              const SizedBox(width: 8),
              Text(
                'ملخص الاختيار',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(AppConstants.primaryColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryItem(
            'نوع الفترة',
            DateRangeHelper.presetLabels[_selectedPreset]!,
            Icons.access_time,
            isMobile,
          ),
          _buildSummaryItem(
            'الفترة الزمنية',
            dateRangeText,
            Icons.date_range,
            isMobile,
          ),
          _buildSummaryItem(
            'النطاق الجغرافي',
            DateRangeHelper.areaLabels[_selectedArea]!,
            Icons.location_on,
            isMobile,
          ),
          _buildSummaryItem(
            'مندوب المبيعات',
            _selectedSalesman?.name ?? 'كل مناديب المبيعات',
            Icons.person,
            isMobile,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      String label, String value, IconData icon, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: isMobile ? 14 : 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: isMobile ? 12 : 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                color: const Color(AppConstants.primaryColor),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isMobile = screenWidth < 768;
    final maxWidth = isDesktop ? 700.0 : double.infinity;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back,
                color: Color(AppConstants.primaryColor)),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'تقرير المبيعات بناءاً على الفترات',
            style: TextStyle(
              color: Color(AppConstants.primaryColor),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Date Selection
                  _buildSectionTitle('اختيار سريع للفترة', isMobile),
                  SizedBox(height: isMobile ? 12 : 16),
                  _buildQuickSelection(isMobile),

                  SizedBox(height: isMobile ? 24 : 32),

                  // Custom Date Selection
                  _buildSectionTitle('تحديد التواريخ', isMobile),
                  SizedBox(height: isMobile ? 12 : 16),
                  _buildDateSelection(isDesktop, isMobile),

                  SizedBox(height: isMobile ? 24 : 32),

                  // Area Selection - Dynamic title based on user permissions
                  _buildSectionTitle(_getAreaSectionTitle(), isMobile),
                  SizedBox(height: isMobile ? 12 : 16),
                  _buildAreaSelector(isMobile),
// Add the salesman section in the build method, after area selection:
                  SizedBox(height: isMobile ? 24 : 32),

// Salesman Selection
                  _buildSectionTitle('مندوب المبيعات', isMobile),
                  SizedBox(height: isMobile ? 12 : 16),
                  _buildSalesmanSelector(isMobile),

                  SizedBox(height: isMobile ? 24 : 32),

                  // Summary
                  _buildSummary(isMobile),

                  SizedBox(height: isMobile ? 24 : 32),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: isMobile ? 50 : 56,
                          child: ElevatedButton(
                            onPressed: _navigateToReport,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(AppConstants.accentColor),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.analytics,
                                  size: isMobile ? 18 : 20,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'عرض التقرير',
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: isMobile ? 50 : 56,
                          child: OutlinedButton(
// In the reset button onPressed:
                            onPressed: () {
                              setState(() {
                                _selectedPreset = DateRangePreset.currentMonth;
                                // Only reset area if user can choose
                                if (widget
                                    .user.canChoosePeriodicAreaSelection) {
                                  _selectedArea = AreaSelection.all;
                                }
                                _selectedSalesman = null; // Add this line
                                _updateCustomDatesFromPreset();
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
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
                      ),
                    ],
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

class _PeriodOption {
  final DateRangePreset preset;
  final String title;
  final IconData icon;

  const _PeriodOption(this.preset, this.title, this.icon);
}

class _AreaOption {
  final AreaSelection selection;
  final String title;
  final IconData icon;

  const _AreaOption(this.selection, this.title, this.icon);
}
