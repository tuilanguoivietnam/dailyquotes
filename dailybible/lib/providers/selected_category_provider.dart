import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

final selectedCategoryProvider =
    StateNotifierProvider<SelectedCategoryNotifier, String?>((ref) {
  return SelectedCategoryNotifier();
});

class SelectedCategoryNotifier extends StateNotifier<String?> {
  SelectedCategoryNotifier() : super(null) {
    _loadSavedCategory();
  }

  Future<void> _loadSavedCategory() async {
    final savedCategory = await StorageService.getSelectedCategory();
    state = savedCategory;
  }

  Future<void> setCategory(String? category) async {
    state = category;
    await StorageService.saveSelectedCategory(category);
  }
}
