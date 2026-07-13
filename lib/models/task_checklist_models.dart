// lib/models/task_checklist_models.dart

enum TaskChecklistFrequency {
  daily,
  specificDays,
  once;

  String get displayText {
    switch (this) {
      case TaskChecklistFrequency.daily:
        return 'يومياً';
      case TaskChecklistFrequency.specificDays:
        return 'أيام محددة';
      case TaskChecklistFrequency.once:
        return 'مرة واحدة';
    }
  }

  String get name {
    switch (this) {
      case TaskChecklistFrequency.daily:
        return 'daily';
      case TaskChecklistFrequency.specificDays:
        return 'specific_days';
      case TaskChecklistFrequency.once:
        return 'once';
    }
  }

  static TaskChecklistFrequency fromString(String s) {
    switch (s) {
      case 'daily':
        return TaskChecklistFrequency.daily;
      case 'specific_days':
        return TaskChecklistFrequency.specificDays;
      case 'once':
        return TaskChecklistFrequency.once;
      default:
        return TaskChecklistFrequency.daily;
    }
  }
}

enum TaskChecklistStatus {
  pending,
  inProgress,
  completed,
  missed;

  String get displayText {
    switch (this) {
      case TaskChecklistStatus.pending:
        return 'قيد الانتظار';
      case TaskChecklistStatus.inProgress:
        return 'جارٍ التنفيذ';
      case TaskChecklistStatus.completed:
        return 'مكتمل';
      case TaskChecklistStatus.missed:
        return 'فائت';
    }
  }

  String get name {
    switch (this) {
      case TaskChecklistStatus.pending:
        return 'pending';
      case TaskChecklistStatus.inProgress:
        return 'in_progress';
      case TaskChecklistStatus.completed:
        return 'completed';
      case TaskChecklistStatus.missed:
        return 'missed';
    }
  }

  static TaskChecklistStatus fromString(String s) {
    switch (s) {
      case 'pending':
        return TaskChecklistStatus.pending;
      case 'in_progress':
        return TaskChecklistStatus.inProgress;
      case 'completed':
        return TaskChecklistStatus.completed;
      case 'missed':
        return TaskChecklistStatus.missed;
      default:
        return TaskChecklistStatus.pending;
    }
  }
}

// ─── Task Item (a single task within a checklist) ────────────────────────────
class TaskItem {
  final String id;
  final String title;
  final String? description;
  final int order;

