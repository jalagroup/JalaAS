// lib/services/device_info_service.dart - Device Identification Service

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../utils/platform_utils.dart';

class DeviceInfoService {
  static final DeviceInfoService _instance = DeviceInfoService._internal();
  factory DeviceInfoService() => _instance;
  DeviceInfoService._internal();

  static const String _deviceIdKey = 'device_unique_id';
  String? _cachedDeviceId;

  /// Get unique device identifier
  /// For Android: Uses Android ID
  /// For iOS: Uses identifierForVendor
  /// Fallback: Generates and stores a UUID
  Future<String> getDeviceId() async {
    // Return cached ID if available
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    final prefs = await SharedPreferences.getInstance();

    // Check if we have a stored device ID
    String? storedId = prefs.getString(_deviceIdKey);
    if (storedId != null && storedId.isNotEmpty) {
      _cachedDeviceId = storedId;
      return storedId;
    }

    // Generate new device ID
    String deviceId = await _generateDeviceId();

    // Store for future use
    await prefs.setString(_deviceIdKey, deviceId);
    _cachedDeviceId = deviceId;

    return deviceId;
  }

  /// Generate unique device identifier based on platform
  Future<String> _generateDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    String identifier = '';

    try {
      if (PlatformUtils.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Use Android ID as primary identifier
        identifier = androidInfo.id; // This is Android ID (unique per device)

        // Fallback: combine multiple identifiers for uniqueness
        if (identifier.isEmpty) {
          identifier =
              '${androidInfo.device}_${androidInfo.model}_${androidInfo.product}';
        }
      } else if (PlatformUtils.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // Use identifierForVendor
        identifier = iosInfo.identifierForVendor ?? '';

        // Fallback: combine device info
        if (identifier.isEmpty) {
          identifier =
              '${iosInfo.name}_${iosInfo.model}_${iosInfo.systemVersion}';
        }
      }
    } catch (e) {
      print('Error getting device info: $e');
      // Generate random UUID as last resort
      identifier = DateTime.now().millisecondsSinceEpoch.toString();
    }

    // Hash the identifier for privacy and consistency
    return _hashIdentifier(identifier);
  }

  /// Hash the device identifier using SHA-256
  String _hashIdentifier(String input) {
    final bytes = utf8.encode(input);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// Get device information for display/debugging
  Future<Map<String, dynamic>> getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    Map<String, dynamic> info = {};

    try {
      if (PlatformUtils.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        info = {
          'platform': 'Android',
          'model': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
          'version': androidInfo.version.release,
          'sdk': androidInfo.version.sdkInt,
          'device': androidInfo.device,
        };
      } else if (PlatformUtils.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        info = {
          'platform': 'iOS',
          'model': iosInfo.model,
          'name': iosInfo.name,
          'version': iosInfo.systemVersion,
          'device': iosInfo.utsname.machine,
        };
      }
    } catch (e) {
      print('Error getting device info: $e');
    }

    return info;
  }

  /// Clear stored device ID (for testing/debugging)
  Future<void> clearDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceIdKey);
    _cachedDeviceId = null;
  }
}
