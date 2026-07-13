// lib/widgets/connectivity_indicator.dart - Network Status Indicator

import 'package:flutter/material.dart';
import '../services/offline_queue_service.dart';
import '../services/api_service.dart';
import '../utils/platform_utils.dart';

class ConnectivityIndicator extends StatefulWidget {
  const ConnectivityIndicator({super.key});

  @override
  State<ConnectivityIndicator> createState() => _ConnectivityIndicatorState();
}

class _ConnectivityIndicatorState extends State<ConnectivityIndicator> {
  bool _isOnline = true;
  int _pendingCount = 0;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    if (PlatformUtils.isMobile) {
      _checkStatus();
      _startPeriodicCheck();
    }
  }

  void _startPeriodicCheck() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _checkStatus();
        _startPeriodicCheck();
      }
    });
  }

  Future<void> _checkStatus() async {
    if (!PlatformUtils.isMobile || !mounted) return;

    final isOnline = OfflineQueueService().isOnline;
    final pendingCount = await ApiService.getPendingOperationsCount();
    final isSyncing = OfflineQueueService().isProcessing;

    if (mounted) {
      setState(() {
        _isOnline = isOnline;
        _pendingCount = pendingCount;
        _isSyncing = isSyncing;
      });
    }
  }

  Future<void> _manualSync() async {
    if (!_isOnline || _isSyncing) return;

    setState(() => _isSyncing = true);
    await ApiService.syncPendingOperations();
    await _checkStatus();
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformUtils.isMobile) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIcon(),
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Text(
            _getStatusText(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_pendingCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$_pendingCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          if (_isOnline && _pendingCount > 0 && !_isSyncing) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _manualSync,
              child: const Icon(
                Icons.sync,
                size: 16,
                color: Colors.white,
              ),
            ),
          ],
          if (_isSyncing) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getBackgroundColor() {
    if (_isSyncing) return Colors.blue;
    if (!_isOnline) return Colors.red;
    if (_pendingCount > 0) return Colors.orange;
    return Colors.green;
  }

  IconData _getIcon() {
    if (_isSyncing) return Icons.sync;
    if (!_isOnline) return Icons.cloud_off;
    if (_pendingCount > 0) return Icons.cloud_queue;
    return Icons.cloud_done;
  }

  String _getStatusText() {
    if (_isSyncing) return 'جاري المزامنة...';
    if (!_isOnline) return 'غير متصل';
    if (_pendingCount > 0) return 'في الانتظار';
    return 'متصل';
  }
}
