# JEEVibe Documentation

AI-powered JEE preparation app with adaptive learning, snap-to-solve, and daily quizzes.

## 📚 Documentation Navigation

**New to the project?** Start here:
1. [REORGANIZATION_README.md](REORGANIZATION_README.md) - **How to find what you need** (start here!)
2. [walkthrough.md](walkthrough.md) - Product walkthrough
3. [01-setup/FIREBASE_SETUP_GUIDE.md](01-setup/FIREBASE_SETUP_GUIDE.md) - Setup guide

**Quick Reference** (in this folder):
- [API_ENDPOINTS_COMPLETE.md](API_ENDPOINTS_COMPLETE.md) - Complete API reference
- [FIRESTORE_INDEXES.md](FIRESTORE_INDEXES.md) - Database indexes
- [FIRESTORE_SECURITY_RULES.md](FIRESTORE_SECURITY_RULES.md) - Security rules

---

## 📂 Organized Documentation

All docs are now organized into logical folders:

### [01-setup/](01-setup/) - Getting Started
Firebase setup, environment configuration, deployment keys
- Firebase setup guides
- Environment variables
- GitHub configuration

### [02-architecture/](02-architecture/) - System Design
Database schemas, architecture reviews, design decisions
- **Database schema** (DATABASE_DESIGN_V2.md)
- **IRT algorithm** (engine/JEEVibe_IIDP_Algorithm_Specification_v4_CALIBRATED.md)
- System architecture reviews

### [03-features/](03-features/) - Features
Feature implementation documentation
- **Paywall system** (PAYWALL-SYSTEM-DESIGN.md)
- **Feature gating** (FEATURE-GATING-SYSTEM.md)
- Forgot PIN, Onboarding, Snap & Solve

### [04-deployment/](04-deployment/) - Deployment
Build guides, deployment processes
- Production deployment
- TestFlight setup
- Build troubleshooting

### [05-testing/](05-testing/) - Testing
Testing strategies and guides
- Testing guide
- Mobile testing strategy

### [06-fixes/](06-fixes/) - Bug Fixes
Bug fix documentation and history

### [07-reviews/](07-reviews/) - Quality
Code reviews and quality assessments

### [08-archive/](08-archive/) - Archive
Completed/legacy documentation

### [claude-assessment/](claude-assessment/) - External Assessment
Independent architectural assessment and recommendations

---

## Project Structure

```
JEEVibe/
├── backend/          # Node.js Express API
├── mobile/           # Flutter iOS/Android app
└── docs/             # Documentation (you are here)
```

## Prerequisites

### Backend
- Node.js 18+ installed
- OpenAI API key

### Mobile
- Flutter SDK installed
- Xcode (for iOS development)
- iOS device or simulator (iOS 12+)
- Apple Developer account (for TestFlight)

## Setup Instructions

### Backend Setup

1. Navigate to backend directory:
```bash
cd backend
```

2. Install dependencies:
```bash
npm install
```

3. Create `.env` file:
```bash
cp .env.example .env
```

4. Add your OpenAI API key to `.env`:
```
OPENAI_API_KEY=your_openai_api_key_here
PORT=3000
NODE_ENV=development
```

5. Start the server:
```bash
npm start
```

The server will run on `http://localhost:3000`

### Mobile Setup

1. Navigate to mobile directory:
```bash
cd mobile
```

2. Install dependencies:
```bash
flutter pub get
```

3. Update API base URL in `lib/services/api_service.dart`:
   - Change `baseUrl` to your backend URL
   - For iOS simulator: `http://localhost:3000`
   - For real device: `http://YOUR_COMPUTER_IP:3000` (ensure same WiFi network)

4. Run on iOS simulator:
```bash
flutter run
```

Or open in Xcode:
```bash
open ios/Runner.xcworkspace
```

## Features

- ✅ Camera capture for questions
- ✅ Gallery selection
- ✅ Image compression (<5MB)
- ✅ OpenAI Vision API for OCR
- ✅ Step-by-step solution generation
- ✅ Priya Ma'am persona in solutions
- ✅ 3 progressive follow-up questions
- ✅ Interactive mini-quiz with timer
- ✅ LaTeX rendering (basic)

## Testing

### Backend
- Health check: `GET http://localhost:3000/api/health`
- Solve endpoint: `POST http://localhost:3000/api/solve` (multipart/form-data with 'image' field)

### Mobile
- Test on iOS simulator first
- Then test on real device via TestFlight

## Next Steps

1. Configure iOS build settings in Xcode
2. Build and archive for TestFlight
3. Upload to App Store Connect
4. Set up TestFlight distribution
5. Test on real device

## Notes

- Backend processes images in memory (no storage for POC)
- Images are compressed client-side before upload
- LaTeX rendering is basic - needs enhancement for production
- API base URL needs to be updated for real device testing

