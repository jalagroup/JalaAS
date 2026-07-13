import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:jala_as/models/quality_models.dart';
import 'package:jala_as/models/report_models.dart';
import 'package:jala_as/screens/utils/file_utils.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/helpers.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF0891B2);
const _kBg = Color(0xFFF1F5F9);
const _kBorder = Color(0xFFE2E8F0);
const _kTextPrimary = Color(0xFF0F172A);
const _kTextSecondary = Color(0xFF64748B);
const _kSuccess = Color(0xFF059669);

// ─── Screen ───────────────────────────────────────────────────────────────────

class ReportListResponsesScreen extends StatefulWidget {
  final ReportListGroup group;
  final ReportList reportList;

  const ReportListResponsesScreen({
    super.key,
    required this.group,
    required this.reportList,
  });

  @override
  State<ReportListResponsesScreen> createState() =>
      _ReportListResponsesScreenState();
}

class _ReportListResponsesScreenState
    extends State<ReportListResponsesScreen> {
  List<ReportListResponse> _responses = [];
  Map<String, String> _userNames = {}; // userId → username
  bool _loading = true;
  bool _exporting = false;

  // Filters
  DateTime? _fromDate;
  DateTime? _toDate;
  final Map<String, String?> _detFilter = {}; // determinantId → selectedValue

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final responses = await SupabaseService.getReportListResponses(
          widget.reportList.id);
      final users = await SupabaseService.getQualityControllerUsers();
      final nameMap = {for (final u in users) u.id: u.username};
      setState(() {
        _responses = responses;
        _userNames = nameMap;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) Helpers.showSnackBar(context, 'فشل في تحميل البيانات', isError: true);
    }
  }

  List<ReportListResponse> get _filtered {
    var list = _responses;
    if (_fromDate != null) {
      list = list
          .where((r) =>
              !r.responseDate.isBefore(DateTime(_fromDate!.year,
                  _fromDate!.month, _fromDate!.day)))
          .toList();
    }
    if (_toDate != null) {
      list = list
          .where((r) =>
              !r.responseDate.isAfter(DateTime(
                  _toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59)))
          .toList();
    }
    for (final det in widget.reportList.determinants) {
      final sel = _detFilter[det.id];
      if (sel != null && sel.isNotEmpty) {
        list = list
            .where((r) =>
                r.determinantValues[det.id]?.toString() == sel)
            .toList();
      }
    }
    return list;
  }

  // ── Export ───────────────────────────────────────────────────

  Future<void> _exportExcel() async {
    setState(() => _exporting = true);
    try {
      final bytes = await _buildExcel();
      final fileName =
          'تقرير_${widget.reportList.title}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      await FileUtils.instance.downloadFile(bytes, fileName);
    } catch (e) {
      if (mounted)
        Helpers.showSnackBar(context, 'فشل في تصدير Excel: $e',
            isError: true);
    } finally {
      setState(() => _exporting = false);
    }
  }

  Future<Uint8List> _buildExcel() async {
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = widget.reportList.title.length > 31
        ? widget.reportList.title.substring(0, 31)
        : widget.reportList.title;

    // RTL
    sheet.getRangeByName('A1:ZZ9999').cellStyle.hAlign =
        xlsio.HAlignType.right;

    final responses = _filtered;
    final rl = widget.reportList;

    // ── Header row ──────────────────────────────────────────────
    const headerBg = '#1E3A5F';
    const headerFg = '#FFFFFF';

    final fixedHeaders = ['#', 'المستخدم', 'التاريخ', 'وقت الإرسال'];
    final detHeaders = rl.determinants.map((d) => d.name).toList();
    final fieldHeaders = rl.fields.map((f) => f.title).toList();

    final allHeaders = [...fixedHeaders, ...detHeaders, ...fieldHeaders];
    final totalCols = allHeaders.length;

    for (int c = 0; c < totalCols; c++) {
      final cell = sheet.getRangeByIndex(1, c + 1);
      cell.setText(allHeaders[c]);
      cell.cellStyle
        ..bold = true
        ..fontSize = 11
        ..fontColor = headerFg
        ..backColor = headerBg
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;
    }
    sheet.setRowHeightInPixels(1, 36);

    // ── Data rows ───────────────────────────────────────────────
    const evenBg = '#F8FAFC';
    const oddBg = '#FFFFFF';

    for (int i = 0; i < responses.length; i++) {
      final r = responses[i];
      final row = i + 2;
      final bg = (i % 2 == 0) ? evenBg : oddBg;
      int col = 1;

      void writeCell(String text, {bool wrap = false, int? maxLines}) {
        final cell = sheet.getRangeByIndex(row, col++);
        cell.setText(text);
        cell.cellStyle
          ..backColor = bg
          ..borders.all.lineStyle = xlsio.LineStyle.thin
          ..wrapText = wrap;
        if (wrap && maxLines != null && maxLines > 1) {
          cell.cellStyle.vAlign = xlsio.VAlignType.top;
        }
      }

      writeCell('${i + 1}');
      writeCell(_userNames[r.userId] ?? r.userId);
      writeCell(ArabicDate.format(r.responseDate));
      writeCell(ArabicDate.format(r.submittedAt));

      for (final det in rl.determinants) {
        writeCell(r.determinantValues[det.id]?.toString() ?? '');
      }

      int maxLines = 1;
      for (final field in rl.fields) {
        final text = r.fieldResponses[field.id] ?? '';
        final lines = '\n'.allMatches(text).length + 1;
        if (lines > maxLines) maxLines = lines;
        final cell = sheet.getRangeByIndex(row, col++);
        cell.setText(text);
        cell.cellStyle
          ..backColor = bg
          ..borders.all.lineStyle = xlsio.LineStyle.thin
          ..wrapText = true
          ..vAlign = xlsio.VAlignType.top;
      }

      final rowHeight =
          (28 + (maxLines - 1) * 16).clamp(28, 200).toDouble();
      sheet.setRowHeightInPixels(row, rowHeight);
    }

    // ── Column widths ───────────────────────────────────────────
    sheet.setColumnWidthInPixels(1, 40); // #
    sheet.setColumnWidthInPixels(2, 130); // user
    sheet.setColumnWidthInPixels(3, 110); // date
    sheet.setColumnWidthInPixels(4, 110); // submitted at
    for (int c = 5; c <= 4 + detHeaders.length; c++) {
      sheet.setColumnWidthInPixels(c, 120);
    }
    for (int c = 5 + detHeaders.length;
        c <= 4 + detHeaders.length + fieldHeaders.length;
        c++) {
      sheet.setColumnWidthInPixels(c, 280);
    }

    // ── Summary block below data ─────────────────────────────────
    final summaryStartRow = responses.length + 3;
    final summaryCell = sheet.getRangeByIndex(summaryStartRow, 1);
    summaryCell.setText('إجمالي الردود: ${responses.length}');
    summaryCell.cellStyle
      ..bold = true
      ..fontSize = 11
      ..fontColor = '#1E3A5F';

    final bytes = Uint8List.fromList(workbook.saveAsStream());
    workbook.dispose();
    return bytes;
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          iconTheme: const IconThemeData(color: _kTextPrimary),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.reportList.title,
                  style: const TextStyle(
                      color: _kTextPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
              Text(widget.group.title,
                  style: const TextStyle(
                      color: _kTextSecondary, fontSize: 11)),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _kBorder),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kSuccess,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
                icon: _exporting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_rounded, size: 16),
                label: const Text('تصدير Excel',
                    style: TextStyle(fontSize: 12)),
                onPressed: _exporting ? null : _exportExcel,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildFilterBar(),
            _buildSummaryBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: _buildTable(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filter bar ───────────────────────────────────────────────

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _DatePicker(
              label: 'من',
              date: _fromDate,
              onPick: (d) => setState(() => _fromDate = d),
              onClear: () => setState(() => _fromDate = null),
            ),
            const SizedBox(width: 10),
            _DatePicker(
              label: 'إلى',
              date: _toDate,
              onPick: (d) => setState(() => _toDate = d),
              onClear: () => setState(() => _toDate = null),
            ),
            ...widget.reportList.determinants.map((det) {
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _DetFilter(
                  determinant: det,
                  selected: _detFilter[det.id],
                  onChanged: (v) =>
                      setState(() => _detFilter[det.id] = v),
                ),
              );
            }),
            if (_fromDate != null ||
                _toDate != null ||
                _detFilter.values.any((v) => v != null))
              TextButton.icon(
                onPressed: () => setState(() {
                  _fromDate = null;
                  _toDate = null;
                  _detFilter.clear();
                }),
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('مسح الفلاتر',
                    style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar() {
    final count = _filtered.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _kAccent.withValues(alpha: 0.06),
      child: Row(
        children: [
          const Icon(Icons.bar_chart_rounded, size: 16, color: _kAccent),
          const SizedBox(width: 6),
          Text('$count رد',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kAccent)),
        ],
      ),
    );
  }

  // ── Table ────────────────────────────────────────────────────

  Widget _buildTable() {
    final responses = _filtered;
    final rl = widget.reportList;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          headingRowColor:
              WidgetStateProperty.all(const Color(0xFF1E3A5F)),
          headingTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12),
          dataRowColor: WidgetStateProperty.resolveWith((states) {
            return Colors.white;
          }),
          border: TableBorder.all(color: _kBorder, width: 0.5),
          columns: [
            const DataColumn(label: Text('#')),
            const DataColumn(label: Text('المستخدم')),
            const DataColumn(label: Text('التاريخ')),
            ...rl.determinants.map(
                (d) => DataColumn(label: Text(d.name))),
            ...rl.fields
                .map((f) => DataColumn(label: Text(f.title))),
          ],
          rows: List.generate(responses.length, (i) {
            final r = responses[i];
            return DataRow(
              color: WidgetStateProperty.all(
                  i % 2 == 0
                      ? const Color(0xFFF8FAFC)
                      : Colors.white),
              cells: [
                DataCell(Text('${i + 1}',
                    style:
                        const TextStyle(fontSize: 12, color: _kTextSecondary))),
                DataCell(Text(
                    _userNames[r.userId] ?? r.userId,
                    style: const TextStyle(
                        fontSize: 12, color: _kTextPrimary))),
                DataCell(Text(ArabicDate.format(r.responseDate),
                    style: const TextStyle(
                        fontSize: 12, color: _kTextPrimary))),
                ...rl.determinants.map((d) => DataCell(Text(
                    r.determinantValues[d.id]?.toString() ?? '-',
                    style: const TextStyle(
                        fontSize: 12, color: _kTextPrimary)))),
                ...rl.fields.map((f) => DataCell(
                      ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxWidth: 260),
                        child: Text(
                          r.fieldResponses[f.id] ?? '-',
                          style: const TextStyle(
                              fontSize: 12, color: _kTextPrimary),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onTap: () => _showResponseDetail(r),
                    )),
              ],
            );
          }),
        ),
      ),
    );
  }

  void _showResponseDetail(ReportListResponse r) {
    final rl = widget.reportList;
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.assignment_rounded,
                  color: _kAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_userNames[r.userId] ?? r.userId,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(ArabicDate.format(r.responseDate),
                        style: const TextStyle(
                            fontSize: 12, color: _kTextSecondary)),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rl.determinants.isNotEmpty) ...[
                    const Text('المحددات',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _kAccent)),
                    const SizedBox(height: 8),
                    ...rl.determinants.map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Text('${d.name}: ',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: _kTextPrimary)),
                              Text(
                                  r.determinantValues[d.id]
                                          ?.toString() ??
                                      '-',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: _kTextSecondary)),
                            ],
                          ),
                        )),
                    const Divider(),
                  ],
                  const Text('الحقول',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kAccent)),
                  const SizedBox(height: 8),
                  ...rl.fields.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.title,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _kTextPrimary)),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _kBorder),
                              ),
                              child: Text(
                                r.fieldResponses[f.id]?.isEmpty == false
                                    ? r.fieldResponses[f.id]!
                                    : '—',
                                style: const TextStyle(
                                    fontSize: 12, color: _kTextPrimary),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assignment_outlined,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('لا توجد ردود بعد',
              style: TextStyle(color: _kTextSecondary, fontSize: 15)),
        ],
      ),
    );
  }
}

