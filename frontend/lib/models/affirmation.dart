import 'package:hive/hive.dart';

part 'affirmation.g.dart';

@HiveType(typeId: 1)
class Affirmation {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String message;

  @HiveField(2)
  final String category;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final String? audioPath;

  Affirmation({
    required this.id,
    required this.message,
    required this.category,
    required this.createdAt,
    this.audioPath,
  });

  factory Affirmation.fromJson(Map<String, dynamic> json) {
    return Affirmation(
      id: json['id'] as String? ?? '',
      message: json['message'] as String? ?? '',
      category: json['category'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
