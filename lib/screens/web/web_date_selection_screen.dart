// lib/screens/web/web_date_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user.dart';
import '../../models/contact.dart';
import '../../utils/helpers.dart';
import '../../utils/constants.dart';
import '../../utils/arabic_text_helper.dart';
import '../../services/supabase_service.dart';
import 'web_account_statements_screen.dart';
import 'web_login_screen.dart';
import 'dart:ui' as ui;

class DateSelectionScreen extends StatefulWidget {
  final AppUser user;
  final Contact contact;

  const DateSelectionScreen({
    super.key,
    required this.user,
    required this.contact,
  });

  @override
  State<DateSelectionScreen> createState() => _DateSelectionScreenState();
}

class _DateSelectionScreenState extends State<DateSelectionScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;
  String _selectedPeriod = '';
  bool _isLoadingStatements = false;
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _displayDateFormat = DateFormat('dd/MM/yyyy');

  final List<DatePeriod> _predefinedPeriods = [
    DatePeriod(
      id: 'today',
      title: 'اليوم',
      icon: Icons.today,
    ),
    DatePeriod(
      id: 'this_week',
      title: 'هذا الأسبوع',
      icon: Icons.view_week,
    ),
    DatePeriod(
      id: 'this_month',
      title: 'هذا الشهر',
      icon: Icons.calendar_view_month,
    ),
    DatePeriod(
      id: 'this_quarter',
      title: 'هذا الربع',
      icon: Icons.calendar_view_day,
    ),
    DatePeriod(
      id: 'this_year',
      title: 'هذه السنة',
      icon: Icons.calendar_today,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Default to this month
    _selectPredefinedPeriod('this_month');
  }

  void _selectPredefinedPeriod(String periodId) {
    final now = DateTime.now();
    setState(() {
      _selectedPeriod = periodId;

      switch (periodId) {
        case 'today':
          _fromDate = DateTime(now.year, now.month, now.day);
          _toDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'this_week':
          final weekday = now.weekday;
          _fromDate = now.subtract(Duration(days: weekday - 1));
          _fromDate =
              DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
          _toDate = now;
          break;
        case 'this_month':
          _fromDate = DateTime(now.year, now.month, 1);
          _toDate = now;
          break;
        case 'this_quarter':
          final quarterMonth = ((now.month - 1) ~/ 3) * 3 + 1;
          _fromDate = DateTime(now.year, quarterMonth, 1);
          _toDate = now;
          break;
        case 'this_year':
          _fromDate = DateTime(now.year, 1, 1);
          _toDate = now;
          break;
      }
    });
  }

  Future<void> _selectCustomDate(bool isFromDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          isFromDate ? _fromDate ?? DateTime.now() : _toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
          if (_toDate != null && _toDate!.isBefore(picked)) {
            _toDate = picked;
            _showDateAdjustmentWarning();
          }
        } else {
          _toDate = picked;
        }
        _selectedPeriod = ''; // Clear selected period when manually editing
      });
    }
  }

  void _showDateAdjustmentWarning() {
    Helpers.showSnackBar(
      context,
      'تأكد من أن تاريخ النهاية بعد تاريخ البداية',
      isError: false,
    );
  }

  Future<void> _loadStatements() async {
    if (_fromDate == null || _toDate == null) {
      Helpers.showSnackBar(
        context,
        'يرجى اختيار التواريخ',
        isError: true,
      );
      return;
    }

    if (_toDate!.isBefore(_fromDate!)) {
      Helpers.showSnackBar(
        context,
        'تاريخ النهاية يجب أن يكون بعد تاريخ البداية',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoadingStatements = true;
    });

    try {
// Navigate to results screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebAccountStatementsScreen(
            user: widget.user,
            contact: widget.contact,
            fromDate:
                _dateFormat.format(_fromDate!), // Convert DateTime to String
            toDate: _dateFormat.format(_toDate!), // Convert DateTime to String
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStatements = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'تسجيل الخروج',
            style: TextStyle(
              color: Color(AppConstants.primaryColor),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text('هل تريد تسجيل الخروج؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: Color(AppConstants.primaryColor)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppConstants.accentColor),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'تسجيل الخروج',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.signOut();
        await Helpers.setLoggedIn(false);
        await Helpers.clearUserData();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const WebLoginScreen(),
            ),
            (route) => false,
          );
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
  }

  String _getGreetingMessage() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return 'صباح الخير ☀️';
    } else if (hour >= 12 && hour < 17) {
      return 'مساء الخير 🌤️';
    } else {
      return 'مساء الخير 🌙';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _WebDateAppBar(
          user: widget.user,
          contact: widget.contact,
          onLogout: _logout,
          greeting: _getGreetingMessage(),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 800 : double.infinity,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 32 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Enhanced Contact Info Card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isDesktop ? 12 : 10),
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
                        // Contact Avatar
                        Container(
                          width: isDesktop ? 70 : 60,
                          height: isDesktop ? 70 : 60,
                          decoration: BoxDecoration(
                            color: const Color(AppConstants.accentColor),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(AppConstants.accentColor)
                                    .withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 0,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              widget.contact.nameAr.isNotEmpty
                                  ? widget.contact.nameAr[0]
                                  : 'ع',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: isDesktop ? 22 : 19,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(width: isDesktop ? 20 : 16),

                        // Contact Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'العميل المحدد',
                                style: TextStyle(
                                  fontSize: isDesktop ? 12 : 11,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: isDesktop ? 6 : 4),
                              Text(
                                ArabicTextHelper.cleanText(
                                    widget.contact.nameAr),
                                style: TextStyle(
                                  fontSize: isDesktop ? 15 : 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(AppConstants.primaryColor),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: isDesktop ? 10 : 8),
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isDesktop ? 10 : 8,
                                      vertical: isDesktop ? 6 : 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          const Color(AppConstants.accentColor)
                                              .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '#',
                                      style: TextStyle(
                                        fontSize: isDesktop ? 12 : 10,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(
                                            AppConstants.accentColor),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: isDesktop ? 10 : 8),
                                  Text(
                                    widget.contact.code,
                                    style: TextStyle(
                                      fontSize: isDesktop ? 13 : 11,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          const Color(AppConstants.accentColor),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Status indicator
                        Container(
                          padding: EdgeInsets.all(isDesktop ? 12 : 10),
                          decoration: BoxDecoration(
                            color: const Color(AppConstants.primaryColor)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.check_circle,
                            color: const Color(AppConstants.primaryColor),
                            size: isDesktop ? 24 : 20,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: isDesktop ? 20 : 16),

                  // Quick Date Selection Section
                  Text(
                    'اختيار سريع للفترة',
                    style: TextStyle(
                      fontSize: isDesktop ? 15 : 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(AppConstants.primaryColor),
                    ),
                  ),

                  SizedBox(height: isDesktop ? 8 : 6),

                  Text(
                    'اختر فترة زمنية محددة مسبقاً',
                    style: TextStyle(
                      fontSize: isDesktop ? 14 : 12,
                      color: Colors.grey[600],
                    ),
                  ),

                  SizedBox(height: isDesktop ? 20 : 16),

                  // Quick date chips in a better layout
                  Container(
                    padding: EdgeInsets.all(isDesktop ? 15 : 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: Wrap(
                      spacing: isDesktop ? 12 : 10,
                      runSpacing: isDesktop ? 12 : 10,
                      children: _predefinedPeriods.map((period) {
                        final isSelected = _selectedPeriod == period.id;
                        return _QuickDateChip(
                          label: period.title,
                          icon: period.icon,
                          isSelected: isSelected,
                          isDesktop: isDesktop,
                          onTap: () => _selectPredefinedPeriod(period.id),
                        );
                      }).toList(),
                    ),
                  ),

                  SizedBox(height: isDesktop ? 40 : 32),

                  // Custom Date Selection Section
                  Text(
                    'اختيار مخصص للتواريخ',
                    style: TextStyle(
                      fontSize: isDesktop ? 15 : 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(AppConstants.primaryColor),
                    ),
                  ),

                  SizedBox(height: isDesktop ? 8 : 6),

                  Text(
                    'حدد تاريخ البداية والنهاية يدوياً',
                    style: TextStyle(
                      fontSize: isDesktop ? 14 : 12,
                      color: Colors.grey[600],
                    ),
                  ),

                  SizedBox(height: isDesktop ? 20 : 16),

                  // Date selection cards
                  Container(
                    padding: EdgeInsets.all(isDesktop ? 20 : 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // From Date
                        _buildDateSelector(
                          title: 'تاريخ البداية',
                          date: _fromDate,
                          icon: Icons.event,
                          color: const Color(AppConstants.accentColor),
                          isDesktop: isDesktop,
                          onTap: () => _selectCustomDate(true),
                        ),

                        SizedBox(height: isDesktop ? 16 : 12),

                        // To Date
                        _buildDateSelector(
                          title: 'تاريخ النهاية',
                          date: _toDate,
                          icon: Icons.event_available,
                          color: const Color(AppConstants.primaryColor),
                          isDesktop: isDesktop,
                          onTap: () => _selectCustomDate(false),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: isDesktop ? 40 : 32),

                  // Enhanced Proceed Button
                  Container(
                    width: double.infinity,
                    height: isDesktop ? 60 : 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: (_fromDate != null &&
                              _toDate != null &&
                              !_isLoadingStatements)
                          ? [
                              BoxShadow(
                                color: const Color(AppConstants.accentColor)
                                    .withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: ElevatedButton(
                      onPressed: (_fromDate != null &&
                              _toDate != null &&
                              !_isLoadingStatements)
                          ? _loadStatements
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(AppConstants.accentColor),
                        disabledBackgroundColor: Colors.grey[300],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoadingStatements
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'جاري التحميل...',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 16 : 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.analytics,
                                  size: isDesktop ? 22 : 20,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'عرض كشف الحساب',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 16 : 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  SizedBox(height: isDesktop ? 32 : 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector({
    required String title,
    required DateTime? date,
    required IconData icon,
    required Color color,
    required bool isDesktop,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isDesktop ? 14 : 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.02),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isDesktop ? 10 : 8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: isDesktop ? 22 : 20,
              ),
            ),
            SizedBox(width: isDesktop ? 18 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isDesktop ? 12 : 10,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: isDesktop ? 6 : 4),
                  Text(
                    date != null
                        ? _displayDateFormat.format(date)
                        : 'اختر التاريخ',
                    style: TextStyle(
                      fontSize: isDesktop ? 14 : 13,
                      fontWeight: FontWeight.w600,
                      color: date != null
                          ? const Color(AppConstants.primaryColor)
                          : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_back_ios,
              size: isDesktop ? 18 : 16,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class _WebDateAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppUser user;
  final Contact contact;
  final VoidCallback onLogout;
  final String greeting;

  const _WebDateAppBar({
    required this.user,
    required this.contact,
    required this.onLogout,
    required this.greeting,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AppBar(
        elevation: 4,
        backgroundColor: const Color(AppConstants.primaryColor),
        toolbarHeight: kToolbarHeight,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Padding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 8),
          child: Row(
            children: [
              // Logo with white background
              Container(
                padding: EdgeInsets.all(isDesktop ? 8 : 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  AppConstants.logoPath,
                  width: isDesktop ? 32 : 28,
                  height: isDesktop ? 32 : 28,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: isDesktop ? 32 : 28,
                      height: isDesktop ? 32 : 28,
                      decoration: BoxDecoration(
                        color: const Color(AppConstants.accentColor),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.account_balance,
                        size: isDesktop ? 18 : 16,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),

              SizedBox(width: isDesktop ? 16 : 12),

              // Title
              Expanded(
                child: Text(
                  isDesktop
                      ? 'كشف حساب - ${ArabicTextHelper.cleanText(contact.nameAr)}'
                      : 'كشف الحساب',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // User info for desktop
              if (isDesktop) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person,
                        size: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        user.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(left: isDesktop ? 16 : 12),
            child: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'logout') {
                  onLogout();
                }
              },
              icon: const Icon(
                Icons.more_vert,
                color: Colors.white,
                size: 20,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'logout',
                  child: Directionality(
                    textDirection: ui.TextDirection.rtl,
                    child: Row(
                      children: [
                        Icon(
                          Icons.logout,
                          color: const Color(AppConstants.errorColor),
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'تسجيل الخروج',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _QuickDateChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDesktop;
  final VoidCallback onTap;

  const _QuickDateChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isDesktop,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 14 : 12,
            vertical: isDesktop ? 10 : 8,
          ),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      const Color(AppConstants.accentColor).withOpacity(0.2),
                      const Color(AppConstants.accentColor).withOpacity(0.1),
                    ],
                  )
                : LinearGradient(
                    colors: [
                      const Color(AppConstants.accentColor).withOpacity(0.05),
                      const Color(AppConstants.accentColor).withOpacity(0.02),
                    ],
                  ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: isSelected
                  ? const Color(AppConstants.accentColor)
                  : const Color(AppConstants.accentColor).withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: isDesktop ? 15 : 13,
                color: const Color(AppConstants.accentColor),
              ),
              SizedBox(width: isDesktop ? 8 : 6),
              Text(
                label,
                style: TextStyle(
                  color: const Color(AppConstants.accentColor),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: isDesktop ? 13 : 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DatePeriod {
  final String id;
  final String title;
  final IconData icon;

  DatePeriod({
    required this.id,
    required this.title,
    required this.icon,
  });
}
