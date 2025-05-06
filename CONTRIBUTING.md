# Contributing Guide

Thank you for your interest in the DailyMind project! We welcome all forms of contribution.

## How to Contribute

### 1. Fork the Project
1. Fork this project on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/yourusername/dailymind.git
   cd dailymind
   ```

### 2. Create a Branch
```bash
git checkout -b feature/your-feature-name
```

### 3. Set Up Development Environment

#### Backend
```bash
cd backend
pip install -r requirements.txt
cp env.example .env
# Edit .env to configure environment variables
```

#### Frontend
```bash
cd frontend
flutter pub get
# Edit lib/config/api_config.dart to set API endpoint
```

### 4. Development
- Follow the project's code style
- Add necessary tests
- Ensure all checks pass

### 5. Commit Changes
```bash
git add .
git commit -m "feat: add new feature"
git push origin feature/your-feature-name
```

### 6. Create a Pull Request
1. Create a Pull Request on GitHub
2. Describe your changes
3. Wait for code review

## Code Style

### Python (Backend)
- Use Black for code formatting
- Follow PEP 8
- Add type annotations
- Write docstrings

### Dart (Frontend)
- Use `dart format` for code formatting
- Follow Dart official style
- Use Riverpod for state management
- Add necessary comments

### Commit Message Convention
Use [Conventional Commits](https://www.conventionalcommits.org/) format:

```
type(scope): description

feat: new feature
fix: bug fix
docs: documentation update
style: code style changes
refactor: code refactor
test: test related
chore: build or auxiliary tool changes
```

## Reporting Issues

### Bug Reports
Please use GitHub Issues to report bugs and include:
- OS and version
- Browser/device info
- Steps to reproduce
- Expected and actual behavior
- Error logs (if any)

### Feature Requests
For new features, please:
- Describe the feature
- Explain the use case
- Provide design suggestions (optional)

## Development Guide

### Project Structure
```
dailymind/
├── backend/          # Python FastAPI backend
├── frontend/         # Flutter frontend
├── docs/             # Documentation
└── README.md         # Project description
```

### Tech Stack
- **Backend**: Python, FastAPI, MongoDB
- **Frontend**: Flutter, Dart, Riverpod
- **Database**: MongoDB
- **Deployment**: Docker, Nginx

### Development Tools
- **IDE**: VS Code, Android Studio
- **Version Control**: Git
- **API Testing**: Postman, curl
- **Database**: MongoDB Compass

## Testing

### Backend
```bash
cd backend
python -m pytest tests/
```

### Frontend
```bash
cd frontend
flutter test
```

## Documentation

### Update Documentation
- Update README.md and related docs
- Add API documentation
- Update deployment guide

### Translation
- Support multi-language translation
- Update language pack files

## Release

### Versioning
Use [Semantic Versioning](https://semver.org/):
- MAJOR.MINOR.PATCH
- e.g., 1.0.0

### Release Process
1. Update version number
2. Update CHANGELOG.md
3. Create a release tag
4. Publish to app stores

## Community

### Communication Channels
- GitHub Issues
- GitHub Discussions
- Mailing list

### Code of Conduct
- Be respectful
- Stay professional
- Engage in constructive discussion
- Follow open source licenses

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgements

Thanks to all contributors to this project!

---

If you have any questions, feel free to contact the project maintainers. 