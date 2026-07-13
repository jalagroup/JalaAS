import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../../../models/user.dart';
import '../../../models/warehouse_models.dart';
import '../../../services/api_service.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';

// ─────────────────────────── SHARED HELPERS ───────────────────────────

Color _statusColor(TransferStatus s) {
  switch (s) {
    case TransferStatus.pending:
      return Colors.orange.shade700;
    case TransferStatus.approved:
      return Colors.blue.shade700;
    case TransferStatus.completed:
      return Colors.green.shade700;
    case TransferStatus.rejected:
      return Colors.red.shade700;
  }
}

Color _statusBg(TransferStatus s) {
  switch (s) {
    case TransferStatus.pending:
      return Colors.orange.shade50;
    case TransferStatus.approved:
      return Colors.blue.shade50;
    case TransferStatus.completed:
      return Colors.green.shade50;
    case TransferStatus.rejected:
      return Colors.red.shade50;
  }
}

IconData _statusIcon(TransferStatus s) {
  switch (s) {
    case TransferStatus.pending:
      return Icons.hourglass_top_rounded;
    case TransferStatus.approved:
      return Icons.thumb_up_rounded;
    case TransferStatus.completed:
      return Icons.check_circle_rounded;
    case TransferStatus.rejected:
      return Icons.cancel_rounded;
  }
}

String _statusText(TransferStatus s) {
  switch (s) {
    case TransferStatus.pending:
      return 'معلق';
    case TransferStatus.approved:
      return 'موافق';
    case TransferStatus.completed:
      return 'مكتمل';
    case TransferStatus.rejected:
      return 'مرفوض';
  }
}

Widget _statusBadge(TransferStatus s, {double fontSize = 11}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: _statusBg(s),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _statusColor(s).withValues(alpha: 0.4)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_statusIcon(s), color: _statusColor(s), size: fontSize + 1),
        const SizedBox(width: 4),
        Text(
          _statusText(s),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: _statusColor(s),
          ),
        ),
      ],
    ),
  );
}

Widget _infoChip(String label, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );
}

Widget _sectionHeader(String title, IconData icon, int? count,
    {VoidCallback? onRefresh}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(AppConstants.primaryColor).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              color: const Color(AppConstants.primaryColor), size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(AppConstants.primaryColor),
            ),
          ),
        ),
        if (count != null && count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(AppConstants.accentColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ),
        if (onRefresh != null) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            height: 36,
            child: ElevatedButton(
              onPressed: onRefresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppConstants.accentColor),
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Icon(Icons.refresh, size: 18),
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _emptyState(IconData icon, String title, String subtitle) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 52, color: Colors.grey.shade400),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
      ],
    ),
  );
}

Widget _itemsTable(List<TransferItem> items, bool isMobile) {
  return Container(
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade200),
      borderRadius: BorderRadius.circular(8),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3),
          1: FlexColumnWidth(1.2),
          2: FlexColumnWidth(1),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: const Color(AppConstants.primaryColor).withValues(alpha: 0.07),
            ),
            children: [
              _tCell('الصنف', isMobile, isHeader: true),
              _tCell('الكمية', isMobile, isHeader: true),
              _tCell('الوحدة', isMobile, isHeader: true),
            ],
          ),
          ...items.asMap().entries.map((e) => TableRow(
                decoration: BoxDecoration(
                  color: e.key % 2 == 0
                      ? Colors.white
                      : Colors.grey.shade50,
                ),
                children: [
                  _tCell(e.value.itemName, isMobile),
                  _tCell(
                    e.value.requestedQuantity % 1 == 0
                        ? e.value.requestedQuantity.toInt().toString()
                        : e.value.requestedQuantity.toStringAsFixed(2),
                    isMobile,
                    isBold: true,
                    color: const Color(AppConstants.accentColor),
                  ),
                  _tCell(e.value.unit, isMobile),
                ],
              )),
        ],
      ),
    ),
  );
}

Widget _tCell(String text, bool isMobile,
    {bool isHeader = false, bool isBold = false, Color? color}) {
  return Padding(
    padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 12, vertical: isMobile ? 8 : 10),
    child: Text(
      text,
      style: TextStyle(
        fontSize: isMobile ? 11 : 12,
        fontWeight:
            isHeader || isBold ? FontWeight.w700 : FontWeight.normal,
        color: color ??
            (isHeader
                ? const Color(AppConstants.primaryColor)
                : Colors.grey.shade800),
      ),
      textAlign: isHeader ? TextAlign.center : TextAlign.start,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

void _snack(BuildContext ctx, String msg, bool isError) {
  if (!ctx.mounted) return;
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontSize: 14)),
    backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.all(16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    duration: Duration(seconds: isError ? 4 : 2),
  ));
}

// ═══════════════════════════ NEW TRANSFER TAB ═══════════════════════════

class NewTransferTab extends StatefulWidget {
  final AppUser user;
  final VoidCallback? onTransferComplete;

  const NewTransferTab(
      {super.key, required this.user, this.onTransferComplete});

