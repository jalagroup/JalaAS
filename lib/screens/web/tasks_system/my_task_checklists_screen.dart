// lib/screens/web/my_task_checklists_screen.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../models/task_checklist_models.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/helpers.dart';
import 'task_checklist_form_screen.dart';

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

// ══════════════════════════════════════════════════════════════════════════════
class MyTaskChecklistsScreen extends StatefulWidget {
  const MyTaskChecklistsScreen({super.key});

  @override
  State<MyTaskChecklistsScreen> createState() => _MyTaskChecklistsScreenState();
}

class _MyTaskChecklistsScreenState extends State<MyTaskChecklistsScreen> {
  List<TaskChecklist> _checklists = [];
  List<TaskChecklistResponse> _todayResponses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getMyTaskChecklists(),
        SupabaseService.getMyTodayTaskResponses(),
      ]);
      if (mounted) {
        setState(() {
          _checklists     = results[0] as List<TaskChecklist>;
          _todayResponses = results[1] as List<TaskChecklistResponse>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        Helpers.showSnackBar(context, 'فشل التحميل: $e', isError: true);
      }
    }
  }

  /// Find today's response for a given checklist
  TaskChecklistResponse? _todayResponse(int checklistId) =>
      _todayResponses.where((r) => r.checklistId == checklistId).firstOrNull;

  /// Check if today is a valid day to do this checklist
  bool _isDueToday(TaskChecklist cl) {
    final today = DateTime.now();
    switch (cl.frequency) {
      case TaskChecklistFrequency.daily:
        return true;
      case TaskChecklistFrequency.specificDays:
        // weekday: 1=Mon … 7=Sun
        return cl.scheduledDays.contains(today.weekday);
      case TaskChecklistFrequency.once:
        if (cl.onceDate == null) return false;
        return cl.onceDate!.year == today.year &&
               cl.onceDate!.month == today.month &&
               cl.onceDate!.day == today.day;
    }
  }

  List<TaskChecklist> get _dueToday =>
      _checklists.where(_isDueToday).toList();

  List<TaskChecklist> get _notDueToday =>
      _checklists.where((cl) => !_isDueToday(cl)).toList();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 640;
    final today = DateTime.now();
    final due = _dueToday;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: _buildAppBar(due.length),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _kAccent))
            : RefreshIndicator(
                onRefresh: _load,
                color: _kAccent,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 14 : 20,
                    vertical: 14,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 700),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Today summary card
                        _buildSummaryCard(due, today, isMobile),
                        const SizedBox(height: 20),

                        // Due today section
                        if (due.isNotEmpty) ...[
                          _sectionLabel(
                            Icons.today_rounded,
                            'مستحقة اليوم',
                            _kAccent,
                            '${due.length}',
                          ),
                          const SizedBox(height: 10),
                          ...due.map((cl) => _buildChecklistTile(cl, today, isMobile)),
                          const SizedBox(height: 20),
                        ],

                        // Not due today
                        if (_notDueToday.isNotEmpty) ...[
                          _sectionLabel(Icons.schedule_rounded, 'قوائم أخرى', _kTextMuted, '${_notDueToday.length}'),
                          const SizedBox(height: 10),
                          ..._notDueToday.map((cl) => _buildChecklistTile(cl, today, isMobile, dimmed: true)),
                        ],

                        if (_checklists.isEmpty)
                          _buildEmpty(),
                      ]),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(int dueCount) => AppBar(
    elevation: 0,
    scrolledUnderElevation: 1,
    backgroundColor: _kSurface,
    surfaceTintColor: _kSurface,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _kText),
      onPressed: () => Navigator.pop(context),
    ),
    title: const Text('قوائم مهامي',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
    actions: [
      if (dueCount > 0)
        Container(
          margin: const EdgeInsets.only(left: 14),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _kWarning.withValues(alpha:0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kWarning.withValues(alpha:0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.notifications_active_rounded, size: 13, color: _kWarning),
            const SizedBox(width: 4),
            Text('$dueCount مستحقة',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _kWarning)),
          ]),
        ),
    ],
  );

  Widget _buildSummaryCard(List<TaskChecklist> due, DateTime today, bool isMobile) {
    final doneCount = due.where((cl) {
      final r = _todayResponse(cl.id);
      return r?.status == TaskChecklistStatus.completed;
    }).length;
    final total = due.length;
    final progress = total == 0 ? 1.0 : doneCount / total;
    final color = progress == 1.0 ? _kSuccess : _kAccent;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            _kAccent,
            _kAccent.withValues(alpha:0.75),
          ],
        ),
        borderRadius: BorderRadius.circular(_kRadiusLg),
        boxShadow: [
          BoxShadow(
            color: _kAccent.withValues(alpha:0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.2),
              borderRadius: BorderRadius.circular(_kRadius),
            ),
            child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('اليوم', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text(
              '${today.day}/${today.month}/${today.year}',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$doneCount/$total',
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
            const Text('مكتمل', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ]),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha:0.2),
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          progress == 1.0
              ? '🎉 أحسنت! أكملت جميع مهام اليوم'
              : 'تبقى ${total - doneCount} قائمة لإنجازها اليوم',
          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500),
        ),
      ]),
    );
  }

  Widget _buildChecklistTile(TaskChecklist cl, DateTime today, bool isMobile, {bool dimmed = false}) {
    final response = _todayResponse(cl.id);
    final isDue = _isDueToday(cl);
    final status = response?.status ?? TaskChecklistStatus.pending;
    final progress = response?.progress ?? 0.0;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case TaskChecklistStatus.completed:
        statusColor = _kSuccess; statusLabel = 'مكتمل ✓'; statusIcon = Icons.check_circle_rounded;
        break;
      case TaskChecklistStatus.inProgress:
        statusColor = _kWarning; statusLabel = 'جارٍ...'; statusIcon = Icons.pending_rounded;
        break;
      case TaskChecklistStatus.missed:
        statusColor = _kDanger; statusLabel = 'فائت'; statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = isDue ? _kAccent : _kTextMuted;
        statusLabel = isDue ? 'ابدأ' : 'ليس اليوم';
        statusIcon = isDue ? Icons.play_circle_rounded : Icons.schedule_rounded;
    }

    final bool tappable =
        isDue && status != TaskChecklistStatus.missed && status != TaskChecklistStatus.completed;

    final freqIcon = cl.frequency == TaskChecklistFrequency.daily
        ? Icons.repeat_rounded
        : cl.frequency == TaskChecklistFrequency.specificDays
            ? Icons.date_range_rounded
            : Icons.event_rounded;

    return Opacity(
      opacity: dimmed ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(_kRadius),
          border: Border.all(color: _kBorder),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_kRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(_kRadius),
            onTap: !tappable
                ? null
                : () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => TaskChecklistFormScreen(
                                  checklist: cl,
                                  scheduledDate: today,
                                )));
                    _load();
                  },
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16, vertical: isMobile ? 10 : 12),
              child: Row(children: [
                // ── Accent bar ───────────────────────────────
                Container(
                  width: 3,
                  height: 36,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // ── Icon box ─────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 16),
                ),
                const SizedBox(width: 10),
                // ── Title + meta chips ────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cl.title,
                          style: TextStyle(
                              fontSize: isMobile ? 13 : 14,
                              fontWeight: FontWeight.w600,
                              color: _kText)),
                      const SizedBox(height: 4),
                      Wrap(spacing: 10, runSpacing: 2, children: [
                        _miniChip(Icons.task_rounded, '${cl.tasks.length} مهمة',
                            const Color(0xFF6366F1)),
                        _miniChip(freqIcon, cl.frequency.displayText, _kTextMuted),
                        if (status == TaskChecklistStatus.inProgress)
                          _miniChip(Icons.pending_outlined,
                              '${(progress * 100).toInt()}%', _kWarning),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // ── Action / status button ────────────────────
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 8 : 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: tappable
                        ? statusColor
                        : statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(statusLabel,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: tappable ? Colors.white : statusColor)),
                    if (tappable) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 10, color: Colors.white),
                    ],
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60),
    child: Center(
      child: Column(children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: _kAccent.withValues(alpha:0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.inbox_outlined, color: _kAccent, size: 36),
        ),
        const SizedBox(height: 14),
        const Text('لا توجد قوائم مهام مخصصة لك',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kText)),
        const SizedBox(height: 6),
        const Text('سيتم إشعارك عند تخصيص قوائم جديدة لك',
            style: TextStyle(fontSize: 13, color: _kTextMuted)),
      ]),
    ),
  );

  Widget _sectionLabel(IconData icon, String label, Color color, String count) =>
      Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 7),
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(count,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ),
      ]);

  Widget _miniChip(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 11, color: color)),
    ],
  );
}