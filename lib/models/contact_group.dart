// lib/models/contact_group.dart
import 'package:jala_as/models/account_statement.dart';
import 'package:jala_as/models/contact.dart';

class ContactGroup {
  final int? id;
  final String name;
  final String userId;
  final List<String> contactCodes;
  final DateTime createdAt;
  final DateTime updatedAt;

  ContactGroup({
    this.id,
    required this.name,
    required this.userId,
    required this.contactCodes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory ContactGroup.fromJson(Map<String, dynamic> json) {
    return ContactGroup(
      id: json['id'] as int?,
      name: json['name'] as String,
      userId: json['user_id'] as String,
      contactCodes: (json['contact_codes'] as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'user_id': userId,
      'contact_codes': contactCodes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ContactGroup copyWith({
    int? id,
    String? name,
    String? userId,
    List<String>? contactCodes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContactGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      contactCodes: contactCodes ?? this.contactCodes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ContactStatementResult {
  final Contact contact;
  final List<AccountStatement> statements;
  final bool success;
  final String? errorMessage;

  ContactStatementResult({
    required this.contact,
    required this.statements,
    required this.success,
    this.errorMessage,
  });
}

class GroupAccountStatementResult {
  final String groupName;
  final List<ContactStatementResult> results;
  final String fromDate;
  final String toDate;
  final int successCount;
  final int failureCount;

  GroupAccountStatementResult({
    required this.groupName,
    required this.results,
    required this.fromDate,
    required this.toDate,
  })  : successCount = results.where((r) => r.success).length,
        failureCount = results.where((r) => !r.success).length;

  bool get hasFailures => failureCount > 0;
  bool get allSuccess => failureCount == 0;
  int get totalContacts => results.length;
}
