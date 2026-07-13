// lib/screens/web/quality_management/quality_averages_screen.dart
import 'package:flutter/material.dart';
import 'package:jala_as/models/quality_models.dart';
import 'package:jala_as/screens/utils/file_utils.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/helpers.dart';
import 'dart:ui' as ui;
import 'quality_colors.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'dart:typed_data';
import 'dart:math' as math;

// ─────────────────────────────────────────────────────────────
//  Arabic Date Helper
// ─────────────────────────────────────────────────────────────
class ArabicDate {
  static const List<String> months = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];
  static String format(DateTime date) =>
      '${date.day} ${months[date.month - 1]} ${date.year}';
}

// ─────────────────────────────────────────────────────────────
//  Design Tokens
// ─────────────────────────────────────────────────────────────
class _DS {
  // KPI card gradients
  static const kpiGradients = [
    [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
    [Color(0xFF10B981), Color(0xFF059669)],
    [Color(0xFFF59E0B), Color(0xFFD97706)],
    [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
    [Color(0xFFEF4444), Color(0xFFDC2626)],
    [Color(0xFF06B6D4), Color(0xFF0891B2)],
  ];

  static List<Color> kpiGradient(int index) =>
      kpiGradients[index % kpiGradients.length];

  static const shadowSm = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x06000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const shadowLg = [
    BoxShadow(color: Color(0x15000000), blurRadius: 20, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 4)),
  ];

  static const bg = Color(0xFFF1F5F9);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const borderLight = Color(0xFFF1F5F9);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);
  static const radius = Radius.circular(10);
  static const radiusSm = Radius.circular(6);
  static const radiusLg = Radius.circular(14);
}

// ─────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────
class QualityAveragesScreen extends StatefulWidget {
  final QualityChecklistGroup group;
  const QualityAveragesScreen({super.key, required this.group});

  @override
  State<QualityAveragesScreen> createState() => _QualityAveragesScreenState();
}

