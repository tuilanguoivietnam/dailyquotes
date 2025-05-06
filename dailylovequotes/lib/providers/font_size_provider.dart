import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

enum FontSize {
  small,
  medium,
  large,
}

class FontSizeNotifier extends StateNotifier<FontSize> {
  static const String _key = 'font_size';
  final Box _box;

  FontSizeNotifier(this._box) : super(_loadFontSize(_box));

  static FontSize _loadFontSize(Box box) {
    final value = box.get(_key, defaultValue: 'medium') as String;
    switch (value) {
      case 'small':
        return FontSize.small;
      case 'large':
        return FontSize.large;
      case 'medium':
      default:
        return FontSize.medium;
    }
  }

  Future<void> setFontSize(FontSize size) async {
    state = size;
    await _box.put(_key, size.toString().split('.').last);
  }
}

final fontSizeProvider =
    StateNotifierProvider<FontSizeNotifier, FontSize>((ref) {
  final box = Hive.box('dailylovequotes_settings');
  return FontSizeNotifier(box);
});
