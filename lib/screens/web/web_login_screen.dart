// lib/screens/web/web_login_screen.dart
import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import 'admin_dashboard.dart';
import 'web_statements_screen.dart';

class WebLoginScreen extends StatefulWidget {
  const WebLoginScreen({super.key});

  @override
  State<WebLoginScreen> createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends State<WebLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingSession() async {
    final currentUser = SupabaseService.currentAuthUser;
    if (currentUser == null) return;

    try {
      final user = await SupabaseService.getCurrentUser();
      if (!mounted) return;

      if (user != null && user.isActive) {
        _navigateBasedOnUserType(user);
      } else {
        await SupabaseService.signOut();
      }
    } catch (e) {
      await SupabaseService.signOut();
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await SupabaseService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user != null) {
        final user = await SupabaseService.getCurrentUser();
        if (!mounted) return;

        if (user != null) {
          if (!user.isActive) {
            Helpers.showSnackBar(
              context,
              'حسابك غير مفعل. اتصل بالمدير لتفعيل الحساب.',
              isError: true,
            );
            await SupabaseService.signOut();
            return;
          }
          _navigateBasedOnUserType(user);
        }
      }
    } catch (e) {
      if (!mounted) return;
      Helpers.showSnackBar(
        context,
        'فشل في تسجيل الدخول. تحقق من بيانات الدخول.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateBasedOnUserType(user) {
    if (user.isAdmin) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AdminDashboard()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (context) => WebStatementsScreen(user: user)),
      );
    }
  }

  Future<void> _logout() async {
    await SupabaseService.signOut();
    if (!mounted) return;
    Helpers.showSnackBar(context, 'تم تسجيل الخروج بنجاح.');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const WebLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;
    final isMobile = screenWidth <= 768;
    final isVerySmall = screenHeight < 600;
    final isShort = screenHeight < 700;

    // Responsive padding and sizing based on both width AND height
    final horizontalPadding = isMobile ? 16.0 : (isTablet ? 24.0 : 32.0);
    final verticalPadding = isVerySmall ? 8.0 : (isShort ? 12.0 : 16.0);
    final cardMaxWidth =
        isLargeScreen ? 450.0 : (isTablet ? 400.0 : screenWidth * 0.9);
    final cardPadding =
        isVerySmall ? 16.0 : (isMobile ? 20.0 : (isTablet ? 28.0 : 32.0));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: cardMaxWidth,
                        maxHeight:
                            constraints.maxHeight - (verticalPadding * 2),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(cardPadding),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(isMobile ? 16 : 20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: const Offset(0, 0),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Flexible spacing to adjust based on available height
                              if (!isVerySmall)
                                Flexible(
                                    child: SizedBox(height: isShort ? 10 : 20)),

                              // App Logo with white background - compact on small screens
                              Container(
                                padding: EdgeInsets.all(
                                    isVerySmall ? 12 : (isMobile ? 16 : 20)),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                      isVerySmall ? 12 : 16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: isVerySmall ? 10 : 15,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 0),
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  AppConstants.logoPath,
                                  width: isVerySmall
                                      ? 40
                                      : (isMobile ? 50 : (isTablet ? 60 : 70)),
                                  height: isVerySmall
                                      ? 40
                                      : (isMobile ? 50 : (isTablet ? 60 : 70)),
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: isVerySmall
                                          ? 40
                                          : (isMobile
                                              ? 50
                                              : (isTablet ? 60 : 70)),
                                      height: isVerySmall
                                          ? 40
                                          : (isMobile
                                              ? 50
                                              : (isTablet ? 60 : 70)),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                            AppConstants.primaryColor),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.account_balance,
                                        size: isVerySmall
                                            ? 20
                                            : (isMobile ? 25 : 30),
                                        color: Colors.white,
                                      ),
                                    );
                                  },
                                ),
                              ),

                              SizedBox(
                                  height:
                                      isVerySmall ? 8 : (isShort ? 12 : 16)),

                              // App Name - compact font on small screens
                              Text(
                                AppConstants.appName,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(
                                          AppConstants.primaryColor),
                                      fontSize: isVerySmall
                                          ? 16
                                          : (isMobile
                                              ? 18
                                              : (isTablet ? 20 : 22)),
                                    ),
                                textAlign: TextAlign.center,
                              ),

                              SizedBox(
                                  height:
                                      isVerySmall ? 12 : (isShort ? 16 : 24)),

                              // Login Title - compact on small screens
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal:
                                      isVerySmall ? 12 : (isMobile ? 14 : 16),
                                  vertical: isVerySmall ? 4 : 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(AppConstants.accentColor)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'تسجيل الدخول',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: const Color(
                                            AppConstants.accentColor),
                                        fontSize: isVerySmall
                                            ? 12
                                            : (isMobile ? 13 : 14),
                                      ),
                                ),
                              ),

                              SizedBox(
                                  height:
                                      isVerySmall ? 16 : (isShort ? 20 : 24)),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 0),
                                    ),
                                  ],
                                ),
                                child: TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textDirection: TextDirection.ltr,
                                  autocorrect: false,
                                  enableSuggestions: true,
                                  textInputAction: TextInputAction.next,
                                  // Add HTML attributes for better web support
                                  autofillHints: const [AutofillHints.email],

                                  style: TextStyle(
                                    fontSize:
                                        isVerySmall ? 12 : (isMobile ? 13 : 14),
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'البريد الإلكتروني',
                                    hintText: 'example@domain.com',
                                    labelStyle: TextStyle(
                                      fontSize: isVerySmall
                                          ? 12
                                          : (isMobile ? 13 : 14),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.email,
                                      color:
                                          const Color(AppConstants.accentColor),
                                      size: isVerySmall
                                          ? 16
                                          : (isMobile ? 18 : 20),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Color(AppConstants.accentColor),
                                        width: 2,
                                      ),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Color(AppConstants.errorColor),
                                        width: 1,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: isVerySmall ? 10 : 12,
                                      vertical: isVerySmall ? 10 : 12,
                                    ),
                                    isDense: isVerySmall,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'يرجى إدخال البريد الإلكتروني';
                                    }
                                    if (!Helpers.isValidEmail(value)) {
                                      return 'البريد الإلكتروني غير صحيح';
                                    }
                                    return null;
                                  },
                                  onFieldSubmitted: (_) {
                                    // Move focus to password field
                                    FocusScope.of(context).nextFocus();
                                  },
                                ),
                              ),

                              SizedBox(height: isVerySmall ? 8 : 12),

                              // Password Field with proper web attributes
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 0),
                                    ),
                                  ],
                                ),
                                child: TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textDirection: TextDirection.ltr,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  textInputAction: TextInputAction.done,
                                  // Add HTML attributes for better web support
                                  autofillHints: const [AutofillHints.password],
                                  style: TextStyle(
                                    fontSize:
                                        isVerySmall ? 12 : (isMobile ? 13 : 14),
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'كلمة المرور',
                                    hintText: 'أدخل كلمة المرور',
                                    labelStyle: TextStyle(
                                      fontSize: isVerySmall
                                          ? 12
                                          : (isMobile ? 13 : 14),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.lock,
                                      color: const Color(
                                          AppConstants.primaryColor),
                                      size: isVerySmall
                                          ? 16
                                          : (isMobile ? 18 : 20),
                                    ),
                                    suffixIcon: IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: BoxConstraints(
                                        minWidth: isVerySmall ? 32 : 40,
                                        minHeight: isVerySmall ? 32 : 40,
                                      ),
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        color: const Color(
                                            AppConstants.accentColor),
                                        size: isVerySmall
                                            ? 16
                                            : (isMobile ? 18 : 20),
                                      ),
                                      tooltip: _obscurePassword
                                          ? 'إظهار كلمة المرور'
                                          : 'إخفاء كلمة المرور',
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Color(AppConstants.primaryColor),
                                        width: 2,
                                      ),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Color(AppConstants.errorColor),
                                        width: 1,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: isVerySmall ? 10 : 12,
                                      vertical: isVerySmall ? 10 : 12,
                                    ),
                                    isDense: isVerySmall,
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
                                  onFieldSubmitted: (_) {
                                    // Trigger login when Enter is pressed
                                    if (!_isLoading) {
                                      _login();
                                    }
                                  },
                                ),
                              ),

                              SizedBox(
                                  height:
                                      isVerySmall ? 16 : (isShort ? 20 : 24)),

                              // Login Button - compact height on small screens
                              Container(
                                width: double.infinity,
                                height: isVerySmall ? 40 : (isMobile ? 44 : 48),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(AppConstants.accentColor),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: Colors.grey[300],
                                    disabledForegroundColor: Colors.grey[600],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 2,
                                    shadowColor:
                                        const Color(AppConstants.accentColor)
                                            .withOpacity(0.3),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          height: isVerySmall ? 16 : 20,
                                          width: isVerySmall ? 16 : 20,
                                          child:
                                              const CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          'تسجيل الدخول',
                                          style: TextStyle(
                                            fontSize: isVerySmall
                                                ? 13
                                                : (isMobile ? 14 : 16),
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                ),
                              ),

                              // Conditional info message - hide on very small screens to save space
                              if (!isVerySmall) ...[
                                SizedBox(height: isShort ? 12 : 16),
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(isShort ? 8 : 12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.blue[200]!,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info,
                                        color: const Color(
                                            AppConstants.accentColor),
                                        size: isShort ? 14 : 16,
                                      ),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'للوصول إلى النظام، يرجى استخدام البيانات المرسلة إليك من الإدارة.',
                                          style: TextStyle(
                                            color: Colors.blue[700],
                                            fontSize: isShort ? 10 : 11,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Flexible spacer to push footer to bottom without overflow
                              if (!isVerySmall)
                                Flexible(
                                    child: SizedBox(height: isShort ? 8 : 12)),

                              // Footer - compact on small screens
                              Text(
                                '© 2025 جميع الحقوق محفوظة',
                                style: TextStyle(
                                  fontSize:
                                      isVerySmall ? 9 : (isShort ? 10 : 11),
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),

                              if (!isVerySmall)
                                SizedBox(height: isShort ? 4 : 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
