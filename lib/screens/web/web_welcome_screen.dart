// lib/screens/web/web_welcome_screen.dart - UPDATED WITH TASK CHECKLISTS

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jala_as/screens/web/price_list_report/price_list_screen.dart';
import 'package:jala_as/screens/web/quality_system/quality_issues_screen.dart';
import 'package:jala_as/screens/web/returns_system/bulk_warehouse_transfer_screen.dart';
import 'package:jala_as/screens/web/returns_system/sales_return_form_screen.dart';
import 'package:jala_as/screens/web/storeIssues_system/warehouse_transfer_screen.dart';
import 'package:jala_as/screens/web/aging_report/web_salesman_selection_screen.dart';
import 'package:jala_as/screens/web/salary/salary_management_hub_screen.dart';
import 'package:jala_as/screens/web/tasks_system/my_task_checklists_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user.dart';
import '../../models/feature_definition.dart';
import '../../services/supabase_service.dart';
import '../../services/permission_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import 'report_builder/report_viewer_screen.dart';
import 'report_builder/custom_reports_list_screen.dart';
import 'account_statements/web_contact_selection_screen.dart';
import 'aging_report/web_aging_report_screen.dart';
import 'web_login_screen.dart';
import '../profile_screen.dart';
import 'create_customers_system/web_customer_opening_screen.dart';
import 'quality_system/quality_checklists_screen.dart';
import 'quality_system/my_report_lists_screen.dart';
import 'fuel_system/fuel_filling_form_screen.dart';
import 'admin_dasboards/fuel_management_screen.dart';
import 'periodic_sales_report/periodic_sales_selection_screen.dart';
import 'almira_stock_report/almira_stock_report_screen.dart';

class WebWelcomeScreen extends StatefulWidget {
  const WebWelcomeScreen({super.key});

  @override
  State<WebWelcomeScreen> createState() => _WebWelcomeScreenState();
}

