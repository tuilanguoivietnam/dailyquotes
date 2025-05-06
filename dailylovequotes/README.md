# DailyLoveQuotes

## Overview

DailyLoveQuotes is a mobile app dedicated to providing romantic love quotes for daily inspiration. It helps users express affection, enhance relationships, and bring more love into everyday life.

## Main Features
- Curated daily love quotes
- Scene-based and emotional categories
- Multi-language support (Chinese, English, Japanese)
- Offline reading
- Favorites and sharing
- Elegant, romantic UI

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
cd dailylovequotes
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
- App Store: https://apps.apple.com/us/app/dailylove-love-sparks/id6747162145 
- Google Play: Coming soon
