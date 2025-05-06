import 'package:hive/hive.dart';
import 'dart:convert';

part 'whitenoise.g.dart';

@HiveType(typeId: 4)
class WhiteNoise {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String filePath;

  @HiveField(3)
  final DateTime createdAt;

  WhiteNoise({
    required this.id,
    required this.name,
    required this.filePath,
    required this.createdAt,
  });

  factory WhiteNoise.fromJson(Map<String, dynamic> json) {
    return WhiteNoise(
      id: json['id'] as String,
      name: json['name'] as String,
      filePath: json['file_path'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'file_path': filePath,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
