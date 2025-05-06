import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

class ActionButtons extends StatelessWidget {
  final bool isPlayingTTS;
  final bool isLoadingTTS;
  final bool isFavorite;
  final VoidCallback onPlayTTS;
  final VoidCallback onToggleFavorite;
  final VoidCallback onShare;

  const ActionButtons({
    Key? key,
    required this.isPlayingTTS,
    required this.isLoadingTTS,
    required this.isFavorite,
    required this.onPlayTTS,
    required this.onToggleFavorite,
    required this.onShare,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 播放TTS
        Material(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(30),
          child: InkWell(
            onTap: isLoadingTTS ? null : onPlayTTS,
            borderRadius: BorderRadius.circular(30),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Icon(
                isPlayingTTS
                    ? Icons.stop
                    : isLoadingTTS
                        ? Icons.hourglass_empty
                        : Icons.play_arrow,
                color: theme.colorScheme.onPrimary,
                size: ResponsiveUtils.getIconSize(context),
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        // 收藏
        Material(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(30),
          child: InkWell(
            onTap: onToggleFavorite,
            borderRadius: BorderRadius.circular(30),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: theme.colorScheme.onPrimary,
                size: ResponsiveUtils.getIconSize(context),
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        // 分享
        Material(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(30),
          child: InkWell(
            onTap: onShare,
            borderRadius: BorderRadius.circular(30),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Icon(
                Icons.share,
                color: theme.colorScheme.onPrimary,
                size: ResponsiveUtils.getIconSize(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
