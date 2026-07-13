// lib/screens/web/task_checklist_form_screen.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../models/task_checklist_models.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/helpers.dart';

// ─── Design tokens ─────────────────────────────────────────────────────────────
const _kAccent    = Color(0xFF7C3AED);
const _kSuccess   = Color(0xFF059669);
const _kDanger    = Color(0xFFDC2626);
const _kWarning   = Color(0xFFD97706);
const _kBg        = Color(0xFFF5F6FA);
const _kSurface   = Colors.white;
const _kBorder    = Color(0xFFE8E9F0);
const _kText      = Color(0xFF1A1F36);
const _kTextMuted = Color(0xFF8F95B2);
const _kRadiusLg  = 14.0;
const _kRadius    = 10.0;
const _kRadiusSm  = 6.0;

// ══════════════════════════════════════════════════════════════════════════════
class TaskChecklistFormScreen extends StatefulWidget {
  final TaskChecklist checklist;
  final DateTime scheduledDate;

  const TaskChecklistFormScreen({
    super.key,
    required this.checklist,
    required this.scheduledDate,
  });

  @override
  State<TaskChecklistFormScreen> createState() =>
      _TaskChecklistFormScreenState();
}

class _TaskChecklistFormScreenState extends State<TaskChecklistFormScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  late List<_TaskState> _taskStates;
  TaskChecklistResponse? _existingResponse;
  bool _loading = true;
  bool _saving  = false;

  // Animation controllers for check animations
  final Map<int, AnimationController> _checkAnims = {};

  @override
  void initState() {
    super.initState();
    _initTaskStates();
    _loadExistingResponse();
  }

  @override
  void dispose() {
    for (final ctrl in _checkAnims.values) ctrl.dispose();
    for (final ts in _taskStates) ts.dispose();
    super.dispose();
  }

  void _initTaskStates() {
    _taskStates = widget.checklist.tasks
        .map((t) => _TaskState(task: t))
        .toList();

    for (int i = 0; i < _taskStates.length; i++) {
      _checkAnims[i] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350),
      );
    }
  }

  Future<void> _loadExistingResponse() async {
    setState(() => _loading = true);
    try {
      final existing = await SupabaseService.getTaskChecklistResponse(
        checklistId: widget.checklist.id,
        date: widget.scheduledDate,
      );
      if (existing != null && mounted) {
        _existingResponse = existing;
        // Restore checked states
        for (final taskState in _taskStates) {
          final savedResponse = existing.taskResponses
              .where((r) => r.taskId == taskState.task.id)
              .firstOrNull;
          if (savedResponse != null && savedResponse.isDone) {
            taskState.isDone  = true;
            taskState.notesCtrl.text = savedResponse.notes ?? '';
            final idx = _taskStates.indexOf(taskState);
            _checkAnims[idx]?.forward();
          }
        }
      }
    } catch (e) {
      debugPrint('loadExistingResponse error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Toggle a task ──────────────────────────────────────────────────────────
  Future<void> _toggleTask(int index) async {
    final ts = _taskStates[index];
    setState(() => ts.isDone = !ts.isDone);

    if (ts.isDone) {
      _checkAnims[index]?.forward();
    } else {
      _checkAnims[index]?.reverse();
    }

    await _autosave();
  }

  // ── Auto-save after every change ───────────────────────────────────────────
  Future<void> _autosave() async {
    final isDone   = _taskStates.every((ts) => ts.isDone);
    final hasAny   = _taskStates.any((ts) => ts.isDone);
    final status   = isDone ? TaskChecklistStatus.completed
                  : hasAny ? TaskChecklistStatus.inProgress
                  : TaskChecklistStatus.pending;

    final responses = _taskStates.map((ts) => TaskItemResponse(
      taskId:  ts.task.id,
      isDone:  ts.isDone,
      notes:   ts.notesCtrl.text.trim().isEmpty ? null : ts.notesCtrl.text.trim(),
      doneAt:  ts.isDone ? DateTime.now() : null,
    )).toList();

    try {
      _existingResponse = await SupabaseService.upsertTaskChecklistResponse(
        checklistId:   widget.checklist.id,
        scheduledDate: widget.scheduledDate,
        taskResponses: responses,
        status:        status,
      );
    } catch (e) {
      debugPrint('autosave error: $e');
    }
  }

  // ── Submit all ─────────────────────────────────────────────────────────────
  Future<void> _submitAll() async {
    final undone = _taskStates.where((ts) => !ts.isDone).toList();
    if (undone.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _IncompleteDialog(undoneCount: undone.length),
      );
      if (confirmed != true) return;
    }

    setState(() => _saving = true);
    try {
      final responses = _taskStates.map((ts) => TaskItemResponse(
        taskId: ts.task.id,
        isDone: ts.isDone,
        notes:  ts.notesCtrl.text.trim().isEmpty ? null : ts.notesCtrl.text.trim(),
        doneAt: ts.isDone ? DateTime.now() : null,
      )).toList();

      await SupabaseService.upsertTaskChecklistResponse(
        checklistId:   widget.checklist.id,
        scheduledDate: widget.scheduledDate,
        taskResponses: responses,
        status:        TaskChecklistStatus.completed,
      );

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _SuccessDialog(
            completedCount: _taskStates.where((ts) => ts.isDone).length,
            totalCount: _taskStates.length,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) Helpers.showSnackBar(context, 'حدث خطأ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 640;
    final doneCount = _taskStates.where((ts) => ts.isDone).length;
    final total     = _taskStates.length;
    final progress  = total == 0 ? 0.0 : doneCount / total;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: _buildAppBar(doneCount, total),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _kAccent))
            : Column(children: [
                // Progress bar
                _buildProgressBar(progress, doneCount, total),
                // Task list
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 14 : 20,
                      vertical: 14,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 700),
                        child: Column(children: [
                          // Checklist info card
                          _buildHeaderCard(isMobile),
                          const SizedBox(height: 14),
                          // Tasks
                          ...List.generate(_taskStates.length, (i) =>
                            _buildTaskCard(i, isMobile)),
                          const SizedBox(height: 24),
                          // Submit button
                          _buildSubmitButton(doneCount, total, isMobile),
                          const SizedBox(height: 20),
                        ]),
                      ),
                    ),
                  ),
                ),
              ]),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(int done, int total) => AppBar(
    elevation: 0,
    scrolledUnderElevation: 1,
    backgroundColor: _kSurface,
    surfaceTintColor: _kSurface,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _kText),
      onPressed: () => Navigator.pop(context),
    ),
    title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.checklist.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kText),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      Text('$done من $total مهمة مكتملة',
          style: const TextStyle(fontSize: 11, color: _kTextMuted)),
    ]),
    actions: [
      if (_saving)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: _kAccent)),
        ),
    ],
  );

  Widget _buildProgressBar(double progress, int done, int total) {
    final color = progress == 1.0 ? _kSuccess
                : progress > 0.5 ? _kWarning
                : _kAccent;
    return Container(
      color: _kSurface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('التقدم', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _kTextMuted)),
          Text('${(progress * 100).toInt()}%',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (_, val, __) => LinearProgressIndicator(
              value: val,
              minHeight: 7,
              backgroundColor: _kBorder,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeaderCard(bool isMobile) => Container(
    padding: EdgeInsets.all(isMobile ? 14 : 18),
    decoration: BoxDecoration(
      color: _kAccent.withOpacity(0.05),
      borderRadius: BorderRadius.circular(_kRadiusLg),
      border: Border.all(color: _kAccent.withOpacity(0.15)),
    ),
    child: Row(children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: _kAccent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(_kRadius),
        ),
        child: const Icon(Icons.task_alt_rounded, color: _kAccent, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.checklist.title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kText)),
        if (widget.checklist.description != null) ...[
          const SizedBox(height: 3),
          Text(widget.checklist.description!,
              style: const TextStyle(fontSize: 12, color: _kTextMuted)),
        ],
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${widget.scheduledDate.day}/${widget.scheduledDate.month}/${widget.scheduledDate.year}',
            style: const TextStyle(fontSize: 10.5, color: _kAccent, fontWeight: FontWeight.w600),
          ),
        ),
      ])),
    ]),
  );

  Widget _buildTaskCard(int index, bool isMobile) {
    final ts    = _taskStates[index];
    final anim  = _checkAnims[index]!;

    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final done = ts.isDone;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: done ? _kSuccess.withOpacity(0.04) : _kSurface,
            borderRadius: BorderRadius.circular(_kRadiusLg),
            border: Border.all(
              color: done ? _kSuccess.withOpacity(0.3) : _kBorder,
              width: done ? 1.5 : 1,
            ),
            boxShadow: done ? [] : [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Main row
            InkWell(
              onTap: () => _toggleTask(index),
              borderRadius: BorderRadius.circular(_kRadiusLg),
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 14 : 16),
                child: Row(children: [
                  // Check circle
                  GestureDetector(
                    onTap: () => _toggleTask(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: done ? _kSuccess : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: done ? _kSuccess : _kBorder,
                          width: 2,
                        ),
                      ),
                      child: done
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                          : Center(child: Text('${index + 1}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                  color: _kTextMuted))),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ts.task.title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: done ? _kSuccess : _kText,
                          decoration: done ? TextDecoration.lineThrough : null,
                          decorationColor: _kSuccess,
                        ),
                      ),
                      if (ts.task.description != null) ...[
                        const SizedBox(height: 3),
                        Text(ts.task.description!,
                            style: TextStyle(
                              fontSize: 12,
                              color: done ? _kSuccess.withOpacity(0.6) : _kTextMuted,
                            )),
                      ],
                    ],
                  )),
                  // Status badge
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: done ? _kSuccess.withOpacity(0.1) : _kBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: done ? _kSuccess.withOpacity(0.3) : _kBorder),
                    ),
                    child: Text(
                      done ? 'تم ✓' : 'معلق',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: done ? _kSuccess : _kTextMuted,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            // Notes expander (only if done)
            if (done) ...[
              Divider(height: 1, color: _kSuccess.withOpacity(0.15)),
              Padding(
                padding: EdgeInsets.fromLTRB(isMobile ? 14 : 16, 10, isMobile ? 14 : 16, 12),
                child: Row(children: [
                  const Icon(Icons.notes_rounded, size: 14, color: _kTextMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: ts.notesCtrl,
                      style: const TextStyle(fontSize: 12.5),
                      maxLines: 2,
                      onChanged: (_) => _autosave(),
                      decoration: InputDecoration(
                        hintText: 'ملاحظات (اختياري)...',
                        hintStyle: const TextStyle(fontSize: 12, color: _kTextMuted),
                        filled: true,
                        fillColor: _kSuccess.withOpacity(0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(_kRadiusSm),
                          borderSide: BorderSide(color: _kSuccess.withOpacity(0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(_kRadiusSm),
                          borderSide: BorderSide(color: _kSuccess.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(_kRadiusSm),
                          borderSide: const BorderSide(color: _kSuccess, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        isDense: true,
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ]),
        );
      },
    );
  }

  Widget _buildSubmitButton(int done, int total, bool isMobile) {
    final allDone = done == total;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _saving ? null : _submitAll,
        style: FilledButton.styleFrom(
          backgroundColor: allDone ? _kSuccess : _kAccent,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kRadius)),
          padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 15),
        ),
        child: _saving
            ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 10),
                Text('جارٍ الإرسال...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ])
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(allDone ? Icons.task_alt_rounded : Icons.send_rounded,
                    size: 17, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  allDone ? 'إرسال القائمة مكتملة ✓' : 'إرسال ($done/$total مكتملة)',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ]),
      ),
    );
  }
}

