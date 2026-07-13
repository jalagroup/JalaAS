import 'package:flutter/material.dart';
import 'package:jala_as/models/report_models.dart';
import 'package:jala_as/models/user.dart';
import 'package:jala_as/services/supabase_service.dart';
import 'package:jala_as/utils/constants.dart';
import 'package:jala_as/utils/helpers.dart';
import 'report_list_fill_screen.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF0891B2);
const _kTextPrimary = Color(AppConstants.primaryColor);
const _kSuccess = Color(0xFF059669);
const _kWarning = Color(0xFFD97706);
const _kTextSecondary = Color(0xFF64748B);

// ─────────────────────────────────────────────────────────────────────────────
//  Availability check — pure logic
// ─────────────────────────────────────────────────────────────────────────────

class _Availability {
  final bool isScheduleDay;
  final bool isWithinTime;
  final bool alreadyFilled;

  const _Availability({
    required this.isScheduleDay,
    required this.isWithinTime,
    required this.alreadyFilled,
  });

  bool get canFill => isScheduleDay && isWithinTime && !alreadyFilled;
}

bool _isScheduleDay(ReportList rl, DateTime now) {
  switch (rl.scheduleType) {
    case ReportScheduleType.anytime:
    case ReportScheduleType.daily:
      return true;
    case ReportScheduleType.weekly:
      final dartDay = now.weekday % 7; // Mon=1→1, Sun=7→0
      return dartDay == (rl.scheduleDayOfWeek ?? 0);
    case ReportScheduleType.monthly:
      return now.day == (rl.scheduleDayOfMonth ?? 1);
    case ReportScheduleType.yearly:
      return now.day == (rl.scheduleDayOfMonth ?? 1) &&
          now.month == (rl.scheduleMonth ?? 1);
    case ReportScheduleType.specificDate:
      final sd = rl.scheduleDate;
      if (sd == null) return false;
      return now.year == sd.year && now.month == sd.month && now.day == sd.day;
  }
}

