// lib/screens/mobile/sales_return_form_screen.dart - UPDATED WITH SEARCHABLE DROPDOWNS

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jala_as/models/contact.dart';
import 'package:jala_as/models/returns_models.dart';
import 'package:jala_as/models/user.dart';
import 'package:jala_as/screens/web/widgets/item_picker_dialog.dart';
import 'package:jala_as/screens/web/widgets/searchable_dropdown.dart';
import 'package:jala_as/services/api_service.dart';
import 'package:jala_as/services/local_database_service.dart';
import 'package:jala_as/services/pdf_service.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/helpers.dart';
import 'package:jala_as/utils/platform_utils.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

class SalesReturnFormScreen extends StatefulWidget {
  final AppUser user;

  const SalesReturnFormScreen({
    super.key,
    required this.user,
  });

  @override
  State<SalesReturnFormScreen> createState() => _SalesReturnFormScreenState();
}

class _SalesReturnFormScreenState extends State<SalesReturnFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  Contact? _selectedContact;
  ReturnReason? _selectedReturnReason;
  List<ReturnItem> _returnItems = [];

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isOnline = true;
  bool _isFetchingPrices = false;

  List<Contact> _contacts = [];
  List<Warehouse> _warehouses = [];
  List<Item> _items = [];
  final List<ReturnReason> _returnReasons = ReturnReason.getReturnReasons();

  // Store items without prices for validation
  Set<String> _itemsWithoutPrices = {};

  static const _primaryColor = Color(0xFF135467);
  late final BorderRadius _borderRadius;
  late final BoxDecoration _fieldDecoration;

  @override
  void initState() {
    super.initState();
    _initializeStyles();
    _initializeData();
  }

  void _initializeStyles() {
    _borderRadius = BorderRadius.circular(12);
    _fieldDecoration = BoxDecoration(
      color: Colors.white,
      borderRadius: _borderRadius,
      border: Border.all(color: Colors.grey.shade300),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    try {
      if (PlatformUtils.isMobile) {
        _isOnline = await _checkConnectivity();
        if (_isOnline) {
          await _loadOnlineData();
        } else {
          await _loadOfflineData();
        }
      } else {
        await _loadOnlineData();
      }
    } catch (e) {
      if (mounted) {
        Helpers.showApiErrorDialog(context, e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> _loadOnlineData() async {
    final results = await Future.wait([
      // UPDATED: Get all contacts instead of filtered by user
      SupabaseService.getContactsWithoutFreeze(), // This gets ALL contacts
      SupabaseService.getWarehouses(),
      SupabaseService.getItems(),
    ]);

    _contacts = results[0] as List<Contact>;
    _warehouses = results[1] as List<Warehouse>;
    _items = results[2] as List<Item>;

    if (PlatformUtils.isMobile) {
      await _cacheData();
    }
  }

  Future<void> _loadOfflineData() async {
    final db = LocalDatabaseService();

    final results = await Future.wait([
      db.getCachedData(dataType: 'contacts', dataKey: widget.user.id),
      db.getCachedData(dataType: 'warehouses', dataKey: 'all'),
      db.getCachedData(dataType: 'items', dataKey: 'all'),
    ]);

    if (results[0] != null) {
      _contacts = (results[0]!['data'] as List)
          .map((json) => Contact.fromJson(json))
          .toList();
    }

    if (results[1] != null) {
      _warehouses = (results[1]!['data'] as List)
          .map((json) => Warehouse.fromJson(json))
          .toList();
    }

    if (results[2] != null) {
      _items = (results[2]!['data'] as List)
          .map((json) => Item.fromJson(json))
          .toList();
    }
  }

  Future<void> _cacheData() async {
    final db = LocalDatabaseService();

    await Future.wait([
      db.saveCachedData(
        dataType: 'contacts',
        dataKey: widget.user.id,
        data: {'data': _contacts.map((c) => c.toJson()).toList()},
      ),
      db.saveCachedData(
        dataType: 'warehouses',
        dataKey: 'all',
        data: {'data': _warehouses.map((w) => w.toJson()).toList()},
      ),
      db.saveCachedData(
        dataType: 'items',
        dataKey: 'all',
        data: {'data': _items.map((i) => i.toJson()).toList()},
      ),
    ]);
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ar'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showItemPicker() async {
    final selectedItem = await showDialog<Item>(
      context: context,
      builder: (context) => ItemPickerDialog(items: _items),
    );

    if (selectedItem != null) {
      final quantity = await _showQuantityDialog();
      if (quantity != null && quantity > 0) {
        setState(() {
          _returnItems.add(ReturnItem(
            itemCode: selectedItem.code,
            itemName: selectedItem.nameAr,
            quantity: quantity,
            unit: selectedItem.getPrimaryUnit(),
            price: 0, // Will be fetched later
          ));
        });

        // Fetch prices after adding item
        if (_selectedContact != null) {
          await _fetchPricesForAllItems();
        }
      }
    }
  }

  Future<double?> _showQuantityDialog() async {
    final controller = TextEditingController(text: '1');

    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'أدخل الكمية',
          textDirection: ui.TextDirection.rtl,
          style: TextStyle(fontSize: 13),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textDirection: ui.TextDirection.rtl,
          decoration: const InputDecoration(
            labelText: 'الكمية',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = double.tryParse(controller.text);
              Navigator.pop(context, quantity);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _editItemQuantity(int index) async {
    final currentItem = _returnItems[index];
    final controller = TextEditingController(
      text: currentItem.quantity.toString(),
    );

    final newQuantity = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'تعديل كمية ${currentItem.itemName}',
          textDirection: ui.TextDirection.rtl,
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textDirection: ui.TextDirection.rtl,
          decoration: const InputDecoration(
            labelText: 'الكمية',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = double.tryParse(controller.text);
              Navigator.pop(context, quantity);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (newQuantity != null && newQuantity > 0) {
      setState(() {
        _returnItems[index] = currentItem.copyWith(quantity: newQuantity);
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      final item = _returnItems[index];
      _returnItems.removeAt(index);
      _itemsWithoutPrices.remove(item.itemCode);
    });
  }

  /// Fetch prices for all items in the return
  Future<void> _fetchPricesForAllItems() async {
    if (_selectedContact == null || _returnItems.isEmpty) return;

    setState(() {
      _isFetchingPrices = true;
      _itemsWithoutPrices.clear();
    });

    try {
      final itemCodes = _returnItems.map((item) => item.itemCode!).toList();

      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'جاري جلب الأسعار...',
                  style: TextStyle(fontSize: 14),
                  textDirection: ui.TextDirection.rtl,
                ),
              ],
            ),
          ),
        ),
      );

      final prices = await ApiService.getLastItemPrices(
        contactCode: _selectedContact!.code,
        itemCodes: itemCodes,
      );

      // Close progress dialog
      if (mounted) Navigator.pop(context);

      // Update items with fetched prices
      setState(() {
        for (int i = 0; i < _returnItems.length; i++) {
          final itemCode = _returnItems[i].itemCode!;
          final price = prices[itemCode];

          if (price == null || price <= 0) {
            _itemsWithoutPrices.add(itemCode);
          }

          _returnItems[i] = _returnItems[i].copyWith(
            price: price ?? 0,
          );
        }
      });

      // Show warning if some items don't have prices
      if (_itemsWithoutPrices.isNotEmpty) {
        _showPriceWarningDialog();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        Helpers.showApiErrorDialog(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingPrices = false);
      }
    }
  }

  void _showPriceWarningDialog() {
    final itemsWithoutPrices = _returnItems
        .where((item) => _itemsWithoutPrices.contains(item.itemCode))
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'تحذير - أصناف بدون سعر',
          textDirection: ui.TextDirection.rtl,
          style: TextStyle(color: Colors.orange),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الأصناف التالية لم يتم بيعها لهذا الدليل من قبل:',
              textDirection: ui.TextDirection.rtl,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...itemsWithoutPrices.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${item.itemName} (${item.itemCode})',
                          textDirection: ui.TextDirection.rtl,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
            const Text(
              'سيتم إرسال هذه الأصناف بدون سعر. يمكنك حذفها أو الاستمرار.',
              textDirection: ui.TextDirection.rtl,
              style: TextStyle(fontSize: 12, color: Colors.grey),
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

  Future<void> _submitReturn() async {
    if (!_formKey.currentState!.validate()) {
      Helpers.showSnackBar(context, 'يرجى تعبئة جميع الحقول المطلوبة',
          isError: true);
      return;
    }

    final validations = [
      (_selectedContact == null, 'يرجى اختيار الدليل'),
      (_selectedReturnReason == null, 'يرجى اختيار سبب الإرجاع'),
      (_returnItems.isEmpty, 'يرجى إضافة صنف واحد على الأقل'),
    ];

    for (final (condition, message) in validations) {
      if (condition) {
        Helpers.showSnackBar(context, message, isError: true);
        return;
      }
    }

    // Fetch prices before submitting
    if (_selectedContact != null && !_isFetchingPrices) {
      await _fetchPricesForAllItems();
    }

    setState(() => _isSubmitting = true);

    try {
      if (_isOnline) {
        await _submitOnline();
      } else {
        await _submitOffline();
      }
    } catch (e) {
      if (mounted) {
        Helpers.showApiErrorDialog(context, e);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitOnline() async {
    // Validate that all items have prices
    final itemsWithoutPrices =
        _returnItems.where((item) => item.price <= 0).toList();
    if (itemsWithoutPrices.isNotEmpty) {
      final shouldContinue =
          await _showPriceValidationDialog(itemsWithoutPrices);
      if (!shouldContinue) {
        return; // User chose not to continue
      }
    }

    // Get automatic warehouse based on return reason
    final warehouseCode =
        _selectedReturnReason!.getWarehouseCode(widget.user.salesman);

    print('DEBUG: Automatic warehouse code: $warehouseCode');
    print('DEBUG: User salesman: ${widget.user.salesman}');
    print('DEBUG: Return reason: ${_selectedReturnReason!.code}');

    final orderDetails =
        _returnItems.map((item) => item.toOrderDetail()).toList();

    final bisanResponse = await ApiService.submitSalesReturn(
      contactCode: _selectedContact!.code,
      warehouseCode: warehouseCode,
      returnReasonCode: _selectedReturnReason!.code,
      comment: _commentController.text.trim(),
      username: widget.user.username,
      orderDetails: orderDetails,
    );

    final returnCode = bisanResponse?['rows']?['code'] as String? ??
        DateTime.now().millisecondsSinceEpoch.toString();

    // Save to Supabase
    await SupabaseService.createSalesReturn(
      returnCode: returnCode,
      contactCode: _selectedContact!.code,
      contactName: _selectedContact!.nameAr,
      returnDate: _selectedDate,
      returnReasonCode: _selectedReturnReason!.code,
      returnReasonName: _selectedReturnReason!.nameAr,
      warehouseCode: warehouseCode,
      warehouseName: _getWarehouseName(warehouseCode),
      comment: _commentController.text.trim(),
      items: _returnItems,
      bisanResponse: bisanResponse,
      transactionId: returnCode,
    );

    await _generateAndShowPdf(returnCode, warehouseCode);

    if (mounted) {
      Helpers.showSnackBar(context, 'تم حفظ المرتجع بنجاح');
      Navigator.pop(context, true);
    }
  }

  Future<bool> _showPriceValidationDialog(
      List<ReturnItem> itemsWithoutPrices) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              'تحذير - أصناف بدون سعر',
              textDirection: ui.TextDirection.rtl,
              style: TextStyle(color: Colors.orange),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الأصناف التالية ليس لها سعر:',
                  textDirection: ui.TextDirection.rtl,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...itemsWithoutPrices.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.warning,
                              color: Colors.orange, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${item.itemName} (${item.itemCode})',
                              textDirection: ui.TextDirection.rtl,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 12),
                const Text(
                  'هل تريد المتابعة وحفظ المرتجع بدون أسعار لهذه الأصناف؟',
                  textDirection: ui.TextDirection.rtl,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: const Text('متابعة'),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _getWarehouseName(String warehouseCode) {
    // Try to find warehouse in the list
    try {
      final warehouse = _warehouses.firstWhere(
        (w) => w.code == warehouseCode,
      );
      return warehouse.nameAr;
    } catch (e) {
      // Generate name based on code
      if (warehouseCode.startsWith('1')) {
        return 'مخزن الصالح - ${warehouseCode.substring(1)}';
      } else if (warehouseCode.startsWith('2')) {
        return 'مخزن التالف - ${warehouseCode.substring(1)}';
      }
      return warehouseCode;
    }
  }

  Future<void> _submitOffline() async {
    final db = LocalDatabaseService();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    // Get automatic warehouse
    final warehouseCode =
        _selectedReturnReason!.getWarehouseCode(widget.user.salesman);

    // Generate a temporary return code for offline storage
    final returnCode = 'OFFLINE_$timestamp';

    await db.addPendingOperation(
      operationType: 'sales_return',
      endpoint: 'https://gw.bisan.com/api/v2/jalaf/salesReturn',
      method: 'POST',
      data: {
        'return_code': returnCode,
        'contact_code': _selectedContact!.code,
        'contact_name': _selectedContact!.nameAr,
        'doc_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'warehouse_code': warehouseCode,
        'warehouse_name': _getWarehouseName(warehouseCode),
        'return_reason_code': _selectedReturnReason!.code,
        'return_reason_name': _selectedReturnReason!.nameAr,
        'comment': _commentController.text.trim(),
        'items': _returnItems.map((item) => item.toJson()).toList(),
        'username': widget.user.username,
        'timestamp': timestamp,
        'is_offline': true, // Mark as offline for later sync
      },
      userId: widget.user.id,
    );

    // Also create a local Supabase record for consistency
    try {
      await SupabaseService.createSalesReturn(
        returnCode: returnCode,
        contactCode: _selectedContact!.code,
        contactName: _selectedContact!.nameAr,
        returnDate: _selectedDate,
        returnReasonCode: _selectedReturnReason!.code,
        returnReasonName: _selectedReturnReason!.nameAr,
        warehouseCode: warehouseCode,
        warehouseName: _getWarehouseName(warehouseCode),
        comment: _commentController.text.trim(),
        items: _returnItems,
        bisanResponse: null, // No Bisan response for offline
        transactionId: returnCode,
      );
    } catch (e) {
      print('Warning: Could not save to Supabase offline: $e');
      // Continue anyway since it's saved in local database
    }

    if (mounted) {
      Helpers.showSnackBar(context, 'تم حفظ المرتجع للمزامنة عند توفر الاتصال');
      Navigator.pop(context, true);
    }
  }

  Future<void> _generateAndShowPdf(
      String returnCode, String warehouseCode) async {
    try {
      final pdfBytes = await PdfService.generateSalesReturnPdf(
        returnCode: returnCode,
        contactCode: _selectedContact!.code,
        contactName: _selectedContact!.nameAr,
        returnDate: DateFormat('dd/MM/yyyy').format(_selectedDate),
        returnReasonName: _selectedReturnReason!.nameAr,
        warehouseCode: warehouseCode,
        warehouseName: _getWarehouseName(warehouseCode),
        items: _returnItems,
        username: widget.user.username,
        comment: _commentController.text.trim(),
        paperWidth: 80,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title:
              const Text('ملف PDF جاهز', textDirection: ui.TextDirection.rtl),
          content: const Text('ماذا تريد أن تفعل بملف PDF؟',
              textDirection: ui.TextDirection.rtl),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _sharePdf(pdfBytes, returnCode);
              },
              child: const Text('مشاركة'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _printPdf(pdfBytes);
              },
              child: const Text('طباعة'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في إنشاء ملف PDF', isError: true);
      }
    }
  }

  Future<void> _sharePdf(Uint8List pdfBytes, String returnCode) async {
    try {
      final tempDir = await Directory.systemTemp.createTemp();
      final file = File('${tempDir.path}/return_$returnCode.pdf');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'مرتجع مبيعات - $returnCode',
      );
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في مشاركة ملف PDF', isError: true);
      }
    }
  }

  Future<void> _printPdf(Uint8List pdfBytes) async {
    try {
      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في طباعة ملف PDF', isError: true);
      }
    }
  }

  // UI Methods
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: _buildAppBar(),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _primaryColor))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('التاريخ'),
                      const SizedBox(height: 8),
                      _buildDateField(),
                      const SizedBox(height: 20),
                      _buildSectionTitle('الدليل'),
                      const SizedBox(height: 8),
                      _buildContactField(),
                      const SizedBox(height: 20),
                      _buildSectionTitle('سبب الإرجاع'),
                      const SizedBox(height: 8),
                      _buildReturnReasonField(),
                      // Show warehouse info after reason is selected
                      if (_selectedReturnReason != null) ...[
                        const SizedBox(height: 12),
                        _buildWarehouseInfoCard(),
                      ],
                      const SizedBox(height: 20),
                      _buildSectionTitle('الأصناف'),
                      const SizedBox(height: 8),
                      _buildItemsList(),
                      const SizedBox(height: 12),
                      _buildAddItemButton(),
                      const SizedBox(height: 20),
                      _buildSectionTitle('ملاحظة (اختياري)'),
                      const SizedBox(height: 8),
                      _buildCommentField(),
                      const SizedBox(height: 32),
                      _buildSubmitButton(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

// Add this new method to show the automatic warehouse selection
  Widget _buildWarehouseInfoCard() {
    final warehouseCode =
        _selectedReturnReason!.getWarehouseCode(widget.user.salesman);
    final warehouseName = _getWarehouseName(warehouseCode);
    final isDamaged = _selectedReturnReason!.isDamagedReason;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDamaged ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: _borderRadius,
        border: Border.all(
          color: isDamaged ? Colors.orange.shade200 : Colors.green.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDamaged ? Colors.orange.shade100 : Colors.green.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.warehouse_outlined,
              color: isDamaged ? Colors.orange.shade700 : Colors.green.shade700,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المخزن (تلقائي)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$warehouseCode - $warehouseName',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDamaged
                        ? Colors.orange.shade700
                        : Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDamaged ? Colors.orange.shade100 : Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isDamaged ? 'تالف' : 'صالح',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color:
                    isDamaged ? Colors.orange.shade700 : Colors.green.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      title: const Text(
        'مرتجع مبيعات',
        style: TextStyle(
          color: _primaryColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: _primaryColor),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (!_isOnline)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off,
                        size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'غير متصل',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: _primaryColor,
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _fieldDecoration,
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: _primaryColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                DateFormat('dd/MM/yyyy', 'ar').format(_selectedDate),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildContactField() {
    return SearchableDropdown<Contact>(
      labelText: 'الدليل',
      hintText: 'اختر الدليل',
      value: _selectedContact,
      items: _contacts
          .map((contact) => DropdownMenuItem(
                value: contact,
                child: Text(
                  '${contact.code} - ${contact.nameAr}',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      getLabel: (contact) => '${contact.code} - ${contact.nameAr}',
      onChanged: (value) => setState(() => _selectedContact = value),
    );
  }

  Widget _buildReturnReasonField() {
    return SearchableDropdown<ReturnReason>(
      labelText: 'سبب الإرجاع',
      hintText: 'اختر سبب الإرجاع',
      value: _selectedReturnReason,
      items: _returnReasons
          .map((reason) => DropdownMenuItem(
                value: reason,
                child: Text(
                  reason.nameAr,
                  style: const TextStyle(fontSize: 13),
                ),
              ))
          .toList(),
      getLabel: (reason) => reason.nameAr,
      onChanged: (value) => setState(() => _selectedReturnReason = value),
    );
  }

  Widget _buildItemsList() {
    if (_returnItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: _fieldDecoration,
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'لا توجد أصناف',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: _fieldDecoration,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _returnItems.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final item = _returnItems[index];
          return _ReturnItemTile(
            index: index,
            item: item,
            onEdit: () => _editItemQuantity(index),
            onDelete: () => _removeItem(index),
          );
        },
      ),
    );
  }

  Widget _buildAddItemButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showItemPicker,
        icon: const Icon(Icons.add),
        label: const Text(
          'إضافة صنف',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: _borderRadius,
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentField() {
    return Container(
      decoration: _fieldDecoration,
      child: TextFormField(
        controller: _commentController,
        maxLines: 4,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.all(16),
          border: InputBorder.none,
          hintText: 'أدخل ملاحظة...',
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitReturn,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: _borderRadius),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'حفظ المرتجع',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

// Separate widget for return item tile to reduce rebuilds
class _ReturnItemTile extends StatelessWidget {
  final int index;
  final ReturnItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReturnItemTile({
    required this.index,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF135467).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF135467),
            ),
          ),
        ),
      ),
      title: Text(
        item.itemName ?? item.itemCode ?? '',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        'الكمية: ${item.quantity.toStringAsFixed(2)} ${item.unit ?? ""}',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            color: const Color(0xFF135467),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 20),
            color: Colors.red,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
