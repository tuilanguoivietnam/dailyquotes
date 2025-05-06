import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:hive_flutter/hive_flutter.dart';

final colorSchemeProvider =
    StateNotifierProvider<ColorSchemeNotifier, FlexScheme>((ref) {
  return ColorSchemeNotifier();
});

class ColorSchemeNotifier extends StateNotifier<FlexScheme> {
  ColorSchemeNotifier() : super(FlexScheme.blueM3) {
    _initState();
  }

  static const String _boxName = 'dailyfacts_theme';
  static const String _key = 'colorScheme';

  Future<void> _initState() async {
    final box = await Hive.openBox<String>(_boxName);
    final savedScheme = box.get(_key);
    if (savedScheme != null) {
      state = FlexScheme.values.firstWhere(
        (scheme) => scheme.name == savedScheme,
        orElse: () => FlexScheme.blueM3,
      );
    }
  }

  Future<void> setColorScheme(FlexScheme scheme) async {
    final box = await Hive.openBox<String>(_boxName);
    await box.put(_key, scheme.name);
    state = scheme;
  }

  ThemeData getLightTheme() {
    return FlexThemeData.light(
      scheme: state,
      useMaterial3: true,
    );
  }

  ThemeData getDarkTheme() {
    return FlexThemeData.dark(
      scheme: state,
      useMaterial3: true,
    );
  }
}
