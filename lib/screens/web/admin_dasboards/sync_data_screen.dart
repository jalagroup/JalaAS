// lib/screens/web/sync_data_screen.dart
import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/fuel_service.dart';
import '../../../services/auto_sync_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';

class SyncDataScreen extends StatefulWidget {
  const SyncDataScreen({super.key});

  @override
  State<SyncDataScreen> createState() => _SyncDataScreenState();
}

class _SyncDataScreenState extends State<SyncDataScreen> {
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  // Contacts
  int _totalContacts = 0;
  String _contactsSyncStatus = '';
  double _contactsSyncProgress = 0.0;

  // Items
  int _totalItems = 0;
  String _itemsSyncStatus = '';
  double _itemsSyncProgress = 0.0;

  // Warehouses
  int _totalWarehouses = 0;
  String _warehousesSyncStatus = '';
  double _warehousesSyncProgress = 0.0;

  // Fuel Contacts (NEW)
  int _totalFuelContacts = 0;
  String _fuelContactsSyncStatus = '';
  double _fuelContactsSyncProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final contacts = await SupabaseService.getContacts();
      final itemsCount = await SupabaseService.getTotalItemsCount();
      final warehousesCount = await SupabaseService.getTotalWarehousesCount();
      final fuelContacts = await FuelService.getFuelContacts(); // NEW

