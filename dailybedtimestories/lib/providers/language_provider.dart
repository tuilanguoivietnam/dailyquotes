import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final languageProvider = StateNotifierProvider<LanguageNotifier, String>((ref) {
  return LanguageNotifier();
});

class LanguageNotifier extends StateNotifier<String> {
  LanguageNotifier() : super('system') {
    _loadLanguage();
  }

  static const String _boxName = 'dailystory_language';
  static const String _key = 'current_language';

  Future<void> _loadLanguage() async {
    final box = await Hive.openBox<String>(_boxName);
    final savedLanguage = box.get(_key);
    if (savedLanguage != null && ['zh', 'en', 'ja'].contains(savedLanguage)) {
      state = savedLanguage;
    } else {
      state = 'system';
    }
  }

  Future<void> setLanguage(String langCode) async {
    final box = await Hive.openBox<String>(_boxName);
    await box.put(_key, langCode);
    state = langCode;
  }

  Future<void> setSystemLanguage() async {
    final box = await Hive.openBox<String>(_boxName);
    await box.delete(_key);
    state = 'system';
  }

  // 获取当前实际生效的 Locale
  Locale getLocale(Locale deviceLocale) {
    if (state == 'system') {
      const supported = ['zh', 'en', 'ja'];
      if (supported.contains(deviceLocale.languageCode)) {
        return Locale(deviceLocale.languageCode);
      }
      return const Locale('en');
    } else {
      return Locale(state);
    }
  }
}
