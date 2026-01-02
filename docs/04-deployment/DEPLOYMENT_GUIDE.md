# JEEVibe Deployment Guide

This guide covers deploying the backend to Render.com and building the iOS app for TestFlight.

---

## Part 1: Backend Deployment to Render.com

### Prerequisites
- GitHub account (to connect your repository)
- Render.com account (free tier available)
- OpenAI API key

### Step 1: Prepare Backend for Deployment

1. **Ensure package.json has start script**
   ```bash
   cd backend
   ```
   
   Verify `package.json` has:
   ```json
   {
     "scripts": {
       "start": "node src/server.js",
       "dev": "nodemon src/server.js"
     }
   }
   ```

2. **Create `.gitignore` if not exists**
   ```
   node_modules/
   .env
   .DS_Store
   ```

3. **Commit and push to GitHub**
   ```bash
   git add .
   git commit -m "Prepare backend for Render deployment"
   git push origin main
   ```

### Step 2: Deploy to Render.com

1. **Sign up/Login to Render.com**
   - Go to https://render.com
   - Sign up or login with GitHub

2. **Create New Web Service**
   - Click "New +" → "Web Service"
   - Connect your GitHub repository
   - Select the `JEEVibe` repository

3. **Configure Web Service**
   - **Name**: `jeevibe-backend` (or your preferred name)
   - **Region**: Choose closest to your users (e.g., Oregon, Singapore)
   - **Branch**: `main`
   - **Root Directory**: `backend`
   - **Runtime**: `Node`
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
   - **Instance Type**: `Free` (or paid for better performance)

4. **Add Environment Variables**
   Click "Advanced" → "Add Environment Variable":
   
   | Key | Value |
   |-----|-------|
   | `OPENAI_API_KEY` | Your OpenAI API key |
   | `PORT` | `10000` (Render default) |
   | `NODE_ENV` | `production` |

5. **Deploy**
   - Click "Create Web Service"
   - Wait for deployment (5-10 minutes)
   - Note your service URL: `https://jeevibe-backend.onrender.com`

### Step 3: Verify Backend Deployment

1. **Test Health Endpoint**
   ```bash
   curl https://jeevibe-backend.onrender.com/health
   ```
   
   Should return:
   ```json
   {"status":"ok","timestamp":"..."}
   ```

2. **Check Logs**
   - Go to Render dashboard → Your service → Logs
   - Verify no errors

### Step 4: Update Mobile App API URL

1. **Find API configuration in mobile app**
   ```bash
   cd mobile/lib/services
   ```

2. **Update `api_service.dart`**
   Look for the base URL and update it:
   ```dart
   static const String baseUrl = 'https://jeevibe-backend.onrender.com';
   ```

3. **Commit changes**
   ```bash
   git add .
   git commit -m "Update API URL to Render deployment"
   git push origin main
   ```

---

## Part 2: iOS App Build for TestFlight

### Prerequisites
- macOS with Xcode installed (latest version)
- Apple Developer Account ($99/year)
- Valid iOS device or simulator

### Step 1: Prepare iOS Project

1. **Open project in Xcode**
   ```bash
   cd mobile
   open ios/Runner.xcworkspace
   ```
   
   ⚠️ **Important**: Open `.xcworkspace`, NOT `.xcodeproj`

2. **Update Bundle Identifier**
   - Select `Runner` in project navigator
   - Go to "Signing & Capabilities" tab
   - Update Bundle Identifier: `com.yourcompany.jeevibe`
   - Select your Team (Apple Developer account)

3. **Update Version and Build Number**
   - In Xcode, select `Runner` → `General`
   - **Version**: `1.0.0` (user-facing version)
   - **Build**: `1` (increment for each TestFlight upload)

4. **Configure App Icons**
   - Ensure `ios/Runner/Assets.xcassets/AppIcon.appiconset` has all required sizes
   - Use a tool like https://appicon.co to generate all sizes

### Step 2: Configure Signing

1. **Automatic Signing (Recommended)**
   - In Xcode → "Signing & Capabilities"
   - Check "Automatically manage signing"
   - Select your Team
   - Xcode will create provisioning profiles automatically

2. **Manual Signing (Advanced)**
   - Go to https://developer.apple.com/account
   - Create App ID, Provisioning Profile, and Certificates manually
   - Import to Xcode

### Step 3: Update App Store Connect

1. **Create App in App Store Connect**
   - Go to https://appstoreconnect.apple.com
   - Click "My Apps" → "+" → "New App"
   - **Platform**: iOS
   - **Name**: JEEVibe
   - **Primary Language**: English
   - **Bundle ID**: Select the one you created
   - **SKU**: `jeevibe-ios-001`
   - **User Access**: Full Access

