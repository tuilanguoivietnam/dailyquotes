import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, List<String>>((ref) {
  return FavoritesNotifier();
});

class FavoritesNotifier extends StateNotifier<List<String>> {
  FavoritesNotifier() : super([]) {
    _loadFavorites();
  }

  static const String _boxName = 'dailylovequotes_favorites';
  Box<String>? _box;

  Future<void> _loadFavorites() async {
    if (_box == null) {
      _box = await Hive.openBox<String>(_boxName);
    }
    state = _box!.values.whereType<String>().toList().reversed.toList();
  }

  Future<void> toggleFavorite(String affirmation) async {
    if (_box == null) {
      _box = await Hive.openBox<String>(_boxName);
    }
    if (state.contains(affirmation)) {
      // 取消收藏
      final idx = state.indexOf(affirmation);
      if (idx >= 0 && idx < _box!.length) {
        final key = _box!.keyAt(_box!.values.toList().indexOf(affirmation));
        await _box!.delete(key);
      }
      state = state.where((msg) => msg != affirmation).toList();
    } else {
      // 添加收藏，最新的在顶部
      await _box!.add(affirmation);
      state = [affirmation, ...state];
    }
  }

  bool isFavorite(String message) {
    return state.contains(message);
  }

  Future<void> removeFavorite(String message) async {
    if (_box == null) {
      _box = await Hive.openBox<String>(_boxName);
    }
    final idx = state.indexOf(message);
    if (idx >= 0 && idx < _box!.length) {
      final key = _box!.keyAt(idx);
      await _box!.delete(key);
      state = state.where((msg) => msg != message).toList();
    }
  }

  @override
  void dispose() {
    _box?.close();
    super.dispose();
  }
}
