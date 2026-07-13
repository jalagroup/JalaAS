-- =============================================================================
-- SEED: Base roles + role features + built-in custom reports
-- =============================================================================

-- ── 1. Base roles ─────────────────────────────────────────────────────────────
INSERT INTO roles (id, name_ar, description, interface_type, is_active) VALUES
  ('00000000-0000-0001-0000-000000000001', 'مدير عام',         'صلاحيات كاملة على جميع أقسام النظام',          'admin', true),
  ('00000000-0000-0001-0000-000000000002', 'مندوب مبيعات',     'عرض التقارير وكشوف الحسابات والتعاملات اليومية','user',  true),
  ('00000000-0000-0001-0000-000000000003', 'مدير جودة',        'إدارة نظام مراقبة الجودة والتقارير',            'admin', true),
  ('00000000-0000-0001-0000-000000000004', 'مدير محروقات',     'إدارة نظام المحروقات والسيارات',                'admin', true),
  ('00000000-0000-0001-0000-000000000005', 'موظف جودة',        'تسجيل فحوصات الجودة والمشاكل الميدانية',       'user',  true),
  ('00000000-0000-0001-0000-000000000006', 'موظف وقود',        'تسجيل طلبات الوقود اليومية',                   'user',  true),
  ('00000000-0000-0001-0000-000000000007', 'مدير مبيعات',      'إدارة المرتجعات والعملاء الجدد',                'admin', true),
  ('00000000-0000-0001-0000-000000000008', 'موظف مستودع',      'تنفيذ حركات التحويل والإصدار من المستودع',      'user',  true)
ON CONFLICT (id) DO NOTHING;

-- ── 2. Role features ──────────────────────────────────────────────────────────
-- مدير عام  → all admin features
INSERT INTO role_features (role_id, feature_key, config) VALUES
  ('00000000-0000-0001-0000-000000000001', 'users_management',       '{}'),
  ('00000000-0000-0001-0000-000000000001', 'roles_management',       '{}'),
  ('00000000-0000-0001-0000-000000000001', 'report_builder',         '{}'),
  ('00000000-0000-0001-0000-000000000001', 'report_management',      '{}'),
  ('00000000-0000-0001-0000-000000000001', 'quality_management',     '{}'),
  ('00000000-0000-0001-0000-000000000001', 'task_checklists_admin',  '{}'),
  ('00000000-0000-0001-0000-000000000001', 'sales_returns_admin',    '{}'),
  ('00000000-0000-0001-0000-000000000001', 'fuel_management',        '{}'),
  ('00000000-0000-0001-0000-000000000001', 'positions_management',   '{}'),
  ('00000000-0000-0001-0000-000000000001', 'brands_management',      '{}'),
  ('00000000-0000-0001-0000-000000000001', 'sync_data',              '{}')
ON CONFLICT (role_id, feature_key) DO NOTHING;

-- مندوب مبيعات → user-facing sales features
INSERT INTO role_features (role_id, feature_key, config) VALUES
  ('00000000-0000-0001-0000-000000000002', 'account_statements',  '{"scope":"salesman"}'),
  ('00000000-0000-0001-0000-000000000002', 'aging_report',        '{"salesman_scope":"own"}'),
  ('00000000-0000-0001-0000-000000000002', 'price_list',          '{}'),
  ('00000000-0000-0001-0000-000000000002', 'periodic_sales_report','{}'),
  ('00000000-0000-0001-0000-000000000002', 'sales_returns',       '{}'),
  ('00000000-0000-0001-0000-000000000002', 'create_customer',     '{}'),
  ('00000000-0000-0001-0000-000000000002', 'custom_reports_viewer','{}'),
  ('00000000-0000-0001-0000-000000000002', 'task_checklists',     '{}'),
  ('00000000-0000-0001-0000-000000000002', 'report_lists',        '{}')
ON CONFLICT (role_id, feature_key) DO NOTHING;

-- مدير جودة → quality admin features
INSERT INTO role_features (role_id, feature_key, config) VALUES
  ('00000000-0000-0001-0000-000000000003', 'quality_management',    '{}'),
  ('00000000-0000-0001-0000-000000000003', 'report_management',     '{}'),
  ('00000000-0000-0001-0000-000000000003', 'task_checklists_admin', '{}'),
  ('00000000-0000-0001-0000-000000000003', 'users_management',      '{}')
ON CONFLICT (role_id, feature_key) DO NOTHING;

-- مدير محروقات → fuel admin
INSERT INTO role_features (role_id, feature_key, config) VALUES
  ('00000000-0000-0001-0000-000000000004', 'fuel_management', '{}')
ON CONFLICT (role_id, feature_key) DO NOTHING;

