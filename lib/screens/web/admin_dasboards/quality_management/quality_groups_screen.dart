// lib/screens/web/quality_management/quality_groups_screen.dart
import 'package:flutter/material.dart';
import 'package:jala_as/models/quality_models.dart';
import 'package:jala_as/screens/web/admin_dasboards/quality_management/quality_averages_screen.dart';
import 'package:jala_as/screens/web/admin_dasboards/quality_management/quality_checklist_builder_screen.dart';
import 'package:jala_as/screens/web/admin_dasboards/quality_management/quality_responses_screen.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/helpers.dart';
import 'dart:ui' as ui;
import 'quality_colors.dart';

// Import your checklist builder screen
// import 'quality_checklist_builder_screen.dart';

class QualityGroupsScreen extends StatefulWidget {
  const QualityGroupsScreen({super.key});

  @override
  State<QualityGroupsScreen> createState() => _QualityGroupsScreenState();
}

class _QualityGroupsScreenState extends State<QualityGroupsScreen> {
  List<QualityChecklistGroup> _checklistGroups = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Map<int, bool> _expanded = {};

  @override
  void initState() {
    super.initState();
    _loadChecklistGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChecklistGroups() async {
    setState(() => _isLoading = true);
    try {
      final groups = await SupabaseService.getQualityChecklistGroups();
      setState(() {
        _checklistGroups = groups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Helpers.showSnackBar(context, 'فشل في تحميل البيانات', isError: true);
    }
  }

  List<QualityChecklistGroup> get _filteredGroups {
    if (_searchQuery.isEmpty) return _checklistGroups;
    return _checklistGroups.where((group) {
      return group.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (group.description
                  ?.toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ??
              false);
    }).toList();
  }

  void _navigateToAverages(QualityChecklistGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QualityAveragesScreen(group: group),
      ),
    );
  }

  void _navigateToResponses(QualityChecklistGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QualityResponsesScreen(group: group),
      ),
    );
  }

  Future<void> _createNewGroup() async {
    // Navigate to checklist builder
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QualityChecklistBuilderScreen(),
        ));
    if (result == true) _loadChecklistGroups();
  }

  Future<void> _editGroup(QualityChecklistGroup group) async {
    // Navigate to checklist builder with group data
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              QualityChecklistBuilderScreen(checklistGroup: group),
        ));
    if (result == true) _loadChecklistGroups();
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

  Future<void> _deleteGroup(QualityChecklistGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text(
              'هل تريد حذف "${group.title}"؟\nسيتم حذف جميع البيانات المرتبطة.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: QColors.error),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.deleteQualityChecklistGroup(group.id);
        Helpers.showSnackBar(context, 'تم الحذف بنجاح');
        _loadChecklistGroups();
      } catch (e) {
        Helpers.showSnackBar(context, 'فشل في الحذف', isError: true);
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
          context, group.isActive ? 'تم إلغاء التفعيل' : 'تم التفعيل');
      _loadChecklistGroups();
    } catch (e) {
      Helpers.showSnackBar(context, 'فشل في تغيير الحالة', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: QColors.background,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: QColors.primary))
                  : _filteredGroups.isEmpty
                      ? _buildEmptyState()
                      : _buildGroupsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: QColors.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.checklist, color: QColors.primary, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'إدارة مراقبة الجودة',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: QColors.textPrimary,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _createNewGroup,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إنشاء مجموعة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: QColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'بحث...',
                hintStyle:
                    const TextStyle(color: QColors.textSecondary, fontSize: 14),
                prefixIcon:
                    const Icon(Icons.search, color: QColors.primary, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: QColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: QColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: QColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isEmpty ? Icons.folder_open : Icons.search_off,
            size: 48,
            color: QColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'لا توجد مجموعات' : 'لا توجد نتائج',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: QColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'ابدأ بإنشاء مجموعة جديدة'
                : 'جرب كلمات أخرى',
            style: const TextStyle(fontSize: 14, color: QColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsList() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _filteredGroups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildGroupCard(_filteredGroups[index]),
    );
  }

  Widget _buildGroupCard(QualityChecklistGroup group) {
    final isExpanded = _expanded[group.id] ?? false;
    final statusColor = group.isActive ? QColors.success : QColors.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: QColors.border),
      ),
      child: Column(children: [
        // ── Main row ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            // Accent bar
            Container(
              width: 3, height: 36,
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
              child: Icon(Icons.checklist_rounded, color: statusColor, size: 16),
            ),
            const SizedBox(width: 10),
            // Title + chips
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(group.title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: QColors.textPrimary)),
                const SizedBox(height: 4),
                Wrap(spacing: 10, runSpacing: 2, children: [
                  _miniChip(Icons.list_alt_rounded,
                      '${group.checklists.length} قائمة', QColors.primary),
                  _miniChip(
                    group.isActive
                        ? Icons.check_circle_outline_rounded
                        : Icons.pause_circle_outline_rounded,
                    group.isActive ? 'مفعل' : 'معطل',
                    statusColor,
                  ),
                  if (group.isMultipleActive)
                    _miniChip(Icons.layers_rounded, 'متعدد', QColors.info),
                ]),
              ]),
            ),
            const SizedBox(width: 8),
            // ── 5 action buttons ────────────────────────────────
            _buildIconButton(Icons.copy_outlined, QColors.info,
                () => _duplicateGroup(group)),
            const SizedBox(width: 4),
            _buildIconButton(Icons.edit_rounded, QColors.warning,
                () => _editGroup(group)),
            const SizedBox(width: 4),
            _buildIconButton(
              group.isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
              group.isActive ? QColors.warning : QColors.success,
              () => _toggleGroupStatus(group),
            ),
            const SizedBox(width: 4),
            _buildIconButton(Icons.delete_rounded, QColors.error,
                () => _deleteGroup(group)),
            const SizedBox(width: 4),
            _buildIconButton(
              isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              QColors.textSecondary,
              () => setState(() => _expanded[group.id] = !isExpanded),
            ),
          ]),
        ),
        // ── Expanded section ──────────────────────────────────────
        if (isExpanded) ...[
          const Divider(height: 1, color: QColors.border),
          // Analytics + Responses row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              _buildTextAction(Icons.analytics_rounded, 'المتوسطات', QColors.primary,
                  () => _navigateToAverages(group)),
              const SizedBox(width: 8),
              _buildTextAction(Icons.list_alt_rounded, 'الاستجابات', QColors.info,
                  () => _navigateToResponses(group)),
            ]),
          ),
          const Divider(height: 1, color: QColors.border),
          if (group.checklists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('لا توجد قوائم في هذه المجموعة',
                  style: TextStyle(fontSize: 13, color: QColors.textSecondary)),
            )
          else
            ...group.checklists.map((cl) => _buildChecklistTile(cl)),
        ],
      ]),
    );
  }

  Widget _buildChecklistTile(QualityChecklist cl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: QColors.border)),
      ),
      child: Row(children: [
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: QColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.checklist_rounded, color: QColors.primary, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cl.title,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: QColors.textPrimary)),
            if (cl.checkPoints.isNotEmpty)
              Text('${cl.checkPoints.length} نقطة',
                  style: const TextStyle(fontSize: 11, color: QColors.textSecondary)),
          ]),
        ),
        _buildIconButton(Icons.copy_outlined, QColors.info,
            () => _duplicateChecklist(cl)),
      ]),
    );
  }

  Widget _miniChip(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 11, color: color)),
    ],
  );

  Widget _buildTextAction(IconData icon, String label, Color color, VoidCallback onTap) =>
      MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ]),
          ),
        ),
      );

  Widget _buildIconButton(IconData icon, Color color, VoidCallback onPressed) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
