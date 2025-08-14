// lib/screens/mobile/web_date_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jala_as/utils/constants.dart';
import '../../models/contact.dart';
import '../../utils/helpers.dart';
import 'mobile_account_statements_screen.dart';

class DateRangeScreen extends StatefulWidget {
  final Contact contact;

  const DateRangeScreen({
    super.key,
    required this.contact,
  });

  @override
  State<DateRangeScreen> createState() => _DateRangeScreenState();
}

class _DateRangeScreenState extends State<DateRangeScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _displayDateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    // Set default dates (current month)
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = now;
  }

  Future<void> _selectFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      // Remove hardcoded locale - let system handle it
      // locale: const Locale('ar'),
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked;
        // Better logic: only adjust toDate if it's significantly before fromDate
        if (_toDate != null && _toDate!.isBefore(picked)) {
          // Show a warning to user instead of silently changing toDate
          _showDateAdjustmentWarning();
        }
      });
    }
  }

  Future<void> _selectToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: _fromDate ?? DateTime(2020),
      lastDate: DateTime.now(),
      // Remove hardcoded locale
      // locale: const Locale('ar'),
    );

    if (picked != null) {
      setState(() {
        _toDate = picked;
      });
    }
  }

  void _showDateAdjustmentWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تأكد من أن تاريخ النهاية بعد تاريخ البداية'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _proceed() {
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

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AccountStatementsScreen(
          contact: widget.contact,
          fromDate: _dateFormat.format(_fromDate!),
          toDate: _dateFormat.format(_toDate!),
        ),
      ),
    );
  }

  void _setQuickDate(String period) {
    final now = DateTime.now();
    DateTime from;

    switch (period) {
      case 'today':
        from = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        from = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        from = DateTime(now.year, now.month, 1);
        break;
      case 'quarter':
        // Improved quarter calculation
        final currentQuarter = ((now.month - 1) ~/ 3) + 1;
        final quarterStartMonth = (currentQuarter - 1) * 3 + 1;
        from = DateTime(now.year, quarterStartMonth, 1);
        break;
      case 'year':
        from = DateTime(now.year, 1, 1);
        break;
      default:
        return;
    }

    setState(() {
      _fromDate = from;
      _toDate = now;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('اختيار الفترة'),
        backgroundColor: const Color(AppConstants.primaryColor),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enhanced Contact Info Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
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
                  child: Row(
                    children: [
                      // Contact Avatar
                      Container(
                        width: 60,
                        height: 60,
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Contact Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'العميل المحدد',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.contact.nameAr,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(AppConstants.primaryColor),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(AppConstants.accentColor)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '#',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          const Color(AppConstants.accentColor),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.contact.code,
                                  style: TextStyle(
                                    fontSize: 13,
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(AppConstants.primaryColor)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Color(AppConstants.primaryColor),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Quick Date Selection Section
                Text(
                  'اختيار سريع للفترة',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(AppConstants.primaryColor),
                      ),
                ),

                const SizedBox(height: 4),

                Text(
                  'اختر فترة زمنية محددة مسبقاً',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),

                const SizedBox(height: 16),

                // Quick date chips in a better layout
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 6,
                        spreadRadius: 1,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _QuickDateChip(
                          label: 'اليوم',
                          icon: Icons.today,
                          onTap: () => _setQuickDate('today')),
                      _QuickDateChip(
                          label: 'آخر أسبوع',
                          icon: Icons.date_range,
                          onTap: () => _setQuickDate('week')),
                      _QuickDateChip(
                          label: 'هذا الشهر',
                          icon: Icons.calendar_month,
                          onTap: () => _setQuickDate('month')),
                      _QuickDateChip(
                          label: 'هذا الربع',
                          icon: Icons.calendar_view_month,
                          onTap: () => _setQuickDate('quarter')),
                      _QuickDateChip(
                          label: 'هذا العام',
                          icon: Icons.calendar_today,
                          onTap: () => _setQuickDate('year')),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Custom Date Selection Section
                Text(
                  'اختيار مخصص للتواريخ',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(AppConstants.primaryColor),
                      ),
                ),

                const SizedBox(height: 4),

                Text(
                  'حدد تاريخ البداية والنهاية يدوياً',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),

                const SizedBox(height: 16),

                // Date selection cards
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 6,
                        spreadRadius: 1,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // From Date
                      InkWell(
                        onTap: _selectFromDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(AppConstants.accentColor)
                                  .withOpacity(0.2),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: const Color(AppConstants.accentColor)
                                .withOpacity(0.02),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(AppConstants.accentColor),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.event,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'تاريخ البداية',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _fromDate != null
                                          ? _displayDateFormat
                                              .format(_fromDate!)
                                          : 'اختر تاريخ البداية',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(AppConstants.primaryColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Color(AppConstants.accentColor),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // To Date
                      InkWell(
                        onTap: _selectToDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(AppConstants.primaryColor)
                                  .withOpacity(0.2),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: const Color(AppConstants.primaryColor)
                                .withOpacity(0.02),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(AppConstants.primaryColor),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.event_available,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'تاريخ النهاية',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _toDate != null
                                          ? _displayDateFormat.format(_toDate!)
                                          : 'اختر تاريخ النهاية',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(AppConstants.primaryColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Color(AppConstants.primaryColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Enhanced Proceed Button
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: (_fromDate != null && _toDate != null)
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
                    onPressed: (_fromDate != null && _toDate != null)
                        ? _proceed
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.analytics,
                            size: 20, color: Colors.white),
                        const SizedBox(width: 8),
                        const Text(
                          'عرض كشف الحساب',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickDateChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickDateChip({
    required this.label,
    required this.icon,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(AppConstants.accentColor).withOpacity(0.1),
                const Color(AppConstants.accentColor).withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: const Color(AppConstants.accentColor).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: const Color(AppConstants.accentColor),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Color(AppConstants.accentColor),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
