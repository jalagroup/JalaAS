// Custom report config stored fully in Supabase JSONB.

// ── Input parameter types ─────────────────────────────────────────────────────

enum ReportInputType {
  date,
  text,
  select;

  String get labelAr {
    switch (this) {
      case date:
        return 'تاريخ';
      case text:
        return 'نص حر';
      case select:
        return 'قائمة اختيار';
    }
  }
}

// ── Report input definition ───────────────────────────────────────────────────

class ReportInput {
  final String key;
  final String labelAr;
  final ReportInputType type;
  final bool required;
  final String? defaultValue; // 'today', 'month_start', 'year_start', or ISO date
  final String? paramName;    // URL search param to bind to (defaults to key)
  final List<String> options;       // for select type
  final List<String> optionLabels;  // for select type

  const ReportInput({
    required this.key,
    required this.labelAr,
    required this.type,
    this.required = true,
    this.defaultValue,
    this.paramName,
    this.options = const [],
    this.optionLabels = const [],
  });

  factory ReportInput.fromJson(Map<String, dynamic> j) => ReportInput(
        key: j['key'] as String,
        labelAr: j['label_ar'] as String,
        type: ReportInputType.values.firstWhere(
          (t) => t.name == (j['type'] as String? ?? 'text'),
          orElse: () => ReportInputType.text,
        ),
        required: j['required'] as bool? ?? true,
        defaultValue: j['default_value'] as String?,
        paramName: j['param_name'] as String?,
        options: List<String>.from(j['options'] as List? ?? []),
        optionLabels: List<String>.from(j['option_labels'] as List? ?? []),
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'label_ar': labelAr,
        'type': type.name,
        'required': required,
        'default_value': defaultValue,
        'param_name': paramName,
        'options': options,
        'option_labels': optionLabels,
      };

  String get effectiveParamName => paramName ?? key;
}

// ── Column field definition ───────────────────────────────────────────────────

enum FieldFormat {
  text,
  number,
  currency,
  date,
  percentage;

  String get labelAr {
    switch (this) {
      case text:
        return 'نص';
      case number:
        return 'رقم';
      case currency:
        return 'عملة';
      case date:
        return 'تاريخ';
      case percentage:
        return 'نسبة مئوية';
    }
  }
}

class ReportField {
  String key;       // API response field key (supports dot notation: "item.name")
  String labelAr;
  bool visible;
  double width;
  FieldFormat format;
  bool sortable;
  int wrapLines;    // 1 = single line, 2 = two-line ellipsis, etc.

  ReportField({
    required this.key,
    required this.labelAr,
    this.visible = true,
    this.width = 120,
    this.format = FieldFormat.text,
    this.sortable = false,
    this.wrapLines = 1,
  });

  factory ReportField.fromJson(Map<String, dynamic> j) => ReportField(
        key: j['key'] as String,
        labelAr: j['label_ar'] as String,
        visible: j['visible'] as bool? ?? true,
        width: (j['width'] as num? ?? 120).toDouble(),
        format: FieldFormat.values.firstWhere(
          (f) => f.name == (j['format'] as String? ?? 'text'),
          orElse: () => FieldFormat.text,
        ),
        sortable: j['sortable'] as bool? ?? false,
        wrapLines: j['wrap_lines'] as int? ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'label_ar': labelAr,
        'visible': visible,
        'width': width,
        'format': format.name,
        'sortable': sortable,
        'wrap_lines': wrapLines,
      };

  ReportField copyWith({
    String? key,
    String? labelAr,
    bool? visible,
    double? width,
    FieldFormat? format,
    bool? sortable,
    int? wrapLines,
  }) =>
      ReportField(
        key: key ?? this.key,
        labelAr: labelAr ?? this.labelAr,
        visible: visible ?? this.visible,
        width: width ?? this.width,
        format: format ?? this.format,
        sortable: sortable ?? this.sortable,
        wrapLines: wrapLines ?? this.wrapLines,
      );
}

// ── Filter rule ───────────────────────────────────────────────────────────────

enum FilterOperator {
  eq,
  ne,
  gt,
  gte,
  lt,
  lte,
  contains,
  notIn;

  String get labelAr {
    switch (this) {
      case eq:
        return 'يساوي';
      case ne:
        return 'لا يساوي';
      case gt:
        return 'أكبر من';
      case gte:
        return 'أكبر من أو يساوي';
      case lt:
        return 'أصغر من';
      case lte:
        return 'أصغر من أو يساوي';
      case contains:
        return 'يحتوي على';
      case notIn:
        return 'ليس ضمن القائمة';
    }
  }
}