-- موظف جودة → quality user features
INSERT INTO role_features (role_id, feature_key, config) VALUES
  ('00000000-0000-0001-0000-000000000005', 'quality_checklists', '{}'),
  ('00000000-0000-0001-0000-000000000005', 'quality_issues',     '{}'),
  ('00000000-0000-0001-0000-000000000005', 'task_checklists',    '{}'),
  ('00000000-0000-0001-0000-000000000005', 'report_lists',       '{}')
ON CONFLICT (role_id, feature_key) DO NOTHING;

-- موظف وقود → fuel user feature
INSERT INTO role_features (role_id, feature_key, config) VALUES
  ('00000000-0000-0001-0000-000000000006', 'fuel_filling', '{}')
ON CONFLICT (role_id, feature_key) DO NOTHING;

-- مدير مبيعات → sales admin features
INSERT INTO role_features (role_id, feature_key, config) VALUES
  ('00000000-0000-0001-0000-000000000007', 'sales_returns_admin', '{}'),
  ('00000000-0000-0001-0000-000000000007', 'users_management',    '{}')
ON CONFLICT (role_id, feature_key) DO NOTHING;

-- موظف مستودع → warehouse user features
INSERT INTO role_features (role_id, feature_key, config) VALUES
  ('00000000-0000-0001-0000-000000000008', 'warehouse_transfer',      '{}'),
  ('00000000-0000-0001-0000-000000000008', 'bulk_warehouse_transfer', '{}'),
  ('00000000-0000-0001-0000-000000000008', 'almira_stock_report',     '{}')
ON CONFLICT (role_id, feature_key) DO NOTHING;

-- ── 3. Built-in custom reports ────────────────────────────────────────────────

-- تقرير أعمار الديون (Aging Report)
INSERT INTO custom_reports (id, name_ar, description, is_active, report_config) VALUES (
  '00000000-0000-0002-0000-000000000001',
  'تقرير أعمار الديون',
  'يعرض الديون المستحقة على الزبائن مقسمةً بحسب فترات التأخير',
  true,
  '{
    "company": "jalaf",
    "endpoint": "REPORT/aRAging",
    "fixed_params": {
      "groupType": "دليل",
      "fromContactType": "001",
      "toContactType": "006",
      "branch": "00",
      "numPeriods": "3",
      "daysPerPeriod": "26",
      "isCustomer": "true",
      "useContactSalesman": "true",
      "lg_status": "مرحل"
    },
    "inputs": [
      {"key":"asOfDate","label_ar":"تاريخ الاستحقاق","type":"date","required":true,"default_value":"today","param_name":"asOfDate","options":[],"option_labels":[]},
      {"key":"fromSalesman","label_ar":"من مندوب","type":"text","required":false,"default_value":null,"param_name":"fromSalesman","options":[],"option_labels":[]},
      {"key":"toSalesman","label_ar":"إلى مندوب","type":"text","required":false,"default_value":null,"param_name":"toSalesman","options":[],"option_labels":[]},
      {"key":"area","label_ar":"المنطقة","type":"text","required":false,"default_value":null,"param_name":"area","options":[],"option_labels":[]}
    ],
    "fields": [
      {"key":"shownCont","label_ar":"كود الزبون","visible":true,"width":100,"format":"text","sortable":true,"wrap_lines":1},
      {"key":"shownCont.name","label_ar":"اسم الزبون","visible":true,"width":200,"format":"text","sortable":true,"wrap_lines":1},
      {"key":"shownCont.phone","label_ar":"الهاتف","visible":true,"width":120,"format":"text","sortable":false,"wrap_lines":1},
      {"key":"balance","label_ar":"الرصيد الكلي","visible":true,"width":130,"format":"currency","sortable":true,"wrap_lines":1},
      {"key":"1-26days","label_ar":"1-26 يوم","visible":true,"width":120,"format":"currency","sortable":true,"wrap_lines":1},
      {"key":"27-52days","label_ar":"27-52 يوم","visible":true,"width":120,"format":"currency","sortable":true,"wrap_lines":1},
      {"key":"53+days","label_ar":"53+ يوم","visible":true,"width":120,"format":"currency","sortable":true,"wrap_lines":1},
      {"key":"total","label_ar":"الإجمالي","visible":true,"width":130,"format":"currency","sortable":true,"wrap_lines":1}
    ],
    "filters": [],
    "show_summary_row": true,
    "group_by_field": null,
    "by_warehouse": false
  }'
) ON CONFLICT (id) DO NOTHING;

