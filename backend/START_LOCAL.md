# Quick Start: Running Backend Locally

## Step 1: Start the Backend Server

```bash
cd backend
npm start
```

The server will start on `http://localhost:3000`

## Step 2: Update Mobile App API URL

Edit `mobile/lib/services/api_service.dart`:

Change line 16 from:
```dart
static const String baseUrl = 'https://jeevibe.onrender.com';
```

To:
```dart
static const String baseUrl = 'http://localhost:3000';
```

Also update `mobile/lib/services/firebase/firestore_user_service.dart` line 10:
```dart
static const String baseUrl = 'http://localhost:3000';
```

## Step 3: Testing on Physical Device

If testing on a physical device (not emulator), use your computer's local IP address:

1. Find your local IP:
   ```bash
   # macOS - Find active network interface IP
   ifconfig en0 | grep "inet " | awk '{print $2}'
   # Or try en1 if en0 doesn't work
   ifconfig en1 | grep "inet " | awk '{print $2}'
   
   # Alternative: Show all non-localhost IPs
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```
   
   **Your current IP**: `192.168.5.81` (already in code comments)

2. Update the baseUrl to use your IP:
   ```dart
   static const String baseUrl = 'http://192.168.5.81:3000'; // Your IP
   ```
   
   Or uncomment the existing line in `api_service.dart`:
   ```dart
   // static const String baseUrl = 'http://192.168.5.81:3000'; // For real device testing
   ```

3. Ensure your phone and computer are on the same WiFi network

## Step 4: Verify Connection

Test the health endpoint:
```bash
curl http://localhost:3000/api/health
```

## Troubleshooting

- **Connection refused**: Make sure the backend is running (`npm start`)
- **CORS errors**: The backend automatically allows localhost in development mode
- **Firebase errors**: Ensure `serviceAccountKey.json` exists in the `backend/` directory