class _QualityAveragesScreenState extends State<QualityAveragesScreen>
    with SingleTickerProviderStateMixin {
  List<QualityResponse> _responses = [];
  bool _isLoading = true;

  String _selectedPeriod = 'current_year';
  DateTime? _fromDate;
  DateTime? _toDate;
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();

  int? _selectedChecklistId;
  Map<int, Map<String, String>> _checklistFilters = {};
  Map<int, Map<String, dynamic>> _checklistStats = {};

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    _selectedChecklistId = widget.group.checklists.isNotEmpty
        ? widget.group.checklists.first.id
        : null;
    _initializeDates();
    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }

  // ── Date logic ─────────────────────────────────────────────

  void _initializeDates() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'current_month':
        _fromDate = DateTime(now.year, now.month, 1);
        _toDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'last_3_months':
        _fromDate = DateTime(now.year, now.month - 2, 1);
        _toDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'current_year':
        _fromDate = DateTime(now.year, 1, 1);
        _toDate = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
      case 'custom_range':
        _fromDate ??= DateTime(now.year, now.month, 1);
        _toDate ??= DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
    }
    _syncControllers();
  }

  void _syncControllers() {
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    _fromDateController.text = fmt(_fromDate!);
    _toDateController.text = fmt(_toDate!);
  }

  // ── Data ───────────────────────────────────────────────────

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _animController.reset();
    try {
      final responses = await SupabaseService.getQualityResponses(
        groupId: widget.group.id,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (!mounted) return;
      // Auto-select the first checklist that actually has responses
      final ids = responses.map((r) => r.checklistId).toSet();
      final withData = widget.group.checklists.where((c) => ids.contains(c.id)).toList();
      final currentValid = withData.any((c) => c.id == _selectedChecklistId);
      setState(() {
        _responses = responses;
        if (!currentValid && withData.isNotEmpty) {
          _selectedChecklistId = withData.first.id;
        }
        _calculateAllStatistics();
        _isLoading = false;
      });
      _animController.forward();
    } catch (e, stackTrace) {
      debugPrint('QualityAveragesScreen._loadData error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() => _isLoading = false);
      Helpers.showSnackBar(
        context,
        'فشل في تحميل البيانات: ${e.toString()}',
        isError: true,
      );
    }
  }

  void _calculateAllStatistics() {
    _checklistStats.clear();
    for (final checklist in widget.group.checklists) {
      final responses =
          _responses.where((r) => r.checklistId == checklist.id).toList();
      final filtered = _applyFilters(responses, checklist.id);
      _checklistStats[checklist.id] =
          _calculateChecklistStats(filtered, checklist);
    }
  }

  List<QualityResponse> _applyFilters(
      List<QualityResponse> responses, int checklistId) {
    final filters = _checklistFilters[checklistId];
    if (filters == null || filters.isEmpty) return responses;
    return responses.where((r) {
      return filters.entries.every((f) {
        final value = r.determinantValues[f.key];
        return value != null && value.toString() == f.value;
      });
    }).toList();
  }

  /// Safely parses a rating value from dynamic JSON (int, double, or num)
  double _parseRating(dynamic raw) {
    if (raw == null) return 0.0;
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0.0;
  }

  Map<String, dynamic> _calculateChecklistStats(
      List<QualityResponse> responses, QualityChecklist checklist) {
    if (responses.isEmpty) {
      return {
        'total_responses': 0,
        'overall_percentage': 0.0,
        'checkpoints': <String, Map<String, dynamic>>{},
      };
    }

    final checkpointStats = <String, Map<String, dynamic>>{};
    double totalPct = 0;
    int totalRatings = 0;

    for (final cp in checklist.checkPoints) {
      double sum = 0;
      int count = 0;
      for (final r in responses) {
        final ratingData = r.checkPointRatings[cp.id];
        double rating = 0;
        if (ratingData is Map<String, dynamic>) {
          rating = _parseRating(ratingData['rating']);
        } else {
          rating = _parseRating(ratingData);
        }
        if (rating > 0) {
          sum += rating;
          count++;
        }
      }
      final average = count > 0 ? sum / count : 0.0;
      final pct = checklist.rateNumber > 0
          ? (average / checklist.rateNumber * 100)
          : 0.0;
      checkpointStats[cp.id] = {
        'average': average,
        'percentage': pct,
        'count': count,
      };
      if (count > 0) {
        totalPct += pct * count;
        totalRatings += count;
      }
    }

    return {
      'total_responses': responses.length,
      'overall_percentage':
          totalRatings > 0 ? totalPct / totalRatings : 0.0,
      'checkpoints': checkpointStats,
    };
  }

  void _updateFilter(int checklistId, String determinantId, String? value) {
    setState(() {
      _checklistFilters[checklistId] ??= {};
      if (value != null && value.isNotEmpty && value != 'الكل') {
        _checklistFilters[checklistId]![determinantId] = value;
      } else {
        _checklistFilters[checklistId]!.remove(determinantId);
      }
      _calculateAllStatistics();
    });
  }

  void _clearFilters(int checklistId) {
    setState(() {
      _checklistFilters.remove(checklistId);
      _calculateAllStatistics();
    });
  }

  void _onPeriodChanged(String? period) {
    if (period == null) return;
    setState(() {
      _selectedPeriod = period;
      _initializeDates();
    });
    if (period != 'custom_range') _loadData();
  }

  Future<void> _pickDate(bool isFromDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? _fromDate! : _toDate!,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: QColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: QColors.textPrimary,
          ),
        ),
        child: Directionality(
            textDirection: ui.TextDirection.rtl, child: child!),
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = DateTime(picked.year, picked.month, picked.day);
          if (_toDate!.isBefore(_fromDate!)) {
            _toDate = DateTime(
                _fromDate!.year, _fromDate!.month, _fromDate!.day, 23, 59, 59);
          }
        } else {
          _toDate =
              DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
          if (_fromDate!.isAfter(_toDate!)) {
            _fromDate = DateTime(
                _toDate!.year, _toDate!.month, _toDate!.day);
          }
        }
        _syncControllers();
      });
      if (_selectedPeriod == 'custom_range') _loadData();
    }
  }

  // ── Derived values ─────────────────────────────────────────

  QualityChecklist? get _selectedChecklist {
    if (_selectedChecklistId == null) return null;
    return widget.group.checklists.firstWhere(
      (c) => c.id == _selectedChecklistId,
      orElse: () => widget.group.checklists.first,
    );
  }

  /// Only checklists that have at least one response in the loaded data.
  List<QualityChecklist> get _checklistsWithResponses {
    final ids = _responses.map((r) => r.checklistId).toSet();
    return widget.group.checklists.where((c) => ids.contains(c.id)).toList();
  }

  List<QualityChecklist> get _checklistsToShow {
    final withData = _checklistsWithResponses;
    if (withData.isEmpty) return [];
    if (widget.group.isMultipleActive) return withData;
    final cl = _selectedChecklist;
    if (cl == null || !withData.any((c) => c.id == cl.id)) return [withData.first];
    return [cl];
  }

  /// Actual determinant values that appear in responses for a checklist.
  Set<String> _actualDeterminantValues(int checklistId, String determinantId) {
    return _responses
        .where((r) => r.checklistId == checklistId)
        .map((r) => r.determinantValues[determinantId]?.toString())
        .whereType<String>()
        .where((v) => v.isNotEmpty)
        .toSet();
  }

  // ── Aggregate KPI data across all visible checklists ───────

  Map<String, dynamic> get _aggregateKPIs {
    final checklists = _checklistsToShow;
    int totalResponses = 0;
    double weightedPct = 0;
    int weightedCount = 0;
    int totalCheckpoints = 0;
    int excellentCheckpoints = 0;
    int poorCheckpoints = 0;

    for (final cl in checklists) {
      final stats = _checklistStats[cl.id] ?? {};
      final tr = (stats['total_responses'] as int?) ?? 0;
      final pct = (stats['overall_percentage'] as double?) ?? 0.0;
      final cpStats =
          (stats['checkpoints'] as Map<String, Map<String, dynamic>>?) ?? {};

      totalResponses += tr;
      if (tr > 0) {
        weightedPct += pct * tr;
        weightedCount += tr;
      }

      for (final cp in cpStats.values) {
        final p = (cp['percentage'] as double?) ?? 0.0;
        totalCheckpoints++;
        if (p >= 80) excellentCheckpoints++;
        if (p < 50) poorCheckpoints++;
      }
    }

    final overallPct = weightedCount > 0 ? weightedPct / weightedCount : 0.0;

    return {
      'total_responses': totalResponses,
      'overall_pct': overallPct,
      'total_checkpoints': totalCheckpoints,
      'excellent_checkpoints': excellentCheckpoints,
      'poor_checkpoints': poorCheckpoints,
      'total_checklists': checklists.length,
    };
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Container(
        color: _DS.bg,
        child: Column(
          children: [
            _buildTopBar(),
            _buildFiltersBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: QColors.primary))
                  : FadeTransition(
                      opacity: _fadeAnim,
                      child: _buildContent(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────

  Widget _buildTopBar() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _DS.surface,
        border: const Border(bottom: BorderSide(color: _DS.border)),
        boxShadow: _DS.shadowSm,
      ),
      child: Row(
        children: [
          // Date pill — compact on mobile
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _DS.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.date_range_rounded,
                      size: 13, color: _DS.textSecondary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      isMobile
                          ? '${ArabicDate.format(_fromDate!)} - ${ArabicDate.format(_toDate!)}'
                          : '${ArabicDate.format(_fromDate!)}  ←  ${ArabicDate.format(_toDate!)}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _DS.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Export button
          _ExportButton(onPressed: _exportData),
        ],
      ),
    );
  }

  // ── Filters bar ───────────────────────────────────────────

  Widget _buildFiltersBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: _DS.surface,
        border: Border(bottom: BorderSide(color: _DS.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _FilterLabel('الفترة:'),
                const SizedBox(width: 6),
                _CompactDropdown<String>(
                  value: _selectedPeriod,
                  width: 140,
                  onChanged: _onPeriodChanged,
                  items: const [
                    DropdownMenuItem(
                        value: 'current_month', child: Text('الشهر الحالي')),
                    DropdownMenuItem(
                        value: 'last_3_months', child: Text('آخر 3 أشهر')),
                    DropdownMenuItem(
                        value: 'current_year', child: Text('السنة الحالية')),
                    DropdownMenuItem(
                        value: 'custom_range', child: Text('فترة مخصصة')),
                  ],
                ),
                if (_selectedPeriod == 'custom_range') ...[
                  const SizedBox(width: 14),
                  _FilterLabel('من:'),
                  const SizedBox(width: 6),
                  _DatePickerField(
                      text: _fromDateController.text,
                      onTap: () => _pickDate(true)),
                  const SizedBox(width: 10),
                  _FilterLabel('إلى:'),
                  const SizedBox(width: 6),
                  _DatePickerField(
                      text: _toDateController.text,
                      onTap: () => _pickDate(false)),
                ],
                if (_checklistsWithResponses.length > 1) ...[
                  const SizedBox(width: 16),
                  _FilterLabel('القائمة:'),
                  const SizedBox(width: 6),
                  _CompactDropdown<int>(
                    value: _selectedChecklistId,
                    width: 200,
                    onChanged: (v) =>
                        setState(() => _selectedChecklistId = v),
                    items: _checklistsWithResponses
                        .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.title,
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Content ────────────────────────────────────────────────

  Widget _buildContent() {
    final toShow = _checklistsToShow;
    if (toShow.isEmpty) {
      return _buildEmptyState();
    }
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        RepaintBoundary(child: _buildKPIRow()),
        const SizedBox(height: 14),
        ...toShow.map((cl) => RepaintBoundary(child: _buildChecklistCard(cl))),
      ],
    );
  }

  // ── KPI Row ────────────────────────────────────────────────

  Widget _buildKPIRow() {
    final kpis = _aggregateKPIs;
    final overallPct = kpis['overall_pct'] as double;
    final perfColor = QColors.getPerformanceColor(overallPct);
    final perfLabel = QColors.getPerformanceLabel(overallPct);

    final kpiData = [
      _KPIData(
        label: 'إجمالي الاستجابات',
        value: '${kpis['total_responses']}',
        icon: Icons.assignment_outlined,
        gradientIndex: 0,
        subtitle: 'خلال الفترة المحددة',
      ),
      _KPIData(
        label: 'المتوسط العام',
        value: '${overallPct.toStringAsFixed(1)}%',
        icon: Icons.analytics_outlined,
        gradientIndex: overallPct >= 80
            ? 1
            : overallPct >= 60
                ? 0
                : overallPct >= 50
                    ? 2
                    : 4,
        subtitle: perfLabel,
        progress: overallPct / 100,
      ),
      _KPIData(
        label: 'نقاط الفحص',
        value: '${kpis['total_checkpoints']}',
        icon: Icons.checklist_rtl_rounded,
        gradientIndex: 3,
        subtitle:
            '${kpis['excellent_checkpoints']} ممتازة / ${kpis['poor_checkpoints']} ضعيفة',
      ),
      _KPIData(
        label: 'نقاط ممتازة ≥80%',
        value: '${kpis['excellent_checkpoints']}',
        icon: Icons.verified_outlined,
        gradientIndex: 1,
        subtitle: kpis['total_checkpoints'] > 0
            ? '${((kpis['excellent_checkpoints'] as int) / (kpis['total_checkpoints'] as int) * 100).toStringAsFixed(0)}% من الإجمالي'
            : '—',
        progress: kpis['total_checkpoints'] > 0
            ? (kpis['excellent_checkpoints'] as int) /
                (kpis['total_checkpoints'] as int)
            : 0.0,
      ),
      _KPIData(
        label: 'نقاط تحتاج تحسين',
        value: '${kpis['poor_checkpoints']}',
        icon: Icons.warning_amber_rounded,
        gradientIndex: 4,
        subtitle: 'أقل من 50%',
      ),
      _KPIData(
        label: 'عدد القوائم',
        value: '${kpis['total_checklists']}',
        icon: Icons.folder_copy_outlined,
        gradientIndex: 5,
        subtitle: 'قائمة فحص نشطة',
      ),
    ];

    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth;
      final cols = w > 900 ? 6 : w > 600 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.65,
        ),
        itemCount: kpiData.length,
        itemBuilder: (_, i) => _KPICard(data: kpiData[i]),
      );
    });
  }

  // ── Checklist card ─────────────────────────────────────────

  Widget _buildChecklistCard(QualityChecklist checklist) {
    final stats = _checklistStats[checklist.id] ?? {};
    final overallPct = (stats['overall_percentage'] as double?) ?? 0.0;
    final totalResponses = (stats['total_responses'] as int?) ?? 0;
    final checkpointStats =
        (stats['checkpoints'] as Map<String, Map<String, dynamic>>?) ?? {};
    final activeFilters = _checklistFilters[checklist.id]?.length ?? 0;
    final perfColor = QColors.getPerformanceColor(overallPct);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _DS.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _DS.border),
        boxShadow: _DS.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card header ──
          _buildCardHeader(
            checklist: checklist,
            overallPct: overallPct,
            totalResponses: totalResponses,
            activeFilters: activeFilters,
            perfColor: perfColor,
          ),

          // ── Stats row ──
          _buildStatsRow(
              checklist, checkpointStats, overallPct, totalResponses),

          // ── Chart + Table layout ──
          LayoutBuilder(builder: (ctx, constraints) {
            // Need 260 (chart) + 1 (divider) + 224 (table min) = 485 for side-by-side
            final wide = constraints.maxWidth >= 500;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bar chart — fixed width
                  SizedBox(
                    width: 260,
                    child: _buildBarChart(checklist, checkpointStats),
                  ),
                  // Vertical divider
                  Container(
                      width: 1,
                      color: _DS.border,
                      margin: const EdgeInsets.symmetric(vertical: 12)),
                  // Table — takes remaining space
                  Expanded(
                    child: _buildCheckpointsTable(checklist, checkpointStats),
                  ),
                ],
              );
            }
            // Narrow: stack bar chart above table
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBarChart(checklist, checkpointStats),
                Container(height: 1, color: _DS.border),
                _buildCheckpointsTable(checklist, checkpointStats),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCardHeader({
    required QualityChecklist checklist,
    required double overallPct,
    required int totalResponses,
    required int activeFilters,
    required Color perfColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(11),
          topRight: Radius.circular(11),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.checklist_rtl_rounded,
                size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  checklist.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.assignment_outlined,
                        size: 11, color: Colors.white54),
                    const SizedBox(width: 3),
                    Text(
                      '$totalResponses استجابة',
                      style: const TextStyle(
                          fontSize: 10.5, color: Colors.white70),
                    ),
                    if (activeFilters > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$activeFilters فلتر نشط',
                          style: const TextStyle(
                              fontSize: 9.5, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Score badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: perfColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                        color: perfColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: Text(
                  '${overallPct.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                QColors.getPerformanceLabel(overallPct),
                style: TextStyle(
                    fontSize: 10.5,
                    color: perfColor,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(width: 10),
          // Filter button
          if (checklist.determinants.isNotEmpty)
            _buildFiltersDropdown(checklist),
        ],
      ),
    );
  }

  Widget _buildStatsRow(
    QualityChecklist checklist,
    Map<String, Map<String, dynamic>> cpStats,
    double overallPct,
    int totalResponses,
  ) {
    int excellent = 0, good = 0, fair = 0, poor = 0;
    for (final s in cpStats.values) {
      final p = (s['percentage'] as double?) ?? 0.0;
      if (p >= 80) excellent++;
      else if (p >= 60) good++;
      else if (p >= 50) fair++;
      else poor++;
    }
    final total = cpStats.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(color: _DS.border),
          bottom: BorderSide(color: _DS.border),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _StatPill(
                  label: 'ممتاز',
                  count: excellent,
                  total: total,
                  color: const Color(0xFF10B981)),
              _StatPill(
                  label: 'جيد',
                  count: good,
                  total: total,
                  color: const Color(0xFF3B82F6)),
              _StatPill(
                  label: 'مقبول',
                  count: fair,
                  total: total,
                  color: const Color(0xFFF59E0B)),
              _StatPill(
                  label: 'ضعيف',
                  count: poor,
                  total: total,
                  color: const Color(0xFFEF4444)),
            ],
          ),
          // Overall mini progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'المتوسط العام',
                style: const TextStyle(fontSize: 10, color: _DS.textMuted),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 140,
                child: _GradientProgressBar(
                    value: overallPct / 100,
                    color: QColors.getPerformanceColor(overallPct)),
              ),
              const SizedBox(height: 2),
              Text(
                '${overallPct.toStringAsFixed(1)}%  ·  $totalResponses استجابة',
                style: const TextStyle(
                    fontSize: 10, color: _DS.textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bar chart (pure Flutter, no external chart lib needed) ──

  Widget _buildBarChart(
    QualityChecklist checklist,
    Map<String, Map<String, dynamic>> cpStats,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'مقارنة نقاط الفحص',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _DS.textPrimary),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 160,
            child: RepaintBoundary(
              child: _CustomBarChart(
                checkpoints: checklist.checkPoints,
                cpStats: cpStats,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Checkpoints table ──────────────────────────────────────

  Widget _buildCheckpointsTable(
    QualityChecklist checklist,
    Map<String, Map<String, dynamic>> stats,
  ) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9),
            border:
                Border(bottom: BorderSide(color: _DS.border)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 22),
              const SizedBox(width: 8),
              const Expanded(
                flex: 4,
                child: Text(
                  'نقطة الفحص',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _DS.textPrimary),
                ),
              ),
              _TH('المتوسط', 70),
              _TH('عدد', 44),
              _TH('النسبة', 80),
            ],
          ),
        ),
        // Rows
        ...checklist.checkPoints.asMap().entries.map((entry) {
          final idx = entry.key;
          final cp = entry.value;
          final s = stats[cp.id] ?? {};
          final avg = (s['average'] as double?) ?? 0.0;
          final pct = (s['percentage'] as double?) ?? 0.0;
          final count = (s['count'] as int?) ?? 0;
          final c = QColors.getPerformanceColor(pct);
          final isEven = idx.isEven;

          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isEven ? Colors.white : const Color(0xFFFAFAFB),
              border: const Border(
                  bottom: BorderSide(color: _DS.borderLight)),
            ),
            child: Row(
              children: [
                // Rank badge
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: QColors.getPerformanceBgColor(pct),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      '${idx + 1}',
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: c),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Title
                Expanded(
                  flex: 4,
                  child: Text(
                    cp.title,
                    style: const TextStyle(
                        fontSize: 11.5, color: _DS.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Average
                SizedBox(
                  width: 70,
                  child: Text(
                    '${avg.toStringAsFixed(1)}/${checklist.rateNumber}',
                    style: const TextStyle(
                        fontSize: 10.5, color: _DS.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Count
                SizedBox(
                  width: 44,
                  child: Text(
                    '$count',
                    style: const TextStyle(
                        fontSize: 10.5, color: _DS.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Percentage pill + mini bar
                SizedBox(
                  width: 80,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: QColors.getPerformanceBgColor(pct),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: c,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 3),
                      _GradientProgressBar(
                          value: pct / 100, color: c, height: 3),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Filters dropdown ───────────────────────────────────────

  Widget _buildFiltersDropdown(QualityChecklist checklist) {
    final activeFilters = _checklistFilters[checklist.id]?.length ?? 0;
    return PopupMenuButton<String>(
      offset: const Offset(0, 38),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: _DS.border),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: activeFilters > 0
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list_rounded,
                size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              activeFilters > 0 ? 'فلاتر ($activeFilters)' : 'فلاتر',
              style: const TextStyle(fontSize: 11, color: Colors.white),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        ...checklist.determinants.map((det) {
          final actualValues =
              _actualDeterminantValues(checklist.id, det.id);
          if (actualValues.isEmpty) return const PopupMenuItem<String>(height: 0, child: SizedBox.shrink());
          return PopupMenuItem<String>(
            enabled: false,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(det.name,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                SizedBox(
                  width: 180,
                  height: 32,
                  child: DropdownButtonFormField<String>(
                    value: _checklistFilters[checklist.id]?[det.id],
                    onChanged: (value) {
                      Navigator.pop(context);
                      _updateFilter(checklist.id, det.id, value);
                    },
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(
                        fontSize: 11, color: _DS.textPrimary),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                          value: 'الكل',
                          child: Text('الكل',
                              overflow: TextOverflow.ellipsis)),
                      // Only options that actually appear in responses
                      ...det.options
                          .where((opt) => actualValues.contains(opt.value))
                          .map((opt) => DropdownMenuItem(
                              value: opt.value,
                              child: Text(opt.value,
                                  overflow: TextOverflow.ellipsis))),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        if (activeFilters > 0)
          PopupMenuItem<String>(
            onTap: () => _clearFilters(checklist.id),
            child: const Row(
              children: [
                Icon(Icons.clear_rounded, size: 14, color: Color(0xFFEF4444)),
                SizedBox(width: 6),
                Text('مسح الفلاتر',
                    style: TextStyle(
                        fontSize: 11, color: Color(0xFFEF4444))),
              ],
            ),
          ),
      ],
    );
  }

  // ── Empty state ────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.inbox_outlined,
                size: 36, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),
          const Text(
            'لا توجد بيانات',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _DS.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'لا توجد استجابات في الفترة المحددة',
            style: TextStyle(fontSize: 12, color: _DS.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Export ─────────────────────────────────────────────────

  Future<void> _exportData() async {
    setState(() => _isLoading = true);
    try {
      final xlsio.Workbook workbook = xlsio.Workbook();
      final xlsio.Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'المتوسطات - الكل';
      sheet.isRightToLeft = true;
      await _createCombinedAveragesSheet(sheet, workbook);
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();
      final fileName =
          'متوسطات_${widget.group.title}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      await _downloadExcelFile(Uint8List.fromList(bytes), fileName);
      if (mounted) Helpers.showSnackBar(context, 'تم تصدير البيانات بنجاح');
    } catch (e) {
      if (mounted)
        Helpers.showSnackBar(context, 'فشل في تصدير البيانات: $e',
            isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Returns filtered responses for a given checklist (applies active determinant filters).
  List<QualityResponse> _getFilteredResponsesForChecklist(int checklistId) {
    final responses = _responses.where((r) => r.checklistId == checklistId).toList();
    return _applyFilters(responses, checklistId);
  }

  /// Collects non-empty notes for [checkPointId] across [responses], numbered.
  String _collectCheckpointNotes(List<QualityResponse> responses, String checkPointId) {
    final notes = <String>[];
    for (final r in responses) {
      final ratingData = r.checkPointRatings[checkPointId];
      if (ratingData is Map<String, dynamic>) {
        final n = (ratingData['notes'] as String?)?.trim();
        if (n != null && n.isNotEmpty) notes.add(n);
      }
    }
    if (notes.isEmpty) return '';
    return notes.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n');
  }

  Future<void> _createCombinedAveragesSheet(
      xlsio.Worksheet sheet, xlsio.Workbook workbook) async {
    // columns: # | نقطة الفحص | المتوسط | عدد التقييمات | النسبة المئوية | التقييم | الملاحظات
    const int totalCols = 7;
    int row = 1;

    // Main title
    final titleRange = sheet.getRangeByIndex(row, 1, row, totalCols)..merge();
    titleRange.setText('متوسطات ${widget.group.title}');
    titleRange.cellStyle
      ..bold = true
      ..fontSize = 18
      ..backColor = '#1E293B'
      ..fontColor = '#FFFFFF'
      ..hAlign = xlsio.HAlignType.center
      ..vAlign = xlsio.VAlignType.center;
    sheet.setRowHeightInPixels(row, 50);
    row += 2;

    // Period
    sheet.getRangeByIndex(row, 1).setText('الفترة:');
    sheet.getRangeByIndex(row, 1).cellStyle.bold = true;
    sheet.getRangeByIndex(row, 2).setText(
        '${ArabicDate.format(_fromDate!)} - ${ArabicDate.format(_toDate!)}');
    row++;
    sheet.getRangeByIndex(row, 1).setText('عدد القوائم:');
    sheet.getRangeByIndex(row, 1).cellStyle.bold = true;
    sheet.getRangeByIndex(row, 2).setText('${widget.group.checklists.length}');
    row += 2;

    bool wroteAny = false;

    for (int ci = 0; ci < widget.group.checklists.length; ci++) {
      final checklist = widget.group.checklists[ci];
      final stats = _checklistStats[checklist.id] ?? {};
      final totalResponses = (stats['total_responses'] as int?) ?? 0;
      final cpStats =
          (stats['checkpoints'] as Map<String, Map<String, dynamic>>?) ?? {};

      // Skip checklists with no data at all
      final hasData = totalResponses > 0 ||
          cpStats.values.any((s) => ((s['count'] as int?) ?? 0) > 0);
      if (!hasData) continue;

      final overallPct = (stats['overall_percentage'] as double?) ?? 0.0;
      final activeFiltersCount = _checklistFilters[checklist.id]?.length ?? 0;
      final filteredResponses = _getFilteredResponsesForChecklist(checklist.id);

      // Divider between tables
      if (wroteAny) {
        row += 2;
        for (int col = 1; col <= totalCols; col++) {
          sheet.getRangeByIndex(row, col).cellStyle
            ..backColor = '#94A3B8'
            ..borders.bottom.lineStyle = xlsio.LineStyle.thick;
        }
        sheet.setRowHeightInPixels(row, 4);
        row += 2;
      }
      wroteAny = true;

      // Checklist header
      final clRange = sheet.getRangeByIndex(row, 1, row, totalCols)..merge();
      clRange.setText(checklist.title);
      clRange.cellStyle
        ..bold = true
        ..fontSize = 15
        ..backColor = '#334155'
        ..fontColor = '#FFFFFF'
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center;
      sheet.setRowHeightInPixels(row, 40);
      row++;

      // Description
      if (checklist.description != null && checklist.description!.isNotEmpty) {
        final descRange = sheet.getRangeByIndex(row, 1, row, totalCols)..merge();
        descRange.setText(checklist.description);
        descRange.cellStyle
          ..fontSize = 11
          ..backColor = '#F8FAFC'
          ..fontColor = '#64748B'
          ..hAlign = xlsio.HAlignType.right;
        sheet.setRowHeightInPixels(row, 24);
        row++;
      }

      // Summary headers
      final summaryHeaders = ['عدد الاستجابات', 'النسبة المئوية', 'التقييم', 'الفلاتر النشطة'];
      for (int i = 0; i < summaryHeaders.length; i++) {
        final cell = sheet.getRangeByIndex(row, i + 1);
        cell.setText(summaryHeaders[i]);
        cell.cellStyle
          ..bold = true
          ..fontSize = 11
          ..backColor = '#E2E8F0'
          ..fontColor = '#1E293B'
          ..hAlign = xlsio.HAlignType.center
          ..vAlign = xlsio.VAlignType.center
          ..borders.all.lineStyle = xlsio.LineStyle.thin;
      }
      sheet.setRowHeightInPixels(row, 30);
      row++;

      // Summary values
      sheet.getRangeByIndex(row, 1).setNumber(totalResponses.toDouble());
      sheet.getRangeByIndex(row, 1).cellStyle
        ..hAlign = xlsio.HAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      final pctCell = sheet.getRangeByIndex(row, 2);
      pctCell.setText('${overallPct.toStringAsFixed(1)}%');
      pctCell.cellStyle
        ..backColor = _getPerformanceColorHex(overallPct)
        ..fontColor = _getPerformanceFontColorHex(overallPct)
        ..bold = true
        ..fontSize = 14
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      final ratingCell = sheet.getRangeByIndex(row, 3);
      ratingCell.setText(QColors.getPerformanceLabel(overallPct));
      ratingCell.cellStyle
        ..backColor = _getPerformanceColorHex(overallPct)
        ..fontColor = _getPerformanceFontColorHex(overallPct)
        ..bold = true
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      sheet.getRangeByIndex(row, 4).setText(
          activeFiltersCount > 0 ? '$activeFiltersCount فلتر' : 'بدون فلاتر');
      sheet.getRangeByIndex(row, 4).cellStyle
        ..hAlign = xlsio.HAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      sheet.setRowHeightInPixels(row, 35);
      row += 2;

      // Checkpoint table headers
      const cpHeaders = ['#', 'نقطة الفحص', 'المتوسط', 'عدد التقييمات', 'النسبة المئوية', 'التقييم', 'الملاحظات'];
      for (int i = 0; i < cpHeaders.length; i++) {
        final cell = sheet.getRangeByIndex(row, i + 1);
        cell.setText(cpHeaders[i]);
        cell.cellStyle
          ..bold = true
          ..fontSize = 11
          ..backColor = '#F1F5F9'
          ..fontColor = '#1E293B'
          ..hAlign = xlsio.HAlignType.center
          ..vAlign = xlsio.VAlignType.center
          ..borders.all.lineStyle = xlsio.LineStyle.thin;
      }
      sheet.setRowHeightInPixels(row, 30);
      row++;

      // Checkpoint rows — skip checkpoints with zero count
      int visibleIndex = 1;
      for (int i = 0; i < checklist.checkPoints.length; i++) {
        final cp = checklist.checkPoints[i];
        final s = cpStats[cp.id] ?? {};
        final avg = (s['average'] as double?) ?? 0.0;
        final pct = (s['percentage'] as double?) ?? 0.0;
        final count = (s['count'] as int?) ?? 0;
        if (count == 0) continue; // skip all-zero rows

        final bgColor = visibleIndex.isOdd ? '#FFFFFF' : '#F8FAFC';
        final notesText = _collectCheckpointNotes(filteredResponses, cp.id);
        final noteLines = notesText.isEmpty ? 1 : '\n'.allMatches(notesText).length + 1;

        sheet.getRangeByIndex(row, 1).setNumber(visibleIndex.toDouble());
        sheet.getRangeByIndex(row, 1).cellStyle
          ..hAlign = xlsio.HAlignType.center
          ..backColor = bgColor
          ..borders.all.lineStyle = xlsio.LineStyle.thin;

        sheet.getRangeByIndex(row, 2).setText(cp.title);
        sheet.getRangeByIndex(row, 2).cellStyle
          ..hAlign = xlsio.HAlignType.right
          ..backColor = bgColor
          ..borders.all.lineStyle = xlsio.LineStyle.thin;

        sheet.getRangeByIndex(row, 3)
            .setText('${avg.toStringAsFixed(2)}/${checklist.rateNumber}');
        sheet.getRangeByIndex(row, 3).cellStyle
          ..hAlign = xlsio.HAlignType.center
          ..backColor = bgColor
          ..borders.all.lineStyle = xlsio.LineStyle.thin;

        sheet.getRangeByIndex(row, 4).setNumber(count.toDouble());
        sheet.getRangeByIndex(row, 4).cellStyle
          ..hAlign = xlsio.HAlignType.center
          ..backColor = bgColor
          ..borders.all.lineStyle = xlsio.LineStyle.thin;

        final cpPctCell = sheet.getRangeByIndex(row, 5);
        cpPctCell.setText('${pct.toStringAsFixed(1)}%');
        cpPctCell.cellStyle
          ..backColor = _getPerformanceColorHex(pct)
          ..fontColor = _getPerformanceFontColorHex(pct)
          ..bold = true
          ..fontSize = 12
          ..hAlign = xlsio.HAlignType.center
          ..vAlign = xlsio.VAlignType.center
          ..borders.all.lineStyle = xlsio.LineStyle.thin;

        final cpRatingCell = sheet.getRangeByIndex(row, 6);
        cpRatingCell.setText(checklist.getRatingLabel(avg.round()));
        cpRatingCell.cellStyle
          ..backColor = _getPerformanceColorHex(pct)
          ..fontColor = _getPerformanceFontColorHex(pct)
          ..hAlign = xlsio.HAlignType.center
          ..vAlign = xlsio.VAlignType.center
          ..borders.all.lineStyle = xlsio.LineStyle.thin;

        final notesCell = sheet.getRangeByIndex(row, 7);
        if (notesText.isNotEmpty) notesCell.setText(notesText);
        notesCell.cellStyle
          ..hAlign = xlsio.HAlignType.right
          ..vAlign = xlsio.VAlignType.top
          ..wrapText = true
          ..backColor = bgColor
          ..borders.all.lineStyle = xlsio.LineStyle.thin;

        // Row height: base 28 + ~16 per extra note line
        final rowHeight = (28 + (noteLines - 1) * 16).clamp(28, 200).toDouble();
        sheet.setRowHeightInPixels(row, rowHeight);

        visibleIndex++;
        row++;
      }
    }

    // Column widths
    sheet.setColumnWidthInPixels(1, 40);
    sheet.setColumnWidthInPixels(2, 280);
    sheet.setColumnWidthInPixels(3, 100);
    sheet.setColumnWidthInPixels(4, 110);
    sheet.setColumnWidthInPixels(5, 110);
    sheet.setColumnWidthInPixels(6, 130);
    sheet.setColumnWidthInPixels(7, 320);
  }

  String _getPerformanceColorHex(double p) {
    if (p >= 80) return '#D1FAE5';
    if (p >= 60) return '#DBEAFE';
    if (p >= 50) return '#FEF3C7';
    return '#FEE2E2';
  }

  String _getPerformanceFontColorHex(double p) {
    if (p >= 80) return '#065F46';
    if (p >= 60) return '#1E40AF';
    if (p >= 50) return '#92400E';
    return '#991B1B';
  }

  Future<void> _downloadExcelFile(Uint8List bytes, String filename) async {
    final fileUtils = FileUtils.instance;
    await fileUtils.downloadFile(bytes, filename,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  }

  // Legacy methods kept (not shown in UI but preserved for compatibility)
  Future<void> _createSummarySheet(
      xlsio.Worksheet sheet, xlsio.Workbook workbook) async {}

  Future<void> _createChecklistAveragesSheet(xlsio.Worksheet sheet,
      QualityChecklist checklist, xlsio.Workbook workbook) async {}
}

// ─────────────────────────────────────────────────────────────
//  KPI Data Model
// ─────────────────────────────────────────────────────────────
class _KPIData {
  final String label;
  final String value;
  final IconData icon;
  final int gradientIndex;
  final String? subtitle;
  final double? progress;

  const _KPIData({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradientIndex,
    this.subtitle,
    this.progress,
  });
}

// ─────────────────────────────────────────────────────────────
//  KPI Card Widget
// ─────────────────────────────────────────────────────────────
class _KPICard extends StatelessWidget {
  final _KPIData data;
  const _KPICard({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = _DS.kpiGradient(data.gradientIndex);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: _DS.shadowSm,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(data.icon, size: 17, color: Colors.white),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    data.value,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800,
                        color: Colors.white, height: 1),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              data.label,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (data.subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                data.subtitle!,
                style: TextStyle(fontSize: 9.5, color: Colors.white.withValues(alpha: 0.75)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (data.progress != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: data.progress!.clamp(0.0, 1.0),
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Custom Bar Chart (pure Flutter, no external lib)
// ─────────────────────────────────────────────────────────────
class _CustomBarChart extends StatelessWidget {
  final List<CheckPoint> checkpoints;
  final Map<String, Map<String, dynamic>> cpStats;

  const _CustomBarChart({
    required this.checkpoints,
    required this.cpStats,
  });

  static const double _yAxisWidth = 28.0;
  static const double _barGap = 6.0;
  static const double _minBarWidth = 18.0;

  List<Widget> _gridLines() => List.generate(
        5,
        (_) => Container(height: 1, color: _DS.border),
      );

  @override
  Widget build(BuildContext context) {
    if (checkpoints.isEmpty) {
      return const Center(
        child: Text('لا توجد نقاط فحص',
            style: TextStyle(fontSize: 11, color: _DS.textMuted)),
      );
    }

    return LayoutBuilder(builder: (ctx, constraints) {
      final availableWidth =
          constraints.maxWidth - _yAxisWidth - 4; // 4 = SizedBox gap

      // Ideal bar width that fits without scrolling
      final fittedBarWidth =
          (availableWidth / checkpoints.length) - _barGap;

      // Use fitted width but not smaller than minimum
      final barWidth = math.max(_minBarWidth, fittedBarWidth);

      // Total width bars actually need
      final totalBarsWidth =
          checkpoints.length * (barWidth + _barGap);

      // Scroll when bars don't fit in available space
      final needsScroll = totalBarsWidth > availableWidth;

      final bars = checkpoints.asMap().entries.map((e) {
        final cp = e.value;
        final s = cpStats[cp.id] ?? {};
        final pct = (s['percentage'] as double?) ?? 0.0;
        final color = QColors.getPerformanceColor(pct);
        return _AnimatedBar(
          label: '${e.key + 1}',
          percentage: pct,
          color: color,
          barWidth: barWidth,
          tooltip: '${cp.title}\n${pct.toStringAsFixed(1)}%',
        );
      }).toList();

      Widget chartContent = Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Grid lines — always fill the full available width
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _gridLines(),
          ),
          // Bars row
          if (needsScroll)
            Positioned.fill(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: totalBarsWidth,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: bars,
                  ),
                ),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: bars,
            ),
        ],
      );

      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Y-axis labels
          SizedBox(
            width: _yAxisWidth,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: ['100', '75', '50', '25', '0']
                  .map((l) => Text(l,
                      style: const TextStyle(
                          fontSize: 8.5, color: _DS.textMuted)))
                  .toList(),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(child: chartContent),
        ],
      );
    });
  }
}

class _AnimatedBar extends StatefulWidget {
  final String label;
  final double percentage;
  final Color color;
  final double barWidth;
  final String tooltip;

  const _AnimatedBar({
    required this.label,
    required this.percentage,
    required this.color,
    required this.barWidth,
    required this.tooltip,
  });

  @override
  State<_AnimatedBar> createState() => _AnimatedBarState();
}

class _AnimatedBarState extends State<_AnimatedBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      preferBelow: false,
      child: SizedBox(
        width: widget.barWidth,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AnimatedBuilder(
              animation: _anim,
              builder: (_, __) {
                return Container(
                  width: widget.barWidth,
                  height: (_anim.value * widget.percentage / 100) * 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.color.withValues(alpha: 0.7),
                        widget.color,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(3),
                      topRight: Radius.circular(3),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 3),
            Text(widget.label, style: const TextStyle(fontSize: 9, color: _DS.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Gradient Progress Bar
// ─────────────────────────────────────────────────────────────
class _GradientProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;

  const _GradientProgressBar({
    required this.value,
    required this.color,
    this.height = 5,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      return Stack(
        children: [
          Container(
            height: height,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
          Container(
            height: height,
            width: constraints.maxWidth * value.clamp(0.0, 1.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.7), color],
              ),
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────
//  Stat Pill
// ─────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _StatPill({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                fontSize: 10.5,
                color: color,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Small reusable widgets
// ─────────────────────────────────────────────────────────────

class _FilterLabel extends StatelessWidget {
  final String text;
  const _FilterLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: _DS.textSecondary),
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  final double width;
  const _TH(this.text, this.width);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _DS.textPrimary),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _CompactDropdown<T> extends StatelessWidget {
  final T? value;
  final double width;
  final ValueChanged<T?> onChanged;
  final List<DropdownMenuItem<T>> items;

  const _CompactDropdown({
    required this.value,
    required this.width,
    required this.onChanged,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _DS.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: _DS.textSecondary),
          style: const TextStyle(fontSize: 11, color: _DS.textPrimary),
          onChanged: onChanged,
          items: items,
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _DatePickerField({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 120,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _DS.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 12, color: _DS.textSecondary),
              const SizedBox(width: 5),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 11, color: _DS.textPrimary))),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _ExportButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(7),
            boxShadow: _DS.shadowSm,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download_rounded, size: 15, color: Colors.white),
              SizedBox(width: 6),
              Text('تصدير Excel',
                  style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}