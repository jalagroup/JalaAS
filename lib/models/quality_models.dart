// lib/models/quality_checklist.dart
import 'dart:convert';

class QualityChecklist {
  final int id;
  final int groupId;
  final String title;
  final String? description;
  final String? selectorOptionValue;
  final List<Determinant> determinants;
  final int rateNumber;
  final List<RatingScale> ratingScale;
  final List<CheckPoint> checkPoints;
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  QualityChecklist({
    required this.id,
    required this.groupId,
    required this.title,
    this.description,
    this.selectorOptionValue,
    required this.determinants,
    required this.rateNumber,
    required this.ratingScale,
    required this.checkPoints,
    required this.isActive,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory QualityChecklist.fromJson(Map<String, dynamic> json) {
    return QualityChecklist(
      id: json['id'] as int,
      groupId: json['group_id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      selectorOptionValue: json['selector_option_value'] as String?,
      determinants: (json['determinants'] as List?)
              ?.map((e) => Determinant.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      rateNumber: json['rate_number'] as int? ?? 5,
      ratingScale: (json['rating_scale'] as List?)
              ?.map((e) => RatingScale.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      checkPoints: (json['check_points'] as List?)
              ?.map((e) => CheckPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isActive: json['is_active'] as bool? ?? true,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'title': title,
      'description': description,
      'selector_option_value': selectorOptionValue,
      'determinants': determinants.map((e) => e.toJson()).toList(),
      'rate_number': rateNumber,
      'rating_scale': ratingScale.map((e) => e.toJson()).toList(),
      'check_points': checkPoints.map((e) => e.toJson()).toList(),
      'is_active': isActive,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String getRatingLabel(int rating) {
    for (final scale in ratingScale) {
      if (scale.minValue != null && scale.maxValue != null) {
        if (rating >= scale.minValue! && rating <= scale.maxValue!) {
          return scale.label;
        }
      } else if (scale.minValue != null && scale.maxValue == null) {
        if (rating == scale.minValue!) {
          return scale.label;
        }
      }
    }
    return rating.toString();
  }

  QualityChecklist copyWith({
    int? id,
    int? groupId,
    String? title,
    String? description,
    String? selectorOptionValue,
    List<Determinant>? determinants,
    int? rateNumber,
    List<RatingScale>? ratingScale,
    List<CheckPoint>? checkPoints,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QualityChecklist(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      title: title ?? this.title,
      description: description ?? this.description,
      selectorOptionValue: selectorOptionValue ?? this.selectorOptionValue,
      determinants: determinants ?? this.determinants,
      rateNumber: rateNumber ?? this.rateNumber,
      ratingScale: ratingScale ?? this.ratingScale,
      checkPoints: checkPoints ?? this.checkPoints,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'QualityChecklist(id: $id, title: $title, groupId: $groupId)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QualityChecklist && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// lib/models/quality_image.dart

class QualityImage {
  final int id;
  final int responseId;
  final String imageUrl;
  final String imageName;
  final int? imageSize;
  final String? mimeType;
  final DateTime uploadedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  QualityImage({
    required this.id,
    required this.responseId,
    required this.imageUrl,
    required this.imageName,
    this.imageSize,
    this.mimeType,
    required this.uploadedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory QualityImage.fromJson(Map<String, dynamic> json) {
    return QualityImage(
      id: json['id'] as int,
      responseId: json['response_id'] as int,
      imageUrl: json['image_url'] as String,
      imageName: json['image_name'] as String,
      imageSize: json['image_size'] as int?,
      mimeType: json['mime_type'] as String?,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'response_id': responseId,
      'image_url': imageUrl,
      'image_name': imageName,
      'image_size': imageSize,
      'mime_type': mimeType,
      'uploaded_at': uploadedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  QualityImage copyWith({
    int? id,
    int? responseId,
    String? imageUrl,
    String? imageName,
    int? imageSize,
    String? mimeType,
    DateTime? uploadedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QualityImage(
      id: id ?? this.id,
      responseId: responseId ?? this.responseId,
      imageUrl: imageUrl ?? this.imageUrl,
      imageName: imageName ?? this.imageName,
      imageSize: imageSize ?? this.imageSize,
      mimeType: mimeType ?? this.mimeType,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'QualityImage(id: $id, imageName: $imageName, responseId: $responseId)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QualityImage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// lib/models/determinant.dart

class Determinant {
  final String id;
  final String name;
  final List<DeterminantOption> options;

  Determinant({
    required this.id,
    required this.name,
    required this.options,
  });

  factory Determinant.fromJson(Map<String, dynamic> json) {
    return Determinant(
      id: json['id'] as String,
      name: json['name'] as String,
      options: (json['options'] as List?)
              ?.map(
                  (e) => DeterminantOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'options': options.map((e) => e.toJson()).toList(),
    };
  }

  Determinant copyWith({
    String? id,
    String? name,
    List<DeterminantOption>? options,
  }) {
    return Determinant(
      id: id ?? this.id,
      name: name ?? this.name,
      options: options ?? this.options,
    );
  }

  @override
  String toString() =>
      'Determinant(id: $id, name: $name, optionsCount: ${options.length})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Determinant && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
// lib/models/determinant_option.dart

class DeterminantOption {
  final String id;
  final String value;

  DeterminantOption({
    required this.id,
    required this.value,
  });

  factory DeterminantOption.fromJson(Map<String, dynamic> json) {
    return DeterminantOption(
      id: json['id'] as String,
      value: json['value'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'value': value,
    };
  }

  DeterminantOption copyWith({
    String? id,
    String? value,
  }) {
    return DeterminantOption(
      id: id ?? this.id,
      value: value ?? this.value,
    );
  }

  @override
  String toString() => 'DeterminantOption(id: $id, value: $value)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeterminantOption && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// lib/models/check_point.dart

class CheckPoint {
  final String id;
  final String title;

  CheckPoint({
    required this.id,
    required this.title,
  });

  factory CheckPoint.fromJson(Map<String, dynamic> json) {
    return CheckPoint(
      id: json['id'] as String,
      title: json['title'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
    };
  }

  CheckPoint copyWith({
    String? id,
    String? title,
  }) {
    return CheckPoint(
      id: id ?? this.id,
      title: title ?? this.title,
    );
  }

  @override
  String toString() => 'CheckPoint(id: $id, title: $title)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CheckPoint && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// lib/models/quality_session.dart

class QualitySession {
  final int id;
  final int groupId;
  final int? checklistId;
  final String userId;
  final Map<String, dynamic> sessionData;
  final bool isActive;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  QualitySession({
    required this.id,
    required this.groupId,
    this.checklistId,
    required this.userId,
    required this.sessionData,
    required this.isActive,
    required this.startedAt,
    this.endedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory QualitySession.fromJson(Map<String, dynamic> json) {
    return QualitySession(
      id: json['id'] as int,
      groupId: json['group_id'] as int,
      checklistId: json['checklist_id'] as int?,
      userId: json['user_id'] as String,
      sessionData: Map<String, dynamic>.from(
        json['session_data'] as Map<String, dynamic>? ?? {},
      ),
      isActive: json['is_active'] as bool? ?? true,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'checklist_id': checklistId,
      'user_id': userId,
      'session_data': sessionData,
      'is_active': isActive,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  QualitySession copyWith({
    int? id,
    int? groupId,
    int? checklistId,
    String? userId,
    Map<String, dynamic>? sessionData,
    bool? isActive,
    DateTime? startedAt,
    DateTime? endedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QualitySession(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      checklistId: checklistId ?? this.checklistId,
      userId: userId ?? this.userId,
      sessionData: sessionData ?? this.sessionData,
      isActive: isActive ?? this.isActive,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'QualitySession(id: $id, groupId: $groupId, userId: $userId, isActive: $isActive)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QualitySession && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// lib/models/quality_response.dart

Map<String, dynamic> _parseJsonField(dynamic value) {
  if (value == null) return {};
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return {};
}

class QualityResponse {
  final int id;
  final int groupId;
  final int checklistId;
  final String userId;
  final int? sessionId;
  final DateTime responseDate;
  final Map<String, dynamic> determinantValues;
  final Map<String, dynamic> checkPointRatings;
  final DateTime submittedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? mainNotes;
  final List<QualityImage> images; // Legacy general images
  final List<QualityCheckpointImage>
      checkpointImages; // New checkpoint-specific images

  QualityResponse({
    required this.id,
    required this.groupId,
    required this.checklistId,
    required this.userId,
    this.sessionId,
    required this.responseDate,
    required this.determinantValues,
    required this.checkPointRatings,
    required this.submittedAt,
    required this.createdAt,
    required this.updatedAt,
    this.mainNotes ,
    this.images = const [],
    this.checkpointImages = const [],
  });

  factory QualityResponse.fromJson(Map<String, dynamic> json) {
    return QualityResponse(
      id: json['id'] as int,
      groupId: json['group_id'] as int,
      checklistId: json['checklist_id'] as int,
      userId: json['user_id'] as String,
      sessionId: json['session_id'] as int?,
      responseDate: DateTime.parse(json['response_date'] as String),
      determinantValues: _parseJsonField(json['determinant_values']),
      checkPointRatings: _parseJsonField(json['check_point_ratings']),
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now()),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      mainNotes: json['main_notes'] as String?,
      images: json['images'] != null
          ? (json['images'] as List)
              .map((e) => QualityImage.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      checkpointImages: json['checkpoint_images'] != null
          ? (json['checkpoint_images'] as List)
              .map((e) =>
                  QualityCheckpointImage.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

Map<String, dynamic> toJson() {
  return {
    'id': id,
    'group_id': groupId,
    'checklist_id': checklistId,
    'user_id': userId,
    'session_id': sessionId,
    'response_date': responseDate.toIso8601String().split('T')[0],
    'determinant_values': determinantValues,
    'check_point_ratings': checkPointRatings,
    'submitted_at': submittedAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    if (mainNotes != null && mainNotes!.isNotEmpty) 'main_notes': mainNotes,
  };
}
  // Helper method to get images for a specific checkpoint
  List<QualityCheckpointImage> getImagesForCheckpoint(String checkPointId) {
    return checkpointImages
        .where((img) => img.checkPointId == checkPointId)
        .toList();
  }

  QualityResponse copyWith({
    int? id,
    int? groupId,
    int? checklistId,
    String? userId,
    int? sessionId,
    DateTime? responseDate,
    Map<String, dynamic>? determinantValues,
    Map<String, dynamic>? checkPointRatings,
    DateTime? submittedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<QualityImage>? images,
    List<QualityCheckpointImage>? checkpointImages,
  }) {
    return QualityResponse(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      checklistId: checklistId ?? this.checklistId,
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      responseDate: responseDate ?? this.responseDate,
      determinantValues: determinantValues ?? this.determinantValues,
      checkPointRatings: checkPointRatings ?? this.checkPointRatings,
      submittedAt: submittedAt ?? this.submittedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      images: images ?? this.images,
      checkpointImages: checkpointImages ?? this.checkpointImages,
    );
  }

  @override
  String toString() =>
      'QualityResponse(id: $id, checklistId: $checklistId, userId: $userId)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QualityResponse && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class QualityChecklistGroup {
  final int id;
  final String title;
  final String? description;
  final bool isMultipleActive;
  final Determinant? selectorDeterminant;
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<QualityChecklist> checklists;
  final bool canEditSubmissions;

  QualityChecklistGroup({
    required this.id,
    required this.title,
    this.description,
    required this.isMultipleActive,
    this.selectorDeterminant,
    required this.isActive,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.checklists = const [],
    this.canEditSubmissions = false,
  });

  factory QualityChecklistGroup.fromJson(Map<String, dynamic> json) {
    return QualityChecklistGroup(
      id: (json['id'] is int)
        ? json['id'] as int
        : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title'] as String,
      description: json['description'] as String?,
      isMultipleActive: json['is_multiple_active'] as bool? ?? false,
      selectorDeterminant: json['selector_determinant'] != null
          ? Determinant.fromJson(
              json['selector_determinant'] as Map<String, dynamic>)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      checklists: json['checklists'] != null
          ? (json['checklists'] as List)
              .map((e) => QualityChecklist.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      canEditSubmissions: json['can_edit_submissions'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'is_multiple_active': isMultipleActive,
      'selector_determinant': selectorDeterminant?.toJson(),
      'is_active': isActive,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'can_edit_submissions': canEditSubmissions,
    };
  }

  QualityChecklistGroup copyWith({
    int? id,
    String? title,
    String? description,
    bool? isMultipleActive,
    Determinant? selectorDeterminant,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<QualityChecklist>? checklists,
    bool? canEditSubmissions,
  }) {
    return QualityChecklistGroup(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isMultipleActive: isMultipleActive ?? this.isMultipleActive,
      selectorDeterminant: selectorDeterminant ?? this.selectorDeterminant,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      checklists: checklists ?? this.checklists,
      canEditSubmissions: canEditSubmissions ?? this.canEditSubmissions,
    );
  }
}

class RatingScale {
  final int? minValue;
  final int? maxValue;
  final String label;

  RatingScale({
    this.minValue,
    this.maxValue,
    required this.label,
  });

  factory RatingScale.fromJson(Map<String, dynamic> json) {
    return RatingScale(
      minValue: json['min_value'] as int?,
      maxValue: json['max_value'] as int?,
      label: json['label'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'min_value': minValue,
      'max_value': maxValue,
      'label': label,
    };
  }

  RatingScale copyWith({
    int? minValue,
    int? maxValue,
    String? label,
  }) {
    return RatingScale(
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      label: label ?? this.label,
    );
  }

  @override
  String toString() =>
      'RatingScale(minValue: $minValue, maxValue: $maxValue, label: $label)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RatingScale &&
        other.minValue == minValue &&
        other.maxValue == maxValue &&
        other.label == label;
  }

  @override
  int get hashCode => minValue.hashCode ^ maxValue.hashCode ^ label.hashCode;
}

// lib/models/check_point_rating.dart

class CheckPointRating {
  final String checkPointId;
  final int rating;
  final String? notes;
  final String? correctiveAction;

  CheckPointRating({
    required this.checkPointId,
    required this.rating,
    this.notes,
    this.correctiveAction,
  });

  factory CheckPointRating.fromJson(Map<String, dynamic> json) {
    return CheckPointRating(
      checkPointId: json['check_point_id'] as String,
      rating: json['rating'] as int,
      notes: json['notes'] as String?,
      correctiveAction: json['corrective_action'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'check_point_id': checkPointId,
      'rating': rating,
      'notes': notes,
      'corrective_action': correctiveAction,
    };
  }

  CheckPointRating copyWith({
    String? checkPointId,
    int? rating,
    String? notes,
    String? correctiveAction,
  }) {
    return CheckPointRating(
      checkPointId: checkPointId ?? this.checkPointId,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      correctiveAction: correctiveAction ?? this.correctiveAction,
    );
  }

  @override
  String toString() =>
      'CheckPointRating(checkPointId: $checkPointId, rating: $rating)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CheckPointRating &&
        other.checkPointId == checkPointId &&
        other.rating == rating;
  }

  @override
  int get hashCode => checkPointId.hashCode ^ rating.hashCode;
}

class QualityCheckpointImage {
  final int id;
  final int responseId;
  final String checkPointId;
  final String imageUrl;
  final String imageName;
  final int? imageSize;
  final String? mimeType;
  final DateTime uploadedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  QualityCheckpointImage({
    required this.id,
    required this.responseId,
    required this.checkPointId,
    required this.imageUrl,
    required this.imageName,
    this.imageSize,
    this.mimeType,
    required this.uploadedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory QualityCheckpointImage.fromJson(Map<String, dynamic> json) {
    return QualityCheckpointImage(
      id: json['id'] as int,
      responseId: json['response_id'] as int,
      checkPointId: json['check_point_id'] as String,
      imageUrl: json['image_url'] as String,
      imageName: json['image_name'] as String,
      imageSize: json['image_size'] as int?,
      mimeType: json['mime_type'] as String?,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'response_id': responseId,
      'check_point_id': checkPointId,
      'image_url': imageUrl,
      'image_name': imageName,
      'image_size': imageSize,
      'mime_type': mimeType,
      'uploaded_at': uploadedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  QualityCheckpointImage copyWith({
    int? id,
    int? responseId,
    String? checkPointId,
    String? imageUrl,
    String? imageName,
    int? imageSize,
    String? mimeType,
    DateTime? uploadedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QualityCheckpointImage(
      id: id ?? this.id,
      responseId: responseId ?? this.responseId,
      checkPointId: checkPointId ?? this.checkPointId,
      imageUrl: imageUrl ?? this.imageUrl,
      imageName: imageName ?? this.imageName,
      imageSize: imageSize ?? this.imageSize,
      mimeType: mimeType ?? this.mimeType,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'QualityCheckpointImage(id: $id, checkPointId: $checkPointId, imageName: $imageName)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QualityCheckpointImage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class ArabicDate {
  static const List<String> months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر'
  ];

  static String format(DateTime date) {
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static String formatShort(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// lib/models/quality_issue_models.dart

enum IssueStatus {
  open,
  inProgress,
  resolved;

  String get displayText {
    switch (this) {
      case IssueStatus.open:
        return 'مفتوحة';
      case IssueStatus.inProgress:
        return 'قيد المعالجة';
      case IssueStatus.resolved:
        return 'محلولة';
    }
  }

  String get name {
    switch (this) {
      case IssueStatus.open:
        return 'open';
      case IssueStatus.inProgress:
        return 'in_progress';
      case IssueStatus.resolved:
        return 'resolved';
    }
  }

  static IssueStatus fromString(String status) {
    switch (status) {
      case 'open':
        return IssueStatus.open;
      case 'in_progress':
        return IssueStatus.inProgress;
      case 'resolved':
        return IssueStatus.resolved;
      default:
        return IssueStatus.open;
    }
  }
}

class QualityCheckpointIssue {
  final int id;
  final int responseId;
  final String checkPointId;
  final String checkPointTitle;
  final String formTitle;
  final String assignedTo;
  final String assignedBy;
  final String description;
  final IssueStatus status;
  final DateTime responseDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final String? resolutionNotes;
  final List<QualityIssueImage> issueImages;
  final List<QualityIssueResolutionImage> resolutionImages;

  QualityCheckpointIssue({
    required this.id,
    required this.responseId,
    required this.checkPointId,
    required this.checkPointTitle,
    required this.formTitle,
    required this.assignedTo,
    required this.assignedBy,
    required this.description,
    required this.status,
    required this.responseDate,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.resolutionNotes,
    this.issueImages = const [],
    this.resolutionImages = const [],
  });

  factory QualityCheckpointIssue.fromJson(Map<String, dynamic> json) {
    return QualityCheckpointIssue(
      id: json['id'] as int,
      responseId: json['response_id'] as int,
      checkPointId: json['check_point_id'] as String,
      checkPointTitle: json['check_point_title'] as String,
      formTitle: json['form_title'] as String,
      assignedTo: json['assigned_to'] as String,
      assignedBy: json['assigned_by'] as String,
      description: json['description'] as String,
      status: IssueStatus.fromString(json['status'] as String),
      responseDate: DateTime.parse(json['response_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      resolutionNotes: json['resolution_notes'] as String?,
      issueImages: json['issue_images'] != null
          ? (json['issue_images'] as List)
              .map((e) => QualityIssueImage.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      resolutionImages: json['resolution_images'] != null
          ? (json['resolution_images'] as List)
              .map((e) => QualityIssueResolutionImage.fromJson(
                  e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'response_id': responseId,
      'check_point_id': checkPointId,
      'check_point_title': checkPointTitle,
      'form_title': formTitle,
      'assigned_to': assignedTo,
      'assigned_by': assignedBy,
      'description': description,
      'status': status.name,
      'response_date': responseDate.toIso8601String().split('T')[0],
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'resolution_notes': resolutionNotes,
    };
  }

  QualityCheckpointIssue copyWith({
    int? id,
    int? responseId,
    String? checkPointId,
    String? checkPointTitle,
    String? formTitle,
    String? assignedTo,
    String? assignedBy,
    String? description,
    IssueStatus? status,
    DateTime? responseDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
    String? resolutionNotes,
    List<QualityIssueImage>? issueImages,
    List<QualityIssueResolutionImage>? resolutionImages,
  }) {
    return QualityCheckpointIssue(
      id: id ?? this.id,
      responseId: responseId ?? this.responseId,
      checkPointId: checkPointId ?? this.checkPointId,
      checkPointTitle: checkPointTitle ?? this.checkPointTitle,
      formTitle: formTitle ?? this.formTitle,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedBy: assignedBy ?? this.assignedBy,
      description: description ?? this.description,
      status: status ?? this.status,
      responseDate: responseDate ?? this.responseDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      issueImages: issueImages ?? this.issueImages,
      resolutionImages: resolutionImages ?? this.resolutionImages,
    );
  }
}

class QualityIssueImage {
  final int id;
  final int issueId;
  final String imageUrl;
  final String imageName;
  final int? imageSize;
  final String? mimeType;
  final DateTime uploadedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  QualityIssueImage({
    required this.id,
    required this.issueId,
    required this.imageUrl,
    required this.imageName,
    this.imageSize,
    this.mimeType,
    required this.uploadedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory QualityIssueImage.fromJson(Map<String, dynamic> json) {
    return QualityIssueImage(
      id: json['id'] as int,
      issueId: json['issue_id'] as int,
      imageUrl: json['image_url'] as String,
      imageName: json['image_name'] as String,
      imageSize: json['image_size'] as int?,
      mimeType: json['mime_type'] as String?,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'issue_id': issueId,
      'image_url': imageUrl,
      'image_name': imageName,
      'image_size': imageSize,
      'mime_type': mimeType,
      'uploaded_at': uploadedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class QualityIssueResolutionImage {
  final int id;
  final int issueId;
  final String imageUrl;
  final String imageName;
  final int? imageSize;
  final String? mimeType;
  final DateTime uploadedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  QualityIssueResolutionImage({
    required this.id,
    required this.issueId,
    required this.imageUrl,
    required this.imageName,
    this.imageSize,
    this.mimeType,
    required this.uploadedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory QualityIssueResolutionImage.fromJson(Map<String, dynamic> json) {
    return QualityIssueResolutionImage(
      id: json['id'] as int,
      issueId: json['issue_id'] as int,
      imageUrl: json['image_url'] as String,
      imageName: json['image_name'] as String,
      imageSize: json['image_size'] as int?,
      mimeType: json['mime_type'] as String?,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'issue_id': issueId,
      'image_url': imageUrl,
      'image_name': imageName,
      'image_size': imageSize,
      'mime_type': mimeType,
      'uploaded_at': uploadedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
