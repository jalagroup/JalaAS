// lib/screens/web/web_group_date_selection_screen.dart - OPTIMIZED WITH SUGGESTIONS

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:jala_as/models/contact_group.dart';
import 'package:jala_as/models/user.dart';
import 'package:jala_as/utils/constants.dart';
import 'package:jala_as/utils/helpers.dart';
import 'package:jala_as/utils/arabic_text_helper.dart';
import 'web_group_account_statements_result_screen.dart';
import 'dart:ui' as ui;

class GroupDateSelectionScreen extends StatefulWidget {
  final AppUser user;
  final ContactGroup group;

  const GroupDateSelectionScreen({
    super.key,
    required this.user,
    required this.group,
  });

  @override
  State<GroupDateSelectionScreen> createState() =>
      _GroupDateSelectionScreenState();
}

class _GroupDateSelectionScreenState extends State<GroupDateSelectionScreen>
    with AutomaticKeepAliveClientMixin {
  DateTime? _fromDate;
  DateTime? _toDate;
  String _selectedPeriod = '';
  bool _isLoading = false;

  static final _displayDateFormat = DateFormat('dd/MM/yyyy');

  static const List<DatePeriod> _predefinedPeriods = [
    DatePeriod(id: 'today', title: 'اليوم', icon: Icons.today),
    DatePeriod(id: 'this_week', title: 'هذا الأسبوع', icon: Icons.view_week),
    DatePeriod(
        id: 'this_month', title: 'هذا الشهر', icon: Icons.calendar_view_month),
    DatePeriod(
        id: 'prev_month',
        title: 'الشهر الماضي',
        icon: Icons.calendar_view_month),
    DatePeriod(
        id: 'this_quarter', title: 'هذا الربع', icon: Icons.calendar_view_day),
    DatePeriod(id: 'this_year', title: 'هذا العام', icon: Icons.calendar_today),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _selectPredefinedPeriod('this_month');
  }

  void _selectPredefinedPeriod(String periodId) {
    final now = DateTime.now();
    DateTime fromDate;
    DateTime toDate;

    switch (periodId) {
      case 'today':
        fromDate = DateTime(now.year, now.month, now.day);
        toDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'this_week':
        final weekday = now.weekday;
        fromDate = now.subtract(Duration(days: weekday - 1));
        fromDate = DateTime(fromDate.year, fromDate.month, fromDate.day);
        toDate = now;
        break;
      case 'this_month':
        fromDate = DateTime(now.year, now.month, 1);
        toDate = now;
        break;
      case 'prev_month':
        final prevMonth = now.month == 1 ? 12 : now.month - 1;
        final prevYear = now.month == 1 ? now.year - 1 : now.year;
        fromDate = DateTime(prevYear, prevMonth, 1);
        toDate = DateTime(prevYear, prevMonth + 1, 0, 23, 59, 59);
        break;
      case 'this_quarter':
        final quarterMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        fromDate = DateTime(now.year, quarterMonth, 1);
        toDate = now;
        break;
      case 'this_year':
        fromDate = DateTime(now.year, 1, 1);
        toDate = now;
        break;
      default:
        fromDate = DateTime(now.year, now.month, 1);
        toDate = now;
    }

    setState(() {
      _selectedPeriod = periodId;
      _fromDate = fromDate;
      _toDate = toDate;
    });
  }

  Future<void> _selectCustomDate(bool isFromDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          isFromDate ? _fromDate ?? DateTime.now() : _toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: Localizations(
            locale: const Locale('ar', 'SA'),
            delegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: const Color(AppConstants.accentColor),
                    ),
              ),
              child: child!,
            ),
          ),
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
          if (_toDate != null && _toDate!.isBefore(picked)) {
            _toDate = picked;
          }
        } else {
          _toDate = picked;
        }
        _selectedPeriod = '';
      });
    }
  }

  void _proceedToStatements() {
    if (_fromDate == null || _toDate == null) {
      _showSnackBar('يرجى اختيار التاريخ من والى', true);
      return;
    }

    if (_toDate!.isBefore(_fromDate!)) {
      _showSnackBar('تاريخ النهاية يجب أن يكون بعد تاريخ البداية', true);
      return;
    }

    setState(() => _isLoading = true);

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            GroupAccountStatementsResultScreen(
          user: widget.user,
          group: widget.group,
          fromDate: Helpers.formatApiDate(_fromDate!),
          toDate: Helpers.formatApiDate(_toDate!),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.03, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isMobile = size.width < 768;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back,
                color: Color(AppConstants.primaryColor)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'اختيار التاريخ',
            style: TextStyle(
              color: Color(AppConstants.primaryColor),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 700 : double.infinity,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Group Info Card
                  _buildGroupCard(isMobile),

                  SizedBox(height: isMobile ? 20 : 24),

                  // Quick Selection Title
                  _buildSectionTitle('اختيار سريع للفترة', isMobile),

                  SizedBox(height: isMobile ? 12 : 16),

                  // Quick Selection Buttons
                  _buildQuickSelection(isMobile),

                  SizedBox(height: isMobile ? 24 : 32),

                  // Custom Date Selection Title
                  _buildSectionTitle('تحديد التواريخ', isMobile),

                  SizedBox(height: isMobile ? 12 : 16),

                  // From Date
                  _buildDateField(
                    title: 'من تاريخ',
                    date: _fromDate,
                    icon: Icons.event,
                    onTap: () => _selectCustomDate(true),
                    isMobile: isMobile,
                  ),

                  SizedBox(height: isMobile ? 12 : 16),

                  // To Date
                  _buildDateField(
                    title: 'إلى تاريخ',
                    date: _toDate,
                    icon: Icons.event_available,
                    onTap: () => _selectCustomDate(false),
                    isMobile: isMobile,
                  ),

                  SizedBox(height: isMobile ? 24 : 32),

                  // Proceed Button
                  _buildActionButton(isMobile),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupCard(bool isMobile) {
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
      child: Row(
        children: [
          // Icon
          Container(
            width: isMobile ? 50 : 60,
            height: isMobile ? 50 : 60,
            decoration: BoxDecoration(
              color: const Color(AppConstants.accentColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.group,
              color: Colors.white,
              size: isMobile ? 24 : 28,
            ),
          ),

          SizedBox(width: isMobile ? 12 : 16),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'المجموعة المحددة',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: isMobile ? 4 : 6),
                Text(
                  ArabicTextHelper.cleanText(widget.group.name),
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(AppConstants.primaryColor),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isMobile ? 6 : 8),
                Row(
                  children: [
                    Icon(
                      Icons.people,
                      size: isMobile ? 14 : 16,
                      color: const Color(AppConstants.accentColor),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.group.contactCodes.length} عميل',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        color: const Color(AppConstants.accentColor),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Status Icon
          Icon(
            Icons.check_circle,
            color: Colors.green.shade500,
            size: isMobile ? 20 : 24,
          ),
        ],
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
    return Wrap(
      spacing: isMobile ? 8 : 12,
      runSpacing: isMobile ? 8 : 12,
      children: _predefinedPeriods.map((period) {
        final isSelected = _selectedPeriod == period.id;
        return InkWell(
          onTap: () => _selectPredefinedPeriod(period.id),
          borderRadius: BorderRadius.circular(20),
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

  Widget _buildDateField({
    required String title,
    required DateTime? date,
    required IconData icon,
    required VoidCallback onTap,
    required bool isMobile,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
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
                mainAxisSize: MainAxisSize.min,
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
                    date != null
                        ? _displayDateFormat.format(date)
                        : 'اختر التاريخ',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 15,
                      fontWeight: FontWeight.w600,
                      color: date != null
                          ? const Color(AppConstants.primaryColor)
                          : Colors.grey.shade500,
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

  Widget _buildActionButton(bool isMobile) {
    final isEnabled = _fromDate != null && _toDate != null && !_isLoading;

    return SizedBox(
      width: double.infinity,
      height: isMobile ? 50 : 56,
      child: ElevatedButton(
        onPressed: isEnabled ? _proceedToStatements : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(AppConstants.accentColor),
          disabledBackgroundColor: Colors.grey.shade300,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'جاري التحميل...',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.analytics,
                    size: isMobile ? 18 : 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'عرض كشوف الحساب',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class DatePeriod {
  final String id;
  final String title;
  final IconData icon;

  const DatePeriod({
    required this.id,
    required this.title,
    required this.icon,
  });
}
