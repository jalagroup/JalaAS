// lib/screens/web/users_management_screen.dart - Part 1: Main Screen and Core Methods
import 'package:flutter/material.dart';
import 'package:jala_as/models/position.dart';
import 'package:jala_as/models/salesman.dart';
import 'package:jala_as/screens/web/admin_dasboards/assign_additional_contacts_dialog.dart';
import 'package:jala_as/services/api_service.dart';
import '../../../models/user.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/helpers.dart';

class UsersManagementScreen extends StatefulWidget {
  final AppUser? currentUser;
  const UsersManagementScreen({super.key, this.currentUser});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  List<AppUser> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _periodicAreaAssignment = 'all'; // Add this as a class variable

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showAssignAdditionalContactsDialog(AppUser user) async {
    if (!user.isRegularUser) {
      Helpers.showSnackBar(
        context,
        'يمكن تعيين عملاء إضافية للمستخدمين العاديين فقط',
        isError: true,
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AssignAdditionalContactsDialog(user: user),
    );

    if (result == true) {
      await _loadUsers();
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final loggedInUser =
          widget.currentUser ?? await SupabaseService.getCurrentUser();
      final allUsers = await SupabaseService.getUsers();
      final List<AppUser> managedUsers;
      if (loggedInUser?.isQualityControlAdmin == true) {
        // Quality control admins only manage quality_controller users
        managedUsers =
            allUsers.where((user) => user.isQualityController).toList();
      } else {
        // Filter out only the super admin (salesman='0')
        managedUsers = allUsers.where((user) => !user.isSuperAdmin).toList();
      }
      setState(() {
        _users = managedUsers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Helpers.showSnackBar(
        context,
        'فشل في تحميل قائمة المستخدمين',
        isError: true,
      );
    }
  }

  List<AppUser> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    return _users.where((user) {
      return user.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.salesman.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _showCreateUserDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CreateUserDialog(currentUser: widget.currentUser),
    );

    if (result == true) {
      _loadUsers();
    }
  }

  Future<void> _showEditUserDialog(AppUser user) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EditUserDialog(user: user),
    );

    if (result == true) {
      await _loadUsers();
    }
  }

  Future<void> _deleteUser(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'حذف المستخدم',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
          ],
        ),
        content: Text(
          'هل تريد حذف المستخدم "${user.username}"؟',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF546E7A),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF546E7A),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.deleteUser(user.id);
        Helpers.showSnackBar(context, 'تم حذف المستخدم بنجاح');
        _loadUsers();
      } catch (e) {
        Helpers.showSnackBar(
          context,
          'فشل في حذف المستخدم',
          isError: true,
        );
      }
    }
  }

  Future<void> _changeUserPassword(AppUser user) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscure = true;
    bool obscureConfirm = true;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          elevation: 8,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF135467).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lock_outline,
                    color: Color(0xFF135467), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'تغيير كلمة المرور - ${user.username}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50)),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passwordController,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور الجديدة',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  suffixIcon: IconButton(
                    icon: Icon(
                        obscure ? Icons.visibility_off : Icons.visibility,
                        size: 18),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  suffixIcon: IconButton(
                    icon: Icon(
                        obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 18),
                    onPressed: () =>
                        setState(() => obscureConfirm = !obscureConfirm),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF546E7A)),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF135467),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('تغيير'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final newPassword = passwordController.text.trim();
      final confirmPassword = confirmController.text.trim();
      if (newPassword.length < 6) {
        Helpers.showSnackBar(context, 'كلمة المرور يجب أن تكون 6 أحرف على الأقل', isError: true);
        confirmController.dispose();
        passwordController.dispose();
        return;
      }
      if (newPassword != confirmPassword) {
        Helpers.showSnackBar(context, 'كلمة المرور وتأكيدها غير متطابقين', isError: true);
        confirmController.dispose();
        passwordController.dispose();
        return;
      }
      try {
        await SupabaseService.changeUserPassword(user.id, newPassword);
        if (mounted) Helpers.showSnackBar(context, 'تم تغيير كلمة المرور بنجاح');
      } catch (e) {
        if (mounted) Helpers.showSnackBar(context, 'فشل في تغيير كلمة المرور', isError: true);
      }
    }
    passwordController.dispose();
    confirmController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        final isTablet =
            constraints.maxWidth >= 768 && constraints.maxWidth < 1024;

        return Container(
          color: const Color(0xFFF8F9FA),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isMobile),
                const SizedBox(height: 20),
                _buildSearchAndStats(isMobile),
                const SizedBox(height: 20),
                Expanded(
                  child: _buildUsersTable(isMobile, isTablet),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إدارة المستخدمين',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C3E50),
            ),
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showCreateUserDialog,
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: const Text(
                'إضافة مستخدم',
                style: TextStyle(
                  fontSize: 12,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF16936),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      textDirection: TextDirection.ltr,
      children: [
        IconButton(
          onPressed: _loadUsers,
          icon: const Icon(
            Icons.refresh_outlined,
            size: 15,
          ),
          tooltip: 'تحديث',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF135467).withValues(alpha: 0.1),
            foregroundColor: const Color(0xFF135467),
            padding: const EdgeInsets.all(3),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _showCreateUserDialog,
          icon: const Icon(
            Icons.add,
            size: 18,
            color: Colors.white,
          ),
          label: const Text(
            'إضافة مستخدم',
            style: TextStyle(
              fontSize: 12,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF16936),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const Spacer(),
        const Text(
          'إدارة المستخدمين',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2C3E50),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndStats(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF135467).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFE1E5E9),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2C3E50),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'البحث في المستخدمين...',
                      hintStyle: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Color(0xFF9CA3AF),
                        size: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF135467).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.people_outline,
                        color: Color(0xFF135467),
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'المجموع: ${_filteredUsers.length}',
                        style: const TextStyle(
                          color: Color(0xFF135467),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF135467).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.people_outline,
                    color: Color(0xFF135467),
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'المجموع: ${_filteredUsers.length}',
                    style: const TextStyle(
                      color: Color(0xFF135467),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
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

  Widget _buildUsersTable(bool isMobile, bool isTablet) {
    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF135467).withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(
              color: Color(0xFF135467),
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (_filteredUsers.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF135467).withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF135467).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.people_outline,
                    size: 32,
                    color: Color(0xFF135467),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? 'لا يوجد مستخدمون'
                      : 'لا توجد نتائج للبحث',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF546E7A),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (isMobile) {
      return _buildMobileUsersList();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF135467).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // Username - 20%
                Expanded(
                  flex: 20,
                  child: _buildTableHeader('اسم المستخدم'),
                ),
                // Email - 25%
                Expanded(
                  flex: 25,
                  child: _buildTableHeader('البريد الإلكتروني'),
                ),
                // User Type - 15%
                Expanded(
                  flex: 15,
                  child: _buildTableHeaderCenter('نوع المستخدم'),
                ),
                // Salesman - 15%
                if (!isTablet)
                  Expanded(
                    flex: 15,
                    child: _buildTableHeaderCenter('المندوب'),
                  ),
                // Area - 15%
                if (!isTablet)
                  Expanded(
                    flex: 15,
                    child: _buildTableHeaderCenter('المنطقة'),
                  ),
                // Status - 10%
                Expanded(
                  flex: 10,
                  child: _buildTableHeaderCenter('الحالة'),
                ),
                // Actions - 15%
                Expanded(
                  flex: 15,
                  child: _buildTableHeaderCenter('الإجراءات'),
                ),
              ],
            ),
          ),
          // Table Body
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _filteredUsers.length,
              itemBuilder: (context, index) {
                final user = _filteredUsers[index];
                return _buildUserRow(user, index, isTablet);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRow(AppUser user, int index, bool isTablet) {
    final isEven = index % 2 == 0;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFFAFBFC),
        border: const Border(
          bottom: BorderSide(
            color: Color(0xFFE1E5E9),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Username - 20%
          Expanded(
            flex: 20,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _getUserTypeColor(user).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      _getUserTypeIcon(user),
                      size: 14,
                      color: _getUserTypeColor(user),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      user.username,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Email - 25%
          Expanded(
            flex: 25,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                user.email,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF546E7A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // User Type - 15%
          Expanded(
            flex: 15,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(child: _buildUserTypeBadge(user)),
            ),
          ),
          // Salesman - 15%
          if (!isTablet)
            Expanded(
              flex: 15,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF135467).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    user.salesman,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF135467),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          // Area - 15%
          if (!isTablet)
            Expanded(
              flex: 15,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  _getAreaDisplayText(user),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF546E7A),
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          // Status - 10%
          Expanded(
            flex: 10,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: user.isActive
                            ? const Color(0xFF10B981)
                            : const Color(0xFF6B7280),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      user.isActive ? 'مفعل' : 'غير مفعل',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: user.isActive
                            ? const Color(0xFF10B981)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
// Actions - UPDATE THIS SECTION
          Expanded(
            flex: 15,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Assign Additional Contacts button (for regular users only)
                  if (user.isRegularUser) ...[
                    InkWell(
                      onTap: () => _showAssignAdditionalContactsDialog(user),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF16936).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.person_add_outlined,
                          size: 14,
                          color: Color(0xFFF16936),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // Edit button
                  InkWell(
                    onTap: () => _showEditUserDialog(user),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF135467).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: Color(0xFF135467),
                      ),
                    ),
                  ),

                  // Change password button
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _changeUserPassword(user),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.lock_reset_outlined,
                        size: 14,
                        color: Colors.orange,
                      ),
                    ),
                  ),

                  // Delete button
                  if (!user.isSystemAdmin) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _deleteUser(user),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          size: 14,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _getAreaDisplayText(AppUser user) {
    if (user.isQualityController) return '-';
    if (user.isQualityControlAdmin) return '-';
    if (user.isSalesAdmin &&
        user.area != '00' &&
        user.area != null &&
        user.area!.isNotEmpty) {
      return 'محدد';
    }
    return user.area ?? '-';
  }

  Color _getUserTypeColor(AppUser user) {
    if (user.isSystemAdmin) return const Color(0xFFF16936);
    if (user.isSalesOfficer) return const Color(0xFF3B82F6);
    if (user.isSalesAdmin) return const Color(0xFF10B981);
    if (user.isQualityControlAdmin) return const Color(0xFFD97706);
    if (user.isQualityController) return const Color(0xFF8B5CF6);
    return const Color(0xFF135467);
  }

  IconData _getUserTypeIcon(AppUser user) {
    if (user.isSystemAdmin) return Icons.admin_panel_settings_outlined;
    if (user.isSalesOfficer) return Icons.assignment_ind_outlined;
    if (user.isSalesAdmin) return Icons.supervisor_account_outlined;
    if (user.isQualityControlAdmin) return Icons.verified_user_outlined;
    if (user.isQualityController) return Icons.checklist_outlined;
    return Icons.person_outline;
  }

  Widget _buildTableHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF546E7A),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildTableHeaderCenter(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF546E7A),
          letterSpacing: 0.3,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

