// lib/screens/web/admin_dasboards/quality_management_screen.dart
import 'package:flutter/material.dart';
import 'package:jala_as/models/quality_models.dart';
import 'package:jala_as/screens/web/admin_dasboards/quality_management/quality_averages_screen.dart';
import 'package:jala_as/screens/web/admin_dasboards/quality_management/quality_responses_screen.dart';
import 'package:jala_as/screens/web/admin_dasboards/quality_management/quality_checklist_builder_screen.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/helpers.dart';
import 'dart:ui' as ui;
import 'quality_colors.dart';
import 'package:jala_as/screens/web/admin_dasboards/quality_management/quality_dashboard_screen.dart';

// ─────────────────────────────────────────────────────────────
//  Design Tokens
// ─────────────────────────────────────────────────────────────
class _DS {
  static const shadowSm = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x06000000), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const shadowMd = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 2)),
  ];
  static const bg = Color(0xFFF1F5F9);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const borderLight = Color(0xFFF1F5F9);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);
}

// ─────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────
class QualityManagementDashboard extends StatefulWidget {
  const QualityManagementDashboard({super.key});

  @override
  State<QualityManagementDashboard> createState() =>
      _QualityManagementDashboardState();
}

class _QualityManagementDashboardState
    extends State<QualityManagementDashboard>
    with SingleTickerProviderStateMixin {
  List<QualityChecklistGroup> _checklistGroups = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  QualityChecklistGroup? _selectedGroup;
  String _currentView = 'groups';

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadChecklistGroups();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────

  Future<void> _loadChecklistGroups() async {
    setState(() => _isLoading = true);
    _animCtrl.reset();
    try {
      // Only load groups created by the current admin
      final groups = await SupabaseService.getMyQualityChecklistGroups();
      if (!mounted) return;
      setState(() {
        _checklistGroups = groups;
        _isLoading = false;
      });
      _animCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Helpers.showSnackBar(context, 'فشل في تحميل البيانات', isError: true);
    }
  }



  List<QualityChecklistGroup> get _filteredGroups {
    if (_searchQuery.isEmpty) return _checklistGroups;
    return _checklistGroups.where((g) {
      return g.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (g.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false);
    }).toList();
  }

  // ── Navigation ─────────────────────────────────────────────

  void _navigateToResponses(QualityChecklistGroup group) =>
      setState(() {
        _selectedGroup = group;
        _currentView = 'responses';
      });

  void _navigateToAverages(QualityChecklistGroup group) =>
      setState(() {
        _selectedGroup = group;
        _currentView = 'averages';
      });

      void _navigateToDashboard(QualityChecklistGroup group) =>
    setState(() {
      _selectedGroup = group;
      _currentView = 'dashboard';
    });

  void _backToGroups() =>
      setState(() {
        _selectedGroup = null;
        _currentView = 'groups';
      });

  // ── CRUD actions ───────────────────────────────────────────

  Future<void> _createNewGroup() async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => QualityChecklistBuilderScreen()));
    if (result == true) _loadChecklistGroups();
  }

  Future<void> _editGroup(QualityChecklistGroup group) async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                QualityChecklistBuilderScreen(checklistGroup: group)));
    if (result == true) {
      _loadChecklistGroups();
      if (_selectedGroup?.id == group.id) _backToGroups();
    }
  }

  Future<void> _deleteGroup(QualityChecklistGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444), size: 24),
                ),
                const SizedBox(height: 14),
                const Text('تأكيد الحذف',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _DS.textPrimary)),
                const SizedBox(height: 8),
                Text(
                  'هل تريد حذف "${group.title}"؟\nسيتم حذف جميع البيانات المرتبطة.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12.5, color: _DS.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _DS.border),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7)),
                        ),
                        child: const Text('إلغاء',
                            style: TextStyle(
                                fontSize: 12, color: _DS.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7)),
                        ),
                        child: const Text('حذف',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.deleteQualityChecklistGroup(group.id);
        if (!mounted) return;
        Helpers.showSnackBar(context, 'تم الحذف بنجاح');
        if (_selectedGroup?.id == group.id) _backToGroups();
        _loadChecklistGroups();
      } catch (e) {
        if (mounted)
          Helpers.showSnackBar(context, 'فشل في الحذف', isError: true);
      }
    }
  }

  Future<void> _toggleGroupStatus(QualityChecklistGroup group) async {
    try {
      await SupabaseService.updateQualityChecklistGroup(
          id: group.id, isActive: !group.isActive);
      if (!mounted) return;
      Helpers.showSnackBar(
          context, group.isActive ? 'تم إلغاء التفعيل' : 'تم التفعيل');
      _loadChecklistGroups();
    } catch (e) {
      if (mounted)
        Helpers.showSnackBar(context, 'فشل في تغيير الحالة', isError: true);
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

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _DS.bg,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: QColors.primary))
                  : _buildCurrentView(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (_currentView != 'groups' && _selectedGroup != null) {
      final isResponses = _currentView == 'responses';
      final isDashboard = _currentView == 'dashboard';
      final viewColor = isResponses
          ? const Color(0xFF3B82F6)
          : isDashboard
              ? const Color(0xFF10B981)
              : const Color(0xFF8B5CF6);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _DS.surface,
          border: const Border(bottom: BorderSide(color: _DS.border)),
          boxShadow: _DS.shadowSm,
        ),
        child: Row(
          children: [
            _IconBtn(
              icon: Icons.arrow_back_ios_new_rounded,
              color: QColors.primary,
              onTap: _backToGroups,
              tooltip: 'العودة',
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: viewColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isResponses
                    ? Icons.assignment_outlined
                    : isDashboard
                        ? Icons.dashboard_outlined
                        : Icons.analytics_outlined,
                size: 17,
                color: viewColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isResponses
                        ? 'الاستجابات'
                        : isDashboard
                            ? 'لوحة المراقبة'
                            : 'المتوسطات',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _DS.textPrimary,
                        height: 1.1),
                  ),
                  Text(
                    _selectedGroup!.title,
                    style:
                        const TextStyle(fontSize: 11, color: _DS.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Groups list header ─────────────────────────────────────
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: 14, vertical: isMobile ? 10 : 10),
      decoration: BoxDecoration(
        color: _DS.surface,
        border: const Border(bottom: BorderSide(color: _DS.border)),
        boxShadow: _DS.shadowSm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: QColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.checklist_rtl_rounded,
                    size: 17, color: QColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    const Text(
                      'إدارة مراقبة الجودة',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _DS.textPrimary),
                    ),
                    const SizedBox(width: 6),
                    if (_checklistGroups.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: QColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_checklistGroups.length}',
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: QColors.primary),
                        ),
                      ),
                  ],
                ),
              ),
              // On mobile show only the add button; search is below
              if (!isMobile) ...[
                Container(
                  width: 200,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _DS.surfaceAlt,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: _DS.border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(
                        fontSize: 12, color: _DS.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'بحث...',
                      hintStyle: const TextStyle(
                          fontSize: 12, color: _DS.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 15, color: _DS.textSecondary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: const Icon(Icons.close_rounded,
                                  size: 14, color: _DS.textSecondary),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 1),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              _NewGroupButton(onPressed: _createNewGroup),
            ],
          ),
          // Mobile: full-width search bar below title row
          if (isMobile) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(
                    fontSize: 13, color: _DS.textPrimary),
                decoration: InputDecoration(
                  hintText: 'بحث عن مجموعة...',
                  hintStyle:
                      const TextStyle(fontSize: 13, color: _DS.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 17, color: _DS.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: const Icon(Icons.close_rounded,
                              size: 15, color: _DS.textSecondary),
                        )
                      : null,
                  filled: true,
                  fillColor: _DS.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _DS.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _DS.border),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 1),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Content router ─────────────────────────────────────────

