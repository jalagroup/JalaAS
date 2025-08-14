// lib/screens/web/admin_dashboard.dart
import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../utils/helpers.dart';
import '../../utils/constants.dart';
import 'users_management_screen.dart';
import 'sync_data_screen.dart';
import 'web_login_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>(); // Add this key

  final List<Widget> _pages = [
    const UsersManagementScreen(),
    const SyncDataScreen(),
  ];

  final List<_NavigationItem> _navigationItems = [
    _NavigationItem(
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      label: 'إدارة المستخدمين',
    ),
    _NavigationItem(
      icon: Icons.sync,
      selectedIcon: Icons.sync,
      label: 'مزامنة البيانات',
    ),
  ];

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
                  color: const Color(0xFFF16936).withOpacity(0.1),
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
          actionsAlignment:
              MainAxisAlignment.start, // to match RTL buttons order
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
      key: _scaffoldKey, // Assign the key here
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
          Container(
            width: 1,
            color: const Color(0xFFE1E5E9),
          ),
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
          Container(
            width: 1,
            color: const Color(0xFFE1E5E9),
          ),
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
        children: [
          const Text(
            'لوحة تحكم المدير',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
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
                  color: const Color(0xFF135467).withOpacity(0.1),
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
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Logout button - always visible
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF16936).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.logout,
              color: Color(0xFFF16936),
              size: 20,
            ),
          ),
          onPressed: _logout,
          tooltip: 'تسجيل الخروج',
        ),

        // Profile icon
        Container(
          margin: const EdgeInsets.only(left: 8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF135467).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.person_outline,
              color: Color(0xFF135467),
              size: 20,
            ),
          ),
        ),

        // Menu button for mobile - updated to use the scaffold key
        if (showMenuButton)
          IconButton(
            icon: const Icon(
              Icons.menu,
              color: Color(0xFF135467),
            ),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer(); // Use the key here
            },
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: const Color(0xFFE1E5E9),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF135467),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'جالا - كشف الحساب',
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
                    selectedTileColor: const Color(0xFF135467).withOpacity(0.1),
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
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedIndex = index;
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, size: 20, color: Colors.white),
              label: const Text('تسجيل الخروج'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF16936),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
              child: Row(
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
                      color: const Color(0xFF135467).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
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
                color: const Color(0xFF135467).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
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
                          const Color(0xFF135467).withOpacity(0.1),
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                    ),
                  );
                } else {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Tooltip(
                      message: item.label,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedIndex = index;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF135467).withOpacity(0.1)
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
          // Logout button in side navigation
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: extended
                ? ElevatedButton.icon(
                    onPressed: _logout,
                    icon:
                        const Icon(Icons.logout, size: 20, color: Colors.white),
                    label: const Text('تسجيل الخروج'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF16936),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                : IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF16936).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.logout,
                        color: Color(0xFFF16936),
                        size: 20,
                      ),
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
