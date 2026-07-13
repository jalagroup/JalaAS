// lib/screens/web/quality_management/quality_dashboard_screen.dart
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:jala_as/models/quality_models.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/helpers.dart';
import 'quality_colors.dart';

// ─────────────────────────────────────────────────────────────
// Arabic Date Helper
// ─────────────────────────────────────────────────────────────
class _ArabicDate {
  static const months = [
    'يناير','فبراير','مارس','أبريل','مايو','يونيو',
    'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر',
  ];
  static String format(DateTime d) => '${d.day} ${months[d.month - 1]} ${d.year}';
}

// ─────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────
const _bg        = Color(0xFFF1F5F9);
const _surface   = Color(0xFFFFFFFF);
const _border    = Color(0xFFE2E8F0);
const _textPri   = Color(0xFF0F172A);
const _textSec   = Color(0xFF64748B);
const _textMut   = Color(0xFF94A3B8);
const _blue      = Color(0xFF3B82F6);
const _green     = Color(0xFF10B981);
const _amber     = Color(0xFFF59E0B);
const _red       = Color(0xFFEF4444);
const _darkHdr   = Color(0xFF1E293B);
const _purple    = Color(0xFF8B5CF6);
const _indigo    = Color(0xFF6366F1);

const _comboPalette = [
  Color(0xFF3B82F6),
  Color(0xFF10B981),
  Color(0xFF8B5CF6),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFF06B6D4),
  Color(0xFFF97316),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
  Color(0xFF84CC16),
];

// ─────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────
class _CpStat {
  final String id;
  final String title;
  final double passPct;
  final double failPct;
  final int count;
  final String trend;

  const _CpStat({
    required this.id,
    required this.title,
    required this.passPct,
    required this.failPct,
    required this.count,
    required this.trend,
  });
}

class _ComboStat {
  final Map<String, String> comboLabels;
  final int totalResponses;
  final double overallPassPct;
  final double overallFailPct;
  final List<_CpStat> cpStats;
  final int colorIndex;

  const _ComboStat({
    required this.comboLabels,
    required this.totalResponses,
    required this.overallPassPct,
    required this.overallFailPct,
    required this.cpStats,
    required this.colorIndex,
  });

  String get comboKey => comboLabels.values.join(' | ');
}

class _ChecklistDashboard {
  final QualityChecklist checklist;
  final int totalResponses;
  final double overallPassPct;
  final double overallFailPct;
  final List<_CpStat> cpStats;
  final List<_ComboStat> comboStats;
  final bool hasDeterminants;

  const _ChecklistDashboard({
    required this.checklist,
    required this.totalResponses,
    required this.overallPassPct,
    required this.overallFailPct,
    required this.cpStats,
    required this.comboStats,
    required this.hasDeterminants,
  });
}

// ─────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────
class QualityDashboardScreen extends StatefulWidget {
  final QualityChecklistGroup group;
  const QualityDashboardScreen({super.key, required this.group});

  @override
  State<QualityDashboardScreen> createState() => _QualityDashboardScreenState();
}

