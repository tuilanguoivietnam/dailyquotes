import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/favorites_provider.dart';
import '../providers/affirmation_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import '../providers/theme_provider.dart';

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({Key? key}) : super(key: key);

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  String _searchQuery = '';
  AudioPlayer? _ttsPlayer;
  String? _playingMsg;
  final TextEditingController _searchController = TextEditingController();
  late bool isDark;

  @override
  void initState() {
    super.initState();
    isDark = ref.read(themeProvider) == ThemeMode.dark;
    _ttsPlayer = ref.read(affirmationProvider.notifier).audioPlayer;
    _ttsPlayer?.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playingMsg = null;
        });
      }
    });
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(
        isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark
    );
    _ttsPlayer?.stop();
    _searchController.dispose();
    super.dispose();
  }

  List<String> _filterFavorites(List<String> favorites) {
    return favorites
        .where((msg) => msg.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'favorites.title'.tr(),
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
        elevation: 0,
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
        child: Column(
          children: [
            // 搜索框
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'favorites.search_hint'.tr(),
                  prefixIcon: Icon(
                    Icons.search,
                    color: theme.colorScheme.primary,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            // 收藏列表
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final favorites = ref.watch(favoritesProvider);
                  final filteredFavorites = _filterFavorites(favorites);

                  if (favorites.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_border,
                            size: 80,
                            color: theme.colorScheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'favorites.empty_title'.tr(),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'favorites.empty_subtitle'.tr(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodySmall?.color,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  if (filteredFavorites.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: theme.colorScheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'favorites.no_results'.tr(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredFavorites.length,
                    itemBuilder: (context, index) {
                      final favorite = filteredFavorites[index];
                      final isPlaying = _playingMsg == favorite;

                      return Dismissible(
                        key: Key(favorite),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (direction) {
                          ref
                              .read(favoritesProvider.notifier)
                              .removeFavorite(favorite);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('favorites.deleted'.tr()),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              if (isPlaying) {
                                await _ttsPlayer?.stop();
                                setState(() {
                                  _playingMsg = null;
                                });
                              } else {
                                await _ttsPlayer?.stop();
                                await ref
                                    .read(affirmationProvider.notifier)
                                    .playTTS(favorite);
                                setState(() {
                                  _playingMsg = favorite;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    theme.colorScheme.surface,
                                    theme.colorScheme.surface.withOpacity(0.95),
                                  ],
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      favorite,
                                      style:
                                          theme.textTheme.titleLarge?.copyWith(
                                        height: 1.6,
                                        letterSpacing: 0.3,
                                        fontWeight: FontWeight.w500,
                                        color: theme.colorScheme.onSurface,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isPlaying
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isPlaying
                                                  ? theme.colorScheme.primary
                                                  : theme.colorScheme
                                                      .primaryContainer)
                                              .withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        isPlaying
                                            ? Icons.stop
                                            : Icons.play_arrow,
                                        color: isPlaying
                                            ? theme.colorScheme.onPrimary
                                            : theme.colorScheme.primary,
                                        size: 30,
                                      ),
                                      onPressed: () async {
                                        if (isPlaying) {
                                          await _ttsPlayer?.stop();
                                          setState(() {
                                            _playingMsg = null;
                                          });
                                        } else {
                                          await _ttsPlayer?.stop();
                                          await ref
                                              .read(
                                                  affirmationProvider.notifier)
                                              .playTTS(favorite);
                                          setState(() {
                                            _playingMsg = favorite;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
