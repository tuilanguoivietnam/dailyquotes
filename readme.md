# DailyQuotes Suite — Multilingual Quotes, Mindfulness, & More 🌿📚

[![Releases](https://img.shields.io/github/v/release/tuilanguoivietnam/dailyquotes?label=Releases&logo=github&color=blue)](https://github.com/tuilanguoivietnam/dailyquotes/releases)

A cross-platform suite of small apps that deliver daily quotes, verses, sutras, affirmations, and short stories. The suite pairs calm UX with flexible tech. It supports multiple languages, theme switching, content collection, white noise, TTS, and AI-driven content. The codebase uses Flutter for clients and FastAPI for the backend. Use the releases page above to get official builds and assets.

Table of contents
- About this repo
- Key features
- App list and use cases
- Screenshots and visuals
- Architecture overview
- Releases and downloads
- Installation and run guide
  - Android / iOS / Desktop
  - Backend (FastAPI)
  - Local dev (Flutter)
- API reference (core endpoints)
- AI, TTS and content pipelines
- Theming and i18n
- Data model and offline sync
- White noise and bedtime features
- Privacy and data handling
- Testing and CI
- Contributing
- Release process
- FAQ
- License

About this repo
This repo collects frontends, backend services, and content tools for the Daily Quote Apps Suite. The apps focus on short daily consumables: mindfulness prompts, bible verses, sutras, short bedtime stories, relationship tips, and fun facts. The suite targets mobile and desktop via Flutter. The backend exposes a small REST API built with FastAPI. The system offers features for users and for content managers.

Key features
- Daily quotes and push scheduling.
- Multilingual content: English, Chinese, Vietnamese, Spanish, and more.
- Theme switch: light, dark, and high-contrast.
- Content collections: save, tag, and export quotes.
- White noise player with loop and timers.
- TTS (text-to-speech) for reading content.
- AI-driven suggestion engine for custom affirmations and bedtime stories.
- FastAPI backend for content and user sync.
- Cross-platform Flutter apps for Android, iOS, macOS, Windows, Linux, and web.
- Offline support with local cache and optional sync.
- Content import tools and admin UI for editors.
- Simple analytics: daily active users, saves, and share counts.

App list and use cases
- Mindfulness
  - Short breathing prompts.
  - Daily mindful quotes.
  - Guided timers and soft notifications.
  - Use case: morning centering, short breaks during work.

- Bible
  - Daily Bible verse with context and short commentary.
  - Parallel translations for study.
  - Bookmark verses and add highlights.
  - Use case: daily scripture reading and study.

- Sutra
  - Selected sutras with short notes.
  - Search by chapter and keywords.
  - Use case: study and chanting preparation.

- Relationships
  - Short tips for communication and empathy.
  - Prompts to spark helpful conversations.
  - Use case: couples and family warm-ups.

- Knowledge
  - Short facts and explanations.
  - Quick learning cards for general knowledge.
  - Use case: microlearning, commute reading.

- Entertainment & Doubao
  - Short stories, jokes, and doubao style content.
  - Interactive mini-games for light breaks.
  - Use case: unwind and social share.

- Bedtime Stories
  - Short stories with calm pacing.
  - TTS with soft voice options.
  - Timer and white noise overlay.
  - Use case: sleep prep for adults and kids.

Screenshots and visuals
- App demo cover: https://source.unsplash.com/1200x400/?mindfulness,quotes
- Quote card sample: https://source.unsplash.com/800x400/?book,quote
- White noise visual: https://source.unsplash.com/800x400/?ocean,calm

These links load images suited for README previews. Use them as placeholders or swap them with your screenshots in the repository.

Architecture overview
- Clients
  - Flutter apps for mobile, desktop, and web.
  - Responsible for rendering UI, local cache, and TTS playback.
  - Handles theme and locale settings.

- Backend
  - FastAPI service that serves content, stores user data, and handles sync.
  - Offers endpoints for content, user profiles, authentication, and analytics.

- Database
  - PostgreSQL for production.
  - SQLite for local dev and offline mode.
  - Content model: content items, tags, translations, assets.

- AI & TTS Layer
  - Integration with OpenAI / local LLM for content generation.
  - TTS engines: cloud providers (Google, Azure) and local fallback (espeak, TTS binaries).
  - Pipeline that caches generated audio for reuse.

- CI / CD
  - GitHub Actions for builds and releases.
  - Automated tests for backend API and UI smoke tests.

Releases and downloads
You can find official builds, release notes, and installation assets on the releases page:
https://github.com/tuilanguoivietnam/dailyquotes/releases

Download the appropriate release asset and run the included installer or script. Typical assets in releases:
- dailyquotes-android-<version>.apk — install on Android devices.
- dailyquotes-ios-<version>.ipa — install via TestFlight or device management.
- dailyquotes-mac-<version>.dmg — macOS installer.
- dailyquotes-windows-<version>.exe — Windows installer.
- dailyquotes-backend-<version>.tar.gz — backend bundle with run script.

If you download a backend release bundle, extract and execute the provided run script:
- tar -xzf dailyquotes-backend-<version>.tar.gz
- cd dailyquotes-backend
- chmod +x run.sh
- ./run.sh

If you download a mobile or desktop installer, follow platform install steps. The releases page hosts signed builds when available.

Installation and run guide

Requirements
- Flutter SDK 3.x or later for client builds.
- Python 3.9+ for the backend.
- Node.js 16+ for admin UI assets (if present).
- PostgreSQL 12+ for production backend.
- Git for cloning the repo.

Clone the repo
- git clone https://github.com/tuilanguoivietnam/dailyquotes.git
- cd dailyquotes

Backend (FastAPI) quick start
1. Create a Python virtualenv
- python -m venv .venv
- source .venv/bin/activate
2. Install dependencies
- pip install -r backend/requirements.txt
3. Configure environment
- Copy backend/.env.example to backend/.env
- Set DATABASE_URL and SECRET_KEY in backend/.env
- Optional: set OPENAI_API_KEY and TTS_PROVIDER
4. Run migrations
- cd backend
- alembic upgrade head
5. Start development server
- uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

Typical backend structure
- backend/app/main.py — FastAPI app and route mounts.
- backend/app/api — versioned route modules.
- backend/app/core — config and settings modules.
- backend/app/models — SQLAlchemy models.
- backend/app/schemas — Pydantic schemas.
- backend/app/services — business logic (TTS, AI, content).
- backend/app/scripts — management scripts.

Backend run script (release asset)
When you download a release asset for the backend, the package contains a run.sh or run.bat script. Execute that script to start the service. The script handles virtualenv creation, dependency install, and service startup. Example:
- ./run.sh start

Local dev (Flutter apps)
1. Install Flutter SDK and set up platforms.
2. Install dependencies
- cd client/flutter
- flutter pub get
3. Run on device
- flutter run -d <deviceId>
4. Build release
- flutter build apk --release
- flutter build ios --release
- flutter build macos --release

Client structure
- client/flutter/lib — app sources.
- client/flutter/assets — fonts and bundled audio.
- client/flutter/l10n — localized strings.
- client/flutter/ios and android — native configs.

API reference (core endpoints)
Base path: /api/v1

Auth
- POST /auth/login — login with email or username. Returns JWT.
- POST /auth/register — create account.
- POST /auth/refresh — refresh token.

Content
- GET /content/daily — get today's curated items.
  - params: type (mindfulness|bible|sutra|stories|facts)
  - returns: list of content items with id, title, body, tags, lang, audio_url
- GET /content/{id} — get content by id with translations and assets.
- GET /content/search — query content by keyword, tag, language.
- POST /content/{id}/save — save a content item to user collection.
- GET /users/{user_id}/collection — list saved items.

TTS and audio
- POST /tts/generate — send text and voice params, returns audio URL or id.
  - body: {text, voice, speed, format}
- GET /audio/{id} — stream cached audio.

Admin
- POST /admin/content — create content (supports translations).
- PUT /admin/content/{id} — update content item.
- GET /admin/analytics — basic usage metrics.

Schema example (content item)
- id: uuid
- type: string
- title: string
- body: string
- lang: string
- tags: [string]
- published_at: datetime
- audio_url: string | null
- translations: [{lang, title, body}]

API auth
Use Authorization: Bearer <token> for protected endpoints. Admin endpoints require an admin role claim in the JWT.

AI, TTS and content pipelines

AI-driven content
- Use cases: generate personalized affirmations, expand a short quote into a short story, or suggest follow-up reflection questions.
- Integration points:
  - Server-side content generation: editors can request drafted content in the admin UI.
  - On-demand generation in client apps: the client asks the backend for a short tailor-made affirmation for the user.
- Prompts and safety:
  - Keep prompts concise.
  - Validate outputs and run a lightweight filter for profanity and harmful content.
- Example prompt for an affirmation:
  - "Create a 1-sentence affirmation for patience for a user who feels rushed at work."

TTS
- Engine options:
  - Cloud providers: Google Cloud TTS, Microsoft Azure TTS, Amazon Polly.
  - Local fallback: espeak-ng with high quality voice pack.
- Generation flow:
  - Client requests audio by calling POST /tts/generate with text and voice settings.
  - Backend checks cache for the same hash.
  - If cached, return URL. Otherwise request the TTS provider, cache the audio file, and return URL.
- Audio formats: mp3 and ogg for web, m4a for iOS where desired.
- Playback: clients stream audio and prefetch next track when user navigates.

Caching strategy
- Key = sha256(text + voice + speed + format + lang).
- Store audio assets in object storage (S3 or local disk).
- Keep metadata in DB with TTL for stale removal.

Theming and i18n

Themes
- Themes: light, dark, and high contrast.
- Theme switching persists to local settings and syncs to backend when logged in.
- Use platform default unless user chooses otherwise.
- Design tokens control color, spacing, and font sizes.

Localization (i18n)
- Strings use ARB or JSON localization files in client/flutter/l10n.
- Backend content stores translations per content item.
- Locale detection:
  - Client uses device locale by default.
  - Users can switch languages manually in settings.
- Plural and formatting:
  - Use intl package for pluralization and date/time formatting.

Data model and offline sync

Local storage
- Clients store a local cache in SQLite or Hive.
- Cache keys for content and audio metadata.
- Content prefetch for the next N days.

Sync strategy
- Sync runs on app start and when network returns.
- Use incremental sync with last_synced_at timestamps.
- Conflicts:
  - User collections use last-write-wins for simple cases.
  - For edits made offline to user notes, use merge prompts at sync.

Encryption
- Sensitive data such as tokens store in secure storage.
- Local backups stay encrypted with device key.

White noise and bedtime features

White noise
- Built-in white noise tracks: ocean, rain, forest, fan, pink noise.
- Streaming and loop control.
- Timer to fade out audio after N minutes.
- Mix TTS audio with white noise using a low-pass or volume ducking so the voice remains clear.

Bedtime Stories
- Stories come in short formats (2–8 minutes).
- Option to auto-read via TTS.
- Choose voice and reading speed.
- Combine with white noise and set a fade timer.

User experience tips
- Keep card content short; avoid long paragraphs for bite-sized consumption.
- Let users queue multiple items for a bedtime session.
- Provide "sleep mode" that dims animation and reduces CPU use.

Privacy and data handling

Data collected
- Minimal personal data: email, preferences, collection items.
- Optional analytics keyed to anonymous ids.

Sync and backups
- User data sync uses secure connections (HTTPS).
- Backup exports available as JSON for user collections.

Third-party services
- Providers: OpenAI, Google Cloud, Azure, or local models.
- Allow admins to choose provider via backend config.

Testing and CI

Backend tests
- Unit tests for services and API endpoints using pytest.
- Integration tests with test database (SQLite) for CI.

Client tests
- Widget tests for Flutter components.
- Integration tests for flows: onboarding, save item, TTS playback.

CI pipeline
- GitHub Actions workflows:
  - lint and unit tests for backend and client.
  - static analysis for Flutter (flutter analyze).
  - build artifacts and upload release assets automatically when a tag is pushed.

Contributing
- Fork the repo.
- Create a feature branch feature/<short-description>.
- Follow branch naming and commit style.
- Open a pull request.
- PR checklist:
  - Code builds and tests run locally.
  - Add tests for new behavior.
  - Update README or docs for new features.
- Labels:
  - bug, enhancement, help wanted, good first issue.

Developer setup checklist
- Install Flutter and confirm flutter doctor shows no major issues.
- Install Python 3.9+ and pip.
- Set up a local Postgres or use Docker compose
  - docker-compose up -d db
- Set backend env variables in backend/.env
- Run migrations and seed content for local testing.

Release process
- Create a git tag vX.Y.Z with a changelog entry.
- Push the tag to GitHub.
- GitHub Actions will build artifacts and create a draft release.
- Review the draft release and mark it as published.
- Releases page:
  - https://github.com/tuilanguoivietnam/dailyquotes/releases
- For backend bundles, download the asset, extract, and execute run.sh as described earlier.

Security and secrets
- Do not commit API keys.
- Use GitHub Secrets for CI builds.
- Rotate provider keys if exposed.

FAQ

Q: Where can I download official builds?
A: Visit the releases page for official builds and release notes:
https://github.com/tuilanguoivietnam/dailyquotes/releases
Download the asset that matches your platform. If you download a backend bundle, extract the archive and execute the run script that the bundle includes.

Q: How do I enable TTS with a cloud provider?
A: Set your TTS_PROVIDER and provider credentials in backend/.env. Restart backend. Use POST /tts/generate to request audio. The backend caches audio and returns a URL.

Q: Can I run this offline?
A: Yes. Clients cache content locally. You can use the app without network for saved items and cached audio. Full sync requires network.

Q: How do I add a new language?
A: Add locale files in client/flutter/l10n and update translations for content in the backend. Admin UI supports adding translations per content item.

Q: Can I use my own OpenAI key?
A: Yes. Set OPENAI_API_KEY in backend/.env and restart the backend. The system can use OpenAI to generate content where allowed.

Code of conduct
- Be respectful.
- Use issue and PR templates.
- Keep discussion constructive.

Sample commands and snippets

Run the backend locally
- python -m venv .venv
- source .venv/bin/activate
- pip install -r backend/requirements.txt
- cd backend
- alembic upgrade head
- uvicorn app.main:app --reload --port 8000

Generate a build for Android
- cd client/flutter
- flutter pub get
- flutter build apk --release

Generate TTS audio via API (example payload)
- POST /api/v1/tts/generate
- body: {
    "text": "Close your eyes and breathe evenly for three breaths.",
    "voice": "soft_female",
    "speed": 0.95,
    "format": "mp3",
    "lang": "en"
  }

Example response
- {
    "id": "a6f1f2c3-4d5e-6f7a-8b9c-0d1e2f3a4b5c",
    "url": "https://storage.example.com/audio/a6f1f2c3.mp3",
    "ttl": 604800
  }

CLI helpers
- backend/scripts/seed_content.py — seed demo content for local testing.
- client/flutter/tools/generate_localizations.sh — export ARB files.

Content and editorial workflow
- Editors can draft content in the admin UI.
- Drafts go through review steps: draft -> review -> publish.
- Publish triggers notifications for subscribers of the content type.

Analytics and telemetry
- Keep analytics minimal.
- Track:
  - daily active users
  - saves
  - share counts
  - TTS requests
- Store event samples with anonymized IDs.

Performance tips
- Prefetch today's content on app start.
- Cache audio and delete old cached assets on low storage.
- Use low-res images for list views and high-res for details.

Accessibility
- Support large fonts and dynamic type.
- Respect system contrast settings.
- Add semantic labels for content cards and interactive controls.

Common development issues
- Flutter toolchain mismatch: run flutter doctor and update SDK.
- Backend dependency issues: use the virtualenv and pip install -r backend/requirements.txt.
- Database migration errors: re-run alembic with the correct database URL.

Roadmap ideas
- Add scheduled daily push with custom time per user.
- Add sync across devices via user accounts.
- Add user-generated content with moderation queue.
- Offer offline-first build with full local content pack downloads.
- Add native widget/shortcut for quick daily quote on mobile.

Repository topics and tags
This repo uses topics to make it findable. Relevant topics:
- affirmations
- ai
- bedtime-stories
- bible-verse
- cross-platform
- daily-quotes
- doubao
- family-app
- fastapi
- flutter-apps
- github
- mindfulness
- openai
- self-improvement
- sutra
- tts

Contact and support
- Open an issue for bugs and feature requests.
- Use pull requests for code contributions.
- For urgent problems, tag maintainers in an issue.

Changelog and release notes
- Follow semantic versioning.
- Each release includes a changelog entry and the built assets.
- Use the Releases page to download the assets and read release notes:
https://github.com/tuilanguoivietnam/dailyquotes/releases

License
- This project uses the MIT License. See LICENSE file for details.