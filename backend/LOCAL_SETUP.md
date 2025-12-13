# Local Development Setup

This guide will help you run the JEEVibe backend locally for testing.

## Prerequisites

1. **Node.js** (v18 or higher recommended)
2. **Firebase Service Account Key** (`serviceAccountKey.json`)
3. **OpenAI API Key**

## Quick Start

### 1. Install Dependencies

```bash
cd backend
npm install
```

### 2. Set Up Environment Variables

Create a `.env` file in the `backend/` directory:

```bash
cp .env.example .env
```

Edit `.env` and add your OpenAI API key:
```
OPENAI_API_KEY=your-openai-api-key-here
```

### 3. Verify Firebase Service Account

The backend will automatically use `serviceAccountKey.json` if it exists in the `backend/` directory. This file should already be present.

To verify:
```bash
ls -la backend/serviceAccountKey.json
```

If the file doesn't exist, download it from Firebase Console:
1. Go to Firebase Console → Project Settings → Service Accounts
2. Click "Generate New Private Key"
3. Save the file as `serviceAccountKey.json` in the `backend/` directory

### 4. Start the Server

```bash
npm start
```

Or for development with auto-reload (if you have nodemon installed):
```bash
npm run dev
```

The server will start on `http://localhost:3000` by default.

## Configuration

### Port

Default port is `3000`. To change it, set the `PORT` environment variable:

```bash
PORT=4000 npm start
```

Or add to `.env`:
```
PORT=4000
```

### CORS

For local development, CORS is automatically configured to allow:
- `http://localhost:3000`
- `http://localhost:8080`
- `http://127.0.0.1:3000`
- `http://127.0.0.1:8080`

To add more origins, set `ALLOWED_ORIGINS` in `.env`:
```
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080,http://localhost:5173
```

## Testing the Server

### Health Check

```bash
curl http://localhost:3000/api/health
```

### Test Firebase Connection

```bash
curl http://localhost:3000/api/test-firebase
```

## Common Issues

### Firebase Not Initializing

**Error**: `Firebase configuration not found`

**Solution**: 
- Ensure `serviceAccountKey.json` exists in the `backend/` directory
- Or set `FIREBASE_PROJECT_ID`, `FIREBASE_PRIVATE_KEY`, and `FIREBASE_CLIENT_EMAIL` in `.env`

### Port Already in Use

**Error**: `EADDRINUSE: address already in use`

**Solution**: 
- Change the port in `.env`: `PORT=4000`
- Or kill the process using port 3000:
  ```bash
  lsof -ti:3000 | xargs kill -9
  ```

### CORS Errors

**Error**: `Not allowed by CORS`

**Solution**: 
- Add your origin to `ALLOWED_ORIGINS` in `.env`
- Or ensure you're accessing from `localhost` or `127.0.0.1`

## Environment Variables Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PORT` | No | `3000` | Server port |
| `NODE_ENV` | No | `development` | Environment mode |
| `OPENAI_API_KEY` | Yes | - | OpenAI API key |
| `ALLOWED_ORIGINS` | No | `localhost:3000,8080` | Comma-separated CORS origins |
| `FIREBASE_PROJECT_ID` | Conditional* | - | Firebase project ID |
| `FIREBASE_PRIVATE_KEY` | Conditional* | - | Firebase private key |
| `FIREBASE_CLIENT_EMAIL` | Conditional* | - | Firebase client email |
| `CRON_SECRET` | No | - | Secret for cron job endpoints |

*Required only if not using `serviceAccountKey.json`

## Running Tests

```bash
# Run all tests
npm test

# Run unit tests only
npm run test:unit

# Run integration tests only
npm run test:integration

# Run tests in watch mode
npm run test:watch

# Run tests with coverage
npm run test:coverage
```

## Stopping the Server

Press `Ctrl+C` in the terminal where the server is running.

## Next Steps

1. Update your Flutter app's API base URL to point to `http://localhost:3000` (or your configured port)
2. Test the daily quiz generation endpoint
3. Check logs in `backend/logs/` directory