// ─── Task state holder ─────────────────────────────────────────────────────────
class _TaskState {
  final TaskItem task;
  bool isDone;
  final TextEditingController notesCtrl;

  _TaskState({required this.task, this.isDone = false})
      : notesCtrl = TextEditingController();

  void dispose() => notesCtrl.dispose();
}

// ─── Incomplete dialog ─────────────────────────────────────────────────────────
class _IncompleteDialog extends StatelessWidget {
  final int undoneCount;
  const _IncompleteDialog({required this.undoneCount});

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: ui.TextDirection.rtl,
    child: AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _kWarning.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.warning_amber_rounded, color: _kWarning, size: 20),
        ),
        const SizedBox(width: 10),
        const Text('قائمة غير مكتملة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ]),
      content: Text(
        'لا تزال هناك $undoneCount مهمة غير مكتملة. هل تريد الإرسال على أنها جزئية؟',
        style: const TextStyle(fontSize: 13.5, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء', style: TextStyle(color: _kTextMuted)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: _kWarning),
          child: const Text('إرسال كجزئي'),
        ),
      ],
    ),
  );
}

// ─── Success dialog ────────────────────────────────────────────────────────────
class _SuccessDialog extends StatelessWidget {
  final int completedCount;
  final int totalCount;
  const _SuccessDialog({required this.completedCount, required this.totalCount});

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: ui.TextDirection.rtl,
    child: AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: _kSuccess.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded, color: _kSuccess, size: 40),
        ),
        const SizedBox(height: 16),
        const Text('تم الإرسال بنجاح!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kText)),
        const SizedBox(height: 8),
        Text(
          'تم إكمال $completedCount من $totalCount مهمة',
          style: const TextStyle(fontSize: 13.5, color: _kTextMuted),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: _kSuccess),
            child: const Text('تم', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    ),
  );
}