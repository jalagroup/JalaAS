// lib/screens/web/web_customer_opening_screen.dart - Improved with Full Screen Loader
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:jala_as/services/offline_contact_service.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/platform_utils.dart';
import 'package:jala_as/widgets/pending_operations_dialog.dart';
import '../../utils/file_utils.dart';
import '../../../models/user.dart';
import '../../../services/api_service.dart';
import '../../../services/pdf_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';
import '../web_login_screen.dart';
import 'dart:ui' as ui;
import 'package:jala_as/services/offline_queue_service.dart'; // ADD THIS import

class WebCustomerOpeningScreen extends StatefulWidget {
  final AppUser user;

  const WebCustomerOpeningScreen({
    super.key,
    required this.user,
  });

  @override
  State<WebCustomerOpeningScreen> createState() =>
      _WebCustomerOpeningScreenState();
}

class _WebCustomerOpeningScreenState extends State<WebCustomerOpeningScreen>
    with AutomaticKeepAliveClientMixin {
  // Controllers - keep as is
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // State variables - optimized
  bool _isPickingImages = false;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String _loadingMessage = 'جارٍ المعالجة...';
  int _pendingCount = 0;

  // Dropdown values
  String? _selectedStateType;
  String? _selectedBusinessType;
  String? _selectedPaymentMethod;
  DateTime _selectedDate = DateTime.now();
  List<String> _selectedVisitDays = [];
  List<Uint8List> _imageBytes = [];

  // Controllers
  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _responsiblePersonController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _mobileController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _stateController = TextEditingController();
  final _streetController = TextEditingController();
  final _besideController = TextEditingController();
  final _creditLimitController = TextEditingController();
  final _cityController = TextEditingController();

  // Services
  final _offlineService = OfflineContactService();
  final _offlineQueueService = OfflineQueueService();

  // Constants - define once
  static const List<Map<String, String>> _businessTypes = [
    {"code": "001", "name": "جملة"},
    {"code": "002", "name": "مفرق"},
    {"code": "003", "name": "مطعم"},
    {"code": "004", "name": "ملحمة"},
    {"code": "005", "name": "فندق"},
  ];

  static const List<String> _stateTypes = ["مدينة", "قرية", "مخيم"];
  static const List<String> _paymentMethods = ["كاش", "شيك"];
  static const List<String> _daysOfWeek = [
    "السبت",
    "الأحد",
    "الإثنين",
    "الثلاثاء",
    "الأربعاء",
    "الخميس",
    "الجمعة"
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (PlatformUtils.isMobile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeOfflineSupport();
      });
    }
  }

  Future<void> _initializeOfflineSupport() async {
    if (!PlatformUtils.isMobile || !mounted) return;

    try {
      await _offlineService.initialize();
      await _offlineQueueService.initialize(
        executeOperation: _executeQueuedOperation,
        generatePdf: _generatePdfFromFormData,
        sendEmail: _sendEmailWithImages,
        onErrors: _handleSyncErrors,
        getContactCode: _extractContactCode,
      );
      await _loadPendingCount();
    } catch (e) {
      print('Error initializing offline support: $e');
    }
  }

  /// Create new customer record in Supabase from formData (for offline sync)
  Future<void> _createNewCustomerRecordFromFormData({
    required String contactCode,
    required Uint8List pdfBytes,
    required Map<String, dynamic> formData,
    required List<Uint8List> images,
  }) async {
    try {
      print('DEBUG: Creating new customer record from formData');

      // Extract data from formData
      final businessName = formData['businessName'] ?? '';
      final ownerName = formData['ownerName'] ?? '';
      final responsiblePerson = formData['responsiblePerson'] ?? '';
      final taxId = formData['taxId'] ?? '';
      final idNumber = formData['idNumber'] ?? '';
      final mobile = formData['mobile'] ?? '';
      final telephone = formData['telephone'] ?? '';
      final email = formData['email'] ?? '';
      final city = formData['city'] ?? '';
      final state = formData['state'] ?? '';
      final stateType = formData['stateType'] ?? '';
      final street = formData['street'] ?? '';
      final beside = formData['beside'] ?? '';
      final businessType = formData['businessType'] ?? '';
      final businessTypeName = formData['businessTypeName'] ?? '';
      final visitDays = formData['visitDays'] ?? '';
      final paymentMethod = formData['paymentMethod'] ?? '';
      final creditLimit = formData['creditLimit'] ?? '';
      final dateString = formData['date'] ?? '';
      final username = formData['username'] ?? '';
      final salesman = formData['salesman'] ?? '';

      // Parse date
      DateTime createdDate;
      try {
        // Date format is 'dd/MM/yyyy'
        final parts = dateString.split('/');
        if (parts.length == 3) {
          createdDate = DateTime(
            int.parse(parts[2]), // year
            int.parse(parts[1]), // month
            int.parse(parts[0]), // day
          );
        } else {
          createdDate = DateTime.now();
        }
      } catch (e) {
        print('ERROR: Failed to parse date: $e');
        createdDate = DateTime.now();
      }

      // Step 1: Create the new customer record
      final customerId = await SupabaseService.createNewCustomerRecord(
        bisanCode: contactCode,
        businessName: businessName,
        ownerName: ownerName,
        responsiblePerson: responsiblePerson,
        taxId: taxId,
        idNumber: idNumber,
        mobile: mobile,
        telephone: telephone,
        email: email,
        city: city,
        state: state,
        stateType: stateType,
        street: street,
        beside: beside,
        businessType: businessType,
        businessTypeName: businessTypeName,
        visitDays: visitDays,
        paymentMethod: paymentMethod,
        creditLimit: creditLimit,
        createdDate: createdDate,
        salesman: salesman,
        username: username,
      );

      print('DEBUG: New customer record created with ID: $customerId');

      // Step 2: Upload PDF
      final pdfUrl = await SupabaseService.uploadNewCustomerPdf(
        customerId: customerId,
        pdfBytes: pdfBytes,
        fileName: 'customer_info_$contactCode.pdf',
      );

      print('DEBUG: PDF uploaded to: $pdfUrl');

      // Step 3: Update the record with PDF URL
      await SupabaseService.updateNewCustomerPdfUrl(
        customerId: customerId,
        pdfUrl: pdfUrl,
      );

      // Step 4: Upload images if they exist
      if (images.isNotEmpty) {
        print('DEBUG: Uploading ${images.length} images');

        for (int i = 0; i < images.length; i++) {
          final imageBytes = images[i];
          final fileName = 'image_${i + 1}.jpg';

          try {
            // Upload image to storage
            final imageUrl = await SupabaseService.uploadNewCustomerImage(
              customerId: customerId,
              imageBytes: imageBytes,
              fileName: fileName,
            );

            print('DEBUG: Image $i uploaded to: $imageUrl');

            // Create image record
            await SupabaseService.createNewCustomerImageRecord(
              newCustomerId: customerId,
              imageUrl: imageUrl,
              imageName: fileName,
              imageSize: imageBytes.length,
              mimeType: _detectImageType(imageBytes),
            );
          } catch (e) {
            print('ERROR: Failed to upload image $i: $e');
            // Continue with other images
          }
        }

        print('DEBUG: All images uploaded successfully');
      }

      print('DEBUG: New customer record creation completed for offline sync');
    } catch (e) {
      print('ERROR: Failed to create new customer record from formData: $e');
      rethrow;
    }
  }

  /// Send email callback for offline sync - extracts images from the last PDF generation
  Future<void> _sendEmailWithImages(
    String contactCode,
    Uint8List pdfBytes,
    Map<String, dynamic> formData,
  ) async {
    // Extract images from formData
    final List<Uint8List> images = [];

    if (formData['images'] != null) {
      final imagesData = formData['images'];

      if (imagesData is List) {
        for (var image in imagesData) {
          if (image is Map<String, dynamic> && image['data'] != null) {
            // Decode Base64 to Uint8List
            try {
              final base64String = image['data'] as String;
              final bytes = base64Decode(base64String);
              images.add(bytes);
              print('DEBUG: Restored image for email: ${image['fileName']}');
            } catch (e) {
              print('ERROR: Failed to decode image: $e');
            }
          }
        }
      }
    }

    print('DEBUG: Sending email with ${images.length} restored images');

    // Call the regular _sendEmail with images parameter
    await _sendEmail(contactCode, pdfBytes, images: images);

    // NEW: Create record in Supabase new_customers table
    print('DEBUG: Creating new customer record in Supabase after offline sync');
    try {
      await _createNewCustomerRecordFromFormData(
        contactCode: contactCode,
        pdfBytes: pdfBytes,
        formData: formData,
        images: images,
      );
      print('DEBUG: New customer record created successfully');
    } catch (e) {
      print('ERROR: Failed to create new customer record: $e');
      // Don't throw - email was sent successfully, record creation is additional
    }
  }

  /// Handle sync errors - show dialog only if there are errors
  void _handleSyncErrors(List<Map<String, dynamic>> errors) {
    if (!mounted) return;

    print('Handling ${errors.length} sync errors');

    // Show error dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 32),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'فشلت بعض العمليات',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'فشلت ${errors.length} عملية(عمليات) أثناء المزامنة التلقائية:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...errors.take(3).map((error) {
                try {
                  final data = jsonDecode(error['data'] as String);
                  final record = data['record'];
                  final contactName = record is Map
                      ? (record['nameAR'] ?? 'غير محدد')
                      : 'غير محدد';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contactName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            error['error'] as String? ?? 'خطأ غير معروف',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } catch (e) {
                  return const SizedBox.shrink();
                }
              }).toList(),
              if (errors.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '... و ${errors.length - 3} عملية أخرى',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showPendingOperations(); // Open pending operations dialog
            },
            child: const Text('عرض التفاصيل وإعادة المحاولة'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    ).then((_) {
      // Update pending count after dialog closes
      _loadPendingCount();
    });
  }

  /// Execute queued operation (for OfflineQueueService)
  Future<bool> _executeQueuedOperation(
    String endpoint,
    String method,
    Map<String, dynamic> data,
  ) async {
    try {
      print('Executing queued operation: $method $endpoint');
      final response = await ApiService.createContact(data);

      // Check if creation was successful
      if (response != null && response.containsKey('rows')) {
        print('✓ Contact created successfully in Bisan');
        return true;
      }

      print('⚠️ Unexpected response format from API');
      return false;
    } catch (e) {
      print('Error executing queued operation: $e');
      return false;
    }
  }

  /// Extract contact code from API response or body
  String _extractContactCode(Map<String, dynamic> apiBody, dynamic response) {
    // Try to get from response first (if available)
    if (response != null) {
      if (response is Map && response.containsKey('rows')) {
        final rows = response['rows'];
        if (rows is Map && rows.containsKey('code')) {
          return rows['code'] as String;
        }
      }
    }

    // Fallback to TRANSACTION_ID
    return apiBody['TRANSACTION_ID'] as String? ??
        DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Generate PDF from formData - NO IMAGE HANDLING, JUST PDF
  Future<Uint8List> _generatePdfFromFormData(
    String contactCode,
    Map<String, dynamic> formData,
  ) async {
    try {
      print('Generating PDF for contact: $contactCode');

      // Just generate PDF - NO IMAGE EXTRACTION
      final pdfBytes = await PdfService.generateCustomerOpeningPdf(
        businessName: formData['businessName'] ?? '',
        ownerName: formData['ownerName'] ?? '',
        responsiblePerson: formData['responsiblePerson'] ?? '',
        taxId: formData['taxId'] ?? '',
        idNumber: formData['idNumber'] ?? '',
        mobile: formData['mobile'] ?? '',
        telephone: formData['telephone'] ?? '',
        email: formData['email'] ?? '',
        state: formData['state'] ?? '',
        street: formData['street'] ?? '',
        stateType: formData['stateType'] ?? '',
        beside: formData['beside'] ?? '',
        businessType:
            formData['businessTypeName'] ?? formData['businessType'] ?? '',
        visitDays: formData['visitDays'] ?? '',
        paymentMethod: formData['paymentMethod'] ?? '',
        creditLimit: formData['creditLimit'] ?? '',
        date: formData['date'] ?? '',
        contactCode: contactCode,
        createdBy: formData['username'] ?? '',
        salesman: formData['salesman'] ?? '',
      );

      print('PDF generated: ${pdfBytes.length} bytes');
      return pdfBytes;
    } catch (e) {
      print('Error generating PDF: $e');
      rethrow;
    }
  }

  Future<void> _loadPendingCount() async {
    if (!PlatformUtils.isMobile || !mounted) return;

    final counts = await _offlineService.getOperationCounts();
    if (mounted) {
      setState(() {
        _pendingCount = counts['total'] ?? 0;
      });
    }
  }

  void _showPendingOperations() {
    showDialog(
      context: context,
      builder: (context) => PendingOperationsDialog(
        apiCreateFunction: ApiService.createContact,
      ),
    ).then((_) => _loadPendingCount());
  }

  @override
  void dispose() {
    _offlineQueueService.dispose();
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _responsiblePersonController.dispose();
    _taxIdController.dispose();
    _idNumberController.dispose();
    _mobileController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _streetController.dispose();
    _besideController.dispose();
    _creditLimitController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ar'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  /// Pick multiple images - CROSS PLATFORM VERSION
  Future<void> _pickImages() async {
    if (_isPickingImages) {
      _showSnackBar('جارٍ معالجة الصور السابقة...', true);
      return;
    }

    setState(() {
      _isPickingImages = true;
    });

    try {
      // Use FileUtils for cross-platform support
      final fileUtils = FileUtils.instance;
      final imagesBytesList = await fileUtils.pickImages();

      if (imagesBytesList.isEmpty) {
        if (mounted) {
          _showSnackBar('لم يتم اختيار أي صور', false);
        }
        return;
      }

      // Process images sequentially
      int successCount = 0;
      for (int i = 0; i < imagesBytesList.length; i++) {
        final bytes = imagesBytesList[i];

        final success = await _processImageBytes(
          bytes,
          'image_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
        );
        if (success) successCount++;

        // Small delay between processing images
        if (i < imagesBytesList.length - 1) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      if (mounted && successCount > 0) {
        _showSnackBar('✅ تم إضافة $successCount صورة بنجاح', false);
      }
    } catch (e) {
      print('Error in image picker: $e');
      if (mounted) {
        _showSnackBar('❌ فشل في اختيار الصور: ${e.toString()}', true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImages = false;
        });
      }
    }
  }

  Future<bool> _processImageBytes(Uint8List bytes, String filename) async {
    try {
      // Validate file size (10MB limit)
      if (bytes.length > 10 * 1024 * 1024) {
        if (mounted) {
          _showSnackBar(
            '⚠️ حجم الصورة "$filename" كبير جداً (الحد الأقصى 10 ميجابايت)',
            true,
          );
        }
        return false;
      }

      // Validate minimum size (1KB)
      if (bytes.length < 1024) {
        if (mounted) {
          _showSnackBar(
            '⚠️ الصورة "$filename" صغيرة جداً أو تالفة',
            true,
          );
        }
        return false;
      }

      if (mounted) {
        setState(() {
          _imageBytes.add(bytes);
        });
        return true;
      }
      return false;
    } catch (e) {
      print('Error processing image $filename: $e');
      if (mounted) {
        _showSnackBar('❌ فشل في معالجة الصورة: $filename', true);
      }
      return false;
    }
  }

  /// Take photo using camera - CROSS PLATFORM VERSION
  Future<void> _takePhoto() async {
    if (_isPickingImages) {
      _showSnackBar('جارٍ معالجة الصور السابقة...', true);
      return;
    }

    setState(() {
      _isPickingImages = true;
    });

    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo == null) {
        if (mounted) {
          _showSnackBar('لم يتم التقاط صورة', false);
        }
        return;
      }

      // Read image bytes
      final imageBytes = await photo.readAsBytes();

      // Validate file size (10MB limit)
      if (imageBytes.length > 10 * 1024 * 1024) {
        if (mounted) {
          _showSnackBar(
            '⚠️ حجم الصورة كبير جداً (الحد الأقصى 10 ميجابايت)',
            true,
          );
        }
        return;
      }

      // Validate minimum size (1KB)
      if (imageBytes.length < 1024) {
        if (mounted) {
          _showSnackBar(
            '⚠️ الصورة صغيرة جداً أو تالفة',
            true,
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _imageBytes.add(imageBytes);
        });
        _showSnackBar('✅ تم التقاط الصورة بنجاح', false);
      }
    } catch (e) {
      print('Error capturing photo: $e');
      if (mounted) {
        _showSnackBar('❌ فشل في التقاط الصورة: ${e.toString()}', true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImages = false;
        });
      }
    }
  }

  /// Remove image by index
  void _removeImage(int index) {
    if (index >= 0 && index < _imageBytes.length) {
      setState(() {
        _imageBytes.removeAt(index);
      });
      _showSnackBar('🗑️ تم حذف الصورة', false);
    }
  }

  /// Clear all images
  void _clearAllImages() {
    if (_imageBytes.isEmpty) return;

    setState(() {
      _imageBytes.clear();
    });
    _showSnackBar('🗑️ تم حذف جميع الصور', false);
  }

  /// Show snackbar message
  void _showSnackBar(String message, bool isError) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleVisitDay(String day) {
    setState(() {
      if (_selectedVisitDays.contains(day)) {
        _selectedVisitDays.remove(day);
      } else {
        _selectedVisitDays.add(day);
      }
    });
  }

  // Full screen loading overlay
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
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
                _loadingMessage,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(AppConstants.primaryColor),
                ),
                textDirection: ui.TextDirection.rtl,
              ),
              const SizedBox(height: 8),
              Text(
                'يرجى الانتظار...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textDirection: ui.TextDirection.rtl,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Lightweight field builder similar to salesman selection
  Widget _buildField({
    required String label,
    required Widget child,
    bool isRequired = false,
    bool isMobile = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label + (isRequired ? ' *' : ''),
          style: TextStyle(
            fontSize: isMobile ? 14 : 16,
            fontWeight: FontWeight.w500,
            color: const Color(AppConstants.primaryColor),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        ),
      ],
    );
  }

  // Lightweight text field
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    bool isRequired = false,
    TextInputType? keyboardType,
    bool isMobile = false,
  }) {
    return _buildField(
      label: label,
      isRequired: isRequired,
      isMobile: isMobile,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textDirection: ui.TextDirection.rtl,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        style: TextStyle(
          fontSize: isMobile ? 12 : 14,
          color: Colors.black87,
        ),
        validator: isRequired
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'هذا الحقل مطلوب';
                }
                return null;
              }
            : null,
      ),
    );
  }

  // Lightweight dropdown field
  Widget _buildDropdownField({
    required String? value,
    required String label,
    required List<String> items,
    bool isRequired = false,
    required ValueChanged<String?> onChanged,
    bool isMobile = false,
  }) {
    return _buildField(
      label: label,
      isRequired: isRequired,
      isMobile: isMobile,
      child: DropdownButtonFormField<String>(
        value: value,
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    textDirection: ui.TextDirection.rtl,
                    style: TextStyle(fontSize: isMobile ? 12 : 14),
                  ),
                ))
            .toList(),
        onChanged: onChanged,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        isExpanded: true,
        validator: isRequired
            ? (value) {
                if (value == null || value.isEmpty) {
                  return 'هذا الحقل مطلوب';
                }
                return null;
              }
            : null,
      ),
    );
  }

  // Business type dropdown
  Widget _buildBusinessTypeDropdown(bool isMobile) {
    return _buildField(
      label: 'نوع العمل',
      isRequired: true,
      isMobile: isMobile,
      child: DropdownButtonFormField<String>(
        value: _selectedBusinessType,
        items: _businessTypes
            .map((type) => DropdownMenuItem(
                  value: type['code'],
                  child: Text(
                    type['name']!,
                    textDirection: ui.TextDirection.rtl,
                    style: TextStyle(fontSize: isMobile ? 12 : 14),
                  ),
                ))
            .toList(),
        onChanged: (value) => setState(() => _selectedBusinessType = value),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        isExpanded: true,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'هذا الحقل مطلوب';
          }
          return null;
        },
      ),
    );
  }

  // Visit days selector
  Widget _buildVisitDaysSelector(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'أيام الزيارات المقترحة',
          style: TextStyle(
            fontSize: isMobile ? 14 : 16,
            fontWeight: FontWeight.w500,
            color: const Color(AppConstants.primaryColor),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _daysOfWeek.map((day) {
              final isSelected = _selectedVisitDays.contains(day);
              return FilterChip(
                label: Text(
                  day,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : const Color(AppConstants.primaryColor),
                    fontSize: isMobile ? 10 : 12,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) => _toggleVisitDay(day),
                selectedColor: const Color(AppConstants.accentColor),
                backgroundColor: Colors.grey.shade100,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide(
                  color: isSelected
                      ? const Color(AppConstants.accentColor)
                      : Colors.grey.shade300,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // Date selector
  Widget _buildDateSelector(bool isMobile) {
    return _buildField(
      label: 'التاريخ',
      isRequired: true,
      isMobile: isMobile,
      child: InkWell(
        onTap: _selectDate,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('dd/MM/yyyy').format(_selectedDate),
                textDirection: ui.TextDirection.rtl,
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  color: Colors.black87,
                ),
              ),
              Icon(
                Icons.calendar_today,
                size: isMobile ? 16 : 20,
                color: Colors.grey.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Format file size in bytes to human-readable format
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  // OPTIMIZED: Image attachments
  Widget _buildImageAttachments(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'صورة (اختياري)',
                style: TextStyle(
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            if (_imageBytes.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_imageBytes.length} صورة',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: const Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_imageBytes.isNotEmpty) ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 2 : 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: _imageBytes.length,
            itemBuilder: (context, index) => _buildImageThumbnail(index),
          ),
          const SizedBox(height: 16),
          _buildImageActions(isMobile),
        ] else
          _buildImagePlaceholder(isMobile),
      ],
    );
  }

// OPTIMIZED: Image thumbnail
  Widget _buildImageThumbnail(int index) {
    final imageBytes = _imageBytes[index];
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            imageBytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image, color: Colors.grey),
              );
            },
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
        Positioned(
          bottom: 4,
          left: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'الصورة ${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  // OPTIMIZED: Image actions
  Widget _buildImageActions(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isPickingImages ? null : _showImageSourceDialog,
            icon: const Icon(Icons.add_photo_alternate, size: 18),
            label: const Text('إضافة المزيد'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(AppConstants.accentColor),
              side: const BorderSide(
                color: Color(AppConstants.accentColor),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isPickingImages ? null : _clearAllImages,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('حذف الكل'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // OPTIMIZED: Image placeholder
  Widget _buildImagePlaceholder(bool isMobile) {
    return InkWell(
      onTap: _isPickingImages ? null : _showImageSourceDialog,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          border: Border.all(
            color: _isPickingImages
                ? Colors.grey.shade300
                : const Color(AppConstants.accentColor).withOpacity(0.3),
            width: 2,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(8),
          color: _isPickingImages
              ? Colors.grey.shade100
              : const Color(AppConstants.accentColor).withOpacity(0.05),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isPickingImages
                ? SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.grey.shade600),
                    ),
                  )
                : Icon(
                    Icons.cloud_upload_outlined,
                    size: 48,
                    color: const Color(AppConstants.accentColor),
                  ),
            const SizedBox(height: 12),
            Text(
              _isPickingImages
                  ? 'جارٍ التحميل...'
                  : 'اضغط لاختيار أو التقاط صور',
              style: TextStyle(
                fontSize: 16,
                color: _isPickingImages
                    ? Colors.grey.shade600
                    : const Color(AppConstants.accentColor),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Colors.blue),
              title: const Text('التقاط صورة'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('اختيار من المعرض'),
              onTap: () {
                Navigator.pop(context);
                _pickImages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('إلغاء'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // OPTIMIZED: Summary
  Widget _buildSummary(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'ملخص البيانات',
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(AppConstants.primaryColor),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'مندوب: ${widget.user.salesman}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_businessNameController.text.isNotEmpty)
            _buildSummaryItem(
                'اسم المحل', _businessNameController.text, isMobile),
          if (_ownerNameController.text.isNotEmpty)
            _buildSummaryItem('المالك', _ownerNameController.text, isMobile),
          if (_selectedBusinessType != null)
            _buildSummaryItem('نوع العمل',
                _getBusinessTypeName(_selectedBusinessType!), isMobile),
          if (_mobileController.text.isNotEmpty)
            _buildSummaryItem('الخلوي', _mobileController.text, isMobile),
          _buildSummaryItem('التاريخ',
              DateFormat('dd/MM/yyyy').format(_selectedDate), isMobile),
        ],
      ),
    );
  }

// Add this new helper method
  String _getCombinedLocation() {
    final city = _cityController.text.trim();
    final state = _stateController.text.trim();

    if (city.isNotEmpty && state.isNotEmpty) {
      return '$city - $state';
    } else if (city.isNotEmpty) {
      return city;
    } else if (state.isNotEmpty) {
      return state;
    }
    return '';
  }

  Widget _buildSummaryItem(String label, String value, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: isMobile ? 11 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                color: Colors.grey.shade700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getBusinessTypeName(String code) {
    final type = _businessTypes.firstWhere(
      (type) => type['code'] == code,
      orElse: () => {'name': ''},
    );
    return type['name'] ?? '';
  }

  // OPTIMIZED: Action buttons
  Widget _buildActionButtons(bool isMobile) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConstants.accentColor),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              'إضافة العميل',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: _isSubmitting ? null : _clearForm,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              side: BorderSide(color: Colors.grey.shade300),
              padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'إعادة تعيين',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('يرجى تعبئة جميع الحقول المطلوبة', true);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _loadingMessage = 'جارٍ إنشاء العميل...';
    });

    try {
      // Step 1: Build the API contact data structure
      final contactData = _buildContactData();

      print('DEBUG: Creating contact with data: ${jsonEncode(contactData)}');

      // Step 2: Try to create contact with offline fallback
      if (PlatformUtils.isMobile) {
        // Mobile: Use offline service for automatic fallback
        await _submitFormWithOfflineSupport(contactData);
      } else {
        // Web: Direct API call without offline support
        await _submitFormOnline(contactData);
      }
    } catch (e) {
      print('ERROR: Submit form failed: $e');
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _loadingMessage = 'جارٍ المعالجة...';
        });
        _showSnackBar('خطأ غير متوقع: ${e.toString()}', true);
      }
    }
  }

// UPDATED: Helper dialog methods with enhanced messages
  /// Submit form with offline support (Mobile only)
  Future<void> _submitFormWithOfflineSupport(
      Map<String, dynamic> contactData) async {
    try {
      // Check connectivity first
      final isOnline = await _offlineService.hasConnectivity();

      if (!isOnline) {
        // Offline: Queue immediately
        print('DEBUG: Device is offline - queueing contact');
        await _queueContactForOffline(contactData);
        return;
      }

      // Online: Try to create contact
      try {
        setState(() {
          _loadingMessage = 'جارٍ إنشاء العميل في النظام...';
        });

        final response = await ApiService.createContact(contactData);
        final contactCode = response['rows']['code'] as String;

        // Step 3: Generate PDF
        setState(() {
          _loadingMessage = 'جارٍ إنشاء ملف PDF...';
        });
        final pdfBytes = await _generatePdf(contactCode);

        // Step 4: Send email
        setState(() {
          _loadingMessage = 'جارٍ إرسال البيانات بالبريد الإلكتروني...';
        });
        await _sendEmail(contactCode, pdfBytes);

        setState(() {
          _loadingMessage = 'تم الانتهاء بنجاح!';
        });

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          setState(() {
            _isSubmitting = false;
            _loadingMessage = 'جارٍ المعالجة...';
          });

          _showSnackBar('تم إضافة العميل بنجاح وإرسال البيانات', false);
          _clearForm();
          await _loadPendingCount();
        }
      } catch (e) {
        print('DEBUG: API call failed: $e');

        // Check if it's a network error
        if (_isNetworkError(e)) {
          print('DEBUG: Network error detected - queueing contact');
          await _queueContactForOffline(contactData);
        } else {
          // Other errors (validation, server errors, etc.)
          throw e;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _loadingMessage = 'جارٍ المعالجة...';
        });
        _showSnackBar('فشل في إضافة العميل: ${e.toString()}', true);
      }
    }
  }

// lib/screens/web/web_customer_opening_screen.dart

  Map<String, dynamic> _buildContactData() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    // Handle taxId logic
    String finalTaxId = _taxIdController.text.trim();
    if (finalTaxId.isEmpty && _idNumberController.text.trim().isNotEmpty) {
      finalTaxId = _idNumberController.text.trim();
    }

    // ✅ CRITICAL: Convert images to base64 WITH metadata for storage
    print('DEBUG: Building contact data with ${_imageBytes.length} images');
    final imagesData = <Map<String, dynamic>>[];

    for (int i = 0; i < _imageBytes.length; i++) {
      try {
        final imageBase64 = base64Encode(_imageBytes[i]);
        imagesData.add({
          'data': imageBase64,
          'fileName': 'image_${i + 1}.jpg',
          'mimeType': 'image/jpeg',
          'index': i,
        });
        print('DEBUG: Encoded image $i - size: ${_imageBytes[i].length} bytes');
      } catch (e) {
        print('ERROR: Failed to encode image $i: $e');
      }
    }

    print('DEBUG: Successfully encoded ${imagesData.length} images to base64');

    return widget.user.area == '049'
        ? {
            "TRANSACTION_ID": timestamp,
            "stationId": "Jala",
            "record": {
              "nameAR": _businessNameController.text.trim(),
              "name": _businessNameController.text.trim(),
              "enabled": "false",
              "streetAddress":
                  '${_cityController.text.trim()} - ${_stateController.text.trim()} - ${_streetController.text.trim()} - ${_besideController.text.trim()}',
              "notes": "تم إنشاؤه من تطبيق الموبايل",
              "language": "العربية",
              "isCustomer": "true",
              "taxId": finalTaxId,
              "type": _selectedBusinessType ?? "001",
              "cusContactAR": _ownerNameController.text.trim(),
              "cusContact": _ownerNameController.text.trim(),
              "cusTaxType": "p",
              "cusPriceList": "S",
              "cusTaxFormat": "Include Tax",
              "salesman": widget.user.salesman,
              "activity": widget.user.area == '049'
                  ? "1030"
                  : "1${widget.user.salesman}",
              "area": '049',
              "cusAccount": "1300",
              "customerCreditPolicy": "00001",
              "country": "PS"
            },

            // ✅ Form data for PDF generation and email later
            "_formData": {
              "businessName": _businessNameController.text.trim(),
              "ownerName": _ownerNameController.text.trim(),
              "responsiblePerson": _responsiblePersonController.text.trim(),
              "taxId": finalTaxId,
              "idNumber": _idNumberController.text.trim(),
              "mobile": _mobileController.text.trim(),
              "telephone": _telephoneController.text.trim(),
              "email": _emailController.text.trim(),
              "city": _cityController.text.trim(),
              "state": _stateController.text.trim(),
              "stateType": _selectedStateType ?? '',
              "street": _streetController.text.trim(),
              "beside": _besideController.text.trim(),
              "businessType": _selectedBusinessType ?? "001",
              "businessTypeName":
                  _getBusinessTypeName(_selectedBusinessType ?? "001"),
              "visitDays": _selectedVisitDays.join(', '),
              "paymentMethod": _selectedPaymentMethod ?? '',
              "creditLimit": _creditLimitController.text.trim(),
              "date": DateFormat('dd/MM/yyyy').format(_selectedDate),
              "username": widget.user.username,
              "salesman": widget.user.salesman,
              "images": imagesData, // ✅ Store as list of maps with metadata
              "imageCount": imagesData.length,
            }
          }
        : widget.user.area == '048'
            ? {
                "TRANSACTION_ID": timestamp,
                "stationId": "Jala",
                "record": {
                  "nameAR": _businessNameController.text.trim(),
                  "name": _businessNameController.text.trim(),
                  "enabled": "false",
                  "streetAddress":
                      '${_cityController.text.trim()} - ${_stateController.text.trim()} - ${_streetController.text.trim()} - ${_besideController.text.trim()}',
                  "notes": "تم إنشاؤه من تطبيق الموبايل",
                  "language": "العربية",
                  "isCustomer": "true",
                  "taxId": finalTaxId,
                  "type": _selectedBusinessType ?? "001",
                  "cusContactAR": _ownerNameController.text.trim(),
                  "cusContact": _ownerNameController.text.trim(),
                  "cusTaxType": "p",
                  "cusPriceList": "S",
                  "cusTaxFormat": "Include Tax",
                  "salesman": widget.user.salesman,
                  "activity": widget.user.area == '049'
                      ? "1030"
                      : "1${widget.user.salesman}",
                  "area": '048',
                  "cusAccount": "1300",
                  "customerCreditPolicy": "00001",
                  "country": "PS"
                },

                // ✅ Form data for PDF generation and email later
                "_formData": {
                  "businessName": _businessNameController.text.trim(),
                  "ownerName": _ownerNameController.text.trim(),
                  "responsiblePerson": _responsiblePersonController.text.trim(),
                  "taxId": finalTaxId,
                  "idNumber": _idNumberController.text.trim(),
                  "mobile": _mobileController.text.trim(),
                  "telephone": _telephoneController.text.trim(),
                  "email": _emailController.text.trim(),
                  "city": _cityController.text.trim(),
                  "state": _stateController.text.trim(),
                  "stateType": _selectedStateType ?? '',
                  "street": _streetController.text.trim(),
                  "beside": _besideController.text.trim(),
                  "businessType": _selectedBusinessType ?? "001",
                  "businessTypeName":
                      _getBusinessTypeName(_selectedBusinessType ?? "001"),
                  "visitDays": _selectedVisitDays.join(', '),
                  "paymentMethod": _selectedPaymentMethod ?? '',
                  "creditLimit": _creditLimitController.text.trim(),
                  "date": DateFormat('dd/MM/yyyy').format(_selectedDate),
                  "username": widget.user.username,
                  "salesman": widget.user.salesman,
                  "images": imagesData, // ✅ Store as list of maps with metadata
                  "imageCount": imagesData.length,
                }
              }
            : {
                "TRANSACTION_ID": timestamp,
                "stationId": "Jala",
                "record": {
                  "nameAR": _businessNameController.text.trim(),
                  "name": _businessNameController.text.trim(),
                  "enabled": "false",
                  "streetAddress":
                      '${_cityController.text.trim()} - ${_stateController.text.trim()} - ${_streetController.text.trim()} - ${_besideController.text.trim()}',
                  "notes": "تم إنشاؤه من تطبيق الموبايل",
                  "language": "العربية",
                  "isCustomer": "true",
                  "taxId": finalTaxId,
                  "type": _selectedBusinessType ?? "001",
                  "cusContactAR": _ownerNameController.text.trim(),
                  "cusContact": _ownerNameController.text.trim(),
                  "cusTaxType": "p",
                  "cusPriceList": "S",
                  "cusTaxFormat": "Include Tax",
                  "salesman": widget.user.salesman,
                  "activity": widget.user.area == '049'
                      ? "1030"
                      : "1${widget.user.salesman}",
                  "cusAccount": "1300",
                  "customerCreditPolicy": "00001",
                  "country": "PS"
                },

                // ✅ Form data for PDF generation and email later
                "_formData": {
                  "businessName": _businessNameController.text.trim(),
                  "ownerName": _ownerNameController.text.trim(),
                  "responsiblePerson": _responsiblePersonController.text.trim(),
                  "taxId": finalTaxId,
                  "idNumber": _idNumberController.text.trim(),
                  "mobile": _mobileController.text.trim(),
                  "telephone": _telephoneController.text.trim(),
                  "email": _emailController.text.trim(),
                  "city": _cityController.text.trim(),
                  "state": _stateController.text.trim(),
                  "stateType": _selectedStateType ?? '',
                  "street": _streetController.text.trim(),
                  "beside": _besideController.text.trim(),
                  "businessType": _selectedBusinessType ?? "001",
                  "businessTypeName":
                      _getBusinessTypeName(_selectedBusinessType ?? "001"),
                  "visitDays": _selectedVisitDays.join(', '),
                  "paymentMethod": _selectedPaymentMethod ?? '',
                  "creditLimit": _creditLimitController.text.trim(),
                  "date": DateFormat('dd/MM/yyyy').format(_selectedDate),
                  "username": widget.user.username,
                  "salesman": widget.user.salesman,
                  "images": imagesData, // ✅ Store as list of maps with metadata
                  "imageCount": imagesData.length,
                }
              };
  }

  /// Check if an error is a network error
  bool _isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('socketexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('no address associated with hostname') ||
        errorString.contains('connection refused') ||
        errorString.contains('connection timeout') ||
        errorString.contains('connection timed out');
  }

  Future<void> _submitFormOnline(Map<String, dynamic> contactData) async {
    try {
      setState(() {
        _loadingMessage = 'جارٍ إنشاء العميل في النظام...';
      });

      final response = await ApiService.createContact(contactData);
      final contactCode = response['rows']['code'] as String;

      print('DEBUG: Contact created with code: $contactCode');

      // Step 3: Generate PDF
      setState(() {
        _loadingMessage = 'جارٍ إنشاء ملف PDF...';
      });
      final pdfBytes = await _generatePdf(contactCode);

      // Step 4: Send email
      setState(() {
        _loadingMessage = 'جارٍ إرسال البيانات بالبريد الإلكتروني...';
      });
      await _sendEmail(contactCode, pdfBytes);

      // Step 5: Create record in Supabase NEW CUSTOMERS table
      setState(() {
        _loadingMessage = 'جارٍ حفظ السجل في قاعدة البيانات...';
      });
      await _createNewCustomerRecord(contactCode, pdfBytes);

      setState(() {
        _loadingMessage = 'تم الانتهاء بنجاح!';
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _loadingMessage = 'جارٍ المعالجة...';
        });

        _showSnackBar('تم إضافة العميل بنجاح وإرسال البيانات', false);
        _clearForm();
      }
    } catch (e) {
      print('ERROR: Online submission failed: $e');
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _loadingMessage = 'جارٍ المعالجة...';
        });
        _showSnackBar('فشل في إضافة العميل: ${e.toString()}', true);
      }
    }
  }

