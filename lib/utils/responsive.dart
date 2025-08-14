import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:jala_as/screens/mobile/mobile_main.dart';

import '../screens/web/web_main.dart';

class ResponsiveHelper {
  static bool isMobileApp() =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool isDesktopApp() =>
      !kIsWeb &&
      !(defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool isMobileWeb(BuildContext context) =>
      kIsWeb && MediaQuery.of(context).size.width < 600;

  static bool isDesktopWeb(BuildContext context) =>
      kIsWeb && MediaQuery.of(context).size.width >= 600;
}

class Responsive extends StatelessWidget {
  const Responsive({super.key});

  @override
  Widget build(BuildContext context) {
    if (ResponsiveHelper.isMobileWeb(context)) {
      return const WebApp(); // Web (Mobile Layout)
    } else if (ResponsiveHelper.isDesktopWeb(context)) {
      return const WebApp(); // Web (Desktop Layout)
    } else if (ResponsiveHelper.isMobileApp()) {
      return const MobileApp(); // Mobile App
    } else {
      return const MobileApp(); // Desktop App fallback
    }
  }
}
