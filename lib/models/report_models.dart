import 'dart:convert';
import 'quality_models.dart'; // reuse Determinant / DeterminantOption

// ---------------------------------------------------------------------------
// Schedule type
// ---------------------------------------------------------------------------

enum ReportScheduleType {
  anytime,
  daily,
  weekly,
  monthly,
  yearly,
  specificDate;

  String get displayText {
    switch (this) {
      case ReportScheduleType.anytime:
        return 'في أي وقت';
      case ReportScheduleType.daily:
        return 'يومي';
      case ReportScheduleType.weekly:
        return 'أسبوعي';
      case ReportScheduleType.monthly:
        return 'شهري';
      case ReportScheduleType.yearly:
        return 'سنوي';
      case ReportScheduleType.specificDate:
        return 'تاريخ محدد';
    }
  }

  String get value {
    switch (this) {
      case ReportScheduleType.anytime:
        return 'anytime';
      case ReportScheduleType.daily:
        return 'daily';
      case ReportScheduleType.weekly:
        return 'weekly';
      case ReportScheduleType.monthly:
        return 'monthly';
      case ReportScheduleType.yearly:
        return 'yearly';
      case ReportScheduleType.specificDate:
        return 'specific_date';
    }
  }

  static ReportScheduleType fromString(String? s) {
    switch (s) {
      case 'daily':
        return ReportScheduleType.daily;
      case 'weekly':
        return ReportScheduleType.weekly;
      case 'monthly':
        return ReportScheduleType.monthly;
      case 'yearly':
        return ReportScheduleType.yearly;
      case 'specific_date':
        return ReportScheduleType.specificDate;
      default:
        return ReportScheduleType.anytime;
    }
  }
}

// ---------------------------------------------------------------------------
// ReportField — a single text-area field inside a report list
// ---------------------------------------------------------------------------

class ReportField {
  final String id;
  final String title;
  final String? hint;
  final bool isRequired;

  const ReportField({
    required this.id,
    required this.title,
    this.hint,
    this.isRequired = false,
  });

