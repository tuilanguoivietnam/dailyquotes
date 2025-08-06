# Daily Quote Apps Suite

## Introduction

The Daily Quote Apps Suite is a diverse collection of applications covering various aspects of daily life, including mindfulness, relationships, knowledge, spirituality, and entertainment. Our apps support multiple languages, theme switching, content collection, and more. This suite is designed to enrich users' daily experiences through inspirational quotes, educational content, romantic messages, bedtime stories, spiritual guidance, and relaxation techniques.


<div align="center">
  <img src="screenshots/0x0ss (1).png" alt="App Screenshot 1" width="200"/>
  <img src="screenshots/0x0ss (2).png" alt="App Screenshot 2" width="200"/>
  <img src="screenshots/0x0ss (3).png" alt="App Screenshot 3" width="200"/>
  <img src="screenshots/0x0ss (5).png" alt="App Screenshot 4" width="200"/>
</div>

## App Suite

This repository contains six Flutter-based apps, each focused on a different aspect of daily life enrichment. Our diverse collection includes apps for mental well-being, relationship enhancement, knowledge acquisition, spiritual growth, family bonding, and relaxation:

| App Directory         | Description                                                                 |
|----------------------|-----------------------------------------------------------------------------|
| frontend/            | **DailyMind**: Main app for daily affirmations, mindfulness, and white noise for relaxation and mental well-being |
| dailybedtimestories/ | **BedStory**: Soothing bedtime stories for all ages, promoting relaxation, better sleep quality, and family bonding   |
| dailysutra/          | **DailySutra**: Buddhist wisdom quotes and daily sutras for inner peace, mindfulness practice, and spiritual growth                      |
| dailylovequotes/     | **DailyLove**: Romantic love quotes for relationship inspiration, emotional connection, and expressing affection              |
| dailyfacts/          | **DailyFacts**: Fascinating daily facts and knowledge to spark curiosity, expand horizons, and encourage lifelong learning                        |
| dailybible/          | **DailyBible**: Daily Bible verses and Christian inspiration for spiritual reflection, faith development, and daily encouragement                       |

Each app is a standalone Flutter project with its own codebase, assets, and build configuration. See each directory's README for details.

## Featured Apps

### DailyMind

DailyMind is our flagship application designed to help users cultivate a positive mindset and improve mental well-being through daily practice. It offers:

- **Daily Affirmations**: Positive statements to boost self-esteem and change negative thought patterns
- **Mindfulness Exercises**: Guided practices to help users stay present and reduce stress
- **White Noise & Relaxation Sounds**: Calming audio to aid sleep, meditation, and focus
- **Multi-language Support**: Available in English, Chinese, and Japanese
- **Customizable Themes**: Light and dark mode with various color options
- **Quote Collection**: Save and organize your favorite inspirational quotes
- **Daily Notifications**: Gentle reminders to practice mindfulness throughout the day

DailyMind is perfect for anyone looking to reduce anxiety, improve focus, practice gratitude, and develop a more positive outlook on life.

### BedStory

BedStory provides soothing and heartwarming bedtime stories for users of all ages, helping to create a peaceful end to the day:

- **Curated Daily Stories**: New, carefully selected stories every day
- **Age and Theme Categories**: Stories organized by age group and themes
- **Emotional Categories**: Stories that match your mood or desired emotional state
- **Multi-language Support**: Available in English, Chinese, and Japanese
- **Favorites and Sharing**: Save and share your favorite stories
- **Elegant, Relaxing UI**: Designed for a calming bedtime experience

BedStory is ideal for parents looking to bond with children, adults seeking better sleep quality, and anyone who enjoys the comfort of a good story before bed.

### DailySutra

DailySutra focuses on delivering Buddhist wisdom quotes and sutras to help users find inner peace and spiritual growth:

- **Daily Buddhist Quotes**: Carefully selected wisdom from Buddhist teachings
- **Sutra Collections**: Access to important Buddhist sutras and teachings
- **Scene-based Categories**: Quotes organized by life situations and needs
- **Emotional Support**: Wisdom tailored to different emotional states
- **Multi-language Support**: Available in English, Chinese, and Japanese
- **Favorites and Sharing**: Save and share meaningful quotes
- **Tranquil UI Design**: Peaceful interface that promotes calm reflection

