import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/whitenoise.dart';
import '../services/storage_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:hive/hive.dart';
import 'volume_provider.dart';
import '../config/api_config.dart';
import 'package:flutter/widgets.dart';

final whitenoiseProvider =
    StateNotifierProvider<WhiteNoiseNotifier, AsyncValue<List<WhiteNoise>>>(
        (ref) {
  return WhiteNoiseNotifier(ref);
});

class WhiteNoiseNotifier extends StateNotifier<AsyncValue<List<WhiteNoise>>> {
  final Ref ref;
  late final LifecycleEventHandler _lifecycleHandler;

  WhiteNoiseNotifier(this.ref) : super(const AsyncValue.loading()) {
    // 初始化生命周期处理器
    _lifecycleHandler = LifecycleEventHandler(
      resumeCallBack: _onAppResume,
      pauseCallBack: _onAppPause,
    );

    // 设置播放状态监听
    audioPlayer.onPlayerStateChanged.listen((playerState) {
      _isPlaying = playerState == PlayerState.playing;
      _updateState();
    });

    audioPlayer.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _currentPlayingId = null;
      _updateState();
    });

    // 添加应用生命周期监听
    _setupAppLifecycleListener();
  }

  static const _lastWhiteNoiseKey = 'last_whitenoise_id';
  static const _prefsBox = 'app_prefs';
  final audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _currentPlayingId;
  String? _currentLoadingId;
  List<WhiteNoise>? _whitenoises;
  File? _currentAudioFile;
  Set<String> _loadingIds = {};
  bool _wasPlayingBeforePause = false;

  bool isPlaying(String id) => _isPlaying && _currentPlayingId == id;
  bool isLoading(String id) => _loadingIds.contains(id);

  void _updateState() {
    if (_whitenoises != null) {
      state = AsyncValue.data(_whitenoises!);
    }
  }

  void _setupAppLifecycleListener() {
    WidgetsBinding.instance.addObserver(_lifecycleHandler);
  }

  Future<void> _onAppResume() async {
    // 应用恢复时，重新检查播放状态
    if (_currentPlayingId != null) {
      final playerState = await audioPlayer.state;
      _isPlaying = playerState == PlayerState.playing;
      if (_wasPlayingBeforePause && !_isPlaying) {
        // 如果之前在播放，但现在停止了，尝试恢复播放
        try {
          await audioPlayer.resume();
          _isPlaying = true;
        } catch (e) {
          print('恢复播放失败: $e');
          _isPlaying = false;
          _currentPlayingId = null;
        }
      }
      _updateState();
    }
  }

  Future<void> _onAppPause() async {
    // 记录应用暂停时的播放状态
    if (_currentPlayingId != null) {
      _wasPlayingBeforePause = _isPlaying;
      if (_isPlaying) {
        try {
          // 暂停播放
          await audioPlayer.pause();
          _isPlaying = false;
          _updateState();
        } catch (e) {
          print('暂停播放失败: $e');
          _isPlaying = false;
          _currentPlayingId = null;
          _updateState();
        }
      }
    }
  }

  Future<void> toggleWhiteNoise(String id) async {
    try {
      // 记忆本次选择
      final box = await Hive.openBox(_prefsBox);
      await box.put(_lastWhiteNoiseKey, id);

      // 切换加载ID，后续只处理最新点击的ID
      _currentLoadingId = id;

      // 如果当前正在播放的就是这个id，则停止播放
      if (_currentPlayingId == id && _isPlaying) {
        await audioPlayer.stop();
        _isPlaying = false;
        _currentPlayingId = null;
        _updateState();
        return;
      }

      // 播放新白噪音前，先停止所有播放
      if (_isPlaying) {
        await audioPlayer.stop();
        _isPlaying = false;
        _currentPlayingId = null;
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // 设置加载状态
      _loadingIds.clear();
      _loadingIds.add(id);
      _updateState();

      final url = '${ApiConfig.baseUrl}/api/whitenoises/$id/audio';
      // 检查是否已被新点击打断
      if (_currentLoadingId != id) {
        _loadingIds.remove(id);
        _updateState();
        return;
      }

      // 设置为循环播放
      await audioPlayer.setReleaseMode(ReleaseMode.loop);
      // 设置音量
      final whiteNoiseVolume = ref.read(volumeProvider).whiteNoiseVolume;
      await audioPlayer.setVolume(whiteNoiseVolume);

      // 1. 优先检查本地缓存
      final tempDir = await getTemporaryDirectory();
      final cacheFile = File('${tempDir.path}/whitenoise_${id}.mp3');
      if (await cacheFile.exists()) {
        _currentAudioFile = cacheFile;
        _currentPlayingId = id;
        await audioPlayer.play(DeviceFileSource(cacheFile.path));
        _isPlaying = true;
        _updateState();
        _loadingIds.remove(id);
        return;
      }

      // 2. 先尝试流媒体播放
      try {
        await audioPlayer.play(UrlSource(url));
        _currentPlayingId = id;
        _isPlaying = true;
        _updateState();
      } catch (e) {
        print('流媒体播放失败，尝试本地下载并缓存: $e');
        // 自动回退为本地播放并缓存
        try {
          final response =
              await http.get(Uri.parse(url), headers: {'Accept': 'audio/mpeg'});
          if (response.statusCode == 200) {
            await cacheFile.writeAsBytes(response.bodyBytes);
            _currentAudioFile = cacheFile;
            _currentPlayingId = id;
            await audioPlayer.play(DeviceFileSource(cacheFile.path));
            _isPlaying = true;
            _updateState();
          } else {
            throw Exception('获取白噪音失败: ${response.statusCode}');
          }
        } catch (e2) {
          print('本地播放也失败: $e2');
          _isPlaying = false;
          _currentPlayingId = null;
        }
      }
    } catch (e) {
      print('白噪音播放错误: $e');
      _isPlaying = false;
      _currentPlayingId = null;
      rethrow;
    } finally {
      // 清除加载状态
      _loadingIds.remove(id);
      _updateState();
    }
  }

  Future<void> stopWhiteNoise() async {
    await audioPlayer.stop();
    _currentPlayingId = null;
    _isPlaying = false;
    _wasPlayingBeforePause = false;
    _updateState();
  }

  void setWhiteNoises(List<WhiteNoise> whitenoises) {
    _whitenoises = whitenoises;
    state = AsyncValue.data(whitenoises);
  }

  Future<void> fetchWhiteNoises() async {
    try {
      state = const AsyncValue.loading();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/whitenoises'),
        headers: {
          'Accept': 'application/json; charset=utf-8',
        },
      );

      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> data = jsonDecode(responseBody);
        final whitenoises =
            data.map((json) => WhiteNoise.fromJson(json)).toList();

        // 保存到本地存储
        await StorageService.saveWhiteNoises(whitenoises);

        _whitenoises = whitenoises;
        state = AsyncValue.data(whitenoises);

        // 自动播放上次选择的白噪音
        final box = await Hive.openBox(_prefsBox);
        final lastId = box.get(_lastWhiteNoiseKey);
        if (lastId != null && whitenoises.any((w) => w.id == lastId)) {
          await toggleWhiteNoise(lastId);
        }

        // 新增：首次自动播放第一条白噪音
        await playFirstIfNeeded();
      } else {
        throw Exception('获取白噪音列表失败');
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<String> getWhiteNoiseUrl(String id) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/whitenoises/$id/audio'),
        headers: {
          'Accept': 'application/octet-stream',
        },
      );

      if (response.statusCode == 200) {
        final base64Audio = base64Encode(response.bodyBytes);
        return 'data:audio/mp3;base64,$base64Audio';
      } else {
        throw Exception('获取白噪音失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取白噪音失败: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleHandler);
    audioPlayer.dispose();
    _cleanupTempFile();
    super.dispose();
  }

  // 清理临时文件
  Future<void> _cleanupTempFile() async {
    try {
      if (_currentAudioFile != null && await _currentAudioFile!.exists()) {
        await _currentAudioFile!.delete();
        _currentAudioFile = null;
      }
    } catch (e) {
      print('清理临时文件失败: $e');
    }
  }

  Future<void> playFirstIfNeeded() async {
    final box = await Hive.openBox(_prefsBox);
    final hasPlayed = box.get('hasPlayedFirstWhiteNoise', defaultValue: false);
    if (hasPlayed == true) return;
    if (_whitenoises != null && _whitenoises!.isNotEmpty) {
      final first = _whitenoises!.first;
      await toggleWhiteNoise(first.id);
      await box.put('hasPlayedFirstWhiteNoise', true);
    }
  }
}

// 添加应用生命周期监听类
class LifecycleEventHandler extends WidgetsBindingObserver {
  final Future<void> Function()? resumeCallBack;
  final Future<void> Function()? pauseCallBack;

  LifecycleEventHandler({
    this.resumeCallBack,
    this.pauseCallBack,
  });

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await resumeCallBack?.call();
    } else if (state == AppLifecycleState.paused) {
      await pauseCallBack?.call();
    }
  }
}
