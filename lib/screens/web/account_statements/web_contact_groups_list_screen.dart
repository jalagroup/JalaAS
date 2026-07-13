// lib/screens/web/web_contact_groups_list_screen.dart
import 'package:flutter/material.dart';
import 'package:jala_as/models/contact_group.dart';
import 'package:jala_as/models/user.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/constants.dart';
import 'package:jala_as/utils/arabic_text_helper.dart';
import 'web_create_contact_group_screen.dart';
import 'web_group_date_selection_screen.dart';
import 'dart:ui' as ui;

class ContactGroupsListScreen extends StatefulWidget {
  final AppUser user;

  const ContactGroupsListScreen({
    super.key,
    required this.user,
  });

  @override
  State<ContactGroupsListScreen> createState() =>
      _ContactGroupsListScreenState();
}

// lib/screens/web/web_contact_groups_list_screen.dart - OPTIMIZED

class _ContactGroupsListScreenState extends State<ContactGroupsListScreen>
    with AutomaticKeepAliveClientMixin {
  List<ContactGroup> _groups = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGroups();
    });
  }

  Future<void> _loadGroups() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final groups = await SupabaseService.getContactGroups();
      if (mounted) {
        setState(() {
          _groups = groups;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('فشل في تحميل المجموعات: ${e.toString()}', true);
      }
    }
  }

  void _showSnackBar(String message, bool isError) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteGroup(ContactGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من حذف مجموعة "${group.name}"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await SupabaseService.deleteContactGroup(group.id!);
        _showSnackBar('تم حذف المجموعة بنجاح', false);
        await _loadGroups();
      } catch (e) {
        _showSnackBar('فشل في حذف المجموعة: ${e.toString()}', true);
      }
    }
  }

  void _navigateToCreateGroup() async {
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CreateContactGroupScreen(user: widget.user),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.03, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );

    if (result == true && mounted) {
      await _loadGroups();
    }
  }

  void _navigateToEditGroup(ContactGroup group) async {
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CreateContactGroupScreen(
          user: widget.user,
          editingGroup: group,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.03, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );

    if (result == true && mounted) {
      await _loadGroups();
    }
  }

  void _navigateToGroupDateSelection(ContactGroup group) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            GroupDateSelectionScreen(
          user: widget.user,
          group: group,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.03, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isMobile = size.width < 768;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back,
                color: Color(AppConstants.primaryColor)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'مجموعات العملاء',
            style: TextStyle(
              color: Color(AppConstants.primaryColor),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.refresh,
                color: Color(AppConstants.accentColor),
              ),
              onPressed: _loadGroups,
              tooltip: 'تحديث',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 1000 : double.infinity,
            ),
            child: _buildContent(isMobile),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _navigateToCreateGroup,
          backgroundColor: const Color(AppConstants.accentColor),
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(
            'إنشاء مجموعة',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: isMobile ? 14 : 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isMobile) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(AppConstants.accentColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'جاري تحميل المجموعات...',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (_groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 24 : 32),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Icon(
                Icons.group_outlined,
                size: isMobile ? 60 : 80,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'لا توجد مجموعات',
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'قم بإنشاء مجموعة جديدة للعملاء',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      physics: const BouncingScrollPhysics(),
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        return _GroupCard(
          key: ValueKey(group.id),
          group: group,
          isMobile: isMobile,
          onDelete: () => _deleteGroup(group),
          onEdit: () => _navigateToEditGroup(group),
          onGetStatements: () => _navigateToGroupDateSelection(group),
        );
      },
    );
  }
}

class _GroupCard extends StatelessWidget {
  final ContactGroup group;
  final bool isMobile;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onGetStatements;

  const _GroupCard({
    super.key,
    required this.group,
    required this.isMobile,
    required this.onDelete,
    required this.onEdit,
    required this.onGetStatements,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onGetStatements,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isMobile ? 10 : 12),
                      decoration: BoxDecoration(
                        color: const Color(AppConstants.accentColor),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.group,
                        color: Colors.white,
                        size: isMobile ? 20 : 24,
                      ),
                    ),
                    SizedBox(width: isMobile ? 12 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            ArabicTextHelper.cleanText(group.name),
                            style: TextStyle(
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.w600,
                              color: const Color(AppConstants.primaryColor),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isMobile ? 4 : 6),
                          Row(
                            children: [
                              Icon(
                                Icons.people,
                                size: isMobile ? 14 : 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${group.contactCodes.length} عميل',
                                style: TextStyle(
                                  fontSize: isMobile ? 12 : 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.edit,
                        color: const Color(AppConstants.accentColor),
                        size: isMobile ? 20 : 22,
                      ),
                      onPressed: onEdit,
                      tooltip: 'تعديل',
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: Colors.red.shade400,
                        size: isMobile ? 20 : 22,
                      ),
                      onPressed: onDelete,
                      tooltip: 'حذف',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),

                SizedBox(height: isMobile ? 12 : 16),

                // Quick Action Button
                SizedBox(
                  width: double.infinity,
                  height: isMobile ? 44 : 48,
                  child: ElevatedButton.icon(
                    onPressed: onGetStatements,
                    icon: Icon(
                      Icons.analytics,
                      size: isMobile ? 18 : 20,
                    ),
                    label: Text(
                      'عرض كشف الحساب',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(AppConstants.accentColor),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
