// lib/screens/web/web_account_statements_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../models/user.dart';
import '../../models/contact.dart';
import '../../models/account_statement.dart';
import '../../services/api_service.dart';
import '../../services/pdf_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../utils/arabic_text_helper.dart';
import 'web_statement_detail_screen.dart';
import 'web_login_screen.dart';
import 'dart:ui' as ui;

class WebAccountStatementsScreen extends StatefulWidget {
  final AppUser user;
  final Contact contact;
  final String fromDate;
  final String toDate;

  const WebAccountStatementsScreen({
    super.key,
    required this.user,
    required this.contact,
    required this.fromDate,
    required this.toDate,
  });

  @override
  State<WebAccountStatementsScreen> createState() =>
      _WebAccountStatementsScreenState();
}

class _WebAccountStatementsScreenState
    extends State<WebAccountStatementsScreen> {
  List<AccountStatement> _statements = [];
  bool _isLoading = true;
  bool _isGeneratingPdf = false;
  bool _isCardView = false;

  // Controllers for horizontal scrolling (header and data)
  final ScrollController _horizontalHeaderController = ScrollController();
  final ScrollController _horizontalDataController = ScrollController();
  final ScrollController _screenVerticalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadStatements();

    // Attach listeners to synchronize horizontal scrolling between header and data
    _horizontalHeaderController.addListener(() {
      if (_horizontalHeaderController.offset !=
          _horizontalDataController.offset) {
        _horizontalDataController.jumpTo(_horizontalHeaderController.offset);
      }
    });

    _horizontalDataController.addListener(() {
      if (_horizontalDataController.offset !=
          _horizontalHeaderController.offset) {
        _horizontalHeaderController.jumpTo(_horizontalDataController.offset);
      }
    });
  }

  @override
  void dispose() {
    _horizontalHeaderController.dispose();
    _horizontalDataController.dispose();
    _screenVerticalController.dispose();
    super.dispose();
  }

  Future<void> _loadStatements() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final statements = await ApiService.getAccountStatements(
        contactCode: widget.contact.code,
        fromDate: widget.fromDate,
        toDate: widget.toDate,
      );

      setState(() {
        _statements = statements;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'فشل في تحميل كشف الحساب: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  Future<void> _generatePdf() async {
    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      final pdfBytes = await PdfService.generateAccountStatementPdf(
        contact: widget.contact,
        statements: _statements,
        fromDate: widget.fromDate,
        toDate: widget.toDate,
      );

      setState(() {
        _isGeneratingPdf = false;
      });

      // Show PDF action dialog
      if (mounted) {
        _showPdfActionDialog(pdfBytes);
      }
    } catch (e) {
      setState(() {
        _isGeneratingPdf = false;
      });
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'فشل في إنشاء ملف PDF: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  void _showPdfActionDialog(Uint8List pdfBytes) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        const Color(AppConstants.primaryColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf,
                    color: Color(AppConstants.primaryColor),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'خيارات PDF',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(AppConstants.primaryColor),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPdfActionButton(
                  icon: Icons.print,
                  title: 'طباعة',
                  subtitle: 'طباعة كشف الحساب مباشرة',
                  color: const Color(AppConstants.accentColor),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await Printing.layoutPdf(
                      onLayout: (format) async => pdfBytes,
                      name:
                          'كشف_حساب_${widget.contact.code}_${widget.fromDate}_${widget.toDate}.pdf',
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildPdfActionButton(
                  icon: Icons.download,
                  title: 'تحميل',
                  subtitle: 'حفظ الملف في الجهاز',
                  color: Colors.green,
                  onTap: () async {
                    Navigator.of(context).pop();
                    await Printing.sharePdf(
                      bytes: pdfBytes,
                      filename:
                          'كشف_حساب_${widget.contact.code}_${widget.fromDate}_${widget.toDate}.pdf',
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildPdfActionButton(
                  icon: Icons.share,
                  title: 'مشاركة',
                  subtitle: 'مشاركة الملف مع التطبيقات الأخرى',
                  color: const Color(AppConstants.primaryColor),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await Printing.sharePdf(
                      bytes: pdfBytes,
                      filename:
                          'كشف_حساب_${widget.contact.code}_${widget.fromDate}_${widget.toDate}.pdf',
                    );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPdfActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(AppConstants.primaryColor),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_back_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  void _viewStatementDetail(AccountStatement statement) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WebStatementDetailScreen(
          user: widget.user,
          contact: widget.contact,
          statement: statement,
          fromDate: widget.fromDate, // Convert String to DateTime
          toDate: widget.toDate, // Convert String to DateTime
        ),
      ),
    );
  }

  Color _getDocumentTypeColor(String documentType) {
    switch (documentType) {
      case 'invoice':
        return const Color(AppConstants.primaryColor);
      case 'return':
        return const Color(AppConstants.accentColor);
      case 'payment':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getDocumentTypeIcon(String documentType) {
    switch (documentType) {
      case 'invoice':
        return Icons.receipt;
      case 'return':
        return Icons.undo;
      case 'payment':
        return Icons.payment;
      default:
        return Icons.description;
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
        appBar: _WebStatementsAppBar(
          user: widget.user,
          contact: widget.contact,
          statements: _statements,
          onLogout: _logout,
          greeting: _getGreetingMessage(),
          isGeneratingPdf: _isGeneratingPdf,
          onGeneratePdf: _statements.isNotEmpty ? _generatePdf : null,
          onRefresh: _loadStatements,
          isCardView: _isCardView,
          onViewModeChanged: (bool cardView) {
            setState(() {
              _isCardView = cardView;
            });
          },
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 1400 : double.infinity,
            ),
            child: Column(
              children: [
                // Enhanced Contact Info Header
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.all(isDesktop ? 24 : 16),
                  padding: EdgeInsets.all(isDesktop ? 20 : 15),
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
                        width: isDesktop ? 70 : 56,
                        height: isDesktop ? 70 : 56,
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
                              fontSize: isDesktop ? 28 : 22,
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
                              ArabicTextHelper.cleanText(widget.contact.nameAr),
                              style: TextStyle(
                                fontSize: isDesktop ? 18 : 15,
                                fontWeight: FontWeight.bold,
                                color: const Color(AppConstants.primaryColor),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: isDesktop ? 6 : 4),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isDesktop ? 8 : 6,
                                    vertical: isDesktop ? 4 : 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(AppConstants.accentColor)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '#',
                                    style: TextStyle(
                                      fontSize: isDesktop ? 12 : 10,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          const Color(AppConstants.accentColor),
                                    ),
                                  ),
                                ),
                                SizedBox(width: isDesktop ? 8 : 6),
                                Text(
                                  widget.contact.code,
                                  style: TextStyle(
                                    fontSize: isDesktop ? 15 : 13,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        const Color(AppConstants.accentColor),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isDesktop ? 8 : 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.date_range,
                                  size: isDesktop ? 16 : 14,
                                  color: Colors.grey[600],
                                ),
                                SizedBox(width: isDesktop ? 6 : 4),
                                Text(
                                  '${Helpers.formatDisplayDate(DateTime.parse(widget.fromDate))} - ${Helpers.formatDisplayDate(DateTime.parse(widget.toDate))}',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 14 : 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Statements count badge
                      if (_statements.isNotEmpty)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 16 : 12,
                            vertical: isDesktop ? 8 : 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(AppConstants.primaryColor)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(AppConstants.primaryColor)
                                  .withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${_statements.length}',
                                style: TextStyle(
                                  color: const Color(AppConstants.primaryColor),
                                  fontWeight: FontWeight.bold,
                                  fontSize: isDesktop ? 18 : 16,
                                ),
                              ),
                              Text(
                                'حركة',
                                style: TextStyle(
                                  color: const Color(AppConstants.primaryColor),
                                  fontWeight: FontWeight.w600,
                                  fontSize: isDesktop ? 12 : 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(isDesktop ? 32 : 24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 0),
                                    ),
                                  ],
                                ),
                                child: const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(AppConstants.accentColor)),
                                  strokeWidth: 3,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'جاري تحميل كشف الحساب...',
                                style: TextStyle(
                                  color: const Color(AppConstants.primaryColor),
                                  fontWeight: FontWeight.w500,
                                  fontSize: isDesktop ? 18 : 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _statements.isEmpty
                          ? Center(
                              child: Container(
                                padding: EdgeInsets.all(isDesktop ? 40 : 32),
                                margin: EdgeInsets.all(isDesktop ? 32 : 24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 0),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: isDesktop ? 100 : 80,
                                      color: Colors.grey[300],
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'لا توجد حركات في هذه الفترة',
                                      style: TextStyle(
                                        fontSize: isDesktop ? 24 : 20,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'لم يتم العثور على أي معاملات خلال الفترة المحددة',
                                      style: TextStyle(
                                        fontSize: isDesktop ? 16 : 14,
                                        color: Colors.grey[500],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton(
                                      onPressed: _loadStatements,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                            AppConstants.accentColor),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isDesktop ? 32 : 24,
                                          vertical: isDesktop ? 16 : 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(25),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        'إعادة التحميل',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: isDesktop ? 16 : 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : _isCardView
                              ? _buildEnhancedCardView(isDesktop)
                              : _buildStatementsTable(isDesktop),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedCardView(bool isDesktop) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16),
      child: ListView.builder(
        itemCount: _statements.length,
        itemBuilder: (context, index) {
          final statement = _statements[index];
          return Container(
            margin: EdgeInsets.only(bottom: isDesktop ? 16 : 12),
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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: statement.documentType == 'other'
                    ? null
                    : () => _viewStatementDetail(statement),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: EdgeInsets.all(isDesktop ? 24 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row with document type and date
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 14 : 12,
                              vertical: isDesktop ? 8 : 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  _getDocumentTypeColor(statement.documentType),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _getDocumentTypeColor(
                                          statement.documentType)
                                      .withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getDocumentTypeIcon(statement.documentType),
                                  color: Colors.white,
                                  size: isDesktop ? 16 : 14,
                                ),
                                SizedBox(width: isDesktop ? 8 : 6),
                                Text(
                                  Helpers.getDocumentTypeInArabic(
                                      statement.documentType),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isDesktop ? 14 : 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 12 : 10,
                              vertical: isDesktop ? 8 : 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: isDesktop ? 14 : 12,
                                  color: Colors.grey[600],
                                ),
                                SizedBox(width: isDesktop ? 6 : 4),
                                Text(
                                  statement.docDate,
                                  style: TextStyle(
                                    fontSize: isDesktop ? 14 : 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: isDesktop ? 20 : 16),

                      // Document name/description
                      Text(
                        ArabicTextHelper.cleanText(statement.displayName),
                        style: TextStyle(
                          fontSize: isDesktop ? 18 : 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(AppConstants.primaryColor),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      SizedBox(height: isDesktop ? 20 : 16),

                      // Financial data in enhanced layout
                      Container(
                        padding: EdgeInsets.all(isDesktop ? 20 : 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[25],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Debit
                            Expanded(
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.trending_up,
                                        size: isDesktop ? 18 : 16,
                                        color: Colors.red[600],
                                      ),
                                      SizedBox(width: isDesktop ? 6 : 4),
                                      Text(
                                        'مدين',
                                        style: TextStyle(
                                          fontSize: isDesktop ? 14 : 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: isDesktop ? 8 : 6),
                                  Text(
                                    Helpers.formatNumber(statement.debit),
                                    style: TextStyle(
                                      fontSize: isDesktop ? 18 : 16,
                                      fontWeight: FontWeight.bold,
                                      color: statement.debit.isNotEmpty
                                          ? Colors.red[600]
                                          : Colors.grey[400],
                                    ),
                                    textDirection: ui.TextDirection.ltr,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),

                            // Divider
                            Container(
                              width: 1,
                              height: isDesktop ? 50 : 40,
                              color: Colors.grey[300],
                            ),

                            // Credit
                            Expanded(
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.trending_down,
                                        size: isDesktop ? 18 : 16,
                                        color: Colors.green[600],
                                      ),
                                      SizedBox(width: isDesktop ? 6 : 4),
                                      Text(
                                        'دائن',
                                        style: TextStyle(
                                          fontSize: isDesktop ? 14 : 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: isDesktop ? 8 : 6),
                                  Text(
                                    Helpers.formatNumber(statement.credit),
                                    style: TextStyle(
                                      fontSize: isDesktop ? 18 : 16,
                                      fontWeight: FontWeight.bold,
                                      color: statement.credit.isNotEmpty
                                          ? Colors.green[600]
                                          : Colors.grey[400],
                                    ),
                                    textDirection: ui.TextDirection.ltr,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),

                            // Divider
                            Container(
                              width: 1,
                              height: isDesktop ? 50 : 40,
                              color: Colors.grey[300],
                            ),

                            // Balance
                            Expanded(
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.account_balance_wallet,
                                        size: isDesktop ? 18 : 16,
                                        color: const Color(
                                            AppConstants.accentColor),
                                      ),
                                      SizedBox(width: isDesktop ? 6 : 4),
                                      Text(
                                        'الرصيد',
                                        style: TextStyle(
                                          fontSize: isDesktop ? 14 : 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(
                                              AppConstants.accentColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: isDesktop ? 8 : 6),
                                  Text(
                                    Helpers.formatNumber(
                                        statement.runningBalance),
                                    style: TextStyle(
                                      fontSize: isDesktop ? 18 : 16,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          const Color(AppConstants.accentColor),
                                    ),
                                    textDirection: ui.TextDirection.ltr,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Comment section if exists
                      if (statement.docComment.isNotEmpty) ...[
                        SizedBox(height: isDesktop ? 20 : 16),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(isDesktop ? 16 : 12),
                          decoration: BoxDecoration(
                            color: Colors.blue[25],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue[200]!,
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.comment,
                                size: isDesktop ? 18 : 16,
                                color: Colors.blue[600],
                              ),
                              SizedBox(width: isDesktop ? 10 : 8),
                              Expanded(
                                child: Text(
                                  ArabicTextHelper.cleanText(
                                      statement.docComment),
                                  style: TextStyle(
                                    fontSize: isDesktop ? 15 : 13,
                                    color: Colors.blue[700],
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Action indicator
                      if (statement.documentType != 'other') ...[
                        SizedBox(height: isDesktop ? 16 : 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 14 : 12,
                                vertical: isDesktop ? 8 : 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(AppConstants.primaryColor)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'عرض التفاصيل',
                                    style: TextStyle(
                                      fontSize: isDesktop ? 14 : 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(
                                          AppConstants.primaryColor),
                                    ),
                                  ),
                                  SizedBox(width: isDesktop ? 6 : 4),
                                  Icon(
                                    Icons.arrow_back_ios,
                                    size: isDesktop ? 14 : 12,
                                    color:
                                        const Color(AppConstants.primaryColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatementsTable(bool isDesktop) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fixedColumnWidth = screenWidth * 0.5;
    final scrollableColumnContentWidth =
        screenWidth > 520 ? screenWidth * 0.5 : 240.0;

    return Center(
      child: Container(
        margin: EdgeInsets.all(isDesktop ? 16 : 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              // Fixed Header Row
              SizedBox(
                height: isDesktop ? 48 : 40,
                child: Row(
                  children: [
                    // Fixed header columns (Date, Document)
                    Container(
                      width: fixedColumnWidth,
                      decoration: BoxDecoration(
                        color: const Color(AppConstants.primaryColor),
                        border: Border(
                          top:
                              BorderSide(color: Colors.grey.shade200, width: 1),
                          left: BorderSide(
                              color: const Color(AppConstants.primaryColor),
                              width: 2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text(
                                'التاريخ',
                                style: TextStyle(
                                  fontSize: isDesktop ? 14 : 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Center(
                              child: Text(
                                'المستند',
                                style: TextStyle(
                                  fontSize: isDesktop ? 14 : 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Scrollable header columns (Debit, Credit, Balance)
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        controller: _horizontalHeaderController,
                        child: Container(
                          width: scrollableColumnContentWidth,
                          decoration: BoxDecoration(
                            color: const Color(AppConstants.primaryColor),
                            border: Border(
                              top: BorderSide(
                                  color: Colors.grey.shade200, width: 1),
                              right: BorderSide(
                                  color: Colors.grey.shade200, width: 1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'مدين',
                                    style: TextStyle(
                                      fontSize: isDesktop ? 14 : 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'دائن',
                                    style: TextStyle(
                                      fontSize: isDesktop ? 14 : 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'الرصيد',
                                    style: TextStyle(
                                      fontSize: isDesktop ? 14 : 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Scrollable Data Rows Container
              Expanded(
                child: SingleChildScrollView(
                  controller: _screenVerticalController,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Fixed Column Data
                      SizedBox(
                        width: fixedColumnWidth,
                        child: Column(
                          children: [
                            for (int index = 0;
                                index < _statements.length;
                                index++)
                              _buildFixedRowPart(
                                  _statements[index], index, isDesktop),
                          ],
                        ),
                      ),
                      // Right Scrollable Columns Data
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: _horizontalDataController,
                          child: SizedBox(
                            width: scrollableColumnContentWidth,
                            child: Column(
                              children: [
                                for (int index = 0;
                                    index < _statements.length;
                                    index++)
                                  _buildScrollableRowPart(
                                      _statements[index], index, isDesktop),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFixedRowPart(
      AccountStatement statement, int index, bool isDesktop) {
    return InkWell(
      onTap: statement.documentType == 'other'
          ? null
          : () => _viewStatementDetail(statement),
      child: Container(
        height: isDesktop ? 60 : 52,
        decoration: BoxDecoration(
          color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
            left: BorderSide(
                color: const Color(AppConstants.primaryColor), width: 2),
          ),
        ),
        child: Row(
          children: [
            // Date column
            Expanded(
              flex: 2,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 6 : 4),
                child: Center(
                  child: Text(
                    statement.docDate,
                    style: TextStyle(
                      fontSize: isDesktop ? 12 : 10,
                      fontWeight: FontWeight.w500,
                      color: const Color(AppConstants.primaryColor),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            // Document column
            Expanded(
              flex: 4,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 8 : 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 8 : 6,
                            vertical: isDesktop ? 4 : 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _getDocumentTypeColor(statement.documentType),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            Helpers.getDocumentTypeInArabic(
                                statement.documentType),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isDesktop ? 11 : 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: isDesktop ? 6 : 4),
                        if (statement.documentType != 'other')
                          Icon(
                            Icons.arrow_back_ios,
                            size: isDesktop ? 12 : 10,
                            color: Colors.grey,
                          ),
                      ],
                    ),
                    SizedBox(height: isDesktop ? 4 : 2),
                    Text(
                      ArabicTextHelper.cleanText(statement.docNumber),
                      style: TextStyle(
                        fontSize: isDesktop ? 12 : 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(AppConstants.primaryColor),
                      ),
                      maxLines: 2,
                      textDirection: ui.TextDirection.ltr,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableRowPart(
      AccountStatement statement, int index, bool isDesktop) {
    final debitColor =
        statement.debit.isNotEmpty ? Colors.red.shade600 : Colors.grey.shade400;
    final creditColor = statement.credit.isNotEmpty
        ? Colors.green.shade600
        : Colors.grey.shade400;
    final balanceColor = const Color(AppConstants.accentColor);

    return InkWell(
      onTap: statement.documentType == 'other'
          ? null
          : () => _viewStatementDetail(statement),
      child: Container(
        height: isDesktop ? 60 : 52,
        decoration: BoxDecoration(
          color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Debit column
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 6 : 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'مدين',
                      style: TextStyle(
                        fontSize: isDesktop ? 10 : 8,
                        color: debitColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: isDesktop ? 4 : 2),
                    Text(
                      Helpers.formatNumber(statement.debit),
                      style: TextStyle(
                        fontSize: isDesktop ? 13 : 11,
                        fontWeight: FontWeight.bold,
                        color: debitColor,
                      ),
                      textDirection: ui.TextDirection.ltr,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            // Credit column
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 6 : 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'دائن',
                      style: TextStyle(
                        fontSize: isDesktop ? 10 : 8,
                        color: creditColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: isDesktop ? 4 : 2),
                    Text(
                      Helpers.formatNumber(statement.credit),
                      style: TextStyle(
                        fontSize: isDesktop ? 13 : 11,
                        fontWeight: FontWeight.bold,
                        color: creditColor,
                      ),
                      textDirection: ui.TextDirection.ltr,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            // Balance column
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 6 : 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'الرصيد',
                      style: TextStyle(
                        fontSize: isDesktop ? 10 : 8,
                        color: balanceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: isDesktop ? 4 : 2),
                    Text(
                      Helpers.formatNumber(statement.runningBalance),
                      style: TextStyle(
                        fontSize: isDesktop ? 13 : 11,
                        fontWeight: FontWeight.bold,
                        color: balanceColor,
                      ),
                      textDirection: ui.TextDirection.ltr,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WebStatementsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final AppUser user;
  final Contact contact;
  final List<AccountStatement> statements;
  final VoidCallback onLogout;
  final String greeting;
  final bool isGeneratingPdf;
  final VoidCallback? onGeneratePdf;
  final VoidCallback onRefresh;
  final bool isCardView;
  final ValueChanged<bool> onViewModeChanged;

  const _WebStatementsAppBar({
    required this.user,
    required this.contact,
    required this.statements,
    required this.onLogout,
    required this.greeting,
    required this.isGeneratingPdf,
    required this.onGeneratePdf,
    required this.onRefresh,
    required this.isCardView,
    required this.onViewModeChanged,
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
          // View toggle button
          if (statements.isNotEmpty)
            Container(
              margin: EdgeInsets.only(left: isDesktop ? 12 : 8),
              child: ToggleButtons(
                isSelected: [!isCardView, isCardView],
                onPressed: (int index) {
                  onViewModeChanged(index == 1);
                },
                borderRadius: BorderRadius.circular(8),
                selectedBorderColor: const Color(AppConstants.accentColor),
                selectedColor: Colors.white,
                fillColor: const Color(AppConstants.accentColor),
                borderColor: Colors.white54,
                color: Colors.white,
                constraints: BoxConstraints(
                  minHeight: isDesktop ? 40 : 36,
                  minWidth: isDesktop ? 40 : 36,
                ),
                children: const [
                  Icon(Icons.table_rows, size: 18),
                  Icon(Icons.view_agenda, size: 18),
                ],
              ),
            ),

          // PDF button
          if (statements.isNotEmpty)
            IconButton(
              icon: isGeneratingPdf
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf),
              onPressed: isGeneratingPdf ? null : onGeneratePdf,
              tooltip: 'إنشاء PDF',
            ),

          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: onRefresh,
            tooltip: 'تحديث',
          ),

          // Logout menu
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
