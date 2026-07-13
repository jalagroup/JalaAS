// lib/screens/web/web_statement_detail_screen.dart - Part 1 (Fixed)
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:jala_as/utils/platform_utils.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../models/user.dart';
import '../../../models/contact.dart';
import '../../../models/account_statement.dart';
import '../../../models/account_statement.dart' as models;
import '../../../services/api_service.dart';
import '../../../services/pdf_service.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';
import '../../../utils/arabic_text_helper.dart';
import '../web_login_screen.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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

class _WebStatementDetailScreenState extends State<WebStatementDetailScreen>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  List<models.AccountStatementDetail> _allDetails = [];
  List<models.AccountStatementDetail> _filteredDetails = [];
  bool _isLoading = true;
  bool _isGeneratingPdf = false;

  // Controllers for table scrolling
  final ScrollController _horizontalHeaderController = ScrollController();
  final ScrollController _horizontalDataController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _setupScrollControllers();
  }

  void _setupScrollControllers() {
    // Synchronize horizontal scrolling
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
    _searchController.dispose();
    _horizontalHeaderController.dispose();
    _horizontalDataController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  // FIXED: Enhanced number parsing to handle all formats properly
  double _parseNumericValue(String value) {
    if (value.isEmpty || value == '-' || value == '0' || value == '0.00')
      return 0.0;

    // Remove Arabic/Persian digits and replace with English
    String cleanValue = value
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .trim();

    // Remove currency symbols and extra spaces
    cleanValue = cleanValue
        .replaceAll('ر.س', '')
        .replaceAll('SAR', '')
        .replaceAll('SR', '')
        .replaceAll(RegExp(r'\s+'), '');

    // Handle different number formats
    if (cleanValue.contains('.') && cleanValue.contains(',')) {
      int lastDot = cleanValue.lastIndexOf('.');
      int lastComma = cleanValue.lastIndexOf(',');

      if (lastDot > lastComma) {
        // Format: 1,234.56 - comma is thousands separator
        cleanValue = cleanValue.replaceAll(',', '');
      } else {
        // Format: 1.234,56 - dot is thousands separator
        cleanValue = cleanValue.replaceAll('.', '').replaceAll(',', '.');
      }
    } else if (cleanValue.contains(',')) {
      List<String> parts = cleanValue.split(',');
      if (parts.length == 2 && parts[1].length <= 2) {
        // Decimal separator (e.g., "123,45")
        cleanValue = cleanValue.replaceAll(',', '.');
      } else {
        // Thousands separator (e.g., "1,234,567")
        cleanValue = cleanValue.replaceAll(',', '');
      }
    }

    // Final cleanup - remove any remaining non-numeric characters except dot and minus
    cleanValue = cleanValue.replaceAll(RegExp(r'[^\d.-]'), '');

    return double.tryParse(cleanValue) ?? 0.0;
  }

  // FIXED: Improved number formatting that shows full numbers
  String _formatNumber(double value) {
    if (value == 0.0) return '0.00';

    // Handle negative numbers
    bool isNegative = value < 0;
    double absValue = value.abs();

    // Use proper number formatting with full precision
    final formatter = NumberFormat('#,##0.00', 'en_US');
    String formatted = formatter.format(absValue);

    return isNegative ? '-$formatted' : formatted;
  }

  String _formatStringValue(String value) {
    if (value.isEmpty || value == '-') return '0.00';
    double numValue = _parseNumericValue(value);
    return _formatNumber(numValue);
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);

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

      if (mounted) {
        setState(() {
          _allDetails = filteredDetails;
          _filteredDetails = List.from(filteredDetails);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Helpers.showApiErrorDialog(context, e);
      }
    }
  }

  // FIXED: Add search functionality for items
  void _filterDetails(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredDetails = List.from(_allDetails);
      } else {
        _filteredDetails = _allDetails.where((detail) {
          final itemMatch =
              detail.item.toLowerCase().contains(query.toLowerCase());
          final nameMatch = ArabicTextHelper.cleanText(detail.name)
              .toLowerCase()
              .contains(query.toLowerCase());
          return itemMatch || nameMatch;
        }).toList();
      }
    });
  }

  void _showSnackBar(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _generatePdf() async {
    setState(() => _isGeneratingPdf = true);

    try {
      final pdfBytes = await PdfService.generateInvoiceDetailPdf(
        contact: widget.contact,
        details: _filteredDetails,
        documentTitle: ArabicTextHelper.cleanText(widget.statement.displayName),
      );

      if (mounted) {
        setState(() => _isGeneratingPdf = false);
        _showPdfActionDialog(pdfBytes);
      }
    } catch (e) {
      print('Error generating PDF: $e');
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
        _showSnackBar('فشل في إنشاء ملف PDF: ${e.toString()}', true);
      }
    }
  }

  void _showPdfActionDialog(Uint8List pdfBytes) {
    // Generate clean filename
    String filename = '${widget.statement.displayName}.pdf';
    filename = filename
        .replaceAll('/', '-')
        .replaceAll('\\', '-')
        .replaceAll(':', '-')
        .replaceAll('*', '-')
        .replaceAll('?', '-')
        .replaceAll('"', '-')
        .replaceAll('<', '-')
        .replaceAll('>', '-')
        .replaceAll('|', '-');

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
                        const Color(AppConstants.accentColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf,
                    color: Color(AppConstants.accentColor),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'خيارات PDF',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Print option
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
                        name: filename,
                      );
                    } catch (e) {
                      print('Error printing PDF: $e');
                      if (mounted) {
                        _showSnackBar(
                            'فشل في طباعة PDF: ${e.toString()}', true);
                      }
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Download/Save option
                _buildPdfActionButton(
                  icon: Icons.download,
                  title: PlatformUtils.isWeb ? 'تحميل' : 'حفظ',
                  subtitle: PlatformUtils.isWeb
                      ? 'تحميل الملف على جهازك'
                      : 'حفظ الملف في الجهاز',
                  color: Colors.green,
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _downloadPdf(pdfBytes, filename);
                  },
                ),
                const SizedBox(height: 12),

                // Share option (mobile only)
                if (PlatformUtils.isMobile)
                  _buildPdfActionButton(
                    icon: Icons.share,
                    title: 'مشاركة',
                    subtitle: 'مشاركة الملف مع التطبيقات الأخرى',
                    color: Colors.blue,
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _sharePdf(pdfBytes, filename);
                    },
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إلغاء'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Download PDF - FIXED
  Future<void> _downloadPdf(Uint8List pdfBytes, String filename) async {
    try {
      if (PlatformUtils.isWeb) {
        // Web download
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: filename,
        );
        if (mounted) {
          _showSnackBar('تم تحميل الملف', false);
        }
      } else {
        // Mobile save
        Directory directory;

        if (Platform.isAndroid) {
          // For Android, try Downloads directory
          directory = Directory('/storage/emulated/0/Download');

          // If Downloads doesn't exist, use app documents directory
          if (!await directory.exists()) {
            directory = await getApplicationDocumentsDirectory();
          }
        } else {
          // For iOS, use app documents directory
          directory = await getApplicationDocumentsDirectory();
        }

        final filePath = '${directory.path}/$filename';
        final file = File(filePath);

        await file.writeAsBytes(pdfBytes);

        print('PDF saved to: $filePath');
        if (mounted) {
          _showSnackBar('تم حفظ الملف في: ${directory.path}', false);
        }
      }
    } catch (e) {
      print('Error downloading PDF: $e');
      if (mounted) {
        _showSnackBar('فشل في حفظ الملف: ${e.toString()}', true);
      }
    }
  }

  /// Share PDF - FIXED
  Future<void> _sharePdf(Uint8List pdfBytes, String filename) async {
    if (!PlatformUtils.isMobile) {
      _showSnackBar('المشاركة متاحة فقط على الأجهزة المحمولة', true);
      return;
    }

    try {
      // Get temporary directory and create share subfolder
      final tempDir = await getTemporaryDirectory();
      final shareDir = Directory('${tempDir.path}/share');

      // Create directory if it doesn't exist
      if (!await shareDir.exists()) {
        await shareDir.create(recursive: true);
        print('Created share directory: ${shareDir.path}');
      }

      final filePath = '${shareDir.path}/$filename';
      final file = File(filePath);

      await file.writeAsBytes(pdfBytes);
      print('Created temp file for sharing: $filePath');

      // Share the file
      final result = await Share.shareXFiles(
        [XFile(filePath)],
        subject: widget.statement.displayName,
        text: 'مستند: ${widget.statement.displayName}',
      );

      print('Share result: ${result.status}');

      // Clean up temp file after sharing
      try {
        if (await file.exists()) {
          await file.delete();
          print('Cleaned up temp file');
        }
      } catch (e) {
        print('Error cleaning up temp file: $e');
      }
    } catch (e) {
      print('Error sharing PDF: $e');
      if (mounted) {
        _showSnackBar('فشل في مشاركة الملف: ${e.toString()}', true);
      }
    }
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
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
                      fontWeight: FontWeight.w600,
                      color: Color(AppConstants.primaryColor),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_back_ios,
              size: 16,
              color: Colors.grey.shade400,
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

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isMobile = screenWidth < 768;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _LightDetailAppBar(
          user: widget.user,
          contact: widget.contact,
          statement: widget.statement,
          onLogout: _logout,
          isGeneratingPdf: _isGeneratingPdf,
          onGeneratePdf: _filteredDetails.isNotEmpty ? _generatePdf : null,
          onRefresh: _loadDetails,
          isDesktop: isDesktop,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 1000 : double.infinity,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Document Header
                  _buildDocumentHeader(isDesktop, isMobile),

                  SizedBox(height: isMobile ? 20 : 24),

                  // Search Section - FIXED
                  if (!_isLoading &&
                      _allDetails.isNotEmpty &&
                      widget.statement.documentType != 'payment')
                    _buildSearchSection(isMobile),

                  if (!_isLoading &&
                      _allDetails.isNotEmpty &&
                      widget.statement.documentType != 'payment')
                    SizedBox(height: isMobile ? 20 : 24),

                  // Content
                  _buildContent(isDesktop, isMobile),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // FIXED: Search bar with proper height and spacing
  Widget _buildSearchSection(bool isMobile) {
    return Container(
      height: 48, // FIXED: Set specific height
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _filterDetails,
        decoration: InputDecoration(
          labelText: 'البحث في الأصناف',
          hintText: 'ادخل اسم الصنف أو رقمه',
          prefixIcon: Container(
            margin: const EdgeInsets.all(8), // FIXED: Reduced margin
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(AppConstants.accentColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.search,
              color: Colors.white,
              size: 16, // FIXED: Smaller icon
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(AppConstants.accentColor),
              width: 1.5,
            ),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12), // FIXED: Proper padding
          isDense: true, // FIXED: Makes the field more compact
        ),
        style: const TextStyle(fontSize: 14), // FIXED: Consistent text size
      ),
    );
  }

  Widget _buildDocumentHeader(bool isDesktop, bool isMobile) {
    return Container(
      width: double.infinity,
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
          // Document Icon
          Container(
            width: isMobile ? 50 : 60,
            height: isMobile ? 50 : 60,
            decoration: BoxDecoration(
              color: _getDocumentTypeColor(widget.statement.documentType),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                _getDocumentTypeIcon(widget.statement.documentType),
                color: Colors.white,
                size: isMobile ? 20 : 24,
              ),
            ),
          ),

          SizedBox(width: isMobile ? 12 : 16),

          // Document Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ArabicTextHelper.cleanText(widget.statement.displayName),
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(AppConstants.primaryColor),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isMobile ? 4 : 6),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 8 : 10,
                        vertical: isMobile ? 4 : 6,
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
                          fontSize: isMobile ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          color: _getDocumentTypeColor(
                              widget.statement.documentType),
                        ),
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 10),
                    Text(
                      'رقم: ${widget.statement.documentNumber ?? "غير محدد"}',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        color: const Color(AppConstants.accentColor),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 6 : 8),
                Row(
                  children: [
                    Icon(
                      Icons.date_range,
                      size: isMobile ? 14 : 16,
                      color: Colors.grey.shade600,
                    ),
                    SizedBox(width: isMobile ? 4 : 6),
                    Text(
                      widget.statement.docDate,
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Details count
          if (_filteredDetails.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 6 : 8,
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
                    '${_filteredDetails.length}',
                    style: TextStyle(
                      color: const Color(AppConstants.primaryColor),
                      fontWeight: FontWeight.w600,
                      fontSize: isMobile ? 14 : 16,
                    ),
                  ),
                  Text(
                    widget.statement.documentType == 'payment' ? 'قبض' : 'صنف',
                    style: TextStyle(
                      color: const Color(AppConstants.primaryColor),
                      fontWeight: FontWeight.w500,
                      fontSize: isMobile ? 10 : 11,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  // lib/screens/web/web_statement_detail_screen.dart - Part 2 (Fixed)

  Widget _buildContent(bool isDesktop, bool isMobile) {
    if (_isLoading) {
      return SizedBox(
        height: 400,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.05),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(AppConstants.accentColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'جاري تحميل تفاصيل المستند...',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredDetails.isEmpty) {
      return _buildEmptyState(isDesktop, isMobile);
    }

    return widget.statement.documentType == 'payment'
        ? _buildPaymentDetails(isDesktop, isMobile)
        : _buildInvoiceDetails(isDesktop, isMobile);
  }

  Widget _buildEmptyState(bool isDesktop, bool isMobile) {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 24 : 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.05),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(
                Icons.description_outlined,
                size: isMobile ? 60 : 80,
                color: Colors.grey.shade300,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _searchController.text.isNotEmpty
                  ? 'لا توجد نتائج للبحث'
                  : 'لا توجد تفاصيل لهذا المستند',
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty
                  ? 'جرب البحث بكلمات مختلفة'
                  : 'لم يتم العثور على أي تفاصيل لهذا المستند',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_searchController.text.isNotEmpty)
              ElevatedButton(
                onPressed: () {
                  _searchController.clear();
                  _filterDetails('');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppConstants.accentColor),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 24 : 32,
                    vertical: isMobile ? 12 : 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                // lib/screens/web/web_statement_detail_screen.dart - Part 3 (Final)

                child: Text(
                  'مسح البحث',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
              )
            else
              ElevatedButton(
                onPressed: _loadDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppConstants.accentColor),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 24 : 32,
                    vertical: isMobile ? 12 : 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'إعادة المحاولة',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetails(bool isDesktop, bool isMobile) {
    if (_filteredDetails.isEmpty) return const SizedBox();

    final detail = _filteredDetails.first;

    return Container(
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
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: BoxDecoration(
              color: const Color(AppConstants.primaryColor).withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.payment,
                  color: const Color(AppConstants.primaryColor),
                  size: isMobile ? 18 : 20,
                ),
                SizedBox(width: isMobile ? 8 : 10),
                Text(
                  'تفاصيل القبض',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(AppConstants.primaryColor),
                  ),
                ),
              ],
            ),
          ),

          // Payment Details
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Column(
              children: [
                _buildPaymentRow('طريقة الدفع',
                    detail.check.isEmpty ? 'كاش' : 'شيك', isMobile),
                if (detail.check.isNotEmpty) ...[
                  _buildPaymentRow('رقم الشيك', detail.checkNumber, isMobile),
                  _buildPaymentRow(
                      'تاريخ الاستحقاق', detail.checkDueDate, isMobile),
                ],
                _buildPaymentRow(
                    'القيمة', _formatStringValue(detail.credit), isMobile,
                    isAmount: true),
              ],
            ),
          ),

          // Comment section if exists
          if (detail.docComment.isNotEmpty)
            Container(
              width: double.infinity,
              margin: EdgeInsets.all(isMobile ? 16 : 20),
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.comment,
                    size: isMobile ? 16 : 18,
                    color: Colors.blue.shade600,
                  ),
                  SizedBox(width: isMobile ? 8 : 10),
                  Expanded(
                    child: Text(
                      ArabicTextHelper.cleanText(detail.docComment),
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 15,
                        color: Colors.blue.shade700,
                        height: 1.3,
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

  Widget _buildPaymentRow(String label, String value, bool isMobile,
      {bool isAmount = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 14 : 15,
                fontWeight: isAmount ? FontWeight.w600 : FontWeight.w500,
                color: isAmount
                    ? const Color(AppConstants.accentColor)
                    : const Color(AppConstants.primaryColor),
              ),
              textDirection:
                  isAmount ? ui.TextDirection.ltr : ui.TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }

  // FIXED: Enhanced invoice details with better number display
  Widget _buildInvoiceDetails(bool isDesktop, bool isMobile) {
    final items = _filteredDetails.where((d) => d.item.isNotEmpty).toList();
    if (items.isEmpty) return const SizedBox();

    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Header section
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 20,
                vertical: isMobile ? 12 : 16,
              ),
              decoration: const BoxDecoration(
                color: Color(AppConstants.primaryColor),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory,
                    color: Colors.white,
                    size: isMobile ? 18 : 20,
                  ),
                  SizedBox(width: isMobile ? 8 : 10),
                  Text(
                    'الأصناف',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 8 : 10,
                      vertical: isMobile ? 4 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${items.length} صنف',
                      style: TextStyle(
                        fontSize: isMobile ? 10 : 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Table Header
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: const BoxDecoration(
                color: Color(AppConstants.primaryColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'رقم الصنف',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'اسم الصنف',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'الكمية',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'السعر',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'المبلغ',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            // Data Rows
            SizedBox(
              height: 300, // FIXED: Set specific height for table content
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isEven = index % 2 == 0;

                  return Container(
                    padding: EdgeInsets.all(isMobile ? 8 : 12),
                    decoration: BoxDecoration(
                      color: isEven ? Colors.grey.shade50 : Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade200,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Item Code
                        Expanded(
                          flex: 2,
                          child: Text(
                            item.item,
                            style: TextStyle(
                              fontSize: isMobile ? 10 : 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(AppConstants.primaryColor),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Item Name
                        Expanded(
                          flex: 3,
                          child: Text(
                            ArabicTextHelper.cleanText(item.name),
                            style: TextStyle(
                              fontSize: isMobile ? 10 : 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(AppConstants.primaryColor),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Quantity - FIXED: Better number display
                        Expanded(
                          flex: 2,
                          child: Text(
                            _formatStringValue(item.quantity),
                            style: TextStyle(
                              fontSize: isMobile ? 10 : 12,
                              fontWeight: FontWeight.w500,
                            ),
                            textDirection: ui.TextDirection.ltr,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Price - FIXED: Better number display
                        Expanded(
                          flex: 2,
                          child: Text(
                            _formatStringValue(item.price),
                            style: TextStyle(
                              fontSize: isMobile ? 10 : 12,
                              fontWeight: FontWeight.w500,
                            ),
                            textDirection: ui.TextDirection.ltr,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Amount - FIXED: Better number display
                        Expanded(
                          flex: 2,
                          child: Text(
                            _formatStringValue(item.amount),
                            style: TextStyle(
                              fontSize: isMobile ? 10 : 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(AppConstants.accentColor),
                            ),
                            textDirection: ui.TextDirection.ltr,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Totals Summary
            _buildTotalsSummary(items, isMobile),
          ],
        ),
      ),
    );
  }

  // FIXED: Enhanced totals with better number formatting
  Widget _buildTotalsSummary(
      List<models.AccountStatementDetail> items, bool isMobile) {
    double totalAmount = 0;
    double tax = 0;
    double discount = 0;

    for (final item in items) {
      totalAmount += _parseNumericValue(item.amount);
    }

    if (items.isNotEmpty) {
      for (final item in items) {
        if (item.tax.isNotEmpty) {
          tax = _parseNumericValue(item.tax);
        }
        if (item.docDiscount.isNotEmpty) {
          discount = _parseNumericValue(item.docDiscount);
        }
      }
    }

    final afterDiscount = totalAmount - discount;
    final netAmount = afterDiscount + tax;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildTotalRow('المجموع', totalAmount, isMobile: isMobile),
          if (discount > 0)
            _buildTotalRow('الخصم', discount, isMobile: isMobile),
          if (discount > 0)
            _buildTotalRow('بعد الخصم', afterDiscount, isMobile: isMobile),
          if (tax > 0) _buildTotalRow('ضريبة ال 16%', tax, isMobile: isMobile),
          Divider(height: isMobile ? 8 : 12),
          _buildTotalRow('الصافي', netAmount, isNet: true, isMobile: isMobile),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount,
      {bool isNet = false, required bool isMobile}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 2 : 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontSize: isNet ? (isMobile ? 14 : 16) : (isMobile ? 12 : 14),
              fontWeight: isNet ? FontWeight.w600 : FontWeight.w500,
              color: isNet
                  ? const Color(AppConstants.primaryColor)
                  : Colors.black87,
            ),
          ),
          Text(
            _formatNumber(amount),
            style: TextStyle(
              fontSize: isNet ? (isMobile ? 14 : 16) : (isMobile ? 12 : 14),
              fontWeight: isNet ? FontWeight.w600 : FontWeight.w500,
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
}

// Light App Bar Component
class _LightDetailAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final AppUser user;
  final Contact contact;
  final AccountStatement statement;
  final VoidCallback onLogout;
  final bool isGeneratingPdf;
  final VoidCallback? onGeneratePdf;
  final VoidCallback onRefresh;
  final bool isDesktop;

  const _LightDetailAppBar({
    required this.user,
    required this.contact,
    required this.statement,
    required this.onLogout,
    required this.isGeneratingPdf,
    required this.onGeneratePdf,
    required this.onRefresh,
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
      title: Row(
        children: [
          // Document type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getDocumentTypeColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              Helpers.getDocumentTypeInArabic(statement.documentType),
              style: TextStyle(
                color: _getDocumentTypeColor(),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Title
          Expanded(
            child: Text(
              isDesktop
                  ? 'تفاصيل - ${ArabicTextHelper.cleanText(contact.nameAr)}'
                  : 'تفاصيل المستند',
              style: const TextStyle(
                color: Color(AppConstants.primaryColor),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        // PDF button
        if (onGeneratePdf != null)
          IconButton(
            icon: isGeneratingPdf
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(AppConstants.accentColor),
                    ),
                  )
                : const Icon(
                    Icons.picture_as_pdf,
                    color: Color(AppConstants.primaryColor),
                  ),
            onPressed: isGeneratingPdf ? null : onGeneratePdf,
            tooltip: 'إنشاء PDF',
          ),

        // User info for desktop
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

        // Menu
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'logout') {
              onLogout();
            } else if (value == 'refresh') {
              onRefresh();
            }
          },
          icon: const Icon(
            Icons.more_vert,
            color: Color(AppConstants.primaryColor),
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(
                    Icons.refresh,
                    color: const Color(AppConstants.accentColor),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text('تحديث'),
                ],
              ),
            ),
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

  Color _getDocumentTypeColor() {
    switch (statement.documentType) {
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

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
