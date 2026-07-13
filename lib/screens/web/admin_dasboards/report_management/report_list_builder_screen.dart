import 'package:flutter/material.dart';
import 'package:jala_as/models/quality_models.dart';
import 'package:jala_as/models/report_models.dart';
import 'package:jala_as/models/user.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/helpers.dart';
import 'package:uuid/uuid.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF0891B2);
const _kDanger = Color(0xFFDC2626);
const _kBg = Color(0xFFF1F5F9);
const _kBorder = Color(0xFFE2E8F0);
const _kTextPrimary = Color(0xFF0F172A);
const _kTextSecondary = Color(0xFF64748B);
const _kRadius = 12.0;

const _kStepColors = [
  Color(0xFF0891B2),
  Color(0xFF7C3AED),
  Color(0xFF059669),
];

// 3 steps only
const _kStepData = [
  (title: 'معلومات المجموعة', icon: Icons.folder_outlined),
  (title: 'قوائم التقارير',   icon: Icons.list_alt_rounded),
  (title: 'تعيين المستخدمين', icon: Icons.people_alt_rounded),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class ReportListBuilderScreen extends StatefulWidget {
  final ReportListGroup? group;

  const ReportListBuilderScreen({super.key, this.group});

  @override
  State<ReportListBuilderScreen> createState() =>
      _ReportListBuilderScreenState();
}

class _ReportListBuilderScreenState extends State<ReportListBuilderScreen> {
  final _uuid = const Uuid();
  final _pageCtrl = PageController();
  int _step = 0;
  bool _saving = false;

  // ── Step 1 – Group info ──
  final _groupTitleCtrl = TextEditingController();
  final _groupDescCtrl = TextEditingController();
  bool _canEditSubmissions = false;

  // ── Step 2 – Multiple report lists ──
  final List<_ReportListDraft> _reportLists = [];

  // ── Step 3 – Assign users ──
  List<AppUser> _allUsers = [];
  final Set<String> _selectedUserIds = {};
  bool _loadingUsers = false;

  bool get _isEdit => widget.group != null;

  @override
  void initState() {
    super.initState();
    _prefill();
    _loadUsers();
  }

  void _prefill() {
    final g = widget.group;
    if (g == null) {
      // New group: start with one empty list
      _addNewDraft();
      return;
    }
    _groupTitleCtrl.text = g.title;
    _groupDescCtrl.text = g.description ?? '';
    _canEditSubmissions = g.canEditSubmissions;

    for (final rl in g.reportLists) {
      final draft = _ReportListDraft(
        localId: _uuid.v4(),
        dbId: rl.id,
        titleCtrl: TextEditingController(text: rl.title),
        descCtrl: TextEditingController(text: rl.description ?? ''),
        fields: rl.fields.map((f) => _FieldDraft(
              id: f.id,
              titleCtrl: TextEditingController(text: f.title),
              hintCtrl: TextEditingController(text: f.hint ?? ''),
              isRequired: f.isRequired,
            )).toList(),
        determinants: List<Determinant>.from(rl.determinants),
        notificationRules: List<NotificationRule>.from(rl.notificationRules),
        scheduleType: rl.scheduleType,
        dayOfWeek: rl.scheduleDayOfWeek ?? 0,
        dayOfMonth: rl.scheduleDayOfMonth ?? 1,
        scheduleMonth: rl.scheduleMonth ?? 1,
        specificDate: rl.scheduleDate,
        timeAllDay: rl.timeAllDay,
        timeStart: _parseTime(rl.timeStart, const TimeOfDay(hour: 8, minute: 0)),
        timeEnd: _parseTime(rl.timeEnd, const TimeOfDay(hour: 20, minute: 0)),
      );
      _reportLists.add(draft);
    }

    if (_reportLists.isEmpty) _addNewDraft();
  }

  TimeOfDay _parseTime(String? raw, TimeOfDay fallback) {
    if (raw == null) return fallback;
    final parts = raw.split(':');
    if (parts.length < 2) return fallback;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? fallback.hour,
      minute: int.tryParse(parts[1]) ?? fallback.minute,
    );
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final users = await SupabaseService.getQualityControllerUsers();
      final Set<String> existingIds = {};
      if (_isEdit && widget.group!.reportLists.isNotEmpty) {
        final assignments = await SupabaseService.getReportListAssignments(
          widget.group!.reportLists.first.id,
        );
        existingIds.addAll(assignments.map((a) => a.userId));
      }
      setState(() {
        _allUsers = users;
        _selectedUserIds.addAll(existingIds);
        _loadingUsers = false;
      });
    } catch (_) {
      setState(() => _loadingUsers = false);
    }
  }

  void _addNewDraft() {
    setState(() => _reportLists.add(_ReportListDraft(
          localId: _uuid.v4(),
          titleCtrl: TextEditingController(),
          descCtrl: TextEditingController(),
        )));
  }

  @override
  void dispose() {
    _groupTitleCtrl.dispose();
    _groupDescCtrl.dispose();
    for (final d in _reportLists) { d.dispose(); }
    _pageCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ──────────────────────────────────────────────

  void _goToStep(int i) {
    if (i < 0 || i >= _kStepData.length) return;
    if (i > _step && !_validateCurrentStep()) return;
    _pageCtrl.animateToPage(i,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    setState(() => _step = i);
  }

  void _next() {
    if (_step < _kStepData.length - 1) {
      _goToStep(_step + 1);
    } else {
      _save();
    }
  }

  void _prev() => _goToStep(_step - 1);

  bool _validateCurrentStep() {
    switch (_step) {
      case 0:
        if (_groupTitleCtrl.text.trim().isEmpty) {
          Helpers.showSnackBar(context, 'يرجى إدخال اسم المجموعة',
              isError: true);
          return false;
        }
        return true;
      case 1:
        if (_reportLists.isEmpty) {
          Helpers.showSnackBar(context, 'يرجى إضافة قائمة تقرير واحدة على الأقل',
              isError: true);
          return false;
        }
        for (final d in _reportLists) {
          if (d.titleCtrl.text.trim().isEmpty) {
            Helpers.showSnackBar(context, 'يرجى إدخال اسم لجميع قوائم التقارير',
                isError: true);
            return false;
          }
          if (d.fields.isEmpty) {
            Helpers.showSnackBar(
                context,
                'قائمة "${d.titleCtrl.text.trim()}" تحتاج حقلاً واحداً على الأقل',
                isError: true);
            return false;
          }
          for (final f in d.fields) {
            if (f.titleCtrl.text.trim().isEmpty) {
              Helpers.showSnackBar(context, 'يرجى إدخال عنوان لجميع الحقول',
                  isError: true);
              return false;
            }
          }
        }
        return true;
      default:
        return true;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      int groupId;

      if (_isEdit) {
        groupId = widget.group!.id;
        await SupabaseService.updateReportListGroup(
          id: groupId,
          title: _groupTitleCtrl.text.trim(),
          description: _groupDescCtrl.text.trim().isEmpty
              ? null
              : _groupDescCtrl.text.trim(),
          canEditSubmissions: _canEditSubmissions,
        );
      } else {
        final group = await SupabaseService.createReportListGroup(
          title: _groupTitleCtrl.text.trim(),
          description: _groupDescCtrl.text.trim().isEmpty
              ? null
              : _groupDescCtrl.text.trim(),
          canEditSubmissions: _canEditSubmissions,
        );
        groupId = group.id;
      }

      for (final draft in _reportLists) {
        final fields = draft.fields
            .map((f) => ReportField(
                  id: f.id,
                  title: f.titleCtrl.text.trim(),
                  hint: f.hintCtrl.text.trim().isEmpty
                      ? null
                      : f.hintCtrl.text.trim(),
                  isRequired: f.isRequired,
                ))
            .toList();

        final scheduleDate =
            draft.scheduleType == ReportScheduleType.specificDate &&
                    draft.specificDate != null
                ? draft.specificDate!.toIso8601String().split('T')[0]
                : null;
        final timeStart = draft.timeAllDay
            ? null
            : '${draft.timeStart.hour.toString().padLeft(2, '0')}:${draft.timeStart.minute.toString().padLeft(2, '0')}';
        final timeEnd = draft.timeAllDay
            ? null
            : '${draft.timeEnd.hour.toString().padLeft(2, '0')}:${draft.timeEnd.minute.toString().padLeft(2, '0')}';

        int rlId;

        final notifRules =
            draft.notificationRules.map((r) => r.toJson()).toList();

        if (draft.dbId != null) {
          rlId = draft.dbId!;
          await SupabaseService.updateReportList(
            id: rlId,
            title: draft.titleCtrl.text.trim(),
            description: draft.descCtrl.text.trim().isEmpty
                ? null
                : draft.descCtrl.text.trim(),
            determinants:
                draft.determinants.map((d) => d.toJson()).toList(),
            fields: fields.map((f) => f.toJson()).toList(),
            canEditSubmissions: _canEditSubmissions,
            scheduleType: draft.scheduleType.value,
            scheduleDayOfWeek:
                draft.scheduleType == ReportScheduleType.weekly
                    ? draft.dayOfWeek
                    : null,
            scheduleDayOfMonth:
                (draft.scheduleType == ReportScheduleType.monthly ||
                        draft.scheduleType == ReportScheduleType.yearly)
                    ? draft.dayOfMonth
                    : null,
            scheduleMonth:
                draft.scheduleType == ReportScheduleType.yearly
                    ? draft.scheduleMonth
                    : null,
            scheduleDate: scheduleDate,
            timeAllDay: draft.timeAllDay,
            timeStart: timeStart,
            timeEnd: timeEnd,
            notificationRules: notifRules,
          );
        } else {
          final rl = await SupabaseService.createReportList(
            groupId: groupId,
            title: draft.titleCtrl.text.trim(),
            description: draft.descCtrl.text.trim().isEmpty
                ? null
                : draft.descCtrl.text.trim(),
            determinants:
                draft.determinants.map((d) => d.toJson()).toList(),
            fields: fields.map((f) => f.toJson()).toList(),
            canEditSubmissions: _canEditSubmissions,
            scheduleType: draft.scheduleType.value,
            scheduleDayOfWeek:
                draft.scheduleType == ReportScheduleType.weekly
                    ? draft.dayOfWeek
                    : null,
            scheduleDayOfMonth:
                (draft.scheduleType == ReportScheduleType.monthly ||
                        draft.scheduleType == ReportScheduleType.yearly)
                    ? draft.dayOfMonth
                    : null,
            scheduleMonth:
                draft.scheduleType == ReportScheduleType.yearly
                    ? draft.scheduleMonth
                    : null,
            scheduleDate: scheduleDate,
            timeAllDay: draft.timeAllDay,
            timeStart: timeStart,
            timeEnd: timeEnd,
            notificationRules: notifRules,
          );
          rlId = rl.id;
        }

        // Assign users to each list
        await SupabaseService.assignReportList(
          reportListId: rlId,
          reportListTitle: draft.titleCtrl.text.trim(),
          userIds: _selectedUserIds.toList(),
        );
      }

      if (mounted) {
        Helpers.showSnackBar(
            context,
            _isEdit
                ? 'تم تحديث قوائم التقرير بنجاح'
                : 'تم إنشاء قوائم التقرير بنجاح');
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في الحفظ: $e', isError: true);
      }
    }
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
          title: Text(
            _isEdit ? 'تعديل مجموعة قوائم التقرير' : 'إنشاء مجموعة قوائم تقرير',
            style: const TextStyle(
                color: _kTextPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _kBorder),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close, color: _kTextSecondary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Column(
          children: [
            _buildStepTabs(),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ── Clickable step tabs ──────────────────────────────────────

  Widget _buildStepTabs() {
    return Container(
      height: 52,
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: List.generate(_kStepData.length, (i) {
            final s = _kStepData[i];
            final active = i == _step;
            final done = i < _step;
            final c = _kStepColors[i];
            return GestureDetector(
              onTap: () => _goToStep(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(left: 6),
                padding: EdgeInsets.symmetric(
                    horizontal: active ? 14 : 10, vertical: 5),
                decoration: BoxDecoration(
                  color: active
                      ? c
                      : done
                          ? c.withValues(alpha: 0.08)
                          : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: active
                          ? c
                          : done
                              ? c.withValues(alpha: 0.3)
                              : Colors.grey.shade200),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white.withValues(alpha: 0.25)
                          : done
                              ? c
                              : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: done
                          ? const Icon(Icons.check_rounded,
                              size: 11, color: Colors.white)
                          : Text('${i + 1}',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: active
                                      ? Colors.white
                                      : Colors.grey.shade500)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(s.title,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                          color: active
                              ? Colors.white
                              : done
                                  ? c
                                  : Colors.grey.shade500)),
                ]),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_step > 0)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _kTextSecondary,
                side: const BorderSide(color: _kBorder),
              ),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('السابق'),
              onPressed: _saving ? null : _prev,
            )
          else
            const SizedBox(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccent,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(
                    _step < _kStepData.length - 1
                        ? Icons.arrow_back
                        : Icons.save_rounded,
                    size: 16),
            label: Text(
                _step < _kStepData.length - 1
                    ? 'التالي'
                    : (_isEdit ? 'حفظ التعديلات' : 'إنشاء'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            onPressed: _saving ? null : _next,
          ),
        ],
      ),
    );
  }

  // ── Step 1: Group Info ────────────────────────────────────────

  Widget _buildStep1() {
    return _StepScaffold(
      icon: _kStepData[0].icon,
      color: _kStepColors[0],
      title: _kStepData[0].title,
      subtitle: 'أدخل اسم المجموعة والإعدادات العامة',
      child: Column(
        children: [
          _field(
            label: 'اسم المجموعة *',
            controller: _groupTitleCtrl,
            hint: 'مثال: تقارير الجودة اليومية',
          ),
          const SizedBox(height: 14),
          _field(
            label: 'الوصف (اختياري)',
            controller: _groupDescCtrl,
            hint: 'وصف مختصر للمجموعة',
            maxLines: 3,
          ),
          const SizedBox(height: 14),
          _SwitchCard(
            title: 'السماح بتعديل الردود',
            subtitle: 'يمكن للمستخدم تعديل ردوده خلال 48 ساعة',
            value: _canEditSubmissions,
            color: _kStepColors[0],
            onChanged: (v) => setState(() => _canEditSubmissions = v),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Multiple report lists ────────────────────────────

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_kRadius),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _kStepColors[1].withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_kStepData[1].icon,
                      color: _kStepColors[1], size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_kStepData[1].title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _kTextPrimary)),
                      const Text(
                          'أضف قائمة تقرير واحدة أو أكثر لهذه المجموعة',
                          style: TextStyle(
                              fontSize: 12, color: _kTextSecondary)),
                    ],
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: _kStepColors[1],
                    backgroundColor:
                        _kStepColors[1].withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('إضافة قائمة',
                      style: TextStyle(fontSize: 12)),
                  onPressed: _addNewDraft,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Draft cards
          ..._reportLists.asMap().entries.map((entry) {
            final i = entry.key;
            final draft = entry.value;
            return _ReportListDraftCard(
              key: ValueKey(draft.localId),
              draft: draft,
              index: i,
              color: _kStepColors[1],
              uuid: _uuid,
              canDelete: _reportLists.length > 1,
              onDelete: () => setState(() => _reportLists.removeAt(i)),
              onChanged: () => setState(() {}),
            );
          }),

          if (_reportLists.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_kRadius),
                border: Border.all(color: _kBorder),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.list_alt_outlined,
                        size: 40, color: _kTextSecondary),
                    SizedBox(height: 8),
                    Text('اضغط "إضافة قائمة" للبدء',
                        style:
                            TextStyle(color: _kTextSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Step 3: Assign Users ──────────────────────────────────────

  Widget _buildStep3() {
    final assignedUsers =
        _allUsers.where((u) => _selectedUserIds.contains(u.id)).toList();

    return _StepScaffold(
      icon: _kStepData[2].icon,
      color: _kStepColors[2],
      title: _kStepData[2].title,
      subtitle: 'المستخدمون المعيّنون على هذه التقارير',
      child: _loadingUsers
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kStepColors[2].withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${assignedUsers.length} مستخدم معيّن',
                        style: TextStyle(
                            fontSize: 12,
                            color: _kStepColors[2],
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: _kStepColors[2],
                        backgroundColor:
                            _kStepColors[2].withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded,
                          size: 16),
                      label: const Text('إضافة مستخدم',
                          style: TextStyle(fontSize: 12)),
                      onPressed: _showAddUserDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (assignedUsers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _kBorder,
                          style: BorderStyle.solid),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.people_outline,
                              size: 40,
                              color: _kTextSecondary.withValues(alpha: 0.5)),
                          const SizedBox(height: 10),
                          const Text('لم يتم تعيين أي مستخدم بعد',
                              style: TextStyle(
                                  color: _kTextSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          const Text(
                              'اضغط "إضافة مستخدم" لتعيين مراقبي الجودة',
                              style: TextStyle(
                                  color: _kTextSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                  )
                else
                  ...assignedUsers.map((u) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color:
                              _kStepColors[2].withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _kStepColors[2]
                                  .withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: _kStepColors[2]
                                  .withValues(alpha: 0.15),
                              child: Text(
                                u.username.isNotEmpty
                                    ? u.username[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _kStepColors[2]),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(u.username,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _kTextPrimary)),
                                  Text(u.email,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: _kTextSecondary)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: _kDanger,
                                  size: 18),
                              onPressed: () => setState(
                                  () => _selectedUserIds.remove(u.id)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'إزالة التعيين',
                            ),
                          ],
                        ),
                      )),
              ],
            ),
    );
  }

  Future<void> _showAddUserDialog() async {
    final unassigned = _allUsers
        .where((u) => !_selectedUserIds.contains(u.id))
        .toList();

    if (unassigned.isEmpty) {
      Helpers.showSnackBar(
          context, 'جميع المستخدمين المتاحين تم تعيينهم بالفعل');
      return;
    }

    final Set<String> toAdd = {};

    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _kStepColors[2].withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.person_add_alt_1_rounded,
                    size: 17, color: _kStepColors[2]),
              ),
              const SizedBox(width: 10),
              const Text('إضافة مستخدمين',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: StatefulBuilder(
              builder: (ctx2, setDlgState) => SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: unassigned
                      .map((u) => Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: toAdd.contains(u.id)
                                  ? _kStepColors[2].withValues(alpha: 0.06)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: toAdd.contains(u.id)
                                    ? _kStepColors[2].withValues(alpha: 0.3)
                                    : _kBorder,
                              ),
                            ),
                            child: CheckboxListTile(
                              dense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              value: toAdd.contains(u.id),
                              activeColor: _kStepColors[2],
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              title: Text(u.username,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _kTextPrimary)),
                              subtitle: Text(u.email,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: _kTextSecondary)),
                              onChanged: (v) => setDlgState(() {
                                if (v == true) {
                                  toAdd.add(u.id);
                                } else {
                                  toAdd.remove(u.id);
                                }
                              }),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(color: _kTextSecondary)),
            ),
            StatefulBuilder(
              builder: (ctx3, setSaveState) => ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kStepColors[2],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: Text(
                    toAdd.isEmpty ? 'إضافة' : 'إضافة (${toAdd.length})'),
                onPressed: () {
                  setState(() => _selectedUserIds.addAll(toAdd));
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared field widget ───────────────────────────────────────

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _kTextPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(fontSize: 13, color: _kTextSecondary),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: _kAccent, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}

// ─── Report list draft model ──────────────────────────────────────────────────

class _ReportListDraft {
  final String localId;
  int? dbId;
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final List<_FieldDraft> fields;
  List<Determinant> determinants;
  ReportScheduleType scheduleType;
  int dayOfWeek;
  int dayOfMonth;
  int scheduleMonth;
  DateTime? specificDate;
  bool timeAllDay;
  TimeOfDay timeStart;
  TimeOfDay timeEnd;
  List<NotificationRule> notificationRules;

  _ReportListDraft({
    required this.localId,
    this.dbId,
    required this.titleCtrl,
    required this.descCtrl,
    List<_FieldDraft>? fields,
    List<Determinant>? determinants,
    this.scheduleType = ReportScheduleType.anytime,
    this.dayOfWeek = 0,
    this.dayOfMonth = 1,
    this.scheduleMonth = 1,
    this.specificDate,
    this.timeAllDay = true,
    this.timeStart = const TimeOfDay(hour: 8, minute: 0),
    this.timeEnd = const TimeOfDay(hour: 20, minute: 0),
    List<NotificationRule>? notificationRules,
  })  : fields = fields ?? [],
        determinants = determinants ?? [],
        notificationRules = notificationRules ?? [];

  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    for (final f in fields) {
      f.titleCtrl.dispose();
      f.hintCtrl.dispose();
    }
  }
}

