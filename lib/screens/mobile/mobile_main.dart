import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jala_as/screens/mobile/mobile_contact_selection_screen.dart';
import 'package:jala_as/screens/mobile/mobile_login_screen.dart';
import 'package:jala_as/screens/mobile/no_internet_screen.dart';
import 'package:jala_as/screens/mobile/pin_enter_screen.dart';
import 'package:jala_as/screens/mobile/pin_setup_screen.dart';
import 'package:jala_as/screens/mobile/welcome_screen.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/constants.dart';
import 'package:jala_as/utils/helpers.dart';

class MobileApp extends StatelessWidget {
  const MobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,

      // Localization support for Arabic and English
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar'), // Arabic support
        Locale('en'), // English support
      ],
      locale: const Locale('ar'), // Force Arabic UI

      // App theme
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: const Color(AppConstants.primaryColor),
        scaffoldBackgroundColor: const Color(AppConstants.backgroundColor),
        fontFamily: GoogleFonts.notoSansArabic().fontFamily,
        textTheme: GoogleFonts.notoSansArabicTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(AppConstants.primaryColor),
          foregroundColor: Colors.white,
          titleTextStyle: GoogleFonts.notoSansArabic(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(AppConstants.primaryColor),
            foregroundColor: Colors.white,
            textStyle: GoogleFonts.notoSansArabic(
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Color(AppConstants.primaryColor),
              width: 2,
            ),
          ),
          labelStyle: GoogleFonts.notoSansArabic(),
        ),
      ),

      home: const AppInitializer(),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer>
    with WidgetsBindingObserver {
  bool _hasInternet = true;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _checkAppResume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      Helpers.updateLastActiveTime();
    }
  }

  // Initial app state: check internet, PIN, and login
  Future<void> _checkInitialState() async {
    if (_isNavigating || !mounted) return;

    try {
      _hasInternet = await Helpers.hasInternetConnection();

      if (!mounted) return;

      if (!_hasInternet) {
        _navigateToNoInternet();
        return;
      }

      final shouldRequirePin = await Helpers.shouldRequirePin();
      final hasPinCode = await Helpers.hasPinCode();

      if (!mounted) return;

      if (!hasPinCode) {
        _navigateToPinSetup();
      } else if (shouldRequirePin) {
        _navigateToPinEntry();
      } else {
        _checkLoginStatus();
      }
    } catch (e) {
      print('Error in _checkInitialState: $e');
      if (mounted) {
        _navigateToLogin();
      }
    }
  }

  // Resume app: recheck internet and PIN
  Future<void> _checkAppResume() async {
    if (_isNavigating || !mounted) return;

    try {
      _hasInternet = await Helpers.hasInternetConnection();

      if (!mounted) return;

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
      print('Error in _checkAppResume: $e');
    }
  }

  // Check if user is already logged in
  Future<void> _checkLoginStatus() async {
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
      print('Error in _checkLoginStatus: $e');
      if (mounted) {
        _navigateToLogin();
      }
    }
  }

  // Navigation methods
  void _navigateToNoInternet() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => NoInternetScreen(
          onRetry: () {
            _isNavigating = false;
            _checkInitialState();
          },
        ),
      ),
    );
  }

  void _navigateToPinSetup() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PinSetupScreen(
          onPinSet: () {
            _isNavigating = false;
            _checkLoginStatus();
          },
        ),
      ),
    );
  }

  void _navigateToPinEntry() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PinEnterScreen(
          onPinVerified: () {
            _isNavigating = false;
            _checkLoginStatus();
          },
        ),
      ),
    );
  }

  void _navigateToLogin() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }

  void _navigateToContactSelection() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) =>
            const WelcomeScreen(), // Changed from ContactSelectionScreen to WelcomeScreen
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
