// lib/screens/web/web_account_statements_screen.dart - Part 1
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:jala_as/utils/platform_utils.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../models/user.dart';
import '../../../models/contact.dart';
import '../../../models/account_statement.dart';
import '../../../services/api_service.dart';
import '../../../services/pdf_service.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';
import '../../../utils/arabic_text_helper.dart';
import 'web_statement_detail_screen.dart';
import '../web_login_screen.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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

class _WebAccountStatementsScreenState extends State<WebAccountStatementsScreen>
    with AutomaticKeepAliveClientMixin {
  List<AccountStatement> _statements = [];
  bool _isLoading = true;
  bool _isGeneratingPdf = false;
  bool _isCardView = false;

  final ScrollController _horizontalHeaderController = ScrollController();
  final ScrollController _horizontalDataController = ScrollController();
  final ScrollController _screenVerticalController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStatements();
    });

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
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final statements = await ApiService.getAccountStatements(
        contactCode: widget.contact.code,
        fromDate: widget.fromDate,
        toDate: widget.toDate,
      );

      if (mounted) {
        setState(() {
          _statements = statements;
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

  Future<void> _generatePdf() async {
    setState(() => _isGeneratingPdf = true);

    try {
      final pdfBytes = await PdfService.generateAccountStatementPdf(
        contact: widget.contact,
        statements: _statements,
        fromDate: widget.fromDate,
        toDate: widget.toDate,
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
    // Generate filename - CLEAN IT
    final formattedFromDate =
        Helpers.formatDisplayDate(DateTime.parse(widget.fromDate));
    final formattedToDate =
        Helpers.formatDisplayDate(DateTime.parse(widget.toDate));

    String filename =
        '${widget.contact.code} - ${widget.contact.nameAr} - من $formattedFromDate إلى $formattedToDate.pdf';
    // Clean filename - remove problematic characters
    filename = filename.replaceAll('/', '-').replaceAll('\\', '-');

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
                      _showSnackBar('فشل في طباعة PDF: ${e.toString()}', true);
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Download/Save option
                _buildPdfActionButton(
                  icon: Icons.download,
                  title: PlatformUtils.isWeb ? 'تحميل' : 'حفظ',
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
        _showSnackBar('تم تحميل الملف', false);
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
        _showSnackBar('تم حفظ الملف في: ${directory.path}', false);
      }
    } catch (e) {
      print('Error downloading PDF: $e');
      _showSnackBar('فشل في حفظ الملف: ${e.toString()}', true);
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
        subject: 'كشف حساب - ${widget.contact.nameAr}',
        text:
            'كشف الحساب من ${Helpers.formatDisplayDate(DateTime.parse(widget.fromDate))} إلى ${Helpers.formatDisplayDate(DateTime.parse(widget.toDate))}',
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
      _showSnackBar('فشل في مشاركة الملف: ${e.toString()}', true);
    }
  }

  Widget _buildPdfActionButton({
    required IconData icon,
    required String title,
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(AppConstants.primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewStatementDetail(AccountStatement statement) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            WebStatementDetailScreen(
          user: widget.user,
          contact: widget.contact,
          statement: statement,
          fromDate: widget.fromDate,
          toDate: widget.toDate,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(0.1, 0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeOut)),
            ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
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
          statements: _statements,
          onLogout: _logout,
          isGeneratingPdf: _isGeneratingPdf,
          onGeneratePdf: _statements.isNotEmpty ? _generatePdf : null,
          onRefresh: _loadStatements,
          isCardView: _isCardView,
          onViewModeChanged: (bool cardView) {
            setState(() => _isCardView = cardView);
          },
          isDesktop: isDesktop,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 1000 : double.infinity,
            ),
            child: Column(
              children: [
                _buildContactHeader(isDesktop, isMobile),
                Expanded(
                  child: _buildContent(isDesktop, isMobile),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactHeader(bool isDesktop, bool isMobile) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(isMobile ? 16 : 24),
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
          // Avatar
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
                  fontSize: isMobile ? 18 : 22,
                ),
              ),
            ),
          ),

          SizedBox(width: isMobile ? 12 : 16),

          // Contact Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ArabicTextHelper.cleanText(widget.contact.nameAr),
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(AppConstants.primaryColor),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isMobile ? 4 : 6),
                Text(
                  'كود: ${widget.contact.code}',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: const Color(AppConstants.accentColor),
                    fontWeight: FontWeight.w500,
                  ),
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
                    Expanded(
                      child: Text(
                        '${Helpers.formatDisplayDate(DateTime.parse(widget.fromDate))} - ${Helpers.formatDisplayDate(DateTime.parse(widget.toDate))}',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Statements count
          if (_statements.isNotEmpty)
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
                    '${_statements.length}',
                    style: TextStyle(
                      color: const Color(AppConstants.primaryColor),
                      fontWeight: FontWeight.w600,
                      fontSize: isMobile ? 14 : 16,
                    ),
                  ),
                  Text(
                    'حركة',
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

  // Content methods will be in Part 2...

  // lib/screens/web/web_account_statements_screen.dart - Part 2
// Content display methods and App Bar

  Widget _buildContent(bool isDesktop, bool isMobile) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
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
              'جاري تحميل كشف الحساب...',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    if (_statements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 24 : 32),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: isMobile ? 60 : 80,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'لا توجد حركات في هذه الفترة',
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لم يتم العثور على أي معاملات خلال الفترة المحددة',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadStatements,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppConstants.accentColor),
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
                'إعادة التحميل',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: isMobile ? 14 : 16,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _isCardView
        ? _buildCardView(isMobile)
        : _buildTableView(isDesktop, isMobile);
  }

  Widget _buildCardView(bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: _statements.length,
        itemBuilder: (context, index) {
          final statement = _statements[index];
          return _buildStatementCard(statement, isMobile);
        },
      ),
    );
  }

  Widget _buildStatementCard(AccountStatement statement, bool isMobile) {
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: statement.documentType == 'other'
              ? null
              : () => _viewStatementDetail(statement),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10 : 12,
                        vertical: isMobile ? 6 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: _getDocumentTypeColor(statement.documentType),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getDocumentTypeIcon(statement.documentType),
                            color: Colors.white,
                            size: isMobile ? 12 : 14,
                          ),
                          SizedBox(width: isMobile ? 4 : 6),
                          Text(
                            Helpers.getDocumentTypeInArabic(
                                statement.documentType),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 11 : 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      statement.docDate,
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: isMobile ? 12 : 16),

                // Document name
                Text(
                  ArabicTextHelper.cleanText(statement.displayName),
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(AppConstants.primaryColor),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                SizedBox(height: isMobile ? 12 : 16),

                // Financial data
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      // Debit
                      Expanded(
                        child: _buildAmountColumn(
                          'مدين',
                          statement.debit,
                          Colors.red.shade600,
                          isMobile,
                        ),
                      ),

                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.grey.shade300,
                      ),

                      // Credit
                      Expanded(
                        child: _buildAmountColumn(
                          'دائن',
                          statement.credit,
                          Colors.green.shade600,
                          isMobile,
                        ),
                      ),

                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.grey.shade300,
                      ),

                      // Balance
                      Expanded(
                        child: _buildAmountColumn(
                          'الرصيد',
                          statement.runningBalance,
                          const Color(AppConstants.accentColor),
                          isMobile,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action indicator
                if (statement.documentType != 'other') ...[
                  SizedBox(height: isMobile ? 12 : 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'عرض التفاصيل',
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          color: const Color(AppConstants.accentColor),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: const Color(AppConstants.accentColor),
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
  }

  Widget _buildAmountColumn(
      String label, String amount, Color color, bool isMobile) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 11 : 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: isMobile ? 4 : 6),
        Text(
          Helpers.formatNumber(amount),
          style: TextStyle(
            fontSize: isMobile ? 13 : 14,
            fontWeight: FontWeight.w600,
            color: amount.isNotEmpty ? color : Colors.grey.shade400,
          ),
          textDirection: ui.TextDirection.ltr,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTableView(bool isDesktop, bool isMobile) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fixedColumnWidth = screenWidth * 0.5;
    final scrollableColumnContentWidth =
        screenWidth > 520 ? screenWidth * 0.5 : 240.0;

    return Container(
      margin: EdgeInsets.all(isMobile ? 16 : 24),
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
            // Fixed Header Row
            SizedBox(
              height: isMobile ? 40 : 48,
              child: Row(
                children: [
                  // Fixed header columns (Date, Document)
                  Container(
                    width: fixedColumnWidth,
                    decoration: BoxDecoration(
                      color: const Color(AppConstants.primaryColor),
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200, width: 1),
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
                              'التاريخ',
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 14,
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
                                fontSize: isMobile ? 12 : 14,
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
                                    fontSize: isMobile ? 12 : 14,
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
                                    fontSize: isMobile ? 12 : 14,
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
                                    fontSize: isMobile ? 12 : 14,
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
                                _statements[index], index, isMobile),
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
                                    _statements[index], index, isMobile),
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
    );
  }

  Widget _buildFixedRowPart(
      AccountStatement statement, int index, bool isMobile) {
    return InkWell(
      onTap: statement.documentType == 'other'
          ? null
          : () => _viewStatementDetail(statement),
      child: Container(
        height: isMobile ? 52 : 60,
        decoration: BoxDecoration(
          color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
            left: BorderSide(
              color: const Color(AppConstants.primaryColor),
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            // Date column
            Expanded(
              flex: 2,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 6),
                child: Center(
                  child: Text(
                    statement.docDate,
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 12,
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
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 6 : 8,
                            vertical: isMobile ? 2 : 4,
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
                              fontSize: isMobile ? 9 : 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: isMobile ? 4 : 6),
                        if (statement.documentType != 'other')
                          Icon(
                            Icons.arrow_back_ios,
                            size: isMobile ? 10 : 12,
                            color: Colors.grey,
                          ),
                      ],
                    ),
                    SizedBox(height: isMobile ? 2 : 4),
                    Text(
                      ArabicTextHelper.cleanText(statement.docNumber),
                      style: TextStyle(
                        fontSize: isMobile ? 10 : 12,
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
      AccountStatement statement, int index, bool isMobile) {
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
        height: isMobile ? 52 : 60,
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
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'مدين',
                      style: TextStyle(
                        fontSize: isMobile ? 8 : 10,
                        color: debitColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: isMobile ? 2 : 4),
                    Text(
                      Helpers.formatNumber(statement.debit),
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 13,
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
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'دائن',
                      style: TextStyle(
                        fontSize: isMobile ? 8 : 10,
                        color: creditColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: isMobile ? 2 : 4),
                    Text(
                      Helpers.formatNumber(statement.credit),
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 13,
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
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'الرصيد',
                      style: TextStyle(
                        fontSize: isMobile ? 8 : 10,
                        color: balanceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: isMobile ? 2 : 4),
                    Text(
                      Helpers.formatNumber(statement.runningBalance),
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 13,
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

// lib/screens/web/web_account_statements_screen.dart - Part 3
// App Bar Completion

class _LightAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppUser user;
  final Contact contact;
  final List<AccountStatement> statements;
  final VoidCallback onLogout;
  final bool isGeneratingPdf;
  final VoidCallback? onGeneratePdf;
  final VoidCallback onRefresh;
  final bool isCardView;
  final ValueChanged<bool> onViewModeChanged;
  final bool isDesktop;

  const _LightAppBar({
    required this.user,
    required this.contact,
    required this.statements,
    required this.onLogout,
    required this.isGeneratingPdf,
    required this.onGeneratePdf,
    required this.onRefresh,
    required this.isCardView,
    required this.onViewModeChanged,
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
        // View toggle button
        if (statements.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(left: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => onViewModeChanged(false),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: !isCardView
                          ? const Color(AppConstants.accentColor)
                              .withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.table_rows,
                      size: 18,
                      color: !isCardView
                          ? const Color(AppConstants.accentColor)
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => onViewModeChanged(true),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCardView
                          ? const Color(AppConstants.accentColor)
                              .withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.view_agenda,
                      size: 18,
                      color: isCardView
                          ? const Color(AppConstants.accentColor)
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // PDF button
        if (statements.isNotEmpty)
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

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
