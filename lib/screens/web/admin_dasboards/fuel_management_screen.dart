// lib/screens/web/fuel_management_screen.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jala_as/models/user.dart';
import '../../../models/fuel_models.dart';
import '../../../services/supabase_service.dart';
import '../../../services/fuel_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';
import 'dart:ui' as ui;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import '../../utils/file_utils.dart';
import 'dart:convert';

// Edit Fuel Record Dialog
class _EditFuelRecordDialog extends StatefulWidget {
  final FuelFillingRecord record;
  final List<AssignCostCenter> assignCostCenters;
  final List<FuelType> fuelTypes;

  const _EditFuelRecordDialog({
    required this.record,
    required this.assignCostCenters,
    required this.fuelTypes,
  });

  @override
  State<_EditFuelRecordDialog> createState() => _EditFuelRecordDialogState();
}

class _EditFuelRecordDialogState extends State<_EditFuelRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _quantityController = TextEditingController();
  final _meterReadingController = TextEditingController();

  late DateTime _selectedDate;
  String? _selectedTruckNumber;
  int? _selectedFuelTypeId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.record.fillingDate;
    _selectedTruckNumber = widget.record.truckNumber;
    _selectedFuelTypeId = widget.record.fuelTypeId;
    _amountController.text = widget.record.amount.toString();
    _quantityController.text = widget.record.quantity.toString();
    _meterReadingController.text = widget.record.meterReading ?? '';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _quantityController.dispose();
    _meterReadingController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
      builder: (context, child) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTruckNumber == null) {
      _showSnackBar('يرجى اختيار رقم الشاحنة');
      return;
    }

    if (_selectedFuelTypeId == null) {
      _showSnackBar('يرجى اختيار نوع المحروقات');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SupabaseService.updateFuelFillingRecord(
        id: widget.record.id,
        fillingDate: _selectedDate,
        truckNumber: _selectedTruckNumber!,
        fuelTypeId: _selectedFuelTypeId!,
        amount: double.parse(_amountController.text.trim()),
        quantity: double.parse(_quantityController.text.trim()),
        meterReading: _meterReadingController.text.trim().isEmpty
            ? null
            : _meterReadingController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('فشل في تحديث السجل: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          constraints: const BoxConstraints(
            maxWidth: 500,
            maxHeight: 750, // Increased height for new fields
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'تعديل سجل التعبئة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),

              // Form Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date Field
                          const Text(
                            'تاريخ التعبئة',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: _selectDate,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      DateFormat('dd/MM/yyyy')
                                          .format(_selectedDate),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  Icon(Icons.calendar_today,
                                      size: 18, color: Colors.grey.shade600),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Truck Number Dropdown
                          const Text(
                            'رقم الشاحنة',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _selectedTruckNumber,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                            hint: const Text('اختر رقم الشاحنة'),
                            items: widget.assignCostCenters.map((assign) {
                              return DropdownMenuItem<String>(
                                value: assign.number,
                                child: Text(
                                    '${assign.number} - ${assign.costCenter?.name ?? 'غير محدد'}'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedTruckNumber = value);
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'يرجى اختيار رقم الشاحنة';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Fuel Type Dropdown
                          const Text(
                            'نوع المحروقات',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            value: _selectedFuelTypeId,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                            hint: const Text('اختر نوع المحروقات'),
                            items: widget.fuelTypes.map((fuelType) {
                              return DropdownMenuItem<int>(
                                value: fuelType.id,
                                child: Text('${fuelType.name}'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedFuelTypeId = value);
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'يرجى اختيار نوع المحروقات';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Amount Field
                          const Text(
                            'المبلغ',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _amountController,
                            decoration: InputDecoration(
                              hintText: 'أدخل المبلغ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              prefixIcon: const Icon(Icons.attach_money),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textDirection: ui.TextDirection.ltr,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال المبلغ';
                              }
                              if (double.tryParse(value.trim()) == null) {
                                return 'يرجى إدخال مبلغ صحيح';
                              }
                              if (double.parse(value.trim()) <= 0) {
                                return 'المبلغ يجب أن يكون أكبر من صفر';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Quantity Field
                          const Text(
                            'الكمية (لتر)',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _quantityController,
                            decoration: InputDecoration(
                              hintText: 'أدخل الكمية',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              prefixIcon: const Icon(Icons.local_gas_station),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textDirection: ui.TextDirection.ltr,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال الكمية';
                              }
                              if (double.tryParse(value.trim()) == null) {
                                return 'يرجى إدخال كمية صحيحة';
                              }
                              if (double.parse(value.trim()) <= 0) {
                                return 'الكمية يجب أن تكون أكبر من صفر';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Meter Reading Field
                          const Text(
                            'رقم العداد',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _meterReadingController,
                            decoration: InputDecoration(
                              hintText: 'أدخل رقم العداد (اختياري)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              prefixIcon: const Icon(Icons.speed),
                            ),
                            textDirection: ui.TextDirection.ltr,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Action Buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context, false),
                      child: const Text('إلغاء'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('تحديث'),
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
}

class _ImageViewerDialog extends StatefulWidget {
  final String imageUrl;

  const _ImageViewerDialog({required this.imageUrl});

  @override
  State<_ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<_ImageViewerDialog>
    with TickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  double _scale = 1.0;
  static const double _minScale = 0.5;
  static const double _maxScale = 5.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _transformationController.addListener(() {
      setState(() {
        _scale = _transformationController.value.getMaxScaleOnAxis();
      });
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _animationController.reset();
    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animation!.addListener(() {
      _transformationController.value = _animation!.value;
    });

    _animationController.forward();
  }

  void _zoomIn() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final newScale = (currentScale * 1.5).clamp(_minScale, _maxScale);
    _animateToScale(newScale);
  }

  void _zoomOut() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final newScale = (currentScale / 1.5).clamp(_minScale, _maxScale);
    _animateToScale(newScale);
  }

  void _animateToScale(double scale) {
    _animationController.reset();
    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: Matrix4.identity()..scale(scale),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animation!.addListener(() {
      _transformationController.value = _animation!.value;
    });

    _animationController.forward();
  }

  void _fitToScreen() {
    _resetZoom();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.9,
          constraints: const BoxConstraints(
            maxWidth: 800,
            maxHeight: 700,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header with controls
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.image,
                      color: Color(AppConstants.primaryColor),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'عرض الصورة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(AppConstants.primaryColor),
                        ),
                      ),
                    ),

                    // Zoom controls
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        '${(_scale * 100).round()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Zoom out button
                    IconButton(
                      onPressed: _scale > _minScale ? _zoomOut : null,
                      icon: const Icon(Icons.zoom_out),
                      iconSize: 20,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade300),
                        minimumSize: const Size(36, 36),
                      ),
                      tooltip: 'تصغير',
                    ),

                    const SizedBox(width: 4),

                    // Zoom in button
                    IconButton(
                      onPressed: _scale < _maxScale ? _zoomIn : null,
                      icon: const Icon(Icons.zoom_in),
                      iconSize: 20,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade300),
                        minimumSize: const Size(36, 36),
                      ),
                      tooltip: 'تكبير',
                    ),

                    const SizedBox(width: 4),

                    // Fit to screen button
                    IconButton(
                      onPressed: _fitToScreen,
                      icon: const Icon(Icons.fit_screen),
                      iconSize: 20,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade300),
                        minimumSize: const Size(36, 36),
                      ),
                      tooltip: 'ملء الشاشة',
                    ),

                    const SizedBox(width: 8),

                    // Close button
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      iconSize: 20,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade200),
                        minimumSize: const Size(36, 36),
                      ),
                      tooltip: 'إغلاق',
                    ),
                  ],
                ),
              ),

              // Image viewer
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: Colors.grey.shade100,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        // Main image with zoom and pan
                        InteractiveViewer(
                          transformationController: _transformationController,
                          minScale: _minScale,
                          maxScale: _maxScale,
                          panEnabled: true,
                          scaleEnabled: true,
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            child: Image.network(
                              widget.imageUrl,
                              fit: BoxFit.contain,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (mounted) {
                                      setState(() => _isLoading = false);
                                    }
                                  });
                                  return child;
                                }
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                        color: const Color(
                                            AppConstants.accentColor),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'جاري تحميل الصورة...',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        size: 48,
                                        color: Colors.red.shade400,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'فشل في تحميل الصورة',
                                        style: TextStyle(
                                          color: Colors.red.shade600,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'تحقق من الاتصال بالإنترنت',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // Instructions overlay (only show when not loading)
                        if (!_isLoading)
                          Positioned(
                            bottom: 16,
                            left: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.touch_app,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'اسحب للتنقل • قرص للتكبير',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
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
      ),
    );
  }
}

// 1. UPDATE: _DateRangeSelectionDialog to include fuel contact selection
class _DateRangeSelectionDialog extends StatefulWidget {
  final List<FuelContact> availableFuelContacts; // NEW

  const _DateRangeSelectionDialog({
    required this.availableFuelContacts, // NEW
  });

  @override
  State<_DateRangeSelectionDialog> createState() =>
      _DateRangeSelectionDialogState();
}

class _DateRangeSelectionDialogState extends State<_DateRangeSelectionDialog> {
  DateTime? _fromDate;
  DateTime? _toDate;
  FuelContact?
      _selectedFuelContact; // CHANGED from truck numbers to fuel contact

  @override
  void initState() {
    super.initState();
    // Default to current month
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = DateTime(now.year, now.month + 1, 0);
  }

  Future<void> _selectFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
      builder: (context, child) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(picked)) {
          _toDate = picked;
        }
      });
    }
  }

  Future<void> _selectToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: _fromDate ?? DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
      builder: (context, child) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _toDate = picked);
    }
  }

  bool _isValidDateRange() {
    return _fromDate != null &&
        _toDate != null &&
        !_toDate!.isBefore(_fromDate!);
  }

  void _setPresetRange(String preset) {
    final now = DateTime.now();

    setState(() {
      switch (preset) {
        case 'today':
          _fromDate = DateTime(now.year, now.month, now.day);
          _toDate = DateTime(now.year, now.month, now.day);
          break;
        case 'thisWeek':
          final weekday = now.weekday;
          _fromDate = now.subtract(Duration(days: weekday - 1));
          _fromDate =
              DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
          _toDate = DateTime(now.year, now.month, now.day);
          break;
        case 'thisMonth':
          _fromDate = DateTime(now.year, now.month, 1);
          _toDate = DateTime(now.year, now.month + 1, 0);
          break;
        case 'lastMonth':
          _fromDate = DateTime(now.year, now.month - 1, 1);
          _toDate = DateTime(now.year, now.month, 0);
          break;
        case 'thisYear':
          _fromDate = DateTime(now.year, 1, 1);
          _toDate = DateTime(now.year, 12, 31);
          break;
      }
    });
  }

