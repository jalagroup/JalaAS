import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jala_as/models/report_models.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/helpers.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF0891B2);
const _kBg = Color(0xFFF1F5F9);
const _kCard = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE2E8F0);
const _kTextPrimary = Color(0xFF0F172A);
const _kTextSecondary = Color(0xFF64748B);
const _kSuccess = Color(0xFF059669);
const _kWarning = Color(0xFFD97706);

// ─── Screen ───────────────────────────────────────────────────────────────────

class ReportListFillScreen extends StatefulWidget {
  final ReportList reportList;
  final ReportListResponse? existingResponse; // non-null = editing

  const ReportListFillScreen({
    super.key,
    required this.reportList,
    this.existingResponse,
  });

  @override
  State<ReportListFillScreen> createState() => _ReportListFillScreenState();
}

class _ReportListFillScreenState extends State<ReportListFillScreen> {
  // determinantId → selected option value
  final Map<String, String> _determinantValues = {};

  // fieldId → TextEditingController
  final Map<String, TextEditingController> _fieldControllers = {};

  bool _saving = false;
  bool _autoSaving = false;
  bool _draftLoaded = false;
  // Date the in-progress session belongs to
  DateTime _sessionDate = DateTime.now();

  Timer? _autoSaveTimer;

  bool get _isEdit => widget.existingResponse != null;
  String? get _userId => SupabaseService.currentUserId;

  @override
  void initState() {
    super.initState();
    _initControllers();
    if (!_isEdit) {
      _initDraft();
    } else {
      _draftLoaded = true;
    }
  }

  void _initControllers() {
    final rl = widget.reportList;
    final existing = widget.existingResponse;

    for (final det in rl.determinants) {
      _determinantValues[det.id] =
          existing?.determinantValues[det.id]?.toString() ?? '';
    }

    for (final field in rl.fields) {
      _fieldControllers[field.id] = TextEditingController(
        text: existing?.fieldResponses[field.id] ?? '',
      );
    }
  }

  Future<void> _initDraft() async {
    final uid = _userId;
    if (uid == null) {
      setState(() => _draftLoaded = true);
      return;
    }

    final draft = await SupabaseService.getReportListDraft(
      reportListId: widget.reportList.id,
      userId: uid,
    );

    if (draft == null) {
      setState(() => _draftLoaded = true);
      return;
    }

    if (draft.isFromToday) {
      // Silently restore today's draft
      _applyDraft(draft);
      setState(() {
        _sessionDate = draft.draftDate;
        _draftLoaded = true;
      });
    } else {
      // Draft is from a previous day — ask the user
      setState(() => _draftLoaded = true);
      if (mounted) {
        await _showCrossDayDialog(draft);
      }
    }
  }

  void _applyDraft(ReportListDraft draft) {
    for (final det in widget.reportList.determinants) {
      final v = draft.determinantValues[det.id]?.toString();
      if (v != null) _determinantValues[det.id] = v;
    }
    for (final field in widget.reportList.fields) {
      final text = draft.fieldResponses[field.id];
      if (text != null) {
        _fieldControllers[field.id]?.text = text;
      }
    }
  }