  @override
  State<NewTransferTab> createState() => _NewTransferTabState();
}

class _NewTransferTabState extends State<NewTransferTab>
    with AutomaticKeepAliveClientMixin {
  String? _warehouseType;
  String? _targetCode;
  List<StockItem> _stock = [];
  Map<String, double> _qty = {};
  final Map<String, TextEditingController> _qtyControllers = {};
  bool _loadingStock = false;
  bool _loadingUsers = false;
  bool _submitting = false;
  String _search = '';
  final _searchCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  List<Map<String, String>> _targets = [];

  static const _primary = Color(AppConstants.primaryColor);
  static const _accent = Color(AppConstants.accentColor);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadTargets();
    _searchCtrl.addListener(() {
      setState(() => _search = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _commentCtrl.dispose();
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTargets() async {
    setState(() => _loadingUsers = true);
    try {
      final users = await SupabaseService.getUsers();
      final valid = users.where((u) {
        if (u.id == widget.user.id) return false;
        if (u.isSystemAdmin || u.isQualityController) return false;
        final s = u.salesman.trim();
        if (s.isEmpty || s == '00' || s == '000' || s == '0000') return false;
        return u.isActive;
      }).toList()
        ..sort((a, b) => a.username.compareTo(b.username));
      setState(() {
        _targets = [
          {'code': 'MAIN_WAREHOUSE', 'name': WarehouseType.main},
          ...valid.map((u) => {
                'code': u.salesman,
                'name': '${u.username} (${u.salesman})',
              }),
        ];
      });
    } catch (_) {
      setState(() => _targets = [
            {'code': 'MAIN_WAREHOUSE', 'name': WarehouseType.main}
          ]);
    } finally {
      setState(() => _loadingUsers = false);
    }
  }

  Future<void> _loadStock() async {
    if (_warehouseType == null) return;
    setState(() {
      _loadingStock = true;
      _stock = [];
      _qty = {};
    });
    try {
      final code =
          WarehouseHelper.getWarehouseCode(widget.user.salesman, _warehouseType!);
      final items = await ApiService.getWarehouseStock(warehouseCode: code);
      if (mounted) {
        setState(() {
          _stock = items;
          for (final c in _qtyControllers.values) {
            c.dispose();
          }
          _qtyControllers.clear();
          for (var i in items) {
            _qty[i.itemCode] = 0.0;
            _qtyControllers[i.itemCode] = TextEditingController();
          }
        });
      }
    } catch (e) {
      if (mounted) Helpers.showApiErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _loadingStock = false);
    }
  }

  List<TransferItem> get _selectedItems {
    return _stock
        .where((i) => (_qty[i.itemCode] ?? 0) > 0)
        .map((i) => TransferItem(
              itemCode: i.itemCode,
              itemName: i.itemName,
              unit: i.unit,
              availableQuantity: i.endBalance,
              requestedQuantity: _qty[i.itemCode]!,
            ))
        .toList();
  }

  bool _validate(List<TransferItem> items) {
    if (_warehouseType == null) {
      _snack(context, 'يرجى اختيار نوع المخزن', true);
      return false;
    }
    if (_targetCode == null) {
      _snack(context, 'يرجى اختيار الوجهة', true);
      return false;
    }
    if (items.isEmpty) {
      _snack(context, 'يرجى تحديد كميات للأصناف', true);
      return false;
    }
    if (items.any((i) => !i.isValid)) {
      _snack(context, 'بعض الكميات أكبر من المتاح', true);
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    final items = _selectedItems;
    if (!_validate(items)) return;

    final targetName = _targetCode == 'MAIN_WAREHOUSE'
        ? 'المخزن الرئيسي'
        : _targets
            .firstWhere((t) => t['code'] == _targetCode)['name']!
            .split(' (')[0];

    final confirmed = await _showConfirmDialog(items, targetName);
    if (!confirmed) return;

    setState(() => _submitting = true);
    try {
      final src = WarehouseHelper.getWarehouseCode(
          widget.user.salesman, _warehouseType!);
      final toMain = _targetCode == 'MAIN_WAREHOUSE';

      if (toMain) {
        final tgt = WarehouseHelper.getMainWarehouseCode(_warehouseType!);
        final res = await ApiService.createMainWarehouseStoreIssueVoucher(
          sourceWarehouse: src,
          targetWarehouse: tgt,
          items: items,
          requesterName: widget.user.username,
          warehouseType: _warehouseType!,
          comment: _commentCtrl.text.trim(),
        );
        await SupabaseService.createWarehouseTransferRequestWithBisanCode(
          sourceWarehouse: src,
          targetWarehouse: tgt,
          warehouseType: _warehouseType!,
          items: items,
          bisanCode: res['bisan_code'],
          docDate: res['doc_date'],
          comment: _commentCtrl.text.trim(),
        );
        if (mounted) _snack(context, 'تم الإرسال إلى المخزن الرئيسي بنجاح ✓', false);
      } else {
        final tgt = WarehouseHelper.getWarehouseCode(_targetCode!, _warehouseType!);
        final targetUser = await _getTargetUser(_targetCode!);
        final targetUserName = targetUser?['username'] ?? targetName;
        final res = await ApiService.createUserToUserStoreIssueVoucher(
          sourceWarehouse: src,
          targetWarehouse: tgt,
          items: items,
          requesterName: widget.user.username,
          targetUserName: targetUserName,
          warehouseType: _warehouseType!,
          comment: _commentCtrl.text.trim(),
        );
        await SupabaseService.createWarehouseTransferRequestWithBisanCode(
          sourceWarehouse: src,
          targetWarehouse: tgt,
          warehouseType: _warehouseType!,
          items: items,
          bisanCode: res['bisan_code'],
          docDate: res['doc_date'],
          targetUserId: targetUser?['id'],
          targetUserName: targetUserName,
          comment: _commentCtrl.text.trim(),
        );
        if (mounted)
          _snack(context, 'تم إنشاء طلب النقل وإرساله للموافقة ✓', false);
      }
      _clearForm();
      widget.onTransferComplete?.call();
    } catch (e) {
      if (mounted) Helpers.showApiErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<Map<String, String>?> _getTargetUser(String salesman) async {
    try {
      final users = await SupabaseService.getUsers();
      final u = users.firstWhere((u) => u.salesman == salesman);
      return {'id': u.id, 'username': u.username};
    } catch (_) {
      return null;
    }
  }

  void _clearForm() {
    setState(() {
      _warehouseType = null;
      _targetCode = null;
      _stock = [];
      _qty = {};
      for (final c in _qtyControllers.values) {
        c.dispose();
      }
      _qtyControllers.clear();
      _search = '';
      _searchCtrl.clear();
      _commentCtrl.clear();
    });
  }

  Future<bool> _showConfirmDialog(
      List<TransferItem> items, String targetName) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: ui.TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              title: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: _accent, size: 22),
                ),
                const SizedBox(width: 10),
                const Text('تأكيد عملية النقل',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ]),
              content: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 480, maxHeight: 500),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(children: [
                          _confirmRow(Icons.warehouse, 'من',
                              'مخزن $_warehouseType', Colors.blue.shade800),
                          const SizedBox(height: 8),
                          _confirmRow(Icons.location_on, 'إلى', targetName,
                              Colors.blue.shade800),
                          if (_commentCtrl.text.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _confirmRow(Icons.comment, 'ملاحظة',
                                _commentCtrl.text.trim(), Colors.orange.shade800),
                          ],
                        ]),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'الأصناف (${items.length}):',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: items.take(6).toList().asMap().entries.map(
                            (e) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: e.key % 2 == 0
                                    ? Colors.white
                                    : Colors.grey.shade50,
                                border: e.key > 0
                                    ? const Border(
                                        top: BorderSide(
                                            color: Color(0xFFEEEEEE)))
                                    : null,
                              ),
                              child: Row(children: [
                                Expanded(
                                  child: Text(e.value.itemName,
                                      style: const TextStyle(
                                          fontSize: 13),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${e.value.requestedQuantity % 1 == 0 ? e.value.requestedQuantity.toInt() : e.value.requestedQuantity.toStringAsFixed(2)} ${e.value.unit}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _accent),
                                  ),
                                ),
                              ]),
                            ),
                          ).toList(),
                        ),
                      ),
                      if (items.length > 6)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '+ ${items.length - 6} أصناف أخرى',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('إلغاء', style: TextStyle(fontSize: 14))),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('تأكيد الإرسال',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  Widget _confirmRow(IconData icon, String label, String value, Color color) {
    return Row(children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 6),
      Text('$label: ', style: TextStyle(fontSize: 12, color: color)),
      Expanded(
        child: Text(value,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: color),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 768;
    final isDesktop = w > 1000;
    final selectedCount = _selectedItems.length;

    if (isMobile) {
      return _buildMobileLayout(selectedCount);
    }
    return _buildDesktopLayout(isDesktop, selectedCount);
  }

  Widget _buildDesktopLayout(bool isDesktop, int selectedCount) {
    return Column(
      children: [
        // Summary bar
        if (selectedCount > 0) _buildSummaryBar(selectedCount),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left control panel
              SizedBox(
                width: isDesktop ? 320 : 280,
                child: Container(
                  color: Colors.white,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildControlsSection(),
                        const SizedBox(height: 16),
                        _buildCommentSection(),
                        const SizedBox(height: 16),
                        _buildSubmitButton(false, selectedCount),
                      ],
                    ),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              // Right stock panel
              Expanded(child: _buildStockPanel(false)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(int selectedCount) {
    return Column(
      children: [
        if (selectedCount > 0) _buildSummaryBar(selectedCount),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildControlsSection(),
                if (_warehouseType != null && _targetCode != null) ...[
                  const SizedBox(height: 12),
                  _buildCommentSection(),
                  const SizedBox(height: 12),
                  _buildStockPanel(true),
                  const SizedBox(height: 16),
                  _buildSubmitButton(true, selectedCount),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBar(int selectedCount) {
    final items = _selectedItems;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: _accent,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            '$selectedCount ${selectedCount == 1 ? 'صنف' : 'أصناف'} محددة',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              items
                  .take(3)
                  .map((i) => i.itemName.split(' ').first)
                  .join(' • '),
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85), fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsSection() {
    const inputDeco = InputDecoration(
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
    );
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Icon(Icons.settings, color: _primary, size: 16),
                SizedBox(width: 8),
                Text('إعدادات النقل',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _primary)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Warehouse type
                const _FieldLabel('نوع المخزن المصدر', Icons.warehouse_outlined),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _warehouseType,
                  decoration: inputDeco.copyWith(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: _accent, width: 2)),
                  ),
                  items: [WarehouseType.good, WarehouseType.damaged]
                      .map((t) => DropdownMenuItem(
                          value: t,
                          child: Row(children: [
                            Icon(
                              t == WarehouseType.good
                                  ? Icons.check_circle_outline
                                  : Icons.warning_amber_outlined,
                              size: 16,
                              color: t == WarehouseType.good
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(t,
                                style: const TextStyle(fontSize: 13)),
                          ])))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _warehouseType = v;
                      _stock = [];
                      _qty = {};
                    });
                    if (v != null) _loadStock();
                  },
                  hint: const Text('اختر نوع المخزن',
                      style: TextStyle(fontSize: 13)),
                  isExpanded: true,
                ),

                const SizedBox(height: 14),

                // Destination
                const _FieldLabel('الوجهة', Icons.location_on_outlined),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _targetCode,
                  decoration: inputDeco.copyWith(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: _accent, width: 2)),
                  ),
                  items: _targets
                      .map((t) => DropdownMenuItem(
                          value: t['code'],
                          child: Text(t['name']!,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: _loadingUsers
                      ? null
                      : (v) => setState(() => _targetCode = v),
                  hint: Text(
                      _loadingUsers ? 'جارٍ التحميل...' : 'اختر الوجهة',
                      style: const TextStyle(fontSize: 13)),
                  isExpanded: true,
                ),

                // Auto warehouse type info
                if (_targetCode != null &&
                    _targetCode != 'MAIN_WAREHOUSE' &&
                    _warehouseType != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue.shade700, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'سيتم النقل إلى مخزن $_warehouseType تلقائياً',
                          style: TextStyle(
                              fontSize: 11, color: Colors.blue.shade800),
                        ),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Icon(Icons.comment_outlined, color: _primary, size: 16),
                SizedBox(width: 8),
                Text('ملاحظة (اختياري)',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _primary)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _commentCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'أضف ملاحظة...',
                hintStyle:
                    TextStyle(fontSize: 13, color: Colors.grey.shade500),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _accent, width: 2)),
                contentPadding: const EdgeInsets.all(10),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtQty(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  Widget _qtyBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 24,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled
              ? _accent.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: enabled
                ? _accent.withValues(alpha: 0.35)
                : Colors.grey.shade300,
          ),
        ),
        child: Icon(icon, size: 14,
            color: enabled ? _accent : Colors.grey.shade400),
      ),
    );
  }

  Widget _buildStockPanel(bool isMobile) {
    return Container(
      color: const Color(0xFFF8F9FC),
      child: Column(
        mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
        children: [
          // Search + header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        color: _primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'الأصناف المتاحة (${_stock.length})',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _primary),
                      ),
                    ),
                    if (_loadingStock)
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _accent)),
                  ],
                ),
                if (_stock.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'بحث عن صنف...',
                      hintStyle: TextStyle(
                          fontSize: 13, color: Colors.grey.shade500),
                      prefixIcon: Icon(Icons.search,
                          color: Colors.grey.shade500, size: 18),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: _searchCtrl.clear)
                          : null,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade200)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade200)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: _accent, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Table header
          if (_stock.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: _primary.withValues(alpha: 0.07),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text('الصنف',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _primary)),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text('المتاح',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _primary)),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 90,
                    child: Text('الكمية',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _primary)),
                  ),
                ],
              ),
            ),
          // Items list
          if (isMobile)
            _buildStockList(isMobile)
          else
            Expanded(child: _buildStockList(isMobile)),
        ],
      ),
    );
  }

  Widget _buildStockList(bool isMobile) {
    Widget wrap(Widget child) => isMobile
        ? Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: child)
        : child;

    if (_loadingStock) {
      return wrap(const Center(child: CircularProgressIndicator(color: _accent)));
    }
    if (_warehouseType == null || _targetCode == null) {
      return wrap(_emptyState(Icons.warehouse_outlined, 'اختر المخزن والوجهة',
          'لعرض الأصناف المتاحة'));
    }
    if (_stock.isEmpty) {
      return wrap(_emptyState(Icons.inventory_2_outlined, 'لا توجد أصناف متاحة',
          'المخزن المحدد فارغ'));
    }

    final filtered = _search.isEmpty
        ? _stock
        : _stock
            .where((i) =>
                i.itemName.toLowerCase().contains(_search) ||
                i.itemCode.toLowerCase().contains(_search))
            .toList();

    if (filtered.isEmpty) {
      return wrap(_emptyState(
          Icons.search_off, 'لم يُعثر على نتائج', 'جرب كلمة بحث أخرى'));
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: isMobile,
      physics: isMobile ? const NeverScrollableScrollPhysics() : null,
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final item = filtered[i];
        final q = _qty[item.itemCode] ?? 0.0;
        final hasQty = q > 0;
        final isOver = hasQty && q > item.endBalance;

        return Container(
          decoration: BoxDecoration(
            color: isOver
                ? Colors.red.shade50
                : hasQty
                    ? _accent.withValues(alpha: 0.04)
                    : (i % 2 == 0 ? Colors.white : const Color(0xFFFAFAFB)),
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade100),
              right: hasQty
                  ? BorderSide(
                      color: isOver ? Colors.red : _accent, width: 3)
                  : BorderSide.none,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.itemCode,
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 80,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: item.endBalance > 0
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${item.endBalance % 1 == 0 ? item.endBalance.toInt() : item.endBalance.toStringAsFixed(1)} ${item.unit}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: item.endBalance > 0
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _qtyBtn(
                    icon: Icons.remove_rounded,
                    enabled: q > 0,
                    onTap: () {
                      final n = (q - 1).clamp(0.0, item.endBalance);
                      _qtyControllers[item.itemCode]?.text =
                          n == 0 ? '' : _fmtQty(n);
                      setState(() => _qty[item.itemCode] = n);
                    },
                  ),
                  const SizedBox(width: 2),
                  SizedBox(
                    width: 56,
                    child: TextFormField(
                      key: ValueKey(item.itemCode),
                      controller: _qtyControllers[item.itemCode],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isOver ? Colors.red : _primary,
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(
                            fontSize: 12, color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                              color: isOver
                                  ? Colors.red
                                  : hasQty
                                      ? _accent
                                      : Colors.grey.shade300,
                              width: hasQty ? 1.5 : 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                              color: isOver
                                  ? Colors.red
                                  : hasQty
                                      ? _accent
                                      : Colors.grey.shade300,
                              width: hasQty ? 1.5 : 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                              color: isOver ? Colors.red : _accent,
                              width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                        isDense: true,
                        errorStyle:
                            const TextStyle(fontSize: 0, height: 0),
                      ),
                      onChanged: (v) {
                        final parsed = double.tryParse(v) ?? 0.0;
                        setState(() => _qty[item.itemCode] = parsed);
                      },
                    ),
                  ),
                  const SizedBox(width: 2),
                  _qtyBtn(
                    icon: Icons.add_rounded,
                    enabled: q < item.endBalance,
                    onTap: () {
                      final n = (q + 1).clamp(0.0, item.endBalance);
                      _qtyControllers[item.itemCode]?.text = _fmtQty(n);
                      setState(() => _qty[item.itemCode] = n);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubmitButton(bool isMobile, int selectedCount) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _submitting || selectedCount == 0 ? null : _submit,
        icon: _submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white)))
            : Icon(
                _targetCode == 'MAIN_WAREHOUSE'
                    ? Icons.warehouse
                    : Icons.send_rounded,
                size: 20),
        label: Text(
          _submitting
              ? 'جارٍ الإرسال...'
              : selectedCount > 0
                  ? 'إرسال ($selectedCount ${selectedCount == 1 ? 'صنف' : 'أصناف'})'
                  : 'حدد الأصناف للإرسال',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 2,
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final IconData icon;
  const _FieldLabel(this.text, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 13, color: const Color(AppConstants.primaryColor)),
      const SizedBox(width: 5),
      Text(text,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(AppConstants.primaryColor))),
    ]);
  }
}

