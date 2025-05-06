import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

// 创建背景图片状态提供者
final backgroundImageProvider =
    StateNotifierProvider<BackgroundImageNotifier, String?>(
  (ref) => BackgroundImageNotifier(),
);

class BackgroundImageNotifier extends StateNotifier<String?> {
  BackgroundImageNotifier() : super(null) {
    _loadBackgroundImage();
  }

  // 加载保存的背景图片路径
  Future<void> _loadBackgroundImage() async {
    final imagePath = await StorageService.getBackgroundImage();
    state = imagePath;
  }

  // 设置背景图片
  Future<void> setBackgroundImage(String? imagePath) async {
    await StorageService.saveBackgroundImage(imagePath);
    state = imagePath;
  }

  // 删除背景图片
  Future<void> removeBackgroundImage() async {
    await StorageService.saveBackgroundImage(null);
    state = null;
  }
}