-- قائمة الأسعار (Price List)
INSERT INTO custom_reports (id, name_ar, description, is_active, report_config) VALUES (
  '00000000-0000-0002-0000-000000000002',
  'قائمة الأسعار',
  'أسعار المواد من قائمة P إلى S لجميع الأصناف',
  true,
  '{
    "company": "jalaf",
    "endpoint": "REPORT/priceListRpt",
    "fixed_params": {
      "fromPriceList": "P",
      "toPriceList": "S",
      "brand_From": "001",
      "brand_To": "905"
    },
    "inputs": [],
    "fields": [
      {"key":"item","label_ar":"كود الصنف","visible":true,"width":100,"format":"text","sortable":true,"wrap_lines":1},
      {"key":"item.name","label_ar":"اسم الصنف","visible":true,"width":220,"format":"text","sortable":true,"wrap_lines":2},
      {"key":"item.brand","label_ar":"الماركة","visible":true,"width":100,"format":"text","sortable":true,"wrap_lines":1},
      {"key":"unit","label_ar":"الوحدة","visible":true,"width":80,"format":"text","sortable":false,"wrap_lines":1},
      {"key":"partNumber","label_ar":"رقم القطعة","visible":true,"width":120,"format":"text","sortable":false,"wrap_lines":1},
      {"key":"P_rawPrice","label_ar":"سعر P (بدون ضريبة)","visible":true,"width":140,"format":"currency","sortable":true,"wrap_lines":1},
      {"key":"P_taxPrice","label_ar":"سعر P (مع ضريبة)","visible":true,"width":140,"format":"currency","sortable":true,"wrap_lines":1},
      {"key":"S_rawPrice","label_ar":"سعر S (بدون ضريبة)","visible":true,"width":140,"format":"currency","sortable":true,"wrap_lines":1},
      {"key":"S_taxPrice","label_ar":"سعر S (مع ضريبة)","visible":true,"width":140,"format":"currency","sortable":true,"wrap_lines":1}
    ],
    "filters": [],
    "show_summary_row": false,
    "group_by_field": null,
    "by_warehouse": false
  }'
) ON CONFLICT (id) DO NOTHING;

-- تقرير المبيعات الدورية (Periodic Sales Report)
INSERT INTO custom_reports (id, name_ar, description, is_active, report_config) VALUES (
  '00000000-0000-0002-0000-000000000003',
  'تقرير المبيعات الدورية',
  'مبيعات المندوبين خلال فترة زمنية محددة مقسمةً حسب الماركة',
  true,
  '{
    "company": "jalaf",
    "endpoint": "REPORT/periodicSalesRpt",
    "fixed_params": {
      "reportType": "Amount",
      "groupType": "By Brand",
      "brand_From": "001",
      "brand_To": "905"
    },
    "inputs": [
      {"key":"fromDate","label_ar":"من تاريخ","type":"date","required":true,"default_value":"month_start","param_name":"fromDate","options":[],"option_labels":[]},
      {"key":"toDate","label_ar":"إلى تاريخ","type":"date","required":true,"default_value":"today","param_name":"toDate","options":[],"option_labels":[]},
      {"key":"salesman","label_ar":"كود المندوب","type":"text","required":false,"default_value":null,"param_name":"salesman","options":[],"option_labels":[]}
    ],
    "fields": [
      {"key":"salesman","label_ar":"المندوب","visible":true,"width":100,"format":"text","sortable":true,"wrap_lines":1},
      {"key":"salesman.name","label_ar":"اسم المندوب","visible":true,"width":160,"format":"text","sortable":true,"wrap_lines":1},
      {"key":"brand","label_ar":"الماركة","visible":true,"width":100,"format":"text","sortable":true,"wrap_lines":1},
      {"key":"brand.name","label_ar":"اسم الماركة","visible":true,"width":160,"format":"text","sortable":true,"wrap_lines":1},
      {"key":"amount","label_ar":"المبيعات","visible":true,"width":140,"format":"currency","sortable":true,"wrap_lines":1},
      {"key":"target","label_ar":"الهدف","visible":true,"width":140,"format":"currency","sortable":true,"wrap_lines":1},
      {"key":"percentage","label_ar":"النسبة","visible":true,"width":100,"format":"percentage","sortable":true,"wrap_lines":1}
    ],
    "filters": [],
    "show_summary_row": true,
    "group_by_field": null,
    "by_warehouse": false
  }'
) ON CONFLICT (id) DO NOTHING;

