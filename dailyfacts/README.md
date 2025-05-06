# DailyFacts

## Overview

DailyFacts is a mobile app that delivers interesting and educational facts every day. It helps users expand their knowledge, spark curiosity, and have fun learning new things.

## Main Features
- Curated daily facts
- Thematic categories
- Multi-language support (Chinese, English, Japanese)
- Offline reading
- Favorites and sharing
- Clean, engaging UI

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
cd dailyfacts
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
- App Store: https://apps.apple.com/us/app/dailyfacts-discover-new-info/id6746777421
- Google Play: Coming soon
