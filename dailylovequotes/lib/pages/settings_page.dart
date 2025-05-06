import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import '../providers/volume_provider.dart';
import '../providers/language_provider.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../providers/affirmation_provider.dart';
import '../providers/whitenoise_provider.dart';
import '../providers/affirmation_list_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/subscription_service.dart';
import '../models/subscription.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dailylovequotes/providers/theme_provider.dart';
import 'package:dailylovequotes/providers/font_size_provider.dart';
import 'package:dailylovequotes/utils/responsive_utils.dart';
import 'package:dailylovequotes/widgets/custom_dialog.dart';

import 'subscription_page.dart';
import 'dart:io' show Platform;

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _notificationsEnabled = false;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 8, minute: 0);
  bool _isInitialized = false;
  late bool isDark;

  @override
  void initState() {
    super.initState();
    isDark = ref.read(themeProvider) == ThemeMode.dark;
    _loadNotificationSettings();
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(
        isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark);
    super.dispose();
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final settings = await StorageService.getNotificationSettings();
      bool needFix = false;
      bool enabled = true;
      String time = '08:00';

      if (settings.isNotEmpty) {
        // 自动修复 enabled 字段
        if (settings['enabled'] is! bool) {
          needFix = true;
          enabled = true;
        } else {
          enabled = settings['enabled'] as bool;
        }
        // 自动修复 time 字段
        if (settings['time'] is! String) {
          needFix = true;
          time = '08:00';
        } else {
          time = settings['time'] as String;
        }
      } else {
        // 没有设置，写入默认值
        needFix = true;
      }

      if (needFix) {
        await StorageService.saveNotificationSettings(
          enabled: enabled,
          time: time,
        );
      }

      final timeParts = time.split(':');
      setState(() {
        _notificationsEnabled = enabled;
        _notificationTime = TimeOfDay(
          hour: int.parse(timeParts[0]),
          minute: int.parse(timeParts[1]),
        );
        _isInitialized = true;
      });
    } catch (e) {
      print('加载通知设置失败: $e');
      // 发生错误时使用默认值并修复
      setState(() {
        _notificationsEnabled = false; // 默认关闭通知
        _notificationTime = const TimeOfDay(hour: 8, minute: 0);
        _isInitialized = true;
      });
      await StorageService.saveNotificationSettings(
        enabled: false,
        time: '08:00',
      );
    }
  }

  Future<void> _saveNotificationSettings() async {
    try {
      final formattedTime =
          '${_notificationTime.hour.toString().padLeft(2, '0')}:${_notificationTime.minute.toString().padLeft(2, '0')}';

      // 检查 affirmations box 是否有内容
      final affirmations = await StorageService.getAffirmations();
      if (affirmations.isEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(context.tr('settings.notification_error')),
              content: Text(context.tr('settings.no_affirmations')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr('common.ok')),
                ),
              ],
            ),
          );
        }
        return;
      }

      // 如果启用通知，先请求权限
      if (_notificationsEnabled) {
        final hasPermission =
            await NotificationService.instance.requestPermission();
        if (!hasPermission) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(
                    context.tr('settings.notification_permission_required')),
                content: Text(
                    context.tr('settings.notification_permission_message')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.tr('common.ok')),
                  ),
                ],
              ),
            );
          }
          setState(() {
            _notificationsEnabled = false;
          });
          return;
        }
      }

      // 保存设置
      await StorageService.saveNotificationSettings(
        enabled: _notificationsEnabled,
        time: formattedTime,
      );

      // 设置通知
      await NotificationService.instance.scheduleMultipleNotifications(
        formattedTime,
        enabled: _notificationsEnabled,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('settings.notification_saved'))),
        );
      }
    } catch (e) {
      print('保存通知设置失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.tr('settings.notification_save_failed'))),
        );
      }
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
    );
    if (picked != null && picked != _notificationTime) {
      setState(() {
        _notificationTime = picked;
      });
      await _saveNotificationSettings();
    }
  }

  Future<void> _shareApp() async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      text: context.tr('settings.share_app_message'),
      subject: 'DailyLove',
      sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
    ));
  }

  Future<void> _rateApp() async {
    final url = Uri.parse(
        'https://apps.apple.com/us/app/dailylove-love-sparks/id6747162145');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final volumeSettings = ref.watch(volumeProvider);
    final langState = ref.watch(languageProvider);
    final theme = Theme.of(context);
    final isDarkMode = ref.watch(themeProvider) == ThemeMode.dark;
    final currentFontSize = ref.watch(fontSizeProvider);
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'app.settings'.tr(),
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.background,
              theme.colorScheme.primaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          children: [
            // 会员订阅 - 仅在iOS设备上显示
            // if (Platform.isIOS)
            Card(
              margin: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.card_membership, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'settings.subscription'.tr(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      final isSubscribed = ref.watch(subscriptionProvider);

                      return Column(
                        children: [
                          // 订阅状态卡片
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSubscribed
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isSubscribed
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: isSubscribed ? Colors.amber : null,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isSubscribed
                                          ? 'settings.premium_active'.tr()
                                          : 'settings.premium_inactive'.tr(),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isSubscribed ? Colors.amber : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                FutureBuilder<UserSubscription?>(
                                  future:
                                      SubscriptionService.getUserSubscription(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return Text('common.loading'.tr());
                                    }

                                    final subscription = snapshot.data;
                                    return Text(
                                      isSubscribed
                                          ? subscription?.endDate != null
                                              ? 'settings.subscription_expires'
                                                  .tr(args: [
                                                  DateFormat('yyyy-MM-dd')
                                                      .format(
                                                          subscription!.endDate)
                                                ])
                                              : 'settings.subscription_active'
                                                  .tr()
                                          : 'settings.subscription_benefits'
                                              .tr(),
                                    );
                                  },
                                ),
                                if (isSubscribed) ...[
                                  const SizedBox(height: 16),
                                  // Row(
                                  //   children: [
                                  //     const Icon(Icons.check_circle,
                                  //         color: Colors.green, size: 16),
                                  //     const SizedBox(width: 4),
                                  //     Text('settings.benefit_no_ads'.tr()),
                                  //   ],
                                  // ),
                                  // const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle,
                                          color: Colors.green, size: 16),
                                      const SizedBox(width: 4),
                                      Text('settings.benefit_all_content'.tr()),
                                    ],
                                  ),
                                  // const SizedBox(height: 4),
                                  // Row(
                                  //   children: [
                                  //     const Icon(Icons.check_circle,
                                  //         color: Colors.green, size: 16),
                                  //     const SizedBox(width: 4),
                                  //     Text('settings.benefit_premium_themes'
                                  //         .tr()),
                                  //   ],
                                  // ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // 订阅按钮
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/subscription');
                                },
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  backgroundColor: isSubscribed
                                      ? Theme.of(context).colorScheme.surface
                                      : Theme.of(context).colorScheme.primary,
                                  foregroundColor: isSubscribed
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: isSubscribed
                                        ? BorderSide(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary)
                                        : BorderSide.none,
                                  ),
                                ),
                                child: Text(
                                  isSubscribed
                                      ? 'settings.manage_subscription'.tr()
                                      : 'settings.subscribe_now'.tr(),
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          ),
                          // 取消订阅按钮
                          if (isSubscribed)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: ListTile(
                                leading: const Icon(Icons.cancel_outlined,
                                    color: Colors.red),
                                title: Text(
                                  'settings.cancel_subscription'.tr(),
                                  style: const TextStyle(color: Colors.red),
                                ),
                                onTap: () {
                                  // 添加确认对话框
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title:
                                          Text('settings.cancel_confirm'.tr()),
                                      content: Text(
                                          'settings.cancel_confirm_message'
                                              .tr()),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: Text('common.no'.tr()),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          child: Text(
                                            'common.yes'.tr(),
                                            style: const TextStyle(
                                                color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            // 语言设置
            Card(
              margin: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'app.language'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  RadioListTile<String>(
                    title: Text('app.language_system'.tr()),
                    value: 'system',
                    groupValue: langState,
                    onChanged: (value) {
                      ref.read(languageProvider.notifier).setSystemLanguage();
                      final deviceLocale = context.deviceLocale;
                      final supported = ['zh', 'en', 'ja'];
                      final locale =
                          supported.contains(deviceLocale.languageCode)
                              ? Locale(deviceLocale.languageCode)
                              : const Locale('en');
                      context.setLocale(locale);
                      ref
                          .read(affirmationListProvider.notifier)
                          .loadInitial(null, locale.languageCode);
                    },
                  ),
                  RadioListTile<String>(
                    title: Text('app.language_zh'.tr()),
                    value: 'zh',
                    groupValue: langState,
                    onChanged: (value) {
                      ref.read(languageProvider.notifier).setLanguage('zh');
                      context.setLocale(const Locale('zh'));
                      ref
                          .read(affirmationListProvider.notifier)
                          .loadInitial(null, 'zh');
                    },
                  ),
                  RadioListTile<String>(
                    title: Text('app.language_en'.tr()),
                    value: 'en',
                    groupValue: langState,
                    onChanged: (value) {
                      ref.read(languageProvider.notifier).setLanguage('en');
                      context.setLocale(const Locale('en'));
                      ref
                          .read(affirmationListProvider.notifier)
                          .loadInitial(null, 'en');
                    },
                  ),
                  RadioListTile<String>(
                    title: Text('app.language_ja'.tr()),
                    value: 'ja',
                    groupValue: langState,
                    onChanged: (value) {
                      ref.read(languageProvider.notifier).setLanguage('ja');
                      context.setLocale(const Locale('ja'));
                      ref
                          .read(affirmationListProvider.notifier)
                          .loadInitial(null, 'ja');
                    },
                  ),
                ],
              ),
            ),
            // 通知设置
            Card(
              margin: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'settings.notifications'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SwitchListTile(
                    title: Text('settings.daily_notification'.tr()),
                    subtitle: Text('settings.notification_subtitle'.tr()),
                    value: _notificationsEnabled,
                    onChanged: (bool value) async {
                      if (value) {
                        // 用户尝试打开，先请求权限
                        final hasPermission = await NotificationService.instance
                            .requestPermission();
                        if (hasPermission) {
                          setState(() {
                            _notificationsEnabled = true;
                          });
                          await _saveNotificationSettings();
                        } else {
                          setState(() {
                            _notificationsEnabled = false;
                          });
                          if (mounted) {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(context.tr(
                                    'settings.notification_permission_required')),
                                content: Text(context.tr(
                                    'settings.notification_permission_message')),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(context.tr('common.ok')),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                      } else {
                        // 用户关闭
                        setState(() {
                          _notificationsEnabled = false;
                        });
                        await _saveNotificationSettings();
                      }
                    },
                  ),
                  ListTile(
                    enabled: _notificationsEnabled,
                    title: Text('settings.notification_time'.tr()),
                    subtitle: Text('settings.notification_time_format'
                        .tr(args: [_notificationTime.format(context)])),
                    trailing: IconButton(
                      icon: const Icon(Icons.access_time),
                      onPressed: _notificationsEnabled
                          ? () => _selectTime(context)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            // 音量设置
            Card(
              margin: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'settings.volume'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ListTile(
                    title: Text('settings.tts_volume'.tr()),
                    subtitle: Slider(
                      value: volumeSettings.ttsVolume,
                      onChanged: (value) {
                        ref.read(volumeProvider.notifier).setTTSVolume(value);
                        final player =
                            ref.read(affirmationProvider.notifier).audioPlayer;
                        player.setVolume(value);
                        print('TTS音量已设为: $value');
                      },
                    ),
                  ),
                ],
              ),
            ),
            // 字体大小设置
            _buildSection(
              context,
              title: context.tr('settings.font_size'),
              child: Column(
                children: [
                  RadioListTile<FontSize>(
                    value: FontSize.small,
                    groupValue: currentFontSize,
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(fontSizeProvider.notifier).setFontSize(value);
                      }
                    },
                    title: Text(
                      context.tr('settings.font_size_small'),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  RadioListTile<FontSize>(
                    value: FontSize.medium,
                    groupValue: currentFontSize,
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(fontSizeProvider.notifier).setFontSize(value);
                      }
                    },
                    title: Text(
                      context.tr('settings.font_size_medium'),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  RadioListTile<FontSize>(
                    value: FontSize.large,
                    groupValue: currentFontSize,
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(fontSizeProvider.notifier).setFontSize(value);
                      }
                    },
                    title: Text(
                      context.tr('settings.font_size_large'),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            // 分享和评分
            _buildSection(
              context,
              title: context.tr('settings.about'),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.share),
                    title: Text(
                      context.tr('settings.share_app'),
                      style: theme.textTheme.titleMedium,
                    ),
                    onTap: _shareApp,
                  ),
                  ListTile(
                    leading: const Icon(Icons.star),
                    title: Text(
                      context.tr('settings.rate_app'),
                      style: theme.textTheme.titleMedium,
                    ),
                    onTap: _rateApp,
                  ),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      return ListTile(
                        leading: const Icon(Icons.info),
                        title: Text(
                          context.tr('settings.version'),
                          style: theme.textTheme.titleMedium,
                        ),
                        subtitle: Text(snapshot.data!.version),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.getSpacing(context),
            vertical: ResponsiveUtils.getSpacing(context) / 2,
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Card(
          margin: const EdgeInsets.all(12),
          child: child,
        ),
        SizedBox(height: ResponsiveUtils.getSpacing(context)),
      ],
    );
  }
}
