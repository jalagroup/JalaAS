// lib/screens/web/web_statement_detail_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../models/user.dart';
import '../../models/contact.dart';
import '../../models/account_statement.dart';
import '../../models/account_statement.dart' as models;
import '../../services/api_service.dart';
import '../../services/pdf_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../utils/arabic_text_helper.dart';
import 'web_login_screen.dart';
import 'dart:ui' as ui;

class WebStatementDetailScreen extends StatefulWidget {
  final AppUser user;
  final Contact contact;
  final AccountStatement statement;
  final String fromDate;
  final String toDate;

  const WebStatementDetailScreen({
    super.key,
    required this.user,
    required this.contact,
    required this.statement,
    required this.fromDate,
    required this.toDate,
  });

  @override
  State<WebStatementDetailScreen> createState() =>
      _WebStatementDetailScreenState();
}

class _WebStatementDetailScreenState extends State<WebStatementDetailScreen> {
  List<models.AccountStatementDetail> _details = [];
  bool _isLoading = true;
  bool _isGeneratingPdf = false;

  // Controllers for invoice table scrolling
  final ScrollController _invoiceHorizontalHeaderController =
      ScrollController();
  final ScrollController _invoiceHorizontalDataController = ScrollController();
  final ScrollController _invoiceVerticalController = ScrollController();

