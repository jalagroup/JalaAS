// lib/screens/fuel_filling_form_screen.dart - UPDATED with Fuel Contacts

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jala_as/models/fuel_models.dart';
import 'package:jala_as/services/connectivity_service.dart';
import 'package:jala_as/services/fuel_cache_service.dart';
import 'package:jala_as/services/fuel_service.dart';
import 'package:jala_as/services/image_upload_service.dart';
import 'package:jala_as/utils/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

class FuelFillingFormScreen extends StatefulWidget {
  const FuelFillingFormScreen({Key? key}) : super(key: key);

  @override
  State<FuelFillingFormScreen> createState() => _FuelFillingFormScreenState();
}

class _FuelFillingFormScreenState extends State<FuelFillingFormScreen> {
  // Services
  late final FuelService _fuelService;
  late final ConnectivityService _connectivityService;
  late final ImageUploadService _imageService;

  // Form state
  List<AssignCostCenter> _assignedCostCenters = [];
  List<AssignCostCenter> _filteredTruckNumbers = [];
  List<FuelContact> _fuelContacts = []; // NEW
  List<FuelContact> _filteredFuelContacts = []; // NEW

  bool _isLoading = true;
  bool _isOnline = false;
  int _pendingCount = 0;
  String _connectivityType = 'Unknown';

  // Form controllers
  AssignCostCenter? _selectedCostCenter;
  FuelContact? _selectedFuelContact; // NEW

  late final TextEditingController _amountController;
  late final TextEditingController _quantityController;
  late final TextEditingController _meterReadingController;
  late final TextEditingController _truckSearchController;
  late final TextEditingController _dropdownSearchController;
  late final TextEditingController _fuelContactSearchController; // NEW

  DateTime _selectedDate = DateTime.now();

  // Image handling
  File? _selectedImage;
  bool _isUploadingImage = false;

  // Connectivity subscription
  StreamSubscription<bool>? _connectivitySubscription;

  // UI state
  bool _showTruckDropdown = false;
  bool _showFuelContactDropdown = false; // NEW
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // AdBlue option
  bool _isAdBlueFilling = false;
  static const int ADBLUE_FUEL_TYPE_ID = 3;

  // Cached styles
  static const _primaryColor = Color(AppConstants.primaryColor);
  late final InputDecoration _baseInputDecoration;
  late final TextStyle _labelStyle;
  late final TextStyle _inputStyle;
  late final BoxDecoration _cardDecoration;
  late final BorderRadius _borderRadius;

