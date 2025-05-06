import '../services/storage_service.dart';

class RatingService {
  // 应该显示评分弹窗的最小打开次数
  static const int _minLaunchesForRating = 3;
  // 两次评分提示的最小间隔天数
  static const int _minDaysBetweenPrompts = 7;
  
  // 增加应用打开计数
  static Future<void> incrementAppOpenCount() async {
    final currentCount = await StorageService.getSetting<int>(StorageService.keyAppOpenCount, defaultValue: 0);
    await StorageService.saveSetting(StorageService.keyAppOpenCount, currentCount! + 1);
  }
  
  // 检查是否应该显示评分提示
  static Future<bool> shouldShowRatingPrompt() async {
    // 如果用户已评分或选择永不提示，则不再显示
    final isRated = await StorageService.getSetting<bool>(StorageService.keyRated, defaultValue: false);
    final isNeverAsk = await StorageService.getSetting<bool>(StorageService.keyNeverAsk, defaultValue: false);
    
    if (isRated == true || isNeverAsk == true) {
      return false;
    }
    
    // 检查应用打开次数是否达到阈值
    final appOpenCount = await StorageService.getSetting<int>(StorageService.keyAppOpenCount, defaultValue: 0);
    if (appOpenCount! < _minLaunchesForRating) {
      return false;
    }
    
    // 检查与上次提示的时间间隔
    final lastPromptDateStr = await StorageService.getSetting<String>(StorageService.keyLastPromptDate);
    if (lastPromptDateStr != null) {
      final lastPromptDate = DateTime.parse(lastPromptDateStr);
      final daysSinceLastPrompt = DateTime.now().difference(lastPromptDate).inDays;
      
      if (daysSinceLastPrompt < _minDaysBetweenPrompts) {
        return false;
      }
    }
    
    return true;
  }
  
  // 记录显示了评分提示
  static Future<void> recordRatingPromptShown() async {
    await StorageService.saveSetting(StorageService.keyLastPromptDate, DateTime.now().toIso8601String());
  }
  
  // 记录用户已评分
  static Future<void> recordUserRated() async {
    await StorageService.saveSetting(StorageService.keyRated, true);
  }
  
  // 记录用户选择永不提示
  static Future<void> recordNeverAskAgain() async {
    await StorageService.saveSetting(StorageService.keyNeverAsk, true);
  }
} 