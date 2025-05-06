import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/affirmation.dart';
import '../models/whitenoise.dart';
import '../services/subscription_service.dart';

class StorageService {
  static const String _affirmationBoxName = 'affirmations';
  static const String _whitenoiseBoxName = 'whitenoises';
  static const String _settingsBoxName = 'settings';
  static const String _audioDirName = 'audio';
  static const String _selectedCategoryKey = 'selected_category';
  static const String _backgroundImageKey = 'background_image';
  
  // 评分服务相关键
  static const String keyAppOpenCount = 'app_open_count';
  static const String keyLastPromptDate = 'rating_last_prompt_date';
  static const String keyRated = 'app_rated';
  static const String keyNeverAsk = 'rating_never_ask';

  // 首次请求网络
  static const String keyFirstRequest = 'first_request';

  static Future<void> init() async {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);

    await Hive.openBox<Affirmation>(_affirmationBoxName);
    await Hive.openBox<WhiteNoise>(_whitenoiseBoxName);
    await Hive.openBox(_settingsBoxName);

    final audioDir = Directory('${appDocumentDir.path}/$_audioDirName');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
  }

  static Future<void> saveBackgroundImage(String? imagePath) async {
    final box = await Hive.openBox(_settingsBoxName);
    await box.put(_backgroundImageKey, imagePath);
  }

  static Future<String?> getBackgroundImage() async {
    final box = await Hive.openBox(_settingsBoxName);
    return box.get(_backgroundImageKey) as String?;
  }

  static Future<void> saveAffirmation(Affirmation affirmation,
      {String? audioPath}) async {
    final box = await Hive.openBox<Affirmation>(_affirmationBoxName);
    if (audioPath != null) {
      affirmation = Affirmation(
        id: affirmation.id,
        category: affirmation.category,
        message: affirmation.message,
        createdAt: affirmation.createdAt,
        audioPath: audioPath,
      );
    }
    await box.put(affirmation.category, affirmation);
  }

  static Future<Affirmation?> getAffirmation(String category) async {
    final box = await Hive.openBox<Affirmation>(_affirmationBoxName);
    return box.get(category);
  }

  static Future<void> saveAffirmations(List<Affirmation> affirmations) async {
    final box = await Hive.openBox<Affirmation>(_affirmationBoxName);
    for (var affirmation in affirmations) {
      await box.put(affirmation.id, affirmation);
    }
  }

  static Future<List<Affirmation>> getAffirmations() async {
    final box = await Hive.openBox<Affirmation>(_affirmationBoxName);
    return box.values.toList();
  }

  static Future<Affirmation?> getRandomAffirmation() async {
    final affirmations = await getAffirmations();
    if (affirmations.isEmpty) return null;
    affirmations.shuffle();
    return affirmations.first;
  }

  static Future<void> clearAffirmations() async {
    final box = await Hive.openBox<Affirmation>(_affirmationBoxName);
    await box.clear();
  }

  static Future<void> saveNotificationSettings({
    required bool enabled,
    required String time,
  }) async {
    final box = await Hive.openBox(_settingsBoxName);
    await box.put('notification_enabled', enabled);
    await box.put('notification_time', time);
  }

  static Future<Map<String, dynamic>> getNotificationSettings() async {
    final box = await Hive.openBox(_settingsBoxName);
    return {
      'enabled': box.get('notification_enabled', defaultValue: false),
      'time': box.get('notification_time', defaultValue: '08:00'),
    };
  }

  static Future<void> saveWhiteNoises(List<WhiteNoise> whitenoises) async {
    final box = await Hive.openBox<WhiteNoise>(_whitenoiseBoxName);
    await box.clear();
    for (var whitenoise in whitenoises) {
      await box.put(whitenoise.id, whitenoise);
    }
  }

  static Future<void> saveSelectedCategory(String? category) async {
    final box = await Hive.openBox('settings');
    await box.put(_selectedCategoryKey, category);
  }

  static Future<String?> getSelectedCategory() async {
    final box = await Hive.openBox('settings');
    return box.get(_selectedCategoryKey) as String?;
  }

  static Future<String?> getAppleSubscriptionId() async {
    final box = await Hive.openBox('settings');
    return box.get('apple_subscription_id');
  }

  static Future<void> saveAppleSubscriptionId(String subscriptionId) async {
    final box = await Hive.openBox('settings');
    await box.put('apple_subscription_id', subscriptionId);
  }

  static Future<void> saveAppleSubscription(
    String subscriptionId,
    String productId,
    DateTime expiresDate,
  ) async {
    await SubscriptionService.saveSubscription(
      subscriptionId,
      productId,
      expiresDate,
    );
  }

  static Future<void> saveThemeMode(ThemeMode themeMode) async {
    final box = await Hive.openBox(_settingsBoxName);
    String themeModeString;

    switch (themeMode) {
      case ThemeMode.light:
        themeModeString = 'light';
        break;
      case ThemeMode.dark:
        themeModeString = 'dark';
        break;
      case ThemeMode.system:
      default:
        themeModeString = 'system';
        break;
    }

    await box.put('theme_mode', themeModeString);
  }

  static Future<ThemeMode?> getThemeMode() async {
    final box = await Hive.openBox(_settingsBoxName);
    final themeModeString = box.get('theme_mode') as String?;

    if (themeModeString == null) return null;

    switch (themeModeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  // 通用方法：保存任意设置值
  static Future<void> saveSetting(String key, dynamic value) async {
    final box = await Hive.openBox(_settingsBoxName);
    await box.put(key, value);
  }

  // 通用方法：获取任意设置值
  static Future<T?> getSetting<T>(String key, {T? defaultValue}) async {
    final box = await Hive.openBox(_settingsBoxName);
    return box.get(key, defaultValue: defaultValue) as T?;
  }
}