  // Debounce timer
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeStyles();
    _initializeServices();
  }

  void _initializeControllers() {
    _amountController = TextEditingController();
    _quantityController = TextEditingController();
    _meterReadingController = TextEditingController();
    _truckSearchController = TextEditingController();
    _dropdownSearchController = TextEditingController();
    _fuelContactSearchController = TextEditingController(); // NEW
  }

  void _initializeStyles() {
    _borderRadius = BorderRadius.circular(8);

    _baseInputDecoration = InputDecoration(
      border: OutlineInputBorder(
        borderRadius: _borderRadius,
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: _borderRadius,
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );

    _labelStyle = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: _primaryColor,
    );

    _inputStyle = const TextStyle(fontSize: 16);

    _cardDecoration = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Future<void> _initializeServices() async {
    _fuelService = FuelService();
    _connectivityService = ConnectivityService();
    _imageService = ImageUploadService();

    await _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _fuelService.initialize();
      _isOnline = _connectivityService.isOnline;
      _connectivityType = await _connectivityService.getConnectivityType();

      await Future.wait([
        _loadAssignedCostCenters(),
        _loadFuelContacts(), // NEW
        _refreshPendingCount(),
      ]);

      _connectivitySubscription = _connectivityService.connectivityStream
          .listen(_onConnectivityChanged);
    } catch (e) {
      _showSnackBar('خطأ في التهيئة: $e', backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onConnectivityChanged(bool isOnline) async {
    if (!mounted) return;

    setState(() => _isOnline = isOnline);
    _connectivityType = await _connectivityService.getConnectivityType();

    if (isOnline) {
      _showSnackBar('🌐 تم الاتصال بالإنترنت - جاري المزامنة...',
          backgroundColor: Colors.green);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        await Future.wait([
          _refreshPendingCount(),
          _loadAssignedCostCenters(),
          _loadFuelContacts(), // NEW
        ]);
      }
    } else {
      _showSnackBar('📴 انقطع الاتصال - سيتم حفظ البيانات محلياً',
          backgroundColor: Colors.orange);
    }

    if (mounted) setState(() {});
  }

  Future<void> _loadAssignedCostCenters() async {
    try {
      _assignedCostCenters = await _fuelService.getAssignedCostCenters();
      _filteredTruckNumbers = _assignedCostCenters;
      if (mounted) setState(() {});
    } catch (e) {
      _showSnackBar('خطأ في تحميل البيانات: $e', backgroundColor: Colors.red);
    }
  }

  // NEW: Load fuel contacts
  Future<void> _loadFuelContacts() async {
    try {
      _fuelContacts = await _fuelService.getCachedFuelContacts();
      _filteredFuelContacts = _fuelContacts;
      if (mounted) setState(() {});
      print('✅ Loaded ${_fuelContacts.length} fuel contacts');
    } catch (e) {
      _showSnackBar('خطأ في تحميل محطات المحروقات: $e',
          backgroundColor: Colors.red);
      print('❌ Error loading fuel contacts: $e');
    }
  }

  void _filterTruckNumbers(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;

      setState(() {
        if (query.isEmpty) {
          _filteredTruckNumbers = _assignedCostCenters;
        } else {
          final lowerQuery = query.toLowerCase();
          _filteredTruckNumbers = _assignedCostCenters
              .where((truck) =>
                  truck.number.toLowerCase().contains(lowerQuery) ||
                  (truck.costCenter?.name.toLowerCase().contains(lowerQuery) ??
                      false))
              .toList();
        }
      });
    });
  }

  // NEW: Filter fuel contacts
  void _filterFuelContacts(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;

      setState(() {
        if (query.isEmpty) {
          _filteredFuelContacts = _fuelContacts;
        } else {
          final lowerQuery = query.toLowerCase();
          _filteredFuelContacts = _fuelContacts
              .where((contact) =>
                  contact.name.toLowerCase().contains(lowerQuery) ||
                  contact.code.toLowerCase().contains(lowerQuery))
              .toList();
        }
      });
    });
  }

  void _selectTruck(AssignCostCenter truck) {
    setState(() {
      _selectedCostCenter = truck;
      _truckSearchController.text = truck.number;
      _showTruckDropdown = false;
      _dropdownSearchController.clear();
      _filteredTruckNumbers = _assignedCostCenters;
    });
  }

  // NEW: Select fuel contact
  void _selectFuelContact(FuelContact contact) {
    setState(() {
      _selectedFuelContact = contact;
      _fuelContactSearchController.text = contact.name;
      _showFuelContactDropdown = false;
      _filteredFuelContacts = _fuelContacts;
    });
  }

  void _handleManualTruckInput(String value) {
    final trimmedValue = value.trim();

    if (trimmedValue.isEmpty) {
      if (_selectedCostCenter != null) {
        setState(() => _selectedCostCenter = null);
      }
      return;
    }

    final matchingTruck = _assignedCostCenters.firstWhere(
      (truck) => truck.number == trimmedValue,
      orElse: () => AssignCostCenter(
        id: 0,
        number: '',
        costCenterId: 0,
        fuelTypeId: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final newSelection = matchingTruck.id != 0 ? matchingTruck : null;

    if (_selectedCostCenter != newSelection) {
      setState(() => _selectedCostCenter = newSelection);
    }
  }

  Future<void> _refreshPendingCount() async {
    final count = await _fuelService.getPendingRecordsCount();
    if (mounted && _pendingCount != count) {
      setState(() => _pendingCount = count);
    }
  }

  Future<void> _showImageSourceDialog() async {
    await showModalBottomSheet(
      context: context,
      builder: (context) => _ImageSourceSheet(
        hasImage: _selectedImage != null,
        onCamera: () {
          Navigator.pop(context);
          _pickImage(ImageSource.camera);
        },
        onGallery: () {
          Navigator.pop(context);
          _pickImage(ImageSource.gallery);
        },
        onDelete: () {
          Navigator.pop(context);
          _removeImage();
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _isUploadingImage = true);

    try {
      final imageFile = source == ImageSource.camera
          ? await _imageService.pickImageFromCamera()
          : await _imageService.pickImageFromGallery();

      if (imageFile != null && mounted) {
        setState(() => _selectedImage = imageFile);
        _showSnackBar('✅ تم اختيار الصورة بنجاح',
            backgroundColor: Colors.green);
      }
    } catch (e) {
      _showSnackBar('❌ خطأ في اختيار الصورة: $e', backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _removeImage() {
    setState(() => _selectedImage = null);
    _showSnackBar('🗑️ تم حذف الصورة', backgroundColor: Colors.orange);
  }

  bool _validateForm() {
    final validations = [
      (_selectedCostCenter == null, '⚠️ الرجاء اختيار رقم الشاحنة'),
      (_selectedFuelContact == null, '⚠️ الرجاء اختيار محطة المحروقات'), // NEW
      (_amountController.text.isEmpty, '⚠️ الرجاء إدخال المبلغ'),
      (_quantityController.text.isEmpty, '⚠️ الرجاء إدخال الكمية'),
      (_meterReadingController.text.isEmpty, '⚠️ الرجاء إدخال رقم العداد'),
      (_selectedImage == null, '⚠️ الرجاء اختيار صورة'),
    ];

    for (final (condition, message) in validations) {
      if (condition) {
        _showSnackBar(message, backgroundColor: Colors.orange);
        return false;
      }
    }

    return true;
  }

  Future<void> _submitForm() async {
    if (!_validateForm()) return;

    setState(() => _isSubmitting = true);

    try {
      int finalFuelTypeId;
      if (_isAdBlueFilling) {
        finalFuelTypeId = ADBLUE_FUEL_TYPE_ID;
      } else {
        if (_selectedCostCenter!.fuelTypeId == null) {
          _showSnackBar(
            'لم يتم تحديد نوع المحروقات للشاحنة المختارة. يرجى التواصل مع الإدارة.',
            backgroundColor: Colors.red,
          );
          return;
        }
        finalFuelTypeId = _selectedCostCenter!.fuelTypeId!;
      }

      final result = await _fuelService.submitFuelRecordWithImage(
        fillingDate: _selectedDate,
        truckNumber: _selectedCostCenter!.number,
        assignCostCenterId: _selectedCostCenter!.id,
        fuelTypeId: finalFuelTypeId,
        amount: double.parse(_amountController.text),
        quantity: double.parse(_quantityController.text),
        meterReading: _meterReadingController.text,
        imageFile: _selectedImage,
        userId:
            Supabase.instance.client.auth.currentUser?.id ?? 'current-user-id',
        fuelContactId: _selectedFuelContact!.id, // NEW
        fuelContactCode: _selectedFuelContact!.code, // NEW
      );

      if (result['success']) {
        _showSnackBar(
          result['message'],
          backgroundColor:
              result['pending'] == true ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 4),
        );

        if (result['pending'] == true) {
          await _refreshPendingCount();
        }

        _clearForm();
      }
    } catch (e) {
      _showSnackBar('خطأ: $e', backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _clearForm() {
    _amountController.clear();
    _quantityController.clear();
    _meterReadingController.clear();
    _truckSearchController.clear();
    _dropdownSearchController.clear();
    _fuelContactSearchController.clear(); // NEW

    setState(() {
      _selectedCostCenter = null;
      _selectedFuelContact = null; // NEW
      _selectedImage = null;
      _isAdBlueFilling = false;
      _showTruckDropdown = false;
      _showFuelContactDropdown = false; // NEW
      _filteredTruckNumbers = _assignedCostCenters;
      _filteredFuelContacts = _fuelContacts; // NEW
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: child!,
      ),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  // NEW: Build fuel contact field
  Widget _buildFuelContactField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('محطة المحروقات *', style: _labelStyle),
        const SizedBox(height: 8),
        TextFormField(
          controller: _fuelContactSearchController,
          decoration: _baseInputDecoration.copyWith(
            hintText: 'اختر محطة المحروقات...',
            suffixIcon: IconButton(
              icon: Icon(
                _showFuelContactDropdown
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: Colors.blue,
              ),
              onPressed: () {
                setState(() {
                  _showFuelContactDropdown = !_showFuelContactDropdown;
                  if (_showFuelContactDropdown) {
                    _filterFuelContacts(_fuelContactSearchController.text);
                  }
                });
              },
            ),
          ),
          style: _inputStyle,
          onChanged: (value) {
            if (_showFuelContactDropdown) {
              _filterFuelContacts(value);
            }
          },
          validator: (value) {
            if (_selectedFuelContact == null) {
              return 'يرجى اختيار محطة المحروقات';
            }
            return null;
          },
        ),
        if (_selectedFuelContact != null) _buildFuelContactInfoCard(),
        if (_showFuelContactDropdown && _filteredFuelContacts.isNotEmpty)
          _buildFuelContactDropdown(),
      ],
    );
  }

  // NEW: Build fuel contact info card
  Widget _buildFuelContactInfoCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: _borderRadius,
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle,
                    color: Colors.green.shade600, size: 18),
                const SizedBox(width: 8),
                Text(
                  'تم اختيار المحطة',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'الاسم: ${_selectedFuelContact!.name}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            Text(
              'الكود: ${_selectedFuelContact!.code}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Build fuel contact dropdown
  Widget _buildFuelContactDropdown() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: _borderRadius,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _filteredFuelContacts.length,
        itemBuilder: (context, index) => _FuelContactListItem(
          contact: _filteredFuelContacts[index],
          isSelected:
              _selectedFuelContact?.code == _filteredFuelContacts[index].code,
          onTap: () => _selectFuelContact(_filteredFuelContacts[index]),
          isFirst: index == 0,
        ),
      ),
    );
  }

  Widget _buildAdBlueOption() {
    final isActive = _isAdBlueFilling;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: _borderRadius,
        border: Border.all(
          color: isActive ? Colors.blue.shade200 : Colors.grey.shade300,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isActive,
            onChanged: (value) =>
                setState(() => _isAdBlueFilling = value ?? false),
            activeColor: Colors.blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تعبئة AdBlue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.blue : _primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'اختر هذا الخيار إذا كانت التعبئة خاصة بـ AdBlue بدلاً من الوقود العادي',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTruckNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('رقم الشاحنة *', style: _labelStyle),
        const SizedBox(height: 8),
        TextFormField(
          controller: _truckSearchController,
          decoration: _baseInputDecoration.copyWith(
            hintText: 'أدخل رقم الشاحنة أو ابحث...',
            suffixIcon: IconButton(
              icon: Icon(
                _showTruckDropdown
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: Colors.blue,
              ),
              onPressed: () {
                setState(() {
                  _showTruckDropdown = !_showTruckDropdown;
                  if (_showTruckDropdown) {
                    _filterTruckNumbers(_truckSearchController.text);
                  }
                });
              },
            ),
          ),
          style: _inputStyle,
          onChanged: (value) {
            _handleManualTruckInput(value);
            if (_showTruckDropdown) {
              _filterTruckNumbers(value);
            }
          },
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'يرجى إدخال رقم الشاحنة';
            }
            if (_selectedCostCenter == null) {
              return 'رقم الشاحنة غير مسجل في النظام';
            }
            return null;
          },
        ),
        if (_selectedCostCenter != null) _buildTruckInfoCard(),
        if (_showTruckDropdown && _filteredTruckNumbers.isNotEmpty)
          _buildTruckDropdown(),
      ],
    );
  }

  Widget _buildTruckInfoCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: _borderRadius,
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle,
                    color: Colors.green.shade600, size: 18),
                const SizedBox(width: 8),
                Text(
                  'تم العثور على الشاحنة',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'مركز التكلفة: ${_selectedCostCenter!.costCenter?.name ?? 'غير محدد'}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            if (_isAdBlueFilling)
              Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade600, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'نوع المحروقات: AdBlue (تم تجاهل نوع الوقود المخصص للشاحنة)',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                'نوع المحروقات: ${_selectedCostCenter!.fuelType?.name ?? 'غير محدد'}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTruckDropdown() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: _borderRadius,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDropdownSearchField(),
          const Divider(height: 1, color: Colors.grey),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredTruckNumbers.length,
              itemBuilder: (context, index) => _TruckListItem(
                truck: _filteredTruckNumbers[index],
                isSelected: _selectedCostCenter?.number ==
                    _filteredTruckNumbers[index].number,
                onTap: () => _selectTruck(_filteredTruckNumbers[index]),
                isFirst: index == 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownSearchField() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: TextField(
        controller: _dropdownSearchController,
        decoration: const InputDecoration(
          hintText: 'البحث في قائمة الشاحنات...',
          prefixIcon: Icon(Icons.search, size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 14),
        onChanged: _filterTruckNumbers,
      ),
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('تاريخ التعبئة *', style: _labelStyle),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: _borderRadius,
              color: Colors.white,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(_selectedDate),
                    style: const TextStyle(fontSize: 16, color: _primaryColor),
                  ),
                ),
                Icon(Icons.calendar_today,
                    color: Colors.grey.shade600, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: _baseInputDecoration.copyWith(hintText: hintText),
          style: _inputStyle,
          validator: validator,
          textDirection: ui.TextDirection.ltr,
        ),
      ],
    );
  }

  Widget _buildAmountField() {
    return _buildTextField(
      label: 'مجموع المبلغ *',
      controller: _amountController,
      hintText: '0.00',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.isEmpty) return 'يرجى إدخال المبلغ';
        final amount = double.tryParse(value);
        if (amount == null || amount <= 0) return 'يرجى إدخال مبلغ صحيح';
        return null;
      },
    );
  }

  Widget _buildQuantityField() {
    return _buildTextField(
      label: 'الكمية (لتر) *',
      controller: _quantityController,
      hintText: '0.000',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.isEmpty) return 'يرجى إدخال الكمية';
        final quantity = double.tryParse(value);
        if (quantity == null || quantity <= 0) return 'يرجى إدخال كمية صحيحة';
        return null;
      },
    );
  }

  Widget _buildMeterReadingField() {
    return _buildTextField(
      label: 'رقم العداد *',
      controller: _meterReadingController,
      hintText: 'أدخل رقم العداد',
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.trim().isEmpty)
          return 'يرجى إدخال رقم العداد';
        if (int.tryParse(value.trim()) == null) return 'يرجى إدخال رقم صحيح';
        return null;
      },
    );
  }

  Widget _buildImageSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'صورة *',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          _selectedImage != null ? _buildImagePreview() : _buildImagePicker(),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: _borderRadius,
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: _borderRadius,
                child: kIsWeb
                    ? Image.network(
                        _selectedImage!.path,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildImageError(),
                      )
                    : Image.file(
                        _selectedImage!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _removeImage,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          kIsWeb ? 'صورة محددة' : _selectedImage!.path.split('/').last,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildImageError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.error, color: Colors.red, size: 48),
          SizedBox(height: 8),
          Text('خطأ في تحميل الصورة'),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return InkWell(
      onTap: _isUploadingImage ? null : _showImageSourceDialog,
      child: Container(
        width: double.infinity,
        height: 150,
        decoration: BoxDecoration(
          border: Border.all(
            color: _isUploadingImage ? Colors.grey : Colors.red.shade300,
            width: 2,
          ),
          borderRadius: _borderRadius,
          color: _isUploadingImage ? Colors.grey.shade100 : Colors.red.shade50,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isUploadingImage)
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.grey.shade600),
                ),
              )
            else
              const Icon(Icons.cloud_upload_outlined,
                  size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              _isUploadingImage
                  ? 'جارٍ التحميل...'
                  : 'اضغط لاختيار صورة (مطلوب)',
              style: TextStyle(
                fontSize: 16,
                color: _isUploadingImage
                    ? Colors.grey.shade600
                    : Colors.red.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'صيغ مدعومة: JPG, PNG, GIF',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
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
                : Text(
                    _isOnline ? 'حفظ' : 'حفظ للإرسال لاحقاً',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
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
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: _borderRadius),
            ),
            child: const Text(
              'إعادة تعيين',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'بيانات التعبئة',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          _buildDateField(),
          const SizedBox(height: 16),
          _buildTruckNumberField(),
          const SizedBox(height: 16),
          _buildFuelContactField(), // NEW
          const SizedBox(height: 16),
          _buildAdBlueOption(),
          const SizedBox(height: 16),
          _buildAmountField(),
          const SizedBox(height: 16),
          _buildQuantityField(),
          const SizedBox(height: 16),
          _buildMeterReadingField(),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: _borderRadius,
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade800),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'وضع عدم الاتصال',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'سيتم حفظ البيانات والصور محلياً',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
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
      surfaceTintColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: _primaryColor),
        onPressed: _isSubmitting ? null : () => Navigator.pop(context),
      ),
      title: const Text(
        'إدخال المحروقات',
        style: TextStyle(
          color: _primaryColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              Tooltip(
                message: _isOnline ? 'متصل ($_connectivityType)' : 'غير متصل',
                child: Icon(
                  _isOnline ? Icons.cloud_done : Icons.cloud_off,
                  color: _isOnline ? Colors.green : Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 8),
              if (_pendingCount > 0)
                Tooltip(
                  message: '$_pendingCount سجلات قيد الانتظار',
                  child: Badge(
                    label: Text('$_pendingCount'),
                    backgroundColor: Colors.orange,
                    child: const Icon(Icons.pending_actions),
                  ),
                ),
            ],
          ),
        ),
        if (_isOnline && _pendingCount > 0)
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'مزامنة يدوية',
            onPressed: () async {
              final result = await _fuelService.manualSync();
              _showSnackBar(result['message']);
              await _refreshPendingCount();
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: _buildAppBar(),
        body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('جاري التحميل...'),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_isOnline) _buildOfflineBanner(),
                          _buildFormCard(),
                          const SizedBox(height: 24),
                          _buildImageSection(),
                          const SizedBox(height: 32),
                          _buildActionButtons(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  void _showSnackBar(
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _connectivitySubscription?.cancel();
    _amountController.dispose();
    _quantityController.dispose();
    _meterReadingController.dispose();
    _truckSearchController.dispose();
    _dropdownSearchController.dispose();
    _fuelContactSearchController.dispose(); // NEW
    _fuelService.dispose();
    super.dispose();
  }
}

