# DailySutra

## Overview

DailySutra is a mobile app focused on delivering daily Buddhist wisdom quotes and sutras. It helps users find inner peace and inspiration in their daily lives.

## Main Features
- Curated daily Buddhist quotes and sutras
- Scene-based and emotional categories
- Multi-language support (Chinese, English, Japanese)
- Offline reading
- Favorites and sharing
- Elegant, tranquil UI

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
cd dailysutra
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
- App Store: https://apps.apple.com/us/app/dailysutra-cultivate-calm/id6747883782
- Google Play: Coming soon
