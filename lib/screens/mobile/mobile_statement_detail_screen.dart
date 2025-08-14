// lib/screens/mobile/mobile_statement_detail_screen.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../models/contact.dart';
import '../../models/account_statement.dart';
import '../../models/account_statement.dart' as models;
import '../../services/api_service.dart';
import '../../services/pdf_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../utils/arabic_text_helper.dart';

class StatementDetailScreen extends StatefulWidget {
  final Contact contact;
  final AccountStatement statement;
  final String fromDate;
  final String toDate;

  const StatementDetailScreen({
    super.key,
    required this.contact,
    required this.statement,
    required this.fromDate,
    required this.toDate,
  });

  @override
  State<StatementDetailScreen> createState() => _StatementDetailScreenState();
}

class _StatementDetailScreenState extends State<StatementDetailScreen> {
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
    // Dispose all scroll controllers
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

      // Filter details for this specific statement
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

// FOR STATEMENT DETAIL SCREEN - Updated _generatePdf and dialog methods
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

// Updated PDF action dialog for statement detail screen
  void _showPdfActionDialog(Uint8List pdfBytes) {
    // Create safe filename
    final String safeFilename = _createSafeFilename(
        '${widget.statement.documentType}_${widget.contact.code}_${DateTime.now().millisecondsSinceEpoch}');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
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
                color: Colors.blue,
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
                color: Colors.orange,
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
              const SizedBox(height: 12),
              _buildPdfActionButton(
                icon: Icons.open_in_new,
                title: 'فتح',
                subtitle: 'فتح الملف في تطبيق PDF',
                color: Colors.purple,
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
                        'فشل في فتح الملف: ${e.toString()}',
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
        );
      },
    );
  }

// Helper method to create safe filenames (add to both screens)
  String _createSafeFilename(String originalName) {
    // Remove special characters and replace with safe alternatives
    String safeName = originalName
        .replaceAll(RegExp(r'[^\w\s-_.]'), '') // Remove special chars
        .replaceAll(RegExp(r'\s+'), '_') // Replace spaces with underscores
        .replaceAll('/', '_') // Replace slashes
        .replaceAll('\\', '_') // Replace backslashes
        .replaceAll(':', '_') // Replace colons
        .replaceAll('*', '_') // Replace asterisks
        .replaceAll('?', '_') // Replace question marks
        .replaceAll('"', '_') // Replace quotes
        .replaceAll('<', '_') // Replace less than
        .replaceAll('>', '_') // Replace greater than
        .replaceAll('|', '_'); // Replace pipes

    // Ensure it ends with .pdf
    if (!safeName.toLowerCase().endsWith('.pdf')) {
      safeName += '.pdf';
    }

    // Limit length to avoid filesystem issues
    if (safeName.length > 100) {
      safeName = safeName.substring(0, 96) + '.pdf';
    }

    return safeName;
  }

// Helper method to build PDF action buttons (same for both screens)
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
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