  // Controllers for payment table scrolling
  final ScrollController _paymentHorizontalHeaderController =
      ScrollController();
  final ScrollController _paymentHorizontalDataController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _setupScrollControllers();
  }

  void _setupScrollControllers() {
    // Synchronize invoice table horizontal scrolling
    _invoiceHorizontalHeaderController.addListener(() {
      if (_invoiceHorizontalHeaderController.offset !=
          _invoiceHorizontalDataController.offset) {
        _invoiceHorizontalDataController
            .jumpTo(_invoiceHorizontalHeaderController.offset);
      }
    });

    _invoiceHorizontalDataController.addListener(() {
      if (_invoiceHorizontalDataController.offset !=
          _invoiceHorizontalHeaderController.offset) {
        _invoiceHorizontalHeaderController
            .jumpTo(_invoiceHorizontalDataController.offset);
      }
    });

    // Synchronize payment table horizontal scrolling
    _paymentHorizontalHeaderController.addListener(() {
      if (_paymentHorizontalHeaderController.offset !=
          _paymentHorizontalDataController.offset) {
        _paymentHorizontalDataController
            .jumpTo(_paymentHorizontalHeaderController.offset);
      }
    });

    _paymentHorizontalDataController.addListener(() {
      if (_paymentHorizontalDataController.offset !=
          _paymentHorizontalHeaderController.offset) {
        _paymentHorizontalHeaderController
            .jumpTo(_paymentHorizontalDataController.offset);
      }
    });
  }

  @override
  void dispose() {
    _invoiceHorizontalHeaderController.dispose();
    _invoiceHorizontalDataController.dispose();
    _invoiceVerticalController.dispose();
    _paymentHorizontalHeaderController.dispose();
    _paymentHorizontalDataController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final details = await ApiService.getAccountStatementDetails(
        contactCode: widget.contact.code,
        fromDate: widget.fromDate,
        toDate: widget.toDate,
      );

      final filteredDetails = details.where((detail) {
        return ArabicTextHelper.cleanText(detail.shownParent) ==
            ArabicTextHelper.cleanText(widget.statement.shownParent);
      }).toList();

      setState(() {
        _details = filteredDetails;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'فشل في تحميل تفاصيل المستند: ${e.toString()}',
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
      final pdfBytes = await PdfService.generateInvoiceDetailPdf(
        contact: widget.contact,
        details: _details,
        documentTitle: ArabicTextHelper.cleanText(widget.statement.displayName),
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
    final String safeFilename = _createSafeFilename(
        '${widget.statement.documentType}_${widget.contact.code}_${DateTime.now().millisecondsSinceEpoch}');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
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
                  subtitle: 'طباعة المستند مباشرة',
                  color: const Color(AppConstants.accentColor),
                  onTap: () async {
                    Navigator.of(context).pop();
                    try {
                      await Printing.layoutPdf(
                        onLayout: (format) async => pdfBytes,
                        name: safeFilename,
                      );
                    } catch (e) {
                      if (mounted) {
                        Helpers.showSnackBar(
                          context,
                          'فشل في الطباعة: ${e.toString()}',
                          isError: true,
                        );
                      }
                    }
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
                    try {
                      await Printing.sharePdf(
                        bytes: pdfBytes,
                        filename: safeFilename,
                      );
                    } catch (e) {
                      if (mounted) {
                        Helpers.showSnackBar(
                          context,
                          'فشل في التحميل: ${e.toString()}',
                          isError: true,
                        );
                      }
                    }
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
                    try {
                      await Printing.sharePdf(
                        bytes: pdfBytes,
                        filename: safeFilename,
                      );
                      if (mounted) {
                        Helpers.showSnackBar(
                          context,
                          'تم تحضير الملف للمشاركة',
                          isError: false,
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        Helpers.showSnackBar(
                          context,
                          'فشل في المشاركة: ${e.toString()}',
                          isError: true,
                        );
                      }
                    }
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

  String _createSafeFilename(String originalName) {
    String safeName = originalName
        .replaceAll(RegExp(r'[^\w\s-_.]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll(':', '_')
        .replaceAll('*', '_')
        .replaceAll('?', '_')
        .replaceAll('"', '_')
        .replaceAll('<', '_')
        .replaceAll('>', '_')
        .replaceAll('|', '_');

    if (!safeName.toLowerCase().endsWith('.pdf')) {
      safeName += '.pdf';
    }

    if (safeName.length > 100) {
      safeName = safeName.substring(0, 96) + '.pdf';
    }

    return safeName;
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
        textDirection: TextDirection.rtl,
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
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _WebDetailAppBar(
          user: widget.user,
          contact: widget.contact,
          statement: widget.statement,
          onLogout: _logout,
          greeting: _getGreetingMessage(),
          isGeneratingPdf: _isGeneratingPdf,
          onGeneratePdf: _details.isNotEmpty ? _generatePdf : null,
          onRefresh: _loadDetails,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 1400 : double.infinity,
            ),
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
                          'جاري تحميل تفاصيل المستند...',
                          style: TextStyle(
                            color: const Color(AppConstants.primaryColor),
                            fontWeight: FontWeight.w500,
                            fontSize: isDesktop ? 18 : 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : _details.isEmpty
                    ? _buildEmptyState(isDesktop)
                    : Column(
                        children: [
                          _buildEnhancedDocumentHeader(isDesktop),
                          Expanded(
                            child: widget.statement.documentType == 'payment'
                                ? _buildPaymentDetails(isDesktop)
                                : _buildInvoiceDetails(isDesktop),
                          ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDesktop) {
    return Center(
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
              Icons.description_outlined,
              size: isDesktop ? 80 : 60,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 20),
            Text(
              'لا توجد تفاصيل لهذا المستند',
              style: TextStyle(
                fontSize: isDesktop ? 20 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لم يتم العثور على أي تفاصيل لهذا المستند',
              style: TextStyle(
                fontSize: isDesktop ? 16 : 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppConstants.accentColor),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 24,
                  vertical: isDesktop ? 16 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 0,
              ),
              child: Text(
                'إعادة المحاولة',
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
    );
  }

  Widget _buildEnhancedDocumentHeader(bool isDesktop) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(isDesktop ? 20 : 13),
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
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
          // Document Icon
          Container(
            width: isDesktop ? 70 : 56,
            height: isDesktop ? 70 : 56,
            decoration: BoxDecoration(
              color: _getDocumentTypeColor(widget.statement.documentType),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _getDocumentTypeColor(widget.statement.documentType)
                      .withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                _getDocumentTypeIcon(widget.statement.documentType),
                color: Colors.white,
                size: isDesktop ? 32 : 24,
              ),
            ),
          ),

          SizedBox(width: isDesktop ? 20 : 16),

          // Document Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ArabicTextHelper.cleanText(widget.statement.displayName),
                  style: TextStyle(
                    fontSize: isDesktop ? 20 : 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(AppConstants.primaryColor),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isDesktop ? 8 : 6),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 10 : 8,
                        vertical: isDesktop ? 6 : 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            _getDocumentTypeColor(widget.statement.documentType)
                                .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        Helpers.getDocumentTypeInArabic(
                            widget.statement.documentType),
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          color: _getDocumentTypeColor(
                              widget.statement.documentType),
                        ),
                        textDirection: ui.TextDirection.ltr,
                      ),
                    ),
                    SizedBox(width: isDesktop ? 10 : 8),
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
                          color: const Color(AppConstants.accentColor),
                        ),
                      ),
                    ),
                    SizedBox(width: isDesktop ? 6 : 4),
                    Text(
                      widget.statement.documentNumber ?? 'غير محدد',
                      style: TextStyle(
                        fontSize: isDesktop ? 16 : 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(AppConstants.accentColor),
                      ),
                      textDirection: ui.TextDirection.ltr,
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
                      widget.statement.docDate,
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

          // Details count badge
          if (_details.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 16 : 12,
                vertical: isDesktop ? 8 : 6,
              ),
              decoration: BoxDecoration(
                color: const Color(AppConstants.primaryColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      const Color(AppConstants.primaryColor).withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '${_details.length}',
                    style: TextStyle(
                      color: const Color(AppConstants.primaryColor),
                      fontWeight: FontWeight.bold,
                      fontSize: isDesktop ? 18 : 16,
                    ),
                  ),
                  Text(
                    'تفصيل',
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
    );
  }

  Widget _buildPaymentDetails(bool isDesktop) {
    if (_details.isEmpty) return const SizedBox();

    final detail = _details.first;
    final screenWidth = MediaQuery.of(context).size.width;
    final fixedColumnWidth = screenWidth * 0.4;
    final scrollableColumnContentWidth =
        screenWidth > 520 ? screenWidth * 0.6 : 320.0;

    return Center(
      child: Container(
        margin: EdgeInsets.all(isDesktop ? 24 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // Header section
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 20 : 16,
                  vertical: isDesktop ? 12 : 10,
                ),
                decoration: const BoxDecoration(
                  color: Color(AppConstants.primaryColor),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.payment,
                      color: Colors.white,
                      size: isDesktop ? 20 : 18,
                    ),
                    SizedBox(width: isDesktop ? 10 : 8),
                    Text(
                      'تفاصيل القبض',
                      style: TextStyle(
                        fontSize: isDesktop ? 16 : 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Table Header
              SizedBox(
                height: isDesktop ? 44 : 36,
                child: Row(
                  children: [
                    // Fixed header columns
                    Container(
                      width: fixedColumnWidth,
                      decoration: BoxDecoration(
                        color: const Color(AppConstants.lightPrimary),
                        border: Border(
                          left: BorderSide(
                            color: const Color(AppConstants.primaryColor),
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: Text(
                                'طريقة الدفع',
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
                                'رقم الشيك',
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
                    // Scrollable header columns
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        controller: _paymentHorizontalHeaderController,
                        child: Container(
                          width: scrollableColumnContentWidth,
                          decoration: const BoxDecoration(
                            color: Color(AppConstants.lightPrimary),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'تاريخ الاستحقاق',
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
                                    'القيمة',
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
              // Data Row
              SizedBox(
                height: isDesktop ? 50 : 44,
                child: Row(
                  children: [
                    // Fixed data columns
                    Container(
                      width: fixedColumnWidth,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          left: BorderSide(
                            color: const Color(AppConstants.primaryColor),
                            width: 2,
                          ),
                          bottom: BorderSide(
                            color: Colors.grey.shade300,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: Text(
                                detail.check.isEmpty ? 'كاش' : 'شيك',
                                style: TextStyle(
                                  fontSize: isDesktop ? 14 : 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(AppConstants.primaryColor),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                detail.check.isEmpty ? '-' : detail.checkNumber,
                                style: TextStyle(
                                  fontSize: isDesktop ? 14 : 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Scrollable data columns
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        controller: _paymentHorizontalDataController,
                        child: Container(
                          width: scrollableColumnContentWidth,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.shade300,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Center(
                                  child: Text(
                                    detail.check.isEmpty
                                        ? '-'
                                        : detail.checkDueDate,
                                    style: TextStyle(
                                      fontSize: isDesktop ? 14 : 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    Helpers.formatNumber(detail.credit),
                                    style: TextStyle(
                                      fontSize: isDesktop ? 16 : 14,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          const Color(AppConstants.accentColor),
                                    ),
                                    textDirection: ui.TextDirection.ltr,
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
              // Comment section if exists
              if (_details.isNotEmpty &&
                  _details.first.docComment.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.all(isDesktop ? 20 : 16),
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
                          ArabicTextHelper.cleanText(_details.first.docComment),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceDetails(bool isDesktop) {
    final items = _details.where((d) => d.item.isNotEmpty).toList();
    if (items.isEmpty) return const SizedBox();

    final screenWidth = MediaQuery.of(context).size.width;
    final fixedColumnWidth = screenWidth * 0.45;
    final scrollableColumnContentWidth =
        screenWidth > 520 ? screenWidth * 0.55 : 320.0;

    return Center(
      child: Container(
        margin: EdgeInsets.all(isDesktop ? 24 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // Header section
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 20 : 16,
                  vertical: isDesktop ? 12 : 10,
                ),
                decoration: const BoxDecoration(
                  color: Color(AppConstants.primaryColor),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory,
                      color: Colors.white,
                      size: isDesktop ? 20 : 18,
                    ),
                    SizedBox(width: isDesktop ? 10 : 8),
                    Text(
                      'الأصناف',
                      style: TextStyle(
                        fontSize: isDesktop ? 16 : 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 10 : 8,
                        vertical: isDesktop ? 4 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${items.length} صنف',
                        style: TextStyle(
                          fontSize: isDesktop ? 12 : 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Table Header
              SizedBox(
                height: isDesktop ? 44 : 36,
                child: Row(
                  children: [
                    // Fixed header columns
                    Container(
                      width: fixedColumnWidth,
                      decoration: BoxDecoration(
                        color: const Color(AppConstants.lightPrimary),
                        border: Border(
                          left: BorderSide(
                            color: const Color(AppConstants.primaryColor),
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text(
                                'رقم الصنف',
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
                                'اسم الصنف',
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
                    // Scrollable header columns
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        controller: _invoiceHorizontalHeaderController,
                        child: Container(
                          width: scrollableColumnContentWidth,
                          decoration: const BoxDecoration(
                            color: Color(AppConstants.lightPrimary),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'الكمية',
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
                                    'الوحدة',
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
                                    'السعر',
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
                                    'المبلغ',
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
                  controller: _invoiceVerticalController,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Fixed Column Data
                      SizedBox(
                        width: fixedColumnWidth,
                        child: Column(
                          children: [
                            for (int index = 0; index < items.length; index++)
                              _buildInvoiceFixedRowPart(
                                  items[index], index, isDesktop),
                          ],
                        ),
                      ),
                      // Right Scrollable Columns Data
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: _invoiceHorizontalDataController,
                          child: SizedBox(
                            width: scrollableColumnContentWidth,
                            child: Column(
                              children: [
                                for (int index = 0;
                                    index < items.length;
                                    index++)
                                  _buildInvoiceScrollableRowPart(
                                      items[index], index, isDesktop),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Totals Summary
              _buildTotalsSummary(items, isDesktop),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceFixedRowPart(
      models.AccountStatementDetail item, int index, bool isDesktop) {
    return Container(
      height: isDesktop ? 50 : 44,
      decoration: BoxDecoration(
        color: index % 2 == 0
            ? Colors.white
            : const Color(AppConstants.surfaceColor),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 0.5),
          left: BorderSide(
              color: const Color(AppConstants.primaryColor), width: 2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 6 : 4),
              child: Center(
                child: Text(
                  item.item,
                  style: TextStyle(
                    fontSize: isDesktop ? 13 : 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(AppConstants.primaryColor),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 8 : 6),
              child: Center(
                child: Text(
                  ArabicTextHelper.cleanText(item.name),
                  style: TextStyle(
                    fontSize: isDesktop ? 13 : 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(AppConstants.primaryColor),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceScrollableRowPart(
      models.AccountStatementDetail item, int index, bool isDesktop) {
    return Container(
      height: isDesktop ? 50 : 44,
      decoration: BoxDecoration(
        color: index % 2 == 0
            ? Colors.white
            : const Color(AppConstants.surfaceColor),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: Text(
                Helpers.formatNumber(item.quantity),
                style: TextStyle(
                  fontSize: isDesktop ? 13 : 11,
                  fontWeight: FontWeight.bold,
                ),
                textDirection: ui.TextDirection.ltr,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                item.unit,
                style: TextStyle(
                  fontSize: isDesktop ? 12 : 10,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                Helpers.formatNumber(item.price),
                style: TextStyle(
                  fontSize: isDesktop ? 13 : 11,
                ),
                textDirection: ui.TextDirection.ltr,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                Helpers.formatNumber(item.amount),
                style: TextStyle(
                  fontSize: isDesktop ? 13 : 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(AppConstants.accentColor),
                ),
                textDirection: ui.TextDirection.ltr,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsSummary(
      List<models.AccountStatementDetail> items, bool isDesktop) {
    double totalAmount = 0;
    double tax = 0;
    double discount = 0;

    for (final item in items) {
      totalAmount += Helpers.parseNumber(item.amount);
    }

    if (items.isNotEmpty) {
      for (final item in items) {
        if (item.tax.isNotEmpty) {
          tax = Helpers.parseNumber(item.tax);
        }
        if (item.docDiscount.isNotEmpty) {
          discount = Helpers.parseNumber(item.docDiscount);
        }
      }
    }

    final afterDiscount = totalAmount - discount;
    final netAmount = afterDiscount;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: BoxDecoration(
        color: const Color(AppConstants.surfaceColor),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildTotalRow('المجموع', totalAmount, isDesktop: isDesktop),
          if (tax > 0)
            _buildTotalRow('ضريبة ال 16%', tax, isDesktop: isDesktop),
          if (discount != 0)
            _buildTotalRow('الخصم', discount, isDesktop: isDesktop),
          if (discount != 0)
            _buildTotalRow('بعد الخصم', afterDiscount, isDesktop: isDesktop),
          Divider(height: isDesktop ? 12 : 8),
          _buildTotalRow('الصافي', netAmount,
              isNet: true, isDesktop: isDesktop),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount,
      {bool isNet = false, required bool isDesktop}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isDesktop ? 4 : 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Label moved to the left (first in the Row)
          Text(
            '$label:',
            style: TextStyle(
              fontSize: isNet ? (isDesktop ? 16 : 14) : (isDesktop ? 14 : 12),
              fontWeight: isNet ? FontWeight.bold : FontWeight.w600,
              color: isNet
                  ? const Color(AppConstants.primaryColor)
                  : Colors.black87,
            ),
          ),
          // Value moved to the right (second in the Row)
          Text(
            Helpers.formatNumber(amount.toString()),
            style: TextStyle(
              fontSize: isNet ? (isDesktop ? 16 : 14) : (isDesktop ? 14 : 12),
              fontWeight: isNet ? FontWeight.bold : FontWeight.w600,
              color: isNet
                  ? const Color(AppConstants.primaryColor)
                  : Colors.black87,
            ),
            textDirection: ui.TextDirection.ltr,
          ),
        ],
      ),
    );
  }

  double _roundToNearest(double amount) {
    final decimal = amount - amount.floor();
    if (decimal >= 0.5) {
      return amount.ceil().toDouble();
    } else {
      return amount.floor().toDouble();
    }
  }
}

class _WebDetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppUser user;
  final Contact contact;
  final AccountStatement statement;
  final VoidCallback onLogout;
  final String greeting;
  final bool isGeneratingPdf;
  final VoidCallback? onGeneratePdf;
  final VoidCallback onRefresh;

  const _WebDetailAppBar({
    required this.user,
    required this.contact,
    required this.statement,
    required this.onLogout,
    required this.greeting,
    required this.isGeneratingPdf,
    required this.onGeneratePdf,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Directionality(
      textDirection: TextDirection.rtl,
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

              // Document type badge
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 10 : 8,
                  vertical: isDesktop ? 6 : 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  Helpers.getDocumentTypeInArabic(statement.documentType),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isDesktop ? 12 : 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              SizedBox(width: isDesktop ? 12 : 8),

              // Title
              Expanded(
                child: Text(
                  isDesktop
                      ? 'تفاصيل - ${ArabicTextHelper.cleanText(contact.nameAr)}'
                      : 'تفاصيل المستند',
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
          // PDF button
          if (onGeneratePdf != null)
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
                    textDirection: TextDirection.rtl,
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
