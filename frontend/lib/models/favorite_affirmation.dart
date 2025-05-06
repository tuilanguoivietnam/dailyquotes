import 'package:hive/hive.dart';

part 'favorite_affirmation.g.dart';

@HiveType(typeId: 2)
class FavoriteAffirmation extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String message;

  @HiveField(2)
  final String category;

  @HiveField(3)
  final DateTime createdAt;

  FavoriteAffirmation({
    required this.id,
    required this.message,
    required this.category,
    required this.createdAt,
  });

  factory FavoriteAffirmation.fromAffirmation(dynamic affirmation) {
    return FavoriteAffirmation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: affirmation.message,
      category: affirmation.category,
      createdAt: DateTime.now(),
    );
  }
}