// ─── Filter widgets ───────────────────────────────────────────────────────────

class _DatePicker extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime> onPick;
  final VoidCallback onClear;

  const _DatePicker({
    required this.label,
    required this.date,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasDate = date != null;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: hasDate ? _kAccent.withValues(alpha: 0.08) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: hasDate ? _kAccent.withValues(alpha: 0.4) : _kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today,
                size: 13,
                color: hasDate ? _kAccent : _kTextSecondary),
            const SizedBox(width: 5),
            Text(
              hasDate
                  ? '$label: ${date!.day}/${date!.month}/${date!.year}'
                  : '$label تاريخ',
              style: TextStyle(
                  fontSize: 12,
                  color: hasDate ? _kAccent : _kTextSecondary),
            ),
            if (hasDate) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close,
                    size: 12, color: _kAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetFilter extends StatelessWidget {
  final Determinant determinant;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _DetFilter({
    required this.determinant,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasFilter = selected != null && selected!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasFilter ? _kAccent.withValues(alpha: 0.08) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: hasFilter ? _kAccent.withValues(alpha: 0.4) : _kBorder),
      ),
      child: DropdownButton<String>(
        value: selected,
        hint: Text(determinant.name,
            style: const TextStyle(fontSize: 12, color: _kTextSecondary)),
        isDense: true,
        underline: const SizedBox(),
        style: const TextStyle(fontSize: 12, color: _kTextPrimary),
        items: [
          DropdownMenuItem<String>(
              value: null,
              child: Text('الكل — ${determinant.name}',
                  style: const TextStyle(
                      fontSize: 12, color: _kTextSecondary))),
          ...determinant.options.map((o) => DropdownMenuItem<String>(
                value: o.value,
                child: Text(o.value,
                    style: const TextStyle(fontSize: 12)),
              )),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
