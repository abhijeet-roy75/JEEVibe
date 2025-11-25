# JEEVibe Snap & Solve POC

Proof of Concept for Snap & Solve feature - AI-powered JEE question solving with interactive follow-up quiz.

## Quick Start

1. **Backend Setup:**
   ```bash
   cd backend
   npm install
   # Add your OpenAI API key to .env
   npm start
   ```

2. **Mobile Setup:**
   ```bash
   cd mobile
   flutter pub get
   flutter run
   ```

## Documentation

All documentation is in the [`docs/`](./docs/) folder:

- **[Setup Guide](./docs/SETUP_COMPLETE.md)** - Complete setup instructions
- **[Implementation Plan](./docs/Snap_Solve_POC_Implementation_Plan.md)** - Detailed POC plan
- **[Build Status](./docs/BUILD_STATUS.md)** - Current build status and known issues
- **[Backend README](./docs/backend_README.md)** - Backend API documentation
- **[Mobile README](./docs/mobile_README.md)** - Mobile app documentation

## Project Structure

```
JEEVibe/
├── backend/          # Node.js Express API
├── mobile/           # Flutter iOS app
├── scripts/          # Utility scripts (clean, rebuild, icon generation, etc.)
└── docs/             # All documentation
```

## Features

- ✅ Camera capture for questions
- ✅ OpenAI Vision API for OCR
- ✅ Step-by-step solution generation
- ✅ Priya Ma'am persona in solutions
- ✅ 3 progressive follow-up questions
- ✅ Interactive mini-quiz with timer

For detailed information, see the [documentation](./docs/).

