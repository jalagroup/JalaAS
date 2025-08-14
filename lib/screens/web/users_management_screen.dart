// lib/screens/web/users_management_screen.dart
import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/supabase_service.dart';
import '../../utils/helpers.dart';

// lib/screens/web/users_management_screen.dart - Part 2
import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/supabase_service.dart';
import '../../utils/helpers.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  List<AppUser> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final allUsers = await SupabaseService.getUsers();
      // Filter out admin users
      final nonAdminUsers = allUsers.where((user) => !user.isAdmin).toList();
      setState(() {
        _users = nonAdminUsers;
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
      builder: (context) => const _CreateUserDialog(),
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
      _loadUsers();
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
                color: Colors.red.withOpacity(0.1),
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
        crossAxisAlignment: CrossAxisAlignment.start, // Changed to end for RTL
        children: [
          const Text(
            'إدارة المستخدمين',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C3E50),
            ),
            textAlign: TextAlign.left, // Align text to right
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
      textDirection: TextDirection.ltr, // RTL for header row
      children: [
        IconButton(
          onPressed: _loadUsers,
          icon: const Icon(
            Icons.refresh_outlined,
            size: 15,
          ),
          tooltip: 'تحديث',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF135467).withOpacity(0.1),
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
            color: const Color(0xFF135467).withOpacity(0.05),
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
                  height: 36, // Set fixed height here
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
                      fontSize: 12, // Smaller font size
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
                        size: 16, // Smaller icon
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, // Reduced horizontal padding
                        vertical: 9, // Reduced vertical padding
                      ),
                      isDense: true, // This is important for reducing height
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
                    color: const Color(0xFF135467).withOpacity(0.1),
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
                color: const Color(0xFF135467).withOpacity(0.1),
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
              color: const Color(0xFF135467).withOpacity(0.05),
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
              color: const Color(0xFF135467).withOpacity(0.05),
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
                    color: const Color(0xFF135467).withOpacity(0.1),
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
            color: const Color(0xFF135467).withOpacity(0.05),
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
                // Username - 25%
                Expanded(
                  flex: 25,
                  child: _buildTableHeader('اسم المستخدم'),
                ),
                // Email - 30%
                Expanded(
                  flex: 30,
                  child: _buildTableHeader('البريد الإلكتروني'),
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
                return _buildAlignedUserRow(user, index, isTablet);
              },
            ),
          ),
        ],
      ),
    );
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

  Widget _buildAlignedUserRow(AppUser user, int index, bool isTablet) {
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
          // Username - 25%
          Expanded(
            flex: 25,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF135467).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 14,
                      color: Color(0xFF135467),
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
          // Email - 30%
          Expanded(
            flex: 30,
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
                    color: const Color(0xFF135467).withOpacity(0.08),
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
                  user.area ?? '-',
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
          // Actions - 15%
          Expanded(
            flex: 15,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () => _showEditUserDialog(user),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF135467).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: Color(0xFF135467),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _deleteUser(user),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
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
              ),
            ),
          ),
        ],
      ),
    );
  }

// Updated mobile users list to also exclude admins
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
                color: const Color(0xFF135467).withOpacity(0.04),
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
                        color: const Color(0xFF135467).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 16,
                        color: Color(0xFF135467),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.username,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C3E50),
                            ),
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
                              color: const Color(0xFF135467).withOpacity(0.1),
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
                          if (user.area != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              'المنطقة: ${user.area}',
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
                        InkWell(
                          onTap: () => _showEditUserDialog(user),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFF135467).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: Color(0xFF135467),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _deleteUser(user),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
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
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserRow(AppUser user, int index, bool isTablet) {
    final isEven = index % 2 == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          Expanded(
            flex: 2,
            child: Text(
              user.username,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              user.email,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF546E7A),
              ),
            ),
          ),
          if (!isTablet) ...[
            Expanded(
              flex: 2,
              child: Text(
                user.salesman,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF546E7A),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                user.area ?? '-',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF546E7A),
                ),
              ),
            ),
          ],
          Expanded(
            flex: 1,
            child: _buildUserTypeBadge(user.isAdmin),
          ),
          Expanded(
            flex: 1,
            child: _buildStatusBadge(user.isActive),
          ),
          Expanded(
            flex: 1,
            child: _buildActionButtons(user),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTypeBadge(bool isAdmin) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAdmin
            ? const Color(0xFFF16936).withOpacity(0.1)
            : const Color(0xFF135467).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isAdmin ? 'مدير' : 'مستخدم',
        style: TextStyle(
          color: isAdmin ? const Color(0xFFF16936) : const Color(0xFF135467),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF10B981).withOpacity(0.1)
            : const Color(0xFF6B7280).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? 'مفعل' : 'غير مفعل',
        style: TextStyle(
          color: isActive ? const Color(0xFF10B981) : const Color(0xFF6B7280),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildActionButtons(AppUser user) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _showEditUserDialog(user),
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'تعديل',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF135467).withOpacity(0.1),
            foregroundColor: const Color(0xFF135467),
            padding: const EdgeInsets.all(8),
            minimumSize: const Size(32, 32),
          ),
        ),
        if (!user.isAdmin) ...[
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => _deleteUser(user),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'حذف',
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.1),
              foregroundColor: Colors.red,
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(32, 32),
            ),
          ),
        ],
      ],
    );
  }
}

// Dialog Classes
class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

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

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _salesmanController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await SupabaseService.createUser(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        salesman: _salesmanController.text.trim(),
        area: _areaController.text.trim().isEmpty
            ? null
            : _areaController.text.trim(),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'إضافة مستخدم جديد',
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
                      color: const Color(0xFF135467).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.person_add,
                      color: Color(0xFF135467),
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Flexible(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildInputField(
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
                        const SizedBox(height: 16),
                        _buildInputField(
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
                        const SizedBox(height: 16),
                        _buildInputField(
                          controller: _passwordController,
                          label: 'كلمة المرور',
                          icon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
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
                        const SizedBox(height: 16),
                        _buildInputField(
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
                        const SizedBox(height: 16),
                        _buildInputField(
                          controller: _areaController,
                          label: 'رقم المنطقة (اختياري)',
                          icon: Icons.location_on_outlined,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pop(false),
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
                      onPressed: _isLoading ? null : _createUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF135467),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
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
          fontSize: 14,
        ),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF9CA3AF),
          size: 20,
        ),
        suffixIcon: suffixIcon,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: Colors.red,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.user.username;
    _emailController.text = widget.user.email;
    _salesmanController.text = widget.user.salesman;
    _areaController.text = widget.user.area ?? '';
    _isActive = widget.user.isActive;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _salesmanController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await SupabaseService.updateUser(
        userId: widget.user.id,
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        salesman: _salesmanController.text.trim(),
        area: _areaController.text.trim().isEmpty
            ? null
            : _areaController.text.trim(),
        isActive: _isActive,
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'تعديل المستخدم',
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
                      color: const Color(0xFFF16936).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Color(0xFFF16936),
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Flexible(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildInputField(
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
                        const SizedBox(height: 16),
                        _buildInputField(
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
                        const SizedBox(height: 16),
                        _buildInputField(
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
                        const SizedBox(height: 16),
                        _buildInputField(
                          controller: _areaController,
                          label: 'رقم المنطقة (اختياري)',
                          icon: Icons.location_on_outlined,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFE1E5E9),
                            ),
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
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'المستخدم مفعل',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                              ),
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
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
                                        size: 14,
                                        color: Color(0xFF135467),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pop(false),
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
                      onPressed: _isLoading ? null : _updateUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF16936),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF2C3E50),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF9CA3AF),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: Colors.red,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}