// Image source sheet widget
class _ImageSourceSheet extends StatelessWidget {
  final bool hasImage;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  const _ImageSourceSheet({
    required this.hasImage,
    required this.onCamera,
    required this.onGallery,
    required this.onDelete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera, color: Colors.blue),
            title: const Text('التقاط صورة'),
            onTap: onCamera,
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.green),
            title: const Text('اختيار من المعرض'),
            onTap: onGallery,
          ),
          if (hasImage)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('حذف الصورة'),
              onTap: onDelete,
            ),
          ListTile(
            leading: const Icon(Icons.cancel),
            title: const Text('إلغاء'),
            onTap: onCancel,
          ),
        ],
      ),
    );
  }
}

// Truck list item widget
class _TruckListItem extends StatelessWidget {
  final AssignCostCenter truck;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isFirst;

  const _TruckListItem({
    required this.truck,
    required this.isSelected,
    required this.onTap,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : null,
          border: !isFirst
              ? Border(top: BorderSide(color: Colors.grey.shade200))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'رقم الشاحنة: ${truck.number}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.blue
                          : const Color(AppConstants.primaryColor),
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: Colors.blue, size: 18),
              ],
            ),
            if (truck.costCenter != null) ...[
              const SizedBox(height: 2),
              Text(
                'مركز التكلفة: ${truck.costCenter!.name}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            if (truck.fuelType != null) ...[
              const SizedBox(height: 2),
              Text(
                'نوع المحروقات: ${truck.fuelType!.name}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// NEW: Fuel contact list item widget
class _FuelContactListItem extends StatelessWidget {
  final FuelContact contact;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isFirst;

  const _FuelContactListItem({
    required this.contact,
    required this.isSelected,
    required this.onTap,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : null,
          border: !isFirst
              ? Border(top: BorderSide(color: Colors.grey.shade200))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    contact.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.blue
                          : const Color(AppConstants.primaryColor),
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: Colors.blue, size: 18),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'الكود: ${contact.code}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
