import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final volumeProvider =
    StateNotifierProvider<VolumeNotifier, VolumeSettings>((ref) {
  return VolumeNotifier();
});

class VolumeSettings {
  final double ttsVolume;
  final double whiteNoiseVolume;

  const VolumeSettings({
    this.ttsVolume = 0.5,
    this.whiteNoiseVolume = 0.5,
  });

  VolumeSettings copyWith({
    double? ttsVolume,
    double? whiteNoiseVolume,
  }) {
    return VolumeSettings(
      ttsVolume: ttsVolume ?? this.ttsVolume,
      whiteNoiseVolume: whiteNoiseVolume ?? this.whiteNoiseVolume,
    );
  }
}

class VolumeNotifier extends StateNotifier<VolumeSettings> {
  static const _boxName = 'dailyfacts_volume_settings';
  static const _defaultTtsVolume = 1.0;
  static const _defaultWhiteNoiseVolume = 0.5;

  VolumeNotifier()
      : super(const VolumeSettings(
          ttsVolume: _defaultTtsVolume,
          whiteNoiseVolume: _defaultWhiteNoiseVolume,
        )) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final box = await Hive.openBox<Map>(_boxName);
      final settings = box.get('settings');
      if (settings != null) {
        state = VolumeSettings(
          ttsVolume: settings['ttsVolume'] ?? _defaultTtsVolume,
          whiteNoiseVolume:
              settings['whiteNoiseVolume'] ?? _defaultWhiteNoiseVolume,
        );
      }
    } catch (e) {
      print('Error loading volume settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final box = await Hive.openBox<Map>(_boxName);
      await box.put('settings', {
        'ttsVolume': state.ttsVolume,
        'whiteNoiseVolume': state.whiteNoiseVolume,
      });
    } catch (e) {
      print('Error saving volume settings: $e');
    }
  }

  void setTTSVolume(double volume) {
    state = state.copyWith(ttsVolume: volume);
    _saveSettings();
  }

  void setWhiteNoiseVolume(double volume) {
    state = state.copyWith(whiteNoiseVolume: volume);
    _saveSettings();
  }
}
