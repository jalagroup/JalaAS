// lib/screens/web/web_welcome_screen.dart
import 'package:flutter/material.dart';
import 'package:jala_as/screens/web/web_salesman_selection_screen.dart';
import '../../models/user.dart';
import '../../services/supabase_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import 'web_contact_selection_screen.dart';
import 'web_aging_report_screen.dart';
import 'web_login_screen.dart';

class WebWelcomeScreen extends StatefulWidget {
  const WebWelcomeScreen({super.key});

  @override
  State<WebWelcomeScreen> createState() => _WebWelcomeScreenState();
}

class _WebWelcomeScreenState extends State<WebWelcomeScreen> {
  AppUser? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      _currentUser = await SupabaseService.getCurrentUser();

      if (_currentUser == null) {
        _navigateToLogin();
        return;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'فشل في تحميل بيانات المستخدم',
          isError: true,
        );
        _navigateToLogin();
      }
    }
  }

  Future<void> _logout() async {
    try {
      await SupabaseService.signOut();
      await Helpers.setLoggedIn(false);
      await Helpers.clearUserData();
      if (mounted) {
        _navigateToLogin();
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'فشل في تسجيل الخروج',
          isError: true,
        );
      }
    }
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const WebLoginScreen(),
        ),
      );
    }
  }

  void _navigateToContactSelection() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ContactSelectionScreen(user: _currentUser!),
      ),
    );
  }

// Updated _navigateToAgingReport method in WebWelcomeScreen

  void _navigateToAgingReport() {
    // Check if user is admin (salesman=00 and area=00)
    if (_currentUser!.salesman == '00' && _currentUser!.area == '00') {
      // Navigate to salesman selection screen for admin users
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => WebSalesmanSelectionScreen(user: _currentUser!),
        ),
      );
    } else {
      // Navigate directly to aging report for regular users
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => WebAgingReportScreen(user: _currentUser!),
        ),
      );
    }
  }

// Don't forget to add this import at the top of web_welcome_screen.dart:
// import 'web_salesman_selection_screen.dart';

  String _getGreetingMessage() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return 'صباح الخير ☀️';
    } else if (hour >= 12 && hour < 17) {
      return 'مساء الخير 🌤️';
    } else {
      return 'مساء الخير 🌙';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isDesktop = screenWidth >= 1024;

    if (_isLoading) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.grey[50],
          body: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Color(AppConstants.accentColor),
              ),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _currentUser != null
            ? _WebWelcomeAppBar(
                currentUser: _currentUser!,
                onLogout: _logout,
                isDesktop: isDesktop,
              )
            : AppBar(
                title: const Text('الرئيسية'),
                backgroundColor: const Color(AppConstants.primaryColor),
                foregroundColor: Colors.white,
                automaticallyImplyLeading: false,
              ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 800 : 600,
            ),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Welcome Message
                  Container(
                    padding: EdgeInsets.all(isMobile ? 20 : 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Logo
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Image.asset(
                            AppConstants.logoPath,
                            width: isMobile ? 50 : 60,
                            height: isMobile ? 50 : 60,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.account_balance,
                                size: isMobile ? 50 : 60,
                                color: const Color(AppConstants.primaryColor),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 20),

                        Text(
                          _getGreetingMessage(),
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(AppConstants.primaryColor),
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 8),

                        if (_currentUser != null)
                          Text(
                            _currentUser!.username,
                            style: TextStyle(
                              fontSize: isMobile ? 16 : 18,
                              color: const Color(AppConstants.accentColor),
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),

                        // Show additional user info on desktop
                        if (_currentUser != null && isDesktop) ...[
                          const SizedBox(height: 8),
                          Text(
                            'مندوب: ${_currentUser!.salesman}${_currentUser!.area != null ? ' - منطقة: ${_currentUser!.area}' : ''}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: isMobile ? 32 : 40),

                  // Options Cards - Different layout for desktop
                  if (isDesktop)
                    Row(
                      children: [
                        Expanded(
                          child: _buildOptionCard(
                            title: 'كشف الحساب',
                            subtitle: 'عرض كشوف حسابات العملاء',
                            icon: Icons.account_balance_wallet,
                            onTap: _navigateToContactSelection,
                            isMobile: false,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildOptionCard(
                            title: 'التعميرة',
                            subtitle: 'تقرير المديونيات',
                            icon: Icons.analytics,
                            onTap: _navigateToAgingReport,
                            isMobile: false,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildOptionCard(
                          title: 'كشف الحساب',
                          subtitle: 'عرض كشوف حسابات العملاء',
                          icon: Icons.account_balance_wallet,
                          onTap: _navigateToContactSelection,
                          isMobile: true,
                        ),
                        const SizedBox(height: 16),
                        _buildOptionCard(
                          title: 'التعميرة',
                          subtitle: 'تقرير المديونيات',
                          icon: Icons.analytics,
                          onTap: _navigateToAgingReport,
                          isMobile: true,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required bool isMobile,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Row(
              children: [
                // Icon
                Container(
                  width: isMobile ? 50 : 60,
                  height: isMobile ? 50 : 60,
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.accentColor),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(AppConstants.accentColor)
                            .withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: isMobile ? 24 : 30,
                    color: Colors.white,
                  ),
                ),

                SizedBox(width: isMobile ? 16 : 20),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(AppConstants.primaryColor),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.primaryColor)
                        .withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: isMobile ? 14 : 16,
                    color: const Color(AppConstants.primaryColor),
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

class _WebWelcomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppUser currentUser;
  final VoidCallback onLogout;
  final bool isDesktop;

  const _WebWelcomeAppBar({
    required this.currentUser,
    required this.onLogout,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 4,
      backgroundColor: const Color(AppConstants.primaryColor),
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(
              AppConstants.logoPath,
              width: 32,
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.accentColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.account_balance,
                    size: 16,
                    color: Colors.white,
                  ),
                );
              },
            ),
          ),

          const SizedBox(width: 12),

          // App Title
          Expanded(
            child: Text(
              'الرئيسية',
              style: TextStyle(
                color: Colors.white,
                fontSize: isDesktop ? 20 : 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // User info for desktop
          if (isDesktop) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.white,
                    child: Text(
                      currentUser.username.isNotEmpty
                          ? currentUser.username[0].toUpperCase()
                          : 'م',
                      style: const TextStyle(
                        color: Color(AppConstants.primaryColor),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currentUser.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'logout') {
              onLogout();
            }
          },
          icon: const Icon(Icons.more_vert, color: Colors.white),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Color(AppConstants.errorColor)),
                  SizedBox(width: 8),
                  Text('تسجيل الخروج'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
