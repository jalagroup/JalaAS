// lib/screens/web/task_checklists_admin_screen.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:jala_as/models/task_checklist_models.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/helpers.dart';
import 'task_checklist_builder_screen.dart';

// ─── Design tokens ─────────────────────────────────────────────────────────────
const _kAccent    = Color(0xFF7C3AED);
const _kSuccess   = Color(0xFF059669);
const _kDanger    = Color(0xFFDC2626);
const _kWarning   = Color(0xFFD97706);
const _kBg        = Color(0xFFF5F6FA);
const _kSurface   = Colors.white;
const _kBorder    = Color(0xFFE8E9F0);
const _kText      = Color(0xFF1A1F36);
const _kTextMuted = Color(0xFF8F95B2);
const _kTextSub   = Color(0xFF4E5D78);
const _kRadiusLg  = 14.0;
const _kRadius    = 10.0;
const _kRadiusSm  = 6.0;

// ══════════════════════════════════════════════════════════════════════════════
class TaskChecklistsAdminScreen extends StatefulWidget {
  const TaskChecklistsAdminScreen({super.key});

  @override
  State<TaskChecklistsAdminScreen> createState() =>
      _TaskChecklistsAdminScreenState();
}

class _TaskChecklistsAdminScreenState
    extends State<TaskChecklistsAdminScreen> {
  List<TaskChecklist> _checklists = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadChecklists();
  }

  Future<void> _loadChecklists() async {
    setState(() => _loading = true);
    try {
      final list = await SupabaseService.getTaskChecklists();
      if (mounted) setState(() { _checklists = list; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        Helpers.showSnackBar(context, 'فشل التحميل: $e', isError: true);
      }
    }
  }

  List<TaskChecklist> get _filtered {
    if (_searchQuery.isEmpty) return _checklists;
    final q = _searchQuery.toLowerCase();
    return _checklists.where((c) =>
      c.title.toLowerCase().contains(q) ||
      (c.description?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  Future<void> _duplicate(TaskChecklist cl) async {
    try {
      await SupabaseService.duplicateTaskChecklist(cl.id);
      await _loadChecklists();
      if (mounted) Helpers.showSnackBar(context, 'تم تكرار القائمة بنجاح');
    } catch (e) {
      if (mounted) Helpers.showSnackBar(context, 'فشل التكرار: $e', isError: true);
    }
  }

  Future<void> _delete(TaskChecklist cl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(title: cl.title),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.deleteTaskChecklist(cl.id);
      await _loadChecklists();
      if (mounted) Helpers.showSnackBar(context, 'تم الحذف');
    } catch (e) {
      if (mounted) Helpers.showSnackBar(context, 'فشل الحذف: $e', isError: true);
    }
  }

  Future<void> _toggleActive(TaskChecklist cl) async {
    try {
      await SupabaseService.updateTaskChecklist(id: cl.id, isActive: !cl.isActive);
      await _loadChecklists();
    } catch (e) {
      if (mounted) Helpers.showSnackBar(context, 'فشل التحديث: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 640;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: _buildAppBar(),
        body: Column(children: [
          // Search + stats bar
          _buildTopBar(isMobile),
          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kAccent))
                : _filtered.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _loadChecklists,
                        color: _kAccent,
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 14 : 20,
                            vertical: 14,
                          ),
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) => _buildChecklistCard(_filtered[i], isMobile),
                        ),
                      ),
          ),
        ]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.push<bool>(context,
              MaterialPageRoute(builder: (_) => const TaskChecklistBuilderScreen()));
            if (result == true) _loadChecklists();
          },
          backgroundColor: _kAccent,
          icon: const Icon(Icons.add_task_rounded, color: Colors.white),
          label: const Text('إنشاء قائمة مهام',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    elevation: 0,
    scrolledUnderElevation: 1,
    backgroundColor: _kSurface,
    surfaceTintColor: _kSurface,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _kText),
      onPressed: () => Navigator.pop(context),
    ),
    title: const Text('قوائم المهام',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
    actions: [
      IconButton(
        icon: const Icon(Icons.refresh_rounded, size: 20, color: _kTextMuted),
        onPressed: _loadChecklists,
        tooltip: 'تحديث',
      ),
    ],
  );

  Widget _buildTopBar(bool isMobile) => Container(
    color: _kSurface,
    padding: EdgeInsets.fromLTRB(isMobile ? 14 : 20, 12, isMobile ? 14 : 20, 12),
    child: Column(children: [
      // Stats row
      Row(children: [
        _statChip(Icons.list_alt_rounded, '${_checklists.length}', 'إجمالي', _kAccent),
        const SizedBox(width: 10),
        _statChip(Icons.check_circle_outline_rounded,
            '${_checklists.where((c) => c.isActive).length}', 'نشط', _kSuccess),
        const SizedBox(width: 10),
        _statChip(Icons.pause_circle_outline_rounded,
            '${_checklists.where((c) => !c.isActive).length}', 'موقوف', _kWarning),
      ]),
      const SizedBox(height: 10),
      // Search
      TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'بحث في قوائم المهام...',
          hintStyle: const TextStyle(fontSize: 13, color: _kTextMuted),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _kTextMuted),
          filled: true,
          fillColor: _kBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kRadius),
            borderSide: const BorderSide(color: _kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kRadius),
            borderSide: const BorderSide(color: _kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kRadius),
            borderSide: const BorderSide(color: _kAccent, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          isDense: true,
        ),
      ),
    ]),
  );

  Widget _buildChecklistCard(TaskChecklist cl, bool isMobile) {
    final isActive = cl.isActive;
    final statusColor = isActive ? _kAccent : _kTextMuted;
    final freqColor = cl.frequency == TaskChecklistFrequency.daily
        ? _kAccent
        : cl.frequency == TaskChecklistFrequency.specificDays
            ? _kWarning
            : _kSuccess;
    final freqIcon = cl.frequency == TaskChecklistFrequency.daily
        ? Icons.repeat_rounded
        : cl.frequency == TaskChecklistFrequency.specificDays
            ? Icons.date_range_rounded
            : Icons.event_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(color: isActive ? _kBorder : Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_kRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(_kRadius),
          onTap: () async {
            final result = await Navigator.push<bool>(context,
                MaterialPageRoute(
                    builder: (_) => TaskChecklistBuilderScreen(existing: cl)));
            if (result == true) _loadChecklists();
          },
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 10 : 12),
            child: Row(children: [
              // ── Accent bar ──────────────────────────────────
              Container(
                width: 3,
                height: 36,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // ── Icon box ────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(Icons.checklist_rounded, color: statusColor, size: 16),
              ),
              const SizedBox(width: 10),
              // ── Title + chips ────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cl.title,
                        style: TextStyle(
                            fontSize: isMobile ? 13 : 14,
                            fontWeight: FontWeight.w600,
                            color: isActive ? _kText : _kTextMuted)),
                    const SizedBox(height: 4),
                    Wrap(spacing: 10, runSpacing: 2, children: [
                      _inlineChip(Icons.task_rounded,
                          '${cl.tasks.length} مهمة', _kAccent),
                      _inlineChip(freqIcon, cl.frequency.displayText, freqColor),
                      if (cl.scheduledTime != null)
                        _inlineChip(Icons.notifications_outlined,
                            cl.scheduledTime!, Colors.indigo),
                      if (!isActive)
                        _inlineChip(Icons.pause_circle_outline_rounded,
                            'موقوف', _kTextMuted),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // ── Action icon buttons ──────────────────────────
              _iconAction(Icons.bar_chart_rounded, _kAccent, () =>
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) =>
                          TaskChecklistResponsesScreen(checklist: cl)))),
              const SizedBox(width: 4),
              _iconAction(Icons.copy_outlined, const Color(0xFF0891B2),
                  () => _duplicate(cl)),
              const SizedBox(width: 4),
              _iconAction(Icons.edit_outlined, _kWarning, () async {
                final result = await Navigator.push<bool>(context,
                    MaterialPageRoute(
                        builder: (_) =>
                            TaskChecklistBuilderScreen(existing: cl)));
                if (result == true) _loadChecklists();
              }),
              const SizedBox(width: 4),
              _iconAction(
                cl.isActive
                    ? Icons.pause_circle_outline_rounded
                    : Icons.play_circle_outline_rounded,
                cl.isActive ? _kWarning : _kSuccess,
                () => _toggleActive(cl),
              ),
              const SizedBox(width: 4),
              _iconAction(Icons.delete_outline_rounded, _kDanger,
                  () => _delete(cl)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: _kAccent.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.checklist_rounded, color: _kAccent, size: 36),
      ),
      const SizedBox(height: 16),
      Text(
        _searchQuery.isNotEmpty ? 'لا توجد نتائج للبحث' : 'لا توجد قوائم مهام بعد',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kText),
      ),
      const SizedBox(height: 6),
      Text(
        _searchQuery.isNotEmpty ? 'جرّب كلمة بحث مختلفة' : 'اضغط + لإنشاء أول قائمة مهام',
        style: const TextStyle(fontSize: 13, color: _kTextMuted),
      ),
    ]),
  );

  Widget _statChip(IconData icon, String value, String label, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(_kRadius),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7))),
        ]),
      );

  Widget _inlineChip(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 11, color: color)),
    ],
  );

  Widget _iconAction(IconData icon, Color color, VoidCallback onTap) => InkWell(
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
  );
}