// ═══════════════════════════ SENT REQUESTS TAB ═══════════════════════════

class SentRequestsTab extends StatefulWidget {
  final AppUser user;

  const SentRequestsTab({super.key, required this.user});

  @override
  State<SentRequestsTab> createState() => _SentRequestsTabState();
}

class _SentRequestsTabState extends State<SentRequestsTab>
    with AutomaticKeepAliveClientMixin {
  List<WarehouseTransferRequest> _requests = [];
  bool _loading = true;
  TransferStatus? _filter;
  final Set<int> _expanded = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await SupabaseService.getWarehouseTransferRequests(
          sentByMe: true, status: _filter);
      if (mounted) setState(() => _requests = r);
    } catch (e) {
      if (mounted) Helpers.showApiErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(WarehouseTransferRequest req) async {
    final ok = await _confirmDelete();
    if (!ok) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(
                color: Color(AppConstants.accentColor)),
            const SizedBox(height: 16),
            Text('جارٍ إلغاء الطلب...',
                style: TextStyle(color: Colors.grey.shade700)),
          ]),
        ),
      ),
    );

    try {
      await SupabaseService.deleteWarehouseTransferRequestWithReversal(req.id!);
      if (mounted) {
        Navigator.pop(context);
        _snack(context, 'تم إلغاء الطلب وإعادة البضاعة بنجاح', false);
        _load();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        Helpers.showApiErrorDialog(context, e);
      }
    }
  }

  Future<bool> _confirmDelete() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: ui.TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.warning_rounded,
                      color: Colors.red.shade700, size: 22),
                ),
                const SizedBox(width: 10),
                const Text('إلغاء الطلب',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  'سيتم إعادة البضاعة إلى مخزنك. هذا الإجراء لا يمكن التراجع عنه.',
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey.shade700, height: 1.5),
                ),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('لا، إبقه')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  child: const Text('نعم، إلغاء',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 768;

    // Count per status
    final counts = <TransferStatus?, int>{null: _requests.length};
    for (final s in TransferStatus.values) {
      counts[s] = _requests.where((r) => r.status == s).length;
    }

    return Column(
      children: [
        _sectionHeader('الطلبات المرسلة', Icons.outbox_outlined,
            _requests.length, onRefresh: _load),
        // Filter chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(null, 'الكل', Icons.list_alt, isMobile),
                ...TransferStatus.values.map(
                    (s) => _filterChip(s, _statusText(s), _statusIcon(s), isMobile)),
              ],
            ),
          ),
        ),
        // Content
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(AppConstants.accentColor)))
              : _requests.isEmpty
                  ? _emptyState(Icons.outbox_outlined, 'لا توجد طلبات مرسلة',
                      'ستظهر هنا طلباتك المرسلة')
                  : ListView.builder(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      itemCount: _requests.length,
                      itemBuilder: (ctx, i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildCard(_requests[i], i, isMobile),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _filterChip(
      TransferStatus? s, String label, IconData icon, bool isMobile) {
    final selected = _filter == s;
    final color = s == null
        ? const Color(AppConstants.primaryColor)
        : _statusColor(s);
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: FilterChip(
        selected: selected,
        label: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: selected ? Colors.white : color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.white : color,
                  fontWeight: FontWeight.w600)),
        ]),
        onSelected: (_) {
          setState(() {
            _filter = s;
            _expanded.clear();
          });
          _load();
        },
        selectedColor: color,
        backgroundColor: color.withValues(alpha: 0.08),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildCard(
      WarehouseTransferRequest req, int index, bool isMobile) {
    final isExpanded = _expanded.contains(index);
    final target = req.targetUserName ?? 'المخزن الرئيسي';
    final wType = req.warehouseType == WarehouseType.good ? 'صالح' : 'تالف';
    final statusC = _statusColor(req.status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(right: BorderSide(color: statusC, width: 4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: target + status + date
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: statusC.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.arrow_outward,
                          color: statusC, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إلى: $target',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(AppConstants.primaryColor)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'مخزن $wType',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _statusBadge(req.status),
                        const SizedBox(height: 4),
                        Text(
                          req.docDate ??
                              DateFormat('dd/MM/yyyy')
                                  .format(req.requestDate),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Row 2: info chips
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _infoChip(
                      '${req.items.length} ${req.items.length == 1 ? 'صنف' : 'أصناف'}',
                      Icons.inventory_2_outlined,
                      Colors.indigo,
                    ),
                    if (req.bisanTransactionId?.isNotEmpty == true)
                      _infoChip(
                        'بيسان: ${req.bisanTransactionId}',
                        Icons.receipt_long,
                        Colors.teal,
                      ),
                    if (req.comment?.isNotEmpty == true)
                      _infoChip(
                        'يحتوي ملاحظة',
                        Icons.comment_outlined,
                        Colors.blue,
                      ),
                  ],
                ),
              ],
            ),
          ),
          // ── Comment ──
          if (req.comment?.isNotEmpty == true)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.comment, size: 13, color: Colors.blue.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    req.comment!,
                    style: TextStyle(
                        fontSize: 12, color: Colors.blue.shade800),
                  ),
                ),
              ]),
            ),
          // ── Expand items ──
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expanded.remove(index);
                } else {
                  _expanded.add(index);
                }
              });
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(
                children: [
                  Icon(
                    isExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isExpanded ? 'إخفاء الأصناف' : 'عرض الأصناف',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  if (req.isPending)
                    TextButton.icon(
                      onPressed: () => _delete(req),
                      icon: const Icon(Icons.delete_outline,
                          size: 16, color: Colors.red),
                      label: const Text('إلغاء',
                          style:
                              TextStyle(fontSize: 12, color: Colors.red)),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: _itemsTable(req.items, false),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════ PENDING RECEIVED REQUESTS TAB ═══════════════════

class PendingReceivedRequestsTab extends StatefulWidget {
  final AppUser user;
  final VoidCallback? onRequestHandled;

  const PendingReceivedRequestsTab(
      {super.key, required this.user, this.onRequestHandled});

  @override
  State<PendingReceivedRequestsTab> createState() =>
      _PendingReceivedRequestsTabState();
}

class _PendingReceivedRequestsTabState
    extends State<PendingReceivedRequestsTab>
    with AutomaticKeepAliveClientMixin {
  List<WarehouseTransferRequest> _requests = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await SupabaseService.getWarehouseTransferRequests(
          receivedByMe: true, status: TransferStatus.pending);
      if (mounted) setState(() => _requests = r);
    } catch (e) {
      if (mounted) Helpers.showApiErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(WarehouseTransferRequest req) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: ui.TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.check_circle,
                      color: Colors.green.shade700, size: 22),
                ),
                const SizedBox(width: 10),
                const Text('موافقة على الطلب',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
              content: Text(
                'هل توافق على استلام هذه البضاعة؟ سيتم تنفيذ العملية في النظام فوراً.',
                style: TextStyle(
                    fontSize: 14, color: Colors.grey.shade700, height: 1.5),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('إلغاء')),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('موافقة واستلام',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!ok || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(
                color: Color(AppConstants.accentColor)),
            const SizedBox(height: 16),
            Text('جارٍ الموافقة وتنفيذ الاستلام...',
                style: TextStyle(color: Colors.grey.shade700)),
          ]),
        ),
      ),
    );

    try {
      await SupabaseService.approveAndExecuteWarehouseTransferRequest(
          requestId: req.id!);
      if (mounted) {
        Navigator.pop(context);
        _snack(context, 'تم الاستلام وتنفيذ الطلب بنجاح ✓', false);
        _load();
        widget.onRequestHandled?.call();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        Helpers.showApiErrorDialog(context, e);
      }
    }
  }

  Future<void> _reject(WarehouseTransferRequest req) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: ui.TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.cancel, color: Colors.red.shade700, size: 22),
                ),
                const SizedBox(width: 10),
                const Text('رفض الطلب',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'سيتم إعادة البضاعة تلقائياً إلى المرسل',
                          style: TextStyle(
                              fontSize: 12, color: Colors.orange.shade900),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'سبب الرفض (اختياري)',
                      hintText: 'اكتب سبب الرفض...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(AppConstants.accentColor),
                              width: 2)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('إلغاء')),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.cancel, size: 18),
                  label: const Text('رفض',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!ok || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(
                color: Color(AppConstants.accentColor)),
            const SizedBox(height: 16),
            Text('جارٍ رفض الطلب وإعادة البضاعة...',
                style: TextStyle(color: Colors.grey.shade700)),
          ]),
        ),
      ),
    );

    try {
      await SupabaseService.rejectWarehouseTransferRequestWithReversal(
        requestId: req.id!,
        rejectionReason:
            reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        _snack(context, 'تم رفض الطلب وإعادة البضاعة إلى المرسل', false);
        _load();
        widget.onRequestHandled?.call();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        Helpers.showApiErrorDialog(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 768;

    return Column(
      children: [
        _sectionHeader(
          'الطلبات المستلمة - بانتظار موافقتك',
          Icons.inbox_rounded,
          _requests.length,
          onRefresh: _load,
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(AppConstants.accentColor)))
              : _requests.isEmpty
                  ? _emptyState(
                      Icons.inbox_outlined,
                      'لا توجد طلبات بانتظار موافقتك',
                      'ستظهر هنا الطلبات الجديدة')
                  : ListView.builder(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      itemCount: _requests.length,
                      itemBuilder: (ctx, i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildCard(_requests[i], isMobile),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildCard(WarehouseTransferRequest req, bool isMobile) {
    final wType = req.warehouseType == WarehouseType.good ? 'صالح' : 'تالف';
    const accent = Color(AppConstants.accentColor);
    const primary = Color(AppConstants.primaryColor);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
            padding: EdgeInsets.all(isMobile ? 14 : 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.12),
                  accent.withValues(alpha: 0.04),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person, color: accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.requesterName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primary),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _infoChip('مخزن $wType', Icons.warehouse_outlined,
                              wType == 'صالح' ? Colors.green : Colors.orange),
                          _infoChip(
                            '${req.items.length} ${req.items.length == 1 ? 'صنف' : 'أصناف'}',
                            Icons.inventory_2_outlined,
                            Colors.indigo,
                          ),
                          if (req.bisanTransactionId?.isNotEmpty == true)
                            _infoChip(
                              'بيسان: ${req.bisanTransactionId}',
                              Icons.receipt_long,
                              Colors.teal,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    req.docDate ??
                        DateFormat('dd/MM/yyyy').format(req.requestDate),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange.shade900),
                  ),
                ),
              ],
            ),
          ),

          // ── Items table ──
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.list_alt_rounded,
                      size: 16, color: primary),
                  const SizedBox(width: 6),
                  const Text('الأصناف المطلوبة',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: primary)),
                ]),
                const SizedBox(height: 10),
                _itemsTable(req.items, isMobile),
              ],
            ),
          ),

          // ── Comment ──
          if (req.comment?.isNotEmpty == true)
            Padding(
              padding:
                  EdgeInsets.fromLTRB(isMobile ? 12 : 16, 0, isMobile ? 12 : 16, 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.comment, size: 14, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        req.comment!,
                        style: TextStyle(
                            fontSize: 12, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Action buttons ──
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
              border:
                  Border(top: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: isMobile ? 44 : 48,
                    child: OutlinedButton.icon(
                      onPressed: () => _reject(req),
                      icon: const Icon(Icons.cancel_outlined, size: 20),
                      label: const Text('رفض',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: isMobile ? 44 : 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _approve(req),
                      icon: const Icon(Icons.check_circle, size: 20),
                      label: const Text('موافقة واستلام',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
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
}

// ═══════════════════════ COMPLETED REQUESTS TAB ═══════════════════════

class CompletedRequestsTab extends StatefulWidget {
  final AppUser user;

  const CompletedRequestsTab({super.key, required this.user});

  @override
  State<CompletedRequestsTab> createState() => _CompletedRequestsTabState();
}

class _CompletedRequestsTabState extends State<CompletedRequestsTab>
    with AutomaticKeepAliveClientMixin {
  List<WarehouseTransferRequest> _requests = [];
  bool _loading = true;
  final Set<int> _expanded = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sent = await SupabaseService.getWarehouseTransferRequests(
          sentByMe: true, status: TransferStatus.completed);
      final recv = await SupabaseService.getWarehouseTransferRequests(
          receivedByMe: true, status: TransferStatus.completed);
      final all = [...sent, ...recv]
        ..sort((a, b) =>
            (b.completedDate ?? b.updatedAt)
                .compareTo(a.completedDate ?? a.updatedAt));
      if (mounted) setState(() => _requests = all);
    } catch (e) {
      if (mounted) Helpers.showApiErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 768;

    return Column(
      children: [
        _sectionHeader(
            'الطلبات المنهية', Icons.task_alt_rounded, _requests.length,
            onRefresh: _load),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(AppConstants.accentColor)))
              : _requests.isEmpty
                  ? _emptyState(Icons.task_alt_outlined, 'لا توجد طلبات منهية',
                      'ستظهر هنا الطلبات المكتملة')
                  : ListView.builder(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      itemCount: _requests.length,
                      itemBuilder: (ctx, i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildCard(_requests[i], i, isMobile),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildCard(
      WarehouseTransferRequest req, int index, bool isMobile) {
    final isSent = req.requesterId == widget.user.id;
    final wType = req.warehouseType == WarehouseType.good ? 'صالح' : 'تالف';
    final isExpanded = _expanded.contains(index);
    final isRejected = req.isRejected;
    final cardColor = isRejected ? Colors.red : Colors.green;
    const primary = Color(AppConstants.primaryColor);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(right: BorderSide(color: cardColor.shade400, width: 4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            decoration: BoxDecoration(
              color: cardColor.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cardColor.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isSent ? Icons.call_made : Icons.call_received,
                    color: cardColor.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSent
                            ? 'أرسلت إلى ${req.targetUserName ?? "المخزن الرئيسي"}'
                            : 'استلمت من ${req.requesterName}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: primary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _infoChip(
                            'مخزن $wType',
                            Icons.warehouse_outlined,
                            wType == 'صالح' ? Colors.green : Colors.orange,
                          ),
                          _infoChip(
                            '${req.items.length} أصناف',
                            Icons.inventory_2_outlined,
                            Colors.indigo,
                          ),
                          if (req.bisanTransactionId?.isNotEmpty == true)
                            _infoChip(
                              req.bisanTransactionId!,
                              Icons.receipt_long,
                              Colors.teal,
                            ),
                          _statusBadge(req.status, fontSize: 10),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: cardColor.shade600,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isRejected ? Icons.close : Icons.check,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (req.completedDate != null)
                      Text(
                        DateFormat('dd/MM/yy').format(req.completedDate!),
                        style: TextStyle(
                            fontSize: 10,
                            color: cardColor.shade700,
                            fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Bisan code row (always visible) ──
          if (req.docDate?.isNotEmpty == true ||
              req.bisanTransactionId?.isNotEmpty == true)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                border: Border.symmetric(
                    horizontal: BorderSide(color: Colors.teal.shade100)),
              ),
              child: Row(
                children: [
                  Icon(Icons.receipt_long,
                      size: 14, color: Colors.teal.shade700),
                  const SizedBox(width: 6),
                  Text('كود بيسان: ',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal.shade700)),
                  Expanded(
                    child: Text(
                      req.docDate ??
                          req.bisanTransactionId ??
                          '',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade900),
                    ),
                  ),
                  if (req.completedDate != null)
                    Text(
                      DateFormat('HH:mm').format(req.completedDate!),
                      style: TextStyle(
                          fontSize: 10, color: Colors.teal.shade600),
                    ),
                ],
              ),
            ),

          // ── Expand toggle ──
          InkWell(
            onTap: () => setState(() {
              if (isExpanded) {
                _expanded.remove(index);
              } else {
                _expanded.add(index);
              }
            }),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border:
                    Border(top: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isExpanded ? 'إخفاء الأصناف' : 'عرض الأصناف (${req.items.length})',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),

          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: _itemsTable(req.items, false),
            ),
        ],
      ),
    );
  }
}
