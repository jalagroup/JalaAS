// lib/utils/platform_utils.dart - Platform Detection Utility

import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class PlatformUtils {
  // Check if running on web
  static bool get isWeb => kIsWeb;

  // Check if running on mobile (Android or iOS)
  static bool get isMobile => !kIsWeb && (isAndroid || isIOS);

  // Check if running on Android
  static bool get isAndroid {
    try {
      return !kIsWeb && Platform.isAndroid;
    } catch (e) {
      return false;
    }
  }

  // Check if running on iOS
  static bool get isIOS {
    try {
      return !kIsWeb && Platform.isIOS;
    } catch (e) {
      return false;
    }
  }

  // Check if offline features should be enabled
  static bool get supportsOfflineMode => isMobile;

  // Get platform name for debugging
  static String get platformName {
    if (isWeb) return 'Web';
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    return 'Unknown';
  }
}
