// lib/screens/web/task_checklist_builder_screen.dart
import 'package:flutter/material.dart';
import 'package:jala_as/models/task_checklist_models.dart';
import 'package:jala_as/models/user.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/helpers.dart';
import 'package:uuid/uuid.dart';
import 'dart:ui' as ui;


// ─── Design tokens (same palette as quality builder) ──────────────────────────
const _kAccent      = Color(0xFF7C3AED);
const _kSuccess     = Color(0xFF059669);
const _kDanger      = Color(0xFFDC2626);
const _kWarning     = Color(0xFFD97706);
const _kBg          = Color(0xFFF5F6FA);
const _kSurface     = Colors.white;
const _kBorder      = Color(0xFFE8E9F0);
const _kText        = Color(0xFF1A1F36);
const _kTextMuted   = Color(0xFF8F95B2);
const _kTextSub     = Color(0xFF4E5D78);
const _kRadius      = 10.0;
const _kRadiusSm    = 6.0;
const _kRadiusLg    = 14.0;

BoxDecoration _card({bool shadow = true}) => BoxDecoration(
  color: _kSurface,
  borderRadius: BorderRadius.circular(_kRadiusLg),
  border: Border.all(color: _kBorder),
  boxShadow: shadow
      ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]
      : null,
);

// ─── Day chip data ─────────────────────────────────────────────────────────────
const _kDays = [
  (1, 'الاثنين'),
  (2, 'الثلاثاء'),
  (3, 'الأربعاء'),
  (4, 'الخميس'),
  (5, 'الجمعة'),
  (6, 'السبت'),
  (7, 'الأحد'),
];

// ══════════════════════════════════════════════════════════════════════════════
class TaskChecklistBuilderScreen extends StatefulWidget {
  final TaskChecklist? existing;
  const TaskChecklistBuilderScreen({super.key, this.existing});

  @override
  State<TaskChecklistBuilderScreen> createState() =>
      _TaskChecklistBuilderScreenState();
}

