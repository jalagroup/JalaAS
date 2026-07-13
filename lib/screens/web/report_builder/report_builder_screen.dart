import 'package:flutter/material.dart';
import '../../../models/custom_report.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';
import 'report_builder_editor_screen.dart';
import 'report_viewer_screen.dart';

/// Admin screen: list + manage custom reports.
class ReportBuilderScreen extends StatefulWidget {
  const ReportBuilderScreen({super.key});

  @override
  State<ReportBuilderScreen> createState() => _ReportBuilderScreenState();
}

class _ReportBuilderScreenState extends State<ReportBuilderScreen> {
  static const _primary = Color(AppConstants.primaryColor);
  static const _accent = Color(AppConstants.accentColor);

  List<CustomReport> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await SupabaseService.getCustomReports();
      if (mounted) setState(() => _reports = list);
    } catch (e) {
      if (mounted) Helpers.showApiErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor({CustomReport? report}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReportBuilderEditorScreen(report: report),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _preview(CustomReport report) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportViewerScreen(report: report),
      ),
    );
  }

  Future<void> _confirmDelete(CustomReport report) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف التقرير'),
          content: Text('هل تريد حذف التقرير "${report.nameAr}"؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حذف')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseService.deleteCustomReport(report.id);
      _load();
    } catch (e) {
      if (mounted) Helpers.showApiErrorDialog(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: _primary,
          title: const Text(
            'منشئ التقارير المخصصة',
            style: TextStyle(
                color: _primary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: Colors.grey.shade200),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditor(),
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('تقرير جديد'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _reports.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _reports.length,
                      itemBuilder: (_, i) => _ReportCard(
                        report: _reports[i],
                        onEdit: () => _openEditor(report: _reports[i]),
                        onPreview: () => _preview(_reports[i]),
                        onDelete: () => _confirmDelete(_reports[i]),
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('لا توجد تقارير مخصصة بعد',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500)),
            const SizedBox(height: 8),
            Text('اضغط على "تقرير جديد" لبناء أول تقرير',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
      );
}

// ── Report card ───────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final CustomReport report;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final VoidCallback onDelete;

  const _ReportCard({
    required this.report,
    required this.onEdit,
    required this.onPreview,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = report.config;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Company badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(AppConstants.accentColor)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  cfg.company.displayName,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(AppConstants.accentColor)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(report.nameAr,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(AppConstants.primaryColor))),
                  const SizedBox(height: 4),
                  Text(
                    cfg.endpoint,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _chip(
                          '${cfg.fields.where((f) => f.visible).length} حقل'),
                      const SizedBox(width: 6),
                      _chip('${cfg.inputs.length} مدخل'),
                      if (cfg.filters.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _chip('${cfg.filters.length} فلتر'),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            Column(
              children: [
                _iconBtn(
                    Icons.play_arrow_outlined, Colors.green.shade600, onPreview,
                    'معاينة'),
                const SizedBox(height: 4),
                _iconBtn(Icons.edit_outlined,
                    const Color(AppConstants.primaryColor), onEdit, 'تعديل'),
                const SizedBox(height: 4),
                _iconBtn(
                    Icons.delete_outline, Colors.red.shade400, onDelete, 'حذف'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      );

  Widget _iconBtn(
          IconData icon, Color color, VoidCallback onTap, String tooltip) =>
      Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      );
}
