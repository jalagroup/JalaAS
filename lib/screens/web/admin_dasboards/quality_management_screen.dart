// lib/screens/web/quality_management_screen.dart - Part 1 (State and Core Methods)
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:jala_as/models/quality_models.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/helpers.dart';
import 'quality_management/quality_checklist_builder_screen.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import '../../utils/file_utils.dart';
import 'dart:typed_data';
import 'package:flutter/painting.dart' as painting;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'dart:math' as Math;

// New Zoomable Image Dialog Widget
class _ZoomableImageDialog extends StatefulWidget {
  final String imageUrl;

  const _ZoomableImageDialog({required this.imageUrl});

  @override
  State<_ZoomableImageDialog> createState() => _ZoomableImageDialogState();
}

class _ZoomableImageDialogState extends State<_ZoomableImageDialog> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _zoomIn() {
    final Matrix4 matrix = _transformationController.value.clone();
    matrix.scale(1.2);
    _transformationController.value = matrix;
  }

  void _zoomOut() {
    final Matrix4 matrix = _transformationController.value.clone();
    matrix.scale(0.8);
    _transformationController.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black87,
      insetPadding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Header with controls
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'عرض الصورة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _zoomOut,
                      icon: const Icon(Icons.zoom_out, color: Colors.white),
                      tooltip: 'تصغير',
                    ),
                    IconButton(
                      onPressed: _resetZoom,
                      icon: const Icon(Icons.center_focus_strong,
                          color: Colors.white),
                      tooltip: 'إعادة تعيين',
                    ),
                    IconButton(
                      onPressed: _zoomIn,
                      icon: const Icon(Icons.zoom_in, color: Colors.white),
                      tooltip: 'تكبير',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'إغلاق',
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Image viewer
          Expanded(
            child: Container(
              color: Colors.black,
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 0.1,
                maxScale: 5.0,
                child: Center(
                  child: Image.network(
                    widget.imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'جارٍ تحميل الصورة...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey.shade800,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image,
                                  color: Colors.white, size: 48),
                              SizedBox(height: 8),
                              Text('فشل في تحميل الصورة',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          // Footer instructions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: const Text(
              'استخدم الإيماءات للتكبير والتصغير أو الأزرار أعلاه',
              style: TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class QualityManagementScreen extends StatefulWidget {
  const QualityManagementScreen({super.key});

  @override
  State<QualityManagementScreen> createState() =>
      _QualityManagementScreenState();
}

class _QualityManagementScreenState extends State<QualityManagementScreen> {
  List<QualityChecklistGroup> _checklistGroups = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  static const Color _primaryColor = Color(0xFF8B5CF6);
  static const Color _lightPrimaryColor = Color(0xFFF3F4F6);
  static const Color _textPrimaryColor = Color(0xFF1F2937);
  static const Color _textSecondaryColor = Color(0xFF6B7280);
  static const Color _backgroundColor = Color(0xFFF8F9FA);
  static const Color _cardBackgroundColor = Colors.white;
  static const Color _borderColor = Color(0xFFE5E7EB);
  Map<String, dynamic> _additionalStatistics = {};
  Map<String, dynamic> checklistAdditionalStats = {};

  Map<int, bool> _expandedResponseCards = {}; // Track expanded cards
  Map<int, bool> _expandedGroups = {}; // Track expanded group cards

  // Report variables
  QualityChecklistGroup? _selectedReportGroup;
  QualityChecklist? _selectedReportChecklist;
  List<QualityResponse> _responses = [];
  Map<String, String> _selectedDeterminants = {};
  DateTime? _fromDate;
  DateTime? _toDate;
  Map<String, dynamic> _statistics = {};
  bool _isLoadingStats = false;
  bool _isExporting = false;
  String _selectedPeriod = 'current_year';
  bool _showReports = false;
  bool _showResponsesTable = false;

  // New variables for multiple checklists
  Map<int, Map<String, String>> _checklistDeterminantFilters = {};
  Map<int, Map<String, dynamic>> _checklistStatistics = {};
  int? _selectedResponsesChecklistId;
  bool _showMultipleChecklistsView = false;

  // Arabic month names
  final List<String> arabicMonths = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر'
  ];

  @override
  void initState() {
    super.initState();
    _initializeDates();
    _loadChecklistGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

// Updated _initializeDates method with auto-apply
  void _initializeDates() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'one_day':
        _fromDate = DateTime(now.year, now.month, now.day);
        _toDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'current_month':
        _fromDate = DateTime(now.year, now.month, 1);
        _toDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'current_year':
        _fromDate = DateTime(now.year, 1, 1);
        _toDate = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
      case 'specific_month':
        _fromDate = DateTime(now.year, now.month, 1);
        _toDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'specific_year':
        _fromDate = DateTime(now.year, 1, 1);
        _toDate = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
      case 'date_range':
        _fromDate = DateTime(now.year, now.month, 1);
        _toDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      default:
        _fromDate = DateTime(now.year, now.month, 1);
        _toDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    }

    // Auto-calculate statistics whenever dates change
    _calculateAdditionalStatistics();

    // Auto-reload statistics based on current view
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_showReports) {
        if (_showMultipleChecklistsView) {
          _loadMultipleChecklistsStatistics();
        } else {
          _loadStatistics();
        }
      }
    });
  }

  Future<void> _loadChecklistGroups() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final groups = await SupabaseService.getQualityChecklistGroups();
      setState(() {
        _checklistGroups = groups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Helpers.showSnackBar(
        context,
        'فشل في تحميل مجموعات قوائم مراقبة الجودة',
        isError: true,
      );
    }
  }

// Updated _calculateAdditionalStatistics method - current month/year not affected by date filter
  void _calculateAdditionalStatistics() {
    // Initialize with zeros
    _additionalStatistics = {
      'overall_percentage': 0.0,
      'monthly_average': 0.0,
      'current_month_average': 0.0,
      'yearly_average': 0.0,
      'current_year_average': 0.0,
    };

    checklistAdditionalStats = {
      'overall_percentage': 0.0,
      'monthly_average': 0.0,
      'current_month_average': 0.0,
      'yearly_average': 0.0,
      'current_year_average': 0.0,
    };

    if (_responses.isEmpty) {
      return;
    }

    if (_showMultipleChecklistsView) {
      // For multiple checklists view, calculate aggregated statistics
      _calculateMultipleChecklistsStatisticsWithFilters();
    } else {
      // For single checklist view
      if (_selectedReportChecklist == null) return;
      _calculateSingleChecklistStatisticsWithFilters();
    }
  }

// Updated single checklist statistics - current month/year ONLY affected by determinant filters
  void _calculateSingleChecklistStatisticsWithFilters() {
    if (_selectedReportChecklist == null) return;

    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final currentMonthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final currentYearStart = DateTime(now.year, 1, 1);
    final currentYearEnd = DateTime(now.year, 12, 31, 23, 59, 59);

    // Get responses for THIS specific checklist only
    final checklistResponses = _responses
        .where((r) => r.checklistId == _selectedReportChecklist!.id)
        .toList();

    if (checklistResponses.isEmpty) return;

    // Apply date filters ONLY for overall percentage
    final dateFilteredResponses = checklistResponses.where((r) {
      if (_fromDate != null && _toDate != null) {
        return r.responseDate
                .isAfter(_fromDate!.subtract(const Duration(days: 1))) &&
            r.responseDate.isBefore(_toDate!.add(const Duration(days: 1)));
      }
      return true;
    }).toList();

    // Apply determinant filters to date-filtered responses for overall percentage
    final allFilteredResponses =
        _applyDeterminantFilters(dateFilteredResponses);

    // For current month - get all current month responses then apply ONLY determinant filters
    final currentMonthResponses = checklistResponses
        .where((r) =>
            r.responseDate
                .isAfter(currentMonthStart.subtract(const Duration(days: 1))) &&
            r.responseDate
                .isBefore(currentMonthEnd.add(const Duration(days: 1))))
        .toList();
    final filteredCurrentMonthResponses =
        _applyDeterminantFilters(currentMonthResponses);

    // For current year - get all current year responses then apply ONLY determinant filters
    final currentYearResponses = checklistResponses
        .where((r) =>
            r.responseDate
                .isAfter(currentYearStart.subtract(const Duration(days: 1))) &&
            r.responseDate
                .isBefore(currentYearEnd.add(const Duration(days: 1))))
        .toList();
    final filteredCurrentYearResponses =
        _applyDeterminantFilters(currentYearResponses);

    // Calculate statistics with filters applied correctly
    _additionalStatistics = {
      'overall_percentage': _calculateChecklistAverage(
          allFilteredResponses, _selectedReportChecklist!),
      'current_month_average': _calculateChecklistAverage(
          filteredCurrentMonthResponses, _selectedReportChecklist!),
      'current_year_average': _calculateChecklistAverage(
          filteredCurrentYearResponses, _selectedReportChecklist!),
    };

    checklistAdditionalStats = Map.from(_additionalStatistics);
  }

// Updated multiple checklists statistics - current month/year ONLY affected by determinant filters
  void _calculateMultipleChecklistsStatisticsWithFilters() {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final currentMonthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final currentYearStart = DateTime(now.year, 1, 1);
    final currentYearEnd = DateTime(now.year, 12, 31, 23, 59, 59);

    // Calculate for each checklist separately, then aggregate
    double totalOverallPercentage = 0.0;
    double totalMonthlyAverage = 0.0;
    double totalCurrentMonthAverage = 0.0;
    double totalYearlyAverage = 0.0;
    double totalCurrentYearAverage = 0.0;
    int checklistCount = 0;

    for (final checklist in _selectedReportGroup!.checklists) {
      final checklistResponses =
          _responses.where((r) => r.checklistId == checklist.id).toList();

      if (checklistResponses.isEmpty) continue;

      // Apply date filters ONLY for overall percentage
      final dateFilteredResponses = checklistResponses.where((r) {
        if (_fromDate != null && _toDate != null) {
          return r.responseDate
                  .isAfter(_fromDate!.subtract(const Duration(days: 1))) &&
              r.responseDate.isBefore(_toDate!.add(const Duration(days: 1)));
        }
        return true;
      }).toList();

      // Apply filters for this specific checklist (for overall percentage)
      final filteredResponses =
          _applyChecklistSpecificFilters(dateFilteredResponses, checklist.id);

      // For current month - get all current month responses then apply ONLY determinant filters
      final currentMonthResponses = checklistResponses
          .where((r) =>
              r.responseDate.isAfter(
                  currentMonthStart.subtract(const Duration(days: 1))) &&
              r.responseDate
                  .isBefore(currentMonthEnd.add(const Duration(days: 1))))
          .toList();
      final filteredCurrentMonthResponses =
          _applyChecklistSpecificFilters(currentMonthResponses, checklist.id);

      // For current year - get all current year responses then apply ONLY determinant filters
      final currentYearResponses = checklistResponses
          .where((r) =>
              r.responseDate.isAfter(
                  currentYearStart.subtract(const Duration(days: 1))) &&
              r.responseDate
                  .isBefore(currentYearEnd.add(const Duration(days: 1))))
          .toList();
      final filteredCurrentYearResponses =
          _applyChecklistSpecificFilters(currentYearResponses, checklist.id);

      // Calculate for this checklist with filters applied correctly
      totalOverallPercentage +=
          _calculateChecklistAverage(filteredResponses, checklist);
      totalMonthlyAverage += _calculateChecklistMonthlyAverageWithFilters(
          checklistResponses, checklist);
      totalCurrentMonthAverage +=
          _calculateChecklistAverage(filteredCurrentMonthResponses, checklist);
      totalYearlyAverage += _calculateChecklistYearlyAverageWithFilters(
          checklistResponses, checklist);
      totalCurrentYearAverage +=
          _calculateChecklistAverage(filteredCurrentYearResponses, checklist);

      checklistCount++;
    }

    // Average across all checklists
    if (checklistCount > 0) {
      _additionalStatistics = {
        'overall_percentage': totalOverallPercentage / checklistCount,
        'monthly_average': totalMonthlyAverage / checklistCount,
        'current_month_average': totalCurrentMonthAverage / checklistCount,
        'yearly_average': totalYearlyAverage / checklistCount,
        'current_year_average': totalCurrentYearAverage / checklistCount,
      };
    }

    checklistAdditionalStats = Map.from(_additionalStatistics);
  }

// Helper method to calculate monthly average with filters applied
  double _calculateChecklistMonthlyAverageWithFilters(
      List<QualityResponse> responses, QualityChecklist checklist) {
    if (responses.isEmpty || checklist.rateNumber <= 0) return 0.0;

    Map<String, List<double>> monthlyData = {};

    for (final response in responses) {
      final monthKey =
          '${response.responseDate.year}-${response.responseDate.month.toString().padLeft(2, '0')}';

      response.checkPointRatings.forEach((key, value) {
        int rating = 0;
        if (value is Map<String, dynamic>) {
          rating = value['rating'] as int? ?? 0;
        } else if (value is int) {
          rating = value;
        }

        if (rating > 0) {
          monthlyData[monthKey] ??= [];
          monthlyData[monthKey]!.add(rating / checklist.rateNumber * 100);
        }
      });
    }

    if (monthlyData.isEmpty) return 0.0;

    double totalMonthlyAverages = 0.0;
    int monthCount = 0;

    monthlyData.forEach((month, percentages) {
      if (percentages.isNotEmpty) {
        final monthAverage =
            percentages.reduce((a, b) => a + b) / percentages.length;
        totalMonthlyAverages += monthAverage;
        monthCount++;
      }
    });

    return monthCount > 0 ? totalMonthlyAverages / monthCount : 0.0;
  }

// Helper method to calculate yearly average with filters applied
  double _calculateChecklistYearlyAverageWithFilters(
      List<QualityResponse> responses, QualityChecklist checklist) {
    if (responses.isEmpty || checklist.rateNumber <= 0) return 0.0;

    Map<int, List<double>> yearlyData = {};

    for (final response in responses) {
      final year = response.responseDate.year;

      response.checkPointRatings.forEach((key, value) {
        int rating = 0;
        if (value is Map<String, dynamic>) {
          rating = value['rating'] as int? ?? 0;
        } else if (value is int) {
          rating = value;
        }

        if (rating > 0) {
          yearlyData[year] ??= [];
          yearlyData[year]!.add(rating / checklist.rateNumber * 100);
        }
      });
    }

    if (yearlyData.isEmpty) return 0.0;

    double totalYearlyAverages = 0.0;
    int yearCount = 0;

    yearlyData.forEach((year, percentages) {
      if (percentages.isNotEmpty) {
        final yearAverage =
            percentages.reduce((a, b) => a + b) / percentages.length;
        totalYearlyAverages += yearAverage;
        yearCount++;
      }
    });

    return yearCount > 0 ? totalYearlyAverages / yearCount : 0.0;
  }

// New method for single checklist statistics
  void _calculateSingleChecklistStatistics() {
    if (_selectedReportChecklist == null) return;

    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final currentMonthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final currentYearStart = DateTime(now.year, 1, 1);
    final currentYearEnd = DateTime(now.year, 12, 31, 23, 59, 59);

    // Get responses for THIS specific checklist only
    final checklistResponses = _responses
        .where((r) => r.checklistId == _selectedReportChecklist!.id)
        .toList();

    if (checklistResponses.isEmpty) return;

    // Apply determinant filters to the checklist responses
    final filteredResponses = _applyDeterminantFilters(checklistResponses);

    final currentMonthResponses = checklistResponses
        .where((r) =>
            r.responseDate
                .isAfter(currentMonthStart.subtract(const Duration(days: 1))) &&
            r.responseDate
                .isBefore(currentMonthEnd.add(const Duration(days: 1))))
        .toList();

    final currentYearResponses = checklistResponses
        .where((r) =>
            r.responseDate
                .isAfter(currentYearStart.subtract(const Duration(days: 1))) &&
            r.responseDate
                .isBefore(currentYearEnd.add(const Duration(days: 1))))
        .toList();

    // Calculate statistics for this specific checklist
    _additionalStatistics = {
      'overall_percentage': _calculateChecklistAverage(
          filteredResponses, _selectedReportChecklist!),
      'current_month_average': _calculateChecklistAverage(
          currentMonthResponses, _selectedReportChecklist!),
      'current_year_average': _calculateChecklistAverage(
          currentYearResponses, _selectedReportChecklist!),
    };

    checklistAdditionalStats = Map.from(_additionalStatistics);
  }

// New method for multiple checklists statistics (aggregated)
  void _calculateMultipleChecklistsStatistics() {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final currentMonthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final currentYearStart = DateTime(now.year, 1, 1);
    final currentYearEnd = DateTime(now.year, 12, 31, 23, 59, 59);

    // Calculate for each checklist separately, then aggregate
    double totalOverallPercentage = 0.0;
    double totalMonthlyAverage = 0.0;
    double totalCurrentMonthAverage = 0.0;
    double totalYearlyAverage = 0.0;
    double totalCurrentYearAverage = 0.0;
    int checklistCount = 0;

    for (final checklist in _selectedReportGroup!.checklists) {
      final checklistResponses =
          _responses.where((r) => r.checklistId == checklist.id).toList();

      if (checklistResponses.isEmpty) continue;

      // Apply filters for this specific checklist
      final filteredResponses =
          _applyChecklistSpecificFilters(checklistResponses, checklist.id);

      final currentMonthResponses = checklistResponses
          .where((r) =>
              r.responseDate.isAfter(
                  currentMonthStart.subtract(const Duration(days: 1))) &&
              r.responseDate
                  .isBefore(currentMonthEnd.add(const Duration(days: 1))))
          .toList();

      final currentYearResponses = checklistResponses
          .where((r) =>
              r.responseDate.isAfter(
                  currentYearStart.subtract(const Duration(days: 1))) &&
              r.responseDate
                  .isBefore(currentYearEnd.add(const Duration(days: 1))))
          .toList();

      // Calculate for this checklist
      totalOverallPercentage +=
          _calculateChecklistAverage(filteredResponses, checklist);
      totalMonthlyAverage +=
          _calculateChecklistMonthlyAverage(checklistResponses, checklist);
      totalCurrentMonthAverage +=
          _calculateChecklistAverage(currentMonthResponses, checklist);
      totalYearlyAverage +=
          _calculateChecklistYearlyAverage(checklistResponses, checklist);
      totalCurrentYearAverage +=
          _calculateChecklistAverage(currentYearResponses, checklist);

      checklistCount++;
    }

    // Average across all checklists
    if (checklistCount > 0) {
      _additionalStatistics = {
        'overall_percentage': totalOverallPercentage / checklistCount,
        'current_month_average': totalCurrentMonthAverage / checklistCount,
        'current_year_average': totalCurrentYearAverage / checklistCount,
      };
    }

    checklistAdditionalStats = Map.from(_additionalStatistics);
  }

// Helper method to calculate average for a specific checklist
  double _calculateChecklistAverage(
      List<QualityResponse> responses, QualityChecklist checklist) {
    if (responses.isEmpty || checklist.rateNumber <= 0) return 0.0;

    double totalPercentage = 0.0;
    int totalRatings = 0;

    for (final response in responses) {
      response.checkPointRatings.forEach((key, value) {
        int rating = 0;
        if (value is Map<String, dynamic>) {
          rating = value['rating'] as int? ?? 0;
        } else if (value is int) {
          rating = value;
        }

        if (rating > 0) {
          totalPercentage += (rating / checklist.rateNumber * 100);
          totalRatings++;
        }
      });
    }

    return totalRatings > 0 ? totalPercentage / totalRatings : 0.0;
  }

// Helper method to calculate monthly average for a specific checklist
  double _calculateChecklistMonthlyAverage(
      List<QualityResponse> responses, QualityChecklist checklist) {
    if (responses.isEmpty || checklist.rateNumber <= 0) return 0.0;

    Map<String, List<double>> monthlyData = {};

    for (final response in responses) {
      final monthKey =
          '${response.responseDate.year}-${response.responseDate.month.toString().padLeft(2, '0')}';

      response.checkPointRatings.forEach((key, value) {
        int rating = 0;
        if (value is Map<String, dynamic>) {
          rating = value['rating'] as int? ?? 0;
        } else if (value is int) {
          rating = value;
        }

        if (rating > 0) {
          monthlyData[monthKey] ??= [];
          monthlyData[monthKey]!.add(rating / checklist.rateNumber * 100);
        }
      });
    }

    if (monthlyData.isEmpty) return 0.0;

    double totalMonthlyAverages = 0.0;
    int monthCount = 0;

    monthlyData.forEach((month, percentages) {
      if (percentages.isNotEmpty) {
        final monthAverage =
            percentages.reduce((a, b) => a + b) / percentages.length;
        totalMonthlyAverages += monthAverage;
        monthCount++;
      }
    });

    return monthCount > 0 ? totalMonthlyAverages / monthCount : 0.0;
  }

// Helper method to calculate yearly average for a specific checklist
  double _calculateChecklistYearlyAverage(
      List<QualityResponse> responses, QualityChecklist checklist) {
    if (responses.isEmpty || checklist.rateNumber <= 0) return 0.0;

    Map<int, List<double>> yearlyData = {};

    for (final response in responses) {
      final year = response.responseDate.year;

      response.checkPointRatings.forEach((key, value) {
        int rating = 0;
        if (value is Map<String, dynamic>) {
          rating = value['rating'] as int? ?? 0;
        } else if (value is int) {
          rating = value;
        }

        if (rating > 0) {
          yearlyData[year] ??= [];
          yearlyData[year]!.add(rating / checklist.rateNumber * 100);
        }
      });
    }

    if (yearlyData.isEmpty) return 0.0;

    double totalYearlyAverages = 0.0;
    int yearCount = 0;

    yearlyData.forEach((year, percentages) {
      if (percentages.isNotEmpty) {
        final yearAverage =
            percentages.reduce((a, b) => a + b) / percentages.length;
        totalYearlyAverages += yearAverage;
        yearCount++;
      }
    });

    return yearCount > 0 ? totalYearlyAverages / yearCount : 0.0;
  }

// Helper method to apply determinant filters (for single checklist)
  List<QualityResponse> _applyDeterminantFilters(
      List<QualityResponse> responses) {
    if (_selectedDeterminants.isEmpty) return responses;

    return responses.where((response) {
      for (final entry in _selectedDeterminants.entries) {
        final determinantId = entry.key;
        final selectedValue = entry.value;
        final responseValue = response.determinantValues[determinantId];

        if (responseValue == null ||
            responseValue.toString() != selectedValue) {
          return false;
        }
      }
      return true;
    }).toList();
  }

// Helper method to apply checklist-specific filters (for multiple checklists)
  List<QualityResponse> _applyChecklistSpecificFilters(
      List<QualityResponse> responses, int checklistId) {
    final filters = _checklistDeterminantFilters[checklistId];
    if (filters == null || filters.isEmpty) return responses;

    return responses.where((response) {
      for (final entry in filters.entries) {
        final determinantId = entry.key;
        final selectedValue = entry.value;
        final responseValue = response.determinantValues[determinantId];

        if (responseValue == null ||
            responseValue.toString() != selectedValue) {
          return false;
        }
      }
      return true;
    }).toList();
  }

// Updated monthly average calculation
  double _calculateMonthlyAverageForChecklist(List<QualityResponse> responses) {
    if (responses.isEmpty) return 0.0;

    Map<String, List<double>> monthlyData = {};

    for (final response in responses) {
      final monthKey =
          '${response.responseDate.year}-${response.responseDate.month.toString().padLeft(2, '0')}';

      final responseChecklist = _showMultipleChecklistsView
          ? _selectedReportGroup!.checklists.firstWhere(
              (c) => c.id == response.checklistId,
              orElse: () => _selectedReportGroup!.checklists.first,
            )
          : _selectedReportChecklist;

      if (responseChecklist == null) continue;
      final maxRating = responseChecklist.rateNumber;
      if (maxRating <= 0) continue;

      response.checkPointRatings.forEach((key, value) {
        int rating = 0;
        if (value is Map<String, dynamic>) {
          rating = value['rating'] as int? ?? 0;
        } else if (value is int) {
          rating = value;
        }

        if (rating > 0) {
          monthlyData[monthKey] ??= [];
          monthlyData[monthKey]!.add(rating / maxRating * 100);
        }
      });
    }

    if (monthlyData.isEmpty) return 0.0;

    double totalMonthlyAverages = 0.0;
    int monthCount = 0;

    monthlyData.forEach((month, percentages) {
      if (percentages.isNotEmpty) {
        final monthAverage =
            percentages.reduce((a, b) => a + b) / percentages.length;
        totalMonthlyAverages += monthAverage;
        monthCount++;
      }
    });

    return monthCount > 0 ? totalMonthlyAverages / monthCount : 0.0;
  }

// Updated yearly average calculation
  double _calculateYearlyAverageForChecklist(List<QualityResponse> responses) {
    if (responses.isEmpty) return 0.0;

    Map<int, List<double>> yearlyData = {};

    for (final response in responses) {
      final year = response.responseDate.year;

      final responseChecklist = _showMultipleChecklistsView
          ? _selectedReportGroup!.checklists.firstWhere(
              (c) => c.id == response.checklistId,
              orElse: () => _selectedReportGroup!.checklists.first,
            )
          : _selectedReportChecklist;

      if (responseChecklist == null) continue;
      final maxRating = responseChecklist.rateNumber;
      if (maxRating <= 0) continue;

      response.checkPointRatings.forEach((key, value) {
        int rating = 0;
        if (value is Map<String, dynamic>) {
          rating = value['rating'] as int? ?? 0;
        } else if (value is int) {
          rating = value;
        }

        if (rating > 0) {
          yearlyData[year] ??= [];
          yearlyData[year]!.add(rating / maxRating * 100);
        }
      });
    }

    if (yearlyData.isEmpty) return 0.0;

    double totalYearlyAverages = 0.0;
    int yearCount = 0;

    yearlyData.forEach((year, percentages) {
      if (percentages.isNotEmpty) {
        final yearAverage =
            percentages.reduce((a, b) => a + b) / percentages.length;
        totalYearlyAverages += yearAverage;
        yearCount++;
      }
    });

    return yearCount > 0 ? totalYearlyAverages / yearCount : 0.0;
  }

// New helper method for calculating averages with proper checklist context
  double _calculateResponsesAverageForChecklist(
      List<QualityResponse> responses, QualityChecklist? checklist) {
    if (responses.isEmpty) return 0.0;

    if (_showMultipleChecklistsView) {
      // For multiple checklists, calculate average across all checklists
      double totalPercentage = 0.0;
      int totalRatings = 0;

      for (final response in responses) {
        final responseChecklist = _selectedReportGroup!.checklists.firstWhere(
          (c) => c.id == response.checklistId,
          orElse: () => _selectedReportGroup!.checklists.first,
        );

        final maxRating = responseChecklist.rateNumber;
        if (maxRating <= 0) continue;

        response.checkPointRatings.forEach((key, value) {
          int rating = 0;
          if (value is Map<String, dynamic>) {
            rating = value['rating'] as int? ?? 0;
          } else if (value is int) {
            rating = value;
          }
          if (rating > 0) {
            totalPercentage += (rating / maxRating * 100);
            totalRatings++;
          }
        });
      }

      return totalRatings > 0 ? totalPercentage / totalRatings : 0.0;
    } else {
      // For single checklist
      if (checklist == null) return 0.0;

      final maxRating = checklist.rateNumber;
      if (maxRating <= 0) return 0.0;

      double totalPercentage = 0.0;
      int totalRatings = 0;

      for (final response in responses) {
        response.checkPointRatings.forEach((key, value) {
          int rating = 0;
          if (value is Map<String, dynamic>) {
            rating = value['rating'] as int? ?? 0;
          } else if (value is int) {
            rating = value;
          }
          if (rating > 0) {
            totalPercentage += (rating / maxRating * 100);
            totalRatings++;
          }
        });
      }

      return totalRatings > 0 ? totalPercentage / totalRatings : 0.0;
    }
  }

  double _calculateMonthlyAverage(List<QualityResponse> responses) {
    if (responses.isEmpty || _selectedReportChecklist == null) return 0.0;

    Map<String, List<double>> monthlyData = {};
    final maxRating = _selectedReportChecklist!.rateNumber;

    for (final response in responses) {
      final monthKey =
          '${response.responseDate.year}-${response.responseDate.month.toString().padLeft(2, '0')}';

      response.checkPointRatings.forEach((key, value) {
        int rating = 0;
        if (value is Map<String, dynamic>) {
          rating = value['rating'] as int? ?? 0;
        } else if (value is int) {
          rating = value;
        }

        if (rating > 0 && maxRating > 0) {
          monthlyData[monthKey] ??= [];
          monthlyData[monthKey]!.add(rating / maxRating * 100);
        }
      });
    }

    if (monthlyData.isEmpty) return 0.0;

    double totalMonthlyAverages = 0.0;
    int monthCount = 0;

    monthlyData.forEach((month, percentages) {
      if (percentages.isNotEmpty) {
        final monthAverage =
            percentages.reduce((a, b) => a + b) / percentages.length;
        totalMonthlyAverages += monthAverage;
        monthCount++;
      }
    });

    return monthCount > 0 ? totalMonthlyAverages / monthCount : 0.0;
  }

  double _calculateYearlyAverage(List<QualityResponse> responses) {
    if (responses.isEmpty || _selectedReportChecklist == null) return 0.0;

    Map<int, List<double>> yearlyData = {};
    final maxRating = _selectedReportChecklist!.rateNumber;

    for (final response in responses) {
      final year = response.responseDate.year;

      response.checkPointRatings.forEach((key, value) {
        int rating = 0;
        if (value is Map<String, dynamic>) {
          rating = value['rating'] as int? ?? 0;
        } else if (value is int) {
          rating = value;
        }

        if (rating > 0 && maxRating > 0) {
          yearlyData[year] ??= [];
          yearlyData[year]!.add(rating / maxRating * 100);
        }
      });
    }

    if (yearlyData.isEmpty) return 0.0;

    double totalYearlyAverages = 0.0;
    int yearCount = 0;

    yearlyData.forEach((year, percentages) {
      if (percentages.isNotEmpty) {
        final yearAverage =
            percentages.reduce((a, b) => a + b) / percentages.length;
        totalYearlyAverages += yearAverage;
        yearCount++;
      }
    });

    return yearCount > 0 ? totalYearlyAverages / yearCount : 0.0;
  }

  double _calculateResponsesAverage(List<QualityResponse> responses) {
    if (responses.isEmpty || _selectedReportChecklist == null) return 0.0;

    final maxRating = _selectedReportChecklist!.rateNumber;
    double totalPercentage = 0.0;
    int totalRatings = 0;

    for (final response in responses) {
      response.checkPointRatings.forEach((key, value) {
        int rating = 0;
        if (value is Map<String, dynamic>) {
          rating = value['rating'] as int? ?? 0;
        } else if (value is int) {
          rating = value;
        }
        if (rating > 0 && maxRating > 0) {
          totalPercentage += (rating / maxRating * 100);
          totalRatings++;
        }
      });
    }

    return totalRatings > 0 ? totalPercentage / totalRatings : 0.0;
  }

// Updated loadStatistics to ensure proper calculation
  Future<void> _loadStatistics() async {
    if (_selectedReportGroup == null || _selectedReportChecklist == null)
      return;

    setState(() {
      _isLoadingStats = true;
    });

    try {
      final responses = await SupabaseService.getQualityResponses(
        groupId: _selectedReportGroup!.id,
        checklistId: _selectedReportChecklist!.id,
        fromDate: _fromDate,
        toDate: _toDate,
      );

      setState(() {
        _responses = responses;
        _calculateAdditionalStatistics();
        _isLoadingStats = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingStats = false;
      });
      Helpers.showSnackBar(
        context,
        'فشل في تحميل الإحصائيات',
        isError: true,
      );
    }
  }

// Updated loadMultipleChecklistsStatistics
  Future<void> _loadMultipleChecklistsStatistics() async {
    if (_selectedReportGroup == null) return;

    setState(() {
      _isLoadingStats = true;
    });

    try {
      final responses = await SupabaseService.getQualityResponses(
        groupId: _selectedReportGroup!.id,
        fromDate: _fromDate,
        toDate: _toDate,
      );

      setState(() {
        _responses = responses;
        _calculateAdditionalStatistics(); // This will now work properly
      });

      final statistics = await SupabaseService.getMultipleChecklistsStatistics(
        groupId: _selectedReportGroup!.id,
        fromDate: _fromDate,
        toDate: _toDate,
        checklistDeterminantFilters: _checklistDeterminantFilters,
      );

      setState(() {
        _checklistStatistics = Map<int, Map<String, dynamic>>.from(
            statistics['checklist_statistics']
                as Map<int, Map<String, dynamic>>);
        _isLoadingStats = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingStats = false;
      });
      Helpers.showSnackBar(context, 'فشل في تحميل الإحصائيات', isError: true);
    }
  }

  List<QualityResponse> get _dateAndDeterminantFilteredResponses {
    List<QualityResponse> dateFiltered = _responses;

    if (_fromDate != null && _toDate != null) {
      dateFiltered = _responses.where((response) {
        final responseDate = response.responseDate;
        return responseDate
                .isAfter(_fromDate!.subtract(const Duration(days: 1))) &&
            responseDate.isBefore(_toDate!.add(const Duration(days: 1)));
      }).toList();
    }

    if (_selectedDeterminants.isEmpty) {
      return dateFiltered;
    }

    return dateFiltered.where((response) {
      for (final entry in _selectedDeterminants.entries) {
        final determinantId = entry.key;
        final selectedValue = entry.value;
        final responseValue = response.determinantValues[determinantId];
        if (responseValue == null ||
            responseValue.toString() != selectedValue) {
          return false;
        }
      }
      return true;
    }).toList();
  }

// Updated _filteredStatistics getter to apply all filters
  Map<String, dynamic> get _filteredStatistics {
    final filteredResponses = _dateAndDeterminantFilteredResponses;

    if (filteredResponses.isEmpty || _selectedReportChecklist == null) {
      return {
        'total_responses': 0,
        'overall_average': 0.0,
        'check_point_statistics': <String, dynamic>{},
      };
    }

    final checkPointStats = <String, dynamic>{};
    final checkPointTotals = <String, double>{};
    final checkPointCounts = <String, int>{};

    for (final checkPoint in _selectedReportChecklist!.checkPoints) {
      checkPointTotals[checkPoint.id] = 0.0;
      checkPointCounts[checkPoint.id] = 0;

      for (final response in filteredResponses) {
        final ratingData = response.checkPointRatings[checkPoint.id];
        int rating = 0;

        if (ratingData is Map<String, dynamic>) {
          rating = ratingData['rating'] as int? ?? 0;
        } else if (ratingData is int) {
          rating = ratingData;
        }

        if (rating > 0) {
          checkPointTotals[checkPoint.id] =
              checkPointTotals[checkPoint.id]! + rating;
          checkPointCounts[checkPoint.id] =
              checkPointCounts[checkPoint.id]! + 1;
        }
      }

      final count = checkPointCounts[checkPoint.id]!;
      final average =
          count > 0 ? checkPointTotals[checkPoint.id]! / count : 0.0;

      checkPointStats[checkPoint.id] = {
        'average': average,
        'total_responses': count,
      };
    }

    double overallTotal = 0.0;
    int overallCount = 0;

    checkPointStats.forEach((key, value) {
      final avg = value['average'] as double;
      final count = value['total_responses'] as int;
      if (count > 0) {
        overallTotal += avg * count;
        overallCount += count;
      }
    });

    final overallAverage = overallCount > 0 ? overallTotal / overallCount : 0.0;

    return {
      'total_responses': filteredResponses.length,
      'overall_average': overallAverage,
      'check_point_statistics': checkPointStats,
    };
  }

// Updated _updateChecklistFilter method to auto-reload statistics
  void _updateChecklistFilter(
      int checklistId, String determinantId, String? value) {
    setState(() {
      _checklistDeterminantFilters[checklistId] ??= {};
      if (value != null && value.isNotEmpty && value != 'الكل') {
        _checklistDeterminantFilters[checklistId]![determinantId] = value;
      } else {
        _checklistDeterminantFilters[checklistId]!.remove(determinantId);
        if (_checklistDeterminantFilters[checklistId]!.isEmpty) {
          _checklistDeterminantFilters.remove(checklistId);
        }
      }
    });

    // Auto-reload statistics and apply filters
    _calculateAdditionalStatistics();
    if (_showMultipleChecklistsView) {
      _loadMultipleChecklistsStatistics();
    }
  }

// Updated _clearChecklistFilters method to auto-reload statistics
  void _clearChecklistFilters(int checklistId) {
    setState(() {
      _checklistDeterminantFilters.remove(checklistId);
    });

    // Auto-reload statistics and apply filters
    _calculateAdditionalStatistics();
    if (_showMultipleChecklistsView) {
      _loadMultipleChecklistsStatistics();
    }
  }

  Color _getPerformanceColor(double percentage) {
    if (percentage >= 85) return const Color(0xFF10B981);
    if (percentage >= 70) return const Color(0xFF3B82F6);
    if (percentage >= 60) return const Color(0xFFF59E0B);
    if (percentage >= 40) return const Color(0xFFEF4444);
    return const Color(0xFF6B7280);
  }

  Color _getRatingColor(double percentage) {
    if (percentage >= 80) return const Color(0xFF10B981);
    if (percentage >= 60) return const Color(0xFF3B82F6);
    if (percentage >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _getRatingColorHex(double percentage) {
    if (percentage >= 80) return '#D4EDDA';
    if (percentage >= 60) return '#CCE5FF';
    if (percentage >= 50) return '#FFF3CD';
    return '#F8D7DA';
  }

  String _getRatingFontColorHex(double percentage) {
    if (percentage >= 80) return '#155724';
    if (percentage >= 60) return '#004085';
    if (percentage >= 50) return '#856404';
    return '#721C24';
  }

  List<QualityChecklistGroup> get _filteredChecklistGroups {
    if (_searchQuery.isEmpty) return _checklistGroups;
    return _checklistGroups.where((group) {
      return group.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (group.description
                  ?.toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ??
              false) ||
          group.checklists.any((checklist) =>
              checklist.title
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              (checklist.description
                      ?.toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ??
                  false));
    }).toList();
  }

  Future<void> _selectSpecificDate() async {
    final DateTime now = DateTime.now();
    int selectedYear = _fromDate?.year ?? now.year;
    int selectedMonth = _fromDate?.month ?? now.month;
    int selectedDay = _fromDate?.day ?? now.day;

    final result = await showDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final daysInMonth =
                DateTime(selectedYear, selectedMonth + 1, 0).day;
            if (selectedDay > daysInMonth) selectedDay = daysInMonth;

            return Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: _cardBackgroundColor,
                elevation: 8,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(24),
                title: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'اختر تاريخ محدد',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                content: SizedBox(
                  width: 350,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildEnhancedDateSelector('السنة:', selectedYear,
                          (value) {
                        setDialogState(() => selectedYear = value!);
                      }, List.generate(10, (index) => now.year - 5 + index)),
                      const SizedBox(height: 20),
                      _buildEnhancedDateSelector('الشهر:', selectedMonth,
                          (value) {
                        setDialogState(() => selectedMonth = value!);
                      }, List.generate(12, (index) => index + 1),
                          itemBuilder: (value) => arabicMonths[value - 1]),
                      const SizedBox(height: 20),
                      _buildEnhancedDateSelector('اليوم:', selectedDay,
                          (value) {
                        setDialogState(() => selectedDay = value!);
                      }, List.generate(daysInMonth, (index) => index + 1)),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _lightPrimaryColor,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: _primaryColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_month,
                                color: _primaryColor, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              '$selectedDay ${arabicMonths[selectedMonth - 1]} $selectedYear',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: _textSecondaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child: const Text('إلغاء',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context,
                          DateTime(selectedYear, selectedMonth, selectedDay));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('موافق',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _fromDate = result;
        _toDate = DateTime(result.year, result.month, result.day, 23, 59, 59);
        _calculateAdditionalStatistics();
      });
    }
  }

  Future<void> _selectSpecificMonth() async {
    final DateTime now = DateTime.now();
    int selectedYear = _fromDate?.year ?? now.year;
    int selectedMonth = _fromDate?.month ?? now.month;

    final result = await showDialog<Map<String, int>>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: _cardBackgroundColor,
                elevation: 8,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(24),
                title: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.calendar_view_month,
                          color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'اختر شهر محدد',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                content: SizedBox(
                  width: 350,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildEnhancedDateSelector('السنة:', selectedYear,
                          (value) {
                        setDialogState(() => selectedYear = value!);
                      }, List.generate(10, (index) => now.year - 5 + index)),
                      const SizedBox(height: 20),
                      _buildEnhancedDateSelector('الشهر:', selectedMonth,
                          (value) {
                        setDialogState(() => selectedMonth = value!);
                      }, List.generate(12, (index) => index + 1),
                          itemBuilder: (value) => arabicMonths[value - 1]),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _lightPrimaryColor,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: _primaryColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_month,
                                color: _primaryColor, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              '${arabicMonths[selectedMonth - 1]} $selectedYear',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: _textSecondaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child: const Text('إلغاء',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context,
                          {'year': selectedYear, 'month': selectedMonth});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('موافق',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _fromDate = DateTime(result['year']!, result['month']!, 1);
        _toDate =
            DateTime(result['year']!, result['month']! + 1, 0, 23, 59, 59);
        _calculateAdditionalStatistics();
      });
    }
  }

  Future<void> _selectSpecificYear() async {
    final DateTime now = DateTime.now();
    int selectedYear = _fromDate?.year ?? now.year;

    final result = await showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: _cardBackgroundColor,
                elevation: 8,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(24),
                title: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.edit_calendar, color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'اختر سنة محددة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                content: SizedBox(
                  width: 350,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildEnhancedDateSelector('السنة:', selectedYear,
                          (value) {
                        setDialogState(() => selectedYear = value!);
                      }, List.generate(15, (index) => now.year - 10 + index)),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _lightPrimaryColor,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: _primaryColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_month,
                                color: _primaryColor, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              '$selectedYear',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: _primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: _textSecondaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child: const Text('إلغاء',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, selectedYear);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('موافق',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _fromDate = DateTime(result, 1, 1);
        _toDate = DateTime(result, 12, 31, 23, 59, 59);
        _calculateAdditionalStatistics();
      });
    }
  }

  Widget _buildEnhancedDateSelector(
      String label, int value, Function(int?) onChanged, List<int> items,
      {String Function(int)? itemBuilder}) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textPrimaryColor,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _lightPrimaryColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _borderColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: value,
                isExpanded: true,
                items: items.map((item) {
                  return DropdownMenuItem(
                    value: item,
                    child: Text(
                      itemBuilder?.call(item) ?? '$item',
                      style: TextStyle(
                        fontSize: 16,
                        color: _textPrimaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showCreateChecklistGroupDialog() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const QualityChecklistBuilderScreen(),
      ),
    );

    if (result == true) {
      _loadChecklistGroups();
    }
  }

  Future<void> _editChecklistGroup(QualityChecklistGroup group) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            QualityChecklistBuilderScreen(checklistGroup: group),
      ),
    );

    if (result == true) {
      _loadChecklistGroups();
    }
  }

  Future<void> _deleteChecklistGroup(QualityChecklistGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DeleteConfirmationDialog(group: group),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.deleteQualityChecklistGroup(group.id);
        Helpers.showSnackBar(
            context, 'تم حذف مجموعة قوائم مراقبة الجودة بنجاح');
        _loadChecklistGroups();
      } catch (e) {
        Helpers.showSnackBar(
          context,
          'فشل في حذف مجموعة قوائم مراقبة الجودة',
          isError: true,
        );
      }
    }
  }

  Future<void> _toggleGroupStatus(QualityChecklistGroup group) async {
    try {
      await SupabaseService.updateQualityChecklistGroup(
        id: group.id,
        isActive: !group.isActive,
      );
      Helpers.showSnackBar(
        context,
        group.isActive ? 'تم إلغاء تفعيل المجموعة' : 'تم تفعيل المجموعة',
      );
      _loadChecklistGroups();
    } catch (e) {
      Helpers.showSnackBar(
        context,
        'فشل في تغيير حالة المجموعة',
        isError: true,
      );
    }
  }

  Future<void> _duplicateGroup(QualityChecklistGroup group) async {
    try {
      await SupabaseService.duplicateQualityChecklistGroup(group.id);
      if (!mounted) return;
      Helpers.showSnackBar(context, 'تم تكرار المجموعة بنجاح');
      _loadChecklistGroups();
    } catch (e) {
      if (!mounted) return;
      Helpers.showSnackBar(context, 'فشل في التكرار', isError: true);
    }
  }

  Future<void> _duplicateChecklist(QualityChecklist cl) async {
    try {
      await SupabaseService.duplicateQualityChecklist(cl.id);
      if (!mounted) return;
      Helpers.showSnackBar(context, 'تم تكرار القائمة بنجاح');
      _loadChecklistGroups();
    } catch (e) {
      if (!mounted) return;
      Helpers.showSnackBar(context, 'فشل في التكرار', isError: true);
    }
  }

  // Updated method to handle multiple checklists
  void _showReportsForGroup(QualityChecklistGroup group) {
    setState(() {
      _selectedReportGroup = group;
      _selectedReportChecklist =
          group.checklists.isNotEmpty ? group.checklists.first : null;
      _selectedDeterminants.clear();
      _checklistDeterminantFilters.clear();
      _checklistStatistics.clear();
      _selectedResponsesChecklistId =
          group.checklists.isNotEmpty ? group.checklists.first.id : null;
      _showReports = true;
      _showResponsesTable = false;
      _showMultipleChecklistsView =
          group.isMultipleActive && group.checklists.length > 1;
    });

    if (_showMultipleChecklistsView) {
      _loadMultipleChecklistsStatistics();
    } else {
      _loadStatistics();
    }
  }

  void _goBackToGroups() {
    setState(() {
      _showReports = false;
      _selectedReportGroup = null;
      _selectedReportChecklist = null;
      _selectedDeterminants.clear();
      _showResponsesTable = false;
      _checklistDeterminantFilters.clear();
      _checklistStatistics.clear();
      _showMultipleChecklistsView = false;
    });
  }

  void _toggleResponsesView() {
    setState(() {
      _showResponsesTable = !_showResponsesTable;
    });
  }

  String _formatArabicDate(DateTime date) {
    return '${date.day} ${arabicMonths[date.month - 1]} ${date.year}';
  }

  Widget _buildDateSelector(
      String label, int value, Function(int?) onChanged, List<int> items,
      {String Function(int)? itemBuilder}) {
    return Row(
      children: [
        Container(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE1E5E9)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: value,
                isExpanded: true,
                items: items.map((item) {
                  return DropdownMenuItem(
                    value: item,
                    child: Text(
                      itemBuilder?.call(item) ?? '$item',
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF2C3E50)),
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final isMobile = screenWidth < 768;
          final isTablet = screenWidth >= 768 && screenWidth < 1200;

          return Scaffold(
            backgroundColor: Colors.white,
            appBar: _buildCompactAppBar(isMobile),
            body: _showReports
                ? _buildReportsView(isMobile, isTablet)
                : _buildChecklistGroupsView(isMobile, isTablet),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildCompactAppBar(bool isMobile) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent, // remove M3 overlay tint
      elevation: 1,
      toolbarHeight: 60,
      leading: _showReports
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
              onPressed: _goBackToGroups,
            )
          : null,
      title: Container(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                _showReports ? Icons.analytics : Icons.checklist,
                color: const Color(0xFF8B5CF6),
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _showReports
                    ? 'تقارير - ${_selectedReportGroup?.title ?? ''}'
                    : 'إدارة مراقبة الجودة',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2C3E50),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (!_showReports) ...[
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ElevatedButton.icon(
              onPressed: _showCreateChecklistGroupDialog,
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: Text(
                isMobile ? 'إنشاء' : 'إنشاء مجموعة',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                elevation: 1,
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                minimumSize: const Size(0, 36),
              ),
            ),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: ElevatedButton.icon(
              onPressed: _toggleResponsesView,
              icon: Icon(
                _showResponsesTable ? Icons.analytics : Icons.list,
                size: 16,
                color: Colors.white,
              ),
              label: Text(
                _showResponsesTable ? 'المتوسطات' : 'الاستجابات',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                elevation: 1,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                minimumSize: const Size(0, 36),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ElevatedButton.icon(
              onPressed: _isExporting ? null : _showExportDialog,
              icon: _isExporting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download, size: 16, color: Colors.white),
              label: Text(
                _isExporting ? 'جارٍ...' : 'تصدير',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 1,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                minimumSize: const Size(0, 36),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChecklistGroupsView(bool isMobile, bool isTablet) {
    return Column(
      children: [
        Container(
          height: 40,
          margin: const EdgeInsets.all(8),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'البحث في مجموعات القوائم...',
              hintStyle:
                  const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              prefixIcon:
                  const Icon(Icons.search, color: Color(0xFF8B5CF6), size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE1E5E9)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ),
        if (_searchQuery.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Text(
                  'النتائج: ${_filteredChecklistGroups.length} من أصل ${_checklistGroups.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF546E7A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
              : _filteredChecklistGroups.isEmpty
                  ? _buildEmptyState()
                  : _buildCompactGroupsList(isMobile),
        ),
      ],
    );
  }

  Widget _buildCompactGroupsList(bool isMobile) {
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _filteredChecklistGroups.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final group = _filteredChecklistGroups[index];
        return _buildCompactGroupCard(group, isMobile);
      },
    );
  }

  Widget _buildCompactGroupCard(QualityChecklistGroup group, bool isMobile) {
    final isExpanded = _expandedGroups[group.id] ?? false;
    final statusColor = group.isActive ? _primaryColor : _textSecondaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _cardBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Main row ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              // Accent bar
              Container(
                width: 3, height: 38,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Icon box
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(Icons.checklist_rtl_rounded, color: statusColor, size: 16),
              ),
              const SizedBox(width: 10),
              // Title + meta chips
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title,
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        fontWeight: FontWeight.w700,
                        color: _textPrimaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(spacing: 10, runSpacing: 2, children: [
                      _miniInfoChip(Icons.list_alt_rounded,
                          '${group.checklists.length} قائمة', _primaryColor),
                      _miniInfoChip(
                        group.isActive
                            ? Icons.check_circle_outline_rounded
                            : Icons.pause_circle_outline_rounded,
                        group.isActive ? 'مفعل' : 'معطل',
                        statusColor,
                      ),
                      if (group.isMultipleActive)
                        _miniInfoChip(Icons.layers_rounded, 'متعدد',
                            const Color(0xFF8B5CF6)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // ── Action buttons ──────────────────────────────
              _buildCompactIconBtn(Icons.analytics_outlined, _primaryColor,
                  () => _showReportsForGroup(group), 'التقارير'),
              const SizedBox(width: 4),
              _buildCompactIconBtn(Icons.copy_outlined, const Color(0xFF3B82F6),
                  () => _duplicateGroup(group), 'تكرار'),
              const SizedBox(width: 4),
              _buildCompactIconBtn(Icons.edit_outlined, Colors.blue,
                  () => _editChecklistGroup(group), 'تعديل'),
              const SizedBox(width: 4),
              _buildCompactIconBtn(
                group.isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                group.isActive ? Colors.orange : Colors.green,
                () => _toggleGroupStatus(group),
                group.isActive ? 'إيقاف' : 'تفعيل',
              ),
              const SizedBox(width: 4),
              _buildCompactIconBtn(Icons.delete_outline_rounded, Colors.red,
                  () => _deleteChecklistGroup(group), 'حذف'),
              const SizedBox(width: 4),
              _buildCompactIconBtn(
                isExpanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                _textSecondaryColor,
                () => setState(() =>
                    _expandedGroups[group.id] = !isExpanded),
                isExpanded ? 'طي' : 'عرض القوائم',
              ),
            ]),
          ),
          // ── Expanded checklist sub-list ────────────────────
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            if (group.checklists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('لا توجد قوائم في هذه المجموعة',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              )
            else
              ...group.checklists.map((cl) => _buildChecklistSubTile(cl)),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklistSubTile(QualityChecklist cl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(children: [
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.checklist_rounded, color: _primaryColor, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cl.title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textPrimaryColor)),
            if (cl.checkPoints.isNotEmpty)
              Text('${cl.checkPoints.length} نقطة تفتيش',
                  style: TextStyle(fontSize: 11, color: _textSecondaryColor)),
          ]),
        ),
        _buildCompactIconBtn(Icons.copy_outlined, const Color(0xFF3B82F6),
            () => _duplicateChecklist(cl), 'تكرار'),
      ]),
    );
  }

  Widget _miniInfoChip(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 11, color: color)),
    ],
  );

  Widget _buildCompactIconBtn(
      IconData icon, Color color, VoidCallback onTap, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
    bool isMobile, {
    bool isDanger = false,
  }) {
    return SizedBox(
      height: 28,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 12, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.checklist_outlined,
                size: 32,
                color: Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'لا توجد مجموعات قوائم مراقبة جودة'
                  : 'لا توجد نتائج للبحث',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'ابدأ بإنشاء مجموعة قوائم مراقبة الجودة الأولى'
                  : 'جرب كلمات مفتاحية مختلفة',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF546E7A),
              ),
            ),
          ],
        ),
      ),
    );
  }

