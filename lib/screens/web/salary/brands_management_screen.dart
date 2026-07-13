// lib/screens/web/salary/brands_management_screen.dart

import 'package:flutter/material.dart';
import 'package:jala_as/models/salary_models.dart';
import 'package:jala_as/services/api_service.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/helpers.dart';
import 'package:jala_as/utils/constants.dart';

class BrandsManagementScreen extends StatefulWidget {
  const BrandsManagementScreen({super.key});

  @override
  State<BrandsManagementScreen> createState() => _BrandsManagementScreenState();
}

class _BrandsManagementScreenState extends State<BrandsManagementScreen> {
  List<Brand> _brands = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBrands();
  }

  Future<void> _loadBrands() async {
    setState(() => _isLoading = true);
    try {
      final brands = await SupabaseService.getBrands();
      setState(() {
        _brands = brands;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في تحميل العلامات التجارية',
            isError: true);
      }
    }
  }

  Future<void> _syncBrandsFromBisan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مزامنة العلامات التجارية'),
        content: const Text('هل تريد مزامنة العلامات التجارية من نظام بيسان؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('مزامنة'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSyncing = true);
    try {
      final bisanBrands = await ApiService.getBrandsFromBisan();
      await SupabaseService.syncBrands(bisanBrands);
      await _loadBrands();

      if (mounted) {
        Helpers.showSnackBar(
          context,
          'تم مزامنة ${bisanBrands.length} علامة تجارية بنجاح',
        );
      }
    } catch (e) {
      if (mounted) {
        Helpers.showApiErrorDialog(context, e);
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _toggleBrandStatus(Brand brand) async {
    try {
      await SupabaseService.updateBrandStatus(brand.id, !brand.isActive);
      await _loadBrands();
      if (mounted) {
        Helpers.showSnackBar(
          context,
          brand.isActive
              ? 'تم إلغاء تفعيل العلامة التجارية'
              : 'تم تفعيل العلامة التجارية',
        );
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في تحديث الحالة', isError: true);
      }
    }
  }

  Future<void> _deleteBrand(Brand brand) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف العلامة التجارية'),
        content: Text('هل تريد حذف ${brand.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SupabaseService.deleteBrand(brand.id);
      await _loadBrands();
      if (mounted) {
        Helpers.showSnackBar(context, 'تم حذف العلامة التجارية');
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في الحذف: $e', isError: true);
      }
    }
  }

  List<Brand> get _filteredBrands {
    if (_searchQuery.isEmpty) return _brands;
    return _brands.where((brand) {
      return brand.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          brand.code.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: isMobile ? _buildMobileAppBar() : null,
        body: Column(
          children: [
            // Header - Desktop only
            if (!isMobile) _buildDesktopHeader(),

            // Search Bar
            Padding(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'البحث عن علامة تجارية...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF135467)),
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),

            // Brands List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredBrands.isEmpty
                      ? _buildEmptyState(isMobile)
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 16 : 24,
                          ),
                          itemCount: _filteredBrands.length,
                          itemBuilder: (context, index) {
                            final brand = _filteredBrands[index];
                            return _buildBrandCard(brand, isMobile);
                          },
                        ),
            ),
          ],
        ),
        // FAB for mobile sync
        floatingActionButton: isMobile
            ? FloatingActionButton.extended(
                onPressed: _isSyncing ? null : _syncBrandsFromBisan,
                backgroundColor: const Color(0xFF135467),
                icon: _isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync, color: Colors.white),
                label: Text(
                  _isSyncing ? 'جاري المزامنة...' : 'مزامنة من بيسان',
                  style: const TextStyle(color: Colors.white),
                ),
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
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إدارة العلامات التجارية',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          Text(
            'إدارة العلامات التجارية للأهداف والرواتب',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF546E7A),
            ),
          ),
        ],
      ),
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
              Icons.category,
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
                  'إدارة العلامات التجارية',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'إدارة العلامات التجارية للأهداف والرواتب',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF546E7A),
                  ),
                ),
              ],
            ),
          ),
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _syncBrandsFromBisan,
              icon: const Icon(Icons.sync, size: 20),
              label: const Text('مزامنة من بيسان'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF135467),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
              Icons.category_outlined,
              size: isMobile ? 48 : 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'لا توجد علامات تجارية' : 'لا توجد نتائج',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                color: Colors.grey.shade600,
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'قم بالمزامنة من بيسان لإضافة العلامات التجارية',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBrandCard(Brand brand, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: brand.isActive ? Colors.grey.shade200 : Colors.red.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isMobile
          ? _buildMobileBrandCard(brand)
          : _buildDesktopBrandCard(brand),
    );
  }

  Widget _buildMobileBrandCard(Brand brand) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: brand.isActive
                      ? const Color(0xFF135467).withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    brand.code,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color:
                          brand.isActive ? const Color(0xFF135467) : Colors.red,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brand.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: brand.isActive
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        brand.isActive ? 'نشط' : 'غير نشط',
                        style: TextStyle(
                          fontSize: 11,
                          color: brand.isActive ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _toggleBrandStatus(brand),
                icon: Icon(
                  brand.isActive ? Icons.cancel : Icons.check_circle,
                  size: 18,
                  color: brand.isActive ? Colors.orange : Colors.green,
                ),
                label: Text(
                  brand.isActive ? 'إلغاء التفعيل' : 'تفعيل',
                  style: TextStyle(
                    fontSize: 12,
                    color: brand.isActive ? Colors.orange : Colors.green,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _deleteBrand(brand),
                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                label: const Text(
                  'حذف',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopBrandCard(Brand brand) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: brand.isActive
              ? const Color(0xFF135467).withOpacity(0.1)
              : Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            brand.code,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: brand.isActive ? const Color(0xFF135467) : Colors.red,
            ),
          ),
        ),
      ),
      title: Text(
        brand.name,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2C3E50),
        ),
      ),
      subtitle: Text(
        brand.isActive ? 'نشط' : 'غير نشط',
        style: TextStyle(
          fontSize: 14,
          color: brand.isActive ? Colors.green : Colors.red,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              brand.isActive ? Icons.check_circle : Icons.cancel,
              color: brand.isActive ? Colors.green : Colors.red,
            ),
            tooltip: brand.isActive ? 'إلغاء التفعيل' : 'تفعيل',
            onPressed: () => _toggleBrandStatus(brand),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'حذف',
            onPressed: () => _deleteBrand(brand),
          ),
        ],
      ),
    );
  }
}
