// lib/screens/create_contact_screen.dart
// Example screen showing how to use offline contact creation

import 'package:flutter/material.dart';
import 'package:jala_as/services/offline_contact_service.dart';
import 'package:jala_as/widgets/pending_operations_dialog.dart';

import 'dart:convert';

class CreateContactScreen extends StatefulWidget {
  const CreateContactScreen({Key? key}) : super(key: key);

  @override
  State<CreateContactScreen> createState() => _CreateContactScreenState();
}

class _CreateContactScreenState extends State<CreateContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _offlineService = OfflineContactService();

  // Form controllers
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _taxNumberController = TextEditingController();

  bool _isSubmitting = false;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _taxNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingCount() async {
    final counts = await _offlineService.getOperationCounts();
    setState(() {
      _pendingCount = counts['total'] ?? 0;
    });
  }

  Future<void> _showPendingOperations() async {
    await showDialog(
      context: context,
      builder: (context) => PendingOperationsDialog(
        apiCreateFunction: _apiCreateContact,
      ),
    );
    // Reload count after dialog closes
    await _loadPendingCount();
  }

  Future<Map<String, dynamic>> _apiCreateContact(
      Map<String, dynamic> contactData) async {
    // Your actual API call from BisanService.createContact
    const String createContactUrl = 'https://gw.bisan.com/api/v2/jalaf/contact';

    // Simulate API call - replace with your actual implementation
    final response = await _makeApiRequest(
      url: createContactUrl,
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: contactData,
    );

    return response;
  }

  Future<Map<String, dynamic>> _makeApiRequest({
    required String url,
    required String method,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
  }) async {
    // TODO: Replace this with your actual API implementation
    // This is just a placeholder

    // Example implementation:
    // final response = await http.post(
    //   Uri.parse(url),
    //   headers: headers,
    //   body: jsonEncode(body),
    // );
    //
    // if (response.statusCode == 200 || response.statusCode == 201) {
    //   return jsonDecode(response.body);
    // } else {
    //   throw Exception('API Error: ${response.statusCode} - ${response.body}');
    // }

    // For now, simulate success (remove this in production)
    await Future.delayed(const Duration(seconds: 1));
    return {'success': true, 'id': '12345', ...body};
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Prepare contact data
      final contactData = {
        'name': _nameController.text.trim(),
        'code': _codeController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'taxNumber': _taxNumberController.text.trim(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Get current user ID (from your auth service)
      final userId = await _getCurrentUserId();

      // Create contact with offline support
      final result = await _offlineService.createContact(
        contactData: contactData,
        userId: userId,
        apiCreateFunction: _apiCreateContact,
      );

      if (mounted) {
        if (result['success']) {
          // Check if it was queued or created immediately
          if (result['isQueued'] == true) {
            _showQueuedDialog(result['message']);
          } else {
            _showSuccessDialog(result['message']);
          }

          // Clear form
          _clearForm();

          // Update pending count
          await _loadPendingCount();
        } else {
          _showErrorDialog(result['message']);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('خطأ غير متوقع: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _clearForm() {
    _nameController.clear();
    _codeController.clear();
    _phoneController.clear();
    _emailController.clear();
    _addressController.clear();
    _taxNumberController.clear();
  }

  Future<String> _getCurrentUserId() async {
    // TODO: Get from your auth service
    // Example: return AuthService().currentUser?.id ?? 'unknown';
    return 'user_123'; // Placeholder
  }

  void _showSuccessDialog(String message) {
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
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showQueuedDialog(String message) {
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
            const SizedBox(height: 16),
            const Text(
              'سيتم مزامنة البيانات تلقائياً عند توفر الاتصال بالإنترنت.',
              style: TextStyle(fontSize: 12),
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
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة عميل جديد'),
        actions: [
          // Pending operations badge
          if (_pendingCount > 0)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.sync_problem),
                  onPressed: _showPendingOperations,
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
                      _pendingCount.toString(),
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
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info card about offline support
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'يمكنك إضافة العملاء حتى بدون اتصال بالإنترنت. سيتم المزامنة تلقائياً عند توفر الاتصال.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Form fields
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم العميل *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'الرجاء إدخال اسم العميل';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'كود العميل *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'الرجاء إدخال كود العميل';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'العنوان',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _taxNumberController,
              decoration: const InputDecoration(
                labelText: 'الرقم الضريبي',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance),
              ),
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                child: _isSubmitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('جاري الحفظ...'),
                        ],
                      )
                    : const Text(
                        'حفظ العميل',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),

            // View pending operations button
            if (_pendingCount > 0) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _showPendingOperations,
                icon: const Icon(Icons.list),
                label: Text('عرض العمليات المعلقة ($_pendingCount)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
