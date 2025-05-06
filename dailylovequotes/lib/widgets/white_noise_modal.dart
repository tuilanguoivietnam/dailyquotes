import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/whitenoise_provider.dart';

class WhiteNoiseModal extends ConsumerWidget {
  const WhiteNoiseModal({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'home.white_noise'.tr(),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Consumer(
                builder: (context, ref, child) {
                  final whitenoiseState = ref.watch(whitenoiseProvider);
                  final whitenoiseNotifier =
                      ref.read(whitenoiseProvider.notifier);

                  return whitenoiseState.when(
                    data: (whitenoises) => whitenoises.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text('home.no_white_noise'.tr()),
                          )
                        : Container(
                            constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.of(context).size.height * 0.6,
                            ),
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                children: whitenoises.map((whitenoise) {
                                  final isPlaying = whitenoiseNotifier
                                      .isPlaying(whitenoise.id);
                                  final isLoading = whitenoiseNotifier
                                      .isLoading(whitenoise.id);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () async {
                                          if (isPlaying) {
                                            await whitenoiseNotifier
                                                .stopWhiteNoise();
                                          } else {
                                            await whitenoiseNotifier
                                                .toggleWhiteNoise(
                                                    whitenoise.id);
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(20),
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 18),
                                          decoration: BoxDecoration(
                                            color: isPlaying
                                                ? theme.colorScheme.primary
                                                    .withOpacity(0.12)
                                                : theme
                                                    .colorScheme.surfaceVariant
                                                    .withOpacity(0.08),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isPlaying
                                                  ? theme.colorScheme.primary
                                                  : theme.colorScheme.outline
                                                      .withOpacity(0.2),
                                              width: 1.5,
                                            ),
                                            boxShadow: isPlaying
                                                ? [
                                                    BoxShadow(
                                                      color: theme
                                                          .colorScheme.primary
                                                          .withOpacity(0.08),
                                                      blurRadius: 12,
                                                      offset:
                                                          const Offset(0, 2),
                                                    ),
                                                  ]
                                                : [],
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: isPlaying
                                                      ? theme
                                                          .colorScheme.primary
                                                          .withOpacity(0.15)
                                                      : theme.colorScheme
                                                          .surfaceVariant
                                                          .withOpacity(0.3),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: isLoading
                                                    ? SizedBox(
                                                        width: 28,
                                                        height: 28,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          valueColor:
                                                              AlwaysStoppedAnimation<
                                                                  Color>(
                                                            theme.colorScheme
                                                                .primary,
                                                          ),
                                                        ),
                                                      )
                                                    : Icon(
                                                        isPlaying
                                                            ? Icons
                                                                .pause_rounded
                                                            : Icons
                                                                .play_arrow_rounded,
                                                        size: 28,
                                                        color: isPlaying
                                                            ? theme.colorScheme
                                                                .primary
                                                            : theme.colorScheme
                                                                .onSurface
                                                                .withOpacity(
                                                                    0.7),
                                                      ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      whitenoise.name,
                                                      style: theme
                                                          .textTheme.titleMedium
                                                          ?.copyWith(
                                                        fontWeight: isPlaying
                                                            ? FontWeight.bold
                                                            : FontWeight.w500,
                                                        color: isPlaying
                                                            ? theme.colorScheme
                                                                .primary
                                                            : theme.colorScheme
                                                                .onSurface,
                                                      ),
                                                    ),
                                                    if (isPlaying ||
                                                        isLoading) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        isLoading
                                                            ? 'home.white_noise_loading'
                                                                .tr()
                                                            : 'home.now_playing'
                                                                .tr(),
                                                        style: theme
                                                            .textTheme.bodySmall
                                                            ?.copyWith(
                                                          color: theme
                                                              .colorScheme
                                                              .primary
                                                              .withOpacity(0.8),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              if (isPlaying || isLoading)
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: theme
                                                        .colorScheme.primary
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Text(
                                                    isLoading
                                                        ? 'home.loading'.tr()
                                                        : 'home.playing'.tr(),
                                                    style: theme
                                                        .textTheme.bodySmall
                                                        ?.copyWith(
                                                      color: theme
                                                          .colorScheme.primary,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                    loading: () => const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, stack) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 48,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'home.white_noise_load_failed'.tr(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'home.load_failed_message'.tr(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                ref
                                    .read(whitenoiseProvider.notifier)
                                    .fetchWhiteNoises();
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
                  );
                },
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
