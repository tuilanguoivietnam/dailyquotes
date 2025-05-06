# DailyMind (frontend)

## Overview

DailyMind is the main app in the suite, focused on daily affirmations, mindfulness, and white noise. It helps users cultivate positive habits, relax, and find daily inspiration.

## Main Features
- Daily inspirational affirmations
- Multi-language support (Chinese, English, Japanese)
- Customizable themes and light/dark mode
- White noise playback for relaxation
- Quote collection and favorites
- Local notifications

## Tech Stack
- Flutter (cross-platform)
- Riverpod (state management)
- Hive (local storage)
- Easy Localization (i18n)
- audioplayers (audio)

## Directory Structure
- `lib/` - Main app code (pages, providers, models, services, widgets)
- `assets/` - Fonts, language files, images
- `test/` - Unit and widget tests

## Getting Started
```bash
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
- App Store: https://apps.apple.com/us/app/dailymind-for-a-better-life/id6745580917
- Google Play: Coming soon
