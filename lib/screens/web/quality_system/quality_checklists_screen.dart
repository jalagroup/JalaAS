// lib/screens/web/quality_checklists_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jala_as/models/quality_models.dart';
import 'package:jala_as/screens/web/quality_system/quality_checklist_form_screen.dart';
import '../../../models/user.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';
import 'dart:ui' as ui;

class QualityChecklistsScreen extends StatefulWidget {
  final AppUser user;

  const QualityChecklistsScreen({
    super.key,
    required this.user,
  });

  @override
  State<QualityChecklistsScreen> createState() =>
      _QualityChecklistsScreenState();
}

class _QualityChecklistsScreenState extends State<QualityChecklistsScreen> {
  List<QualityChecklistGroup> _checklistGroups = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // ── History state ──────────────────────────────────────────────────────────
  final Map<int, bool> _historyExpanded = {};
  final Map<int, bool> _historyLoading = {};
  final Map<int, List<QualityResponse>> _recentResponses = {};

  @override
  void initState() {
    super.initState();
    _loadAssignedGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Load groups ──────────────────────────────────────────────────────────

  Future<void> _loadAssignedGroups() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Uses auth.uid() internally — no need to pass userId
      final groups = await SupabaseService.getAssignedQualityGroupsForUser();

      if (!mounted) return;
      setState(() {
        _checklistGroups = groups;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      Helpers.showSnackBar(
        context,
        'فشل في تحميل قوائم مراقبة الجودة: $e',
        isError: true,
      );
    }
  }

  // ─── Filtered groups ──────────────────────────────────────────────────────

  List<QualityChecklistGroup> get _filteredGroups {
    if (_searchQuery.isEmpty) return _checklistGroups;
    final q = _searchQuery.toLowerCase();
    return _checklistGroups.where((group) {
      if (group.title.toLowerCase().contains(q)) return true;
      if (group.description?.toLowerCase().contains(q) ?? false) return true;
      if (group.checklists.any((c) => c.title.toLowerCase().contains(q)))
        return true;
      return false;
    }).toList();
  }

  int get _totalChecklists =>
      _filteredGroups.fold(0, (sum, g) => sum + g.checklists.length);

  // ─── Navigate to form ─────────────────────────────────────────────────────

  void _handleChecklistTap(QualityChecklist checklist) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => QualityChecklistFormScreen(
            user: widget.user,
            checklistId: checklist.id,
          ),
        ))
        .then((_) {
      // Find the group this checklist belongs to and refresh only its history.
      final group = _checklistGroups.where(
        (g) => g.checklists.any((c) => c.id == checklist.id),
      ).firstOrNull;
      if (group != null) {
        _recentResponses.remove(group.id);
        setState(() => _historyExpanded[group.id] = true);
        _loadGroupHistory(group.id);
      }
    });
  }

  void _handleViewTap(QualityChecklistGroup group, QualityResponse response) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QualityChecklistFormScreen(
        user: widget.user,
        checklistId: response.checklistId,
        existingResponse: response,
        readOnly: true,
      ),
    ));
  }

  void _handleEditTap(QualityChecklistGroup group, QualityResponse response) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => QualityChecklistFormScreen(
            user: widget.user,
            checklistId: response.checklistId,
            existingResponse: response,
          ),
        ))
        .then((_) {
      _recentResponses.remove(group.id);
      setState(() => _historyExpanded[group.id] = true);
      _loadGroupHistory(group.id);
    });
  }

  // ─── History helpers ───────────────────────────────────────────────────────

  void _toggleHistory(QualityChecklistGroup group) {
    final expanded = !(_historyExpanded[group.id] ?? false);
    setState(() => _historyExpanded[group.id] = expanded);
    if (expanded && !_recentResponses.containsKey(group.id)) {
      _loadGroupHistory(group.id);
    }
  }

  Future<void> _loadGroupHistory(int groupId) async {
    setState(() => _historyLoading[groupId] = true);
    try {
      final responses = await SupabaseService.getRecentQualityResponses(groupId);
      if (!mounted) return;
      setState(() {
        _recentResponses[groupId] = responses;
        _historyLoading[groupId] = false;
      });
    } catch (_) {
      if (mounted) setState(() => _historyLoading[groupId] = false);
    }
  }

  String _formatSubmittedAt(DateTime dt) {
    final local = dt.toLocal();
    final arabicMonths = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    final time = DateFormat('hh:mm a').format(local);
    return '${local.day} ${arabicMonths[local.month - 1]} - $time';
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isMobile = screenWidth < 768;
    final maxWidth = isDesktop ? 800.0 : double.infinity;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: _LightAppBar(isDesktop: isDesktop),
        body: _isLoading
            ? _buildLoading(isMobile)
            : Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: RefreshIndicator(
                    onRefresh: _loadAssignedGroups,
                    color: const Color(0xFF8B5CF6),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(isMobile ? 16 : 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(isMobile),
                          SizedBox(height: isMobile ? 16 : 20),
                          // Error box (shows when something went wrong)
                          if (_errorMessage != null) ...[
                            _buildErrorBox(isMobile),
                            SizedBox(height: isMobile ? 16 : 20),
                          ],
                          if (_filteredGroups.isNotEmpty) ...[
                            _buildStatsBar(isMobile),
                            SizedBox(height: isMobile ? 16 : 20),
                          ],
                          if (_filteredGroups.isEmpty)
                            _buildEmptyState(isMobile)
                          else
                            ..._filteredGroups.map(
                              (group) => _buildGroupCard(group, isMobile),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ─── Loading ──────────────────────────────────────────────────────────────

  Widget _buildLoading(bool isMobile) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor:
                  AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'جارٍ تحميل القوائم المُسندة إليك...',
            style: TextStyle(
                fontSize: isMobile ? 13 : 15,
                color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ─── Error box ────────────────────────────────────────────────────────────

  Widget _buildErrorBox(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline_rounded,
                  color: Color(0xFFEF4444), size: 16),
              SizedBox(width: 8),
              Text(
                'حدث خطأ أثناء التحميل',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF991B1B)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? '',
            style: const TextStyle(
                fontSize: 11, color: Color(0xFFB91C1C)),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _loadAssignedGroups,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('إعادة المحاولة',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.checklist_outlined,
                    color: Color(0xFF8B5CF6), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تقارير مراقبة الجودة',
                      style: TextStyle(
                        fontSize: isMobile ? 17 : 19,
                        fontWeight: FontWeight.w700,
                        color: const Color(AppConstants.primaryColor),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'القوائم المُسندة إليك فقط',
                      style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user_outlined,
                        size: 13, color: Color(0xFF10B981)),
                    const SizedBox(width: 5),
                    Text(
                      '${_checklistGroups.length} مجموعة',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF065F46),
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: TextStyle(
                fontSize: isMobile ? 14 : 15,
                color: const Color(AppConstants.primaryColor)),
            decoration: InputDecoration(
              hintText: 'البحث في القوائم...',
              hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: isMobile ? 13 : 14),
              prefixIcon: Icon(Icons.search,
                  color: Colors.grey.shade400, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: Icon(Icons.close_rounded,
                          size: 18, color: Colors.grey.shade400),
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: Color(0xFF8B5CF6), width: 1.5),
              ),
              contentPadding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 14,
                  vertical: isMobile ? 11 : 13),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stats bar ────────────────────────────────────────────────────────────

  Widget _buildStatsBar(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFF8B5CF6).withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              color: Color(0xFF8B5CF6), size: 16),
          const SizedBox(width: 8),
          Text(
            '$_totalChecklists قائمة متاحة',
            style: TextStyle(
                color: const Color(0xFF8B5CF6),
                fontWeight: FontWeight.w600,
                fontSize: isMobile ? 12 : 13),
          ),
          const Spacer(),
          Text(
            '${_filteredGroups.length} مجموعة',
            style: TextStyle(
                color: const Color(0xFF8B5CF6).withOpacity(0.7),
                fontWeight: FontWeight.w500,
                fontSize: isMobile ? 11 : 12),
          ),
        ],
      ),
    );
  }

  // ─── Group card ───────────────────────────────────────────────────────────

  Widget _buildGroupCard(QualityChecklistGroup group, bool isMobile) {
    final hasChecklists = group.checklists.isNotEmpty;

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group header
          Padding(
            padding: EdgeInsets.all(isMobile ? 14 : 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.folder_outlined,
                      color: Color(0xFF8B5CF6), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.title,
                        style: TextStyle(
                          fontSize: isMobile ? 15 : 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(AppConstants.primaryColor),
                        ),
                      ),
                      if (group.description != null &&
                          group.description!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          group.description!,
                          style: TextStyle(
                              fontSize: isMobile ? 12 : 13,
                              color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasChecklists
                        ? const Color(0xFF8B5CF6).withOpacity(0.08)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: hasChecklists
                        ? Border.all(
                            color:
                                const Color(0xFF8B5CF6).withOpacity(0.2))
                        : null,
                  ),
                  child: Text(
                    '${group.checklists.length} قائمة',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: hasChecklists
                          ? const Color(0xFF8B5CF6)
                          : Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade100),

          // Checklists
          if (hasChecklists)
            ...group.checklists
                .map((c) => _buildChecklistRow(c, isMobile))
          else
            Padding(
              padding: EdgeInsets.all(isMobile ? 14 : 18),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 8),
                  Text(
                    'لا توجد قوائم في هذه المجموعة',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),

          // History toggle
          _buildHistoryToggle(group, isMobile),
          if (_historyExpanded[group.id] == true)
            _buildHistorySection(group, isMobile),
        ],
      ),
    );
  }

  // ─── History toggle row ────────────────────────────────────────────────────

  Widget _buildHistoryToggle(QualityChecklistGroup group, bool isMobile) {
    final expanded = _historyExpanded[group.id] ?? false;
    final count = _recentResponses[group.id]?.length;
    return InkWell(
      onTap: () => _toggleHistory(group),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 14 : 18, vertical: 10),
        decoration: BoxDecoration(
          color: expanded
              ? const Color(0xFF8B5CF6).withOpacity(0.04)
              : Colors.grey.shade50,
          border: Border(
              top: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          children: [
            Icon(Icons.history_rounded,
                size: 15,
                color: expanded
                    ? const Color(0xFF8B5CF6)
                    : Colors.grey.shade500),
            const SizedBox(width: 8),
            Text(
              'سجل آخر 48 ساعة',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: expanded
                    ? const Color(0xFF8B5CF6)
                    : Colors.grey.shade600,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: count > 0
                      ? const Color(0xFF8B5CF6).withOpacity(0.1)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: count > 0
                        ? const Color(0xFF8B5CF6)
                        : Colors.grey.shade500,
                  ),
                ),
              ),
            ],
            const Spacer(),
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  // ─── History section ───────────────────────────────────────────────────────

  Widget _buildHistorySection(
      QualityChecklistGroup group, bool isMobile) {
    final loading = _historyLoading[group.id] ?? false;
    final responses = _recentResponses[group.id] ?? [];

    if (loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: const Color(0xFF8B5CF6),
            ),
          ),
        ),
      );
    }

    if (responses.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 18),
        child: Row(
          children: [
            Icon(Icons.inbox_outlined,
                size: 14, color: Colors.grey.shade400),
            const SizedBox(width: 8),
            Text(
              'لا توجد تقارير في آخر 48 ساعة',
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        ...responses.map<Widget>((response) {
        final checklistTitle = group.checklists
            .where((c) => c.id == response.checklistId)
            .map((c) => c.title)
            .firstOrNull ?? 'قائمة #${response.checklistId}';

        return Container(
          margin: EdgeInsets.symmetric(
              horizontal: isMobile ? 10 : 14, vertical: 4),
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF8B5CF6).withOpacity(0.07),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.assignment_turned_in_outlined,
                    size: 14, color: Color(0xFF8B5CF6)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      checklistTitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(AppConstants.primaryColor),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatSubmittedAt(response.submittedAt),
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              if (group.canEditSubmissions) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _handleEditTap(group, response),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_rounded,
                            size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'تعديل',
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _handleViewTap(group, response),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_outlined,
                            size: 12, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'عرض',
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }),
        const SizedBox(height: 8),
      ],
    );
  }

  // ─── Checklist row ────────────────────────────────────────────────────────

  Widget _buildChecklistRow(QualityChecklist checklist, bool isMobile) {
    final hasCheckPoints = checklist.checkPoints.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasCheckPoints ? () => _handleChecklistTap(checklist) : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 14 : 18,
              vertical: isMobile ? 12 : 14),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 38,
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  color: hasCheckPoints
                      ? const Color(0xFF8B5CF6).withOpacity(0.35)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: hasCheckPoints
                      ? const Color(0xFF8B5CF6).withOpacity(0.07)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  Icons.assignment_outlined,
                  color: hasCheckPoints
                      ? const Color(0xFF8B5CF6)
                      : Colors.grey.shade400,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      checklist.title,
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 15,
                        fontWeight: FontWeight.w600,
                        color: hasCheckPoints
                            ? const Color(AppConstants.primaryColor)
                            : Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildChip(
                          icon: Icons.checklist_rounded,
                          label: '${checklist.checkPoints.length} نقطة فحص',
                          color: Colors.grey.shade600,
                        ),
                        _buildChip(
                          icon: Icons.star_outline_rounded,
                          label: 'التقييم من ${checklist.rateNumber}',
                          color: Colors.grey.shade600,
                        ),
                        if (checklist.determinants.isNotEmpty)
                          _buildChip(
                            icon: Icons.tune_rounded,
                            label:
                                '${checklist.determinants.length} محدد',
                            color: const Color(0xFF10B981),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (hasCheckPoints)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ابدأ',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 11, color: Colors.white),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('فارغ',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────

  Widget _buildEmptyState(bool isMobile) {
    final isSearch = _searchQuery.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 32 : 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              isSearch
                  ? Icons.search_off_rounded
                  : Icons.assignment_outlined,
              size: isMobile ? 40 : 48,
              color: Colors.grey.shade400,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 20),
          Text(
            isSearch
                ? 'لا توجد نتائج للبحث'
                : 'لا توجد قوائم مُسندة إليك',
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Text(
            isSearch
                ? 'جرّب كلمات بحث مختلفة'
                : 'تواصل مع المشرف لإسناد قوائم إليك',
            style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          if (!isSearch) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _loadAssignedGroups,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label:
                  const Text('تحديث', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8B5CF6),
                side: const BorderSide(color: Color(0xFF8B5CF6)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── AppBar ───────────────────────────────────────────────────────────────────

class _LightAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isDesktop;
  const _LightAppBar({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back,
            color: Color(AppConstants.primaryColor)),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'تقارير مراقبة الجودة',
        style: TextStyle(
          color: Color(AppConstants.primaryColor),
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}