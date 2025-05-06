# DailyMind Deployment Guide

## Requirements

### Backend
- Python 3.8+
- MongoDB 4.0+
- Sufficient disk space for audio file storage

### Frontend
- Flutter 3.0+
- Android Studio / Xcode (for mobile builds)

## Deployment Steps

### 1. Clone the Project
```bash
git clone https://github.com/yourusername/dailymind.git
cd dailymind
```

### 2. Backend Setup

#### 2.1 Install Dependencies
```bash
cd backend
pip install -r requirements.txt
```

#### 2.2 Configure Environment Variables
Copy the example env file:
```bash
cp env.example .env
```

Edit `.env` and fill in your configuration:
```env
# MongoDB connection
MONGODB_URL=mongodb://localhost:27017

# OpenAI API
OPENAI_API_KEY=your_openai_api_key_here

# Doubao TTS API
DOUBAO_APPID=your_doubao_appid_here
DOUBAO_TOKEN=your_doubao_token_here
DOUBAO_API_KEY=your_doubao_api_key_here

# Google Service Account
GOOGLE_SERVICE_ACCOUNT_PROJECT_ID=your_project_id
GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY_ID=your_private_key_id
GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
GOOGLE_SERVICE_ACCOUNT_CLIENT_EMAIL=your_service_account_email
GOOGLE_SERVICE_ACCOUNT_CLIENT_ID=your_client_id

# Android package name
ANDROID_PACKAGE_NAME=com.yourcompany.dailymind
```

#### 2.3 Start the Backend
```bash
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### 3. Frontend Setup

#### 3.1 Install Dependencies
```bash
cd frontend
flutter pub get
```

#### 3.2 Configure API Endpoint
Edit `lib/config/api_config.dart`:
```dart
class ApiConfig {
  // Set your API server address
  static const String baseUrl = 'http://your-api-server.com';
}
```

#### 3.3 Run the App
```bash
flutter run
```

## Production Deployment

### Using Docker (Recommended)

#### Backend Docker Deployment
```bash
cd backend
docker build -t dailymind-backend .
docker run -d -p 8000:8000 --env-file .env dailymind-backend
```

#### Frontend Build
```bash
cd frontend
flutter build web  # Web version
flutter build apk  # Android version
flutter build ios  # iOS version
```

### Using Nginx Reverse Proxy
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Security

### 1. Environment Variables
- Ensure `.env` is never committed to version control
- Use strong passwords and proper access control
- Rotate API keys regularly

### 2. Database Security
- Use MongoDB Atlas or other managed services
- Configure network access control
- Enable database encryption

### 3. API Security
- Use HTTPS
- Configure CORS policy
- Implement rate limiting

## Monitoring & Logs

### Logs
Backend logs are stored in `backend/logs/`.

### Health Check
Visit `http://your-api-server.com/api/health` to check service status.

## Troubleshooting

### Common Issues

1. **MongoDB connection failed**
   - Check if MongoDB is running
   - Verify connection string format
   - Check network connectivity

2. **API key errors**
   - Ensure environment variables are set correctly
   - Check if API keys are valid
   - Ensure API quota is sufficient

3. **Frontend cannot connect to backend**
   - Check API endpoint configuration
   - Ensure backend is running
   - Check network/firewall settings

## Updates & Maintenance

### Update Code
```bash
git pull origin main
cd backend && pip install -r requirements.txt
cd ../frontend && flutter pub get
```

### Database Backup
```bash
mongodump --db dailymind --out /backup/path
```

### Database Restore
```bash
mongorestore --db dailymind /backup/path/dailymind
```

## Support

If you encounter issues:
1. Check the log files
2. Review GitHub Issues
3. Open a new Issue describing your problem 