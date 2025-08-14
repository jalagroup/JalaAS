// lib/screens/mobile/welcome_screen.dart
import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/supabase_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import 'mobile_contact_selection_screen.dart';
import 'aging_report_screen.dart';
import 'mobile_login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
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
          builder: (context) => const LoginScreen(),
        ),
      );
    }
  }

  void _navigateToContactSelection() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ContactSelectionScreen(),
      ),
    );
  }

  void _navigateToAgingReport() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AgingReportScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _currentUser != null
          ? _WelcomeAppBar(
              currentUser: _currentUser!,
              onLogout: _logout,
            )
          : AppBar(
              title: const Text('الرئيسية'),
              backgroundColor: const Color(AppConstants.primaryColor),
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Welcome Message
                Container(
                  padding: const EdgeInsets.all(24),
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
                          width: 60,
                          height: 60,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.account_balance,
                              size: 60,
                              color: Colors.white,
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      Text(
                        _getGreetingMessage(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(AppConstants.primaryColor),
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 8),

                      if (_currentUser != null)
                        Text(
                          _currentUser!.username,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Color(AppConstants.accentColor),
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Options Cards
                _buildOptionCard(
                  title: 'كشف الحساب',
                  subtitle: 'عرض كشوف حسابات العملاء',
                  icon: Icons.account_balance_wallet,
                  onTap: _navigateToContactSelection,
                ),

                const SizedBox(height: 16),

                _buildOptionCard(
                  title: 'التعميرة',
                  subtitle: 'تقرير المديونيات',
                  icon: Icons.analytics,
                  onTap: _navigateToAgingReport,
                ),
              ],
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
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 60,
                  height: 60,
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
                    size: 30,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(width: 20),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(AppConstants.primaryColor),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
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
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Color(AppConstants.primaryColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
}

class _WelcomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppUser currentUser;
  final VoidCallback onLogout;

  const _WelcomeAppBar({
    required this.currentUser,
    required this.onLogout,
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
          const Expanded(
            child: Text(
              'الرئيسية',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
