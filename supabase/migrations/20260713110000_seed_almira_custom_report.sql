-- Seed: أرصدة المخزون - الميرا as a multi-source custom report.
-- Uses 1 primary call (to get item list) + 6 extra sources for the numeric columns.

INSERT INTO custom_reports (id, name_ar, description, is_active, report_config)
VALUES (
  '00000000-0000-0002-0000-000000000006',
  'أرصدة المخزون - الميرا',
  'رصيد المرحل والمحفوظ وإنتاج ZFI - ميرا 309',
  true,
  '{
    "company": "jalaf",
    "endpoint": "REPORT/stockBalance",
    "fixed_params": {
      "fromDate": "2025-01-01",
      "toDate": "2026-12-31",
      "warehouse_From": "0002",
      "warehouse_To": "1050",
      "brand_From": "309",
      "brand_To": "309",
      "orderBy": "صنف",
      "includeZeroBalances": "true",
      "byWarehouse": "true",
      "lg_status": "posted",
      "whsGrp": "02"
    },
    "primary_api_fields": ["item", "item.name"],
    "inputs": [],
    "fields": [
      {"key": "item",              "label_ar": "كود الصنف",                    "visible": false, "width": 100, "format": "text",   "sortable": false, "wrap_lines": 1},
      {"key": "item.name",         "label_ar": "اسم الصنف",                    "visible": true,  "width": 220, "format": "text",   "sortable": false, "wrap_lines": 2},
      {"key": "jalaf_marhol",      "label_ar": "المرحل",                       "visible": true,  "width": 130, "format": "number", "sortable": true,  "wrap_lines": 1},
      {"key": "jalaf_marhol_main", "label_ar": "المرحل - المخزن الرئيسي",     "visible": true,  "width": 150, "format": "number", "sortable": true,  "wrap_lines": 2},
      {"key": "jalaf_mahfuz",      "label_ar": "المحفوظ",                      "visible": true,  "width": 130, "format": "number", "sortable": true,  "wrap_lines": 1},
      {"key": "jalaf_mahfuz_main", "label_ar": "المحفوظ - المخزن الرئيسي",    "visible": true,  "width": 150, "format": "number", "sortable": true,  "wrap_lines": 2},
      {"key": "zfi_intaj",         "label_ar": "رصيد الإنتاج",                 "visible": true,  "width": 130, "format": "number", "sortable": true,  "wrap_lines": 1},
      {"key": "zfi_reserved",      "label_ar": "رصيد الإنتاج المحجوز",        "visible": true,  "width": 150, "format": "number", "sortable": true,  "wrap_lines": 2}
    ],
    "filters": [],
    "show_summary_row": true,
    "group_by_field": "item",
    "by_warehouse": false,
    "extra_sources": [
      {
        "id": "jalaf_marhol",
        "company": "jalaf",
        "endpoint": "REPORT/stockBalance",
        "fixed_params": {
          "fromDate": "2025-01-01",
          "toDate": "2026-12-31",
          "warehouse_From": "0002",
          "warehouse_To": "1050",
          "brand_From": "309",
          "brand_To": "309",
          "orderBy": "صنف",
          "includeZeroBalances": "true",
          "byWarehouse": "true",
          "lg_status": "posted",
          "whsGrp": "02"
        },
        "join_key": "item",
        "value_field": "endBalance",
        "output_field": "jalaf_marhol",
        "pre_filters": [
          {"field": "warehouse", "operator": "notIn", "value": ["0010"]}
        ],
        "aggregate": "sum"
      },
      {
        "id": "jalaf_marhol_main",
        "company": "jalaf",
        "endpoint": "REPORT/stockBalance",
        "fixed_params": {
          "fromDate": "2025-01-01",
          "toDate": "2026-12-31",
          "warehouse_From": "0002",
          "warehouse_To": "0002",
          "brand_From": "309",
          "brand_To": "309",
          "orderBy": "صنف",
          "includeZeroBalances": "true",
          "byWarehouse": "true",
          "lg_status": "posted",
          "whsGrp": "02"
        },
        "join_key": "item",
        "value_field": "endBalance",
        "output_field": "jalaf_marhol_main",
        "pre_filters": [],
        "aggregate": "sum"
      },
      {
        "id": "jalaf_mahfuz",
        "company": "jalaf",
        "endpoint": "REPORT/stockBalance",
        "fixed_params": {
          "fromDate": "2025-01-01",
          "toDate": "2026-12-31",
          "warehouse_From": "0002",
          "warehouse_To": "1050",
          "brand_From": "309",
          "brand_To": "309",
          "orderBy": "صنف",
          "includeZeroBalances": "true",
          "byWarehouse": "true",
          "lg_status": "saved",
          "whsGrp": "02"
        },
        "join_key": "item",
        "value_field": "endBalance",
        "output_field": "jalaf_mahfuz",
        "pre_filters": [
          {"field": "warehouse", "operator": "notIn", "value": ["0010"]}
        ],
        "aggregate": "sum"
      },
      {
        "id": "jalaf_mahfuz_main",
        "company": "jalaf",
        "endpoint": "REPORT/stockBalance",
        "fixed_params": {
          "fromDate": "2025-01-01",
          "toDate": "2026-12-31",
          "warehouse_From": "0002",
          "warehouse_To": "0002",
          "brand_From": "309",
          "brand_To": "309",
          "orderBy": "صنف",
          "includeZeroBalances": "true",
          "byWarehouse": "true",
          "lg_status": "saved",
          "whsGrp": "02"
        },
        "join_key": "item",
        "value_field": "endBalance",
        "output_field": "jalaf_mahfuz_main",
        "pre_filters": [],
        "aggregate": "sum"
      },
      {
        "id": "zfi_intaj",
        "company": "zfi",
        "endpoint": "REPORT/stockBalance",
        "fixed_params": {
          "fromDate": "2025-01-01",
          "toDate": "2026-12-31",
          "warehouse_From": "0001",
          "warehouse_To": "0001",
          "brand_From": "309",
          "brand_To": "309",
          "orderBy": "صنف",
          "includeZeroBalances": "true",
          "byWarehouse": "true",
          "lg_status": "مرحل"
        },
        "join_key": "item",
        "value_field": "endBalance",
        "output_field": "zfi_intaj",
        "pre_filters": [],
        "aggregate": "sum"
      },
      {
        "id": "zfi_reserved",
        "company": "zfi",
        "endpoint": "REPORT/stockBalance",
        "fixed_params": {
          "fromDate": "2025-01-01",
          "toDate": "2026-12-31",
          "warehouse_From": "0025",
          "warehouse_To": "0025",
          "brand_From": "309",
          "brand_To": "309",
          "orderBy": "صنف",
          "includeZeroBalances": "true",
          "byWarehouse": "true",
          "lg_status": "مرحل"
        },
        "join_key": "item",
        "value_field": "endBalance",
        "output_field": "zfi_reserved",
        "pre_filters": [],
        "aggregate": "sum"
      }
    ]
  }'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  name_ar       = EXCLUDED.name_ar,
  description   = EXCLUDED.description,
  report_config = EXCLUDED.report_config;
