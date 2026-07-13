// lib/screens/web/quality_management/quality_responses_screen.dart
import 'package:flutter/material.dart';
import 'package:jala_as/models/quality_models.dart';
import 'package:jala_as/screens/utils/file_utils.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/helpers.dart';
import 'dart:ui' as ui;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'dart:typed_data';

import 'quality_colors.dart';

// ─────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────
class ArabicDate {
  static const List<String> months = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  static String format(DateTime date) =>
      '${date.day} ${months[date.month - 1]} ${date.year}';

  static String formatTime(DateTime date) {
    final period = date.hour < 12 ? 'ص' : 'م';
    final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '${h.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $period';
  }
}

/// Parses a rating value from dynamic JSON (int, double, or num) → double
double _parseRating(dynamic raw) {
  if (raw == null) return 0.0;
  if (raw is double) return raw;
  if (raw is int) return raw.toDouble();
  if (raw is num) return raw.toDouble();
  final parsed = double.tryParse(raw.toString());
  return parsed ?? 0.0;
}

/// Formats a decimal rating for display: drops trailing ".0"
String _fmt(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

// ─────────────────────────────────────────────────────────────
//  Filter condition model
// ─────────────────────────────────────────────────────────────
enum ConditionOperator { eq, neq, gte, lte, gt, lt }

extension ConditionOperatorX on ConditionOperator {
  String get label {
    switch (this) {
      case ConditionOperator.eq: return '=';
      case ConditionOperator.neq: return '≠';
      case ConditionOperator.gte: return '≥';
      case ConditionOperator.lte: return '≤';
      case ConditionOperator.gt: return '>';
      case ConditionOperator.lt: return '<';
    }
  }
  bool evaluate(double a, double b) {
    switch (this) {
      case ConditionOperator.eq: return (a - b).abs() < 0.001;
      case ConditionOperator.neq: return (a - b).abs() >= 0.001;
      case ConditionOperator.gte: return a >= b;
      case ConditionOperator.lte: return a <= b;
      case ConditionOperator.gt: return a > b;
      case ConditionOperator.lt: return a < b;
    }
  }
}

class FilterCondition {
  final String fieldId;        // 'average' or a checkpoint id
  final ConditionOperator op;
  final double value;
  FilterCondition({required this.fieldId, required this.op, required this.value});
  FilterCondition copyWith({String? fieldId, ConditionOperator? op, double? value}) =>
      FilterCondition(fieldId: fieldId ?? this.fieldId, op: op ?? this.op, value: value ?? this.value);
}

// ─────────────────────────────────────────────────────────────
//  Export option models
// ─────────────────────────────────────────────────────────────
enum _ExportScope { current, all }
enum _ReportType { regular, singleDay }
enum _ResultFormat { percentage, score }
enum _SheetLayout { stacked, separateSheets }

class _ExportOptions {
  final _ExportScope scope;
  final _ReportType reportType;
  final DateTime? singleDate;
  final DateTime? fromDate;
  final DateTime? toDate;
  final bool withNotes;
  final bool withAttachments;
  final _ResultFormat resultFormat;
  final _SheetLayout layout;
  const _ExportOptions({
    required this.scope,
    required this.reportType,
    this.singleDate,
    this.fromDate,
    this.toDate,
    required this.withNotes,
    required this.withAttachments,
    required this.resultFormat,
    required this.layout,
  });
}

// ─────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────
class QualityResponsesScreen extends StatefulWidget {
  final QualityChecklistGroup group;
  final int? initialChecklistId;
  final DateTime? initialFromDate;
  final DateTime? initialToDate;
  final Map<String, String>? initialFilters;

  const QualityResponsesScreen({
    super.key,
    required this.group,
    this.initialChecklistId,
    this.initialFromDate,
    this.initialToDate,
    this.initialFilters,
  });

  @override
  State<QualityResponsesScreen> createState() => _QualityResponsesScreenState();
}

class _QualityResponsesScreenState extends State<QualityResponsesScreen> {
  List<QualityResponse> _responses = [];
  Map<String, String> _userNames = {};
  Map<int, List<QualityCheckpointIssue>> _responseIssues = {};
  bool _isLoading = true;
  String _selectedPeriod = 'current_year';
  DateTime? _fromDate;
  DateTime? _toDate;
  int? _selectedChecklistId;
  Map<String, String> _determinantFilters = {};
  Set<int> _expandedResponses = {};

  // Search / sort / score filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _searchTarget = 'all'; // 'all', 'user', 'date', 'notes', 'determinants'
  String _sortBy = 'date';      // 'date', 'average', or a checkpoint ID
  bool _sortAscending = false;
  double _overallMinPct = 0;
  double _overallMaxPct = 100;

  // View mode
  bool _tableView = false;

  // Advanced filter state
  final List<FilterCondition> _conditions = [];
  Set<String> _selectedUserIds = {};
  final Map<String, Set<String>> _multiDeterminantFilters = {};
  DateTime? _advFromDate;
  DateTime? _advToDate;

  // Single-date filter
  DateTime? _singleDateFilter;

  // Advanced filter panel expanded state
  bool _advancedFilterExpanded = false;

  // Transposed table view: records as columns, checkpoints as rows
  bool _transposedView = false;
  String? _transposedSortCpId;  // checkpoint id to sort by
  bool _transposedSortAsc = false;
  late final ScrollController _transposedHCtrl = ScrollController();
  late final ScrollController _transposedHBarCtrl = ScrollController();
  bool _syncingH = false;

  void _syncHToBar() {
    if (_syncingH || !_transposedHBarCtrl.hasClients) return;
    _syncingH = true;
    try { _transposedHBarCtrl.jumpTo(_transposedHCtrl.offset); } catch (_) {}
    _syncingH = false;
  }

  void _syncBarToH() {
    if (_syncingH || !_transposedHCtrl.hasClients) return;
    _syncingH = true;
    try { _transposedHCtrl.jumpTo(_transposedHBarCtrl.offset); } catch (_) {}
    _syncingH = false;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    _transposedHCtrl.addListener(_syncHToBar);
    _transposedHBarCtrl.addListener(_syncBarToH);
    _selectedChecklistId = widget.initialChecklistId ??
        (widget.group.checklists.isNotEmpty ? widget.group.checklists.first.id : null);
    if (widget.initialFromDate != null && widget.initialToDate != null) {
      _fromDate = widget.initialFromDate;
      _toDate = widget.initialToDate;
    } else {
      _initializeDates();
    }
    if (widget.initialFilters != null) {
      _determinantFilters = Map.from(widget.initialFilters!);
    }
    _loadData();
  }

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
      default:
        _fromDate = DateTime(now.year, 1, 1);
        _toDate = DateTime(now.year, 12, 31, 23, 59, 59);
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    debugPrint('[QualityResponsesScreen] _loadData: groupId=${widget.group.id}, from=$_fromDate, to=$_toDate');
    setState(() => _isLoading = true);
    try {
      final responses = await SupabaseService.getQualityResponses(
        groupId: widget.group.id,
        fromDate: _fromDate,
        toDate: _toDate,
      );

      debugPrint('[QualityResponsesScreen] Got ${responses.length} responses. ChecklistId filter: $_selectedChecklistId');

      final userIds = responses.map((r) => r.userId).toSet().toList();
      final responseIds = responses.map((r) => r.id).toList();

      debugPrint('[QualityResponsesScreen] Fetching names for ${userIds.length} users, issues for ${responseIds.length} responses');

      // Fetch user names and all issues in parallel (2 queries total)
      final results = await Future.wait([
        SupabaseService.getUsersByIds(userIds),
        SupabaseService.getQualityCheckpointIssuesBulk(responseIds),
      ]);

      if (!mounted) return;
      final userNames = results[0] as Map<String, String>;
      final responseIssues = results[1] as Map<int, List<QualityCheckpointIssue>>;
      debugPrint('[QualityResponsesScreen] Loaded ${userNames.length} user names, ${responseIssues.length} issue groups');

      // Auto-select first checklist that has responses
      final ids = responses.map((r) => r.checklistId).toSet();
      final withData = widget.group.checklists.where((c) => ids.contains(c.id)).toList();
      final currentValid = withData.any((c) => c.id == _selectedChecklistId);

      setState(() {
        _responses = responses;
        _userNames = userNames;
        _responseIssues = responseIssues;
        if (!currentValid && withData.isNotEmpty) {
          _selectedChecklistId = withData.first.id;
          _determinantFilters.clear();
        }
        _isLoading = false;
      });
    } catch (e, stack) {
      debugPrint('[QualityResponsesScreen] ERROR in _loadData: $e');
      debugPrint('[QualityResponsesScreen] STACK: $stack');
      if (!mounted) return;
      setState(() => _isLoading = false);
      Helpers.showSnackBar(context, 'فشل في تحميل البيانات: $e', isError: true);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _transposedHCtrl.removeListener(_syncHToBar);
    _transposedHBarCtrl.removeListener(_syncBarToH);
    _transposedHCtrl.dispose();
    _transposedHBarCtrl.dispose();
    super.dispose();
  }

  List<QualityResponse> get _filteredResponses {
    var responses = _responses;
    if (_selectedChecklistId != null) {
      responses = responses.where((r) => r.checklistId == _selectedChecklistId).toList();
    }
    if (_fromDate != null && _toDate != null) {
      responses = responses.where((r) {
        return r.responseDate.isAfter(_fromDate!.subtract(const Duration(days: 1))) &&
            r.responseDate.isBefore(_toDate!.add(const Duration(days: 1)));
      }).toList();
    }
    if (_determinantFilters.isNotEmpty) {
      responses = responses.where((r) {
        return _determinantFilters.entries.every((filter) {
          final value = r.determinantValues[filter.key];
          return value != null && value.toString() == filter.value;
        });
      }).toList();
    }
    return responses;
  }

  /// Applies advanced filters, search query, score range filter, and sorting on top of _filteredResponses.
  List<QualityResponse> get _displayedResponses {
    final checklist = _selectedChecklist;
    var list = _filteredResponses;

    // ── Advanced date range ──
    if (_advFromDate != null || _advToDate != null) {
      list = list.where((r) {
        if (_advFromDate != null && r.responseDate.isBefore(_advFromDate!)) return false;
        if (_advToDate != null && r.responseDate.isAfter(_advToDate!.add(const Duration(days: 1)))) return false;
        return true;
      }).toList();
    }

    // ── Single-date filter ──
    if (_singleDateFilter != null) {
      list = list.where((r) => _isSameDay(r.responseDate, _singleDateFilter!)).toList();
    }

    // ── Multi-select user filter ──
    if (_selectedUserIds.isNotEmpty) {
      list = list.where((r) => _selectedUserIds.contains(r.userId)).toList();
    }

    // ── Multi-select determinant filters ──
    if (_multiDeterminantFilters.isNotEmpty) {
      list = list.where((r) {
        return _multiDeterminantFilters.entries.every((entry) {
          if (entry.value.isEmpty) return true;
          final val = r.determinantValues[entry.key]?.toString() ?? '';
          return entry.value.contains(val);
        });
      }).toList();
    }

    // ── Score range (quick chips) ──
    if (checklist != null && (_overallMinPct > 0 || _overallMaxPct < 100)) {
      list = list.where((r) {
        final avg = _responseAverage(r, checklist);
        return avg >= _overallMinPct && avg <= _overallMaxPct;
      }).toList();
    }

    // ── Condition builder ──
    if (checklist != null && _conditions.isNotEmpty) {
      list = list.where((r) {
        return _conditions.every((cond) {
          double actual;
          if (cond.fieldId == 'average') {
            actual = _responseAverage(r, checklist);
          } else {
            final data = r.checkPointRatings[cond.fieldId];
            double rawRating = 0;
            if (data is Map<String, dynamic>) {
              rawRating = _parseRating(data['rating']);
            } else {
              rawRating = _parseRating(data);
            }
            actual = rawRating;
          }
          return cond.op.evaluate(actual, cond.value);
        });
      }).toList();
    }

    // ── Text search ──
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) {
        switch (_searchTarget) {
          case 'user':
            return (_userNames[r.userId] ?? '').toLowerCase().contains(q);
          case 'date':
            return ArabicDate.format(r.responseDate).contains(q) ||
                r.responseDate.toIso8601String().contains(q);
          case 'notes':
            if (r.mainNotes?.toLowerCase().contains(q) ?? false) return true;
            for (final v in r.checkPointRatings.values) {
              if (v is Map<String, dynamic> &&
                  (v['notes'] as String? ?? '').toLowerCase().contains(q)) return true;
            }
            return false;
          case 'determinants':
            return r.determinantValues.values.any((v) => v.toString().toLowerCase().contains(q));
          default:
            if ((_userNames[r.userId] ?? '').toLowerCase().contains(q)) return true;
            if (ArabicDate.format(r.responseDate).contains(q)) return true;
            if (r.determinantValues.values.any((v) => v.toString().toLowerCase().contains(q))) return true;
            if (r.mainNotes?.toLowerCase().contains(q) ?? false) return true;
            for (final v in r.checkPointRatings.values) {
              if (v is Map<String, dynamic> &&
                  (v['notes'] as String? ?? '').toLowerCase().contains(q)) return true;
            }
            return false;
        }
      }).toList();
    }

    // ── Sorting ──
    if (checklist != null) {
      list = List.from(list)..sort((a, b) {
        int cmp;
        if (_sortBy == 'average') {
          cmp = _responseAverage(a, checklist).compareTo(_responseAverage(b, checklist));
        } else if (_sortBy != 'date' && checklist.checkPoints.any((cp) => cp.id == _sortBy)) {
          cmp = _cpRatingPct(a, _sortBy, checklist).compareTo(_cpRatingPct(b, _sortBy, checklist));
        } else {
          cmp = a.responseDate.compareTo(b.responseDate);
        }
        return _sortAscending ? cmp : -cmp;
      });
    }

    // ── Transposed view sort (sort columns = records by checkpoint value) ──
    if (_transposedView && _transposedSortCpId != null && checklist != null) {
      list = List.from(list)..sort((a, b) {
        final va = _cpRatingPct(a, _transposedSortCpId!, checklist);
        final vb = _cpRatingPct(b, _transposedSortCpId!, checklist);
        final cmp = va.compareTo(vb);
        return _transposedSortAsc ? cmp : -cmp;
      });
    }

    return list;
  }

  double _cpRatingPct(QualityResponse r, String cpId, QualityChecklist checklist) {
    final data = r.checkPointRatings[cpId];
    double rating = 0;
    if (data is Map<String, dynamic>) {
      rating = _parseRating(data['rating']);
    } else {
      rating = _parseRating(data);
    }
    return checklist.rateNumber > 0 ? rating / checklist.rateNumber * 100 : 0;
  }

  /// Checklists that have at least one response in the loaded data.
  List<QualityChecklist> get _checklistsWithResponses {
    final ids = _responses.map((r) => r.checklistId).toSet();
    return widget.group.checklists.where((c) => ids.contains(c.id)).toList();
  }

  /// Actual values used in responses for a given checklist + determinant.
  Set<String> _actualDeterminantValues(String determinantId) {
    if (_selectedChecklistId == null) return {};
    return _responses
        .where((r) => r.checklistId == _selectedChecklistId)
        .map((r) => r.determinantValues[determinantId]?.toString())
        .whereType<String>()
        .where((v) => v.isNotEmpty)
        .toSet();
  }

  QualityChecklist? get _selectedChecklist {
    if (_selectedChecklistId == null) return null;
    return widget.group.checklists.firstWhere(
      (c) => c.id == _selectedChecklistId,
      orElse: () => widget.group.checklists.first,
    );
  }

  /// Compute response average (decimal-aware)
  double _responseAverage(QualityResponse response, QualityChecklist checklist) {
    double total = 0;
    int rated = 0;
    response.checkPointRatings.forEach((_, value) {
      double rating = 0;
      if (value is Map<String, dynamic>) {
        rating = _parseRating(value['rating']);
      } else {
        rating = _parseRating(value);
      }
      if (rating > 0 && checklist.rateNumber > 0) {
        total += (rating / checklist.rateNumber * 100);
        rated++;
      }
    });
    return rated > 0 ? total / rated : 0.0;
  }

  void _onPeriodChanged(String? period) {
    if (period == null) return;
    setState(() {
      _selectedPeriod = period;
      _initializeDates();
    });
    _loadData();
  }

  void _updateFilter(String determinantId, String? value) {
    setState(() {
      if (value != null && value.isNotEmpty && value != 'الكل') {
        _determinantFilters[determinantId] = value;
      } else {
        _determinantFilters.remove(determinantId);
      }
    });
  }

  void _clearFilters() => setState(() => _determinantFilters.clear());

  void _toggleExpanded(int responseId) {
    setState(() {
      if (_expandedResponses.contains(responseId)) {
        _expandedResponses.remove(responseId);
      } else {
        _expandedResponses.add(responseId);
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Container(
        color: const Color(0xFFF0F2F5),
        child: Column(
          children: [
            _buildTopBar(),
            _buildFiltersBar(),
            if (_advancedFilterExpanded) _buildAdvancedFilterPanel(),
            _buildSearchSortBar(),
            _buildSummaryBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: QColors.primary))
                  : _displayedResponses.isEmpty
                      ? _buildEmptyState()
                      : _transposedView
                          ? _buildTransposedTableView()
                          : _tableView
                              ? _buildTableView()
                              : _buildResponsesList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────

  Widget _buildTopBar() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final datePill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.date_range, size: 13, color: Color(0xFF6B7280)),
          const SizedBox(width: 5),
          Text(
            isMobile
                ? '${ArabicDate.format(_fromDate!)} - ${ArabicDate.format(_toDate!)}'
                : '${ArabicDate.format(_fromDate!)}  ←  ${ArabicDate.format(_toDate!)}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF374151), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                datePill,
                const SizedBox(height: 8),
                Row(
                  children: [
                    _ExportButton(onTap: _showExportDialog),
                    const SizedBox(width: 8),
                    _buildAdvancedFilterButton(),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                datePill,
                const SizedBox(width: 10),
                _ExportButton(onTap: _showExportDialog),
                const SizedBox(width: 8),
                _buildViewToggle(),
                const SizedBox(width: 8),
                _buildAdvancedFilterButton(),
              ],
            ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewBtn(
            icon: Icons.view_agenda_outlined,
            active: !_tableView && !_transposedView,
            tooltip: 'عرض البطاقات',
            onTap: () => setState(() { _tableView = false; _transposedView = false; }),
          ),
          _ViewBtn(
            icon: Icons.table_rows_rounded,
            active: _tableView && !_transposedView,
            tooltip: 'جدول (سجل × صف)',
            onTap: () => setState(() { _tableView = true; _transposedView = false; }),
          ),
          _ViewBtn(
            icon: Icons.view_column_rounded,
            active: _transposedView,
            tooltip: 'جدول (سجل × عمود)',
            onTap: () => setState(() { _transposedView = true; _tableView = false; }),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedFilterButton() {
    final hasAdvanced = _conditions.isNotEmpty ||
        _selectedUserIds.isNotEmpty ||
        _multiDeterminantFilters.values.any((s) => s.isNotEmpty) ||
        _advFromDate != null ||
        _advToDate != null;
    final color = _advancedFilterExpanded
        ? const Color(0xFF7C3AED)
        : hasAdvanced
            ? const Color(0xFF7C3AED)
            : const Color(0xFF6B7280);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _advancedFilterExpanded = !_advancedFilterExpanded),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _advancedFilterExpanded
                ? const Color(0xFFF5F3FF)
                : hasAdvanced
                    ? const Color(0xFFF5F3FF)
                    : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: (_advancedFilterExpanded || hasAdvanced)
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFFD1D5DB)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 14, color: color),
              const SizedBox(width: 5),
              Text('فلاتر متقدمة',
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
              if (hasAdvanced) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration:
                      BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    '${_conditions.length + (_selectedUserIds.isNotEmpty ? 1 : 0) + _multiDeterminantFilters.values.where((s) => s.isNotEmpty).length + (_advFromDate != null || _advToDate != null ? 1 : 0)}',
                    style: const TextStyle(
                        fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(
                _advancedFilterExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedFilterPanel() {
    final checklist = _selectedChecklist;
    if (checklist == null) return const SizedBox.shrink();

    final userIds = _filteredResponses.map((r) => r.userId).toSet();
    final availableUsers = userIds
        .map((id) => (id: id, label: _userNames[id] ?? id))
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    Set<String> availableDetValues(String detId) => _filteredResponses
        .map((r) => r.determinantValues[detId]?.toString() ?? '')
        .where((v) => v.isNotEmpty)
        .toSet();

    double maxForField(String fieldId) =>
        fieldId == 'average' ? 100 : checklist.rateNumber.toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFB),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
          top: BorderSide(color: Color(0xFFEDE9FE)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 14, color: Color(0xFF7C3AED)),
              const SizedBox(width: 6),
              const Text('الفلاتر المتقدمة',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B))),
              const Spacer(),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _conditions.clear();
                    _selectedUserIds.clear();
                    _multiDeterminantFilters.clear();
                    _advFromDate = null;
                    _advToDate = null;
                  }),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.clear_all, size: 13, color: Color(0xFFDC2626)),
                        SizedBox(width: 4),
                        Text('إعادة تعيين',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFFDC2626))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _advancedFilterExpanded = false),
                  child: const Icon(Icons.close_rounded,
                      size: 16, color: Color(0xFF6B7280)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Date range ──
          const _AFSectionHeader(
              title: 'نطاق التاريخ', icon: Icons.date_range_rounded),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _AFDatePickerField(
                  label: 'من تاريخ',
                  value: _advFromDate,
                  onPicked: (d) => setState(() => _advFromDate = d),
                  onClear: () => setState(() => _advFromDate = null),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AFDatePickerField(
                  label: 'إلى تاريخ',
                  value: _advToDate,
                  onPicked: (d) => setState(() => _advToDate = d),
                  onClear: () => setState(() => _advToDate = null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Users ──
          const _AFSectionHeader(
              title: 'المستخدمون', icon: Icons.people_outline_rounded),
          const SizedBox(height: 8),
          _AFMultiSelectChips(
            items: availableUsers,
            selected: _selectedUserIds,
            onToggle: (id) => setState(() {
              _selectedUserIds.contains(id)
                  ? _selectedUserIds.remove(id)
                  : _selectedUserIds.add(id);
            }),
          ),

          // ── Determinants ──
          if (checklist.determinants.isNotEmpty) ...[
            const SizedBox(height: 14),
            const _AFSectionHeader(
                title: 'المتغيرات', icon: Icons.filter_alt_outlined),
            const SizedBox(height: 8),
            ...checklist.determinants.map((det) {
              final vals = availableDetValues(det.id);
              if (vals.isEmpty) return const SizedBox.shrink();
              final selected = _multiDeterminantFilters[det.id] ?? {};
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(det.name,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151))),
                    const SizedBox(height: 4),
                    _AFMultiSelectChips(
                      items: vals.map((v) => (id: v, label: v)).toList(),
                      selected: selected,
                      onToggle: (v) => setState(() {
                        final s =
                            _multiDeterminantFilters[det.id] ?? <String>{};
                        s.contains(v) ? s.remove(v) : s.add(v);
                        _multiDeterminantFilters[det.id] = s;
                      }),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 14),

          // ── Score conditions ──
          Row(
            children: [
              const Expanded(
                child: _AFSectionHeader(
                    title: 'شروط الدرجات', icon: Icons.rule_rounded),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _conditions.add(FilterCondition(
                        fieldId: 'average',
                        op: ConditionOperator.gte,
                        value: 60,
                      ))),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFF93C5FD)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 13, color: Color(0xFF1D4ED8)),
                        SizedBox(width: 3),
                        Text('إضافة شرط',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF1D4ED8),
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_conditions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'لا توجد شروط. اضغط "إضافة شرط" لإضافة شرط جديد.',
                style:
                    TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ),
          ..._conditions.asMap().entries.map((entry) {
            final i = entry.key;
            final cond = entry.value;
            final maxVal = maxForField(cond.fieldId);
            final unit = cond.fieldId == 'average'
                ? '(0–100%)'
                : '(0–${maxVal.toInt()})';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _AFDropdown<String>(
                      value: cond.fieldId,
                      items: [
                        const DropdownMenuItem(
                            value: 'average',
                            child: Text('المتوسط العام (%)')),
                        ...checklist.checkPoints.map((cp) =>
                            DropdownMenuItem(
                                value: cp.id,
                                child: Text(cp.title,
                                    overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) => setState(() =>
                          _conditions[i] =
                              cond.copyWith(fieldId: v, value: 0)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: _AFDropdown<ConditionOperator>(
                      value: cond.op,
                      items: ConditionOperator.values
                          .map((op) => DropdownMenuItem(
                              value: op, child: Text(op.label)))
                          .toList(),
                      onChanged: (v) => setState(
                          () => _conditions[i] = cond.copyWith(op: v)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: _AFValueField(
                      value: cond.value,
                      maxValue: maxVal,
                      onChanged: (v) => setState(
                          () => _conditions[i] = cond.copyWith(value: v)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(unit,
                      style: const TextStyle(
                          fontSize: 9, color: Color(0xFF9CA3AF))),
                  const SizedBox(width: 6),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _conditions.removeAt(i)),
                      child: const Icon(
                          Icons.remove_circle_outline_rounded,
                          size: 18,
                          color: Color(0xFFEF4444)),
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

  // ── Filters bar ───────────────────────────────────────────

  Widget _buildFiltersBar() {
    final checklist = _selectedChecklist;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 10,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildDropdown<String>(
                label: 'الفترة',
                value: _selectedPeriod,
                items: const [
                  {'value': 'current_month', 'label': 'الشهر الحالي'},
                  {'value': 'last_3_months', 'label': 'آخر 3 أشهر'},
                  {'value': 'current_year', 'label': 'السنة الحالية'},
                ],
                onChanged: _onPeriodChanged,
                width: 130,
              ),
              if (_checklistsWithResponses.length > 1)
                _buildDropdown<int>(
                  label: 'القائمة',
                  value: _selectedChecklistId,
                  items: _checklistsWithResponses
                      .map((c) => {'value': c.id, 'label': c.title})
                      .toList(),
                  onChanged: (value) => setState(() {
                    _selectedChecklistId = value;
                    _determinantFilters.clear();
                    _sortBy = 'date';
                  }),
                  width: 150,
                ),
              if (checklist != null)
                ...checklist.determinants.map((det) {
                  final actualVals = _actualDeterminantValues(det.id);
                  if (actualVals.isEmpty) return const SizedBox.shrink();
                  final isActive = _determinantFilters.containsKey(det.id);
                  return _buildDropdown<String>(
                    label: det.name,
                    value: _determinantFilters[det.id],
                    items: [
                      {'value': 'الكل', 'label': 'الكل'},
                      ...det.options
                          .where((opt) => actualVals.contains(opt.value))
                          .map((opt) => {'value': opt.value, 'label': opt.value}),
                    ],
                    onChanged: (value) => _updateFilter(det.id, value),
                    width: 110,
                    isActive: isActive,
                  );
                }),
              _buildSingleDatePill(),
              if (_determinantFilters.isNotEmpty)
                GestureDetector(
                  onTap: _clearFilters,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                      border:
                          Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.clear, size: 12, color: Color(0xFFDC2626)),
                        SizedBox(width: 4),
                        Text(
                          'مسح الفلاتر',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<Map<String, dynamic>> items,
    required Function(T?) onChanged,
    double width = 120,
    bool isActive = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label:', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
        const SizedBox(width: 5),
        Container(
          width: width,
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFEFF6FF) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isActive ? const Color(0xFF3B82F6) : const Color(0xFFD1D5DB)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: Color(0xFF6B7280)),
              style: const TextStyle(fontSize: 11, color: Color(0xFF111827)),
              onChanged: onChanged,
              items: items.map((item) {
                return DropdownMenuItem<T>(
                  value: item['value'] as T,
                  child: Text(item['label'] as String,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11)),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleDatePill() {
    final active = _singleDateFilter != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('يوم:', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
        const SizedBox(width: 5),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _singleDateFilter ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _singleDateFilter = picked);
            },
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: active ? const Color(0xFFEFF6FF) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: active ? const Color(0xFF3B82F6) : const Color(0xFFD1D5DB)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded, size: 12,
                      color: active ? const Color(0xFF1D4ED8) : const Color(0xFF6B7280)),
                  const SizedBox(width: 5),
                  Text(
                    active ? ArabicDate.format(_singleDateFilter!) : 'اختر يوماً',
                    style: TextStyle(
                      fontSize: 11,
                      color: active ? const Color(0xFF1D4ED8) : const Color(0xFF6B7280),
                    ),
                  ),
                  if (active) ...[
                    const SizedBox(width: 4),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => setState(() => _singleDateFilter = null),
                        child: const Icon(Icons.close, size: 12, color: Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Summary bar ───────────────────────────────────────────

  Widget _buildSummaryBar() {
    final responses = _displayedResponses;
    final checklist = _selectedChecklist;
    if (checklist == null) return const SizedBox.shrink();

    double totalPct = 0;
    int totalRatings = 0;
    int issueCount = 0;
    int openIssues = 0;

    for (final r in responses) {
      r.checkPointRatings.forEach((_, value) {
        double rating = 0;
        if (value is Map<String, dynamic>) {
          rating = _parseRating(value['rating']);
        } else {
          rating = _parseRating(value);
        }
        if (rating > 0 && checklist.rateNumber > 0) {
          totalPct += (rating / checklist.rateNumber * 100);
          totalRatings++;
        }
      });
      final issues = _responseIssues[r.id] ?? [];
      issueCount += issues.length;
      openIssues += issues.where((i) => i.status != IssueStatus.resolved).length;
    }

    final avg = totalRatings > 0 ? totalPct / totalRatings : 0.0;
    final perfColor = QColors.getPerformanceColor(avg);

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFB),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: isMobile
          ? Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _SummaryKPI(label: 'الاستجابات', value: '${responses.length}', icon: Icons.assignment_outlined, color: const Color(0xFF3B82F6)),
                _SummaryKPI(label: 'المتوسط', value: '${avg.toStringAsFixed(1)}%', icon: Icons.analytics_outlined, color: perfColor),
                _SummaryKPI(label: 'التقييم', value: QColors.getPerformanceLabel(avg), icon: Icons.star_outline_rounded, color: perfColor),
                _SummaryKPI(label: 'المشاكل', value: '$openIssues/$issueCount', icon: Icons.report_problem_outlined, color: openIssues > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                if (_determinantFilters.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text('${_determinantFilters.length} فلتر نشط',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600)),
                  ),
              ],
            )
          : Row(
              children: [
                _SummaryKPI(label: 'الاستجابات', value: '${responses.length}', icon: Icons.assignment_outlined, color: const Color(0xFF3B82F6)),
                _kpiDivider(),
                _SummaryKPI(label: 'المتوسط', value: '${avg.toStringAsFixed(1)}%', icon: Icons.analytics_outlined, color: perfColor),
                _kpiDivider(),
                _SummaryKPI(label: 'التقييم', value: QColors.getPerformanceLabel(avg), icon: Icons.star_outline_rounded, color: perfColor),
                _kpiDivider(),
                _SummaryKPI(label: 'المشاكل', value: '$openIssues/$issueCount', icon: Icons.report_problem_outlined, color: openIssues > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                const Spacer(),
                if (_determinantFilters.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text('${_determinantFilters.length} فلتر نشط',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
    );
  }

  Widget _kpiDivider() => Container(
        width: 1, height: 28, color: const Color(0xFFE5E7EB),
        margin: const EdgeInsets.symmetric(horizontal: 14),
      );

  // ── Table view (dense, business-grade) ────────────────────

  Widget _buildTableView() {
    final responses = _displayedResponses;
    final checklist = _selectedChecklist;
    if (checklist == null) return const SizedBox.shrink();

    // Calculate min width so fixed-column table always renders correctly on any screen
    final double minWidth = 32 + 120 + 110 +
        checklist.determinants.length * 90.0 +
        checklist.checkPoints.length * 90.0 +
        80 + 72 + 80 + 64 + 36;

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: minWidth),
          child: Column(
            children: [
              _buildTableHeader(checklist),
              ...responses.asMap().entries
                  .map((e) => _buildTableRow(e.value, e.key, checklist)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader(QualityChecklist checklist) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
      ),
      child: Row(
        children: [
          _th('#', 32, center: true),
          _th('التاريخ / الوقت', 120),
          _th('المستخدم', 110),
          ...checklist.determinants.map((d) => _th(d.name, 90)),
          ...checklist.checkPoints.map((cp) => _th(cp.title, 90, center: true)),
          _th('المتوسط', 80, center: true),
          _th('النسبة', 72, center: true),
          _th('التقييم', 80, center: true),
          _th('مشاكل', 64, center: true),
          _th('', 36, center: true), // expand
        ],
      ),
    );
  }

  Widget _th(String text, double width, {bool center = false}) {
    return SizedBox(
      width: width,
      height: 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Align(
          alignment: center ? Alignment.center : AlignmentDirectional.centerStart,
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700,
                  color: Colors.white, letterSpacing: 0.3)),
        ),
      ),
    );
  }

  Widget _buildTableRow(QualityResponse response, int index, QualityChecklist checklist) {
    final isExpanded = _expandedResponses.contains(response.id);
    final issues = _responseIssues[response.id] ?? [];
    final openIssues = issues.where((i) => i.status != IssueStatus.resolved).length;
    final avg = _responseAverage(response, checklist);
    final perfColor = QColors.getPerformanceColor(avg);
    final isEven = index.isEven;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFF8FAFC),
        border: const Border(
          left: BorderSide(color: Color(0xFFE5E7EB)),
          right: BorderSide(color: Color(0xFFE5E7EB)),
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _toggleExpanded(response.id),
            child: SizedBox(
              height: 38,
              child: Row(
                children: [
                  // Index
                  SizedBox(
                    width: 32,
                    child: Center(
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: perfColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text('${index + 1}',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: perfColor)),
                        ),
                      ),
                    ),
                  ),

                  // Date/Time
                  SizedBox(
                    width: 120,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ArabicDate.format(response.responseDate),
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF111827), fontWeight: FontWeight.w500)),
                          Text(ArabicDate.formatTime(response.createdAt),
                              style: const TextStyle(fontSize: 9.5, color: Color(0xFF6B7280))),
                        ],
                      ),
                    ),
                  ),

                  // User
                  SizedBox(
                    width: 110,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        _userNames[response.userId] ?? '—',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF374151)),
                      ),
                    ),
                  ),

                  // Determinants
                  ...checklist.determinants.map((det) {
                    final val = response.determinantValues[det.id];
                    return SizedBox(
                      width: 90,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          val?.toString() ?? '—',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF374151)),
                        ),
                      ),
                    );
                  }),

                  // Checkpoints — score badge only; notes/images shown in expanded detail below
                  ...checklist.checkPoints.map((cp) {
                    final ratingData = response.checkPointRatings[cp.id];
                    double rating = 0;
                    bool hasExtra = false;
                    if (ratingData is Map<String, dynamic>) {
                      rating = _parseRating(ratingData['rating']);
                      hasExtra = (ratingData['notes'] as String? ?? '').isNotEmpty ||
                          (ratingData['corrective_action'] as String? ?? '').isNotEmpty ||
                          response.getImagesForCheckpoint(cp.id).isNotEmpty;
                    } else {
                      rating = _parseRating(ratingData);
                    }
                    final pct = checklist.rateNumber > 0 ? (rating / checklist.rateNumber * 100) : 0.0;
                    final c = QColors.getPerformanceColor(pct);

                    return SizedBox(
                      width: 90,
                      child: Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: c.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${_fmt(rating)}/${_fmt(checklist.rateNumber.toDouble())}',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c),
                              ),
                            ),
                            if (hasExtra)
                              Positioned(
                                top: -3, left: -3,
                                child: Container(
                                  width: 7, height: 7,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Average
                  SizedBox(
                    width: 80,
                    child: Center(
                      child: Text(
                        '${avg.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: perfColor),
                      ),
                    ),
                  ),

                  // Progress bar column
                  SizedBox(
                    width: 72,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _MiniProgressBar(value: avg / 100, color: perfColor),
                    ),
                  ),

                  // Label
                  SizedBox(
                    width: 80,
                    child: Center(
                      child: _PerformanceBadge(label: QColors.getPerformanceLabel(avg), color: perfColor),
                    ),
                  ),

                  // Issues
                  SizedBox(
                    width: 64,
                    child: Center(
                      child: issues.isEmpty
                          ? const Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))
                          : _IssueBadge(open: openIssues, total: issues.length),
                    ),
                  ),

                  // Expand toggle
                  SizedBox(
                    width: 36,
                    child: Center(
                      child: Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          size: 18, color: const Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded detail
          if (isExpanded)
            _buildExpandedDetailTable(response, checklist),
        ],
      ),
    );
  }

  Widget _buildExpandedDetailTable(QualityResponse response, QualityChecklist checklist) {
    final issues = _responseIssues[response.id] ?? [];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF0F4FF),
        border: Border(top: BorderSide(color: Color(0xFFBFDBFE))),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Determinants row
          if (response.determinantValues.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: response.determinantValues.entries.map((entry) {
                final det = checklist.determinants.firstWhere(
                  (d) => d.id == entry.key,
                  orElse: () => Determinant(id: entry.key, name: entry.key, options: []),
                );
                return _InfoChip(label: det.name, value: entry.value.toString());
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],

          // Main notes
          if (response.mainNotes != null && response.mainNotes!.isNotEmpty) ...[
            _NoteCard(text: response.mainNotes!, label: 'الملاحظات العامة', color: const Color(0xFF3B82F6)),
            const SizedBox(height: 10),
          ],

          // Checkpoint details grid
          _buildDetailCheckpoints(response, checklist, issues),

          // General images
          if (response.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ImagesRow(
              label: 'صور عامة',
              images: response.images.map((e) => e.imageUrl).toList(),
              onTap: _showImageGallery,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailCheckpoints(
      QualityResponse response, QualityChecklist checklist, List<QualityCheckpointIssue> issues) {
    return Column(
      children: checklist.checkPoints.asMap().entries.map((entry) {
        final i = entry.key;
        final cp = entry.value;
        final ratingData = response.checkPointRatings[cp.id];

        double rating = 0;
        String notes = '';
        String correctiveAction = '';

        if (ratingData is Map<String, dynamic>) {
          rating = _parseRating(ratingData['rating']);
          notes = ratingData['notes'] as String? ?? '';
          correctiveAction = ratingData['corrective_action'] as String? ?? '';
        } else {
          rating = _parseRating(ratingData);
        }

        final pct = checklist.rateNumber > 0 ? (rating / checklist.rateNumber * 100) : 0.0;
        final c = QColors.getPerformanceColor(pct);
        final cpImages = response.getImagesForCheckpoint(cp.id);
        final cpIssues = issues.where((issue) => issue.checkPointId == cp.id).toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkpoint header row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                  border: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                      child: Center(
                        child: Text('${i + 1}', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: c)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(cp.title,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF111827), fontWeight: FontWeight.w600)),
                    ),
                    if (cpIssues.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _IssueBadge(
                        open: cpIssues.where((x) => x.status != IssueStatus.resolved).length,
                        total: cpIssues.length,
                      ),
                    ],
                    const SizedBox(width: 12),
                    // Rating chip
                    _RatingChip(rating: rating, max: checklist.rateNumber.toDouble(), color: c),
                    const SizedBox(width: 8),
                    _MiniProgressBar(value: pct / 100, color: c, width: 60),
                    const SizedBox(width: 8),
                    Text('${pct.toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
                  ],
                ),
              ),

              // Notes / corrective / images / issues
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (notes.isNotEmpty) ...[
                      _InlineNote(icon: Icons.note_outlined, text: notes, color: const Color(0xFF3B82F6)),
                      const SizedBox(height: 6),
                    ],
                    if (correctiveAction.isNotEmpty) ...[
                      _InlineNote(icon: Icons.build_outlined, text: correctiveAction, color: const Color(0xFFF59E0B)),
                      const SizedBox(height: 6),
                    ],
                    if (cpImages.isNotEmpty) ...[
                      _ImagesRow(
                        label: 'صور النقطة',
                        images: cpImages.map((e) => e.imageUrl).toList(),
                        onTap: _showImageGallery,
                        size: 64,
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (cpIssues.isNotEmpty)
                      ...cpIssues.map((issue) => _IssueCard(issue: issue, userNames: _userNames, onImageTap: _showImageGallery)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Transposed table view (records = columns, checkpoints = rows) ─────

  Widget _buildTransposedTableView() {
    final records = _displayedResponses;
    final checklist = _selectedChecklist;
    if (checklist == null || records.isEmpty) return _buildEmptyState();

    const double labelW = 220;
    const double cellW = 180;
    final totalW = labelW + records.length * cellW;

    Widget sortIcon(String cpId) {
      if (_transposedSortCpId != cpId) {
        return const Icon(Icons.unfold_more, size: 13, color: Colors.white54);
      }
      return Icon(
        _transposedSortAsc ? Icons.arrow_upward : Icons.arrow_downward,
        size: 13, color: Colors.white,
      );
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header row (record index + date + user) ──
        _buildTransposedHeader(records, checklist, labelW, cellW),

        // ── Info rows ──
        _buildTransposedRow(
          label: 'التاريخ', labelW: labelW, cellW: cellW,
          isLabel: true, labelBg: '#475569', labelFg: '#F1F5F9',
          cells: records.map((r) => ArabicDate.format(r.responseDate)).toList(),
        ),
        _buildTransposedRow(
          label: 'المستخدم', labelW: labelW, cellW: cellW,
          isLabel: true, labelBg: '#475569', labelFg: '#F1F5F9',
          cells: records.map((r) => _userNames[r.userId] ?? '—').toList(),
        ),
        for (final det in checklist.determinants)
          _buildTransposedRow(
            label: det.name, labelW: labelW, cellW: cellW,
            isLabel: true, labelBg: '#1D4ED8', labelFg: '#DBEAFE',
            cells: records.map((r) => r.determinantValues[det.id]?.toString() ?? '—').toList(),
          ),

        // ── Checkpoint rows (sortable) ──
        ...checklist.checkPoints.asMap().entries.map((e) {
          final ci = e.key;
          final cp = e.value;
          final isActive = _transposedSortCpId == cp.id;

          final cellData = records.map((r) {
            final data = r.checkPointRatings[cp.id];
            double rating = 0;
            String notes = '';
            String corrective = '';
            if (data is Map<String, dynamic>) {
              rating = _parseRating(data['rating']);
              notes = data['notes'] as String? ?? '';
              corrective = data['corrective_action'] as String? ?? '';
            } else {
              rating = _parseRating(data);
            }
            final images = r.getImagesForCheckpoint(cp.id);
            return (rating: rating, notes: notes, corrective: corrective, images: images, response: r);
          }).toList();

          return Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sortable checkpoint label — GestureDetector only, no InkWell
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      if (_transposedSortCpId == cp.id) {
                        _transposedSortAsc = !_transposedSortAsc;
                      } else {
                        _transposedSortCpId = cp.id;
                        _transposedSortAsc = false;
                      }
                    }),
                    child: Container(
                      width: labelW,
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      color: isActive
                          ? const Color(0xFFEDE9FE)
                          : (ci.isEven ? const Color(0xFFF0F4FF) : const Color(0xFFF8FAFC)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${ci + 1}. ${cp.title}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isActive ? const Color(0xFF5B21B6) : const Color(0xFF1E40AF),
                              ),
                            ),
                          ),
                          sortIcon(cp.id),
                        ],
                      ),
                    ),
                  ),
                ),
                // Data cells — plain Container, no InkWell, no hover
                ...cellData.map((cv) {
                  final pct = checklist.rateNumber > 0
                      ? cv.rating / checklist.rateNumber * 100
                      : 0.0;
                  final c = QColors.getPerformanceColor(pct);
                  return Container(
                    width: cellW,
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.07),
                      border: const Border(right: BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // Rating badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${_fmt(cv.rating)}/${_fmt(checklist.rateNumber.toDouble())}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c),
                          ),
                        ),
                        // Notes
                        if (cv.notes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.note_outlined, size: 10, color: const Color(0xFF3B82F6)),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(cv.notes,
                                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF1D4ED8), height: 1.35)),
                              ),
                            ],
                          ),
                        ],
                        // Corrective action
                        if (cv.corrective.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.build_outlined, size: 10, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(cv.corrective,
                                    style: const TextStyle(fontSize: 9.5, color: Color(0xFFB45309), height: 1.35)),
                              ),
                            ],
                          ),
                        ],
                        // All checkpoint images — no truncation
                        if (cv.images.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 3,
                            runSpacing: 3,
                            children: cv.images.map((img) => GestureDetector(
                              onTap: () => _showImageGallery(
                                  cv.images.map((e) => e.imageUrl).toList(), 0),
                              child: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: c.withValues(alpha: 0.3)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: Image.network(img.imageUrl, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          Icon(Icons.broken_image, size: 14, color: c)),
                                ),
                              ),
                            )).toList(),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        }),

        // ── Main notes row ──
        _buildTransposedMainNotesRow(records, checklist, labelW, cellW),

        // ── Main attachments row ──
        _buildTransposedMainAttachmentsRow(records, checklist, labelW, cellW),

        // ── Average row ──
        _buildTransposedAverageRow(records, checklist, labelW, cellW),
      ],
    );

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _transposedHCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(width: totalW, child: content),
            ),
          ),
        ),
        // Pinned horizontal scrollbar — synced via _transposedHBarCtrl
        Container(
          height: 14,
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Scrollbar(
            controller: _transposedHBarCtrl,
            thumbVisibility: true,
            trackVisibility: true,
            scrollbarOrientation: ScrollbarOrientation.bottom,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _transposedHBarCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(width: totalW, height: 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransposedHeader(
      List<QualityResponse> records, QualityChecklist checklist, double labelW, double cellW) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF1E293B)),
      child: Row(
        children: [
          SizedBox(
            width: labelW,
            height: 44,
            child: const Center(
              child: Text('نقطة التفتيش / البيانات',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          ...records.asMap().entries.map((e) {
            final ri = e.key;
            final r = e.value;
            final avg = _responseAverage(r, checklist);
            final pc = QColors.getPerformanceColor(avg);
            return Container(
              width: cellW,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                border: const Border(right: BorderSide(color: Color(0xFF334155))),
                color: pc.withValues(alpha: 0.15),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${ri + 1}',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(ArabicDate.format(r.responseDate),
                      style: const TextStyle(fontSize: 9, color: Colors.white70)),
                  Text(_userNames[r.userId] ?? '—',
                      style: const TextStyle(fontSize: 9, color: Colors.white60),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTransposedRow({
    required String label,
    required double labelW,
    required double cellW,
    required bool isLabel,
    required String labelBg,
    required String labelFg,
    required List<String> cells,
  }) {
    Color bgColor(String hex) => Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Container(
            width: labelW,
            constraints: const BoxConstraints(minHeight: 28),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: bgColor(labelBg).withValues(alpha: 0.85),
            alignment: AlignmentDirectional.centerStart,
            child: Text(label,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: bgColor(labelFg))),
          ),
          ...cells.map((v) => Container(
                width: cellW,
                constraints: const BoxConstraints(minHeight: 28),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                alignment: Alignment.center,
                child: Text(v, style: const TextStyle(fontSize: 10, color: Color(0xFF374151))),
              )),
        ],
      ),
    );
  }

  Widget _buildTransposedMainNotesRow(
      List<QualityResponse> records, QualityChecklist checklist, double labelW, double cellW) {
    final hasAny = records.any((r) => r.mainNotes != null && r.mainNotes!.isNotEmpty);
    if (!hasAny) return const SizedBox.shrink();
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: labelW,
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: const Color(0xFFEFF6FF),
              alignment: AlignmentDirectional.centerStart,
              child: const Row(
                children: [
                  Icon(Icons.note_outlined, size: 13, color: Color(0xFF1D4ED8)),
                  SizedBox(width: 6),
                  Text('الملاحظات العامة',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8))),
                ],
              ),
            ),
            ...records.map((r) {
              final notes = r.mainNotes ?? '';
              return Container(
                width: cellW,
                constraints: const BoxConstraints(minHeight: 36),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: notes.isEmpty
                    ? const Center(child: Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))))
                    : Text(notes,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF374151), height: 1.4)),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTransposedMainAttachmentsRow(
      List<QualityResponse> records, QualityChecklist checklist, double labelW, double cellW) {
    final hasAny = records.any((r) => r.images.isNotEmpty);
    if (!hasAny) return const SizedBox.shrink();
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: labelW,
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: const Color(0xFFFFF7ED),
              alignment: AlignmentDirectional.centerStart,
              child: const Row(
                children: [
                  Icon(Icons.photo_library_outlined, size: 13, color: Color(0xFFD97706)),
                  SizedBox(width: 6),
                  Text('المرفقات العامة',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
                ],
              ),
            ),
            ...records.map((r) {
              final imgs = r.images;
              return Container(
                width: cellW,
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFAFB),
                  border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: imgs.isEmpty
                    ? const Center(child: Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))))
                    : Wrap(
                        spacing: 3,
                        runSpacing: 3,
                        children: imgs.map((img) => GestureDetector(
                              onTap: () => _showImageGallery(
                                  imgs.map((e) => e.imageUrl).toList(), 0),
                              child: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: Image.network(img.imageUrl, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.broken_image, size: 16, color: Color(0xFFD97706))),
                                ),
                              ),
                            )).toList(),
                      ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTransposedAverageRow(
      List<QualityResponse> records, QualityChecklist checklist, double labelW, double cellW) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFD1FAE5),
        border: Border(top: BorderSide(color: Color(0xFF6EE7B7), width: 2)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: labelW,
            height: 40,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('المتوسط العام',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF065F46))),
              ),
            ),
          ),
          ...records.map((r) {
            final avg = _responseAverage(r, checklist);
            final c = QColors.getPerformanceColor(avg);
            return Container(
              width: cellW,
              height: 40,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.12),
                border: const Border(right: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${avg.toStringAsFixed(1)}%',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: c)),
                  Text(QColors.getPerformanceLabel(avg),
                      style: TextStyle(fontSize: 9, color: c)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Card list view ─────────────────────────────────────────

  Widget _buildResponsesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _displayedResponses.length,
      itemBuilder: (context, index) => _buildResponseCard(_displayedResponses[index], index),
    );
  }

  Widget _buildResponseCard(QualityResponse response, int index) {
    final checklist = widget.group.checklists.firstWhere(
      (c) => c.id == response.checklistId,
      orElse: () => widget.group.checklists.first,
    );
    final isExpanded = _expandedResponses.contains(response.id);
    final issues = _responseIssues[response.id] ?? [];
    final openIssues = issues.where((i) => i.status != IssueStatus.resolved).length;
    final avg = _responseAverage(response, checklist);
    final perfColor = QColors.getPerformanceColor(avg);

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _toggleExpanded(response.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Line 1: index + score + progress + label + issues + expand
                        Row(
                          children: [
                            Container(width: 3, height: 28, decoration: BoxDecoration(color: perfColor, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 8),
                            Container(
                              width: 24, height: 24,
                              decoration: BoxDecoration(color: perfColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
                              child: Center(child: Text('${index + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: perfColor))),
                            ),
                            const SizedBox(width: 8),
                            _PerformanceBadge(label: '${avg.toStringAsFixed(1)}%', color: perfColor, large: true),
                            const SizedBox(width: 6),
                            _MiniProgressBar(value: avg / 100, color: perfColor, width: 48),
                            const SizedBox(width: 6),
                            Text(QColors.getPerformanceLabel(avg), style: TextStyle(fontSize: 11, color: perfColor, fontWeight: FontWeight.w500)),
                            if (issues.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              _IssueBadge(open: openIssues, total: issues.length),
                            ],
                            const Spacer(),
                            Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                size: 18, color: const Color(0xFF9CA3AF)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        // Line 2: date + time + user + determinants
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFF9CA3AF)),
                            const SizedBox(width: 3),
                            Text(ArabicDate.format(response.responseDate),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                            const SizedBox(width: 8),
                            const Icon(Icons.person_outline_rounded, size: 12, color: Color(0xFF9CA3AF)),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(_userNames[response.userId] ?? '—',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF374151))),
                            ),
                            ...response.determinantValues.entries.take(1).map((entry) => Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFE5E7EB)),
                                  ),
                                  child: Text(entry.value.toString(),
                                      style: const TextStyle(fontSize: 9.5, color: Color(0xFF6B7280))),
                                )),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Container(width: 3, height: 28, decoration: BoxDecoration(color: perfColor, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 10),
                        Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(color: perfColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
                          child: Center(child: Text('${index + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: perfColor))),
                        ),
                        const SizedBox(width: 10),
                        _PerformanceBadge(label: '${avg.toStringAsFixed(1)}%', color: perfColor, large: true),
                        const SizedBox(width: 8),
                        _MiniProgressBar(value: avg / 100, color: perfColor, width: 56),
                        const SizedBox(width: 8),
                        Text(QColors.getPerformanceLabel(avg), style: TextStyle(fontSize: 11, color: perfColor, fontWeight: FontWeight.w500)),
                        if (issues.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          _IssueBadge(open: openIssues, total: issues.length),
                        ],
                        const SizedBox(width: 14),
                        const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 4),
                        Text(ArabicDate.format(response.responseDate),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                        const SizedBox(width: 10),
                        const Icon(Icons.schedule_outlined, size: 11, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 4),
                        Text(ArabicDate.formatTime(response.createdAt),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                        const SizedBox(width: 10),
                        const Icon(Icons.person_outline_rounded, size: 12, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(_userNames[response.userId] ?? '—',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF374151))),
                        ),
                        if (response.mainNotes != null && response.mainNotes!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: response.mainNotes!,
                            child: const Icon(Icons.sticky_note_2_outlined, size: 14, color: Color(0xFF3B82F6)),
                          ),
                        ],
                        ...response.determinantValues.entries.take(2).map((entry) => Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Text(entry.value.toString(),
                                  style: const TextStyle(fontSize: 9.5, color: Color(0xFF6B7280))),
                            )),
                        const SizedBox(width: 8),
                        Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            size: 18, color: const Color(0xFF9CA3AF)),
                      ],
                    ),
            ),
          ),
          if (isExpanded) _buildExpandedDetailTable(response, checklist),
        ],
      ),
    );
  }

  // ── Empty ──────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final hasAnyFilter = _determinantFilters.isNotEmpty ||
        _searchQuery.isNotEmpty ||
        _overallMinPct > 0 ||
        _overallMaxPct < 100;
    final message = _searchQuery.isNotEmpty
        ? 'لا توجد نتائج تطابق البحث'
        : (_overallMinPct > 0 || _overallMaxPct < 100)
            ? 'لا توجد سجلات في نطاق النسبة المحدد'
            : _determinantFilters.isNotEmpty
                ? 'لا توجد نتائج تطابق الفلاتر'
                : 'لا توجد استجابات';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(hasAnyFilter ? Icons.filter_alt_off : Icons.inbox_outlined,
              size: 44, color: const Color(0xFF9CA3AF)),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
          if (hasAnyFilter) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _overallMinPct = 0;
                  _overallMaxPct = 100;
                  _determinantFilters.clear();
                });
              },
              child: const Text('مسح جميع الفلاتر'),
            ),
          ],
        ],
      ),
    );
  }

  // ── Image gallery ──────────────────────────────────────────

  void _showImageGallery(List<String> images, int initialIndex) {
    showDialog(
      context: context,
      builder: (_) => _ImageGalleryDialog(images: images, initialIndex: initialIndex),
    );
  }

  // ── Search / sort / score-filter bar ─────────────────────

  Widget _buildSearchSortBar() {
    final checklist = _selectedChecklist;
    final sortValue = (_sortBy == 'date' ||
            _sortBy == 'average' ||
            (checklist?.checkPoints.any((cp) => cp.id == _sortBy) ?? false))
        ? _sortBy
        : 'date';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        children: [
          // Search row
          Row(
            children: [
              // Scope dropdown
              Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _searchTarget,
                    icon: const Icon(Icons.keyboard_arrow_down, size: 14, color: Color(0xFF6B7280)),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF374151)),
                    onChanged: (v) => setState(() => _searchTarget = v ?? 'all'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('الكل')),
                      DropdownMenuItem(value: 'user', child: Text('المستخدم')),
                      DropdownMenuItem(value: 'date', child: Text('التاريخ')),
                      DropdownMenuItem(value: 'notes', child: Text('الملاحظات')),
                      DropdownMenuItem(value: 'determinants', child: Text('المتغيرات')),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Search field
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'بحث في السجلات...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF9CA3AF)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Sort + score filter row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('ترتيب:',
                    style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                const SizedBox(width: 5),
                GestureDetector(
                  onTap: () => setState(() => _sortAscending = !_sortAscending),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                    ),
                    child: Row(
                      children: [
                        Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 12, color: const Color(0xFF3B82F6)),
                        const SizedBox(width: 3),
                        Text(_sortAscending ? 'تصاعدي' : 'تنازلي',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF374151))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: sortValue,
                      icon: const Icon(Icons.keyboard_arrow_down, size: 13),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF111827)),
                      onChanged: (v) => setState(() => _sortBy = v ?? 'date'),
                      items: [
                        const DropdownMenuItem(value: 'date', child: Text('التاريخ')),
                        const DropdownMenuItem(value: 'average', child: Text('المتوسط')),
                        if (checklist != null)
                          ...checklist.checkPoints.map((cp) => DropdownMenuItem(
                                value: cp.id,
                                child: Text(cp.title, overflow: TextOverflow.ellipsis),
                              )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('فلتر النسبة:',
                    style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                const SizedBox(width: 5),
                ..._buildScoreFilterChips(),
                if (_overallMinPct > 0 || _overallMaxPct < 100) ...[
                  const SizedBox(width: 5),
                  GestureDetector(
                    onTap: () => setState(() {
                      _overallMinPct = 0;
                      _overallMaxPct = 100;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.clear, size: 11, color: Color(0xFFDC2626)),
                          SizedBox(width: 3),
                          Text('مسح', style: TextStyle(fontSize: 10, color: Color(0xFFDC2626))),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildScoreFilterChips() {
    final ranges = <Map<String, dynamic>>[
      {'label': '≥ 80%', 'min': 80.0, 'max': 100.0},
      {'label': '60–79%', 'min': 60.0, 'max': 80.0},
      {'label': '50–59%', 'min': 50.0, 'max': 60.0},
      {'label': '< 50%', 'min': 0.0, 'max': 50.0},
    ];
    return ranges.map((r) {
      final min = r['min'] as double;
      final max = r['max'] as double;
      final isActive = _overallMinPct == min && _overallMaxPct == max;
      return GestureDetector(
        onTap: () => setState(() {
          if (isActive) {
            _overallMinPct = 0;
            _overallMaxPct = 100;
          } else {
            _overallMinPct = min;
            _overallMaxPct = max;
          }
        }),
        child: Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFEFF6FF) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isActive ? const Color(0xFF3B82F6) : const Color(0xFFD1D5DB),
            ),
          ),
          child: Text(
            r['label'] as String,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? const Color(0xFF1D4ED8) : const Color(0xFF374151),
            ),
          ),
        ),
      );
    }).toList();
  }

  // ── Export ─────────────────────────────────────────────────

  void _showExportDialog() {
    final checklist = _selectedChecklist;
    showDialog<_ExportOptions>(
      context: context,
      builder: (_) => _ExportOptionsDialog(
        group: widget.group,
        currentChecklist: checklist,
      ),
    ).then((opts) {
      if (opts != null) _handleExportOptions(opts);
    });
  }

  Future<void> _handleExportOptions(_ExportOptions opts) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      if (opts.reportType == _ReportType.singleDay) {
        if (opts.scope == _ExportScope.current) {
          await _exportDailyCurrentInternal(opts);
        } else {
          await _exportDailyAllInternal(opts);
        }
      } else {
        if (opts.scope == _ExportScope.current) {
          await _exportRegularCurrentInternal(opts);
        } else {
          await _exportRegularAllInternal(opts);
        }
      }
    } catch (e) {
      if (mounted) Helpers.showSnackBar(context, 'فشل في التصدير: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<QualityResponse> _getExportResponses({
    int? checklistId,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    var list = _responses;
    if (checklistId != null) {
      list = list.where((r) => r.checklistId == checklistId).toList();
    }
    if (fromDate != null) {
      list = list.where((r) => !r.responseDate.isBefore(fromDate)).toList();
    }
    if (toDate != null) {
      final end = DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);
      list = list.where((r) => !r.responseDate.isAfter(end)).toList();
    }
    if (_determinantFilters.isNotEmpty) {
      list = list.where((r) {
        return _determinantFilters.entries.every((e) {
          if (e.value == 'الكل') return true;
          return r.determinantValues[e.key]?.toString() == e.value;
        });
      }).toList();
    }
    return list;
  }

  static String _colLetter(int col) {
    if (col <= 26) return String.fromCharCode(64 + col);
    return String.fromCharCode(64 + (col - 1) ~/ 26) +
        String.fromCharCode(64 + (col - 1) % 26 + 1);
  }

  static String _cellRef(int row, int col) => '${_colLetter(col)}$row';

  static String _ratingFormulaStr(String pctRef) =>
      '=IF($pctRef>=0.85,"ممتاز",IF($pctRef>=0.70,"جيد جداً",IF($pctRef>=0.55,"جيد",IF($pctRef>=0.40,"مقبول","ضعيف"))))';

  /// Builds a nested IF formula that maps the cell value (a raw score or a 0-1 percentage)
  /// to a rating label using the checklist's own ratingScale conditions.
  /// [fromPct] = true when the cell holds a 0-1 pct that must be multiplied by rateNumber first.
  static String _buildRatingFormula(
    String cellRef,
    QualityChecklist checklist, {
    bool fromPct = false,
  }) {
    final scales = checklist.ratingScale;
    if (scales.isEmpty) {
      // Fallback to generic pct-based thresholds
      final pctRef = fromPct ? cellRef : '$cellRef/${checklist.rateNumber}';
      return _ratingFormulaStr(pctRef);
    }
    // Use ROUND to mirror getRatingLabel(avg.round()) behaviour with decimal averages
    final scoreRef = fromPct
        ? 'ROUND($cellRef*${checklist.rateNumber},0)'
        : 'ROUND($cellRef,0)';
    final buf = StringBuffer('=');
    for (int i = 0; i < scales.length; i++) {
      buf.write('IF(${_scaleCondition(scoreRef, scales[i])},"${scales[i].label}",');
    }
    buf.write('""'); // unmatched fallback
    for (int i = 0; i < scales.length; i++) { buf.write(')'); }
    return buf.toString();
  }

  static String _scaleCondition(String scoreRef, RatingScale s) {
    final min = s.minValue;
    final max = s.maxValue;
    if (min != null && max != null && min != max) {
      return 'AND($scoreRef>=$min,$scoreRef<=$max)';
    }
    final val = min ?? max ?? 0;
    return '$scoreRef=$val';
  }

  /// Returns (bgHex, fgHex) by mapping the matched ratingScale entry's
  /// sorted rank to a red→yellow→blue→green colour tier.
  // Non-static: calls instance methods _getPerformanceColorHex/FontColorHex as fallback
  (String, String) _ratingScaleColors(
      double rawScore, QualityChecklist checklist) {
    final scales = checklist.ratingScale;
    if (scales.isEmpty) {
      final pct = checklist.rateNumber > 0
          ? rawScore / checklist.rateNumber * 100
          : 50.0;
      return (_getPerformanceColorHex(pct), _getPerformanceFontColorHex(pct));
    }
    // Sort ascending so index 0 = worst, last = best
    final sorted = [...scales]
      ..sort((a, b) => (a.minValue ?? 0).compareTo(b.minValue ?? 0));

    final rounded = rawScore.round();
    int matchIdx = -1;
    for (int i = 0; i < sorted.length; i++) {
      final s = sorted[i];
      final mn = s.minValue;
      final mx = s.maxValue;
      if (mn != null && mx != null) {
        if (rounded >= mn && rounded <= mx) { matchIdx = i; break; }
      } else if (mn != null && rounded == mn) {
        matchIdx = i; break;
      }
    }
    if (matchIdx < 0) {
      // Fallback: proportional
      final pct = checklist.rateNumber > 0
          ? rawScore / checklist.rateNumber * 100
          : 50.0;
      return (_getPerformanceColorHex(pct), _getPerformanceFontColorHex(pct));
    }
    final ratio = sorted.length == 1 ? 0.5 : matchIdx / (sorted.length - 1);
    if (ratio >= 0.75) return ('#D1FAE5', '#065F46');
    if (ratio >= 0.50) return ('#DBEAFE', '#1D4ED8');
    if (ratio >= 0.25) return ('#FEF3C7', '#92400E');
    return ('#FEE2E2', '#991B1B');
  }

  Future<void> _exportDailyCurrentInternal(_ExportOptions opts) async {
    final checklist = _selectedChecklist;
    if (checklist == null || opts.singleDate == null) return;
    final date = opts.singleDate!;
    final dayResponses = _getExportResponses(
      checklistId: checklist.id,
      fromDate: date,
      toDate: date,
    );
    if (dayResponses.isEmpty) {
      if (mounted) Helpers.showSnackBar(context, 'لا توجد استجابات في هذا التاريخ', isError: true);
      return;
    }
    const totalCols = 7;
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'تقرير يوم';
    sheet.isRightToLeft = true;
    final titleRange = sheet.getRangeByIndex(1, 1, 1, totalCols)..merge();
    titleRange.setText('تقرير يوم ${ArabicDate.format(date)} — ${checklist.title}');
    titleRange.cellStyle
      ..bold = true
      ..fontSize = 16
      ..backColor = '#1E293B'
      ..fontColor = '#FFFFFF'
      ..hAlign = xlsio.HAlignType.center
      ..vAlign = xlsio.VAlignType.center;
    sheet.setRowHeightInPixels(1, 46);
    _writeDailyAverageTable(sheet, checklist, dayResponses, date,
        startRow: 3, withNotes: opts.withNotes);
    _setDailyColWidths(sheet);
    final bytes = workbook.saveAsStream();
    workbook.dispose();
    final ds = _dateStr(date);
    await _downloadExcelFile(
        Uint8List.fromList(bytes), 'تقرير_يوم_${checklist.title}_$ds.xlsx');
    if (mounted) Helpers.showSnackBar(context, 'تم التصدير بنجاح');
  }

  Future<void> _exportDailyAllInternal(_ExportOptions opts) async {
    if (opts.singleDate == null) return;
    final date = opts.singleDate!;
    const totalCols = 7;
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'تقرير يوم - جميع القوائم';
    sheet.isRightToLeft = true;
    final titleRange = sheet.getRangeByIndex(1, 1, 1, totalCols)..merge();
    titleRange.setText('تقرير يوم ${ArabicDate.format(date)} — ${widget.group.title}');
    titleRange.cellStyle
      ..bold = true
      ..fontSize = 18
      ..backColor = '#1E293B'
      ..fontColor = '#FFFFFF'
      ..hAlign = xlsio.HAlignType.center
      ..vAlign = xlsio.VAlignType.center;
    sheet.setRowHeightInPixels(1, 50);
    int currentRow = 3;
    bool wroteAny = false;
    for (final checklist in widget.group.checklists) {
      final dayResponses = _getExportResponses(
          checklistId: checklist.id, fromDate: date, toDate: date);
      if (dayResponses.isEmpty) continue;
      if (wroteAny) {
        currentRow += 2;
        for (int c = 1; c <= totalCols; c++) {
          sheet.getRangeByIndex(currentRow, c).cellStyle
            ..backColor = '#94A3B8'
            ..borders.bottom.lineStyle = xlsio.LineStyle.thick;
        }
        sheet.setRowHeightInPixels(currentRow, 4);
        currentRow += 2;
      }
      wroteAny = true;
      currentRow = _writeDailyAverageTable(sheet, checklist, dayResponses, date,
          startRow: currentRow, withNotes: opts.withNotes);
    }
    if (!wroteAny) {
      workbook.dispose();
      if (mounted) Helpers.showSnackBar(context, 'لا توجد استجابات في هذا التاريخ', isError: true);
      return;
    }

    // Append cross-checklist summary after a separator gap
    currentRow += 4;
    for (int c = 1; c <= 7; c++) {
      sheet.getRangeByIndex(currentRow - 2, c).cellStyle
        ..backColor = '#94A3B8'
        ..borders.bottom.lineStyle = xlsio.LineStyle.thick;
      sheet.setRowHeightInPixels(currentRow - 2, 4);
    }
    _writeCrossChecklistSummary(
      sheet,
      widget.group.checklists,
      date, date,
      startRow: currentRow,
      dailyLayout: true,
      setWidths: false,
    );

    _setDailyColWidths(sheet);
    final bytes = workbook.saveAsStream();
    workbook.dispose();
    final ds = _dateStr(date);
    await _downloadExcelFile(
        Uint8List.fromList(bytes), 'تقرير_يوم_جميع_القوائم_$ds.xlsx');
    if (mounted) Helpers.showSnackBar(context, 'تم التصدير بنجاح');
  }

  Future<void> _exportRegularCurrentInternal(_ExportOptions opts) async {
    final checklist = _selectedChecklist;
    if (checklist == null) {
      if (mounted) Helpers.showSnackBar(context, 'لم يتم اختيار قائمة', isError: true);
      return;
    }
    final responses = _getExportResponses(
      checklistId: checklist.id,
      fromDate: opts.fromDate,
      toDate: opts.toDate,
    );
    if (responses.isEmpty) {
      if (mounted) Helpers.showSnackBar(context, 'لا توجد بيانات للتصدير', isError: true);
      return;
    }
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = _sanitizeSheetName(checklist.title);
    sheet.isRightToLeft = true;
    await _writeChecklistToSheet(sheet, checklist, responses,
        withNotes: opts.withNotes,
        withAttachments: opts.withAttachments,
        resultFormat: opts.resultFormat,
        fromDate: opts.fromDate,
        toDate: opts.toDate);
    final bytes = workbook.saveAsStream();
    workbook.dispose();
    await _downloadExcelFile(
        Uint8List.fromList(bytes),
        'استجابات_${checklist.title}_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    if (mounted) Helpers.showSnackBar(context, 'تم التصدير بنجاح');
  }

  Future<void> _exportRegularAllInternal(_ExportOptions opts) async {
    final workbook = xlsio.Workbook();
    bool firstSheet = true;
    bool wroteAny = false;
    xlsio.Worksheet? stackedSheet;
    int stackedRow = 1;

    if (opts.layout == _SheetLayout.stacked) {
      stackedSheet = workbook.worksheets[0];
      stackedSheet.name = 'جميع القوائم';
      stackedSheet.isRightToLeft = true;
      firstSheet = false;
    }

    for (final checklist in widget.group.checklists) {
      final responses = _getExportResponses(
        checklistId: checklist.id,
        fromDate: opts.fromDate,
        toDate: opts.toDate,
      );
      if (responses.isEmpty) continue;
      wroteAny = true;

      if (opts.layout == _SheetLayout.separateSheets) {
        xlsio.Worksheet sheet;
        if (firstSheet) {
          sheet = workbook.worksheets[0];
          firstSheet = false;
        } else {
          sheet = workbook.worksheets.add();
        }
        sheet.name = _sanitizeSheetName(checklist.title);
        sheet.isRightToLeft = true;
        await _writeChecklistToSheet(sheet, checklist, responses,
            withNotes: opts.withNotes,
            withAttachments: opts.withAttachments,
            resultFormat: opts.resultFormat,
            fromDate: opts.fromDate,
            toDate: opts.toDate);
      } else {
        if (stackedRow > 1) stackedRow += 3;
        stackedRow = await _writeChecklistToSheet(
          stackedSheet!, checklist, responses,
          withNotes: opts.withNotes,
          withAttachments: opts.withAttachments,
          resultFormat: opts.resultFormat,
          fromDate: opts.fromDate,
          toDate: opts.toDate,
          startRow: stackedRow,
        );
      }
    }

    if (!wroteAny) {
      workbook.dispose();
      if (mounted) Helpers.showSnackBar(context, 'لا توجد بيانات للتصدير', isError: true);
      return;
    }

    if (opts.layout == _SheetLayout.stacked && stackedSheet != null) {
      // Append summary section after a gap
      _writeCrossChecklistSummary(
        stackedSheet,
        widget.group.checklists,
        opts.fromDate, opts.toDate,
        startRow: stackedRow + 3,
        dailyLayout: false,
        setWidths: false,
      );
    } else if (opts.layout == _SheetLayout.separateSheets) {
      // Add dedicated summary sheet at the end
      final summarySheet = workbook.worksheets.add();
      summarySheet.name = 'ملخص القوائم';
      summarySheet.isRightToLeft = true;
      _writeCrossChecklistSummary(
        summarySheet,
        widget.group.checklists,
        opts.fromDate, opts.toDate,
        startRow: 1,
        dailyLayout: false,
        setWidths: true,
      );
    }

    final bytes = workbook.saveAsStream();
    workbook.dispose();
    await _downloadExcelFile(
        Uint8List.fromList(bytes),
        'استجابات_كل_القوائم_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    if (mounted) Helpers.showSnackBar(context, 'تم التصدير بنجاح');
  }

  // ── Sheet writer ───────────────────────────────────────────

  /// Column-per-record layout: checkpoints are ROWS, each response is a COLUMN.
  /// Returns the next available row after writing.
  Future<int> _writeChecklistToSheet(
    xlsio.Worksheet sheet,
    QualityChecklist checklist,
    List<QualityResponse> responses, {
    bool withNotes = true,
    bool withAttachments = false,
    _ResultFormat resultFormat = _ResultFormat.percentage,
    DateTime? fromDate,
    DateTime? toDate,
    int startRow = 1,
  }) async {
    if (responses.isEmpty) {
      sheet.getRangeByIndex(startRow, 1).setText('لا توجد بيانات');
      return startRow + 1;
    }

    sheet.isRightToLeft = true;
    int row = startRow;
    final totalCols = responses.length + 1;

    // ── Title ──
    final titleRange = sheet.getRangeByIndex(row, 1, row, totalCols)..merge();
    titleRange.setText('استجابات ${checklist.title}');
    titleRange.cellStyle
      ..bold = true
      ..fontSize = 14
      ..backColor = '#1E293B'
      ..fontColor = '#FFFFFF'
      ..hAlign = xlsio.HAlignType.center
      ..vAlign = xlsio.VAlignType.center;
    sheet.setRowHeightInPixels(row, 40);
    row++;

    // ── Meta rows ──
    sheet.getRangeByIndex(row, 1).setText('الفترة:');
    sheet.getRangeByIndex(row, 1).cellStyle.bold = true;
    String periodText;
    if (fromDate == null && toDate == null) {
      periodText = 'كل السجلات';
    } else if (fromDate != null && toDate != null) {
      periodText = '${ArabicDate.format(fromDate)} - ${ArabicDate.format(toDate)}';
    } else if (fromDate != null) {
      periodText = 'من ${ArabicDate.format(fromDate)}';
    } else {
      periodText = 'حتى ${ArabicDate.format(toDate!)}';
    }
    sheet.getRangeByIndex(row, 2).setText(periodText);
    row++;
    sheet.getRangeByIndex(row, 1).setText('إجمالي السجلات:');
    sheet.getRangeByIndex(row, 1).cellStyle.bold = true;
    sheet.getRangeByIndex(row, 2).setText('${responses.length}');
    row += 2;

    // ── Column-header row: label col + one col per record ──
    _writeLabelCell(sheet, row, 1, 'نقطة التفتيش / البيانات', '#1E293B', '#1E293B',
        fontColor: '#FFFFFF', center: true);
    for (int ri = 0; ri < responses.length; ri++) {
      final r = responses[ri];
      final cell = sheet.getRangeByIndex(row, ri + 2);
      cell.setText('${ri + 1}\n${ArabicDate.format(r.responseDate)}\n${_userNames[r.userId] ?? "—"}');
      cell.cellStyle
        ..bold = true
        ..fontSize = 10
        ..backColor = '#334155'
        ..fontColor = '#FFFFFF'
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..wrapText = true;
      cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    }
    sheet.setRowHeightInPixels(row, 52);
    row++;

    // ── Info rows (date / time / user / determinants) ──
    _writeLabelCell(sheet, row, 1, 'التاريخ', '#475569', '#F1F5F9');
    for (int ri = 0; ri < responses.length; ri++) {
      _applyDataCell(sheet.getRangeByIndex(row, ri + 2),
          ArabicDate.format(responses[ri].responseDate), '#F8FAFC');
    }
    sheet.setRowHeightInPixels(row, 24);
    row++;

    _writeLabelCell(sheet, row, 1, 'الوقت', '#475569', '#F1F5F9');
    for (int ri = 0; ri < responses.length; ri++) {
      _applyDataCell(sheet.getRangeByIndex(row, ri + 2),
          ArabicDate.formatTime(responses[ri].createdAt), '#F8FAFC');
    }
    sheet.setRowHeightInPixels(row, 24);
    row++;

    _writeLabelCell(sheet, row, 1, 'المستخدم', '#475569', '#F1F5F9');
    for (int ri = 0; ri < responses.length; ri++) {
      _applyDataCell(sheet.getRangeByIndex(row, ri + 2),
          _userNames[responses[ri].userId] ?? '—', '#F8FAFC');
    }
    sheet.setRowHeightInPixels(row, 24);
    row++;

    for (final det in checklist.determinants) {
      _writeLabelCell(sheet, row, 1, det.name, '#1D4ED8', '#DBEAFE');
      for (int ri = 0; ri < responses.length; ri++) {
        final val = responses[ri].determinantValues[det.id];
        _applyDataCell(sheet.getRangeByIndex(row, ri + 2),
            val?.toString() ?? '—', '#EFF6FF');
      }
      sheet.setRowHeightInPixels(row, 24);
      row++;
    }

    // ── Main notes row (general response-level notes) ──
    if (withNotes && responses.any((r) => r.mainNotes?.isNotEmpty == true)) {
      _writeLabelCell(sheet, row, 1, 'الملاحظات العامة', '#1D4ED8', '#DBEAFE');
      for (int ri = 0; ri < responses.length; ri++) {
        final notes = responses[ri].mainNotes ?? '';
        final cell = sheet.getRangeByIndex(row, ri + 2);
        cell.setText(notes.isNotEmpty ? notes : '—');
        cell.cellStyle
          ..fontSize = 10
          ..hAlign = xlsio.HAlignType.center
          ..vAlign = xlsio.VAlignType.top
          ..wrapText = true
          ..backColor = '#EFF6FF';
        cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      }
      sheet.autoFitRow(row);
      final hn = sheet.getRowHeight(row);
      if (hn < 24) sheet.setRowHeightInPixels(row, 24);
      if (hn > 80) sheet.setRowHeightInPixels(row, 80);
      row++;
    }

    // ── Score format: "الحد الأقصى" row before checkpoints ──
    if (resultFormat == _ResultFormat.score) {
      _writeLabelCell(sheet, row, 1,
          'الحد الأقصى (${checklist.rateNumber})', '#1E40AF', '#DBEAFE');
      for (int ri = 0; ri < responses.length; ri++) {
        final cell = sheet.getRangeByIndex(row, ri + 2);
        cell.setNumber(checklist.rateNumber.toDouble());
        cell.cellStyle
          ..hAlign = xlsio.HAlignType.center
          ..backColor = '#EFF6FF'
          ..bold = true;
        cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      }
      sheet.setRowHeightInPixels(row, 24);
      row++;
    }

    // ── Checkpoint rows (always numeric; notes go to a separate section below) ──
    final int firstCpRow = row;
    int lastCpRow = row;

    for (int ci = 0; ci < checklist.checkPoints.length; ci++) {
      final cp = checklist.checkPoints[ci];
      final labelBg = ci.isEven ? '#F0F4FF' : '#F8FAFC';
      _writeLabelCell(sheet, row, 1, cp.title, '#1E40AF', labelBg);

      for (int ri = 0; ri < responses.length; ri++) {
        final r = responses[ri];
        final ratingData = r.checkPointRatings[cp.id];
        double rating = 0;
        if (ratingData is Map<String, dynamic>) {
          rating = _parseRating(ratingData['rating']);
        } else {
          rating = _parseRating(ratingData);
        }
        final pct = checklist.rateNumber > 0 ? (rating / checklist.rateNumber * 100) : 0.0;
        final cell = sheet.getRangeByIndex(row, ri + 2);
        if (resultFormat == _ResultFormat.score) {
          cell.setNumber(rating);
          cell.numberFormat = '0.##';
        } else {
          cell.setNumber(pct / 100);
          cell.numberFormat = '0.00%';
        }
        final cpColors = _ratingScaleColors(rating, checklist);
        cell.cellStyle
          ..backColor = cpColors.$1
          ..fontColor = cpColors.$2
          ..bold = true
          ..fontSize = 10
          ..hAlign = xlsio.HAlignType.center;
        cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      }
      // Estimate height based on label text length (wrap text, ~28 chars/line at 360px col)
      final labelLen = cp.title.length;
      final estLines = ((labelLen / 25) + 1).ceil().clamp(1, 8);
      sheet.setRowHeightInPixels(row, (estLines * 22).clamp(28, 176).toDouble());
      lastCpRow = row;
      row++;
    }

    // ── Summary rows — always use Excel formulas ──
    final int avgRow = row;
    _writeLabelCell(sheet, row, 1, 'المتوسط', '#065F46', '#D1FAE5');
    for (int ri = 0; ri < responses.length; ri++) {
      final col = ri + 2;
      final cell = sheet.getRangeByIndex(row, col);
      // AVERAGEIF works for both score (raw) and pct (0-1) range values
      cell.formula =
          '=IFERROR(AVERAGEIF(${_cellRef(firstCpRow, col)}:${_cellRef(lastCpRow, col)},">0"),0)';
      if (resultFormat == _ResultFormat.percentage) {
        cell.numberFormat = '0.00%';
      } else {
        cell.numberFormat = '0.00';
      }
      final avg = _responseAverage(responses[ri], checklist);
      final sumColors = _ratingScaleColors(avg * checklist.rateNumber / 100, checklist);
      cell.cellStyle
        ..backColor = sumColors.$1
        ..fontColor = sumColors.$2
        ..bold = true
        ..fontSize = 10
        ..hAlign = xlsio.HAlignType.center;
      cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    }
    sheet.setRowHeightInPixels(row, 28);
    row++;

    _writeLabelCell(sheet, row, 1, 'النسبة المئوية', '#065F46', '#D1FAE5');
    for (int ri = 0; ri < responses.length; ri++) {
      final col = ri + 2;
      final cell = sheet.getRangeByIndex(row, col);
      if (resultFormat == _ResultFormat.score) {
        cell.formula =
            '=IFERROR(${_cellRef(avgRow, col)}/${checklist.rateNumber},0)';
      } else {
        cell.formula = '=${_cellRef(avgRow, col)}';
      }
      cell.numberFormat = '0.00%';
      final avg = _responseAverage(responses[ri], checklist);
      final pctColors = _ratingScaleColors(avg * checklist.rateNumber / 100, checklist);
      cell.cellStyle
        ..backColor = pctColors.$1
        ..fontColor = pctColors.$2
        ..bold = true
        ..fontSize = 11
        ..hAlign = xlsio.HAlignType.center;
      cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    }
    sheet.setRowHeightInPixels(row, 28);
    row++;

    _writeLabelCell(sheet, row, 1, 'التقييم', '#065F46', '#D1FAE5');
    for (int ri = 0; ri < responses.length; ri++) {
      final col = ri + 2;
      final cell = sheet.getRangeByIndex(row, col);
      cell.formula = _buildRatingFormula(
        _cellRef(avgRow, col),
        checklist,
        fromPct: resultFormat == _ResultFormat.percentage,
      );
      final avg = _responseAverage(responses[ri], checklist);
      final ratingColors = _ratingScaleColors(avg * checklist.rateNumber / 100, checklist);
      cell.cellStyle
        ..backColor = ratingColors.$1
        ..fontColor = ratingColors.$2
        ..bold = true
        ..fontSize = 10
        ..hAlign = xlsio.HAlignType.center;
      cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    }
    sheet.setRowHeightInPixels(row, 28);
    row++;

    // ── Checkpoint notes section (separate rows after summary) ──
    if (withNotes) {
      bool wroteNotesHeader = false;
      for (int ci = 0; ci < checklist.checkPoints.length; ci++) {
        final cp = checklist.checkPoints[ci];
        bool hasNote = false;
        for (int ri = 0; ri < responses.length; ri++) {
          final rd = responses[ri].checkPointRatings[cp.id];
          if (rd is Map<String, dynamic>) {
            final n = rd['notes'] as String? ?? '';
            final ca = rd['corrective_action'] as String? ?? '';
            if (n.isNotEmpty || ca.isNotEmpty) { hasNote = true; break; }
          }
        }
        if (!hasNote) continue;
        if (!wroteNotesHeader) {
          final hdr = sheet.getRangeByIndex(row, 1, row, totalCols)..merge();
          hdr.setText('ملاحظات نقاط التفتيش');
          hdr.cellStyle
            ..bold = true
            ..backColor = '#1D4ED8'
            ..fontColor = '#FFFFFF'
            ..hAlign = xlsio.HAlignType.center
            ..vAlign = xlsio.VAlignType.center;
          sheet.setRowHeightInPixels(row, 28);
          row++;
          wroteNotesHeader = true;
        }
        _writeLabelCell(sheet, row, 1, cp.title, '#1D4ED8', '#DBEAFE');
        for (int ri = 0; ri < responses.length; ri++) {
          final rd = responses[ri].checkPointRatings[cp.id];
          final cell = sheet.getRangeByIndex(row, ri + 2);
          String text = '—';
          if (rd is Map<String, dynamic>) {
            final n = rd['notes'] as String? ?? '';
            final ca = rd['corrective_action'] as String? ?? '';
            final buf = StringBuffer();
            if (n.isNotEmpty) buf.write('📝 $n');
            if (ca.isNotEmpty) {
              if (buf.isNotEmpty) buf.write('\n');
              buf.write('🔧 $ca');
            }
            if (buf.isNotEmpty) text = buf.toString();
          }
          cell.setText(text);
          cell.cellStyle
            ..fontSize = 10
            ..hAlign = xlsio.HAlignType.center
            ..vAlign = xlsio.VAlignType.top
            ..wrapText = true
            ..backColor = '#EFF6FF';
          cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        }
        sheet.autoFitRow(row);
        final h = sheet.getRowHeight(row);
        if (h < 24) sheet.setRowHeightInPixels(row, 24);
        if (h > 100) sheet.setRowHeightInPixels(row, 100);
        row++;
      }
    }

    // ── Checkpoint attachments section (separate rows after notes) ──
    if (withAttachments) {
      bool wroteAttHeader = false;
      for (int ci = 0; ci < checklist.checkPoints.length; ci++) {
        final cp = checklist.checkPoints[ci];
        bool hasImg = false;
        for (int ri = 0; ri < responses.length; ri++) {
          if (responses[ri].getImagesForCheckpoint(cp.id).isNotEmpty) {
            hasImg = true; break;
          }
        }
        if (!hasImg) continue;
        if (!wroteAttHeader) {
          final hdr = sheet.getRangeByIndex(row, 1, row, totalCols)..merge();
          hdr.setText('مرفقات نقاط التفتيش');
          hdr.cellStyle
            ..bold = true
            ..backColor = '#7C3AED'
            ..fontColor = '#FFFFFF'
            ..hAlign = xlsio.HAlignType.center
            ..vAlign = xlsio.VAlignType.center;
          sheet.setRowHeightInPixels(row, 28);
          row++;
          wroteAttHeader = true;
        }
        _writeLabelCell(sheet, row, 1, cp.title, '#7C3AED', '#EDE9FE');
        for (int ri = 0; ri < responses.length; ri++) {
          final imgs = responses[ri].getImagesForCheckpoint(cp.id);
          final cell = sheet.getRangeByIndex(row, ri + 2);
          if (imgs.isEmpty) {
            cell.setText('—');
          } else {
            cell.setText(imgs.asMap().entries
                .map((e) => '📎 صورة ${e.key + 1}: ${e.value.imageUrl}')
                .join('\n'));
          }
          cell.cellStyle
            ..fontSize = 9
            ..hAlign = xlsio.HAlignType.center
            ..vAlign = xlsio.VAlignType.top
            ..wrapText = true
            ..backColor = '#F5F3FF';
          cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        }
        sheet.autoFitRow(row);
        final h = sheet.getRowHeight(row);
        if (h < 24) sheet.setRowHeightInPixels(row, 24);
        if (h > 100) sheet.setRowHeightInPixels(row, 100);
        row++;
      }
    }

    // ── Column widths ──
    sheet.setColumnWidthInPixels(1, 360); // wide enough for long checkpoint names
    for (int i = 2; i <= totalCols; i++) {
      sheet.autoFitColumn(i);
      final w = sheet.getColumnWidthInPixels(i);
      if (w < 110) sheet.setColumnWidthInPixels(i, 110);
      if (w > 240) sheet.setColumnWidthInPixels(i, 240);
    }

    return row;
  }

  void _writeLabelCell(
    xlsio.Worksheet sheet,
    int row,
    int col,
    String text,
    String backColor,
    String backColor2, {
    String? fontColor,
    bool center = false,
  }) {
    final cell = sheet.getRangeByIndex(row, col);
    cell.setText(text);
    cell.cellStyle
      ..bold = true
      ..fontSize = 10
      ..fontColor = fontColor ?? backColor
      ..backColor = backColor2
      ..hAlign = center ? xlsio.HAlignType.center : xlsio.HAlignType.right
      ..vAlign = xlsio.VAlignType.center
      ..wrapText = true;
    cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
  }

  void _applyDataCell(xlsio.Range cell, String text, String backColor) {
    cell.setText(text);
    cell.cellStyle
      ..fontSize = 10
      ..hAlign = xlsio.HAlignType.center
      ..vAlign = xlsio.VAlignType.center
      ..backColor = backColor;
    cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
  }

  // ── Daily-average helpers ──────────────────────────────────

  String _collectDailyCheckpointNotes(List<QualityResponse> responses, String checkPointId) {
    final notes = <String>[];
    for (final r in responses) {
      final data = r.checkPointRatings[checkPointId];
      if (data is Map<String, dynamic>) {
        final n = (data['notes'] as String?)?.trim();
        if (n != null && n.isNotEmpty) notes.add(n);
      }
    }
    if (notes.isEmpty) return '';
    return notes.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n');
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _setDailyColWidths(xlsio.Worksheet sheet) {
    sheet.setColumnWidthInPixels(1, 40);
    sheet.setColumnWidthInPixels(2, 340); // wide for checkpoint names + wrap
    sheet.setColumnWidthInPixels(3, 110);
    sheet.setColumnWidthInPixels(4, 110);
    sheet.setColumnWidthInPixels(5, 120);
    sheet.setColumnWidthInPixels(6, 130);
    sheet.setColumnWidthInPixels(7, 320);
  }

  /// Writes a cross-checklist summary table starting at [startRow].
  /// One row per checklist showing overall average %, and a final overall row.
  /// [dailyLayout] = true fits the 7-column daily sheet structure
  ///   (cols 1-2 merged for name, cols 3/4/5/6 for avg/count/pct/rating).
  /// [setWidths] = true sets column widths — use only for dedicated summary sheets.
  /// Returns the next available row after writing.
  int _writeCrossChecklistSummary(
    xlsio.Worksheet sheet,
    List<QualityChecklist> checklists,
    DateTime? fromDate,
    DateTime? toDate, {
    required int startRow,
    bool dailyLayout = false,
    bool setWidths = false,
  }) {
    final int colAvg    = 3;
    final int colCount  = dailyLayout ? 4 : 2;
    final int colPct    = dailyLayout ? 5 : -1; // -1 = no separate pct col
    final int colRating = dailyLayout ? 6 : 4;
    final int totalCols = dailyLayout ? 7 : 4;

    int row = startRow;

    // ── Title ──
    final titleRange = sheet.getRangeByIndex(row, 1, row, totalCols)..merge();
    titleRange.setText('ملخص جميع القوائم');
    titleRange.cellStyle
      ..bold = true
      ..fontSize = 14
      ..backColor = '#0F172A'
      ..fontColor = '#FFFFFF'
      ..hAlign = xlsio.HAlignType.center
      ..vAlign = xlsio.VAlignType.center;
    sheet.setRowHeightInPixels(row, 40);
    row++;

    // ── Column headers ──
    void writeHdr(int col, String text) {
      final cell = sheet.getRangeByIndex(row, col);
      cell.setText(text);
      cell.cellStyle
        ..bold = true
        ..fontSize = 10
        ..backColor = '#334155'
        ..fontColor = '#FFFFFF'
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;
    }

    if (dailyLayout) {
      final nameHdr = sheet.getRangeByIndex(row, 1, row, 2)..merge();
      nameHdr.setText('القائمة');
      nameHdr.cellStyle
        ..bold = true
        ..fontSize = 10
        ..backColor = '#334155'
        ..fontColor = '#FFFFFF'
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;
      writeHdr(3, 'المتوسط %');
      writeHdr(4, 'عدد السجلات');
      writeHdr(5, 'النسبة المئوية');
      writeHdr(6, 'التقييم');
      sheet.getRangeByIndex(row, 7).cellStyle
        ..backColor = '#334155'
        ..borders.all.lineStyle = xlsio.LineStyle.thin;
    } else {
      writeHdr(1, 'القائمة');
      writeHdr(2, 'عدد السجلات');
      writeHdr(3, 'المتوسط %');
      writeHdr(4, 'التقييم');
    }
    sheet.setRowHeightInPixels(row, 30);
    row++;

    double totalPctSum = 0;
    int totalChecklistsWithData = 0;
    int totalResponseCount = 0;
    final int firstDataRow = row;
    int lastDataRow = row;

    for (final checklist in checklists) {
      final responses = _getExportResponses(
        checklistId: checklist.id,
        fromDate: fromDate,
        toDate: toDate,
      );
      if (responses.isEmpty) continue;

      double pctSum = 0;
      for (final r in responses) {
        pctSum += _responseAverage(r, checklist); // 0-100
      }
      final avgPct = pctSum / responses.length; // 0-100
      final avgScore = avgPct * checklist.rateNumber / 100;
      totalPctSum += avgPct;
      totalChecklistsWithData++;
      totalResponseCount += responses.length;

      final clrs = _ratingScaleColors(avgScore, checklist);
      final int dataRow = row;

      // Name cell
      if (dailyLayout) {
        final nameCell = sheet.getRangeByIndex(row, 1, row, 2)..merge();
        nameCell.setText(checklist.title);
        nameCell.cellStyle
          ..bold = true
          ..wrapText = true
          ..vAlign = xlsio.VAlignType.center
          ..backColor = '#F8FAFC'
          ..borders.all.lineStyle = xlsio.LineStyle.thin;
      } else {
        final nameCell = sheet.getRangeByIndex(row, 1);
        nameCell.setText(checklist.title);
        nameCell.cellStyle
          ..bold = true
          ..wrapText = true
          ..vAlign = xlsio.VAlignType.center
          ..backColor = '#F8FAFC'
          ..borders.all.lineStyle = xlsio.LineStyle.thin;
      }

      // Count
      final countCell = sheet.getRangeByIndex(row, colCount);
      countCell.setNumber(responses.length.toDouble());
      countCell.cellStyle
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..backColor = '#F8FAFC'
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      // المتوسط % — store 0-1 with Percentage format
      final avgCell = sheet.getRangeByIndex(row, colAvg);
      avgCell.setNumber(avgPct / 100);
      avgCell.numberFormat = '0.00%';
      avgCell.cellStyle
        ..bold = true
        ..backColor = clrs.$1
        ..fontColor = clrs.$2
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      // النسبة المئوية (daily layout only — mirrors avg cell)
      if (colPct > 0) {
        final pctCell = sheet.getRangeByIndex(row, colPct);
        pctCell.formula = '=${_cellRef(dataRow, colAvg)}';
        pctCell.numberFormat = '0.00%';
        pctCell.cellStyle
          ..bold = true
          ..backColor = clrs.$1
          ..fontColor = clrs.$2
          ..hAlign = xlsio.HAlignType.center
          ..vAlign = xlsio.VAlignType.center
          ..borders.all.lineStyle = xlsio.LineStyle.thin;
      }

      // التقييم — formula using checklist ratingScale (avgCell is 0-1 → fromPct=true)
      final ratingCell = sheet.getRangeByIndex(row, colRating);
      ratingCell.formula = _buildRatingFormula(
          _cellRef(dataRow, colAvg), checklist, fromPct: true);
      ratingCell.cellStyle
        ..bold = true
        ..backColor = clrs.$1
        ..fontColor = clrs.$2
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      if (dailyLayout) {
        sheet.getRangeByIndex(row, 7).cellStyle
          ..backColor = '#F8FAFC'
          ..borders.all.lineStyle = xlsio.LineStyle.thin;
      }

      sheet.setRowHeightInPixels(row, 28);
      lastDataRow = row;
      row++;
    }

    // ── Overall row ──
    if (totalChecklistsWithData > 0) {
      final overallPct = totalPctSum / totalChecklistsWithData; // 0-100
      final overallBg = _getPerformanceColorHex(overallPct);
      final overallFg = _getPerformanceFontColorHex(overallPct);

      if (dailyLayout) {
        final lbl = sheet.getRangeByIndex(row, 1, row, 2)..merge();
        lbl.setText('المتوسط الإجمالي');
        lbl.cellStyle
          ..bold = true
          ..fontSize = 12
          ..backColor = '#1E293B'
          ..fontColor = '#FFFFFF'
          ..hAlign = xlsio.HAlignType.center
          ..vAlign = xlsio.VAlignType.center
          ..borders.all.lineStyle = xlsio.LineStyle.thin;
      } else {
        final lbl = sheet.getRangeByIndex(row, 1);
        lbl.setText('المتوسط الإجمالي');
        lbl.cellStyle
          ..bold = true
          ..fontSize = 12
          ..backColor = '#1E293B'
          ..fontColor = '#FFFFFF'
          ..hAlign = xlsio.HAlignType.center
          ..vAlign = xlsio.VAlignType.center
          ..borders.all.lineStyle = xlsio.LineStyle.thin;
      }

      final ovCountCell = sheet.getRangeByIndex(row, colCount);
      ovCountCell.setNumber(totalResponseCount.toDouble());
      ovCountCell.cellStyle
        ..bold = true
        ..backColor = '#1E293B'
        ..fontColor = '#FFFFFF'
        ..hAlign = xlsio.HAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      // Overall avg — AVERAGE of all per-checklist avg cells (all 0-1 pct values)
      final ovAvgCell = sheet.getRangeByIndex(row, colAvg);
      ovAvgCell.formula =
          '=IFERROR(AVERAGE(${_cellRef(firstDataRow, colAvg)}:${_cellRef(lastDataRow, colAvg)}),0)';
      ovAvgCell.numberFormat = '0.00%';
      ovAvgCell.cellStyle
        ..bold = true
        ..fontSize = 13
        ..backColor = overallBg
        ..fontColor = overallFg
        ..hAlign = xlsio.HAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      if (colPct > 0) {
        final ovPctCell = sheet.getRangeByIndex(row, colPct);
        ovPctCell.formula = '=${_cellRef(row, colAvg)}';
        ovPctCell.numberFormat = '0.00%';
        ovPctCell.cellStyle
          ..bold = true
          ..backColor = overallBg
          ..fontColor = overallFg
          ..hAlign = xlsio.HAlignType.center
          ..borders.all.lineStyle = xlsio.LineStyle.thin;
      }

      // Overall التقييم — generic rating formula (cross-checklist avg uses 0-1 pct)
      final ovRatingCell = sheet.getRangeByIndex(row, colRating);
      ovRatingCell.formula = _ratingFormulaStr(_cellRef(row, colAvg));
      ovRatingCell.cellStyle
        ..bold = true
        ..backColor = overallBg
        ..fontColor = overallFg
        ..hAlign = xlsio.HAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      if (dailyLayout) {
        sheet.getRangeByIndex(row, 7).cellStyle
          ..backColor = '#1E293B'
          ..borders.all.lineStyle = xlsio.LineStyle.thin;
      }

      sheet.setRowHeightInPixels(row, 36);
      row++;
    }

    if (setWidths) {
      sheet.setColumnWidthInPixels(1, 300);
      sheet.setColumnWidthInPixels(2, 100);
      sheet.setColumnWidthInPixels(3, 130);
      sheet.setColumnWidthInPixels(4, 130);
    }

    return row;
  }

  /// Writes one checklist's daily-average block to [sheet] starting at [startRow].
  /// Returns the next available row index after writing.
  int _writeDailyAverageTable(
    xlsio.Worksheet sheet,
    QualityChecklist checklist,
    List<QualityResponse> responses,
    DateTime date, {
    required int startRow,
    bool withNotes = true,
  }) {
    const int totalCols = 7;
    int row = startRow;

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

    // Date & response-count row
    final infoRange = sheet.getRangeByIndex(row, 1, row, totalCols)..merge();
    infoRange.setText('${ArabicDate.format(date)} — عدد الاستجابات: ${responses.length}');
    infoRange.cellStyle
      ..fontSize = 11
      ..backColor = '#F8FAFC'
      ..fontColor = '#64748B'
      ..hAlign = xlsio.HAlignType.right;
    sheet.setRowHeightInPixels(row, 24);
    row++;

    // Column headers
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

    // ── Max value row — shows rateNumber in المتوسط column ──
    final maxLblCell = sheet.getRangeByIndex(row, 1, row, 2)..merge();
    maxLblCell.setText('الحد الأقصى');
    maxLblCell.cellStyle
      ..bold = true
      ..fontSize = 10
      ..backColor = '#DBEAFE'
      ..fontColor = '#1E40AF'
      ..hAlign = xlsio.HAlignType.center
      ..vAlign = xlsio.VAlignType.center
      ..borders.all.lineStyle = xlsio.LineStyle.thin;
    final maxValCell = sheet.getRangeByIndex(row, 3);
    maxValCell.setNumber(checklist.rateNumber.toDouble());
    maxValCell.numberFormat = '0.##';
    maxValCell.cellStyle
      ..bold = true
      ..fontSize = 11
      ..backColor = '#DBEAFE'
      ..fontColor = '#1E40AF'
      ..hAlign = xlsio.HAlignType.center
      ..vAlign = xlsio.VAlignType.center
      ..borders.all.lineStyle = xlsio.LineStyle.thin;
    for (final c in [4, 5, 6, 7]) {
      sheet.getRangeByIndex(row, c).cellStyle
        ..backColor = '#DBEAFE'
        ..borders.all.lineStyle = xlsio.LineStyle.thin;
    }
    sheet.setRowHeightInPixels(row, 28);
    row++;

    int visibleIndex = 1;
    int firstDataRow = row;
    int lastDataRow = row;
    int cpWithData = 0;
    double overallPctSum = 0;

    for (final cp in checklist.checkPoints) {
      double totalRating = 0;
      int count = 0;
      for (final r in responses) {
        final data = r.checkPointRatings[cp.id];
        final rating = data is Map<String, dynamic>
            ? _parseRating(data['rating'])
            : _parseRating(data);
        if (rating > 0) { totalRating += rating; count++; }
      }
      if (count == 0) continue;

      final avg = totalRating / count;
      final pct = checklist.rateNumber > 0 ? (avg / checklist.rateNumber) * 100 : 0.0;
      overallPctSum += pct;
      cpWithData++;

      final bgColor = visibleIndex.isOdd ? '#FFFFFF' : '#F8FAFC';
      final notesText = _collectDailyCheckpointNotes(responses, cp.id);
      final noteLines = notesText.isEmpty ? 1 : '\n'.allMatches(notesText).length + 1;

      sheet.getRangeByIndex(row, 1).setNumber(visibleIndex.toDouble());
      sheet.getRangeByIndex(row, 1).cellStyle
        ..hAlign = xlsio.HAlignType.center
        ..backColor = bgColor
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      sheet.getRangeByIndex(row, 2).setText(cp.title);
      sheet.getRangeByIndex(row, 2).cellStyle
        ..hAlign = xlsio.HAlignType.right
        ..vAlign = xlsio.VAlignType.top
        ..wrapText = true
        ..backColor = bgColor
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      final cpClrs = _ratingScaleColors(avg, checklist);

      // المتوسط — plain number with '0.00' format (type: Number)
      final avgCell = sheet.getRangeByIndex(row, 3);
      avgCell.setNumber(avg);
      avgCell.numberFormat = '0.00';
      avgCell.cellStyle
        ..backColor = cpClrs.$1
        ..fontColor = cpClrs.$2
        ..bold = true
        ..fontSize = 12
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      sheet.getRangeByIndex(row, 4).setNumber(count.toDouble());
      sheet.getRangeByIndex(row, 4).cellStyle
        ..hAlign = xlsio.HAlignType.center
        ..backColor = bgColor
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      // النسبة المئوية — formula: =C{row}/rateNumber → 0-1, formatted as Percentage
      final pctCell = sheet.getRangeByIndex(row, 5);
      pctCell.formula = '=IFERROR(C$row/${checklist.rateNumber},0)';
      pctCell.numberFormat = '0.00%';
      pctCell.cellStyle
        ..backColor = cpClrs.$1
        ..fontColor = cpClrs.$2
        ..bold = true
        ..fontSize = 12
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      // التقييم — formula based on المتوسط (C col, raw score) via checklist ratingScale
      final ratingCell = sheet.getRangeByIndex(row, 6);
      ratingCell.formula = _buildRatingFormula('C$row', checklist);
      ratingCell.cellStyle
        ..backColor = cpClrs.$1
        ..fontColor = cpClrs.$2
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      final notesCell = sheet.getRangeByIndex(row, 7);
      if (withNotes && notesText.isNotEmpty) notesCell.setText(notesText);
      notesCell.cellStyle
        ..hAlign = xlsio.HAlignType.right
        ..vAlign = xlsio.VAlignType.top
        ..wrapText = true
        ..backColor = bgColor
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      // Row height: max of cp title lines and notes lines
      final cpLines = ((cp.title.length / 28) + 1).ceil().clamp(1, 6);
      final effectiveNoteLines = withNotes ? noteLines : 1;
      final rowLines = cpLines > effectiveNoteLines ? cpLines : effectiveNoteLines;
      sheet.setRowHeightInPixels(row, (rowLines * 20).clamp(28, 120).toDouble());

      lastDataRow = row;
      visibleIndex++;
      row++;
    }

    // ── Overall averages row ──
    if (cpWithData > 0) {
      final overallPct = overallPctSum / cpWithData;

      // Merged label cell (cols 1-2)
      final labelCell = sheet.getRangeByIndex(row, 1, row, 2)..merge();
      labelCell.setText('المتوسط الإجمالي');
      labelCell.cellStyle
        ..bold = true
        ..fontSize = 12
        ..backColor = '#1E293B'
        ..fontColor = '#FFFFFF'
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      final overallClrs = _ratingScaleColors(
          overallPct * checklist.rateNumber / 100, checklist);

      // Overall avg score — formula: average of all data rows' C column
      final overallAvgCell = sheet.getRangeByIndex(row, 3);
      overallAvgCell.formula =
          '=IFERROR(AVERAGEIF(C$firstDataRow:C$lastDataRow,">0"),0)';
      overallAvgCell.numberFormat = '0.00';
      overallAvgCell.cellStyle
        ..bold = true
        ..backColor = overallClrs.$1
        ..fontColor = overallClrs.$2
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      // Total responses
      sheet.getRangeByIndex(row, 4).setNumber(responses.length.toDouble());
      sheet.getRangeByIndex(row, 4).cellStyle
        ..bold = true
        ..backColor = '#1E293B'
        ..fontColor = '#FFFFFF'
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      // Overall النسبة المئوية — formula: C{overallRow}/rateNumber
      final overallPctCell = sheet.getRangeByIndex(row, 5);
      overallPctCell.formula = '=IFERROR(C$row/${checklist.rateNumber},0)';
      overallPctCell.numberFormat = '0.00%';
      overallPctCell.cellStyle
        ..bold = true
        ..fontSize = 13
        ..backColor = overallClrs.$1
        ..fontColor = overallClrs.$2
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      // Overall التقييم — formula based on المتوسط الإجمالي (C col) via checklist ratingScale
      final overallRatingCell = sheet.getRangeByIndex(row, 6);
      overallRatingCell.formula = _buildRatingFormula('C$row', checklist);
      overallRatingCell.cellStyle
        ..bold = true
        ..backColor = overallClrs.$1
        ..fontColor = overallClrs.$2
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      // Notes col — empty
      sheet.getRangeByIndex(row, 7).cellStyle
        ..backColor = '#1E293B'
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      sheet.setRowHeightInPixels(row, 36);
      row++;
    }

    return row;
  }

  /// Returns a valid Excel sheet name (max 31 chars, no special characters).
  String _sanitizeSheetName(String name) {
    var s = name.replaceAll(RegExp(r'[\\/*?:\[\]]'), '_').trim();
    if (s.length > 31) s = s.substring(0, 31);
    return s.isEmpty ? 'ورقة' : s;
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
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  }
}

// ─────────────────────────────────────────────────────────────
//  Small reusable widgets
// ─────────────────────────────────────────────────────────────


class _ExportButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ExportButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF059669);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download_rounded, size: 14, color: color),
              SizedBox(width: 5),
              Text('تصدير Excel',
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryKPI extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryKPI({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ],
    );
  }
}

