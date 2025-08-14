// lib/models/area.dart
class Area {
  final String code;
  final String name;

  Area({
    required this.code,
    required this.name,
  });

  factory Area.fromJson(Map<String, dynamic> json) {
    return Area(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
    };
  }

  @override
  String toString() => '$name ($code)';
}