class ReportFilter {
  String field;
  FilterOperator operator;
  dynamic value; // String, num, or List<String> for notIn

  ReportFilter({
    required this.field,
    required this.operator,
    required this.value,
  });

  factory ReportFilter.fromJson(Map<String, dynamic> j) => ReportFilter(
        field: j['field'] as String,
        operator: FilterOperator.values.firstWhere(
          (o) => o.name == (j['operator'] as String? ?? 'ne'),
          orElse: () => FilterOperator.ne,
        ),
        value: j['value'],
      );

  Map<String, dynamic> toJson() => {
        'field': field,
        'operator': operator.name,
        'value': value,
      };

  bool matches(Map<String, dynamic> row) {
    final cellRaw = _extract(row, field);
    final cell = double.tryParse(cellRaw?.toString() ?? '') ?? cellRaw;

    switch (operator) {
      case FilterOperator.eq:
        return cellRaw?.toString() == value?.toString();
      case FilterOperator.ne:
        return cellRaw?.toString() != value?.toString();
      case FilterOperator.gt:
        final v = double.tryParse(value.toString()) ?? 0;
        return (cell is double) && cell > v;
      case FilterOperator.gte:
        final v = double.tryParse(value.toString()) ?? 0;
        return (cell is double) && cell >= v;
      case FilterOperator.lt:
        final v = double.tryParse(value.toString()) ?? 0;
        return (cell is double) && cell < v;
      case FilterOperator.lte:
        final v = double.tryParse(value.toString()) ?? 0;
        return (cell is double) && cell <= v;
      case FilterOperator.contains:
        return cellRaw?.toString().contains(value.toString()) ?? false;
      case FilterOperator.notIn:
        final list = (value as List?)?.map((e) => e.toString()).toList() ?? [];
        return !list.contains(cellRaw?.toString() ?? '');
    }
  }

  static dynamic _extract(Map<String, dynamic> row, String key) {
    if (row.containsKey(key)) return row[key];
    if (key.contains('.')) {
      final parts = key.split('.');
      dynamic cur = row;
      for (final p in parts) {
        if (cur is Map) {
          cur = cur[p];
        } else {
          return null;
        }
      }
      return cur;
    }
    return row[key];
  }
}

// ── Extra data source (for multi-API reports) ─────────────────────────────────
//
// Each extra source makes its own API call. Results are grouped by [joinKey]
// and aggregated ([aggregate]: "sum" | "first"), then merged into the primary
// rows as a new field named [outputField].

class ReportDataSource {
  final String id;            // unique label for logging/debugging
  final ReportCompany company;
  final String endpoint;
  final Map<String, String> fixedParams;
  final String joinKey;       // field shared with primary rows to join on (e.g. "item")
  final String valueField;    // numeric field to extract/aggregate (e.g. "endBalance")
  final String outputField;   // name of the new field added to merged rows
  final List<ReportFilter> preFilters; // applied before aggregation
  final String aggregate;     // "sum" | "first"

  const ReportDataSource({
    required this.id,
    required this.company,
    required this.endpoint,
    this.fixedParams = const {},
    required this.joinKey,
    required this.valueField,
    required this.outputField,
    this.preFilters = const [],
    this.aggregate = 'sum',
  });

  factory ReportDataSource.fromJson(Map<String, dynamic> j) => ReportDataSource(
        id: j['id'] as String? ?? '',
        company: ReportCompany.values.firstWhere(
          (c) => c.name == (j['company'] as String? ?? 'jalaf'),
          orElse: () => ReportCompany.jalaf,
        ),
        endpoint: j['endpoint'] as String? ?? '',
        fixedParams: Map<String, String>.from(j['fixed_params'] as Map? ?? {}),
        joinKey: j['join_key'] as String? ?? 'item',
        valueField: j['value_field'] as String? ?? 'endBalance',
        outputField: j['output_field'] as String? ?? j['id'] as String? ?? '',
        preFilters: (j['pre_filters'] as List<dynamic>? ?? [])
            .map((e) => ReportFilter.fromJson(e as Map<String, dynamic>))
            .toList(),
        aggregate: j['aggregate'] as String? ?? 'sum',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'company': company.name,
        'endpoint': endpoint,
        'fixed_params': fixedParams,
        'join_key': joinKey,
        'value_field': valueField,
        'output_field': outputField,
        'pre_filters': preFilters.map((e) => e.toJson()).toList(),
        'aggregate': aggregate,
      };
}

