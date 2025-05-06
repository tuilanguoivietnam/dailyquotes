# DailyBible

## Overview

DailyBible is a mobile app that provides daily Bible verses and Christian inspiration. It helps users reflect, find encouragement, and grow in faith every day.

## Main Features
- Curated daily Bible verses
- Thematic and devotional categories
- Multi-language support (Chinese, English, Japanese)
- Offline reading
- Favorites and sharing
- Simple, uplifting UI

## Tech Stack
- Flutter (cross-platform)
- Riverpod (state management)
- Hive (local storage)
- Easy Localization (i18n)

## Directory Structure
- `lib/` - App code (config, models, pages, providers, services, utils, widgets)
- `assets/` - Fonts, language files, images
- `test/` - Unit and widget tests

## Getting Started
```bash
cd dailybible
flutter pub get
flutter run
```

## API Configuration
The app is configured to connect to a local API server by default:

```dart
// In lib/config/api_config.dart
class ApiConfig {
  // API Base URL
  static const String baseUrl = 'http://localhost:8000';
}
```

Make sure the backend server is running at this address before starting the app.

## App Store & Google Play
- App Store: https://apps.apple.com/us/app/dailybible-gods-word-daily/id6746378496
- Google Play: https://play.google.com/store/apps/details?id=com.civisolo.dailybible&pli=1
