import 'package:flutter/material.dart';

enum InterfaceType {
  admin,
  user;

  String get displayName =>
      this == admin ? 'واجهة الإدارة' : 'واجهة المستخدم';

  String get description => this == admin
      ? 'الوصول إلى لوحة إدارة النظام'
      : 'الوصول إلى الخدمات والتقارير';

  IconData get icon => this == admin
      ? Icons.admin_panel_settings_outlined
      : Icons.dashboard_outlined;

  Color get color =>
      this == admin ? const Color(0xFFF16936) : const Color(0xFF1B4674);
}

class RoleFeature {
  final String featureKey;
  final Map<String, dynamic> config;

  const RoleFeature({
    required this.featureKey,
    this.config = const {},
  });

  factory RoleFeature.fromJson(Map<String, dynamic> json) {
    return RoleFeature(
      featureKey: json['feature_key'] as String,
      config: Map<String, dynamic>.from(json['config'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toInsertJson(String roleId) => {
        'role_id': roleId,
        'feature_key': featureKey,
        'config': config,
      };

  List<String> getStringList(String key) {
    final val = config[key];
    if (val == null) return [];
    if (val is List) return List<String>.from(val);
    return [];
  }

  String getString(String key, {String defaultVal = ''}) =>
      config[key] as String? ?? defaultVal;

  bool getBool(String key, {bool defaultVal = false}) =>
      config[key] as bool? ?? defaultVal;
}

class Role {
  final String id;
  final String nameAr;
  final String? description;
  final InterfaceType interfaceType;
  final bool isActive;
  final List<RoleFeature> features;

  const Role({
    required this.id,
    required this.nameAr,
    this.description,
    required this.interfaceType,
    this.isActive = true,
    this.features = const [],
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'] as String,
      nameAr: json['name_ar'] as String,
      description: json['description'] as String?,
      interfaceType: json['interface_type'] == 'admin'
          ? InterfaceType.admin
          : InterfaceType.user,
      isActive: json['is_active'] as bool? ?? true,
      features: (json['role_features'] as List<dynamic>? ?? [])
          .map((f) => RoleFeature.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toUpsertJson() => {
        'name_ar': nameAr,
        'description': description,
        'interface_type': interfaceType.name,
        'is_active': isActive,
      };

  bool hasFeature(String key) => features.any((f) => f.featureKey == key);

  RoleFeature? getFeature(String key) {
    for (final f in features) {
      if (f.featureKey == key) return f;
    }
    return null;
  }

  int get featureCount => features.length;
}
