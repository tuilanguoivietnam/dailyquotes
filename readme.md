# Daily Quote Apps Suite

## Introduction

The Daily Quote Apps Suite is a collection of applications focused on daily inspiration and mental well-being, supporting multiple languages, theme switching, white noise, and quote collection.

## App Suite

This repository contains six Flutter-based apps, each focused on a different aspect of daily inspiration and well-being:

| App Directory         | Description                                                                 |
|----------------------|-----------------------------------------------------------------------------|
| frontend/            | **DailyMind**: Main app for daily affirmations, mindfulness, and white noise |
| dailybedtimestories/ | **BedStory**: Bedtime stories for all ages, relaxation & family   |
| dailysutra/          | **DailySutra**: Buddhist wisdom quotes and daily sutras                      |
| dailylovequotes/     | **DailyLove**: Romantic love quotes for daily inspiration              |
| dailyfacts/          | **DailyFacts**: Interesting daily facts and knowledge                        |
| dailybible/          | **DailyBible**: Bible verses and Christian inspiration                       |

Each app is a standalone Flutter project with its own codebase, assets, and build configuration. See each directory's README for details.

## App Store & Google Play Links

| App                  | App Store Link                | Google Play Link             |
|----------------------|-------------------------------|-----------------------------|
| DailyMind            | [App Store](https://apps.apple.com/us/app/dailymind-for-a-better-life/id6745580917) | Coming soon                 |
| BedStory             | Coming soon                   | Coming soon                 |
| DailySutra           | [App Store](https://apps.apple.com/us/app/dailysutra-cultivate-calm/id6747883782) | Coming soon                 |
| DailyLove            | [App Store](https://apps.apple.com/us/app/dailylove-love-sparks/id6747162145) | Coming soon                 |
| DailyFacts           | [App Store](https://apps.apple.com/us/app/dailyfacts-discover-new-info/id6746777421) | Coming soon                 |
| DailyBible           | [App Store](https://apps.apple.com/us/app/dailybible-gods-word-daily/id6746378496) | [Google Play](https://play.google.com/store/apps/details?id=com.civisolo.dailybible&pli=1) |

## Environment Variables

### Backend
Create a `.env` file in the `backend` directory:

```env
MONGODB_URL=mongodb://localhost:27017
OPENAI_API_KEY=your_openai_api_key_here
DOUBAO_APPID=your_doubao_appid_here
DOUBAO_TOKEN=your_doubao_token_here
DOUBAO_API_KEY=your_doubao_api_key_here
APPLE_SHARED_SECRET=your_apple_shared_secret
GOOGLE_SERVICE_ACCOUNT_PROJECT_ID=your_project_id
GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY_ID=your_private_key_id
GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
GOOGLE_SERVICE_ACCOUNT_CLIENT_EMAIL=your_service_account_email
GOOGLE_SERVICE_ACCOUNT_CLIENT_ID=your_client_id
ANDROID_PACKAGE_NAME=com.yourcompany.dailymind
```

### Frontend
Edit `lib/config/api_config.dart` in each app directory:

```dart
class ApiConfig {
  // Set API server address
  static const String baseUrl = 'http://localhost:8000';
}
```

## Getting Started

### Backend
```bash
cd backend
pip install -r requirements.txt
cp env.example .env
# Edit .env with your own keys
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Frontend
```bash
cd frontend
flutter pub get
flutter run
```

## Deployment
See [DEPLOYMENT.md](DEPLOYMENT.md) for full deployment instructions, including Docker and production best practices.

## Security
- **Never commit `.env` or any secret files.**
- All API keys and credentials must be set via environment variables.
- Use HTTPS in production.

## License
MIT
