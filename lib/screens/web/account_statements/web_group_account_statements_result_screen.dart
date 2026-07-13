// lib/screens/web/web_group_account_statements_result_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jala_as/models/account_statement.dart';
import 'package:jala_as/models/contact_group.dart';
import 'package:jala_as/models/contact.dart';
import 'package:jala_as/models/user.dart';
import 'package:jala_as/services/api_service.dart';
import 'package:jala_as/services/pdf_service.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/constants.dart';
import 'package:jala_as/utils/helpers.dart';
import 'package:jala_as/utils/arabic_text_helper.dart';
import 'package:jala_as/utils/platform_utils.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui' as ui;

class GroupAccountStatementsResultScreen extends StatefulWidget {
  final AppUser user;
  final ContactGroup group;
  final String fromDate;
  final String toDate;

  const GroupAccountStatementsResultScreen({
    super.key,
    required this.user,
    required this.group,
    required this.fromDate,
    required this.toDate,
  });

  @override
  State<GroupAccountStatementsResultScreen> createState() =>
      _GroupAccountStatementsResultScreenState();
}

class _GroupAccountStatementsResultScreenState
    extends State<GroupAccountStatementsResultScreen> {
  List<ContactStatementResult> _results = [];
  bool _isLoading = true;
  bool _isGeneratingAllPdfs = false;
  bool _isSendingEmail = false;
  Map<String, bool> _generatingPdfMap = {};
  Map<String, Uint8List> _cachedPdfs = {};

  // Email dialog controllers
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();

  @override
  bool get wantKeepAlive => true; // IMPORTANT: This is required!

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllStatements();
      _initializeEmailDefaults();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  void _initializeEmailDefaults() {
    final formattedFromDate =
        Helpers.formatDisplayDate(DateTime.parse(widget.fromDate));
    final formattedToDate =
        Helpers.formatDisplayDate(DateTime.parse(widget.toDate));

    _subjectController.text =
        'كشوف حساب - ${widget.group.name} - من $formattedFromDate إلى $formattedToDate';
    _emailController.text = 'jessica.qasasfeh@jala.ps';
  }

  Future<void> _loadAllStatements() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final allContacts = await _getGroupContacts();
      final results = <ContactStatementResult>[];

      for (final contact in allContacts) {
        try {
          final statements = await ApiService.getAccountStatements(
            contactCode: contact.code,
            fromDate: widget.fromDate,
            toDate: widget.toDate,
          );

          results.add(ContactStatementResult(
            contact: contact,
            statements: statements,
            success: true,
          ));
        } catch (e) {
          results.add(ContactStatementResult(
            contact: contact,
            statements: [],
            success: false,
            errorMessage: e.toString(),
          ));
        }
      }

      if (mounted) {
        setState(() {
          _results = results;
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

  Future<List<Contact>> _getGroupContacts() async {
    final contacts = <Contact>[];

    for (final code in widget.group.contactCodes) {
      final contact = await SupabaseService.getContactByCode(code);
      if (contact != null) {
        contacts.add(contact);
      }
    }

    return contacts;
  }

  Future<void> _showEmailDialog() async {
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        final size = MediaQuery.of(context).size;
        final isMobile = size.width < 768;

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
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.email,
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'إرسال كشوف الحساب بالبريد',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: isMobile ? double.maxFinite : 500,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'سيتم إرفاق ${_results.where((r) => r.success && r.statements.isNotEmpty).length} ملف PDF',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'البريد الإلكتروني للمستلم',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(AppConstants.primaryColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: ui.TextDirection.ltr,
                      decoration: InputDecoration(
                        hintText: 'example@domain.com',
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(AppConstants.accentColor),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'يرجى إدخال البريد الإلكتروني';
                        }
                        final emailRegex = RegExp(
                          r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                        );
                        if (!emailRegex.hasMatch(value.trim())) {
                          return 'يرجى إدخال بريد إلكتروني صحيح';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'موضوع الرسالة',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(AppConstants.primaryColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _subjectController,
                      textDirection: ui.TextDirection.rtl,
                      decoration: InputDecoration(
                        hintText: 'أدخل موضوع الرسالة',
                        prefixIcon: Icon(
                          Icons.subject,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(AppConstants.accentColor),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'يرجى إدخال موضوع الرسالة';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(context).pop();
                    _sendEmailWithPdfs();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.send, size: 18),
                    SizedBox(width: 8),
                    Text('إرسال'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendEmailWithPdfs() async {
    setState(() => _isSendingEmail = true);

    try {
      final successfulResults =
          _results.where((r) => r.success && r.statements.isNotEmpty).toList();

      if (successfulResults.isEmpty) {
        _showSnackBar('لا توجد كشوف حساب لإرسالها', true);
        setState(() => _isSendingEmail = false);
        return;
      }

      _showProgressDialog('جاري إنشاء ملفات PDF...');

      final pdfs = await PdfService.generateGroupAccountStatementPdfs(
        results: successfulResults,
        fromDate: widget.fromDate,
        toDate: widget.toDate,
        onProgress: (current, total, contactName) {
          print('Generating PDF $current/$total for $contactName');
        },
      );

      _cachedPdfs.addAll(pdfs);

      if (mounted) {
        Navigator.of(context).pop();
        _showProgressDialog('جاري إرسال البريد الإلكتروني...');
      }

      final attachments = <Map<String, dynamic>>[];

      for (final entry in pdfs.entries) {
        final contactCode = entry.key;
        final pdfBytes = entry.value;

        final result =
            successfulResults.firstWhere((r) => r.contact.code == contactCode);
        final contact = result.contact;

        final formattedFromDate =
            Helpers.formatDisplayDate(DateTime.parse(widget.fromDate));
        final formattedToDate =
            Helpers.formatDisplayDate(DateTime.parse(widget.toDate));
        final filename =
            '$contactCode - ${contact.nameAr} من $formattedFromDate إلى $formattedToDate.pdf';

        attachments.add({
          'name': filename,
          'ContentBytes': base64Encode(pdfBytes),
          'contentType': 'application/pdf',
        });
      }

      final formattedFromDate =
          Helpers.formatDisplayDate(DateTime.parse(widget.fromDate));
      final formattedToDate =
          Helpers.formatDisplayDate(DateTime.parse(widget.toDate));

      final emailBody = '''
مرحباً<br><br>
نرسل لكم كشوف الحساب للمجموعة: <strong>${widget.group.name}</strong><br><br>
<strong>تفاصيل الكشوف:</strong><br>
- الفترة: من $formattedFromDate إلى $formattedToDate<br>
- عدد العملاء: ${successfulResults.length}<br>
- عدد الملفات المرفقة: ${attachments.length}<br><br>
<strong>قائمة العملاء:</strong><br>
${_generateContactsList(successfulResults)}<br>
تم إنشاء هذه الكشوف بواسطة: <strong>${widget.user.username}</strong><br>
التاريخ: ${Helpers.formatDisplayDate(DateTime.now())} - ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}<br><br>
مع تحيات فريق جالا
''';

      await ApiService.sendEmail(
        to: _emailController.text.trim(),
        subject: _subjectController.text.trim(),
        body: emailBody,
        attachments: attachments,
      );

      if (mounted) {
        Navigator.of(context).pop();
        setState(() => _isSendingEmail = false);

        _showSuccessDialog(
          '✅ تم إرسال البريد الإلكتروني بنجاح',
          'تم إرسال ${attachments.length} ملف PDF إلى ${_emailController.text.trim()}',
        );
      }
    } catch (e) {
      print('Error sending email with PDFs: $e');
      if (mounted) {
        Navigator.of(context).pop();
        setState(() => _isSendingEmail = false);
        _showSnackBar('فشل في إرسال البريد الإلكتروني: ${e.toString()}', true);
      }
    }
  }

  String _generateContactsList(List<ContactStatementResult> results) {
    final buffer = StringBuffer();
    buffer.write('<ul style="margin: 10px 0; padding-right: 20px;">');

    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      buffer.write('<li style="margin: 5px 0;">'
          '${i + 1}. ${result.contact.nameAr} (${result.contact.code}) - '
          '${result.statements.length} حركة'
          '</li>');
    }

    buffer.write('</ul>');
    return buffer.toString();
  }

  void _showProgressDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(AppConstants.accentColor),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(AppConstants.primaryColor),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'يرجى الانتظار...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(AppConstants.primaryColor),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('حسناً'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadAllPdfs() async {
    setState(() => _isGeneratingAllPdfs = true);

    try {
      final successfulResults =
          _results.where((r) => r.success && r.statements.isNotEmpty).toList();

      if (successfulResults.isEmpty) {
        _showSnackBar('لا توجد كشوف حساب لتحميلها', true);
        setState(() => _isGeneratingAllPdfs = false);
        return;
      }

      if (mounted) {
        _showProgressDialog('جاري إنشاء ملفات PDF...');
      }

      final pdfs = await PdfService.generateGroupAccountStatementPdfs(
        results: successfulResults,
        fromDate: widget.fromDate,
        toDate: widget.toDate,
        onProgress: (current, total, contactName) {
          print('Generating PDF $current/$total for $contactName');
        },
      );

      _cachedPdfs.addAll(pdfs);

      if (mounted) {
        Navigator.of(context).pop();
      }

      if (PlatformUtils.isWeb) {
        await _downloadAllPdfsWeb(pdfs);
      } else {
        await _downloadAllPdfsMobile(pdfs);
      }

      if (mounted) {
        setState(() => _isGeneratingAllPdfs = false);
        _showSnackBar('تم تحميل جميع ملفات PDF بنجاح', false);
      }
    } catch (e) {
      print('Error downloading all PDFs: $e');
      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        setState(() => _isGeneratingAllPdfs = false);
        _showSnackBar('فشل في تحميل ملفات PDF: ${e.toString()}', true);
      }
    }
  }

  Future<void> _downloadAllPdfsWeb(Map<String, Uint8List> pdfs) async {
    for (final entry in pdfs.entries) {
      final contactCode = entry.key;
      final pdfBytes = entry.value;

      final result = _results.firstWhere((r) => r.contact.code == contactCode);
      final contact = result.contact;

      final formattedFromDate =
          Helpers.formatDisplayDate(DateTime.parse(widget.fromDate));
      final formattedToDate =
          Helpers.formatDisplayDate(DateTime.parse(widget.toDate));
      final filename =
          '$contactCode - ${contact.nameAr} - من $formattedFromDate إلى $formattedToDate.pdf';

      try {
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: filename,
        );

        await Future.delayed(const Duration(milliseconds: 800));
      } catch (e) {
        print('Error downloading PDF for $contactCode: $e');
      }
    }
  }

  Future<void> _downloadAllPdfsMobile(Map<String, Uint8List> pdfs) async {
    try {
      Directory directory;

      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');

        if (!await directory.exists()) {
          directory = await getApplicationDocumentsDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final savedFiles = <String>[];

      for (final entry in pdfs.entries) {
        final contactCode = entry.key;
        final pdfBytes = entry.value;

        final result =
            _results.firstWhere((r) => r.contact.code == contactCode);
        final contact = result.contact;

        final formattedFromDate =
            Helpers.formatDisplayDate(DateTime.parse(widget.fromDate));
        final formattedToDate =
            Helpers.formatDisplayDate(DateTime.parse(widget.toDate));

        String cleanFilename =
            '$contactCode - ${contact.nameAr} - من $formattedFromDate إلى $formattedToDate.pdf';
        cleanFilename =
            cleanFilename.replaceAll('/', '-').replaceAll('\\', '-');

        final filePath = '${directory.path}/$cleanFilename';

        try {
          final file = File(filePath);
          await file.writeAsBytes(pdfBytes);
          savedFiles.add(filePath);
        } catch (e) {
          print('Error saving PDF $contactCode: $e');
        }
      }

      if (mounted) {
        if (savedFiles.isEmpty) {
          _showSnackBar('فشل في حفظ ملفات PDF', true);
        } else {
          _showSnackBar(
              'تم حفظ ${savedFiles.length} ملف PDF في: ${directory.path}',
              false);
        }
      }
    } catch (e) {
      print('Error in _downloadAllPdfsMobile: $e');
      if (mounted) {
        _showSnackBar('فشل في حفظ ملفات PDF: ${e.toString()}', true);
      }
    }
  }

  Future<void> _shareAllPdfs() async {
    if (!PlatformUtils.isMobile) {
      _showSnackBar('المشاركة متاحة فقط على الأجهزة المحمولة', true);
      return;
    }

    setState(() => _isGeneratingAllPdfs = true);

    try {
      final successfulResults =
          _results.where((r) => r.success && r.statements.isNotEmpty).toList();

      if (successfulResults.isEmpty) {
        _showSnackBar('لا توجد كشوف حساب لمشاركتها', true);
        setState(() => _isGeneratingAllPdfs = false);
        return;
      }

      if (mounted) {
        _showProgressDialog('جاري إنشاء ملفات PDF...');
      }

      final pdfs = await PdfService.generateGroupAccountStatementPdfs(
        results: successfulResults,
        fromDate: widget.fromDate,
        toDate: widget.toDate,
        onProgress: (current, total, contactName) {
          print('Generating PDF $current/$total for $contactName');
        },
      );

      if (mounted) {
        Navigator.of(context).pop();
        _showProgressDialog('جاري تحضير الملفات للمشاركة...');
      }

      final tempDir = await getTemporaryDirectory();
      final shareDir = Directory('${tempDir.path}/share');

      if (!await shareDir.exists()) {
        await shareDir.create(recursive: true);
      }

      final filePaths = <String>[];

      for (final entry in pdfs.entries) {
        final contactCode = entry.key;
        final pdfBytes = entry.value;

        final result =
            _results.firstWhere((r) => r.contact.code == contactCode);
        final contact = result.contact;

        final formattedFromDate =
            Helpers.formatDisplayDate(DateTime.parse(widget.fromDate));
        final formattedToDate =
            Helpers.formatDisplayDate(DateTime.parse(widget.toDate));

        String cleanFilename =
            '$contactCode - ${contact.nameAr} - من $formattedFromDate إلى $formattedToDate.pdf';
        cleanFilename =
            cleanFilename.replaceAll('/', '-').replaceAll('\\', '-');

        final filePath = '${shareDir.path}/$cleanFilename';

        try {
          final file = File(filePath);
          await file.writeAsBytes(pdfBytes);
          filePaths.add(filePath);
        } catch (e) {
          print('Error creating temp file for $contactCode: $e');
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }

      if (filePaths.isEmpty) {
        if (mounted) {
          _showSnackBar('فشل في تحضير الملفات للمشاركة', true);
          setState(() => _isGeneratingAllPdfs = false);
        }
        return;
      }

      try {
        await Share.shareXFiles(
          filePaths.map((path) => XFile(path)).toList(),
          subject: 'كشوف حساب - ${widget.group.name}',
          text:
              'كشوف الحساب من ${Helpers.formatDisplayDate(DateTime.parse(widget.fromDate))} إلى ${Helpers.formatDisplayDate(DateTime.parse(widget.toDate))}',
        );

        for (final filePath in filePaths) {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        }
      } catch (e) {
        print('Error sharing files: $e');
        if (mounted) {
          _showSnackBar('فشل في مشاركة الملفات: ${e.toString()}', true);
        }
      }

      if (mounted) {
        setState(() => _isGeneratingAllPdfs = false);
      }
    } catch (e) {
      print('Error in _shareAllPdfs: $e');
      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        setState(() => _isGeneratingAllPdfs = false);
        _showSnackBar('فشل في مشاركة ملفات PDF: ${e.toString()}', true);
      }
    }
  }

  Future<void> _downloadSinglePdf(ContactStatementResult result) async {
    final contactCode = result.contact.code;
    setState(() => _generatingPdfMap[contactCode] = true);

    try {
      Uint8List pdfBytes;

      if (_cachedPdfs.containsKey(contactCode)) {
        pdfBytes = _cachedPdfs[contactCode]!;
      } else {
        pdfBytes = await PdfService.generateSingleContactPdf(
          result: result,
          fromDate: widget.fromDate,
          toDate: widget.toDate,
        );
        _cachedPdfs[contactCode] = pdfBytes;
      }

      final formattedFromDate =
          Helpers.formatDisplayDate(DateTime.parse(widget.fromDate));
      final formattedToDate =
          Helpers.formatDisplayDate(DateTime.parse(widget.toDate));

      String cleanFilename =
          '$contactCode - ${result.contact.nameAr} - من $formattedFromDate إلى $formattedToDate.pdf';
      cleanFilename = cleanFilename.replaceAll('/', '-').replaceAll('\\', '-');

      if (PlatformUtils.isWeb) {
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: cleanFilename,
        );
      } else {
        Directory directory;

        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/Download');

          if (!await directory.exists()) {
            directory = await getApplicationDocumentsDirectory();
          }
        } else {
          directory = await getApplicationDocumentsDirectory();
        }

        final filePath = '${directory.path}/$cleanFilename';
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);

        if (mounted) {
          _showSnackBar('تم حفظ الملف في: ${directory.path}', false);
        }
      }

      if (mounted) {
        setState(() => _generatingPdfMap[contactCode] = false);
      }
    } catch (e) {
      print('Error in _downloadSinglePdf: $e');
      if (mounted) {
        setState(() => _generatingPdfMap[contactCode] = false);
        _showSnackBar('فشل في تحميل PDF: ${e.toString()}', true);
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

  @override
  Widget build(BuildContext context) {
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
            'نتائج كشوف الحساب',
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
              maxWidth: isDesktop ? 1000 : double.infinity,
            ),
            child: _isLoading
                ? _buildLoadingState(isMobile)
                : _buildResultsContent(isDesktop, isMobile),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isMobile) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                Color(AppConstants.accentColor),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'جاري تحميل كشوف الحساب...',
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'قد تستغرق هذه العملية بعض الوقت',
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsContent(bool isDesktop, bool isMobile) {
    final successCount = _results.where((r) => r.success).length;
    final failureCount = _results.where((r) => !r.success).length;
    final hasStatements =
        _results.any((r) => r.success && r.statements.isNotEmpty);

    return Column(
      children: [
        _buildSuccessHeader(successCount, failureCount, isMobile),
        if (hasStatements) ...[
          if (PlatformUtils.isWeb)
            _buildWebActions(isMobile)
          else
            _buildMobileActions(isMobile),
          SizedBox(height: isMobile ? 20 : 24),
        ],
        Expanded(
          child: _buildContactsList(isMobile),
        ),
      ],
    );
  }

  Widget _buildSuccessHeader(
      int successCount, int failureCount, bool isMobile) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(isMobile ? 16 : 24),
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade400,
            Colors.green.shade600,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.white,
            size: isMobile ? 48 : 56,
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Text(
            'تم جلب كشوف الحساب بنجاح',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatBadge(
                label: 'ناجح',
                count: successCount,
                color: Colors.white,
                isMobile: isMobile,
              ),
              if (failureCount > 0) ...[
                SizedBox(width: isMobile ? 12 : 16),
                _buildStatBadge(
                  label: 'فشل',
                  count: failureCount,
                  color: Colors.red.shade300,
                  isMobile: isMobile,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebActions(bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.download,
              label: 'تحميل الكل',
              onTap: _isGeneratingAllPdfs ? null : _downloadAllPdfs,
              isLoading: _isGeneratingAllPdfs,
              color: const Color(AppConstants.accentColor),
              isMobile: isMobile,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: _buildActionButton(
              icon: Icons.email,
              label: 'إرسال بالبريد',
              onTap: _isSendingEmail ? null : _showEmailDialog,
              isLoading: _isSendingEmail,
              color: Colors.blue,
              isMobile: isMobile,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileActions(bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.download,
              label: 'حفظ الكل',
              onTap: _isGeneratingAllPdfs ? null : _downloadAllPdfs,
              isLoading: _isGeneratingAllPdfs,
              color: const Color(AppConstants.accentColor),
              isMobile: isMobile,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: _buildActionButton(
              icon: Icons.share,
              label: 'مشاركة الكل',
              onTap: _isGeneratingAllPdfs ? null : _shareAllPdfs,
              isLoading: _isGeneratingAllPdfs,
              color: Colors.blue,
              isMobile: isMobile,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge({
    required String label,
    required int count,
    required Color color,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 12 : 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required Color color,
    required bool isMobile,
    bool isLoading = false,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          vertical: isMobile ? 14 : 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 0,
      ),
      child: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: isMobile ? 18 : 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildContactsList(bool isMobile) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 8,
      ),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        return _buildContactCard(result, isMobile);
      },
    );
  }

  Widget _buildContactCard(ContactStatementResult result, bool isMobile) {
    final isGeneratingPdf = _generatingPdfMap[result.contact.code] ?? false;
    final hasStatements = result.success && result.statements.isNotEmpty;

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: result.success ? Colors.grey.shade200 : Colors.red.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Row(
          children: [
            Container(
              width: isMobile ? 40 : 48,
              height: isMobile ? 40 : 48,
              decoration: BoxDecoration(
                color: result.success
                    ? const Color(AppConstants.accentColor)
                    : Colors.red.shade400,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: result.success
                    ? Text(
                        result.contact.nameAr.isNotEmpty
                            ? result.contact.nameAr[0]
                            : 'ع',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: isMobile ? 16 : 18,
                        ),
                      )
                    : Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: isMobile ? 20 : 24,
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
                    ArabicTextHelper.cleanText(result.contact.nameAr),
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(AppConstants.primaryColor),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isMobile ? 4 : 6),
                  Row(
                    children: [
                      Text(
                        'كود: ${result.contact.code}',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: const Color(AppConstants.accentColor),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (hasStatements) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            '${result.statements.length} حركة',
                            style: TextStyle(
                              fontSize: isMobile ? 10 : 11,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (!result.success) ...[
                    SizedBox(height: isMobile ? 4 : 6),
                    Text(
                      'فشل في التحميل',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (hasStatements)
              IconButton(
                onPressed:
                    isGeneratingPdf ? null : () => _downloadSinglePdf(result),
                icon: isGeneratingPdf
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(AppConstants.accentColor),
                        ),
                      )
                    : Icon(
                        Icons.download,
                        color: const Color(AppConstants.accentColor),
                        size: isMobile ? 22 : 24,
                      ),
                tooltip: 'تحميل PDF',
              ),
          ],
        ),
      ),
    );
  }
}
