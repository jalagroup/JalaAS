// lib/screens/web/salary/set_targets_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:jala_as/models/user.dart';
import 'package:jala_as/models/salary_models.dart';
import 'package:jala_as/services/excel_import_service.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/helpers.dart';

class SetTargetsScreen extends StatefulWidget {
  const SetTargetsScreen({super.key});

  @override
  State<SetTargetsScreen> createState() => _SetTargetsScreenState();
}

class _SetTargetsScreenState extends State<SetTargetsScreen> {
  AppUser? _currentUser;
  List<AppUser> _groupUsers = [];
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = false;
  bool _isUploadingExcel = false;

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

  Future<void> _uploadExcel() async {
    if (_currentUser == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploadingExcel = true);

      final bytes = result.files.first.bytes;
      if (bytes == null) {
        throw Exception('فشل في قراءة الملف');
      }

      final excelData = await ExcelImportService.parseExcelFile(bytes);

      final confirmed = await _showUploadConfirmationDialog(excelData);
      if (!confirmed) {
        setState(() => _isUploadingExcel = false);
        return;
      }

      final allUsers = await SupabaseService.getUsers();

      int targetsProcessed = 0;
      int salariesProcessed = 0;
      int groupsProcessed = 0;

      try {
        targetsProcessed = await _processTargets(excelData.targets, allUsers);
        salariesProcessed =
            await _processSalaries(excelData.salaries, allUsers);
        groupsProcessed = await _processGroups(excelData.groups);

        await _loadUsers();

        if (mounted) {
          Helpers.showSnackBar(
            context,
            'تم رفع البيانات بنجاح ✓\n\n'
            '📊 الأهداف المعالجة: $targetsProcessed\n'
            '💰 الرواتب المحدثة: $salariesProcessed\n'
            '👥 المجموعات المضافة: $groupsProcessed',
          );
        }
      } catch (e) {
        if (mounted) {
          Helpers.showSnackBar(
            context,
            'حدث خطأ أثناء معالجة البيانات:\n$e',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'فشل في رفع الملف: $e',
          isError: true,
        );
      }
    } finally {
      setState(() => _isUploadingExcel = false);
    }
  }