// ─── Delete dialog ─────────────────────────────────────────────────────────────
class _DeleteDialog extends StatelessWidget {
  final String title;
  const _DeleteDialog({required this.title});

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: ui.TextDirection.rtl,
    child: AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('حذف القائمة', style: TextStyle(fontWeight: FontWeight.w700)),
      content: Text('هل أنت متأكد من حذف "$title"؟ لا يمكن التراجع عن هذا الإجراء.',
          style: const TextStyle(fontSize: 13.5, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: _kTextMuted))),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: _kDanger),
          child: const Text('حذف'),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Responses screen (admin sees how all users responded)
// ══════════════════════════════════════════════════════════════════════════════
class TaskChecklistResponsesScreen extends StatefulWidget {
  final TaskChecklist checklist;
  const TaskChecklistResponsesScreen({super.key, required this.checklist});

  @override
  State<TaskChecklistResponsesScreen> createState() =>
      _TaskChecklistResponsesScreenState();
}

class _TaskChecklistResponsesScreenState
    extends State<TaskChecklistResponsesScreen> {
  List<TaskChecklistResponse> _responses = [];
  bool _loading = true;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate   = DateTime.now();
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.getTaskChecklistResponses(
        checklistId: widget.checklist.id,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (mounted) setState(() { _responses = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<TaskChecklistResponse> get _filtered {
    if (_statusFilter == 'all') return _responses;
    return _responses.where((r) => r.status.name == _statusFilter).toList();
  }

  Color _statusColor(TaskChecklistStatus s) {
    switch (s) {
      case TaskChecklistStatus.completed:   return _kSuccess;
      case TaskChecklistStatus.inProgress:  return _kWarning;
      case TaskChecklistStatus.pending:     return _kTextMuted;
      case TaskChecklistStatus.missed:      return _kDanger;
    }
  }

  IconData _statusIcon(TaskChecklistStatus s) {
    switch (s) {
      case TaskChecklistStatus.completed:   return Icons.check_circle_rounded;
      case TaskChecklistStatus.inProgress:  return Icons.pending_rounded;
      case TaskChecklistStatus.pending:     return Icons.radio_button_unchecked;
      case TaskChecklistStatus.missed:      return Icons.cancel_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 640;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 1,
          backgroundColor: _kSurface,
          surfaceTintColor: _kSurface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _kText),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.checklist.title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kText)),
            const Text('سجل الاستجابات',
                style: TextStyle(fontSize: 11, color: _kTextMuted)),
          ]),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _kTextMuted, size: 20),
              onPressed: _load,
            ),
          ],
        ),
        body: Column(children: [
          // Filters
          _buildFilters(isMobile),
          // Stats summary
          _buildStats(),
          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kAccent))
                : _filtered.isEmpty
                    ? const Center(child: Text('لا توجد استجابات لهذه الفترة',
                        style: TextStyle(color: _kTextMuted)))
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 14 : 20,
                          vertical: 14,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) => _buildResponseCard(_filtered[i], isMobile),
                      ),
          ),
        ]),
      ),
    );
  }

  Widget _buildFilters(bool isMobile) => Container(
    color: _kSurface,
    padding: EdgeInsets.fromLTRB(isMobile ? 12 : 16, 10, isMobile ? 12 : 16, 10),
    child: Column(children: [
      // Date range
      Row(children: [
        Expanded(child: _DateBtn(
          label: 'من',
          date: _fromDate,
          onPick: (d) { if (d != null) setState(() { _fromDate = d; _load(); }); },
        )),
        const SizedBox(width: 8),
        Expanded(child: _DateBtn(
          label: 'إلى',
          date: _toDate,
          onPick: (d) { if (d != null) setState(() { _toDate = d; _load(); }); },
        )),
      ]),
      const SizedBox(height: 8),
      // Status filter chips
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final (String value, String label, Color color) item in [
            ('all', 'الكل', _kAccent),
            ('completed', 'مكتمل', _kSuccess),
            ('in_progress', 'جارٍ', _kWarning),
            ('pending', 'معلق', _kTextMuted),
            ('missed', 'فائت', _kDanger),
          ])
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: GestureDetector(
                onTap: () => setState(() => _statusFilter = item.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusFilter == item.$1 ? item.$3 : _kBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _statusFilter == item.$1 ? item.$3 : _kBorder),
                  ),
                  child: Text(item.$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusFilter == item.$1 ? Colors.white : _kTextMuted,
                      )),
                ),
              ),
            ),
        ]),
      ),
    ]),
  );

  Widget _buildStats() {
    final total     = _responses.length;
    final completed = _responses.where((r) => r.status == TaskChecklistStatus.completed).length;
    final rate      = total == 0 ? 0.0 : completed / total;

    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(_kRadiusLg),
        border: Border.all(color: _kBorder),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _statItem('${(rate * 100).toInt()}%', 'معدل الإنجاز', _kSuccess),
        _divider(),
        _statItem('$total', 'إجمالي', _kAccent),
        _divider(),
        _statItem('$completed', 'مكتمل', _kSuccess),
        _divider(),
        _statItem(
          '${_responses.where((r) => r.status == TaskChecklistStatus.missed).length}',
          'فائت', _kDanger,
        ),
      ]),
    );
  }

  Widget _statItem(String value, String label, Color color) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 11, color: _kTextMuted)),
    ],
  );

  Widget _divider() => Container(width: 1, height: 32, color: _kBorder);

  Widget _buildResponseCard(TaskChecklistResponse r, bool isMobile) {
    final color = _statusColor(r.status);
    final icon  = _statusIcon(r.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(_kRadiusLg),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.02), blurRadius: 6)],
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16, vertical: 6),
        leading: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(_kRadius),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(r.username ?? r.userId.substring(0, 8),
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _kText)),
        subtitle: Row(children: [
          Text(
            '${r.scheduledDate.day}/${r.scheduledDate.month}/${r.scheduledDate.year}',
            style: const TextStyle(fontSize: 11.5, color: _kTextMuted),
          ),
          const SizedBox(width: 8),
          // Progress
          Text('${r.completedCount}/${r.totalCount}',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
        ]),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha:0.3)),
          ),
          child: Text(r.status.displayText,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ),
        children: [
          Divider(height: 1, color: _kBorder.withValues(alpha:0.6)),
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: r.progress,
                    minHeight: 6,
                    backgroundColor: _kBorder,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 14),
                // Task list
                ...r.taskResponses.map((tr) {
                  final taskDef = widget.checklist.tasks
                      .where((t) => t.id == tr.taskId)
                      .firstOrNull;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: tr.isDone ? _kSuccess.withValues(alpha:0.04) : _kBg,
                      borderRadius: BorderRadius.circular(_kRadiusSm),
                      border: Border.all(
                        color: tr.isDone ? _kSuccess.withValues(alpha:0.2) : _kBorder),
                    ),
                    child: Row(children: [
                      Icon(
                        tr.isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                        size: 16,
                        color: tr.isDone ? _kSuccess : _kTextMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            taskDef?.title ?? tr.taskId,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: tr.isDone ? _kSuccess : _kTextMuted,
                              decoration: tr.isDone ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          if (tr.notes != null)
                            Text(tr.notes!,
                                style: const TextStyle(fontSize: 11.5, color: _kTextMuted)),
                        ]),
                      ),
                      if (tr.isDone && tr.doneAt != null)
                        Text(
                          '${tr.doneAt!.hour}:${tr.doneAt!.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 10.5, color: _kTextMuted),
                        ),
                    ]),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Date button ───────────────────────────────────────────────────────────────
class _DateBtn extends StatelessWidget {
  final String label;
  final DateTime date;
  final ValueChanged<DateTime?> onPick;
  const _DateBtn({required this.label, required this.date, required this.onPick});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      final d = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime(2024),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        builder: (ctx, child) => Directionality(
          textDirection: ui.TextDirection.rtl, child: child!),
      );
      onPick(d);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        const Icon(Icons.calendar_today_outlined, size: 13, color: _kTextMuted),
        const SizedBox(width: 6),
        Text(
          '$label: ${date.day}/${date.month}/${date.year}',
          style: const TextStyle(fontSize: 12, color: _kTextSub, fontWeight: FontWeight.w500),
        ),
      ]),
    ),
  );
}

//const _kTextSub = Color(0xFF4E5D78);