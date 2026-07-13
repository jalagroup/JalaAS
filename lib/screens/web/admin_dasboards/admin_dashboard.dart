// lib/screens/web/admin_dashboard.dart - Updated with Task Checklist Management
import 'package:flutter/material.dart';
import 'package:jala_as/screens/web/admin_dasboards/quality_management/quality_groups_screen.dart';
import 'package:jala_as/screens/web/admin_dasboards/quality_management/quality_management_dashboard.dart';
import 'package:jala_as/screens/web/admin_dasboards/sales_returns_admin_screen.dart';
import 'package:jala_as/screens/web/admin_dasboards/tasks_management/task_checklists_admin_screen.dart';
import 'package:jala_as/screens/web/salary/brands_management_screen.dart';
import 'package:jala_as/screens/web/salary/calculate_salary_screen.dart';
import 'package:jala_as/screens/web/salary/review_report_screen.dart';
import 'package:jala_as/screens/web/salary/set_targets_screen.dart';
import '../../../models/user.dart';
import '../../../models/feature_definition.dart';
import '../../../services/supabase_service.dart';
import '../../../services/permission_service.dart';
import '../../../utils/helpers.dart';
import '../../../utils/constants.dart';
import 'users_management_screen.dart';
import 'sync_data_screen.dart';
import 'quality_management_screen.dart';
import 'fuel_management_screen.dart';
import '../web_login_screen.dart';
import '../../profile_screen.dart';
import 'positions_management_screen.dart';
import '../../../services/auto_sync_service.dart';
import 'report_management/report_lists_screen.dart';
import 'roles_management_screen.dart';
import '../report_builder/report_builder_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  AppUser? _currentUser;
  bool _isLoadingUser = true;
  List<Widget> _pages = [];
  List<_NavigationItem> _navigationItems = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    AutoSyncService.instance.initialize();
  }

  Future<void> _loadCurrentUser() async {
    try {
      _currentUser = await SupabaseService.getCurrentUser();

      if (_currentUser == null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const WebLoginScreen()),
          );
        }
        return;
      }

      // Load permissions if not already in memory (e.g. after browser refresh).
      if (!PermissionService.hasRole) {
        await PermissionService.loadForUser(_currentUser!.id);
      }

      if (!PermissionService.hasRole || !PermissionService.isAdminInterface) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const WebLoginScreen()),
          );
        }
        return;
      }

      _setupNavigationBasedOnPermissions();
      if (mounted) setState(() => _isLoadingUser = false);
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في تحميل بيانات المستخدم',
            isError: true);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WebLoginScreen()),
        );
      }
    }
  }

  void _setupNavigationBasedOnPermissions() {
    _pages.clear();
    _navigationItems.clear();

    void addIf(String key, Widget page, _NavigationItem item) {
      if (PermissionService.hasFeature(key)) {
        _pages.add(page);
        _navigationItems.add(item);
      }
    }

    addIf(AppFeatures.usersManagement, const UsersManagementScreen(),
        _NavigationItem(icon: Icons.people_outline, selectedIcon: Icons.people, label: 'إدارة المستخدمين'));

    addIf(AppFeatures.rolesManagement, const RolesManagementScreen(),
        _NavigationItem(icon: Icons.shield_outlined, selectedIcon: Icons.shield, label: 'إدارة الأدوار'));

    addIf(AppFeatures.reportBuilder, const ReportBuilderScreen(),
        _NavigationItem(icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart, label: 'منشئ التقارير'));

    addIf(AppFeatures.qualityManagement, const QualityManagementDashboard(),
        _NavigationItem(icon: Icons.checklist_outlined, selectedIcon: Icons.checklist, label: 'إدارة مراقبة الجودة'));

    addIf(AppFeatures.reportManagement, const ReportListsScreen(),
        _NavigationItem(icon: Icons.assignment_rounded, selectedIcon: Icons.assignment_rounded, label: 'قوائم التقارير'));

    addIf(AppFeatures.taskChecklistsAdmin, const TaskChecklistsAdminScreen(),
        _NavigationItem(icon: Icons.task_alt_outlined, selectedIcon: Icons.task_alt, label: 'إدارة قوائم المهام'));

    addIf(AppFeatures.salesReturnsAdmin, SalesReturnsAdminScreen(user: _currentUser!),
        _NavigationItem(icon: Icons.assignment_return_outlined, selectedIcon: Icons.assignment_return, label: 'المرتجعات'));

    addIf(AppFeatures.fuelManagement, const FuelManagementScreen(),
        _NavigationItem(icon: Icons.local_gas_station_outlined, selectedIcon: Icons.local_gas_station, label: 'إدارة المحروقات'));

    addIf(AppFeatures.positionsManagement, const PositionsManagementScreen(),
        _NavigationItem(icon: Icons.work_outline, selectedIcon: Icons.work, label: 'المسميات الوظيفية'));

    addIf(AppFeatures.syncData, const SyncDataScreen(),
        _NavigationItem(icon: Icons.sync, selectedIcon: Icons.sync, label: 'مزامنة البيانات'));

    if (_selectedIndex >= _pages.length) _selectedIndex = 0;
  }

  void _openProfile() {
    if (_currentUser == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(user: _currentUser!)),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
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
                  color: const Color(0xFFF16936).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.logout,
                  color: Color(0xFFF16936),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'تسجيل الخروج',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              )
            ],
          ),
          content: const Text(
            'هل تريد تسجيل الخروج؟',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF546E7A),
            ),
          ),
          actionsAlignment: MainAxisAlignment.start,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF546E7A),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF16936),
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.signOut();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const WebLoginScreen(),
            ),
          );
        }
      } catch (e) {
        Helpers.showSnackBar(
          context,
          'فشل في تسجيل الخروج',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(AppConstants.accentColor),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'جارٍ تحميل البيانات...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_currentUser == null || _pages.isEmpty) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red.shade400,
                ),
                const SizedBox(height: 16),
                const Text(
                  'ليس لديك صلاحية للوصول',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'تواصل مع مدير النظام للحصول على الصلاحيات المطلوبة',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF546E7A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF16936),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('تسجيل الخروج'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 768;
          final isTablet =
              constraints.maxWidth >= 768 && constraints.maxWidth < 1024;
          final isDesktop = constraints.maxWidth >= 1024;

          if (isMobile) {
            return _buildMobileLayout();
          } else if (isTablet) {
            return _buildTabletLayout();
          } else {
            return _buildDesktopLayout();
          }
        },
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(showMenuButton: true),
      drawer: _buildDrawer(),
      body: _pages[_selectedIndex],
    );
  }

  Widget _buildTabletLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: Row(
        children: [
          _buildSideNavigation(extended: false),
          Container(width: 1, color: const Color(0xFFE1E5E9)),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: Row(
        children: [
          _buildSideNavigation(extended: true),
          Container(width: 1, color: const Color(0xFFE1E5E9)),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({bool showMenuButton = false}) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              'لوحة التحكم',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF135467).withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.account_balance,
                    color: Color(AppConstants.accentColor),
                    size: 20,
                  );
                },
              ),
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF135467).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getAdminTypeIcon(),
                color: const Color(0xFF135467),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                _getUserTypeDisplayText(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF135467),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF135467).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.person_outline, color: Color(0xFF135467), size: 20),
          ),
          onPressed: _openProfile,
          tooltip: 'الملف الشخصي',
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF16936).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.logout, color: Color(0xFFF16936), size: 20),
          ),
          onPressed: _logout,
          tooltip: 'تسجيل الخروج',
        ),
        if (showMenuButton)
          IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF135467)),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFE1E5E9)),
      ),
    );
  }

  String _getUserTypeDisplayText() => PermissionService.roleName;

  IconData _getAdminTypeIcon() => Icons.admin_panel_settings;

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: Color(0xFF135467)),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Jala Success',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.account_balance,
                                    color: Color(AppConstants.accentColor),
                                    size: 24),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getUserTypeDisplayText(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _navigationItems.length,
              itemBuilder: (context, index) {
                final item = _navigationItems[index];
                final isSelected = _selectedIndex == index;
                return Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: ListTile(
                    selected: isSelected,
                    selectedTileColor:
                        const Color(0xFF135467).withValues(alpha: 0.1),
                    leading: Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      color: isSelected
                          ? const Color(0xFF135467)
                          : const Color(0xFF546E7A),
                      size: 20,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? const Color(0xFF135467)
                            : const Color(0xFF546E7A),
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    onTap: () {
                      setState(() => _selectedIndex = index);
                      Navigator.of(context).pop();
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _openProfile();
              },
              icon: const Icon(Icons.person_outline, size: 18),
              label: const Text('الملف الشخصي'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF135467),
                side: const BorderSide(color: Color(0xFF135467)),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, size: 20, color: Colors.white),
              label: const Text('تسجيل الخروج'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF16936),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideNavigation({required bool extended}) {
    return Container(
      width: extended ? 240 : 72,
      color: Colors.white,
      child: Column(
        children: [
          if (extended) ...[
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'جالا',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF135467).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset('assets/images/logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.account_balance,
                                  color: Color(AppConstants.accentColor),
                                  size: 20)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF135467).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getUserTypeDisplayText(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF135467),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: const Color(0xFFE1E5E9),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF135467).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.account_balance,
                        color: Color(AppConstants.accentColor),
                        size: 20)),
              ),
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: const Color(0xFFE1E5E9),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _navigationItems.length,
              itemBuilder: (context, index) {
                final item = _navigationItems[index];
                final isSelected = _selectedIndex == index;

                if (extended) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      selected: isSelected,
                      selectedTileColor:
                          const Color(0xFF135467).withValues(alpha: 0.1),
                      leading: Icon(
                        isSelected ? item.selectedIcon : item.icon,
                        color: isSelected
                            ? const Color(0xFF135467)
                            : const Color(0xFF546E7A),
                        size: 20,
                      ),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected
                              ? const Color(0xFF135467)
                              : const Color(0xFF546E7A),
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      onTap: () => setState(() => _selectedIndex = index),
                    ),
                  );
                } else {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Tooltip(
                      message: item.label,
                      child: InkWell(
                        onTap: () => setState(() => _selectedIndex = index),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF135467).withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isSelected ? item.selectedIcon : item.icon,
                            color: isSelected
                                ? const Color(0xFF135467)
                                : const Color(0xFF546E7A),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: extended
                ? ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, size: 20, color: Colors.white),
                    label: const Text('تسجيل الخروج'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF16936),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                : IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF16936).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.logout,
                          color: Color(0xFFF16936), size: 20),
                    ),
                    onPressed: _logout,
                    tooltip: 'تسجيل الخروج',
                  ),
          ),
        ],
      ),
    );
  }
}

class _NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}