class _TaskChecklistBuilderScreenState
    extends State<TaskChecklistBuilderScreen> {
  // ── Form state ────────────────────────────────────────────────────────────
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  TaskChecklistFrequency _frequency = TaskChecklistFrequency.daily;
  List<int> _scheduledDays = [];
  TimeOfDay? _scheduledTime;
  DateTime? _onceDate;

  // Tasks list
  final List<_TaskBuilder> _tasks = [];

  // Users
  List<AppUser> _allUsers = [];
  List<String> _selectedUserIds = [];
  bool _loadingUsers = false;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    if (widget.existing != null) {
      _prefill(widget.existing!);
    } else {
      _tasks.add(_TaskBuilder());
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    for (final t in _tasks) t.dispose();
    super.dispose();
  }

  void _prefill(TaskChecklist cl) {
    _titleCtrl.text = cl.title;
    _descCtrl.text  = cl.description ?? '';
    _frequency      = cl.frequency;
    _scheduledDays  = List.from(cl.scheduledDays);
    if (cl.scheduledTime != null) {
      final parts = cl.scheduledTime!.split(':');
      _scheduledTime = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 0,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }
    _onceDate = cl.onceDate;
    _tasks.addAll(cl.tasks.map((t) => _TaskBuilder(
      id: t.id,
      titleCtrl: TextEditingController(text: t.title),
      descCtrl:  TextEditingController(text: t.description ?? ''),
    )));
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final users = await SupabaseService.getUsers();
      List<String> assigned = [];
      if (widget.existing != null) {
        assigned = await SupabaseService.getTaskChecklistAssignedUserIds(widget.existing!.id);
      }
      if (!mounted) return;
      setState(() {
        _allUsers = users.where((u) => u.isActive).toList();
        _selectedUserIds = assigned;
        _loadingUsers = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  // ── Validation ─────────────────────────────────────────────────────────────
  bool _validate() {
    if (_titleCtrl.text.trim().isEmpty) {
      _err('يرجى إدخال عنوان القائمة');
      return false;
    }
    if (_tasks.isEmpty) {
      _err('يرجى إضافة مهمة واحدة على الأقل');
      return false;
    }
    for (int i = 0; i < _tasks.length; i++) {
      if (_tasks[i].titleCtrl.text.trim().isEmpty) {
        _err('يرجى إدخال عنوان المهمة ${i + 1}');
        return false;
      }
    }
    if (_frequency == TaskChecklistFrequency.specificDays && _scheduledDays.isEmpty) {
      _err('يرجى اختيار يوم واحد على الأقل');
      return false;
    }
    if (_frequency == TaskChecklistFrequency.once && _onceDate == null) {
      _err('يرجى اختيار تاريخ التنفيذ');
      return false;
    }
    return true;
  }

  void _err(String msg) => Helpers.showSnackBar(context, msg, isError: true);

  // ── Save ────────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _isSaving = true);
    try {
      final tasks = _tasks.asMap().entries.map((e) => TaskItem(
        id: e.value.id,
        title: e.value.titleCtrl.text.trim(),
        description: e.value.descCtrl.text.trim().isEmpty
            ? null : e.value.descCtrl.text.trim(),
        order: e.key,
      )).toList();

      final timeStr = _scheduledTime != null
          ? '${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}'
          : null;

      int checklistId;
      if (widget.existing != null) {
        final updated = await SupabaseService.updateTaskChecklist(
          id: widget.existing!.id,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          tasks: tasks,
          frequency: _frequency,
          scheduledDays: _scheduledDays,
          scheduledTime: timeStr,
          onceDate: _onceDate,
        );
        checklistId = updated.id;
      } else {
        final created = await SupabaseService.createTaskChecklist(
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          tasks: tasks,
          frequency: _frequency,
          scheduledDays: _scheduledDays,
          scheduledTime: timeStr,
          onceDate: _onceDate,
        );
        checklistId = created.id;
      }

      await SupabaseService.assignUsersToTaskChecklist(
        checklistId: checklistId,
        userIds: _selectedUserIds,
      );

      if (mounted) {
        Helpers.showSnackBar(
          context,
          widget.existing != null ? 'تم التحديث بنجاح' : 'تم الإنشاء بنجاح',
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) _err('فشل في الحفظ: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Time picker ────────────────────────────────────────────────────────────
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? TimeOfDay.now(),
      builder: (ctx, child) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: child!,
      ),
    );
    if (picked != null) setState(() => _scheduledTime = picked);
  }

  Future<void> _pickOnceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _onceDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: child!,
      ),
    );
    if (picked != null) setState(() => _onceDate = picked);
  }

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 640;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: _buildAppBar(),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 24,
            vertical: isMobile ? 16 : 20,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBasicsCard(isMobile),
                  const SizedBox(height: 16),
                  _buildScheduleCard(isMobile),
                  const SizedBox(height: 16),
                  _buildTasksCard(isMobile),
                  const SizedBox(height: 16),
                  _buildUsersCard(isMobile),
                  const SizedBox(height: 24),
                  _buildSaveButton(isMobile),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    elevation: 0,
    scrolledUnderElevation: 1,
    backgroundColor: _kSurface,
    surfaceTintColor: _kSurface,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _kText),
      onPressed: () => Navigator.pop(context),
    ),
    title: Text(
      widget.existing != null ? 'تعديل قائمة المهام' : 'إنشاء قائمة مهام',
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kText),
    ),
    actions: [
      if (_isSaving)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: _kAccent)),
            SizedBox(width: 6),
            Text('حفظ...', style: TextStyle(fontSize: 12, color: _kTextMuted)),
          ]),
        )
      else
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_rounded, size: 15, color: Colors.white),
            label: const Text('حفظ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
              backgroundColor: _kSuccess,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kRadiusSm)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            ),
          ),
        ),
    ],
  );

  // ── Basics ─────────────────────────────────────────────────────────────────
  Widget _buildBasicsCard(bool isMobile) => Container(
    padding: EdgeInsets.all(isMobile ? 16 : 20),
    decoration: _card(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHead(Icons.checklist_rounded, 'المعلومات الأساسية'),
      const SizedBox(height: 16),
      _fieldLabel('عنوان القائمة *', 'يظهر للمستخدم كعنوان رئيسي'),
      const SizedBox(height: 6),
      TextFormField(
        controller: _titleCtrl,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kText),
        decoration: _inp(hint: 'مثال: قائمة مهام الصباح', prefix: Icons.title_rounded),
      ),
      const SizedBox(height: 16),
      _fieldLabel('الوصف (اختياري)', 'تفاصيل إضافية تظهر تحت العنوان'),
      const SizedBox(height: 6),
      TextFormField(
        controller: _descCtrl,
        maxLines: 3,
        style: const TextStyle(fontSize: 14),
        decoration: _inp(hint: 'وصف موجز لهدف هذه القائمة...', prefix: Icons.notes_rounded),
      ),
    ]),
  );

  // ── Schedule ───────────────────────────────────────────────────────────────
  Widget _buildScheduleCard(bool isMobile) => Container(
    padding: EdgeInsets.all(isMobile ? 16 : 20),
    decoration: _card(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHead(Icons.schedule_rounded, 'جدولة الإشعارات'),
      const SizedBox(height: 16),

      // Frequency selector
      _fieldLabel('تكرار التنفيذ *', 'متى يجب على المستخدم تنفيذ هذه القائمة؟'),
      const SizedBox(height: 10),
      Row(children: TaskChecklistFrequency.values.map((f) {
        final sel = _frequency == f;
        return Expanded(child: GestureDetector(
          onTap: () => setState(() { _frequency = f; _scheduledDays = []; _onceDate = null; }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: sel ? _kAccent : _kBg,
              borderRadius: BorderRadius.circular(_kRadius),
              border: Border.all(color: sel ? _kAccent : _kBorder),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                f == TaskChecklistFrequency.daily ? Icons.repeat_rounded
                    : f == TaskChecklistFrequency.specificDays ? Icons.date_range_rounded
                    : Icons.event_rounded,
                size: 18,
                color: sel ? Colors.white : _kTextMuted,
              ),
              const SizedBox(height: 4),
              Text(f.displayText,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : _kTextMuted),
                  textAlign: TextAlign.center),
            ]),
          ),
        ));
      }).toList()),

      // Specific days picker
      if (_frequency == TaskChecklistFrequency.specificDays) ...[
        const SizedBox(height: 16),
        _fieldLabel('أيام التنفيذ *', 'اختر الأيام التي يجب فيها تنفيذ القائمة'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: _kDays.map(((int, String) day) {
          final sel = _scheduledDays.contains(day.$1);
          return GestureDetector(
            onTap: () => setState(() {
              if (sel) _scheduledDays.remove(day.$1);
              else _scheduledDays.add(day.$1);
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? _kAccent.withOpacity(0.1) : _kBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? _kAccent : _kBorder),
              ),
              child: Text(day.$2,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: sel ? _kAccent : _kTextMuted)),
            ),
          );
        }).toList()),
      ],

      // Once date
      if (_frequency == TaskChecklistFrequency.once) ...[
        const SizedBox(height: 16),
        _fieldLabel('تاريخ التنفيذ *', 'اليوم الذي يجب فيه تنفيذ القائمة مرة واحدة'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickOnceDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(_kRadius),
              border: Border.all(color: _onceDate != null ? _kAccent : _kBorder),
            ),
            child: Row(children: [
              Icon(Icons.calendar_today_outlined, size: 16,
                  color: _onceDate != null ? _kAccent : _kTextMuted),
              const SizedBox(width: 10),
              Text(
                _onceDate != null
                    ? '${_onceDate!.day}/${_onceDate!.month}/${_onceDate!.year}'
                    : 'اختر تاريخ...',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                    color: _onceDate != null ? _kText : _kTextMuted),
              ),
              const Spacer(),
              const Icon(Icons.edit_outlined, size: 14, color: _kTextMuted),
            ]),
          ),
        ),
      ],

      // Time picker
      const SizedBox(height: 16),
      _fieldLabel('وقت الإشعار', 'الوقت الذي يتلقى فيه المستخدم الإشعار للقيام بالمهام'),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: _pickTime,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.circular(_kRadius),
            border: Border.all(color: _scheduledTime != null ? _kAccent : _kBorder),
          ),
          child: Row(children: [
            Icon(Icons.access_time_rounded, size: 16,
                color: _scheduledTime != null ? _kAccent : _kTextMuted),
            const SizedBox(width: 10),
            Text(
              _scheduledTime != null
                  ? _scheduledTime!.format(context)
                  : 'اختر وقت الإشعار... (اختياري)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                  color: _scheduledTime != null ? _kText : _kTextMuted),
            ),
            const Spacer(),
            if (_scheduledTime != null)
              GestureDetector(
                onTap: () => setState(() => _scheduledTime = null),
                child: const Icon(Icons.close, size: 14, color: _kDanger),
              )
            else
              const Icon(Icons.edit_outlined, size: 14, color: _kTextMuted),
          ]),
        ),
      ),

      // Summary chip
      if (_scheduledTime != null || _frequency != TaskChecklistFrequency.daily) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.07),
            borderRadius: BorderRadius.circular(_kRadiusSm),
            border: Border.all(color: _kAccent.withOpacity(0.2)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.notifications_outlined, size: 14, color: _kAccent),
            const SizedBox(width: 7),
            Flexible(child: Text(
              _buildFrequencyPreview(),
              style: const TextStyle(fontSize: 12, color: _kAccent, fontWeight: FontWeight.w500),
            )),
          ]),
        ),
      ],
    ]),
  );

  String _buildFrequencyPreview() {
    String base;
    switch (_frequency) {
      case TaskChecklistFrequency.daily:
        base = 'إشعار يومي';
        break;
      case TaskChecklistFrequency.specificDays:
        if (_scheduledDays.isEmpty) return 'اختر الأيام أولاً';
        final names = _scheduledDays.map((d) => _kDays.firstWhere((e) => e.$1 == d).$2).join('، ');
        base = 'كل: $names';
        break;
      case TaskChecklistFrequency.once:
        base = _onceDate != null
            ? 'مرة واحدة ${_onceDate!.day}/${_onceDate!.month}/${_onceDate!.year}'
            : 'مرة واحدة';
    }
    return _scheduledTime != null ? '$base الساعة ${_scheduledTime!.format(context)}' : base;
  }

  // ── Tasks ──────────────────────────────────────────────────────────────────
  Widget _buildTasksCard(bool isMobile) => Container(
    decoration: _card(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 18),
        child: Row(children: [
          _sectionHead(Icons.task_alt_rounded, 'قائمة المهام'),
          const Spacer(),
          _countBadge(_tasks.length, 'مهمة'),
        ]),
      ),
      const Divider(height: 1, color: _kBorder),

      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _tasks.length,
        buildDefaultDragHandles: false,
        onReorder: (oldIdx, newIdx) {
          setState(() {
            if (newIdx > oldIdx) newIdx--;
            final item = _tasks.removeAt(oldIdx);
            _tasks.insert(newIdx, item);
          });
        },
        itemBuilder: (ctx, idx) {
          final t = _tasks[idx];
          return _buildTaskRow(idx, t, isMobile, key: ValueKey(t.id));
        },
      ),

      Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 18),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _tasks.add(_TaskBuilder())),
            icon: const Icon(Icons.add_task_rounded, size: 16, color: _kAccent),
            label: const Text('إضافة مهمة', style: TextStyle(fontSize: 13, color: _kAccent, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _kAccent.withOpacity(0.3)),
              backgroundColor: _kAccent.withOpacity(0.04),
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kRadius)),
            ),
          ),
        ),
      ),
    ]),
  );

  Widget _buildTaskRow(int idx, _TaskBuilder t, bool isMobile, {required Key key}) => Column(
    key: key,
    children: [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 18, vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Drag handle
          ReorderableDragStartListener(
            index: idx,
            child: Padding(
              padding: const EdgeInsets.only(top: 10, left: 10),
              child: Icon(Icons.drag_indicator_rounded, size: 18, color: _kTextMuted),
            ),
          ),
          // Number badge
          Padding(
            padding: const EdgeInsets.only(top: 9, left: 10),
            child: Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: _kAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _kAccent.withOpacity(0.2)),
              ),
              child: Center(child: Text('${idx + 1}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _kAccent))),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(children: [
              TextFormField(
                controller: t.titleCtrl,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                decoration: _inp(hint: 'عنوان المهمة (مثال: تفقد مستوى الزيت)'),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: t.descCtrl,
                maxLines: 2,
                style: const TextStyle(fontSize: 12, color: _kTextSub),
                decoration: _inp(hint: 'تفاصيل إضافية (اختياري)'),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          // Insert after
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: () => setState(() => _tasks.insert(idx + 1, _TaskBuilder())),
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _kAccent.withOpacity(0.2)),
                ),
                child: const Icon(Icons.add_rounded, size: 14, color: _kAccent),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Delete
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: _tasks.length > 1
                  ? () => setState(() { _tasks[idx].dispose(); _tasks.removeAt(idx); })
                  : null,
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: _tasks.length > 1 ? _kDanger.withOpacity(0.07) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: _tasks.length > 1 ? _kDanger.withOpacity(0.2) : Colors.grey.shade200),
                ),
                child: Icon(Icons.delete_outline_rounded, size: 14,
                    color: _tasks.length > 1 ? _kDanger : Colors.grey.shade400),
              ),
            ),
          ),
        ]),
      ),
      if (idx < _tasks.length - 1) const Divider(height: 1, color: _kBorder),
    ],
  );

  // ── Users ──────────────────────────────────────────────────────────────────
  Widget _buildUsersCard(bool isMobile) => Container(
    padding: EdgeInsets.all(isMobile ? 14 : 18),
    decoration: _card(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _sectionHead(Icons.people_alt_outlined, 'تعيين المستخدمين'),
        const Spacer(),
        _countBadge(_allUsers.length, 'متاح'),
      ]),
      const SizedBox(height: 14),
      if (_loadingUsers)
        const Center(child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: _kAccent),
        ))
      else if (_allUsers.isEmpty)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(_kRadius)),
          child: const Center(child: Text('لا يوجد مستخدمون نشطون',
              style: TextStyle(color: _kTextMuted, fontSize: 13))),
        )
      else ...[
        Row(children: [
          Text('المتاحون (${_allUsers.length})',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kTextMuted)),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() {
              _selectedUserIds = _selectedUserIds.length == _allUsers.length
                  ? [] : _allUsers.map((u) => u.id).toList();
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kAccent.withOpacity(0.07),
                borderRadius: BorderRadius.circular(_kRadiusSm),
                border: Border.all(color: _kAccent.withOpacity(0.2)),
              ),
              child: Text(
                _selectedUserIds.length == _allUsers.length ? 'إلغاء تحديد الكل' : 'تحديد الكل',
                style: const TextStyle(fontSize: 11.5, color: _kAccent, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _allUsers.map((u) {
            final sel = _selectedUserIds.contains(u.id);
            return GestureDetector(
              onTap: () => setState(() {
                if (sel) _selectedUserIds.remove(u.id);
                else _selectedUserIds.add(u.id);
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? _kAccent.withOpacity(0.07) : _kSurface,
                  borderRadius: BorderRadius.circular(_kRadius),
                  border: Border.all(
                    color: sel ? _kAccent.withOpacity(0.35) : _kBorder,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: sel ? _kAccent : Colors.grey.shade400,
                    child: Text(
                      u.username.isNotEmpty ? u.username[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(u.username,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600,
                            color: sel ? _kAccent : _kText)),
                    Text(u.email,
                        style: const TextStyle(fontSize: 10.5, color: _kTextMuted)),
                  ]),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      color: sel ? _kAccent : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: sel ? _kAccent : Colors.grey.shade300, width: 1.5),
                    ),
                    child: sel ? const Icon(Icons.check_rounded, size: 10, color: Colors.white) : null,
                  ),
                ]),
              ),
            );
          }).toList(),
        ),
        if (_selectedUserIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _kSuccess.withOpacity(0.08),
              borderRadius: BorderRadius.circular(_kRadius),
              border: Border.all(color: _kSuccess.withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle_outline_rounded, color: _kSuccess, size: 15),
              const SizedBox(width: 7),
              Text('تم تحديد ${_selectedUserIds.length} مستخدم',
                  style: const TextStyle(fontSize: 12, color: _kSuccess, fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ],
    ]),
  );

  // ── Save button ────────────────────────────────────────────────────────────
  Widget _buildSaveButton(bool isMobile) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: _isSaving ? null : _save,
      style: FilledButton.styleFrom(
        backgroundColor: _kAccent,
        disabledBackgroundColor: _kAccent.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kRadius)),
        padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 15),
      ),
      child: _isSaving
          ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 10),
              Text('جارٍ الحفظ...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ])
          : Text(
              widget.existing != null ? 'حفظ التعديلات' : 'إنشاء قائمة المهام',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
    ),
  );

  // ── Shared helpers ─────────────────────────────────────────────────────────
  Widget _sectionHead(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: _kAccent),
      const SizedBox(width: 7),
      Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kText)),
    ],
  );

  Widget _fieldLabel(String label, String hint) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _kText)),
      const SizedBox(height: 2),
      Text(hint, style: const TextStyle(fontSize: 10.5, color: _kTextMuted, fontStyle: FontStyle.italic)),
    ],
  );

  Widget _countBadge(int count, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _kAccent.withOpacity(0.08),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: _kAccent.withOpacity(0.2)),
    ),
    child: Text('$count $label',
        style: const TextStyle(fontSize: 11, color: _kAccent, fontWeight: FontWeight.w600)),
  );

  InputDecoration _inp({String? hint, IconData? prefix}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _kTextMuted, fontSize: 13),
    prefixIcon: prefix != null ? Icon(prefix, size: 17, color: _kTextMuted) : null,
    filled: true, fillColor: _kBg,
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_kRadius), borderSide: const BorderSide(color: _kBorder)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_kRadius), borderSide: const BorderSide(color: _kBorder)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_kRadius), borderSide: const BorderSide(color: _kAccent, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    isDense: true,
  );
}

// ─── Builder helper ────────────────────────────────────────────────────────────
class _TaskBuilder {
  final String id;
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;

  _TaskBuilder({
    String? id,
    TextEditingController? titleCtrl,
    TextEditingController? descCtrl,
  })  : id = id ?? const Uuid().v4(),
        titleCtrl = titleCtrl ?? TextEditingController(),
        descCtrl = descCtrl ?? TextEditingController();

  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
  }
}