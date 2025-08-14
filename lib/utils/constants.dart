// lib/utils/constants.dart
class AppConstants {
  // App Information
  static const String appName = 'جالا - كشف الحساب';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Account Statement Management App';

  // Supabase Configuration
  static const String supabaseUrl = 'https://ykwnsmyvkwjctidhoqib.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlrd25zbXl2a3dqY3RpZGhvcWliIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExOTkzMzYsImV4cCI6MjA2Njc3NTMzNn0.W6WYYc-s24kX2H_-9bvWe1nG31lDlFCSVnDSqIKD5xk';

  // Shared Preferences Keys
  static const String pinCodeKey = 'pin_code';
  static const String isLoggedInKey = 'is_logged_in';
  static const String lastActiveTimeKey = 'last_active_time';
  static const String userDataKey = 'user_data';
  static const String userTokenKey = 'user_token';
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language_code';
  static const String firstTimeKey = 'first_time_launch';

  // Security Settings
  static const int pinLength = 4; // Changed from 4 to 6 based on your code
  static const int maxPinAttempts = 3;
  static const int backgroundTimeoutMinutes = 5;
  static const int maxLoginAttempts = 5;
  static const Duration loginAttemptLockoutDuration = Duration(minutes: 15);

  // Date Formats
  static const String dateFormat = 'yyyy-MM-dd';
  static const String displayDateFormat = 'dd/MM/yyyy';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';
  static const String apiDateFormat = 'yyyy-MM-dd';
  static const String apiDateTimeFormat = 'yyyy-MM-ddTHH:mm:ss.SSSZ';

  // Updated Color Scheme - Primary: #135467, Accent: #f16936
  static const int primaryColor = 0xFF135467; // Dark Teal - Main brand color
  static const int lightPrimary = 0xFF1E6B7F; // Lighter teal for variations
  static const int darkPrimary = 0xFF0F4550; // Darker teal for emphasis
  static const int accentColor = 0xFFF16936; // Orange - Secondary/accent color
  static const int lightAccent = 0xFFF78455; // Lighter orange for variations
  static const int darkAccent = 0xFFE55A2B; // Darker orange for emphasis

  // Supporting Colors
  static const int surfaceColor = 0xFFF8FAFA; // Very light teal for backgrounds
  static const int backgroundColor = 0xFFFDFDFD; // Almost white background
  static const int cardColor = 0xFFFFFFFF; // Pure white for cards
  static const int dividerColor = 0xFFE8EAEB; // Light gray for dividers

  // Status Colors
  static const int errorColor = 0xFFD32F2F; // Red for errors
  static const int successColor = 0xFF2E7D32; // Green for success
  static const int warningColor = 0xFFF57C00; // Amber for warnings
  static const int infoColor = 0xFF1976D2; // Blue for information

  // Text Colors
  static const int primaryTextColor = 0xFF212121; // Dark Grey - Primary text
  static const int secondaryTextColor =
      0xFF757575; // Medium Grey - Secondary text
  static const int hintTextColor = 0xFFBDBDBD; // Light Grey - Hint text
  static const int onPrimaryTextColor = 0xFFFFFFFF; // White text on primary
  static const int onAccentTextColor = 0xFFFFFFFF; // White text on accent
  static const int disabledTextColor = 0xFF9E9E9E; // Disabled text

  // Interactive Colors
  static const int buttonPrimaryColor = 0xFF135467; // Primary button color
  static const int buttonSecondaryColor = 0xFFF16936; // Secondary button color
  static const int buttonDisabledColor = 0xFFE0E0E0; // Disabled button color
  static const int rippleColor = 0x20135467; // Ripple effect color
  static const int focusColor = 0x40135467; // Focus color
  static const int hoverColor = 0x10135467; // Hover color

  // Shadow Colors
  static const int shadowColor = 0x40000000; // Shadow color
  static const int lightShadowColor = 0x20000000; // Light shadow
  static const int cardShadowColor = 0x15135467; // Card shadow with brand tint