class _PerformanceBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool large;
  const _PerformanceBadge({required this.label, required this.color, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 8 : 6, vertical: large ? 3 : 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: large ? 12 : 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _IssueBadge extends StatelessWidget {
  final int open;
  final int total;
  const _IssueBadge({required this.open, required this.total});

  @override
  Widget build(BuildContext context) {
    final allResolved = open == 0;
    final color = allResolved ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(allResolved ? Icons.check_circle_outline : Icons.report_problem_outlined, size: 10, color: color),
          const SizedBox(width: 3),
          Text('$open/$total', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  final double rating;
  final double max;
  final Color color;
  const _RatingChip({required this.rating, required this.max, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        '${_fmt(rating)} / ${_fmt(max)}',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _MiniProgressBar extends StatelessWidget {
  final double value; // 0.0–1.0
  final Color color;
  final double width;
  const _MiniProgressBar({required this.value, required this.color, this.width = 50});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          backgroundColor: color.withValues(alpha: 0.12),
          color: color,
          minHeight: 6,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text('$label: $value',
          style: const TextStyle(fontSize: 11, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w500)),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final String text;
  final String label;
  final Color color;
  const _NoteCard({required this.text, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sticky_note_2_outlined, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
                const SizedBox(height: 3),
                Text(text, style: TextStyle(fontSize: 11.5, color: color.withValues(alpha: 0.85), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineNote extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InlineNote({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Expanded(child: Text(text, style: TextStyle(fontSize: 11, color: color, height: 1.4))),
      ],
    );
  }
}

class _ImagesRow extends StatelessWidget {
  final String label;
  final List<String> images;
  final void Function(List<String>, int) onTap;
  final double size;
  const _ImagesRow({required this.label, required this.images, required this.onTap, this.size = 60});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.photo_library_outlined, size: 12, color: Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Text('$label (${images.length})', style: const TextStyle(fontSize: 10.5, color: Color(0xFF6B7280))),
        ]),
        const SizedBox(height: 5),
        SizedBox(
          height: size,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            itemBuilder: (ctx, i) => _HoverImage(url: images[i], size: size, onTap: () => onTap(images, i)),
          ),
        ),
      ],
    );
  }
}

class _HoverImage extends StatelessWidget {
  final String url;
  final double size;
  final VoidCallback onTap;
  const _HoverImage({required this.url, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.zoomIn,
        child: Container(
          margin: const EdgeInsets.only(left: 6),
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Image.network(url, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image, size: 18, color: Color(0xFF9CA3AF))),
          ),
        ),
      ),
    );
  }
}

// Issue card extracted
class _IssueCard extends StatelessWidget {
  final QualityCheckpointIssue issue;
  final Map<String, String> userNames;
  final void Function(List<String>, int) onImageTap;
  const _IssueCard({required this.issue, required this.userNames, required this.onImageTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = issue.status == IssueStatus.resolved
        ? const Color(0xFF10B981)
        : issue.status == IssueStatus.inProgress
            ? const Color(0xFF3B82F6)
            : const Color(0xFFF59E0B);

    final statusLabel = issue.status == IssueStatus.resolved
        ? 'محلولة'
        : issue.status == IssueStatus.inProgress
            ? 'قيد المعالجة'
            : 'مفتوحة';

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
            ),
            child: Row(
              children: [
                Icon(Icons.report_problem_outlined, size: 13, color: statusColor),
                const SizedBox(width: 5),
                Text('مشكلة', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: statusColor)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                ),
                const Spacer(),
                Icon(Icons.person_outline_rounded, size: 11, color: const Color(0xFF6B7280)),
                const SizedBox(width: 3),
                Text(userNames[issue.assignedTo] ?? '—',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF6B7280))),
                const SizedBox(width: 10),
                Text(ArabicDate.format(issue.createdAt),
                    style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(issue.description,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF111827), height: 1.4)),

                if (issue.issueImages.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _ImagesRow(
                    label: 'صور المشكلة',
                    images: issue.issueImages.map((e) => e.imageUrl).toList(),
                    onTap: onImageTap,
                    size: 56,
                  ),
                ],

                if (issue.status == IssueStatus.resolved) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFF6EE7B7)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 12, color: Color(0xFF065F46)),
                            const SizedBox(width: 4),
                            Text('تم الحل: ${ArabicDate.format(issue.resolvedAt!)}',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF065F46))),
                          ],
                        ),
                        if (issue.resolutionNotes?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(issue.resolutionNotes!,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF065F46))),
                        ],
                        if (issue.resolutionImages.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _ImagesRow(
                            label: 'صور الحل',
                            images: issue.resolutionImages.map((e) => e.imageUrl).toList(),
                            onTap: onImageTap,
                            size: 56,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Image Gallery Dialog
// ─────────────────────────────────────────────────────────────
class _ImageGalleryDialog extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _ImageGalleryDialog({required this.images, required this.initialIndex});

  @override
  State<_ImageGalleryDialog> createState() => _ImageGalleryDialogState();
}

class _ImageGalleryDialogState extends State<_ImageGalleryDialog> {
  late PageController _pageController;
  late int _currentIndex;
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() => _transformationController.value = Matrix4.identity();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.photo_library_outlined, size: 16, color: Colors.white60),
                const SizedBox(width: 8),
                Text('${_currentIndex + 1} / ${widget.images.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                const Spacer(),
                IconButton(
                  onPressed: _resetZoom,
                  icon: const Icon(Icons.center_focus_strong_rounded, color: Colors.white60, size: 18),
                  padding: EdgeInsets.zero,
                  tooltip: 'إعادة تعيين الزووم',
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 18),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          // Image viewer
          Expanded(
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: widget.images.length,
                  onPageChanged: (i) { setState(() => _currentIndex = i); _resetZoom(); },
                  itemBuilder: (_, i) => InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: Center(
                      child: Image.network(widget.images[i], fit: BoxFit.contain,
                          loadingBuilder: (_, child, prog) => prog == null
                              ? child
                              : Center(child: CircularProgressIndicator(
                                  value: prog.expectedTotalBytes != null
                                      ? prog.cumulativeBytesLoaded / prog.expectedTotalBytes!
                                      : null,
                                  color: Colors.white)),
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image, color: Colors.white54, size: 48)),
                    ),
                  ),
                ),
                if (widget.images.length > 1) ...[
                  Positioned(
                    left: 8, top: 0, bottom: 0,
                    child: Center(child: _GalleryNavBtn(
                      icon: Icons.chevron_left_rounded,
                      enabled: _currentIndex > 0,
                      onTap: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                    )),
                  ),
                  Positioned(
                    right: 8, top: 0, bottom: 0,
                    child: Center(child: _GalleryNavBtn(
                      icon: Icons.chevron_right_rounded,
                      enabled: _currentIndex < widget.images.length - 1,
                      onTap: () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                    )),
                  ),
                ],
              ],
            ),
          ),

          // Thumbnails
          if (widget.images.length > 1)
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              color: const Color(0xFF1E293B),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.images.length,
                itemBuilder: (_, i) {
                  final selected = i == _currentIndex;
                  return GestureDetector(
                    onTap: () => _pageController.animateToPage(i,
                        duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44, height: 44,
                      margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: selected ? const Color(0xFF3B82F6) : Colors.white24,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(widget.images[i], fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.broken_image, color: Colors.white38, size: 14)),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  View toggle button (StatelessWidget — no setState in mouse callbacks)
// ─────────────────────────────────────────────────────────────
class _ViewBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;
  const _ViewBtn({required this.icon, required this.active, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: 32,
            height: 28,
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              boxShadow: active
                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)]
                  : const [],
            ),
            child: Icon(
              icon,
              size: 15,
              color: active ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Export options dialog
// ─────────────────────────────────────────────────────────────
class _ExportOptionsDialog extends StatefulWidget {
  final QualityChecklistGroup group;
  final QualityChecklist? currentChecklist;
  const _ExportOptionsDialog({required this.group, required this.currentChecklist});
  @override
  State<_ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<_ExportOptionsDialog> {
  _ExportScope _scope = _ExportScope.current;
  _ReportType _reportType = _ReportType.regular;
  DateTime? _singleDate;
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _withNotes = true;
  bool _withAttachments = false;
  _ResultFormat _resultFormat = _ResultFormat.percentage;
  _SheetLayout _layout = _SheetLayout.stacked;

  bool get _canExport =>
      _reportType == _ReportType.singleDay ? _singleDate != null : true;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 650),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF059669),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.download_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text('تصدير Excel',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white60, size: 18),
                    ),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Scope
                      _SectionLabel('النطاق', Icons.list_alt_rounded),
                      const SizedBox(height: 8),
                      _RadioRow<_ExportScope>(
                        label: 'القائمة المحددة',
                        value: _ExportScope.current,
                        groupValue: _scope,
                        onChanged: (v) => setState(() => _scope = v!),
                      ),
                      _RadioRow<_ExportScope>(
                        label: 'جميع القوائم',
                        value: _ExportScope.all,
                        groupValue: _scope,
                        onChanged: (v) => setState(() => _scope = v!),
                      ),
                      const SizedBox(height: 14),
                      // Report type
                      _SectionLabel('نوع التقرير', Icons.description_outlined),
                      const SizedBox(height: 8),
                      _RadioRow<_ReportType>(
                        label: 'تقرير عادي',
                        value: _ReportType.regular,
                        groupValue: _reportType,
                        onChanged: (v) => setState(() => _reportType = v!),
                      ),
                      _RadioRow<_ReportType>(
                        label: 'تقرير يوم واحد',
                        value: _ReportType.singleDay,
                        groupValue: _reportType,
                        onChanged: (v) => setState(() => _reportType = v!),
                      ),
                      const SizedBox(height: 14),
                      // Conditional fields
                      if (_reportType == _ReportType.singleDay) ...[
                        _SectionLabel('التاريخ', Icons.today_rounded),
                        const SizedBox(height: 8),
                        _AFDatePickerField(
                          label: 'اختر التاريخ *',
                          value: _singleDate,
                          onPicked: (d) => setState(() => _singleDate = d),
                          onClear: () => setState(() => _singleDate = null),
                        ),
                        const SizedBox(height: 14),
                        _ToggleRow(
                          label: 'مع الملاحظات',
                          value: _withNotes,
                          onChanged: (v) => setState(() => _withNotes = v),
                        ),
                      ],
                      if (_reportType == _ReportType.regular) ...[
                        _SectionLabel(
                            'نطاق التاريخ (اختياري)', Icons.date_range_rounded),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _AFDatePickerField(
                                label: 'من تاريخ',
                                value: _fromDate,
                                onPicked: (d) => setState(() => _fromDate = d),
                                onClear: () => setState(() => _fromDate = null),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _AFDatePickerField(
                                label: 'إلى تاريخ',
                                value: _toDate,
                                onPicked: (d) => setState(() => _toDate = d),
                                onClear: () => setState(() => _toDate = null),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _ToggleRow(
                          label: 'مع الملاحظات',
                          value: _withNotes,
                          onChanged: (v) => setState(() => _withNotes = v),
                        ),
                        const SizedBox(height: 8),
                        _ToggleRow(
                          label: 'مع المرفقات (صور)',
                          value: _withAttachments,
                          onChanged: (v) => setState(() => _withAttachments = v),
                        ),
                        const SizedBox(height: 14),
                        _SectionLabel('عرض النتيجة',
                            Icons.format_list_numbered_rounded),
                        const SizedBox(height: 8),
                        _RadioRow<_ResultFormat>(
                          label: 'نسبة مئوية %',
                          value: _ResultFormat.percentage,
                          groupValue: _resultFormat,
                          onChanged: (v) =>
                              setState(() => _resultFormat = v!),
                        ),
                        _RadioRow<_ResultFormat>(
                          label: 'قيمة رقمية (الحد الأقصى في صف منفصل)',
                          value: _ResultFormat.score,
                          groupValue: _resultFormat,
                          onChanged: (v) =>
                              setState(() => _resultFormat = v!),
                        ),
                        if (_scope == _ExportScope.all) ...[
                          const SizedBox(height: 14),
                          _SectionLabel(
                              'التخطيط', Icons.table_chart_outlined),
                          const SizedBox(height: 8),
                          _RadioRow<_SheetLayout>(
                            label: 'جميع القوائم في شيت واحد',
                            value: _SheetLayout.stacked,
                            groupValue: _layout,
                            onChanged: (v) => setState(() => _layout = v!),
                          ),
                          _RadioRow<_SheetLayout>(
                            label: 'شيت منفصل لكل قائمة',
                            value: _SheetLayout.separateSheets,
                            groupValue: _layout,
                            onChanged: (v) => setState(() => _layout = v!),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              // Footer
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  border:
                      Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  children: [
                    if (_reportType == _ReportType.singleDay &&
                        _singleDate == null)
                      const Text('* اختر التاريخ للمتابعة',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFFEF4444))),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _canExport
                          ? () => Navigator.pop(
                                context,
                                _ExportOptions(
                                  scope: _scope,
                                  reportType: _reportType,
                                  singleDate: _singleDate,
                                  fromDate: _fromDate,
                                  toDate: _toDate,
                                  withNotes: _withNotes,
                                  withAttachments: _withAttachments,
                                  resultFormat: _resultFormat,
                                  layout: _layout,
                                ),
                              )
                          : null,
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('تصدير'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
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

class _SectionLabel extends StatelessWidget {
  final String text;
  final IconData icon;
  const _SectionLabel(this.text, this.icon);
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 14, color: const Color(0xFF475569)),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B))),
      ]);
}

