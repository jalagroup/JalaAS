// lib/screens/web/salary/calculate_salary_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jala_as/models/user.dart';
import 'package:jala_as/models/salary_models.dart';
import 'package:jala_as/screens/web/salary/salary_calculation_detail_screen.dart';
import 'package:jala_as/screens/web/salary/set_targets_screen.dart';
import 'package:jala_as/services/salary_calculation_service.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/helpers.dart';

class CalculateSalaryScreen extends StatefulWidget {
  const CalculateSalaryScreen({super.key});

  @override
  State<CalculateSalaryScreen> createState() => _CalculateSalaryScreenState();
}

class _CalculateSalaryScreenState extends State<CalculateSalaryScreen> {
  AppUser? _currentUser;
  List<AppUser> _groupUsers = [];
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = await SupabaseService.getCurrentUser();
      if (_currentUser != null) {
        await _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في التحميل: $e', isError: true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUsers() async {
    if (_currentUser == null) return;

    try {
      final allUsers = await SupabaseService.getUsers();

      if (_currentUser!.isSalesManager) {
        setState(() {
          _groupUsers =
              allUsers.where((u) => u.isRegularUser || u.isSalesAdmin).toList();
        });
      } else if (_currentUser!.isSalesAdmin &&
          _currentUser!.salesAdmin != null) {
        final groupSalesmenCodes =
            await SupabaseService.getSalesmenInAdminGroup(
                _currentUser!.salesAdmin!);

        setState(() {
          _groupUsers = allUsers.where((u) {
            if (groupSalesmenCodes.contains(u.salesman)) return true;
            if (u.salesman == '00' && u.salesAdmin != null) {
              return groupSalesmenCodes.contains(u.salesAdmin);
            }
            return false;
          }).toList();
        });
      } else {
        setState(() {
          _groupUsers = [];
        });
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في تحميل المستخدمين', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: isMobile ? _buildMobileAppBar() : null,
        body: Column(
          children: [
            // Header - Desktop only
            if (!isMobile) _buildDesktopHeader(),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _groupUsers.isEmpty
                      ? _buildEmptyState(isMobile)
                      : _buildUsersList(isMobile, isTablet),
            ),
          ],
        ),
        // FAB for mobile month selector
        floatingActionButton: isMobile
            ? FloatingActionButton(
                onPressed: _selectMonth,
                backgroundColor: const Color(0xFF135467),
                child: const Icon(Icons.calendar_today, color: Colors.white),
              )
            : null,
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'حساب الرواتب',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          Text(
            Helpers.formatMonthYear(_selectedMonth),
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF546E7A),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.calendar_today, color: Color(0xFF135467)),
          onPressed: _selectMonth,
        ),
      ],
    );
  }

  Widget _buildDesktopHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back Button
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
            onPressed: () => Navigator.pop(context),
            tooltip: 'رجوع',
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF135467).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calculate,
              color: Color(0xFF135467),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حساب الرواتب',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'حساب رواتب المندوبين بناءً على الأهداف والمبيعات',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF546E7A),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _selectMonth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    Helpers.formatMonthYear(_selectedMonth),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isMobile) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: isMobile ? 48 : 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'لا يوجد مستخدمين',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersList(bool isMobile, bool isTablet) {
    // Determine grid columns based on screen size
    int crossAxisCount;
    double childAspectRatio;

    if (isMobile) {
      crossAxisCount = 2;
      childAspectRatio = 0.9;
    } else if (isTablet) {
      crossAxisCount = 2;
      childAspectRatio = 1.3;
    } else {
      crossAxisCount = 3;
      childAspectRatio = 1.5;
    }

    return GridView.builder(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: isMobile ? 12 : 16,
        mainAxisSpacing: isMobile ? 12 : 16,
      ),
      itemCount: _groupUsers.length,
      itemBuilder: (context, index) {
        final user = _groupUsers[index];
        return _buildUserCard(user, isMobile);
      },
    );
  }

  Widget _buildUserCard(AppUser user, bool isMobile) {
    return InkWell(
      onTap: () => _navigateToSalaryCalculation(user),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: isMobile ? 28 : 40,
              backgroundColor: const Color(0xFF135467).withOpacity(0.1),
              child: Text(
                user.username.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: isMobile ? 20 : 32,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF135467),
                ),
              ),
            ),
            SizedBox(height: isMobile ? 8 : 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                user.username,
                style: TextStyle(
                  fontSize: isMobile ? 14 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2C3E50),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: isMobile ? 2 : 4),
            Text(
              'مندوب: ${user.effectiveSalesman}',
              style: TextStyle(
                fontSize: isMobile ? 11 : 14,
                color: const Color(0xFF546E7A),
              ),
            ),
            if (user.area != null && !isMobile) ...[
              const SizedBox(height: 4),
              Text(
                'منطقة: ${user.area}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF546E7A),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _navigateToSalaryCalculation(AppUser user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SalaryCalculationDetailScreen(
          user: user,
          selectedMonth: _selectedMonth,
          currentUser: _currentUser!,
        ),
      ),
    );
  }

  Future<void> _selectMonth() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => MonthYearPickerDialog(initialDate: _selectedMonth),
    );

    if (picked != null) {
      setState(() => _selectedMonth = picked);
    }
  }
}
