import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:dailystory/pages/subscription_page.dart';
import 'pages/home_page.dart';
import 'widgets/gesture_guide.dart';
import 'providers/guide_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/color_scheme_provider.dart';
import 'providers/connectivity_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showGuide = ref.watch(guideProvider);
    final themeMode = ref.watch(themeProvider);
    final colorScheme = ref.watch(colorSchemeProvider);

    // 初始化网络监听
    ref.listen(connectivityProvider, (previous, next) {
      next.whenData((connectivityResult) {
        print('Network status changed: $connectivityResult');
      });
    });

    final lightTheme = FlexThemeData.light(
      scheme: colorScheme,
      useMaterial3: true,
      appBarBackground: FlexThemeData.light(scheme: colorScheme).primaryColor,
      tooltipsMatchBackground: true,
      subThemesData: const FlexSubThemesData(
        interactionEffects: true,
        tintedDisabledControls: true,
        blendOnColors: true,
        useTextTheme: true,
        defaultRadius: 16,
        elevatedButtonSchemeColor: SchemeColor.primary,
        outlinedButtonSchemeColor: SchemeColor.primary,
        toggleButtonsSchemeColor: SchemeColor.primary,
        segmentedButtonSchemeColor: SchemeColor.primary,
        bottomNavigationBarSelectedLabelSchemeColor: SchemeColor.primary,
        bottomNavigationBarSelectedIconSchemeColor: SchemeColor.primary,
        navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
        navigationBarSelectedIconSchemeColor: SchemeColor.primary,
        navigationRailSelectedLabelSchemeColor: SchemeColor.primary,
        navigationRailSelectedIconSchemeColor: SchemeColor.primary,
      ),
    );

    final darkTheme = FlexThemeData.dark(
      scheme: colorScheme,
      useMaterial3: true,
      appBarBackground: FlexThemeData.dark(scheme: colorScheme).primaryColor,
      tooltipsMatchBackground: true,
      subThemesData: const FlexSubThemesData(
        interactionEffects: true,
        tintedDisabledControls: true,
        blendOnColors: true,
        useTextTheme: true,
        defaultRadius: 16,
        elevatedButtonSchemeColor: SchemeColor.primary,
        outlinedButtonSchemeColor: SchemeColor.primary,
        toggleButtonsSchemeColor: SchemeColor.primary,
        segmentedButtonSchemeColor: SchemeColor.primary,
        bottomNavigationBarSelectedLabelSchemeColor: SchemeColor.primary,
        bottomNavigationBarSelectedIconSchemeColor: SchemeColor.primary,
        navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
        navigationBarSelectedIconSchemeColor: SchemeColor.primary,
        navigationRailSelectedLabelSchemeColor: SchemeColor.primary,
        navigationRailSelectedIconSchemeColor: SchemeColor.primary,
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'app.name'.tr(),
      themeMode: themeMode,
      theme: lightTheme,
      darkTheme: darkTheme,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: Stack(
        children: [
          const HomePage(),
          if (showGuide) const GestureGuide(),
        ],
      ),
      routes: {
        '/subscription': (context) => const SubscriptionPage(),
      },
    );
  }
}
