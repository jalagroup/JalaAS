// lib/models/salesman.dart
class Salesman {
  final String code;
  final String name;

  Salesman({
    required this.code,
    required this.name,
  });

  factory Salesman.fromJson(Map<String, dynamic> json) {
    return Salesman(
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Salesman &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => '$name ($code)';
}