class _WebWelcomeScreenState extends State<WebWelcomeScreen>
    with AutomaticKeepAliveClientMixin {
  AppUser? _currentUser;
  bool _isLoading = true;
  int _pendingTransfersCount = 0;
  Timer? _refreshTimer;
  int _pendingIssuesCount = 0;

  // Cached colors
  static const _primaryColor = Color(AppConstants.primaryColor);
  static const _accentColor = Color(AppConstants.accentColor);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentUser();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      _currentUser = await SupabaseService.getCurrentUser();

      if (_currentUser == null) {
        _navigateToLogin();
        return;
      }

      // Load role-based permissions when the user has a role assigned
      if (_currentUser!.roleId != null) {
        await PermissionService.loadForUser(_currentUser!.id);
      } else {
        PermissionService.clear();
      }

      // Load pending issues count for all users
      await _loadPendingIssuesCount();

      if (_currentUser!.salesman != '00' &&
          !_currentUser!.isQualityController) {
        await _loadPendingTransfersCount();
        _startPeriodicRefresh();
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في تحميل بيانات المستخدم',
            isError: true);
        _navigateToLogin();
      }
    }
  }

  Future<void> _loadPendingIssuesCount() async {
    try {
      final count = await SupabaseService.getUserPendingIssuesCount();
      if (mounted) {
        setState(() {
          _pendingIssuesCount = count;
        });
      }
    } catch (e) {
      // Silent fail
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (mounted) {
        _loadPendingTransfersCount();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _loadPendingTransfersCount() async {
    try {
      final currentUser = SupabaseService.currentAuthUser;
      if (currentUser == null) return;

      final response = await Supabase.instance.client
          .rpc('get_user_pending_requests_count', params: {
        'user_id': currentUser.id,
      });

      if (mounted) {
        setState(() {
          _pendingTransfersCount = response as int? ?? 0;
        });
      }
    } catch (e) {
      // Silent fail
    }
  }

  void _navigateToBulkWarehouseTransfer() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BulkWarehouseTransferScreen(user: _currentUser!),
      ),
    );
  }

  void _navigateToWarehouseTransfer() async {
    final result = await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            WarehouseTransferScreen(user: _currentUser!),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );

    if (result == null &&
        _currentUser!.salesman != '00' &&
        !_currentUser!.isQualityController) {
      await _loadPendingTransfersCount();
    }
  }

  void _navigateToQualityIssues() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QualityIssuesScreen(user: _currentUser!),
      ),
    );

    if (result == true) {
      await _loadPendingIssuesCount();
    }
  }

  // ── NEW: Navigate to task checklists ───────────────────────────────────────
  void _navigateToMyTaskChecklists() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MyTaskChecklistsScreen(),
      ),
    );
  }

  void _navigateToMyReportLists() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MyReportListsScreen(user: _currentUser!),
      ),
    );
  }

  // ── Role-based card builder ─────────────────────────────────────────────────

  List<Widget> _buildRoleBasedCards(bool isMobile) {
    final List<Widget> cards = [];

    void add(String featureKey, String title, String subtitle, IconData icon,
        VoidCallback onTap, {int? badge}) {
      if (!PermissionService.hasFeature(featureKey)) return;
      cards.add(_buildLightCard(
        title: title,
        subtitle: subtitle,
        icon: icon,
        onTap: onTap,
        isMobile: isMobile,
        badgeCount: badge,
      ));
    }

    add(AppFeatures.accountStatements, 'كشف الحساب',
        'عرض كشوف حسابات العملاء',
        Icons.account_balance_wallet_outlined, _navigateToContactSelection);

    add(AppFeatures.agingReport, 'التعميرة', 'تقرير المديونيات',
        Icons.analytics_outlined, _navigateToAgingReport);

    add(AppFeatures.almiraStockReport, 'أرصدة المخزون - الميرا',
        'رصيد المرحل والمحفوظ وإنتاج ZFI',
        Icons.inventory_2_outlined, _navigateToAlmiraStockReport);

    add(AppFeatures.periodicSalesReport, 'تقرير المبيعات',
        'تقرير المبيعات حسب الفترات والمناطق',
        Icons.timeline_outlined, _navigateToPeriodicSalesReport);

    add(AppFeatures.priceList, 'قائمة الأسعار', 'عرض قوائم الأسعار P و S',
        Icons.price_change_outlined, _navigateToPriceList);

    add(AppFeatures.salaryManagement, 'إدارة الرواتب والأهداف',
        'إدارة العلامات التجارية والأهداف وحساب الرواتب',
        Icons.payments_outlined, _navigateToSalaryManagement);

    add(AppFeatures.warehouseTransfer, 'إرسال بضاعة بين المستودعات',
        'نقل الأصناف بين المخازن المختلفة',
        Icons.warehouse_outlined, _navigateToWarehouseTransfer,
        badge: _pendingTransfersCount);

    add(AppFeatures.bulkWarehouseTransfer, 'ترحيل كل البضاعة بالمخازن',
        'ترحيل جميع الأصناف للمخزن الرئيسي',
        Icons.move_to_inbox_outlined, _navigateToBulkWarehouseTransfer);

    add(AppFeatures.createCustomer, 'فتح الزبون', 'إضافة عميل جديد',
        Icons.person_add_outlined, _navigateToCustomerOpening);

    add(AppFeatures.fuelFilling, 'إدخال المحروقات',
        'تسجيل بيانات تعبئة المحروقات',
        Icons.local_gas_station_outlined, _navigateToFuelFilling);

    add(AppFeatures.salesReturns, 'مرتجعات المبيعات',
        'إدارة مرتجعات المبيعات والطباعة',
        Icons.assignment_return_outlined, _navigateToSalesReturns);

    add(AppFeatures.qualityChecklists, 'تقارير مراقبة الجودة',
        'إدارة وملء قوائم مراقبة الجودة',
        Icons.checklist_outlined, _navigateToQualityChecklists);

    add(AppFeatures.qualityIssues, 'مشاكل نقاط الفحص',
        'عرض وحل المشاكل المعينة لك',
        Icons.report_problem_outlined, _navigateToQualityIssues,
        badge: _pendingIssuesCount);

    add(AppFeatures.taskChecklists, 'قوائم مهامي',
        'المهام اليومية المخصصة لك',
        Icons.task_alt_outlined, _navigateToMyTaskChecklists);

    add(AppFeatures.reportLists, 'قوائم التقارير',
        'عرض وملء قوائم التقارير المخصصة لك',
        Icons.assignment_outlined, _navigateToMyReportLists);

    add(AppFeatures.customReportsViewer, 'التقارير المخصصة',
        'عرض وتشغيل التقارير المخصصة',
        Icons.bar_chart_outlined, _navigateToCustomReports);

    return cards;
  }

  void _navigateToCustomReports() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomReportsListScreen(currentUser: _currentUser!),
      ),
    );
  }

  // ── Legacy card builder (users without a role) ───────────────────────────────

  List<Widget> _buildServiceCards(bool isDesktop, bool isMobile) {
    // When user has a role assigned, use the role-based card list
    if (PermissionService.hasRole && PermissionService.isUserInterface) {
      return _buildRoleBasedCards(isMobile);
    }

    final List<Widget> cards = [];

    if (_currentUser!.isQualityController) {
      // Quality checklists (rating-based)
      cards.add(_buildLightCard(
        title: 'تقارير مراقبة الجودة',
        subtitle: 'إدارة وملء قوائم مراقبة الجودة',
        icon: Icons.checklist_outlined,
        onTap: _navigateToQualityChecklists,
        isMobile: isMobile,
      ));

      // ── NEW: Task checklists card for quality controller ──────────────────
      cards.add(_buildLightCard(
        title: 'قوائم مهامي',
        subtitle: 'المهام اليومية المخصصة لك',
        icon: Icons.task_alt_outlined,
        onTap: _navigateToMyTaskChecklists,
        isMobile: isMobile,
      ));

      // Report lists card
      cards.add(_buildLightCard(
        title: 'قوائم التقارير',
        subtitle: 'عرض وملء قوائم التقارير المخصصة لك',
        icon: Icons.assignment_outlined,
        onTap: _navigateToMyReportLists,
        isMobile: isMobile,
      ));

      // Quality issues
      cards.add(_buildLightCard(
        title: 'مشاكل نقاط الفحص',
        subtitle: 'عرض وحل المشاكل المعينة لك',
        icon: Icons.report_problem_outlined,
        onTap: _navigateToQualityIssues,
        isMobile: isMobile,
        badgeCount: _pendingIssuesCount,
      ));

      return cards;
    }

    // Common cards for all non-QC users
    cards.addAll([
      _buildLightCard(
        title: 'كشف الحساب',
        subtitle: 'عرض كشوف حسابات العملاء',
        icon: Icons.account_balance_wallet_outlined,
        onTap: _navigateToContactSelection,
        isMobile: isMobile,
      ),
      _buildLightCard(
        title: 'التعميرة',
        subtitle: 'تقرير المديونيات',
        icon: Icons.analytics_outlined,
        onTap: _navigateToAgingReport,
        isMobile: isMobile,
      ),
      _buildLightCard(
        title: 'مشاكل نقاط الفحص',
        subtitle: 'عرض وحل المشاكل المعينة لك',
        icon: Icons.report_problem_outlined,
        onTap: _navigateToQualityIssues,
        isMobile: isMobile,
        badgeCount: _pendingIssuesCount,
      ),
    ]);

    // مدير مبيعات only
    if (_currentUser!.isSalesAdmin) {
      cards.add(_buildLightCard(
        title: 'أرصدة المخزون - الميرا',
        subtitle: 'رصيد المرحل والمحفوظ وإنتاج ZFI',
        icon: Icons.inventory_2_outlined,
        onTap: _navigateToAlmiraStockReport,
        isMobile: isMobile,
      ));
    }

    // Admin-only cards
    if (_currentUser?.salesman == '00') {
      cards.addAll([
        _buildLightCard(
          title: 'تقرير المبيعات',
          subtitle: 'تقرير المبيعات حسب الفترات الزمنية والمناطق',
          icon: Icons.timeline_outlined,
          onTap: _navigateToPeriodicSalesReport,
          isMobile: isMobile,
        ),
        _buildLightCard(
          title: 'قائمة الأسعار',
          subtitle: 'عرض قوائم الأسعار P و S',
          icon: Icons.price_change_outlined,
          onTap: _navigateToPriceList,
          isMobile: isMobile,
        ),
        _buildLightCard(
          title: 'إدارة رواتب المندوبين والأهداف',
          subtitle: 'إدارة العلامات التجارية والأهداف وحساب الرواتب',
          icon: Icons.payments_outlined,
          onTap: _navigateToSalaryManagement,
          isMobile: isMobile,
        ),
      ]);
    }

    if (_currentUser?.salesman != '00' && !_currentUser!.isQualityController) {
      cards.addAll([
        _buildLightCard(
          title: 'إرسال بضاعة بين المستودعات',
          subtitle: 'نقل الأصناف بين المخازن المختلفة',
          icon: Icons.warehouse_outlined,
          onTap: _navigateToWarehouseTransfer,
          isMobile: isMobile,
          badgeCount: _pendingTransfersCount,
        ),
        _buildLightCard(
          title: 'ترحيل كل البضاعة بالمخازن',
          subtitle: 'ترحيل جميع الأصناف للمخزن الرئيسي',
          icon: Icons.move_to_inbox_outlined,
          onTap: _navigateToBulkWarehouseTransfer,
          isMobile: isMobile,
        ),
        _buildLightCard(
          title: 'فتح الزبون',
          subtitle: 'إضافة عميل جديد',
          icon: Icons.person_add_outlined,
          onTap: _navigateToCustomerOpening,
          isMobile: isMobile,
        ),
      ]);
    }

    // Common cards at the end
    cards.addAll([
      _buildLightCard(
        title: 'إدخال المحروقات',
        subtitle: 'تسجيل بيانات تعبئة المحروقات',
        icon: Icons.local_gas_station_outlined,
        onTap: _navigateToFuelFilling,
        isMobile: isMobile,
      ),
      _buildLightCard(
        title: 'مرتجعات المبيعات',
        subtitle: 'إدارة مرتجعات المبيعات والطباعة',
        icon: Icons.assignment_return_outlined,
        onTap: _navigateToSalesReturns,
        isMobile: isMobile,
      ),
    ]);

    return cards;
  }

  Widget _buildLightCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required bool isMobile,
    int? badgeCount,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: isMobile ? 44 : 48,
                      height: isMobile ? 44 : 48,
                      decoration: BoxDecoration(
                        color: _accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        size: isMobile ? 20 : 24,
                        color: _accentColor,
                      ),
                    ),
                    if (badgeCount != null && badgeCount > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Text(
                            badgeCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          color: _primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isDesktop = screenWidth >= 1024;

    if (_isLoading) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _currentUser != null
            ? _LightAppBar(
                currentUser: _currentUser!,
                onLogout: _logout,
                onProfile: _openProfile,
                isDesktop: isDesktop,
              )
            : null,
        body: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 800 : 600,
                    ),
                    child: Column(
                      children: [
                        _buildWelcomeHeader(isMobile),
                        SizedBox(height: isMobile ? 24 : 32),
                        Text(
                          'الخدمات المتاحة',
                          style: TextStyle(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.w600,
                            color: _primaryColor,
                          ),
                        ),
                        SizedBox(height: isMobile ? 16 : 20),
                        _buildServiceCardsLayout(isDesktop, isMobile),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isMobile ? 60 : 70,
            height: isMobile ? 60 : 70,
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Image.asset(
                AppConstants.logoPath,
                width: isMobile ? 32 : 40,
                height: isMobile ? 32 : 40,
                fit: BoxFit.contain,
                cacheWidth: isMobile ? 64 : 80,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.account_balance,
                    size: isMobile ? 32 : 40,
                    color: _accentColor,
                  );
                },
              ),
            ),
          ),
          SizedBox(height: isMobile ? 16 : 20),
          Text(
            _getGreetingMessage(),
            style: TextStyle(
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.w600,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          if (_currentUser != null) ...[
            Text(
              _currentUser!.username,
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w500,
                color: _accentColor,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getUserTypeBadgeColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getUserTypeIcon(),
                    size: 14,
                    color: _getUserTypeBadgeColor(),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _currentUser!.userTypeDisplayText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _getUserTypeBadgeColor(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceCardsLayout(bool isDesktop, bool isMobile) {
    final cards = _buildServiceCards(isDesktop, isMobile);

    if (isDesktop && cards.length > 2) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2.5,
        ),
        itemCount: cards.length,
        itemBuilder: (context, index) => cards[index],
      );
    } else {
      return Column(
        children: cards
            .map((card) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: card,
                ))
            .toList(),
      );
    }
  }

  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'صباح الخير';
    if (hour >= 12 && hour < 17) return 'مساء الخير';
    return 'مساء الخير';
  }

  Color _getUserTypeBadgeColor() {
    if (_currentUser!.isSystemAdmin) return const Color(0xFFF16936);
    if (_currentUser!.isSalesAdmin) return const Color(0xFF10B981);
    if (_currentUser!.isQualityController) return const Color(0xFF8B5CF6);
    return _accentColor;
  }

  IconData _getUserTypeIcon() {
    if (_currentUser!.isSystemAdmin) return Icons.admin_panel_settings_outlined;
    if (_currentUser!.isSalesAdmin) return Icons.supervisor_account_outlined;
    if (_currentUser!.isQualityController) return Icons.checklist_outlined;
    return Icons.person_outline;
  }

  void _openProfile() {
    if (_currentUser == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(user: _currentUser!)),
    );
  }

  Future<void> _logout() async {
    try {
      await SupabaseService.signOut();
      await Helpers.setLoggedIn(false);
      await Helpers.clearUserData();
      if (mounted) _navigateToLogin();
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في تسجيل الخروج', isError: true);
      }
    }
  }

  void _navigateToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const WebLoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  void _navigateToContactSelection() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ContactSelectionScreen(user: _currentUser!),
      ),
    );
  }

  void _navigateToAgingReport() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WebSalesmanSelectionScreen(user: _currentUser!),
      ),
    );
  }

  void _navigateToAlmiraStockReport() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AlmiraStockReportScreen(),
      ),
    );
  }

  void _navigateToPeriodicSalesReport() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PeriodicSalesSelectionScreen(user: _currentUser!),
      ),
    );
  }

  void _navigateToPriceList() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PriceListScreen(user: _currentUser!),
      ),
    );
  }

  void _navigateToSalaryManagement() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SalaryManagementHubScreen(),
      ),
    );
  }

  void _navigateToCustomerOpening() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WebCustomerOpeningScreen(user: _currentUser!),
      ),
    );
  }

  void _navigateToQualityChecklists() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QualityChecklistsScreen(user: _currentUser!),
      ),
    );
  }

  void _navigateToFuelFilling() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FuelFillingFormScreen(),
      ),
    );
  }

  void _navigateToSalesReturns() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SalesReturnFormScreen(user: _currentUser!),
      ),
    );
  }
}