class _QualityDashboardScreenState extends State<QualityDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String _period = 'current_month';
  DateTime? _from;
  DateTime? _to;
  List<_ChecklistDashboard> _dashboards = [];

  /// 'overall' or 'combos' per checklist id
  final Map<int, String> _viewMode = {};

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _initDates();
    _load();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  String _getViewMode(int checklistId) => _viewMode[checklistId] ?? 'overall';

  void _setViewMode(int checklistId, String mode) =>
      setState(() => _viewMode[checklistId] = mode);

  void _initDates() {
    final now = DateTime.now();
    switch (_period) {
      case 'current_month':
        _from = DateTime(now.year, now.month, 1);
        _to   = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'last_3_months':
        _from = DateTime(now.year, now.month - 2, 1);
        _to   = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'current_year':
        _from = DateTime(now.year, 1, 1);
        _to   = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _fadeCtrl.reset();
    try {
      final responses = await SupabaseService.getQualityResponses(
        groupId: widget.group.id,
        fromDate: _from,
        toDate: _to,
      );
      final List<_ChecklistDashboard> result = [];
      for (final cl in widget.group.checklists) {
        final clResponses =
            responses.where((r) => r.checklistId == cl.id).toList();
        // Skip checklists that have no responses — nothing useful to show
        if (clResponses.isEmpty) continue;
        result.add(_buildDashboard(cl, clResponses));
      }
      if (!mounted) return;
      setState(() {
        _dashboards = result;
        _isLoading = false;
      });
      _fadeCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Helpers.showSnackBar(context, 'فشل في تحميل البيانات', isError: true);
    }
  }

  // ── Dashboard builder ──────────────────────────────────────

  _ChecklistDashboard _buildDashboard(
      QualityChecklist cl, List<QualityResponse> responses) {
    final overall = _computeCpStats(cl, responses);
    final hasDeterminants = cl.determinants.isNotEmpty;
    final List<_ComboStat> comboStats = [];

    if (hasDeterminants && responses.isNotEmpty) {
      final Map<String, List<QualityResponse>> grouped = {};
      for (final r in responses) {
        if (r.determinantValues.isEmpty) continue;
        final parts = cl.determinants.map((d) {
          final v = r.determinantValues[d.id]?.toString() ?? '';
          return '${d.id}:$v';
        }).toList();
        final key = parts.join('||');
        grouped.putIfAbsent(key, () => []).add(r);
      }
      final sortedEntries = grouped.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));

      int colorIdx = 0;
      for (final entry in sortedEntries) {
        final groupResponses = entry.value;
        final cpStats = _computeCpStats(cl, groupResponses);
        final firstR = groupResponses.first;
        final Map<String, String> labels = {};
        for (final d in cl.determinants) {
          final val = firstR.determinantValues[d.id]?.toString() ?? '—';
          if (val.isNotEmpty && val != '—') labels[d.name] = val;
        }
        if (labels.isEmpty) { colorIdx++; continue; }

        final totalPass = cpStats.isNotEmpty
            ? cpStats.fold<double>(0, (s, c) => s + c.passPct * c.count) /
              math.max(1, cpStats.fold<int>(0, (s, c) => s + c.count))
            : 0.0;

        comboStats.add(_ComboStat(
          comboLabels: labels,
          totalResponses: groupResponses.length,
          overallPassPct: totalPass,
          overallFailPct: 100 - totalPass,
          cpStats: cpStats,
          colorIndex: colorIdx % _comboPalette.length,
        ));
        colorIdx++;
      }
    }

    final overallPass = overall.isNotEmpty
        ? overall.fold<double>(0, (s, c) => s + c.passPct * c.count) /
          math.max(1, overall.fold<int>(0, (s, c) => s + c.count))
        : 0.0;

    return _ChecklistDashboard(
      checklist: cl,
      totalResponses: responses.length,
      overallPassPct: overallPass,
      overallFailPct: 100 - overallPass,
      cpStats: overall,
      comboStats: comboStats,
      hasDeterminants: hasDeterminants,
    );
  }

  List<_CpStat> _computeCpStats(
      QualityChecklist cl, List<QualityResponse> responses) {
    final List<_CpStat> result = [];
    for (final cp in cl.checkPoints) {
      double sumRating = 0;
      int count = 0;
      for (final r in responses) {
        final rd = r.checkPointRatings[cp.id];
        double rating = 0;
        if (rd is Map<String, dynamic>) {
          rating = _parseRating(rd['rating']);
        } else {
          rating = _parseRating(rd);
        }
        if (rating > 0) { sumRating += rating; count++; }
      }
      final avg = count > 0 ? sumRating / count : 0.0;
      final pct = cl.rateNumber > 0 ? (avg / cl.rateNumber * 100) : 0.0;
      final failPct = math.max(0.0, 100 - pct);
      String trend = '→';
      if (pct >= 70) trend = '↑';
      else if (pct < 50) trend = '↓';
      result.add(_CpStat(
        id: cp.id, title: cp.title,
        passPct: pct, failPct: failPct,
        count: count, trend: trend,
      ));
    }
    return result;
  }

  double _parseRating(dynamic raw) {
    if (raw == null) return 0.0;
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0.0;
  }

  void _onPeriodChanged(String? p) {
    if (p == null) return;
    setState(() => _period = p);
    _initDates();
    _load();
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Container(
        color: _bg,
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: QColors.primary))
                  : _dashboards.isEmpty
                      ? _buildEmpty()
                      : FadeTransition(
                          opacity: _fadeAnim,
                          child: ListView(
                            padding: const EdgeInsets.all(14),
                            children: _dashboards.map(_buildChecklistCard).toList(),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────

  Widget _buildTopBar() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final datePill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.date_range_rounded, size: 13, color: _textSec),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${_ArabicDate.format(_from!)}  ←  ${_ArabicDate.format(_to!)}',
              style: const TextStyle(
                  fontSize: 11, color: _textPri, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bar_chart_rounded, size: 18, color: _textSec),
                    const SizedBox(width: 6),
                    const Text('لوحة المراقبة',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _textPri)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(child: datePill),
                    const SizedBox(width: 8),
                    _PeriodDropdown(value: _period, onChanged: _onPeriodChanged),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                datePill,
                const SizedBox(width: 12),
                _PeriodDropdown(value: _period, onChanged: _onPeriodChanged),
                const Spacer(),
                const Icon(Icons.bar_chart_rounded, size: 18, color: _textSec),
                const SizedBox(width: 6),
                const Text('لوحة المراقبة',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textPri)),
              ],
            ),
    );
  }

  // ── Checklist card ─────────────────────────────────────────

  Widget _buildChecklistCard(_ChecklistDashboard dash) {
    final mode = _getViewMode(dash.checklist.id);
    final showCombos = mode == 'combos';
    final hasCombos = dash.hasDeterminants && dash.comboStats.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(dash),
          _buildViewToggle(dash, mode, hasCombos),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: showCombos
                ? _buildCombosBody(dash)
                : _buildOverallBody(dash),
          ),
        ],
      ),
    );
  }

  // ── Card header ────────────────────────────────────────────

  Widget _buildCardHeader(_ChecklistDashboard dash) {
    final passColor = _passColor(dash.overallPassPct);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: const BoxDecoration(
        color: _darkHdr,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(11),
          topRight: Radius.circular(11),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.checklist_rtl_rounded,
                size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dash.checklist.title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                Row(
                  children: [
                    Text('${dash.totalResponses} استجابة',
                        style: const TextStyle(fontSize: 11, color: Colors.white60)),
                    if (dash.hasDeterminants && dash.comboStats.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _purple.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _purple.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          '${dash.comboStats.length} تركيبة',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white70),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          _StatBadge(
            label: 'نجاح',
            value: '${dash.overallPassPct.toStringAsFixed(1)}%',
            color: passColor,
          ),
          const SizedBox(width: 8),
          _StatBadge(
            label: 'إخفاق',
            value: '${dash.overallFailPct.toStringAsFixed(1)}%',
            color: _red,
          ),
        ],
      ),
    );
  }

  // ── Prominent view toggle ──────────────────────────────────

  Widget _buildViewToggle(
      _ChecklistDashboard dash, String mode, bool hasCombos) {
    final isOverall = mode == 'overall';
    final isMobile = MediaQuery.of(context).size.width < 600;

    Widget? infoChip;
    if (isOverall) {
      infoChip = _InfoChip(
        icon: Icons.info_outline_rounded,
        label: '${dash.cpStats.length} نقطة فحص  ·  ${dash.totalResponses} استجابة',
        color: _blue,
      );
    } else if (hasCombos) {
      infoChip = _InfoChip(
        icon: Icons.account_tree_rounded,
        label:
            '${dash.comboStats.length} تركيبة  ·  ${dash.comboStats.fold(0, (s, c) => s + c.totalResponses)} استجابة',
        color: _purple,
      );
    } else if (dash.hasDeterminants) {
      infoChip = _InfoChip(
        icon: Icons.warning_amber_rounded,
        label: 'لا توجد استجابات بمحددات في هذه الفترة',
        color: _amber,
      );
    }

    final togglePills = Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TogglePill(
            label: 'الإحصائيات العامة',
            icon: Icons.bar_chart_rounded,
            active: isOverall,
            activeColor: _blue,
            onTap: () => _setViewMode(dash.checklist.id, 'overall'),
          ),
          const SizedBox(width: 4),
          _TogglePill(
            label: hasCombos
                ? 'حسب المحددات  •  ${dash.comboStats.length}'
                : 'حسب المحددات',
            icon: Icons.account_tree_rounded,
            active: !isOverall,
            activeColor: _purple,
            disabled: !hasCombos,
            onTap: hasCombos
                ? () => _setViewMode(dash.checklist.id, 'combos')
                : null,
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOverall
              ? [const Color(0xFFEFF6FF), const Color(0xFFF0FDF4)]
              : [const Color(0xFFF5F3FF), const Color(0xFFEDE9FE)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        border: const Border(
          top: BorderSide(color: _border),
          bottom: BorderSide(color: _border),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                togglePills,
                if (infoChip != null) ...[
                  const SizedBox(height: 8),
                  infoChip,
                ],
              ],
            )
          : Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, size: 16, color: _textSec),
                const SizedBox(width: 8),
                const Text(
                  'عرض البيانات:',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: _textSec),
                ),
                const SizedBox(width: 14),
                togglePills,
                const Spacer(),
                if (infoChip != null) infoChip,
              ],
            ),
    );
  }

  // ── Overall body ───────────────────────────────────────────

  Widget _buildOverallBody(_ChecklistDashboard dash) {
    return KeyedSubtree(
      key: const ValueKey('overall'),
      child: LayoutBuilder(builder: (ctx, constraints) {
        final wide = constraints.maxWidth > 700;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildTable(
                  dash.cpStats, dash.checklist,
                  dash.overallPassPct, dash.overallFailPct,
                ),
              ),
              Container(
                  width: 1,
                  color: _border,
                  margin: const EdgeInsets.symmetric(vertical: 12)),
              Expanded(
                flex: 4,
                child: _buildCharts(
                  dash.cpStats, dash.overallPassPct, dash.overallFailPct,
                ),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              _buildTable(
                dash.cpStats, dash.checklist,
                dash.overallPassPct, dash.overallFailPct,
              ),
              const Divider(height: 1, color: _border),
              _buildCharts(
                dash.cpStats, dash.overallPassPct, dash.overallFailPct,
              ),
            ],
          );
        }
      }),
    );
  }

  // ── Combos body – full-width list ──────────────────────────

  Widget _buildCombosBody(_ChecklistDashboard dash) {
    if (dash.comboStats.isEmpty) {
      return KeyedSubtree(
        key: const ValueKey('combos'),
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.account_tree_outlined,
                    size: 36, color: _purple.withValues(alpha: 0.3)),
                const SizedBox(height: 10),
                const Text(
                  'لا توجد بيانات محددات في هذه الفترة',
                  style: TextStyle(fontSize: 13, color: _textSec),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return KeyedSubtree(
      key: const ValueKey('combos'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDeterminantLegend(dash.checklist),
          ...dash.comboStats.asMap().entries.map(
                (e) => _buildFullWidthComboCard(e.value, e.key),
              ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  // ── Determinant legend bar ─────────────────────────────────

  Widget _buildDeterminantLegend(QualityChecklist cl) {
    if (cl.determinants.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF5FF),
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.label_outline_rounded, size: 13, color: _indigo),
          const SizedBox(width: 8),
          const Text(
            'المحددات:',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: _indigo),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: cl.determinants
                  .map((d) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: _indigo.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: _indigo.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              d.name,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _indigo),
                            ),
                            if (d.options.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(${d.options.length})',
                                style: const TextStyle(
                                    fontSize: 10, color: _textMut),
                              ),
                            ],
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Combo header stats (response chip + pass/fail badges) ────

  Widget _buildComboStats(
      _ComboStat combo, Color accentColor, Color passColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_rounded,
                  size: 13, color: accentColor.withValues(alpha: 0.8)),
              const SizedBox(width: 5),
              Text(
                '${combo.totalResponses} استجابة',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _StatBadge(
          label: 'نجاح',
          value: '${combo.overallPassPct.toStringAsFixed(1)}%',
          color: passColor,
        ),
        const SizedBox(width: 6),
        _StatBadge(
          label: 'إخفاق',
          value: '${combo.overallFailPct.toStringAsFixed(1)}%',
          color: _red,
        ),
      ],
    );
  }

  // ── Full-width combo card (mirrors main card layout) ───────

  Widget _buildFullWidthComboCard(_ComboStat combo, int index) {
    final accentColor = _comboPalette[combo.colorIndex];
    final passColor = _passColor(combo.overallPassPct);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Combo header ──────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.09),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(9),
                topRight: Radius.circular(9),
              ),
              border: Border(
                  bottom: BorderSide(color: accentColor.withValues(alpha: 0.2))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Index badge
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Determinant tags
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: combo.comboLabels.entries
                            .map((e) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: accentColor.withValues(alpha: 0.25)),
                                  ),
                                  child: RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${e.key}: ',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: accentColor.withValues(alpha: 0.75),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        TextSpan(
                                          text: e.value,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: accentColor,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    if (!isMobile) ...[
                      const SizedBox(width: 12),
                      _buildComboStats(combo, accentColor, passColor),
                    ],
                  ],
                ),
                if (isMobile) ...[
                  const SizedBox(height: 8),
                  _buildComboStats(combo, accentColor, passColor),
                ],
              ],
            ),
          ),

          // ── Table + Charts (exact same layout as main card) ──
          LayoutBuilder(builder: (ctx, constraints) {
            final wide = constraints.maxWidth > 700;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildComboTable(
                      combo.cpStats,
                      combo.overallPassPct,
                      combo.overallFailPct,
                      accentColor,
                    ),
                  ),
                  Container(
                    width: 1,
                    color: accentColor.withValues(alpha: 0.15),
                    margin: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  Expanded(
                    flex: 4,
                    child: _buildComboCharts(
                      combo.cpStats,
                      combo.overallPassPct,
                      combo.overallFailPct,
                    ),
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildComboTable(
                    combo.cpStats,
                    combo.overallPassPct,
                    combo.overallFailPct,
                    accentColor,
                  ),
                  Divider(height: 1, color: accentColor.withValues(alpha: 0.15)),
                  _buildComboCharts(
                    combo.cpStats,
                    combo.overallPassPct,
                    combo.overallFailPct,
                  ),
                ],
              );
            }
          }),
        ],
      ),
    );
  }

  // ── Combo table (mirrors _buildTable exactly) ──────────────

  Widget _buildComboTable(
    List<_CpStat> cpStats,
    double overallPassPct,
    double overallFailPct,
    Color accentColor,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: accentColor.withValues(alpha: 0.06),
          child: const Row(
            children: [
              SizedBox(width: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'نقطة الفحص',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _textPri),
                ),
              ),
              SizedBox(width: 8),
              _TH('FAIL MTD %', 72),
              SizedBox(width: 8),
              _TH('PASS MTD %', 72),
            ],
          ),
        ),
        ...cpStats.asMap().entries.map((e) {
          final i = e.key;
          final cp = e.value;
          final passC = _passColor(cp.passPct);
          final failC = _failColor(cp.failPct);
          return Container(
            color: i.isEven ? _surface : const Color(0xFFFAFAFB),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              children: [
                _TrendIcon(trend: cp.trend, pct: cp.passPct),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(cp.title,
                      style: const TextStyle(fontSize: 11, color: _textPri),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _ArrowIcon(up: false, color: failC),
                      const SizedBox(width: 4),
                      Text('${cp.failPct.toStringAsFixed(0)}%',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: failC)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _ArrowIcon(up: true, color: passC),
                      const SizedBox(width: 4),
                      Text('${cp.passPct.toStringAsFixed(0)}%',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: passC)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        Container(
          color: accentColor.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const SizedBox(width: 30),
              const Expanded(
                child: Text('المجموع الكلي',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _textPri)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: Text('${overallFailPct.toStringAsFixed(0)}%',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _red)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: Text('${overallPassPct.toStringAsFixed(0)}%',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _passColor(overallPassPct))),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Combo charts (mirrors _buildCharts exactly) ────────────

  Widget _buildComboCharts(
    List<_CpStat> cpStats,
    double overallPassPct,
    double overallFailPct,
  ) {
    final passColor = _passColor(overallPassPct);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PASS MTD %',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _textPri)),
                const SizedBox(height: 10),
                ...cpStats.map((cp) {
                  final passC = _passColor(cp.passPct);
                  final shortTitle = cp.title.length > 22
                      ? '${cp.title.substring(0, 22)}...'
                      : cp.title;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(shortTitle,
                                  style: const TextStyle(
                                      fontSize: 10, color: _textSec)),
                            ),
                            Text('${cp.passPct.toStringAsFixed(0)}%',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: passC)),
                          ],
                        ),
                        const SizedBox(height: 3),
                        _HorizontalBar(value: cp.passPct / 100, color: passC),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              const Text('MTD %',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _textPri)),
              const SizedBox(height: 10),
              SizedBox(
                width: 100, height: 100,
                child: CustomPaint(
                  painter: _DonutPainter(
                    passPct: overallPassPct / 100,
                    passColor: passColor,
                    failColor: _red.withValues(alpha: 0.25),
                  ),
                  child: Center(
                    child: Text(
                      '${overallPassPct.toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: passColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _DonutLegend(
                passColor: passColor,
                failPct: overallFailPct,
                passPct: overallPassPct,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Overall Table ──────────────────────────────────────────

  Widget _buildTable(
    List<_CpStat> cpStats,
    QualityChecklist cl,
    double overallPassPct,
    double overallFailPct,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: const Color(0xFFF1F5F9),
          child: const Row(
            children: [
              SizedBox(width: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text('نقطة الفحص',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _textPri)),
              ),
              SizedBox(width: 8),
              _TH('FAIL MTD %', 72),
              SizedBox(width: 8),
              _TH('PASS MTD %', 72),
            ],
          ),
        ),
        ...cpStats.asMap().entries.map((e) {
          final i = e.key;
          final cp = e.value;
          final isEven = i.isEven;
          final passC = _passColor(cp.passPct);
          final failC = _failColor(cp.failPct);
          return Container(
            color: isEven ? _surface : const Color(0xFFFAFAFB),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              children: [
                _TrendIcon(trend: cp.trend, pct: cp.passPct),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(cp.title,
                      style: const TextStyle(fontSize: 11, color: _textPri),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _ArrowIcon(up: false, color: failC),
                      const SizedBox(width: 4),
                      Text('${cp.failPct.toStringAsFixed(0)}%',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: failC)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _ArrowIcon(up: true, color: passC),
                      const SizedBox(width: 4),
                      Text('${cp.passPct.toStringAsFixed(0)}%',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: passC)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        Container(
          color: const Color(0xFFEFF6FF),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const SizedBox(width: 30),
              const Expanded(
                child: Text('المجموع الكلي',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _textPri)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: Text('${overallFailPct.toStringAsFixed(0)}%',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _red)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: Text('${overallPassPct.toStringAsFixed(0)}%',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _green)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Overall Charts ─────────────────────────────────────────

  Widget _buildCharts(
    List<_CpStat> cpStats,
    double overallPassPct,
    double overallFailPct,
  ) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildHorizontalBars(cpStats)),
          const SizedBox(width: 16),
          _buildDonut(overallPassPct, overallFailPct),
        ],
      ),
    );
  }

  Widget _buildHorizontalBars(List<_CpStat> cpStats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PASS MTD %',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: _textPri)),
        const SizedBox(height: 10),
        ...cpStats.map((cp) {
          final passC = _passColor(cp.passPct);
          final shortTitle = cp.title.length > 22
              ? '${cp.title.substring(0, 22)}...'
              : cp.title;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(shortTitle,
                          style: const TextStyle(
                              fontSize: 10, color: _textSec)),
                    ),
                    Text('${cp.passPct.toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: passC)),
                  ],
                ),
                const SizedBox(height: 3),
                _HorizontalBar(value: cp.passPct / 100, color: passC),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDonut(double overallPassPct, double overallFailPct) {
    final passColor = _passColor(overallPassPct);
    return Column(
      children: [
        const Text('MTD %',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: _textPri)),
        const SizedBox(height: 10),
        SizedBox(
          width: 100, height: 100,
          child: CustomPaint(
            painter: _DonutPainter(
              passPct: overallPassPct / 100,
              passColor: passColor,
              failColor: _red.withValues(alpha: 0.25),
            ),
            child: Center(
              child: Text(
                '${overallPassPct.toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: passColor),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _DonutLegend(
          passColor: passColor,
          failPct: overallFailPct,
          passPct: overallPassPct,
        ),
      ],
    );
  }

  // ── Empty ──────────────────────────────────────────────────

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: _textMut),
          SizedBox(height: 12),
          Text(
            'لا توجد بيانات في هذه الفترة',
            style: TextStyle(
                fontSize: 13, color: _textSec, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── Color helpers ──────────────────────────────────────────

  Color _passColor(double pct) {
    if (pct >= 70) return _green;
    if (pct >= 50) return _amber;
    return _red;
  }

  Color _failColor(double pct) {
    if (pct >= 60) return _red;
    if (pct >= 40) return _amber;
    return _green;
  }
}

// ─────────────────────────────────────────────────────────────
// Toggle Pill
// ─────────────────────────────────────────────────────────────
class _TogglePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool disabled;
  final Color activeColor;
  final VoidCallback? onTap;

  const _TogglePill({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    this.disabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = active ? activeColor : Colors.transparent;
    final Color labelColor = active
        ? Colors.white
        : (disabled ? _textMut : _textSec);

    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(7),
            boxShadow: active
                ? [BoxShadow(color: activeColor.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: labelColor),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: labelColor,
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
// Info Chip
// ─────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────

class _PeriodDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;
  const _PeriodDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 15, color: _textSec),
          style: const TextStyle(fontSize: 11, color: _textPri),
          onChanged: onChanged,
          items: const [
            DropdownMenuItem(
                value: 'current_month', child: Text('الشهر الحالي')),
            DropdownMenuItem(
                value: 'last_3_months', child: Text('آخر 3 أشهر')),
            DropdownMenuItem(
                value: 'current_year', child: Text('السنة الحالية')),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBadge(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w800)),
        ],
      ),
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
      child: Text(text,
          textAlign: TextAlign.end,
          style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: _textPri)),
    );
  }
}

class _TrendIcon extends StatelessWidget {
  final String trend;
  final double pct;
  const _TrendIcon({required this.trend, required this.pct});

  @override
  Widget build(BuildContext context) {
    Color c;
    IconData icon;
    if (trend == '↑') {
      c = _green;
      icon = Icons.arrow_upward_rounded;
    } else if (trend == '↓') {
      c = _red;
      icon = Icons.arrow_downward_rounded;
    } else {
      c = _amber;
      icon = Icons.remove_rounded;
    }
    return SizedBox(
      width: 22, height: 22,
      child: Container(
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 12, color: c),
      ),
    );
  }
}

class _ArrowIcon extends StatelessWidget {
  final bool up;
  final Color color;
  const _ArrowIcon({required this.up, required this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(
      up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
      size: 11,
      color: color,
    );
  }
}

class _HorizontalBar extends StatelessWidget {
  final double value;
  final Color color;
  const _HorizontalBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final w = c.maxWidth;
      return Stack(
        children: [
          Container(
            height: 10,
            width: w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          Container(
            height: 10,
            width: w * value.clamp(0, 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ],
      );
    });
  }
}

class _DonutLegend extends StatelessWidget {
  final Color passColor;
  final double passPct;
  final double failPct;
  const _DonutLegend(
      {required this.passColor, required this.passPct, required this.failPct});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _legendRow(passColor, 'نجاح ${passPct.toStringAsFixed(0)}%'),
        const SizedBox(height: 4),
        _legendRow(_red.withValues(alpha: 0.6), 'إخفاق ${failPct.toStringAsFixed(0)}%'),
      ],
    );
  }

  Widget _legendRow(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 9.5, color: _textSec)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Donut Painter
// ─────────────────────────────────────────────────────────────
class _DonutPainter extends CustomPainter {
  final double passPct;
  final Color passColor;
  final Color failColor;

  const _DonutPainter(
      {required this.passPct,
      required this.passColor,
      required this.failColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) - 6;
    const strokeW = 14.0;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..color = failColor;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, bgPaint);

    if (passPct > 0) {
      final fgPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round
        ..color = passColor;
      canvas.drawArc(rect, -math.pi / 2,
          math.pi * 2 * passPct.clamp(0.0, 1.0), false, fgPaint);
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.passPct != passPct || old.passColor != passColor;
}