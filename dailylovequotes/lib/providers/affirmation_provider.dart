import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../models/affirmation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'volume_provider.dart';
import '../config/api_config.dart';
import 'language_provider.dart';

final affirmationProvider =
    StateNotifierProvider<AffirmationNotifier, AsyncValue<Affirmation?>>((ref) {
  return AffirmationNotifier(ref);
});

class AffirmationNotifier extends StateNotifier<AsyncValue<Affirmation?>> {
  final Ref ref;
  AffirmationNotifier(this.ref) : super(const AsyncValue.data(null));
  final audioPlayer = AudioPlayer();

  String? _lastCategory;

  Future<void> playTTS(String text) async {
    try {
      await audioPlayer.stop();
      final ttsVolume = ref.read(volumeProvider).ttsVolume;
      await audioPlayer.setVolume(ttsVolume);
      String lang = 'zh';
      try {
        lang = ref.read(languageProvider);
        if (lang == 'system' || lang.isEmpty) lang = 'zh';
      } catch (_) {}
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/tts'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/octet-stream',
        },
        body: jsonEncode({'text': text, 'lang': lang}),
      );

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
            '${tempDir.path}/temp_tts_${DateTime.now().millisecondsSinceEpoch}.mp3');

        await tempFile.writeAsBytes(response.bodyBytes);

        await audioPlayer.play(DeviceFileSource(tempFile.path));
      } else {
        throw Exception('获取音频失败: ${response.statusCode}');
      }
    } catch (e) {
      print('TTS播放错误: $e');
      rethrow;
    }
  }

  Future<String> getTTSUrl(String text) async {
    try {
      String lang = 'zh';
      try {
        lang = ref.read(languageProvider);
        if (lang == 'system' || lang.isEmpty) lang = 'zh';
      } catch (_) {}
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/tts'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/octet-stream',
        },
        body: jsonEncode({'text': text, 'lang': lang}),
      );

      if (response.statusCode == 200) {
        final base64Audio = base64Encode(response.bodyBytes);
        return 'data:audio/mp3;base64,$base64Audio';
      } else {
        throw Exception('生成语音失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('生成语音失败: $e');
    }
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }
}
