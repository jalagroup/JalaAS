import 'package:flutter/material.dart';
import 'role.dart';

// ── Config field types ────────────────────────────────────────────────────────

enum ConfigFieldType {
  text,
  select,
  multiSelect,
  textList, // user adds/removes string chips
  toggle,
}

class ConfigOption {
  final String value;
  final String label;
  const ConfigOption(this.value, this.label);
}

class ConfigField {
  final String key;
  final String label;
  final String? hint;
  final ConfigFieldType type;
  final List<ConfigOption> options;
  final dynamic defaultValue;
  /// Show this field only when [showWhenKey] equals [showWhenValue].
  final String? showWhenKey;
  final String? showWhenValue;

  const ConfigField({
    required this.key,
    required this.label,
    this.hint,
    required this.type,
    this.options = const [],
    this.defaultValue,
    this.showWhenKey,
    this.showWhenValue,
  });
}

// ── Feature definition ────────────────────────────────────────────────────────

class FeatureDefinition {
  final String key;
  final String nameAr;
  final String? descriptionAr;
  final IconData icon;
  final InterfaceType interfaceType;
  final List<ConfigField> configSchema;

  const FeatureDefinition({
    required this.key,
    required this.nameAr,
    this.descriptionAr,
    required this.icon,
    required this.interfaceType,
    this.configSchema = const [],
  });
}

// ── Static feature catalog ────────────────────────────────────────────────────

class AppFeatures {
  // ── User interface keys ─────────────────────────────────────────────────────
  static const String accountStatements = 'account_statements';
  static const String agingReport = 'aging_report';
  static const String almiraStockReport = 'almira_stock_report';
  static const String periodicSalesReport = 'periodic_sales_report';
  static const String priceList = 'price_list';
  static const String salaryManagement = 'salary_management';
  static const String warehouseTransfer = 'warehouse_transfer';
  static const String bulkWarehouseTransfer = 'bulk_warehouse_transfer';
  static const String createCustomer = 'create_customer';
  static const String fuelFilling = 'fuel_filling';
  static const String salesReturns = 'sales_returns';
  static const String qualityChecklists = 'quality_checklists';
  static const String qualityIssues = 'quality_issues';
  static const String taskChecklists = 'task_checklists';
  static const String reportLists = 'report_lists';
  static const String customReportsViewer = 'custom_reports_viewer';

  // ── Admin interface keys ────────────────────────────────────────────────────
  static const String usersManagement = 'users_management';
  static const String rolesManagement = 'roles_management';
  static const String syncData = 'sync_data';
  static const String brandsManagement = 'brands_management';
  static const String qualityManagement = 'quality_management';
  static const String positionsManagement = 'positions_management';
  static const String salesReturnsAdmin = 'sales_returns_admin';
  static const String fuelManagement = 'fuel_management';
  static const String reportManagement = 'report_management';
  static const String reportBuilder = 'report_builder';
  static const String taskChecklistsAdmin = 'task_checklists_admin';

  // ── Full catalog ────────────────────────────────────────────────────────────