// ─── Draft card widget ────────────────────────────────────────────────────────

class _ReportListDraftCard extends StatefulWidget {
  final _ReportListDraft draft;
  final int index;
  final Color color;
  final Uuid uuid;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _ReportListDraftCard({
    super.key,
    required this.draft,
    required this.index,
    required this.color,
    required this.uuid,
    required this.canDelete,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_ReportListDraftCard> createState() => _ReportListDraftCardState();
}

class _ReportListDraftCardState extends State<_ReportListDraftCard> {
  bool _expanded = true;
  int _tab = 0; // 0=fields, 1=determinants, 2=schedule, 3=notifications

  static const _tabs = [
    (label: 'الحقول',        icon: Icons.edit_note_rounded),
    (label: 'المحددات',      icon: Icons.tune_rounded),
    (label: 'الجدول الزمني', icon: Icons.schedule_rounded),
    (label: 'الإشعارات',     icon: Icons.notifications_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(_kRadius)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text('${widget.index + 1}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: widget.color)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.titleCtrl.text.isEmpty
                              ? 'قائمة تقرير ${widget.index + 1}'
                              : d.titleCtrl.text,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _kTextPrimary),
                        ),
                        Text(
                          '${d.fields.length} حقل • ${d.determinants.length} محدد',
                          style: const TextStyle(
                              fontSize: 11, color: _kTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (widget.canDelete)
                    IconButton(
                      icon:
                          const Icon(Icons.delete_outline, color: _kDanger, size: 18),
                      onPressed: widget.onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: _kTextSecondary,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded content ─────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1, color: _kBorder),

            // Title & description
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _labeledField('اسم القائمة *', d.titleCtrl,
                      'مثال: تقرير المتابعة اليومي',
                      onChanged: (_) => setState(() {})),
                  const SizedBox(height: 10),
                  _labeledField('الوصف (اختياري)', d.descCtrl,
                      'وصف مختصر لهذه القائمة',
                      maxLines: 2),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Tab bar
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: _kBorder),
                  bottom: BorderSide(color: _kBorder),
                ),
              ),
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final t = _tabs[i];
                  final active = _tab == i;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tab = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: active
                              ? widget.color.withValues(alpha: 0.06)
                              : Colors.transparent,
                          border: Border(
                            bottom: BorderSide(
                              color:
                                  active ? widget.color : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(t.icon,
                                size: 14,
                                color: active
                                    ? widget.color
                                    : _kTextSecondary),
                            const SizedBox(width: 5),
                            Text(t.label,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: active
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: active
                                        ? widget.color
                                        : _kTextSecondary)),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Tab content
            Padding(
              padding: const EdgeInsets.all(14),
              child: _buildTabContent(d),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabContent(_ReportListDraft d) {
    switch (_tab) {
      case 0:
        return _buildFieldsTab(d);
      case 1:
        return _buildDeterminantsTab(d);
      case 2:
        return _buildScheduleTab(d);
      case 3:
        return _buildNotificationsTab(d);
      default:
        return const SizedBox();
    }
  }

  Widget _buildFieldsTab(_ReportListDraft d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('الحقول',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kTextPrimary)),
            const Spacer(),
            TextButton.icon(
              style: TextButton.styleFrom(
                  foregroundColor: widget.color,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('إضافة حقل', style: TextStyle(fontSize: 12)),
              onPressed: () {
                setState(() => d.fields.add(_FieldDraft(
                      id: widget.uuid.v4(),
                      titleCtrl: TextEditingController(),
                      hintCtrl: TextEditingController(),
                    )));
                widget.onChanged();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (d.fields.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder),
            ),
            child: const Center(
              child: Text('اضغط "إضافة حقل" لإضافة منطقة نص',
                  style: TextStyle(color: _kTextSecondary, fontSize: 13)),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: d.fields.length,
            onReorder: (old, nw) {
              setState(() {
                final item = d.fields.removeAt(old);
                d.fields.insert(nw > old ? nw - 1 : nw, item);
              });
              widget.onChanged();
            },
            itemBuilder: (_, i) => _FieldEditor(
              key: ValueKey(d.fields[i].id),
              field: d.fields[i],
              index: i,
              onDelete: () {
                setState(() => d.fields.removeAt(i));
                widget.onChanged();
              },
              onChanged: () {
                setState(() {});
                widget.onChanged();
              },
            ),
          ),
      ],
    );
  }

  Widget _buildDeterminantsTab(_ReportListDraft d) {
    return _DeterminantsEditor(
      determinants: d.determinants,
      color: widget.color,
      onChanged: () {
        setState(() {});
        widget.onChanged();
      },
      uuid: widget.uuid,
    );
  }

  Widget _buildScheduleTab(_ReportListDraft d) {
    return _ScheduleEditor(
      scheduleType: d.scheduleType,
      dayOfWeek: d.dayOfWeek,
      dayOfMonth: d.dayOfMonth,
      scheduleMonth: d.scheduleMonth,
      specificDate: d.specificDate,
      timeAllDay: d.timeAllDay,
      timeStart: d.timeStart,
      timeEnd: d.timeEnd,
      color: widget.color,
      onScheduleTypeChanged: (v) => setState(() => d.scheduleType = v),
      onDayOfWeekChanged: (v) => setState(() => d.dayOfWeek = v),
      onDayOfMonthChanged: (v) => setState(() => d.dayOfMonth = v),
      onScheduleMonthChanged: (v) => setState(() => d.scheduleMonth = v),
      onSpecificDateChanged: (v) => setState(() => d.specificDate = v),
      onTimeAllDayChanged: (v) => setState(() => d.timeAllDay = v),
      onTimeStartChanged: (v) => setState(() => d.timeStart = v),
      onTimeEndChanged: (v) => setState(() => d.timeEnd = v),
    );
  }

  // ── Notifications tab ─────────────────────────────────────────────────────

  static const _kNotifColor = Color(0xFFD97706);

  static const _allRuleTypes = NotificationRuleType.values;

  static const _ruleIcons = <NotificationRuleType, IconData>{
    NotificationRuleType.dailyReminder: Icons.alarm_rounded,
    NotificationRuleType.exitWithoutSubmit: Icons.exit_to_app_rounded,
    NotificationRuleType.beforeDeadline: Icons.timer_rounded,
    NotificationRuleType.missedSubmission: Icons.notification_important_rounded,
    NotificationRuleType.afterPartialFill: Icons.pending_actions_rounded,
    NotificationRuleType.scheduleStart: Icons.event_available_rounded,
  };

  Widget _buildNotificationsTab(_ReportListDraft d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header hint
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _kNotifColor.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kNotifColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 15, color: _kNotifColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'فعّل الإشعارات التلقائية التي تريدها. سيتم إرسالها عبر الإشعارات الفورية للمستخدمين المعيّنين.',
                  style: TextStyle(fontSize: 11, color: _kTextSecondary, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Rule cards
        ...List.generate(_allRuleTypes.length, (i) {
          final type = _allRuleTypes[i];
          final existingIdx =
              d.notificationRules.indexWhere((r) => r.type == type);
          final rule = existingIdx >= 0 ? d.notificationRules[existingIdx] : null;
          final isEnabled = rule?.enabled ?? false;

          return _NotificationRuleCard(
            type: type,
            icon: _ruleIcons[type] ?? Icons.notifications_rounded,
            isEnabled: isEnabled,
            config: rule?.config ?? {},
            accentColor: _kNotifColor,
            onToggle: (v) {
              setState(() {
                if (v) {
                  if (existingIdx >= 0) {
                    d.notificationRules[existingIdx] =
                        d.notificationRules[existingIdx].copyWith(enabled: true);
                  } else {
                    d.notificationRules.add(NotificationRule(type: type, enabled: true));
                  }
                } else {
                  if (existingIdx >= 0) {
                    d.notificationRules[existingIdx] =
                        d.notificationRules[existingIdx].copyWith(enabled: false);
                  }
                }
              });
              widget.onChanged();
            },
            onConfigChanged: (cfg) {
              setState(() {
                final idx = d.notificationRules.indexWhere((r) => r.type == type);
                if (idx >= 0) {
                  d.notificationRules[idx] =
                      d.notificationRules[idx].copyWith(config: cfg);
                }
              });
              widget.onChanged();
            },
          );
        }),
      ],
    );
  }

  Widget _labeledField(
    String label,
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _kTextPrimary)),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(fontSize: 12, color: _kTextSecondary),
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: widget.color, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }
}

