import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui' as ui;
import '../../../models/user.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/constants.dart';
import 'warehouse_request_tabs.dart';

class WarehouseTransferScreen extends StatefulWidget {
  final AppUser user;

  const WarehouseTransferScreen({super.key, required this.user});

  @override
  State<WarehouseTransferScreen> createState() =>
      _WarehouseTransferScreenState();
}

class _WarehouseTransferScreenState extends State<WarehouseTransferScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPendingCount();
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.index == 2) _loadPendingCount();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingCount() async {
    try {
      final currentUser = SupabaseService.currentAuthUser;
      if (currentUser == null) return;
      final response = await Supabase.instance.client.rpc(
        'get_user_pending_requests_count',
        params: {'user_id': currentUser.id},
      );
      if (mounted) setState(() => _pendingCount = response as int? ?? 0);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 768;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F3F8),
        body: Column(
          children: [
            _buildHeader(isMobile),
            _buildTabBar(isMobile),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  NewTransferTab(
                    user: widget.user,
                    onTransferComplete: _loadPendingCount,
                  ),
                  SentRequestsTab(user: widget.user),
                  PendingReceivedRequestsTab(
                    user: widget.user,
                    onRequestHandled: _loadPendingCount,
                  ),
                  CompletedRequestsTab(user: widget.user),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(AppConstants.primaryColor), Color(0xFF0B3D50)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 20,
            vertical: 12,
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha:0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.swap_horiz,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'إرسال بضاعة بين المستودعات',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 15 : 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.user.username,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha:0.7),
                        fontSize: isMobile ? 11 : 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (_pendingCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_active,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '$_pendingCount طلب',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(AppConstants.accentColor),
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: const Color(AppConstants.accentColor),
        unselectedLabelColor: Colors.grey.shade500,
        labelStyle: TextStyle(
          fontSize: isMobile ? 11 : 13,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: isMobile ? 11 : 13,
          fontWeight: FontWeight.w500,
        ),
        isScrollable: isMobile,
        tabs: [
          _buildTab(Icons.send_outlined, 'إرسال جديد', isMobile),
          _buildTab(Icons.outbox_outlined, 'المرسلة', isMobile),
          _buildPendingTab(isMobile),
          _buildTab(Icons.task_alt_outlined, 'المنهية', isMobile),
        ],
      ),
    );
  }

  Tab _buildTab(IconData icon, String label, bool isMobile) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isMobile ? 14 : 16),
          const SizedBox(width: 5),
          Text(label),
        ],
      ),
    );
  }

  Tab _buildPendingTab(bool isMobile) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: isMobile ? 14 : 16),
          const SizedBox(width: 5),
          const Text('المستلمة'),
          if (_pendingCount > 0) ...[
            const SizedBox(width: 5),
            Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                _pendingCount.toString(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
