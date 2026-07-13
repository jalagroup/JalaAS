// lib/services/fcm_service.dart
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:jala_as/models/user.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/constants.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // On mobile: system tray notification is shown automatically by FCM.
  // No extra work needed here.
  debugPrint('📱 Background FCM message: ${message.notification?.title}');
}

class FCMService {
  static String? _currentToken;
  static bool _isSetup = false;
  static GlobalKey<NavigatorState>? _navigatorKey;

  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _localNotificationsInitialized = false;

  // Must be called once at app startup (mobile only — pass navigatorKey for web)
  static Future<void> initialize() async {
    if (kIsWeb) return;
    await _initLocalNotifications();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  static Future<void> _initLocalNotifications() async {
    if (_localNotificationsInitialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          try {
            final data = jsonDecode(details.payload!) as Map<String, dynamic>;
            _handleNotificationTap(data);
          } catch (_) {}
        }
      },
    );

    // Create Android notification channel
    const channel = AndroidNotificationChannel(
      'jala_as_channel',
      'Jala Success Notifications',
      description: 'App notifications',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _localNotificationsInitialized = true;
  }

  /// Call this after the user logs in (both web and mobile).
  /// On web: only fetches the token if permission is already granted.
  ///   Permission requests must come from a user gesture — the
  ///   NotificationPermissionBanner widget calls [requestWebPermission].
  /// On native: requests permission directly (no gesture required).
  static Future<void> setupForUser(AppUser user,
      {GlobalKey<NavigatorState>? navigatorKey}) async {
    _navigatorKey = navigatorKey;
    try {
      final messaging = FirebaseMessaging.instance;

      if (kIsWeb) {
        // Check current status without triggering the browser dialog.
        final settings = await messaging.getNotificationSettings();
        final granted =
            settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
        if (granted) {
          final token =
              await messaging.getToken(vapidKey: AppConstants.vapidKey);
          if (token != null) {
            _currentToken = token;
            await SupabaseService.saveFcmToken(token);
            debugPrint('✅ FCM token saved (web)');
          }
        }
        // If not granted, the banner will handle it via requestWebPermission().
      } else {
        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        if (settings.authorizationStatus != AuthorizationStatus.authorized &&
            settings.authorizationStatus != AuthorizationStatus.provisional) {
          debugPrint('❌ FCM permission denied');
          return;
        }
        final token = await messaging.getToken();
        if (token != null) {
          _currentToken = token;
          await SupabaseService.saveFcmToken(token);
          debugPrint('✅ FCM token saved (${token.substring(0, 20)}...)');
        }
      }

      if (!_isSetup) {
        _setupListeners(navigatorKey: navigatorKey);
        messaging.onTokenRefresh.listen((newToken) async {
          _currentToken = newToken;
          await SupabaseService.saveFcmToken(newToken);
        });
        _isSetup = true;
      }
      debugPrint('✅ FCM setup complete');
    } catch (e) {
      debugPrint('❌ FCM setup error: $e');
    }
  }

  /// Request notification permission from within a user gesture (web only).
  /// Returns true if the user granted permission.
  static Future<bool> requestWebPermission() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (granted) {
        final token =
            await messaging.getToken(vapidKey: AppConstants.vapidKey);
        if (token != null) {
          _currentToken = token;
          await SupabaseService.saveFcmToken(token);
          debugPrint('✅ FCM token saved after web permission grant');
        }
        // Wire up listeners if setupForUser ran before permission was granted.
        if (!_isSetup) {
          _setupListeners(navigatorKey: _navigatorKey);
          messaging.onTokenRefresh.listen((newToken) async {
            _currentToken = newToken;
            await SupabaseService.saveFcmToken(newToken);
          });
          _isSetup = true;
        }
      }
      return granted;
    } catch (e) {
      debugPrint('❌ FCM web permission error: $e');
      return false;
    }
  }

  static void _setupListeners({GlobalKey<NavigatorState>? navigatorKey}) {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('📨 Foreground message: ${message.notification?.title}');
      _showForegroundNotification(message, navigatorKey: navigatorKey);
    });

    // Tapped while app was in background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message.data);
    });

    // Tapped while app was terminated
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        Future.delayed(
          const Duration(milliseconds: 500),
          () => _handleNotificationTap(message.data),
        );
      }
    });
  }

  static void _showForegroundNotification(RemoteMessage message,
      {GlobalKey<NavigatorState>? navigatorKey}) {
    final title = message.notification?.title ?? 'إشعار جديد';
    final body = message.notification?.body ?? '';

    if (kIsWeb) {
      // Service worker handles background; show a SnackBar for foreground
      final context = navigatorKey?.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                if (body.isNotEmpty) Text(body, style: const TextStyle(fontSize: 13)),
              ],
            ),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } else {
      _showLocalNotification(title, body, message.data);
    }
  }

  static Future<void> _showLocalNotification(
      String title, String body, Map<String, dynamic> data) async {
    if (!_localNotificationsInitialized) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'jala_as_channel',
        'Jala Success Notifications',
        channelDescription: 'App notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
      title,
      body,
      details,
      payload: jsonEncode(data),
    );
  }

  static void _handleNotificationTap(Map<String, dynamic> data) {
    debugPrint('🔔 Notification tapped: $data');
    final type = data['type'] as String?;
    if (type == null) return;

    // Delay to ensure the navigator is ready after cold start
    Future.delayed(const Duration(milliseconds: 300), () {
      switch (type) {
        case 'task_assigned':
        case 'task_due_today':
        case 'task_reminder':
          _navigatorPush('/tasks',
              args: {'checklist_id': data['checklist_id']});
          break;
        case 'quality_issue_assigned':
        case 'quality_issue_resolved':
        case 'quality_reminder':
          _navigatorPush('/quality',
              args: {'issue_id': data['issue_id']});
          break;
      }
    });
  }

  static void _navigatorPush(String route, {Map<String, dynamic>? args}) {
    // Named-route navigation — works if your app uses named routes.
    // Replace with direct Navigator.push calls if you use builder-style routing.
    debugPrint('🔔 Navigate to $route with args: $args');
    // Example for builder routing (uncomment and adapt):
    // navigatorKey?.currentState?.push(MaterialPageRoute(builder: (_) => TargetScreen(...)));
  }

  static Future<void> clearForLogout() async {
    try {
      if (_currentToken != null && !kIsWeb) {
        await FirebaseMessaging.instance.deleteToken();
      }
    } catch (_) {}
    _currentToken = null;
    _isSetup = false;
  }

  static String? get currentToken => _currentToken;
  static bool get isSetup => _isSetup;
}
