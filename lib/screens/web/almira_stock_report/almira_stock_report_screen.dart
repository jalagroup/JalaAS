// lib/screens/web/almira_stock_report/almira_stock_report_screen.dart

import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../utils/api_exception.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';

class AlmiraStockReportScreen extends StatefulWidget {
  const AlmiraStockReportScreen({super.key});

  @override
  State<AlmiraStockReportScreen> createState() =>
      _AlmiraStockReportScreenState();
}

class _AlmiraStockReportScreenState extends State<AlmiraStockReportScreen> {
  List<_StockRow> _rows = [];
  bool _isLoading = true;
  String? _errorMessage;

  String? _sortColumn;
  bool _sortAscending = false;

  late final ScrollController _headerHScroll;
  late final ScrollController _dataHScroll;
  late final ScrollController _dataVScroll;

  static const _jalafUrl =
      'https://default2cf7d6cd9c34481c9d7810b848e31f.4f.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/74ef47faa1034d21a92631a0e89763e4/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=U95UQ9ohOeEJFWWXpCXNIQMOFhf-XIGBbq9pRYS_7m8';
  static const _zfiUrl =
      'https://default2cf7d6cd9c34481c9d7810b848e31f.4f.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/ef2d8d742a044117891e4a3a314686f8/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=JTI-TSXG5nQVrhgF1LmobbD5FkrCxV-lwtz7dMSk4Ig';

  static const _fields =
      'item,item.name,warehouse,warehouse.name,binNum,item.reportUnit,partNumber,count,packVolume,begBalance,rptQntIn,rptQntOut,change,endBalance';

  // API 1: JALAF posted (مرحل) – all warehouses 0002→1050
  static const _api1InnerUrl =
      'https://gw.bisan.com/api/v2/jalaf/REPORT/stockBalance?search=fromDate:2025-01-01,toDate:2026-12-31,warehouse_From:0002,warehouse_To:1050,brand_From:309,brand_To:309,orderBy:%D8%B5%D9%86%D9%81,includeZeroBalances:true,byWarehouse:true,lg_status:posted,whsGrp:02&fields=$_fields';

  // API 2: JALAF saved (محفوظ) – all warehouses 0002→1050
  static const _api2InnerUrl =
      'https://gw.bisan.com/api/v2/jalaf/REPORT/stockBalance?search=fromDate:2025-01-01,toDate:2026-12-31,warehouse_From:0002,warehouse_To:1050,brand_From:309,brand_To:309,orderBy:%D8%B5%D9%86%D9%81,includeZeroBalances:true,byWarehouse:true,lg_status:saved,whsGrp:02&fields=$_fields';

  // API 3: ZFI production (إنتاج) – warehouse 0001 only
  static const _api3InnerUrl =
      'https://gw.bisan.com/api/v2/zfi/REPORT/stockBalance?search=fromDate:2025-01-01,toDate:2026-12-31,brand_From:309,brand_To:309,orderBy:%D8%B5%D9%86%D9%81,includeZeroBalances:true,byWarehouse:true,warehouse_From:0001,warehouse_To:0001,lg_status:%D9%85%D8%B1%D8%AD%D9%84&fields=$_fields';

  // API 4: ZFI reserved (محجوز) – warehouse 0025 only
  static const _api4InnerUrl =
      'https://gw.bisan.com/api/v2/zfi/REPORT/stockBalance?search=fromDate:2025-01-01,toDate:2026-12-31,brand_From:309,brand_To:309,orderBy:%D8%B5%D9%86%D9%81,includeZeroBalances:true,byWarehouse:true,warehouse_From:0025,warehouse_To:0025,lg_status:%D9%85%D8%B1%D8%AD%D9%84&fields=$_fields';

  @override
  void initState() {
    super.initState();
    _headerHScroll = ScrollController();
    _dataHScroll = ScrollController();
    _dataVScroll = ScrollController();
    _headerHScroll.addListener(_syncFromHeader);
    _dataHScroll.addListener(_syncFromData);
    _fetchData();
  }

  void _syncFromHeader() {
    if (_dataHScroll.hasClients &&
        _dataHScroll.offset != _headerHScroll.offset) {
      _dataHScroll.jumpTo(_headerHScroll.offset);
    }
  }

  void _syncFromData() {
    if (_headerHScroll.hasClients &&
        _headerHScroll.offset != _dataHScroll.offset) {
      _headerHScroll.jumpTo(_dataHScroll.offset);
    }
  }