// ── Full report config ────────────────────────────────────────────────────────

enum ReportCompany {
  jalaf,
  zfi;

  String get displayName => this == jalaf ? 'JALAF' : 'ZFI';
}

class CustomReportConfig {
  final ReportCompany company;
  final String endpoint;            // e.g. 'REPORT/stockBalance'
  final Map<String, String> fixedParams; // always-present URL params
  final List<ReportInput> inputs;
  final List<ReportField> fields;
  final List<ReportFilter> filters; // applied after fetch
  final bool showSummaryRow;
  final String? groupByField;       // group multi-row results by this field key
  final bool byWarehouse;
  // ── Multi-source support ───────────────────────────────────────────────────
  /// When non-empty, only these field keys are requested from the primary API
  /// (avoids sending derived/extra-source field names to Bisan).
  final List<String> primaryApiFields;
  /// Additional API calls whose results are joined into the primary rows.
  final List<ReportDataSource> extraSources;

  const CustomReportConfig({
    required this.company,
    required this.endpoint,
    this.fixedParams = const {},
    this.inputs = const [],
    this.fields = const [],
    this.filters = const [],
    this.showSummaryRow = false,
    this.groupByField,
    this.byWarehouse = false,
    this.primaryApiFields = const [],
    this.extraSources = const [],
  });

  factory CustomReportConfig.fromJson(Map<String, dynamic> j) =>
      CustomReportConfig(
        company: ReportCompany.values.firstWhere(
          (c) => c.name == (j['company'] as String? ?? 'jalaf'),
          orElse: () => ReportCompany.jalaf,
        ),
        endpoint: j['endpoint'] as String? ?? '',
        fixedParams: Map<String, String>.from(j['fixed_params'] as Map? ?? {}),
        inputs: (j['inputs'] as List<dynamic>? ?? [])
            .map((e) => ReportInput.fromJson(e as Map<String, dynamic>))
            .toList(),
        fields: (j['fields'] as List<dynamic>? ?? [])
            .map((e) => ReportField.fromJson(e as Map<String, dynamic>))
            .toList(),
        filters: (j['filters'] as List<dynamic>? ?? [])
            .map((e) => ReportFilter.fromJson(e as Map<String, dynamic>))
            .toList(),
        showSummaryRow: j['show_summary_row'] as bool? ?? false,
        groupByField: j['group_by_field'] as String?,
        byWarehouse: j['by_warehouse'] as bool? ?? false,
        primaryApiFields:
            List<String>.from(j['primary_api_fields'] as List? ?? []),
        extraSources: (j['extra_sources'] as List<dynamic>? ?? [])
            .map((e) => ReportDataSource.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'company': company.name,
        'endpoint': endpoint,
        'fixed_params': fixedParams,
        'inputs': inputs.map((e) => e.toJson()).toList(),
        'fields': fields.map((e) => e.toJson()).toList(),
        'filters': filters.map((e) => e.toJson()).toList(),
        'show_summary_row': showSummaryRow,
        'group_by_field': groupByField,
        'by_warehouse': byWarehouse,
        'primary_api_fields': primaryApiFields,
        'extra_sources': extraSources.map((e) => e.toJson()).toList(),
      };
}

// ── Custom report (row in DB) ─────────────────────────────────────────────────

class CustomReport {
  final String id;
  final String nameAr;
  final String? description;
  final bool isActive;
  final CustomReportConfig config;
  final DateTime createdAt;

  const CustomReport({
    required this.id,
    required this.nameAr,
    this.description,
    this.isActive = true,
    required this.config,
    required this.createdAt,
  });

  factory CustomReport.fromJson(Map<String, dynamic> j) => CustomReport(
        id: j['id'] as String,
        nameAr: j['name_ar'] as String,
        description: j['description'] as String?,
        isActive: j['is_active'] as bool? ?? true,
        config: CustomReportConfig.fromJson(
            j['report_config'] as Map<String, dynamic>? ?? {}),
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toUpsertJson() => {
        'name_ar': nameAr,
        'description': description,
        'is_active': isActive,
        'report_config': config.toJson(),
      };
}
