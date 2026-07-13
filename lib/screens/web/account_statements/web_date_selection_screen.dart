// lib/screens/web/web_date_selection_screen.dart - Light and Smooth
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import '../../../models/user.dart';
import '../../../models/contact.dart';
import '../../../utils/helpers.dart';
import '../../../utils/constants.dart';
import '../../../utils/arabic_text_helper.dart';
import '../../../services/supabase_service.dart';
import 'web_account_statements_screen.dart';
import '../web_login_screen.dart';
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

// lib/screens/web/web_date_selection_screen.dart - OPTIMIZED

class _DateSelectionScreenState extends State<DateSelectionScreen>
    with AutomaticKeepAliveClientMixin {
  DateTime? _fromDate;
  DateTime? _toDate;
  String _selectedPeriod = '';
  bool _isLoadingStatements = false;

  static final _dateFormat = DateFormat('yyyy-MM-dd');
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

  Future<void> _loadStatements() async {
    if (_fromDate == null || _toDate == null) {
      _showSnackBar('يرجى اختيار التواريخ', true);
      return;
    }

    if (_toDate!.isBefore(_fromDate!)) {
      _showSnackBar('تاريخ النهاية يجب أن يكون بعد تاريخ البداية', true);
      return;
    }

    setState(() => _isLoadingStatements = true);

    try {
      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              WebAccountStatementsScreen(
            user: widget.user,
            contact: widget.contact,
            fromDate: _dateFormat.format(_fromDate!),
            toDate: _dateFormat.format(_toDate!),
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
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingStatements = false);
      }
    }
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
            transitionDuration: const Duration(milliseconds: 200),
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
    super.build(context);

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isMobile = size.width < 768;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _LightAppBar(
          user: widget.user,
          contact: widget.contact,
          onLogout: _logout,
          isDesktop: isDesktop,
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
                  _buildContactCard(isDesktop, isMobile),
                  SizedBox(height: isMobile ? 20 : 24),
                  _buildSectionTitle('اختيار سريع للفترة', isMobile),
                  SizedBox(height: isMobile ? 12 : 16),
                  _buildQuickSelection(isMobile),
                  SizedBox(height: isMobile ? 24 : 32),
                  _buildSectionTitle('تحديد التواريخ', isMobile),
                  SizedBox(height: isMobile ? 12 : 16),
                  _buildDateSelection(isDesktop, isMobile),
                  SizedBox(height: isMobile ? 24 : 32),
                  _buildActionButton(isDesktop, isMobile),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard(bool isDesktop, bool isMobile) {
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
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isMobile ? 50 : 60,
            height: isMobile ? 50 : 60,
            decoration: BoxDecoration(
              color: const Color(AppConstants.accentColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                widget.contact.nameAr.isNotEmpty
                    ? widget.contact.nameAr[0]
                    : 'ع',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: isMobile ? 18 : 20,
                ),
              ),
            ),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'العميل المحدد',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: isMobile ? 4 : 6),
                Text(
                  ArabicTextHelper.cleanText(widget.contact.nameAr),
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(AppConstants.primaryColor),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isMobile ? 6 : 8),
                Text(
                  'كود: ${widget.contact.code}',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: const Color(AppConstants.accentColor),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
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

  Widget _buildDateSelection(bool isDesktop, bool isMobile) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDateField(
          title: 'من تاريخ',
          date: _fromDate,
          icon: Icons.event,
          onTap: () => _selectCustomDate(true),
          isMobile: isMobile,
        ),
        SizedBox(height: isMobile ? 12 : 16),
        _buildDateField(
          title: 'إلى تاريخ',
          date: _toDate,
          icon: Icons.event_available,
          onTap: () => _selectCustomDate(false),
          isMobile: isMobile,
        ),
      ],
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

  Widget _buildActionButton(bool isDesktop, bool isMobile) {
    final isEnabled =
        _fromDate != null && _toDate != null && !_isLoadingStatements;

    return SizedBox(
      width: double.infinity,
      height: isMobile ? 50 : 56,
      child: ElevatedButton(
        onPressed: isEnabled ? _loadStatements : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(AppConstants.accentColor),
          disabledBackgroundColor: Colors.grey.shade300,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoadingStatements
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
                    'عرض كشف الحساب',
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

class _LightAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppUser user;
  final Contact contact;
  final VoidCallback onLogout;
  final bool isDesktop;

  const _LightAppBar({
    required this.user,
    required this.contact,
    required this.onLogout,
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
        isDesktop
            ? 'كشف حساب - ${ArabicTextHelper.cleanText(contact.nameAr)}'
            : 'كشف الحساب',
        style: const TextStyle(
          color: Color(AppConstants.primaryColor),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        if (isDesktop)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Chip(
              label: Text(
                user.username,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor:
                  const Color(AppConstants.accentColor).withOpacity(0.1),
              side: BorderSide.none,
            ),
          ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'logout') onLogout();
          },
          icon: const Icon(
            Icons.more_vert,
            color: Color(AppConstants.primaryColor),
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(
                    Icons.logout,
                    color: Colors.red.shade400,
                    size: 18,
                  ),
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