  @override
  void dispose() {
    _headerHScroll.dispose();
    _dataHScroll.dispose();
    _dataVScroll.dispose();
    super.dispose();
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  double _parseNum(String s) =>
      double.tryParse(s.replaceAll(',', '')) ?? 0.0;

  // Returns true for warehouses excluded from JALAF total columns:
  // warehouse 0010 and any warehouse in the 2000–2999 range.
  bool _isExcludedWarehouse(String wh) {
    if (wh == '0010') return true;
    final code = int.tryParse(wh) ?? -1;
    return code >= 2000 && code <= 2999;
  }

  String _formatNum(double v) {
    if (v == 0.0) return '0.00';
    return v.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  // ── sorting ───────────────────────────────────────────────────────────────

  List<_StockRow> get _sortedRows {
    if (_sortColumn == null) return _rows;
    final sorted = List<_StockRow>.from(_rows);
    sorted.sort((a, b) {
      final va = _colValue(a, _sortColumn!);
      final vb = _colValue(b, _sortColumn!);
      return _sortAscending ? va.compareTo(vb) : vb.compareTo(va);
    });
    return sorted;
  }

  double _colValue(_StockRow r, String col) {
    switch (col) {
      case 'marhol':
        return r.jalafMarhol;
      case 'marholMain':
        return r.jalafMarholMain;
      case 'mahfuz':
        return r.jalafMahfuz;
      case 'mahfuzMain':
        return r.jalafMahfuzMain;
      case 'intaj':
        return r.zfiIntaj;
      case 'reserved':
        return r.zfiReserved;
      default:
        return 0.0;
    }
  }

  void _sortByColumn(String col) {
    setState(() {
      if (_sortColumn == col) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = col;
        _sortAscending = false;
      }
    });
  }

  // ── data fetching ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _fetchApiRows(
      String endpointUrl, String innerUrl) async {
    final response = await http.post(
      Uri.parse(endpointUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'url': innerUrl, 'method': 'GET'}),
    );
    if (response.statusCode != 200) {
      throw ApiException.fromResponse(response);
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = decoded['rows'] as List<dynamic>? ?? [];
    return rows.cast<Map<String, dynamic>>();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _fetchApiRows(_jalafUrl, _api1InnerUrl),
        _fetchApiRows(_jalafUrl, _api2InnerUrl),
        _fetchApiRows(_zfiUrl, _api3InnerUrl),
        _fetchApiRows(_zfiUrl, _api4InnerUrl),
      ]);

      // APIs 1 & 2 return multiple rows per item (one per warehouse).
      // Group them by item code so we can sum all warehouses and also
      // extract warehouse-0002 values separately.
      final api1ByItem = <String, List<Map<String, dynamic>>>{};
      for (final r in results[0]) {
        api1ByItem.putIfAbsent(r['item'] as String? ?? '', () => []).add(r);
      }

      final api2ByItem = <String, List<Map<String, dynamic>>>{};
      for (final r in results[1]) {
        api2ByItem.putIfAbsent(r['item'] as String? ?? '', () => []).add(r);
      }

      // APIs 3 & 4 target a single warehouse each → one row per item.
      final api3Map = {for (final r in results[2]) r['item'] as String: r};
      final api4Map = {for (final r in results[3]) r['item'] as String: r};

      // Build the master item list from unique item codes in API 1.
      final seen = <String>{};
      final merged = <_StockRow>[];

      for (final r in results[0]) {
        final code = r['item'] as String? ?? '';
        if (!seen.add(code)) continue;

        final api1Rows = api1ByItem[code] ?? [];
        final api2Rows = api2ByItem[code] ?? [];

        // Total endBalance across warehouses, excluding 0010 and 2000–2999
        final marholTotal = api1Rows
            .where((x) => !_isExcludedWarehouse(x['warehouse'] as String? ?? ''))
            .fold(0.0, (s, x) => s + _parseNum(x['endBalance'] as String? ?? '0'));
        final mahfuzTotal = api2Rows
            .where((x) => !_isExcludedWarehouse(x['warehouse'] as String? ?? ''))
            .fold(0.0, (s, x) => s + _parseNum(x['endBalance'] as String? ?? '0'));

        // endBalance for warehouse 0002 only (المخزن الرئيسي)
        final marholMain = api1Rows
            .where((x) => x['warehouse'] == '0002')
            .fold(
                0.0,
                (s, x) =>
                    s + _parseNum(x['endBalance'] as String? ?? '0'));
        final mahfuzMain = api2Rows
            .where((x) => x['warehouse'] == '0002')
            .fold(
                0.0,
                (s, x) =>
                    s + _parseNum(x['endBalance'] as String? ?? '0'));

        merged.add(_StockRow(
          itemCode: code,
          itemName: r['item.name'] as String? ?? '',
          jalafMarhol: marholTotal,
          jalafMarholMain: marholMain,
          jalafMahfuz: mahfuzTotal,
          jalafMahfuzMain: mahfuzMain,
          zfiIntaj:
              _parseNum(api3Map[code]?['endBalance'] as String? ?? '0'),
          zfiReserved:
              _parseNum(api4Map[code]?['endBalance'] as String? ?? '0'),
        ));
      }

      if (mounted) {
        setState(() {
          _rows = merged;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
        Helpers.showApiErrorDialog(context, e);
      }
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isMobile = screenWidth < 768;
    final pad = isMobile ? 16.0 : 24.0;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back,
                color: Color(AppConstants.primaryColor)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            isDesktop ? 'تقرير أرصدة المخزون - الميرا' : 'أرصدة الميرا',
            style: const TextStyle(
              color: Color(AppConstants.primaryColor),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh,
                  color: Color(AppConstants.primaryColor)),
              tooltip: 'تحديث',
              onPressed: _isLoading ? null : _fetchData,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: isDesktop ? 1200 : double.infinity),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card – fixed height
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, pad, pad, pad / 2),
                  child: _buildHeaderSection(today, isMobile),
                ),
                // Table – fills all remaining screen height
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
                    child: _buildContent(isMobile),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(String today, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isMobile ? 50 : 60,
            height: isMobile ? 50 : 60,
            decoration: BoxDecoration(
              color: const Color(AppConstants.accentColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                color: Colors.white, size: 24),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تقرير أرصدة المخزون - الميرا',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(AppConstants.primaryColor),
                  ),
                ),
                SizedBox(height: isMobile ? 4 : 6),
                Text(
                  'رصيد المرحل والمحفوظ وإنتاج ZFI - بتاريخ: $today',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (_rows.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(AppConstants.accentColor)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_rows.length} صنف',
                style: const TextStyle(
                  color: Color(AppConstants.accentColor),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isMobile) {
    if (_isLoading) return _buildLoadingState();
    if (_errorMessage != null) return _buildErrorState();
    if (_rows.isEmpty) return _buildEmptyState();
    return _buildTable(isMobile);
  }

  // ── states ────────────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.05),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                  Color(AppConstants.accentColor)),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'جاري تحميل البيانات...',
            style: TextStyle(
              color: Color(AppConstants.primaryColor),
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.05),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(Icons.inventory_2_outlined,
                size: 80, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 24),
          Text(
            'لا توجد بيانات',
            style: TextStyle(
                fontSize: 20,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'لم يتم العثور على أرصدة مخزون',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConstants.accentColor),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('إعادة التحميل',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.05),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(Icons.error_outline,
                size: 80, color: Colors.red.shade300),
          ),
          const SizedBox(height: 24),
          Text(
            'فشل في تحميل البيانات',
            style: TextStyle(
                fontSize: 20,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchData,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة',
                style: TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConstants.accentColor),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // ── table ─────────────────────────────────────────────────────────────────

  Widget _buildTable(bool isMobile) {
    const nameWidth = 200.0;
    const numWidth = 120.0;
    // 7 columns: name + 6 numeric
    const totalWidth = nameWidth + numWidth * 6;

    final rows = _sortedRows;

    final tMarhol = rows.fold(0.0, (s, r) => s + r.jalafMarhol);
    final tMarholMain = rows.fold(0.0, (s, r) => s + r.jalafMarholMain);
    final tMahfuz = rows.fold(0.0, (s, r) => s + r.jalafMahfuz);
    final tMahfuzMain = rows.fold(0.0, (s, r) => s + r.jalafMahfuzMain);
    final tIntaj = rows.fold(0.0, (s, r) => s + r.zfiIntaj);
    final tReserved = rows.fold(0.0, (s, r) => s + r.zfiReserved);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Sticky header – horizontally synced with data
          SingleChildScrollView(
            controller: _headerHScroll,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              width: totalWidth,
              child: _buildHeaderRow(nameWidth, numWidth),
            ),
          ),
          // Data rows + summary – fills remaining height, dual scroll
          Expanded(
            child: SingleChildScrollView(
              controller: _dataVScroll,
              scrollDirection: Axis.vertical,
              physics: const BouncingScrollPhysics(),
              child: SingleChildScrollView(
                controller: _dataHScroll,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  width: totalWidth,
                  child: Column(
                    children: [
                      ...List.generate(
                        rows.length,
                        (i) => _buildDataRow(rows[i], i, nameWidth, numWidth),
                      ),
                      _buildSummaryRow(nameWidth, numWidth, tMarhol,
                          tMarholMain, tMahfuz, tMahfuzMain, tIntaj, tReserved),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── header row ────────────────────────────────────────────────────────────

  Widget _buildHeaderRow(double nameWidth, double numWidth) {
    return Container(
      color: const Color(AppConstants.primaryColor),
      child: Row(
        children: [
          // Name column – not sortable
          Container(
            width: nameWidth,
            height: 56,
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            alignment: AlignmentDirectional.centerEnd,
            child: const Text(
              'الصنف',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
          _sortableHeader('المرحل', 'marhol', numWidth),
          _sortableHeader('المرحل في المخزن الرئيسي', 'marholMain', numWidth),
          _sortableHeader('المحفوظ', 'mahfuz', numWidth),
          _sortableHeader('المحفوظ في المخزن الرئيسي', 'mahfuzMain', numWidth),
          _sortableHeader('رصيد الإنتاج', 'intaj', numWidth),
          _sortableHeader('رصيد الإنتاج المحجوز', 'reserved', numWidth),
        ],
      ),
    );
  }

  Widget _sortableHeader(String label, String col, double width) {
    final isActive = _sortColumn == col;
    return InkWell(
      onTap: () => _sortByColumn(col),
      child: Container(
        width: width,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border(
            right: BorderSide(
                color: Colors.white.withValues(alpha: 0.2), width: 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 3),
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: Colors.white70,
                size: 11,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── data rows ─────────────────────────────────────────────────────────────

  Widget _buildDataRow(
      _StockRow row, int index, double nameWidth, double numWidth) {
    final isEven = index % 2 == 0;

    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      decoration: BoxDecoration(
        color: isEven ? Colors.grey.shade50 : Colors.white,
        border:
            Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _nameCell(row.itemName, nameWidth),
          _numCell(_formatNum(row.jalafMarhol), numWidth),
          _numCell(_formatNum(row.jalafMarholMain), numWidth),
          _numCell(_formatNum(row.jalafMahfuz), numWidth),
          _numCell(_formatNum(row.jalafMahfuzMain), numWidth),
          _numCell(_formatNum(row.zfiIntaj), numWidth),
          _numCell(_formatNum(row.zfiReserved), numWidth),
        ],
      ),
    );
  }

  Widget _nameCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      alignment: AlignmentDirectional.centerEnd,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(AppConstants.primaryColor),
        ),
        textAlign: TextAlign.right,
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );
  }

  Widget _numCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ── summary row ───────────────────────────────────────────────────────────

  Widget _buildSummaryRow(
      double nameWidth,
      double numWidth,
      double tMarhol,
      double tMarholMain,
      double tMahfuz,
      double tMahfuzMain,
      double tIntaj,
      double tReserved) {
    const style = TextStyle(
      color: Color(AppConstants.accentColor),
      fontWeight: FontWeight.w600,
      fontSize: 12,
    );

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(AppConstants.accentColor).withValues(alpha: 0.1),
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: nameWidth,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: AlignmentDirectional.centerEnd,
            child: const Text(
              'الإجمالي',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(AppConstants.accentColor),
              ),
            ),
          ),
          _summaryCell(_formatNum(tMarhol), numWidth, style),
          _summaryCell(_formatNum(tMarholMain), numWidth, style),
          _summaryCell(_formatNum(tMahfuz), numWidth, style),
          _summaryCell(_formatNum(tMahfuzMain), numWidth, style),
          _summaryCell(_formatNum(tIntaj), numWidth, style),
          _summaryCell(_formatNum(tReserved), numWidth, style),
        ],
      ),
    );
  }

  Widget _summaryCell(String text, double width, TextStyle style) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      child: Text(
        text,
        style: style,
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ── model ─────────────────────────────────────────────────────────────────────

class _StockRow {
  final String itemCode;
  final String itemName;
  final double jalafMarhol;      // total across all warehouses, posted
  final double jalafMarholMain;  // warehouse 0002 only, posted
  final double jalafMahfuz;      // total across all warehouses, saved
  final double jalafMahfuzMain;  // warehouse 0002 only, saved
  final double zfiIntaj;         // ZFI warehouse 0001
  final double zfiReserved;      // ZFI warehouse 0025

  const _StockRow({
    required this.itemCode,
    required this.itemName,
    required this.jalafMarhol,
    required this.jalafMarholMain,
    required this.jalafMahfuz,
    required this.jalafMahfuzMain,
    required this.zfiIntaj,
    required this.zfiReserved,
  });
}
