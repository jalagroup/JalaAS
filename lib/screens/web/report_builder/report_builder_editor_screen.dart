import 'package:flutter/material.dart';
import '../../../models/custom_report.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';
import 'report_viewer_screen.dart';

/// Multi-step wizard for creating or editing a custom report.
class ReportBuilderEditorScreen extends StatefulWidget {
  final CustomReport? report; // null = create new

  const ReportBuilderEditorScreen({super.key, this.report});

  @override
  State<ReportBuilderEditorScreen> createState() =>
      _ReportBuilderEditorScreenState();
}

class _ReportBuilderEditorScreenState
    extends State<ReportBuilderEditorScreen> {
  static const _primary = Color(AppConstants.primaryColor);
  static const _accent = Color(AppConstants.accentColor);

  final _pageCtrl = PageController();
  int _step = 0;
  bool _saving = false;

  // ── Step 1: Basic info ──────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // ── Step 2: API config ──────────────────────────────────────────────────────
  ReportCompany _company = ReportCompany.jalaf;
  final _endpointCtrl = TextEditingController();
  bool _byWarehouse = false;
  bool _showSummaryRow = false;
  String? _groupByField;

  // fixed params (key → value pairs entered by user)
  final List<_KvPair> _fixedParams = [];

  // ── Step 3: Input parameters ────────────────────────────────────────────────
  final List<ReportInput> _inputs = [];

  // ── Step 4: Fields ──────────────────────────────────────────────────────────
  final List<ReportField> _fields = [];

  // ── Step 5: Filters ─────────────────────────────────────────────────────────
  final List<ReportFilter> _filters = [];

  static const _steps = [
    'المعلومات الأساسية',
    'إعداد الـ API',
    'مدخلات المستخدم',
    'أعمدة العرض',
    'الفلاتر',
  ];

  bool get _isEdit => widget.report != null;

  @override
  void initState() {
    super.initState();
    final r = widget.report;
    if (r != null) {
      _nameCtrl.text = r.nameAr;
      _descCtrl.text = r.description ?? '';
      final cfg = r.config;
      _company = cfg.company;
      _endpointCtrl.text = cfg.endpoint;
      _byWarehouse = cfg.byWarehouse;
      _showSummaryRow = cfg.showSummaryRow;
      _groupByField = cfg.groupByField;
      cfg.fixedParams.forEach(
          (k, v) => _fixedParams.add(_KvPair(key: k, value: v)));
      _inputs.addAll(cfg.inputs);
      _fields.addAll(cfg.fields);
      _filters.addAll(cfg.filters);
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _endpointCtrl.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    setState(() => _step = index);
    _pageCtrl.animateToPage(index,
        duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
  }

  bool _canProceed() {
    if (_step == 0 && _nameCtrl.text.trim().isEmpty) return false;
    if (_step == 1 && _endpointCtrl.text.trim().isEmpty) return false;
    return true;
  }

  CustomReportConfig _buildConfig() => CustomReportConfig(
        company: _company,
        endpoint: _endpointCtrl.text.trim(),
        fixedParams: {for (final p in _fixedParams) p.key: p.value},
        inputs: List.from(_inputs),
        fields: List.from(_fields),
        filters: List.from(_filters),
        showSummaryRow: _showSummaryRow,
        groupByField:
            _groupByField?.trim().isEmpty == true ? null : _groupByField,
        byWarehouse: _byWarehouse,
      );

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      Helpers.showSnackBar(context, 'يرجى إدخال اسم التقرير', isError: true);
      _goTo(0);
      return;
    }
    if (_endpointCtrl.text.trim().isEmpty) {
      Helpers.showSnackBar(context, 'يرجى إدخال مسار الـ API', isError: true);
      _goTo(1);
      return;
    }
    setState(() => _saving = true);
    try {
      final report = CustomReport(
        id: widget.report?.id ?? '',
        nameAr: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        config: _buildConfig(),
        createdAt: widget.report?.createdAt ?? DateTime.now(),
      );
      if (_isEdit) {
        await SupabaseService.updateCustomReport(report);
      } else {
        await SupabaseService.createCustomReport(report);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) Helpers.showApiErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _preview() async {
    if (_endpointCtrl.text.trim().isEmpty) {
      Helpers.showSnackBar(context, 'يرجى إدخال مسار الـ API أولاً',
          isError: true);
      return;
    }
    final preview = CustomReport(
      id: '__preview__',
      nameAr: _nameCtrl.text.isEmpty ? 'معاينة' : _nameCtrl.text,
      config: _buildConfig(),
      createdAt: DateTime.now(),
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => ReportViewerScreen(report: preview)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: _primary,
          title: Text(
            _isEdit ? 'تعديل التقرير' : 'تقرير جديد',
            style: const TextStyle(
                color: _primary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.play_circle_outline),
              tooltip: 'معاينة',
              onPressed: _preview,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: _accent),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('حفظ'),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: Colors.grey.shade200),
          ),
        ),
        body: Column(
          children: [
            _StepBar(
                steps: _steps, current: _step, onTap: (i) => _goTo(i)),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _step1BasicInfo(),
                  _step2ApiConfig(),
                  _step3Inputs(),
                  _step4Fields(),
                  _step5Filters(),
                ],
              ),
            ),
            _NavBar(
              step: _step,
              total: _steps.length,
              canNext: _canProceed(),
              onBack: _step > 0 ? () => _goTo(_step - 1) : null,
              onNext: _step < _steps.length - 1
                  ? (_canProceed() ? () => _goTo(_step + 1) : null)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Step 1 – Basic Info
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _step1BasicInfo() => _StepScaffold(
        title: 'المعلومات الأساسية',
        children: [
          _label('اسم التقرير *'),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(hintText: 'مثال: تقرير أرصدة المخزون'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          _label('الوصف (اختياري)'),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'وصف مختصر للتقرير'),
          ),
        ],
      );

  // ─────────────────────────────────────────────────────────────────────────────
  // Step 2 – API Config
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _step2ApiConfig() => _StepScaffold(
        title: 'إعداد مصدر البيانات',
        children: [
          _label('الشركة / النظام'),
          Row(
            children: ReportCompany.values.map((c) {
              final sel = _company == c;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _company = c),
                  child: Container(
                    margin: EdgeInsets.only(
                        left: c == ReportCompany.zfi ? 8 : 0),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: sel
                          ? _accent.withValues(alpha: 0.1)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: sel ? _accent : Colors.grey.shade300,
                          width: sel ? 2 : 1),
                    ),
                    child: Text(c.displayName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: sel ? _accent : Colors.grey.shade600)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _label('مسار الـ API (Endpoint)'),
          TextField(
            controller: _endpointCtrl,
            decoration: const InputDecoration(
              hintText: 'مثال: REPORT/stockBalance',
              prefixText: '.../api/v2/jalaf/',
              prefixStyle: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          _label('خصائص العرض'),
          _switchRow('تقرير حسب المستودع (byWarehouse)',
              _byWarehouse, (v) => setState(() => _byWarehouse = v)),
          _switchRow('إظهار صف الإجماليات', _showSummaryRow,
              (v) => setState(() => _showSummaryRow = v)),
          const SizedBox(height: 12),
          _label('تجميع الصفوف حسب حقل (اختياري)'),
          TextFormField(
            initialValue: _groupByField,
            decoration: const InputDecoration(
                hintText: 'مثال: item  (اتركه فارغاً إن لم يلزم)'),
            onChanged: (v) => _groupByField = v,
          ),
          const SizedBox(height: 16),
          _label('معاملات ثابتة في الـ URL (Fixed Params)'),
          ..._fixedParams.asMap().entries.map((e) => _KvRow(
                pair: e.value,
                onRemove: () =>
                    setState(() => _fixedParams.removeAt(e.key)),
                onChanged: () => setState(() {}),
              )),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => setState(
                () => _fixedParams.add(_KvPair(key: '', value: ''))),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('إضافة معامل ثابت'),
          ),
        ],
      );

  // ─────────────────────────────────────────────────────────────────────────────
  // Step 3 – Input Parameters
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _step3Inputs() => _StepScaffold(
        title: 'مدخلات المستخدم',
        subtitle:
            'حدد ما يملؤه المستخدم قبل تشغيل التقرير (فترات زمنية، اختيارات، إلخ)',
        children: [
          ..._inputs.asMap().entries.map((e) => _InputEditor(
                input: e.value,
                index: e.key + 1,
                onRemove: () =>
                    setState(() => _inputs.removeAt(e.key)),
                onChanged: (updated) =>
                    setState(() => _inputs[e.key] = updated),
              )),
          if (_inputs.isNotEmpty) const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => setState(() => _inputs.add(ReportInput(
                  key: 'param${_inputs.length + 1}',
                  labelAr: '',
                  type: ReportInputType.date,
                ))),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('إضافة مدخل'),
          ),
        ],
      );

  // ─────────────────────────────────────────────────────────────────────────────
  // Step 4 – Fields
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _step4Fields() => _StepScaffold(
        title: 'أعمدة العرض',
        subtitle: 'حدد الحقول التي تظهر في التقرير وكيفية عرضها',
        children: [
          ..._fields.asMap().entries.map((e) => _FieldEditor(
                field: e.value,
                index: e.key + 1,
                onRemove: () =>
                    setState(() => _fields.removeAt(e.key)),
                onChanged: (updated) =>
                    setState(() => _fields[e.key] = updated),
                onMoveUp: e.key > 0
                    ? () => setState(() {
                          final tmp = _fields[e.key - 1];
                          _fields[e.key - 1] = _fields[e.key];
                          _fields[e.key] = tmp;
                        })
                    : null,
                onMoveDown: e.key < _fields.length - 1
                    ? () => setState(() {
                          final tmp = _fields[e.key + 1];
                          _fields[e.key + 1] = _fields[e.key];
                          _fields[e.key] = tmp;
                        })
                    : null,
              )),
          if (_fields.isNotEmpty) const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => setState(() => _fields.add(ReportField(
                  key: 'field${_fields.length + 1}',
                  labelAr: '',
                ))),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('إضافة عمود'),
          ),
        ],
      );

  // ─────────────────────────────────────────────────────────────────────────────
  // Step 5 – Filters
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _step5Filters() => _StepScaffold(
        title: 'الفلاتر (ما بعد الجلب)',
        subtitle: 'قواعد تصفية البيانات بعد استلامها من الـ API',
        children: [
          ..._filters.asMap().entries.map((e) => _FilterEditor(
                filter: e.value,
                index: e.key + 1,
                onRemove: () =>
                    setState(() => _filters.removeAt(e.key)),
                onChanged: (updated) =>
                    setState(() => _filters[e.key] = updated),
              )),
          if (_filters.isNotEmpty) const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => setState(() => _filters.add(ReportFilter(
                  field: '',
                  operator: FilterOperator.ne,
                  value: '0',
                ))),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('إضافة فلتر'),
          ),
        ],
      );

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(AppConstants.primaryColor))),
      );

  Widget _switchRow(
          String label, bool value, ValueChanged<bool> onChanged) =>
      Row(
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
          Switch(
            value: value,
            activeThumbColor: _accent,
            onChanged: onChanged,
          ),
        ],
      );
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StepBar extends StatelessWidget {
  final List<String> steps;
  final int current;
  final ValueChanged<int> onTap;

  const _StepBar(
      {required this.steps, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: steps.asMap().entries.map((e) {
          final i = e.key;
          final done = i < current;
          final active = i == current;
          final color = active
              ? const Color(AppConstants.accentColor)
              : done
                  ? Colors.green
                  : Colors.grey.shade400;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (i > 0)
                        Expanded(
                          child: Container(
                              height: 2,
                              color: done
                                  ? Colors.green
                                  : Colors.grey.shade200),
                        ),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: active || done
                              ? color
                              : Colors.grey.shade100,
                          shape: BoxShape.circle,
                          border: Border.all(color: color),
                        ),
                        child: Center(
                          child: done
                              ? const Icon(Icons.check,
                                  size: 14, color: Colors.white)
                              : Text('${i + 1}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: active
                                          ? Colors.white
                                          : Colors.grey.shade500)),
                        ),
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                              height: 2,
                              color: i < current
                                  ? Colors.green
                                  : Colors.grey.shade200),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(e.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10,
                          color: active ? color : Colors.grey.shade500,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.normal)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int step;
  final int total;
  final bool canNext;
  final VoidCallback? onBack;
  final VoidCallback? onNext;

  const _NavBar(
      {required this.step,
      required this.total,
      required this.canNext,
      this.onBack,
      this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          if (onBack != null)
            OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('السابق'),
            ),
          const Spacer(),
          if (onNext != null)
            FilledButton.icon(
              onPressed: canNext ? onNext : null,
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(AppConstants.accentColor)),
              icon: const Text('التالي'),
              label: const Icon(Icons.arrow_back, size: 16),
            ),
          if (onNext == null)
            Text('${step + 1} من $total',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _StepScaffold(
      {required this.title, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(AppConstants.primaryColor))),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

// ── KvPair for fixed params ───────────────────────────────────────────────────

class _KvPair {
  String key;
  String value;
  _KvPair({required this.key, required this.value});
}

class _KvRow extends StatelessWidget {
  final _KvPair pair;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _KvRow(
      {required this.pair, required this.onRemove, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: TextEditingController(text: pair.key),
              decoration: const InputDecoration(
                  labelText: 'المفتاح', isDense: true),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              onChanged: (v) {
                pair.key = v;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: pair.value),
              decoration: const InputDecoration(
                  labelText: 'القيمة', isDense: true),
              style: const TextStyle(fontSize: 12),
              onChanged: (v) {
                pair.value = v;
                onChanged();
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Colors.red),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

// ── Input editor ──────────────────────────────────────────────────────────────

class _InputEditor extends StatelessWidget {
  final ReportInput input;
  final int index;
  final VoidCallback onRemove;
  final ValueChanged<ReportInput> onChanged;

  const _InputEditor(
      {required this.input,
      required this.index,
      required this.onRemove,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('مدخل #$index',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                  onPressed: onRemove),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: input.labelAr),
                  decoration: const InputDecoration(
                      labelText: 'التسمية (عربي)', isDense: true),
                  onChanged: (v) => onChanged(ReportInput(
                      key: input.key,
                      labelAr: v,
                      type: input.type,
                      required: input.required,
                      defaultValue: input.defaultValue,
                      paramName: input.paramName)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: input.key),
                  decoration: const InputDecoration(
                      labelText: 'المعرّف (key)', isDense: true),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  onChanged: (v) => onChanged(ReportInput(
                      key: v,
                      labelAr: input.labelAr,
                      type: input.type,
                      required: input.required,
                      defaultValue: input.defaultValue,
                      paramName: input.paramName)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ReportInputType>(
                  value: input.type,
                  decoration: const InputDecoration(
                      labelText: 'النوع', isDense: true),
                  items: ReportInputType.values
                      .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.labelAr,
                              style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => onChanged(ReportInput(
                      key: input.key,
                      labelAr: input.labelAr,
                      type: v ?? input.type,
                      required: input.required,
                      defaultValue: input.defaultValue,
                      paramName: input.paramName)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller:
                      TextEditingController(text: input.defaultValue ?? ''),
                  decoration: const InputDecoration(
                      labelText: 'القيمة الافتراضية', isDense: true),
                  onChanged: (v) => onChanged(ReportInput(
                      key: input.key,
                      labelAr: input.labelAr,
                      type: input.type,
                      required: input.required,
                      defaultValue: v.isEmpty ? null : v,
                      paramName: input.paramName)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Field editor ──────────────────────────────────────────────────────────────

class _FieldEditor extends StatelessWidget {
  final ReportField field;
  final int index;
  final VoidCallback onRemove;
  final ValueChanged<ReportField> onChanged;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _FieldEditor(
      {required this.field,
      required this.index,
      required this.onRemove,
      required this.onChanged,
      this.onMoveUp,
      this.onMoveDown});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: field.visible ? Colors.grey.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Column(
                children: [
                  if (onMoveUp != null)
                    GestureDetector(
                        onTap: onMoveUp,
                        child: const Icon(Icons.arrow_drop_up, size: 20)),
                  if (onMoveDown != null)
                    GestureDetector(
                        onTap: onMoveDown,
                        child: const Icon(Icons.arrow_drop_down, size: 20)),
                ],
              ),
              const SizedBox(width: 4),
              Text('عمود #$index',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              Text('مرئي', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              Switch(
                value: field.visible,
                activeThumbColor: const Color(AppConstants.accentColor),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) => onChanged(field.copyWith(visible: v)),
              ),
              IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                  onPressed: onRemove),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: TextEditingController(text: field.key),
                  decoration: const InputDecoration(
                      labelText: 'مفتاح الحقل (API)', isDense: true),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  onChanged: (v) => onChanged(field.copyWith(key: v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: TextEditingController(text: field.labelAr),
                  decoration: const InputDecoration(
                      labelText: 'التسمية (عربي)', isDense: true),
                  onChanged: (v) => onChanged(field.copyWith(labelAr: v)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<FieldFormat>(
                  value: field.format,
                  decoration: const InputDecoration(
                      labelText: 'التنسيق', isDense: true),
                  items: FieldFormat.values
                      .map((f) => DropdownMenuItem(
                          value: f,
                          child: Text(f.labelAr,
                              style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) =>
                      onChanged(field.copyWith(format: v ?? field.format)),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller:
                      TextEditingController(text: field.width.toInt().toString()),
                  decoration: const InputDecoration(
                      labelText: 'العرض', isDense: true, suffixText: 'px'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => onChanged(
                      field.copyWith(width: double.tryParse(v) ?? field.width)),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller:
                      TextEditingController(text: field.wrapLines.toString()),
                  decoration: const InputDecoration(
                      labelText: 'سطور', isDense: true),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => onChanged(field.copyWith(
                      wrapLines: int.tryParse(v) ?? field.wrapLines)),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ترتيب',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
                  Switch(
                    value: field.sortable,
                    activeThumbColor: const Color(AppConstants.accentColor),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (v) => onChanged(field.copyWith(sortable: v)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Filter editor ─────────────────────────────────────────────────────────────

class _FilterEditor extends StatelessWidget {
  final ReportFilter filter;
  final int index;
  final VoidCallback onRemove;
  final ValueChanged<ReportFilter> onChanged;

  const _FilterEditor(
      {required this.filter,
      required this.index,
      required this.onRemove,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('فلتر #$index',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                  onPressed: onRemove),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: filter.field),
                  decoration: const InputDecoration(
                      labelText: 'الحقل', isDense: true),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  onChanged: (v) => onChanged(ReportFilter(
                      field: v,
                      operator: filter.operator,
                      value: filter.value)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<FilterOperator>(
                  value: filter.operator,
                  decoration: const InputDecoration(
                      labelText: 'الشرط', isDense: true),
                  items: FilterOperator.values
                      .map((o) => DropdownMenuItem(
                          value: o,
                          child: Text(o.labelAr,
                              style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (v) => onChanged(ReportFilter(
                      field: filter.field,
                      operator: v ?? filter.operator,
                      value: filter.value)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: TextEditingController(
                      text: filter.value?.toString() ?? ''),
                  decoration: const InputDecoration(
                      labelText: 'القيمة', isDense: true),
                  onChanged: (v) => onChanged(ReportFilter(
                      field: filter.field,
                      operator: filter.operator,
                      value: v)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