class _LightAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppUser currentUser;
  final VoidCallback onLogout;
  final VoidCallback onProfile;
  final bool isDesktop;

  const _LightAppBar({
    required this.currentUser,
    required this.onLogout,
    required this.onProfile,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(AppConstants.accentColor).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Image.asset(
                AppConstants.logoPath,
                width: 18,
                height: 18,
                fit: BoxFit.contain,
                cacheWidth: 36,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.account_balance,
                    size: 16,
                    color: Color(AppConstants.accentColor),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'لوحة التحكم',
              style: TextStyle(
                color: Color(AppConstants.primaryColor),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Username chip
          if (isDesktop)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor:
                        const Color(AppConstants.accentColor).withValues(alpha: 0.1),
                    child: Text(
                      currentUser.username.isNotEmpty
                          ? currentUser.username[0].toUpperCase()
                          : 'م',
                      style: const TextStyle(
                        color: Color(AppConstants.accentColor),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currentUser.username,
                    style: const TextStyle(
                      color: Color(AppConstants.primaryColor),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
          // Profile button
          Tooltip(
            message: 'الملف الشخصي',
            child: InkWell(
              onTap: onProfile,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(AppConstants.primaryColor).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: Color(AppConstants.primaryColor),
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Logout button
          Tooltip(
            message: 'تسجيل الخروج',
            child: InkWell(
              onTap: onLogout,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(AppConstants.accentColor).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.logout_outlined,
                  color: Color(AppConstants.accentColor),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}