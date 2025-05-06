import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import '../models/category.dart';

class CategoryNotifier extends StateNotifier<AsyncValue<List<Category>>> {
  CategoryNotifier() : super(const AsyncValue.loading());

  Future<void> loadCategories(String lang) async {
    try {
      state = const AsyncValue.loading();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/categories?lang=$lang&module_name=常识'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final categories = data.map((json) => Category.fromJson(json)).toList();
        state = AsyncValue.data(categories);
      } else {
        throw Exception('Failed to load categories');
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

final categoryProvider =
    StateNotifierProvider<CategoryNotifier, AsyncValue<List<Category>>>(
  (ref) => CategoryNotifier(),
);