// Also update mobile list builder
  Widget _buildMobileUsersList() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF135467).withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _getUserTypeColor(user).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            _getUserTypeIcon(user),
                            size: 16,
                            color: _getUserTypeColor(user),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      user.username,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2C3E50),
                                      ),
                                    ),
                                  ),
                                  _buildUserTypeBadge(user),
                                ],
                              ),
                              Text(
                                user.email,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF546E7A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: user.isActive
                                ? const Color(0xFF10B981)
                                : const Color(0xFF6B7280),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF135467).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'المندوب: ${user.salesman}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF135467),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (user.area != null &&
                                  user.area!.isNotEmpty &&
                                  !user.isQualityController) ...[
                                const SizedBox(width: 8),
                                Text(
                                  _getAreaDisplayText(user),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF546E7A),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Assign Additional Contacts button for regular users
                            if (user.isRegularUser) ...[
                              InkWell(
                                onTap: () =>
                                    _showAssignAdditionalContactsDialog(user),
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF16936)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    Icons.person_add_outlined,
                                    size: 16,
                                    color: Color(0xFFF16936),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],

                            // Edit button
                            InkWell(
                              onTap: () => _showEditUserDialog(user),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF135467).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: Color(0xFF135467),
                                ),
                              ),
                            ),

                            // Change password button
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _changeUserPassword(user),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.lock_reset_outlined,
                                  size: 16,
                                  color: Colors.orange,
                                ),
                              ),
                            ),

                            // Delete button
                            if (!user.isSystemAdmin) ...[
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => _deleteUser(user),
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ]),
            ));
      },
    );
  }
}

