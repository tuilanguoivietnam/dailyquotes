import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final guideProvider = StateNotifierProvider<GuideNotifier, bool>((ref) {
  return GuideNotifier();
});

class GuideNotifier extends StateNotifier<bool> {
  GuideNotifier() : super(false) {
    _initState();
  }

  static const String _boxName = 'dailylovequotes_guide';
  static const String _key = 'hasShown';

  Future<void> _initState() async {
    try {
      final box = await Hive.openBox<bool>(_boxName);
      final value = box.get(_key);
      state = value ?? false;
    } catch (e) {
      // 如果发生错误，默认为true（已显示过引导）避免无限显示
      state = true;
      print('初始化引导状态失败: $e');
    }
  }

  Future<void> markAsShown() async {
    _saveState(true);
    state = true;
  }

  // 立即更新状态并异步保存，确保UI立即响应
  void manuallyCloseGuide() {
    // 立即更新状态
    state = true;
    // 异步保存到存储
    _saveState(true);
  }

  // 统一保存方法
  Future<void> _saveState(bool value) async {
    try {
      final box = await Hive.openBox<bool>(_boxName);
      await box.put(_key, value);
    } catch (e) {
      print('保存到Hive失败: $e');
    }
  }

  Future<void> reset() async {
    _saveState(false);
    state = false;
  }
}
