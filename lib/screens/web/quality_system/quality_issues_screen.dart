// lib/screens/web/quality_system/quality_issues_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jala_as/models/quality_models.dart';
import '../../../models/user.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';
import 'dart:ui' as ui;
import 'issue_details_screen.dart';

class QualityIssuesScreen extends StatefulWidget {
  final AppUser user;

  const QualityIssuesScreen({super.key, required this.user});

  @override
  State<QualityIssuesScreen> createState() => _QualityIssuesScreenState();
}

class _QualityIssuesScreenState extends State<QualityIssuesScreen> {
  List<QualityCheckpointIssue> _issues = [];
  bool _isLoading = true;
  IssueStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadIssues();
  }

  Future<void> _loadIssues() async {
    setState(() => _isLoading = true);

    try {
      final issues = await SupabaseService.getQualityCheckpointIssues(
        assignedTo: widget.user.id,
        status: _filterStatus,
      );

      setState(() {
        _issues = issues;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في تحميل المشاكل', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back,
                color: Color(AppConstants.primaryColor)),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'مشاكل نقاط الفحص',
            style: TextStyle(
              color: Color(AppConstants.primaryColor),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            PopupMenuButton<IssueStatus?>(
              icon: Icon(Icons.filter_list,
                  color: _filterStatus != null
                      ? const Color(AppConstants.accentColor)
                      : Colors.grey.shade600),
              onSelected: (status) {
                setState(() => _filterStatus = status);
                _loadIssues();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: null,
                  child: Text('الكل'),
                ),
                PopupMenuItem(
                  value: IssueStatus.open,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('مفتوحة'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: IssueStatus.inProgress,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('قيد المعالجة'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: IssueStatus.resolved,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('محلولة'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _issues.isEmpty
                ? _buildEmptyState(isMobile)
                : RefreshIndicator(
                    onRefresh: _loadIssues,
                    child: ListView.builder(
                      padding: EdgeInsets.all(isMobile ? 16 : 24),
                      itemCount: _issues.length,
                      itemBuilder: (context, index) {
                        return _buildIssueCard(_issues[index], isMobile);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmptyState(bool isMobile) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt,
            size: isMobile ? 64 : 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _filterStatus == null
                ? 'لا توجد مشاكل'
                : 'لا توجد مشاكل ${_filterStatus!.displayText}',
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueCard(QualityCheckpointIssue issue, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToIssueDetails(issue),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
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
                            style: TextStyle(
                              fontSize: isMobile ? 13 : 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(issue.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getStatusColor(issue.status),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            issue.status.displayText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(issue.status),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Description
                Text(
                  issue.description,
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 12),

                // Footer
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('yyyy-MM-dd').format(issue.responseDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (issue.issueImages.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      Icon(Icons.image, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        '${issue.issueImages.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios,
                        size: 14, color: Colors.grey.shade400),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(IssueStatus status) {
    switch (status) {
      case IssueStatus.open:
        return Colors.orange;
      case IssueStatus.inProgress:
        return Colors.blue;
      case IssueStatus.resolved:
        return Colors.green;
    }
  }

  void _navigateToIssueDetails(QualityCheckpointIssue issue) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IssueDetailsScreen(
          issue: issue,
          user: widget.user,
        ),
      ),
    );

    if (result == true) {
      _loadIssues();
    }
  }
}