Widget _buildUserTypeBadge(AppUser user) {
  Color backgroundColor;
  Color textColor;
  String text;

  if (user.isSystemAdmin) {
    backgroundColor = const Color(0xFFF16936).withValues(alpha: 0.1);
    textColor = const Color(0xFFF16936);
    text = user.adminTypeDisplayText;
  } else if (user.isSalesOfficer) {
    backgroundColor = const Color(0xFF3B82F6).withValues(alpha: 0.1);
    textColor = const Color(0xFF3B82F6);
    text = 'ضابط مبيعات';
  } else if (user.isSalesAdmin) {
    backgroundColor = const Color(0xFF10B981).withValues(alpha: 0.1);
    textColor = const Color(0xFF10B981);
    text = 'مدير مبيعات';
  } else if (user.isQualityControlAdmin) {
    backgroundColor = const Color(0xFFD97706).withValues(alpha: 0.1);
    textColor = const Color(0xFFD97706);
    text = 'مدير مراقبة الجودة';
  } else if (user.isQualityController) {
    backgroundColor = const Color(0xFF8B5CF6).withValues(alpha: 0.1);
    textColor = const Color(0xFF8B5CF6);
    text = 'مراقب جودة';
  } else {
    backgroundColor = const Color(0xFF135467).withValues(alpha: 0.1);
    textColor = const Color(0xFF135467);
    text = 'مستخدم عادي';
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    ),
  );
}

// Create User Dialog
class _CreateUserDialog extends StatefulWidget {
  final AppUser? currentUser;
  const _CreateUserDialog({this.currentUser});

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _salesmanController = TextEditingController();
  final _areaController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _hasArea = false;
  String _periodicAreaAssignment = 'all';
  bool _canSeeAllQualityForms = false;

  String _userType = 'user';
  bool _isSalesAdmin = false;
  List<String> _selectedSalesmen = [];
  List<Position> _positions = [];
  String? _selectedPositionId;

  List<Salesman> get _availableSalesmen => ApiService.getAvailableSalesmen();

  bool get _isQualityControlAdminCreating =>
      widget.currentUser?.isQualityControlAdmin == true;

  @override
  void initState() {
    super.initState();
    if (_isQualityControlAdminCreating) {
      _userType = 'quality_controller';
    }
    _loadPositions();
  }

  Future<void> _loadPositions() async {
    try {
      final positions = await SupabaseService.getPositions();
      if (mounted) setState(() => _positions = positions);
    } catch (_) {}
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _salesmanController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  void _onUserTypeChanged(String value) {
    setState(() {
      _userType = value;
      _isSalesAdmin = false;
      _selectedSalesmen.clear();
      _hasArea = false;
      _canSeeAllQualityForms = false;
      if (value == 'admin') {
        _salesmanController.text = '00';
        _areaController.clear();
      } else if (value == 'quality_controller' || value == 'quality_control_admin') {
        _salesmanController.clear();
        _areaController.clear();
      } else {
        _salesmanController.clear();
        _areaController.clear();
      }
    });
  }

  void _onSalesAdminChanged(bool value) {
    setState(() {
      _isSalesAdmin = value;
      if (_isSalesAdmin) {
        _salesmanController.text = '00';
        _selectedSalesmen.clear();
        _areaController.clear();
        _hasArea = false;
      } else {
        _salesmanController.clear();
        _selectedSalesmen.clear();
        _areaController.clear();
        _hasArea = false;
      }
    });
  }

  void _onHasAreaChanged(bool value) {
    setState(() {
      _hasArea = value;
      if (!_hasArea) {
        _areaController.clear();
      }
    });
  }

  void _showSalesmenSelector() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => _SalesmenSelectorDialog(
        availableSalesmen: _availableSalesmen,
        selectedSalesmen: _selectedSalesmen,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedSalesmen = result;
        if (_selectedSalesmen.isEmpty) {
          _areaController.text = '00';
        } else {
          _areaController.text = _selectedSalesmen.join('');
        }
      });
    }
  }

  String _getSalesmenDisplayText() {
    if (!_isSalesAdmin) return '';
    if (_selectedSalesmen.isEmpty) return 'جميع المندوبين';

    return _selectedSalesmen.map((code) {
      final salesman = _availableSalesmen.firstWhere(
        (s) => s.code == code,
        orElse: () => Salesman(code: code, name: 'غير معروف'),
      );
      return '${salesman.name} ($code)';
    }).join(', ');
  }

