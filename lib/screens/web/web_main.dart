// lib/main.dart - OPTIMIZED WEB VERSION

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jala_as/screens/web/admin_dasboards/admin_dashboard.dart';
import 'package:jala_as/screens/web/web_login_screen.dart';
import 'package:jala_as/screens/web/web_welcome_screen.dart';
import 'package:jala_as/screens/web/no_role_screen.dart';
import 'package:jala_as/services/permission_service.dart';
import 'package:jala_as/services/api_service.dart';
import 'package:jala_as/services/local_database_service.dart';
import 'package:jala_as/services/fcm_service.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/constants.dart';
import 'package:jala_as/utils/platform_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:jala_as/firebase_options.dart';

final supabase = Supabase.instance.client;

// Global navigator key used by FCMService for foreground notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register background message handler (mobile only — web uses service worker)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await initializeDateFormatting('ar', null);

  try {
    // Initialize in parallel for faster startup
    await Future.wait([
      if (PlatformUtils.isMobile) LocalDatabaseService.initializeDatabase(),
      SupabaseService.initialize(),
    ]);

    await ApiService.initialize();

    runApp(const WebApp());
  } catch (e) {
    print('Failed to initialize application: $e');
    runApp(const ErrorApp());
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // ✨ ADD THIS
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      locale: const Locale('ar'),
      home: const SplashScreen(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          child: child!,
        );
      },
    );
  }
}

class WebApp extends StatelessWidget {
  const WebApp({super.key});

  // Cache theme to avoid rebuilding
  static final _theme = _buildTheme();

  static ThemeData _buildTheme() {
    final arabicFont = GoogleFonts.notoSansArabic();

    return ThemeData(
      primarySwatch: Colors.blue,
      primaryColor: const Color(AppConstants.primaryColor),
      scaffoldBackgroundColor: const Color(AppConstants.backgroundColor),
      fontFamily: arabicFont.fontFamily,
      textTheme: GoogleFonts.notoSansArabicTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(AppConstants.primaryColor),
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: arabicFont.fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(AppConstants.primaryColor),
          foregroundColor: Colors.white,
          textStyle: TextStyle(
            fontFamily: arabicFont.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: Color(AppConstants.primaryColor),
            width: 2,
          ),
        ),
        labelStyle: TextStyle(fontFamily: arabicFont.fontFamily),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: _theme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      locale: const Locale('ar'),
      home: const SplashScreen(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          child: Stack(
            children: [
              child!,
              const _WebNotifPermissionBanner(),
            ],
          ),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndNavigate();
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    // Show splash for minimum 1 second (reduced from 2)
    final stopwatch = Stopwatch()..start();

    if (!mounted) return;

    // Check login status
    final isLoggedIn = await SupabaseService.isLoggedIn();

    if (!mounted) return;

    if (isLoggedIn) {
      try {
        final user = await SupabaseService.getCurrentUser();

        if (!mounted) return;

        if (user != null && user.isActive) {
          // Ensure minimum splash time
          final elapsed = stopwatch.elapsedMilliseconds;
          if (elapsed < 1000) {
            await Future.delayed(Duration(milliseconds: 1000 - elapsed));
          }

          if (!mounted) return;
          await _navigateToHome(user);
        } else {
          await SupabaseService.signOut();
          if (!mounted) return;
          _navigateToLogin();
        }
      } catch (e) {
        if (!mounted) return;
        _navigateToLogin();
      }
    } else {
      // Ensure minimum splash time
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed < 1000) {
        await Future.delayed(Duration(milliseconds: 1000 - elapsed));
      }

      if (!mounted) return;
      _navigateToLogin();
    }
  }

  Future<void> _navigateToHome(user) async {
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

  void _navigateToLogin() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const WebLoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Optimized logo loading
            SizedBox(
              width: 200,
              height: 200,
              child: Image.asset(
                AppConstants.logoPath,
                fit: BoxFit.contain,
                cacheWidth: 400, // Cache at 2x resolution
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.account_balance,
                      size: 80,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            Text(
              AppConstants.appName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(AppConstants.primaryColor),
              ),
            ),

            const SizedBox(height: 32),

            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(AppConstants.primaryColor),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'جاري التحميل...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Web notification permission banner
// Floats above the app at the bottom of the screen.  Appears once after login
// if the browser has not yet been asked for notification permission.
// The actual Notification.requestPermission() call is inside the button's
// onPressed handler — that user gesture is required by Safari on iOS/macOS.
// ─────────────────────────────────────────────────────────────────────────────

class _WebNotifPermissionBanner extends StatefulWidget {
  const _WebNotifPermissionBanner();

  @override
  State<_WebNotifPermissionBanner> createState() =>
      _WebNotifPermissionBannerState();
}

class _WebNotifPermissionBannerState
    extends State<_WebNotifPermissionBanner> {
  bool _visible = false;
  bool _loading = false;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // Check once the widget appears (covers the case where the user is
    // already logged in from a previous session).
    Future.delayed(const Duration(seconds: 2), _check);

    // Also check whenever the user signs in (covers fresh logins).
    _authSub =
        Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) {
        Future.delayed(const Duration(seconds: 1), _check);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (!mounted) return;
    try {
      // Bail if the browser does not support the Notifications API at all
      // (e.g. iOS Safari < 16.4 running outside a PWA).
      if (!html.Notification.supported) return;

      // Only prompt logged-in users.
      if (Supabase.instance.client.auth.currentSession == null) return;

      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      if (mounted &&
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        setState(() => _visible = true);
      }
    } catch (_) {}
  }

  Future<void> _requestPermission() async {
    if (_loading) return;
    setState(() => _loading = true);
    final granted = await FCMService.requestWebPermission();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _visible = false;
    });
    if (granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تفعيل الإشعارات بنجاح'),
          backgroundColor: Color(AppConstants.primaryColor),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return Positioned(
      bottom: 16,
      left: 12,
      right: 12,
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Material(
          elevation: 10,
          borderRadius: BorderRadius.circular(14),
          shadowColor: Colors.black38,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(AppConstants.primaryColor),
                  Color(0xFF0B3D50),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'تفعيل الإشعارات',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ابقَ على اطلاع بالطلبات والتحديثات الجديدة',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () => setState(() => _visible = false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'لاحقاً',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor:
                        const Color(AppConstants.primaryColor),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _loading ? null : _requestPermission,
                  child: _loading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(AppConstants.primaryColor)),
                          ),
                        )
                      : const Text(
                          'تفعيل',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold),
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
