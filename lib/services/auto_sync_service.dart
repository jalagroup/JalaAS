import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Read-only service — actual syncing is handled by the Supabase Edge Function
// scheduled via pg_cron every 3 hours. This service just reads sync_logs.
class AutoSyncService extends ChangeNotifier {
  static final AutoSyncService instance = AutoSyncService._();
  AutoSyncService._();

  static const _kEnabledKey = 'auto_sync_enabled';
  static const syncInterval = Duration(hours: 3);

  bool _enabled = true;
  DateTime? _lastSyncTime;
  bool _initialized = false;
  Timer? _refreshTimer;

  bool get enabled => _enabled;
  bool get isSyncing => false;
  String get syncStatus => '';
  DateTime? get lastSyncTime => _lastSyncTime;

  DateTime? get nextSyncTime => _lastSyncTime?.add(syncInterval);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kEnabledKey) ?? true;

    await _refreshLastSyncTime();

    // Refresh display every 5 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _refreshLastSyncTime();
    });
  }

  Future<void> _refreshLastSyncTime() async {
    try {
      final row = await Supabase.instance.client
          .from('sync_logs')
          .select('synced_at')
          .eq('status', 'success')
          .order('synced_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row != null) {
        _lastSyncTime = DateTime.parse(row['synced_at'] as String).toLocal();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, value);
    notifyListeners();
  }

  // Refresh after a manual sync completes
  Future<void> refreshFromServer() => _refreshLastSyncTime();

  void resetInitialized() {
    _initialized = false;
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