bool _isWithinTimeWindow(ReportList rl, DateTime now) {
  if (rl.timeAllDay) return true;
  final start = rl.timeStart;
  final end = rl.timeEnd;
  if (start == null || end == null) return true;

  final parse = (String s) {
    final p = s.split(':');
    return TimeOfDay(
        hour: int.tryParse(p[0]) ?? 0,
        minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
  };

  final s = parse(start);
  final e = parse(end);
  final nowMins = now.hour * 60 + now.minute;
  final sMins = s.hour * 60 + s.minute;
  final eMins = e.hour * 60 + e.minute;

  if (sMins <= eMins) {
    return nowMins >= sMins && nowMins <= eMins;
  } else {
    return nowMins >= sMins || nowMins <= eMins;
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class MyReportListsScreen extends StatefulWidget {
  final AppUser user;

  const MyReportListsScreen({super.key, required this.user});

  @override
  State<MyReportListsScreen> createState() => _MyReportListsScreenState();
}

class _MyReportListsScreenState extends State<MyReportListsScreen> {
  List<ReportList> _lists = [];
  final Map<int, ReportListResponse?> _todayResponses = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final lists = await SupabaseService.getMyAssignedReportLists(userId: widget.user.id);
      final now = DateTime.now();

      final responses = await Future.wait(
        lists.map((rl) => SupabaseService.getMyReportListResponseForDate(
              reportListId: rl.id,
              date: now,
              forUserId: widget.user.id,
            )),
      );

      if (!mounted) return;
      setState(() {
        _lists = lists;
        for (int i = 0; i < lists.length; i++) {
          _todayResponses[lists[i].id] = responses[i];
        }
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        Helpers.showSnackBar(context, 'فشل في تحميل القوائم', isError: true);
      }
    }
  }

  _Availability _checkAvailability(ReportList rl) {
    final now = DateTime.now();
    return _Availability(
      isScheduleDay: _isScheduleDay(rl, now),
      isWithinTime: _isWithinTimeWindow(rl, now),
      alreadyFilled: _todayResponses[rl.id] != null,
    );
  }

  Future<void> _openFillForm(ReportList rl) async {
    final existing = _todayResponses[rl.id];
    final canEdit = existing != null &&
        rl.canEditSubmissions &&
        DateTime.now().difference(existing.submittedAt).inHours < 48;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReportListFillScreen(
          reportList: rl,
          existingResponse: (existing != null && canEdit) ? existing : null,
        ),
      ),
    );
    if (result == true) _load();
  }

  String _scheduleLabel(ReportList rl) {
    const days = ['أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    switch (rl.scheduleType) {
      case ReportScheduleType.anytime:
        return 'في أي وقت';
      case ReportScheduleType.daily:
        return 'يومي';
      case ReportScheduleType.weekly:
        final d = rl.scheduleDayOfWeek ?? 0;
        return 'أسبوعي – ${days[d.clamp(0, 6)]}';
      case ReportScheduleType.monthly:
        return 'شهري – يوم ${rl.scheduleDayOfMonth ?? ''}';
      case ReportScheduleType.yearly:
        final m = (rl.scheduleMonth ?? 1).clamp(1, 12);
        return 'سنوي – ${rl.scheduleDayOfMonth ?? ''} ${months[m - 1]}';
      case ReportScheduleType.specificDate:
        final sd = rl.scheduleDate;
        return sd != null ? '${sd.day}/${sd.month}/${sd.year}' : 'تاريخ محدد';
    }
  }

  String _timeLabel(ReportList rl) {
    if (rl.timeAllDay) return 'طوال اليوم';
    return '${rl.timeStart ?? ''} – ${rl.timeEnd ?? ''}';
  }

  int get _availableCount =>
      _lists.where((rl) => _checkAvailability(rl).canFill).length;

  int get _filledCount =>
      _lists.where((rl) => _todayResponses[rl.id] != null).length;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          iconTheme: const IconThemeData(color: _kTextPrimary),
          title: const Text(
            'قوائم التقارير',
            style: TextStyle(
                color: _kTextPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 17),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: Colors.grey.shade200),
          ),
        ),
        body: _loading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(_kAccent)),
                    ),
                    const SizedBox(height: 14),
                    Text('جارٍ تحميل القوائم المُسندة إليك...',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade500)),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                color: _kAccent,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding:
                      EdgeInsets.all(isMobile ? 14 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(isMobile),
                      if (_lists.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildStatsBar(isMobile),
                        const SizedBox(height: 12),
                        ..._lists.map((rl) {
                          final av = _checkAvailability(rl);
                          return _ReportListCard(
                            reportList: rl,
                            availability: av,
                            scheduleLabel: _scheduleLabel(rl),
                            timeLabel: _timeLabel(rl),
                            isMobile: isMobile,
                            onTap: () {
                              final av2 = _checkAvailability(rl);
                              final interactive = av2.canFill ||
                                  (av2.alreadyFilled && rl.canEditSubmissions);
                              if (interactive) _openFillForm(rl);
                            },
                          );
                        }),
                      ],
                      if (_lists.isEmpty) _buildEmpty(isMobile),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _kAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.assignment_outlined,
                color: _kAccent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'قوائم التقارير',
                  style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.w700,
                      color: _kTextPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'القوائم المُسندة إليك',
                  style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: _kAccent.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.list_alt_rounded,
                    size: 13, color: _kAccent),
                const SizedBox(width: 5),
                Text(
                  '${_lists.length} قائمة',
                  style: const TextStyle(
                      fontSize: 11,
                      color: _kAccent,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16, vertical: 10),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kAccent.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: _kAccent, size: 16),
          const SizedBox(width: 8),
          Text(
            '$_availableCount قائمة متاحة للملء',
            style: TextStyle(
                color: _kAccent,
                fontWeight: FontWeight.w600,
                fontSize: isMobile ? 12 : 13),
          ),
          const Spacer(),
          if (_filledCount > 0)
            Text(
              '$_filledCount مكتملة',
              style: TextStyle(
                  color: _kSuccess,
                  fontWeight: FontWeight.w600,
                  fontSize: isMobile ? 11 : 12),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isMobile) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 60),
          Icon(Icons.assignment_outlined,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('لا توجد قوائم تقارير مخصصة لك',
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 15)),
          const SizedBox(height: 4),
          Text('تواصل مع المشرف لتعيين قوائم إليك',
              style: TextStyle(
                  color: Colors.grey.shade400, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── Card widget ──────────────────────────────────────────────────────────────

class _ReportListCard extends StatelessWidget {
  final ReportList reportList;
  final _Availability availability;
  final String scheduleLabel;
  final String timeLabel;
  final bool isMobile;
  final VoidCallback onTap;

  const _ReportListCard({
    required this.reportList,
    required this.availability,
    required this.scheduleLabel,
    required this.timeLabel,
    required this.isMobile,
    required this.onTap,
  });

  static Widget _chip(IconData icon, String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final av = availability;
    final rl = reportList;

    final Color stateColor;
    final IconData stateIcon;
    String? blockNote;
    String actionLabel;

    if (av.alreadyFilled) {
      stateColor = _kSuccess;
      stateIcon = Icons.check_circle_rounded;
      actionLabel = rl.canEditSubmissions ? 'تعديل' : 'تم ✓';
    } else if (!av.isScheduleDay) {
      stateColor = Colors.grey.shade400;
      stateIcon = Icons.event_busy_rounded;
      actionLabel = 'غير متاح';
      blockNote = scheduleLabel;
    } else if (!av.isWithinTime) {
      stateColor = _kWarning;
      stateIcon = Icons.access_time_filled_rounded;
      actionLabel = 'خارج الوقت';
      blockNote = timeLabel;
    } else {
      stateColor = _kAccent;
      stateIcon = Icons.edit_note_rounded;
      actionLabel = 'ابدأ';
    }

    final bool interactive =
        av.canFill || (av.alreadyFilled && rl.canEditSubmissions);

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: interactive ? onTap : null,
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 10 : 12),
            child: Row(children: [
              // ── Accent bar ─────────────────────────────────
              Container(
                width: 3,
                height: 36,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // ── Icon box ───────────────────────────────────
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(stateIcon, color: stateColor, size: 16),
              ),
              const SizedBox(width: 10),
              // ── Title + chips ──────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rl.title,
                      style: TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          fontWeight: FontWeight.w600,
                          color: _kTextPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(spacing: 10, runSpacing: 2, children: [
                      _chip(Icons.schedule_rounded, scheduleLabel,
                          _kTextSecondary),
                      if (!rl.timeAllDay)
                        _chip(Icons.access_time_rounded, timeLabel,
                            _kTextSecondary),
                      _chip(Icons.text_fields_rounded,
                          '${rl.fields.length} حقل', _kTextSecondary),
                      if (rl.determinants.isNotEmpty)
                        _chip(Icons.tune_rounded,
                            '${rl.determinants.length} محدد',
                            _kTextSecondary),
                    ]),
                    if (blockNote != null) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        Icon(Icons.info_outline,
                            size: 11,
                            color: stateColor.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(blockNote,
                              style: TextStyle(
                                  fontSize: 10,
                                  color:
                                      stateColor.withValues(alpha: 0.8))),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // ── Action button ──────────────────────────────
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 10, vertical: 7),
                decoration: BoxDecoration(
                  color: interactive
                      ? stateColor
                      : stateColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    actionLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: interactive ? Colors.white : stateColor),
                  ),
                  if (interactive) ...[
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
    );
  }
}
