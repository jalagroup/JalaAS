// lib/screens/web/sync_data_screen.dart
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

class SyncDataScreen extends StatefulWidget {
  const SyncDataScreen({super.key});

  @override
  State<SyncDataScreen> createState() => _SyncDataScreenState();
}

class _SyncDataScreenState extends State<SyncDataScreen> {
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  int _totalContacts = 0;
  String _syncStatus = '';
  double _syncProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadContactsCount();
  }

  Future<void> _loadContactsCount() async {
    try {
      final contacts = await SupabaseService.getContacts();
      setState(() {
        _totalContacts = contacts.length;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _syncContacts() async {
    setState(() {
      _isSyncing = true;
      _syncStatus = 'جاري الاتصال بـ Bisan API...';
      _syncProgress = 0.1;
    });

    try {
      // Step 1: Fetch contacts from Bisan API
      setState(() {
        _syncStatus = 'جاري تحميل البيانات من Bisan API...';
        _syncProgress = 0.3;
      });

      final bisanContacts = await ApiService.getContacts();

      if (bisanContacts.isEmpty) {
        setState(() {
          _syncStatus = 'لم يتم العثور على بيانات في Bisan API';
          _isSyncing = false;
          _syncProgress = 0.0;
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
        _syncStatus =
            'جاري حفظ ${bisanContacts.length} جهة اتصال في قاعدة البيانات...';
        _syncProgress = 0.7;
      });

      await SupabaseService.syncContacts(bisanContacts);

      setState(() {
        _syncProgress = 1.0;
        _syncStatus =
            'تمت المزامنة بنجاح! تم حفظ ${bisanContacts.length} جهة اتصال.';
      });

      // Wait a moment to show completion
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _lastSyncTime = DateTime.now();
        _totalContacts = bisanContacts.length;
        _isSyncing = false;
        _syncProgress = 0.0;
      });

      Helpers.showSnackBar(
        context,
        'تمت مزامنة البيانات بنجاح! تم حفظ ${bisanContacts.length} جهة اتصال.',
      );
    } catch (e) {
      setState(() {
        _syncStatus = 'فشل في المزامنة: ${e.toString()}';
        _isSyncing = false;
        _syncProgress = 0.0;
      });

      Helpers.showSnackBar(
        context,
        'فشل في مزامنة البيانات: ${e.toString()}',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return SingleChildScrollView(
          // Add this wrapper
          child: Container(
            color: const Color(0xFFF8F9FA),
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: ConstrainedBox(
              // Add this constraint
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                // Add this to handle intrinsic heights
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    if (isMobile) ...[
                      _buildMobileStats(),
                      const SizedBox(height: 12),
                      _buildSyncCard(),
                      const SizedBox(height: 12),
                      Flexible(
                        // Make warning card flexible
                        child: _buildWarningCard(),
                      ),
                    ] else ...[
                      _buildDesktopStats(),
                      const SizedBox(height: 20),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildSyncCard(),
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
      crossAxisAlignment: CrossAxisAlignment.start, // Changed to end for RTL
      children: [
        Row(
          textDirection: TextDirection.rtl, // RTL for header row
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
          'مزامنة بيانات العملاء من Bisan API',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF546E7A),
          ),
          textAlign: TextAlign.left, // Align text to right
        ),
      ],
    );
  }

  Widget _buildMobileStats() {
    return Directionality(
      textDirection: TextDirection.ltr, // Add this
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
      textDirection: TextDirection.ltr, // Add this
      child: Row(
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
              title: 'آخر مزامنة',
              value: _lastSyncTime != null
                  ? Helpers.formatDisplayDate(_lastSyncTime!)
                  : 'لم تتم المزامنة بعد',
              icon: Icons.access_time,
              color: const Color(0xFF10B981),
            ),
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
        textDirection: TextDirection.rtl, // RTL for stat card content
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end, // Changed to end for RTL
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF546E7A),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right, // Align text to right
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C3E50),
                  ),
                  textAlign: TextAlign.right, // Align text to right
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

  Widget _buildSyncCard() {
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
        crossAxisAlignment: CrossAxisAlignment.start, // Changed to end for RTL
        children: [
          Row(
            textDirection: TextDirection.rtl, // RTL for sync card header
            children: [
              const Text(
                'مزامنة البيانات',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
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
          const SizedBox(height: 16),
          const Text(
            'اضغط على الزر أدناه لمزامنة بيانات العملاء من Bisan API. سيتم حذف جميع البيانات الحالية واستبدالها بالبيانات الجديدة.',
            style: TextStyle(
              color: Color(0xFF546E7A),
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.left, // Align text to right
          ),
          const SizedBox(height: 24),
          if (_isSyncing) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF135467).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end, // Changed to end for RTL
                children: [
                  Row(
                    textDirection:
                        TextDirection.rtl, // RTL for sync progress row
                    children: [
                      Expanded(
                        child: Text(
                          _syncStatus,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF135467),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.right, // Align text to right
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: const Color(0xFF135467),
                          value: _syncProgress,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _syncProgress,
                    backgroundColor: const Color(0xFFE1E5E9),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF135467),
                    ),
                    minHeight: 4,
                  ),
                ],
              ),
            ),
          ] else ...[
            if (_syncStatus.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _syncStatus.contains('فشل')
                      ? Colors.red.withOpacity(0.05)
                      : const Color(0xFF10B981).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _syncStatus.contains('فشل')
                        ? Colors.red.withOpacity(0.2)
                        : const Color(0xFF10B981).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  textDirection: TextDirection.rtl, // RTL for status row
                  children: [
                    Expanded(
                      child: Text(
                        _syncStatus,
                        style: TextStyle(
                          color: _syncStatus.contains('فشل')
                              ? Colors.red
                              : const Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.right, // Align text to right
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _syncStatus.contains('فشل')
                            ? Colors.red.withOpacity(0.1)
                            : const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        _syncStatus.contains('فشل')
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        color: _syncStatus.contains('فشل')
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
                onPressed: _syncContacts,
                icon: const Icon(
                  Icons.sync,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text('بدء المزامنة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF135467),
                  foregroundColor: Colors.white,
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
        crossAxisAlignment: CrossAxisAlignment.end, // Changed to end for RTL
        children: [
          Row(
            textDirection: TextDirection.rtl, // RTL for warning header
            children: [
              const Text(
                'تحذير مهم',
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
                  Icons.warning_outlined,
                  color: Color(0xFFF16936),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'ستؤدي عملية المزامنة إلى حذف جميع بيانات العملاء الحالية واستبدالها بالبيانات الجديدة من Bisan API.',
            style: TextStyle(
              color: Color(0xFF2C3E50),
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.right, // Align text to right
          ),
          const SizedBox(height: 12),
          const Text(
            'تأكد من عمل نسخة احتياطية من البيانات المهمة قبل البدء.',
            style: TextStyle(
              color: Color(0xFF546E7A),
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.right, // Align text to right
          ),
        ],
      ),
    );
  }
}
