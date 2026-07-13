import 'package:flutter/material.dart';
import '../../../models/custom_report.dart';
import '../../../models/user.dart';
import '../../../services/supabase_service.dart';
import '../../../services/permission_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';
import 'report_viewer_screen.dart';

/// User-facing screen that lists the custom reports the current role can access.
class CustomReportsListScreen extends StatefulWidget {
  final AppUser currentUser;

  const CustomReportsListScreen({super.key, required this.currentUser});

  @override
  State<CustomReportsListScreen> createState() =>
      _CustomReportsListScreenState();
}

class _CustomReportsListScreenState extends State<CustomReportsListScreen> {
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
      final all = await SupabaseService.getCustomReports();
      // Filter to only reports the role allows and that are active
      final allowed = PermissionService.filterReports(all)
          .where((r) => r.isActive)
          .toList();
      if (mounted) setState(() => _reports = allowed);
    } catch (e) {
      if (mounted) Helpers.showApiErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
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
            'التقارير المخصصة',
            style: TextStyle(
                color: _primary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: Colors.grey.shade200),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _reports.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _reports.length,
                    itemBuilder: (_, i) => _buildCard(_reports[i]),
                  ),
      ),
    );
  }

  Widget _buildCard(CustomReport report) {
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => ReportViewerScreen(report: report)),
          ),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      report.config.company.displayName,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _accent),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(report.nameAr,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _primary)),
                      if (report.description != null &&
                          report.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(report.description!,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey.shade400),
              ],
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
            Text('لا توجد تقارير متاحة',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500)),
          ],
        ),
      );
}
