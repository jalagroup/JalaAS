// lib/main.dart - Updated with Better Internet Handling

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:io';
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

  try {
    await SupabaseService.initialize();
  } catch (e) {
    print('Failed to initialize Supabase: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
  bool _isCheckingInternet = false;
  DateTime? _backgroundTime;
  Timer? _timeoutTimer;
  bool _isInBackground = false;
  String _connectionStatus = 'جاري التحقق من الاتصال...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeoutTimer?.cancel();
    Helpers.stopInternetMonitoring();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    // Add a small delay to show the loading screen
    await Future.delayed(const Duration(milliseconds: 500));

    // Start internet monitoring
    Helpers.startInternetMonitoring(
      onConnectivityChanged: (bool isConnected) {
        if (mounted && !_isNavigating) {
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

    // Initial state check
    await _checkInitialState();
  }

  void _startBackgroundTimer() {
    _timeoutTimer?.cancel();
    _backgroundTime = DateTime.now();

    // Start timer to check every 30 seconds
    _timeoutTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkBackgroundTimeout();
    });

    print('Background timer started at: $_backgroundTime');
  }

  void _stopBackgroundTimer() {
    _timeoutTimer?.cancel();
    _backgroundTime = null;
    print('Background timer stopped');
  }

  Future<void> _checkBackgroundTimeout() async {
    if (!_isInBackground || _backgroundTime == null) {
      return;
    }

    final now = DateTime.now();
    final backgroundDuration = now.difference(_backgroundTime!);

    print('App in background for: ${backgroundDuration.inMinutes} minutes');

    if (backgroundDuration.inMinutes >= AppConstants.backgroundTimeoutMinutes) {
      print('5 minutes timeout reached - closing app');
      _closeApp();
    }
  }

  void _closeApp() {
    print('Closing app due to background timeout');

    // Cancel timer
    _timeoutTimer?.cancel();

    // Close the app completely
    if (Platform.isAndroid) {
      SystemNavigator.pop(); // Close app on Android
    } else if (Platform.isIOS) {
      exit(0); // Close app on iOS (Note: Apple doesn't recommend this)
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    print('App lifecycle state changed to: $state'); // Debug log

    if (state == AppLifecycleState.resumed) {
      print('App resumed from background'); // Debug log
      _isInBackground = false;
      _stopBackgroundTimer();
      _checkAppResume();
    } else if (state == AppLifecycleState.paused) {
      print('App paused, going to background'); // Debug log
      _isInBackground = true;
      _startBackgroundTimer();
      Helpers.updateLastActiveTime();
    } else if (state == AppLifecycleState.inactive) {
      print('App inactive'); // Debug log
      Helpers.updateLastActiveTime();
    }
  }

  // Initial app state: check internet, PIN, and login
  Future<void> _checkInitialState() async {
    if (_isNavigating || !mounted || _isCheckingInternet) return;

    setState(() {
      _isCheckingInternet = true;
      _connectionStatus = 'جاري التحقق من الاتصال بالإنترنت...';
    });

    try {
      // Use the improved internet check with detailed info
      final connectionInfo = await Helpers.getDetailedConnectionInfo();
      _hasInternet = connectionInfo['hasInternet'] as bool;

      print('Connection Info: $connectionInfo');

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
        // First time ever - setup PIN
        _navigateToPinSetup();
      } else {
        // Has PIN - require PIN entry
        _navigateToPinEntry();
      }
    } catch (e) {
      print('Error in _checkInitialState: $e');
      setState(() {
        _isCheckingInternet = false;
      });

      if (mounted) {
        // Show debug info in case of persistent issues
        await Helpers.debugInternetConnection();
        _navigateToNoInternet();
      }
    }
  }

  // Resume app: recheck internet and PIN based on background time
  Future<void> _checkAppResume() async {
    if (_isNavigating || !mounted || _isCheckingInternet) return;

    setState(() {
      _isCheckingInternet = true;
      _connectionStatus = 'جاري التحقق من الاتصال...';
    });

    try {
      // Use quick check for resume to be faster
      _hasInternet = await Helpers.hasInternetConnectionQuick();

      if (!mounted) return;

      setState(() {
        _isCheckingInternet = false;
      });

      if (!_hasInternet) {
        _navigateToNoInternet();
        return;
      }

      // Check if PIN is required after coming back from background
      final shouldRequirePin = await Helpers.shouldRequirePin();

      print('Should require PIN on resume: $shouldRequirePin'); // Debug log

      if (!mounted) return;

      if (shouldRequirePin) {
        print('Requiring PIN due to background timeout on resume'); // Debug log
        _navigateToPinEntry();
      }
    } catch (e) {
      print('Error in _checkAppResume: $e');
      setState(() {
        _isCheckingInternet = false;
      });
    }
  }

  // Check login status after PIN verification
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
      print('Error in _checkLoginStatusAfterPin: $e');
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
          onRetry: () async {
            _isNavigating = false;
            // Add a small delay before rechecking
            await Future.delayed(const Duration(milliseconds: 500));
            await _checkInitialState();
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
            // After PIN setup, go directly to login screen
            _navigateToLogin();
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
            _checkLoginStatusAfterPin();
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
        builder: (context) => const ContactSelectionScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(AppConstants.primaryColor),
                  ),
            ),
            const SizedBox(height: 24),
            if (_isCheckingInternet) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _connectionStatus,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'جاري التحميل...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],

            // Debug button (remove in production)
            if (const bool.fromEnvironment('dart.vm.product') == false) ...[
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  await Helpers.debugInternetConnection();
                },
                child: const Text('Debug Connection'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
