// lib/widgets/pending_operations_dialog.dart
// UI for managing pending contact operations with edit/delete options

import 'package:flutter/material.dart';
import 'package:jala_as/services/local_database_service.dart';
import '../services/offline_contact_service.dart';

class PendingOperationsDialog extends StatefulWidget {
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)
      apiCreateFunction;

  const PendingOperationsDialog({
    Key? key,
    required this.apiCreateFunction,
  }) : super(key: key);

  @override
  State<PendingOperationsDialog> createState() =>
      _PendingOperationsDialogState();
}

class _PendingOperationsDialogState extends State<PendingOperationsDialog> {
  final OfflineContactService _offlineService = OfflineContactService();
  bool _isLoading = false;
  bool _isSyncing = false;
  List<PendingContactOperation> _pendingOps = [];
  List<PendingContactOperation> _failedOps = [];
  Map<String, int> _counts = {};

  @override
  void initState() {
    super.initState();
    _loadOperations();
  }

  Future<void> _loadOperations() async {
    setState(() => _isLoading = true);

    try {
      final pending = await _offlineService.getPendingOperations();
      final failed = await _offlineService.getFailedOperations();
      final counts = await _offlineService.getOperationCounts();

      setState(() {
        _pendingOps = pending;
        _failedOps = failed;
        _counts = counts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('خطأ في تحميل العمليات المعلقة: $e');
    }
  }

  Future<void> _syncAll() async {
    setState(() => _isSyncing = true);

    try {
      final results = await _offlineService.syncPendingContacts(
        apiCreateFunction: widget.apiCreateFunction,
      );

      // Show results
      final successCount = results.where((r) => r.success).length;
      final failCount = results.where((r) => !r.success).length;

      if (mounted) {
        _showSuccess(
          'تمت المزامنة:\n'
          '✓ نجح: $successCount\n'
          '✗ فشل: $failCount',
        );

        // Reload operations
        await _loadOperations();
      }
    } catch (e) {
      _showError('خطأ في المزامنة: $e');
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _retryOperation(PendingContactOperation operation) async {
    try {
      final result = await _offlineService.retryFailedOperation(
        operationId: operation.id!,
        apiCreateFunction: widget.apiCreateFunction,
      );

      if (result.success) {
        _showSuccess(result.message);
        await _loadOperations();
      } else {
        _showErrorDetails(
          operation: operation,
          message: result.message,
          errorDetails: result.errorDetails,
        );
      }
    } catch (e) {
      _showError('خطأ في إعادة المحاولة: $e');
    }
  }

  Future<void> _editOperation(PendingContactOperation operation) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditContactDialog(
        contactData: operation.contactData,
      ),
    );

    if (result != null) {
      final success = await _offlineService.updatePendingContactData(
        operationId: operation.id!,
        newContactData: result,
      );

      if (success) {
        _showSuccess('تم تحديث البيانات بنجاح');
        await _loadOperations();
      } else {
        _showError('فشل تحديث البيانات');
      }
    }
  }

  Future<void> _deleteOperation(PendingContactOperation operation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد حذف هذه العملية؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success =
          await _offlineService.deletePendingOperation(operation.id!);
      if (success) {
        _showSuccess('تم حذف العملية');
        await _loadOperations();
      } else {
        _showError('فشل حذف العملية');
      }
    }
  }

  void _showErrorDetails({
    required PendingContactOperation operation,
    required String message,
    String? errorDetails,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خطأ في المزامنة'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (errorDetails != null) ...[
                const SizedBox(height: 8),
                const Text('تفاصيل الخطأ:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(errorDetails),
              ],
              const SizedBox(height: 16),
              const Text('ماذا تريد أن تفعل؟'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _editOperation(operation);
            },
            child: const Text('تعديل البيانات'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteOperation(operation);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف العملية'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sync, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text(
                    'العمليات المعلقة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Stats
            if (!_isLoading) ...[
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[100],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatCard(
                      label: 'قيد الانتظار',
                      count: _counts['pending'] ?? 0,
                      color: Colors.orange,
                    ),
                    _StatCard(
                      label: 'فشلت',
                      count: _counts['failed'] ?? 0,
                      color: Colors.red,
                    ),
                    _StatCard(
                      label: 'الإجمالي',
                      count: _counts['total'] ?? 0,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
            ],

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _pendingOps.isEmpty && _failedOps.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle,
                                  size: 64, color: Colors.green),
                              SizedBox(height: 16),
                              Text('لا توجد عمليات معلقة',
                                  style: TextStyle(fontSize: 16)),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Failed operations first
                            if (_failedOps.isNotEmpty) ...[
                              const Text(
                                'عمليات فشلت (تحتاج إلى مراجعة)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._failedOps.map(
                                (op) => _OperationCard(
                                  operation: op,
                                  onRetry: () => _retryOperation(op),
                                  onEdit: () => _editOperation(op),
                                  onDelete: () => _deleteOperation(op),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Pending operations
                            if (_pendingOps.isNotEmpty) ...[
                              const Text(
                                'عمليات قيد الانتظار',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._pendingOps.map(
                                (op) => _OperationCard(
                                  operation: op,
                                  onRetry: () => _retryOperation(op),
                                  onEdit: () => _editOperation(op),
                                  onDelete: () => _deleteOperation(op),
                                ),
                              ),
                            ],
                          ],
                        ),
            ),

            // Footer with sync button
            if (_pendingOps.isNotEmpty || _failedOps.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSyncing ? null : _syncAll,
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.sync),
                    label:
                        Text(_isSyncing ? 'جاري المزامنة...' : 'مزامنة الكل'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class _OperationCard extends StatelessWidget {
  final PendingContactOperation operation;
  final VoidCallback onRetry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _OperationCard({
    required this.operation,
    required this.onRetry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isFailed = operation.status == 'failed';
    final contactName = operation.getContactName(); // Use new method

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isFailed ? Colors.red[50] : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isFailed ? Icons.error : Icons.pending,
                  color: isFailed ? Colors.red : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    contactName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (operation.retryCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'محاولة ${operation.retryCount}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'تاريخ الإنشاء: ${_formatDate(operation.createdAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (isFailed && operation.errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'خطأ: ${operation.getUserFriendlyError()}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('حذف'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('تعديل'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Dialog for editing contact data
class EditContactDialog extends StatefulWidget {
  final Map<String, dynamic> contactData;

  const EditContactDialog({
    Key? key,
    required this.contactData,
  }) : super(key: key);

  @override
  State<EditContactDialog> createState() => _EditContactDialogState();
}

class _EditContactDialogState extends State<EditContactDialog> {
  late Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {};

    // Create controllers for each field
    widget.contactData.forEach((key, value) {
      if (value != null) {
        _controllers[key] = TextEditingController(text: value.toString());
      }
    });
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Map<String, dynamic> _getUpdatedData() {
    final updated = <String, dynamic>{};
    _controllers.forEach((key, controller) {
      updated[key] = controller.text;
    });
    return updated;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'تعديل بيانات العميل',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: _controllers.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: entry.value,
                      decoration: InputDecoration(
                        labelText: _getFieldLabel(entry.key),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _getUpdatedData()),
                  child: const Text('حفظ'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getFieldLabel(String key) {
    // Map English keys to Arabic labels
    const labels = {
      'name': 'الاسم',
      'code': 'الكود',
      'phone': 'الهاتف',
      'email': 'البريد الإلكتروني',
      'address': 'العنوان',
      'city': 'المدينة',
      'taxNumber': 'الرقم الضريبي',
    };
    return labels[key] ?? key;
  }
}