// ADD THIS NEW METHOD
  Future<void> _createNewCustomerRecord(
    String contactCode,
    Uint8List pdfBytes,
  ) async {
    try {
      print('DEBUG: Creating new customer record in Supabase');

      // Handle taxId logic
      String finalTaxId = _taxIdController.text.trim();
      if (finalTaxId.isEmpty && _idNumberController.text.trim().isNotEmpty) {
        finalTaxId = _idNumberController.text.trim();
      }

      // Step 1: Create the new customer record
      final customerId = await SupabaseService.createNewCustomerRecord(
        bisanCode: contactCode,
        businessName: _businessNameController.text.trim(),
        ownerName: _ownerNameController.text.trim(),
        responsiblePerson: _responsiblePersonController.text.trim(),
        taxId: finalTaxId,
        idNumber: _idNumberController.text.trim(),
        mobile: _mobileController.text.trim(),
        telephone: _telephoneController.text.trim(),
        email: _emailController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        stateType: _selectedStateType,
        street: _streetController.text.trim(),
        beside: _besideController.text.trim(),
        businessType: _selectedBusinessType,
        businessTypeName: _getBusinessTypeName(_selectedBusinessType ?? ''),
        visitDays: _selectedVisitDays.join(', '),
        paymentMethod: _selectedPaymentMethod,
        creditLimit: _creditLimitController.text.trim(),
        createdDate: _selectedDate,
        salesman: widget.user.salesman,
        username: widget.user.username,
      );

      print('DEBUG: New customer record created with ID: $customerId');

      // Step 2: Upload PDF
      final pdfUrl = await SupabaseService.uploadNewCustomerPdf(
        customerId: customerId,
        pdfBytes: pdfBytes,
        fileName: 'customer_info_$contactCode.pdf',
      );

      print('DEBUG: PDF uploaded to: $pdfUrl');

      // Step 3: Update the record with PDF URL
      await SupabaseService.updateNewCustomerPdfUrl(
        customerId: customerId,
        pdfUrl: pdfUrl,
      );

      // Step 4: Upload images if they exist
      if (_imageBytes.isNotEmpty) {
        print('DEBUG: Uploading ${_imageBytes.length} images');

        for (int i = 0; i < _imageBytes.length; i++) {
          final imageBytes = _imageBytes[i];
          final fileName = 'image_${i + 1}.jpg';

          // Upload image to storage
          final imageUrl = await SupabaseService.uploadNewCustomerImage(
            customerId: customerId,
            imageBytes: imageBytes,
            fileName: fileName,
          );

          print('DEBUG: Image $i uploaded to: $imageUrl');

          // Create image record
          await SupabaseService.createNewCustomerImageRecord(
            newCustomerId: customerId,
            imageUrl: imageUrl,
            imageName: fileName,
            imageSize: imageBytes.length,
            mimeType: _detectImageType(imageBytes),
          );
        }

        print('DEBUG: All images uploaded successfully');
      }

      print('DEBUG: New customer record creation completed');
    } catch (e) {
      print('ERROR: Failed to create new customer record: $e');
      // Don't throw - this is additional functionality, don't fail the whole operation
    }
  }

  /// Queue contact for offline sync
  Future<void> _queueContactForOffline(Map<String, dynamic> contactData) async {
    try {
      await _offlineService.addPendingContactOperation(
        contactData: contactData,
        userId: widget.user.id ?? widget.user.username,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _loadingMessage = 'جارٍ المعالجة...';
        });

        // Show dialog explaining what happened
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.cloud_off, color: Colors.orange, size: 32),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'تم الحفظ للمزامنة لاحقاً',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'لا يوجد اتصال بالإنترنت حالياً.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'تم حفظ بيانات العميل على جهازك وسيتم إرسالها تلقائياً عند توفر الاتصال.',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'يمكنك عرض وإدارة العمليات المعلقة من خلال الأيقونة في الأعلى',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );

        _clearForm();
        await _loadPendingCount();
      }
    } catch (e) {
      print('ERROR: Failed to queue contact: $e');
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _loadingMessage = 'جارٍ المعالجة...';
        });
        _showSnackBar('فشل في حفظ العميل: ${e.toString()}', true);
      }
    }
  }

  void _showQueuedDialog(String message, {bool hasImages = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.schedule, color: Colors.orange),
            SizedBox(width: 8),
            Text('تم الحفظ للمزامنة'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'ملاحظة هامة:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• سيتم إنشاء العميل عند توفر الاتصال',
                    style: TextStyle(fontSize: 13),
                  ),
                  const Text(
                    '• سيتم إنشاء ملف PDF تلقائياً',
                    style: TextStyle(fontSize: 13),
                  ),
                  const Text(
                    '• سيتم إرسال البريد الإلكتروني',
                    style: TextStyle(fontSize: 13),
                  ),
                  if (hasImages)
                    Text(
                      '• سيتم إرفاق ${_imageBytes.length} صورة',
                      style: const TextStyle(fontSize: 13),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showPendingOperations();
            },
            child: const Text('عرض العمليات المعلقة'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message, {bool hasPdfAndEmail = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('نجح'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (hasPdfAndEmail) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.done_all, size: 16, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'تم بنجاح:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('✓ تم إنشاء العميل',
                        style: TextStyle(fontSize: 13)),
                    const Text('✓ تم إنشاء ملف PDF',
                        style: TextStyle(fontSize: 13)),
                    const Text('✓ تم إرسال البريد الإلكتروني',
                        style: TextStyle(fontSize: 13)),
                    if (_imageBytes.isNotEmpty)
                      Text(
                        '✓ تم إرفاق ${_imageBytes.length} صورة',
                        style: const TextStyle(fontSize: 13),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('خطأ'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الرجاء:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('• التحقق من الاتصال بالإنترنت',
                      style: TextStyle(fontSize: 13)),
                  Text('• التأكد من صحة البيانات',
                      style: TextStyle(fontSize: 13)),
                  Text('• المحاولة مرة أخرى', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

// Updated _generatePdf method
  Future<Uint8List> _generatePdf(String contactCode) async {
    // Handle taxId logic for PDF
    String finalTaxId = _taxIdController.text.trim();
    if (finalTaxId.isEmpty && _idNumberController.text.trim().isNotEmpty) {
      finalTaxId = _idNumberController.text.trim();
    }

    return await PdfService.generateCustomerOpeningPdf(
        businessName: _businessNameController.text.trim(),
        ownerName: _ownerNameController.text.trim(),
        responsiblePerson: _responsiblePersonController.text.trim(),
        taxId: finalTaxId,
        idNumber: _idNumberController.text.trim(),
        mobile: _mobileController.text.trim(),
        telephone: _telephoneController.text.trim(),
        email: _emailController.text.trim(),
        state: _getCombinedLocation(), // Use combined location here
        street: _streetController.text.trim(),
        stateType: _selectedStateType ?? '',
        beside: _besideController.text.trim(),
        businessType: _getBusinessTypeName(_selectedBusinessType ?? ''),
        visitDays: _selectedVisitDays.join(', '),
        paymentMethod: _selectedPaymentMethod ?? '',
        creditLimit: _creditLimitController.text.trim(),
        date: DateFormat('dd/MM/yyyy').format(_selectedDate),
        contactCode: contactCode,
        createdBy: widget.user.username,
        salesman: widget.user.salesman);
  }

  /// Clear form and reset all fields - UPDATED VERSION
  void _clearForm() {
    _formKey.currentState?.reset();
    _businessNameController.clear();
    _ownerNameController.clear();
    _responsiblePersonController.clear();
    _taxIdController.clear();
    _idNumberController.clear();
    _mobileController.clear();
    _telephoneController.clear();
    _emailController.clear();
    _cityController.clear();
    _stateController.clear();
    _streetController.clear();
    _besideController.clear();
    _creditLimitController.clear();

    setState(() {
      _selectedStateType = null;
      _selectedBusinessType = null;
      _selectedPaymentMethod = null;
      _selectedDate = DateTime.now();
      _selectedVisitDays.clear();

      // UPDATED: Only clear _imageBytes, remove references to old variables
      _imageBytes.clear();
      _isPickingImages = false;

      // REMOVED: _selectedImages.clear()
      // REMOVED: _currentImagePickerCompleter = null
    });
  }

  /// Send email with PDF and images - UPDATED to accept images parameter
  Future<void> _sendEmail(
    String contactCode,
    Uint8List pdfBytes, {
    List<Uint8List>? images, // NEW: Optional images parameter for offline sync
  }) async {
    List<Map<String, dynamic>> attachments = [];

    // Add PDF attachment
    attachments.add({
      "name": "customer_info_$contactCode.pdf",
      "ContentBytes": base64Encode(pdfBytes),
      "contentType": "application/pdf"
    });

    // Use provided images or fall back to form images
    final imagesToSend = images ?? _imageBytes;

    print('DEBUG: Sending email with ${imagesToSend.length} images');

    // Add image attachments
    for (int i = 0; i < imagesToSend.length; i++) {
      final bytes = imagesToSend[i];

      // Generate filename with timestamp for uniqueness
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      String fileName = "image_${i + 1}_$timestamp.jpg";
      String contentType = _detectImageType(bytes);

      attachments.add({
        "name": fileName,
        "ContentBytes": base64Encode(bytes),
        "contentType": contentType
      });
    }

    // Email body
    final emailBody = """
مرحباً<br><br>
لقد تم إضافة زبون جديد بالنظام غير مفعل رقمه: $contactCode<br><br>
يرجى تفقده وعمل التعديلات اللازمة بناءً على المرفقات هنا<br><br>
تم إنشاؤه بواسطة: ${widget.user.username}<br>
التاريخ: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}<br>
عدد الصور المرفقة: ${imagesToSend.length}
""";

    await ApiService.sendEmail(
      to: "jessica.qasasfeh@jala.ps",
      subject:
          "زبون جديد - $contactCode - ${_businessNameController.text.trim()}",
      body: emailBody,
      attachments: attachments,
    );

    print('DEBUG: Email sent with PDF + ${imagesToSend.length} images');
  }

  /// Detect image type from bytes (optional helper method)
  String _detectImageType(Uint8List bytes) {
    if (bytes.length < 4) return 'image/jpeg';

    // Check PNG signature
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }

    // Check JPEG signature
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }

    // Check GIF signature
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      return 'image/gif';
    }

    // Check WebP signature
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }

    // Default to JPEG
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isMobile = size.width < 768;
    final maxWidth = isDesktop ? 700.0 : double.infinity;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _LightAppBar(
          isDesktop: isDesktop,
          isSubmitting: _isSubmitting,
          pendingCount: _pendingCount,
          onPendingTap: _showPendingOperations,
        ),
        body: Stack(
          children: [
            if (_isLoading)
              _buildLoadingState(isMobile)
            else
              _buildFormContent(maxWidth, isMobile, isDesktop),
            if (_isSubmitting) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  // OPTIMIZED: Loading state - lightweight
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
            'جارٍ التحميل...',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // OPTIMIZED: Main form content - only builds when visible
  Widget _buildFormContent(double maxWidth, bool isMobile, bool isDesktop) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info card - only on mobile
                if (PlatformUtils.isMobile) ...[
                  _buildInfoCard(isMobile),
                  SizedBox(height: isMobile ? 16 : 20),
                ],

                // Sections - built lazily
                _buildPersonalInfoSection(isMobile),
                SizedBox(height: isMobile ? 20 : 24),

                _buildAddressSection(isMobile),
                SizedBox(height: isMobile ? 20 : 24),

                _buildBusinessDetailsSection(isMobile),
                SizedBox(height: isMobile ? 20 : 24),

                _buildAdditionalInfoSection(isMobile),
                SizedBox(height: isMobile ? 20 : 24),

                _buildImageAttachments(isMobile),
                SizedBox(height: isMobile ? 20 : 24),

                _buildSummary(isMobile),
                SizedBox(height: isMobile ? 24 : 32),

                _buildActionButtons(isMobile),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // OPTIMIZED: Info card
  Widget _buildInfoCard(bool isMobile) {
    return Container(
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
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'يمكنك إضافة العملاء حتى بدون اتصال بالإنترنت. سيتم المزامنة تلقائياً عند توفر الاتصال.',
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                color: Colors.blue.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // OPTIMIZED: Personal info section
  Widget _buildPersonalInfoSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('المعلومات الشخصية', isMobile),
        SizedBox(height: isMobile ? 12 : 16),
        _buildTwoColumnRow(
          left: _buildTextField(
            controller: _businessNameController,
            label: 'اسم المحل التجاري',
            isRequired: true,
            isMobile: isMobile,
          ),
          right: _buildTextField(
            controller: _ownerNameController,
            label: 'اسم مالك المحل',
            isRequired: true,
            isMobile: isMobile,
          ),
          isMobile: isMobile,
        ),
        SizedBox(height: isMobile ? 16 : 20),
        _buildTwoColumnRow(
          left: _buildTextField(
            controller: _responsiblePersonController,
            label: 'اسم الشخص المسؤول',
            isRequired: true,
            isMobile: isMobile,
          ),
          right: _buildTextField(
            controller: _taxIdController,
            label: 'رقم المشتغل المرخص',
            keyboardType: TextInputType.number,
            isMobile: isMobile,
          ),
          isMobile: isMobile,
        ),
        SizedBox(height: isMobile ? 12 : 16),
        _buildTwoColumnRow(
          left: _buildTextField(
            controller: _idNumberController,
            label: 'رقم الهوية',
            keyboardType: TextInputType.number,
            isMobile: isMobile,
          ),
          right: _buildTextField(
            controller: _mobileController,
            label: 'خلوي',
            isRequired: true,
            keyboardType: TextInputType.phone,
            isMobile: isMobile,
          ),
          isMobile: isMobile,
        ),
        SizedBox(height: isMobile ? 12 : 16),
        _buildTwoColumnRow(
          left: _buildTextField(
            controller: _telephoneController,
            label: 'هاتف المحل',
            keyboardType: TextInputType.phone,
            isMobile: isMobile,
          ),
          right: _buildTextField(
            controller: _emailController,
            label: 'البريد الإلكتروني',
            keyboardType: TextInputType.emailAddress,
            isMobile: isMobile,
          ),
          isMobile: isMobile,
        ),
      ],
    );
  }

  // OPTIMIZED: Address section
  Widget _buildAddressSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('العنوان', isMobile),
        SizedBox(height: isMobile ? 12 : 16),
        _buildTwoColumnRow(
          left: _buildTextField(
            controller: _cityController,
            label: 'المحافظة',
            isRequired: true,
            isMobile: isMobile,
          ),
          right: _buildTextField(
            controller: _stateController,
            label: 'المنطقة',
            isRequired: true,
            isMobile: isMobile,
          ),
          isMobile: isMobile,
        ),
        SizedBox(height: isMobile ? 16 : 20),
        _buildTwoColumnRow(
          left: _buildDropdown(
            value: _selectedStateType,
            label: 'نوع المنطقة',
            items: _stateTypes,
            isRequired: true,
            onChanged: (value) => setState(() => _selectedStateType = value),
            isMobile: isMobile,
          ),
          right: _buildTextField(
            controller: _streetController,
            label: 'الشارع',
            isRequired: true,
            isMobile: isMobile,
          ),
          isMobile: isMobile,
        ),
        SizedBox(height: isMobile ? 16 : 20),
        _buildTextField(
          controller: _besideController,
          label: 'بجانب',
          isRequired: true,
          isMobile: isMobile,
        ),
      ],
    );
  }

  // OPTIMIZED: Business details section
  Widget _buildBusinessDetailsSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('تفاصيل العمل', isMobile),
        SizedBox(height: isMobile ? 12 : 16),
        _buildBusinessTypeDropdown(isMobile),
        SizedBox(height: isMobile ? 12 : 16),
        _buildVisitDaysSelector(isMobile),
        SizedBox(height: isMobile ? 16 : 20),
        _buildTwoColumnRow(
          left: _buildDropdown(
            value: _selectedPaymentMethod,
            label: 'طريقة الدفع',
            items: _paymentMethods,
            onChanged: (value) =>
                setState(() => _selectedPaymentMethod = value),
            isMobile: isMobile,
          ),
          right: _buildTextField(
            controller: _creditLimitController,
            label: 'الحد الأقصى للدين',
            keyboardType: TextInputType.number,
            isMobile: isMobile,
          ),
          isMobile: isMobile,
        ),
      ],
    );
  }

  // OPTIMIZED: Additional info section
  Widget _buildAdditionalInfoSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('معلومات إضافية', isMobile),
        SizedBox(height: isMobile ? 12 : 16),
        _buildDateSelector(isMobile),
      ],
    );
  }

  // OPTIMIZED: Two column row helper
  Widget _buildTwoColumnRow({
    required Widget left,
    required Widget right,
    required bool isMobile,
  }) {
    return Row(
      children: [
        Expanded(child: left),
        SizedBox(width: isMobile ? 12 : 16),
        Expanded(child: right),
      ],
    );
  }

  // OPTIMIZED: Lightweight text field
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isRequired = false,
    TextInputType? keyboardType,
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label + (isRequired ? ' *' : ''),
          style: TextStyle(
            fontSize: isMobile ? 14 : 16,
            fontWeight: FontWeight.w500,
            color: const Color(AppConstants.primaryColor),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textDirection: ui.TextDirection.rtl,
          style: TextStyle(fontSize: isMobile ? 12 : 14),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(AppConstants.accentColor),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'هذا الحقل مطلوب';
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  // OPTIMIZED: Lightweight dropdown
  Widget _buildDropdown({
    required String? value,
    required String label,
    required List<String> items,
    bool isRequired = false,
    required ValueChanged<String?> onChanged,
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label + (isRequired ? ' *' : ''),
          style: TextStyle(
            fontSize: isMobile ? 14 : 16,
            fontWeight: FontWeight.w500,
            color: const Color(AppConstants.primaryColor),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(
                      item,
                      textDirection: ui.TextDirection.rtl,
                      style: TextStyle(fontSize: isMobile ? 12 : 14),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(AppConstants.accentColor),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          isExpanded: true,
          validator: isRequired
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return 'هذا الحقل مطلوب';
                  }
                  return null;
                }
              : null,
        ),
      ],
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
}

// At the bottom of web_customer_opening_screen.dart

class _LightAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isDesktop;
  final bool isSubmitting;
  final int pendingCount;
  final VoidCallback onPendingTap;

  const _LightAppBar({
    required this.isDesktop,
    required this.isSubmitting,
    required this.pendingCount,
    required this.onPendingTap,
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
        onPressed: isSubmitting ? null : () => Navigator.pop(context),
      ),
      title: const Text(
        'فتح زبون جديد',
        style: TextStyle(
          color: Color(AppConstants.primaryColor),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        // Pending operations badge - only show on mobile
        if (PlatformUtils.isMobile && pendingCount > 0)
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.sync_problem,
                  color: Color(AppConstants.primaryColor),
                ),
                onPressed: isSubmitting ? null : onPendingTap,
                tooltip: 'عرض العمليات المعلقة',
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    pendingCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
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