// Updated _buildContent method with enhanced document header
  Widget _buildContent() {
    final documentType = widget.statement.documentType;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced Document Header Card (similar to contact info style)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
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
                // Document Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _getDocumentTypeColor(widget.statement.documentType),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color:
                            _getDocumentTypeColor(widget.statement.documentType)
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
                      size: 24,
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Document Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ArabicTextHelper.cleanText(
                            widget.statement.displayName),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(AppConstants.primaryColor),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getDocumentTypeColor(
                                      widget.statement.documentType)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              Helpers.getDocumentTypeInArabic(
                                  widget.statement.documentType),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _getDocumentTypeColor(
                                    widget.statement.documentType),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(AppConstants.accentColor)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '#',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(AppConstants.accentColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.statement.documentNumber ?? 'غير محدد',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(AppConstants.accentColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.date_range,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.statement.docDate,
                            style: TextStyle(
                              fontSize: 12,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                          '${_details.length}',
                          style: const TextStyle(
                            color: Color(AppConstants.primaryColor),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'تفصيل',
                          style: TextStyle(
                            color: const Color(AppConstants.primaryColor),
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Document Comment if exists
          if (_details.isNotEmpty && _details.first.docComment.isNotEmpty) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[25],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue[200]!,
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.comment,
                    size: 20,
                    color: Colors.blue[600],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ملاحظة:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ArabicTextHelper.cleanText(_details.first.docComment),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[700],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Content based on document type
          if (documentType == 'payment')
            _buildPaymentDetails()
          else
            _buildInvoiceDetails(),
        ],
      ),
    );
  }

// Helper method to get document type color
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

// Helper method to get document type icon
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

// lib/screens/mobile/statement_detail_screen.dart - Updated build method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      appBar: AppBar(
        title: Text(ArabicTextHelper.cleanText(widget.contact.nameAr)),
        backgroundColor: const Color(AppConstants.primaryColor),
        foregroundColor: Colors.white,
        actions: [
          if (_details.isNotEmpty)
            IconButton(
              icon: _isGeneratingPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.picture_as_pdf, color: Colors.white),
              onPressed: _isGeneratingPdf ? null : _generatePdf,
              tooltip: 'إنشاء PDF',
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDetails,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    Color(AppConstants.primaryColor)),
              ),
            )
          : _details.isEmpty
              ? Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'لا توجد تفاصيل لهذا المستند',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : _buildContent(),
    );
  }

