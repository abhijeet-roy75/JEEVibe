# JEEVibe Snap & Solve POC

Proof of Concept for Snap & Solve feature - AI-powered JEE question solving with interactive follow-up quiz.

## Project Structure

```
JEEVibe/
├── backend/          # Node.js Express API
├── mobile/           # Flutter iOS app
└── docs/             # Documentation
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