// ─── Step scaffold ────────────────────────────────────────────────────────────

class _StepScaffold extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget child;

  const _StepScaffold({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_kRadius),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _kTextPrimary)),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: _kTextSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_kRadius),
              border: Border.all(color: _kBorder),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─── Switch card ──────────────────────────────────────────────────────────────

class _SwitchCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  const _SwitchCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: value ? color.withValues(alpha: 0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: value ? color.withValues(alpha: 0.3) : _kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _kTextPrimary)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: _kTextSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: color,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ─── Field draft model ────────────────────────────────────────────────────────

class _FieldDraft {
  final String id;
  final TextEditingController titleCtrl;
  final TextEditingController hintCtrl;
  bool isRequired;

  _FieldDraft({
    required this.id,
    required this.titleCtrl,
    required this.hintCtrl,
    this.isRequired = false,
  });
}

// ─── Field editor tile ────────────────────────────────────────────────────────

class _FieldEditor extends StatelessWidget {
  final _FieldDraft field;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _FieldEditor({
    super.key,
    required this.field,
    required this.index,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header bar ───────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: _kBg,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                const Icon(Icons.drag_handle_rounded,
                    color: _kTextSecondary, size: 18),
                const SizedBox(width: 6),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _kAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Center(
                    child: Text('${index + 1}',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _kAccent)),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('حقل نصي',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _kTextSecondary)),
                const Spacer(),
                Text('إلزامي',
                    style: TextStyle(
                        fontSize: 11,
                        color: field.isRequired
                            ? _kAccent
                            : _kTextSecondary)),
                Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    value: field.isRequired,
                    activeThumbColor: _kAccent,
                    onChanged: (v) {
                      field.isRequired = v;
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 2),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: _kDanger, size: 18),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'حذف الحقل',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          // ── Body: title + hint inputs ─────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: field.titleCtrl,
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(
                    labelText: 'عنوان الحقل *',
                    labelStyle: const TextStyle(
                        fontSize: 12, color: _kTextSecondary),
                    prefixIcon: const Icon(Icons.title_rounded,
                        size: 16, color: _kTextSecondary),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.grey.shade50,
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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: field.hintCtrl,
                  decoration: InputDecoration(
                    labelText: 'نص توجيهي (اختياري)',
                    labelStyle: const TextStyle(
                        fontSize: 12, color: _kTextSecondary),
                    prefixIcon: const Icon(Icons.help_outline_rounded,
                        size: 16, color: _kTextSecondary),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.grey.shade50,
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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
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

// ─── Determinants editor ──────────────────────────────────────────────────────

class _DeterminantsEditor extends StatefulWidget {
  final List<Determinant> determinants;
  final Color color;
  final VoidCallback onChanged;
  final Uuid uuid;

  const _DeterminantsEditor({
    required this.determinants,
    required this.color,
    required this.onChanged,
    required this.uuid,
  });

  @override
  State<_DeterminantsEditor> createState() => _DeterminantsEditorState();
}

class _DeterminantsEditorState extends State<_DeterminantsEditor> {
  void _addDeterminant() {
    setState(() {
      widget.determinants
          .add(Determinant(id: widget.uuid.v4(), name: '', options: []));
      widget.onChanged();
    });
  }

  void _removeDeterminant(int i) {
    setState(() {
      widget.determinants.removeAt(i);
      widget.onChanged();
    });
  }

  void _addOption(int di) {
    setState(() {
      final opts =
          List<DeterminantOption>.from(widget.determinants[di].options)
            ..add(DeterminantOption(id: widget.uuid.v4(), value: ''));
      widget.determinants[di] =
          widget.determinants[di].copyWith(options: opts);
      widget.onChanged();
    });
  }

  void _removeOption(int di, int oi) {
    setState(() {
      final opts =
          List<DeterminantOption>.from(widget.determinants[di].options)
            ..removeAt(oi);
      widget.determinants[di] =
          widget.determinants[di].copyWith(options: opts);
      widget.onChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Text('المحددات',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kTextPrimary)),
            const Spacer(),
            TextButton.icon(
              style: TextButton.styleFrom(
                  foregroundColor: widget.color,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6)),
              icon: const Icon(Icons.add, size: 16),
              label:
                  const Text('إضافة محدد', style: TextStyle(fontSize: 12)),
              onPressed: _addDeterminant,
            ),
          ],
        ),
        if (widget.determinants.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder),
            ),
            child: const Center(
              child: Text('لا توجد محددات (اختياري)',
                  style:
                      TextStyle(color: _kTextSecondary, fontSize: 13)),
            ),
          )
        else
          ...List.generate(widget.determinants.length, (di) {
            final det = widget.determinants[di];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('محدد ${di + 1}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _kTextSecondary)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: _kDanger, size: 18),
                        onPressed: () => _removeDeterminant(di),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: det.name,
                    decoration: const InputDecoration(
                      labelText: 'اسم المحدد',
                      labelStyle: TextStyle(fontSize: 12),
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                    ),
                    onChanged: (v) {
                      widget.determinants[di] = det.copyWith(name: v);
                      widget.onChanged();
                    },
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(det.options.length, (oi) {
                    final opt = det.options[oi];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          const Icon(Icons.circle,
                              size: 6, color: _kTextSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: opt.value,
                              decoration: InputDecoration(
                                hintText: 'قيمة الخيار ${oi + 1}',
                                hintStyle:
                                    const TextStyle(fontSize: 12),
                                isDense: true,
                                border: const OutlineInputBorder(),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                              ),
                              onChanged: (v) {
                                final opts =
                                    List<DeterminantOption>.from(
                                        det.options);
                                opts[oi] = opt.copyWith(value: v);
                                widget.determinants[di] =
                                    det.copyWith(options: opts);
                                widget.onChanged();
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                size: 14, color: _kDanger),
                            onPressed: () => _removeOption(di, oi),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: widget.color,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4)),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('إضافة خيار',
                        style: TextStyle(fontSize: 11)),
                    onPressed: () => _addOption(di),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

// ─── Schedule editor ──────────────────────────────────────────────────────────

class _ScheduleEditor extends StatelessWidget {
  final ReportScheduleType scheduleType;
  final int dayOfWeek;
  final int dayOfMonth;
  final int scheduleMonth;
  final DateTime? specificDate;
  final bool timeAllDay;
  final TimeOfDay timeStart;
  final TimeOfDay timeEnd;
  final Color color;
  final ValueChanged<ReportScheduleType> onScheduleTypeChanged;
  final ValueChanged<int> onDayOfWeekChanged;
  final ValueChanged<int> onDayOfMonthChanged;
  final ValueChanged<int> onScheduleMonthChanged;
  final ValueChanged<DateTime?> onSpecificDateChanged;
  final ValueChanged<bool> onTimeAllDayChanged;
  final ValueChanged<TimeOfDay> onTimeStartChanged;
  final ValueChanged<TimeOfDay> onTimeEndChanged;

  const _ScheduleEditor({
    required this.scheduleType,
    required this.dayOfWeek,
    required this.dayOfMonth,
    required this.scheduleMonth,
    required this.specificDate,
    required this.timeAllDay,
    required this.timeStart,
    required this.timeEnd,
    required this.color,
    required this.onScheduleTypeChanged,
    required this.onDayOfWeekChanged,
    required this.onDayOfMonthChanged,
    required this.onScheduleMonthChanged,
    required this.onSpecificDateChanged,
    required this.onTimeAllDayChanged,
    required this.onTimeStartChanged,
    required this.onTimeEndChanged,
  });

  static const _days = [
    'أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'
  ];
  static const _months = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('نوع الجدول',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _kTextPrimary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ReportScheduleType.values.map((t) {
            final selected = scheduleType == t;
            return GestureDetector(
              onTap: () => onScheduleTypeChanged(t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? color : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: selected ? color : _kBorder),
                ),
                child: Text(t.displayText,
                    style: TextStyle(
                        fontSize: 12,
                        color: selected
                            ? Colors.white
                            : _kTextSecondary,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        if (scheduleType == ReportScheduleType.weekly) ...[
          const Text('اليوم من الأسبوع',
              style: TextStyle(fontSize: 13, color: _kTextPrimary)),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            initialValue: dayOfWeek,
            decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            items: List.generate(7,
                (i) => DropdownMenuItem(value: i, child: Text(_days[i]))),
            onChanged: (v) {
              if (v != null) onDayOfWeekChanged(v);
            },
          ),
        ],

        if (scheduleType == ReportScheduleType.monthly ||
            scheduleType == ReportScheduleType.yearly) ...[
          const Text('يوم الشهر',
              style: TextStyle(fontSize: 13, color: _kTextPrimary)),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            initialValue: dayOfMonth,
            decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            items: List.generate(
                31,
                (i) => DropdownMenuItem(
                    value: i + 1, child: Text('${i + 1}'))),
            onChanged: (v) {
              if (v != null) onDayOfMonthChanged(v);
            },
          ),
          const SizedBox(height: 10),
        ],

        if (scheduleType == ReportScheduleType.yearly) ...[
          const Text('الشهر',
              style: TextStyle(fontSize: 13, color: _kTextPrimary)),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            initialValue: scheduleMonth,
            decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            items: List.generate(
                12,
                (i) => DropdownMenuItem(
                    value: i + 1, child: Text(_months[i]))),
            onChanged: (v) {
              if (v != null) onScheduleMonthChanged(v);
            },
          ),
          const SizedBox(height: 10),
        ],

        if (scheduleType == ReportScheduleType.specificDate) ...[
          const Text('التاريخ المحدد',
              style: TextStyle(fontSize: 13, color: _kTextPrimary)),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: specificDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) onSpecificDateChanged(picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: _kBorder),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 16, color: _kTextSecondary),
                  const SizedBox(width: 8),
                  Text(
                    specificDate != null
                        ? '${specificDate!.day}/${specificDate!.month}/${specificDate!.year}'
                        : 'اختر تاريخاً',
                    style: TextStyle(
                        fontSize: 13,
                        color: specificDate != null
                            ? _kTextPrimary
                            : _kTextSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],

        const Divider(color: _kBorder),
        const SizedBox(height: 8),

        const Text('نافذة الوقت',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _kTextPrimary)),
        const SizedBox(height: 8),
        _SwitchCard(
          title: 'طوال اليوم',
          subtitle: 'يمكن تقديم التقرير في أي وقت خلال اليوم',
          value: timeAllDay,
          color: color,
          onChanged: onTimeAllDayChanged,
        ),
        if (!timeAllDay) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('من',
                        style: TextStyle(
                            fontSize: 12, color: _kTextSecondary)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        final t = await showTimePicker(
                            context: context, initialTime: timeStart);
                        if (t != null) onTimeStartChanged(t);
                      },
                      child: _TimeChip(time: timeStart),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إلى',
                        style: TextStyle(
                            fontSize: 12, color: _kTextSecondary)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        final t = await showTimePicker(
                            context: context, initialTime: timeEnd);
                        if (t != null) onTimeEndChanged(t);
                      },
                      child: _TimeChip(time: timeEnd),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  final TimeOfDay time;
  const _TimeChip({required this.time});

  @override
  Widget build(BuildContext context) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, size: 16, color: _kTextSecondary),
          const SizedBox(width: 6),
          Text('$h:$m',
              style:
                  const TextStyle(fontSize: 14, color: _kTextPrimary)),
        ],
      ),
    );
  }
}

