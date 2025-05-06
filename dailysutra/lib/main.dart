import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'models/affirmation.dart';
import 'models/favorite_affirmation.dart';
import 'models/whitenoise.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'providers/volume_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/font_size_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  await EasyLocalization.ensureInitialized();

  // 只在 iOS 和 Android 平台上初始化 Google Mobile Ads SDK
  if (Platform.isIOS || Platform.isAndroid) {
    await MobileAds.instance.initialize();
  }

  await Hive.initFlutter();

  // 注册 Hive 适配器
  Hive.registerAdapter(AffirmationAdapter());
  Hive.registerAdapter(WhiteNoiseAdapter());
  Hive.registerAdapter(FavoriteAffirmationAdapter());

  // 打开 Hive boxes
  await Hive.openBox<String>('dailysutra_favorites');
  await Hive.openBox<Affirmation>('dailysutra_affirmations');
  await Hive.openBox<WhiteNoise>('dailysutra_whitenoises');
  await Hive.openBox('dailysutra_settings');

  // 初始化网络监听
  final connectivityResult = await Connectivity().checkConnectivity();
  print('Initial network status: $connectivityResult');

  runApp(
    ProviderScope(
      child: EasyLocalization(
        supportedLocales: const [
          Locale('zh'),
          Locale('en'),
          Locale('ja'),
        ],
        path: 'assets/lang',
        fallbackLocale: const Locale('en'),
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const App();
  }
}
