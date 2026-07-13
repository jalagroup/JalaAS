// lib/screens/web/quality_system/admin_issues_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jala_as/models/quality_models.dart';
import 'package:jala_as/models/user.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/constants.dart';
import 'package:jala_as/utils/helpers.dart';
import 'dart:ui' as ui;
import 'issue_details_screen.dart';

class AdminIssuesScreen extends StatefulWidget {
  final AppUser user;

  const AdminIssuesScreen({super.key, required this.user});

  @override
  State<AdminIssuesScreen> createState() => _AdminIssuesScreenState();
}

class _AdminIssuesScreenState extends State<AdminIssuesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<QualityCheckpointIssue> _allIssues = [];
  List<AppUser> _controllers = [];
  Map<String, String> _userNames = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getQualityCheckpointIssues(),
        SupabaseService.getUsers(),
      ]);
      final users = results[1] as List<AppUser>;
      setState(() {
        _allIssues = results[0] as List<QualityCheckpointIssue>;
        _controllers = users;
        _userNames = {for (final u in users) u.id: u.username};
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) Helpers.showSnackBar(context, 'فشل في تحميل البيانات', isError: true);
    }
  }

  List<QualityCheckpointIssue> _filtered(IssueStatus? status) {
    if (status == null) return _allIssues;
    return _allIssues.where((i) => i.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          automaticallyImplyLeading: false,
          title: const Text(
            'إدارة مشاكل الجودة',
            style: TextStyle(
              color: Color(AppConstants.primaryColor),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            labelColor: const Color(AppConstants.primaryColor),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(AppConstants.primaryColor),
            tabs: [
              Tab(text: 'الكل (${_allIssues.length})'),
              Tab(text: 'مفتوحة (${_filtered(IssueStatus.open).length})'),
              Tab(text: 'قيد المعالجة (${_filtered(IssueStatus.inProgress).length})'),
              Tab(text: 'محلولة (${_filtered(IssueStatus.resolved).length})'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildIssueList(_filtered(null), isMobile),
                  _buildIssueList(_filtered(IssueStatus.open), isMobile),
                  _buildIssueList(_filtered(IssueStatus.inProgress), isMobile),
                  _buildIssueList(_filtered(IssueStatus.resolved), isMobile),
                ],
              ),
      ),
    );
  }

  Widget _buildIssueList(List<QualityCheckpointIssue> issues, bool isMobile) {
    if (issues.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'لا توجد مشاكل',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        itemCount: issues.length,
        itemBuilder: (context, index) => _buildIssueCard(issues[index], isMobile),
      ),
    );
  }

  Widget _buildIssueCard(QualityCheckpointIssue issue, bool isMobile) {
    final statusColor = _statusColor(issue.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _openDetails(issue),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              issue.formTitle,
                              style: TextStyle(
                                fontSize: isMobile ? 15 : 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(AppConstants.primaryColor),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              issue.checkPointTitle,
                              style: TextStyle(fontSize: isMobile ? 13 : 14, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              issue.status.displayText,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    issue.description,
                    style: TextStyle(fontSize: isMobile ? 13 : 14, color: Colors.grey.shade700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        'بواسطة: ${_userNames[issue.assignedBy] ?? '—'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('yyyy-MM-dd').format(issue.responseDate),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      if (issue.issueImages.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.image, size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text('${issue.issueImages.length}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                      const Spacer(),
                      Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey.shade400),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Action buttons — only for non-resolved issues
          if (issue.status != IssueStatus.resolved) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showReassignDialog(issue),
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text('إعادة تكليف', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(AppConstants.primaryColor),
                        side: const BorderSide(color: Color(AppConstants.primaryColor)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showCloseDialog(issue),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('إغلاق', style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openDetails(QualityCheckpointIssue issue) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IssueDetailsScreen(issue: issue, user: widget.user),
      ),
    );
    if (result == true) _loadData();
  }

  void _showReassignDialog(QualityCheckpointIssue issue) {
    AppUser? selectedController;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('إعادة تكليف المشكلة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.checkPointTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                const Text('اختر المسؤول الجديد:'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<AppUser>(
                    value: selectedController,
                    hint: const Text('اختر مراقب الجودة'),
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: _controllers
                        .where((c) => c.id != issue.assignedTo)
                        .map((c) => DropdownMenuItem(value: c, child: Text(c.username)))
                        .toList(),
                    onChanged: (val) => setDialogState(() => selectedController = val),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: selectedController == null
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await _reassign(issue, selectedController!);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppConstants.primaryColor),
                ),
                child: const Text('تأكيد', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reassign(QualityCheckpointIssue issue, AppUser newController) async {
    try {
      await SupabaseService.reassignIssue(
        issueId: issue.id,
        newAssignedTo: newController.id,
      );
      if (mounted) {
        Helpers.showSnackBar(context, 'تم إعادة التكليف إلى ${newController.username}');
        _loadData();
      }
    } catch (e) {
      if (mounted) Helpers.showSnackBar(context, 'فشل في إعادة التكليف', isError: true);
    }
  }

  void _showCloseDialog(QualityCheckpointIssue issue) {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إغلاق المشكلة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(issue.checkPointTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'ملاحظات الإغلاق',
                  hintText: 'اكتب سبب الإغلاق أو تقرير الحل...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (notesController.text.trim().isEmpty) {
                  Helpers.showSnackBar(context, 'يرجى إدخال ملاحظات الإغلاق', isError: true);
                  return;
                }
                Navigator.pop(ctx);
                await _closeIssue(issue, notesController.text.trim());
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('إغلاق كمحلولة', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _closeIssue(QualityCheckpointIssue issue, String notes) async {
    try {
      await SupabaseService.resolveIssue(
        issueId: issue.id,
        resolutionNotes: notes,
      );
      if (mounted) {
        Helpers.showSnackBar(context, 'تم إغلاق المشكلة بنجاح');
        _loadData();
      }
    } catch (e) {
      if (mounted) Helpers.showSnackBar(context, 'فشل في إغلاق المشكلة', isError: true);
    }
  }

  Color _statusColor(IssueStatus status) {
    switch (status) {
      case IssueStatus.open:
        return Colors.orange;
      case IssueStatus.inProgress:
        return Colors.blue;
      case IssueStatus.resolved:
        return Colors.green;
    }
  }
}
