# Firebase Storage CORS Fix for Web

**Issue**: SVG images from Firebase Storage fail to load on Flutter Web with error:
```
ClientException: Failed to fetch, uri=https://firebasestorage.googleapis.com/v0/b/jeevibe.firebasestorage.app/...
```

**Root Cause**: Firebase Storage blocks cross-origin requests by default. Flutter Web needs CORS enabled.

---

## Solution: Configure CORS on Firebase Storage

### Method 1: Using gsutil (Command Line) - Recommended

1. **Install Google Cloud SDK** (if not already installed):
   ```bash
   # Mac
   brew install --cask google-cloud-sdk

   # Or download from:
   # https://cloud.google.com/sdk/docs/install
   ```

2. **Authenticate**:
   ```bash
   gcloud auth login
   gcloud config set project jeevibe
   ```

3. **Create CORS configuration file**:
   ```bash
   cat > cors.json << 'EOF'
   [
     {
       "origin": ["*"],
       "method": ["GET"],
       "maxAgeSeconds": 3600
     }
   ]
   EOF
   ```

4. **Apply CORS configuration**:
   ```bash
   gsutil cors set cors.json gs://jeevibe.firebasestorage.app
   ```

5. **Verify CORS configuration**:
   ```bash
   gsutil cors get gs://jeevibe.firebasestorage.app
   ```

### Method 2: Using Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/project/jeevibe/storage)
2. Click on your storage bucket
3. Click the **3-dot menu** → **"Configure CORS"** or **"Bucket details"**
4. Add CORS rule (if option available)

**Note**: Firebase Console may not have direct CORS UI - use Method 1 (gsutil) instead.

---

## Production CORS Configuration

For production, restrict origins to your actual domains:

```json
[
  {
    "origin": [
      "https://jeevibe.web.app",
      "https://jeevibe.firebaseapp.com",
      "http://localhost:8080"
    ],
    "method": ["GET"],
    "maxAgeSeconds": 3600
  }
]
```

Apply with:
```bash
gsutil cors set cors-production.json gs://jeevibe.firebasestorage.app
```

---

## Alternative: Convert SVGs to PNGs

If CORS cannot be configured, convert SVG files to PNG format:

```bash
# Install ImageMagick
brew install imagemagick

# Convert SVG to PNG
for file in *.svg; do
  convert "$file" "${file%.svg}.png"
done
```

Then update your backend to serve PNG files instead.

---

## Testing After Fix

1. Clear browser cache (Cmd+Shift+R)
2. Reload the quiz page
3. Images should now load correctly

---

## References

- [Google Cloud Storage CORS](https://cloud.google.com/storage/docs/configuring-cors)
- [Firebase Storage CORS](https://firebase.google.com/docs/storage/web/download-files#cors_configuration)
- [gsutil CORS command](https://cloud.google.com/storage/docs/gsutil/commands/cors)