      setState(() {
        _totalContacts = contacts.length;
        _totalItems = itemsCount;
        _totalWarehouses = warehousesCount;
        _totalFuelContacts = fuelContacts.length; // NEW
      });
    } catch (e) {
      // Handle error silently
      print('Error loading counts: $e');
    }
  }

  Future<void> _syncContacts() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
      _contactsSyncStatus = 'جاري الاتصال بـ Bisan API...';
      _contactsSyncProgress = 0.1;
    });

    try {
      // Step 1: Fetch contacts from Bisan API
      setState(() {
        _contactsSyncStatus = 'جاري تحميل البيانات من Bisan API...';
        _contactsSyncProgress = 0.3;
      });

      final bisanContacts = await ApiService.getContacts();

      if (bisanContacts.isEmpty) {
        setState(() {
          _contactsSyncStatus = 'لم يتم العثور على بيانات في Bisan API';
          _isSyncing = false;
          _contactsSyncProgress = 0.0;
        });
        Helpers.showSnackBar(
          context,
          'لم يتم العثور على بيانات في Bisan API',
          isError: true,
        );
        return;
      }

      // Step 2: Sync to Supabase
      setState(() {
        _contactsSyncStatus =
            'جاري حفظ ${bisanContacts.length} جهة اتصال في قاعدة البيانات...';
        _contactsSyncProgress = 0.7;
      });

      await SupabaseService.syncContacts(bisanContacts);

      setState(() {
        _contactsSyncProgress = 1.0;
        _contactsSyncStatus =
            'تمت المزامنة بنجاح! تم حفظ ${bisanContacts.length} جهة اتصال.';
      });

      // Wait a moment to show completion
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _lastSyncTime = DateTime.now();
        _totalContacts = bisanContacts.length;
        _isSyncing = false;
        _contactsSyncProgress = 0.0;
      });

      Helpers.showSnackBar(
        context,
        'تمت مزامنة البيانات بنجاح! تم حفظ ${bisanContacts.length} جهة اتصال.',
      );
    } catch (e) {
      setState(() {
        _contactsSyncStatus = 'فشل في المزامنة: ${e.toString()}';
        _isSyncing = false;
        _contactsSyncProgress = 0.0;
      });

      Helpers.showSnackBar(
        context,
        'فشل في مزامنة البيانات: ${e.toString()}',
        isError: true,
      );
    }
  }

  Future<void> _syncItems() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
      _itemsSyncStatus = 'جاري الاتصال بـ Bisan API...';
      _itemsSyncProgress = 0.1;
    });

    try {
      // Step 1: Fetch items from Bisan API
      setState(() {
        _itemsSyncStatus = 'جاري تحميل الأصناف من Bisan API...';
        _itemsSyncProgress = 0.3;
      });

      final bisanItems = await ApiService.getItems();

      if (bisanItems.isEmpty) {
        setState(() {
          _itemsSyncStatus = 'لم يتم العثور على أصناف في Bisan API';
          _isSyncing = false;
          _itemsSyncProgress = 0.0;
        });
        Helpers.showSnackBar(
          context,
          'لم يتم العثور على أصناف في Bisan API',
          isError: true,
        );
        return;
      }

      // Step 2: Sync to Supabase
      setState(() {
        _itemsSyncStatus =
            'جاري مزامنة ${bisanItems.length} صنف في قاعدة البيانات...';
        _itemsSyncProgress = 0.7;
      });

      await SupabaseService.syncItems(bisanItems);

      setState(() {
        _itemsSyncProgress = 1.0;
        _itemsSyncStatus =
            'تمت المزامنة بنجاح! تم حفظ ${bisanItems.length} صنف.';
      });

      // Wait a moment to show completion
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _lastSyncTime = DateTime.now();
        _totalItems = bisanItems.length;
        _isSyncing = false;
        _itemsSyncProgress = 0.0;
      });

      Helpers.showSnackBar(
        context,
        'تمت مزامنة الأصناف بنجاح! تم حفظ ${bisanItems.length} صنف.',
      );
    } catch (e) {
      setState(() {
        _itemsSyncStatus = 'فشل في المزامنة: ${e.toString()}';
        _isSyncing = false;
        _itemsSyncProgress = 0.0;
      });

      Helpers.showSnackBar(
        context,
        'فشل في مزامنة الأصناف: ${e.toString()}',
        isError: true,
      );
    }
  }

  Future<void> _syncWarehouses() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
      _warehousesSyncStatus = 'جاري الاتصال بـ Bisan API...';
      _warehousesSyncProgress = 0.1;
    });

    try {
      // Step 1: Fetch warehouses from Bisan API
      setState(() {
        _warehousesSyncStatus = 'جاري تحميل المخازن من Bisan API...';
        _warehousesSyncProgress = 0.3;
      });

      final bisanWarehouses = await ApiService.getWarehouses();

      if (bisanWarehouses.isEmpty) {
        setState(() {
          _warehousesSyncStatus = 'لم يتم العثور على مخازن في Bisan API';
          _isSyncing = false;
          _warehousesSyncProgress = 0.0;
        });
        Helpers.showSnackBar(
          context,
          'لم يتم العثور على مخازن في Bisan API',
          isError: true,
        );
        return;
      }

      // Step 2: Sync to Supabase
      setState(() {
        _warehousesSyncStatus =
            'جاري مزامنة ${bisanWarehouses.length} مخزن في قاعدة البيانات...';
        _warehousesSyncProgress = 0.7;
      });

      await SupabaseService.syncWarehouses(bisanWarehouses);

      setState(() {
        _warehousesSyncProgress = 1.0;
        _warehousesSyncStatus =
            'تمت المزامنة بنجاح! تم حفظ ${bisanWarehouses.length} مخزن.';
      });

      // Wait a moment to show completion
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _lastSyncTime = DateTime.now();
        _totalWarehouses = bisanWarehouses.length;
        _isSyncing = false;
        _warehousesSyncProgress = 0.0;
      });

      Helpers.showSnackBar(
        context,
        'تمت مزامنة المخازن بنجاح! تم حفظ ${bisanWarehouses.length} مخزن.',
      );
    } catch (e) {
      setState(() {
        _warehousesSyncStatus = 'فشل في المزامنة: ${e.toString()}';
        _isSyncing = false;
        _warehousesSyncProgress = 0.0;
      });

      Helpers.showSnackBar(
        context,
        'فشل في مزامنة المخازن: ${e.toString()}',
        isError: true,
      );
    }
  }

  // NEW: Sync Fuel Contacts
  Future<void> _syncFuelContacts() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
      _fuelContactsSyncStatus = 'جاري الاتصال بـ Bisan API...';
      _fuelContactsSyncProgress = 0.1;
    });

    try {
      // Step 1: Fetch fuel contacts from Bisan API
      setState(() {
        _fuelContactsSyncStatus = 'جاري تحميل محطات المحروقات من Bisan API...';
        _fuelContactsSyncProgress = 0.3;
      });

      final bisanFuelContacts = await ApiService.getFuelContactsFromBisan();

      if (bisanFuelContacts.isEmpty) {
        setState(() {
          _fuelContactsSyncStatus =
              'لم يتم العثور على محطات محروقات في Bisan API';
          _isSyncing = false;
          _fuelContactsSyncProgress = 0.0;
        });
        Helpers.showSnackBar(
          context,
          'لم يتم العثور على محطات محروقات في Bisan API',
          isError: true,
        );
        return;
      }

      // Step 2: Sync to Supabase
      setState(() {
        _fuelContactsSyncStatus =
            'جاري مزامنة ${bisanFuelContacts.length} محطة محروقات في قاعدة البيانات...';
        _fuelContactsSyncProgress = 0.7;
      });

      await FuelService.syncFuelContacts();

      setState(() {
        _fuelContactsSyncProgress = 1.0;
        _fuelContactsSyncStatus =
            'تمت المزامنة بنجاح! تم حفظ ${bisanFuelContacts.length} محطة محروقات.';
      });

      // Wait a moment to show completion
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _lastSyncTime = DateTime.now();
        _totalFuelContacts = bisanFuelContacts.length;
        _isSyncing = false;
        _fuelContactsSyncProgress = 0.0;
      });

      Helpers.showSnackBar(
        context,
        'تمت مزامنة محطات المحروقات بنجاح! تم حفظ ${bisanFuelContacts.length} محطة.',
      );
    } catch (e) {
      setState(() {
        _fuelContactsSyncStatus = 'فشل في المزامنة: ${e.toString()}';
        _isSyncing = false;
        _fuelContactsSyncProgress = 0.0;
      });

      Helpers.showSnackBar(
        context,
        'فشل في مزامنة محطات المحروقات: ${e.toString()}',
        isError: true,
      );
    }
  }

  Future<void> _syncAll() async {
    if (_isSyncing) return;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد المزامنة الشاملة'),
          content: const Text(
            'هل تريد مزامنة جميع البيانات؟\n\n'
            'سيتم مزامنة:\n'
            '• جهات الاتصال\n'
            '• الأصناف\n'
            '• المخازن\n'
            '• محطات المحروقات\n\n'
            'قد تستغرق هذه العملية عدة دقائق.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF135467),
              ),
              child: const Text('متابعة'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    // Sync all data sequentially
    await _syncContacts();
    if (!_isSyncing) await _syncItems();
    if (!_isSyncing) await _syncWarehouses();
    if (!_isSyncing) await _syncFuelContacts(); // NEW

    if (mounted) {
      Helpers.showSnackBar(
        context,
        'تمت المزامنة الشاملة بنجاح!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return SingleChildScrollView(
          child: Container(
            color: const Color(0xFFF8F9FA),
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildAutoSyncCard(),
                    const SizedBox(height: 16),
                    if (isMobile) ...[
                      _buildMobileStats(),
                      const SizedBox(height: 12),
                      _buildSyncAllButton(),
                      const SizedBox(height: 12),
                      _buildContactsSyncCard(),
                      const SizedBox(height: 12),
                      _buildItemsSyncCard(),
                      const SizedBox(height: 12),
                      _buildWarehousesSyncCard(),
                      const SizedBox(height: 12),
                      _buildFuelContactsSyncCard(), // NEW
                      const SizedBox(height: 12),
                      Flexible(
                        child: _buildWarningCard(),
                      ),
                    ] else ...[
                      _buildDesktopStats(),
                      const SizedBox(height: 20),
                      _buildSyncAllButton(),
                      const SizedBox(height: 20),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  _buildContactsSyncCard(),
                                  const SizedBox(height: 20),
                                  _buildItemsSyncCard(),
                                  const SizedBox(height: 20),
                                  _buildWarehousesSyncCard(),
                                  const SizedBox(height: 20),
                                  _buildFuelContactsSyncCard(), // NEW
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _buildWarningCard(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          textDirection: TextDirection.rtl,
          children: [
            const Text(
              'مزامنة البيانات',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF135467).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.sync,
                color: Color(0xFF135467),
                size: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'مزامنة بيانات العملاء والأصناف والمخازن ومحطات المحروقات من Bisan API',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF546E7A),
          ),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }

  Widget _buildMobileStats() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          _buildStatCard(
            title: 'إجمالي العملاء',
            value: _totalContacts.toString(),
            icon: Icons.people_outline,
            color: const Color(0xFF135467),
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            title: 'إجمالي الأصناف',
            value: _totalItems.toString(),
            icon: Icons.inventory_2_outlined,
            color: const Color(0xFF9C27B0),
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            title: 'إجمالي المخازن',
            value: _totalWarehouses.toString(),
            icon: Icons.warehouse_outlined,
            color: const Color(0xFFFF9800),
          ),
          const SizedBox(height: 12),
          // NEW: Fuel Contacts stat
          _buildStatCard(
            title: 'محطات المحروقات',
            value: _totalFuelContacts.toString(),
            icon: Icons.local_gas_station_outlined,
            color: const Color(0xFFE91E63),
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            title: 'آخر مزامنة',
            value: _lastSyncTime != null
                ? Helpers.formatDisplayDate(_lastSyncTime!)
                : 'لم تتم المزامنة بعد',
            icon: Icons.access_time,
            color: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopStats() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'إجمالي العملاء',
                  value: _totalContacts.toString(),
                  icon: Icons.people_outline,
                  color: const Color(0xFF135467),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'إجمالي الأصناف',
                  value: _totalItems.toString(),
                  icon: Icons.inventory_2_outlined,
                  color: const Color(0xFF9C27B0),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'إجمالي المخازن',
                  value: _totalWarehouses.toString(),
                  icon: Icons.warehouse_outlined,
                  color: const Color(0xFFFF9800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'محطات المحروقات',
                  value: _totalFuelContacts.toString(),
                  icon: Icons.local_gas_station_outlined,
                  color: const Color(0xFFE91E63),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'آخر مزامنة',
                  value: _lastSyncTime != null
                      ? Helpers.formatDisplayDate(_lastSyncTime!)
                      : 'لم تتم المزامنة بعد',
                  icon: Icons.access_time,
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(child: SizedBox()), // Empty space
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF135467).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF546E7A),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C3E50),
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncAllButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSyncing ? null : _syncAll,
        icon: const Icon(
          Icons.sync_outlined,
          size: 20,
          color: Colors.white,
        ),
        label: const Text('مزامنة شاملة لجميع البيانات'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildContactsSyncCard() {
    return _buildSyncCard(
      title: 'مزامنة العملاء',
      description:
          'مزامنة بيانات جهات الاتصال من Bisan API. سيتم تحديث البيانات الموجودة وإضافة جهات اتصال جديدة.',
      icon: Icons.people_outline,
      color: const Color(0xFF135467),
      isSyncing: _isSyncing && _contactsSyncProgress > 0,
      syncStatus: _contactsSyncStatus,
      syncProgress: _contactsSyncProgress,
      onSync: _syncContacts,
    );
  }

  Widget _buildItemsSyncCard() {
    return _buildSyncCard(
      title: 'مزامنة الأصناف',
      description:
          'مزامنة أصناف المنتجات من Bisan API. سيتم تحديث البيانات الموجودة وإضافة أصناف جديدة.',
      icon: Icons.inventory_2_outlined,
      color: const Color(0xFF9C27B0),
      isSyncing: _isSyncing && _itemsSyncProgress > 0,
      syncStatus: _itemsSyncStatus,
      syncProgress: _itemsSyncProgress,
      onSync: _syncItems,
    );
  }

  Widget _buildWarehousesSyncCard() {
    return _buildSyncCard(
      title: 'مزامنة المخازن',
      description:
          'مزامنة بيانات المخازن من Bisan API. سيتم تحديث البيانات الموجودة وإضافة مخازن جديدة.',
      icon: Icons.warehouse_outlined,
      color: const Color(0xFFFF9800),
      isSyncing: _isSyncing && _warehousesSyncProgress > 0,
      syncStatus: _warehousesSyncStatus,
      syncProgress: _warehousesSyncProgress,
      onSync: _syncWarehouses,
    );
  }

  // NEW: Fuel Contacts Sync Card
  Widget _buildFuelContactsSyncCard() {
    return _buildSyncCard(
      title: 'مزامنة محطات المحروقات',
      description:
          'مزامنة بيانات محطات المحروقات من Bisan API. سيتم تحديث البيانات الموجودة وإضافة محطات جديدة.',
      icon: Icons.local_gas_station_outlined,
      color: const Color(0xFFE91E63),
      isSyncing: _isSyncing && _fuelContactsSyncProgress > 0,
      syncStatus: _fuelContactsSyncStatus,
      syncProgress: _fuelContactsSyncProgress,
      onSync: _syncFuelContacts,
    );
  }

  Widget _buildSyncCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isSyncing,
    required String syncStatus,
    required double syncProgress,
    required VoidCallback onSync,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF135467).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF546E7A),
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 24),
          if (isSyncing) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Expanded(
                        child: Text(
                          syncStatus,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: color,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                          value: syncProgress,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: syncProgress,
                    backgroundColor: const Color(0xFFE1E5E9),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 4,
                  ),
                ],
              ),
            ),
          ] else ...[
            if (syncStatus.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: syncStatus.contains('فشل')
                      ? Colors.red.withOpacity(0.05)
                      : const Color(0xFF10B981).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: syncStatus.contains('فشل')
                        ? Colors.red.withOpacity(0.2)
                        : const Color(0xFF10B981).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Expanded(
                      child: Text(
                        syncStatus,
                        style: TextStyle(
                          color: syncStatus.contains('فشل')
                              ? Colors.red
                              : const Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: syncStatus.contains('فشل')
                            ? Colors.red.withOpacity(0.1)
                            : const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        syncStatus.contains('فشل')
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        color: syncStatus.contains('فشل')
                            ? Colors.red
                            : const Color(0xFF10B981),
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSyncing ? null : onSync,
                icon: Icon(
                  Icons.sync,
                  size: 18,
                  color: _isSyncing ? Colors.grey : Colors.white,
                ),
                label: const Text('بدء المزامنة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAutoSyncCard() {
    return ListenableBuilder(
      listenable: AutoSyncService.instance,
      builder: (context, _) {
        final svc = AutoSyncService.instance;
        final now = DateTime.now();

        String lastSyncText;
        if (svc.lastSyncTime == null) {
          lastSyncText = 'لم تتم بعد';
        } else {
          final diff = now.difference(svc.lastSyncTime!);
          if (diff.inMinutes < 1) {
            lastSyncText = 'الآن';
          } else if (diff.inHours < 1) {
            lastSyncText = 'منذ ${diff.inMinutes} دقيقة';
          } else {
            lastSyncText = 'منذ ${diff.inHours} ساعة';
          }
        }

        String nextSyncText;
        if (!svc.enabled) {
          nextSyncText = 'معطّلة';
        } else if (svc.isSyncing) {
          nextSyncText = 'جارٍ الآن...';
        } else if (svc.nextSyncTime == null) {
          nextSyncText = 'بعد 30 ثانية (أول تشغيل)';
        } else {
          final remaining = svc.nextSyncTime!.difference(now);
          if (remaining.isNegative || remaining.inSeconds < 60) {
            nextSyncText = 'قريباً';
          } else if (remaining.inMinutes < 60) {
            nextSyncText = 'في ${remaining.inMinutes} دقيقة';
          } else {
            final h = remaining.inHours;
            final m = remaining.inMinutes % 60;
            nextSyncText = m > 0 ? 'في ${h}س ${m}د' : 'في $h ساعة';
          }
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: svc.enabled
                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                  : const Color(0xFFE1E5E9),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF135467).withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.schedule_outlined,
                        color: Color(0xFF10B981), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'المزامنة التلقائية كل 3 ساعات',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ),
                  Switch(
                    value: svc.enabled,
                    onChanged: (v) => AutoSyncService.instance.setEnabled(v),
                    activeThumbColor: const Color(0xFF10B981),
                    activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                  ),
                ],
              ),
              if (svc.isSyncing) ...[
                const SizedBox(height: 12),
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF10B981)),
                    ),
                    const SizedBox(width: 8),
                    Text(svc.syncStatus,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF10B981))),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(
                    child: _buildAutoSyncStat(
                      label: 'آخر مزامنة تلقائية',
                      value: lastSyncText,
                      icon: Icons.history,
                      color: const Color(0xFF135467),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAutoSyncStat(
                      label: 'المزامنة القادمة',
                      value: nextSyncText,
                      icon: Icons.timer_outlined,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAutoSyncStat({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: color.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500)),
                Text(value,
                    style: TextStyle(
                        fontSize: 13,
                        color: color,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF16936).withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF16936).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              const Text(
                'ملاحظات مهمة',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF16936),
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF16936).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Color(0xFFF16936),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildWarningPoint(
            '• المزامنة لا تحذف البيانات الموجودة',
            'سيتم تحديث السجلات الموجودة وإضافة سجلات جديدة فقط',
          ),
          const SizedBox(height: 12),
          _buildWarningPoint(
            '• المزامنة قد تستغرق عدة دقائق',
            'حسب كمية البيانات المراد مزامنتها',
          ),
          const SizedBox(height: 12),
          _buildWarningPoint(
            '• يمكن إيقاف المزامنة',
            'يمكنك الانتقال لصفحة أخرى أثناء المزامنة',
          ),
          const SizedBox(height: 12),
          _buildWarningPoint(
            '• تحديثات تلقائية',
            'استخدم المزامنة الشاملة للتحديث الدوري لجميع البيانات',
          ),
        ],
      ),
    );
  }

  Widget _buildWarningPoint(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF2C3E50),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(
            color: Color(0xFF546E7A),
            fontSize: 13,
            height: 1.5,
          ),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }
}