  // Legacy color support (keeping for backward compatibility)
  static const int secondaryColor = 0xFF1E6B7F; // Light primary as secondary
  static const int onSurfaceColor = 0xFF000000; // Black
  static const int disabledColor = 0xFF9E9E9E; // Grey

  // UI Settings - Optimized for better data density
  static const double borderRadius = 8.0;
  static const double largeBorderRadius = 12.0; // Reduced from 16
  static const double smallBorderRadius = 4.0;

  // Padding and Margins - Optimized for better space utilization
  static const double defaultPadding = 12.0; // Reduced from 16
  static const double largePadding = 20.0; // Reduced from 24
  static const double smallPadding = 6.0; // Reduced from 8
  static const double extraLargePadding = 24.0; // Reduced from 32
  static const double microPadding = 4.0; // Added for very small spacing

  // Spacing - Optimized for better data density
  static const double smallSpacing = 6.0; // Reduced from 8
  static const double mediumSpacing = 12.0; // Reduced from 16
  static const double largeSpacing = 20.0; // Reduced from 24
  static const double extraLargeSpacing = 28.0; // Reduced from 32

  // Button Dimensions - Optimized
  static const double buttonHeight = 44.0; // Reduced from 48
  static const double smallButtonHeight = 32.0; // Reduced from 36
  static const double largeButtonHeight = 52.0; // Reduced from 56
  static const double buttonBorderRadius = 8.0;

  // Input Field Dimensions - Optimized
  static const double inputFieldHeight = 48.0; // Reduced from 56
  static const double pinFieldHeight = 50.0; // Reduced from 60
  static const double pinFieldWidth = 40.0; // Reduced from 50

  // Icon Sizes
  static const double smallIconSize = 16.0;
  static const double mediumIconSize = 20.0; // Reduced from 24
  static const double largeIconSize = 28.0; // Reduced from 32
  static const double extraLargeIconSize = 40.0; // Reduced from 48
  static const double iconSizeXXL = 56.0; // Reduced from 64

  // Font Sizes - Optimized for better data density
  static const double titleFontSize = 20.0; // Reduced from 24
  static const double subtitleFontSize = 16.0; // Reduced from 18
  static const double bodyFontSize = 14.0; // Reduced from 16
  static const double captionFontSize = 12.0; // Reduced from 14
  static const double smallFontSize = 11.0; // Reduced from 12
  static const double largeFontSize = 18.0; // Reduced from 20
  static const double microFontSize = 10.0; // Added for very small text

  // Table and List Dimensions - Optimized for data density
  static const double tableHeaderHeight = 32.0; // Compact header
  static const double tableRowHeight = 36.0; // Compact rows
  static const double listItemHeight = 64.0; // Reduced from 72
  static const double cardMinHeight = 80.0; // Minimum card height
  static const double cardElevation = 1.0; // Reduced from 2.0 for subtlety

  // Validation Settings
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 50;
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 30;

  // Animation Settings
  static const int animationDurationMs =
      250; // Reduced from 300 for snappier feel
  static const int shortAnimationDurationMs = 150;
  static const int longAnimationDurationMs = 400; // Reduced from 500
  static const Duration navigationAnimationDuration =
      Duration(milliseconds: 250);

  // Snackbar Durations
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration shortSnackBarDuration = Duration(seconds: 2);
  static const Duration longSnackBarDuration = Duration(seconds: 5);

  // Network Settings
  static const int connectionTimeoutSeconds = 30;
  static const int receiveTimeoutSeconds = 30;
  static const int sendTimeoutSeconds = 30;

  // Error Messages (Arabic)
  static const String networkErrorMessage = 'خطأ في الاتصال بالشبكة';
  static const String unknownErrorMessage = 'حدث خطأ غير متوقع';
  static const String timeoutErrorMessage = 'انتهت مهلة الاتصال';
  static const String serverErrorMessage = 'خطأ في الخادم';
  static const String noInternetMessage = 'لا يوجد اتصال بالإنترنت';
  static const String authenticationErrorMessage = 'خطأ في المصادقة';
  static const String permissionDeniedMessage = 'تم رفض الإذن';

