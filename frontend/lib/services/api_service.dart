import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../config/api_config.dart';
import '../models/affirmation.dart';

class ApiService {
  static const int _limit = 15;

  Future<List<String>> getAffirmations(String? category, String lang) async {
    final params = <String, String>{
      'lang': lang,
      if (category != null && category.isNotEmpty) 'category': category,
      'limit': '$_limit',
    };

    final uri = Uri.parse('${ApiConfig.baseUrl}/api/affirmations')
        .replace(queryParameters: params);

    final response = await http.get(
      uri,
      headers: {'Accept': 'application/json; charset=utf-8'},
    );

    if (response.statusCode == 200) {
      return List<String>.from(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('Failed to load affirmations: ${response.statusCode}');
    }
  }

  Future<List<String>> getMoreAffirmations(int offset, String lang) async {
    final params = <String, String>{
      'lang': lang,
      'offset': offset.toString(),
      'limit': '$_limit',
    };

    final uri = Uri.parse('${ApiConfig.baseUrl}/api/affirmations')
        .replace(queryParameters: params);

    final response = await http.get(
      uri,
      headers: {'Accept': 'application/json; charset=utf-8'},
    );

    if (response.statusCode == 200) {
      return List<String>.from(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception(
          'Failed to load more affirmations: ${response.statusCode}');
    }
  }
}

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
