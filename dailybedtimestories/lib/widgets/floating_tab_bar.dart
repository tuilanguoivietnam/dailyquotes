import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/selected_category_provider.dart';
import '../utils/responsive_utils.dart';
import '../providers/whitenoise_provider.dart';

class FloatingTabBar extends ConsumerWidget {
  final int selectedTabIndex;
  final Function(int) onTabChanged;
  final VoidCallback onCategoryTap;
  final VoidCallback onWhiteNoiseTap;
  final VoidCallback onFavoritesTap;
  final VoidCallback onThemeTap;
  final VoidCallback onSettingsTap;

  const FloatingTabBar({
    Key? key,
    required this.selectedTabIndex,
    required this.onTabChanged,
    required this.onCategoryTap,
    required this.onWhiteNoiseTap,
    required this.onFavoritesTap,
    required this.onThemeTap,
    required this.onSettingsTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final allCategoryName = 'home.category_all'.tr();

    // 检查白噪音是否正在播放
    final whiteNoiseState = ref.watch(whitenoiseProvider);
    final whiteNoiseNotifier = ref.watch(whitenoiseProvider.notifier);
    final isWhiteNoisePlaying = whiteNoiseState.whenOrNull(
          data: (whiteNoises) =>
              whiteNoises.any((w) => whiteNoiseNotifier.isPlaying(w.id)),
        ) ??
        false;

    return Container(
      height: ResponsiveUtils.getButtonHeight(context),
      margin: EdgeInsets.only(
        left: ResponsiveUtils.getPagePadding(context).left,
        right: ResponsiveUtils.getPagePadding(context).right,
        bottom: ResponsiveUtils.getPagePadding(context).bottom,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTabItem(
            context,
            icon: Icons.category_rounded,
            label: selectedCategory ?? allCategoryName,
            onTap: onCategoryTap,
            isSelected: selectedTabIndex == 0,
          ),
          _buildTabItem(
            context,
            icon: Icons.favorite_rounded,
            label: 'home.favorites'.tr(),
            onTap: onFavoritesTap,
            isSelected: selectedTabIndex == 2,
          ),
          _buildTabItem(
            context,
            icon: Icons.palette_rounded,
            label: 'home.theme'.tr(),
            onTap: onThemeTap,
            isSelected: selectedTabIndex == 3,
          ),
          _buildTabItem(
            context,
            icon: Icons.settings_rounded,
            label: 'app.settings'.tr(),
            onTap: onSettingsTap,
            isSelected: selectedTabIndex == 4,
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: ResponsiveUtils.getButtonHeight(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.6),
                  size: 24,
                ),
                const SizedBox(height: 2),
                Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 专门为白噪音创建一个有状态的动画组件
class AnimatedWhiteNoiseTab extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isSelected;
  final bool isPlaying;

  const AnimatedWhiteNoiseTab({
    Key? key,
    required this.label,
    required this.onTap,
    required this.isSelected,
    required this.isPlaying,
  }) : super(key: key);

  @override
  _AnimatedWhiteNoiseTabState createState() => _AnimatedWhiteNoiseTabState();
}

class _AnimatedWhiteNoiseTabState extends State<AnimatedWhiteNoiseTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
      ),
    );

    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
      ),
    );

    // 设置动画循环
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _animationController.forward();
      }
    });

    // 如果正在播放，启动动画
    if (widget.isPlaying) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(AnimatedWhiteNoiseTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 当播放状态改变时，更新动画
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _animationController.forward();
      } else {
        _animationController.stop();
        _animationController.reset();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: SizedBox(
            height: ResponsiveUtils.getButtonHeight(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // 波纹动画效果
                    if (widget.isPlaying)
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // 外层波纹
                              Container(
                                width: 35 * _scaleAnimation.value,
                                height: 35 * _scaleAnimation.value,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.isSelected
                                      ? theme.colorScheme.primary.withOpacity(
                                          _opacityAnimation.value * 0.3)
                                      : theme.colorScheme.onSurface.withOpacity(
                                          _opacityAnimation.value * 0.15),
                                ),
                              ),

                              // 波浪动画效果
                              ShaderMask(
                                shaderCallback: (Rect bounds) {
                                  return LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      widget.isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface
                                              .withOpacity(0.6),
                                    ],
                                    stops: [
                                      1.0 - (_waveAnimation.value * 0.7 + 0.3),
                                      1.0
                                    ],
                                  ).createShader(bounds);
                                },
                                blendMode: BlendMode.srcIn,
                                child: const Icon(
                                  Icons.waves_rounded,
                                  size: 28,
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                    // 静态图标（未播放状态）
                    if (!widget.isPlaying)
                      Icon(
                        Icons.waves_rounded,
                        color: widget.isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                        size: 24,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Flexible(
                  child: Text(
                    widget.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: widget.isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: widget.isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
