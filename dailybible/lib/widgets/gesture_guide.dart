import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/guide_provider.dart';
import '../utils/responsive_utils.dart';
import 'package:easy_localization/easy_localization.dart';

class GestureGuideStep {
  final IconData icon;
  final String title;
  final String description;

  const GestureGuideStep({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class GestureGuide extends ConsumerStatefulWidget {
  const GestureGuide({super.key});

  @override
  ConsumerState<GestureGuide> createState() => _GestureGuideState();
}

class _GestureGuideState extends ConsumerState<GestureGuide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  int _currentStep = 0;

  List<GestureGuideStep> get _steps => [
        GestureGuideStep(
          icon: Icons.lightbulb_outline,
          title: 'guide.welcome.title'.tr(),
          description: 'guide.welcome.description'.tr(),
        ),
        GestureGuideStep(
          icon: Icons.swipe_vertical,
          title: 'guide.swipe.title'.tr(),
          description: 'guide.swipe.description'.tr(),
        ),
        GestureGuideStep(
          icon: Icons.touch_app_outlined,
          title: 'guide.longPress.title'.tr(),
          description: 'guide.longPress.description'.tr(),
        ),
        GestureGuideStep(
          icon: Icons.play_circle_outline,
          title: 'guide.play.title'.tr(),
          description: 'guide.play.description'.tr(),
        ),
        GestureGuideStep(
          icon: Icons.favorite,
          title: 'guide.favorite.title'.tr(),
          description: 'guide.favorite.description'.tr(),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
      _controller.reset();
      _controller.forward();
    } else {
      _closeGuide();
    }
  }

  void _closeGuide() {
    // 1. 直接强制设置状态为true (已经显示引导)
    ref.read(guideProvider.notifier).manuallyCloseGuide();

    // 2. 等待短暂延迟确保状态更新
    Future.delayed(const Duration(milliseconds: 50), () {
      // 3. 如果组件还挂载，强制刷新
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final isLastStep = _currentStep == _steps.length - 1;

    // 检查引导是否应该显示 - 如果引导已关闭则不渲染
    final shouldShow = !ref.watch(guideProvider);
    if (!shouldShow) {
      return const SizedBox.shrink(); // 如果引导已关闭则返回空组件
    }

    return Material(
      color: Colors.black54,
      child: WillPopScope(
        onWillPop: () async {
          _closeGuide();
          return false;
        },
        child: GestureDetector(
          onTap: _nextStep,
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 关闭按钮
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: Icon(
                            Icons.close,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5),
                          ),
                          onPressed: _closeGuide,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                      Icon(
                        step.icon,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        step.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        step.description,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          isLastStep ? 'common.finish'.tr() : 'common.continue'.tr(),
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_currentStep + 1}/${_steps.length}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.5),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