  factory ReportField.fromJson(Map<String, dynamic> json) => ReportField(
        id: json['id'] as String,
        title: json['title'] as String,
        hint: json['hint'] as String?,
        isRequired: json['is_required'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'hint': hint,
        'is_required': isRequired,
      };

  ReportField copyWith({
    String? id,
    String? title,
    String? hint,
    bool? isRequired,
  }) =>
      ReportField(
        id: id ?? this.id,
        title: title ?? this.title,
        hint: hint ?? this.hint,
        isRequired: isRequired ?? this.isRequired,
      );
}

// ---------------------------------------------------------------------------
// ReportList — one report form
// ---------------------------------------------------------------------------

class ReportList {
  final int id;
  final int? groupId;
  final String title;
  final String? description;
  final String? selectorOptionValue;
  final List<Determinant> determinants;
  final List<ReportField> fields;
  final bool isActive;
  final String? createdBy;
  final bool canEditSubmissions;
  // Scheduling
  final ReportScheduleType scheduleType;
  final int? scheduleDayOfWeek; // 0=Sun … 6=Sat (for weekly)
  final int? scheduleDayOfMonth; // 1-31 (monthly / yearly)
  final int? scheduleMonth; // 1-12 (yearly)
  final DateTime? scheduleDate; // specific date
  // Time window
  final bool timeAllDay;
  final String? timeStart; // 'HH:mm'
  final String? timeEnd; // 'HH:mm'
  // Notification rules
  final List<NotificationRule> notificationRules;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ReportList({
    required this.id,
    this.groupId,
    required this.title,
    this.description,
    this.selectorOptionValue,
    required this.determinants,
    required this.fields,
    required this.isActive,
    this.createdBy,
    this.canEditSubmissions = false,
    required this.scheduleType,
    this.scheduleDayOfWeek,
    this.scheduleDayOfMonth,
    this.scheduleMonth,
    this.scheduleDate,
    this.timeAllDay = true,
    this.timeStart,
    this.timeEnd,
    this.notificationRules = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReportList.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(
      dynamic v,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      if (v == null) return [];
      List list;
      if (v is List) {
        list = v;
      } else if (v is String && v.isNotEmpty) {
        try {
          list = jsonDecode(v) as List;
        } catch (_) {
          return [];
        }
      } else {
        return [];
      }
      return list.map((e) => fromJson(e as Map<String, dynamic>)).toList();
    }

    return ReportList(
      id: json['id'] as int,
      groupId: json['group_id'] as int?,
      title: json['title'] as String,
      description: json['description'] as String?,
      selectorOptionValue: json['selector_option_value'] as String?,
      determinants: parseList(json['determinants'], Determinant.fromJson),
      fields: parseList(json['fields'], ReportField.fromJson),
      isActive: json['is_active'] as bool? ?? true,
      createdBy: json['created_by'] as String?,
      canEditSubmissions: json['can_edit_submissions'] as bool? ?? false,
      scheduleType:
          ReportScheduleType.fromString(json['schedule_type'] as String?),
      scheduleDayOfWeek: json['schedule_day_of_week'] as int?,
      scheduleDayOfMonth: json['schedule_day_of_month'] as int?,
      scheduleMonth: json['schedule_month'] as int?,
      scheduleDate: json['schedule_date'] != null
          ? DateTime.tryParse(json['schedule_date'] as String)
          : null,
      timeAllDay: json['time_all_day'] as bool? ?? true,
      timeStart: json['time_start'] as String?,
      timeEnd: json['time_end'] as String?,
      notificationRules:
          parseList(json['notification_rules'], NotificationRule.fromJson),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'group_id': groupId,
        'title': title,
        'description': description,
        'selector_option_value': selectorOptionValue,
        'determinants': determinants.map((e) => e.toJson()).toList(),
        'fields': fields.map((e) => e.toJson()).toList(),
        'is_active': isActive,
        'created_by': createdBy,
        'can_edit_submissions': canEditSubmissions,
        'schedule_type': scheduleType.value,
        'schedule_day_of_week': scheduleDayOfWeek,
        'schedule_day_of_month': scheduleDayOfMonth,
        'schedule_month': scheduleMonth,
        'schedule_date': scheduleDate?.toIso8601String().split('T')[0],
        'time_all_day': timeAllDay,
        'time_start': timeStart,
        'time_end': timeEnd,
        'notification_rules':
            notificationRules.map((r) => r.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  ReportList copyWith({
    int? id,
    int? groupId,
    String? title,
    String? description,
    String? selectorOptionValue,
    List<Determinant>? determinants,
    List<ReportField>? fields,
    bool? isActive,
    String? createdBy,
    bool? canEditSubmissions,
    ReportScheduleType? scheduleType,
    int? scheduleDayOfWeek,
    int? scheduleDayOfMonth,
    int? scheduleMonth,
    DateTime? scheduleDate,
    bool? timeAllDay,
    String? timeStart,
    String? timeEnd,
    List<NotificationRule>? notificationRules,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      ReportList(
        id: id ?? this.id,
        groupId: groupId ?? this.groupId,
        title: title ?? this.title,
        description: description ?? this.description,
        selectorOptionValue: selectorOptionValue ?? this.selectorOptionValue,
        determinants: determinants ?? this.determinants,
        fields: fields ?? this.fields,
        isActive: isActive ?? this.isActive,
        createdBy: createdBy ?? this.createdBy,
        canEditSubmissions: canEditSubmissions ?? this.canEditSubmissions,
        scheduleType: scheduleType ?? this.scheduleType,
        scheduleDayOfWeek: scheduleDayOfWeek ?? this.scheduleDayOfWeek,
        scheduleDayOfMonth: scheduleDayOfMonth ?? this.scheduleDayOfMonth,
        scheduleMonth: scheduleMonth ?? this.scheduleMonth,
        scheduleDate: scheduleDate ?? this.scheduleDate,
        timeAllDay: timeAllDay ?? this.timeAllDay,
        timeStart: timeStart ?? this.timeStart,
        timeEnd: timeEnd ?? this.timeEnd,
        notificationRules: notificationRules ?? this.notificationRules,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ReportList && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ReportList(id: $id, title: $title)';
}

// ---------------------------------------------------------------------------
// ReportListGroup — container for report lists (like QualityChecklistGroup)
// ---------------------------------------------------------------------------

class ReportListGroup {
  final int id;
  final String title;
  final String? description;
  final bool isActive;
  final String? createdBy;
  final bool canEditSubmissions;
  final List<ReportList> reportLists;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReportListGroup({
    required this.id,
    required this.title,
    this.description,
    required this.isActive,
    this.createdBy,
    this.canEditSubmissions = false,
    this.reportLists = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReportListGroup.fromJson(Map<String, dynamic> json) {
    return ReportListGroup(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdBy: json['created_by'] as String?,
      canEditSubmissions: json['can_edit_submissions'] as bool? ?? false,
      reportLists: json['report_lists'] != null
          ? (json['report_lists'] as List)
              .map((e) => ReportList.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'is_active': isActive,
        'created_by': createdBy,
        'can_edit_submissions': canEditSubmissions,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  ReportListGroup copyWith({
    int? id,
    String? title,
    String? description,
    bool? isActive,
    String? createdBy,
    bool? canEditSubmissions,
    List<ReportList>? reportLists,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      ReportListGroup(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        isActive: isActive ?? this.isActive,
        createdBy: createdBy ?? this.createdBy,
        canEditSubmissions: canEditSubmissions ?? this.canEditSubmissions,
        reportLists: reportLists ?? this.reportLists,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ReportListGroup && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ReportListGroup(id: $id, title: $title)';
}

// ---------------------------------------------------------------------------
// ReportListAssignment — links a report list to a user
// ---------------------------------------------------------------------------

class ReportListAssignment {
  final int id;
  final int reportListId;
  final String userId;
  final String assignedBy;
  final bool isActive;
  final DateTime assignedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReportListAssignment({
    required this.id,
    required this.reportListId,
    required this.userId,
    required this.assignedBy,
    required this.isActive,
    required this.assignedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReportListAssignment.fromJson(Map<String, dynamic> json) =>
      ReportListAssignment(
        id: json['id'] as int,
        reportListId: json['report_list_id'] as int,
        userId: json['user_id'] as String,
        assignedBy: json['assigned_by'] as String,
        isActive: json['is_active'] as bool? ?? true,
        assignedAt: DateTime.parse(json['assigned_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'report_list_id': reportListId,
        'user_id': userId,
        'assigned_by': assignedBy,
        'is_active': isActive,
        'assigned_at': assignedAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

// ---------------------------------------------------------------------------
// NotificationRuleType — types of automated notifications
// ---------------------------------------------------------------------------

enum NotificationRuleType {
  dailyReminder,
  exitWithoutSubmit,
  beforeDeadline,
  missedSubmission,
  afterPartialFill,
  scheduleStart;

  String get displayName {
    switch (this) {
      case NotificationRuleType.dailyReminder:
        return 'تذكير يومي';
      case NotificationRuleType.exitWithoutSubmit:
        return 'خروج بدون إرسال';
      case NotificationRuleType.beforeDeadline:
        return 'قبل الموعد النهائي';
      case NotificationRuleType.missedSubmission:
        return 'فات الموعد بدون إرسال';
      case NotificationRuleType.afterPartialFill:
        return 'ملء جزئي بدون إكمال';
      case NotificationRuleType.scheduleStart:
        return 'تذكير بداية الجدول';
    }
  }

  String get description {
    switch (this) {
      case NotificationRuleType.dailyReminder:
        return 'إشعار يومي لتذكير المستخدم بملء التقرير في وقت محدد';
      case NotificationRuleType.exitWithoutSubmit:
        return 'إشعار عند مغادرة الشاشة دون إرسال التقرير';
      case NotificationRuleType.beforeDeadline:
        return 'إشعار قبل انتهاء وقت الموعد النهائي للتقرير';
      case NotificationRuleType.missedSubmission:
        return 'إشعار عند انتهاء الموعد دون إرسال التقرير';
      case NotificationRuleType.afterPartialFill:
        return 'إشعار عند وجود مسودة غير مكتملة منذ فترة';
      case NotificationRuleType.scheduleStart:
        return 'إشعار عند حلول موعد التقرير حسب جدوله الزمني';
    }
  }

  String get value {
    switch (this) {
      case NotificationRuleType.dailyReminder:
        return 'daily_reminder';
      case NotificationRuleType.exitWithoutSubmit:
        return 'exit_without_submit';
      case NotificationRuleType.beforeDeadline:
        return 'before_deadline';
      case NotificationRuleType.missedSubmission:
        return 'missed_submission';
      case NotificationRuleType.afterPartialFill:
        return 'after_partial_fill';
      case NotificationRuleType.scheduleStart:
        return 'schedule_start';
    }
  }

  static NotificationRuleType? fromString(String? s) {
    switch (s) {
      case 'daily_reminder':
        return NotificationRuleType.dailyReminder;
      case 'exit_without_submit':
        return NotificationRuleType.exitWithoutSubmit;
      case 'before_deadline':
        return NotificationRuleType.beforeDeadline;
      case 'missed_submission':
        return NotificationRuleType.missedSubmission;
      case 'after_partial_fill':
        return NotificationRuleType.afterPartialFill;
      case 'schedule_start':
        return NotificationRuleType.scheduleStart;
      default:
        return null;
    }
  }
}

// ---------------------------------------------------------------------------
// NotificationRule — one notification configuration entry
// ---------------------------------------------------------------------------

class NotificationRule {
  final NotificationRuleType type;
  final bool enabled;
  // type-specific config: e.g. {time: '09:00'}, {minutesBefore: 30}, {hoursAfter: 2}
  final Map<String, dynamic> config;

  const NotificationRule({
    required this.type,
    this.enabled = true,
    this.config = const {},
  });

  factory NotificationRule.fromJson(Map<String, dynamic> json) =>
      NotificationRule(
        type: NotificationRuleType.fromString(json['type'] as String?) ??
            NotificationRuleType.dailyReminder,
        enabled: json['enabled'] as bool? ?? true,
        config: json['config'] is Map
            ? Map<String, dynamic>.from(json['config'] as Map)
            : {},
      );

  Map<String, dynamic> toJson() => {
        'type': type.value,
        'enabled': enabled,
        'config': config,
      };

  NotificationRule copyWith({
    NotificationRuleType? type,
    bool? enabled,
    Map<String, dynamic>? config,
  }) =>
      NotificationRule(
        type: type ?? this.type,
        enabled: enabled ?? this.enabled,
        config: config ?? this.config,
      );
}

// ---------------------------------------------------------------------------
// ReportListDraft — auto-saved in-progress session (one per user per list)
// ---------------------------------------------------------------------------

class ReportListDraft {
  final int id;
  final int reportListId;
  final String userId;
  final DateTime draftDate;
  final Map<String, dynamic> determinantValues;
  final Map<String, String> fieldResponses;
  final DateTime updatedAt;

  const ReportListDraft({
    required this.id,
    required this.reportListId,
    required this.userId,
    required this.draftDate,
    required this.determinantValues,
    required this.fieldResponses,
    required this.updatedAt,
  });

  bool get isFromToday {
    final now = DateTime.now();
    return draftDate.year == now.year &&
        draftDate.month == now.month &&
        draftDate.day == now.day;
  }

  factory ReportListDraft.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> parseMap(dynamic v) {
      if (v == null) return {};
      if (v is Map) return Map<String, dynamic>.from(v);
      if (v is String && v.isNotEmpty) {
        try {
          final d = jsonDecode(v);
          if (d is Map) return Map<String, dynamic>.from(d);
        } catch (_) {}
      }
      return {};
    }

    final rawFields = parseMap(json['field_responses']);
    final fieldResponses =
        rawFields.map((k, v) => MapEntry(k, v?.toString() ?? ''));

    return ReportListDraft(
      id: json['id'] as int,
      reportListId: json['report_list_id'] as int,
      userId: json['user_id'] as String,
      draftDate: DateTime.parse(json['draft_date'] as String),
      determinantValues: parseMap(json['determinant_values']),
      fieldResponses: fieldResponses,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'report_list_id': reportListId,
        'user_id': userId,
        'draft_date': draftDate.toIso8601String().split('T')[0],
        'determinant_values': determinantValues,
        'field_responses': fieldResponses,
        'updated_at': updatedAt.toIso8601String(),
      };
}

// ---------------------------------------------------------------------------
// ReportListResponse — a submitted response
// ---------------------------------------------------------------------------

class ReportListResponse {
  final int id;
  final int reportListId;
  final String userId;
  final DateTime responseDate;
  final Map<String, dynamic> determinantValues;
  final Map<String, String> fieldResponses; // fieldId -> text answer
  final DateTime submittedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReportListResponse({
    required this.id,
    required this.reportListId,
    required this.userId,
    required this.responseDate,
    required this.determinantValues,
    required this.fieldResponses,
    required this.submittedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReportListResponse.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> parseMap(dynamic v) {
      if (v == null) return {};
      if (v is Map) return Map<String, dynamic>.from(v);
      if (v is String && v.isNotEmpty) {
        try {
          final d = jsonDecode(v);
          if (d is Map) return Map<String, dynamic>.from(d);
        } catch (_) {}
      }
      return {};
    }

    final rawFields = parseMap(json['field_responses']);
    final fieldResponses =
        rawFields.map((k, v) => MapEntry(k, v?.toString() ?? ''));

    return ReportListResponse(
      id: json['id'] as int,
      reportListId: json['report_list_id'] as int,
      userId: json['user_id'] as String,
      responseDate: DateTime.parse(json['response_date'] as String),
      determinantValues: parseMap(json['determinant_values']),
      fieldResponses: fieldResponses,
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'report_list_id': reportListId,
        'user_id': userId,
        'response_date': responseDate.toIso8601String().split('T')[0],
        'determinant_values': determinantValues,
        'field_responses': fieldResponses,
        'submitted_at': submittedAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReportListResponse && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