// ─── Notification rule card ───────────────────────────────────────────────────

class _NotificationRuleCard extends StatefulWidget {
  final NotificationRuleType type;
  final IconData icon;
  final bool isEnabled;
  final Map<String, dynamic> config;
  final Color accentColor;
  final ValueChanged<bool> onToggle;
  final ValueChanged<Map<String, dynamic>> onConfigChanged;

  const _NotificationRuleCard({
    required this.type,
    required this.icon,
    required this.isEnabled,
    required this.config,
    required this.accentColor,
    required this.onToggle,
    required this.onConfigChanged,
  });

  @override
  State<_NotificationRuleCard> createState() => _NotificationRuleCardState();
}

class _NotificationRuleCardState extends State<_NotificationRuleCard> {
  late TextEditingController _timeCtrl;
  late TextEditingController _minutesCtrl;
  late TextEditingController _hoursCtrl;

  @override
  void initState() {
    super.initState();
    _timeCtrl = TextEditingController(
        text: widget.config['time'] as String? ?? '09:00');
    _minutesCtrl = TextEditingController(
        text: (widget.config['minutes_before'] ?? 30).toString());
    _hoursCtrl = TextEditingController(
        text: (widget.config['hours_after'] ?? 2).toString());
  }

  @override
  void dispose() {
    _timeCtrl.dispose();
    _minutesCtrl.dispose();
    _hoursCtrl.dispose();
    super.dispose();
  }