// Add this method to both dialog classes
  Widget _buildPeriodicAreaAssignmentSelector() {
    if (!_isSalesAdmin) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'تخصيص نطاق التقارير الدورية',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE1E5E9)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              RadioListTile<String>(
                value: 'all',
                groupValue: _periodicAreaAssignment,
                onChanged: (value) {
                  setState(() {
                    _periodicAreaAssignment = value!;
                  });
                },
                title: const Row(
                  children: [
                    Icon(Icons.map, size: 16, color: Color(0xFF135467)),
                    SizedBox(width: 8),
                    Text(
                      'كل المناطق',
                      style: TextStyle(fontSize: 13, color: Color(0xFF2C3E50)),
                    ),
                  ],
                ),
                activeColor: const Color(0xFF135467),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                dense: true,
              ),
              Divider(height: 1, color: Colors.grey[300]),
              RadioListTile<String>(
                value: 'north',
                groupValue: _periodicAreaAssignment,
                onChanged: (value) {
                  setState(() {
                    _periodicAreaAssignment = value!;
                  });
                },
                title: const Row(
                  children: [
                    Icon(Icons.north, size: 16, color: Color(0xFF135467)),
                    SizedBox(width: 8),
                    Text(
                      'مناطق الشمال',
                      style: TextStyle(fontSize: 13, color: Color(0xFF2C3E50)),
                    ),
                  ],
                ),
                activeColor: const Color(0xFF135467),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                dense: true,
              ),
              Divider(height: 1, color: Colors.grey[300]),
              RadioListTile<String>(
                value: 'south',
                groupValue: _periodicAreaAssignment,
                onChanged: (value) {
                  setState(() {
                    _periodicAreaAssignment = value!;
                  });
                },
                title: const Row(
                  children: [
                    Icon(Icons.south, size: 16, color: Color(0xFF135467)),
                    SizedBox(width: 8),
                    Text(
                      'مناطق الجنوب',
                      style: TextStyle(fontSize: 13, color: Color(0xFF2C3E50)),
                    ),
                  ],
                ),
                activeColor: const Color(0xFF135467),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                dense: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String userType = _userType;
      String salesmanValue;
      String? areaValue;

      if (_userType == 'admin') {
        salesmanValue = '00';
        areaValue = null;
      } else if (_userType == 'quality_controller') {
        salesmanValue = '000';
        areaValue = null;
      } else if (_userType == 'quality_control_admin') {
        salesmanValue = '000';
        areaValue = null;
      } else if (_isSalesAdmin) {
        salesmanValue = '00';
        if (_selectedSalesmen.isEmpty) {
          areaValue = '00';
        } else {
          areaValue = _selectedSalesmen.join('');
        }
      } else {
        salesmanValue = _salesmanController.text.trim();
        if (_hasArea) {
          final areaText = _areaController.text.trim();
          areaValue = areaText.isEmpty ? null : areaText;
        } else {
          areaValue = null;
        }
      }

      await SupabaseService.createUser(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        salesman: salesmanValue,
        area: areaValue,
        userType: userType,
        periodicAreaAssignment: _isSalesAdmin ? _periodicAreaAssignment : null,
        canSeeAllQualityForms: _canSeeAllQualityForms,
        positionId: _selectedPositionId,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        Helpers.showSnackBar(context, 'تم إنشاء المستخدم بنجاح');
      }
    } catch (e) {
      Helpers.showSnackBar(
        context,
        'فشل في إنشاء المستخدم',
        isError: true,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final dialogWidth = isMobile ? screenSize.width - 32 : 500.0;
    final maxHeight = screenSize.height - 80;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : (screenSize.width - 500) / 2,
          vertical: 40,
        ),
        child: Container(
          width: dialogWidth,
          constraints: BoxConstraints(
            maxHeight: maxHeight,
            maxWidth: dialogWidth,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'إضافة مستخدم جديد',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF135467).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.person_add,
                        color: Color(0xFF135467),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 16 : 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCompactInputField(
                          controller: _usernameController,
                          label: 'اسم المستخدم',
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى إدخال اسم المستخدم';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        _buildCompactInputField(
                          controller: _emailController,
                          label: 'البريد الإلكتروني',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى إدخال البريد الإلكتروني';
                            }
                            if (!Helpers.isValidEmail(value)) {
                              return 'البريد الإلكتروني غير صحيح';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        _buildCompactInputField(
                          controller: _passwordController,
                          label: 'كلمة المرور',
                          icon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 18,
                              color: const Color(0xFF9CA3AF),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى إدخال كلمة المرور';
                            }
                            if (value.length < 6) {
                              return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // User type selector with Quality Controller
                        if (_isQualityControlAdminCreating)
                          _buildLockedQualityControllerBadge()
                        else
                          _buildCompactUserTypeSelector(),
                        const SizedBox(height: 12),

                        // Conditional fields
                        if (_userType == 'quality_control_admin') ...[
                          _buildQualityFormsPermissionToggle(),
                          const SizedBox(height: 12),
                        ],

                        if (_userType == 'user') ...[
                          _buildCompactSalesAdminToggle(),
                          const SizedBox(height: 12),
                          if (_isSalesAdmin) ...[
                            _buildCompactSalesmenSelector(),
                            const SizedBox(height: 12),
                            _buildPeriodicAreaAssignmentSelector(),
                          ] else ...[
                            _buildCompactInputField(
                              controller: _salesmanController,
                              label: 'رقم المندوب',
                              icon: Icons.badge_outlined,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'يرجى إدخال رقم المندوب';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // Area switch toggle
                            _buildAreaToggle(),
                            const SizedBox(height: 12),

                            // Area input field (only shown when _hasArea is true)
                            if (_hasArea) ...[
                              _buildCompactInputField(
                                controller: _areaController,
                                label: 'رقم المنطقة',
                                icon: Icons.location_on_outlined,
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ],

                        // Position dropdown
                        const SizedBox(height: 4),
                        _buildPositionDropdown(),
                      ],
                    ),
                  ),
                ),
              ),

              // Footer
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF546E7A),
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 10 : 12,
                          ),
                        ),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF135467),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 10 : 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('إنشاء'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactUserTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'نوع المستخدم',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE1E5E9)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              RadioListTile<String>(
                value: 'admin',
                groupValue: _userType,
                onChanged: (value) => _onUserTypeChanged(value!),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF16936).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'مدير النظام',
                        style: TextStyle(
                          color: Color(0xFFF16936),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'إدارة كاملة للنظام',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF546E7A)),
                      ),
                    ),
                  ],
                ),
                activeColor: const Color(0xFFF16936),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                dense: true,
              ),
              Divider(height: 1, color: Colors.grey[300]),
              RadioListTile<String>(
                value: 'sales_officer',
                groupValue: _userType,
                onChanged: (value) => _onUserTypeChanged(value!),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'ضابط مبيعات',
                        style: TextStyle(
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'مراجعة العملاء الجدد',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF546E7A)),
                      ),
                    ),
                  ],
                ),
                activeColor: const Color(0xFF3B82F6),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                dense: true,
              ),
              Divider(height: 1, color: Colors.grey[300]),
              RadioListTile<String>(
                value: 'quality_control_admin',
                groupValue: _userType,
                onChanged: (value) => _onUserTypeChanged(value!),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'مدير مراقبة الجودة',
                        style: TextStyle(
                          color: Color(0xFFD97706),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'إدارة وإشراف على مراقبة الجودة',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF546E7A)),
                      ),
                    ),
                  ],
                ),
                activeColor: const Color(0xFFD97706),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                dense: true,
              ),
              Divider(height: 1, color: Colors.grey[300]),
              RadioListTile<String>(
                value: 'quality_controller',
                groupValue: _userType,
                onChanged: (value) => _onUserTypeChanged(value!),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'مراقب جودة',
                        style: TextStyle(
                          color: Color(0xFF8B5CF6),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'إدارة تقارير مراقبة الجودة',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF546E7A)),
                      ),
                    ),
                  ],
                ),
                activeColor: const Color(0xFF8B5CF6),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                dense: true,
              ),
              Divider(height: 1, color: Colors.grey[300]),
              RadioListTile<String>(
                value: 'user',
                groupValue: _userType,
                onChanged: (value) => _onUserTypeChanged(value!),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF135467).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'مستخدم',
                        style: TextStyle(
                          color: Color(0xFF135467),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'مدير مبيعات أو مستخدم عادي',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF546E7A)),
                      ),
                    ),
                  ],
                ),
                activeColor: const Color(0xFF135467),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                dense: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQualityFormsPermissionToggle() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Switch(
            value: _canSeeAllQualityForms,
            onChanged: (value) {
              setState(() {
                _canSeeAllQualityForms = value;
              });
            },
            activeColor: const Color(0xFFD97706),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'صلاحية رؤية جميع النماذج',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF2C3E50),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'يمكنه رؤية جميع نماذج الجودة أو فقط ما أنشأه',
                  style: TextStyle(fontSize: 11, color: Color(0xFF546E7A)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _canSeeAllQualityForms
                  ? const Color(0xFFD97706).withValues(alpha: 0.1)
                  : const Color(0xFF6B7280).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _canSeeAllQualityForms ? 'الكل' : 'محدود',
              style: TextStyle(
                color: _canSeeAllQualityForms
                    ? const Color(0xFFD97706)
                    : const Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedQualityControllerBadge() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'نوع المستخدم',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.checklist_outlined, size: 16, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 8),
              const Text(
                'مراقب جودة',
                style: TextStyle(
                  color: Color(0xFF8B5CF6),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.lock_outline, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPositionDropdown() {
    final validId = _positions.any((p) => p.id == _selectedPositionId)
        ? _selectedPositionId
        : null;
    return DropdownButtonFormField<String>(
      initialValue: validId,
      decoration: InputDecoration(
        labelText: 'المسمى الوظيفي (اختياري)',
        prefixIcon: const Icon(Icons.work_outline, size: 18, color: Color(0xFF135467)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF135467), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        labelStyle: const TextStyle(fontSize: 13),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('بدون مسمى', style: TextStyle(fontSize: 13))),
        ..._positions.map((p) => DropdownMenuItem(
              value: p.id,
              child: Text(p.name, style: const TextStyle(fontSize: 13)),
            )),
      ],
      onChanged: (v) => setState(() => _selectedPositionId = v),
    );
  }

  // Helper widget methods for Create User Dialog
  Widget _buildCompactInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF2C3E50),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontSize: 13,
        ),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF9CA3AF),
          size: 18,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE1E5E9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE1E5E9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF135467), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }

  Widget _buildCompactSalesAdminToggle() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E5E9)),
      ),
      child: Row(
        children: [
          Switch(
            value: _isSalesAdmin,
            onChanged: _onSalesAdminChanged,
            activeColor: const Color(0xFF135467),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'مدير مبيعات',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF2C3E50),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _isSalesAdmin
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : const Color(0xFF135467).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _isSalesAdmin ? 'مدير مبيعات' : 'مستخدم عادي',
              style: TextStyle(
                color: _isSalesAdmin
                    ? const Color(0xFF10B981)
                    : const Color(0xFF135467),
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSalesmenSelector() {
    return InkWell(
      onTap: _showSalesmenSelector,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE1E5E9)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.people_outline,
              color: Color(0xFF9CA3AF),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'المندوبين المتاحين',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getSalesmenDisplayText(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2C3E50),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF9CA3AF),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaToggle() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E5E9)),
      ),
      child: Row(
        children: [
          Switch(
            value: _hasArea,
            onChanged: _onHasAreaChanged,
            activeColor: const Color(0xFF135467),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'يوجد منطقة محددة',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF2C3E50),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _hasArea
                  ? const Color(0xFF135467).withValues(alpha: 0.1)
                  : const Color(0xFF6B7280).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _hasArea ? 'محدد' : 'غير محدد',
              style: TextStyle(
                color: _hasArea
                    ? const Color(0xFF135467)
                    : const Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Edit User Dialog
class _EditUserDialog extends StatefulWidget {
  final AppUser user;

  const _EditUserDialog({required this.user});

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _salesmanController = TextEditingController();
  final _areaController = TextEditingController();
  bool _isActive = false;
  bool _isLoading = false;
  bool _hasArea = false;
  String _periodicAreaAssignment = 'all';
  bool _canSeeAllQualityForms = false;

  String _userType = 'user';
  bool _isSalesAdmin = false;
  List<String> _selectedSalesmen = [];
  List<Position> _positions = [];
  String? _selectedPositionId;

  List<Salesman> get _availableSalesmen => ApiService.getAvailableSalesmen();

  // lib/screens/web/users_management_screen.dart - Part 4: Edit Dialog Continuation and Salesmen Selector

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.user.username;
    _emailController.text = widget.user.email;
    _salesmanController.text = widget.user.salesman;
    _areaController.text = widget.user.area ?? '';
    _isActive = widget.user.isActive;
    _userType = widget.user.userType;
    _periodicAreaAssignment = widget.user.periodicAreaAssignment ?? 'all';
    _canSeeAllQualityForms = widget.user.canSeeAllQualityForms;

    _isSalesAdmin = widget.user.isSalesAdmin;

    _hasArea = widget.user.area != null && widget.user.area!.isNotEmpty;

    if (_isSalesAdmin && widget.user.area != null && widget.user.area != '00') {
      _selectedSalesmen = _parseSalesmenFromArea(widget.user.area!);
    }

    _selectedPositionId = widget.user.positionId;
    _loadPositions();
  }

  Future<void> _loadPositions() async {
    try {
      final positions = await SupabaseService.getPositions();
      if (mounted) setState(() => _positions = positions);
    } catch (_) {}
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _salesmanController.dispose();
    _areaController.dispose();
    super.dispose();
  }

// Add this method to both dialog classes
  Widget _buildPeriodicAreaAssignmentSelector() {
    if (!_isSalesAdmin) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'تخصيص نطاق التقارير الدورية',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE1E5E9)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              RadioListTile<String>(
                value: 'all',
                groupValue: _periodicAreaAssignment,
                onChanged: (value) {
                  setState(() {
                    _periodicAreaAssignment = value!;
                  });
                },
                title: const Row(
                  children: [
                    Icon(Icons.map, size: 16, color: Color(0xFF135467)),
                    SizedBox(width: 8),
                    Text(
                      'كل المناطق',
                      style: TextStyle(fontSize: 13, color: Color(0xFF2C3E50)),
                    ),
                  ],
                ),
                activeColor: const Color(0xFF135467),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                dense: true,
              ),
              Divider(height: 1, color: Colors.grey[300]),
              RadioListTile<String>(
                value: 'north',
                groupValue: _periodicAreaAssignment,
                onChanged: (value) {
                  setState(() {
                    _periodicAreaAssignment = value!;
                  });
                },
                title: const Row(
                  children: [
                    Icon(Icons.north, size: 16, color: Color(0xFF135467)),
                    SizedBox(width: 8),
                    Text(
                      'مناطق الشمال',
                      style: TextStyle(fontSize: 13, color: Color(0xFF2C3E50)),
                    ),
                  ],
                ),
                activeColor: const Color(0xFF135467),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                dense: true,
              ),
              Divider(height: 1, color: Colors.grey[300]),
              RadioListTile<String>(
                value: 'south',
                groupValue: _periodicAreaAssignment,
                onChanged: (value) {
                  setState(() {
                    _periodicAreaAssignment = value!;
                  });
                },
                title: const Row(
                  children: [
                    Icon(Icons.south, size: 16, color: Color(0xFF135467)),
                    SizedBox(width: 8),
                    Text(
                      'مناطق الجنوب',
                      style: TextStyle(fontSize: 13, color: Color(0xFF2C3E50)),
                    ),
                  ],
                ),
                activeColor: const Color(0xFF135467),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                dense: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<String> _parseSalesmenFromArea(String areaValue) {
    if (areaValue == '00' || areaValue.isEmpty) return [];

    List<String> salesmen = [];
    for (int i = 0; i < areaValue.length; i += 3) {
      if (i + 3 <= areaValue.length) {
        String salesmanCode = areaValue.substring(i, i + 3);
        salesmen.add(salesmanCode);
      }
    }
    return salesmen;
  }

// UPDATE the _onUserTypeChanged method
  void _onUserTypeChanged(String value) {
    setState(() {
      _userType = value;
      _isSalesAdmin = false;
      _selectedSalesmen.clear();
      _hasArea = false;
      _canSeeAllQualityForms = false;
      if (value == 'admin') {
        _salesmanController.text = '00';
        _areaController.clear();
      } else if (value == 'quality_controller' || value == 'quality_control_admin') {
        _salesmanController.clear();
        _areaController.clear();
      } else if (value == 'sales_officer') {
        _salesmanController.text = '999';
        _areaController.clear();
      } else {
        _salesmanController.clear();
        _areaController.clear();
      }
    });
  }

  void _onSalesAdminChanged(bool value) {
    setState(() {
      _isSalesAdmin = value;
      if (_isSalesAdmin) {
        _salesmanController.text = '00';
        _selectedSalesmen.clear();
        _areaController.clear();
        _hasArea = false;
      } else {
        _salesmanController.clear();
        _selectedSalesmen.clear();
        _areaController.clear();
        _hasArea = false;
      }
    });
  }

  void _onHasAreaChanged(bool value) {
    setState(() {
      _hasArea = value;
      if (!_hasArea) {
        _areaController.clear();
      }
    });
  }

  void _showSalesmenSelector() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => _SalesmenSelectorDialog(
        availableSalesmen: _availableSalesmen,
        selectedSalesmen: _selectedSalesmen,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedSalesmen = result;
        if (_selectedSalesmen.isEmpty) {
          _areaController.text = '00';
        } else {
          _areaController.text = _selectedSalesmen.join('');
        }
      });
    }
  }

  String _getSalesmenDisplayText() {
    if (!_isSalesAdmin) return '';
    if (_selectedSalesmen.isEmpty) return 'جميع المندوبين';

    return _selectedSalesmen.map((code) {
      final salesman = _availableSalesmen.firstWhere(
        (s) => s.code == code,
        orElse: () => Salesman(code: code, name: 'غير معروف'),
      );
      return '${salesman.name} ($code)';
    }).join(', ');
  }

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String userType = _userType;
      String salesmanValue;
      String? areaValue;

      if (_userType == 'admin') {
        salesmanValue = '00';
        areaValue = null;
      } else if (_userType == 'quality_controller') {
        salesmanValue = '000';
        areaValue = null;
      } else if (_userType == 'quality_control_admin') {
        salesmanValue = '000';
        areaValue = null;
      } else if (_isSalesAdmin) {
        salesmanValue = '00';
        if (_selectedSalesmen.isEmpty) {
          areaValue = '00';
        } else {
          areaValue = _selectedSalesmen.join('');
        }
      } else {
        salesmanValue = _salesmanController.text.trim();
        if (_hasArea) {
          final areaText = _areaController.text.trim();
          areaValue = areaText == '' ? null : areaText;
        } else {
          areaValue = null;
        }
      }

// In _EditUserDialog._updateUser():
      await SupabaseService.updateUser(
        userId: widget.user.id,
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        salesman: salesmanValue,
        area: areaValue,
        userType: userType,
        periodicAreaAssignment: _isSalesAdmin ? _periodicAreaAssignment : null,
        isActive: _isActive,
        canSeeAllQualityForms: _canSeeAllQualityForms,
        positionId: _selectedPositionId,
        clearPosition: _selectedPositionId == null,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        Helpers.showSnackBar(context, 'تم تحديث المستخدم بنجاح');
      }
    } catch (e) {
      Helpers.showSnackBar(
        context,
        'فشل في تحديث المستخدم',
        isError: true,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final dialogWidth = isMobile ? screenSize.width - 32 : 500.0;
    final maxHeight = screenSize.height - 80;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : (screenSize.width - 500) / 2,
          vertical: 40,
        ),
        child: Container(
          width: dialogWidth,
          constraints: BoxConstraints(
            maxHeight: maxHeight,
            maxWidth: dialogWidth,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'تعديل المستخدم',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF16936).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Color(0xFFF16936),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 16 : 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCompactInputField(
                          controller: _usernameController,
                          label: 'اسم المستخدم',
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى إدخال اسم المستخدم';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        _buildCompactInputField(
                          controller: _emailController,
                          label: 'البريد الإلكتروني',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى إدخال البريد الإلكتروني';
                            }
                            if (!Helpers.isValidEmail(value)) {
                              return 'البريد الإلكتروني غير صحيح';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Quality forms permission (shown at top for visibility)
                        if (_userType == 'quality_control_admin') ...[
                          _buildQualityFormsPermissionToggle(),
                          const SizedBox(height: 12),
                        ],

                        // User type selector
                        _buildCompactUserTypeSelector(),
                        const SizedBox(height: 12),

                        if (_userType == 'user') ...[
                          _buildCompactSalesAdminToggle(),
                          const SizedBox(height: 12),
                          if (_isSalesAdmin) ...[
                            _buildCompactSalesmenSelector(),
                            const SizedBox(height: 12),
                            _buildPeriodicAreaAssignmentSelector(),
                          ] else ...[
                            _buildCompactInputField(
                              controller: _salesmanController,
                              label: 'رقم المندوب',
                              icon: Icons.badge_outlined,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'يرجى إدخال رقم المندوب';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // Area switch toggle
                            _buildAreaToggle(),
                            const SizedBox(height: 12),

                            // Area input field (only shown when _hasArea is true)
                            if (_hasArea) ...[
                              _buildCompactInputField(
                                controller: _areaController,
                                label: 'رقم المنطقة',
                                icon: Icons.location_on_outlined,
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ],

                        // Position dropdown
                        const SizedBox(height: 4),
                        _buildPositionDropdown(),
                        const SizedBox(height: 12),
                        _buildCompactActiveToggle(),
                      ],
                    ),
                  ),
                ),
              ),

              // Footer
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF546E7A),
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 10 : 12,
                          ),
                        ),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF16936),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 10 : 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('تحديث'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods for Edit Dialog (same as Create Dialog)
  Widget _buildCompactInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF2C3E50),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontSize: 13,
        ),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF9CA3AF),
          size: 18,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE1E5E9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE1E5E9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF135467), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }

  Widget _buildCompactUserTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'نوع المستخدم',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE1E5E9)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              RadioListTile<String>(
                value: 'admin',
                groupValue: _userType,
                onChanged: (value) => _onUserTypeChanged(value!),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF16936).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'مدير النظام',
                        style: TextStyle(
                          color: Color(0xFFF16936),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'إدارة كاملة للنظام',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF546E7A)),
                      ),
                    ),
                  ],
                ),
                activeColor: const Color(0xFFF16936),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                dense: true,
              ),
              Divider(height: 1, color: Colors.grey[300]),
              RadioListTile<String>(
                value: 'quality_control_admin',
                groupValue: _userType,
                onChanged: (value) => _onUserTypeChanged(value!),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'مدير مراقبة الجودة',
                        style: TextStyle(
                          color: Color(0xFFD97706),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'إدارة وإشراف على مراقبة الجودة',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF546E7A)),
                      ),
                    ),
                  ],
                ),
                activeColor: const Color(0xFFD97706),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                dense: true,
              ),
              Divider(height: 1, color: Colors.grey[300]),
              RadioListTile<String>(
                value: 'quality_controller',
                groupValue: _userType,
                onChanged: (value) => _onUserTypeChanged(value!),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'مراقب جودة',
                        style: TextStyle(
                          color: Color(0xFF8B5CF6),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'إدارة تقارير مراقبة الجودة',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF546E7A)),
                      ),
                    ),
                  ],
                ),
                activeColor: const Color(0xFF8B5CF6),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                dense: true,
              ),
              Divider(height: 1, color: Colors.grey[300]),
              RadioListTile<String>(
                value: 'user',
                groupValue: _userType,
                onChanged: (value) => _onUserTypeChanged(value!),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF135467).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'مستخدم',
                        style: TextStyle(
                          color: Color(0xFF135467),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'مدير مبيعات أو مستخدم عادي',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF546E7A)),
                      ),
                    ),
                  ],
                ),
                activeColor: const Color(0xFF135467),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                dense: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQualityFormsPermissionToggle() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Switch(
            value: _canSeeAllQualityForms,
            onChanged: (value) {
              setState(() {
                _canSeeAllQualityForms = value;
              });
            },
            activeColor: const Color(0xFFD97706),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'صلاحية رؤية جميع النماذج',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF2C3E50),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'يمكنه رؤية جميع نماذج الجودة أو فقط ما أنشأه',
                  style: TextStyle(fontSize: 11, color: Color(0xFF546E7A)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _canSeeAllQualityForms
                  ? const Color(0xFFD97706).withValues(alpha: 0.1)
                  : const Color(0xFF6B7280).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _canSeeAllQualityForms ? 'الكل' : 'محدود',
              style: TextStyle(
                color: _canSeeAllQualityForms
                    ? const Color(0xFFD97706)
                    : const Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSalesAdminToggle() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E5E9)),
      ),
      child: Row(
        children: [
          Switch(
            value: _isSalesAdmin,
            onChanged: _onSalesAdminChanged,
            activeColor: const Color(0xFF135467),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'مدير مبيعات',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF2C3E50),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _isSalesAdmin
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : const Color(0xFF135467).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _isSalesAdmin ? 'مدير مبيعات' : 'مستخدم عادي',
              style: TextStyle(
                color: _isSalesAdmin
                    ? const Color(0xFF10B981)
                    : const Color(0xFF135467),
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSalesmenSelector() {
    return InkWell(
      onTap: _showSalesmenSelector,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE1E5E9)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.people_outline,
              color: Color(0xFF9CA3AF),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'المندوبين المتاحين',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getSalesmenDisplayText(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2C3E50),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF9CA3AF),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaToggle() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E5E9)),
      ),
      child: Row(
        children: [
          Switch(
            value: _hasArea,
            onChanged: _onHasAreaChanged,
            activeColor: const Color(0xFF135467),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'يوجد منطقة محددة',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF2C3E50),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _hasArea
                  ? const Color(0xFF135467).withValues(alpha: 0.1)
                  : const Color(0xFF6B7280).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _hasArea ? 'محدد' : 'غير محدد',
              style: TextStyle(
                color: _hasArea
                    ? const Color(0xFF135467)
                    : const Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionDropdown() {
    final validId = _positions.any((p) => p.id == _selectedPositionId)
        ? _selectedPositionId
        : null;
    return DropdownButtonFormField<String>(
      initialValue: validId,
      decoration: InputDecoration(
        labelText: 'المسمى الوظيفي (اختياري)',
        prefixIcon: const Icon(Icons.work_outline, size: 18, color: Color(0xFF135467)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF135467), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        labelStyle: const TextStyle(fontSize: 13),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('بدون مسمى', style: TextStyle(fontSize: 13))),
        ..._positions.map((p) => DropdownMenuItem(
              value: p.id,
              child: Text(p.name, style: const TextStyle(fontSize: 13)),
            )),
      ],
      onChanged: (v) => setState(() => _selectedPositionId = v),
    );
  }

  Widget _buildCompactActiveToggle() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E5E9)),
      ),
      child: Row(
        children: [
          Switch(
            value: _isActive,
            onChanged: (value) {
              setState(() {
                _isActive = value;
              });
            },
            activeColor: const Color(0xFF135467),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'المستخدم مفعل',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF2C3E50),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: _isActive
                    ? const Color(0xFF135467)
                    : const Color(0xFFE1E5E9),
                width: 2,
              ),
            ),
            child: _isActive
                ? const Icon(
                    Icons.check,
                    size: 10,
                    color: Color(0xFF135467),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

// Salesmen Selector Dialog
class _SalesmenSelectorDialog extends StatefulWidget {
  final List<Salesman> availableSalesmen;
  final List<String> selectedSalesmen;

  const _SalesmenSelectorDialog({
    required this.availableSalesmen,
    required this.selectedSalesmen,
  });

  @override
  State<_SalesmenSelectorDialog> createState() =>
      _SalesmenSelectorDialogState();
}

class _SalesmenSelectorDialogState extends State<_SalesmenSelectorDialog> {
  late List<String> _selectedSalesmen;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedSalesmen = List.from(widget.selectedSalesmen);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Salesman> get _filteredSalesmen {
    if (_searchQuery.isEmpty) return widget.availableSalesmen;
    return widget.availableSalesmen.where((salesman) {
      return salesman.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          salesman.code.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _toggleSalesman(String code) {
    setState(() {
      if (_selectedSalesmen.contains(code)) {
        _selectedSalesmen.remove(code);
      } else {
        _selectedSalesmen.add(code);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedSalesmen = widget.availableSalesmen.map((s) => s.code).toList();
    });
  }

  void _selectNone() {
    setState(() {
      _selectedSalesmen.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width > 600 ? 500 : null,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Text(
                    'اختيار المندوبين',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF135467).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.people_outline,
                      color: Color(0xFF135467),
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // lib/screens/web/users_management_screen.dart - Part 5: Final Part - Salesmen Selector Dialog Continuation

              // Selected count and actions
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF135467).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'محدد: ${_selectedSalesmen.length}',
                      style: const TextStyle(
                        color: Color(0xFF135467),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _selectAll,
                    child: const Text(
                      'تحديد الكل',
                      style: TextStyle(
                        color: Color(0xFF135467),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _selectNone,
                    child: const Text(
                      'إلغاء الكل',
                      style: TextStyle(
                        color: Color(0xFF546E7A),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search field
              TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2C3E50),
                ),
                decoration: InputDecoration(
                  hintText: 'البحث في المندوبين...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF9CA3AF),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFFE1E5E9),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFFE1E5E9),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFF135467),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Salesmen list
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE1E5E9)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: _filteredSalesmen.length,
                    itemBuilder: (context, index) {
                      final salesman = _filteredSalesmen[index];
                      final isSelected =
                          _selectedSalesmen.contains(salesman.code);

                      return Container(
                        decoration: BoxDecoration(
                          border: index > 0
                              ? const Border(
                                  top: BorderSide(
                                    color: Color(0xFFE1E5E9),
                                    width: 0.5,
                                  ),
                                )
                              : null,
                        ),
                        child: CheckboxListTile(
                          value: isSelected,
                          onChanged: (value) => _toggleSalesman(salesman.code),
                          title: Text(
                            salesman.name,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          subtitle: Text(
                            'كود: ${salesman.code}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          activeColor: const Color(0xFF135467),
                          checkColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF546E7A),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(_selectedSalesmen),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF135467),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('تأكيد'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
