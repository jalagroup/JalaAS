// lib/screens/web/web_login_screen.dart - WHITE BACKGROUNDS VERSION
import 'package:flutter/material.dart';
import '../../services/fcm_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../services/permission_service.dart';
import 'admin_dasboards/admin_dashboard.dart';
import 'web_main.dart' show navigatorKey;
import 'web_welcome_screen.dart';
import 'no_role_screen.dart';

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
  bool _sessionChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_sessionChecked) {
        _sessionChecked = true;
        _checkExistingSession();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingSession() async {
    try {
      final isLoggedIn = await SupabaseService.isLoggedIn();

      if (!isLoggedIn || !mounted) return;

      final user = await SupabaseService.getCurrentUser();

      if (!mounted) return;

      if (user != null && user.isActive) {
        _navigateBasedOnUserType(user);
      } else {
        await SupabaseService.signOut();
      }
    } catch (e) {
      print('Session check error: $e');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

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
          await _navigateBasedOnUserType(user);
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
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _navigateBasedOnUserType(user) async {
    if (!mounted) return;

    FCMService.setupForUser(user, navigatorKey: navigatorKey);
    await PermissionService.loadForUser(user.id);

    if (!mounted) return;

    Widget targetScreen;
    if (!PermissionService.hasRole) {
      targetScreen = const NoRoleScreen();
    } else if (PermissionService.isAdminInterface) {
      targetScreen = const AdminDashboard();
    } else {
      targetScreen = const WebWelcomeScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 768;
    final isVerySmall = size.height < 600;

    final cardMaxWidth =
        isSmall ? size.width * 0.9 : (size.width > 1200 ? 450.0 : 400.0);
    final cardPadding = isVerySmall ? 16.0 : (isSmall ? 20.0 : 32.0);
    final verticalSpacing = isVerySmall ? 8.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.white, // ✅ WHITE BACKGROUND
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 16 : 32,
              vertical: verticalSpacing,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: cardMaxWidth),
              child: Card(
                elevation: 2, // Reduced elevation for cleaner look
                color: Colors.white, // ✅ WHITE CARD BACKGROUND
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isSmall ? 16 : 20),
                  side: BorderSide(
                    color: Colors.grey.shade200, // Subtle border
                    width: 0,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(cardPadding),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLogo(isSmall, isVerySmall),
                        SizedBox(height: isVerySmall ? 12 : 20),
                        Text(
                          AppConstants.appName,
                          style: TextStyle(
                            fontSize: isVerySmall ? 16 : (isSmall ? 18 : 22),
                            fontWeight: FontWeight.bold,
                            color: const Color(AppConstants.primaryColor),
                          ),
                        ),
                        SizedBox(height: isVerySmall ? 8 : 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(AppConstants.accentColor)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'تسجيل الدخول',
                            style: TextStyle(
                              fontSize: isVerySmall ? 12 : 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(AppConstants.accentColor),
                            ),
                          ),
                        ),
                        SizedBox(height: isVerySmall ? 16 : 24),
                        _buildEmailField(isSmall, isVerySmall),
                        SizedBox(height: isVerySmall ? 8 : 12),
                        _buildPasswordField(isSmall, isVerySmall),
                        SizedBox(height: isVerySmall ? 16 : 24),
                        _buildLoginButton(isSmall, isVerySmall),
                        if (!isVerySmall) ...[
                          const SizedBox(height: 16),
                          _buildInfoBox(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(bool isSmall, bool isVerySmall) {
    final size = isVerySmall ? 40.0 : (isSmall ? 50.0 : 70.0);

    return Container(
      padding: EdgeInsets.all(isVerySmall ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white, // ✅ WHITE LOGO CONTAINER BACKGROUND
        borderRadius: BorderRadius.circular(isVerySmall ? 12 : 16),
        border: Border.all(
          color: Colors.grey.shade200, // Subtle border instead of shadow
          width: 1,
        ),
      ),
      child: Image.asset(
        AppConstants.logoPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        cacheWidth: (size * 2).toInt(),
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(AppConstants.primaryColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.account_balance,
              size: size * 0.5,
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmailField(bool isSmall, bool isVerySmall) {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textDirection: TextDirection.ltr,
      autocorrect: false,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      style: TextStyle(fontSize: isVerySmall ? 12 : 14),
      decoration: InputDecoration(
        labelText: 'البريد الإلكتروني',
        hintText: 'example@domain.com',
        prefixIcon: Icon(
          Icons.email,
          color: const Color(AppConstants.accentColor),
          size: isVerySmall ? 16 : 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(AppConstants.accentColor),
            width: 2,
          ),
        ),
        filled: true,
        fillColor: Colors.white, // ✅ WHITE INPUT BACKGROUND
        contentPadding: EdgeInsets.symmetric(
          horizontal: isVerySmall ? 10 : 12,
          vertical: isVerySmall ? 10 : 14,
        ),
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
    );
  }

  Widget _buildPasswordField(bool isSmall, bool isVerySmall) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textDirection: TextDirection.ltr,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      style: TextStyle(fontSize: isVerySmall ? 12 : 14),
      decoration: InputDecoration(
        labelText: 'كلمة المرور',
        hintText: 'أدخل كلمة المرور',
        prefixIcon: Icon(
          Icons.lock,
          color: const Color(AppConstants.primaryColor),
          size: isVerySmall ? 16 : 20,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
            size: isVerySmall ? 16 : 20,
          ),
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(AppConstants.accentColor),
            width: 2,
          ),
        ),
        filled: true,
        fillColor: Colors.white, // ✅ WHITE INPUT BACKGROUND
        contentPadding: EdgeInsets.symmetric(
          horizontal: isVerySmall ? 10 : 12,
          vertical: isVerySmall ? 10 : 14,
        ),
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
        if (!_isLoading) _login();
      },
    );
  }

  Widget _buildLoginButton(bool isSmall, bool isVerySmall) {
    return SizedBox(
      width: double.infinity,
      height: isVerySmall ? 40 : (isSmall ? 44 : 48),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(AppConstants.accentColor),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0, // Flat design
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              )
            : Text(
                'تسجيل الدخول',
                style: TextStyle(
                  fontSize: isVerySmall ? 13 : (isSmall ? 14 : 16),
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, // ✅ WHITE INFO BOX BACKGROUND
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: Colors.blue.shade200), // Kept blue border for info
      ),
      child: Row(
        children: [
          Icon(
            Icons.info,
            color: const Color(AppConstants.accentColor),
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'للوصول إلى النظام، يرجى استخدام البيانات المرسلة إليك من الإدارة.',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