  void _emitConfig() {
    final cfg = <String, dynamic>{};
    switch (widget.type) {
      case NotificationRuleType.dailyReminder:
        cfg['time'] = _timeCtrl.text.trim();
        break;
      case NotificationRuleType.beforeDeadline:
        cfg['minutes_before'] = int.tryParse(_minutesCtrl.text.trim()) ?? 30;
        break;
      case NotificationRuleType.afterPartialFill:
        cfg['hours_after'] = int.tryParse(_hoursCtrl.text.trim()) ?? 2;
        break;
      default:
        break;
    }
    widget.onConfigChanged(cfg);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: widget.isEnabled
            ? widget.accentColor.withValues(alpha: 0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isEnabled
              ? widget.accentColor.withValues(alpha: 0.3)
              : _kBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: widget.isEnabled
                        ? widget.accentColor.withValues(alpha: 0.12)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 16,
                    color: widget.isEnabled
                        ? widget.accentColor
                        : _kTextSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.type.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.isEnabled
                              ? _kTextPrimary
                              : _kTextSecondary,
                        ),
                      ),
                      Text(
                        widget.type.description,
                        style: const TextStyle(
                            fontSize: 10,
                            color: _kTextSecondary,
                            height: 1.3),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: widget.isEnabled,
                  activeThumbColor: widget.accentColor,
                  onChanged: widget.onToggle,
                ),
              ],
            ),
          ),

          // Config section (only when enabled and rule has configurable options)
          if (widget.isEnabled) _buildConfig(),
        ],
      ),
    );
  }

  Widget _buildConfig() {
    switch (widget.type) {
      case NotificationRuleType.dailyReminder:
        return _ConfigRow(
          label: 'وقت الإشعار',
          child: SizedBox(
            width: 100,
            child: TextField(
              controller: _timeCtrl,
              textAlign: TextAlign.center,
              onChanged: (_) => _emitConfig(),
              decoration: _miniInputDecor('مثال: 09:00'),
            ),
          ),
        );

      case NotificationRuleType.beforeDeadline:
        return _ConfigRow(
          label: 'قبل الموعد بـ (دقيقة)',
          child: SizedBox(
            width: 80,
            child: TextField(
              controller: _minutesCtrl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              onChanged: (_) => _emitConfig(),
              decoration: _miniInputDecor('30'),
            ),
          ),
        );

      case NotificationRuleType.afterPartialFill:
        return _ConfigRow(
          label: 'بعد توقف الملء بـ (ساعة)',
          child: SizedBox(
            width: 80,
            child: TextField(
              controller: _hoursCtrl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              onChanged: (_) => _emitConfig(),
              decoration: _miniInputDecor('2'),
            ),
          ),
        );

      // exitWithoutSubmit and missedSubmission need no extra config
      default:
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Text(
            'لا توجد إعدادات إضافية — الإشعار يُرسل تلقائياً عند حدوث الحالة.',
            style: TextStyle(
                fontSize: 10,
                color: _kTextSecondary.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic),
          ),
        );
    }
  }

  InputDecoration _miniInputDecor(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 11, color: _kTextSecondary),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _kBorder)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      );
}

class _ConfigRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _ConfigRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: _kTextSecondary,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 10),
          child,
        ],
      ),
    );
  }
}