  // Success Messages (Arabic)
  static const String loginSuccessMessage = 'تم تسجيل الدخول بنجاح';
  static const String logoutSuccessMessage = 'تم تسجيل الخروج بنجاح';
  static const String pinSetSuccessMessage = 'تم حفظ رمز PIN بنجاح';
  static const String pinVerifiedSuccessMessage = 'تم التحقق من رمز PIN بنجاح';
  static const String dataUpdatedSuccessMessage = 'تم تحديث البيانات بنجاح';
  static const String dataSavedSuccessMessage = 'تم حفظ البيانات بنجاح';

  // PIN Messages (Arabic)
  static const String enterPinMessage = 'أدخل رمز PIN';
  static const String setupPinMessage = 'قم بإنشاء رمز PIN';
  static const String confirmPinMessage = 'أكد رمز PIN';
  static const String pinMismatchMessage = 'رمز PIN غير متطابق. حاول مرة أخرى.';
  static const String pinIncorrectMessage = 'رمز PIN غير صحيح.';
  static const String maxAttemptsMessage =
      'تم تجاوز عدد المحاولات المسموح. يرجى إعادة تشغيل التطبيق.';

  // Loading Messages (Arabic)
  static const String loadingMessage = 'جاري التحميل...';
  static const String processingMessage = 'جاري المعالجة...';
  static const String connectingMessage = 'جاري الاتصال...';
  static const String retryingMessage = 'جاري المحاولة...';
  static const String savingMessage = 'جاري الحفظ...';
  static const String updatingMessage = 'جاري التحديث...';

  // Validation Messages (Arabic)
  static const String emailRequiredMessage = 'البريد الإلكتروني مطلوب';
  static const String emailInvalidMessage = 'البريد الإلكتروني غير صحيح';
  static const String passwordRequiredMessage = 'كلمة المرور مطلوبة';
  static const String passwordTooShortMessage = 'كلمة المرور قصيرة جداً';
  static const String usernameRequiredMessage = 'اسم المستخدم مطلوب';
  static const String pinRequiredMessage = 'رمز PIN مطلوب';
  static const String pinInvalidMessage = 'رمز PIN غير صحيح';

  // Regex Patterns
  static const String emailPattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
  static const String phonePattern = r'^[0-9]{10,15}$';
  static const String pinPattern = r'^\d{4,6}$';
  static const String usernamePattern = r'^[a-zA-Z0-9_]{3,30}$';
  static const String arabicTextPattern = r'^[\u0600-\u06FF\s\d]+$';

  // API Endpoints (if needed for future use)
  static const String baseUrl = 'https://api.example.com';
  static const String loginEndpoint = '/auth/login';
  static const String signupEndpoint = '/auth/signup';
  static const String logoutEndpoint = '/auth/logout';
  static const String contactsEndpoint = '/contacts';
  static const String usersEndpoint = '/users';
  static const String documentsEndpoint = '/documents';

  // File Paths - Updated logo path
  static const String assetsPath = 'assets/';
  static const String imagesPath = '${assetsPath}images/';
  static const String iconsPath = '${assetsPath}icons/';
  static const String fontsPath = '${assetsPath}fonts/';
  static const String logoPath = '${imagesPath}logo.png'; // Added logo path

  // Cache Settings
  static const Duration cacheExpiration = Duration(hours: 24);
  static const Duration shortCacheExpiration = Duration(hours: 1);
  static const Duration longCacheExpiration = Duration(days: 7);

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  static const int maxContactsPerPage = 50;
  static const int maxSearchResults = 100;

  // File Size Limits
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int maxDocumentSize = 20 * 1024 * 1024; // 20MB

  // Security
  static const int tokenExpirationHours = 24;
  static const int refreshTokenExpirationDays = 30;
  static const int sessionTimeoutMinutes = 30;

