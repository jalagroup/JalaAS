import 'package:flutter/material.dart';
import 'package:jala_as/models/report_models.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/helpers.dart';
import 'report_list_builder_screen.dart';
import 'report_list_responses_screen.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF0891B2);
const _kAccentLight = Color(0xFFE0F2FE);
const _kDanger = Color(0xFFDC2626);
const _kSuccess = Color(0xFF059669);
const _kWarning = Color(0xFFD97706);
const _kBg = Color(0xFFF1F5F9);
const _kCard = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE2E8F0);
const _kTextPrimary = Color(0xFF0F172A);
const _kTextSecondary = Color(0xFF64748B);
const _kRadius = 12.0;

BoxDecoration _cardDecoration({Color? border}) => BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(_kRadius),
      border: Border.all(color: border ?? _kBorder),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2))
      ],
    );

// ─── Main Screen ──────────────────────────────────────────────────────────────

class ReportListsScreen extends StatefulWidget {
  const ReportListsScreen({super.key});

  @override
  State<ReportListsScreen> createState() => _ReportListsScreenState();
}

class _ReportListsScreenState extends State<ReportListsScreen> {
  List<ReportListGroup> _groups = [];
  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final groups = await SupabaseService.getReportListGroups();
      setState(() {
        _groups = groups;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) Helpers.showSnackBar(context, 'فشل في تحميل البيانات', isError: true);
    }
  }

  List<ReportListGroup> get _filtered {
    if (_search.isEmpty) return _groups;
    final q = _search.toLowerCase();
    return _groups.where((g) {
      return g.title.toLowerCase().contains(q) ||
          (g.description?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _createGroup() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ReportListBuilderScreen()),
    );
    if (result == true) _load();
  }

  Future<void> _editGroup(ReportListGroup group) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => ReportListBuilderScreen(group: group)),
    );
    if (result == true) _load();
  }

  Future<void> _deleteGroup(ReportListGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('حذف المجموعة', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            'هل أنت متأكد من حذف "${group.title}"؟\nسيتم حذف جميع القوائم والردود المرتبطة بها.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kDanger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.deleteReportListGroup(group.id);
      _load();
    } catch (e) {
      if (mounted) Helpers.showSnackBar(context, 'فشل في الحذف', isError: true);
    }
  }

  Future<void> _duplicateGroup(ReportListGroup group) async {
    try {
      await SupabaseService.duplicateReportListGroup(group.id);
      if (mounted) Helpers.showSnackBar(context, 'تم تكرار المجموعة بنجاح');
      _load();
    } catch (e) {
      if (mounted) Helpers.showSnackBar(context, 'فشل في التكرار', isError: true);
    }
  }

  Future<void> _duplicateReportList(ReportList rl) async {
    try {
      await SupabaseService.duplicateReportList(rl.id);
      if (mounted) Helpers.showSnackBar(context, 'تم تكرار القائمة بنجاح');
      _load();
    } catch (e) {
      if (mounted) Helpers.showSnackBar(context, 'فشل في التكرار', isError: true);
    }
  }

  void _openResponses(ReportListGroup group, ReportList reportList) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              ReportListResponsesScreen(group: group, reportList: reportList)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          title: const Text('قوائم التقارير',
              style: TextStyle(
                  color: _kTextPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _kBorder),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('مجموعة جديدة', style: TextStyle(fontSize: 13)),
                onPressed: _createGroup,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) =>
                                _GroupCard(
                                  group: _filtered[i],
                                  onEdit: () => _editGroup(_filtered[i]),
                                  onDelete: () => _deleteGroup(_filtered[i]),
                                  onDuplicate: () => _duplicateGroup(_filtered[i]),
                                  onOpenResponses: (rl) =>
                                      _openResponses(_filtered[i], rl),
                                  onDuplicateReportList: _duplicateReportList,
                                ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: 'بحث عن مجموعة...',
          hintStyle: const TextStyle(fontSize: 13, color: _kTextSecondary),
          prefixIcon: const Icon(Icons.search, size: 18, color: _kTextSecondary),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _search = '');
                  })
              : null,
          filled: true,
          fillColor: _kBg,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assignment_outlined, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            _search.isNotEmpty ? 'لا توجد نتائج' : 'لا توجد مجموعات بعد',
            style: const TextStyle(color: _kTextSecondary, fontSize: 15),
          ),
          if (_search.isEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _kAccent),
              onPressed: _createGroup,
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              label: const Text('إنشاء مجموعة',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Group card ───────────────────────────────────────────────────────────────

class _GroupCard extends StatefulWidget {
  final ReportListGroup group;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final void Function(ReportList) onOpenResponses;
  final void Function(ReportList) onDuplicateReportList;

  const _GroupCard({
    required this.group,
    required this.onEdit,
    required this.onDelete,
    required this.onDuplicate,
    required this.onOpenResponses,
    required this.onDuplicateReportList,
  });

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _expanded = false;

  static Widget _chip(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 11, color: color)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final isMobile = MediaQuery.of(context).size.width < 640;
    final statusColor = g.isActive ? _kSuccess : _kTextSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(color: _kBorder),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_kRadius),
        child: Column(children: [
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(_kRadius),
              bottom: Radius.circular(_expanded ? 0 : _kRadius),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 10 : 12,
              ),
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
                  child: Icon(Icons.folder_rounded, color: statusColor, size: 16),
                ),
                const SizedBox(width: 10),
                // Title + chips
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.title,
                          style: TextStyle(
                              fontSize: isMobile ? 13 : 14,
                              fontWeight: FontWeight.w600,
                              color: _kTextPrimary)),
                      const SizedBox(height: 4),
                      Wrap(spacing: 10, runSpacing: 2, children: [
                        _chip(Icons.list_alt_rounded,
                            '${g.reportLists.length} قائمة', _kAccent),
                        _chip(
                          g.isActive
                              ? Icons.check_circle_outline_rounded
                              : Icons.pause_circle_outline_rounded,
                          g.isActive ? 'نشط' : 'موقوف',
                          statusColor,
                        ),
                        if (g.canEditSubmissions)
                          _chip(Icons.edit_rounded, 'تعديل مسموح',
                              const Color(0xFF7C3AED)),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Action icon buttons
                _IconBtn(Icons.bar_chart_rounded, _kAccent,
                    g.reportLists.isEmpty
                        ? () {}
                        : () => widget.onOpenResponses(g.reportLists.first)),
                const SizedBox(width: 4),
                _IconBtn(Icons.copy_outlined, _kAccent, widget.onDuplicate),
                const SizedBox(width: 4),
                _IconBtn(Icons.edit_outlined, _kWarning, widget.onEdit),
                const SizedBox(width: 4),
                _IconBtn(Icons.delete_outline, _kDanger, widget.onDelete),
                const SizedBox(width: 4),
                _IconBtn(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  _kTextSecondary,
                  () => setState(() => _expanded = !_expanded),
                ),
              ]),
            ),
          ),
          // Expanded sub-list
          if (_expanded) ...[
            const Divider(height: 1, color: _kBorder),
            if (g.reportLists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('لا توجد قوائم في هذه المجموعة',
                    style: TextStyle(color: _kTextSecondary, fontSize: 13)),
              )
            else
              ...g.reportLists.map((rl) => _ReportListTile(
                    reportList: rl,
                    onOpenResponses: () => widget.onOpenResponses(rl),
                    onDuplicate: () => widget.onDuplicateReportList(rl),
                  )),
          ],
        ]),
      ),
    );
  }
}

