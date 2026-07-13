// lib/main.dart - OPTIMIZED VERSION

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/fcm_service.dart';
import 'services/supabase_service.dart';
import 'screens/mobile/pin_setup_screen.dart';
import 'screens/mobile/pin_enter_screen.dart';
import 'screens/mobile/mobile_login_screen.dart';
import 'screens/mobile/mobile_contact_selection_screen.dart';
import 'screens/mobile/no_internet_screen.dart';
import 'utils/constants.dart';
import 'utils/helpers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('ar', null);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FCMService.initialize();

  SupabaseService.initialize().catchError((e) {
    print('Supabase init delayed: $e');
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Cache theme data to avoid rebuilding
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
      home: const AppInitializer(),
      // Add this to reduce rebuilds
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          child: child!,
        );
      },
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  bool _hasInternet = true;
  bool _isNavigating = false;
  bool _isCheckingInternet = false;
  DateTime? _backgroundTime;
  Timer? _timeoutTimer;
  bool _isInBackground = false;
  String _connectionStatus = 'جاري التحقق من الاتصال...';
  StreamSubscription? _connectivitySubscription;

  @override
  bool get wantKeepAlive => false; // Don't keep state alive unnecessarily

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Delay initialization slightly to allow UI to render first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeoutTimer?.cancel();
    _connectivitySubscription?.cancel();
    Helpers.stopInternetMonitoring();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;

    // Quick check without blocking UI
    final hasConnection = await Helpers.hasInternetConnectionQuick();

    if (!mounted) return;

    setState(() {
      _hasInternet = hasConnection;
    });

    if (!hasConnection) {
      _navigateToNoInternet();
      return;
    }

    // Start monitoring in background
    _startConnectivityMonitoring();

    // Check initial state
    await _checkInitialState();
  }

  void _startConnectivityMonitoring() {
    // Use stream subscription instead of callback for better performance
    _connectivitySubscription?.cancel();

    Helpers.startInternetMonitoring(
      onConnectivityChanged: (bool isConnected) {
        if (!mounted || _isNavigating) return;

        if (_hasInternet != isConnected) {
          setState(() {
            _hasInternet = isConnected;
          });

          if (isConnected) {
            _checkInitialState();
          } else {
            _navigateToNoInternet();
          }
        }
      },
    );
  }

  void _startBackgroundTimer() {
    _timeoutTimer?.cancel();
    _backgroundTime = DateTime.now();

    // Check every 30 seconds, but only when in background
    _timeoutTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isInBackground) {
        _checkBackgroundTimeout();
      }
    });
  }

  void _stopBackgroundTimer() {
    _timeoutTimer?.cancel();
    _backgroundTime = null;
  }

  Future<void> _checkBackgroundTimeout() async {
    if (!_isInBackground || _backgroundTime == null) return;

    final now = DateTime.now();
    final backgroundDuration = now.difference(_backgroundTime!);

    if (backgroundDuration.inMinutes >= AppConstants.backgroundTimeoutMinutes) {
      _closeApp();
    }
  }

  void _closeApp() {
    _timeoutTimer?.cancel();

    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else if (Platform.isIOS) {
      exit(0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _isInBackground = false;
        _stopBackgroundTimer();
        _checkAppResume();
        break;
      case AppLifecycleState.paused:
        _isInBackground = true;
        _startBackgroundTimer();
        Helpers.updateLastActiveTime();
        break;
      case AppLifecycleState.inactive:
        Helpers.updateLastActiveTime();
        break;
      default:
        break;
    }
  }

  Future<void> _checkInitialState() async {
    if (_isNavigating || !mounted || _isCheckingInternet) return;

    setState(() {
      _isCheckingInternet = true;
      _connectionStatus = 'جاري التحقق من الاتصال بالإنترنت...';
    });

    try {
      // Use quick check first
      _hasInternet = await Helpers.hasInternetConnectionQuick();

      if (!mounted) return;

      setState(() {
        _isCheckingInternet = false;
      });

      if (!_hasInternet) {
        _navigateToNoInternet();
        return;
      }

      setState(() {
        _connectionStatus = 'جاري التحقق من بيانات المصادقة...';
      });

      final hasPinCode = await Helpers.hasPinCode();

      if (!mounted) return;

      if (!hasPinCode) {
        _navigateToPinSetup();
      } else {
        _navigateToPinEntry();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingInternet = false;
        });
        _navigateToNoInternet();
      }
    }
  }

  Future<void> _checkAppResume() async {
    if (_isNavigating || !mounted || _isCheckingInternet) return;

    setState(() {
      _isCheckingInternet = true;
      _connectionStatus = 'جاري التحقق من الاتصال...';
    });

    try {
      _hasInternet = await Helpers.hasInternetConnectionQuick();

      if (!mounted) return;

      setState(() {
        _isCheckingInternet = false;
      });

      if (!_hasInternet) {
        _navigateToNoInternet();
        return;
      }

      final shouldRequirePin = await Helpers.shouldRequirePin();

      if (!mounted) return;

      if (shouldRequirePin) {
        _navigateToPinEntry();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingInternet = false;
        });
      }
    }
  }

  Future<void> _checkLoginStatusAfterPin() async {
    if (_isNavigating || !mounted) return;

    try {
      final isLoggedIn = await Helpers.isLoggedIn();

      if (!mounted) return;

      if (isLoggedIn && SupabaseService.currentAuthUser != null) {
        _navigateToContactSelection();
      } else {
        _navigateToLogin();
      }
    } catch (e) {
      if (mounted) {
        _navigateToLogin();
      }
    }
  }

  void _navigateToNoInternet() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            NoInternetScreen(
          onRetry: () async {
            _isNavigating = false;
            await Future.delayed(const Duration(milliseconds: 300));
            await _checkInitialState();
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  void _navigateToPinSetup() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PinSetupScreen(
          onPinSet: () {
            _isNavigating = false;
            _navigateToLogin();
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  void _navigateToPinEntry() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PinEnterScreen(
          onPinVerified: () {
            _isNavigating = false;
            _checkLoginStatusAfterPin();
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  void _navigateToLogin() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  void _navigateToContactSelection() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ContactSelectionScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // Don't take full height
          children: [
            // Optimized logo container
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(AppConstants.primaryColor),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.apps,
                size: 64,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 32),

            Text(
              AppConstants.appName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(AppConstants.primaryColor),
              ),
            ),

            const SizedBox(height: 24),

            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),

            const SizedBox(height: 16),

            Text(
              _isCheckingInternet ? _connectionStatus : 'جاري التحميل...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
