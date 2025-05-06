# DailyBedtimeStories

## Overview

DailyBedtimeStories is a mobile app designed to provide soothing, inspiring, and heartwarming bedtime stories for users of all ages. It helps users relax before sleep, fosters family bonding, and offers a peaceful end to the day.

## Main Features
- Curated daily bedtime stories
- Scene-based categories (age, theme, emotion)
- Multi-language support (Chinese, English, Japanese)
- Offline reading/listening
- Favorites and sharing
- Elegant, relaxing UI

## Tech Stack
- Flutter (cross-platform)
- Riverpod (state management)
- Hive (local storage)
- Easy Localization (i18n)
- just_audio (audio playback)

## Directory Structure
- `lib/` - App code (config, models, pages, providers, services, utils, widgets)
- `assets/` - Fonts, language files, images
- `test/` - Unit and widget tests

## Getting Started
```bash
cd dailybedtimestories
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
- App Store: Coming soon
- Google Play: Coming soon