// ─── Report list tile (inside expanded group) ─────────────────────────────────

class _ReportListTile extends StatelessWidget {
  final ReportList reportList;
  final VoidCallback onOpenResponses;
  final VoidCallback onDuplicate;

  const _ReportListTile({
    required this.reportList,
    required this.onOpenResponses,
    required this.onDuplicate,
  });

  String get _scheduleLabel {
    final rl = reportList;
    switch (rl.scheduleType) {
      case ReportScheduleType.anytime:
        return 'في أي وقت';
      case ReportScheduleType.daily:
        return 'يومي';
      case ReportScheduleType.weekly:
        final days = ['أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];
        final d = rl.scheduleDayOfWeek;
        return 'أسبوعي - ${d != null && d < days.length ? days[d] : ''}';
      case ReportScheduleType.monthly:
        return 'شهري - يوم ${rl.scheduleDayOfMonth ?? ''}';
      case ReportScheduleType.yearly:
        final months = [
          'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
          'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
        ];
        final m = rl.scheduleMonth;
        return 'سنوي - ${rl.scheduleDayOfMonth ?? ''} ${m != null && m >= 1 && m <= 12 ? months[m - 1] : ''}';
      case ReportScheduleType.specificDate:
        final sd = rl.scheduleDate;
        return sd != null
            ? 'تاريخ محدد: ${sd.day}/${sd.month}/${sd.year}'
            : 'تاريخ محدد';
    }
  }

  String get _timeLabel {
    if (reportList.timeAllDay) return 'طوال اليوم';
    final s = reportList.timeStart ?? '';
    final e = reportList.timeEnd ?? '';
    return '$s - $e';
  }

  @override
  Widget build(BuildContext context) {
    final rl = reportList;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.list_alt_rounded,
                color: _kSuccess, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rl.title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kTextPrimary)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 12, color: _kTextSecondary),
                    const SizedBox(width: 3),
                    Text(_scheduleLabel,
                        style: const TextStyle(
                            fontSize: 11, color: _kTextSecondary)),
                    const SizedBox(width: 10),
                    const Icon(Icons.access_time, size: 12, color: _kTextSecondary),
                    const SizedBox(width: 3),
                    Text(_timeLabel,
                        style: const TextStyle(
                            fontSize: 11, color: _kTextSecondary)),
                  ],
                ),
                const SizedBox(height: 3),
                Text('${rl.fields.length} حقل • ${rl.determinants.length} محدد',
                    style:
                        const TextStyle(fontSize: 11, color: _kTextSecondary)),
              ],
            ),
          ),
          _IconBtn(Icons.bar_chart_rounded, _kAccent, onOpenResponses),
          const SizedBox(width: 4),
          _IconBtn(Icons.copy_outlined, _kAccent, onDuplicate),
        ],
      ),
    );
  }
}

// ─── Widget helpers ───────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  const _IconBtn(this.icon, this.color, this.onPressed);
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