  // Feature Flags
  static const bool enableBiometrics = false;
  static const bool enableRememberMe = true;
  static const bool enableOfflineMode = true;
  static const bool enableAnalytics = false;
  static const bool enableCrashReporting = false;
  static const bool enablePushNotifications = true;
  static const bool enableAutoBackup = true;

  // Development & Debug
  static const bool isDebugMode = true;
  static const bool enableLogging = true;
  static const bool showDebugInfo = false;
  static const bool enablePerformanceMonitoring = false;

  // Localization
  static const String defaultLanguage = 'ar';
  static const String fallbackLanguage = 'en';

  // Theme Settings
  static const String defaultTheme = 'light';
  static const bool enableDarkMode = true;
  static const bool enableSystemTheme = true;

  // Notification Settings
  static const String defaultNotificationChannel = 'general';
  static const bool enableVibration = true;
  static const bool enableSound = true;

  // Backup Settings
  static const int maxBackupFiles = 5;
  static const Duration autoBackupInterval = Duration(days: 7);

  // Search Settings
  static const int minSearchLength = 2;
  static const int maxSearchLength = 50;
  static const Duration searchDebounceDelay = Duration(milliseconds: 500);

  // Document Types
  static const List<String> supportedDocumentTypes = [
    'invoice',
    'return',
    'payment',
    'receipt',
    'credit',
    'debit'
  ];

  // Status Types
  static const List<String> documentStatusTypes = [
    'pending',
    'approved',
    'rejected',
    'cancelled',
    'completed'
  ];

  // User Types
  static const List<String> userTypes = ['admin', 'user', 'viewer'];

  // Contact Categories
  static const List<String> contactCategories = [
    'customer',
    'supplier',
    'partner',
    'other'
  ];

  // Default Values
  static const String defaultCurrency = 'USD';
  static const String defaultDateFormat = 'dd/MM/yyyy';
  static const String defaultTimeFormat = '24h';
  static const int defaultItemsPerPage = 20;

  // Limits and Constraints
  static const int maxContactNameLength = 100;
  static const int maxAddressLength = 200;
  static const int maxNotesLength = 500;
  static const int maxDescriptionLength = 1000;

  // Grid and List Settings - Optimized
  static const int gridCrossAxisCount = 2;
  static const double gridChildAspectRatio = 1.3; // Slightly more rectangular
  static const double cardMargin = 6.0; // Reduced margin for cards
  static const double listPadding = 12.0; // Reduced list padding

  // Chart and Graph Settings
  static const int maxChartDataPoints = 100;
  static const double chartAnimationDuration = 1.2; // Slightly faster

  // Export Settings
  static const List<String> supportedExportFormats = ['PDF', 'Excel', 'CSV'];
  static const String defaultExportFormat = 'PDF';

  // Print Settings
  static const String defaultPaperSize = 'A4';
  static const String defaultOrientation = 'portrait';

  // Database Settings
  static const int maxDatabaseConnections = 10;
  static const Duration databaseTimeout = Duration(seconds: 30);

  // Memory Management
  static const int maxCacheSize = 50 * 1024 * 1024; // 50MB
  static const int maxImageCacheSize = 100;
  static const Duration imageCacheTimeout = Duration(hours: 24);

  // Performance Settings
  static const int maxConcurrentOperations = 5;
  static const Duration operationTimeout = Duration(seconds: 30);
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // Accessibility
  static const double minTouchTargetSize =
      44.0; // Reduced from 48 but still accessible
  static const double accessibilityFontScale = 1.2;
  static const bool enableHighContrast = false;

  // Gesture Settings
  static const double swipeThreshold = 100.0;
  static const Duration doubleTapTimeout = Duration(milliseconds: 300);
  static const Duration longPressTimeout = Duration(milliseconds: 500);

  // Keyboard Settings
  static const bool enableAutoCorrect = false;
  static const bool enableSuggestions = true;
  static const bool enableCapitalization = true;

  // Camera and Media
  static const double maxImageQuality = 0.8;
  static const int maxImageWidth = 1920;
  static const int maxImageHeight = 1080;

