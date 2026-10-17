/// 사용자 정보
class User {
  final int? id; // DB가 자동으로 붙여주는 번호 (저장 전에는 null)
  final String name;
  final int age;
  final double heightCm;
  final double weightKg;
  final DateTime createdAt;

  const User({
    this.id,
    required this.name,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.createdAt,
  });

  /// Dart 객체 → DB에 저장할 Map
  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'age': age,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'created_at': createdAt.toIso8601String(),
      };

  /// DB에서 읽은 Map → Dart 객체
  factory User.fromMap(Map<String, Object?> map) => User(
        id: map['id'] as int,
        name: map['name'] as String,
        age: map['age'] as int,
        heightCm: (map['height_cm'] as num).toDouble(),
        weightKg: (map['weight_kg'] as num).toDouble(),
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  User copyWith({int? id}) => User(
        id: id ?? this.id,
        name: name,
        age: age,
        heightCm: heightCm,
        weightKg: weightKg,
        createdAt: createdAt,
      );

  @override
  String toString() =>
      'User(id: $id, $name, $age세, ${heightCm}cm, ${weightKg}kg)';
}