Widget _buildCurrentView() {
  switch (_currentView) {
    case 'responses':
      return _selectedGroup != null
          ? QualityResponsesScreen(group: _selectedGroup!)
          : _buildEmptyState();
    case 'averages':
      return _selectedGroup != null
          ? QualityAveragesScreen(group: _selectedGroup!)
          : _buildEmptyState();
    case 'dashboard':
      return _selectedGroup != null
          ? QualityDashboardScreen(group: _selectedGroup!)
          : _buildEmptyState();
    case 'groups':
    default:
      return _filteredGroups.isEmpty
          ? _buildEmptyState()
          : _buildGroupsList();
  }
}

  // ── Groups list ────────────────────────────────────────────

  Widget _buildGroupsList() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _filteredGroups.length,
        itemBuilder: (_, i) => _GroupCard(
          group: _filteredGroups[i],
          onDashboard: () => _navigateToDashboard(_filteredGroups[i]),
          onAverages: () => _navigateToAverages(_filteredGroups[i]),
          onResponses: () => _navigateToResponses(_filteredGroups[i]),
          onEdit: () => _editGroup(_filteredGroups[i]),
          onToggle: () => _toggleGroupStatus(_filteredGroups[i]),
          onDelete: () => _deleteGroup(_filteredGroups[i]),
          onDuplicate: () => _duplicateGroup(_filteredGroups[i]),
          onDuplicateChecklist: _duplicateChecklist,
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────

  Widget _buildEmptyState() {
    final isSearch = _searchQuery.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _DS.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _DS.border),
            ),
            child: Icon(
              isSearch ? Icons.search_off_rounded : Icons.folder_open_outlined,
              size: 30,
              color: _DS.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isSearch ? 'لا توجد نتائج' : 'لا توجد مجموعات',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _DS.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            isSearch ? 'جرب كلمات أخرى' : 'ابدأ بإنشاء مجموعة جديدة',
            style: const TextStyle(fontSize: 12, color: _DS.textSecondary),
          ),
          if (!isSearch) ...[
            const SizedBox(height: 16),
            _NewGroupButton(onPressed: _createNewGroup),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Group Card
// ─────────────────────────────────────────────────────────────
class _GroupCard extends StatefulWidget {
  final QualityChecklistGroup group;
  final VoidCallback onAverages;
  final VoidCallback onResponses;
  final VoidCallback onDashboard;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final void Function(QualityChecklist) onDuplicateChecklist;

  const _GroupCard({
    required this.group,
    required this.onAverages,
    required this.onResponses,
    required this.onDashboard,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.onDuplicate,
    required this.onDuplicateChecklist,
  });

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final isActive = group.isActive;
    final activeColor = isActive ? const Color(0xFF10B981) : _DS.textMuted;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _DS.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _DS.border),
        boxShadow: _DS.shadowSm,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: isMobile
                ? _buildMobileLayout(group, isActive, activeColor)
                : _buildDesktopLayout(group, isActive, activeColor),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: _DS.border),
            if (group.checklists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('لا توجد قوائم في هذه المجموعة',
                    style: TextStyle(fontSize: 13, color: _DS.textSecondary)),
              )
            else
              ...group.checklists.map((cl) => _buildChecklistTile(cl)),
          ],
        ],
      ),
    );
  }

  // ── Desktop: single dense row ──────────────────────────────
  Widget _buildDesktopLayout(
      QualityChecklistGroup group, bool isActive, Color activeColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _statusBar(activeColor),
        const SizedBox(width: 10),
        _groupIcon(),
        const SizedBox(width: 10),
        Expanded(child: _titleBlock(group)),
        const SizedBox(width: 10),
        _MetaBadge(label: '${group.checklists.length} قائمة', color: QColors.primary),
        const SizedBox(width: 5),
        if (group.isMultipleActive) ...[
          _MetaBadge(label: 'متعدد', color: const Color(0xFF8B5CF6)),
          const SizedBox(width: 5),
        ],
        _MetaBadge(label: isActive ? 'مفعّل' : 'معطّل', color: activeColor),
        const SizedBox(width: 12),
        Container(width: 1, height: 28, color: _DS.borderLight),
        const SizedBox(width: 12),
        _NavButton(
          label: 'المتوسطات',
          icon: Icons.analytics_outlined,
          color: const Color(0xFF8B5CF6),
          onTap: widget.onAverages,
        ),
        const SizedBox(width: 6),
        _NavButton(
          label: 'لوحة المراقبة',
          icon: Icons.dashboard_outlined,
          color: const Color(0xFF10B981),
          onTap: widget.onDashboard,
        ),
        const SizedBox(width: 6),
        _NavButton(
          label: 'الاستجابات',
          icon: Icons.assignment_outlined,
          color: const Color(0xFF3B82F6),
          onTap: widget.onResponses,
        ),
        const SizedBox(width: 10),
        Container(width: 1, height: 28, color: _DS.borderLight),
        const SizedBox(width: 8),
        _IconBtn(
          icon: Icons.copy_outlined,
          color: const Color(0xFF3B82F6),
          onTap: widget.onDuplicate,
          tooltip: 'تكرار المجموعة',
        ),
        const SizedBox(width: 2),
        _IconBtn(
          icon: Icons.edit_outlined,
          color: const Color(0xFFF59E0B),
          onTap: widget.onEdit,
          tooltip: 'تعديل',
        ),
        const SizedBox(width: 2),
        _IconBtn(
          icon: isActive
              ? Icons.pause_circle_outline_rounded
              : Icons.play_circle_outline_rounded,
          color: isActive ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
          onTap: widget.onToggle,
          tooltip: isActive ? 'تعطيل' : 'تفعيل',
        ),
        const SizedBox(width: 2),
        _IconBtn(
          icon: Icons.delete_outline_rounded,
          color: const Color(0xFFEF4444),
          onTap: widget.onDelete,
          tooltip: 'حذف',
        ),
        const SizedBox(width: 2),
        _IconBtn(
          icon: _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
          color: _DS.textSecondary,
          onTap: () => setState(() => _expanded = !_expanded),
          tooltip: _expanded ? 'طي' : 'عرض القوائم',
        ),
      ],
    );
  }

  // ── Mobile: stacked two-row layout ─────────────────────────
  Widget _buildMobileLayout(
      QualityChecklistGroup group, bool isActive, Color activeColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statusBar(activeColor),
        const SizedBox(width: 10),
        _groupIcon(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _titleBlock(group)),
                  const SizedBox(width: 6),
                  _IconBtn(
                    icon: Icons.copy_outlined,
                    color: const Color(0xFF3B82F6),
                    onTap: widget.onDuplicate,
                    tooltip: 'تكرار',
                  ),
                  _IconBtn(
                    icon: Icons.edit_outlined,
                    color: const Color(0xFFF59E0B),
                    onTap: widget.onEdit,
                    tooltip: 'تعديل',
                  ),
                  _IconBtn(
                    icon: isActive
                        ? Icons.pause_circle_outline_rounded
                        : Icons.play_circle_outline_rounded,
                    color: isActive
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF10B981),
                    onTap: widget.onToggle,
                    tooltip: isActive ? 'تعطيل' : 'تفعيل',
                  ),
                  _IconBtn(
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFFEF4444),
                    onTap: widget.onDelete,
                    tooltip: 'حذف',
                  ),
                  _IconBtn(
                    icon: _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: _DS.textSecondary,
                    onTap: () => setState(() => _expanded = !_expanded),
                    tooltip: _expanded ? 'طي' : 'عرض',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 5,
                runSpacing: 4,
                children: [
                  _MetaBadge(
                      label: '${group.checklists.length} قائمة',
                      color: QColors.primary),
                  if (group.isMultipleActive)
                    _MetaBadge(label: 'متعدد', color: const Color(0xFF8B5CF6)),
                  _MetaBadge(
                      label: isActive ? 'مفعّل' : 'معطّل', color: activeColor),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _NavButton(
                    label: 'المتوسطات',
                    icon: Icons.analytics_outlined,
                    color: const Color(0xFF8B5CF6),
                    onTap: widget.onAverages,
                  ),
                  _NavButton(
                    label: 'لوحة المراقبة',
                    icon: Icons.dashboard_outlined,
                    color: const Color(0xFF10B981),
                    onTap: widget.onDashboard,
                  ),
                  _NavButton(
                    label: 'الاستجابات',
                    icon: Icons.assignment_outlined,
                    color: const Color(0xFF3B82F6),
                    onTap: widget.onResponses,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Expanded: individual checklist tile ────────────────────
  Widget _buildChecklistTile(QualityChecklist cl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _DS.border)),
      ),
      child: Row(children: [
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: QColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.checklist_rounded,
              color: QColors.primary, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cl.title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _DS.textPrimary)),
                if (cl.checkPoints.isNotEmpty)
                  Text('${cl.checkPoints.length} نقطة تفتيش',
                      style: const TextStyle(
                          fontSize: 11, color: _DS.textSecondary)),
              ]),
        ),
        _IconBtn(
          icon: Icons.copy_outlined,
          color: const Color(0xFF3B82F6),
          onTap: () => widget.onDuplicateChecklist(cl),
          tooltip: 'تكرار القائمة',
        ),
      ]),
    );
  }

  Widget _statusBar(Color color) => Container(
        width: 3,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _groupIcon() => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              QColors.primary.withValues(alpha: 0.15),
              QColors.primary.withValues(alpha: 0.08),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.checklist_rtl_rounded,
            size: 18, color: QColors.primary),
      );

  Widget _titleBlock(QualityChecklistGroup group) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            group.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _DS.textPrimary,
            ),
          ),
          if (group.description != null && group.description!.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              group.description!,
              style: const TextStyle(fontSize: 11, color: _DS.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          FutureBuilder<int>(
            future: SupabaseService.getGroupAssignedUsersCount(group.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data == 0) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_outline_rounded,
                        size: 11, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 3),
                    Text(
                      'مُسند إلى ${snapshot.data} مستخدم',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF3B82F6)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────
//  Small reusable widgets
// ─────────────────────────────────────────────────────────────

class _MetaBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _MetaBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _NavButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;
  const _IconBtn(
      {required this.icon,
      required this.color,
      required this.onTap,
      this.tooltip});

  @override
  Widget build(BuildContext context) {
    final btn = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

class _NewGroupButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _NewGroupButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [QColors.primary, Color(0xFF4F46E5)],
            ),
            borderRadius: BorderRadius.circular(7),
            boxShadow: _DS.shadowSm,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 15, color: Colors.white),
              SizedBox(width: 5),
              Text('إنشاء مجموعة',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}