  Future<void> _showCrossDayDialog(ReportListDraft draft) async {
    final formatted =
        DateFormat('yyyy/MM/dd', 'ar').format(draft.draftDate);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.history_rounded, color: _kWarning, size: 22),
              SizedBox(width: 8),
              Text('جلسة سابقة غير مكتملة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Text(
            'يوجد مسودة محفوظة بتاريخ $formatted.\n'
            'هل تريد متابعة ما بدأته أم البدء من جديد؟',
            style: const TextStyle(fontSize: 13, color: _kTextSecondary, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('بدء جديد',
                  style: TextStyle(color: _kTextSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('متابعة السابق'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      // Continue previous session — keep its date so submit goes to that date
      setState(() => _sessionDate = draft.draftDate);
      _applyDraft(draft);
    } else {
      // Discard old draft, start fresh with today's date
      setState(() => _sessionDate = DateTime.now());
      final uid = _userId;
      if (uid != null) {
        await SupabaseService.deleteReportListDraft(
          reportListId: widget.reportList.id,
          userId: uid,
        );
      }
    }
  }

  // ── Auto-save ─────────────────────────────────────────────────

  void _scheduleAutoSave() {
    if (_isEdit) return; // editing a submitted response — no drafts
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), _saveDraft);
  }

  Future<void> _saveDraft() async {
    final uid = _userId;
    if (uid == null) return;

    setState(() => _autoSaving = true);

    final fieldResponses = {
      for (final e in _fieldControllers.entries) e.key: e.value.text.trim(),
    };
    final detValues = Map<String, dynamic>.from(_determinantValues);

    try {
      await SupabaseService.upsertReportListDraft(
        reportListId: widget.reportList.id,
        userId: uid,
        draftDate: _sessionDate,
        determinantValues: detValues,
        fieldResponses: fieldResponses,
      );
    } catch (_) {
      // silent — auto-save failures should not disrupt the user
    } finally {
      if (mounted) setState(() => _autoSaving = false);
    }
  }

  Future<void> _clearDraft() async {
    _autoSaveTimer?.cancel();
    final uid = _userId;
    if (uid == null) return;
    await SupabaseService.deleteReportListDraft(
      reportListId: widget.reportList.id,
      userId: uid,
    );
  }

  // ── Validation & submit ───────────────────────────────────────

  bool _validate() {
    for (final field in widget.reportList.fields) {
      if (field.isRequired &&
          (_fieldControllers[field.id]?.text.trim().isEmpty ?? true)) {
        Helpers.showSnackBar(
            context, 'حقل "${field.title}" مطلوب', isError: true);
        return false;
      }
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() => _saving = true);

    try {
      final fieldResponses = {
        for (final e in _fieldControllers.entries)
          e.key: e.value.text.trim(),
      };
      final detValues = Map<String, dynamic>.from(_determinantValues);

      if (_isEdit) {
        await SupabaseService.updateReportListResponse(
          responseId: widget.existingResponse!.id,
          determinantValues: detValues,
          fieldResponses: fieldResponses,
        );
      } else {
        await SupabaseService.submitReportListResponse(
          reportListId: widget.reportList.id,
          responseDate: _sessionDate,
          determinantValues: detValues,
          fieldResponses: fieldResponses,
        );
        await _clearDraft();
      }

      if (mounted) {
        Helpers.showSnackBar(
            context,
            _isEdit ? 'تم تحديث التقرير بنجاح' : 'تم إرسال التقرير بنجاح');
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في الإرسال: $e', isError: true);
      }
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final rl = widget.reportList;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
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
              Text(
                rl.title,
                style: const TextStyle(
                    color: _kTextPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
              if (!_isEdit)
                _AutoSaveIndicator(
                    autoSaving: _autoSaving, draftLoaded: _draftLoaded)
              else
                const Text(
                  'تعديل الإجابة',
                  style: TextStyle(color: _kTextSecondary, fontSize: 11),
                ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 16),
                label: Text(_isEdit ? 'حفظ التعديل' : 'إرسال',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                onPressed: _saving ? null : _submit,
              ),
            ),
          ],
        ),
        body: !_draftLoaded
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Session date badge (when continuing a past draft) ──
                    if (!_isEdit && !_sessionDate.isToday) ...[
                      _InfoCard(
                        icon: Icons.calendar_today_rounded,
                        color: _kWarning,
                        child: Text(
                          'أنت تكمل تقرير يوم ${DateFormat('EEEE، yyyy/MM/dd', 'ar').format(_sessionDate)}',
                          style: const TextStyle(
                              fontSize: 13, color: _kTextPrimary, height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Description ───────────────────────────────────────
                    if (rl.description?.isNotEmpty == true)
                      _InfoCard(
                        icon: Icons.info_outline_rounded,
                        color: _kAccent,
                        child: Text(rl.description!,
                            style: const TextStyle(
                                fontSize: 13,
                                color: _kTextPrimary,
                                height: 1.5)),
                      ),

                    // ── Determinants ──────────────────────────────────────
                    if (rl.determinants.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _SectionHeader(
                          label: 'المحددات', icon: Icons.tune_rounded),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: _cardDecor(),
                        child: Column(
                          children: rl.determinants.map((det) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(det.name,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: _kTextPrimary)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    initialValue:
                                        _determinantValues[det.id]?.isEmpty ==
                                                true
                                            ? null
                                            : _determinantValues[det.id],
                                    decoration: InputDecoration(
                                      hintText: 'اختر ${det.name}',
                                      hintStyle: const TextStyle(
                                          fontSize: 13,
                                          color: _kTextSecondary),
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                              color: _kBorder)),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                              color: _kBorder)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                    ),
                                    items: det.options
                                        .map((o) => DropdownMenuItem(
                                              value: o.value,
                                              child: Text(o.value,
                                                  style: const TextStyle(
                                                      fontSize: 13)),
                                            ))
                                        .toList(),
                                    onChanged: (v) {
                                      setState(() =>
                                          _determinantValues[det.id] = v ?? '');
                                      _scheduleAutoSave();
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],

                    // ── Fields ────────────────────────────────────────────
                    const SizedBox(height: 14),
                    _SectionHeader(
                        label: 'الحقول', icon: Icons.edit_note_rounded),
                    const SizedBox(height: 10),
                    ...rl.fields.map((field) {
                      final ctrl = _fieldControllers[field.id]!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: _cardDecor(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(field.title,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: _kTextPrimary)),
                                  ),
                                  if (field.isRequired)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: const Color(0xFFFCA5A5)),
                                      ),
                                      child: const Text('مطلوب',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFFDC2626),
                                              fontWeight: FontWeight.w600)),
                                    ),
                                ],
                              ),
                              if (field.hint?.isNotEmpty == true) ...[
                                const SizedBox(height: 4),
                                Text(field.hint!,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: _kTextSecondary,
                                        fontStyle: FontStyle.italic)),
                              ],
                              const SizedBox(height: 10),
                              TextField(
                                controller: ctrl,
                                maxLines: 5,
                                minLines: 3,
                                textDirection: ui.TextDirection.rtl,
                                onChanged: (_) => _scheduleAutoSave(),
                                decoration: InputDecoration(
                                  hintText: field.hint?.isNotEmpty == true
                                      ? field.hint
                                      : 'اكتب هنا...',
                                  hintStyle: const TextStyle(
                                      fontSize: 13, color: _kTextSecondary),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          const BorderSide(color: _kBorder)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          const BorderSide(color: _kBorder)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: _kAccent, width: 1.5)),
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 8),

                    // ── Submit button (bottom) ──────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kSuccess,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                            _isEdit ? 'حفظ التعديل' : 'إرسال التقرير',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        onPressed: _saving ? null : _submit,
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}

// ─── Auto-save indicator ──────────────────────────────────────────────────────

class _AutoSaveIndicator extends StatelessWidget {
  final bool autoSaving;
  final bool draftLoaded;

  const _AutoSaveIndicator(
      {required this.autoSaving, required this.draftLoaded});

  @override
  Widget build(BuildContext context) {
    if (!draftLoaded) {
      return const SizedBox(
        width: 10,
        height: 10,
        child: CircularProgressIndicator(strokeWidth: 1.5, color: _kTextSecondary),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (autoSaving)
          const SizedBox(
            width: 9,
            height: 9,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: _kTextSecondary),
          )
        else
          const Icon(Icons.cloud_done_rounded,
              size: 11, color: _kSuccess),
        const SizedBox(width: 4),
        Text(
          autoSaving ? 'جارٍ الحفظ...' : 'محفوظ تلقائياً',
          style: TextStyle(
              fontSize: 10,
              color: autoSaving ? _kTextSecondary : _kSuccess),
        ),
      ],
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

extension _DateHelpers on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }
}

BoxDecoration _cardDecor() => BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _kBorder),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2))
      ],
    );

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _kAccent),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _kTextPrimary)),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: _kBorder)),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Widget child;

  const _InfoCard({
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}