// Updated _buildReportsView - remove تطبيق button
  Widget _buildReportsView(bool isMobile, bool isTablet) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                  color:
                      !_showResponsesTable ? Color(0xFFE1E5E9) : Colors.white),
            ),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildPeriodSelector(isMobile),
                  ),
                  if (_selectedPeriod == 'one_day' ||
                      _selectedPeriod == 'date_range' ||
                      _selectedPeriod == 'specific_month' ||
                      _selectedPeriod == 'specific_year') ...[
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _buildDateSelectors(isMobile),
                    ),
                  ],
                  // Remove the تطبيق button - filters apply automatically
                ],
              ),
              _buildOverallStatisticsCard(),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingStats
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
              : _showResponsesTable
                  ? (_showMultipleChecklistsView
                      ? _buildMultipleChecklistsResponsesTable(
                          isMobile, isTablet)
                      : _buildResponsesTable(isMobile, isTablet))
                  : (_showMultipleChecklistsView
                      ? _buildMultipleChecklistsDataTables(isMobile, isTablet)
                      : _buildDataTables(isMobile, isTablet)),
        ),
      ],
    );
  }

// Updated _buildResponsesTable method with fixed statistics
  Widget _buildResponsesTable(bool isMobile, bool isTablet) {
    final filteredResponses = _dateAndDeterminantFilteredResponses;

    if (_responses.isEmpty) {
      return _buildNoDataState();
    }

    if (filteredResponses.isEmpty && _selectedDeterminants.isNotEmpty) {
      return _buildNoFilterResultsState();
    }

    final Map<String, String> userNames = {};

    return FutureBuilder<void>(
      future: _loadUserNames(
          filteredResponses.map((r) => r.userId).toSet(), userNames),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statistics and Filters section for single checklist
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE1E5E9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.analytics,
                            color: _primaryColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إحصائيات ${_selectedReportChecklist!.title}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _textPrimaryColor,
                              ),
                            ),
                            Text(
                              'الفترة: ${_formatArabicDate(_fromDate!)} - ${_formatArabicDate(_toDate!)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF546E7A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Statistics grid with FIXED calculations
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Builder(
                      builder: (context) {
                        // Calculate statistics with correct filter application
                        final now = DateTime.now();
                        final currentMonthStart =
                            DateTime(now.year, now.month, 1);
                        final currentMonthEnd =
                            DateTime(now.year, now.month + 1, 0, 23, 59, 59);
                        final currentYearStart = DateTime(now.year, 1, 1);
                        final currentYearEnd =
                            DateTime(now.year, 12, 31, 23, 59, 59);

                        final checklistResponses = _responses
                            .where((r) =>
                                r.checklistId == _selectedReportChecklist!.id)
                            .toList();

                        // For overall percentage - apply date + determinant filters
                        final dateFilteredResponses =
                            checklistResponses.where((r) {
                          if (_fromDate != null && _toDate != null) {
                            return r.responseDate.isAfter(_fromDate!
                                    .subtract(const Duration(days: 1))) &&
                                r.responseDate.isBefore(
                                    _toDate!.add(const Duration(days: 1)));
                          }
                          return true;
                        }).toList();
                        final overallFilteredResponses =
                            _applyDeterminantFilters(dateFilteredResponses);

                        // For current month - apply ONLY determinant filters
                        final currentMonthResponses = checklistResponses
                            .where((r) =>
                                r.responseDate.isAfter(currentMonthStart
                                    .subtract(const Duration(days: 1))) &&
                                r.responseDate.isBefore(currentMonthEnd
                                    .add(const Duration(days: 1))))
                            .toList();
                        final currentMonthFilteredResponses =
                            _applyDeterminantFilters(currentMonthResponses);

                        // For current year - apply ONLY determinant filters
                        final currentYearResponses = checklistResponses
                            .where((r) =>
                                r.responseDate.isAfter(currentYearStart
                                    .subtract(const Duration(days: 1))) &&
                                r.responseDate.isBefore(currentYearEnd
                                    .add(const Duration(days: 1))))
                            .toList();
                        final currentYearFilteredResponses =
                            _applyDeterminantFilters(currentYearResponses);

                        // Calculate percentages with correct filter application
                        final overallPercentage = _calculateChecklistAverage(
                            overallFilteredResponses,
                            _selectedReportChecklist!);
                        final currentMonthPercentage =
                            _calculateChecklistAverage(
                                currentMonthFilteredResponses,
                                _selectedReportChecklist!);
                        final currentYearPercentage =
                            _calculateChecklistAverage(
                                currentYearFilteredResponses,
                                _selectedReportChecklist!);

                        return Row(
                          children: [
                            _buildResponseStatisticCard(
                              'الشهر الحالي',
                              '${currentMonthPercentage.toStringAsFixed(1)}%',
                              Icons.calendar_today,
                              const Color(0xFF10B981),
                              '${currentMonthFilteredResponses.length} استجابة',
                            ),
                            const SizedBox(width: 12),
                            _buildResponseStatisticCard(
                              'السنة الحالية',
                              '${currentYearPercentage.toStringAsFixed(1)}%',
                              Icons.event,
                              const Color(0xFF3B82F6),
                              '${currentYearFilteredResponses.length} استجابة',
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Quick metrics row
                  Row(
                    children: [
                      _buildQuickMetric(
                        _selectedDeterminants.isNotEmpty
                            ? 'الاستجابات المفلترة'
                            : 'إجمالي الاستجابات',
                        '${filteredResponses.length}${_selectedDeterminants.isNotEmpty ? ' من ${_responses.length}' : ''}',
                        Icons.list_alt,
                        _selectedDeterminants.isNotEmpty
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFF8B5CF6),
                      ),
                      const SizedBox(width: 16),
                      _buildQuickMetric(
                        'نقاط الفحص',
                        '${_selectedReportChecklist!.checkPoints.length}',
                        Icons.checklist,
                        const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 16),
                      _buildQuickMetric(
                        'المحددات',
                        '${_selectedReportChecklist!.determinants.length}',
                        Icons.tune,
                        const Color(0xFF6366F1),
                      ),
                      if (_selectedDeterminants.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        _buildQuickMetric(
                          'الفلاتر النشطة',
                          '${_selectedDeterminants.length}',
                          Icons.filter_alt,
                          const Color(0xFFF59E0B),
                        ),
                      ],
                    ],
                  ),

                  // Add determinant filters for single checklist responses
                  if (_selectedReportChecklist!.determinants.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE1E5E9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.filter_list,
                                  size: 20, color: _primaryColor),
                              const SizedBox(width: 8),
                              Text(
                                'فلاتر المحددات:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              ..._selectedReportChecklist!.determinants
                                  .map((determinant) {
                                final isActive = _selectedDeterminants
                                    .containsKey(determinant.id);

                                return Container(
                                  width: 180,
                                  height: 32,
                                  child: DropdownButtonFormField<String>(
                                    value:
                                        _selectedDeterminants[determinant.id],
                                    hint: Text(
                                      determinant.name,
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        if (value != null &&
                                            value.isNotEmpty &&
                                            value != 'الكل') {
                                          _selectedDeterminants[
                                              determinant.id] = value;
                                        } else {
                                          _selectedDeterminants
                                              .remove(determinant.id);
                                        }
                                        _calculateAdditionalStatistics();
                                      });
                                    },
                                    style: TextStyle(
                                        fontSize: 12, color: _textPrimaryColor),
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: 'الكل',
                                        child: Text('الكل',
                                            style: TextStyle(fontSize: 12)),
                                      ),
                                      ...determinant.options.map((option) {
                                        return DropdownMenuItem<String>(
                                          value: option.value,
                                          child: Text(
                                            option.value,
                                            style:
                                                const TextStyle(fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                );
                              }),
                              if (_selectedDeterminants.isNotEmpty) ...[
                                Container(
                                  height: 32,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _selectedDeterminants.clear();
                                        _calculateAdditionalStatistics();
                                      });
                                    },
                                    icon: const Icon(Icons.clear,
                                        size: 14, color: Colors.red),
                                    label: const Text('مسح الفلاتر',
                                        style: TextStyle(fontSize: 11)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Colors.red.withOpacity(0.1),
                                      foregroundColor: Colors.red,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side:
                                            const BorderSide(color: Colors.red),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_selectedDeterminants.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildActiveFiltersRow(),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                trackVisibility: true,
                child: ListView.separated(
                  padding: const EdgeInsets.all(4),
                  itemCount: filteredResponses.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final response = filteredResponses[index];
                    return _buildEnhancedResponseCard(
                        response, userNames, index);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

// Updated period selector with auto-apply
  Widget _buildPeriodSelector(bool isMobile) {
    final periods = [
      {'key': 'one_day', 'label': 'يوم محدد'},
      {'key': 'current_month', 'label': 'الشهر الحالي'},
      {'key': 'current_year', 'label': 'السنة الحالية'},
      {'key': 'specific_month', 'label': 'شهر محدد'},
      {'key': 'specific_year', 'label': 'سنة محددة'},
      {'key': 'date_range', 'label': 'فترة مخصصة'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الفترة الزمنية',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _textPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 40,
          child: DropdownButtonFormField<String>(
            value: _selectedPeriod,
            onChanged: (value) {
              setState(() {
                _selectedPeriod = value!;
                _initializeDates(); // This will auto-apply the changes
              });
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: _lightPrimaryColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _primaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            style: TextStyle(fontSize: 13, color: _textPrimaryColor),
            items: periods.map((period) {
              return DropdownMenuItem<String>(
                value: period['key'] as String,
                child: Text(period['label'] as String),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

// Updated date selectors widget - shows single field for date range
  Widget _buildDateSelectors(bool isMobile) {
    if (_selectedPeriod == 'date_range') {
      String dateRangeText = 'اختر الفترة';
      if (_fromDate != null && _toDate != null) {
        dateRangeText =
            '${_formatArabicDate(_fromDate!)} - ${_formatArabicDate(_toDate!)}';
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الفترة المخصصة',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _showDateRangeDialog,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _lightPrimaryColor,
                border: Border.all(color: _borderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.date_range, size: 18, color: _primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      dateRangeText,
                      style: TextStyle(
                        fontSize: 13,
                        color: _textPrimaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else if (['one_day', 'specific_month', 'specific_year']
        .contains(_selectedPeriod)) {
      String label = '';
      String dateText = 'اختر التاريخ';

      switch (_selectedPeriod) {
        case 'one_day':
          label = 'اختر التاريخ';
          if (_fromDate != null) {
            dateText = _formatArabicDate(_fromDate!);
          }
          break;
        case 'specific_month':
          label = 'اختر الشهر';
          if (_fromDate != null) {
            dateText =
                '${arabicMonths[_fromDate!.month - 1]} ${_fromDate!.year}';
          }
          break;
        case 'specific_year':
          label = 'اختر السنة';
          if (_fromDate != null) {
            dateText = '${_fromDate!.year}';
          }
          break;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _selectDate,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _lightPrimaryColor,
                border: Border.all(color: _borderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 18, color: _primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      dateText,
                      style: TextStyle(
                        fontSize: 13,
                        color: _textPrimaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

// Updated date selection method - applies filters automatically
  Future<void> _selectDate() async {
    switch (_selectedPeriod) {
      case 'one_day':
        await _selectSpecificDateWithAutoApply();
        break;
      case 'specific_month':
        await _selectSpecificMonthWithAutoApply();
        break;
      case 'specific_year':
        await _selectSpecificYearWithAutoApply();
        break;
      case 'date_range':
        await _showDateRangeDialog();
        break;
    }
  }

// Updated method to show single date range dialog for custom date range
  Future<void> _showDateRangeDialog() async {
    final DateTime now = DateTime.now();
    DateTime selectedFromDate = _fromDate ?? DateTime(now.year, now.month, 1);
    DateTime selectedToDate =
        _toDate ?? DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: _cardBackgroundColor,
                elevation: 8,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(24),
                title: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.date_range, color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'اختر الفترة المخصصة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                content: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // From Date Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: _lightPrimaryColor,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: _primaryColor.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'من تاريخ:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDateSelectorInDialog(
                                      'السنة:', selectedFromDate.year, (value) {
                                    setDialogState(() {
                                      selectedFromDate = DateTime(
                                          value!,
                                          selectedFromDate.month,
                                          selectedFromDate.day);
                                    });
                                  },
                                      List.generate(
                                          10, (index) => now.year - 5 + index)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDateSelectorInDialog(
                                      'الشهر:', selectedFromDate.month,
                                      (value) {
                                    setDialogState(() {
                                      final daysInMonth = DateTime(
                                              selectedFromDate.year,
                                              value! + 1,
                                              0)
                                          .day;
                                      final day =
                                          selectedFromDate.day > daysInMonth
                                              ? daysInMonth
                                              : selectedFromDate.day;
                                      selectedFromDate = DateTime(
                                          selectedFromDate.year, value, day);
                                    });
                                  }, List.generate(12, (index) => index + 1),
                                      itemBuilder: (value) =>
                                          arabicMonths[value - 1]),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDateSelectorInDialog(
                                      'اليوم:', selectedFromDate.day, (value) {
                                    setDialogState(() {
                                      selectedFromDate = DateTime(
                                          selectedFromDate.year,
                                          selectedFromDate.month,
                                          value!);
                                    });
                                  },
                                      List.generate(
                                          DateTime(selectedFromDate.year,
                                                  selectedFromDate.month + 1, 0)
                                              .day,
                                          (index) => index + 1)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // To Date Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _lightPrimaryColor,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: _primaryColor.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إلى تاريخ:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDateSelectorInDialog(
                                      'السنة:', selectedToDate.year, (value) {
                                    setDialogState(() {
                                      selectedToDate = DateTime(
                                          value!,
                                          selectedToDate.month,
                                          selectedToDate.day,
                                          23,
                                          59,
                                          59);
                                    });
                                  },
                                      List.generate(
                                          10, (index) => now.year - 5 + index)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDateSelectorInDialog(
                                      'الشهر:', selectedToDate.month, (value) {
                                    setDialogState(() {
                                      final daysInMonth = DateTime(
                                              selectedToDate.year,
                                              value! + 1,
                                              0)
                                          .day;
                                      final day =
                                          selectedToDate.day > daysInMonth
                                              ? daysInMonth
                                              : selectedToDate.day;
                                      selectedToDate = DateTime(
                                          selectedToDate.year,
                                          value,
                                          day,
                                          23,
                                          59,
                                          59);
                                    });
                                  }, List.generate(12, (index) => index + 1),
                                      itemBuilder: (value) =>
                                          arabicMonths[value - 1]),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDateSelectorInDialog(
                                      'اليوم:', selectedToDate.day, (value) {
                                    setDialogState(() {
                                      selectedToDate = DateTime(
                                          selectedToDate.year,
                                          selectedToDate.month,
                                          value!,
                                          23,
                                          59,
                                          59);
                                    });
                                  },
                                      List.generate(
                                          DateTime(selectedToDate.year,
                                                  selectedToDate.month + 1, 0)
                                              .day,
                                          (index) => index + 1)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Preview Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: _primaryColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.preview, color: _primaryColor, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              '${_formatArabicDate(selectedFromDate)} - ${_formatArabicDate(selectedToDate)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: _textSecondaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child: const Text('إلغاء',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, {
                        'fromDate': selectedFromDate,
                        'toDate': selectedToDate,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('تطبيق',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _fromDate = result['fromDate']!;
        _toDate = result['toDate']!;
        _calculateAdditionalStatistics();
      });

      // Auto-reload statistics
      if (_showMultipleChecklistsView) {
        _loadMultipleChecklistsStatistics();
      } else {
        _loadStatistics();
      }
    }
  }

  Widget _buildDateSelectorInDialog(
      String label, int value, Function(int?) onChanged, List<int> items,
      {String Function(int)? itemBuilder}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _textPrimaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              items: items.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(
                    itemBuilder?.call(item) ?? '$item',
                    style: TextStyle(
                      fontSize: 13,
                      color: _textPrimaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

// Updated specific date selector with auto-apply
  Future<void> _selectSpecificDateWithAutoApply() async {
    final DateTime now = DateTime.now();
    int selectedYear = _fromDate?.year ?? now.year;
    int selectedMonth = _fromDate?.month ?? now.month;
    int selectedDay = _fromDate?.day ?? now.day;

    final result = await showDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final daysInMonth =
                DateTime(selectedYear, selectedMonth + 1, 0).day;
            if (selectedDay > daysInMonth) selectedDay = daysInMonth;

            return Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: _cardBackgroundColor,
                elevation: 8,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(24),
                title: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'اختر تاريخ محدد',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                content: SizedBox(
                  width: 350,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildEnhancedDateSelector('السنة:', selectedYear,
                          (value) {
                        setDialogState(() => selectedYear = value!);
                      }, List.generate(10, (index) => now.year - 5 + index)),
                      const SizedBox(height: 20),
                      _buildEnhancedDateSelector('الشهر:', selectedMonth,
                          (value) {
                        setDialogState(() => selectedMonth = value!);
                      }, List.generate(12, (index) => index + 1),
                          itemBuilder: (value) => arabicMonths[value - 1]),
                      const SizedBox(height: 20),
                      _buildEnhancedDateSelector('اليوم:', selectedDay,
                          (value) {
                        setDialogState(() => selectedDay = value!);
                      }, List.generate(daysInMonth, (index) => index + 1)),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _lightPrimaryColor,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: _primaryColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_month,
                                color: _primaryColor, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              '$selectedDay ${arabicMonths[selectedMonth - 1]} $selectedYear',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: _textSecondaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child: const Text('إلغاء',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context,
                          DateTime(selectedYear, selectedMonth, selectedDay));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('موافق',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _fromDate = result;
        _toDate = DateTime(result.year, result.month, result.day, 23, 59, 59);
        _calculateAdditionalStatistics();
      });

      // Auto-reload statistics
      if (_showMultipleChecklistsView) {
        _loadMultipleChecklistsStatistics();
      } else {
        _loadStatistics();
      }
    }
  }

// Updated specific month selector with auto-apply
  Future<void> _selectSpecificMonthWithAutoApply() async {
    final DateTime now = DateTime.now();
    int selectedYear = _fromDate?.year ?? now.year;
    int selectedMonth = _fromDate?.month ?? now.month;

    final result = await showDialog<Map<String, int>>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: _cardBackgroundColor,
                elevation: 8,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(24),
                title: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.calendar_view_month,
                          color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'اختر شهر محدد',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                content: SizedBox(
                  width: 350,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildEnhancedDateSelector('السنة:', selectedYear,
                          (value) {
                        setDialogState(() => selectedYear = value!);
                      }, List.generate(10, (index) => now.year - 5 + index)),
                      const SizedBox(height: 20),
                      _buildEnhancedDateSelector('الشهر:', selectedMonth,
                          (value) {
                        setDialogState(() => selectedMonth = value!);
                      }, List.generate(12, (index) => index + 1),
                          itemBuilder: (value) => arabicMonths[value - 1]),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _lightPrimaryColor,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: _primaryColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_month,
                                color: _primaryColor, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              '${arabicMonths[selectedMonth - 1]} $selectedYear',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: _textSecondaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child: const Text('إلغاء',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context,
                          {'year': selectedYear, 'month': selectedMonth});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('موافق',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _fromDate = DateTime(result['year']!, result['month']!, 1);
        _toDate =
            DateTime(result['year']!, result['month']! + 1, 0, 23, 59, 59);
        _calculateAdditionalStatistics();
      });

      // Auto-reload statistics
      if (_showMultipleChecklistsView) {
        _loadMultipleChecklistsStatistics();
      } else {
        _loadStatistics();
      }
    }
  }

// Updated specific year selector with auto-apply
  Future<void> _selectSpecificYearWithAutoApply() async {
    final DateTime now = DateTime.now();
    int selectedYear = _fromDate?.year ?? now.year;

    final result = await showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: _cardBackgroundColor,
                elevation: 8,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(24),
                title: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.edit_calendar, color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'اختر سنة محددة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                content: SizedBox(
                  width: 350,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildEnhancedDateSelector('السنة:', selectedYear,
                          (value) {
                        setDialogState(() => selectedYear = value!);
                      }, List.generate(15, (index) => now.year - 10 + index)),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _lightPrimaryColor,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: _primaryColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_month,
                                color: _primaryColor, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              '$selectedYear',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: _primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: _textSecondaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child: const Text('إلغاء',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, selectedYear);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('موافق',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _fromDate = DateTime(result, 1, 1);
        _toDate = DateTime(result, 12, 31, 23, 59, 59);
        _calculateAdditionalStatistics();
      });

      // Auto-reload statistics
      if (_showMultipleChecklistsView) {
        _loadMultipleChecklistsStatistics();
      } else {
        _loadStatistics();
      }
    }
  }

// Revert back to original _buildEnhancedStatisticsCards design
  Widget _buildEnhancedStatisticsCards(bool isMobile) {
    if (_selectedReportChecklist == null) return const SizedBox();

    final filteredStats = _filteredStatistics;
    final overallAverage = filteredStats['overall_average'] as double;
    final maxRating = _selectedReportChecklist!.rateNumber;
    final overallPercentage =
        maxRating > 0 ? (overallAverage / maxRating * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: _cardBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.analytics, color: _primaryColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الإحصائيات التفصيلية',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _textPrimaryColor,
                      ),
                    ),
                    Text(
                      'الفترة: ${_formatArabicDate(_fromDate!)} - ${_formatArabicDate(_toDate!)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: _textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Statistics Grid - Original design with 5 statistics -----------------------------------------------------------------------------------------
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount =
                  isMobile ? 2 : (constraints.maxWidth > 1200 ? 5 : 3);
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio:
                    isMobile ? 1.1 : (crossAxisCount == 5 ? 0.9 : 1.0),
                children: [
                  _buildStatisticCard(
                    'المتوسط العام للشهر الحالي',
                    '${(_additionalStatistics['current_month_average'] as double).toStringAsFixed(1)}%',
                    Icons.calendar_today,
                    const Color(0xFF10B981),
                    subtitle: 'الشهر الحالي فقط',
                  ),
                  _buildStatisticCard(
                    'المتوسط العام للسنة الحالية',
                    '${(_additionalStatistics['current_year_average'] as double).toStringAsFixed(1)}%',
                    Icons.event,
                    const Color(0xFF3B82F6),
                    subtitle: 'السنة الحالية فقط',
                  ),
                ],
              );
            },
          ),

          if (_selectedDeterminants.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildActiveFiltersSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatisticCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            textDirection: ui.TextDirection.ltr,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textPrimaryColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: _textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt, size: 18, color: _primaryColor),
              const SizedBox(width: 8),
              Text(
                'الفلاتر المطبقة:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._selectedDeterminants.entries.map((entry) {
                final determinant = _selectedReportChecklist!.determinants
                    .firstWhere((d) => d.id == entry.key);

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _primaryColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${determinant.name}: ${entry.value}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _primaryColor,
                    ),
                  ),
                );
              }).toList(),
              Container(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() => _selectedDeterminants.clear());
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('مسح الكل', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: _primaryColor,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Export methods will be added here
  Future<void> _showExportDialog() async {
    if (_selectedReportGroup == null) return;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ExportOptionsDialog(
        checklistGroup: _selectedReportGroup!,
      ),
    );

    if (result != null) {
      if (result == 'all') {
        await _exportAllChecklistsToExcel();
      } else {
        final checklistId = int.tryParse(result);
        if (checklistId != null) {
          await _exportSingleChecklistToExcel(checklistId);
        }
      }
    }
  }

// Keep the existing _buildResponseStatisticCard method as is
  Widget _buildResponseStatisticCard(
      String title, String value, IconData icon, Color color,
      [String? subtitle]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                textDirection: ui.TextDirection.ltr,
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  color: _textSecondaryColor,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9,
                    color: _textSecondaryColor.withOpacity(0.7),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

// Updated statistics calculation for responses table in multiple checklists view
  Widget _buildMultipleChecklistsResponsesTable(bool isMobile, bool isTablet) {
    if (_selectedReportGroup == null || _responses.isEmpty) {
      return _buildNoDataState();
    }

    final filteredResponses = _selectedResponsesChecklistId != null
        ? _responses
            .where((r) => r.checklistId == _selectedResponsesChecklistId)
            .toList()
        : _responses;

    // Apply checklist-specific filters
    final finalFilteredResponses = _selectedResponsesChecklistId != null
        ? _applyChecklistSpecificFilters(
            filteredResponses, _selectedResponsesChecklistId!)
        : filteredResponses;

    // Get the selected checklist for statistics calculation
    final selectedChecklist = _selectedResponsesChecklistId != null
        ? _selectedReportGroup!.checklists.firstWhere(
            (c) => c.id == _selectedResponsesChecklistId,
            orElse: () => _selectedReportGroup!.checklists.first,
          )
        : null;

    final Map<String, String> userNames = {};

    return FutureBuilder<void>(
      future: _loadUserNames(
          finalFilteredResponses.map((r) => r.userId).toSet(), userNames),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE1E5E9)),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Selector (Right side)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.list_alt,
                              size: 16, color: Color(0xFF8B5CF6)),
                          const SizedBox(width: 8),
                          const Text(
                            'اختر القائمة:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 250,
                            height: 30,
                            child: DropdownButtonFormField<int>(
                              value: _selectedResponsesChecklistId,
                              onChanged: (value) {
                                setState(() {
                                  _selectedResponsesChecklistId = value;
                                });
                              },
                              decoration: const InputDecoration(
                                filled: true,
                                fillColor: Color(0xFFF8F9FA),
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 8),
                                isDense: true,
                                border: OutlineInputBorder(
                                    borderSide: BorderSide.none),
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2C3E50),
                              ),
                              items: _selectedReportGroup!.checklists
                                  .map((checklist) {
                                final responseCount = _responses
                                    .where((r) => r.checklistId == checklist.id)
                                    .length;
                                return DropdownMenuItem<int>(
                                  value: checklist.id,
                                  child: Text(
                                    '${checklist.title} ($responseCount استجابة)',
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),

                      // Statistics (Left side) - FIXED to apply all filters correctly
                      if (selectedChecklist != null)
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Builder(
                              builder: (context) {
                                final checklistResponses = _responses
                                    .where((r) =>
                                        r.checklistId == selectedChecklist.id)
                                    .toList();

                                final now = DateTime.now();
                                final currentMonthStart =
                                    DateTime(now.year, now.month, 1);
                                final currentMonthEnd = DateTime(
                                    now.year, now.month + 1, 0, 23, 59, 59);
                                final currentYearStart =
                                    DateTime(now.year, 1, 1);
                                final currentYearEnd =
                                    DateTime(now.year, 12, 31, 23, 59, 59);

                                // Apply date filters ONLY for overall responses
                                final dateFilteredResponses =
                                    checklistResponses.where((r) {
                                  if (_fromDate != null && _toDate != null) {
                                    return r.responseDate.isAfter(_fromDate!
                                            .subtract(
                                                const Duration(days: 1))) &&
                                        r.responseDate.isBefore(_toDate!
                                            .add(const Duration(days: 1)));
                                  }
                                  return true;
                                }).toList();
                                final filteredChecklistResponses =
                                    _applyChecklistSpecificFilters(
                                        dateFilteredResponses,
                                        selectedChecklist.id);

                                // Apply ONLY determinant filters to current month/year responses
                                final currentMonthResponses = checklistResponses
                                    .where((r) =>
                                        r.responseDate.isAfter(
                                            currentMonthStart.subtract(
                                                const Duration(days: 1))) &&
                                        r.responseDate.isBefore(currentMonthEnd
                                            .add(const Duration(days: 1))))
                                    .toList();
                                final filteredCurrentMonthResponses =
                                    _applyChecklistSpecificFilters(
                                        currentMonthResponses,
                                        selectedChecklist.id);

                                final currentYearResponses = checklistResponses
                                    .where((r) =>
                                        r.responseDate.isAfter(
                                            currentYearStart.subtract(
                                                const Duration(days: 1))) &&
                                        r.responseDate.isBefore(currentYearEnd
                                            .add(const Duration(days: 1))))
                                    .toList();
                                final filteredCurrentYearResponses =
                                    _applyChecklistSpecificFilters(
                                        currentYearResponses,
                                        selectedChecklist.id);

                                // Calculate statistics with ALL filters applied correctly
                                final checklistStats = {
                                  'overall_percentage':
                                      _calculateChecklistAverage(
                                          filteredChecklistResponses,
                                          selectedChecklist),
                                  'current_month_average':
                                      _calculateChecklistAverage(
                                          filteredCurrentMonthResponses,
                                          selectedChecklist),
                                  'current_year_average':
                                      _calculateChecklistAverage(
                                          filteredCurrentYearResponses,
                                          selectedChecklist),
                                };

                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildResponseStatisticCard(
                                        'الشهر الحالي',
                                        '${(checklistStats['current_month_average'] as double).toStringAsFixed(1)}%',
                                        Icons.calendar_today,
                                        const Color(0xFF10B981),
                                        '${filteredCurrentMonthResponses.length} استجابة',
                                      ),
                                      const SizedBox(width: 12),
                                      _buildResponseStatisticCard(
                                        'السنة الحالية',
                                        '${(checklistStats['current_year_average'] as double).toStringAsFixed(1)}%',
                                        Icons.event,
                                        const Color(0xFF3B82F6),
                                        '${filteredCurrentYearResponses.length} استجابة',
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Add determinant filters for the selected checklist in responses view
                  if (selectedChecklist != null &&
                      selectedChecklist.determinants.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE1E5E9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.filter_list,
                                  size: 16, color: _primaryColor),
                              const SizedBox(width: 6),
                              Text(
                                'فلاتر ${selectedChecklist.title}:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              ...selectedChecklist.determinants
                                  .map((determinant) {
                                final currentFilters =
                                    _checklistDeterminantFilters[
                                            selectedChecklist.id] ??
                                        {};
                                final isActive =
                                    currentFilters.containsKey(determinant.id);

                                return Container(
                                  width: 140,
                                  height: 28,
                                  child: DropdownButtonFormField<String>(
                                    value: currentFilters[determinant.id],
                                    hint: Text(
                                      determinant.name,
                                      style: const TextStyle(fontSize: 10),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onChanged: (value) {
                                      _updateChecklistFilter(
                                          selectedChecklist.id,
                                          determinant.id,
                                          value);
                                    },
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: isActive
                                          ? _primaryColor.withOpacity(0.1)
                                          : _cardBackgroundColor,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(
                                          color: isActive
                                              ? _primaryColor
                                              : _borderColor,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(
                                          color: isActive
                                              ? _primaryColor
                                              : _borderColor,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(
                                            color: _primaryColor, width: 1.5),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 6),
                                      isDense: true,
                                    ),
                                    style: TextStyle(
                                        fontSize: 10, color: _textPrimaryColor),
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: 'الكل',
                                        child: Text('الكل',
                                            style: TextStyle(fontSize: 10)),
                                      ),
                                      ...determinant.options.map((option) {
                                        return DropdownMenuItem<String>(
                                          value: option.value,
                                          child: Text(
                                            option.value,
                                            style:
                                                const TextStyle(fontSize: 10),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                );
                              }),
                              if ((_checklistDeterminantFilters[
                                              selectedChecklist.id]
                                          ?.length ??
                                      0) >
                                  0) ...[
                                Container(
                                  height: 28,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _clearChecklistFilters(
                                        selectedChecklist.id),
                                    icon: const Icon(Icons.clear,
                                        size: 12, color: Colors.red),
                                    label: const Text('مسح الفلاتر',
                                        style: TextStyle(fontSize: 9)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Colors.red.withOpacity(0.1),
                                      foregroundColor: Colors.red,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        side:
                                            const BorderSide(color: Colors.red),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Expanded(
              child: finalFilteredResponses.isEmpty
                  ? _buildNoDataState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(4),
                      itemCount: finalFilteredResponses.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final response = finalFilteredResponses[index];
                        return _buildEnhancedResponseCard(
                            response, userNames, index);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

// New method to show checkpoint images in a dialog
  void _showCheckpointImagesDialog(
      String checkpointTitle, List<QualityCheckpointImage> images) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 500,
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.image, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'صور نقطة الفحص',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              checkpointTitle,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // Images grid
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        final image = images[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                            _showImageDialog(image.imageUrl);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    image.imageUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                          strokeWidth: 2,
                                          color: _primaryColor,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey.shade200,
                                        child: const Center(
                                          child: Icon(Icons.broken_image,
                                              color: Colors.grey),
                                        ),
                                      );
                                    },
                                  ),
                                  // Image number badge
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Footer with count
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline,
                          size: 14, color: _textSecondaryColor),
                      const SizedBox(width: 6),
                      Text(
                        'اضغط على الصورة لعرضها بالحجم الكامل',
                        style: TextStyle(
                          fontSize: 11,
                          color: _textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// Updated Enhanced Response Card - with checkpoint images support
  Widget _buildEnhancedResponseCard(
      QualityResponse response, Map<String, String> userNames, int index) {
    final checklist = _selectedReportGroup!.checklists.firstWhere(
      (c) => c.id == response.checklistId,
      orElse: () => _selectedReportGroup!.checklists.first,
    );
    final maxRating = checklist.rateNumber;

    double totalRating = 0;
    int ratedCheckpoints = 0;

    response.checkPointRatings.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        totalRating += (value['rating'] as int? ?? 0);
      } else if (value is int) {
        totalRating += value;
      }
      ratedCheckpoints++;
    });

    final averageRating =
        ratedCheckpoints > 0 ? totalRating / ratedCheckpoints : 0;
    final overallPercentage =
        maxRating > 0 ? (averageRating / maxRating * 100) : 0.0;

    final isExpanded = _expandedResponseCards[index] ?? false;

    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main card header - clickable but NO RELOAD
            InkWell(
              onTap: () {
                setState(() {
                  _expandedResponseCards[index] = !isExpanded;
                });
              },
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(8),
                    topRight: const Radius.circular(8),
                    bottomLeft:
                        isExpanded ? Radius.zero : const Radius.circular(8),
                    bottomRight:
                        isExpanded ? Radius.zero : const Radius.circular(8),
                  ),
                  border: Border(
                    bottom: isExpanded
                        ? BorderSide(
                            color: _primaryColor.withOpacity(0.2),
                            width: 1,
                          )
                        : BorderSide.none,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'استجابة #${index + 1} - ${checklist.title}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  '${overallPercentage.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  textDirection: ui.TextDirection.ltr,
                                ),
                              ),
                              const SizedBox(width: 8),
                              AnimatedRotation(
                                turns: isExpanded ? 0.5 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                _formatArabicDate(response.responseDate),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.person,
                                  size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  userNames[response.userId] ?? 'غير معروف',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Expandable content
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: isExpanded ? null : 0,
              child: isExpanded
                  ? Column(
                      children: [
                        // Determinants section
                        if (response.determinantValues.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.tune,
                                        size: 14, color: Color(0xFF8B5CF6)),
                                    SizedBox(width: 6),
                                    Text(
                                      'المحددات:',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF374151),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: response.determinantValues.entries
                                      .map((entry) {
                                    final determinant =
                                        checklist.determinants.firstWhere(
                                      (d) => d.id == entry.key,
                                      orElse: () => Determinant(
                                          id: entry.key,
                                          name: 'غير معروف',
                                          options: []),
                                    );

                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFF8B5CF6)
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        '${determinant.name}: ${entry.value}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF8B5CF6),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Checkpoints results table with images
                        Container(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.checklist,
                                      size: 14, color: Color(0xFF10B981)),
                                  SizedBox(width: 6),
                                  Text(
                                    'نتائج نقاط الفحص:',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: const Color(0xFFE5E7EB)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  children: [
                                    // Header row
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 6),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(6),
                                          topRight: Radius.circular(6),
                                        ),
                                      ),
                                      child: const Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              'نقطة الفحص',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF374151),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 40,
                                            child: Text(
                                              'التقييم',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF374151),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 50,
                                            child: Text(
                                              'النسبة',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF374151),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 80,
                                            child: Text(
                                              'وصف التقييم',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF374151),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 60,
                                            child: Text(
                                              'الصور',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF374151),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Checkpoint rows
                                    ...checklist.checkPoints
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final cpIndex = entry.key;
                                      final checkPoint = entry.value;
                                      final ratingData = response
                                          .checkPointRatings[checkPoint.id];

                                      int rating = 0;
                                      String notes = '';
                                      String correctiveAction = '';

                                      if (ratingData is Map<String, dynamic>) {
                                        rating =
                                            ratingData['rating'] as int? ?? 0;
                                        notes =
                                            ratingData['notes'] as String? ??
                                                '';
                                        correctiveAction =
                                            ratingData['corrective_action']
                                                    as String? ??
                                                '';
                                      } else if (ratingData is int) {
                                        rating = ratingData;
                                      }

                                      final percentage = maxRating > 0
                                          ? (rating / maxRating * 100)
                                          : 0.0;
                                      final ratingLabel =
                                          checklist.getRatingLabel(rating);

                                      // Get checkpoint-specific images
                                      final checkpointImages =
                                          response.getImagesForCheckpoint(
                                              checkPoint.id);

                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: cpIndex % 2 == 0
                                              ? Colors.white
                                              : const Color(0xFFFAFBFC),
                                          border: const Border(
                                            bottom: BorderSide(
                                                color: Color(0xFFF1F5F9),
                                                width: 0.5),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    checkPoint.title,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Color(0xFF374151),
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 40,
                                                  child: Text(
                                                    '$rating/$maxRating',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Color(0xFF374151),
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    textDirection:
                                                        ui.TextDirection.ltr,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 50,
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 3,
                                                        vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: _getRatingColor(
                                                              percentage)
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              3),
                                                    ),
                                                    child: Text(
                                                      '${percentage.toStringAsFixed(0)}%',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: _getRatingColor(
                                                            percentage),
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                      textDirection:
                                                          ui.TextDirection.ltr,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 80,
                                                  child: Text(
                                                    ratingLabel,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: _getRatingColor(
                                                          percentage),
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                // Checkpoint images indicator
                                                SizedBox(
                                                  width: 60,
                                                  child: checkpointImages
                                                          .isNotEmpty
                                                      ? GestureDetector(
                                                          onTap: () =>
                                                              _showCheckpointImagesDialog(
                                                                  checkPoint
                                                                      .title,
                                                                  checkpointImages),
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        4,
                                                                    vertical:
                                                                        2),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: const Color(
                                                                      0xFF3B82F6)
                                                                  .withOpacity(
                                                                      0.1),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4),
                                                              border:
                                                                  Border.all(
                                                                color: const Color(
                                                                        0xFF3B82F6)
                                                                    .withOpacity(
                                                                        0.3),
                                                              ),
                                                            ),
                                                            child: Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                const Icon(
                                                                  Icons.image,
                                                                  size: 12,
                                                                  color: Color(
                                                                      0xFF3B82F6),
                                                                ),
                                                                const SizedBox(
                                                                    width: 2),
                                                                Text(
                                                                  '${checkpointImages.length}',
                                                                  style:
                                                                      const TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color: Color(
                                                                        0xFF3B82F6),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        )
                                                      : const Text(
                                                          '-',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Color(
                                                                0xFF9CA3AF),
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                ),
                                              ],
                                            ),
                                            // Notes
                                            if (notes.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF3B82F6)
                                                      .withOpacity(0.05),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color:
                                                        const Color(0xFF3B82F6)
                                                            .withOpacity(0.2),
                                                  ),
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Icon(Icons.note,
                                                        size: 10,
                                                        color:
                                                            Color(0xFF3B82F6)),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        notes,
                                                        style: const TextStyle(
                                                          fontSize: 9,
                                                          color:
                                                              Color(0xFF3B82F6),
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            // Corrective action
                                            if (correctiveAction
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF59E0B)
                                                      .withOpacity(0.05),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color:
                                                        const Color(0xFFF59E0B)
                                                            .withOpacity(0.2),
                                                  ),
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Icon(Icons.build,
                                                        size: 10,
                                                        color:
                                                            Color(0xFFF59E0B)),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        correctiveAction,
                                                        style: const TextStyle(
                                                          fontSize: 9,
                                                          color:
                                                              Color(0xFFF59E0B),
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            // Checkpoint images preview
                                            if (checkpointImages
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              SizedBox(
                                                height: 40,
                                                child: ListView.builder(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  itemCount:
                                                      checkpointImages.length,
                                                  itemBuilder:
                                                      (context, imgIndex) {
                                                    final image =
                                                        checkpointImages[
                                                            imgIndex];
                                                    return Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                              left: 4),
                                                      child: GestureDetector(
                                                        onTap: () =>
                                                            _showImageDialog(
                                                                image.imageUrl),
                                                        child: ClipRRect(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                          child: Image.network(
                                                            image.imageUrl,
                                                            width: 40,
                                                            height: 40,
                                                            fit: BoxFit.cover,
                                                            errorBuilder:
                                                                (context, error,
                                                                    stackTrace) {
                                                              return Container(
                                                                width: 40,
                                                                height: 40,
                                                                color: Colors
                                                                    .grey
                                                                    .shade200,
                                                                child: const Icon(
                                                                    Icons
                                                                        .broken_image,
                                                                    color: Colors
                                                                        .grey,
                                                                    size: 16),
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Legacy general images section
                        if (response.images.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(8),
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.image,
                                        size: 14, color: Color(0xFF10B981)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'الصور العامة المرفقة (${response.images.length})',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF374151),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 50,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: response.images.length,
                                    itemBuilder: (context, imageIndex) {
                                      final image = response.images[imageIndex];
                                      return Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        child: GestureDetector(
                                          onTap: () =>
                                              _showImageDialog(image.imageUrl),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            child: Image.network(
                                              image.imageUrl,
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Container(
                                                  width: 50,
                                                  height: 50,
                                                  color: Colors.grey.shade200,
                                                  child: const Icon(
                                                      Icons.broken_image,
                                                      color: Colors.grey,
                                                      size: 16),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ));
  }

// Build no filter results state
  Widget _buildNoFilterResultsState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.filter_alt_off,
                size: 32,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد نتائج تطابق الفلاتر المحددة',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'الفلاتر النشطة: ${_selectedDeterminants.length} • إجمالي الاستجابات: ${_responses.length}',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF546E7A),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _selectedDeterminants.clear());
              },
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('مسح الفلاتر'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// Export single checklist
  Future<void> _exportSingleChecklistToExcel(int checklistId) async {
    setState(() {
      _isExporting = true;
    });

    try {
      final checklist = _selectedReportGroup!.checklists.firstWhere(
        (c) => c.id == checklistId,
      );

      final responses =
          _responses.where((r) => r.checklistId == checklistId).toList();

      final filteredResponses =
          _checklistDeterminantFilters.containsKey(checklistId)
              ? responses.where((response) {
                  final filters = _checklistDeterminantFilters[checklistId]!;
                  return filters.entries.every((filter) {
                    final determinantId = filter.key;
                    final selectedValue = filter.value;
                    final responseValue =
                        response.determinantValues[determinantId];
                    return responseValue != null &&
                        responseValue.toString() == selectedValue;
                  });
                }).toList()
              : responses;

      final xlsio.Workbook workbook = xlsio.Workbook();

      final xlsio.Worksheet averageSheet = workbook.worksheets[0];
      averageSheet.name = 'المتوسطات - ${checklist.title}';
      averageSheet.isRightToLeft = true;

      _createAveragesSheet(
          averageSheet, checklist, filteredResponses, workbook);

      final xlsio.Worksheet responsesSheet = workbook.worksheets.add();
      responsesSheet.name = 'الاستجابات - ${checklist.title}';
      responsesSheet.isRightToLeft = true;

      await _createResponsesSheet(
          responsesSheet, checklist, filteredResponses, workbook);

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();
      _downloadExcelFile(bytes,
          'تقرير_${checklist.title}_${DateTime.now().millisecondsSinceEpoch}.xlsx');

      Helpers.showSnackBar(context, 'تم تصدير تقرير ${checklist.title} بنجاح');
    } catch (e) {
      Helpers.showSnackBar(context, 'فشل في تصدير البيانات: ${e.toString()}',
          isError: true);
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

// Export all checklists
  Future<void> _exportAllChecklistsToExcel() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final xlsio.Workbook workbook = xlsio.Workbook();

      final xlsio.Worksheet combinedAveragesSheet = workbook.worksheets[0];
      combinedAveragesSheet.name = 'المتوسطات - الجميع';
      combinedAveragesSheet.isRightToLeft = true;

      await _createCombinedAveragesSheet(combinedAveragesSheet, workbook);

      for (int i = 0; i < _selectedReportGroup!.checklists.length; i++) {
        final checklist = _selectedReportGroup!.checklists[i];
        final responses =
            _responses.where((r) => r.checklistId == checklist.id).toList();

        final filteredResponses =
            _checklistDeterminantFilters.containsKey(checklist.id)
                ? responses.where((response) {
                    final filters = _checklistDeterminantFilters[checklist.id]!;
                    return filters.entries.every((filter) {
                      final determinantId = filter.key;
                      final selectedValue = filter.value;
                      final responseValue =
                          response.determinantValues[determinantId];
                      return responseValue != null &&
                          responseValue.toString() == selectedValue;
                    });
                  }).toList()
                : responses;

        if (filteredResponses.isNotEmpty) {
          final xlsio.Worksheet responsesSheet = workbook.worksheets.add();
          responsesSheet.name = checklist.title.length > 25
              ? '${checklist.title.substring(0, 22)}...'
              : checklist.title;
          responsesSheet.isRightToLeft = true;

          await _createResponsesSheet(
              responsesSheet, checklist, filteredResponses, workbook);
        }
      }

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      _downloadExcelFile(bytes,
          'تقرير_${_selectedReportGroup!.title}_شامل_${DateTime.now().millisecondsSinceEpoch}.xlsx');

      Helpers.showSnackBar(context, 'تم تصدير التقرير الشامل بنجاح');
    } catch (e) {
      Helpers.showSnackBar(context, 'فشل في تصدير البيانات: ${e.toString()}',
          isError: true);
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

// Updated _createAveragesSheet method with improved formatting
  void _createAveragesSheet(xlsio.Worksheet sheet, QualityChecklist checklist,
      List<QualityResponse> responses, xlsio.Workbook workbook) {
    // Statistics in one row - BIG SIZE
    final statisticsData = [
      'المتوسط العام للفترة المحددة',
      'المتوسط العام للشهر الحالي',
      'المتوسط العام للسنة الحالية',
    ];

    final statisticsValues = [
      '${(_additionalStatistics['overall_percentage'] as double).toStringAsFixed(1)}%',
      '${(_additionalStatistics['current_month_average'] as double).toStringAsFixed(1)}%',
      '${(_additionalStatistics['current_year_average'] as double).toStringAsFixed(1)}%',
    ];

    // Statistics headers in row 1
    for (int i = 0; i < statisticsData.length; i++) {
      final headerCell = sheet.getRangeByIndex(1, i + 1);
      headerCell.setText(statisticsData[i]);
      headerCell.cellStyle.bold = true;
      headerCell.cellStyle.fontSize = 12;
      headerCell.cellStyle.backColor = '#8B5CF6';
      headerCell.cellStyle.fontColor = '#FFFFFF';
      headerCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      headerCell.cellStyle.hAlign = xlsio.HAlignType.center;
      headerCell.cellStyle.vAlign = xlsio.VAlignType.center;
      headerCell.cellStyle.wrapText = true;
    }

    // Statistics values in row 2 - BIG SIZE
    for (int i = 0; i < statisticsValues.length; i++) {
      final valueCell = sheet.getRangeByIndex(2, i + 1);
      valueCell.setText(statisticsValues[i]);

      // Extract percentage for color coding
      final percentageStr = statisticsValues[i].replaceAll('%', '');
      final percentage = double.tryParse(percentageStr) ?? 0.0;

      final statsStyle =
          workbook.styles.add('StatsValue${checklist.id}_${i + 1}');
      statsStyle.backColor = _getRatingColorHex(percentage);
      statsStyle.fontColor = _getRatingFontColorHex(percentage);
      statsStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      statsStyle.hAlign = xlsio.HAlignType.center;
      statsStyle.vAlign = xlsio.VAlignType.center;
      statsStyle.bold = true;
      statsStyle.fontSize = 18; // BIG SIZE for percentages
      valueCell.cellStyle = statsStyle;
    }

    // Set row heights for better visibility
    sheet.setRowHeightInPixels(1, 60); // Header row height
    sheet.setRowHeightInPixels(2, 50); // Values row height

    // Add spacing
    int currentRow = 4;

    // Checkpoint analysis header
    final checkpointTitleRange =
        sheet.getRangeByIndex(currentRow, 1, currentRow, 5);
    checkpointTitleRange.merge();
    checkpointTitleRange.setText('تحليل نقاط الفحص');
    checkpointTitleRange.cellStyle.bold = true;
    checkpointTitleRange.cellStyle.fontSize = 14;
    checkpointTitleRange.cellStyle.backColor = '#3B82F6';
    checkpointTitleRange.cellStyle.fontColor = '#FFFFFF';
    checkpointTitleRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    checkpointTitleRange.cellStyle.hAlign = xlsio.HAlignType.center;
    checkpointTitleRange.cellStyle.vAlign = xlsio.VAlignType.center;
    sheet.setRowHeightInPixels(currentRow, 40);
    currentRow++;

    // Checkpoint headers
    final checkpointHeaders = [
      'نقطة الفحص',
      'المتوسط',
      'عدد الاستجابات',
      'النسبة المئوية',
      'الوصف'
    ];
    for (int i = 0; i < checkpointHeaders.length; i++) {
      final headerCell = sheet.getRangeByIndex(currentRow, i + 1);
      headerCell.setText(checkpointHeaders[i]);
      headerCell.cellStyle.bold = true;
      headerCell.cellStyle.backColor = '#F8F9FA';
      headerCell.cellStyle.fontColor = '#2C3E50';
      headerCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      headerCell.cellStyle.hAlign = xlsio.HAlignType.center;
      headerCell.cellStyle.vAlign = xlsio.VAlignType.center;
    }
    sheet.setRowHeightInPixels(currentRow, 35);
    currentRow++;

    final statistics =
        SupabaseService.calculateChecklistStatistics(responses, checklist.id);
    final checkPointStats =
        statistics['check_point_statistics'] as Map<String, dynamic>;

    // Checkpoint data rows
    for (final checkPoint in checklist.checkPoints) {
      final stats =
          checkPointStats[checkPoint.id] as Map<String, dynamic>? ?? {};
      final average = (stats['average'] ?? 0.0) as double;
      final responseCount = stats['total_responses'] ?? 0;
      final maxRating = checklist.rateNumber;
      final percentage = maxRating > 0 ? (average / maxRating * 100) : 0.0;

      // Create row style based on percentage for ALL cells in the row
      final rowStyle =
          workbook.styles.add('CheckpointRow${checklist.id}_$currentRow');
      rowStyle.backColor = _getRatingColorHex(percentage);
      rowStyle.fontColor = _getRatingFontColorHex(percentage);
      rowStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      rowStyle.hAlign = xlsio.HAlignType.center;
      rowStyle.vAlign = xlsio.VAlignType.center;

      // Checkpoint title
      final titleCell = sheet.getRangeByIndex(currentRow, 1);
      titleCell.setText(checkPoint.title);
      final titleStyle =
          workbook.styles.add('CheckpointTitle${checklist.id}_$currentRow');
      titleStyle.backColor = _getRatingColorHex(percentage);
      titleStyle.fontColor = _getRatingFontColorHex(percentage);
      titleStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      titleStyle.hAlign = xlsio.HAlignType.right; // Right align for Arabic text
      titleStyle.vAlign = xlsio.VAlignType.center;
      titleCell.cellStyle = titleStyle;

      // Average rating
      final averageCell = sheet.getRangeByIndex(currentRow, 2);
      averageCell.setText('${average.toStringAsFixed(1)}/$maxRating');
      averageCell.cellStyle = rowStyle;

      // Response count
      final countCell = sheet.getRangeByIndex(currentRow, 3);
      countCell.setNumber(responseCount.toDouble());
      countCell.cellStyle = rowStyle;

      // Percentage - larger font
      final percentageCell = sheet.getRangeByIndex(currentRow, 4);
      percentageCell.setText('${percentage.toStringAsFixed(1)}%');
      final percentageStyle = workbook.styles
          .add('CheckpointPercentage${checklist.id}_$currentRow');
      percentageStyle.backColor = _getRatingColorHex(percentage);
      percentageStyle.fontColor = _getRatingFontColorHex(percentage);
      percentageStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      percentageStyle.hAlign = xlsio.HAlignType.center;
      percentageStyle.vAlign = xlsio.VAlignType.center;
      percentageStyle.bold = true;
      percentageStyle.fontSize = 14; // Larger font for percentages
      percentageCell.cellStyle = percentageStyle;

      // Description
      final descCell = sheet.getRangeByIndex(currentRow, 5);
      descCell.setText(checklist.getRatingLabel(average.round()));
      descCell.cellStyle = rowStyle;

      sheet.setRowHeightInPixels(currentRow, 30);
      currentRow++;
    }

    // Auto-fit all columns based on content
    for (int i = 1; i <= 5; i++) {
      sheet.autoFitColumn(i);
    }

    // Set minimum widths for better appearance
    sheet.setColumnWidthInPixels(1, 200); // Checkpoint title column
    sheet.setColumnWidthInPixels(2, 80); // Average column
    sheet.setColumnWidthInPixels(3, 80); // Count column
    sheet.setColumnWidthInPixels(4, 100); // Percentage column
    sheet.setColumnWidthInPixels(5, 120); // Description column
  }

// Updated _createCombinedAveragesSheet method without overall statistics section
  Future<void> _createCombinedAveragesSheet(
      xlsio.Worksheet sheet, xlsio.Workbook workbook) async {
    int currentRow = 1;
    int styleCounter = 1;

    // Individual checklist statistics (removed overall statistics section)
    for (final checklist in _selectedReportGroup!.checklists) {
      final responses =
          _responses.where((r) => r.checklistId == checklist.id).toList();

      final filteredResponses =
          _checklistDeterminantFilters.containsKey(checklist.id)
              ? responses.where((response) {
                  final filters = _checklistDeterminantFilters[checklist.id]!;
                  return filters.entries.every((filter) {
                    final determinantId = filter.key;
                    final selectedValue = filter.value;
                    final responseValue =
                        response.determinantValues[determinantId];
                    return responseValue != null &&
                        responseValue.toString() == selectedValue;
                  });
                }).toList()
              : responses;

      if (filteredResponses.isEmpty) continue;

      // Checklist title with larger font
      final titleRange = sheet.getRangeByIndex(currentRow, 1, currentRow, 10);
      titleRange.merge();
      titleRange.setText(checklist.title);
      titleRange.cellStyle.bold = true;
      titleRange.cellStyle.fontSize = 16;
      titleRange.cellStyle.backColor = '#8B5CF6';
      titleRange.cellStyle.fontColor = '#FFFFFF';
      titleRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      titleRange.cellStyle.hAlign = xlsio.HAlignType.center;
      titleRange.cellStyle.vAlign = xlsio.VAlignType.center;
      sheet.setRowHeightInPixels(currentRow, 50);
      currentRow++;

      // Calculate checklist-specific statistics
      final now = DateTime.now();
      final currentMonthStart = DateTime(now.year, now.month, 1);
      final currentMonthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      final currentYearStart = DateTime(now.year, 1, 1);
      final currentYearEnd = DateTime(now.year, 12, 31, 23, 59, 59);

      final checklistResponses = responses;
      final dateFilteredResponses = checklistResponses.where((r) {
        if (_fromDate != null && _toDate != null) {
          return r.responseDate
                  .isAfter(_fromDate!.subtract(const Duration(days: 1))) &&
              r.responseDate.isBefore(_toDate!.add(const Duration(days: 1)));
        }
        return true;
      }).toList();

      final filteredChecklistResponses =
          _applyChecklistSpecificFilters(dateFilteredResponses, checklist.id);
      final currentMonthResponses = checklistResponses
          .where((r) =>
              r.responseDate.isAfter(
                  currentMonthStart.subtract(const Duration(days: 1))) &&
              r.responseDate
                  .isBefore(currentMonthEnd.add(const Duration(days: 1))))
          .toList();
      final filteredCurrentMonthResponses =
          _applyChecklistSpecificFilters(currentMonthResponses, checklist.id);
      final currentYearResponses = checklistResponses
          .where((r) =>
              r.responseDate.isAfter(
                  currentYearStart.subtract(const Duration(days: 1))) &&
              r.responseDate
                  .isBefore(currentYearEnd.add(const Duration(days: 1))))
          .toList();
      final filteredCurrentYearResponses =
          _applyChecklistSpecificFilters(currentYearResponses, checklist.id);

      final checklistStats = {
        'overall_percentage':
            _calculateChecklistAverage(filteredChecklistResponses, checklist),
        'current_month_average': _calculateChecklistAverage(
            filteredCurrentMonthResponses, checklist),
        'current_year_average':
            _calculateChecklistAverage(filteredCurrentYearResponses, checklist),
      };

      // Statistics in one row - headers
      final statsHeaders = [
        'المتوسط العام للفترة المحددة',
        'المتوسط العام للشهر الحالي',
        'المتوسط العام للسنة الحالية',
      ];

      for (int i = 0; i < statsHeaders.length; i++) {
        final headerCell = sheet.getRangeByIndex(currentRow, i + 1);
        headerCell.setText(statsHeaders[i]);
        headerCell.cellStyle.bold = true;
        headerCell.cellStyle.fontSize = 11;
        headerCell.cellStyle.backColor = '#F8F9FA';
        headerCell.cellStyle.fontColor = '#2C3E50';
        headerCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        headerCell.cellStyle.hAlign = xlsio.HAlignType.center;
        headerCell.cellStyle.vAlign = xlsio.VAlignType.center;
        headerCell.cellStyle.wrapText = true;
      }
      sheet.setRowHeightInPixels(currentRow, 50);
      currentRow++;

      // Statistics values in one row - BIG SIZE
      final statsValues = [
        '${(checklistStats['overall_percentage'] as double).toStringAsFixed(1)}%',
        '${(checklistStats['current_month_average'] as double).toStringAsFixed(1)}%',
        '${(checklistStats['current_year_average'] as double).toStringAsFixed(1)}%',
      ];

      for (int i = 0; i < statsValues.length; i++) {
        final valueCell = sheet.getRangeByIndex(currentRow, i + 1);
        valueCell.setText(statsValues[i]);

        final percentageStr = statsValues[i].replaceAll('%', '');
        final percentage = double.tryParse(percentageStr) ?? 0.0;

        final statsStyle = workbook.styles
            .add('ChecklistStatsValue${checklist.id}_${i + 1}_$styleCounter');
        statsStyle.backColor = _getRatingColorHex(percentage);
        statsStyle.fontColor = _getRatingFontColorHex(percentage);
        statsStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        statsStyle.hAlign = xlsio.HAlignType.center;
        statsStyle.vAlign = xlsio.VAlignType.center;
        statsStyle.bold = true;
        statsStyle.fontSize = 16; // BIG SIZE
        valueCell.cellStyle = statsStyle;
      }
      sheet.setRowHeightInPixels(currentRow, 45);
      currentRow += 2;

      // Checkpoint headers
      final checkpointHeaders = [
        'نقطة الفحص',
        'المتوسط',
        'عدد الاستجابات',
        'النسبة المئوية',
        'الوصف'
      ];
      for (int i = 0; i < checkpointHeaders.length; i++) {
        final headerCell = sheet.getRangeByIndex(currentRow, i + 1);
        headerCell.setText(checkpointHeaders[i]);
        headerCell.cellStyle.bold = true;
        headerCell.cellStyle.backColor = '#E5E7EB';
        headerCell.cellStyle.fontColor = '#2C3E50';
        headerCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        headerCell.cellStyle.hAlign = xlsio.HAlignType.center;
        headerCell.cellStyle.vAlign = xlsio.VAlignType.center;
      }
      sheet.setRowHeightInPixels(currentRow, 30);
      currentRow++;

      // Checkpoint data
      final statistics = SupabaseService.calculateChecklistStatistics(
          filteredResponses, checklist.id);
      final checkPointStats =
          statistics['check_point_statistics'] as Map<String, dynamic>;

      for (final checkPoint in checklist.checkPoints) {
        final stats =
            checkPointStats[checkPoint.id] as Map<String, dynamic>? ?? {};
        final average = (stats['average'] ?? 0.0) as double;
        final responseCount = stats['total_responses'] ?? 0;
        final maxRating = checklist.rateNumber;
        final percentage = maxRating > 0 ? (average / maxRating * 100) : 0.0;

        // Create row style for all cells
        final rowStyle = workbook.styles.add(
            'CombinedCheckpointRow${checklist.id}_$currentRow$styleCounter');
        rowStyle.backColor = _getRatingColorHex(percentage);
        rowStyle.fontColor = _getRatingFontColorHex(percentage);
        rowStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        rowStyle.hAlign = xlsio.HAlignType.center;
        rowStyle.vAlign = xlsio.VAlignType.center;

        // Checkpoint title - right aligned
        final titleCell = sheet.getRangeByIndex(currentRow, 1);
        titleCell.setText(checkPoint.title);
        final titleStyle = workbook.styles
            .add('CombinedTitle${checklist.id}_$currentRow$styleCounter');
        titleStyle.backColor = _getRatingColorHex(percentage);
        titleStyle.fontColor = _getRatingFontColorHex(percentage);
        titleStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        titleStyle.hAlign = xlsio.HAlignType.right;
        titleStyle.vAlign = xlsio.VAlignType.center;
        titleCell.cellStyle = titleStyle;

        // Average
        final averageCell = sheet.getRangeByIndex(currentRow, 2);
        averageCell.setText('${average.toStringAsFixed(1)}/$maxRating');
        averageCell.cellStyle = rowStyle;

        // Count
        final countCell = sheet.getRangeByIndex(currentRow, 3);
        countCell.setNumber(responseCount.toDouble());
        countCell.cellStyle = rowStyle;

        // Percentage - larger font
        final percentageCell = sheet.getRangeByIndex(currentRow, 4);
        percentageCell.setText('${percentage.toStringAsFixed(1)}%');
        final percentageStyle = workbook.styles
            .add('CombinedPercentage${checklist.id}_$currentRow$styleCounter');
        percentageStyle.backColor = _getRatingColorHex(percentage);
        percentageStyle.fontColor = _getRatingFontColorHex(percentage);
        percentageStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        percentageStyle.hAlign = xlsio.HAlignType.center;
        percentageStyle.vAlign = xlsio.VAlignType.center;
        percentageStyle.bold = true;
        percentageStyle.fontSize = 13; // Larger font
        percentageCell.cellStyle = percentageStyle;

        // Description
        final descCell = sheet.getRangeByIndex(currentRow, 5);
        descCell.setText(checklist.getRatingLabel(average.round()));
        descCell.cellStyle = rowStyle;

        sheet.setRowHeightInPixels(currentRow, 25);
        currentRow++;
        styleCounter++;
      }

      currentRow += 3; // Add space between checklists
    }

    // Auto-fit all columns
    for (int i = 1; i <= 10; i++) {
      sheet.autoFitColumn(i);
    }

    // Set minimum column widths
    sheet.setColumnWidthInPixels(1, 200); // Checkpoint title
    sheet.setColumnWidthInPixels(2, 80); // Average
    sheet.setColumnWidthInPixels(3, 80); // Count
    sheet.setColumnWidthInPixels(4, 100); // Percentage
    sheet.setColumnWidthInPixels(5, 120); // Description
  }

// Updated _createResponsesSheet method - with checkpoint images support
  Future<void> _createResponsesSheet(
      xlsio.Worksheet sheet,
      QualityChecklist checklist,
      List<QualityResponse> responses,
      xlsio.Workbook workbook) async {
    // Find maximum number of images per checkpoint across all responses
    Map<String, int> maxImagesPerCheckpoint = {};
    for (final checkPoint in checklist.checkPoints) {
      maxImagesPerCheckpoint[checkPoint.id] = 0;
    }

    for (final response in responses) {
      for (final checkPoint in checklist.checkPoints) {
        final checkpointImages = response.getImagesForCheckpoint(checkPoint.id);
        if (checkpointImages.length > maxImagesPerCheckpoint[checkPoint.id]!) {
          maxImagesPerCheckpoint[checkPoint.id] = checkpointImages.length;
        }
      }
    }

    // Find maximum number of general images across all responses
    int maxGeneralImages = 0;
    for (final response in responses) {
      if (response.images.length > maxGeneralImages) {
        maxGeneralImages = response.images.length;
      }
    }

    // Build headers dynamically
    final List<String> headers = [
      'التاريخ',
      'المستخدم',
      ...checklist.determinants.map((d) => d.name),
    ];

    // Add checkpoint columns with their image columns
    for (final checkPoint in checklist.checkPoints) {
      headers.add(checkPoint.title);
      final maxImages = maxImagesPerCheckpoint[checkPoint.id] ?? 0;
      for (int i = 0; i < maxImages; i++) {
        headers.add('صورة ${checkPoint.title} ${i + 1}');
      }
    }

    // Add general images columns
    for (int i = 0; i < maxGeneralImages; i++) {
      headers.add('صورة عامة ${i + 1}');
    }

    // Create headers with proper formatting
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#F8F9FA';
      cell.cellStyle.fontColor = '#2C3E50';
      cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      cell.cellStyle.hAlign = xlsio.HAlignType.center;
      cell.cellStyle.vAlign = xlsio.VAlignType.center;
      cell.cellStyle.wrapText = true;
    }

    final Map<String, String> userNames = {};
    await _loadUserNames(responses.map((r) => r.userId).toSet(), userNames);

    int rowIndex = 2;
    int ratingStyleCounter = 1;

    for (final response in responses) {
      int currentCol = 1;

      // Date - center aligned
      final dateCell = sheet.getRangeByIndex(rowIndex, currentCol++);
      dateCell.setText(_formatArabicDate(response.responseDate));
      dateCell.cellStyle.hAlign = xlsio.HAlignType.center;
      dateCell.cellStyle.vAlign = xlsio.VAlignType.center;
      dateCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;

      // User - center aligned
      final userCell = sheet.getRangeByIndex(rowIndex, currentCol++);
      userCell.setText(userNames[response.userId] ?? 'غير معروف');
      userCell.cellStyle.hAlign = xlsio.HAlignType.center;
      userCell.cellStyle.vAlign = xlsio.VAlignType.center;
      userCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;

      // Determinants - center aligned
      for (final determinant in checklist.determinants) {
        final value = response.determinantValues[determinant.id] ?? 'غير محدد';
        final detCell = sheet.getRangeByIndex(rowIndex, currentCol++);
        detCell.setText(value.toString());
        detCell.cellStyle.hAlign = xlsio.HAlignType.center;
        detCell.cellStyle.vAlign = xlsio.VAlignType.center;
        detCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      }

      // Checkpoint ratings with notes, corrective actions, and images
      for (final checkPoint in checklist.checkPoints) {
        final ratingData = response.checkPointRatings[checkPoint.id];
        int rating = 0;
        String notes = '';
        String correctiveAction = '';

        if (ratingData is Map<String, dynamic>) {
          rating = ratingData['rating'] as int? ?? 0;
          notes = ratingData['notes'] as String? ?? '';
          correctiveAction = ratingData['corrective_action'] as String? ?? '';
        } else if (ratingData is int) {
          rating = ratingData;
        }

        final maxRating = checklist.rateNumber;
        final percentage = maxRating > 0 ? (rating / maxRating * 100) : 0.0;
        final ratingLabel = checklist.getRatingLabel(rating);

        // Combine rating, notes, and corrective actions in one cell
        String cellText = '$rating/$maxRating';
        if (ratingLabel.isNotEmpty) {
          cellText += ' ($ratingLabel)';
        }

        // Add notes if available
        if (notes.isNotEmpty) {
          cellText += '\n📝 ملاحظات: $notes';
        }

        // Add corrective actions if available
        if (correctiveAction.isNotEmpty) {
          cellText += '\n🔧 إجراء تصحيحي: $correctiveAction';
        }

        final cell = sheet.getRangeByIndex(rowIndex, currentCol++);
        cell.setText(cellText);
        cell.cellStyle.wrapText = true;

        // Apply style with larger font for ratings
        final cellStyle = workbook.styles
            .add('ResponseRating${checklist.id}_$ratingStyleCounter');
        cellStyle.backColor = _getRatingColorHex(percentage);
        cellStyle.fontColor = _getRatingFontColorHex(percentage);
        cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        cellStyle.hAlign = xlsio.HAlignType.center;
        cellStyle.vAlign = xlsio.VAlignType.top;
        cellStyle.bold = true;
        cellStyle.fontSize = 12;
        cellStyle.wrapText = true;
        cell.cellStyle = cellStyle;

        ratingStyleCounter++;

        // Add checkpoint-specific images
        final checkpointImages = response.getImagesForCheckpoint(checkPoint.id);
        final maxImages = maxImagesPerCheckpoint[checkPoint.id] ?? 0;

        for (int imageIndex = 0; imageIndex < maxImages; imageIndex++) {
          final imageCell = sheet.getRangeByIndex(rowIndex, currentCol++);

          if (imageIndex < checkpointImages.length) {
            // Show "صورة X" as display text
            imageCell.setText('صورة ${imageIndex + 1}');
            imageCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
            imageCell.cellStyle.hAlign = xlsio.HAlignType.center;
            imageCell.cellStyle.vAlign = xlsio.VAlignType.center;
            imageCell.cellStyle.wrapText = true;
            imageCell.cellStyle.fontSize = 11;

            // Add hyperlink to this specific image
            try {
              sheet.hyperlinks.add(
                  imageCell,
                  xlsio.HyperlinkType.url,
                  checkpointImages[imageIndex].imageUrl,
                  'انقر لعرض صورة ${checkPoint.title} ${imageIndex + 1}');
              imageCell.cellStyle.fontColor = '#0066CC';
              imageCell.cellStyle.underline = true;
            } catch (e) {
              // Continue without hyperlink if it fails
            }
          } else {
            // Empty cell for responses with fewer images than max
            imageCell.setText('');
            imageCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
            imageCell.cellStyle.hAlign = xlsio.HAlignType.center;
            imageCell.cellStyle.vAlign = xlsio.VAlignType.center;
          }
        }
      }

      // Add general images
      final generalImageUrls =
          response.images.map((img) => img.imageUrl).toList();
      for (int imageIndex = 0; imageIndex < maxGeneralImages; imageIndex++) {
        final imageCell = sheet.getRangeByIndex(rowIndex, currentCol++);

        if (imageIndex < generalImageUrls.length) {
          imageCell.setText('صورة ${imageIndex + 1}');
          imageCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
          imageCell.cellStyle.hAlign = xlsio.HAlignType.center;
          imageCell.cellStyle.vAlign = xlsio.VAlignType.center;
          imageCell.cellStyle.wrapText = true;
          imageCell.cellStyle.fontSize = 11;

          // Add hyperlink
          try {
            sheet.hyperlinks.add(
                imageCell,
                xlsio.HyperlinkType.url,
                generalImageUrls[imageIndex],
                'انقر لعرض الصورة العامة ${imageIndex + 1}');
            imageCell.cellStyle.fontColor = '#0066CC';
            imageCell.cellStyle.underline = true;
          } catch (e) {
            // Continue without hyperlink if it fails
          }
        } else {
          imageCell.setText('');
          imageCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
          imageCell.cellStyle.hAlign = xlsio.HAlignType.center;
          imageCell.cellStyle.vAlign = xlsio.VAlignType.center;
        }
      }

      rowIndex++;
    }

    // Auto-fit all columns based on content
    for (int i = 1; i <= headers.length; i++) {
      sheet.autoFitColumn(i);
    }

    // Set specific minimum and maximum widths for better appearance
    sheet.setColumnWidthInPixels(1, 100); // Date column
    sheet.setColumnWidthInPixels(2, 120); // User column

    // Set checkpoint columns width
    int colIndex = 3 + checklist.determinants.length;
    for (final checkPoint in checklist.checkPoints) {
      // Rating column
      sheet.autoFitColumn(colIndex);
      final currentWidth = sheet.getColumnWidthInPixels(colIndex);
      if (currentWidth < 150) {
        sheet.setColumnWidthInPixels(colIndex, 150);
      } else if (currentWidth > 300) {
        sheet.setColumnWidthInPixels(colIndex, 300);
      }
      colIndex++;

      // Image columns for this checkpoint
      final maxImages = maxImagesPerCheckpoint[checkPoint.id] ?? 0;
      for (int i = 0; i < maxImages; i++) {
        sheet.setColumnWidthInPixels(colIndex, 100);
        colIndex++;
      }
    }

    // Set general image columns width
    for (int i = 0; i < maxGeneralImages; i++) {
      sheet.setColumnWidthInPixels(colIndex, 100);
      colIndex++;
    }

    // Auto-fit row heights
    for (int row = 1; row <= rowIndex - 1; row++) {
      sheet.autoFitRow(row);
      final currentHeight = sheet.getRowHeight(row);

      if (row == 1) {
        // Header row
        if (currentHeight < 40) {
          sheet.setRowHeightInPixels(row, 40);
        }
      } else {
        // Data rows
        if (currentHeight < 30) {
          sheet.setRowHeightInPixels(row, 30);
        } else if (currentHeight > 100) {
          sheet.setRowHeightInPixels(row, 100);
        }
      }
    }
  }

// Excel image handling WITH hyperlinks (but with Excel's one-hyperlink-per-cell limitation)
  Future<void> _handleImagesInExcelCell(
      xlsio.Range imageCell,
      List<String> imageUrls,
      xlsio.Worksheet sheet,
      xlsio.Workbook workbook,
      int rowIndex) async {
    if (imageUrls.isEmpty) return;

    try {
      if (imageUrls.length == 1) {
        // Single image - simple case
        imageCell.setText('الصورة 1');
        imageCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        imageCell.cellStyle.hAlign = xlsio.HAlignType.center;
        imageCell.cellStyle.vAlign = xlsio.VAlignType.center;
        imageCell.cellStyle.fontSize = 11;
        imageCell.cellStyle.wrapText = true;

        // Add hyperlink to the single image
        try {
          final hyperlink = sheet.hyperlinks.add(imageCell,
              xlsio.HyperlinkType.url, imageUrls.first, 'انقر لعرض الصورة');
          imageCell.cellStyle.fontColor = '#0066CC';
          imageCell.cellStyle.underline = true;
        } catch (e) {
          // Continue without hyperlink if it fails
        }
      } else {
        // Multiple images - show all numbers but hyperlink goes to first image
        String cellText = '';
        for (int i = 0; i < imageUrls.length; i++) {
          if (i > 0) cellText += '\n';
          cellText += 'الصورة ${i + 1}';
        }

        imageCell.setText(cellText);
        imageCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        imageCell.cellStyle.hAlign = xlsio.HAlignType.center;
        imageCell.cellStyle.vAlign = xlsio.VAlignType.center;
        imageCell.cellStyle.fontSize = 11;
        imageCell.cellStyle.wrapText = true;

        // Add hyperlink to first image with note about multiple images
        try {
          final hyperlink = sheet.hyperlinks.add(
              imageCell,
              xlsio.HyperlinkType.url,
              imageUrls.first,
              'انقر لعرض الصورة الأولى من ${imageUrls.length} صور');
          imageCell.cellStyle.fontColor = '#0066CC';
          imageCell.cellStyle.underline = true;
        } catch (e) {
          // Continue without hyperlink if it fails
        }
      }
    } catch (e) {
      // Fallback to simple text with no hyperlink
      imageCell.setText('${imageUrls.length} صورة');
      imageCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      imageCell.cellStyle.hAlign = xlsio.HAlignType.center;
      imageCell.cellStyle.vAlign = xlsio.VAlignType.center;
    }
  }

// BETTER SOLUTION: Use separate columns approach when you want all hyperlinks to work
  Future<void> _createResponsesSheetWithIndividualImageHyperlinks(
      xlsio.Worksheet sheet,
      QualityChecklist checklist,
      List<QualityResponse> responses,
      xlsio.Workbook workbook) async {
    // Find maximum number of images across all responses
    int maxImages = 0;
    for (final response in responses) {
      if (response.images.length > maxImages) {
        maxImages = response.images.length;
      }
    }

    // Create headers including separate image columns
    final List<String> headers = [
      'التاريخ',
      'المستخدم',
      ...checklist.determinants.map((d) => d.name),
      ...checklist.checkPoints.map((cp) => cp.title),
      // Add separate columns for each image - each gets its own hyperlink
      ...List.generate(maxImages, (index) => 'الصورة ${index + 1}'),
    ];

    // Create headers with proper formatting
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#F8F9FA';
      cell.cellStyle.fontColor = '#2C3E50';
      cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      cell.cellStyle.hAlign = xlsio.HAlignType.center;
      cell.cellStyle.vAlign = xlsio.VAlignType.center;
      cell.cellStyle.wrapText = true;
    }

    final Map<String, String> userNames = {};
    await _loadUserNames(responses.map((r) => r.userId).toSet(), userNames);

    int rowIndex = 2;
    int ratingStyleCounter = 1;

    for (final response in responses) {
      int currentCol = 1;

      // Date - center aligned
      final dateCell = sheet.getRangeByIndex(rowIndex, currentCol++);
      dateCell.setText(_formatArabicDate(response.responseDate));
      dateCell.cellStyle.hAlign = xlsio.HAlignType.center;
      dateCell.cellStyle.vAlign = xlsio.VAlignType.center;
      dateCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;

      // User - center aligned
      final userCell = sheet.getRangeByIndex(rowIndex, currentCol++);
      userCell.setText(userNames[response.userId] ?? 'غير معروف');
      userCell.cellStyle.hAlign = xlsio.HAlignType.center;
      userCell.cellStyle.vAlign = xlsio.VAlignType.center;
      userCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;

      // Determinants - center aligned
      for (final determinant in checklist.determinants) {
        final value = response.determinantValues[determinant.id] ?? 'غير محدد';
        final detCell = sheet.getRangeByIndex(rowIndex, currentCol++);
        detCell.setText(value.toString());
        detCell.cellStyle.hAlign = xlsio.HAlignType.center;
        detCell.cellStyle.vAlign = xlsio.VAlignType.center;
        detCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      }

      // Checkpoint ratings with notes and corrective actions combined
      for (final checkPoint in checklist.checkPoints) {
        final ratingData = response.checkPointRatings[checkPoint.id];
        int rating = 0;
        String notes = '';
        String correctiveAction = '';

        if (ratingData is Map<String, dynamic>) {
          rating = ratingData['rating'] as int? ?? 0;
          notes = ratingData['notes'] as String? ?? '';
          correctiveAction = ratingData['corrective_action'] as String? ?? '';
        } else if (ratingData is int) {
          rating = ratingData;
        }

        final maxRating = checklist.rateNumber;
        final percentage = maxRating > 0 ? (rating / maxRating * 100) : 0.0;
        final ratingLabel = checklist.getRatingLabel(rating);

        // Combine rating, notes, and corrective actions in one cell
        String cellText = '$rating/$maxRating';
        if (ratingLabel.isNotEmpty) {
          cellText += ' ($ratingLabel)';
        }

        // Add notes if available
        if (notes.isNotEmpty) {
          cellText += '\n📝 ملاحظات: $notes';
        }

        // Add corrective actions if available
        if (correctiveAction.isNotEmpty) {
          cellText += '\n🔧 إجراء تصحيحي: $correctiveAction';
        }

        final cell = sheet.getRangeByIndex(rowIndex, currentCol++);
        cell.setText(cellText);
        cell.cellStyle.wrapText = true;

        // Apply style with larger font for ratings
        final cellStyle = workbook.styles
            .add('ResponseRating${checklist.id}_$ratingStyleCounter');
        cellStyle.backColor = _getRatingColorHex(percentage);
        cellStyle.fontColor = _getRatingFontColorHex(percentage);
        cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        cellStyle.hAlign = xlsio.HAlignType.center;
        cellStyle.vAlign = xlsio.VAlignType.top;
        cellStyle.bold = true;
        cellStyle.fontSize = 12;
        cellStyle.wrapText = true;
        cell.cellStyle = cellStyle;

        ratingStyleCounter++;
      }

      // Add each image URL in separate columns - EACH GETS ITS OWN WORKING HYPERLINK
      final imageUrls = response.images.map((img) => img.imageUrl).toList();
      for (int imageIndex = 0; imageIndex < maxImages; imageIndex++) {
        final imageCell = sheet.getRangeByIndex(rowIndex, currentCol++);

        if (imageIndex < imageUrls.length) {
          // Show "الصورة X" as display text
          imageCell.setText('الصورة ${imageIndex + 1}');
          imageCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
          imageCell.cellStyle.hAlign = xlsio.HAlignType.center;
          imageCell.cellStyle.vAlign = xlsio.VAlignType.center;
          imageCell.cellStyle.wrapText = true;
          imageCell.cellStyle.fontSize = 11;

          // Add hyperlink to this specific image - THIS WILL WORK!
          try {
            final hyperlink = sheet.hyperlinks.add(
                imageCell,
                xlsio.HyperlinkType.url,
                imageUrls[imageIndex],
                'انقر لعرض الصورة ${imageIndex + 1}');
            imageCell.cellStyle.fontColor = '#0066CC';
            imageCell.cellStyle.underline = true;
          } catch (e) {
            // Continue without hyperlink if it fails
          }
        } else {
          // Empty cell for responses with fewer images
          imageCell.setText('');
          imageCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
          imageCell.cellStyle.hAlign = xlsio.HAlignType.center;
          imageCell.cellStyle.vAlign = xlsio.VAlignType.center;
        }
      }

      rowIndex++;
    }

    // Auto-fit all columns based on content
    for (int i = 1; i <= headers.length; i++) {
      sheet.autoFitColumn(i);
    }

    // Set specific minimum and maximum widths for better appearance
    sheet.setColumnWidthInPixels(1, 100); // Date column
    sheet.setColumnWidthInPixels(2, 120); // User column

    // Set checkpoint columns width
    final checkpointStartCol = 3 + checklist.determinants.length;
    final checkpointEndCol =
        checkpointStartCol + checklist.checkPoints.length - 1;

    for (int i = checkpointStartCol; i <= checkpointEndCol; i++) {
      sheet.autoFitColumn(i);
      final currentWidth = sheet.getColumnWidthInPixels(i);

      if (currentWidth < 150) {
        sheet.setColumnWidthInPixels(i, 150);
      } else if (currentWidth > 300) {
        sheet.setColumnWidthInPixels(i, 300);
      }
    }

    // Set image columns width - each column gets proper width for "الصورة X"
    final imageStartCol = checkpointEndCol + 1;
    for (int i = imageStartCol; i <= headers.length; i++) {
      sheet.setColumnWidthInPixels(i, 100); // Perfect width for "الصورة X"
    }

    // Auto-fit row heights
    for (int row = 1; row <= rowIndex - 1; row++) {
      sheet.autoFitRow(row);
      final currentHeight = sheet.getRowHeight(row);

      if (row == 1) {
        // Header row
        if (currentHeight < 40) {
          sheet.setRowHeightInPixels(row, 40);
        }
      } else {
        // Data rows
        if (currentHeight < 30) {
          sheet.setRowHeightInPixels(row, 30);
        } else if (currentHeight > 100) {
          sheet.setRowHeightInPixels(row, 100);
        }
      }
    }
  }

// Updated _tryEmbedSingleImage method with proper error handling
  Future<void> _tryEmbedSingleImage(xlsio.Range imageCell, String imageUrl,
      xlsio.Worksheet sheet, xlsio.Workbook workbook, int rowIndex) async {
    try {
      // For web images, we'll create a visual representation with a hyperlink
      final shortUrl = _createShortUrl(imageUrl);
      imageCell.setText('🖼️ الصورة 1\n$shortUrl');
      imageCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      imageCell.cellStyle.hAlign = xlsio.HAlignType.center;
      imageCell.cellStyle.vAlign = xlsio.VAlignType.center;
      imageCell.cellStyle.fontSize = 12;
      imageCell.cellStyle.wrapText = true;

      // Add hyperlink
      try {
        final hyperlink = sheet.hyperlinks.add(
            imageCell, xlsio.HyperlinkType.url, imageUrl, 'انقر لعرض الصورة');
        imageCell.cellStyle.fontColor = '#0066CC';
        imageCell.cellStyle.underline = true;
      } catch (e) {
        // Continue without hyperlink if it fails
      }
    } catch (e) {
      // Fallback to text link
      _createImageLinksWithShortcuts(imageCell, [imageUrl]);
    }
  }

// Updated _tryEmbedMultipleImages method with proper numbered naming
  Future<void> _tryEmbedMultipleImages(
      xlsio.Range imageCell,
      List<String> imageUrls,
      xlsio.Worksheet sheet,
      xlsio.Workbook workbook,
      int rowIndex) async {
    try {
      // Create a formatted display for multiple images with numbered names
      String cellText = '';

      for (int i = 0; i < imageUrls.length; i++) {
        if (i > 0) cellText += '\n';
        cellText += 'الصورة ${i + 1}';
      }

      imageCell.setText(cellText);
      imageCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      imageCell.cellStyle.hAlign = xlsio.HAlignType.right;
      imageCell.cellStyle.vAlign = xlsio.VAlignType.top;
      imageCell.cellStyle.fontSize = 11;
      imageCell.cellStyle.wrapText = true;

      // Add hyperlink to the first image
      if (imageUrls.isNotEmpty) {
        try {
          final hyperlink = sheet.hyperlinks.add(
              imageCell,
              xlsio.HyperlinkType.url,
              imageUrls.first,
              'انقر لعرض الصور (${imageUrls.length})');
          imageCell.cellStyle.fontColor = '#0066CC';
          imageCell.cellStyle.underline = true;
        } catch (e) {
          // Continue without hyperlink if it fails
        }
      }
    } catch (e) {
      // Fallback to text links
      _createImageLinksWithShortcuts(imageCell, imageUrls);
    }
  }

// Updated _createImageLinksWithShortcuts method with numbered names
  void _createImageLinksWithShortcuts(
      xlsio.Range imageCell, List<String> imageUrls) {
    if (imageUrls.length == 1) {
      imageCell.setText('الصورة 1');

      // Add hyperlink
      try {
        final hyperlink = imageCell.worksheet.hyperlinks.add(imageCell,
            xlsio.HyperlinkType.url, imageUrls.first, 'انقر لعرض الصورة');
        imageCell.cellStyle.fontColor = '#0066CC';
        imageCell.cellStyle.underline = true;
      } catch (e) {
        // Continue without hyperlink if it fails
      }
    } else {
      // Multiple images with numbered names
      String cellText = '';
      for (int i = 0; i < imageUrls.length; i++) {
        if (i > 0) cellText += '\n';
        cellText += 'الصورة ${i + 1}';
      }

      imageCell.setText(cellText);

      // Add hyperlink to first image
      try {
        final hyperlink = imageCell.worksheet.hyperlinks.add(imageCell,
            xlsio.HyperlinkType.url, imageUrls.first, 'انقر لعرض جميع الصور');
        imageCell.cellStyle.fontColor = '#0066CC';
        imageCell.cellStyle.underline = true;
      } catch (e) {
        // Continue without hyperlink if it fails
      }
    }

    imageCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    imageCell.cellStyle.hAlign = xlsio.HAlignType.right;
    imageCell.cellStyle.vAlign = xlsio.VAlignType.top;
    imageCell.cellStyle.wrapText = true;
    imageCell.cellStyle.fontSize = 11;
  }

// Helper method to create shortened URLs (already exists but making sure it's included)
  String _createShortUrl(String fullUrl) {
    if (fullUrl.length <= 30) return fullUrl;

    try {
      final uri = Uri.parse(fullUrl);
      final fileName =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'صورة';

      // Extract file name or create meaningful short name
      if (fileName.contains('.')) {
        final namePart = fileName.split('.').first;
        final extension = fileName.split('.').last;

        if (namePart.length > 15) {
          return '...${namePart.substring(namePart.length - 12)}.$extension';
        }
        return fileName;
      }

      // For URLs without clear file names
      final domain = uri.host.isNotEmpty ? uri.host : 'رابط';
      return '$domain/...${fullUrl.substring(fullUrl.length - 15)}';
    } catch (e) {
      // If URL parsing fails, just truncate
      return '...${fullUrl.substring(fullUrl.length - 25)}';
    }
  }

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
        Helpers.showSnackBar(context, 'تم تنزيل الملف: $filename');
      }
    } catch (e) {
      print('Error downloading Excel file: $e');
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'فشل تنزيل الملف: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  Widget _buildDataTables(bool isMobile, bool isTablet) {
    final filteredStats = _filteredStatistics;
    final checkPointStats =
        filteredStats['check_point_statistics'] as Map<String, dynamic>;

    if (checkPointStats.isEmpty || _selectedReportChecklist == null) {
      return _buildNoDataState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEnhancedStatisticsCards(isMobile),
          const SizedBox(height: 24),

          // Main Data Table
          Container(
            decoration: BoxDecoration(
              color: _cardBackgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _borderColor),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                    border: Border(
                      bottom: BorderSide(
                          color: _primaryColor.withOpacity(0.2), width: 2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.checklist, color: _primaryColor, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _selectedDeterminants.isNotEmpty
                            ? 'نتائج نقاط الفحص (مفلترة)'
                            : 'نتائج نقاط الفحص',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // Column Headers
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: _lightPrimaryColor,
                    border: Border(
                      bottom: BorderSide(color: _borderColor, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          'نقطة الفحص',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _textPrimaryColor,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          'التقييم',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                        width: 50,
                        child: Text(
                          'النسبة',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                // Data Rows
                ...(_selectedReportChecklist!.checkPoints
                    .asMap()
                    .entries
                    .map((entry) {
                  final index = entry.key;
                  final checkPoint = entry.value;
                  final stats =
                      checkPointStats[checkPoint.id] as Map<String, dynamic>? ??
                          {};
                  final average = (stats['average'] ?? 0.0) as double;
                  final responseCount = stats['total_responses'] ?? 0;
                  final maxRating = _selectedReportChecklist!.rateNumber;
                  final percentage =
                      maxRating > 0 ? (average / maxRating * 100) : 0.0;

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: index % 2 == 0
                          ? _cardBackgroundColor
                          : _lightPrimaryColor.withOpacity(0.3),
                      border: Border(
                        bottom: BorderSide(
                            color: _borderColor.withOpacity(0.5), width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: _primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: _primaryColor.withOpacity(0.3)),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  checkPoint.title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: _textPrimaryColor,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_selectedDeterminants.isNotEmpty &&
                                  responseCount > 0)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: _primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${average.toStringAsFixed(1)}/$maxRating',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                            textAlign: TextAlign.center,
                            textDirection: ui.TextDirection.ltr,
                          ),
                        ),
                        SizedBox(
                          width: 50,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 3, vertical: 1),
                            decoration: BoxDecoration(
                              color:
                                  _getRatingColor(percentage).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '${percentage.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _getRatingColor(percentage),
                              ),
                              textAlign: TextAlign.center,
                              textDirection: ui.TextDirection.ltr,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleChecklistsDataTables(bool isMobile, bool isTablet) {
    if (_selectedReportGroup == null ||
        _selectedReportGroup!.checklists.isEmpty) {
      return _buildNoDataState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Statistics
          // Individual Checklist Tables with Clear Separators
          ...(_selectedReportGroup!.checklists.asMap().entries.map((entry) {
            final index = entry.key;
            final checklist = entry.value;
            return Column(
              children: [
                _buildChecklistStatisticsTable(checklist, isMobile),
                if (index < _selectedReportGroup!.checklists.length - 1) ...[
                  const SizedBox(height: 16),
                  // Clear separator between checklists
                  Container(
                    width: double.infinity,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _primaryColor.withOpacity(0.1),
                          _primaryColor.withOpacity(0.3),
                          _primaryColor.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            );
          }).toList()),
        ],
      ),
    );
  }

  Widget _buildOverallStatisticsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.dashboard, color: _primaryColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إحصائيات عامة - ${_selectedReportGroup!.title}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'الفترة: ${_formatArabicDate(_fromDate!)} - ${_formatArabicDate(_toDate!)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: _textSecondaryColor,
                      ),
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

// Updated method to properly calculate filtered statistics for individual checklist
  Widget _buildChecklistStatisticsTable(
      QualityChecklist checklist, bool isMobile) {
    final statistics = _checklistStatistics[checklist.id] ?? {};
    final checkPointStats =
        statistics['check_point_statistics'] as Map<String, dynamic>? ?? {};
    final totalResponses = statistics['total_responses'] as int? ?? 0;
    final overallAverage = statistics['overall_average'] as double? ?? 0.0;
    final maxRating = checklist.rateNumber;
    final overallPercentage =
        maxRating > 0 ? (overallAverage / maxRating * 100) : 0.0;

    // Calculate individual statistics for THIS checklist with filters applied
    final checklistResponses =
        _responses.where((r) => r.checklistId == checklist.id).toList();

    // Apply date filters first
    final dateFilteredResponses = checklistResponses.where((r) {
      if (_fromDate != null && _toDate != null) {
        return r.responseDate
                .isAfter(_fromDate!.subtract(const Duration(days: 1))) &&
            r.responseDate.isBefore(_toDate!.add(const Duration(days: 1)));
      }
      return true;
    }).toList();

    final filteredChecklistResponses =
        _applyChecklistSpecificFilters(dateFilteredResponses, checklist.id);

    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final currentMonthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final currentYearStart = DateTime(now.year, 1, 1);
    final currentYearEnd = DateTime(now.year, 12, 31, 23, 59, 59);

    final currentMonthResponses = checklistResponses
        .where((r) =>
            r.responseDate
                .isAfter(currentMonthStart.subtract(const Duration(days: 1))) &&
            r.responseDate
                .isBefore(currentMonthEnd.add(const Duration(days: 1))))
        .toList();
    final filteredCurrentMonthResponses =
        _applyChecklistSpecificFilters(currentMonthResponses, checklist.id);

    final currentYearResponses = checklistResponses
        .where((r) =>
            r.responseDate
                .isAfter(currentYearStart.subtract(const Duration(days: 1))) &&
            r.responseDate
                .isBefore(currentYearEnd.add(const Duration(days: 1))))
        .toList();
    final filteredCurrentYearResponses =
        _applyChecklistSpecificFilters(currentYearResponses, checklist.id);

    // Calculate individual checklist statistics with ALL filters applied
    final checklistStats = {
      'overall_percentage':
          _calculateChecklistAverage(filteredChecklistResponses, checklist),
      'current_month_average':
          _calculateChecklistAverage(filteredCurrentMonthResponses, checklist),
      'current_year_average':
          _calculateChecklistAverage(filteredCurrentYearResponses, checklist),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: _cardBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checklist Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: _primaryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(
                bottom:
                    BorderSide(color: _primaryColor.withOpacity(0.2), width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.checklist,
                    color: _primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checklist.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (checklist.description != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          checklist.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(checklistStats['overall_percentage'] as double).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _primaryColor,
                    ),
                    textDirection: ui.TextDirection.ltr,
                  ),
                ),
              ],
            ),
          ),

          // Individual Checklist Statistics Row - FIXED to use filtered data
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFBFC),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  _buildIndividualStatisticCard(
                    'الشهر الحالي',
                    '${(checklistStats['current_month_average'] as double).toStringAsFixed(1)}%',
                    Icons.calendar_today,
                    const Color(0xFF10B981),
                    '${filteredCurrentMonthResponses.length} استجابة', // FIXED: now shows filtered count
                  ),
                  const SizedBox(width: 12),
                  _buildIndividualStatisticCard(
                    'السنة الحالية',
                    '${(checklistStats['current_year_average'] as double).toStringAsFixed(1)}%',
                    Icons.event,
                    const Color(0xFF3B82F6),
                    '${filteredCurrentYearResponses.length} استجابة', // FIXED: now shows filtered count
                  ),
                ],
              ),
            ),
          ),

          // Filters Section
          if (checklist.determinants.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFBFC),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.filter_list, size: 20, color: _primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'فلاتر ${checklist.title}:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _textPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ...checklist.determinants.map((determinant) {
                        final currentFilters =
                            _checklistDeterminantFilters[checklist.id] ?? {};
                        final isActive =
                            currentFilters.containsKey(determinant.id);

                        return Container(
                          width: 160,
                          height: 30,
                          child: DropdownButtonFormField<String>(
                            value: currentFilters[determinant.id],
                            hint: Text(
                              determinant.name,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            onChanged: (value) {
                              _updateChecklistFilter(
                                  checklist.id, determinant.id, value);
                            },
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: isActive
                                  ? _primaryColor.withOpacity(0.1)
                                  : _cardBackgroundColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color:
                                      isActive ? _primaryColor : _borderColor,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color:
                                      isActive ? _primaryColor : _borderColor,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: _primaryColor, width: 2),
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              isDense: true,
                            ),
                            style: TextStyle(
                                fontSize: 13, color: _textPrimaryColor),
                            items: [
                              const DropdownMenuItem<String>(
                                value: 'الكل',
                                child: Text('الكل',
                                    style: TextStyle(fontSize: 14)),
                              ),
                              ...determinant.options.map((option) {
                                return DropdownMenuItem<String>(
                                  value: option.value,
                                  child: Text(
                                    option.value,
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }),
                      if ((_checklistDeterminantFilters[checklist.id]?.length ??
                              0) >
                          0) ...[
                        Container(
                          height: 25,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _clearChecklistFilters(checklist.id),
                            icon: const Icon(Icons.clear,
                                size: 18, color: Colors.red),
                            label: const Text('مسح الفلاتر',
                                style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.1),
                              foregroundColor: Colors.red,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: Colors.red),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Data Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _lightPrimaryColor,
              border: Border(
                bottom: BorderSide(color: _borderColor, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'نقطة الفحص',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textPrimaryColor,
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    'التقييم',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    'النسبة',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // Data Rows
          ...checklist.checkPoints.asMap().entries.map((entry) {
            final index = entry.key;
            final checkPoint = entry.value;
            final stats =
                checkPointStats[checkPoint.id] as Map<String, dynamic>? ?? {};

            final average = (stats['average'] ?? 0.0) as double;
            final responseCount = stats['total_responses'] ?? 0;
            final percentage =
                maxRating > 0 ? (average / maxRating * 100) : 0.0;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: index % 2 == 0
                    ? _cardBackgroundColor
                    : _lightPrimaryColor.withOpacity(0.3),
                border: Border(
                  bottom: BorderSide(
                      color: _borderColor.withOpacity(0.5), width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _primaryColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            checkPoint.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _textPrimaryColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${average.toStringAsFixed(1)}/$maxRating',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                      textAlign: TextAlign.center,
                      textDirection: ui.TextDirection.ltr,
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: _getRatingColor(percentage).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _getRatingColor(percentage),
                        ),
                        textAlign: TextAlign.center,
                        textDirection: ui.TextDirection.ltr,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

// Fix for the _buildChecklistStatisticsTable in multiple checklists data view
  Widget _buildIndividualStatisticCard(
      String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                textDirection: ui.TextDirection.ltr,
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  color: _textSecondaryColor,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 9,
                  color: _textSecondaryColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: _primaryColor),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _primaryColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: _textSecondaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

// Build active filters row
  Widget _buildActiveFiltersRow() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt, size: 14, color: Color(0xFF3B82F6)),
          const SizedBox(width: 4),
          const Text(
            'الفلاتر المطبقة:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _selectedDeterminants.entries.map((entry) {
                final determinant = _selectedReportChecklist!.determinants
                    .firstWhere((d) => d.id == entry.key);

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF3B82F6).withOpacity(0.3)),
                  ),
                  child: Text(
                    '${determinant.name}: ${entry.value}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _selectedDeterminants.clear());
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF3B82F6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              minimumSize: const Size(0, 24),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.clear, size: 12),
                SizedBox(width: 2),
                Text('مسح', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getAllNotes(QualityResponse response) {
    final notes = <String>[];

    response.checkPointRatings.forEach((checkPointId, ratingData) {
      if (ratingData is Map<String, dynamic>) {
        final note = ratingData['notes'] as String?;
        if (note != null && note.isNotEmpty) {
          final checklist = _selectedReportGroup!.checklists.firstWhere(
            (c) => c.id == response.checklistId,
            orElse: () => _selectedReportGroup!.checklists.first,
          );
          final checkPoint = checklist.checkPoints.firstWhere(
            (cp) => cp.id == checkPointId,
            orElse: () => CheckPoint(id: '', title: 'غير معروف'),
          );
          notes.add('${checkPoint.title}: $note');
        }
      }
    });

    return notes.join('\n');
  }

  String _getAllCorrectiveActions(QualityResponse response) {
    final correctiveActions = <String>[];

    response.checkPointRatings.forEach((checkPointId, ratingData) {
      if (ratingData is Map<String, dynamic>) {
        final correctiveAction = ratingData['corrective_action'] as String?;
        if (correctiveAction != null && correctiveAction.isNotEmpty) {
          final checklist = _selectedReportGroup!.checklists.firstWhere(
            (c) => c.id == response.checklistId,
            orElse: () => _selectedReportGroup!.checklists.first,
          );
          final checkPoint = checklist.checkPoints.firstWhere(
            (cp) => cp.id == checkPointId,
            orElse: () => CheckPoint(id: '', title: 'غير معروف'),
          );
          correctiveActions.add('${checkPoint.title}: $correctiveAction');
        }
      }
    });

    return correctiveActions.join('\n');
  }

  Future<void> _loadUserNames(
      Set<String> userIds, Map<String, String> userNames) async {
    try {
      final users = await SupabaseService.getUsersByIds(userIds.toList());
      userNames.addAll(users);
    } catch (e) {
      print('Error fetching users: $e');
      for (final userId in userIds) {
        userNames[userId] = 'غير معروف';
      }
    }
  }

// Updated image dialog with zoom functionality
  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => _ZoomableImageDialog(imageUrl: imageUrl),
    );
  }

  Widget _buildQuickMetric(
      String label, String value, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: _textSecondaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoDataState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 48, color: Color(0xFF8B5CF6)),
            const SizedBox(height: 16),
            const Text(
              'لا توجد بيانات للفترة المحددة',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50)),
            ),
            const SizedBox(height: 8),
            const Text(
              'جرب تغيير الفترة الزمنية أو إزالة الفلاتر',
              style: TextStyle(fontSize: 14, color: Color(0xFF546E7A)),
            ),
          ],
        ),
      ),
    );
  }

  // Additional methods like _buildMultipleChecklistsDataTables,
  // _buildMultipleChecklistsResponsesTable, _buildDataTables,
  // _buildResponsesTable, export methods etc. are already provided
  // in the previous responses and should be included here.
}

// Export Options Dialog
class _ExportOptionsDialog extends StatelessWidget {
  final QualityChecklistGroup checklistGroup;

  const _ExportOptionsDialog({
    required this.checklistGroup,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.all(10),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.download,
                color: Color(0xFF10B981),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'خيارات التصدير',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
          ],
        ),
        content: Container(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'اختر نوع التقرير الذي تريد تصديره:',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF546E7A),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              // Export all option
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE1E5E9)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.layers,
                        color: Color(0xFF8B5CF6), size: 18),
                  ),
                  title: const Text(
                    'تصدير جميع القوائم',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  subtitle: Text(
                    'تصدير تقرير شامل يحتوي على ${checklistGroup.checklists.length} قوائم مع صفحة منفصلة لكل قائمة',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop('all'),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),

              const Text(
                'أو اختر قائمة محددة:',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              // Individual checklist options
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Column(
                    children: checklistGroup.checklists.map((checklist) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE1E5E9)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.checklist,
                                color: Color(0xFF3B82F6), size: 16),
                          ),
                          title: Text(
                            checklist.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C3E50),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: checklist.description != null
                              ? Text(
                                  checklist.description!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6B7280),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${checklist.checkPoints.length} نقطة',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          onTap: () => Navigator.of(context)
                              .pop(checklist.id.toString()),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'إلغاء',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteConfirmationDialog extends StatelessWidget {
  final QualityChecklistGroup group;

  const _DeleteConfirmationDialog({required this.group});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child:
                  const Icon(Icons.delete_outline, color: Colors.red, size: 18),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'تأكيد الحذف',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C3E50)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل أنت متأكد من حذف مجموعة "${group.title}"؟',
              style: const TextStyle(fontSize: 14, color: Color(0xFF546E7A)),
            ),
            const SizedBox(height: 8),
            Text(
              'تحتوي على ${group.checklists.length} قائمة فحص',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_outlined, color: Colors.red, size: 16),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'سيتم حذف جميع البيانات والاستجابات المرتبطة نهائياً',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء', style: TextStyle(fontSize: 13)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('حذف',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