-- تقرير رصيد المخزون - JALAF (Stock Balance)
INSERT INTO custom_reports (id, name_ar, description, is_active, report_config) VALUES (
  '00000000-0000-0002-0000-000000000004',
  'رصيد المخزون - JALAF',
  'أرصدة المخزون الحالية لجميع مستودعات جالا',
  true,
  '{
    "company": "jalaf",
    "endpoint": "REPORT/stockBalance",
    "fixed_params": {
      "warehouse_From": "0002",
      "warehouse_To": "1050",
      "brand_From": "309",
      "brand_To": "309",
      "includeZeroBalances": "true",
      "lg_status": "posted",
      "whsGrp": "02",
      "orderBy": "صنف"
    },
    "inputs": [
      {"key":"fromDate","label_ar":"من تاريخ","type":"date","required":true,"default_value":"year_start","param_name":"fromDate","options":[],"option_labels":[]},
      {"key":"toDate","label_ar":"إلى تاريخ","type":"date","required":true,"default_value":"today","param_name":"toDate","options":[],"option_labels":[]}
    ],
    "fields": [
      {"key":"item","label_ar":"كود الصنف","visible":true,"width":100,"format":"text","sortable":true,"wrap_lines":1},
      {"key":"item.name","label_ar":"اسم الصنف","visible":true,"width":200,"format":"text","sortable":true,"wrap_lines":2},
      {"key":"warehouse","label_ar":"كود المستودع","visible":true,"width":110,"format":"text","sortable":true,"wrap_lines":1},
      {"key":"warehouse.name","label_ar":"المستودع","visible":true,"width":150,"format":"text","sortable":true,"wrap_lines":1},
      {"key":"partNumber","label_ar":"رقم القطعة","visible":true,"width":120,"format":"text","sortable":false,"wrap_lines":1},
      {"key":"begBalance","label_ar":"الرصيد الافتتاحي","visible":true,"width":130,"format":"number","sortable":true,"wrap_lines":1},
      {"key":"rptQntIn","label_ar":"الوارد","visible":true,"width":100,"format":"number","sortable":true,"wrap_lines":1},
      {"key":"rptQntOut","label_ar":"الصادر","visible":true,"width":100,"format":"number","sortable":true,"wrap_lines":1},
      {"key":"endBalance","label_ar":"الرصيد الختامي","visible":true,"width":130,"format":"number","sortable":true,"wrap_lines":1}
    ],
    "filters": [
      {"field":"endBalance","operator":"ne","value":"0"}
    ],
    "show_summary_row": true,
    "group_by_field": "item",
    "by_warehouse": true
  }'
) ON CONFLICT (id) DO NOTHING;

-- تقرير رصيد المخزون - ZFI
INSERT INTO custom_reports (id, name_ar, description, is_active, report_config) VALUES (
  '00000000-0000-0002-0000-000000000005',
  'رصيد المخزون - ZFI',
  'أرصدة مخزون الإنتاج والاحتياطي لشركة ZFI',
  true,
  '{
    "company": "zfi",
    "endpoint": "REPORT/stockBalance",
    "fixed_params": {
      "brand_From": "309",
      "brand_To": "309",
      "includeZeroBalances": "true",
      "lg_status": "مرحل",
      "orderBy": "صنف"
    },
    "inputs": [
      {"key":"fromDate","label_ar":"من تاريخ","type":"date","required":true,"default_value":"year_start","param_name":"fromDate","options":[],"option_labels":[]},
      {"key":"toDate","label_ar":"إلى تاريخ","type":"date","required":true,"default_value":"today","param_name":"toDate","options":[],"option_labels":[]}
    ],
    "fields": [
      {"key":"item","label_ar":"كود الصنف","visible":true,"width":100,"format":"text","sortable":true,"wrap_lines":1},
      {"key":"item.name","label_ar":"اسم الصنف","visible":true,"width":200,"format":"text","sortable":true,"wrap_lines":2},
      {"key":"warehouse","label_ar":"كود المستودع","visible":true,"width":110,"format":"text","sortable":true,"wrap_lines":1},
      {"key":"warehouse.name","label_ar":"المستودع","visible":true,"width":150,"format":"text","sortable":true,"wrap_lines":1},
      {"key":"partNumber","label_ar":"رقم القطعة","visible":true,"width":120,"format":"text","sortable":false,"wrap_lines":1},
      {"key":"begBalance","label_ar":"الرصيد الافتتاحي","visible":true,"width":130,"format":"number","sortable":true,"wrap_lines":1},
      {"key":"rptQntIn","label_ar":"الوارد","visible":true,"width":100,"format":"number","sortable":true,"wrap_lines":1},
      {"key":"rptQntOut","label_ar":"الصادر","visible":true,"width":100,"format":"number","sortable":true,"wrap_lines":1},
      {"key":"endBalance","label_ar":"الرصيد الختامي","visible":true,"width":130,"format":"number","sortable":true,"wrap_lines":1}
    ],
    "filters": [],
    "show_summary_row": true,
    "group_by_field": "item",
    "by_warehouse": true
  }'
) ON CONFLICT (id) DO NOTHING;