// UPDATE: _DateRangeSelectionDialog build method
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.date_range,
                color: Color(AppConstants.accentColor)),
            const SizedBox(width: 8),
            const Text('اختيار الفترة الزمنية ومحطة المحروقات'),
          ],
        ),
        content: SizedBox(
          width: 500,
          // ADD: Set max height to prevent overflow
          height:
              MediaQuery.of(context).size.height * 0.7, // 70% of screen height
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Preset buttons
                const Text(
                  'فترات محددة مسبقاً:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(AppConstants.primaryColor),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPresetButton('اليوم', 'today'),
                    _buildPresetButton('هذا الأسبوع', 'thisWeek'),
                    _buildPresetButton('هذا الشهر', 'thisMonth'),
                    _buildPresetButton('الشهر الماضي', 'lastMonth'),
                    _buildPresetButton('هذا العام', 'thisYear'),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),

                // Custom date selection
                const Text(
                  'اختر الفترة الزمنية:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(AppConstants.primaryColor),
                  ),
                ),
                const SizedBox(height: 12),

                // From Date & To Date
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('من تاريخ:'),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: _selectFromDate,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _fromDate != null
                                          ? DateFormat('dd/MM/yyyy')
                                              .format(_fromDate!)
                                          : 'اختر التاريخ',
                                      style: TextStyle(
                                        color: _fromDate != null
                                            ? Colors.black87
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.calendar_today,
                                      size: 18, color: Colors.grey.shade600),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('إلى تاريخ:'),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: _selectToDate,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _toDate != null
                                          ? DateFormat('dd/MM/yyyy')
                                              .format(_toDate!)
                                          : 'اختر التاريخ',
                                      style: TextStyle(
                                        color: _toDate != null
                                            ? Colors.black87
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.calendar_today,
                                      size: 18, color: Colors.grey.shade600),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),

                // Fuel Contact Selection
                const Text(
                  'محطة المحروقات:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(AppConstants.primaryColor),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'اختر محطة المحروقات للترحيل',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),

                // Fuel Contacts Dropdown
                if (widget.availableFuelContacts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber,
                            color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'لا توجد محطات محروقات متاحة في السجلات المحددة',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  DropdownButtonFormField<FuelContact>(
                    value: _selectedFuelContact,
                    decoration: InputDecoration(
                      hintText: 'اختر محطة المحروقات',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      prefixIcon: Icon(
                        Icons.local_gas_station,
                        color: Colors.grey.shade600,
                      ),
                      isDense: true, // ADD: Make dropdown more compact
                    ),
                    items: widget.availableFuelContacts.map((contact) {
                      return DropdownMenuItem<FuelContact>(
                        value: contact,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    contact.name,
                                    style: const TextStyle(
                                      fontSize: 13, // REDUCED from 14
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  Text(
                                    'الكود: ${contact.code}',
                                    style: TextStyle(
                                      fontSize: 10, // REDUCED from 11
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedFuelContact = value);
                    },
                    isExpanded: true,
                    menuMaxHeight: 200, // REDUCED from 300 to prevent overflow
                    selectedItemBuilder: (BuildContext context) {
                      // Custom builder for selected item to make it more compact
                      return widget.availableFuelContacts.map((contact) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            contact.name,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList();
                    },
                  ),

                const SizedBox(height: 8), // REDUCED from 12

                // Validation message
                if (!_isValidDateRange() &&
                    _fromDate != null &&
                    _toDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'تاريخ النهاية يجب أن يكون بعد تاريخ البداية',
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: (_isValidDateRange() && _selectedFuelContact != null)
                ? () {
                    Navigator.pop(context, {
                      'fromDate': _fromDate!,
                      'toDate': _toDate!,
                      'fuelContact': _selectedFuelContact!,
                    });
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConstants.accentColor),
              foregroundColor: Colors.white,
            ),
            child: const Text('حساب الحسابات'),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton(String label, String preset) {
    return OutlinedButton(
      onPressed: () => _setPresetRange(preset),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(AppConstants.accentColor),
        side: const BorderSide(color: Color(AppConstants.accentColor)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

// Add Cost Center Dialog - Compact and Overflow-Fixed
// Update the constructor for _AddAssignCostCenterDialog
class _AddAssignCostCenterDialog extends StatefulWidget {
  final List<CostCenter> costCenters;
  final List<FuelType> fuelTypes; // NEW PARAMETER

  const _AddAssignCostCenterDialog({
    required this.costCenters,
    required this.fuelTypes, // NEW PARAMETER
  });

  @override
  State<_AddAssignCostCenterDialog> createState() =>
      _AddAssignCostCenterDialogState();
}

class _AddAssignCostCenterDialogState
    extends State<_AddAssignCostCenterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _costCenterSearchController = TextEditingController();
  final _fuelTypeSearchController = TextEditingController(); // ADD THIS
  final _scrollController = ScrollController();

  int? _selectedCostCenterId;
  int? _selectedFuelTypeId; // ADD THIS VARIABLE
  bool _isLoading = false;
  bool _showCostCenterDropdown = true;
  bool _showFuelTypeDropdown = true; // ADD THIS
  List<CostCenter> _filteredCostCenters = [];
  List<FuelType> _filteredFuelTypes = []; // ADD THIS
  String _costCenterSearchQuery = '';
  String _fuelTypeSearchQuery = ''; // ADD THIS

  @override
  void initState() {
    super.initState();
    _filteredCostCenters = List.from(widget.costCenters);
    _filteredFuelTypes = List.from(widget.fuelTypes); // ADD THIS
  }

  @override
  void dispose() {
    _numberController.dispose();
    _costCenterSearchController.dispose();
    _fuelTypeSearchController.dispose(); // ADD THIS
    _scrollController.dispose();
    super.dispose();
  }

  // ADD THESE METHODS
  void _filterFuelTypes(String query) {
    setState(() {
      _fuelTypeSearchQuery = query;
      if (query.isEmpty) {
        _filteredFuelTypes = List.from(widget.fuelTypes);
      } else {
        _filteredFuelTypes = widget.fuelTypes
            .where((fuelType) =>
                fuelType.name.toLowerCase().contains(query.toLowerCase()) ||
                fuelType.code.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
      _showFuelTypeDropdown = true;
    });
  }

  void _selectFuelType(FuelType fuelType) {
    setState(() {
      _selectedFuelTypeId = fuelType.id;
      _fuelTypeSearchController.text = '${fuelType.code} - ${fuelType.name}';
      _showFuelTypeDropdown = false;
    });
  }

  void _clearFuelTypeSelection() {
    setState(() {
      _selectedFuelTypeId = null;
      _fuelTypeSearchController.clear();
      _showFuelTypeDropdown = true;
      _filteredFuelTypes = List.from(widget.fuelTypes);
    });
  }

  void _filterCostCenters(String query) {
    setState(() {
      _costCenterSearchQuery = query;
      if (query.isEmpty) {
        _filteredCostCenters = List.from(widget.costCenters);
      } else {
        _filteredCostCenters = widget.costCenters
            .where((costCenter) =>
                costCenter.name.toLowerCase().contains(query.toLowerCase()) ||
                costCenter.code.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
      _showCostCenterDropdown = true;
    });
  }

  void _selectCostCenter(CostCenter costCenter) {
    setState(() {
      _selectedCostCenterId = costCenter.id;
      _costCenterSearchController.text =
          '${costCenter.code} - ${costCenter.name}';
      _showCostCenterDropdown = false;
    });
  }

  void _clearCostCenterSelection() {
    setState(() {
      _selectedCostCenterId = null;
      _costCenterSearchController.clear();
      _showCostCenterDropdown = true;
      _filteredCostCenters = List.from(widget.costCenters);
    });
  }

  void _toggleDropdown() {
    setState(() {
      _showCostCenterDropdown = !_showCostCenterDropdown;
      if (_showCostCenterDropdown && _costCenterSearchQuery.isEmpty) {
        _filteredCostCenters = List.from(widget.costCenters);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCostCenterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار مركز التكلفة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedFuelTypeId == null) {
      // NEW VALIDATION
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار نوع المحروقات'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SupabaseService.createAssignCostCenter(
        number: _numberController.text.trim(),
        costCenterId: _selectedCostCenterId!,
        fuelTypeId: _selectedFuelTypeId!, // NEW PARAMETER
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إضافة الشاحنة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          constraints: const BoxConstraints(
            maxWidth: 480,
            maxHeight: 750, // Increased height for fuel type field
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header (same as before)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(AppConstants.accentColor),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'إضافة شاحنة جديدة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),

              // Form Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Truck Number Field (same as before)
                        const Text(
                          'رقم الشاحنة',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _numberController,
                          decoration: InputDecoration(
                            hintText: 'أدخل رقم الشاحنة',
                            hintStyle: TextStyle(
                                fontSize: 13, color: Colors.grey.shade500),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(AppConstants.accentColor),
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            prefixIcon: Icon(
                              Icons.confirmation_number,
                              color: Colors.grey.shade500,
                              size: 18,
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال رقم الشاحنة';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Cost Center Field (same logic as before but shorter height)
                        const Text(
                          'مركز التكلفة',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Cost center search field and dropdown logic here...
                        // (Keep the same implementation but reduce height)

                        const SizedBox(height: 16),

                        // NEW: Fuel Type Field
                        const Text(
                          'نوع المحروقات',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _fuelTypeSearchController,
                          onChanged: _filterFuelTypes,
                          onTap: () {
                            if (!_showFuelTypeDropdown) {
                              setState(() => _showFuelTypeDropdown = true);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'ابحث أو اختر نوع المحروقات',
                            hintStyle: TextStyle(
                                fontSize: 13, color: Colors.grey.shade500),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(AppConstants.accentColor),
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            prefixIcon: Icon(
                              Icons.local_gas_station,
                              color: Colors.grey.shade500,
                              size: 18,
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_selectedFuelTypeId != null)
                                  IconButton(
                                    onPressed: _clearFuelTypeSelection,
                                    icon: Icon(Icons.clear,
                                        size: 16, color: Colors.grey.shade600),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 32, minHeight: 32),
                                  ),
                                IconButton(
                                  onPressed: () => setState(() =>
                                      _showFuelTypeDropdown =
                                          !_showFuelTypeDropdown),
                                  icon: AnimatedRotation(
                                    turns: _showFuelTypeDropdown ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 150),
                                    child: Icon(Icons.keyboard_arrow_down,
                                        size: 18, color: Colors.grey.shade600),
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                ),
                              ],
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                          validator: (value) {
                            if (_selectedFuelTypeId == null) {
                              return 'يرجى اختيار نوع المحروقات';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 8),

                        // Fuel Type Dropdown List
                        if (_showFuelTypeDropdown)
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(8),
                                        topRight: Radius.circular(8),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.list,
                                            size: 14,
                                            color: Colors.grey.shade600),
                                        const SizedBox(width: 6),
                                        Text(
                                          'أنواع المحروقات (${_filteredFuelTypes.length})',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_filteredFuelTypes.isNotEmpty)
                                    Expanded(
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        itemCount: _filteredFuelTypes.length,
                                        itemBuilder: (context, index) {
                                          final fuelType =
                                              _filteredFuelTypes[index];
                                          final isSelected =
                                              _selectedFuelTypeId ==
                                                  fuelType.id;

                                          return Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () =>
                                                  _selectFuelType(fuelType),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? const Color(AppConstants
                                                              .accentColor)
                                                          .withOpacity(0.1)
                                                      : null,
                                                  border: index <
                                                          _filteredFuelTypes
                                                                  .length -
                                                              1
                                                      ? Border(
                                                          bottom: BorderSide(
                                                              color: Colors.grey
                                                                  .shade200))
                                                      : null,
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            fuelType.name,
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              fontWeight: isSelected
                                                                  ? FontWeight
                                                                      .w500
                                                                  : FontWeight
                                                                      .normal,
                                                              color: isSelected
                                                                  ? const Color(
                                                                      AppConstants
                                                                          .accentColor)
                                                                  : Colors
                                                                      .black87,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                          const SizedBox(
                                                              height: 2),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical:
                                                                        1),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: isSelected
                                                                  ? const Color(
                                                                      AppConstants
                                                                          .accentColor)
                                                                  : Colors.grey
                                                                      .shade200,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          3),
                                                            ),
                                                            child: Text(
                                                              fuelType.code,
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                                color: isSelected
                                                                    ? Colors
                                                                        .white
                                                                    : Colors
                                                                        .grey
                                                                        .shade700,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (isSelected)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: const Color(
                                                              AppConstants
                                                                  .accentColor),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                        ),
                                                        child: const Icon(
                                                            Icons.check,
                                                            color: Colors.white,
                                                            size: 12),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  if (_filteredFuelTypes.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        children: [
                                          Icon(Icons.search_off,
                                              size: 24,
                                              color: Colors.grey.shade400),
                                          const SizedBox(height: 6),
                                          Text(
                                            'لا توجد نتائج',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Action Buttons (same as before)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                      child: Text(
                        'إلغاء',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(AppConstants.accentColor),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 1,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.add,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                const Text('إضافة',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                              ],
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
}

class _EditAssignCostCenterDialog extends StatefulWidget {
  final AssignCostCenter assignCostCenter;
  final List<CostCenter> costCenters;
  final List<FuelType> fuelTypes; // ADD THIS

  const _EditAssignCostCenterDialog({
    required this.assignCostCenter,
    required this.costCenters,
    required this.fuelTypes, // ADD THIS
  });

  @override
  State<_EditAssignCostCenterDialog> createState() =>
      _EditAssignCostCenterDialogState();
}

class _EditAssignCostCenterDialogState
    extends State<_EditAssignCostCenterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _costCenterSearchController = TextEditingController();
  final _fuelTypeSearchController = TextEditingController(); // ADD THIS
  final _scrollController = ScrollController();

  int? _selectedCostCenterId;
  int? _selectedFuelTypeId; // ADD THIS VARIABLE
  bool _isLoading = false;
  bool _showCostCenterDropdown = true;
  bool _showFuelTypeDropdown = true; // ADD THIS
  List<CostCenter> _filteredCostCenters = [];
  List<FuelType> _filteredFuelTypes = []; // ADD THIS
  String _costCenterSearchQuery = '';
  String _fuelTypeSearchQuery = ''; // ADD THIS

  @override
  void initState() {
    super.initState();
    _filteredCostCenters = List.from(widget.costCenters);
    _filteredFuelTypes = List.from(widget.fuelTypes); // ADD THIS

    // Initialize with existing data
    _numberController.text = widget.assignCostCenter.number;
    _selectedCostCenterId = widget.assignCostCenter.costCenterId;
    _selectedFuelTypeId = widget.assignCostCenter.fuelTypeId; // ADD THIS

    // Set the search field with the selected cost center
    if (widget.assignCostCenter.costCenter != null) {
      _costCenterSearchController.text =
          '${widget.assignCostCenter.costCenter!.code} - ${widget.assignCostCenter.costCenter!.name}';
      _showCostCenterDropdown = false;
    }

    // Set the search field with the selected fuel type - ADD THIS
    if (widget.assignCostCenter.fuelType != null) {
      _fuelTypeSearchController.text =
          '${widget.assignCostCenter.fuelType!.code} - ${widget.assignCostCenter.fuelType!.name}';
      _showFuelTypeDropdown = false;
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    _costCenterSearchController.dispose();
    _fuelTypeSearchController.dispose(); // ADD THIS
    _scrollController.dispose();
    super.dispose();
  }

  // ADD THESE METHODS
  void _filterFuelTypes(String query) {
    setState(() {
      _fuelTypeSearchQuery = query;
      if (query.isEmpty) {
        _filteredFuelTypes = List.from(widget.fuelTypes);
      } else {
        _filteredFuelTypes = widget.fuelTypes
            .where((fuelType) =>
                fuelType.name.toLowerCase().contains(query.toLowerCase()) ||
                fuelType.code.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
      _showFuelTypeDropdown = true;
    });
  }

  void _selectFuelType(FuelType fuelType) {
    setState(() {
      _selectedFuelTypeId = fuelType.id;
      _fuelTypeSearchController.text = '${fuelType.code} - ${fuelType.name}';
      _showFuelTypeDropdown = false;
    });
  }

  void _clearFuelTypeSelection() {
    setState(() {
      _selectedFuelTypeId = null;
      _fuelTypeSearchController.clear();
      _showFuelTypeDropdown = true;
      _filteredFuelTypes = List.from(widget.fuelTypes);
    });
  }

  void _toggleFuelTypeDropdown() {
    setState(() {
      _showFuelTypeDropdown = !_showFuelTypeDropdown;
      if (_showFuelTypeDropdown && _fuelTypeSearchQuery.isEmpty) {
        _filteredFuelTypes = List.from(widget.fuelTypes);
      }
    });
  }

  void _filterCostCenters(String query) {
    setState(() {
      _costCenterSearchQuery = query;
      if (query.isEmpty) {
        _filteredCostCenters = List.from(widget.costCenters);
      } else {
        _filteredCostCenters = widget.costCenters
            .where((costCenter) =>
                costCenter.name.toLowerCase().contains(query.toLowerCase()) ||
                costCenter.code.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
      _showCostCenterDropdown = true;
    });
  }

  void _selectCostCenter(CostCenter costCenter) {
    setState(() {
      _selectedCostCenterId = costCenter.id;
      _costCenterSearchController.text =
          '${costCenter.code} - ${costCenter.name}';
      _showCostCenterDropdown = false;
    });
  }

  void _clearCostCenterSelection() {
    setState(() {
      _selectedCostCenterId = null;
      _costCenterSearchController.clear();
      _showCostCenterDropdown = true;
      _filteredCostCenters = List.from(widget.costCenters);
    });
  }

  void _toggleDropdown() {
    setState(() {
      _showCostCenterDropdown = !_showCostCenterDropdown;
      if (_showCostCenterDropdown && _costCenterSearchQuery.isEmpty) {
        _filteredCostCenters = List.from(widget.costCenters);
      }
    });
  }

// In _EditAssignCostCenterDialogState
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCostCenterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار مركز التكلفة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedFuelTypeId == null) {
      // NEW VALIDATION
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار نوع المحروقات'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SupabaseService.updateAssignCostCenter(
        id: widget.assignCostCenter.id,
        number: _numberController.text.trim(),
        costCenterId: _selectedCostCenterId!,
        fuelTypeId: _selectedFuelTypeId!, // NEW PARAMETER
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تحديث الشاحنة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          constraints: const BoxConstraints(
            maxWidth: 480,
            maxHeight: 750, // Increased height for fuel type field
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue, // Different color for edit
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'تعديل الشاحنة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),

              // Form Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Truck Number Field
                        const Text(
                          'رقم الشاحنة',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _numberController,
                          decoration: InputDecoration(
                            hintText: 'أدخل رقم الشاحنة',
                            hintStyle: TextStyle(
                                fontSize: 13, color: Colors.grey.shade500),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.blue, // Match header color
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            prefixIcon: Icon(
                              Icons.confirmation_number,
                              color: Colors.grey.shade500,
                              size: 18,
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال رقم الشاحنة';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Cost Center Field
                        const Text(
                          'مركز التكلفة',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _costCenterSearchController,
                          onChanged: _filterCostCenters,
                          onTap: () {
                            if (!_showCostCenterDropdown) {
                              setState(() => _showCostCenterDropdown = true);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'ابحث أو اختر مركز التكلفة',
                            hintStyle: TextStyle(
                                fontSize: 13, color: Colors.grey.shade500),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.blue, // Match header color
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.grey.shade500,
                              size: 18,
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_selectedCostCenterId != null)
                                  IconButton(
                                    onPressed: _clearCostCenterSelection,
                                    icon: Icon(Icons.clear,
                                        size: 16, color: Colors.grey.shade600),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 32, minHeight: 32),
                                  ),
                                IconButton(
                                  onPressed: _toggleDropdown,
                                  icon: AnimatedRotation(
                                    turns: _showCostCenterDropdown ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 150),
                                    child: Icon(Icons.keyboard_arrow_down,
                                        size: 18, color: Colors.grey.shade600),
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                ),
                              ],
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                          validator: (value) {
                            if (_selectedCostCenterId == null) {
                              return 'يرجى اختيار مركز التكلفة';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // NEW: Fuel Type Field
                        const Text(
                          'نوع المحروقات',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _fuelTypeSearchController,
                          onChanged: _filterFuelTypes,
                          onTap: () {
                            if (!_showFuelTypeDropdown) {
                              setState(() => _showFuelTypeDropdown = true);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'ابحث أو اختر نوع المحروقات',
                            hintStyle: TextStyle(
                                fontSize: 13, color: Colors.grey.shade500),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.blue, // Match header color
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            prefixIcon: Icon(
                              Icons.local_gas_station,
                              color: Colors.grey.shade500,
                              size: 18,
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_selectedFuelTypeId != null)
                                  IconButton(
                                    onPressed: _clearFuelTypeSelection,
                                    icon: Icon(Icons.clear,
                                        size: 16, color: Colors.grey.shade600),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 32, minHeight: 32),
                                  ),
                                IconButton(
                                  onPressed: _toggleFuelTypeDropdown,
                                  icon: AnimatedRotation(
                                    turns: _showFuelTypeDropdown ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 150),
                                    child: Icon(Icons.keyboard_arrow_down,
                                        size: 18, color: Colors.grey.shade600),
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                ),
                              ],
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                          validator: (value) {
                            if (_selectedFuelTypeId == null) {
                              return 'يرجى اختيار نوع المحروقات';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 8),

                        // Dropdown sections (cost center and fuel type)
                        if (_showCostCenterDropdown || _showFuelTypeDropdown)
                          Expanded(
                            child: Column(
                              children: [
                                // Cost Center Dropdown
                                if (_showCostCenterDropdown)
                                  Expanded(
                                    flex: _showFuelTypeDropdown ? 1 : 2,
                                    child: _buildCostCenterDropdown(),
                                  ),

                                // Spacing between dropdowns
                                if (_showCostCenterDropdown &&
                                    _showFuelTypeDropdown)
                                  const SizedBox(height: 8),

                                // Fuel Type Dropdown
                                if (_showFuelTypeDropdown)
                                  Expanded(
                                    flex: _showCostCenterDropdown ? 1 : 2,
                                    child: _buildFuelTypeDropdown(),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Action Buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                      child: Text(
                        'إلغاء',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue, // Match header color
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 1,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.update,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                const Text('تحديث',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                              ],
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

// Helper method for cost center dropdown
  Widget _buildCostCenterDropdown() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.list, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  'مراكز التكلفة (${_filteredCostCenters.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          // List
          if (_filteredCostCenters.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _filteredCostCenters.length,
                itemBuilder: (context, index) {
                  final costCenter = _filteredCostCenters[index];
                  final isSelected = _selectedCostCenterId == costCenter.id;
                  return _buildDropdownItem(
                    title: costCenter.name,
                    subtitle: costCenter.code,
                    isSelected: isSelected,
                    onTap: () => _selectCostCenter(costCenter),
                    index: index,
                    totalItems: _filteredCostCenters.length,
                  );
                },
              ),
            ),
          if (_filteredCostCenters.isEmpty) _buildEmptyState(),
        ],
      ),
    );
  }

// Helper method for fuel type dropdown
  Widget _buildFuelTypeDropdown() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.list, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  'أنواع المحروقات (${_filteredFuelTypes.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          // List
          if (_filteredFuelTypes.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _filteredFuelTypes.length,
                itemBuilder: (context, index) {
                  final fuelType = _filteredFuelTypes[index];
                  final isSelected = _selectedFuelTypeId == fuelType.id;
                  return _buildDropdownItem(
                    title: fuelType.name,
                    subtitle: fuelType.code,
                    isSelected: isSelected,
                    onTap: () => _selectFuelType(fuelType),
                    index: index,
                    totalItems: _filteredFuelTypes.length,
                  );
                },
              ),
            ),
          if (_filteredFuelTypes.isEmpty) _buildEmptyState(),
        ],
      ),
    );
  }

// Helper method for dropdown items
  Widget _buildDropdownItem({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required int index,
    required int totalItems,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.withOpacity(0.1) : null,
            border: index < totalItems - 1
                ? Border(bottom: BorderSide(color: Colors.grey.shade200))
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w500 : FontWeight.normal,
                        color: isSelected ? Colors.blue : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color:
                              isSelected ? Colors.white : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }

// Helper method for empty state
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 24, color: Colors.grey.shade400),
          const SizedBox(height: 6),
          Text(
            'لا توجد نتائج',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class FuelManagementScreen extends StatefulWidget {
  const FuelManagementScreen({super.key});

  @override
  State<FuelManagementScreen> createState() => _FuelManagementScreenState();
}

class _FuelManagementScreenState extends State<FuelManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  FuelContact? _selectedFuelContact; // NEW - Store selected fuel contact
  List<FuelContact> _fuelContacts = []; // NEW - Store all fuel contacts
  // Data
  List<FuelFillingRecord> _records = [];
  List<AssignCostCenter> _assignCostCenters = [];
  List<CostCenter> _costCenters = [];
  List<FuelType> _fuelTypes = [];
  List<CostCenterStatistics> _statistics = [];
  List<UserFuelStatistics> _userStatistics = [];

  // State
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isCalculating = false;
  String _syncStatus = '';

  // Filter variables
  DateTime? _filterFromDate;
  DateTime? _filterToDate;
  String? _filterUserId;
  int? _filterCostCenterId;
  String? _filterTruckNumber;
  List<FuelFillingRecord> _filteredRecords = [];
  List<AppUser> _users = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 3. UPDATE: Load fuel contacts data
  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    try {
      final futures = await Future.wait([
        SupabaseService.getFuelFillingRecords(),
        SupabaseService.getAssignCostCenters(),
        SupabaseService.getCostCenters(),
        SupabaseService.getFuelTypes(),
        SupabaseService.getUsers(),
        FuelService.getFuelContacts(), // NEW
      ]);

      _records = futures[0] as List<FuelFillingRecord>;
      _assignCostCenters = futures[1] as List<AssignCostCenter>;
      _costCenters = futures[2] as List<CostCenter>;
      _fuelTypes = futures[3] as List<FuelType>;
      _users = futures[4] as List<AppUser>;
      _fuelContacts = futures[5] as List<FuelContact>; // NEW

      _filteredRecords = List.from(_records);

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('فشل في تحميل البيانات: $e', true);
    }
  }

  Future<bool> _isCurrentUserAdmin() async {
    try {
      final currentUser = await SupabaseService.getCurrentUser();
      return currentUser?.isAdmin ?? false;
    } catch (e) {
      return false;
    }
  }

// Delete record method with admin check
  Future<void> _deleteRecord(FuelFillingRecord record) async {
    // Check admin permission first
    final isAdmin = await _isCurrentUserAdmin();
    if (!isAdmin) {
      _showSnackBar('غير مصرح لك بحذف السجلات', true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف السجل'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('هل تريد حذف سجل التعبئة التالي؟'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الشاحنة: ${record.truckNumber}'),
                    Text(
                        'التاريخ: ${DateFormat('dd/MM/yyyy').format(record.fillingDate)}'),
                    Text('المبلغ: ${FuelService.formatAmount(record.amount)}'),
                    Text('النوع: ${record.fuelType?.name ?? 'غير محدد'}'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'تحذير: هذا الإجراء لا يمكن التراجع عنه!',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
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
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        setState(() => _isLoading = true);
        await SupabaseService.deleteFuelFillingRecord(record.id);
        await _loadAllData();
        _showSnackBar('تم حذف السجل بنجاح', false);
      } catch (e) {
        _showSnackBar('فشل في حذف السجل: $e', true);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

// Show edit record dialog with admin check
  Future<void> _showEditRecordDialog(FuelFillingRecord record) async {
    // Check admin permission first
    final isAdmin = await _isCurrentUserAdmin();
    if (!isAdmin) {
      _showSnackBar('غير مصرح لك بتعديل السجلات', true);
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EditFuelRecordDialog(
        record: record,
        assignCostCenters: _assignCostCenters,
        fuelTypes: _fuelTypes,
      ),
    );

    if (result == true) {
      await _loadAllData();
      _showSnackBar('تم تحديث السجل بنجاح', false);
    }
  }

  // 7. UPDATE: _buildRecordRow to include fuel contact column
  Widget _buildRecordRow(FuelFillingRecord record, int index) {
    final isEven = index % 2 == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isEven ? Colors.white : Colors.grey.shade50,
        border: const Border(
          bottom: BorderSide(color: Colors.grey, width: 0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('dd/MM/yyyy').format(record.fillingDate),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              record.truckNumber,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  record.assignCostCenter?.costCenter?.name ?? 'غير محدد',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (record.assignCostCenter?.costCenter?.code != null)
                  Text(
                    record.assignCostCenter!.costCenter!.code,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              record.fuelType?.name ?? 'غير محدد',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          // NEW: Fuel Contact Column
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  record.fuelContact?.name ?? 'غير محدد',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (record.fuelContact?.code != null)
                  Text(
                    record.fuelContact!.code,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              FuelService.formatAmount(record.amount),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textDirection: ui.TextDirection.ltr,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${FuelService.formatAmount(record.quantity)} لتر',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textDirection: ui.TextDirection.ltr,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              record.meterReading ?? '--',
              style: const TextStyle(fontSize: 12),
              textDirection: ui.TextDirection.ltr,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: FutureBuilder<Map<String, String>>(
              future: SupabaseService.getUsersByIds([record.userId]),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(
                    snapshot.data![record.userId] ?? 'غير معروف',
                    style: const TextStyle(fontSize: 12),
                  );
                }
                return const Text('...', style: TextStyle(fontSize: 12));
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: record.imageUrl != null
                ? IconButton(
                    icon: const Icon(Icons.image,
                        color: Color(AppConstants.accentColor), size: 18),
                    onPressed: () => _showImageDialog(record.imageUrl!),
                    tooltip: 'عرض الصورة',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  )
                : const Icon(Icons.image_not_supported,
                    color: Colors.grey, size: 16),
          ),
          Expanded(
            flex: 1,
            child: FutureBuilder<bool>(
              future: _isCurrentUserAdmin(),
              builder: (context, snapshot) {
                final isAdmin = snapshot.data ?? false;
                if (!isAdmin) {
                  return const SizedBox();
                }

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.edit, size: 16, color: Colors.blue),
                      onPressed: () => _showEditRecordDialog(record),
                      tooltip: 'تعديل',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon:
                          const Icon(Icons.delete, size: 16, color: Colors.red),
                      onPressed: () => _deleteRecord(record),
                      tooltip: 'حذف',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _applyFilters() {
    setState(() {
      _filteredRecords = _records.where((record) {
        // Date filter
        if (_filterFromDate != null &&
            record.fillingDate.isBefore(_filterFromDate!)) {
          return false;
        }
        if (_filterToDate != null &&
            record.fillingDate.isAfter(_filterToDate!)) {
          return false;
        }

        // User filter
        if (_filterUserId != null && record.userId != _filterUserId) {
          return false;
        }

        // Cost center filter
        if (_filterCostCenterId != null &&
            record.assignCostCenter?.costCenter?.id != _filterCostCenterId) {
          return false;
        }

        // Truck number filter
        if (_filterTruckNumber != null &&
            _filterTruckNumber!.isNotEmpty &&
            !record.truckNumber
                .toLowerCase()
                .contains(_filterTruckNumber!.toLowerCase())) {
          return false;
        }

        return true;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _filterFromDate = null;
      _filterToDate = null;
      _filterUserId = null;
      _filterCostCenterId = null;
      _filterTruckNumber = null;
      _filteredRecords = List.from(_records);
    });
  }

  Future<void> _syncData(String type) async {
    setState(() {
      _isSyncing = true;
      _syncStatus = type == 'cost_centers'
          ? 'جارٍ مزامنة مراكز التكلفة...'
          : type == 'fuel_types'
              ? 'جارٍ مزامنة أنواع المحروقات...'
              : 'جارٍ مزامنة محطات المحروقات...';
    });

    try {
      if (type == 'cost_centers') {
        await FuelService.syncCostCenters();
        _costCenters = await SupabaseService.getCostCenters();
        _syncStatus = 'تمت مزامنة مراكز التكلفة بنجاح';
      } else if (type == 'fuel_types') {
        await FuelService.syncFuelTypes();
        _fuelTypes = await SupabaseService.getFuelTypes();
        _syncStatus = 'تمت مزامنة أنواع المحروقات بنجاح';
      } else {
        await FuelService.syncFuelContacts();
        _syncStatus = 'تمت مزامنة محطات المحروقات بنجاح';
      }

      _showSnackBar(_syncStatus, false);

      // Wait a moment then clear status
      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _syncStatus = '';
      });
    } catch (e) {
      setState(() {
        _syncStatus = 'فشل في المزامنة: $e';
      });
      _showSnackBar(_syncStatus, true);
    } finally {
      setState(() => _isSyncing = false);
    }
  }

// Complete _calculateStatistics method for FuelManagementScreen
// Add this method to your _FuelManagementScreenState class

  // 5. NEW: Get available fuel contacts from records
  List<FuelContact> _getAvailableFuelContacts() {
    // Get unique fuel contact IDs from records
    final fuelContactIds = _records
        .where((record) => record.fuelContactId != null)
        .map((record) => record.fuelContactId!)
        .toSet()
        .toList();

    // Filter fuel contacts that exist in records
    return _fuelContacts
        .where((contact) => fuelContactIds.contains(contact.id))
        .toList();
  }

  // 4. UPDATE: _calculateStatistics method
  Future<void> _calculateStatistics() async {
    // Get available fuel contacts from current records
    final availableFuelContacts = _getAvailableFuelContacts();

    if (availableFuelContacts.isEmpty) {
      _showSnackBar('لا توجد محطات محروقات في السجلات الحالية', true);
      return;
    }

    // Show date range and fuel contact selection dialog
    final filterData = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DateRangeSelectionDialog(
        availableFuelContacts: availableFuelContacts,
      ),
    );

    if (filterData == null) return;

    setState(() => _isCalculating = true);

    try {
      // Store selected fuel contact for later use in journal posting
      _selectedFuelContact = filterData['fuelContact'] as FuelContact;

      // Get statistics with filters
      _statistics = await SupabaseService.getCostCenterStatisticsWithFilters(
        fromDate: filterData['fromDate'],
        toDate: filterData['toDate'],
        fuelContactId: _selectedFuelContact!.id, // Filter by fuel contact
      );

      setState(() {});

      // Show success message
      _showSnackBar(
        'تم حساب الحسابات للفترة من ${DateFormat('dd/MM/yyyy').format(filterData['fromDate'])} '
        'إلى ${DateFormat('dd/MM/yyyy').format(filterData['toDate'])} '
        'لمحطة: ${_selectedFuelContact!.name}',
        false,
      );
    } catch (e) {
      _showSnackBar('فشل في حساب الحسابات: $e', true);
    } finally {
      setState(() => _isCalculating = false);
    }
  }

  // 6. UPDATE: _showJournalVoucherDialog to use selected fuel contact
  Future<void> _showJournalVoucherDialog() async {
    if (_statistics.isEmpty) {
      _showSnackBar('يرجى حساب الحسابات أولاً', true);
      return;
    }

    if (_selectedFuelContact == null) {
      _showSnackBar('لم يتم تحديد محطة المحروقات', true);
      return;
    }

    final result = await showDialog<JournalVoucherData>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _JournalVoucherDialog(
        selectedFuelContact: _selectedFuelContact!, // Pass selected contact
      ),
    );

    if (result != null) {
      final validationError = FuelService.validateJournalVoucherData(result);
      if (validationError != null) {
        _showSnackBar(validationError, true);
        return;
      }

      await _postJournalVoucher(result);
    }
  }

// Updated _postJournalVoucher method
  Future<void> _postJournalVoucher(JournalVoucherData data) async {
    try {
      setState(() => _isLoading = true);

      final response = await FuelService.postJournalVoucher(
        statistics: _statistics.where((s) => s.totalAmount > 0).toList(),
        voucherData: data,
      );

      _showSnackBar('تم ترحيل القيد بنجاح', false);

      // Show response details if needed
      print('Journal Voucher Response: $response');

      // Show confirmation dialog with details
      showDialog(
        context: context,
        builder: (context) => Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('تم الترحيل بنجاح'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تم ترحيل القيد المحاسبي بنجاح إلى نظام بيسان'),
                SizedBox(height: 8),
                Text('رقم جهة الاتصال: ${data.contactNumber}'),
                Text('مرجع الضريبة: ${data.taxReference}'),
                Text(
                    'تاريخ الفاتورة: ${DateFormat('dd/MM/yyyy').format(data.invoiceDate)}'),
                if (response['id'] != null)
                  Text('رقم المعاملة: ${response['id']}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('موافق'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _showSnackBar('فشل في ترحيل القيد: $e', true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: _buildAppBar(),
        body: _isLoading ? _buildLoadingIndicator() : _buildTabContent(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: const Text(
        'إدارة المحروقات',
        style: TextStyle(
          color: Color(AppConstants.primaryColor),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
// Update the AppBar tabs
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: const Color(AppConstants.accentColor),
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: const Color(AppConstants.accentColor),
        tabs: const [
          Tab(text: 'السجلات'),
          Tab(text: 'تخصيص الشاحنات'),
          Tab(text: 'الحسابات'),
          Tab(text: 'إحصائيات المستخدمين'), // NEW TAB
          Tab(text: 'المزامنة'),
          Tab(text: 'الترحيل'),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(AppConstants.accentColor)),
          SizedBox(height: 16),
          Text(
            'جارٍ التحميل...',
            style: TextStyle(
              fontSize: 16,
              color: Color(AppConstants.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

// Update the TabBarView to include the new tab
  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildRecordsTab(),
        _buildAssignCostCentersTab(),
        _buildStatisticsTab(),
        _buildUserStatisticsTab(), // NEW TAB
        _buildSyncTab(),
        _buildJournalTab(),
      ],
    );
  }

  Widget _buildRecordsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildRecordsHeader(),
          const SizedBox(height: 16),
          _buildFiltersSection(),
          const SizedBox(height: 16),
          Expanded(child: _buildRecordsTable()),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list,
                  color: Color(AppConstants.accentColor)),
              const SizedBox(width: 8),
              const Text(
                'فلترة السجلات',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(AppConstants.primaryColor),
                ),
              ),
              const Spacer(),
              if (_hasActiveFilters())
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('مسح الفلترة'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              // Date range filter
              SizedBox(
                width: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('من تاريخ:',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _filterFromDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          locale: const Locale('ar'),
                        );
                        if (picked != null) {
                          setState(() => _filterFromDate = picked);
                          _applyFilters();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _filterFromDate != null
                                    ? DateFormat('dd/MM/yyyy')
                                        .format(_filterFromDate!)
                                    : 'اختر التاريخ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _filterFromDate != null
                                      ? Colors.black87
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            Icon(Icons.calendar_today,
                                size: 16, color: Colors.grey.shade600),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // To date filter
              SizedBox(
                width: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إلى تاريخ:',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _filterToDate ?? DateTime.now(),
                          firstDate: _filterFromDate ?? DateTime(2020),
                          lastDate: DateTime.now(),
                          locale: const Locale('ar'),
                        );
                        if (picked != null) {
                          setState(() => _filterToDate = picked);
                          _applyFilters();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _filterToDate != null
                                    ? DateFormat('dd/MM/yyyy')
                                        .format(_filterToDate!)
                                    : 'اختر التاريخ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _filterToDate != null
                                      ? Colors.black87
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            Icon(Icons.calendar_today,
                                size: 16, color: Colors.grey.shade600),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // User filter
              SizedBox(
                width: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('المستخدم:',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _filterUserId,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        isDense: true,
                      ),
                      hint: const Text('كل المستخدمين',
                          style: TextStyle(fontSize: 12)),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('كل المستخدمين',
                              style: TextStyle(fontSize: 12)),
                        ),
                        ..._users.map((user) => DropdownMenuItem<String>(
                              value: user.id,
                              child: Text(user.username,
                                  style: const TextStyle(fontSize: 12)),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() => _filterUserId = value);
                        _applyFilters();
                      },
                    ),
                  ],
                ),
              ),

              // Cost center filter
              SizedBox(
                width: 250, // Increased width
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('مركز التكلفة:',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<int>(
                      value: _filterCostCenterId,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        isDense: true,
                      ),
                      hint: const Text('كل مراكز التكلفة',
                          style: TextStyle(fontSize: 12)),
                      isExpanded: true, // This is crucial to prevent overflow
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('كل مراكز التكلفة',
                              style: TextStyle(fontSize: 12)),
                        ),
                        ..._costCenters.map((center) => DropdownMenuItem<int>(
                              value: center.id,
                              child: SizedBox(
                                width: double.infinity,
                                child: Text(
                                  '${center.code} - ${center.name}',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() => _filterCostCenterId = value);
                        _applyFilters();
                      },
                    ),
                  ],
                ),
              ),
              // Truck number filter
              SizedBox(
                width: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('رقم الشاحنة:',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    TextFormField(
                      decoration: InputDecoration(
                        hintText: 'ابحث برقم الشاحنة',
                        hintStyle: const TextStyle(fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 12),
                      onChanged: (value) {
                        setState(() => _filterTruckNumber = value);
                        _applyFilters();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return _filterFromDate != null ||
        _filterToDate != null ||
        _filterUserId != null ||
        _filterCostCenterId != null ||
        (_filterTruckNumber != null && _filterTruckNumber!.isNotEmpty);
  }

  Widget _buildRecordsHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'سجلات تعبئة المحروقات (${_filteredRecords.length}${_filteredRecords.length != _records.length ? ' من ${_records.length}' : ''})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(AppConstants.primaryColor),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _exportToExcel,
            icon:
                const Icon(Icons.file_download, size: 18, color: Colors.white),
            label: const Text('تصدير Excel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _loadAllData,
            icon: const Icon(Icons.refresh, size: 18, color: Colors.white),
            label: const Text('تحديث'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConstants.accentColor),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  // 8. UPDATE: Table header to include fuel contact column
  Widget _buildRecordsTable() {
    if (_filteredRecords.isEmpty) {
      return _buildEmptyState(_records.isEmpty
          ? 'لا توجد سجلات تعبئة محروقات'
          : 'لا توجد سجلات تطابق الفلترة المحددة');
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header - UPDATED with fuel contact column
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                    flex: 2,
                    child: Text('التاريخ',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13))),
                Expanded(
                    flex: 2,
                    child: Text('الشاحنة',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13))),
                Expanded(
                    flex: 3,
                    child: Text('مركز التكلفة',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13))),
                Expanded(
                    flex: 2,
                    child: Text('النوع',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13))),
                // NEW COLUMN
                Expanded(
                    flex: 2,
                    child: Text('محطة المحروقات',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13))),
                Expanded(
                    flex: 2,
                    child: Text('المبلغ',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13))),
                Expanded(
                    flex: 2,
                    child: Text('الكمية',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13))),
                Expanded(
                    flex: 2,
                    child: Text('رقم العداد',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13))),
                Expanded(
                    flex: 2,
                    child: Text('المستخدم',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13))),
                Expanded(
                    flex: 1,
                    child: Text('صورة',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13))),
              ],
            ),
          ),
          // Table Body
          Expanded(
            child: ListView.builder(
              itemCount: _filteredRecords.length,
              itemBuilder: (context, index) {
                final record = _filteredRecords[index];
                return _buildRecordRow(record, index);
              },
            ),
          ),
        ],
      ),
    );
  }

// Updated _exportToExcel method without HTML
  Future<void> _exportToExcel() async {
    try {
      setState(() => _isLoading = true);

      final xlsio.Workbook workbook = xlsio.Workbook();
      final xlsio.Worksheet worksheet = workbook.worksheets[0];

      worksheet.isRightToLeft = true;
      worksheet.name = 'سجلات المحروقات';

      // Updated headers with new columns
      final List<String> headers = [
        'التاريخ',
        'رقم الشاحنة',
        'كود مركز التكلفة',
        'اسم مركز التكلفة',
        'نوع المحروقات',
        'المبلغ',
        'الكمية (لتر)', // NEW
        'رقم العداد', // NEW
        'اسم المستخدم',
        'تاريخ الإدخال',
      ];

      // Set headers
      for (int i = 0; i < headers.length; i++) {
        final xlsio.Range headerCell = worksheet.getRangeByIndex(1, i + 1);
        headerCell.setText(headers[i]);
        headerCell.cellStyle.bold = true;
        headerCell.cellStyle.backColor = '#E3F2FD';
        headerCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        headerCell.cellStyle.hAlign = xlsio.HAlignType.center;
        headerCell.columnWidth = 15;
      }

      // Get user names
      final Set<String> userIds = _filteredRecords.map((r) => r.userId).toSet();
      final Map<String, String> userNames =
          await SupabaseService.getUsersByIds(userIds.toList());

      // Add data rows
      for (int i = 0; i < _filteredRecords.length; i++) {
        final record = _filteredRecords[i];
        final rowIndex = i + 2;

        worksheet
            .getRangeByIndex(rowIndex, 1)
            .setText(DateFormat('dd/MM/yyyy').format(record.fillingDate));

        worksheet.getRangeByIndex(rowIndex, 2).setText(record.truckNumber);

        worksheet
            .getRangeByIndex(rowIndex, 3)
            .setText(record.assignCostCenter?.costCenter?.code ?? 'غير محدد');

        worksheet
            .getRangeByIndex(rowIndex, 4)
            .setText(record.assignCostCenter?.costCenter?.name ?? 'غير محدد');

        worksheet
            .getRangeByIndex(rowIndex, 5)
            .setText(record.fuelType?.name ?? 'غير محدد');

        worksheet.getRangeByIndex(rowIndex, 6).setNumber(record.amount);

        // NEW: Quantity column
        worksheet.getRangeByIndex(rowIndex, 7).setNumber(record.quantity);

        // NEW: Meter reading column
        worksheet
            .getRangeByIndex(rowIndex, 8)
            .setText(record.meterReading ?? '');

        worksheet
            .getRangeByIndex(rowIndex, 9)
            .setText(userNames[record.userId] ?? 'غير معروف');

        worksheet.getRangeByIndex(rowIndex, 10).setText(
            DateFormat('dd/MM/yyyy HH:mm')
                .format(record.createdAt ?? record.fillingDate));

        // Apply borders
        for (int col = 1; col <= headers.length; col++) {
          worksheet
              .getRangeByIndex(rowIndex, col)
              .cellStyle
              .borders
              .all
              .lineStyle = xlsio.LineStyle.thin;
        }
      }

      // Auto-fit columns
      for (int col = 1; col <= headers.length; col++) {
        worksheet.autoFitColumn(col);
      }

      // Add summary rows
      final summaryRowIndex = _filteredRecords.length + 3;
      worksheet.getRangeByIndex(summaryRowIndex, 1).setText('إجمالي السجلات:');
      worksheet
          .getRangeByIndex(summaryRowIndex, 2)
          .setText('${_filteredRecords.length}');
      worksheet.getRangeByIndex(summaryRowIndex, 1).cellStyle.bold = true;
      worksheet.getRangeByIndex(summaryRowIndex, 2).cellStyle.bold = true;

      final totalAmount = _filteredRecords.fold<double>(
          0, (sum, record) => sum + record.amount);
      final totalQuantity = _filteredRecords.fold<double>(
          0, (sum, record) => sum + record.quantity);

      worksheet
          .getRangeByIndex(summaryRowIndex + 1, 1)
          .setText('إجمالي المبلغ:');
      worksheet.getRangeByIndex(summaryRowIndex + 1, 2).setNumber(totalAmount);
      worksheet.getRangeByIndex(summaryRowIndex + 1, 1).cellStyle.bold = true;
      worksheet.getRangeByIndex(summaryRowIndex + 1, 2).cellStyle.bold = true;

      // NEW: Total quantity summary
      worksheet
          .getRangeByIndex(summaryRowIndex + 2, 1)
          .setText('إجمالي الكمية:');
      worksheet
          .getRangeByIndex(summaryRowIndex + 2, 2)
          .setNumber(totalQuantity);
      worksheet.getRangeByIndex(summaryRowIndex + 2, 1).cellStyle.bold = true;
      worksheet.getRangeByIndex(summaryRowIndex + 2, 2).cellStyle.bold = true;

      // Save and download using FileUtils
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final String fileName =
          'سجلات_المحروقات_${DateFormat('yyyy_MM_dd_HH_mm').format(DateTime.now())}.xlsx';

      // Use FileUtils for downloading
      await _downloadExcelFile(bytes, fileName);

      _showSnackBar('تم تصدير الملف بنجاح', false);
    } catch (e) {
      _showSnackBar('فشل في تصدير الملف: $e', true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildAssignCostCentersTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildAssignCostCentersHeader(),
          const SizedBox(height: 16),
          Expanded(child: _buildAssignCostCentersTable()),
        ],
      ),
    );
  }

  Widget _buildAssignCostCentersHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'تخصيص أرقام الشاحنات (${_assignCostCenters.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(AppConstants.primaryColor),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _showAddAssignCostCenterDialog,
            icon: const Icon(
              Icons.add,
              size: 18,
              color: Colors.white,
            ),
            label: const Text('إضافة شاحنة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConstants.accentColor),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignCostCentersTable() {
    if (_assignCostCenters.isEmpty) {
      return _buildEmptyState('لا توجد شاحنات مخصصة');
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                    flex: 2,
                    child: Text('رقم الشاحنة',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                Expanded(
                    flex: 3,
                    child: Text('مركز التكلفة',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                Expanded(
                    flex: 2,
                    child: Text('كود المركز',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                Expanded(
                    flex: 1,
                    child: Text('الإجراءات',
                        style: TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          // Table Body
          Expanded(
            child: ListView.builder(
              itemCount: _assignCostCenters.length,
              itemBuilder: (context, index) {
                final assign = _assignCostCenters[index];
                final isEven = index % 2 == 0;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isEven ? Colors.white : Colors.grey.shade50,
                    border: const Border(
                      bottom: BorderSide(color: Colors.grey, width: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(assign.number)),
                      Expanded(
                          flex: 3,
                          child: Text(assign.costCenter?.name ?? 'غير محدد')),
                      Expanded(
                          flex: 2,
                          child: Text(assign.costCenter?.code ?? 'غير محدد')),
                      Expanded(
                        flex: 1,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () =>
                                  _showEditAssignCostCenterDialog(assign),
                              tooltip: 'تعديل',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  size: 18, color: Colors.red),
                              onPressed: () => _deleteAssignCostCenter(assign),
                              tooltip: 'حذف',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStatisticsHeader(),
          const SizedBox(height: 16),
          if (_statistics.isNotEmpty) ...[
            _buildStatisticsSummary(),
            const SizedBox(height: 16),
          ],
          Expanded(child: _buildStatisticsTable()),
        ],
      ),
    );
  }

  Widget _buildStatisticsHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'حسابات مراكز التكلفة',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(AppConstants.primaryColor),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isCalculating ? null : _calculateStatistics,
            icon: _isCalculating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.calculate, size: 18, color: Colors.white),
            label: Text(_isCalculating ? 'جارٍ الحساب...' : 'حساب'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConstants.accentColor),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

// Update _buildStatisticsSummary method to include quantity
  Widget _buildStatisticsSummary() {
    final summary = FuelService.calculateStatisticsSummary(_statistics);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'ملخص الحسابات',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(AppConstants.primaryColor),
                ),
              ),
              const Spacer(),
              if (_statistics.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.filter_list,
                          size: 14, color: Colors.blue.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'مفلتر',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'إجمالي المبلغ',
                  FuelService.formatAmount(summary['total_amount']),
                  Icons.attach_money,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              // NEW: Total Quantity Card
              Expanded(
                child: _buildSummaryCard(
                  'إجمالي الكمية',
                  '${FuelService.formatAmount(summary['total_quantity'])} لتر',
                  Icons.local_gas_station,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'الضريبة (16%)',
                  FuelService.formatAmount(summary['tax_amount']),
                  Icons.percent,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'المجموع الكلي',
                  FuelService.formatAmount(summary['grand_total']),
                  Icons.receipt,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'عدد السجلات',
                  '${summary['total_records']}',
                  Icons.list_alt,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            textDirection: ui.TextDirection.ltr,
          ),
        ],
      ),
    );
  }

// Update statistics table to include quantity column
  Widget _buildStatisticsTable() {
    if (_statistics.isEmpty) {
      return _buildEmptyState(
          'لا توجد حسابات. اضغط على "حساب" لتحديث البيانات.');
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header - UPDATED with quantity column
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                    flex: 2,
                    child: Text('رقم الشاحنة',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                Expanded(
                    flex: 3,
                    child: Text('مركز التكلفة',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                Expanded(
                    flex: 2,
                    child: Text('كود المركز',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                Expanded(
                    flex: 2,
                    child: Text('إجمالي المبلغ',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                // NEW COLUMN
                Expanded(
                    flex: 2,
                    child: Text('إجمالي الكمية',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                Expanded(
                    flex: 1,
                    child: Text('عدد السجلات',
                        style: TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          // Table Body
          Expanded(
            child: ListView.builder(
              itemCount: _statistics.length,
              itemBuilder: (context, index) {
                final stat = _statistics[index];
                final isEven = index % 2 == 0;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isEven ? Colors.white : Colors.grey.shade50,
                    border: const Border(
                      bottom: BorderSide(color: Colors.grey, width: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(stat.truckNumber)),
                      Expanded(flex: 3, child: Text(stat.costCenterName)),
                      Expanded(flex: 2, child: Text(stat.costCenterCode)),
                      Expanded(
                        flex: 2,
                        child: Text(
                          FuelService.formatAmount(stat.totalAmount),
                          style: TextStyle(
                            fontWeight: stat.totalAmount > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: stat.totalAmount > 0
                                ? Colors.green.shade700
                                : Colors.grey,
                          ),
                          textDirection: ui.TextDirection.ltr,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // NEW: Quantity Column
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${FuelService.formatAmount(stat.totalQuantity)} لتر',
                          style: TextStyle(
                            fontWeight: stat.totalQuantity > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: stat.totalQuantity > 0
                                ? Colors.blue.shade700
                                : Colors.grey,
                          ),
                          textDirection: ui.TextDirection.ltr,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(flex: 1, child: Text('${stat.recordCount}')),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

// Add this to the FuelManagementScreen tabs
  Widget _buildUserStatisticsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildUserStatisticsHeader(),
          const SizedBox(height: 16),
          if (_userStatistics.isNotEmpty) ...[
            _buildUserStatisticsSummary(),
            const SizedBox(height: 16),
          ],
          Expanded(child: _buildUserStatisticsTable()),
        ],
      ),
    );
  }

// Updated _calculateUserStatistics method
  Future<void> _calculateUserStatistics() async {
    // Get available fuel contacts from current records
    final availableFuelContacts = _getAvailableFuelContacts();

    if (availableFuelContacts.isEmpty) {
      _showSnackBar('لا توجد محطات محروقات في السجلات الحالية', true);
      return;
    }

    final filterData = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DateRangeSelectionDialog(
        availableFuelContacts: availableFuelContacts, // ADD THIS
      ),
    );

    if (filterData == null) return;

    setState(() => _isCalculating = true);

    try {
      // Store selected fuel contact if you want to use it for filtering
      final selectedFuelContact = filterData['fuelContact'] as FuelContact?;

      // Get user statistics with optional fuel contact filter
      _userStatistics = await SupabaseService.getUserFuelStatistics(
        fromDate: filterData['fromDate'],
        toDate: filterData['toDate'],
        fuelContactId: selectedFuelContact
            ?.id, // ADD THIS if you want to filter by fuel contact
      );

      setState(() {});

      // Update success message to include fuel contact info
      String message = 'تم حساب إحصائيات المستخدمين للفترة من '
          '${DateFormat('dd/MM/yyyy').format(filterData['fromDate'])} '
          'إلى ${DateFormat('dd/MM/yyyy').format(filterData['toDate'])}';

      if (selectedFuelContact != null) {
        message += ' لمحطة: ${selectedFuelContact.name}';
      }

      _showSnackBar(message, false);
    } catch (e) {
      _showSnackBar('فشل في حساب إحصائيات المستخدمين: $e', true);
    } finally {
      setState(() => _isCalculating = false);
    }
  }

// Updated _exportUserStatisticsToExcel method without HTML
  Future<void> _exportUserStatisticsToExcel() async {
    try {
      setState(() => _isLoading = true);

      // Get filtered records for detailed breakdown
      List<FuelFillingRecord> userRecords = [];
      if (_userStatistics.isNotEmpty) {
        // We need to get the detailed records for the same date range
        // Since we don't store the filter data, we'll get all records and filter them
        userRecords = _records.where((record) {
          // Apply the same filters that were used for user statistics
          // You might want to store the filter parameters to be more precise
          return _userStatistics.any((stat) => stat.userId == record.userId);
        }).toList();

        // Sort by user and then by date
        userRecords.sort((a, b) {
          int userCompare = a.userId.compareTo(b.userId);
          if (userCompare != 0) return userCompare;
          return a.fillingDate.compareTo(b.fillingDate);
        });
      }

      // Get user names mapping
      final Set<String> userIds = _userStatistics.map((r) => r.userId).toSet();
      final Map<String, String> userNames =
          await SupabaseService.getUsersByIds(userIds.toList());

      final xlsio.Workbook workbook = xlsio.Workbook();
      final xlsio.Worksheet worksheet = workbook.worksheets[0];

      worksheet.isRightToLeft = true;
      worksheet.name = 'إحصائيات المستخدمين المفصلة';

      int currentRow = 1;

      // Main title
      worksheet
          .getRangeByIndex(currentRow, 1)
          .setText('تقرير إحصائيات المستخدمين - تفصيلي');
      worksheet.getRangeByIndex(currentRow, 1).cellStyle.bold = true;
      worksheet.getRangeByIndex(currentRow, 1).cellStyle.fontSize = 16;
      worksheet.getRangeByIndex(currentRow, 1).cellStyle.backColor = '#1976D2';
      worksheet.getRangeByIndex(currentRow, 1).cellStyle.fontColor = '#FFFFFF';
      worksheet.getRangeByIndex(currentRow, 1, currentRow, 9).merge();
      worksheet.getRangeByIndex(currentRow, 1).cellStyle.hAlign =
          xlsio.HAlignType.center;

      currentRow += 2;

      // Overall summary section
      worksheet.getRangeByIndex(currentRow, 1).setText('الملخص العام');
      worksheet.getRangeByIndex(currentRow, 1).cellStyle.bold = true;
      worksheet.getRangeByIndex(currentRow, 1).cellStyle.fontSize = 14;
      worksheet.getRangeByIndex(currentRow, 1).cellStyle.backColor = '#FFF3E0';

      currentRow++;

      final summary =
          FuelService.calculateUserStatisticsSummary(_userStatistics);

      worksheet.getRangeByIndex(currentRow, 1).setText(
          'إجمالي المبالغ: ${FuelService.formatAmount(summary['total_amount'])}');
      worksheet.getRangeByIndex(currentRow, 1).cellStyle.bold = true;

      worksheet.getRangeByIndex(currentRow, 4).setText(
          'إجمالي الكميات: ${FuelService.formatAmount(summary['total_quantity'])} لتر');
      worksheet.getRangeByIndex(currentRow, 4).cellStyle.bold = true;

      worksheet
          .getRangeByIndex(currentRow, 7)
          .setText('إجمالي السجلات: ${summary['total_records']}');
      worksheet.getRangeByIndex(currentRow, 7).cellStyle.bold = true;

      currentRow += 3;

      // Record headers for user tables
      final List<String> recordHeaders = [
        'التاريخ',
        'رقم الشاحنة',
        'كود مركز التكلفة',
        'اسم مركز التكلفة',
        'نوع المحروقات',
        'المبلغ',
        'الكمية (لتر)',
        'رقم العداد',
        'تاريخ الإدخال',
      ];

      // Create tables for each user
      for (final userStat in _userStatistics) {
        // Get records for this specific user
        final userSpecificRecords = userRecords
            .where((record) => record.userId == userStat.userId)
            .toList();

        if (userSpecificRecords.isEmpty) continue;

        // User header section
        worksheet
            .getRangeByIndex(currentRow, 1)
            .setText('المستخدم: ${userStat.username}');
        worksheet.getRangeByIndex(currentRow, 1).cellStyle.bold = true;
        worksheet.getRangeByIndex(currentRow, 1).cellStyle.fontSize = 14;
        worksheet.getRangeByIndex(currentRow, 1).cellStyle.backColor =
            '#E8F5E8';
        worksheet.getRangeByIndex(currentRow, 1, currentRow, 9).merge();

        currentRow++;

        // User summary info
        worksheet.getRangeByIndex(currentRow, 1).setText(
            'إجمالي المبلغ: ${FuelService.formatAmount(userStat.totalAmount)}');
        worksheet.getRangeByIndex(currentRow, 1).cellStyle.bold = true;
        worksheet.getRangeByIndex(currentRow, 1).cellStyle.backColor =
            '#F1F8E9';

        worksheet.getRangeByIndex(currentRow, 4).setText(
            'إجمالي الكمية: ${FuelService.formatAmount(userStat.totalQuantity)} لتر');
        worksheet.getRangeByIndex(currentRow, 4).cellStyle.bold = true;
        worksheet.getRangeByIndex(currentRow, 4).cellStyle.backColor =
            '#F1F8E9';

        worksheet
            .getRangeByIndex(currentRow, 7)
            .setText('عدد السجلات: ${userStat.recordCount}');
        worksheet.getRangeByIndex(currentRow, 7).cellStyle.bold = true;
        worksheet.getRangeByIndex(currentRow, 7).cellStyle.backColor =
            '#F1F8E9';

        currentRow += 2;

        // Records table headers
        for (int i = 0; i < recordHeaders.length; i++) {
          final xlsio.Range headerCell =
              worksheet.getRangeByIndex(currentRow, i + 1);
          headerCell.setText(recordHeaders[i]);
          headerCell.cellStyle.bold = true;
          headerCell.cellStyle.backColor = '#E3F2FD';
          headerCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
          headerCell.cellStyle.hAlign = xlsio.HAlignType.center;
          if (i < 7)
            headerCell.columnWidth = 15;
          else if (i == 7)
            headerCell.columnWidth = 12; // Meter reading column
          else
            headerCell.columnWidth = 18; // Date columns
        }

        currentRow++;

        // Add user records
        double userTotalAmount = 0;
        double userTotalQuantity = 0;

        for (final record in userSpecificRecords) {
          worksheet
              .getRangeByIndex(currentRow, 1)
              .setText(DateFormat('dd/MM/yyyy').format(record.fillingDate));
          worksheet.getRangeByIndex(currentRow, 2).setText(record.truckNumber);
          worksheet
              .getRangeByIndex(currentRow, 3)
              .setText(record.assignCostCenter?.costCenter?.code ?? 'غير محدد');
          worksheet
              .getRangeByIndex(currentRow, 4)
              .setText(record.assignCostCenter?.costCenter?.name ?? 'غير محدد');
          worksheet
              .getRangeByIndex(currentRow, 5)
              .setText(record.fuelType?.name ?? 'غير محدد');
          worksheet.getRangeByIndex(currentRow, 6).setNumber(record.amount);
          worksheet.getRangeByIndex(currentRow, 7).setNumber(record.quantity);
          worksheet
              .getRangeByIndex(currentRow, 8)
              .setText(record.meterReading ?? '');
          worksheet.getRangeByIndex(currentRow, 9).setText(
              DateFormat('dd/MM/yyyy HH:mm')
                  .format(record.createdAt ?? record.fillingDate));

          userTotalAmount += record.amount;
          userTotalQuantity += record.quantity;

          // Apply borders and alternating row colors
          bool isEven = (currentRow % 2) == 0;
          for (int col = 1; col <= recordHeaders.length; col++) {
            worksheet
                .getRangeByIndex(currentRow, col)
                .cellStyle
                .borders
                .all
                .lineStyle = xlsio.LineStyle.thin;
            if (!isEven) {
              worksheet.getRangeByIndex(currentRow, col).cellStyle.backColor =
                  '#F9F9F9';
            }
          }

          currentRow++;
        }

        // Add user totals row
        worksheet
            .getRangeByIndex(currentRow, 1)
            .setText('إجمالي ${userStat.username}');
        worksheet.getRangeByIndex(currentRow, 1).cellStyle.bold = true;
        worksheet.getRangeByIndex(currentRow, 1).cellStyle.backColor =
            '#FFF3E0';

        worksheet.getRangeByIndex(currentRow, 6).setNumber(userTotalAmount);
        worksheet.getRangeByIndex(currentRow, 6).cellStyle.bold = true;
        worksheet.getRangeByIndex(currentRow, 6).cellStyle.backColor =
            '#FFF3E0';

        worksheet.getRangeByIndex(currentRow, 7).setNumber(userTotalQuantity);
        worksheet.getRangeByIndex(currentRow, 7).cellStyle.bold = true;
        worksheet.getRangeByIndex(currentRow, 7).cellStyle.backColor =
            '#FFF3E0';

        worksheet
            .getRangeByIndex(currentRow, 8)
            .setText('${userSpecificRecords.length}');
        worksheet.getRangeByIndex(currentRow, 8).cellStyle.bold = true;
        worksheet.getRangeByIndex(currentRow, 8).cellStyle.backColor =
            '#FFF3E0';

        // Apply borders to totals row
        for (int col = 1; col <= recordHeaders.length; col++) {
          worksheet
              .getRangeByIndex(currentRow, col)
              .cellStyle
              .borders
              .all
              .lineStyle = xlsio.LineStyle.thin;
        }

        currentRow += 3; // Space between user tables
      }

      // Final summary section
      currentRow += 2;
      worksheet
          .getRangeByIndex(currentRow, 1)
          .setText('الإجمالي النهائي لجميع المستخدمين');
      worksheet.getRangeByIndex(currentRow, 1).cellStyle.bold = true;
      worksheet.getRangeByIndex(currentRow, 1).cellStyle.fontSize = 14;
      worksheet.getRangeByIndex(currentRow, 1).cellStyle.backColor = '#FFCDD2';
      worksheet.getRangeByIndex(currentRow, 1, currentRow, 9).merge();
      worksheet.getRangeByIndex(currentRow, 1).cellStyle.hAlign =
          xlsio.HAlignType.center;

      currentRow++;

      worksheet.getRangeByIndex(currentRow, 1).setText('المبلغ الإجمالي');
      worksheet.getRangeByIndex(currentRow, 1).cellStyle.bold = true;
      worksheet.getRangeByIndex(currentRow, 1).cellStyle.backColor = '#FFEBEE';

      worksheet
          .getRangeByIndex(currentRow, 6)
          .setNumber(summary['total_amount']);
      worksheet.getRangeByIndex(currentRow, 6).cellStyle.bold = true;
      worksheet.getRangeByIndex(currentRow, 6).cellStyle.backColor = '#FFEBEE';

      worksheet
          .getRangeByIndex(currentRow, 7)
          .setNumber(summary['total_quantity']);
      worksheet.getRangeByIndex(currentRow, 7).cellStyle.bold = true;
      worksheet.getRangeByIndex(currentRow, 7).cellStyle.backColor = '#FFEBEE';

      worksheet
          .getRangeByIndex(currentRow, 8)
          .setText('${summary['total_records']}');
      worksheet.getRangeByIndex(currentRow, 8).cellStyle.bold = true;
      worksheet.getRangeByIndex(currentRow, 8).cellStyle.backColor = '#FFEBEE';

      // Apply borders to final summary
      for (int col = 1; col <= recordHeaders.length; col++) {
        worksheet
            .getRangeByIndex(currentRow, col)
            .cellStyle
            .borders
            .all
            .lineStyle = xlsio.LineStyle.thin;
      }

      // Auto-fit columns
      for (int col = 1; col <= recordHeaders.length; col++) {
        worksheet.autoFitColumn(col);
      }

      // Save and download using FileUtils
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final String fileName =
          'إحصائيات_المستخدمين_مفصلة_${DateFormat('yyyy_MM_dd_HH_mm').format(DateTime.now())}.xlsx';

      // Use FileUtils for downloading
      await _downloadExcelFile(bytes, fileName);

      _showSnackBar('تم تصدير إحصائيات المستخدمين المفصلة بنجاح', false);
    } catch (e) {
      _showSnackBar('فشل في تصدير إحصائيات المستخدمين: $e', true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

// Helper method to download Excel files using FileUtils
  Future<void> _downloadExcelFile(List<int> bytes, String filename) async {
    try {
      final fileUtils = FileUtils.instance;

      // Convert List<int> to Uint8List if needed
      final uint8bytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

      await fileUtils.downloadFile(
        uint8bytes,
        filename,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      // Optional: Show success message
      if (mounted) {
        _showSnackBar('تم تنزيل الملف: $filename', false);
      }
    } catch (e) {
      print('Error downloading Excel file: $e');
      if (mounted) {
        _showSnackBar(
          'فشل تنزيل الملف: ${e.toString()}',
          true,
        );
      }
    }
  }

// Updated button in _buildUserStatisticsHeader method
  Widget _buildUserStatisticsHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'إحصائيات المستخدمين',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(AppConstants.primaryColor),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isCalculating ? null : _calculateUserStatistics,
            icon: _isCalculating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.people, size: 18, color: Colors.white),
            label: Text(
                _isCalculating ? 'جارٍ الحساب...' : 'حساب إحصائيات المستخدمين'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _userStatistics.isNotEmpty
                ? _exportUserStatisticsToExcel
                : null,
            icon:
                const Icon(Icons.file_download, size: 18, color: Colors.white),
            label: const Text('تصدير تقرير مفصل'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserStatisticsSummary() {
    final summary = FuelService.calculateUserStatisticsSummary(_userStatistics);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ملخص إحصائيات المستخدمين',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(AppConstants.primaryColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'إجمالي المبالغ',
                  FuelService.formatAmount(summary['total_amount']),
                  Icons.attach_money,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'إجمالي الكميات',
                  '${FuelService.formatAmount(summary['total_quantity'])} لتر',
                  Icons.local_gas_station,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'إجمالي السجلات',
                  '${summary['total_records']}',
                  Icons.list_alt,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'عدد المستخدمين',
                  '${summary['users_count']}',
                  Icons.people,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

// Helper method to sanitize sheet names (Excel has restrictions)
  String _sanitizeSheetName(String name) {
    // Excel sheet name restrictions: max 31 characters, no special characters
    String sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (sanitized.length > 31) {
      sanitized = sanitized.substring(0, 31);
    }
    return sanitized;
  }

  Widget _buildUserStatisticsTable() {
    if (_userStatistics.isEmpty) {
      return _buildEmptyState(
          'لا توجد إحصائيات. اضغط على "حساب إحصائيات المستخدمين" لتحديث البيانات.');
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Text('اسم المستخدم',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                Expanded(
                    flex: 2,
                    child: Text(
                      'إجمالي المبلغ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    )),
                Expanded(
                    flex: 2,
                    child: Text(
                      'إجمالي الكمية',
                      style: TextStyle(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    )),
              ],
            ),
          ),
          // Table Body
          Expanded(
            child: ListView.builder(
              itemCount: _userStatistics.length,
              itemBuilder: (context, index) {
                final stat = _userStatistics[index];
                final isEven = index % 2 == 0;
                final averageAmount = stat.recordCount > 0
                    ? stat.totalAmount / stat.recordCount
                    : 0.0;
                final averageQuantity = stat.recordCount > 0
                    ? stat.totalQuantity / stat.recordCount
                    : 0.0;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isEven ? Colors.white : Colors.grey.shade50,
                    border: const Border(
                      bottom: BorderSide(color: Colors.grey, width: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          stat.username,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          FuelService.formatAmount(stat.totalAmount),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                          textDirection: ui.TextDirection.ltr,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${FuelService.formatAmount(stat.totalQuantity)} لتر',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                          textDirection: ui.TextDirection.ltr,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSyncCard(
            'مزامنة مراكز التكلفة',
            'تحديث مراكز التكلفة من نظام Bisan API',
            'cost_centers',
            Icons.business,
            Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildSyncCard(
            'مزامنة أنواع المحروقات',
            'تحديث أنواع المحروقات والأسعار من نظام Bisan API',
            'fuel_types',
            Icons.local_gas_station,
            Colors.green,
          ),
          const SizedBox(height: 16),
          _buildSyncCard(
            'مزامنة محطات المحروقات',
            'تحديث محطات المحروقات من نظام Bisan API',
            'fuel_contacts',
            Icons.local_gas_station,
            Colors.red,
          ),
          if (_syncStatus.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _syncStatus.contains('فشل')
                    ? Colors.red.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _syncStatus.contains('فشل')
                      ? Colors.red.withOpacity(0.3)
                      : Colors.green.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _syncStatus.contains('فشل')
                        ? Icons.error
                        : Icons.check_circle,
                    color:
                        _syncStatus.contains('فشل') ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _syncStatus,
                      style: TextStyle(
                        color: _syncStatus.contains('فشل')
                            ? Colors.red
                            : Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSyncCard(String title, String description, String type,
      IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 32),
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
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: _isSyncing ? null : () => _syncData(type),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: _isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('مزامنة'),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildJournalHeader(),
          const SizedBox(height: 16),
          if (_statistics.isNotEmpty) ...[
            _buildJournalPreview(),
            const SizedBox(height: 16),
            _buildJournalActions(),
          ] else
            _buildEmptyState('يجب حساب الحسابات أولاً قبل الترحيل'),
        ],
      ),
    );
  }

  Widget _buildJournalHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.receipt_long,
              color: Color(AppConstants.accentColor), size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'ترحيل قيود المحروقات',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(AppConstants.primaryColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 9. UPDATE: _buildJournalPreview to show fuel contact info
  Widget _buildJournalPreview() {
    final activeStats = _statistics.where((s) => s.totalAmount > 0).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'معاينة القيود المراد ترحيلها',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(AppConstants.primaryColor),
            ),
          ),
          const SizedBox(height: 12),

          // NEW: Show selected fuel contact
          if (_selectedFuelContact != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_gas_station,
                      color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'محطة المحروقات: ${_selectedFuelContact!.name}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        Text(
                          'الكود: ${_selectedFuelContact!.code}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          ...activeStats.map((stat) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                          '${stat.costCenterCode} - ${stat.costCenterName}'),
                    ),
                    Text(
                      FuelService.formatAmount(stat.totalAmount),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      textDirection: ui.TextDirection.ltr,
                    ),
                  ],
                ),
              )),
          const Divider(),
          Row(
            children: [
              const Expanded(
                  child: Text('المجموع:',
                      style: TextStyle(fontWeight: FontWeight.w600))),
              Text(
                FuelService.formatAmount(activeStats.fold(
                    0.0, (sum, stat) => sum + stat.totalAmount)),
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                textDirection: ui.TextDirection.ltr,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJournalActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showJournalVoucherDialog,
              icon: const Icon(
                Icons.send,
                size: 18,
                color: Colors.white,
              ),
              label: const Text('ترحيل القيود'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Dialog methods and other helper methods would continue here...
  // I'll continue with the dialog implementations in the next part if needed

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => _ImageViewerDialog(imageUrl: imageUrl),
    );
  }

  Future<void> _showAddAssignCostCenterDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AddAssignCostCenterDialog(
        costCenters: _costCenters,
        fuelTypes: _fuelTypes, // ADD THIS
      ),
    );

    if (result == true) {
      await _loadAllData();
      _showSnackBar('تم إضافة الشاحنة بنجاح', false);
    }
  }

  Future<void> _showEditAssignCostCenterDialog(AssignCostCenter assign) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EditAssignCostCenterDialog(
        assignCostCenter: assign,
        costCenters: _costCenters,
        fuelTypes: _fuelTypes, // ADD THIS
      ),
    );

    if (result == true) {
      await _loadAllData();
      _showSnackBar('تم تحديث الشاحنة بنجاح', false);
    }
  }

  Future<void> _deleteAssignCostCenter(AssignCostCenter assign) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الشاحنة'),
          content: Text('هل تريد حذف الشاحنة "${assign.number}"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.deleteAssignCostCenter(assign.id);
        await _loadAllData();
        _showSnackBar('تم حذف الشاحنة بنجاح', false);
      } catch (e) {
        _showSnackBar('فشل في حذف الشاحنة: $e', true);
      }
    }
  }
}

// 10. UPDATE: _JournalVoucherDialog to show fuel contact (read-only)
class _JournalVoucherDialog extends StatefulWidget {
  final FuelContact selectedFuelContact;

  const _JournalVoucherDialog({
    required this.selectedFuelContact,
  });

  @override
  State<_JournalVoucherDialog> createState() => _JournalVoucherDialogState();
}

class _JournalVoucherDialogState extends State<_JournalVoucherDialog> {
  final _formKey = GlobalKey<FormState>();
  final _taxReferenceController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _taxReferenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ar'),
      builder: (context, child) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long,
                color: Color(AppConstants.accentColor)),
            const SizedBox(width: 8),
            const Text('بيانات الترحيل'),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // NEW: Display selected fuel contact (read-only)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.local_gas_station,
                          color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'محطة المحروقات',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.selectedFuelContact.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade900,
                              ),
                            ),
                            Text(
                              'الكود: ${widget.selectedFuelContact.code}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.check_circle,
                          color: Colors.green.shade600, size: 24),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tax Reference Field
                TextFormField(
                  controller: _taxReferenceController,
                  decoration: InputDecoration(
                    labelText: 'مرجع الضريبة *',
                    hintText: 'أدخل مرجع الضريبة',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(
                      Icons.receipt,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال مرجع الضريبة';
                    }
                    if (int.tryParse(value.trim()) == null) {
                      return 'مرجع الضريبة يجب أن يكون رقماً';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Invoice Date Field
                InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'تاريخ الفاتورة *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: Icon(
                        Icons.calendar_today,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(_selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Notes Field
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'ملاحظة *',
                    hintText: 'أدخل ملاحظة حول القيد',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(
                      Icons.note,
                      color: Colors.grey.shade600,
                    ),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال الملاحظة';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Information note
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
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'سيتم ترحيل القيود المحاسبية تلقائياً إلى نظام بيسان',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'إلغاء',
              style: TextStyle(fontSize: 14),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final data = JournalVoucherData(
                  contactNumber:
                      widget.selectedFuelContact.code, // Use fuel contact code
                  taxReference: _taxReferenceController.text.trim(),
                  invoiceDate: _selectedDate,
                  notes: _notesController.text.trim(),
                );
                Navigator.pop(context, data);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(
              Icons.send,
              size: 18,
              color: Colors.white,
            ),
            label: const Text(
              'ترحيل القيود',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