DailySutra is perfect for Buddhist practitioners, meditation enthusiasts, and anyone seeking spiritual wisdom and inner peace.

### DailyLove

DailyLove provides romantic love quotes to inspire relationships and help express affection:

- **Daily Love Quotes**: Fresh romantic inspiration every day
- **Relationship Categories**: Quotes for different relationship stages and situations
- **Emotional Categories**: Express specific feelings and sentiments
- **Multi-language Support**: Available in English, Chinese, and Japanese
- **Favorites and Sharing**: Save and share quotes with loved ones
- **Romantic UI Design**: Beautiful interface designed to evoke feelings of love

DailyLove is ideal for couples looking to strengthen their bond, individuals seeking to express their feelings, and romantics who appreciate the poetry of love.

### DailyFacts

DailyFacts delivers interesting and educational facts to expand knowledge and spark curiosity:

- **Daily Interesting Facts**: Learn something new every day
- **Thematic Categories**: Facts organized by subjects like science, history, nature
- **Multi-language Support**: Available in English, Chinese, and Japanese
- **Favorites and Sharing**: Save and share fascinating facts
- **Clean, Engaging UI**: Designed to make learning enjoyable

DailyFacts is perfect for curious minds, lifelong learners, and anyone who enjoys expanding their knowledge in an accessible, bite-sized format.

### DailyBible

DailyBible provides daily Bible verses and Christian inspiration for spiritual growth:

- **Daily Bible Verses**: Scripture selected for daily reflection
- **Thematic Collections**: Verses organized by themes and life situations
- **Devotional Categories**: Structured spiritual guidance
- **Multi-language Support**: Available in English, Chinese, and Japanese
- **Favorites and Sharing**: Save and share meaningful verses
- **Simple, Uplifting UI**: Designed for focused spiritual reflection

DailyBible is ideal for Christians seeking daily spiritual nourishment, those exploring faith, and anyone looking for biblical wisdom and encouragement.

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

## Contributing

We welcome contributions from the community! Whether you're fixing bugs, adding new features, improving documentation, or spreading the word, your help is appreciated.

Please check out our [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to this project.

## Community & Support

- If you find this project helpful, please consider giving it a star ⭐
- Share these apps with friends and family who might benefit from daily inspiration
- For issues, feature requests, or questions, please open an issue in this repository

## Keywords

### General Keywords
Mindfulness, Meditation, Mental Health, Well-being, Relaxation, Positive Thinking, Self-improvement, Stress Relief, Anxiety Management, Flutter Apps, Cross-platform, Mobile Apps, Inspirational Quotes

### DailyMind
Daily Affirmations, Mindfulness Exercises, White Noise, Relaxation Sounds, Positive Affirmations, Mental Well-being, Meditation Aid, Focus Improvement, Gratitude Practice

### BedStory
Bedtime Stories, Sleep Aid, Family Bonding, Relaxation Stories, Children Stories, Bedtime Routine, Sleep Quality, Soothing Narratives, Nighttime Relaxation

### DailySutra
Buddhist Wisdom, Daily Sutras, Spiritual Growth, Inner Peace, Buddhist Teachings, Mindfulness Practice, Meditation Support, Spiritual Quotes, Eastern Philosophy

### DailyLove
Love Quotes, Romantic Inspiration, Relationship Advice, Expressing Affection, Romantic Messages, Couple Communication, Love Language, Relationship Building, Romantic Gestures

### DailyFacts
Interesting Facts, Daily Knowledge, Educational Content, Curiosity, Learning, Trivia, Knowledge Expansion, Fun Facts, Intellectual Stimulation

### DailyBible
Bible Verses, Christian Inspiration, Daily Scripture, Spiritual Growth, Faith Development, Biblical Wisdom, Christian Devotional, Prayer Support, Religious Guidance

## License
MIT