  TaskItem({
    required this.id,
    required this.title,
    this.description,
    required this.order,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        order: json['order'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'order': order,
      };

  TaskItem copyWith({String? id, String? title, String? description, int? order}) =>
      TaskItem(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        order: order ?? this.order,
      );
}

// ─── Task Checklist Definition ────────────────────────────────────────────────
class TaskChecklist {
  final int id;
  final String title;
  final String? description;
  final List<TaskItem> tasks;
  final TaskChecklistFrequency frequency;
  final List<int> scheduledDays; // 1=Mon … 7=Sun (for specificDays)
  final String? scheduledTime; // "HH:MM" – notification time
  final DateTime? onceDate; // for frequency=once
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskChecklist({
    required this.id,
    required this.title,
    this.description,
    required this.tasks,
    required this.frequency,
    this.scheduledDays = const [],
    this.scheduledTime,
    this.onceDate,
    required this.isActive,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskChecklist.fromJson(Map<String, dynamic> json) => TaskChecklist(
        id: json['id'] as int,
        title: json['title'] as String,
        description: json['description'] as String?,
        tasks: (json['tasks'] as List? ?? [])
            .map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order)),
        frequency: TaskChecklistFrequency.fromString(
            json['frequency'] as String? ?? 'daily'),
        scheduledDays: (json['scheduled_days'] as List? ?? [])
            .map((e) => e as int)
            .toList(),
        scheduledTime: json['scheduled_time'] as String?,
        onceDate: json['once_date'] != null
            ? DateTime.tryParse(json['once_date'] as String)
            : null,
        isActive: json['is_active'] as bool? ?? true,
        createdBy: json['created_by'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'frequency': frequency.name,
        'scheduled_days': scheduledDays,
        'scheduled_time': scheduledTime,
        'once_date': onceDate?.toIso8601String().split('T')[0],
        'is_active': isActive,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  String get frequencyDescription {
    switch (frequency) {
      case TaskChecklistFrequency.daily:
        return scheduledTime != null ? 'يومياً الساعة $scheduledTime' : 'يومياً';
      case TaskChecklistFrequency.specificDays:
        final dayNames = scheduledDays.map(_dayName).join('، ');
        return 'كل: $dayNames${scheduledTime != null ? ' الساعة $scheduledTime' : ''}';
      case TaskChecklistFrequency.once:
        if (onceDate != null) {
          return 'مرة واحدة بتاريخ ${onceDate!.day}/${onceDate!.month}/${onceDate!.year}';
        }
        return 'مرة واحدة';
    }
  }

  static String _dayName(int d) {
    const names = ['', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    return d >= 1 && d <= 7 ? names[d] : '';
  }
}

// ─── Task Checklist Assignment (which users) ──────────────────────────────────
class TaskChecklistAssignment {
  final int id;
  final int checklistId;
  final String userId;
  final String? assignedBy;
  final DateTime createdAt;

  TaskChecklistAssignment({
    required this.id,
    required this.checklistId,
    required this.userId,
    this.assignedBy,
    required this.createdAt,
  });

  factory TaskChecklistAssignment.fromJson(Map<String, dynamic> json) =>
      TaskChecklistAssignment(
        id: json['id'] as int,
        checklistId: json['checklist_id'] as int,
        userId: json['user_id'] as String,
        assignedBy: json['assigned_by'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

// ─── Task Checklist Response (one daily/scheduled submission) ─────────────────
class TaskChecklistResponse {
  final int id;
  final int checklistId;
  final String userId;
  final DateTime scheduledDate;
  final TaskChecklistStatus status;
  final List<TaskItemResponse> taskResponses;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Joined
  final String? checklistTitle;
  final String? username;

  TaskChecklistResponse({
    required this.id,
    required this.checklistId,
    required this.userId,
    required this.scheduledDate,
    required this.status,
    required this.taskResponses,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    this.checklistTitle,
    this.username,
  });

  factory TaskChecklistResponse.fromJson(Map<String, dynamic> json) =>
      TaskChecklistResponse(
        id: json['id'] as int,
        checklistId: json['checklist_id'] as int,
        userId: json['user_id'] as String,
        scheduledDate: DateTime.parse(json['scheduled_date'] as String),
        status: TaskChecklistStatus.fromString(
            json['status'] as String? ?? 'pending'),
        taskResponses: (json['task_responses'] as List? ?? [])
            .map((e) => TaskItemResponse.fromJson(e as Map<String, dynamic>))
            .toList(),
        startedAt: json['started_at'] != null
            ? DateTime.tryParse(json['started_at'] as String)
            : null,
        completedAt: json['completed_at'] != null
            ? DateTime.tryParse(json['completed_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        checklistTitle: json['checklist_title'] as String?,
        username: json['username'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'checklist_id': checklistId,
        'user_id': userId,
        'scheduled_date': scheduledDate.toIso8601String().split('T')[0],
        'status': status.name,
        'task_responses': taskResponses.map((r) => r.toJson()).toList(),
        'started_at': startedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  int get completedCount => taskResponses.where((r) => r.isDone).length;
  int get totalCount => taskResponses.length;
  double get progress =>
      totalCount == 0 ? 0 : completedCount / totalCount;
  bool get isFullyComplete => completedCount == totalCount && totalCount > 0;
}

// ─── Single task item response ────────────────────────────────────────────────
class TaskItemResponse {
  final String taskId;
  final bool isDone;
  final String? notes;
  final DateTime? doneAt;

  TaskItemResponse({
    required this.taskId,
    required this.isDone,
    this.notes,
    this.doneAt,
  });

  factory TaskItemResponse.fromJson(Map<String, dynamic> json) =>
      TaskItemResponse(
        taskId: json['task_id'] as String,
        isDone: json['is_done'] as bool? ?? false,
        notes: json['notes'] as String?,
        doneAt: json['done_at'] != null
            ? DateTime.tryParse(json['done_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'task_id': taskId,
        'is_done': isDone,
        'notes': notes,
        'done_at': doneAt?.toIso8601String(),
      };

  TaskItemResponse copyWith({bool? isDone, String? notes, DateTime? doneAt}) =>
      TaskItemResponse(
        taskId: taskId,
        isDone: isDone ?? this.isDone,
        notes: notes ?? this.notes,
        doneAt: doneAt ?? this.doneAt,
      );
}