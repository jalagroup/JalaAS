import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../models/custom_report.dart';
import '../../../utils/api_exception.dart';
import '../../../utils/constants.dart';

// PA proxy endpoints — same as used in almira_stock_report_screen.dart
const _kJalafUrl =
    'https://default2cf7d6cd9c34481c9d7810b848e31f.4f.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/74ef47faa1034d21a92631a0e89763e4/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=U95UQ9ohOeEJFWWXpCXNIQMOFhf-XIGBbq9pRYS_7m8';
const _kZfiUrl =
    'https://default2cf7d6cd9c34481c9d7810b848e31f.4f.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/ef2d8d742a044117891e4a3a314686f8/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=JTI-TSXG5nQVrhgF1LmobbD5FkrCxV-lwtz7dMSk4Ig';

class ReportViewerScreen extends StatefulWidget {
  final CustomReport report;

  const ReportViewerScreen({super.key, required this.report});

  @override
  State<ReportViewerScreen> createState() => _ReportViewerScreenState();
}

class _ReportViewerScreenState extends State<ReportViewerScreen> {
  static const _primary = Color(AppConstants.primaryColor);

  // User-entered values for each input parameter
  final Map<String, String> _inputValues = {};

  bool _loading = false;
  List<Map<String, dynamic>> _rows = [];
  String? _errorMessage;
  bool _hasRun = false;

  String? _sortField;
  bool _sortAsc = true;

  late final ScrollController _headerHScroll;
  late final ScrollController _dataHScroll;
  late final ScrollController _dataVScroll;

  CustomReportConfig get _cfg => widget.report.config;
  List<ReportField> get _visibleFields =>
      _cfg.fields.where((f) => f.visible).toList();