// Updated _buildPaymentDetails method with new colors and compact design
  Widget _buildPaymentDetails() {
    if (_details.isEmpty) return const SizedBox();

    final detail = _details.first;
    final screenWidth = MediaQuery.of(context).size.width;
    final fixedColumnWidth = screenWidth * 0.4;
    final scrollableColumnContentWidth =
        screenWidth > 520 ? screenWidth * 0.6 : 320.0;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Column(
            children: [
              // Header section
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(AppConstants.primaryColor),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.payment, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    const Text(
                      'تفاصيل القبض',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Table Header
              SizedBox(
                height: 32,
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
                              width: 2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: Text(
                                'طريقة الدفع',
                                style: TextStyle(
                                  fontSize:
                                      MediaQuery.of(context).size.width < 600
                                          ? 10
                                          : 11,
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
                                  fontSize:
                                      MediaQuery.of(context).size.width < 600
                                          ? 10
                                          : 11,
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
                                      fontSize:
                                          MediaQuery.of(context).size.width <
                                                  600
                                              ? 10
                                              : 11,
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
                                      fontSize:
                                          MediaQuery.of(context).size.width <
                                                  600
                                              ? 10
                                              : 11,
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
                height: 36,
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
                              width: 2),
                          bottom: BorderSide(
                              color: Colors.grey.shade300, width: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: Text(
                                detail.check.isEmpty ? 'كاش' : 'شيك',
                                style: TextStyle(
                                  fontSize:
                                      MediaQuery.of(context).size.width < 600
                                          ? 11
                                          : 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                detail.check.isEmpty ? '-' : detail.checkNumber,
                                style: TextStyle(
                                  fontSize:
                                      MediaQuery.of(context).size.width < 600
                                          ? 11
                                          : 12,
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
                                  color: Colors.grey.shade300, width: 0.5),
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
                                      fontSize:
                                          MediaQuery.of(context).size.width <
                                                  600
                                              ? 11
                                              : 12,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    Helpers.formatNumber(detail.credit),
                                    style: TextStyle(
                                      fontSize:
                                          MediaQuery.of(context).size.width <
                                                  600
                                              ? 12
                                              : 13,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(
                                          AppConstants.primaryColor),
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
            ],
          ),
        ),
      ),
    );
  }

// Updated _buildInvoiceDetails method with new colors and compact design
  Widget _buildInvoiceDetails() {
    final items = _details.where((d) => d.item.isNotEmpty).toList();
    if (items.isEmpty) return const SizedBox();

    final screenWidth = MediaQuery.of(context).size.width;
    final fixedColumnWidth = screenWidth * 0.45;
    final scrollableColumnContentWidth =
        screenWidth > 520 ? screenWidth * 0.55 : 320.0;

    // Calculate totals
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

    final afterDiscount = _roundToNearest(totalAmount);
    final netAmount = afterDiscount;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Column(
            children: [
              // Header section
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(AppConstants.primaryColor),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.inventory, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    const Text(
                      'الأصناف',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${items.length} صنف',
                        style: const TextStyle(
                          fontSize: 10,
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
                height: 32,
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
                              width: 2),
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
                                  fontSize:
                                      MediaQuery.of(context).size.width < 600
                                          ? 10
                                          : 11,
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
                                  fontSize:
                                      MediaQuery.of(context).size.width < 600
                                          ? 10
                                          : 11,
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
                                      fontSize:
                                          MediaQuery.of(context).size.width <
                                                  600
                                              ? 10
                                              : 11,
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
                                      fontSize:
                                          MediaQuery.of(context).size.width <
                                                  600
                                              ? 10
                                              : 11,
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
                                      fontSize:
                                          MediaQuery.of(context).size.width <
                                                  600
                                              ? 10
                                              : 11,
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
                                      fontSize:
                                          MediaQuery.of(context).size.width <
                                                  600
                                              ? 10
                                              : 11,
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
              SizedBox(
                height: 240, // Reduced height for better space utilization
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
                              _buildInvoiceFixedRowPart(items[index], index),
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
                                      items[index], index),
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(AppConstants.surfaceColor),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(8)),
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildTotalRow('المجموع', totalAmount),
                    if (tax > 0) _buildTotalRow('ضريبة ال 16%', tax),
                    if (discount != 0) _buildTotalRow('الخصم', discount),
                    if (discount != 0)
                      _buildTotalRow('بعد الخصم', afterDiscount),
                    const Divider(height: 8),
                    _buildTotalRow('الصافي', netAmount, isNet: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Updated _buildInvoiceFixedRowPart method with compact design
  Widget _buildInvoiceFixedRowPart(
      models.AccountStatementDetail item, int index) {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemCodeFontSize = screenWidth < 600 ? 10.0 : 11.0;
    final itemNameFontSize = screenWidth < 600 ? 10.0 : 11.0;

    return Container(
      height: 36,
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
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Center(
                child: Text(
                  item.item,
                  style: TextStyle(
                    fontSize: itemCodeFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Center(
                child: Text(
                  ArabicTextHelper.cleanText(item.name),
                  style: TextStyle(
                    fontSize: itemNameFontSize,
                    fontWeight: FontWeight.bold,
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

// Updated _buildInvoiceScrollableRowPart method with compact design
  Widget _buildInvoiceScrollableRowPart(
      models.AccountStatementDetail item, int index) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dataFontSize = screenWidth < 600 ? 10.0 : 11.0;
    final unitFontSize = screenWidth < 600 ? 9.0 : 10.0;

    return Container(
      height: 36,
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
                  fontSize: dataFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                item.unit,
                style: TextStyle(
                  fontSize: unitFontSize,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                Helpers.formatNumber(item.price),
                style: TextStyle(fontSize: dataFontSize),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                Helpers.formatNumber(item.amount),
                style: TextStyle(
                  fontSize: dataFontSize,
                  fontWeight: FontWeight.bold,
                  color: const Color(AppConstants.primaryColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

// Updated _buildTotalRow method with new colors
  Widget _buildTotalRow(String label, double amount, {bool isNet = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            Helpers.formatNumber(amount.toString()),
            style: TextStyle(
              fontSize: isNet ? 14 : 12,
              fontWeight: isNet ? FontWeight.bold : FontWeight.w600,
              color: isNet
                  ? const Color(AppConstants.primaryColor)
                  : Colors.black87,
            ),
          ),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: isNet ? 14 : 12,
              fontWeight: isNet ? FontWeight.bold : FontWeight.w600,
              color: isNet
                  ? const Color(AppConstants.primaryColor)
                  : Colors.black87,
            ),
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