2. **Fill App Information**
   - App Privacy Policy URL
   - App Category: Education
   - Content Rights
   - Age Rating

### Step 4: Build Archive

1. **Select Target Device**
   - In Xcode toolbar, select "Any iOS Device (arm64)"

2. **Clean Build Folder**
   - Menu: Product → Clean Build Folder
   - Wait for completion

3. **Archive the App**
   - Menu: Product → Archive
   - Wait for build to complete (5-15 minutes)
   - Archive Organizer will open automatically

### Step 5: Upload to TestFlight

1. **Validate Archive**
   - In Archive Organizer, select your archive
   - Click "Validate App"
   - Select distribution method: "App Store Connect"
   - Follow prompts, click "Validate"
   - Wait for validation (2-5 minutes)

2. **Distribute Archive**
   - Click "Distribute App"
   - Select "App Store Connect"
   - Select "Upload"
   - **Options**:
     - ✅ Include bitcode: NO (deprecated)
     - ✅ Upload symbols: YES
     - ✅ Manage version and build: Automatically
   - Click "Upload"
   - Wait for upload (5-10 minutes)

### Step 6: Configure TestFlight

1. **Wait for Processing**
   - Go to App Store Connect → TestFlight
   - Wait for "Processing" to complete (10-30 minutes)
   - You'll receive email when ready

2. **Add Test Information**
   - Click on your build
   - Add "What to Test" notes for testers
   - Add Export Compliance: Select "No" if not using encryption

3. **Add Internal Testers**
   - Go to "Internal Testing" tab
   - Click "+" to add testers
   - Add email addresses of testers
   - Click "Add"

4. **Add External Testers (Optional)**
   - Go to "External Testing" tab
   - Create a new group
   - Add testers
   - Submit for Beta App Review (required for external testing)

### Step 7: Distribute to Testers

1. **Internal Testers**
   - They'll receive email invitation immediately
   - They can install via TestFlight app

2. **External Testers**
   - Wait for Beta App Review approval (1-2 days)
   - They'll receive email invitation after approval

---

## Common Issues & Solutions

### Backend Deployment Issues

**Issue**: Build fails on Render
- **Solution**: Check logs, ensure `package.json` is correct, verify Node version

**Issue**: API returns 500 errors
- **Solution**: Check environment variables are set correctly, especially `OPENAI_API_KEY`

**Issue**: Slow cold starts
- **Solution**: Render free tier sleeps after inactivity. Upgrade to paid tier or use a keep-alive service

### iOS Build Issues

**Issue**: "No signing certificate found"
- **Solution**: Enable "Automatically manage signing" in Xcode

**Issue**: "Archive failed"
- **Solution**: Clean build folder, update CocoaPods: `cd ios && pod install`

**Issue**: "Upload failed - Invalid Bundle"
- **Solution**: Ensure version/build numbers are incremented from previous upload

**Issue**: "Missing compliance"
- **Solution**: In App Store Connect, answer export compliance questions

---

## Testing Checklist

### Backend Testing
- [ ] Health endpoint responds
- [ ] Image upload works
- [ ] OCR extraction works
- [ ] Solution generation works
- [ ] Follow-up quiz generation works
- [ ] CORS configured for mobile app

### iOS App Testing
- [ ] App launches successfully
- [ ] Camera permissions work
- [ ] Image capture works
- [ ] OCR and solution display correctly
- [ ] LaTeX renders properly
- [ ] Navigation flows work
- [ ] No crashes or errors

---

## Maintenance

### Updating Backend
1. Make changes to code
2. Commit and push to GitHub
3. Render auto-deploys from `main` branch
4. Monitor logs for errors

### Updating iOS App
1. Make changes to code
2. Increment build number in Xcode
3. Archive and upload new build
4. Add "What to Test" notes
5. Notify testers

---

## Support Resources

- **Render Docs**: https://render.com/docs
- **TestFlight Guide**: https://developer.apple.com/testflight/
- **App Store Connect**: https://appstoreconnect.apple.com
- **Flutter iOS Deployment**: https://docs.flutter.dev/deployment/ios

---

## Next Steps After Deployment

1. **Monitor Backend Performance**
   - Set up monitoring/alerts in Render
   - Track API response times
   - Monitor OpenAI API usage

2. **Gather Tester Feedback**
   - Create feedback form
   - Track bugs and feature requests
   - Iterate based on feedback

3. **Prepare for Production**
   - Complete App Store listing
   - Create marketing materials
   - Submit for App Store review