  Future<bool> _showUploadConfirmationDialog(ExcelUploadData excelData) async {
    final Map<String, int> targetsBySalesman = {};
    for (final target in excelData.targets) {
      targetsBySalesman[target.salesmanCode] =
          (targetsBySalesman[target.salesmanCode] ?? 0) + 1;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.upload_file, color: Color(0xFF135467)),
              SizedBox(width: 12),
              Text('تأكيد رفع البيانات'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'سيتم معالجة البيانات التالية من الملف:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),

                // Targets Summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.flag,
                              color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'الأهداف (${excelData.targets.length})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...targetsBySalesman.entries.map((entry) => Padding(
                            padding: const EdgeInsets.only(right: 28, top: 4),
                            child: Text(
                                '• مندوب ${entry.key}: ${entry.value} هدف'),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Salaries Summary
                if (excelData.salaries.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.attach_money,
                                color: Colors.green.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'الرواتب الأساسية (${excelData.salaries.length})',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...excelData.salaries.map((salary) => Padding(
                              padding: const EdgeInsets.only(right: 28, top: 4),
                              child: Text(
                                  '• مندوب ${salary.salesmanCode}: ${Helpers.formatCurrency(salary.salary)}'),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Groups Summary
                if (excelData.groups.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.group,
                                color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'المجموعات (${excelData.groups.length})',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'سيتم إضافة/تحديث علاقات المجموعات',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade900),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'ملاحظة: سيتم استبدال الأهداف الموجودة للشهر المحدد',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
                foregroundColor: Colors.white,
              ),
              child: const Text('تأكيد الرفع'),
            ),
          ],
        ),
      ),
    );

    return result ?? false;
  }

  Future<int> _processTargets(
      List<TargetData> targets, List<AppUser> allUsers) async {
    if (targets.isEmpty) return 0;

    final Map<String, List<TargetData>> targetsBySalesman = {};
    for (final target in targets) {
      if (!targetsBySalesman.containsKey(target.salesmanCode)) {
        targetsBySalesman[target.salesmanCode] = [];
      }
      targetsBySalesman[target.salesmanCode]!.add(target);
    }

    int processedCount = 0;

    for (final entry in targetsBySalesman.entries) {
      final salesmanCode = entry.key;
      final salesmanTargets = entry.value;

      try {
        final user = allUsers.firstWhere(
          (u) {
            if (u.salesman == salesmanCode) return true;
            if (u.salesman == '00' && u.salesAdmin == salesmanCode) return true;
            return false;
          },
          orElse: () {
            print(
                'WARNING: User with salesman code $salesmanCode not found, skipping...');
            return AppUser(
              id: '',
              username: '',
              salesman: '',
              email: '',
              userType: '',
              isActive: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          },
        );

        if (user.id.isEmpty) continue;

        await SupabaseService.bulkSaveOrUpdateTargets(
          userId: user.id,
          targetMonth: DateTime(_selectedMonth.year, _selectedMonth.month, 1),
          targetData: salesmanTargets,
          createdBy: _currentUser!.id,
        );

        processedCount += salesmanTargets.length;
        print(
            'DEBUG: Processed ${salesmanTargets.length} targets for salesman $salesmanCode (${user.username})');
      } catch (e) {
        print(
            'ERROR: Failed to process targets for salesman $salesmanCode: $e');
      }
    }

    return processedCount;
  }

  Future<int> _processSalaries(
      List<SalaryData> salaries, List<AppUser> allUsers) async {
    if (salaries.isEmpty) return 0;

    int processedCount = 0;

    for (final salaryData in salaries) {
      try {
        final user = allUsers.firstWhere(
          (u) {
            if (u.salesman == '00') return false;
            return u.salesman == salaryData.salesmanCode;
          },
          orElse: () {
            print(
                'WARNING: User with salesman code ${salaryData.salesmanCode} not found or is sales admin, skipping...');
            return AppUser(
              id: '',
              username: '',
              salesman: '',
              email: '',
              userType: '',
              isActive: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          },
        );

        if (user.id.isEmpty) continue;

        await SupabaseService.updateUserSalary(user.id, salaryData.salary);
        processedCount++;
        print(
            'DEBUG: Updated salary for salesman ${salaryData.salesmanCode} (${user.username}) to ${salaryData.salary}');
      } catch (e) {
        print(
            'ERROR: Failed to update salary for salesman ${salaryData.salesmanCode}: $e');
      }
    }

    return processedCount;
  }

  Future<int> _processGroups(List<GroupData> groups) async {
    if (groups.isEmpty) return 0;

    try {
      await SupabaseService.saveSalesAdminGroups(groups);
      print('DEBUG: Processed ${groups.length} group relationships');
      return groups.length;
    } catch (e) {
      print('ERROR: Failed to process groups: $e');
      return 0;
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
        // FABs for mobile
        floatingActionButton: isMobile
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    heroTag: 'calendar',
                    onPressed: _selectMonth,
                    backgroundColor: Colors.grey.shade600,
                    mini: true,
                    child:
                        const Icon(Icons.calendar_today, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.extended(
                    heroTag: 'upload',
                    onPressed: _isUploadingExcel ? null : _uploadExcel,
                    backgroundColor: Colors.green,
                    icon: _isUploadingExcel
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.upload_file, color: Colors.white),
                    label: Text(
                      _isUploadingExcel ? 'جاري الرفع...' : 'رفع Excel',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
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
            'إعداد الأهداف',
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
      child: Column(
        children: [
          Row(
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
                  Icons.assignment,
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
                      'إعداد الأهداف',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'تحديد أهداف المبيعات للمندوبين',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF546E7A),
                      ),
                    ),
                  ],
                ),
              ),
              // Month Selector
              InkWell(
                onTap: _selectMonth,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              const SizedBox(width: 16),
              // Excel Upload Button
              if (_isUploadingExcel)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                ElevatedButton.icon(
                  onPressed: _uploadExcel,
                  icon: const Icon(Icons.upload_file, size: 20),
                  label: const Text('رفع Excel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Info Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF135467).withOpacity(0.1),
                  const Color(0xFF135467).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: const Color(0xFF135467).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF135467),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'اختر مندوب لإدخال الأهداف يدوياً، أو ارفع ملف Excel لتحديد أهداف عدة مندوبين دفعة واحدة',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
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
      onTap: () => _navigateToSetTargets(user),
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

  void _navigateToSetTargets(AppUser user) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserTargetInputScreen(
          user: user,
          selectedMonth: _selectedMonth,
        ),
      ),
    );

    if (result == true) {
      await _loadUsers();
    }
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

// User Target Input Screen (for individual manual input)
class UserTargetInputScreen extends StatefulWidget {
  final AppUser user;
  final DateTime selectedMonth;

  const UserTargetInputScreen({
    super.key,
    required this.user,
    required this.selectedMonth,
  });

  @override
  State<UserTargetInputScreen> createState() => _UserTargetInputScreenState();
}

class _UserTargetInputScreenState extends State<UserTargetInputScreen> {
  List<Brand> _brands = [];
  Map<String, TextEditingController> _targetControllers = {};
  bool _isLoading = false;
  bool _isSaving = false;
  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = await SupabaseService.getCurrentUser();
      await _loadBrands();
      await _loadExistingTargets();
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في التحميل: $e', isError: true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBrands() async {
    try {
      _brands = await SupabaseService.getBrands(isActive: true);

      for (final brand in _brands) {
        _targetControllers[brand.code] = TextEditingController();
      }
    } catch (e) {
      print('Error loading brands: $e');
      rethrow;
    }
  }

  Future<void> _loadExistingTargets() async {
    try {
      final targets = await SupabaseService.getSalaryTargetsForUser(
        userId: widget.user.id,
        targetMonth:
            DateTime(widget.selectedMonth.year, widget.selectedMonth.month, 1),
      );

      setState(() {
        for (final target in targets) {
          if (_targetControllers.containsKey(target.brandCode)) {
            _targetControllers[target.brandCode]!.text = target.targetAmount > 0
                ? target.targetAmount.toStringAsFixed(2)
                : '';
          }
        }
      });
    } catch (e) {
      print('Error loading existing targets: $e');
    }
  }

  Future<void> _saveTargets() async {
    if (_currentUser == null) return;

    setState(() => _isSaving = true);
    try {
      final List<SalaryTarget> targets = [];

      for (final brand in _brands) {
        final controller = _targetControllers[brand.code];
        if (controller != null && controller.text.isNotEmpty) {
          final amount = double.tryParse(controller.text) ?? 0;
          if (amount > 0) {
            targets.add(SalaryTarget(
              id: 0,
              userId: widget.user.id,
              targetMonth: DateTime(
                  widget.selectedMonth.year, widget.selectedMonth.month, 1),
              brandCode: brand.code,
              targetAmount: amount,
              createdBy: _currentUser!.id,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ));
          }
        }
      }

      if (targets.isEmpty) {
        if (mounted) {
          Helpers.showSnackBar(context, 'الرجاء إدخال هدف واحد على الأقل',
              isError: true);
        }
        return;
      }

      await SupabaseService.saveSalaryTargets(targets);

      if (mounted) {
        Helpers.showSnackBar(context, 'تم حفظ الأهداف بنجاح');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في حفظ الأهداف: $e', isError: true);
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    for (final controller in _targetControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: isMobile ? 1 : 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تحديد الأهداف - ${widget.user.username}',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2C3E50),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                Helpers.formatMonthYear(widget.selectedMonth),
                style: TextStyle(
                  fontSize: isMobile ? 11 : 12,
                  color: const Color(0xFF546E7A),
                ),
              ),
            ],
          ),
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              isMobile
                  ? IconButton(
                      icon: const Icon(Icons.save, color: Color(0xFF135467)),
                      onPressed: _saveTargets,
                    )
                  : TextButton.icon(
                      onPressed: _saveTargets,
                      icon: const Icon(Icons.save),
                      label: const Text('حفظ'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF135467),
                      ),
                    ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(isMobile),
      ),
    );
  }

  Widget _buildContent(bool isMobile) {
    return Container(
      margin: EdgeInsets.all(isMobile ? 16 : 24),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Row(
              children: [
                Icon(
                  Icons.flag,
                  color: const Color(0xFF135467),
                  size: isMobile ? 20 : 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'الأهداف الشهرية حسب العلامة التجارية',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2C3E50),
                    ),
                  ),
                ),
                Text(
                  '${_brands.length} علامة',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              itemCount: _brands.length,
              separatorBuilder: (context, index) =>
                  SizedBox(height: isMobile ? 8 : 12),
              itemBuilder: (context, index) {
                final brand = _brands[index];
                return _buildBrandTargetRow(brand, isMobile);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandTargetRow(Brand brand, bool isMobile) {
    final controller = _targetControllers[brand.code];
    if (controller == null) return const SizedBox();

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brand.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'كود: ${brand.code}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'الهدف الشهري',
                    hintText: '0.00',
                    prefixIcon: const Icon(Icons.attach_money, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        brand.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'كود: ${brand.code}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'الهدف الشهري',
                      hintText: '0.00',
                      prefixIcon: const Icon(Icons.attach_money, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// Month/Year Picker Dialog Widget
class MonthYearPickerDialog extends StatefulWidget {
  final DateTime initialDate;

  const MonthYearPickerDialog({super.key, required this.initialDate});

  @override
  State<MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<MonthYearPickerDialog> {
  late int selectedYear;
  late int selectedMonth;

  @override
  void initState() {
    super.initState();
    selectedYear = widget.initialDate.year;
    selectedMonth = widget.initialDate.month;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('اختر الشهر والسنة'),
        content: SizedBox(
          width: isMobile ? double.maxFinite : 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Year Selector
              DropdownButtonFormField<int>(
                value: selectedYear,
                decoration: const InputDecoration(
                  labelText: 'السنة',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(5, (index) {
                  final year = DateTime.now().year - 2 + index;
                  return DropdownMenuItem(
                    value: year,
                    child: Text(year.toString()),
                  );
                }),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedYear = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              // Month Selector
              DropdownButtonFormField<int>(
                value: selectedMonth,
                decoration: const InputDecoration(
                  labelText: 'الشهر',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(12, (index) {
                  final month = index + 1;
                  return DropdownMenuItem(
                    value: month,
                    child: Text(_getMonthName(month)),
                  );
                }),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedMonth = value);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, DateTime(selectedYear, selectedMonth, 1));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF135467),
              foregroundColor: Colors.white,
            ),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'إبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];
    return months[month - 1];
  }
}