  @override
  void initState() {
    super.initState();
    _headerHScroll = ScrollController();
    _dataHScroll = ScrollController();
    _dataVScroll = ScrollController();
    _headerHScroll.addListener(_syncHeader);
    _dataHScroll.addListener(_syncData);

    // Pre-fill default values
    for (final input in _cfg.inputs) {
      _inputValues[input.key] = _resolveDefault(input.defaultValue);
    }

    // Auto-run if no inputs
    if (_cfg.inputs.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  @override
  void dispose() {
    _headerHScroll.dispose();
    _dataHScroll.dispose();
    _dataVScroll.dispose();
    super.dispose();
  }

  void _syncHeader() {
    if (_dataHScroll.hasClients &&
        _dataHScroll.offset != _headerHScroll.offset) {
      _dataHScroll.jumpTo(_headerHScroll.offset);
    }
  }

  void _syncData() {
    if (_headerHScroll.hasClients &&
        _headerHScroll.offset != _dataHScroll.offset) {
      _headerHScroll.jumpTo(_dataHScroll.offset);
    }
  }

  String _resolveDefault(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final today = DateTime.now();
    switch (raw) {
      case 'today':
        return DateFormat('yyyy-MM-dd').format(today);
      case 'month_start':
        return DateFormat('yyyy-MM-dd')
            .format(DateTime(today.year, today.month, 1));
      case 'year_start':
        return DateFormat('yyyy-MM-dd').format(DateTime(today.year, 1, 1));
      default:
        return raw;
    }
  }

  String _buildInnerUrl() {
    final company = _cfg.company == ReportCompany.jalaf ? 'jalaf' : 'zfi';
    final base =
        'https://gw.bisan.com/api/v2/$company/${_cfg.endpoint}';

    // Merge fixed params + user-supplied input values
    final allParams = <String, String>{};
    allParams.addAll(_cfg.fixedParams);
    for (final input in _cfg.inputs) {
      final val = _inputValues[input.key] ?? '';
      if (val.isNotEmpty) {
        allParams[input.effectiveParamName] = val;
      }
    }

    // Build search string
    final searchParts =
        allParams.entries.map((e) => '${e.key}:${e.value}').join(',');

    // Build fields string from visible fields
    final fieldKeys =
        _cfg.fields.map((f) => f.key.replaceAll('.', '.')).join(',');

    final query =
        'search=$searchParts${fieldKeys.isNotEmpty ? '&fields=$fieldKeys' : ''}';
    return '$base?$query';
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _hasRun = true;
    });

    try {
      final innerUrl = _buildInnerUrl();
      final paUrl =
          _cfg.company == ReportCompany.jalaf ? _kJalafUrl : _kZfiUrl;

      final response = await http.post(
        Uri.parse(paUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': innerUrl, 'method': 'GET'}),
      );

      if (response.statusCode != 200) {
        throw ApiException.fromResponse(response);
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      var rows =
          (decoded['rows'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

      // Group rows if needed
      if (_cfg.groupByField != null && _cfg.groupByField!.isNotEmpty) {
        rows = _groupRows(rows, _cfg.groupByField!);
      }

      // Apply post-fetch filters
      rows = rows
          .where((r) => _cfg.filters.every((f) => f.matches(r)))
          .toList();

      setState(() => _rows = rows);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _groupRows(
      List<Map<String, dynamic>> rows, String groupField) {
    final grouped = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final key = _extractField(row, groupField)?.toString() ?? '';
      if (!grouped.containsKey(key)) {
        grouped[key] = Map<String, dynamic>.from(row);
      } else {
        // Sum numeric fields
        for (final field in _cfg.fields) {
          if (field.format == FieldFormat.number ||
              field.format == FieldFormat.currency) {
            final existing =
                double.tryParse(grouped[key]![field.key]?.toString() ?? '0') ??
                    0;
            final incoming =
                double.tryParse(row[field.key]?.toString() ?? '0') ?? 0;
            grouped[key]![field.key] = (existing + incoming).toString();
          }
        }
      }
    }
    return grouped.values.toList();
  }

  dynamic _extractField(Map<String, dynamic> row, String key) {
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

  List<Map<String, dynamic>> get _sortedRows {
    if (_sortField == null) return _rows;
    final sorted = List<Map<String, dynamic>>.from(_rows);
    sorted.sort((a, b) {
      final va = _extractField(a, _sortField!)?.toString() ?? '';
      final vb = _extractField(b, _sortField!)?.toString() ?? '';
      final na = double.tryParse(va);
      final nb = double.tryParse(vb);
      int cmp;
      if (na != null && nb != null) {
        cmp = na.compareTo(nb);
      } else {
        cmp = va.compareTo(vb);
      }
      return _sortAsc ? cmp : -cmp;
    });
    return sorted;
  }

  String _format(dynamic raw, FieldFormat fmt) {
    if (raw == null) return '';
    switch (fmt) {
      case FieldFormat.number:
        final n = double.tryParse(raw.toString());
        if (n == null) return raw.toString();
        return NumberFormat('#,##0.##').format(n);
      case FieldFormat.currency:
        final n = double.tryParse(raw.toString());
        if (n == null) return raw.toString();
        return NumberFormat('#,##0.00').format(n);
      case FieldFormat.percentage:
        final n = double.tryParse(raw.toString());
        if (n == null) return raw.toString();
        return '${NumberFormat('#,##0.##').format(n)}%';
      default:
        return raw.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasInputs = _cfg.inputs.isNotEmpty;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: _primary,
          title: Text(
            widget.report.nameAr,
            style: const TextStyle(
                color: _primary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          actions: [
            if (_hasRun)
              IconButton(
                icon: const Icon(Icons.refresh_outlined),
                tooltip: 'إعادة تحميل',
                onPressed: _loading ? null : _run,
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: Colors.grey.shade200),
          ),
        ),
        body: Column(
          children: [
            // ── Input panel ──────────────────────────────────────────────────
            if (hasInputs)
              _InputPanel(
                inputs: _cfg.inputs,
                values: _inputValues,
                onChanged: (k, v) => setState(() => _inputValues[k] = v),
                onRun: _loading ? null : _run,
              ),
            // ── Content ──────────────────────────────────────────────────────
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 12),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade600)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _run,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    if (!_hasRun) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('أدخل البيانات واضغط تشغيل',
                style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }
    if (_rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('لا توجد نتائج',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade500)),
          ],
        ),
      );
    }
    return _buildTable();
  }

  Widget _buildTable() {
    final fields = _visibleFields;
    if (fields.isEmpty) {
      return const Center(child: Text('لا توجد أعمدة مرئية'));
    }

    final totalWidth = fields.fold(0.0, (s, f) => s + f.width);
    final sorted = _sortedRows;

    // Compute summary sums for numeric fields
    final sums = <String, double>{};
    if (_cfg.showSummaryRow) {
      for (final f in fields) {
        if (f.format == FieldFormat.number || f.format == FieldFormat.currency) {
          sums[f.key] = sorted.fold(0.0, (s, row) {
            final v = _extractField(row, f.key);
            return s + (double.tryParse(v?.toString() ?? '') ?? 0);
          });
        }
      }
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Sticky header ────────────────────────────────────────────────
          SingleChildScrollView(
            controller: _headerHScroll,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              width: totalWidth,
              child: Container(
                color: const Color(AppConstants.primaryColor),
                child: Row(
                  children: fields.map((f) {
                    final isSorted = _sortField == f.key;
                    return GestureDetector(
                      onTap: f.sortable
                          ? () => setState(() {
                                if (_sortField == f.key) {
                                  _sortAsc = !_sortAsc;
                                } else {
                                  _sortField = f.key;
                                  _sortAsc = true;
                                }
                              })
                          : null,
                      child: SizedBox(
                        width: f.width,
                        height: 48,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  f.labelAr,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (f.sortable) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  isSorted
                                      ? (_sortAsc
                                          ? Icons.arrow_upward
                                          : Icons.arrow_downward)
                                      : Icons.unfold_more,
                                  size: 14,
                                  color: isSorted
                                      ? Colors.white
                                      : Colors.white54,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          // ── Data rows ─────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              controller: _dataVScroll,
              child: SingleChildScrollView(
                controller: _dataHScroll,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  width: totalWidth,
                  child: Column(
                    children: [
                      ...sorted.asMap().entries.map((e) {
                        final i = e.key;
                        final row = e.value;
                        final isEven = i.isEven;
                        return Container(
                          color: isEven
                              ? Colors.grey.shade50
                              : Colors.white,
                          child: Row(
                            children: fields.map((f) {
                              final raw = _extractField(row, f.key);
                              final text = _format(raw, f.format);
                              return SizedBox(
                                width: f.width,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  child: Text(
                                    text,
                                    textAlign: _textAlign(f.format),
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: f.wrapLines,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }),
                      // Summary row
                      if (_cfg.showSummaryRow && sums.isNotEmpty)
                        Container(
                          color: const Color(AppConstants.primaryColor)
                              .withValues(alpha: 0.08),
                          child: Row(
                            children: fields.map((f) {
                              final hasSum = sums.containsKey(f.key);
                              return SizedBox(
                                width: f.width,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 10),
                                  child: Text(
                                    hasSum
                                        ? _format(sums[f.key], f.format)
                                        : (fields.first == f ? 'الإجمالي' : ''),
                                    textAlign: hasSum
                                        ? TextAlign.center
                                        : TextAlign.right,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── Footer: row count ─────────────────────────────────────────────
          Container(
            color: Colors.grey.shade50,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('${sorted.length} سجل',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextAlign _textAlign(FieldFormat fmt) {
    switch (fmt) {
      case FieldFormat.number:
      case FieldFormat.currency:
      case FieldFormat.percentage:
        return TextAlign.center;
      default:
        return TextAlign.right;
    }
  }
}

// ── Input panel ───────────────────────────────────────────────────────────────

class _InputPanel extends StatelessWidget {
  final List<ReportInput> inputs;
  final Map<String, String> values;
  final void Function(String key, String value) onChanged;
  final VoidCallback? onRun;

  const _InputPanel({
    required this.inputs,
    required this.values,
    required this.onChanged,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              ...inputs.map((input) => SizedBox(
                    width: 180,
                    child: _buildInputField(context, input),
                  )),
              FilledButton.icon(
                onPressed: onRun,
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(AppConstants.accentColor)),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('تشغيل'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(BuildContext context, ReportInput input) {
    final val = values[input.key] ?? '';

    switch (input.type) {
      case ReportInputType.date:
        return GestureDetector(
          onTap: () async {
            final parsed = DateTime.tryParse(val) ?? DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: parsed,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              onChanged(
                  input.key, DateFormat('yyyy-MM-dd').format(picked));
            }
          },
          child: AbsorbPointer(
            child: TextFormField(
              initialValue: val.isEmpty
                  ? DateFormat('yyyy-MM-dd').format(DateTime.now())
                  : val,
              decoration: InputDecoration(
                labelText: input.labelAr,
                isDense: true,
                suffixIcon: const Icon(Icons.calendar_today, size: 16),
              ),
            ),
          ),
        );

      case ReportInputType.select:
        return DropdownButtonFormField<String>(
          value: val.isEmpty ? null : val,
          isExpanded: true,
          decoration:
              InputDecoration(labelText: input.labelAr, isDense: true),
          items: input.options.asMap().entries.map((e) {
            final label = e.key < input.optionLabels.length
                ? input.optionLabels[e.key]
                : e.value;
            return DropdownMenuItem(
                value: e.value,
                child: Text(label, style: const TextStyle(fontSize: 13)));
          }).toList(),
          onChanged: (v) => onChanged(input.key, v ?? ''),
        );

      default:
        return TextFormField(
          initialValue: val,
          decoration: InputDecoration(
              labelText: input.labelAr, isDense: true),
          onChanged: (v) => onChanged(input.key, v),
        );
    }
  }
}
