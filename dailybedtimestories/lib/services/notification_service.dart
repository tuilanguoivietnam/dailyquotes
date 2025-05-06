import 'dart:math';
import 'dart:io' show Platform;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/affirmation.dart';
import './storage_service.dart';
import 'package:dailystory/providers/selected_category_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // 用于存储通知中的金句内容
  String? _notificationAffirmation;

  // 通知回调函数
  Function(String)? _onForegroundNotificationReceived;

  // 获取通知中的金句内容
  String? get notificationAffirmation => _notificationAffirmation;

  bool get isInitialized => _isInitialized;

  // 清除通知金句
  void clearNotificationAffirmation() {
    _notificationAffirmation = null;
  }

  // 设置前台通知回调
  void setForegroundNotificationCallback(Function(String)? callback) {
    _onForegroundNotificationReceived = callback;
  }

  // 通知点击处理函数
  @pragma('vm:entry-point')
  void _handleNotificationResponse(NotificationResponse response) {
    // 保存通知中的金句内容（payload）
    if (response.payload != null && response.payload!.isNotEmpty) {
      print("通知点击: 收到金句 payload: ${response.payload}");
      _notificationAffirmation = response.payload;

      // 如果应用在前台，调用回调函数
      if (_onForegroundNotificationReceived != null) {
        print("应用在前台，调用前台通知回调");
        _onForegroundNotificationReceived!(response.payload!);
      }
    }
  }

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      print('Failed to get local timezone: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // 根据平台设置不同的初始化参数
    if (Platform.isMacOS) {
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        requestCriticalPermission: true, // 请求关键通知权限
      );

      await _notifications.initialize(
        const InitializationSettings(
          macOS: initializationSettingsDarwin,
        ),
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );
    } else {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        requestCriticalPermission: true, // 请求关键通知权限
        notificationCategories: <DarwinNotificationCategory>[], // 可以添加通知类别
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );
    }
    _isInitialized = true;
  }

  Future<void> getNotificationAppLaunchDetails() async {
    final NotificationAppLaunchDetails? launchDetails =
        await _notifications.getNotificationAppLaunchDetails();
    if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
      print("应用从通知启动");
      if (launchDetails.notificationResponse?.payload != null) {
        print("启动通知包含payload: ${launchDetails.notificationResponse?.payload}");
        _notificationAffirmation = launchDetails.notificationResponse?.payload;
      }
    }
  }

  // 清除应用角标

  Future<bool> requestPermission() async {
    if (Platform.isMacOS) {
      final bool? result = await _notifications
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    } else if (Platform.isIOS) {
      final bool? result = await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    } else if (Platform.isAndroid) {
      final bool? result = await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return result ?? false;
    }
    return true;
  }

  Future<void> showNotification(String title, String body,
      {String? payload}) async {
    if (!_isInitialized) await init();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'daily_affirmation',
      '日常金句',
      channelDescription: '每日金句提醒',
      importance: Importance.high,
      priority: Priority.high,
      enableLights: true,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      badgeNumber: 0,
      interruptionLevel: InterruptionLevel.active,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    // 使用固定的通知ID，避免重复
    await _notifications.show(
      0, // 使用固定ID
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<bool> checkNotificationStatus() async {
    if (Platform.isIOS) {
      final bool? isEnabled = await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return isEnabled ?? false;
    }
    return true;
  }

  Future<void> _scheduleDaily(String title, String body, int hour, int minute,
      {String? payload, int notificationId = 0}) async {
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // 创建时区时间
    final scheduledTZ = tz.TZDateTime.from(scheduledDate, tz.local);

    await _notifications.zonedSchedule(
      notificationId,
      title,
      body,
      scheduledTZ,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_affirmation',
          '每日金句',
          channelDescription: '每日推送一条金句',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
          badgeNumber: 0,
          interruptionLevel: InterruptionLevel.active,
          threadIdentifier: 'daily_affirmation',
          categoryIdentifier: 'daily_affirmation',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  Future<void> scheduleMultipleNotifications(String time,
      {required bool enabled}) async {
    if (!_isInitialized) await init();

    try {
      // 先取消所有现有的通知
      await _notifications.cancelAll();

      if (!enabled) {
        // 如果通知被禁用，保存设置并返回
        await StorageService.saveNotificationSettings(
          enabled: false,
          time: time,
        );
        return;
      }

      final timeParts = time.split(':');
      final startHour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      // 获取选中的分类
      final selectedCategory = await StorageService.getSelectedCategory();

      // 获取该分类下的金句
      final affirmations = await StorageService.getAffirmations();
      if (affirmations.isEmpty) return;

      // 如果选择了特定分类，只使用该分类的金句
      final filteredAffirmations = selectedCategory != null
          ? affirmations.where((a) => a.category == selectedCategory).toList()
          : affirmations;

      if (filteredAffirmations.isEmpty) return;

      // 设置每两小时一次的通知，从开始时间到晚上10点
      for (int hour = startHour; hour <= 22; hour += 2) {
        // 随机选择一条金句
        final random = Random();
        final randomIndex = random.nextInt(filteredAffirmations.length);
        final affirmation = filteredAffirmations[randomIndex];

        // 使用固定的通知ID，基于小时
        final notificationId = hour;

        await _scheduleDaily(
          'app.name'.tr(),
          affirmation.message,
          hour,
          minute,
          payload: affirmation.message,
          notificationId: notificationId,
        );

        print('已设置通知 - 时间: $hour:$minute, ID: $notificationId');
      }

      // 保存通知设置
      await StorageService.saveNotificationSettings(
        enabled: true,
        time: time,
      );

      print('成功设置所有通知，开始时间: $time, 通知数量: ${(22 - startHour) ~/ 2 + 1}');
    } catch (e) {
      print('设置通知失败: $e');
      rethrow;
    }
  }

  Future<void> cancelAllNotifications() async {
    if (!_isInitialized) await init();
    await _notifications.cancelAll();
  }
}