  // Audio Settings
  static const double defaultVolume = 0.8;
  static const bool enableAudioFeedback = true;

  // Haptic Feedback
  static const bool enableHapticFeedback = true;
  static const String defaultHapticPattern = 'light';

  // Update and Sync
  static const Duration syncInterval = Duration(minutes: 30);
  static const Duration updateCheckInterval = Duration(hours: 12);
  static const bool enableAutoUpdate = false;
  static const bool enableAutoSync = true;

  // Error Reporting
  static const bool enableErrorReporting = false;
  static const int maxErrorReports = 10;
  static const Duration errorReportingCooldown = Duration(minutes: 5);

  // Analytics
  static const bool enableUsageAnalytics = false;
  static const bool enablePerformanceAnalytics = false;
  static const Duration analyticsFlushInterval = Duration(minutes: 15);

  // Privacy
  static const bool enableDataCollection = false;
  static const bool enablePersonalization = true;

  // Legal and Compliance
  static const String privacyPolicyUrl = 'https://example.com/privacy';
  static const String termsOfServiceUrl = 'https://example.com/terms';
  static const String supportUrl = 'https://example.com/support';
  static const String contactEmail = 'support@example.com';

  // App Store and Distribution
  static const String appStoreUrl = 'https://apps.apple.com/app/id123456789';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.example.app';
  static const String updateUrl = 'https://example.com/update';

  // Social Media
  static const String facebookUrl = 'https://facebook.com/example';
  static const String twitterUrl = 'https://twitter.com/example';
  static const String linkedinUrl = 'https://linkedin.com/company/example';

  // Help and Documentation
  static const String helpUrl = 'https://example.com/help';
  static const String documentationUrl = 'https://example.com/docs';
  static const String faqUrl = 'https://example.com/faq';
  static const String tutorialUrl = 'https://example.com/tutorial';

  // Additional UI Constants for Better Data Density
  static const double compactSpacing = 4.0; // Very tight spacing
  static const double denseSpacing =
      8.0; // Dense spacing for data-heavy screens
  static const double tableVerticalPadding = 6.0; // Compact table cell padding
  static const double tableHorizontalPadding = 8.0;
  static const double cardContentPadding = 12.0; // Compact card content padding

  // Status and Priority Colors (complementing the main theme)
  static const int highPriorityColor = 0xFFD32F2F; // Red
  static const int mediumPriorityColor = 0xFFF57C00; // Orange
  static const int lowPriorityColor = 0xFF2E7D32; // Green
  static const int neutralColor = 0xFF757575; // Grey

  // Data Visualization Colors (harmonizing with brand colors)
  static const List<int> chartColors = [
    0xFF135467, // Primary teal
    0xFFF16936, // Accent orange
    0xFF2E7D32, // Success green
    0xFF1976D2, // Info blue
    0xFFF57C00, // Warning amber
    0xFFD32F2F, // Error red
    0xFF7B1FA2, // Purple
    0xFF00796B, // Teal variant
  ];

  // Border and Outline Colors
  static const int borderColor = 0xFFE0E0E0; // Light border
  static const int focusBorderColor = 0xFF135467; // Primary color for focus
  static const int errorBorderColor = 0xFFD32F2F; // Red border for errors
  static const int successBorderColor = 0xFF2E7D32; // Green border for success

  // Opacity Values
  static const double highEmphasisOpacity = 0.87; // High emphasis text/icons
  static const double mediumEmphasisOpacity =
      0.60; // Medium emphasis text/icons
  static const double lowEmphasisOpacity = 0.38; // Low emphasis text/icons
  static const double disabledOpacity = 0.12; // Disabled state opacity
  static const double hoverOpacity = 0.04; // Hover state opacity
  static const double focusOpacity = 0.12; // Focus state opacity
  static const double pressedOpacity = 0.16; // Pressed state opacity

  // Logo and Branding
  static const double logoSize = 60.0; // Standard logo size
  static const double smallLogoSize = 40.0; // Small logo size
  static const double largeLogoSize = 80.0; // Large logo size
}