class _RadioRow<T> extends StatelessWidget {
  final String label;
  final T value;
  final T groupValue;
  final void Function(T?) onChanged;
  const _RadioRow(
      {required this.label,
      required this.value,
      required this.groupValue,
      required this.onChanged});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => onChanged(value),
        child: Row(
          children: [
            Radio<T>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: const Color(0xFF059669),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;
  const _ToggleRow(
      {required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF059669),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
}

// ─────────────────────────────────────────────────────────────
//  (Advanced Filters Dialog removed — now rendered inline)
// ─────────────────────────────────────────────────────────────
// ignore: unused_element
class _AdvancedFiltersDialog extends StatefulWidget {
  final QualityChecklist checklist;
  final Map<String, String> userNames;
  final List<QualityResponse> responses;
  final List<FilterCondition> initialConditions;
  final Set<String> initialUserIds;
  final Map<String, Set<String>> initialDeterminantFilters;
  final DateTime? initialFromDate;
  final DateTime? initialToDate;
  final void Function(
    List<FilterCondition> conditions,
    Set<String> userIds,
    Map<String, Set<String>> detFilters,
    DateTime? fromDate,
    DateTime? toDate,
  ) onApply;

  const _AdvancedFiltersDialog({
    required this.checklist,
    required this.userNames,
    required this.responses,
    required this.initialConditions,
    required this.initialUserIds,
    required this.initialDeterminantFilters,
    required this.initialFromDate,
    required this.initialToDate,
    required this.onApply,
  });

  @override
  State<_AdvancedFiltersDialog> createState() => _AdvancedFiltersDialogState();
}

class _AdvancedFiltersDialogState extends State<_AdvancedFiltersDialog> {
  late List<FilterCondition> _conditions;
  late Set<String> _selectedUserIds;
  late Map<String, Set<String>> _detFilters;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _conditions = List.from(widget.initialConditions);
    _selectedUserIds = Set.from(widget.initialUserIds);
    _detFilters = {
      for (final e in widget.initialDeterminantFilters.entries) e.key: Set.from(e.value),
    };
    _fromDate = widget.initialFromDate;
    _toDate = widget.initialToDate;
  }

  List<MapEntry<String, String>> get _availableUsers {
    final ids = widget.responses.map((r) => r.userId).toSet();
    return ids.map((id) => MapEntry(id, widget.userNames[id] ?? id)).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
  }

  Set<String> _availableDetValues(String detId) => widget.responses
      .map((r) => r.determinantValues[detId]?.toString() ?? '')
      .where((v) => v.isNotEmpty)
      .toSet();

  double _maxForField(String fieldId) =>
      fieldId == 'average' ? 100 : widget.checklist.rateNumber.toDouble();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 620),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text('الفلاتر المتقدمة',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date range
                      const _AFSectionHeader(title: 'نطاق التاريخ', icon: Icons.date_range_rounded),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _AFDatePickerField(
                            label: 'من تاريخ',
                            value: _fromDate,
                            onPicked: (d) => setState(() => _fromDate = d),
                            onClear: () => setState(() => _fromDate = null),
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _AFDatePickerField(
                            label: 'إلى تاريخ',
                            value: _toDate,
                            onPicked: (d) => setState(() => _toDate = d),
                            onClear: () => setState(() => _toDate = null),
                          )),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // User multi-select
                      const _AFSectionHeader(title: 'المستخدمون', icon: Icons.people_outline_rounded),
                      const SizedBox(height: 8),
                      _AFMultiSelectChips(
                        items: _availableUsers.map((e) => (id: e.key, label: e.value)).toList(),
                        selected: _selectedUserIds,
                        onToggle: (id) => setState(() {
                          _selectedUserIds.contains(id)
                              ? _selectedUserIds.remove(id)
                              : _selectedUserIds.add(id);
                        }),
                      ),
                      const SizedBox(height: 16),
                      // Determinant multi-select
                      if (widget.checklist.determinants.isNotEmpty) ...[
                        const _AFSectionHeader(title: 'المتغيرات', icon: Icons.filter_alt_outlined),
                        const SizedBox(height: 8),
                        ...widget.checklist.determinants.map((det) {
                          final vals = _availableDetValues(det.id);
                          if (vals.isEmpty) return const SizedBox.shrink();
                          final selected = _detFilters[det.id] ?? {};
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(det.name,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF374151))),
                                const SizedBox(height: 4),
                                _AFMultiSelectChips(
                                  items: vals.map((v) => (id: v, label: v)).toList(),
                                  selected: selected,
                                  onToggle: (v) => setState(() {
                                    final s = _detFilters[det.id] ?? <String>{};
                                    s.contains(v) ? s.remove(v) : s.add(v);
                                    _detFilters[det.id] = s;
                                  }),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 6),
                      ],
                      // Condition builder
                      Row(
                        children: [
                          const Expanded(
                            child: _AFSectionHeader(
                                title: 'شروط الدرجات', icon: Icons.rule_rounded),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _conditions.add(FilterCondition(
                                  fieldId: 'average',
                                  op: ConditionOperator.gte,
                                  value: 60,
                                ))),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: const Color(0xFF93C5FD)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add, size: 13, color: Color(0xFF1D4ED8)),
                                  SizedBox(width: 3),
                                  Text('إضافة شرط',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF1D4ED8),
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_conditions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'لا توجد شروط. اضغط "إضافة شرط" لإضافة شرط جديد.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                          ),
                        ),
                      ..._conditions.asMap().entries.map((entry) {
                        final i = entry.key;
                        final cond = entry.value;
                        final maxVal = _maxForField(cond.fieldId);
                        final unit = cond.fieldId == 'average'
                            ? '(0–100%)'
                            : '(0–${maxVal.toInt()})';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              // Field
                              Expanded(
                                flex: 3,
                                child: _AFDropdown<String>(
                                  value: cond.fieldId,
                                  items: [
                                    const DropdownMenuItem(
                                        value: 'average',
                                        child: Text('المتوسط العام (%)')),
                                    ...widget.checklist.checkPoints.map((cp) =>
                                        DropdownMenuItem(
                                            value: cp.id,
                                            child: Text(cp.title,
                                                overflow: TextOverflow.ellipsis))),
                                  ],
                                  onChanged: (v) => setState(() =>
                                      _conditions[i] = cond.copyWith(fieldId: v, value: 0)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Operator
                              Expanded(
                                flex: 2,
                                child: _AFDropdown<ConditionOperator>(
                                  value: cond.op,
                                  items: ConditionOperator.values
                                      .map((op) => DropdownMenuItem(
                                          value: op, child: Text(op.label)))
                                      .toList(),
                                  onChanged: (v) => setState(
                                      () => _conditions[i] = cond.copyWith(op: v)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Value
                              Expanded(
                                flex: 2,
                                child: _AFValueField(
                                  value: cond.value,
                                  maxValue: maxVal,
                                  onChanged: (v) => setState(
                                      () => _conditions[i] = cond.copyWith(value: v)),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(unit,
                                  style: const TextStyle(
                                      fontSize: 9, color: Color(0xFF9CA3AF))),
                              const SizedBox(width: 6),
                              // Remove
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _conditions.removeAt(i)),
                                child: const Icon(
                                    Icons.remove_circle_outline_rounded,
                                    size: 18,
                                    color: Color(0xFFEF4444)),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _conditions.clear();
                        _selectedUserIds.clear();
                        _detFilters.clear();
                        _fromDate = null;
                        _toDate = null;
                      }),
                      icon: const Icon(Icons.clear_all, size: 16),
                      label: const Text('إعادة تعيين'),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF6B7280)),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        widget.onApply(
                            _conditions, _selectedUserIds, _detFilters, _fromDate, _toDate);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('تطبيق'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
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

// ─────────────────────────────────────────────────────────────
//  Small helper widgets for the filter dialog
// ─────────────────────────────────────────────────────────────
class _AFSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _AFSectionHeader({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 14, color: const Color(0xFF475569)),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      ]);
}

class _AFMultiSelectChips extends StatelessWidget {
  final List<({String id, String label})> items;
  final Set<String> selected;
  final void Function(String id) onToggle;
  const _AFMultiSelectChips(
      {required this.items, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('لا توجد قيم', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: items.map((item) {
        final isSelected = selected.contains(item.id);
        return GestureDetector(
          onTap: () => onToggle(item.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1E293B) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? const Color(0xFF1E293B) : const Color(0xFFD1D5DB),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  const Icon(Icons.check, size: 11, color: Colors.white),
                  const SizedBox(width: 4),
                ],
                Text(item.label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? Colors.white : const Color(0xFF374151))),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AFDatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final void Function(DateTime) onPicked;
  final VoidCallback onClear;
  const _AFDatePickerField({
    required this.label,
    required this.value,
    required this.onPicked,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: value != null ? const Color(0xFFEFF6FF) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: value != null ? const Color(0xFF3B82F6) : const Color(0xFFD1D5DB)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 14,
                color: value != null ? const Color(0xFF1D4ED8) : const Color(0xFF9CA3AF)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value != null ? ArabicDate.format(value!) : label,
                style: TextStyle(
                    fontSize: 11,
                    color:
                        value != null ? const Color(0xFF1D4ED8) : const Color(0xFF9CA3AF),
                    fontWeight:
                        value != null ? FontWeight.w600 : FontWeight.w400),
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.clear, size: 13, color: Color(0xFF6B7280)),
              ),
          ],
        ),
      ),
    );
  }
}

class _AFDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;
  const _AFDropdown(
      {required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 14),
          style: const TextStyle(fontSize: 11, color: Color(0xFF111827)),
          onChanged: onChanged,
          items: items,
        ),
      ),
    );
  }
}

class _AFValueField extends StatefulWidget {
  final double value;
  final double maxValue;
  final void Function(double) onChanged;
  const _AFValueField(
      {required this.value, required this.maxValue, required this.onChanged});

  @override
  State<_AFValueField> createState() => _AFValueFieldState();
}

class _AFValueFieldState extends State<_AFValueField> {
  late TextEditingController _ctrl;
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _fmt(widget.value));
    _focus = FocusNode();
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        final v = (double.tryParse(_ctrl.text) ?? 0).clamp(0.0, widget.maxValue);
        _ctrl.text = _fmt(v);
        widget.onChanged(v);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _AFValueField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !_focus.hasFocus) {
      _ctrl.text = _fmt(widget.value);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: TextField(
        controller: _ctrl,
        focusNode: _focus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 11),
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        onChanged: (s) {
          final v = double.tryParse(s);
          if (v != null) widget.onChanged(v.clamp(0.0, widget.maxValue));
        },
        onSubmitted: (s) {
          final v = (double.tryParse(s) ?? 0).clamp(0.0, widget.maxValue);
          _ctrl.text = _fmt(v);
          widget.onChanged(v);
        },
      ),
    );
  }
}

class _GalleryNavBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _GalleryNavBtn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.25,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}