import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dailystory/config/api_config.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../providers/affirmation_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/whitenoise_provider.dart';
import '../providers/volume_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/affirmation_list_provider.dart';
import '../providers/category_provider.dart';
import '../providers/selected_category_provider.dart';
import '../providers/connectivity_provider.dart';
import '../utils/responsive_utils.dart';
import '../services/share_service.dart';
import '../models/affirmation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'favorites_page.dart';
import 'theme_page.dart';
import 'settings_page.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:screenshot/screenshot.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/rendering.dart';
import '../widgets/affirmation_card.dart';
import '../widgets/floating_tab_bar.dart';
import '../widgets/category_modal.dart';
import '../widgets/white_noise_modal.dart';
import '../widgets/share_overlay.dart';
import '../providers/font_size_provider.dart';
import '../providers/guide_provider.dart';
import '../widgets/gesture_guide.dart';
import '../services/rating_service.dart';
import '../widgets/rating_dialog.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final Map<int, ScreenshotController> _screenshotControllers = {};
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;
  double _currentPage = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // final AudioPlayer _ttsPlayer = AudioPlayer();
  bool _isPlayingTTS = false;
  bool _isLoadingTTS = false;
  bool _isAutoPlaying = false;
  int _selectedTabIndex = 0;
  bool _hasLoadedInitial = false;
  bool _isFromBackground = false; // 添加标记是否从后台恢复
  final adUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-3524715987811873/4349329576';
  InterstitialAd? _interstitialAd;
  String _selectedCategory = '全部';
  bool _showActionButtons = true;
  bool _isShareMode = false;

  // 添加白噪音动画控制器
  late AnimationController _whiteNoiseTabAnimationController;
  late Animation<double> _whiteNoiseTabScaleAnimation;
  late Animation<double> _whiteNoiseTabOpacityAnimation;
  late AnimationController _whiteNoiseRippleController;
  late Animation<double> _whiteNoiseRippleAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupAnimations();
    _setupAudioListeners();
    _setupWhiteNoiseListeners();
    
    // 设置前台通知处理回调
    NotificationService.instance.setForegroundNotificationCallback(_handleForegroundNotification);

    // 记录应用启动次数
    RatingService.incrementAppOpenCount();

    // 检查是否有通知金句
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 加载初始数据
      _loadInitialData();
      
      // 检查是否应该显示评分弹窗
      _checkAndShowRatingDialog();
    });

    // 初始化白噪音动画
    _whiteNoiseTabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _whiteNoiseTabScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _whiteNoiseTabAnimationController,
      curve: Curves.easeInOut,
    ));

    _whiteNoiseTabOpacityAnimation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _whiteNoiseTabAnimationController,
      curve: Curves.easeInOut,
    ));

    _whiteNoiseRippleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _whiteNoiseRippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _whiteNoiseRippleController,
      curve: Curves.easeOut,
    ));

    // 设置动画循环
    _whiteNoiseTabAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _whiteNoiseTabAnimationController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _whiteNoiseTabAnimationController.forward();
      }
    });

    _whiteNoiseRippleController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _whiteNoiseRippleController.reset();
        _whiteNoiseRippleController.forward();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = context.locale.languageCode;
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final allCategoryName = 'home.category_all'.tr();

    if (selectedCategory != null &&
        selectedCategory != allCategoryName &&
        (selectedCategory == '全部' ||
            selectedCategory == 'All' ||
            selectedCategory == '総合')) {
      // 使用Future延迟执行，避免在build过程中修改provider
      Future.microtask(() {
        ref
            .read(selectedCategoryProvider.notifier)
            .setCategory(allCategoryName);
      });
    }
  }

  void _createInterstitialAd() {
    // 如果不是 iOS 或 Android 平台，直接返回
    if (!Platform.isIOS && !Platform.isAndroid) return;

    try {
      InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            _interstitialAd = ad;
            _interstitialAd!.fullScreenContentCallback =
                FullScreenContentCallback(
              onAdDismissedFullScreenContent: (InterstitialAd ad) {
                ad.dispose();
                _interstitialAd = null;
                // 延迟重试加载广告
                Future.delayed(const Duration(seconds: 1), () {
                  _createInterstitialAd();
                });
              },
              onAdFailedToShowFullScreenContent:
                  (InterstitialAd ad, AdError error) {
                ad.dispose();
                _interstitialAd = null;
                // 延迟重试加载广告
                Future.delayed(const Duration(seconds: 1), () {
                  _createInterstitialAd();
                });
              },
            );
          },
          onAdFailedToLoad: (LoadAdError error) {
            print('Failed to load interstitial ad: ${error.message}');
            _interstitialAd = null;
            // 延迟重试加载广告
            Future.delayed(const Duration(seconds: 1), () {
              _createInterstitialAd();
            });
          },
        ),
      );
    } catch (e) {
      print('Error creating interstitial ad: $e');
      // 延迟重试加载广告
      Future.delayed(const Duration(seconds: 1), () {
        _createInterstitialAd();
      });
    }
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // 设置呼吸动画
    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    _breathingAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOut,
      ),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _breathingController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _breathingController.forward();
        }
      });

    _animationController.forward();

    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page ?? 0;
      });
    });
  }

  void _setupAudioListeners() {
    ref
        .read(affirmationProvider.notifier)
        .audioPlayer
        .onPlayerComplete
        .listen((_) {
      if (_isAutoPlaying) {
        final affirmations = ref.read(affirmationListProvider).value;
        if (affirmations != null && affirmations.isNotEmpty) {
          final currentIndex = _currentPage.toInt();
          if (currentIndex < affirmations.length - 1) {
            // 不是最后一条，自动切换到下一页并播放
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                setState(() {
                  _isPlayingTTS = false;
                  _isAutoPlaying = false;
                  _breathingController.stop();
                });
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
                // 延迟500ms后开始播放下一页
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    final affirmations =
                        ref.read(affirmationListProvider).value;
                    _playTTS(affirmations![currentIndex + 1]);
                  }
                });
              }
            });
          } else {
            // 最后一条，停止自动播放
            setState(() {
              _isPlayingTTS = false;
              _isAutoPlaying = false;
              _breathingController.stop();
            });
          }
        }
      }
    });

    ref
        .read(affirmationProvider.notifier)
        .audioPlayer
        .onPlayerStateChanged
        .listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingTTS = state == PlayerState.playing;
          if (!_isPlayingTTS) {
            _breathingController.stop();
          }
        });
      }
    });
  }

  void _setupWhiteNoiseListeners() {
    // 监听白噪音播放状态
    ref
        .read(whitenoiseProvider.notifier)
        .audioPlayer
        .onPlayerStateChanged
        .listen((state) {
      if (mounted) {
        setState(() {
          // 如果播放停止，清除当前播放的白噪音ID
          // 不需要清除 _currentWhiteNoiseId
        });
      }
    });

    // 监听白噪音播放完成
    ref
        .read(whitenoiseProvider.notifier)
        .audioPlayer
        .onPlayerComplete
        .listen((_) {
      if (mounted) {
        setState(() {
          // 播放完成时，保持当前白噪音ID，因为会自动循环播放
          // 不需要清除 _currentWhiteNoiseId
        });
      }
    });
  }

  void _loadInitialData() async {
    final lang = context.locale.languageCode;
    final selectedCategory = await StorageService.getSelectedCategory();

    // 先获取通知金句
    final notificationAffirmation =
        NotificationService.instance.notificationAffirmation;
    if (_isFromBackground) {
      // 不管是网络加载还是本地加载完成后，都再次确保通知金句在第一位
      if (notificationAffirmation != null) {
        ref
            .read(affirmationListProvider.notifier)
            .addNotificationAffirmation(notificationAffirmation);

        // 确保页面回到第一页
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      }

      // 如果是从后台恢复，不重新加载数据
      return;
    }

    // 再尝试网络加载
    await ref.read(affirmationListProvider.notifier).loadInitial(
          selectedCategory,
          lang,
          useCache: false,
        );

    // 检查网络加载结果
    final affirmations = ref.read(affirmationListProvider).value;
    if (affirmations == null || affirmations.isEmpty) {
      // 网络无数据或失败，再加载本地并 append 到后面
      await ref.read(affirmationListProvider.notifier).loadInitial(
            selectedCategory,
            lang,
            useCache: true,
            append: true,
          );
    }

    // 不管是网络加载还是本地加载完成后，都再次确保通知金句在第一位
    if (notificationAffirmation != null) {
      ref
          .read(affirmationListProvider.notifier)
          .addNotificationAffirmation(notificationAffirmation);

      // 确保页面回到第一页
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
    ref.read(categoryProvider.notifier).loadCategories(lang);

    // 在数据加载完成后初始化通知
    _initDefaultNotification();

    setState(() {
      _hasLoadedInitial = true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // 从后台恢复
      setState(() {
        _isFromBackground = true;
      });
      NotificationService.instance.setForegroundNotificationCallback(_handleForegroundNotification);

      // 检查通知状态
      NotificationService.instance.checkNotificationStatus().then((isEnabled) {
        if (!isEnabled) {
          // 重新设置通知
          _initDefaultNotification();
        }
      });

      // 检查是否有通知金句需要显示
      final notificationAffirmation =
          NotificationService.instance.notificationAffirmation;
      if (notificationAffirmation != null) {
        // 将通知金句添加到列表第一位
        ref
            .read(affirmationListProvider.notifier)
            .addNotificationAffirmation(notificationAffirmation);
        // 回到列表第一页
        if (mounted) {
          _pageController.jumpToPage(0);
        }
        NotificationService.instance.clearNotificationAffirmation();
      }
    } else if (state == AppLifecycleState.paused) {
      // 进入后台
      setState(() {
        _isFromBackground = false;
      });
      NotificationService.instance.setForegroundNotificationCallback(null);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _animationController.dispose();
    _breathingController.dispose();
    _audioPlayer.dispose();
    // _ttsPlayer.dispose();
    _whiteNoiseTabAnimationController.dispose();
    _whiteNoiseRippleController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    _animationController.reset();
    _animationController.forward();
    if (index > 0 && index % 10 == 0) {  // 每浏览10页触发一次检查
      _checkAndShowRatingDialog();
    }
  }

  Future<void> _playTTS(String text) async {
    if (_isLoadingTTS) return;

    setState(() {
      _isLoadingTTS = true;
    });

    try {
      if (_isPlayingTTS) {
        await ref.read(affirmationProvider.notifier).audioPlayer.stop();
        setState(() {
          _isPlayingTTS = false;
          _isAutoPlaying = false;
          _isLoadingTTS = false;
          _breathingController.stop();
        });
        return;
      }

      await ref.read(affirmationProvider.notifier).playTTS(text);
      setState(() {
        _isPlayingTTS = true;
        _isAutoPlaying = true;
        _isLoadingTTS = false;
        _breathingController.forward();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e')),
        );
        setState(() {
          _isPlayingTTS = false;
          _isAutoPlaying = false;
          _isLoadingTTS = false;
          _breathingController.stop();
        });
      }
    }
  }

  void _showWhiteNoiseModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const WhiteNoiseModal(),
    );
  }

  void _showCategoryModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const CategoryModal(),
    );
  }

  String _getFontFamily(String text) {
    final isChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(text);
    if (isChinese) return 'NotoSansSC';
    return 'OpenSans';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
          ));
    final theme = Theme.of(context);
    final affirmationListState = ref.watch(affirmationListProvider);
    final fontSizeEnum = ref.watch(fontSizeProvider);
    final shouldShowGuide = !ref.watch(guideProvider);
    double cardFontSize;
    switch (fontSizeEnum) {
      case FontSize.small:
        cardFontSize = 28;
        break;
      case FontSize.medium:
        cardFontSize = 36;
        break;
      case FontSize.large:
        cardFontSize = 44;
        break;
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: null,
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
            child: SafeArea(
              top: true,
              bottom: false,
              child: Stack(
                children: [
                  Consumer(
                    builder: (context, ref, child) {
                      ref.listen(connectivityProvider, (previous, next) {
                        next.whenData((connectivityResult) async {
                          // 当网络状态变为可用时（WiFi 或移动数据）
                          final isFirstRequest = await StorageService.getSetting(StorageService.keyFirstRequest);
                          if(isFirstRequest == null){
                            if (connectivityResult != ConnectivityResult.none) {
                              StorageService.saveSetting(StorageService.keyFirstRequest, true);
                              _loadInitialData();
                            }
                          }
                        });
                      });
                      return child!;
                    },
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: ResponsiveUtils.getPagePadding(context).left,
                        right: ResponsiveUtils.getPagePadding(context).right,
                        top: ResponsiveUtils.getPagePadding(context).top,
                        bottom: ResponsiveUtils.getButtonHeight(context) + 16,
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: affirmationListState.when(
                              data: (affirmations) => PageView.builder(
                                controller: _pageController,
                                scrollDirection: Axis.vertical,
                                itemCount: affirmations.length,
                                onPageChanged: (index) {
                                  _onPageChanged(index);
                                  if (index == affirmations.length - 1) {
                                    ref
                                        .read(affirmationListProvider.notifier)
                                        .loadMore(context.locale.languageCode);
                                  }
                                },
                                itemBuilder: (context, index) {
                                  final affirmation = affirmations[index];
                                  final isFavorite = ref
                                      .watch(favoritesProvider)
                                      .contains(affirmation);
                                  _screenshotControllers.putIfAbsent(
                                      index, () => ScreenshotController());
                                  final controller =
                                      _screenshotControllers[index]!;
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      left: 0,
                                      right: 0,
                                      top: 0,
                                      bottom: ResponsiveUtils.getButtonHeight(
                                              context) +
                                          24,
                                    ),
                                    child: Center(
                                      child: FadeTransition(
                                        opacity: _fadeAnimation,
                                        child: AffirmationCard(
                                          affirmation: affirmation,
                                          isFavorite: isFavorite,
                                          isPlayingTTS: _isPlayingTTS &&
                                              _currentPage.toInt() == index,
                                          isLoadingTTS: _isLoadingTTS &&
                                              _currentPage.toInt() == index,
                                          showActionButtons: _showActionButtons,
                                          isShareMode: _isShareMode,
                                          screenshotController: controller,
                                          onPlayTTS: () =>
                                              _playTTS(affirmation),
                                          onToggleFavorite: () async{
                                            await ref
                                                .read(
                                                    favoritesProvider.notifier)
                                                .toggleFavorite(affirmation);
                                            // 如果收藏后，可以考虑评分
                                            var isFavorite = ref
                                               .read(favoritesProvider.notifier)
                                            .isFavorite(affirmation);
                                            if (isFavorite){
                                              _checkAndShowRatingDialog();
                                            }
                                          },
                                          onShare: () async {
                                            setState(() {
                                              _isShareMode = true;
                                              _showActionButtons = false;
                                            });
                                            await Future.delayed(const Duration(
                                                milliseconds: 400));
                                            await ShareService.shareAffirmation(
                                                controller,
                                                context: context,
                                                onShareComplete: () {
                                              if (mounted) {
                                                setState(() {
                                                  _isShareMode = false;
                                                  _showActionButtons = true;
                                                });
                                              }
                                            });
                                          },
                                          fontSize: cardFontSize,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              loading: () => const Center(
                                  child: CircularProgressIndicator()),
                              error: (error, stack) => Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.error_outline_rounded,
                                        size: 48,
                                        color:
                                            Theme.of(context).colorScheme.error,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'home.load_failed'.tr(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'home.load_failed_message'.tr(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.7),
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 24),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          _loadInitialData();
                                        },
                                        icon: const Icon(Icons.refresh_rounded),
                                        label: Text('home.retry'.tr()),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: FloatingTabBar(
                      selectedTabIndex: _selectedTabIndex,
                      onTabChanged: (index) {
                        setState(() {
                          _selectedTabIndex = index;
                        });
                      },
                      onCategoryTap: _showCategoryModal,
                      onWhiteNoiseTap: _showWhiteNoiseModal,
                      onFavoritesTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FavoritesPage(),
                          ),
                        );
                      },
                      onThemeTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ThemePage(),
                          ),
                        );
                      },
                      onSettingsTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsPage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (shouldShowGuide)
          Consumer(
            builder: (context, ref, _) {
              // 通过Consumer重新检查状态确保及时更新
              final shouldReallyShowGuide = !ref.watch(guideProvider);
              if (!shouldReallyShowGuide) return const SizedBox.shrink();
              return const GestureGuide();
            },
          ),
      ],
    );
  }

  Future<void> _initDefaultNotification() async {
    try {
      // 初始化通知服务
      await NotificationService.instance.init();

      // 主动请求权限
      final hasPermission =
          await NotificationService.instance.requestPermission();

      // 获取当前通知设置
      final settings = await StorageService.getNotificationSettings();

      // 如果是首次启动或没有设置，设置默认值
      if (settings == null ||
          settings.isEmpty ||
          settings['enabled'] == false) {
        await StorageService.saveNotificationSettings(
          enabled: true,
          time: '08:00',
        );

        // 设置默认通知
        await NotificationService.instance.scheduleMultipleNotifications(
          '08:00',
          enabled: true,
        );
      } else if (settings['enabled'] == true) {
        // 如果有设置且启用了通知，重新设置通知
        await NotificationService.instance.scheduleMultipleNotifications(
          settings['time'] as String,
          enabled: true,
        );
      }

      // 检查通知状态
      final isEnabled =
          await NotificationService.instance.checkNotificationStatus();
      if (!isEnabled) {
        // 如果通知未启用，重新请求权限
        await NotificationService.instance.requestPermission();
      }
    } catch (e) {
      print('初始化通知失败: $e');
    }
  }

  // 处理前台通知
  void _handleForegroundNotification(String affirmation) {
    print("HomePage收到前台通知: $affirmation");
    if (mounted) {
      // 将通知金句添加到列表第一位
      ref
          .read(affirmationListProvider.notifier)
          .addNotificationAffirmation(affirmation);
          
      // 回到列表第一页
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  // 检查并显示评分弹窗
  Future<void> _checkAndShowRatingDialog() async {
    // 在正面操作（如收藏喜欢的肯定语或听完音频）之后的某个时机调用此方法
    final shouldShow = await RatingService.shouldShowRatingPrompt();
    if (shouldShow && mounted) {
      // 延迟几秒显示，让用户先看到内容
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      
      // 记录已显示过评分提示
      await RatingService.recordRatingPromptShown();
      
      // 显示评分弹窗
      showDialog(
        context: context,
        builder: (_) => const RatingDialog(),
      );
    }
  }
}
