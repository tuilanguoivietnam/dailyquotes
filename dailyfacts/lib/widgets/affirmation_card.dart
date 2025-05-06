import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screenshot/screenshot.dart';
import '../utils/responsive_utils.dart';
import 'action_buttons.dart';
import 'share_overlay.dart';
import 'dart:io';
import '../providers/background_image_provider.dart';
import 'package:flutter/rendering.dart';

class AffirmationCard extends ConsumerWidget {
  final String affirmation;
  final bool isFavorite;
  final bool isPlayingTTS;
  final bool isLoadingTTS;
  final bool showActionButtons;
  final bool isShareMode;
  final ScreenshotController screenshotController;
  final VoidCallback onPlayTTS;
  final VoidCallback onToggleFavorite;
  final VoidCallback onShare;
  final double? fontSize;

  const AffirmationCard({
    Key? key,
    required this.affirmation,
    required this.isFavorite,
    required this.isPlayingTTS,
    required this.isLoadingTTS,
    required this.showActionButtons,
    required this.isShareMode,
    required this.screenshotController,
    required this.onPlayTTS,
    required this.onToggleFavorite,
    required this.onShare,
    this.fontSize,
  }) : super(key: key);

  String _getFontFamily(String text) {
    final isChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(text);
    if (isChinese) return 'NotoSansSC';
    return 'OpenSans';
  }

  Widget _buildCardContent(BuildContext context, ThemeData theme, String? backgroundImagePath) {
    return Card(
      color: theme.colorScheme.primaryContainer,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      shadowColor: theme.colorScheme.shadow.withOpacity(0.15),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          left: 32,
          right: 32,
          top: 80,
          bottom: ResponsiveUtils.getButtonHeight(context) + 32,
        ),
        decoration: backgroundImagePath != null
            ? BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          image: DecorationImage(
            image: FileImage(File(backgroundImagePath)),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              theme.colorScheme.background.withOpacity(0.1),
              BlendMode.srcATop,
            ),
          ),
        )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      affirmation,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontFamily: _getFontFamily(affirmation),
                        fontWeight: FontWeight.w600,
                        fontSize: fontSize ?? 44,
                        height: 1.6,
                        color: backgroundImagePath != null
                            ? Colors.white
                            : theme.colorScheme.onPrimaryContainer,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.25),
                            offset: const Offset(0, 2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
            if (showActionButtons)
              ActionButtons(
                isPlayingTTS: isPlayingTTS,
                isLoadingTTS: isLoadingTTS,
                isFavorite: isFavorite,
                onPlayTTS: onPlayTTS,
                onToggleFavorite: onToggleFavorite,
                onShare: onShare,
              ),
            if (isShareMode)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: ShareOverlay(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final backgroundImagePath = ref.watch(backgroundImageProvider);

    return GestureDetector(
      onLongPress: () {
        if (!isShareMode) {
          onShare();
        }
      },
      child: Screenshot(
        controller: screenshotController,
        child: _buildCardContent(context, theme, backgroundImagePath),
      ),
    );
  }
}