  static const List<FeatureDefinition> all = [
    // ═══════════════════════════ USER FEATURES ════════════════════════════════

    FeatureDefinition(
      key: accountStatements,
      nameAr: 'كشف الحساب',
      descriptionAr: 'عرض كشوف حسابات العملاء',
      icon: Icons.account_balance_wallet_outlined,
      interfaceType: InterfaceType.user,
      configSchema: [
        ConfigField(
          key: 'scope',
          label: 'نطاق العملاء المرئيين',
          type: ConfigFieldType.select,
          options: [
            ConfigOption('all', 'جميع العملاء'),
            ConfigOption('by_salesman', 'حسب المندوب'),
            ConfigOption('by_contact_list', 'قائمة عملاء مخصصة'),
          ],
          defaultValue: 'all',
        ),
        ConfigField(
          key: 'salesmen',
          label: 'أكواد المندوبين المسموح بهم',
          hint: 'مثال: 001، 002',
          type: ConfigFieldType.textList,
          showWhenKey: 'scope',
          showWhenValue: 'by_salesman',
        ),
        ConfigField(
          key: 'custom_contacts',
          label: 'أكواد العملاء المخصصين',
          hint: 'أدخل أكواد العملاء المسموح برؤيتهم',
          type: ConfigFieldType.textList,
          showWhenKey: 'scope',
          showWhenValue: 'by_contact_list',
        ),
        ConfigField(
          key: 'additional_contacts',
          label: 'عملاء إضافيون (تُضاف فوق أي نطاق)',
          hint: 'عملاء يُضافون بالإضافة إلى النطاق المحدد',
          type: ConfigFieldType.textList,
        ),
      ],
    ),

    FeatureDefinition(
      key: agingReport,
      nameAr: 'تقرير التعميرة',
      descriptionAr: 'تقرير المديونيات حسب عمر الدين',
      icon: Icons.analytics_outlined,
      interfaceType: InterfaceType.user,
      configSchema: [
        ConfigField(
          key: 'salesman_scope',
          label: 'نطاق المندوبين',
          type: ConfigFieldType.select,
          options: [
            ConfigOption('all', 'جميع المندوبين'),
            ConfigOption('specific', 'مندوبون محددون'),
          ],
          defaultValue: 'all',
        ),
        ConfigField(
          key: 'salesmen',
          label: 'المندوبون المسموح بهم',
          hint: 'أدخل أكواد المندوبين',
          type: ConfigFieldType.textList,
          showWhenKey: 'salesman_scope',
          showWhenValue: 'specific',
        ),
        ConfigField(
          key: 'allowed_contact_types',
          label: 'أنواع جهات الاتصال المسموح بها',
          type: ConfigFieldType.multiSelect,
          options: [
            ConfigOption('customers', 'الزبائن'),
            ConfigOption('defaulters', 'المتعثرون'),
          ],
          defaultValue: ['customers', 'defaulters'],
        ),
        ConfigField(
          key: 'allowed_date_types',
          label: 'أنواع الفترات الزمنية المسموح بها',
          type: ConfigFieldType.multiSelect,
          options: [
            ConfigOption('current', 'التاريخ الحالي'),
            ConfigOption('month_end', 'نهاية الشهر'),
          ],
          defaultValue: ['current', 'month_end'],
        ),
      ],
    ),

    FeatureDefinition(
      key: almiraStockReport,
      nameAr: 'أرصدة المخزون - الميرا',
      descriptionAr: 'رصيد المرحل والمحفوظ وإنتاج ZFI',
      icon: Icons.inventory_2_outlined,
      interfaceType: InterfaceType.user,
    ),

    FeatureDefinition(
      key: periodicSalesReport,
      nameAr: 'تقرير المبيعات الدورية',
      descriptionAr: 'تقرير المبيعات حسب الفترات والمناطق',
      icon: Icons.timeline_outlined,
      interfaceType: InterfaceType.user,
      configSchema: [
        ConfigField(
          key: 'area',
          label: 'المنطقة الجغرافية المسموح بها',
          type: ConfigFieldType.select,
          options: [
            ConfigOption('all', 'كل المناطق'),
            ConfigOption('north', 'مناطق الشمال فقط'),
            ConfigOption('south', 'مناطق الجنوب فقط'),
          ],
          defaultValue: 'all',
        ),
      ],
    ),

    FeatureDefinition(
      key: priceList,
      nameAr: 'قائمة الأسعار',
      descriptionAr: 'عرض قوائم الأسعار P و S',
      icon: Icons.price_change_outlined,
      interfaceType: InterfaceType.user,
    ),

    FeatureDefinition(
      key: salaryManagement,
      nameAr: 'إدارة الرواتب والأهداف',
      descriptionAr: 'إدارة العلامات التجارية والأهداف وحساب الرواتب',
      icon: Icons.payments_outlined,
      interfaceType: InterfaceType.user,
    ),

    FeatureDefinition(
      key: warehouseTransfer,
      nameAr: 'إرسال بضاعة بين المستودعات',
      descriptionAr: 'نقل الأصناف بين المخازن المختلفة',
      icon: Icons.warehouse_outlined,
      interfaceType: InterfaceType.user,
    ),

    FeatureDefinition(
      key: bulkWarehouseTransfer,
      nameAr: 'ترحيل كل البضاعة بالمخازن',
      descriptionAr: 'ترحيل جميع الأصناف للمخزن الرئيسي',
      icon: Icons.move_to_inbox_outlined,
      interfaceType: InterfaceType.user,
    ),

    FeatureDefinition(
      key: createCustomer,
      nameAr: 'فتح الزبون',
      descriptionAr: 'إضافة عميل جديد إلى النظام',
      icon: Icons.person_add_outlined,
      interfaceType: InterfaceType.user,
    ),

    FeatureDefinition(
      key: fuelFilling,
      nameAr: 'إدخال المحروقات',
      descriptionAr: 'تسجيل بيانات تعبئة المحروقات',
      icon: Icons.local_gas_station_outlined,
      interfaceType: InterfaceType.user,
    ),

    FeatureDefinition(
      key: salesReturns,
      nameAr: 'مرتجعات المبيعات',
      descriptionAr: 'إدارة مرتجعات المبيعات والطباعة',
      icon: Icons.assignment_return_outlined,
      interfaceType: InterfaceType.user,
    ),

    FeatureDefinition(
      key: qualityChecklists,
      nameAr: 'تقارير مراقبة الجودة',
      descriptionAr: 'إدارة وملء قوائم مراقبة الجودة',
      icon: Icons.checklist_outlined,
      interfaceType: InterfaceType.user,
    ),

    FeatureDefinition(
      key: qualityIssues,
      nameAr: 'مشاكل نقاط الفحص',
      descriptionAr: 'عرض وحل مشاكل نقاط الفحص المعينة',
      icon: Icons.report_problem_outlined,
      interfaceType: InterfaceType.user,
    ),

    FeatureDefinition(
      key: taskChecklists,
      nameAr: 'قوائم مهامي',
      descriptionAr: 'المهام اليومية المخصصة للمستخدم',
      icon: Icons.task_alt_outlined,
      interfaceType: InterfaceType.user,
    ),

    FeatureDefinition(
      key: reportLists,
      nameAr: 'قوائم التقارير',
      descriptionAr: 'عرض وملء قوائم التقارير المخصصة',
      icon: Icons.assignment_outlined,
      interfaceType: InterfaceType.user,
    ),

    FeatureDefinition(
      key: customReportsViewer,
      nameAr: 'التقارير المخصصة',
      descriptionAr: 'تشغيل التقارير المبنية بمنشئ التقارير',
      icon: Icons.bar_chart_outlined,
      interfaceType: InterfaceType.user,
      configSchema: [
        ConfigField(
          key: 'allowed_report_ids',
          label: 'معرّفات التقارير المسموح بعرضها',
          hint: 'اترك فارغاً للسماح بجميع التقارير',
          type: ConfigFieldType.textList,
        ),
      ],
    ),

    // ═══════════════════════════ ADMIN FEATURES ═══════════════════════════════

    FeatureDefinition(
      key: usersManagement,
      nameAr: 'إدارة المستخدمين',
      descriptionAr: 'إضافة وتعديل وحذف مستخدمي النظام',
      icon: Icons.people_outline,
      interfaceType: InterfaceType.admin,
    ),

    FeatureDefinition(
      key: rolesManagement,
      nameAr: 'إدارة الأدوار والصلاحيات',
      descriptionAr: 'إنشاء الأدوار وتخصيص الصلاحيات لها',
      icon: Icons.security_outlined,
      interfaceType: InterfaceType.admin,
    ),

    FeatureDefinition(
      key: syncData,
      nameAr: 'مزامنة البيانات',
      descriptionAr: 'مزامنة بيانات العملاء والمنتجات من بيسان',
      icon: Icons.sync_outlined,
      interfaceType: InterfaceType.admin,
    ),

    FeatureDefinition(
      key: brandsManagement,
      nameAr: 'العلامات التجارية والأهداف',
      descriptionAr: 'إدارة العلامات التجارية وأهداف المبيعات',
      icon: Icons.category_outlined,
      interfaceType: InterfaceType.admin,
    ),

    FeatureDefinition(
      key: qualityManagement,
      nameAr: 'إدارة منظومة الجودة',
      descriptionAr: 'إدارة نقاط الفحص وتقارير الجودة والمجموعات',
      icon: Icons.verified_outlined,
      interfaceType: InterfaceType.admin,
    ),

    FeatureDefinition(
      key: positionsManagement,
      nameAr: 'إدارة المناصب الوظيفية',
      descriptionAr: 'إنشاء وتعديل المناصب الوظيفية',
      icon: Icons.work_outline,
      interfaceType: InterfaceType.admin,
    ),

    FeatureDefinition(
      key: salesReturnsAdmin,
      nameAr: 'إدارة مرتجعات المبيعات',
      descriptionAr: 'مراجعة واعتماد مرتجعات المبيعات',
      icon: Icons.assignment_return_outlined,
      interfaceType: InterfaceType.admin,
    ),

    FeatureDefinition(
      key: fuelManagement,
      nameAr: 'إدارة المحروقات',
      descriptionAr: 'إدارة سجلات تعبئة المحروقات والمركبات',
      icon: Icons.local_gas_station_outlined,
      interfaceType: InterfaceType.admin,
    ),

    FeatureDefinition(
      key: reportManagement,
      nameAr: 'إدارة قوائم التقارير',
      descriptionAr: 'إنشاء وإدارة قوائم التقارير المخصصة',
      icon: Icons.assessment_outlined,
      interfaceType: InterfaceType.admin,
    ),

    FeatureDefinition(
      key: reportBuilder,
      nameAr: 'منشئ التقارير المخصصة',
      descriptionAr: 'بناء تقارير ديناميكية من واجهة برمجة التطبيقات',
      icon: Icons.build_circle_outlined,
      interfaceType: InterfaceType.admin,
    ),

    FeatureDefinition(
      key: taskChecklistsAdmin,
      nameAr: 'إدارة قوائم المهام',
      descriptionAr: 'إنشاء وتوزيع قوائم المهام اليومية',
      icon: Icons.task_alt,
      interfaceType: InterfaceType.admin,
    ),
  ];

  static FeatureDefinition? findByKey(String key) {
    for (final f in all) {
      if (f.key == key) return f;
    }
    return null;
  }

  static List<FeatureDefinition> forInterface(InterfaceType type) =>
      all.where((f) => f.interfaceType == type).toList();
}
